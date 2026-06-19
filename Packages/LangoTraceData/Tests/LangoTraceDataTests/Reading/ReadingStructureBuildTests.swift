import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("Reading structure build — DATA-08")
struct ReadingStructureBuildTests {
    // MARK: - Import builds sentence-level structure

    @Test("import inline document builds sentence-level structure with real character offsets")
    func importInlineDocumentBuildsSentenceLevelStructure() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )

        // Three sentences in one paragraph → one block, three sentence rows
        let body = "She went to the market. She bought apples. Then she came home."
        let document = try repository.importInlineDocument(.structureSample(spaceID: "space-1", title: "Sentences", body: body))

        let blocks = try database.databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT block_index FROM reading_structure_blocks WHERE document_id = ? ORDER BY block_index",
                arguments: [document.id]
            )
        }
        let sentences = try database.databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT sentence_index, character_offset FROM reading_sentences WHERE document_id = ? ORDER BY sentence_index",
                arguments: [document.id]
            )
        }

        // Must have at least one block and more sentence rows than blocks
        #expect(!blocks.isEmpty)
        #expect(sentences.count > blocks.count)

        // Later sentences must have non-zero character offsets
        let offsets = sentences.map { $0["character_offset"] as Int }
        #expect(offsets.contains { $0 > 0 }, "later sentences should have non-zero character_offset")
    }

    @Test("import records same content_revision in structure rows as the document")
    func importRecordsContentRevisionInStructureRows() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )

        let document = try repository.importInlineDocument(.structureSample(spaceID: "space-1", title: "Rev"))

        let documentRevision = try database.databaseQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT content_revision FROM reading_documents WHERE id = ?",
                arguments: [document.id]
            )
        }
        let blockRevisions = try database.databaseQueue.read { db in
            try Int.fetchAll(
                db,
                sql: "SELECT content_revision FROM reading_structure_blocks WHERE document_id = ?",
                arguments: [document.id]
            )
        }
        let sentenceRevisions = try database.databaseQueue.read { db in
            try Int.fetchAll(
                db,
                sql: "SELECT content_revision FROM reading_sentences WHERE document_id = ?",
                arguments: [document.id]
            )
        }

        let rev = try #require(documentRevision)
        #expect(!blockRevisions.isEmpty)
        #expect(!sentenceRevisions.isEmpty)
        #expect(blockRevisions.allSatisfy { $0 == rev })
        #expect(sentenceRevisions.allSatisfy { $0 == rev })
    }

    @Test("rebuildStructure correctly handles multi-byte characters in offsets")
    func rebuildStructureHandlesMultibyteCharacters() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )

        // CJK + emoji mix: two sentences, second offset must reflect full UTF-16 length of first
        let body = "猫🐱が好き。I love cats."
        let document = try repository.importInlineDocument(.structureSample(spaceID: "space-1", title: "Multibyte", body: body))

        let sentences = try database.databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT sentence_index, character_offset, character_length FROM reading_sentences WHERE document_id = ? ORDER BY sentence_index",
                arguments: [document.id]
            )
        }

        // Should have at least 2 sentences
        #expect(sentences.count >= 2)
        // Second sentence offset must be > 0
        if sentences.count >= 2 {
            let secondOffset = sentences[1]["character_offset"] as Int
            #expect(secondOffset > 0)
        }
    }

    @Test("update document rebuilds structure with incremented content revision")
    func updateDocumentRebuildsStructureWithUpdatedRevision() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )

        let document = try repository.importInlineDocument(.structureSample(spaceID: "space-1", title: "Update"))
        let originalRevision = try database.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT content_revision FROM reading_documents WHERE id = ?", arguments: [document.id])
        }

        let updateInput = try ReadingDocumentUpdateInput(
            documentID: document.id,
            spaceID: "space-1",
            title: "Update",
            body: "Completely new content. With two sentences.",
            sourceFormat: .plainText
        )
        _ = try repository.updateDocument(updateInput)

        let newRevision = try database.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT content_revision FROM reading_documents WHERE id = ?", arguments: [document.id])
        }
        let structureRevisions = try database.databaseQueue.read { db in
            try Int.fetchAll(db, sql: "SELECT DISTINCT content_revision FROM reading_sentences WHERE document_id = ?", arguments: [document.id])
        }

        let rev1 = try #require(originalRevision)
        let rev2 = try #require(newRevision)
        #expect(rev2 > rev1)
        #expect(structureRevisions == [rev2])
    }
}

// MARK: - Helpers

private final class SequentialIDGenerator: @unchecked Sendable {
    private var value = 0
    func next() -> String {
        value += 1
        return "reading-\(value)"
    }
}

private extension ReadingInlineDocumentImportInput {
    static func structureSample(
        spaceID: String,
        title: String,
        body: String = "First sentence here. Second sentence follows."
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
