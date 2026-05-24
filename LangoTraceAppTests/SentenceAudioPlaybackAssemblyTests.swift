@testable import LangoTrace
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import XCTest

final class SentenceAudioPlaybackAssemblyTests: XCTestCase {
    func testSentenceAudioPlaybackAssemblyBuildsCoordinator() throws {
        let database = try AppDatabase.inMemory()
        let previewStore = InMemoryTTSAudioPreviewStore()
        let coordinator = try SentenceAudioPlaybackAssembly.makeCoordinator(
            database: database,
            mediaArtifactsRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("LangoTraceAppTests-\(UUID().uuidString)", isDirectory: true),
            credentialStore: InMemoryAIProviderCredentialStore(),
            diagnosticLogger: DisabledDiagnosticLogger(),
            ttsPreviewStore: previewStore
        )

        XCTAssertNotNil(coordinator)
    }

    func testCoordinatorBoxActionsExposeStateUpdates() async throws {
        let coordinator = try SentenceAudioPlaybackCoordinator(
            availabilityService: FakeAvailabilityService(status: .requiresRetest),
            secretResolver: FakeSecretResolver(),
            mediaStore: FakeMediaStore(),
            generationService: FakeGenerator(),
            playbackSourceResolver: FakePlaybackSourceResolver(),
            player: FakePlayer()
        )
        let box = SentenceAudioPlaybackCoordinatorBox {
            coordinator
        }
        let stream = await box.actions().stateUpdates(sentenceRequest())
        var iterator = stream.makeAsyncIterator()

        let firstState = await iterator.next()

        XCTAssertEqual(firstState, .idle)
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
    func plaintextSecret(for _: PlayableTTSConfiguration) async throws -> String? {
        nil
    }
}

private actor FakeMediaStore: LocalMediaArtifactStoring {
    func ttsAudioArtifact(for _: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult {
        .miss
    }

    func commitTTSAudioArtifact(_: TTSAudioArtifactCommitInput) async throws -> MediaArtifact {
        throw SentenceAudioPlaybackFailure.playbackFailed
    }

    func invalidateArtifacts(_: MediaArtifactInvalidationRequest) async throws {}

    func cleanupArtifacts(_: MediaArtifactCleanupRequest) async throws -> MediaArtifactCleanupResult {
        MediaArtifactCleanupResult(deletedArtifactCount: 0, deletedFileCount: 0, reclaimedBytes: 0, failedFileCount: 0)
    }
}

private actor FakeGenerator: SentenceTTSGenerating {
    func generateSentenceTTS(_: SentenceTTSGenerationRequest) async throws -> SentenceTTSGenerationResult {
        throw SentenceAudioPlaybackFailure.playbackFailed
    }
}

private struct FakePlaybackSourceResolver: MediaArtifactPlaybackSourceResolving {
    func playbackSource(for _: MediaArtifact) async throws -> MediaArtifactPlaybackSource {
        throw SentenceAudioPlaybackFailure.playbackFileUnavailable
    }
}

private actor FakePlayer: TTSAudioPlaying {
    func play(_: MediaArtifactPlaybackSource) async throws -> TTSAudioPlaybackSession {
        throw SentenceAudioPlaybackFailure.playbackFailed
    }

    func pause() async {}

    func resume() async throws {}

    func stop() async {}
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
