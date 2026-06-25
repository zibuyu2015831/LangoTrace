import Foundation
import GRDB

extension AppDatabase {
    /// `learner_memory_facts` (LM02 Slice 1): the Memory layer of the system-level
    /// Learner Model — life facts / preferences / goals / relationships the user
    /// **explicitly** asked the App to remember (ADR-006 §2 显式记住先行).
    ///
    /// **仓库首张系统级表，刻意无 space PK / 无 space FK**（ADR-006 §3）：a Memory
    /// fact is global across language spaces — visible in any space, never
    /// cascade-deleted when a space is removed (ADR-006 §7.1). `source_entry_id` is
    /// a weak `ON DELETE SET NULL` link (a fact outlives its source entry, same
    /// precedent as `memory_items.entry_id`).
    ///
    /// Storage policy columns reuse the Core `MediaArtifact*Policy` vocabulary but
    /// take values **opposite** to TTS-derived assets: Memory is 准原始 (ADR-006
    /// §8) → `localOnly` / `includedInSystemBackup` / `includedInRecoverableBackup`.
    ///
    /// Delete semantics (§12.3): single-row delete sets `soft_deleted_at`
    /// (recoverable); the system-level "重置 App 对我的了解" physically deletes all
    /// rows (`resetAll()`), so "重置" is name-true and the most-concentrated PII
    /// leaves no plaintext软删 residue. The v2 auto-extraction tombstone is not
    /// built here (v1 has no extraction to re-mine).
    static func createLearnerMemoryFactsInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE learner_memory_facts (
          id TEXT PRIMARY KEY,
          kind TEXT NOT NULL,
          text TEXT NOT NULL,
          salience INTEGER NOT NULL DEFAULT 0,
          visibility TEXT NOT NULL DEFAULT 'global',
          source TEXT NOT NULL DEFAULT 'manualMemory',
          source_entry_id TEXT REFERENCES entries(id) ON DELETE SET NULL,
          sync_policy TEXT NOT NULL DEFAULT 'localOnly',
          backup_policy TEXT NOT NULL DEFAULT 'includedInSystemBackup',
          export_policy TEXT NOT NULL DEFAULT 'includedInRecoverableBackup',
          created_at REAL NOT NULL,
          soft_deleted_at REAL,
          CHECK (kind IN ('lifeFact', 'preference', 'goal', 'relationship')),
          CHECK (visibility IN ('global', 'companionOnly')),
          CHECK (source IN ('manualMemory', 'memoryItem')),
          CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
          CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
          CHECK (export_policy IN ('excludedByDefault', 'includedInUserExport', 'includedInRecoverableBackup')),
          CHECK (salience >= 0)
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_learner_memory_facts_active_created
        ON learner_memory_facts(soft_deleted_at, created_at)
        """)
    }
}
