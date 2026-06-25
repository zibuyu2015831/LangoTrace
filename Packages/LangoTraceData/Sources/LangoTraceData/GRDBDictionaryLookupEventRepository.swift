import Foundation
import GRDB
import LangoTraceCore

/// Persists and reads dictionary-lookup behaviour events (LM02-S4a). Writes the
/// explicit local-only / excluded-from-backup / excluded-from-export policy so the
/// row is honest about how it must be treated, independent of column defaults.
/// Reads / writes同源 through the injected `DatabaseWriter` (S1's seam).
public struct GRDBDictionaryLookupEventRepository: Sendable {
    private let writer: DatabaseWriter

    public init(writer: DatabaseWriter) {
        self.writer = writer
    }

    public func record(_ event: DictionaryLookupEvent) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO dictionary_lookup_events
                (id, language_space_id, looked_up_term, source_content_id, source_content_origin,
                 sync_policy, backup_policy, export_policy, occurred_at, soft_deleted_at)
                VALUES (?, ?, ?, ?, ?, 'localOnly', 'excludedFromSystemBackup', 'excludedByDefault', ?, ?)
                """,
                arguments: [
                    event.id,
                    event.languageSpaceID,
                    event.lookedUpTerm,
                    event.sourceContentID,
                    event.sourceContentOrigin.rawValue,
                    event.occurredAt.timeIntervalSince1970,
                    event.softDeletedAt?.timeIntervalSince1970,
                ]
            )
        }
    }

    /// Active events for a space, optionally after a high-water timestamp (the
    /// incremental window), oldest-first.
    public func events(spaceID: String, after: Date?) throws -> [DictionaryLookupEvent] {
        try writer.read { db in
            var sql = """
            SELECT id, language_space_id, looked_up_term, source_content_id,
                   source_content_origin, occurred_at, soft_deleted_at
            FROM dictionary_lookup_events
            WHERE language_space_id = ? AND soft_deleted_at IS NULL
            """
            var arguments: [DatabaseValueConvertible] = [spaceID]
            if let after {
                sql += " AND occurred_at > ?"
                arguments.append(after.timeIntervalSince1970)
            }
            sql += " ORDER BY occurred_at ASC, id ASC"
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.compactMap(Self.event(from:))
        }
    }

    public func softDelete(id: String, now: Date = Date()) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE dictionary_lookup_events SET soft_deleted_at = ? WHERE id = ? AND soft_deleted_at IS NULL",
                arguments: [now.timeIntervalSince1970, id]
            )
        }
    }

    private static func event(from row: Row) -> DictionaryLookupEvent? {
        guard let origin = SourceContentOrigin(rawValue: row["source_content_origin"]) else { return nil }
        let softDeletedAt: Date? = (row["soft_deleted_at"] as Double?).map { Date(timeIntervalSince1970: $0) }
        return DictionaryLookupEvent(
            id: row["id"],
            languageSpaceID: row["language_space_id"],
            lookedUpTerm: row["looked_up_term"],
            sourceContentID: row["source_content_id"],
            sourceContentOrigin: origin,
            occurredAt: Date(timeIntervalSince1970: row["occurred_at"]),
            softDeletedAt: softDeletedAt
        )
    }
}
