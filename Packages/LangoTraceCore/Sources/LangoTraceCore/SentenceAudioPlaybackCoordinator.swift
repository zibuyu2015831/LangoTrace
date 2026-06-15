import Foundation

public protocol PlayableTTSSecretResolving: Sendable {
    func plaintextSecret(for configuration: PlayableTTSConfiguration) async throws -> RedactedSecret?
}

public actor SentenceAudioPlaybackCoordinator {
    private let availabilityService: any TTSConfigurationAvailabilityService
    private let secretResolver: any PlayableTTSSecretResolving
    private let mediaStore: any LocalMediaArtifactStoring
    private let generationService: any SentenceTTSGenerating
    private let playbackSourceResolver: any MediaArtifactPlaybackSourceResolving
    private let player: any TTSAudioPlaying
    private let now: @Sendable () -> Date
    private var state = SentenceAudioPlaybackCoordinatorState()
    private var requestKeyBySummary: [SentenceAudioRequestSummary: SentenceAudioKey] = [:]
    private var stateObservers: [
        SentenceAudioRequestSummary: [UUID: AsyncStream<SentenceAudioPresentationState>.Continuation]
    ] = [:]
    private var playbackCompletionTask: Task<Void, Never>?
    private var playbackDurationFallbackTask: Task<Void, Never>?
    private var activeGenerationTask: Task<MediaArtifact, Error>?
    private var activeGenerationKey: SentenceAudioKey?
    private var activePlaybackKey: SentenceAudioKey?
    private var activePlaybackRemainingSeconds: TimeInterval?
    private var activePlaybackStartedAt: Date?

    public init(
        availabilityService: any TTSConfigurationAvailabilityService,
        secretResolver: any PlayableTTSSecretResolving,
        mediaStore: any LocalMediaArtifactStoring,
        generationService: any SentenceTTSGenerating,
        playbackSourceResolver: any MediaArtifactPlaybackSourceResolving,
        player: any TTSAudioPlaying,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.availabilityService = availabilityService
        self.secretResolver = secretResolver
        self.mediaStore = mediaStore
        self.generationService = generationService
        self.playbackSourceResolver = playbackSourceResolver
        self.player = player
        self.now = now
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
        let effects = reduceAndNotify(.tap(key))
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

    public func stateUpdates(for request: SentenceAudioRequest) -> AsyncStream<SentenceAudioPresentationState> {
        let summary = request.nonSensitiveSummary
        let observerID = UUID()
        return AsyncStream { continuation in
            Task {
                self.addStateObserver(continuation, id: observerID, summary: summary)
            }
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeStateObserver(id: observerID, summary: summary)
                }
            }
        }
    }

    public func stopActivePlayback() async {
        guard let key = activePlaybackKey else {
            return
        }
        clearPlaybackCompletionTracking()
        await player.stop()
        _ = reduceAndNotify(.playbackCompleted(key))
    }
}

private extension SentenceAudioPlaybackCoordinator {
    @discardableResult
    func reduceAndNotify(_ transition: SentenceAudioPlaybackTransition) -> [SentenceAudioPlaybackEffect] {
        let effects = state.reduce(transition)
        notifyStateObservers()
        return effects
    }

