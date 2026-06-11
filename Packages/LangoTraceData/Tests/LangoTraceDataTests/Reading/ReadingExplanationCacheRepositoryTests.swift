import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("Reading explanation cache repository")
struct ReadingExplanationCacheRepositoryTests {
    // MARK: - timestamp storage

    @Test("insert stores Unix epoch timestamps consistent with other tables")
    func insertStoresUnixEpochTimestamps() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)
        var entry = makeSampleEntry(documentID: "doc-1", sourceAnchorID: "anchor-1", mode: .bilingualBridge)
        entry.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        entry.updatedAt = Date(timeIntervalSince1970: 1_700_000_100)

        try await repo.insert(entry)

        let storedCreatedAt = try await database.databaseQueue.read { db in
            try Double.fetchOne(
                db,
                sql: "SELECT created_at FROM reading_explanation_cache WHERE id = ?",
                arguments: [entry.id]
            )
        }
        #expect(storedCreatedAt == 1_700_000_000)

        let found = try await repo.lookup(
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge
        )
        let unwrapped = try #require(found)
        #expect(unwrapped.createdAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(unwrapped.updatedAt == Date(timeIntervalSince1970: 1_700_000_100))
    }

    // MARK: - insert and lookup

    @Test("insert and lookup by sourceAnchorID returns matching entry")
    func insertAndLookupReturnsEntry() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)
        let entry = makeSampleEntry(documentID: "doc-1", sourceAnchorID: "anchor-1", mode: .bilingualBridge)

        try await repo.insert(entry)

        let found = try await repo.lookup(
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge
        )
        let unwrapped = try #require(found)
        #expect(unwrapped.id == entry.id)
        #expect(unwrapped.selectedText == entry.selectedText)
        #expect(unwrapped.result.shortExplanation == entry.result.shortExplanation)
        #expect(unwrapped.explanationLanguageMode == .bilingualBridge)
    }

    @Test("lookup with different sourceAnchorID returns nil")
    func lookupWithDifferentAnchorReturnsNil() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)
        let entry = makeSampleEntry(documentID: "doc-1", sourceAnchorID: "anchor-1", mode: .bilingualBridge)

        try await repo.insert(entry)

        let found = try await repo.lookup(
            documentID: "doc-1",
            sourceAnchorID: "anchor-99",
            mode: .bilingualBridge
        )
        #expect(found == nil)
    }

    @Test("lookup with different mode returns nil")
    func lookupWithDifferentModeReturnsNil() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)
        let entry = makeSampleEntry(documentID: "doc-1", sourceAnchorID: "anchor-1", mode: .bilingualBridge)

        try await repo.insert(entry)

        let found = try await repo.lookup(
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .sourceLanguage
        )
        #expect(found == nil)
    }

    // MARK: - pruneStale

    @Test("pruneStale removes entries with old contentRevision")
    func pruneStaleRemovesOldRevision() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)

        let oldEntry = makeSampleEntry(
            id: "entry-old",
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge,
            contentRevision: 1,
            sentenceID: "sentence-1"
        )
        let newEntry = makeSampleEntry(
            id: "entry-new",
            documentID: "doc-1",
            sourceAnchorID: "anchor-2",
            mode: .bilingualBridge,
            contentRevision: 2,
            sentenceID: "sentence-2"
        )
        try await repo.insert(oldEntry)
        try await repo.insert(newEntry)

        try await repo.pruneStale(documentID: "doc-1", currentContentRevision: 2)

        let foundOld = try await repo.lookup(
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge
        )
        let foundNew = try await repo.lookup(
            documentID: "doc-1",
            sourceAnchorID: "anchor-2",
            mode: .bilingualBridge
        )
        #expect(foundOld == nil)
        #expect(foundNew != nil)
    }

    // MARK: - loadExplainedSentenceIDs

    @Test("loadExplainedSentenceIDs returns distinct sentenceIDs for current revision")
    func loadExplainedSentenceIDsReturnsCorrectSet() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)

        let entry1 = makeSampleEntry(
            id: "e1",
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge,
            contentRevision: 2,
            sentenceID: "sentence-A"
        )
        let entry2 = makeSampleEntry(
            id: "e2",
            documentID: "doc-1",
            sourceAnchorID: "anchor-2",
            mode: .sourceLanguage,
            contentRevision: 2,
            sentenceID: "sentence-B"
        )
        let entryOldRevision = makeSampleEntry(
            id: "e3",
            documentID: "doc-1",
            sourceAnchorID: "anchor-3",
            mode: .bilingualBridge,
            contentRevision: 1,
            sentenceID: "sentence-C"
        )
        try await repo.insert(entry1)
        try await repo.insert(entry2)
        try await repo.insert(entryOldRevision)

        let ids = try await repo.loadExplainedSentenceIDs(documentID: "doc-1", contentRevision: 2)
        #expect(ids == Set(["sentence-A", "sentence-B"]))
    }

    // MARK: - lookupBySentenceID

    @Test("lookupBySentenceID returns entry with matching sentenceID")
    func lookupBySentenceIDReturnsEntry() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)
        let entry = makeSampleEntry(
            id: "e1",
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge,
            contentRevision: 1,
            sentenceID: "sentence-X"
        )
        try await repo.insert(entry)

        let found = try await repo.lookupBySentenceID(
            documentID: "doc-1",
            contentRevision: 1,
            sentenceID: "sentence-X"
        )
        let unwrapped = try #require(found)
        #expect(unwrapped.sentenceID == "sentence-X")
    }

    // MARK: - delete

    @Test("delete removes entry from database")
    func deleteRemovesEntry() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)
        let entry = makeSampleEntry(documentID: "doc-1", sourceAnchorID: "anchor-1", mode: .bilingualBridge)
        try await repo.insert(entry)

        try await repo.delete(id: entry.id)

        let found = try await repo.lookup(
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge
        )
        #expect(found == nil)
    }

    // MARK: - upsert

    @Test("insert with same anchor and mode replaces existing entry")
    func insertReplacesDuplicate() async throws {
        let database = try makeTestDatabase()
        let repo = GRDBReadingExplanationCacheRepository(database: database)

        let original = makeSampleEntry(
            id: "e-original",
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge
        )
        var updated = makeSampleEntry(
            id: "e-updated",
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge
        )
        updated.result = ReadingSelectionExplanationResult(
            schemaVersion: "1",
            selection: "world",
            shortExplanation: "Updated explanation",
            meaningInNativeLanguage: "更新后的意思",
            usageNote: "Updated note",
            exampleSentence: "Hello updated world.",
            explanationLanguageMode: .bilingualBridge
        )

        try await repo.insert(original)
        try await repo.insert(updated)

        let found = try await repo.lookup(
            documentID: "doc-1",
            sourceAnchorID: "anchor-1",
            mode: .bilingualBridge
        )
        let unwrapped = try #require(found)
        #expect(unwrapped.result.shortExplanation == "Updated explanation")
    }
}

