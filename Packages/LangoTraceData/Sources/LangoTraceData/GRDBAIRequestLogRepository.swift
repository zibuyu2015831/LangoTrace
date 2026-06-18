import Foundation
import GRDB
import LangoTraceCore

/// GRDB-backed `ai_request_logs` store (系列 E6).
///
/// `append` inserts a row and, in the same write transaction, prunes the
/// capability's history to `maximumEntriesPerCapability` so the log stays
/// bounded. Reads are newest-first. Rows are non-sensitive by construction —
/// the table has no content column.
public struct GRDBAIRequestLogRepository: AIRequestLogRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let maximumEntriesPerCapability: Int

    public init(database: AppDatabase, maximumEntriesPerCapability: Int = 200) {
        databaseQueue = database.databaseQueue
        self.maximumEntriesPerCapability = max(0, maximumEntriesPerCapability)
    }

    public func append(_ entry: AIRequestLogEntry) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO ai_request_logs (
                    id, operation_id, capability, provider_preset_id, endpoint_purpose,
                    adapter_kind, model_name, prompt_id, prompt_version,
                    input_length_bucket, status, failure_bucket, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    entry.id,
                    entry.operationID.rawValue,
                    entry.capability.rawValue,
                    entry.providerPresetID,
                    entry.endpointPurpose?.rawValue,
                    entry.adapterKind?.rawValue,
                    entry.modelName,
                    entry.promptID,
                    entry.promptVersion,
                    entry.inputLengthBucket.rawValue,
                    entry.status.rawValue,
                    entry.failureBucket?.rawValue,
                    entry.createdAt.timeIntervalSince1970,
                ]
            )
            try prune(db, capability: entry.capability)
        }
    }

    public func recent(capability: AIRequestCapability, limit: Int) async throws -> [AIRequestLogEntry] {
        guard limit > 0 else {
            return []
        }
        return try await databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM ai_request_logs
                WHERE capability = ?
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """,
                arguments: [capability.rawValue, limit]
            ).compactMap(Self.entry(from:))
        }
    }

    public func recentAll(limit: Int) async throws -> [AIRequestLogEntry] {
        guard limit > 0 else {
            return []
        }
        return try await databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM ai_request_logs
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """,
                arguments: [limit]
            ).compactMap(Self.entry(from:))
        }
    }
}

private extension GRDBAIRequestLogRepository {
    func prune(_ db: Database, capability: AIRequestCapability) throws {
        guard maximumEntriesPerCapability > 0 else {
            try db.execute(
                sql: "DELETE FROM ai_request_logs WHERE capability = ?",
                arguments: [capability.rawValue]
            )
            return
        }
        // Keep only the newest N rows for this capability; window function is
        // available in the GRDB-bundled SQLite (>= 3.25).
        try db.execute(
            sql: """
            DELETE FROM ai_request_logs
            WHERE id IN (
                SELECT id FROM (
                    SELECT id, ROW_NUMBER() OVER (
                        ORDER BY created_at DESC, id DESC
                    ) AS row_index
                    FROM ai_request_logs
                    WHERE capability = ?
                )
                WHERE row_index > ?
            )
            """,
            arguments: [capability.rawValue, maximumEntriesPerCapability]
        )
    }

    static func entry(from row: Row) -> AIRequestLogEntry? {
        guard let capability = AIRequestCapability(rawValue: row["capability"] as String),
              let status = AIRequestLogStatus(rawValue: row["status"] as String),
              let lengthBucket = AIRequestLengthBucket(rawValue: row["input_length_bucket"] as String)
        else {
            return nil
        }
        return AIRequestLogEntry(
            id: row["id"],
            operationID: DiagnosticOperationID(rawValue: row["operation_id"]),
            capability: capability,
            providerPresetID: row["provider_preset_id"],
            endpointPurpose: (row["endpoint_purpose"] as String?).flatMap(AIProviderEndpointPurpose.init(rawValue:)),
            adapterKind: (row["adapter_kind"] as String?).flatMap(AIProviderAdapterKind.init(rawValue:)),
            modelName: row["model_name"],
            promptID: row["prompt_id"],
            promptVersion: row["prompt_version"],
            inputLengthBucket: lengthBucket,
            status: status,
            failureBucket: (row["failure_bucket"] as String?).flatMap(AIRequestLogFailureBucket.init(rawValue:)),
            createdAt: Date(timeIntervalSince1970: row["created_at"])
        )
    }
}
