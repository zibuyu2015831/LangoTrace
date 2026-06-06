import GRDB

extension AppDatabase {
    static func createReadingDomainInfrastructure(_ db: Database) throws {
        try addReadingTTSSourceColumnsIfNeeded(db)
        try createReadingDocuments(db)
        try createReadingOrganizationTables(db)
        try createReadingStructureTables(db)
        try createReadingProgressTables(db)
        try createReadingImportTables(db)
        try createReadingOperationTables(db)
    }

    static func upgradeReadingLifecycleEventsForDocumentUpdatesIfNeeded(_ db: Database) throws {
        guard try db.tableExists("reading_document_lifecycle_events") else {
            return
        }
        let definition = try String.fetchOne(
            db,
            sql: """
            SELECT sql
            FROM sqlite_master
            WHERE type = 'table' AND name = 'reading_document_lifecycle_events'
            """
        ) ?? ""
        guard !definition.contains("'updated'") else {
            return
        }

        try db.execute(sql: "ALTER TABLE reading_document_lifecycle_events RENAME TO reading_document_lifecycle_events_legacy")
        try createReadingDocumentLifecycleEvents(db)
        try db.execute(
            sql: """
            INSERT INTO reading_document_lifecycle_events (
                id, document_id, space_id, event_type, actor, summary_json, created_at
            )
            SELECT
                id, document_id, space_id, event_type, actor, summary_json, created_at
            FROM reading_document_lifecycle_events_legacy
            """
        )
        try db.execute(sql: "DROP TABLE reading_document_lifecycle_events_legacy")
    }

