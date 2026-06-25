import Foundation
import GRDB

/// System-level (cross-language-space) read/write repository for the Memory layer
/// of the Learner Model (ADR-006 §3). Reads and writes are同源 through the
/// injected `DatabaseWriter` (the App's serialised queue).
///
/// All operations are global by construction — there is no space argument, because
/// `learner_memory_facts` carries no space partition (ADR-006 §3 / §7.1).
public struct GRDBLearnerMemoryRepository: Sendable {
    private let writer: DatabaseWriter

    public init(writer: DatabaseWriter) {
        self.writer = writer
    }

    /// Persists an explicitly-saved Memory fact. Storage policies are written as
    /// the准原始 literals (local-only / included-in-backup / included-in-recoverable
    /// -backup) so the row is honest about how it must be preserved, independent of
    /// the column defaults.
    public func save(_ fact: MemoryFact) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO learner_memory_facts
                (id, kind, text, salience, visibility, source, source_entry_id,
                 sync_policy, backup_policy, export_policy, created_at, soft_deleted_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'localOnly', 'includedInSystemBackup', 'includedInRecoverableBackup', ?, ?)
                """,
                arguments: [
                    fact.id,
                    fact.kind.rawValue,
                    fact.text,
                    fact.salience,
                    fact.visibility.rawValue,
                    fact.source.rawValue,
                    fact.sourceEntryID,
                    fact.createdAt.timeIntervalSince1970,
                    fact.softDeletedAt?.timeIntervalSince1970,
                ]
            )
        }
    }

    /// Lists facts system-wide, oldest-first. Excludes soft-deleted rows unless
    /// `includeDeleted` is set (for the "查看已删除 / 撤销" governance affordance).
    public func list(includeDeleted: Bool = false) throws -> [MemoryFact] {
        try writer.read { db in
            let sql = """
            SELECT id, kind, text, salience, visibility, source, source_entry_id, created_at, soft_deleted_at
            FROM learner_memory_facts
            \(includeDeleted ? "" : "WHERE soft_deleted_at IS NULL")
            ORDER BY created_at ASC, id ASC
            """
            let rows = try Row.fetchAll(db, sql: sql)
            return rows.compactMap(Self.fact(from:))
        }
    }

    /// Single-row delete = recoverable soft-delete (§12.3).
    public func softDelete(id: String, now: Date = Date()) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE learner_memory_facts SET soft_deleted_at = ? WHERE id = ? AND soft_deleted_at IS NULL",
                arguments: [now.timeIntervalSince1970, id]
            )
        }
    }

    /// System-level "重置 App 对我的了解" = physical DELETE of all facts (§12.3), so
    /// the most-concentrated PII leaves no plaintext软删 residue.
    public func resetAll() throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM learner_memory_facts")
        }
    }

    private static func fact(from row: Row) -> MemoryFact? {
        guard let kind = MemoryFactKind(rawValue: row["kind"]),
              let visibility = MemoryFactVisibility(rawValue: row["visibility"]),
              let source = LearnerSourceType(rawValue: row["source"])
        else {
            return nil
        }
        let softDeletedAt: Date? = (row["soft_deleted_at"] as Double?).map { Date(timeIntervalSince1970: $0) }
        return MemoryFact(
            id: row["id"],
            kind: kind,
            text: row["text"],
            salience: row["salience"],
            visibility: visibility,
            source: source,
            sourceEntryID: row["source_entry_id"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            softDeletedAt: softDeletedAt
        )
    }
}
