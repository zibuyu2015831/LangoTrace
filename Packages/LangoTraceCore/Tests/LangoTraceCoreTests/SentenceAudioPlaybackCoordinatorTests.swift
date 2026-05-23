import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Sentence audio playback coordinator")
struct SentenceAudioPlaybackCoordinatorTests {
    @Test("Coordinator plays cache hits without calling provider generation")
    func coordinatorPlaysCacheHitsWithoutGeneration() async throws {
        let artifact = mediaArtifact()
        let mediaStore = FakeMediaStore(lookup: .hit(artifact))
        let generator = FakeGenerator()
        let player = FakePlayer()
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: mediaStore,
            generationService: generator,
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: player
        )
        let request = sentenceRequest()

        try await coordinator.handleTap(request)

        #expect(await generator.requestCount == 0)
        #expect(await player.playedSources.map(\.artifactID) == ["artifact-1"])
    }

    @Test("Coordinator generates, commits, resolves, and plays cache misses")
    func coordinatorGeneratesCommitsAndPlaysCacheMisses() async throws {
        let mediaStore = FakeMediaStore(lookup: .miss)
        let generator = FakeGenerator(result: SentenceTTSGenerationResult(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: "staging/generated.mp3",
                byteSize: 3,
                contentHash: String(repeating: "b", count: 64)
            ),
            mimeType: "audio/mpeg",
            byteSize: 3,
            durationSeconds: 0.4,
            diagnostics: SentenceTTSGenerationDiagnostics(
                providerPresetID: "openai",
                endpointPurpose: .tts,
                modelName: "gpt-4o-mini-tts",
                outputFormat: .mp3,
                textLengthBucket: .short,
                byteSizeBucket: .small,
                durationBucket: .short,
                elapsedMilliseconds: 1
            )
        ))
        let player = FakePlayer()
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: mediaStore,
            generationService: generator,
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: player
        )

        try await coordinator.handleTap(sentenceRequest())

        #expect(await generator.requestCount == 1)
        #expect(await mediaStore.committedInputs.count == 1)
        #expect(await player.playedSources.map(\.artifactID) == ["committed-artifact"])
    }

    @Test("Coordinator resets presentation state when playback completes")
    func coordinatorResetsPresentationStateWhenPlaybackCompletes() async throws {
        let completion = PlaybackCompletionProbe()
        let player = FakePlayer(completion: completion.session)
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .hit(mediaArtifact())),
            generationService: FakeGenerator(),
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: player
        )
        let request = sentenceRequest()

        try await coordinator.handleTap(request)
        #expect(await coordinator.presentationState(for: request).activeKey != nil)

        await completion.complete(.success(()))
        let didReset = await waitUntil {
            await coordinator.presentationState(for: request) == .idle
        }
        #expect(didReset)
    }

    @Test("Coordinator reports configuration issues without external work")
    func coordinatorReportsConfigurationIssues() async throws {
        let generator = FakeGenerator()
        let coordinator = SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .requiresRetest),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .miss),
            generationService: generator,
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: FakePlayer()
        )
        let request = sentenceRequest()

        try await coordinator.handleTap(request)

        #expect(await coordinator.presentationState(for: request) == .requiresConfiguration(.requiresRetest))
        #expect(await generator.requestCount == 0)
    }
}

private actor FakeAvailabilityService: TTSConfigurationAvailabilityService {
    let status: PlayableTTSConfigurationStatus

    init(status: PlayableTTSConfigurationStatus) {
        self.status = status
    }

    func loadDefaultPlayableTTSConfiguration(languageCode _: String) async throws -> PlayableTTSConfigurationStatus {
        status
    }
}

private actor FakeSecretResolver: PlayableTTSSecretResolving {
    let secret: String?

    init(secret: String?) {
        self.secret = secret
    }

    func plaintextSecret(for _: PlayableTTSConfiguration) async throws -> String? {
        secret
    }
}

