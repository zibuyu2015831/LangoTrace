import Foundation
import GRDB

extension AppDatabase {
    /// `memory_items` (E7): deposited memory items — user main data owned by a
    /// language space (ADR-004), snapshotted from a source candidate so the item
    /// survives source reanalysis (which CASCADE-deletes `memory_candidates`).
    /// `entry_id` is `ON DELETE SET NULL` so a deposit outlives its source entry.
    /// The review columns are E7's contract for E8's review queue (no further
    /// migration). The partial unique index makes candidate deposits idempotent.
    static func createMemoryItemInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE memory_items (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          entry_id TEXT REFERENCES entries(id) ON DELETE SET NULL,
          source_kind TEXT NOT NULL,
          source_candidate_id TEXT,
          kind TEXT NOT NULL,
          text TEXT NOT NULL,
          note TEXT NOT NULL,
          example_target TEXT NOT NULL,
          example_native TEXT NOT NULL,
          difficulty TEXT NOT NULL,
          review_state TEXT NOT NULL DEFAULT 'new',
          review_rung INTEGER NOT NULL DEFAULT 0,
          review_due_at REAL,
          last_reviewed_at REAL,
          review_count INTEGER NOT NULL DEFAULT 0,
          mastered_at REAL,
          created_at REAL NOT NULL,
          soft_deleted_at REAL,
          CHECK (source_kind IN ('candidate')),
          CHECK (kind IN ('wordPhrase', 'sentence')),
          CHECK (difficulty IN ('easy', 'medium', 'hard')),
          CHECK (review_state IN ('new', 'scheduled', 'mastered')),
          CHECK (review_rung >= 0),
          CHECK (review_count >= 0)
        )
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_memory_items_candidate_dedupe
        ON memory_items(space_id, source_candidate_id)
        WHERE source_candidate_id IS NOT NULL
        """)
        try db.execute(sql: """
        CREATE INDEX idx_memory_items_space_state
        ON memory_items(space_id, soft_deleted_at, review_state)
        """)
        try db.execute(sql: """
        CREATE INDEX idx_memory_items_entry
        ON memory_items(entry_id, soft_deleted_at)
        """)
    }
}