    func perform(
        _ effect: SentenceAudioPlaybackEffect,
        request: SentenceAudioRequest,
        artifactKey: TTSAudioArtifactKey,
        configuration: PlayableTTSConfiguration
    ) async throws {
        switch effect {
        case let .start(key):
            try await start(key: key, request: request, artifactKey: artifactKey, configuration: configuration)
        case let .cancelGeneration(key):
            cancelActiveGeneration(for: key)
        case let .pause(key):
            pausePlaybackDurationFallback(for: key)
            await player.pause()
        case let .resume(key):
            try await player.resume()
            resumePlaybackDurationFallback(for: key)
        case .stopPlayback:
            clearPlaybackCompletionTracking()
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
            _ = reduceAndNotify(.generationStarted(key))
            let artifact: MediaArtifact
            do {
                let secret = try await secretResolver.plaintextSecret(for: configuration)
                guard secret?.unsafeUnwrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    _ = reduceAndNotify(.generationFailed(key, .credentialMissing))
                    return
                }
                let generationTask = Task<MediaArtifact, Error> { [self] in
                    let result = try await generationService.generateSentenceTTS(
                        SentenceTTSGenerationRequest(
                            audioRequest: request,
                            artifactKey: artifactKey,
                            playableConfiguration: configuration,
                            plaintextSecret: secret
                        )
                    )
                    return try await mediaStore.commitTTSAudioArtifact(
                        TTSAudioArtifactCommitInput(
                            key: artifactKey,
                            languageSpaceID: request.languageSpaceID,
                            owner: request.owner,
                            stagedFile: result.stagedFile,
                            mimeType: result.mimeType,
                            durationSeconds: result.durationSeconds,
                            createdAt: now()
                        )
                    )
                }
                activeGenerationTask = generationTask
                activeGenerationKey = key
                defer {
                    clearGenerationTracking(for: key)
                }
                artifact = try await generationTask.value
            } catch is CancellationError {
                return
            } catch let failure as SentenceAudioPlaybackFailure {
                guard failure != .cancelled else {
                    return
                }
                reduceGenerationFailureIfStillGenerating(key, failure: failure)
                return
            } catch {
                reduceGenerationFailureIfStillGenerating(key, failure: .playbackFailed)
                return
            }
            guard state.activeKey == key else {
                return
            }
            try await play(artifact: artifact, key: key)
        }
    }

    func cancelActiveGeneration(for key: SentenceAudioKey) {
        guard activeGenerationKey == key else {
            return
        }
        activeGenerationTask?.cancel()
    }

    func clearGenerationTracking(for key: SentenceAudioKey) {
        guard activeGenerationKey == key else {
            return
        }
        activeGenerationTask = nil
        activeGenerationKey = nil
    }

    func reduceGenerationFailureIfStillGenerating(_ key: SentenceAudioKey, failure: SentenceAudioPlaybackFailure) {
        guard state.presentationState(for: key) == .generating(key) else {
            return
        }
        _ = reduceAndNotify(.generationFailed(key, failure))
    }

    func play(artifact: MediaArtifact, key: SentenceAudioKey) async throws {
        let source = try await playbackSourceResolver.playbackSource(for: artifact)
        do {
            let session = try await player.play(source)
            _ = reduceAndNotify(.playbackStarted(key))
            clearPlaybackCompletionTracking()
            activePlaybackKey = key
            activePlaybackRemainingSeconds = playbackDurationFallbackSeconds(for: artifact)
            schedulePlaybackDurationFallbackIfNeeded(for: key)
            playbackCompletionTask = Task { [self] in
                let result = await session.completion()
                guard !Task.isCancelled else {
                    return
                }
                handlePlaybackCompletion(for: key, result: result)
            }
        } catch let failure as SentenceAudioPlaybackFailure {
            _ = reduceAndNotify(.playbackFailed(key, failure))
            throw failure
        } catch {
            _ = reduceAndNotify(.playbackFailed(key, .playbackFailed))
            throw error
        }
    }

    func handlePlaybackCompletion(
        for key: SentenceAudioKey,
        result: Result<Void, SentenceAudioPlaybackFailure>
    ) {
        defer {
            clearPlaybackCompletionTracking()
        }
        guard state.presentationState(for: key).activeKey == key else {
            return
        }
        switch result {
        case .success:
            _ = reduceAndNotify(.playbackCompleted(key))
        case let .failure(failure):
            if failure == .cancelled {
                _ = reduceAndNotify(.playbackCompleted(key))
            } else {
                _ = reduceAndNotify(.playbackFailed(key, failure))
            }
        }
    }

    func clearPlaybackCompletionTracking() {
        playbackCompletionTask?.cancel()
        playbackCompletionTask = nil
        playbackDurationFallbackTask?.cancel()
        playbackDurationFallbackTask = nil
        activePlaybackKey = nil
        activePlaybackRemainingSeconds = nil
        activePlaybackStartedAt = nil
    }

    func pausePlaybackDurationFallback(for key: SentenceAudioKey) {
        guard activePlaybackKey == key else {
            return
        }
        playbackDurationFallbackTask?.cancel()
        playbackDurationFallbackTask = nil
        if let startedAt = activePlaybackStartedAt, let remaining = activePlaybackRemainingSeconds {
            activePlaybackRemainingSeconds = max(0, remaining - now().timeIntervalSince(startedAt))
        }
        activePlaybackStartedAt = nil
    }

    func resumePlaybackDurationFallback(for key: SentenceAudioKey) {
        guard activePlaybackKey == key else {
            return
        }
        schedulePlaybackDurationFallbackIfNeeded(for: key)
    }

    func schedulePlaybackDurationFallbackIfNeeded(for key: SentenceAudioKey) {
        guard let remaining = activePlaybackRemainingSeconds else {
            return
        }
        playbackDurationFallbackTask?.cancel()
        activePlaybackStartedAt = now()
        playbackDurationFallbackTask = Task { [self] in
            let nanoseconds = Self.playbackDurationFallbackNanoseconds(forRemainingSeconds: remaining)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else {
                return
            }
            handlePlaybackCompletion(for: key, result: .success(()))
        }
    }

    func playbackDurationFallbackSeconds(for artifact: MediaArtifact) -> TimeInterval? {
        guard let durationSeconds = artifact.durationSeconds,
              durationSeconds.isFinite,
              durationSeconds >= 0
        else {
            return nil
        }
        return durationSeconds + 0.5
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
            sentenceTextHash: StableHashing.sha256Hex(request.targetText),
            targetLanguageCode: request.targetLanguageCode,
            configurationFingerprint: "unavailable"
        )
        requestKeyBySummary[request.nonSensitiveSummary] = key
        state.setPresentationState(.requiresConfiguration(issue), for: key)
        notifyStateObservers()
    }

    func presentationState(for summary: SentenceAudioRequestSummary) -> SentenceAudioPresentationState {
        guard let key = requestKeyBySummary[summary] else {
            return .idle
        }
        return state.presentationState(for: key)
    }

    func addStateObserver(
        _ continuation: AsyncStream<SentenceAudioPresentationState>.Continuation,
        id: UUID,
        summary: SentenceAudioRequestSummary
    ) {
        stateObservers[summary, default: [:]][id] = continuation
        continuation.yield(presentationState(for: summary))
    }

    func removeStateObserver(id: UUID, summary: SentenceAudioRequestSummary) {
        stateObservers[summary]?[id] = nil
        if stateObservers[summary]?.isEmpty == true {
            stateObservers[summary] = nil
        }
    }

    func notifyStateObservers() {
        for (summary, observers) in stateObservers {
            let presentationState = presentationState(for: summary)
            for continuation in observers.values {
                continuation.yield(presentationState)
            }
        }
    }
}

