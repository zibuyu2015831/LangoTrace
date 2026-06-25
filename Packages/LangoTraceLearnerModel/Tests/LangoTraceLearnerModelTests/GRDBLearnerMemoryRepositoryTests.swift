import Foundation
import GRDB
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM02 Slice 1 system-level Memory repository: explicit save / list /
/// soft-delete / system reset, cross-space visibility (no space partition),
/// `source_entry_id` weak link, and the准原始 storage-policy literals.
@Suite("GRDB learner memory repository")
struct GRDBLearnerMemoryRepositoryTests {
    private func makeRepository() throws -> (GRDBLearnerMemoryRepository, DatabaseQueue) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        let repository = GRDBLearnerMemoryRepository(writer: database.writer)
        return (repository, queue)
    }

    private func insertSpace(_ db: Database, id: String, code: String) throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at)
            VALUES (?, 'zh-Hans', ?, 'b1', ?, ?, 0, 0)
            """,
            arguments: [id, code, id, id]
        )
    }

    private func insertEntry(_ db: Database, id: String, spaceID: String) throws {
        try db.execute(
            sql: """
            INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at)
            VALUES (?, ?, 'title', 'body', 'typedText', 'default', 0, 0)
            """,
            arguments: [id, spaceID]
        )
    }

    @Test("facts are system-level: visible regardless of which space is active")
    func factsAreSystemLevelVisibleAcrossSpaces() throws {
        let (repository, _) = try makeRepository()
        try repository.save(MemoryFact(id: "f1", kind: .lifeFact, text: "我住在上海"))
        try repository.save(MemoryFact(id: "f2", kind: .goal, text: "考过 N2"))

        // No space argument exists — listing is global by construction.
        let facts = try repository.list()
        #expect(facts.map(\.id) == ["f1", "f2"])
    }

    @Test("single delete is a recoverable soft-delete")
    func singleDeleteIsRecoverable() throws {
        let (repository, _) = try makeRepository()
        try repository.save(MemoryFact(id: "f1", kind: .lifeFact, text: "a"))
        try repository.softDelete(id: "f1")

        #expect(try repository.list().isEmpty)
        let withDeleted = try repository.list(includeDeleted: true)
        #expect(withDeleted.map(\.id) == ["f1"])
        #expect(withDeleted[0].softDeletedAt != nil)
    }

    @Test("system reset hard-deletes all facts (count == 0)")
    func systemResetHardDeletesAllFacts() throws {
        let (repository, queue) = try makeRepository()
        try repository.save(MemoryFact(id: "f1", kind: .lifeFact, text: "a"))
        try repository.save(MemoryFact(id: "f2", kind: .goal, text: "b"))
        try repository.softDelete(id: "f1")

        try repository.resetAll()

        let count = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM learner_memory_facts") ?? -1
        }
        #expect(count == 0)
    }

    @Test("deleting a language space does not cascade-delete Memory facts")
    func deletingSpaceDoesNotCascadeMemoryFacts() throws {
        let (repository, queue) = try makeRepository()
        try queue.write { db in
            try insertSpace(db, id: "space-1", code: "ja")
        }
        try repository.save(MemoryFact(id: "f1", kind: .lifeFact, text: "a"))

        // Hard-delete the space; the system-level fact must survive.
        try queue.write { db in
            try db.execute(sql: "DELETE FROM language_spaces WHERE id = 'space-1'")
        }
        #expect(try repository.list().map(\.id) == ["f1"])
    }

    @Test("source_entry_id is a weak link: deleting the entry nulls it, fact survives")
    func sourceEntryIsWeakLink() throws {
        let (repository, queue) = try makeRepository()
        try queue.write { db in
            try insertSpace(db, id: "space-1", code: "ja")
            try insertEntry(db, id: "entry-1", spaceID: "space-1")
        }
        try repository.save(MemoryFact(id: "f1", kind: .lifeFact, text: "a", sourceEntryID: "entry-1"))

        try queue.write { db in
            try db.execute(sql: "DELETE FROM entries WHERE id = 'entry-1'")
        }
        let facts = try repository.list()
        #expect(facts.map(\.id) == ["f1"])
        #expect(facts[0].sourceEntryID == nil)
    }

    @Test("saved facts carry the准原始 storage-policy literals")
    func savedFactsCarryPreservedPolicies() throws {
        let (repository, queue) = try makeRepository()
        try repository.save(MemoryFact(id: "f1", kind: .lifeFact, text: "a"))
        let row = try queue.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT sync_policy, backup_policy, export_policy FROM learner_memory_facts WHERE id = 'f1'"
            )
        }
        #expect(row?["sync_policy"] == "localOnly")
        #expect(row?["backup_policy"] == "includedInSystemBackup")
        #expect(row?["export_policy"] == "includedInRecoverableBackup")
    }
}
