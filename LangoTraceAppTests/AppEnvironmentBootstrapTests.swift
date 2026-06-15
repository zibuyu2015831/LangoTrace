import Foundation
@testable import LangoTrace
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import XCTest

final class AppEnvironmentBootstrapTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppEnvironmentBootstrapTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    private var temporaryDatabaseURL: URL {
        temporaryDirectory.appendingPathComponent("LangoTrace.sqlite", isDirectory: false)
    }

    func testBootstrapUsesPersistentLearningContentRepositoryBoundary() {
        let environment = AppEnvironment.bootstrap(databaseURL: temporaryDatabaseURL)
        let repositoryType = String(describing: type(of: environment.learningContentRepository))

        XCTAssertEqual(repositoryType, "GRDBLearningContentRepositoryBridge")
        XCTAssertFalse(repositoryType.contains("InMemory"))
        XCTAssertFalse(repositoryType.contains("Unavailable"))
    }

    func testBootstrapKeepsUnimplementedExternalServicesDisabled() {
        let environment = AppEnvironment.bootstrap(databaseURL: temporaryDatabaseURL)

        XCTAssertTrue(environment.syncService is DisabledSyncService)
    }

    func testMakeDiagnosticLoggerStaysDisabledWithoutExplicitOptIn() {
        let logger = makeDiagnosticLogger(
            databaseFactory: SharedAppDatabaseFactory(databaseURL: temporaryDatabaseURL),
            environment: [:]
        )

        XCTAssertTrue(logger is DisabledDiagnosticLogger)
    }

    func testMakeDiagnosticLoggerEnablesConsoleLoggingOnlyWhenOptedIn() {
        let logger = makeDiagnosticLogger(
            databaseFactory: SharedAppDatabaseFactory(databaseURL: temporaryDatabaseURL),
            environment: ["LANGOTRACE_DIAGNOSTICS": "1"]
        )

        XCTAssertTrue(logger is ConsoleDiagnosticLogger)
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
