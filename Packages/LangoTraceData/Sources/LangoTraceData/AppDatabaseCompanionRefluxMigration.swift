import Foundation
import GRDB

extension AppDatabase {
    /// `companion_memory_candidates` (LM03-S2a, v31): vocabulary / expression
    /// candidates extracted from a Language Companion conversation (idea-03 §3.8
    /// chat-reflux inbound half).
    ///
    /// **Why a separate table, not `memory_candidates`** (plan §D1): the latter's
    /// `entry_id` / `material_id` are `NOT NULL REFERENCES … ON DELETE CASCADE`, so
    /// it physically cannot hold a chat-sourced row that has neither entry nor
    /// material. Making them nullable would require a 12-step SQLite table rebuild on
    /// the learning-content main path; S2a is the low-risk slice and isolates the
    /// risk instead. The reuse is honoured at the *pipeline* level — same `kind` /
    /// `status` vocabulary, same analysis→insert shape — not by forcing one physical
    /// table. A future deposit pipeline (plan 10/11) unifies the review surface.
    ///
    /// **Persistence policy** (plan §D4): like `memory_candidates`, a candidate is
    /// *recomputable derived data* (a review staging row), so it carries **no**
    /// sync / backup / export policy columns — it is local-only and rebuilt by
    /// re-extracting. Main-data status is reached only when the user promotes a
    /// candidate to a memory item (`learner_memory_facts`, plan 10/11). Deleting the
    /// thread cascade-deletes its candidates; deleting the single source message
    /// nulls `message_id` (weak link) but keeps the candidate.
    static func createCompanionRefluxInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE companion_memory_candidates (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          thread_id TEXT NOT NULL REFERENCES companion_threads(id) ON DELETE CASCADE,
          message_id TEXT REFERENCES companion_messages(id) ON DELETE SET NULL,
          kind TEXT NOT NULL,
          text TEXT NOT NULL,
          explanation_native TEXT NOT NULL,
          example_target TEXT NOT NULL,
          example_native TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'candidate',
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          CHECK (kind IN ('word', 'phrase', 'sentencePattern', 'grammarPoint', 'errorPattern')),
          CHECK (status IN ('candidate'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_companion_memory_candidates_space_created
        ON companion_memory_candidates(space_id, created_at DESC)
        """)
    }
}
