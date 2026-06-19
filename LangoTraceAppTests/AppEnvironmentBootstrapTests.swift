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

    func testAIProviderCredentialResolverMapsMissingKeychainEntryToResolveFailure() async throws {
        let environment = AppEnvironment.bootstrap(databaseURL: temporaryDatabaseURL)
        let credential = AIProviderCredentialMetadata(
            id: "test-credential-\(UUID().uuidString)",
            profileID: "test-profile-id",
            providerPresetID: "openai",
            kind: .apiKey,
            label: "Test API Key",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        do {
            _ = try await environment.aiProviderSettingsActions.resolveCredentialSecret(credential)
            XCTFail("Expected AIProviderCredentialResolveFailure to be thrown for missing Keychain entry")
        } catch let failure as AIProviderCredentialResolveFailure {
            XCTAssertEqual(failure.category, .missingCredential)
        }
    }
}
