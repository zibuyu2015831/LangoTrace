import Foundation
import GRDB

extension AppDatabase {
    /// `conversation_companions` / `companion_threads` / `companion_messages`
    /// (LM03-S1, v30): the Language Companion conversation store.
    ///
    /// Per-space (ADR-008 §4: one fixed companion identity + one thread per space).
    /// Persona is a closed-enum config row (no free text → injection-safe).
    ///
    /// **Persistence policy** (隔离再审 P0-3): conversation history is *recoverable
    /// user main data* — unlike `dictionary_lookup_events` (an unrecomputable
    /// behaviour signal that is excluded from backup/export), companion rows carry
    /// `localOnly` / `includedInSystemBackup` / `includedByDefault`, i.e. they ride
    /// the same backup + export lane as entries / learning content, and are simply
    /// not synced (sync engine does not exist yet).
    ///
    /// `companion_messages.input_modality` / `audio_artifact_id` are **forward
    /// seams** for the future voice-input slice (idea-03 §3.7) — v1 is always
    /// `text` / null. `audio_artifact_id` is an un-constrained nullable column for
    /// now; the FK to the media-artifact store is deferred to the voice slice that
    /// actually writes it (see the companion voice-input architecture note).
    // swiftlint:disable:next function_body_length
    static func createCompanionInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE conversation_companions (
          space_id TEXT PRIMARY KEY REFERENCES language_spaces(id) ON DELETE CASCADE,
          tone TEXT NOT NULL DEFAULT 'friendly',
          formality TEXT NOT NULL DEFAULT 'casual',
          correction TEXT NOT NULL DEFAULT 'ifNeeded',
          sync_policy TEXT NOT NULL DEFAULT 'localOnly',
          backup_policy TEXT NOT NULL DEFAULT 'includedInSystemBackup',
          export_policy TEXT NOT NULL DEFAULT 'includedByDefault',
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          CHECK (tone IN ('friendly', 'neutral', 'humorous')),
          CHECK (formality IN ('casual', 'formal')),
          CHECK (correction IN ('ifNeeded', 'warmRecast', 'none')),
          CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
          CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
          CHECK (export_policy IN ('excludedByDefault', 'includedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'))
        )
        """)
        try db.execute(sql: """
        CREATE TABLE companion_threads (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          source_entry_id TEXT REFERENCES entries(id) ON DELETE SET NULL,
          sync_policy TEXT NOT NULL DEFAULT 'localOnly',
          backup_policy TEXT NOT NULL DEFAULT 'includedInSystemBackup',
          export_policy TEXT NOT NULL DEFAULT 'includedByDefault',
          created_at REAL NOT NULL,
          CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
          CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
          CHECK (export_policy IN ('excludedByDefault', 'includedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_companion_threads_space ON companion_threads(space_id, created_at)
        """)
        try db.execute(sql: """
        CREATE TABLE companion_messages (
          id TEXT PRIMARY KEY,
          thread_id TEXT NOT NULL REFERENCES companion_threads(id) ON DELETE CASCADE,
          sequence INTEGER NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          detected_language TEXT,
          target_language_code TEXT NOT NULL,
          input_modality TEXT NOT NULL DEFAULT 'text',
          audio_artifact_id TEXT,
          sync_policy TEXT NOT NULL DEFAULT 'localOnly',
          backup_policy TEXT NOT NULL DEFAULT 'includedInSystemBackup',
          export_policy TEXT NOT NULL DEFAULT 'includedByDefault',
          created_at REAL NOT NULL,
          UNIQUE (thread_id, sequence),
          CHECK (role IN ('user', 'assistant')),
          CHECK (input_modality IN ('text', 'voice')),
          CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
          CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
          CHECK (export_policy IN ('excludedByDefault', 'includedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_companion_messages_thread_sequence
        ON companion_messages(thread_id, sequence)
        """)
    }
}
