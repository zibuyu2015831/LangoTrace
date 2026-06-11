import CryptoKit
import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("GRDB reading library repository")
struct GRDBReadingLibraryRepositoryTests {
    @Test("documents are scoped by language space")
    func documentsAreScopedByLanguageSpace() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )

        _ = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Space One"))
        _ = try repository.importInlineDocument(.sample(spaceID: "space-2", title: "Space Two"))

        #expect(try repository.listDocuments(spaceID: "space-1").map(\.title) == ["Space One"])
        #expect(try repository.listDocuments(spaceID: "space-2").map(\.title) == ["Space Two"])
    }

    @Test("soft deleted document is hidden until restored")
    func softDeletedDocumentIsHiddenUntilRestored() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Restorable"))

        try repository.softDeleteDocument(id: document.id, spaceID: "space-1")
        #expect(try repository.listDocuments(spaceID: "space-1").isEmpty)
        let deletedDocument = try repository.listDocuments(spaceID: "space-1", includeDeleted: true).first
        #expect(deletedDocument?.libraryStatus == .softDeleted)

        try repository.restoreDocument(id: document.id, spaceID: "space-1")
        #expect(try repository.listDocuments(spaceID: "space-1").first?.libraryStatus == .active)
    }

    @Test("collection and tag membership are idempotent")
    func collectionAndTagMembershipAreIdempotent() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Organized"))

        try repository.assignCollection(documentID: document.id, spaceID: "space-1", title: "Essays")
        try repository.assignCollection(documentID: document.id, spaceID: "space-1", title: "Essays")
        try repository.tagDocument(documentID: document.id, spaceID: "space-1", name: "travel")
        try repository.tagDocument(documentID: document.id, spaceID: "space-1", name: "travel")

        let summaries = try repository.listDocuments(spaceID: "space-1")
        let summary = try #require(summaries.first)
        #expect(summary.collectionTitles == ["Essays"])
        #expect(summary.tagNames == ["travel"])
    }

    @Test("collection and tag membership reject cross-space document ids")
    func collectionAndTagMembershipRejectCrossSpaceDocumentIDs() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Scoped"))

        #expect(throws: Error.self) {
            try repository.assignCollection(documentID: document.id, spaceID: "space-2", title: "Wrong Space")
        }
        #expect(throws: Error.self) {
            try repository.tagDocument(documentID: document.id, spaceID: "space-2", name: "wrong-space")
        }

        #expect(try repository.listDocuments(spaceID: "space-1").first?.collectionTitles.isEmpty == true)
        #expect(try repository.listDocuments(spaceID: "space-1").first?.tagNames.isEmpty == true)
    }

    @Test("lifecycle actions reject cross-space document ids")
    func lifecycleActionsRejectCrossSpaceDocumentIDs() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Lifecycle"))

        #expect(throws: ReadingLibraryRepositoryError.documentNotFound) {
            try repository.markDocumentOpened(id: document.id, spaceID: "space-2")
        }
        #expect(throws: ReadingLibraryRepositoryError.documentNotFound) {
            try repository.softDeleteDocument(id: document.id, spaceID: "space-2")
        }
        #expect(try repository.listDocuments(spaceID: "space-1").first?.libraryStatus == .active)
    }

    @Test("search matches title and indexed body excerpt without triggering external services")
    func searchMatchesTitleAndBodyExcerpt() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        _ = try repository.importInlineDocument(.sample(
            spaceID: "space-1",
            title: "Train Notes",
            body: "I bought a ticket."
        ))
        _ = try repository.importInlineDocument(.sample(
            spaceID: "space-1",
            title: "Cafe",
            body: "Reading markdown quietly."
        ))

        let titleMatches = try repository.listDocuments(
            spaceID: "space-1",
            search: ReadingLibrarySearchQuery(rawValue: "train")
        )
        let bodyMatches = try repository.listDocuments(
            spaceID: "space-1",
            search: ReadingLibrarySearchQuery(rawValue: "markdown")
        )

        #expect(titleMatches.map(\.title) == ["Train Notes"])
        #expect(bodyMatches.map(\.title) == ["Cafe"])
    }

    @Test("search escapes SQL LIKE wildcards in the query")
    func searchEscapesSQLLikeWildcards() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        _ = try repository.importInlineDocument(.sample(
            spaceID: "space-1",
            title: "Progress 100%",
            body: "Done."
        ))
        _ = try repository.importInlineDocument(.sample(
            spaceID: "space-1",
            title: "Progress 1000",
            body: "Counting."
        ))

        let matches = try repository.listDocuments(
            spaceID: "space-1",
            search: ReadingLibrarySearchQuery(rawValue: "100%")
        )

        #expect(matches.map(\.title) == ["Progress 100%"])
    }

    @Test("collection and tag names are trimmed before normalization")
    func collectionAndTagNamesAreTrimmedBeforeNormalization() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Trimmed"))

        try repository.assignCollection(documentID: document.id, spaceID: "space-1", title: " Essays ")
        try repository.assignCollection(documentID: document.id, spaceID: "space-1", title: "Essays")
        try repository.tagDocument(documentID: document.id, spaceID: "space-1", name: " travel ")
        try repository.tagDocument(documentID: document.id, spaceID: "space-1", name: "travel")

        let summary = try #require(try repository.listDocuments(spaceID: "space-1").first)
        #expect(summary.collectionTitles == ["Essays"])
        #expect(summary.tagNames == ["travel"])
    }

    @Test("reusing a soft-deleted collection or tag clears its deleted_at marker")
    func reusingSoftDeletedCollectionOrTagClearsDeletedAt() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Revived"))
        try repository.assignCollection(documentID: document.id, spaceID: "space-1", title: "Essays")
        try repository.tagDocument(documentID: document.id, spaceID: "space-1", name: "travel")
        try database.databaseQueue.write { db in
            try db.execute(sql: "UPDATE reading_collections SET deleted_at = 200")
            try db.execute(sql: "UPDATE reading_tags SET deleted_at = 200")
        }

        try repository.assignCollection(documentID: document.id, spaceID: "space-1", title: "Essays")
        try repository.tagDocument(documentID: document.id, spaceID: "space-1", name: "travel")

        let deletedMarkers = try database.databaseQueue.read { db in
            let collection = try Double.fetchOne(
                db,
                sql: "SELECT deleted_at FROM reading_collections WHERE title_normalized = 'essays'"
            )
            let tag = try Double.fetchOne(
                db,
                sql: "SELECT deleted_at FROM reading_tags WHERE name_normalized = 'travel'"
            )
            return (collection, tag)
        }
        #expect(deletedMarkers.0 == nil)
        #expect(deletedMarkers.1 == nil)
    }

    @Test("document content loads inline body and mark opened updates recent order")
    func documentContentLoadsAndMarkOpenedUpdatesOrder() throws {
        let clock = MutableClock(Date(timeIntervalSince1970: 100))
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: clock.now)
        let first = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "First", body: "Body one."))
        _ = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Second", body: "Body two."))

        let content = try #require(try repository.documentContent(id: first.id, spaceID: "space-1"))
        #expect(content.body == "Body one.")
        #expect(content.contentRevision == 1)
        #expect(content.structureVersion == 1)

        clock.date = Date(timeIntervalSince1970: 500)
        try repository.markDocumentOpened(id: first.id, spaceID: "space-1")

        #expect(try repository.listDocuments(spaceID: "space-1").map(\.title).first == "First")
    }

    @Test("import batch records partial failure without raw text")
    func importBatchRecordsPartialFailureWithoutRawText() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let batch = try repository.createImportBatch(
            ReadingImportBatchCreateInput(
                spaceID: "space-1",
                adapterID: "markdown-file.v1",
                adapterVersion: 1,
                itemCount: 2
            )
        )
        let imported = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Imported"))

        try repository.recordImportItem(
            ReadingImportItemRecordInput(
                batchID: batch.id,
                spaceID: "space-1",
                documentID: imported.id,
                sourceFormat: .markdown,
                adapterID: "markdown-file.v1",
                adapterVersion: 1,
                originalFilename: "ok.md",
                originalFileExtension: "md",
                originalMimeType: "text/markdown",
                originalUTI: "net.daringfireball.markdown",
                originalByteSize: 128,
                byteSizeBucket: "small",
                status: .ready,
                failureCategory: nil
            )
        )
        try repository.recordImportItem(
            ReadingImportItemRecordInput(
                batchID: batch.id,
                spaceID: "space-1",
                documentID: nil,
                sourceFormat: .markdown,
                adapterID: "markdown-file.v1",
                adapterVersion: 1,
                originalFilename: "broken.md",
                originalFileExtension: "md",
                originalMimeType: "text/markdown",
                originalUTI: "net.daringfireball.markdown",
                originalByteSize: 128,
                byteSizeBucket: "small",
                status: .failed,
                failureCategory: "encodingFailed"
            )
        )
        try repository.completeImportBatch(id: batch.id, spaceID: "space-1")

        let completedBatch = try repository.importBatch(id: batch.id, spaceID: "space-1")
        let completed = try #require(completedBatch)
        #expect(completed.status == .partialFailure)
        #expect(completed.successCount == 1)
        #expect(completed.failureCount == 1)
    }

    @Test("import item rejects document id from another language space")
    func importItemRejectsCrossSpaceDocumentID() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let batch = try repository.createImportBatch(
            ReadingImportBatchCreateInput(
                spaceID: "space-2",
                adapterID: "markdown-file.v1",
                adapterVersion: 1,
                itemCount: 1
            )
        )
        let imported = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Imported"))

        #expect(throws: Error.self) {
            try repository.recordImportItem(
                ReadingImportItemRecordInput(
                    batchID: batch.id,
                    spaceID: "space-2",
                    documentID: imported.id,
                    sourceFormat: .markdown,
                    adapterID: "markdown-file.v1",
                    adapterVersion: 1,
                    originalFilename: "wrong.md",
                    originalFileExtension: "md",
                    originalMimeType: "text/markdown",
                    originalUTI: "net.daringfireball.markdown",
                    originalByteSize: 128,
                    byteSizeBucket: "small",
                    status: .ready,
                    failureCategory: nil
                )
            )
        }
    }

    @Test("AI explanation operation stores hashes and non-sensitive metadata")
    func aiExplanationOperationStoresHashesOnly() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )
        let document = try repository.importInlineDocument(.sample(
            spaceID: "space-1",
            title: "Explain",
            body: "A private sentence."
        ))

        var record = ReadingAIExplanationOperationRecord()
        record.documentID = document.id
        record.spaceID = "space-1"
        record.promptID = "builtin.reading.selection_explanation.v1"
        record.promptVersion = "1"
        record.providerProfileID = "profile-1"
        record.providerEndpointID = "endpoint-1"
        record.providerPresetID = "openai"
        record.modelName = "gpt-test"
        record.selectedText = "private"
        record.sentenceText = "A private sentence."
        record.contextCharacterCount = 19
        record.status = "succeeded"
        record.completedAt = Date(timeIntervalSince1970: 101)
        try repository.recordAIExplanationOperation(record)

        let row = try database.databaseQueue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM reading_ai_explanation_operations")
        }
        let stored = try #require(row)
        #expect(stored["prompt_id"] as String? == "builtin.reading.selection_explanation.v1")
        #expect(stored["provider_profile_id"] as String? == "profile-1")
        #expect(stored["model_name"] as String? == "gpt-test")
        #expect(stored["context_character_count"] as Int? == 19)
        #expect((stored["selected_text_hash"] as String?)?.count == 64)
        #expect((stored["sentence_text_hash"] as String?)?.count == 64)
        #expect(!stored.columnNames.contains("selected_text"))
        #expect(!stored.columnNames.contains("context_text"))
    }

    @Test("AI explanation operation rejects document id from another language space")
    func aiExplanationOperationRejectsCrossSpaceDocumentID() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Explain"))

        var record = ReadingAIExplanationOperationRecord()
        record.documentID = document.id
        record.spaceID = "space-2"
        record.promptID = "builtin.reading.selection_explanation.v1"
        record.promptVersion = "1"
        record.selectedText = "private"
        record.status = "pending"

        #expect(throws: Error.self) {
            try repository.recordAIExplanationOperation(record)
        }
    }
}