// MARK: - Helpers

private func makeTestDatabase() throws -> AppDatabase {
    let database = try AppDatabase.inMemory()
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
                'doc-1', 'space-1', 'Test Document', 'pastedText', 'pastedText',
                'builtin.pasted_text', 1, 'inline', 'Hello world.', NULL,
                NULL, NULL, NULL, 'text/plain', 'public.plain-text', 12, 'abc123',
                1, 1, 'en', 'ready', 'active', 1, 1, 1, NULL, NULL, 1
            )
            """
        )
    }
    return database
}

private func makeSampleEntry(
    id: String = "entry-1",
    documentID: String,
    sourceAnchorID: String,
    mode: ExplanationLanguageMode,
    contentRevision: Int = 1,
    sentenceID: String = "sentence-1"
) -> ReadingExplanationCacheEntry {
    let result = ReadingSelectionExplanationResult(
        schemaVersion: "1",
        selection: "hello",
        shortExplanation: "A common greeting",
        meaningInNativeLanguage: "打招呼的常用词",
        usageNote: "Used informally",
        exampleSentence: "Hello, how are you?",
        exampleSentenceTranslation: "你好，你怎么样？",
        grammaticalNote: nil,
        explanationLanguageMode: mode
    )
    return ReadingExplanationCacheEntry(
        id: id,
        documentID: documentID,
        spaceID: "space-1",
        contentRevision: contentRevision,
        structureVersion: 1,
        selectionScope: .sentence,
        sourceAnchorID: sourceAnchorID,
        explanationLanguageMode: mode,
        sentenceID: sentenceID,
        blockID: "block-1",
        charOffset: 0,
        charLength: 5,
        selectedText: "hello",
        selectedTextHash: "abc123hash",
        result: result,
        providerID: "openai",
        modelID: "gpt-4o",
        createdAt: Date(timeIntervalSinceReferenceDate: 1000),
        updatedAt: Date(timeIntervalSinceReferenceDate: 1000)
    )
}