private actor FakeMediaStore: LocalMediaArtifactStoring {
    private let lookup: MediaArtifactLookupResult
    private(set) var committedInputs: [TTSAudioArtifactCommitInput] = []

    init(lookup: MediaArtifactLookupResult) {
        self.lookup = lookup
    }

    func ttsAudioArtifact(for _: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult {
        lookup
    }

    func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact {
        committedInputs.append(input)
        return mediaArtifact(id: "committed-artifact")
    }

    func invalidateArtifacts(_: MediaArtifactInvalidationRequest) async throws {}

    func cleanupArtifacts(_: MediaArtifactCleanupRequest) async throws -> MediaArtifactCleanupResult {
        MediaArtifactCleanupResult(deletedArtifactCount: 0, deletedFileCount: 0, reclaimedBytes: 0, failedFileCount: 0)
    }
}

private actor FakeGenerator: SentenceTTSGenerating {
    private let result: SentenceTTSGenerationResult
    private(set) var requestCount = 0

    init(result: SentenceTTSGenerationResult? = nil) {
        self.result = result ?? SentenceTTSGenerationResult(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: "staging/default.mp3",
                byteSize: 3,
                contentHash: String(repeating: "c", count: 64)
            ),
            mimeType: "audio/mpeg",
            byteSize: 3,
            durationSeconds: 0.4,
            diagnostics: SentenceTTSGenerationDiagnostics(
                providerPresetID: "openai",
                endpointPurpose: .tts,
                modelName: "gpt-4o-mini-tts",
                outputFormat: .mp3,
                textLengthBucket: .short,
                byteSizeBucket: .small,
                durationBucket: .short,
                elapsedMilliseconds: 1
            )
        )
    }

    func generateSentenceTTS(_: SentenceTTSGenerationRequest) async throws -> SentenceTTSGenerationResult {
        requestCount += 1
        return result
    }
}

private struct FakePlaybackSourceResolver: MediaArtifactPlaybackSourceResolving {
    func playbackSource(for artifact: MediaArtifact) async throws -> MediaArtifactPlaybackSource {
        MediaArtifactPlaybackSource(
            artifactID: artifact.id,
            fileURL: URL(fileURLWithPath: "/tmp/\(artifact.id).mp3"),
            mimeType: artifact.mimeType,
            byteSize: artifact.byteSize,
            contentHash: artifact.contentHash
        )
    }
}

private actor FakePlayer: TTSAudioPlaying {
    private(set) var playedSources: [MediaArtifactPlaybackSource] = []
    private let completion: @Sendable () -> TTSAudioPlaybackSession

    init(completion: @escaping @Sendable () -> TTSAudioPlaybackSession = { .completed }) {
        self.completion = completion
    }

    func play(_ source: MediaArtifactPlaybackSource) async throws -> TTSAudioPlaybackSession {
        playedSources.append(source)
        return completion()
    }

    func pause() async {}

    func resume() async throws {}

    func stop() async {}
}

private actor PlaybackCompletionProbe {
    private var continuation: CheckedContinuation<Result<Void, SentenceAudioPlaybackFailure>, Never>?
    private var pendingResult: Result<Void, SentenceAudioPlaybackFailure>?

    nonisolated var session: @Sendable () -> TTSAudioPlaybackSession {
        { [self] in
            TTSAudioPlaybackSession {
                await withCheckedContinuation { continuation in
                    Task {
                        await self.store(continuation)
                    }
                }
            }
        }
    }

    func complete(_ result: Result<Void, SentenceAudioPlaybackFailure>) {
        guard let continuation else {
            pendingResult = result
            return
        }
        continuation.resume(returning: result)
        self.continuation = nil
    }

    private func store(_ continuation: CheckedContinuation<Result<Void, SentenceAudioPlaybackFailure>, Never>) {
        if let pendingResult {
            self.pendingResult = nil
            continuation.resume(returning: pendingResult)
            return
        }
        self.continuation = continuation
    }
}

private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let start = ContinuousClock.now
    while await !condition() {
        if start.duration(to: ContinuousClock.now) > .nanoseconds(Int64(timeoutNanoseconds)) {
            return false
        }
        await Task.yield()
    }
    return true
}

private func sentenceRequest() -> SentenceAudioRequest {
    SentenceAudioRequest(
        languageSpaceID: "space-1",
        owner: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        sentenceSource: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        sentenceIndex: 0,
        targetText: "Today I wrote one sentence.",
        targetLanguageCode: "en"
    )
}

private func playableConfiguration() throws -> PlayableTTSConfiguration {
    let endpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-tts",
            profileID: "profile-1",
            purpose: .tts,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-4o-mini-tts",
            credentialID: "credential-1",
            supportsImageInput: false,
            imageInputEnabled: false
        ),
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    let voiceProfile = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3
    )
    return PlayableTTSConfiguration(
        endpoint: endpoint,
        settings: TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
        voiceProfile: voiceProfile
    )
}

private func mediaArtifact(id: String = "artifact-1") -> MediaArtifact {
    MediaArtifact(
        id: id,
        languageSpaceID: "space-1",
        owner: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        type: .ttsSentenceAudio,
        derivationKind: .ttsAudio,
        derivationKeyHash: "derivation-key",
        relativeFilePath: "tts/\(id).mp3",
        mimeType: "audio/mpeg",
        byteSize: 3,
        durationSeconds: 0.4,
        contentHash: String(repeating: "a", count: 64),
        createdAt: Date(timeIntervalSince1970: 0),
        lastAccessedAt: Date(timeIntervalSince1970: 0)
    )
}
