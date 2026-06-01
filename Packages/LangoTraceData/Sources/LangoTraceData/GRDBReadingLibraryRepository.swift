import CryptoKit
import Foundation
import GRDB
import LangoTraceCore

public struct GRDBReadingLibraryRepository: @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.databaseQueue = database.databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }
}

public extension GRDBReadingLibraryRepository {
    func importInlineDocument(_ input: ReadingInlineDocumentImportInput) throws -> ReadingLibraryDocumentSummary {
        try databaseQueue.write { db in
            let id = idGenerator()
            let now = clock()
            let hash = sha256Hex(input.body)
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
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'inline', ?, NULL, NULL, ?, ?, ?, ?, ?, ?, 1, 1, ?, 'ready', 'active', ?, ?, ?, NULL, NULL, ?)
                """,
                arguments: [
                    id,
                    input.spaceID,
                    input.title,
                    input.sourceFormat == .pastedText ? "pastedText" : "fileImport",
                    input.sourceFormat.rawValue,
                    input.adapterID,
                    input.adapterVersion,
                    input.body,
                    input.originalFilename,
                    input.originalFileExtension,
                    input.originalMimeType,
                    input.originalUTI,
                    input.originalByteSize,
                    hash,
                    input.targetLanguageCode,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                ]
            )
            try rebuildSearchIndex(documentID: id, spaceID: input.spaceID, title: input.title, body: input.body, db: db)
            try recordLifecycle(documentID: id, spaceID: input.spaceID, eventType: .imported, db: db)
            return try summary(documentID: id, spaceID: input.spaceID, db: db)
        }
    }

    func listDocuments(
        spaceID: String,
        includeDeleted: Bool = false,
        search: ReadingLibrarySearchQuery? = nil
    ) throws -> [ReadingLibraryDocumentSummary] {
        try databaseQueue.read { db in
            var conditions = ["d.space_id = ?"]
            var arguments: StatementArguments = [spaceID]
            if !includeDeleted {
                conditions.append("d.library_status = 'active'")
            }
            if let search {
                conditions.append("""
                (
                    LOWER(d.title) LIKE ?
                    OR LOWER(COALESCE(si.indexed_body_excerpt, '')) LIKE ?
                )
                """)
                let pattern = "%\(search.normalized.lowercased())%"
                arguments += [pattern, pattern]
            }
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT d.*
                FROM reading_documents d
                LEFT JOIN reading_document_search_index si ON si.document_id = d.id
                WHERE \(conditions.joined(separator: " AND "))
                ORDER BY d.last_opened_at DESC, d.updated_at DESC, d.title ASC
                """,
                arguments: arguments
            )
            return try rows.map { try summary(from: $0, db: db) }
        }
    }

    func documentContent(id: String, spaceID: String) throws -> ReadingLibraryDocumentContent? {
        try databaseQueue.read { db in
            try Row.fetchOne(
                db,
                sql: """
                SELECT id, space_id, title, body, source_format, target_language_code,
                       content_revision, structure_version
                FROM reading_documents
                WHERE id = ? AND space_id = ?
                """,
                arguments: [id, spaceID]
            ).map { row in
                ReadingLibraryDocumentContent(
                    id: row["id"],
                    spaceID: row["space_id"],
                    title: row["title"],
                    body: row["body"] ?? "",
                    sourceFormat: ReadingSourceFormat(rawValue: row["source_format"] as String) ?? .plainText,
                    targetLanguageCode: row["target_language_code"],
                    contentRevision: row["content_revision"],
                    structureVersion: row["structure_version"]
                )
            }
        }
    }

    func markDocumentOpened(id: String, spaceID: String) throws {
        try databaseQueue.write { db in
            let now = clock().timeIntervalSince1970
            try db.execute(
                sql: """
                UPDATE reading_documents
                SET last_opened_at = ?, updated_at = ?
                WHERE id = ? AND space_id = ? AND library_status = 'active'
                """,
                arguments: [now, now, id, spaceID]
            )
            try recordLifecycle(documentID: id, spaceID: spaceID, eventType: .opened, db: db)
        }
    }

    func softDeleteDocument(id: String, spaceID: String) throws {
        try databaseQueue.write { db in
            let now = clock().timeIntervalSince1970
            try db.execute(
                sql: """
                UPDATE reading_documents
                SET library_status = 'softDeleted', deleted_at = ?, updated_at = ?
                WHERE id = ? AND space_id = ?
                """,
                arguments: [now, now, id, spaceID]
            )
            try recordLifecycle(documentID: id, spaceID: spaceID, eventType: .softDeleted, db: db)
        }
    }

    func restoreDocument(id: String, spaceID: String) throws {
        try databaseQueue.write { db in
            let now = clock().timeIntervalSince1970
            try db.execute(
                sql: """
                UPDATE reading_documents
                SET library_status = 'active', restored_at = ?, deleted_at = NULL, updated_at = ?
                WHERE id = ? AND space_id = ?
                """,
                arguments: [now, now, id, spaceID]
            )
            try recordLifecycle(documentID: id, spaceID: spaceID, eventType: .restored, db: db)
        }
    }

    func assignCollection(documentID: String, spaceID: String, title: String) throws {
        try databaseQueue.write { db in
            let normalized = title.lowercased()
            let collectionID = try upsertCollection(spaceID: spaceID, title: title, normalized: normalized, db: db)
            try db.execute(
                sql: """
                INSERT OR IGNORE INTO reading_document_collections (
                    document_id, collection_id, space_id, assigned_at
                ) VALUES (?, ?, ?, ?)
                """,
                arguments: [documentID, collectionID, spaceID, clock().timeIntervalSince1970]
            )
            try recordLifecycle(documentID: documentID, spaceID: spaceID, eventType: .assignedCollection, db: db)
        }
    }

    func tagDocument(documentID: String, spaceID: String, name: String) throws {
        try databaseQueue.write { db in
            let normalized = name.lowercased()
            let tagID = try upsertTag(spaceID: spaceID, name: name, normalized: normalized, db: db)
            try db.execute(
                sql: """
                INSERT OR IGNORE INTO reading_document_tags (
                    document_id, tag_id, space_id, tagged_at
                ) VALUES (?, ?, ?, ?)
                """,
                arguments: [documentID, tagID, spaceID, clock().timeIntervalSince1970]
            )
            try recordLifecycle(documentID: documentID, spaceID: spaceID, eventType: .tagged, db: db)
        }
    }

    func createImportBatch(_ input: ReadingImportBatchCreateInput) throws -> ReadingImportBatchSummary {
        try databaseQueue.write { db in
            let id = idGenerator()
            try db.execute(
                sql: """
                INSERT INTO reading_import_batches (
                    id, space_id, adapter_id, adapter_version, status, item_count,
                    success_count, failure_count, created_at, completed_at
                ) VALUES (?, ?, ?, ?, 'pending', ?, 0, 0, ?, NULL)
                """,
                arguments: [
                    id,
                    input.spaceID,
                    input.adapterID,
                    input.adapterVersion,
                    input.itemCount,
                    clock().timeIntervalSince1970,
                ]
            )
            return ReadingImportBatchSummary(
                id: id,
                spaceID: input.spaceID,
                status: .pending,
                itemCount: input.itemCount,
                successCount: 0,
                failureCount: 0
            )
        }
    }

    func recordImportItem(_ input: ReadingImportItemRecordInput) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO reading_import_items (
                    id, batch_id, space_id, document_id, source_format, adapter_id,
                    adapter_version, original_filename, original_file_extension,
                    original_mime_type, original_uti, original_byte_size,
                    byte_size_bucket, status, failure_category, created_at, completed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    idGenerator(),
                    input.batchID,
                    input.spaceID,
                    input.documentID,
                    input.sourceFormat.rawValue,
                    input.adapterID,
                    input.adapterVersion,
                    input.originalFilename,
                    input.originalFileExtension,
                    input.originalMimeType,
                    input.originalUTI,
                    input.originalByteSize,
                    input.byteSizeBucket,
                    input.status.rawValue,
                    input.failureCategory,
                    clock().timeIntervalSince1970,
                    clock().timeIntervalSince1970,
                ]
            )
        }
    }

    func completeImportBatch(id: String, spaceID: String) throws {
        try databaseQueue.write { db in
            let success = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM reading_import_items WHERE batch_id = ? AND space_id = ? AND status = 'ready'",
                arguments: [id, spaceID]
            ) ?? 0
            let failure = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM reading_import_items WHERE batch_id = ? AND space_id = ? AND status = 'failed'",
                arguments: [id, spaceID]
            ) ?? 0
            let status: ReadingImportBatchStatus
            if failure > 0 && success > 0 {
                status = .partialFailure
            } else if failure > 0 {
                status = .failed
            } else {
                status = .completed
            }
            try db.execute(
                sql: """
                UPDATE reading_import_batches
                SET status = ?, success_count = ?, failure_count = ?, completed_at = ?
                WHERE id = ? AND space_id = ?
                """,
                arguments: [status.rawValue, success, failure, clock().timeIntervalSince1970, id, spaceID]
            )
        }
    }

    func importBatch(id: String, spaceID: String) throws -> ReadingImportBatchSummary? {
        try databaseQueue.read { db in
            try Row.fetchOne(
                db,
                sql: """
                SELECT id, space_id, status, item_count, success_count, failure_count
                FROM reading_import_batches
                WHERE id = ? AND space_id = ?
                """,
                arguments: [id, spaceID]
            ).map(batchSummary(from:))
        }
    }

    func recordAIExplanationOperation(
        documentID: String,
        spaceID: String,
        sourceAnchorID: String?,
        promptID: String,
        promptVersion: String,
        providerProfileID: String?,
        providerEndpointID: String?,
        providerPresetID: String?,
        modelName: String?,
        selectedText: String,
        sentenceText: String?,
        contextCharacterCount: Int,
        status: String,
        failureCategory: String? = nil,
        completedAt: Date? = nil
    ) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO reading_ai_explanation_operations (
                    id, document_id, space_id, source_anchor_id, prompt_id,
                    prompt_version, provider_profile_id, provider_endpoint_id,
                    provider_preset_id, model_name, selected_text_hash,
                    sentence_text_hash, context_character_count, status,
                    failure_category, created_at, completed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    idGenerator(),
                    documentID,
                    spaceID,
                    sourceAnchorID,
                    promptID,
                    promptVersion,
                    providerProfileID,
                    providerEndpointID,
                    providerPresetID,
                    modelName,
                    sha256Hex(selectedText),
                    sentenceText.map(sha256Hex),
                    contextCharacterCount,
                    status,
                    failureCategory,
                    clock().timeIntervalSince1970,
                    completedAt?.timeIntervalSince1970,
                ]
            )
        }
    }
}

