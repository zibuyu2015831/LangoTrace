import Foundation
import GRDB
import LangoTraceCore

public struct GRDBReadingExplanationCacheRepository: ReadingExplanationCacheRepositoryProtocol, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        databaseQueue = database.databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func insert(_ entry: ReadingExplanationCacheEntry) async throws {
        let resultJSON = try encodeResult(entry.result)
        let record = ReadingExplanationCacheRecord(
            id: entry.id,
            documentID: entry.documentID,
            spaceID: entry.spaceID,
            contentRevision: entry.contentRevision,
            structureVersion: entry.structureVersion,
            selectionScope: entry.selectionScope.rawValue,
            sourceAnchorID: entry.sourceAnchorID,
            explanationLanguageMode: entry.explanationLanguageMode.rawValue,
            sentenceID: entry.sentenceID,
            blockID: entry.blockID,
            charOffset: entry.charOffset,
            charLength: entry.charLength,
            selectedText: entry.selectedText,
            selectedTextHash: entry.selectedTextHash,
            resultJSON: resultJSON,
            providerID: entry.providerID,
            modelID: entry.modelID,
            createdAt: entry.createdAt.timeIntervalSinceReferenceDate,
            updatedAt: entry.updatedAt.timeIntervalSinceReferenceDate
        )
        try await databaseQueue.write { db in
            try record.insert(db, onConflict: .replace)
        }
    }

    public func lookup(
        documentID: String,
        sourceAnchorID: String,
        mode: ExplanationLanguageMode
    ) async throws -> ReadingExplanationCacheEntry? {
        try await databaseQueue.read { db in
            let record = try ReadingExplanationCacheRecord
                .filter(
                    Column("document_id") == documentID &&
                        Column("source_anchor_id") == sourceAnchorID &&
                        Column("explanation_language_mode") == mode.rawValue
                )
                .fetchOne(db)
            return record.flatMap { toEntry($0) }
        }
    }

    public func lookupBySentenceID(
        documentID: String,
        contentRevision: Int,
        sentenceID: String
    ) async throws -> ReadingExplanationCacheEntry? {
        try await databaseQueue.read { db in
            let record = try ReadingExplanationCacheRecord
                .filter(
                    Column("document_id") == documentID &&
                        Column("content_revision") == contentRevision &&
                        Column("sentence_id") == sentenceID
                )
                .fetchOne(db)
            return record.flatMap { toEntry($0) }
        }
    }

    public func loadExplainedSentenceIDs(
        documentID: String,
        contentRevision: Int
    ) async throws -> Set<String> {
        try await databaseQueue.read { db in
            let records = try ReadingExplanationCacheRecord
                .filter(
                    Column("document_id") == documentID &&
                        Column("content_revision") == contentRevision
                )
                .fetchAll(db)
            return Set(records.map(\.sentenceID))
        }
    }

    public func delete(id: String) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: "DELETE FROM reading_explanation_cache WHERE id = ?",
                arguments: [id]
            )
        }
    }

    public func pruneStale(documentID: String, currentContentRevision: Int) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: """
                DELETE FROM reading_explanation_cache
                WHERE document_id = ? AND content_revision != ?
                """,
                arguments: [documentID, currentContentRevision]
            )
        }
    }
}

// MARK: - Private helpers

private extension GRDBReadingExplanationCacheRepository {
    func encodeResult(_ result: ReadingSelectionExplanationResult) throws -> String {
        let data = try JSONEncoder().encode(result)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ReadingExplanationCacheError.encodingFailed
        }
        return json
    }

    func toEntry(_ record: ReadingExplanationCacheRecord) -> ReadingExplanationCacheEntry? {
        guard
            let resultData = record.resultJSON.data(using: .utf8),
            let result = try? JSONDecoder().decode(ReadingSelectionExplanationResult.self, from: resultData),
            let selectionScope = ReadingSelectionScope(rawValue: record.selectionScope),
            let explanationLanguageMode = ExplanationLanguageMode(rawValue: record.explanationLanguageMode)
        else {
            return nil
        }
        return ReadingExplanationCacheEntry(
            id: record.id,
            documentID: record.documentID,
            spaceID: record.spaceID,
            contentRevision: record.contentRevision,
            structureVersion: record.structureVersion,
            selectionScope: selectionScope,
            sourceAnchorID: record.sourceAnchorID,
            explanationLanguageMode: explanationLanguageMode,
            sentenceID: record.sentenceID,
            blockID: record.blockID,
            charOffset: record.charOffset,
            charLength: record.charLength,
            selectedText: record.selectedText,
            selectedTextHash: record.selectedTextHash,
            result: result,
            providerID: record.providerID,
            modelID: record.modelID,
            createdAt: Date(timeIntervalSinceReferenceDate: record.createdAt),
            updatedAt: Date(timeIntervalSinceReferenceDate: record.updatedAt)
        )
    }
}

// MARK: - Error

public enum ReadingExplanationCacheError: Error {
    case encodingFailed
}

// MARK: - GRDB record

private struct ReadingExplanationCacheRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "reading_explanation_cache"

    var id: String
    var documentID: String
    var spaceID: String
    var contentRevision: Int
    var structureVersion: Int
    var selectionScope: String
    var sourceAnchorID: String
    var explanationLanguageMode: String
    var sentenceID: String
    var blockID: String
    var charOffset: Int
    var charLength: Int
    var selectedText: String
    var selectedTextHash: String
    var resultJSON: String
    var providerID: String?
    var modelID: String?
    var createdAt: Double
    var updatedAt: Double

    enum CodingKeys: String, CodingKey {
        case id
        case documentID = "document_id"
        case spaceID = "space_id"
        case contentRevision = "content_revision"
        case structureVersion = "structure_version"
        case selectionScope = "selection_scope"
        case sourceAnchorID = "source_anchor_id"
        case explanationLanguageMode = "explanation_language_mode"
        case sentenceID = "sentence_id"
        case blockID = "block_id"
        case charOffset = "char_offset"
        case charLength = "char_length"
        case selectedText = "selected_text"
        case selectedTextHash = "selected_text_hash"
        case resultJSON = "result_json"
        case providerID = "provider_id"
        case modelID = "model_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
