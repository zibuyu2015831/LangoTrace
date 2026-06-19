import Foundation
import GRDB
import LangoTraceCore

/// GRDB-backed local full-text search (系列 E9).
///
/// `rebuildSearchIndex(spaceID:)` repopulates the FTS index from main data
/// (entries + current learning text, reading documents); it is the maintenance
/// path for v1 (the palette rebuilds on open so results are always fresh).
/// `search` uses FTS5 trigram for queries ≥ 3 characters and falls back to a
/// `LIKE` scan for shorter queries (trigram needs ≥ 3 chars). Search is fully
/// local — no Provider/network dependency.
public struct GRDBLocalSearchRepository: LocalSearchRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    /// Queries shorter than this (in characters) use the LIKE fallback.
    private let minimumTrigramLength = 3

    public init(database: AppDatabase) {
        databaseQueue = database.databaseQueue
    }

    public func search(query: String, spaceID: String, perGroupLimit: Int) async throws -> SearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, perGroupLimit > 0 else {
            return .empty(query: trimmed)
        }
        let rows = try await databaseQueue.read { db in
            try fetchRows(db, query: trimmed, spaceID: spaceID, perGroupLimit: perGroupLimit)
        }
        let groups = SearchObjectKind.allCases.compactMap { kind -> SearchResultGroup? in
            let hits = rows.filter { $0.kind == kind }
            return hits.isEmpty ? nil : SearchResultGroup(kind: kind, hits: hits)
        }
        return SearchResults(query: trimmed, groups: groups)
    }

    public func rebuildSearchIndex(spaceID: String) async throws {
        try await databaseQueue.write { db in
            try SearchIndexWriter.removeAll(spaceID: spaceID, in: db)
            try rebuildEntries(db, spaceID: spaceID)
            try rebuildReadingDocuments(db, spaceID: spaceID)
            // Memory items (E7) are not indexed yet — the memory group degrades
            // to an empty state until E7's memory_items table lands.
        }
    }
}

private extension GRDBLocalSearchRepository {
    func fetchRows(_ db: Database, query: String, spaceID: String, perGroupLimit: Int) throws -> [SearchHit] {
        let useTrigram = query.count >= minimumTrigramLength
        let sql: String
        let arguments: StatementArguments
        if useTrigram {
            sql = """
            SELECT object_kind, object_id, space_id, reading_block_index, title, body
            FROM search_index
            WHERE space_id = ? AND search_index MATCH ?
            ORDER BY rank
            """
            arguments = [spaceID, trigramMatch(query)]
        } else {
            let like = "%\(escapeLike(query))%"
            sql = """
            SELECT object_kind, object_id, space_id, reading_block_index, title, body
            FROM search_index
            WHERE space_id = ? AND (title LIKE ? ESCAPE '\\' OR body LIKE ? ESCAPE '\\')
            ORDER BY rowid
            """
            arguments = [spaceID, like, like]
        }
        var perGroupCount: [SearchObjectKind: Int] = [:]
        var hits: [SearchHit] = []
        let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
        for row in rows {
            guard let kind = SearchObjectKind(rawValue: row["object_kind"] as String) else { continue }
            let count = perGroupCount[kind] ?? 0
            guard count < perGroupLimit else { continue }
            perGroupCount[kind] = count + 1
            let title = row["title"] as String
            let body = row["body"] as String
            let snippet = Self.snippet(from: body, query: query)
            let objectID = row["object_id"] as String
            let blockIndex = row["reading_block_index"] as Int?
            hits.append(
                SearchHit(
                    id: "\(kind.rawValue):\(objectID):\(blockIndex.map(String.init) ?? "-")",
                    kind: kind,
                    spaceID: row["space_id"],
                    objectID: objectID,
                    title: title,
                    snippet: snippet,
                    titleHighlights: SearchHighlighting.ranges(of: query, in: title),
                    snippetHighlights: SearchHighlighting.ranges(of: query, in: snippet),
                    readingBlockIndex: blockIndex
                )
            )
        }
        return hits
    }

    /// FTS5 trigram match string: wrap in double quotes so the whole query is a
    /// literal phrase; double any embedded quotes.
    func trigramMatch(_ query: String) -> String {
        "\"\(query.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    func escapeLike(_ query: String) -> String {
        query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    static func snippet(from body: String, query: String, window: Int = 80) -> String {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return "" }
        if let range = trimmedBody.range(of: query, options: .caseInsensitive) {
            let lower = trimmedBody.index(range.lowerBound, offsetBy: -window, limitedBy: trimmedBody.startIndex)
                ?? trimmedBody.startIndex
            let upper = trimmedBody.index(range.upperBound, offsetBy: window, limitedBy: trimmedBody.endIndex)
                ?? trimmedBody.endIndex
            let prefix = lower > trimmedBody.startIndex ? "…" : ""
            let suffix = upper < trimmedBody.endIndex ? "…" : ""
            return prefix + String(trimmedBody[lower ..< upper]) + suffix
        }
        let end = trimmedBody.index(trimmedBody.startIndex, offsetBy: window * 2, limitedBy: trimmedBody.endIndex)
            ?? trimmedBody.endIndex
        let suffix = end < trimmedBody.endIndex ? "…" : ""
        return String(trimmedBody[trimmedBody.startIndex ..< end]) + suffix
    }

    func rebuildEntries(_ db: Database, spaceID: String) throws {
        // Fold the current learning text into the entry body so a single entry
        // row covers both the user's record and its generated learning material.
        let learningText = try Row.fetchAll(
            db,
            sql: "SELECT entry_id, learning_text FROM learning_materials WHERE space_id = ? AND is_current = 1",
            arguments: [spaceID]
        ).reduce(into: [String: String]()) { result, row in
            result[row["entry_id"] as String] = row["learning_text"] as String
        }
        let entries = try Row.fetchAll(
            db,
            sql: "SELECT id, title, body FROM entries WHERE space_id = ? AND deleted_at IS NULL",
            arguments: [spaceID]
        )
        for row in entries {
            let id = row["id"] as String
            var body = row["body"] as String
            if let extra = learningText[id], !extra.isEmpty {
                body += "\n" + extra
            }
            try SearchIndexWriter.upsert(
                SearchIndexRecord(kind: .entry, objectID: id, spaceID: spaceID, title: row["title"], body: body),
                in: db
            )
        }
    }

    func rebuildReadingDocuments(_ db: Database, spaceID: String) throws {
        let documents = try Row.fetchAll(
            db,
            sql: """
            SELECT id, title, structure_version
            FROM reading_documents
            WHERE space_id = ? AND deleted_at IS NULL
            """,
            arguments: [spaceID]
        )
        for document in documents {
            let documentID = document["id"] as String
            let structureVersion = document["structure_version"] as Int
            let blocks = try Row.fetchAll(
                db,
                sql: """
                SELECT block_index, plain_text
                FROM reading_structure_blocks
                WHERE document_id = ? AND structure_version = ?
                ORDER BY block_index
                """,
                arguments: [documentID, structureVersion]
            )
            let body = blocks.map { $0["plain_text"] as String }.joined(separator: "\n")
            try SearchIndexWriter.upsert(
                SearchIndexRecord(
                    kind: .readingDocument,
                    objectID: documentID,
                    spaceID: spaceID,
                    title: document["title"],
                    body: body
                ),
                in: db
            )
        }
    }
}
