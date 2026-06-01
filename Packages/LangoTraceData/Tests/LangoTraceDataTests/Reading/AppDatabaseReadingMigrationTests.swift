import GRDB
import Testing
@testable import LangoTraceData

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
            "last_opened_at"
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
}
