import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// LM03-S2b-2 Phase 4: `recentTopicCandidates` — recency-ordered, soft-delete
/// excluded, space-scoped (decision #10 cross-space isolation), raw entries.body.
@Suite("Companion topic candidate repository (S2b-2)")
struct CompanionTopicCandidateRepositoryTests {
    private func makeRepo() throws -> (GRDBCompanionRepository, AppDatabase) {
        let database = try AppDatabase(databaseQueue: DatabaseQueue())
        return (GRDBCompanionRepository(writer: database.writer), database)
    }

    private func seedSpace(_ db: Database, id: String) throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at)
            VALUES (?, 'zh-Hans', 'en', 'b1', ?, ?, 0, 0)
            """,
            arguments: [id, id, id]
        )
    }

    private func seedEntry(_ db: Database, id: String, space: String, body: String, createdAt: TimeInterval, deleted: Bool = false) throws {
        try db.execute(
            sql: """
            INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at, deleted_at)
            VALUES (?, ?, ?, ?, 'typedText', 'general', ?, ?, ?)
            """,
            arguments: [id, space, "title-\(id)", body, createdAt, createdAt, deleted ? createdAt : nil]
        )
    }

    @Test("recencyOrderedSoftDeleteExcluded — newest first, deleted dropped, limit honored")
    func recencyOrderedSoftDeleteExcluded() throws {
        let (repo, database) = try makeRepo()
        try database.writer.write { db in
            try seedSpace(db, id: "s1")
            try seedEntry(db, id: "old", space: "s1", body: "old", createdAt: 1)
            try seedEntry(db, id: "new", space: "s1", body: "new", createdAt: 3)
            try seedEntry(db, id: "mid", space: "s1", body: "mid", createdAt: 2)
            try seedEntry(db, id: "del", space: "s1", body: "deleted", createdAt: 9, deleted: true)
        }
        let candidates = try repo.recentTopicCandidates(spaceID: "s1", limit: 2)
        #expect(candidates.map(\.id) == ["new", "mid"]) // newest 2, deleted excluded
        #expect(candidates.first?.body == "new")
    }

    @Test("spaceScoped — never returns entries from another space (decision #10)")
    func spaceScoped() throws {
        let (repo, database) = try makeRepo()
        try database.writer.write { db in
            try seedSpace(db, id: "s1")
            try seedSpace(db, id: "s2")
            try seedEntry(db, id: "a", space: "s1", body: "mine", createdAt: 1)
            try seedEntry(db, id: "b", space: "s2", body: "other space", createdAt: 5)
        }
        let candidates = try repo.recentTopicCandidates(spaceID: "s1", limit: 10)
        #expect(candidates.map(\.id) == ["a"])
    }

    @Test("emptyAndZeroLimit — empty space or limit 0 yields nothing")
    func emptyAndZeroLimit() throws {
        let (repo, database) = try makeRepo()
        try database.writer.write { try seedSpace($0, id: "s1") }
        #expect(try repo.recentTopicCandidates(spaceID: "s1", limit: 5).isEmpty)
        try database.writer.write { try seedEntry($0, id: "a", space: "s1", body: "x", createdAt: 1) }
        #expect(try repo.recentTopicCandidates(spaceID: "s1", limit: 0).isEmpty)
    }
}
