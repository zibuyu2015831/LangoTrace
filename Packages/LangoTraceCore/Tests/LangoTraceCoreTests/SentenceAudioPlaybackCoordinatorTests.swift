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
                modelName: "tts-1",
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

    @Test("Coordinator resets playback state using artifact duration when player completion is missing")
    func coordinatorResetsPlaybackStateUsingArtifactDurationFallback() async throws {
        let completion = PlaybackCompletionProbe()
        let player = FakePlayer(completion: completion.session)
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .hit(mediaArtifact(durationSeconds: 0.001))),
            generationService: FakeGenerator(),
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: player
        )
        let request = sentenceRequest()

        try await coordinator.handleTap(request)
        #expect(await coordinator.presentationState(for: request).activeKey != nil)

        let didReset = await waitUntil(timeoutNanoseconds: 2_000_000_000) {
            await coordinator.presentationState(for: request) == .idle
        }
        #expect(didReset)
    }

    @Test("Coordinator publishes idle update when duration fallback completes playback")
    func coordinatorPublishesIdleUpdateWhenDurationFallbackCompletesPlayback() async throws {
        let completion = PlaybackCompletionProbe()
        let player = FakePlayer(completion: completion.session)
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .hit(mediaArtifact(durationSeconds: 0.001))),
            generationService: FakeGenerator(),
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: player
        )
        let request = sentenceRequest()
        let stream = await coordinator.stateUpdates(for: request)
        let updates = StateUpdateCollector(stream: stream)

        try await coordinator.handleTap(request)

        let didPublishIdle = await waitUntil(timeoutNanoseconds: 2_000_000_000) {
            let values = updates.values
            let state = await coordinator.presentationState(for: request)
            return values.contains(.idle) && state == .idle
        }
        updates.cancel()
        #expect(didPublishIdle)
    }

    @Test("Coordinator keeps paused playback paused when duration fallback would have fired")
    func coordinatorKeepsPausedPlaybackPausedWhenDurationFallbackWouldHaveFired() async throws {
        let completion = PlaybackCompletionProbe()
        let player = FakePlayer(completion: completion.session)
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .hit(mediaArtifact(durationSeconds: 0.001))),
            generationService: FakeGenerator(),
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: player
        )
        let request = sentenceRequest()

        try await coordinator.handleTap(request)
        try await coordinator.handleTap(request)
        try await Task.sleep(nanoseconds: 700_000_000)

        #expect(await coordinator.presentationState(for: request).activeKey != nil)
        #expect(await player.pauseCount == 1)
    }

    @Test("Coordinator stop active playback stops player and clears presentation state")
    func coordinatorStopActivePlaybackStopsPlayerAndClearsState() async throws {
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
        await coordinator.stopActivePlayback()

        #expect(await player.stopCount == 1)
        #expect(await coordinator.presentationState(for: request) == .idle)
    }

    @Test("Coordinator artifact key provider parameters hash ignores insertion order")
    func coordinatorArtifactKeyProviderParametersHashIgnoresInsertionOrder() throws {
        let request = sentenceRequest()
        let first = try playableConfiguration(providerParameters: [
            "instructions": .string("Speak slowly"),
            "response_format": .string("mp3"),
        ])
        let second = try playableConfiguration(providerParameters: [
            "response_format": .string("mp3"),
            "instructions": .string("Speak slowly"),
        ])

        let firstKey = SentenceAudioPlaybackCoordinator.artifactKey(for: request, configuration: first)
        let secondKey = SentenceAudioPlaybackCoordinator.artifactKey(for: request, configuration: second)

        let expectedHash = SentenceAudioPlaybackCoordinator.sha256Hex(
            for: "instructions=s:Speak slowly;response_format=s:mp3"
        )
        #expect(firstKey.providerParametersHash == expectedHash)
        #expect(secondKey.providerParametersHash == expectedHash)
        #expect(firstKey.derivationKeyHash == secondKey.derivationKeyHash)
    }

    @Test("Coordinator keeps presentation state separate for same sentence index in different sources")
    func coordinatorKeepsPresentationStateSeparateAcrossSentenceSources() async throws {
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
        let first = sentenceRequest(source: .entry(id: "entry-1", sentenceIndex: 0))
        let second = sentenceRequest(source: .entry(id: "entry-2", sentenceIndex: 0))

        try await coordinator.handleTap(first)

        #expect(await coordinator.presentationState(for: first).activeKey != nil)
        #expect(await coordinator.presentationState(for: second) == .idle)
    }

    @Test("Coordinator reduces generation provider failures to failed state")
    func coordinatorReducesGenerationProviderFailuresToFailedState() async throws {
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .miss),
            generationService: ThrowingGenerator(error: SentenceAudioPlaybackFailure.rateLimited),
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: FakePlayer()
        )
        let request = sentenceRequest()

        try await coordinator.handleTap(request)

        #expect(await coordinator.presentationState(for: request) == .failed(.rateLimited))
    }

    @Test("Coordinator reduces unknown generation errors to failed state instead of staying generating")
    func coordinatorReducesUnknownGenerationErrorsToFailedState() async throws {
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .miss),
            generationService: ThrowingGenerator(error: URLError(.badServerResponse)),
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: FakePlayer()
        )
        let request = sentenceRequest()

        try await coordinator.handleTap(request)

        #expect(await coordinator.presentationState(for: request) == .failed(.playbackFailed))
    }

    @Test("Coordinator tap during generation cancels the in-flight generation task")
    func coordinatorTapDuringGenerationCancelsInFlightGenerationTask() async throws {
        let generator = SuspendingGenerator()
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .miss),
            generationService: generator,
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: FakePlayer()
        )
        let request = sentenceRequest()

        let firstTap = Task {
            try await coordinator.handleTap(request)
        }
        let didStartGenerating = await waitUntil {
            await generator.startedCount > 0
        }
        #expect(didStartGenerating)

        try await coordinator.handleTap(request)

        let didCancelGeneration = await waitUntil {
            await generator.cancellationCount > 0
        }
        #expect(didCancelGeneration)
        firstTap.cancel()
        _ = try? await firstTap.value
        #expect(await coordinator.presentationState(for: request) == .idle)
    }

    @Test("Coordinator clamps playback duration fallback to a sane upper bound")
    func coordinatorClampsPlaybackDurationFallback() {
        let clamped = SentenceAudioPlaybackCoordinator.playbackDurationFallbackNanoseconds(
            forRemainingSeconds: .greatestFiniteMagnitude
        )
        #expect(clamped == UInt64(86400.0 * 1_000_000_000))
        #expect(SentenceAudioPlaybackCoordinator.playbackDurationFallbackNanoseconds(forRemainingSeconds: -5) == 0)
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

    func practiceRecordingArtifact(for _: PracticeRecordingArtifactKey) async throws -> MediaArtifactLookupResult {
        .miss
    }

    func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact {
        committedInputs.append(input)
        return mediaArtifact(id: "committed-artifact")
    }

    func commitPracticeRecordingArtifact(_: PracticeRecordingArtifactCommitInput) async throws -> MediaArtifact {
        mediaArtifact(id: "committed-practice-artifact")
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
                modelName: "tts-1",
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

private actor ThrowingGenerator: SentenceTTSGenerating {
    private let error: any Error

    init(error: any Error) {
        self.error = error
    }

    func generateSentenceTTS(_: SentenceTTSGenerationRequest) async throws -> SentenceTTSGenerationResult {
        throw error
    }
}

private actor SuspendingGenerator: SentenceTTSGenerating {
    private(set) var startedCount = 0
    private(set) var cancellationCount = 0

    func generateSentenceTTS(_: SentenceTTSGenerationRequest) async throws -> SentenceTTSGenerationResult {
        startedCount += 1
        do {
            while true {
                try Task.checkCancellation()
                await Task.yield()
            }
        } catch {
            cancellationCount += 1
            throw error
        }
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
    private(set) var pauseCount = 0
    private(set) var stopCount = 0
    private let completion: @Sendable () -> TTSAudioPlaybackSession

    init(completion: @escaping @Sendable () -> TTSAudioPlaybackSession = { .completed }) {
        self.completion = completion
    }

    func play(_ source: MediaArtifactPlaybackSource) async throws -> TTSAudioPlaybackSession {
        playedSources.append(source)
        return completion()
    }

    func pause() async {
        pauseCount += 1
    }

    func resume() async throws {}

    func stop() async {
        stopCount += 1
    }
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

private final class StateUpdateCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var collectedValues: [SentenceAudioPresentationState] = []

    init(stream: AsyncStream<SentenceAudioPresentationState>) {
        task = Task {
            for await value in stream {
                self.append(value)
            }
        }
    }

    var values: [SentenceAudioPresentationState] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return collectedValues
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func append(_ value: SentenceAudioPresentationState) {
        lock.lock()
        defer {
            lock.unlock()
        }
        collectedValues.append(value)
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

private func sentenceRequest(
    source: TTSSentenceSource = .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0)
) -> SentenceAudioRequest {
    SentenceAudioRequest(
        languageSpaceID: "space-1",
        owner: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        sentenceSource: source,
        sentenceIndex: 0,
        targetText: "Today I wrote one sentence.",
        targetLanguageCode: "en"
    )
}

private func playableConfiguration(
    providerParameters: [String: TTSProviderParameterValue] = [:]
) throws -> PlayableTTSConfiguration {
    let endpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-tts",
            profileID: "profile-1",
            purpose: .tts,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "tts-1",
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
        modelName: "tts-1",
        voiceID: "coral",
        outputFormat: .mp3,
        providerParameters: providerParameters
    )
    return PlayableTTSConfiguration(
        endpoint: endpoint,
        settings: TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
        voiceProfile: voiceProfile
    )
}

private func mediaArtifact(id: String = "artifact-1", durationSeconds: Double? = 0.4) -> MediaArtifact {
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
        durationSeconds: durationSeconds,
        contentHash: String(repeating: "a", count: 64),
        createdAt: Date(timeIntervalSince1970: 0),
        lastAccessedAt: Date(timeIntervalSince1970: 0)
    )
}
