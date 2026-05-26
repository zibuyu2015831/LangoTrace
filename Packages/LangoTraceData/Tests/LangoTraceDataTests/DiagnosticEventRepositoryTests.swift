import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Test("Diagnostic event repository records and loads recent allowlisted events")
func diagnosticEventRepositoryRecordsAndLoadsRecentAllowlistedEvents() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBDiagnosticEventRepository(
        database: database,
        retentionPolicy: DiagnosticRetentionPolicy(maximumEventCount: 10, maximumAge: 1000),
        clock: { Date(timeIntervalSince1970: 300) }
    )
    let operationID = DiagnosticOperationID(rawValue: "operation-1")

    try await repository.record(
        diagnosticEvent(
            id: "event-1",
            operationID: operationID,
            createdAt: Date(timeIntervalSince1970: 100)
        )
    )
    try await repository.record(
        diagnosticEvent(
            id: "event-2",
            operationID: operationID,
            createdAt: Date(timeIntervalSince1970: 200),
            outcome: .succeeded
        )
    )

    let recent = try await repository.recentEvents(limit: 10)
    #expect(recent.map(\.id) == ["event-2", "event-1"])
    #expect(recent.first?.name == .aiProviderSettingsSaveStarted)
    #expect(recent.first?.attributes.contains(.operationID(operationID)) == true)
    #expect(recent.first?.attributes.contains(.languageSupportFailureReason("sample_too_short")) == true)

    let storedRow = try database.databaseQueue.read { db in
        try Row.fetchOne(db, sql: "SELECT * FROM diagnostic_events WHERE id = ?", arguments: ["event-1"])
    }
    #expect(storedRow?["operation_id"] as String? == "operation-1")

    let columns = try await database.databaseQueue.read { db in
        try Row.fetchAll(db, sql: "PRAGMA table_info(diagnostic_events)")
            .map { $0["name"] as String }
    }
    #expect(!columns.contains("api_key"))
    #expect(!columns.contains("keychain_account"))
    #expect(!columns.contains("request_body"))
}

@Test("Diagnostic event repository prunes by count and cutoff")
func diagnosticEventRepositoryPrunesByCountAndCutoff() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBDiagnosticEventRepository(
        database: database,
        retentionPolicy: DiagnosticRetentionPolicy(maximumEventCount: 10, maximumAge: 1000),
        clock: { Date(timeIntervalSince1970: 500) }
    )

    for index in 1 ... 4 {
        try await repository.record(
            diagnosticEvent(
                id: "event-\(index)",
                operationID: DiagnosticOperationID(rawValue: "operation-\(index)"),
                createdAt: Date(timeIntervalSince1970: Double(index * 100))
            )
        )
    }

    try await repository.prune(
        keepingMostRecent: 2,
        newerThan: Date(timeIntervalSince1970: 250)
    )

    let recent = try await repository.recentEvents(limit: 10)
    #expect(recent.map(\.id) == ["event-4", "event-3"])
}

@Test("Diagnostic event repository applies retention policy after record")
func diagnosticEventRepositoryAppliesRetentionPolicyAfterRecord() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBDiagnosticEventRepository(
        database: database,
        retentionPolicy: DiagnosticRetentionPolicy(maximumEventCount: 2, maximumAge: 250),
        clock: { Date(timeIntervalSince1970: 500) }
    )

    for index in 1 ... 4 {
        try await repository.record(
            diagnosticEvent(
                id: "event-\(index)",
                operationID: DiagnosticOperationID(rawValue: "operation-\(index)"),
                createdAt: Date(timeIntervalSince1970: Double(index * 100))
            )
        )
    }

    let recent = try await repository.recentEvents(limit: 10)
    #expect(recent.map(\.id) == ["event-4", "event-3"])
}

private func diagnosticEvent(
    id: String,
    operationID: DiagnosticOperationID,
    createdAt: Date,
    outcome: DiagnosticOutcome = .started
) -> DiagnosticEvent {
    DiagnosticEvent(
        id: id,
        name: .aiProviderSettingsSaveStarted,
        domain: .aiProviderSettings,
        level: .info,
        outcome: outcome,
        attributes: [
            .operationID(operationID),
            .providerPresetID("openai"),
            .endpointPurpose(.textGeneration),
            .durationMilliseconds(12),
            .languageSupportFailureReason("sample_too_short"),
        ],
        createdAt: createdAt
    )
}