extension SentenceAudioPlaybackCoordinator {
    static let maxPlaybackDurationFallbackSeconds: TimeInterval = 86400

    static func playbackDurationFallbackNanoseconds(forRemainingSeconds remaining: TimeInterval) -> UInt64 {
        let clamped = min(max(0, remaining), maxPlaybackDurationFallbackSeconds)
        return UInt64(clamped * 1_000_000_000)
    }

    static func artifactKey(
        for request: SentenceAudioRequest,
        configuration: PlayableTTSConfiguration
    ) -> TTSAudioArtifactKey {
        let voice = configuration.voiceProfile
        return TTSAudioArtifactKey(
            sentenceSource: request.sentenceSource,
            sentenceTextHash: StableHashing.sha256Hex(request.targetText),
            targetLanguageCode: request.targetLanguageCode,
            providerProfileID: configuration.endpoint.profileID,
            ttsEndpointID: configuration.endpoint.id,
            ttsVoiceProfileID: voice.id,
            adapterKind: configuration.settings.adapterKind.rawValue,
            adapterVersion: "v1",
            modelName: configuration.endpoint.modelName,
            voiceIDHash: StableHashing.sha256Hex(voice.voiceID),
            outputFormat: voice.outputFormat,
            sampleRate: voice.sampleRate,
            speed: voice.speed,
            pitch: voice.pitch,
            volume: voice.volume,
            instructionsHash: voice.instructions.map { StableHashing.sha256Hex($0) },
            providerParametersHash: voice.providerParameters.isEmpty
                ? nil
                : StableHashing.sha256Hex(TTSProviderParameterValue.canonicalSerialization(of: voice.providerParameters)),
            configurationFingerprint: voice.configurationFingerprint
        )
    }
}
