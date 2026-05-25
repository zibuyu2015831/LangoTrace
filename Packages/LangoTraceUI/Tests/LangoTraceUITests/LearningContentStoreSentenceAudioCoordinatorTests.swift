import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Learning content store coordinator sentence audio")
@MainActor
struct LearningContentStoreSentenceAudioCoordinatorTests {
    @Test("Store keeps coordinator state subscription alive until playback completion")
    func storeKeepsCoordinatorStateSubscriptionAliveUntilPlaybackCompletion() async throws {
        let completion = PlaybackCompletionProbe()
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .available(playableConfiguration())),
            secretResolver: FakeSecretResolver(secret: "sk-test"),
            mediaStore: FakeMediaStore(lookup: .hit(mediaArtifact())),
            generationService: FakeGenerator(),
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: FakePlayer(completion: completion.session)
        )
        let store = LearningContentStore(
            repository: InMemoryLearningContentRepository(seedEntries: []),
            spaceID: "space-1",
            sentenceAudioPlaybackActions: .coordinator(coordinator)
        )
        let entry = try store.createEntry(title: "Walk", body: "I walked home.", source: .typedText)
        let rendering = try #require(store.generateLocalPreview(for: entry))
        let sentence = try #require(rendering.sentences.first)

        await store.handleSentenceAudioTap(
            rendering: rendering,
            sentence: sentence,
            sentenceIndex: 0,
            languageSpace: LanguageSpacePreview(
                id: "space-1",
                name: "English",
                nativeLanguage: "zh-Hans",
                targetLanguage: "English",
                targetLanguageCode: "en",
                level: .a1
            )
        )
        #expect(store.sentenceAudioPlaybackState(for: sentence.id).activeKey != nil)

        await completion.complete(.success(()))
        let didReset = await waitUntil {
            store.sentenceAudioPlaybackState(for: sentence.id) == .idle
        }

        #expect(didReset)
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
        MediaArtifact(
            id: "committed-artifact",
            languageSpaceID: input.languageSpaceID,
            owner: input.owner,
            type: .ttsSentenceAudio,
            derivationKind: .ttsAudio,
            derivationKeyHash: "derivation-key",
            relativeFilePath: input.stagedFile.relativeStagingPath,
            mimeType: input.mimeType,
            byteSize: input.stagedFile.byteSize,
            durationSeconds: input.durationSeconds,
            contentHash: input.stagedFile.contentHash,
            createdAt: Date(timeIntervalSince1970: 0),
            lastAccessedAt: Date(timeIntervalSince1970: 0),
            invalidatedAt: nil,
            policy: .defaultDerivedMediaPolicy
        )
    }

    func commitPracticeRecordingArtifact(_: PracticeRecordingArtifactCommitInput) async throws -> MediaArtifact {
        MediaArtifact(
            id: "committed-practice-artifact",
            languageSpaceID: "space-1",
            owner: .practiceSession(id: "session-1"),
            type: .shadowingRecording,
            derivationKind: .practiceRecording,
            derivationKeyHash: "practice-key",
            relativeFilePath: "practice/session-1/recording.m4a",
            mimeType: "audio/mp4",
            byteSize: 3,
            durationSeconds: 0.4,
            contentHash: String(repeating: "c", count: 64),
            createdAt: Date(timeIntervalSince1970: 0),
            lastAccessedAt: Date(timeIntervalSince1970: 0),
            invalidatedAt: nil,
            policy: .defaultDerivedMediaPolicy
        )
    }

    func invalidateArtifacts(_: MediaArtifactInvalidationRequest) async throws {}

    func cleanupArtifacts(_: MediaArtifactCleanupRequest) async throws -> MediaArtifactCleanupResult {
        MediaArtifactCleanupResult(deletedArtifactCount: 0, deletedFileCount: 0, reclaimedBytes: 0, failedFileCount: 0)
    }
}

private actor FakeGenerator: SentenceTTSGenerating {
    func generateSentenceTTS(_: SentenceTTSGenerationRequest) async throws -> SentenceTTSGenerationResult {
        SentenceTTSGenerationResult(
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
        )
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
    private let completion: @Sendable () -> TTSAudioPlaybackSession

    init(completion: @escaping @Sendable () -> TTSAudioPlaybackSession) {
        self.completion = completion
    }

    func play(_: MediaArtifactPlaybackSource) async throws -> TTSAudioPlaybackSession {
        completion()
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

private func mediaArtifact(durationSeconds: Double? = 0.4) -> MediaArtifact {
    MediaArtifact(
        id: "artifact-1",
        languageSpaceID: "space-1",
        owner: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        type: .ttsSentenceAudio,
        derivationKind: .ttsAudio,
        derivationKeyHash: "derivation-key",
        relativeFilePath: "tts/artifact-1.mp3",
        mimeType: "audio/mpeg",
        byteSize: 3,
        durationSeconds: durationSeconds,
        contentHash: String(repeating: "a", count: 64),
        createdAt: Date(timeIntervalSince1970: 0),
        lastAccessedAt: Date(timeIntervalSince1970: 0),
        invalidatedAt: nil,
        policy: .defaultDerivedMediaPolicy
    )
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))
    while !condition(), ContinuousClock.now < deadline {
        await Task.yield()
    }
    return condition()
}
