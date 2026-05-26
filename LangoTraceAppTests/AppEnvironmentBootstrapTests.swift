import Foundation
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

    func testAIProviderSettingsResolverMapsKeychainFailuresToCoreFailure() throws {
        let source = try String(
            contentsOf: langoTraceAppSourceFileURL(named: "AppEnvironment.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("catch let error as AIProviderCredentialStoreError"))
        XCTAssertTrue(source.contains("throw AIProviderCredentialResolveFailure("))
        XCTAssertTrue(source.contains("credentialResolveFailureCategory(for: error)"))
    }
}

private func langoTraceAppSourceFileURL(named fileName: String, currentFilePath: String = #filePath) -> URL {
    var url = URL(fileURLWithPath: currentFilePath)
    while url.lastPathComponent != "LangoTraceAppTests" {
        let parent = url.deletingLastPathComponent()
        precondition(parent.path != url.path, "Could not locate LangoTraceAppTests root")
        url = parent
    }
    return url
        .deletingLastPathComponent()
        .appendingPathComponent("LangoTraceApp")
        .appendingPathComponent(fileName)
}