@Suite("GRDB reading library repository updates")
struct GRDBReadingLibraryRepositoryUpdateTests {
    @Test("update edited document rebuilds search index and preserves metadata")
    func updateEditedDocumentRebuildsSearchIndexAndPreservesMetadata() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )
        let document = try repository.importInlineDocument(.sample(
            spaceID: "space-1",
            title: "Original",
            body: "Old body."
        ))
        try repository.assignCollection(documentID: document.id, spaceID: "space-1", title: "Essays")
        try repository.tagDocument(documentID: document.id, spaceID: "space-1", name: "travel")

        let updated = try repository.updateDocument(
            ReadingDocumentUpdateInput(
                documentID: document.id,
                spaceID: "space-1",
                title: "Updated Title",
                body: "# Heading\n\nUpdated markdown body.",
                sourceFormat: .markdown
            )
        )

        #expect(updated.title == "Updated Title")
        #expect(updated.body == "# Heading\n\nUpdated markdown body.")
        #expect(updated.contentRevision == 2)
        #expect(updated.structureVersion == 2)

        let searchMatches = try repository.listDocuments(
            spaceID: "space-1",
            search: ReadingLibrarySearchQuery(rawValue: "updated markdown")
        )
        let summary = try #require(searchMatches.first)
        #expect(summary.title == "Updated Title")
        #expect(summary.collectionTitles == ["Essays"])
        #expect(summary.tagNames == ["travel"])
    }

    @Test("soft deleted document must be restored before editing")
    func softDeletedDocumentMustBeRestoredBeforeEditing() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Restorable"))

        try repository.softDeleteDocument(id: document.id, spaceID: "space-1")
        #expect(throws: ReadingLibraryRepositoryError.softDeletedDocumentNotEditable) {
            try repository.updateDocument(
                ReadingDocumentUpdateInput(
                    documentID: document.id,
                    spaceID: "space-1",
                    title: "Updated",
                    body: "Updated body.",
                    sourceFormat: .markdown
                )
            )
        }
    }

    @Test("changing source format during edit throws a typed error")
    func changingSourceFormatDuringEditThrowsTypedError() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(database: database, clock: { Date(timeIntervalSince1970: 100) })
        let document = try repository.importInlineDocument(.sample(spaceID: "space-1", title: "Formatted"))

        #expect(throws: ReadingLibraryRepositoryError.sourceFormatChangeNotAllowed) {
            try repository.updateDocument(
                ReadingDocumentUpdateInput(
                    documentID: document.id,
                    spaceID: "space-1",
                    title: "Formatted",
                    body: "Updated body.",
                    sourceFormat: .pastedText
                )
            )
        }
    }

    @Test("updating document records lifecycle event and rebuilds structure rows")
    func updatingDocumentRecordsLifecycleEventAndRebuildsStructureRows() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )
        let document = try repository.importInlineDocument(.sample(
            spaceID: "space-1",
            title: "Original",
            body: "Old body."
        ))
        try database.databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO reading_source_anchors (
                    id, document_id, space_id, source_revision, structure_version,
                    block_id, sentence_id, selected_text_hash, character_offset,
                    character_length, created_at
                ) VALUES (?, ?, ?, 1, 1, 'block-1', NULL, ?, 0, 3, ?)
                """,
                arguments: ["anchor-1", document.id, "space-1", sha256Hex("Old"), 100.0]
            )
        }

        _ = try repository.updateDocument(
            ReadingDocumentUpdateInput(
                documentID: document.id,
                spaceID: "space-1",
                title: "Updated",
                body: "# Heading\n\nUpdated markdown body.",
                sourceFormat: .markdown
            )
        )

        let eventTypes = try database.databaseQueue.read { db in
            try String.fetchAll(
                db,
                sql: """
                SELECT event_type
                FROM reading_document_lifecycle_events
                WHERE document_id = ?
                ORDER BY created_at ASC
                """,
                arguments: [document.id]
            )
        }
        #expect(eventTypes.contains(ReadingDocumentLifecycleEventType.updated.rawValue))

        let counts = try database.databaseQueue.read { db in
            let blockCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM reading_structure_blocks WHERE document_id = ?",
                arguments: [document.id]
            ) ?? 0
            let sentenceCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM reading_sentences WHERE document_id = ?",
                arguments: [document.id]
            ) ?? 0
            let anchorCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM reading_source_anchors WHERE document_id = ?",
                arguments: [document.id]
            ) ?? 0
            return (blockCount, sentenceCount, anchorCount)
        }
        #expect(counts.0 > 0)
        #expect(counts.1 > 0)
        #expect(counts.2 == 0)
    }

    @Test("pasted text document with markdown-like content can be updated")
    func pastedTextDocumentWithMarkdownLikeContentCanBeUpdated() throws {
        let database = try seededDatabase()
        let repository = GRDBReadingLibraryRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator().next
        )
        let originalBody = """
        # Brainary

        Brainary 是一个面向智能体构建的 Python 框架 / SDK。

        ## 快速开始

        建议使用 conda 环境 `brainary`

        ```bash
        pip install -e .
        ```
        """
        let imported = try repository.importInlineDocument(
            ReadingInlineDocumentImportInput(
                spaceID: "space-1",
                title: "测试文本",
                body: originalBody,
                sourceFormat: .pastedText,
                adapterID: "builtin.pasted_text",
                adapterVersion: 1,
                targetLanguageCode: "en",
                originalFilename: nil,
                originalFileExtension: nil,
                originalMimeType: "text/plain",
                originalUTI: "public.plain-text",
                originalByteSize: originalBody.utf8.count
            )
        )

        let updated = try repository.updateDocument(
            ReadingDocumentUpdateInput(
                documentID: imported.id,
                spaceID: "space-1",
                title: "测试文本已修改",
                body: originalBody + "\n\n新增一行。",
                sourceFormat: .pastedText
            )
        )

        #expect(updated.title == "测试文本已修改")
        #expect(updated.body.hasSuffix("新增一行。"))
        #expect(updated.contentRevision == 2)
        #expect(updated.structureVersion == 2)
    }
}

private final class SequentialIDGenerator: @unchecked Sendable {
    private var value = 0

    func next() -> String {
        value += 1
        return "reading-\(value)"
    }
}

private final class MutableClock: @unchecked Sendable {
    var date: Date

    init(_ date: Date) {
        self.date = date
    }

    func now() -> Date {
        date
    }
}

private extension ReadingInlineDocumentImportInput {
    static func sample(
        spaceID: String,
        title: String,
        body: String = "A short reading document."
    ) -> ReadingInlineDocumentImportInput {
        ReadingInlineDocumentImportInput(
            spaceID: spaceID,
            title: title,
            body: body,
            sourceFormat: .markdown,
            adapterID: "markdown-file.v1",
            adapterVersion: 1,
            targetLanguageCode: "en",
            originalFilename: "\(title).md",
            originalFileExtension: "md",
            originalMimeType: "text/markdown",
            originalUTI: "net.daringfireball.markdown",
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
              ('space-1', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL),
              ('space-2', 'zh-Hans', 'ja', 'a2', 'Japanese', 'japanese', 1, 1, 1, NULL)
            """
        )
    }
    return database
}

private func sha256Hex(_ value: String) -> String {
    let digest = SHA256.hash(data: Data(value.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}
