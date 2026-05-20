import Foundation
import LangoTraceCore
import Testing

@Test("Diagnostic event uses typed names and non sensitive operation id")
func diagnosticEventUsesTypedNamesAndOperationID() {
    let operationID = DiagnosticOperationID(rawValue: "operation-123")
    let event = DiagnosticEvent(
        id: "event-1",
        name: .aiProviderSettingsSaveStarted,
        domain: .aiProviderSettings,
        level: .info,
        outcome: .started,
        attributes: [
            .operationID(operationID),
            .providerPresetID("openai"),
            .enabledEndpointCount(2),
        ],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(event.name.rawValue == "ai_provider_settings.save_started")
    #expect(event.attributes.contains(.operationID(operationID)))
    #expect(event.attributes.contains(.providerPresetID("openai")))
}

@Test("Diagnostic attribute keys are stable and allowlisted")
func diagnosticAttributeKeysAreStableAndAllowlisted() {
    #expect(DiagnosticAttribute.operationID(DiagnosticOperationID(rawValue: "op")).key == "operation_id")
    #expect(DiagnosticAttribute.endpointPurpose(.textGeneration).key == "endpoint_purpose")
    #expect(DiagnosticAttribute.durationMilliseconds(42).key == "duration_ms")
    #expect(DiagnosticAttribute.failurePhase("database_write").key == "failure_phase")
}

@Test("AI provider save failure preserves primary database phase when cleanup also fails")
func aiProviderSaveFailurePreservesPrimaryPhaseWhenCleanupAlsoFails() {
    let failure = AIProviderConfigurationSaveFailure(
        operationID: DiagnosticOperationID(rawValue: "operation-456"),
        phase: .databaseWrite,
        category: .databaseWriteFailed,
        cleanupFailure: .credentialCleanupFailed
    )

    #expect(failure.operationID?.rawValue == "operation-456")
    #expect(failure.phase == .databaseWrite)
    #expect(failure.category == .databaseWriteFailed)
    #expect(failure.cleanupFailure == .credentialCleanupFailed)
}

@Test("Repository diagnostic logger swallows repository failures")
func repositoryDiagnosticLoggerSwallowsRepositoryFailures() async {
    let logger = RepositoryDiagnosticLogger(repository: FailingDiagnosticEventRepository())

    await logger.record(sampleDiagnosticEvent(id: "event-failing-repository"))
}

@Test("Composite diagnostic logger records to all loggers")
func compositeDiagnosticLoggerRecordsToAllLoggers() async {
    let first = InMemoryDiagnosticLogger()
    let second = InMemoryDiagnosticLogger()
    let logger = CompositeDiagnosticLogger(loggers: [first, second])

    await logger.record(sampleDiagnosticEvent(id: "event-composite"))

    #expect(await first.events().map(\.id) == ["event-composite"])
    #expect(await second.events().map(\.id) == ["event-composite"])
}

private struct FailingDiagnosticEventRepository: DiagnosticEventRepository {
    func record(_: DiagnosticEvent) async throws {
        throw TestDiagnosticRepositoryError.recordFailed
    }

    func recentEvents(limit _: Int) async throws -> [DiagnosticEvent] {
        []
    }

    func prune(keepingMostRecent _: Int, newerThan _: Date) async throws {}
}

private enum TestDiagnosticRepositoryError: Error {
    case recordFailed
}

private func sampleDiagnosticEvent(id: String) -> DiagnosticEvent {
    DiagnosticEvent(
        id: id,
        name: .aiProviderSettingsSaveStarted,
        domain: .aiProviderSettings,
        level: .info,
        outcome: .started,
        attributes: [.operationID(DiagnosticOperationID(rawValue: "operation"))],
        createdAt: Date(timeIntervalSince1970: 100)
    )
}
