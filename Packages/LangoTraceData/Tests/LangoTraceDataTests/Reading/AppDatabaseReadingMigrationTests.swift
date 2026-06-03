import Foundation
import GRDB
@testable import LangoTraceData
import Testing

@Suite("Reading database migration")
struct AppDatabaseReadingMigrationTests {
    @Test("empty database migrates reading tables")
    func emptyDatabaseMigratesReadingTables() throws {
        let database = try AppDatabase.inMemory()

        let tableNames = try database.databaseQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        }

        #expect(tableNames.contains("reading_documents"))
        #expect(tableNames.contains("reading_collections"))
        #expect(tableNames.contains("reading_document_collections"))
        #expect(tableNames.contains("reading_tags"))
        #expect(tableNames.contains("reading_document_tags"))
        #expect(tableNames.contains("reading_structure_blocks"))
        #expect(tableNames.contains("reading_sentences"))
        #expect(tableNames.contains("reading_positions"))
        #expect(tableNames.contains("reading_source_anchors"))
        #expect(tableNames.contains("reading_document_search_index"))
        #expect(tableNames.contains("reading_import_batches"))
        #expect(tableNames.contains("reading_import_items"))
        #expect(tableNames.contains("reading_import_operations"))
        #expect(tableNames.contains("reading_document_lifecycle_events"))
        #expect(tableNames.contains("reading_ai_explanation_operations"))
    }

    @Test("reading documents expose long term metadata extension columns")
    func readingDocumentsExposeExtensionColumns() throws {
        let database = try AppDatabase.inMemory()

        let columns = try database.databaseQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(reading_documents)")
                .map { row in row["name"] as String }
        }

        for expected in [
            "space_id",
            "source_format",
            "adapter_id",
            "adapter_version",
            "body_storage_kind",
            "managed_body_artifact_id",
            "original_filename",
            "original_file_extension",
            "original_mime_type",
            "original_uti",
            "original_byte_size",
            "body_hash",
            "content_revision",
            "structure_version",
            "target_language_code",
            "import_status",
            "library_status",
            "restored_at",
            "last_opened_at",
        ] {
            #expect(columns.contains(expected))
        }
    }

    @Test("reading operation summary does not require raw text columns")
    func operationSummaryHasNoRawTextColumns() throws {
        let database = try AppDatabase.inMemory()

        let columns = try database.databaseQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(reading_ai_explanation_operations)")
                .map { row in row["name"] as String }
        }

        #expect(!columns.contains("selected_text"))
        #expect(!columns.contains("context_text"))
        #expect(!columns.contains("response_body"))
        #expect(!columns.contains("request_body"))
        #expect(columns.contains("selected_text_hash"))
        #expect(columns.contains("context_character_count"))
    }

    @Test("reading import tables store metadata and failure category without raw text")
    func importTablesStoreMetadataWithoutRawText() throws {
        let database = try AppDatabase.inMemory()

        let itemColumns = try database.databaseQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(reading_import_items)")
                .map { row in row["name"] as String }
        }

        #expect(itemColumns.contains("original_filename"))
        #expect(itemColumns.contains("original_file_extension"))
        #expect(itemColumns.contains("original_mime_type"))
        #expect(itemColumns.contains("original_uti"))
        #expect(itemColumns.contains("byte_size_bucket"))
        #expect(itemColumns.contains("failure_category"))
        #expect(itemColumns.contains("document_id"))
        #expect(!itemColumns.contains("body"))
        #expect(!itemColumns.contains("raw_text"))
    }

    @Test("search index is explicitly rebuildable derived data")
    func searchIndexIsRebuildableDerivedData() throws {
        let database = try AppDatabase.inMemory()

        let columns = try database.databaseQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(reading_document_search_index)")
                .map { row in row["name"] as String }
        }

        #expect(columns.contains("document_id"))
        #expect(columns.contains("indexed_title"))
        #expect(columns.contains("indexed_body_excerpt"))
        #expect(columns.contains("rebuild_required"))
    }

    @Test("reopening a persisted database upgrades reading lifecycle events to accept updated actions")
    func reopeningPersistedDatabaseUpgradesReadingLifecycleEvents() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadingLifecycleMigration-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("sqlite-shm"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("sqlite-wal"))
        }

        let database = try AppDatabase.persistent(at: url)
        try seedReadingLifecycleFixture(database)
        try replaceReadingLifecycleEventsWithLegacyConstraint(database)

        let reopened = try AppDatabase.persistent(at: url)

        #expect(throws: Never.self) {
            try reopened.databaseQueue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO reading_document_lifecycle_events (
                        id, document_id, space_id, event_type, actor, summary_json, created_at
                    ) VALUES (?, ?, ?, 'updated', 'user', NULL, ?)
                    """,
                    arguments: ["event-1", "doc-1", "space-1", 2.0]
                )
            }
        }
    }
}

private func seedReadingLifecycleFixture(_ database: AppDatabase) throws {
    try database.databaseQueue.write { db in
        try db.execute(
            sql: """
            INSERT INTO language_spaces (
                id, native_language_code, target_language_code, level,
                display_name, display_name_normalized, created_at, updated_at,
                last_opened_at, deleted_at
            ) VALUES ('space-1', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
            """
        )
        try db.execute(
            sql: """
            INSERT INTO reading_documents (
                id, space_id, title, source_kind, source_format, adapter_id,
                adapter_version, body_storage_kind, body, managed_body_artifact_id,
                source_metadata_json, original_filename, original_file_extension,
                original_mime_type, original_uti, original_byte_size, body_hash,
                content_revision, structure_version, target_language_code,
                import_status, library_status, created_at, updated_at,
                imported_at, deleted_at, restored_at, last_opened_at
            ) VALUES (
                'doc-1', 'space-1', 'Doc', 'pastedText', 'pastedText', 'builtin.pasted_text',
                1, 'inline', 'Body', NULL, NULL, NULL, NULL, 'text/plain', 'public.plain-text', 4, 'hash',
                1, 1, 'en', 'ready', 'active', 1, 1, 1, NULL, NULL, 1
            )
            """
        )
    }
}

private func replaceReadingLifecycleEventsWithLegacyConstraint(_ database: AppDatabase) throws {
    try database.databaseQueue.write { db in
        try db.execute(sql: "ALTER TABLE reading_document_lifecycle_events RENAME TO reading_document_lifecycle_events_current")
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
            'imported', 'opened', 'softDeleted', 'restored',
            'assignedCollection', 'removedCollection', 'tagged', 'untagged'
          ))
        )
        """)
        try db.execute(sql: "DROP TABLE reading_document_lifecycle_events_current")
        try db.execute(
            sql: """
            DELETE FROM grdb_migrations
            WHERE identifier = 'v13_upgrade_reading_lifecycle_events_for_document_updates'
            """
        )
    }
}
