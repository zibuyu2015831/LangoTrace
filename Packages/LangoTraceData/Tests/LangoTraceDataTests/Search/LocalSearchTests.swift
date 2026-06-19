import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// Covers the E9 local FTS infrastructure: FTS5 trigram availability, the
/// content-free `search_index` schema, the index writer, and the grouped /
/// space-scoped / CJK / short-query-fallback search + rebuild behavior.
@Suite("Local FTS search")
struct LocalSearchTests {
    private func makeDatabase() throws -> AppDatabase {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertSpace(db, id: "space-en")
            try insertSpace(db, id: "space-ja")
        }
        return database
    }

    private func insertSpace(_ db: Database, id: String) throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level, display_name, display_name_normalized, created_at, updated_at)
            VALUES (?, 'zh-Hans', 'en', 'b1', ?, ?, 0, 0)
            """,
            arguments: [id, id, id]
        )
    }

    private func insertEntry(_ db: Database, id: String, spaceID: String, title: String, body: String) throws {
        try db.execute(
            sql: """
            INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at)
            VALUES (?, ?, ?, ?, 'typedText', '生活', 0, 0)
            """,
            arguments: [id, spaceID, title, body]
        )
    }

    @Test("FTS5 trigram virtual table is created by the v25 migration")
    func ftsTrigramTableExists() async throws {
        let database = try makeDatabase()
        let exists = try await database.databaseQueue.read { db in
            try Bool.fetchOne(
                db,
                sql: "SELECT count(*) > 0 FROM sqlite_master WHERE type = 'table' AND name = 'search_index'"
            ) ?? false
        }
        #expect(exists)
        // A trigram MATCH query must execute without error (tokenizer available).
        try await database.databaseQueue.read { db in
            _ = try Row.fetchAll(db, sql: "SELECT * FROM search_index WHERE search_index MATCH ?", arguments: ["\"abc\""])
        }
    }

    @Test("the index writer upserts and removes rows")
    func writerUpsertAndRemove() async throws {
        let database = try makeDatabase()
        try await database.databaseQueue.write { db in
            try SearchIndexWriter.upsert(
                SearchIndexRecord(kind: .entry, objectID: "e1", spaceID: "space-en", title: "Coffee", body: "morning coffee"),
                in: db
            )
        }
        let countAfterInsert = try await database.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM search_index WHERE object_id = 'e1'") ?? 0
        }
        #expect(countAfterInsert == 1)
        try await database.databaseQueue.write { db in
            try SearchIndexWriter.remove(objectKind: .entry, objectID: "e1", in: db)
        }
        let countAfterRemove = try await database.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM search_index WHERE object_id = 'e1'") ?? 0
        }
        #expect(countAfterRemove == 0)
    }

    @Test("an indexed entry is found by a body keyword")
    func indexedEntryIsFoundByBodyKeyword() async throws {
        let database = try makeDatabase()
        try await database.databaseQueue.write { db in
            try insertEntry(db, id: "e1", spaceID: "space-en", title: "Morning", body: "I had a delicious croissant at the cafe")
        }
        let repository = GRDBLocalSearchRepository(database: database)
        try await repository.rebuildSearchIndex(spaceID: "space-en")

        let results = try await repository.search(query: "croissant", spaceID: "space-en", perGroupLimit: 5)
        let entryGroup = results.groups.first { $0.kind == .entry }
        #expect(entryGroup?.hits.first?.objectID == "e1")
        #expect(entryGroup?.hits.first?.snippetHighlights.isEmpty == false)
    }

    @Test("CJK substring is found via trigram")
    func cjkSubstringIsFound() async throws {
        let database = try makeDatabase()
        try await database.databaseQueue.write { db in
            try insertEntry(db, id: "e1", spaceID: "space-en", title: "咖啡馆", body: "今天我去了图书馆看书")
        }
        let repository = GRDBLocalSearchRepository(database: database)
        try await repository.rebuildSearchIndex(spaceID: "space-en")

        let results = try await repository.search(query: "图书馆", spaceID: "space-en", perGroupLimit: 5)
        #expect(results.groups.first?.hits.first?.objectID == "e1")
    }

    @Test("a short (<3 char) query falls back to LIKE and still matches")
    func shortQueryFallsBackToLike() async throws {
        let database = try makeDatabase()
        try await database.databaseQueue.write { db in
            try insertEntry(db, id: "e1", spaceID: "space-en", title: "咖啡", body: "我喜欢咖啡")
        }
        let repository = GRDBLocalSearchRepository(database: database)
        try await repository.rebuildSearchIndex(spaceID: "space-en")

        let results = try await repository.search(query: "咖啡", spaceID: "space-en", perGroupLimit: 5)
        #expect(results.groups.first?.hits.first?.objectID == "e1")
    }

    @Test("search is scoped to a single language space")
    func searchIsSpaceScoped() async throws {
        let database = try makeDatabase()
        try await database.databaseQueue.write { db in
            try insertEntry(db, id: "e1", spaceID: "space-en", title: "A", body: "shared keyword token")
            try insertEntry(db, id: "e2", spaceID: "space-ja", title: "B", body: "shared keyword token")
        }
        let repository = GRDBLocalSearchRepository(database: database)
        try await repository.rebuildSearchIndex(spaceID: "space-en")
        try await repository.rebuildSearchIndex(spaceID: "space-ja")

        let results = try await repository.search(query: "keyword", spaceID: "space-en", perGroupLimit: 5)
        let ids = results.groups.flatMap { $0.hits.map(\.objectID) }
        #expect(ids == ["e1"])
    }

    @Test("an empty query returns empty results")
    func emptyQueryReturnsEmpty() async throws {
        let database = try makeDatabase()
        let repository = GRDBLocalSearchRepository(database: database)
        let results = try await repository.search(query: "   ", spaceID: "space-en", perGroupLimit: 5)
        #expect(results.isEmpty)
    }

    @Test("rebuild drops stale rows for deleted entries (rebuildable derived data)")
    func rebuildDropsDeletedEntries() async throws {
        let database = try makeDatabase()
        try await database.databaseQueue.write { db in
            try insertEntry(db, id: "e1", spaceID: "space-en", title: "Keep", body: "alpha token here")
        }
        let repository = GRDBLocalSearchRepository(database: database)
        try await repository.rebuildSearchIndex(spaceID: "space-en")
        #expect(try await repository.search(query: "alpha", spaceID: "space-en", perGroupLimit: 5).isEmpty == false)

        try await database.databaseQueue.write { db in
            try db.execute(sql: "UPDATE entries SET deleted_at = 1 WHERE id = 'e1'")
        }
        try await repository.rebuildSearchIndex(spaceID: "space-en")
        #expect(try await repository.search(query: "alpha", spaceID: "space-en", perGroupLimit: 5).isEmpty)
    }
}
