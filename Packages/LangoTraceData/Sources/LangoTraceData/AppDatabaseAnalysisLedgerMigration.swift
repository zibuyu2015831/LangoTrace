import Foundation
import GRDB

extension AppDatabase {
    /// `dictionary_lookup_events` (LM02-S4a, v28): captured "looked up a word /
    /// requested an explanation" behaviour events — an **unrecomputable user
    /// behaviour signal** for S4b band re-estimation (ADR-006 §4 / idea-02 §4).
    ///
    /// Records only the user's behaviour (term + when + which content), never the
    /// AI's returned explanation or any AI-assigned difficulty (§4 red line).
    ///
    /// **Explicit persistence policy** (a new category, NOT borrowed from a pseudo
    /// precedent): `localOnly` / `excludedFromSystemBackup` / `excludedByDefault`
    /// — a single lookup is low value, and band can degrade gracefully from the
    /// remaining signals. `source_content_origin` is a **forward schema seam**:
    /// v1 is always `userAuthored` (reading documents are always user-imported);
    /// `aiGenerated` awaits a future "learning material as reading source"
    /// capability (the filtering decision belongs to S4b).
    static func createDictionaryLookupEventInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE dictionary_lookup_events (
          id TEXT PRIMARY KEY,
          language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          looked_up_term TEXT NOT NULL,
          source_content_id TEXT,
          source_content_origin TEXT NOT NULL DEFAULT 'userAuthored',
          sync_policy TEXT NOT NULL DEFAULT 'localOnly',
          backup_policy TEXT NOT NULL DEFAULT 'excludedFromSystemBackup',
          export_policy TEXT NOT NULL DEFAULT 'excludedByDefault',
          occurred_at REAL NOT NULL,
          soft_deleted_at REAL,
          CHECK (source_content_origin IN ('userAuthored', 'aiGenerated')),
          CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
          CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
          CHECK (export_policy IN ('excludedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_dictionary_lookup_events_space_time
        ON dictionary_lookup_events(language_space_id, soft_deleted_at, occurred_at)
        """)
    }

    /// `analysis_ledger` (LM02-S4a, v29): ADR-006 §9's first analysis ledger +
    /// high-water cursor. Keyed by `(source_type, source_id, analyzer,
    /// analyzer_version)`; the cursor is a high-water mark for **incremental window
    /// aggregation** (NOT a per-item flag). Bumping `analyzer_version` creates a
    /// fresh row (cursor 0) → a full re-run. The ledger references its sources by
    /// `(source_type, source_id)` rather than adding columns to the source tables;
    /// the lookup-event stream is one such source (`source_type='dictionaryLookup'`).
    static func createAnalysisLedgerInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE analysis_ledger (
          id TEXT PRIMARY KEY,
          source_type TEXT NOT NULL,
          source_id TEXT NOT NULL,
          analyzer TEXT NOT NULL,
          analyzer_version INTEGER NOT NULL,
          cursor_position REAL NOT NULL DEFAULT 0,
          updated_at REAL NOT NULL,
          CHECK (analyzer_version >= 0),
          UNIQUE (source_type, source_id, analyzer, analyzer_version)
        )
        """)
    }
}
