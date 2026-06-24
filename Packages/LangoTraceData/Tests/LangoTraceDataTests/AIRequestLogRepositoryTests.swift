import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// Covers the `ai_request_logs` schema + repository (系列 E6): migration shape,
/// content-free columns, append + per-capability prune, capability-scoped and
/// global reads, empty-table reads, and the failed-row CHECK invariant.
@Suite("AI request log repository")
struct AIRequestLogRepositoryTests {
    private func makeEntry(
        id: String,
        capability: AIRequestCapability = .learningMaterialGeneration,
        status: AIRequestLogStatus = .success,
        failureBucket: AIRequestLogFailureBucket? = nil,
        createdAt: Date
    ) -> AIRequestLogEntry {
        AIRequestLogEntry(
            id: id,
            operationID: DiagnosticOperationID(rawValue: "op-\(id)"),
            capability: capability,
            providerPresetID: "openai",
            endpointPurpose: .textGeneration,
            adapterKind: .openAICompatibleChat,
            modelName: "model-x",
            promptID: "builtin.learning_material",
            promptVersion: "1",
            inputLengthBucket: .medium,
            status: status,
            failureBucket: failureBucket,
            createdAt: createdAt
        )
    }

    @Test("migration creates a content-free ai_request_logs table")
    func migrationCreatesContentFreeTable() async throws {
        let database = try AppDatabase.inMemory()
        let columns = try await database.databaseQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(ai_request_logs)").map { $0["name"] as String }
        }
        #expect(columns.contains("capability"))
        #expect(columns.contains("status"))
        #expect(columns.contains("failure_bucket"))
        // Structurally content-free: no user-text / prompt-body / credential columns.
        #expect(!columns.contains("content"))
        #expect(!columns.contains("prompt_body"))
        #expect(!columns.contains("request_body"))
        #expect(!columns.contains("api_key"))
        #expect(!columns.contains("selected_text"))
    }

    @Test("append then read round-trips the non-sensitive fields")
    func appendRoundTrips() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIRequestLogRepository(database: database)
        let entry = makeEntry(id: "1", createdAt: Date(timeIntervalSince1970: 100))

        try await repository.append(entry)

        let rows = try await repository.recentAll(limit: 10)
        #expect(rows.count == 1)
        #expect(rows.first == entry)
    }

    @Test("recent is scoped to a single capability, newest first")
    func recentIsCapabilityScoped() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIRequestLogRepository(database: database)
        try await repository.append(makeEntry(id: "gen-1", capability: .learningMaterialGeneration, createdAt: Date(timeIntervalSince1970: 1)))
        try await repository.append(makeEntry(id: "gen-2", capability: .learningMaterialGeneration, createdAt: Date(timeIntervalSince1970: 3)))
        try await repository.append(makeEntry(id: "read-1", capability: .readingSelectionExplanation, createdAt: Date(timeIntervalSince1970: 2)))

        let generation = try await repository.recent(capability: .learningMaterialGeneration, limit: 10)
        #expect(generation.map(\.id) == ["gen-2", "gen-1"])
        let reading = try await repository.recent(capability: .readingSelectionExplanation, limit: 10)
        #expect(reading.map(\.id) == ["read-1"])
    }

    @Test("append prunes the capability history beyond the retention cap")
    func appendPrunesBeyondCap() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIRequestLogRepository(database: database, maximumEntriesPerCapability: 3)
        for index in 1 ... 5 {
            try await repository.append(makeEntry(id: "g-\(index)", capability: .learningMaterialGeneration, createdAt: Date(timeIntervalSince1970: Double(index))))
        }
        // A different capability is untouched by the generation prune.
        try await repository.append(makeEntry(id: "r-1", capability: .readingSelectionExplanation, createdAt: Date(timeIntervalSince1970: 99)))

        let generation = try await repository.recent(capability: .learningMaterialGeneration, limit: 10)
        #expect(generation.map(\.id) == ["g-5", "g-4", "g-3"])
        let reading = try await repository.recent(capability: .readingSelectionExplanation, limit: 10)
        #expect(reading.map(\.id) == ["r-1"])
    }

    @Test("reads on an empty table return an empty list, not an error")
    func emptyTableReturnsEmpty() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIRequestLogRepository(database: database)
        let all = try await repository.recentAll(limit: 10)
        let scoped = try await repository.recent(capability: .learningMaterialGeneration, limit: 10)
        #expect(all.isEmpty)
        #expect(scoped.isEmpty)
    }

    @Test("photo-writing assist rows round-trip the new capability")
    func photoWritingAssistRoundTrips() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIRequestLogRepository(database: database)
        let entry = makeEntry(
            id: "pw-1",
            capability: .photoWritingAssist,
            status: .failed,
            failureBucket: .unsupported,
            createdAt: Date(timeIntervalSince1970: 7)
        )
        try await repository.append(entry)

        let scoped = try await repository.recent(capability: .photoWritingAssist, limit: 10)
        #expect(scoped.count == 1)
        #expect(scoped.first?.capability == .photoWritingAssist)
        #expect(scoped.first == entry)
    }

    @Test("a failed row persists its failure bucket")
    func failedRowPersistsBucket() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIRequestLogRepository(database: database)
        let entry = makeEntry(id: "f-1", status: .failed, failureBucket: .network, createdAt: Date(timeIntervalSince1970: 5))
        try await repository.append(entry)
        let rows = try await repository.recentAll(limit: 10)
        #expect(rows.first?.status == .failed)
        #expect(rows.first?.failureBucket == .network)
    }
}
