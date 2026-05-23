import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
@testable import LangoTrace
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
}
