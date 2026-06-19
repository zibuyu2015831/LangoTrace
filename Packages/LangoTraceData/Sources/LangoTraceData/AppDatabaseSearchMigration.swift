import Foundation
import GRDB

extension AppDatabase {
    /// `search_index` (系列 E9): local FTS5 full-text index — rebuildable derived
    /// data, never synced / never a required export (spec 007 §4, 核心决策 12).
    /// `tokenize='trigram'` gives substring matching for both CJK and Latin text
    /// (≥3-char queries; shorter queries fall back to LIKE in the repository).
    /// `object_kind` / `object_id` / `space_id` are non-indexed metadata used for
    /// grouping, navigation, and space scoping. `search_index_meta` pins the
    /// index schema version so a mismatch can trigger a full rebuild.
    static func createLocalSearchIndexInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE VIRTUAL TABLE search_index USING fts5(
          object_kind UNINDEXED,
          object_id UNINDEXED,
          space_id UNINDEXED,
          reading_block_index UNINDEXED,
          title,
          body,
          tokenize='trigram'
        )
        """)
        try db.execute(sql: """
        CREATE TABLE search_index_meta (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          index_schema_version INTEGER NOT NULL
        )
        """)
        try db.execute(sql: "INSERT INTO search_index_meta (id, index_schema_version) VALUES (1, 1)")
    }
}
