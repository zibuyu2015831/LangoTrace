import Foundation
import GRDB
import LangoTraceCore

/// One row to (re)index in the local FTS `search_index` table (系列 E9).
public struct SearchIndexRecord: Equatable, Sendable {
    public var kind: SearchObjectKind
    public var objectID: String
    public var spaceID: String
    public var title: String
    public var body: String
    public var readingBlockIndex: Int?

    public init(
        kind: SearchObjectKind,
        objectID: String,
        spaceID: String,
        title: String,
        body: String,
        readingBlockIndex: Int? = nil
    ) {
        self.kind = kind
        self.objectID = objectID
        self.spaceID = spaceID
        self.title = title
        self.body = body
        self.readingBlockIndex = readingBlockIndex
    }
}

/// Application-layer maintenance of the local FTS index (系列 E9, 决策 12.1).
///
/// All writes go through GRDB repositories, so the index is maintained in Swift
/// (testable normalization, no SQL triggers). These operate on a `Database` so
/// callers compose them into their own write transaction — index and main data
/// stay consistent (same transaction). The FTS index is rebuildable derived
/// data: `removeAll` + a repopulate from main data fully repairs it.
public enum SearchIndexWriter {
    /// Replaces all rows for one object (kind + id), then inserts the given rows.
    /// Reading documents may map to multiple rows (one per block); pass them all.
    public static func upsert(objectKind: SearchObjectKind, objectID: String, rows: [SearchIndexRecord], in db: Database) throws {
        try remove(objectKind: objectKind, objectID: objectID, in: db)
        for row in rows {
            try insert(row, in: db)
        }
    }

    public static func upsert(_ record: SearchIndexRecord, in db: Database) throws {
        try upsert(objectKind: record.kind, objectID: record.objectID, rows: [record], in: db)
    }

    public static func remove(objectKind: SearchObjectKind, objectID: String, in db: Database) throws {
        try db.execute(
            sql: "DELETE FROM search_index WHERE object_kind = ? AND object_id = ?",
            arguments: [objectKind.rawValue, objectID]
        )
    }

    /// Removes every row for a kind within a space (used before a kind rebuild).
    public static func removeAll(objectKind: SearchObjectKind, spaceID: String, in db: Database) throws {
        try db.execute(
            sql: "DELETE FROM search_index WHERE object_kind = ? AND space_id = ?",
            arguments: [objectKind.rawValue, spaceID]
        )
    }

    /// Removes every row for a space (full rebuild).
    public static func removeAll(spaceID: String, in db: Database) throws {
        try db.execute(sql: "DELETE FROM search_index WHERE space_id = ?", arguments: [spaceID])
    }

    private static func insert(_ record: SearchIndexRecord, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO search_index (object_kind, object_id, space_id, reading_block_index, title, body)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                record.kind.rawValue,
                record.objectID,
                record.spaceID,
                record.readingBlockIndex,
                record.title,
                record.body,
            ]
        )
    }
}
