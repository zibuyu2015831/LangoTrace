import CryptoKit
import Foundation

public protocol PlayableTTSSecretResolving: Sendable {
    func plaintextSecret(for configuration: PlayableTTSConfiguration) async throws -> String?
}

public actor SentenceAudioPlaybackCoordinator {
    private let availabilityService: any TTSConfigurationAvailabilityService
    private let secretResolver: any PlayableTTSSecretResolving
    private let mediaStore: any LocalMediaArtifactStoring
    private let generationService: any SentenceTTSGenerating
    private let playbackSourceResolver: any MediaArtifactPlaybackSourceResolving
    private let player: any TTSAudioPlaying
    private var state = SentenceAudioPlaybackCoordinatorState()
    private var requestKeyBySummary: [SentenceAudioRequestSummary: SentenceAudioKey] = [:]

    public init(
        availabilityService: any TTSConfigurationAvailabilityService,
        secretResolver: any PlayableTTSSecretResolving,
        mediaStore: any LocalMediaArtifactStoring,
        generationService: any SentenceTTSGenerating,
        playbackSourceResolver: any MediaArtifactPlaybackSourceResolving,
        player: any TTSAudioPlaying
    ) {
        self.availabilityService = availabilityService
        self.secretResolver = secretResolver
        self.mediaStore = mediaStore
        self.generationService = generationService
        self.playbackSourceResolver = playbackSourceResolver
        self.player = player
    }

    public func handleTap(_ request: SentenceAudioRequest) async throws {
        let availability = try await availabilityService.loadDefaultPlayableTTSConfiguration(
            languageCode: request.targetLanguageCode
        )
        guard case let .available(configuration) = availability else {
            requestKeyBySummary[request.nonSensitiveSummary] = nil
            setConfigurationState(for: request, availability: availability)
            return
        }

        let artifactKey = Self.artifactKey(for: request, configuration: configuration)
        let key = SentenceAudioKey(
            sentenceSource: request.sentenceSource,
            sentenceTextHash: artifactKey.sentenceTextHash,
            targetLanguageCode: request.targetLanguageCode,
            configurationFingerprint: artifactKey.configurationFingerprint
        )
        requestKeyBySummary[request.nonSensitiveSummary] = key
        let effects = state.reduce(.tap(key))
        for effect in effects {
            try await perform(effect, request: request, artifactKey: artifactKey, configuration: configuration)
        }
    }

    public func presentationState(for request: SentenceAudioRequest) -> SentenceAudioPresentationState {
        guard let key = requestKeyBySummary[request.nonSensitiveSummary] else {
            return .idle
        }
        return state.presentationState(for: key)
    }
}

private extension SentenceAudioPlaybackCoordinator {
    func perform(
        _ effect: SentenceAudioPlaybackEffect,
        request: SentenceAudioRequest,
        artifactKey: TTSAudioArtifactKey,
        configuration: PlayableTTSConfiguration
    ) async throws {
        switch effect {
        case let .start(key):
            try await start(key: key, request: request, artifactKey: artifactKey, configuration: configuration)
        case .cancelGeneration:
            break
        case .pause:
            await player.pause()
        case .resume:
            try await player.resume()
        case .stopPlayback:
            await player.stop()
        }
    }

    func start(
        key: SentenceAudioKey,
        request: SentenceAudioRequest,
        artifactKey: TTSAudioArtifactKey,
        configuration: PlayableTTSConfiguration
    ) async throws {
        switch try await mediaStore.ttsAudioArtifact(for: artifactKey) {
        case let .hit(artifact):
            try await play(artifact: artifact, key: key)
        case .miss, .invalidated:
            _ = state.reduce(.generationStarted(key))
            let secret = try await secretResolver.plaintextSecret(for: configuration)
            guard secret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                _ = state.reduce(.generationFailed(key, .credentialMissing))
                return
            }
            let result = try await generationService.generateSentenceTTS(
                SentenceTTSGenerationRequest(
                    audioRequest: request,
                    artifactKey: artifactKey,
                    playableConfiguration: configuration,
                    plaintextSecret: secret
                )
            )
            let artifact = try await mediaStore.commitTTSAudioArtifact(
                TTSAudioArtifactCommitInput(
                    key: artifactKey,
                    languageSpaceID: request.languageSpaceID,
                    owner: request.owner,
                    stagedFile: result.stagedFile,
                    mimeType: result.mimeType,
                    durationSeconds: result.durationSeconds,
                    createdAt: Date()
                )
            )
            guard state.activeKey == key else {
                return
            }
            try await play(artifact: artifact, key: key)
        }
    }

    func play(artifact: MediaArtifact, key: SentenceAudioKey) async throws {
        let source = try await playbackSourceResolver.playbackSource(for: artifact)
        try await player.play(source)
        _ = state.reduce(.playbackStarted(key))
    }

    func setConfigurationState(
        for request: SentenceAudioRequest,
        availability: PlayableTTSConfigurationStatus
    ) {
        if case .available = availability {
            return
        }
        let issue: SentenceAudioConfigurationIssue = switch availability {
        case .available:
            .notConfigured
        case .notConfigured:
            .notConfigured
        case .notTested:
            .notTested
        case .requiresRetest:
            .requiresRetest
        case .failedLastTest:
            .failedLastTest
        case .credentialMissing:
            .credentialMissing
        case .unsupportedProvider:
            .unsupportedProvider
        }
        let key = SentenceAudioKey(
            sentenceSource: request.sentenceSource,
            sentenceTextHash: Self.sha256Hex(for: request.targetText),
            targetLanguageCode: request.targetLanguageCode,
            configurationFingerprint: "unavailable"
        )
        requestKeyBySummary[request.nonSensitiveSummary] = key
        state.setPresentationState(.requiresConfiguration(issue), for: key)
    }

    static func artifactKey(
        for request: SentenceAudioRequest,
        configuration: PlayableTTSConfiguration
    ) -> TTSAudioArtifactKey {
        let voice = configuration.voiceProfile
        return TTSAudioArtifactKey(
            sentenceSource: request.sentenceSource,
            sentenceTextHash: sha256Hex(for: request.targetText),
            targetLanguageCode: request.targetLanguageCode,
            providerProfileID: configuration.endpoint.profileID,
            ttsEndpointID: configuration.endpoint.id,
            ttsVoiceProfileID: voice.id,
            adapterKind: configuration.settings.adapterKind.rawValue,
            adapterVersion: "v1",
            modelName: configuration.endpoint.modelName,
            voiceIDHash: sha256Hex(for: voice.voiceID),
            outputFormat: voice.outputFormat,
            sampleRate: voice.sampleRate,
            speed: voice.speed,
            pitch: voice.pitch,
            volume: voice.volume,
            instructionsHash: voice.instructions.map(sha256Hex(for:)),
            providerParametersHash: voice.providerParameters.isEmpty
                ? nil
                : sha256Hex(for: String(describing: voice.providerParameters)),
            configurationFingerprint: voice.configurationFingerprint
        )
    }

    static func sha256Hex(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