    private static func createReadingDocuments(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE reading_documents (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          title TEXT NOT NULL,
          source_kind TEXT NOT NULL,
          source_format TEXT NOT NULL,
          adapter_id TEXT NOT NULL,
          adapter_version INTEGER NOT NULL,
          body_storage_kind TEXT NOT NULL,
          body TEXT,
          managed_body_artifact_id TEXT REFERENCES media_artifacts(id) ON DELETE SET NULL,
          source_metadata_json TEXT,
          original_filename TEXT,
          original_file_extension TEXT,
          original_mime_type TEXT,
          original_uti TEXT,
          original_byte_size INTEGER,
          body_hash TEXT NOT NULL,
          content_revision INTEGER NOT NULL,
          structure_version INTEGER NOT NULL,
          target_language_code TEXT NOT NULL,
          import_status TEXT NOT NULL,
          library_status TEXT NOT NULL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          imported_at REAL,
          deleted_at REAL,
          restored_at REAL,
          last_opened_at REAL,
          CHECK (adapter_version > 0),
          CHECK (content_revision > 0),
          CHECK (structure_version > 0),
          CHECK (original_byte_size IS NULL OR original_byte_size >= 0),
          CHECK (source_format IN (
            'pastedText', 'plainText', 'markdown', 'epub', 'pdf', 'htmlClip', 'webArticle'
          )),
          CHECK (body_storage_kind IN ('inline', 'managedFile')),
          CHECK (import_status IN ('pending', 'ready', 'failed')),
          CHECK (library_status IN ('active', 'softDeleted'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_reading_documents_space_library_updated
        ON reading_documents(space_id, library_status, updated_at)
        """)
    }

    private static func createReadingOrganizationTables(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE reading_collections (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          title TEXT NOT NULL,
          title_normalized TEXT NOT NULL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          deleted_at REAL,
          UNIQUE(space_id, title_normalized)
        )
        """)
        try db.execute(sql: """
        CREATE TABLE reading_document_collections (
          document_id TEXT NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          collection_id TEXT NOT NULL REFERENCES reading_collections(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          assigned_at REAL NOT NULL,
          PRIMARY KEY(document_id, collection_id)
        )
        """)
        try db.execute(sql: """
        CREATE TABLE reading_tags (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          name TEXT NOT NULL,
          name_normalized TEXT NOT NULL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          deleted_at REAL,
          UNIQUE(space_id, name_normalized)
        )
        """)
        try db.execute(sql: """
        CREATE TABLE reading_document_tags (
          document_id TEXT NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          tag_id TEXT NOT NULL REFERENCES reading_tags(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          tagged_at REAL NOT NULL,
          PRIMARY KEY(document_id, tag_id)
        )
        """)
    }

    private static func createReadingStructureTables(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE reading_structure_blocks (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          structure_version INTEGER NOT NULL,
          block_index INTEGER NOT NULL,
          block_kind TEXT NOT NULL,
          source_start_offset INTEGER NOT NULL,
          source_length INTEGER NOT NULL,
          plain_text TEXT NOT NULL,
          metadata_json TEXT,
          CHECK (block_index >= 0),
          CHECK (source_start_offset >= 0),
          CHECK (source_length >= 0),
          UNIQUE(document_id, structure_version, block_index)
        )
        """)
        try db.execute(sql: """
        CREATE TABLE reading_sentences (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          block_id TEXT REFERENCES reading_structure_blocks(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          structure_version INTEGER NOT NULL,
          sentence_index INTEGER NOT NULL,
          character_offset INTEGER NOT NULL,
          character_length INTEGER NOT NULL,
          text_hash TEXT NOT NULL,
          CHECK (sentence_index >= 0),
          CHECK (character_offset >= 0),
          CHECK (character_length > 0),
          UNIQUE(document_id, structure_version, sentence_index)
        )
        """)
    }

    private static func createReadingProgressTables(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE reading_positions (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          device_scope_id TEXT NOT NULL,
          block_id TEXT,
          character_offset INTEGER NOT NULL,
          progress REAL,
          updated_at REAL NOT NULL,
          CHECK (character_offset >= 0),
          CHECK (progress IS NULL OR (progress >= 0 AND progress <= 1)),
          UNIQUE(document_id, device_scope_id)
        )
        """)
        try db.execute(sql: """
        CREATE TABLE reading_source_anchors (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          source_revision INTEGER NOT NULL,
          structure_version INTEGER NOT NULL,
          block_id TEXT NOT NULL,
          sentence_id TEXT,
          selected_text_hash TEXT NOT NULL,
          character_offset INTEGER NOT NULL,
          character_length INTEGER NOT NULL,
          created_at REAL NOT NULL,
          CHECK (source_revision > 0),
          CHECK (structure_version > 0),
          CHECK (character_offset >= 0),
          CHECK (character_length > 0)
        )
        """)
        try db.execute(sql: """
        CREATE TABLE reading_document_search_index (
          document_id TEXT PRIMARY KEY REFERENCES reading_documents(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          indexed_title TEXT NOT NULL,
          indexed_body_excerpt TEXT NOT NULL,
          rebuild_required INTEGER NOT NULL,
          updated_at REAL NOT NULL
        )
        """)
    }

    private static func createReadingImportTables(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE reading_import_batches (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          adapter_id TEXT NOT NULL,
          adapter_version INTEGER NOT NULL,
          status TEXT NOT NULL,
          item_count INTEGER NOT NULL,
          success_count INTEGER NOT NULL,
          failure_count INTEGER NOT NULL,
          created_at REAL NOT NULL,
          completed_at REAL,
          CHECK (item_count >= 0),
          CHECK (success_count >= 0),
          CHECK (failure_count >= 0),
          CHECK (status IN ('pending', 'completed', 'partialFailure', 'failed', 'cancelled'))
        )
        """)
        try db.execute(sql: """
        CREATE TABLE reading_import_items (
          id TEXT PRIMARY KEY,
          batch_id TEXT NOT NULL REFERENCES reading_import_batches(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          document_id TEXT REFERENCES reading_documents(id) ON DELETE SET NULL,
          source_format TEXT NOT NULL,
          adapter_id TEXT NOT NULL,
          adapter_version INTEGER NOT NULL,
          original_filename TEXT,
          original_file_extension TEXT,
          original_mime_type TEXT,
          original_uti TEXT,
          original_byte_size INTEGER,
          byte_size_bucket TEXT,
          status TEXT NOT NULL,
          failure_category TEXT,
          created_at REAL NOT NULL,
          completed_at REAL,
          CHECK (original_byte_size IS NULL OR original_byte_size >= 0),
          CHECK (status IN ('pending', 'ready', 'failed', 'cancelled'))
        )
        """)
        try db.execute(sql: """
        CREATE TABLE reading_import_operations (
          id TEXT PRIMARY KEY,
          batch_id TEXT REFERENCES reading_import_batches(id) ON DELETE SET NULL,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          operation_type TEXT NOT NULL,
          status TEXT NOT NULL,
          failure_category TEXT,
          created_at REAL NOT NULL,
          completed_at REAL
        )
        """)
    }

    private static func createReadingOperationTables(_ db: Database) throws {
        try createReadingDocumentLifecycleEvents(db)
        try db.execute(sql: """
        CREATE TABLE reading_ai_explanation_operations (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          source_anchor_id TEXT REFERENCES reading_source_anchors(id) ON DELETE SET NULL,
          prompt_id TEXT NOT NULL,
          prompt_version TEXT NOT NULL,
          provider_profile_id TEXT,
          provider_endpoint_id TEXT,
          provider_preset_id TEXT,
          model_name TEXT,
          selected_text_hash TEXT NOT NULL,
          sentence_text_hash TEXT,
          context_character_count INTEGER NOT NULL,
          status TEXT NOT NULL,
          failure_category TEXT,
          created_at REAL NOT NULL,
          completed_at REAL,
          CHECK (context_character_count >= 0),
          CHECK (status IN ('pending', 'succeeded', 'failed', 'cancelled'))
        )
        """)
    }

    private static func createReadingDocumentLifecycleEvents(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE reading_document_lifecycle_events (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          event_type TEXT NOT NULL,
          actor TEXT NOT NULL,
          summary_json TEXT,
          created_at REAL NOT NULL,
          CHECK (event_type IN (
            'imported', 'opened', 'updated', 'softDeleted', 'restored',
            'assignedCollection', 'removedCollection', 'tagged', 'untagged'
          ))
        )
        """)
    }

    static func createReadingExplanationCache(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE reading_explanation_cache (
          id                        TEXT    PRIMARY KEY,
          document_id               TEXT    NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
          space_id                  TEXT    NOT NULL,
          content_revision          INTEGER NOT NULL,
          structure_version         INTEGER NOT NULL,
          selection_scope           TEXT    NOT NULL,
          source_anchor_id          TEXT    NOT NULL,
          explanation_language_mode TEXT    NOT NULL,
          sentence_id               TEXT    NOT NULL,
          block_id                  TEXT    NOT NULL,
          char_offset               INTEGER NOT NULL,
          char_length               INTEGER NOT NULL,
          selected_text             TEXT    NOT NULL,
          selected_text_hash        TEXT    NOT NULL,
          result_json               TEXT    NOT NULL,
          provider_id               TEXT,
          model_id                  TEXT,
          created_at                REAL    NOT NULL,
          updated_at                REAL    NOT NULL
        )
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_rec_source_anchor
          ON reading_explanation_cache(document_id, source_anchor_id, explanation_language_mode)
        """)
        try db.execute(sql: """
        CREATE INDEX idx_rec_sentence
          ON reading_explanation_cache(document_id, content_revision, sentence_id)
        """)
    }

    private static func addReadingTTSSourceColumnsIfNeeded(_ db: Database) throws {
        guard try db.tableExists("tts_audio_artifacts") else {
            return
        }
        let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(tts_audio_artifacts)")
            .map { $0["name"] as String }
        if !columns.contains("reading_document_id") {
            try db.alter(table: "tts_audio_artifacts") { table in
                table.add(column: "reading_document_id", .text)
            }
        }
        if !columns.contains("reading_sentence_id") {
            try db.alter(table: "tts_audio_artifacts") { table in
                table.add(column: "reading_sentence_id", .text)
            }
        }
    }
}