private extension GRDBReadingLibraryRepository {
    func summary(documentID: String, spaceID: String, db: Database) throws -> ReadingLibraryDocumentSummary {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM reading_documents WHERE id = ? AND space_id = ?",
            arguments: [documentID, spaceID]
        ) else {
            throw DatabaseError(message: "Missing reading document")
        }
        return try summary(from: row, db: db)
    }

    func summary(from row: Row, db: Database) throws -> ReadingLibraryDocumentSummary {
        let documentID: String = row["id"]
        let spaceID: String = row["space_id"]
        let tagNames = try String.fetchAll(
            db,
            sql: """
            SELECT t.name
            FROM reading_tags t
            JOIN reading_document_tags dt ON dt.tag_id = t.id
            WHERE dt.document_id = ? AND dt.space_id = ?
            ORDER BY t.name ASC
            """,
            arguments: [documentID, spaceID]
        )
        let collectionTitles = try String.fetchAll(
            db,
            sql: """
            SELECT c.title
            FROM reading_collections c
            JOIN reading_document_collections dc ON dc.collection_id = c.id
            WHERE dc.document_id = ? AND dc.space_id = ?
            ORDER BY c.title ASC
            """,
            arguments: [documentID, spaceID]
        )
        return ReadingLibraryDocumentSummary(
            id: documentID,
            spaceID: spaceID,
            title: row["title"],
            sourceFormat: ReadingSourceFormat(rawValue: row["source_format"] as String) ?? .plainText,
            importStatus: ReadingImportStatus(rawValue: row["import_status"] as String) ?? .failed,
            libraryStatus: ReadingLibraryStatus(rawValue: row["library_status"] as String) ?? .softDeleted,
            tagNames: tagNames,
            collectionTitles: collectionTitles,
            lastOpenedAt: (row["last_opened_at"] as Double?).map(Date.init(timeIntervalSince1970:))
        )
    }

    func upsertCollection(spaceID: String, title: String, normalized: String, db: Database) throws -> String {
        if let existing = try String.fetchOne(
            db,
            sql: "SELECT id FROM reading_collections WHERE space_id = ? AND title_normalized = ?",
            arguments: [spaceID, normalized]
        ) {
            return existing
        }
        let id = idGenerator()
        try db.execute(
            sql: """
            INSERT INTO reading_collections (
                id, space_id, title, title_normalized, created_at, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, NULL)
            """,
            arguments: [id, spaceID, title, normalized, clock().timeIntervalSince1970, clock().timeIntervalSince1970]
        )
        return id
    }

    func upsertTag(spaceID: String, name: String, normalized: String, db: Database) throws -> String {
        if let existing = try String.fetchOne(
            db,
            sql: "SELECT id FROM reading_tags WHERE space_id = ? AND name_normalized = ?",
            arguments: [spaceID, normalized]
        ) {
            return existing
        }
        let id = idGenerator()
        try db.execute(
            sql: """
            INSERT INTO reading_tags (
                id, space_id, name, name_normalized, created_at, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, NULL)
            """,
            arguments: [id, spaceID, name, normalized, clock().timeIntervalSince1970, clock().timeIntervalSince1970]
        )
        return id
    }

    func rebuildSearchIndex(documentID: String, spaceID: String, title: String, body: String, db: Database) throws {
        try db.execute(
            sql: """
            INSERT OR REPLACE INTO reading_document_search_index (
                document_id, space_id, indexed_title, indexed_body_excerpt,
                rebuild_required, updated_at
            ) VALUES (?, ?, ?, ?, 0, ?)
            """,
            arguments: [
                documentID,
                spaceID,
                title.lowercased(),
                String(body.prefix(2_000)).lowercased(),
                clock().timeIntervalSince1970,
            ]
        )
    }

    func recordLifecycle(
        documentID: String,
        spaceID: String,
        eventType: ReadingDocumentLifecycleEventType,
        db: Database
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO reading_document_lifecycle_events (
                id, document_id, space_id, event_type, actor, summary_json, created_at
            ) VALUES (?, ?, ?, ?, 'user', NULL, ?)
            """,
            arguments: [idGenerator(), documentID, spaceID, eventType.rawValue, clock().timeIntervalSince1970]
        )
    }

    func batchSummary(from row: Row) -> ReadingImportBatchSummary {
        ReadingImportBatchSummary(
            id: row["id"],
            spaceID: row["space_id"],
            status: ReadingImportBatchStatus(rawValue: row["status"] as String) ?? .failed,
            itemCount: row["item_count"],
            successCount: row["success_count"],
            failureCount: row["failure_count"]
        )
    }

    func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
