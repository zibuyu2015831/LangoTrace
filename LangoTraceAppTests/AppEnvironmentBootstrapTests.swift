@testable import LangoTrace
import LangoTraceAI
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import XCTest

final class AppEnvironmentBootstrapTests: XCTestCase {
    func testBootstrapUsesPersistentLearningContentRepositoryBoundary() {
        let environment = AppEnvironment.bootstrap()
        let repositoryType = String(describing: type(of: environment.learningContentRepository))

        XCTAssertEqual(repositoryType, "GRDBLearningContentRepositoryBridge")
        XCTAssertFalse(repositoryType.contains("InMemory"))
        XCTAssertFalse(repositoryType.contains("Unavailable"))
    }

    func testBootstrapKeepsUnimplementedExternalServicesDisabled() {
        let environment = AppEnvironment.bootstrap()

        XCTAssertTrue(environment.aiProvider is DisabledAIProvider)
        XCTAssertTrue(environment.speechService is DisabledSpeechService)
        XCTAssertTrue(environment.syncService is DisabledSyncService)
    }
}
