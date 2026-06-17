import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("Reading progress and favorite — R1 Phase 2")
struct ReadingProgressAndFavoriteTests {
    // MARK: - Schema: new columns exist

    @Test("migration adds progress and favorite columns to reading_documents")
    func migrationAddsProgressAndFavoriteColumns() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.read { db in
            let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(reading_documents)")
                .map { $0["name"] as String }
            #expect(columns.contains("is_favorite"))
            #expect(columns.contains("reading_progress_percent"))
            #expect(columns.contains("last_read_block_index"))
            #expect(columns.contains("last_read_character_offset"))
            #expect(columns.contains("last_read_structure_version"))
            #expect(columns.contains("last_read_content_revision"))
            #expect(columns.contains("read_completed_at"))
            #expect(columns.contains("body_word_count"))
        }
    }

    // MARK: - Favorite

    @Test("set favorite toggles flag and appears in summary")
    func setFavoriteTogglesFlagAndAppearsInSummary() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })

        let document = try repository.importInlineDocument(.progressSample(spaceID: "space-1", title: "Favorites"))
        #expect(try repository.listDocuments(spaceID: "space-1").first?.isFavorite == false)

        try repository.setFavorite(documentID: document.id, spaceID: "space-1", isFavorite: true)
        #expect(try repository.listDocuments(spaceID: "space-1").first?.isFavorite == true)

        try repository.setFavorite(documentID: document.id, spaceID: "space-1", isFavorite: false)
        #expect(try repository.listDocuments(spaceID: "space-1").first?.isFavorite == false)
    }

    @Test("list documents with favorites filter returns only favorite documents")
    func listDocumentsWithFavoritesFilterReturnsOnlyFavorites() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })

        let doc1 = try repository.importInlineDocument(.progressSample(spaceID: "space-1", title: "Doc One"))
        _ = try repository.importInlineDocument(.progressSample(spaceID: "space-1", title: "Doc Two"))

        try repository.setFavorite(documentID: doc1.id, spaceID: "space-1", isFavorite: true)

        let all = try repository.listDocuments(spaceID: "space-1", filter: .all)
        let favorites = try repository.listDocuments(spaceID: "space-1", filter: .favoritesOnly)

        #expect(all.count == 2)
        #expect(favorites.count == 1)
        #expect(favorites.first?.title == "Doc One")
    }

    // MARK: - Reading progress

    @Test("imported document has unstarted reading progress state")
    func importedDocumentHasUnstartedProgressState() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })

        _ = try repository.importInlineDocument(.progressSample(spaceID: "space-1", title: "Unstarted"))
        let summary = try #require(try repository.listDocuments(spaceID: "space-1").first)

        #expect(summary.readingProgressState == .unstarted)
    }

    @Test("update reading progress stores percent and anchor")
    func updateReadingProgressStoresPercentAndAnchor() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })

        let document = try repository.importInlineDocument(.progressSample(spaceID: "space-1", title: "Progress"))
        try repository.updateReadingProgress(
            documentID: document.id,
            spaceID: "space-1",
            percent: 42,
            blockIndex: 2,
            characterOffset: 100,
            structureVersion: 1,
            contentRevision: 1,
            completedAt: nil
        )

        let summary = try #require(try repository.listDocuments(spaceID: "space-1").first)
        #expect(summary.readingProgressState == .reading(percent: 42))
    }

    @Test("update reading progress with completed sets completed state")
    func updateReadingProgressWithCompletedSetsCompletedState() throws {
        let database = try seededDatabase()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let repository = GRDBReadingLibraryRepository(database: database, clock: { now })

        let document = try repository.importInlineDocument(.progressSample(spaceID: "space-1", title: "Completed"))
        try repository.updateReadingProgress(
            documentID: document.id,
            spaceID: "space-1",
            percent: 100,
            blockIndex: 5,
            characterOffset: 0,
            structureVersion: 1,
            contentRevision: 1,
            completedAt: now
        )

        let summary = try #require(try repository.listDocuments(spaceID: "space-1").first)
        if case let .completed(at) = summary.readingProgressState {
            #expect(at.timeIntervalSince1970 == now.timeIntervalSince1970)
        } else {
            #expect(Bool(false), "Expected .completed, got \(summary.readingProgressState)")
        }
    }

    @Test("update reading progress is idempotent (last write wins)")
    func updateReadingProgressIsIdempotent() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })

        let document = try repository.importInlineDocument(.progressSample(spaceID: "space-1", title: "Idempotent"))
        try repository.updateReadingProgress(
            documentID: document.id, spaceID: "space-1",
            percent: 30, blockIndex: 1, characterOffset: 0, structureVersion: 1, contentRevision: 1, completedAt: nil
        )
        try repository.updateReadingProgress(
            documentID: document.id, spaceID: "space-1",
            percent: 70, blockIndex: 3, characterOffset: 50, structureVersion: 1, contentRevision: 1, completedAt: nil
        )

        let summary = try #require(try repository.listDocuments(spaceID: "space-1").first)
        #expect(summary.readingProgressState == .reading(percent: 70))
    }

    // MARK: - Word count

    @Test("summary includes word count from body")
    func summaryIncludesWordCountFromBody() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })

        let body = "One two three four five"
        _ = try repository.importInlineDocument(.progressSample(spaceID: "space-1", title: "Words", body: body))
        let summary = try #require(try repository.listDocuments(spaceID: "space-1").first)

        #expect(summary.bodyWordCount == 5)
    }
}

// MARK: - Helpers

private extension ReadingInlineDocumentImportInput {
    static func progressSample(
        spaceID: String,
        title: String,
        body: String = "First sentence. Second sentence. Third sentence."
    ) -> ReadingInlineDocumentImportInput {
        ReadingInlineDocumentImportInput(
            spaceID: spaceID,
            title: title,
            body: body,
            sourceFormat: .plainText,
            adapterID: "plain-text.v1",
            adapterVersion: 1,
            targetLanguageCode: "en",
            originalFilename: "\(title).txt",
            originalFileExtension: "txt",
            originalMimeType: "text/plain",
            originalUTI: "public.plain-text",
            originalByteSize: body.utf8.count
        )
    }
}

private func seededDatabase() throws -> AppDatabase {
    let database = try AppDatabase.inMemory()
    try database.databaseQueue.write { db in
        try db.execute(
            sql: """
            INSERT INTO language_spaces (
                id, native_language_code, target_language_code, level,
                display_name, display_name_normalized, created_at, updated_at,
                last_opened_at, deleted_at
            ) VALUES
              ('space-1', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
            """
        )
    }
    return database
}
