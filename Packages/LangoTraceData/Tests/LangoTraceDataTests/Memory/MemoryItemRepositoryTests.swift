import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// Covers the E7 memory deposit infrastructure: the v26 schema, idempotent
/// candidate deposit, soft delete, and the deposited-candidate / deposited-entry
/// projections that drive the "已加入" state and the `settled` timeline filter.
@Suite("Memory item repository")
struct MemoryItemRepositoryTests {
    private func makeDatabase() throws -> AppDatabase {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO language_spaces
                (id, native_language_code, target_language_code, level, display_name, display_name_normalized, created_at, updated_at)
                VALUES ('space-1', 'zh-Hans', 'en', 'b1', 's', 's', 0, 0)
                """
            )
            try db.execute(
                sql: """
                INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at)
                VALUES ('entry-1', 'space-1', 'T', 'B', 'typedText', '生活', 0, 0)
                """
            )
        }
        return database
    }

    private func input(candidateID: String = "cand-1", entryID: String = "entry-1") -> MemoryDepositInput {
        MemoryDepositInput(
            spaceID: "space-1",
            entryID: entryID,
            sourceCandidateID: candidateID,
            kind: .wordPhrase,
            text: "croissant",
            note: "a pastry",
            exampleTarget: "I ate a croissant.",
            exampleNative: "我吃了可颂。",
            difficulty: .medium
        )
    }

    @Test("v26 migration creates the memory_items table with the review columns")
    func migrationCreatesMemoryItemsTable() async throws {
        let database = try makeDatabase()
        let columns = try await database.databaseQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(memory_items)").map { $0["name"] as String }
        }
        for required in ["review_state", "review_rung", "review_due_at", "last_reviewed_at", "review_count", "mastered_at"] {
            #expect(columns.contains(required))
        }
    }

    @Test("a candidate deposit persists and lists with new review state")
    func depositPersists() async throws {
        let repository = try GRDBMemoryItemRepository(database: makeDatabase())
        let deposited = try await repository.deposit(input())
        #expect(deposited.reviewState == .new)
        #expect(deposited.kind == .wordPhrase)
        let listed = try await repository.listMemoryItems(spaceID: "space-1")
        #expect(listed.map(\.id) == [deposited.id])
    }

    @Test("depositing the same candidate twice is idempotent")
    func depositIsIdempotent() async throws {
        let repository = try GRDBMemoryItemRepository(database: makeDatabase())
        let first = try await repository.deposit(input())
        let second = try await repository.deposit(input())
        #expect(first.id == second.id)
        #expect(try await repository.listMemoryItems(spaceID: "space-1").count == 1)
    }

    @Test("deposited candidate ids and entry ids reflect deposits")
    func depositedProjections() async throws {
        let repository = try GRDBMemoryItemRepository(database: makeDatabase())
        _ = try await repository.deposit(input(candidateID: "cand-1"))
        #expect(try await repository.depositedCandidateIDs(spaceID: "space-1") == ["cand-1"])
        #expect(try await repository.depositedEntryIDs(spaceID: "space-1") == ["entry-1"])
    }

    @Test("soft delete removes an item from the list and projections")
    func softDeleteHides() async throws {
        let repository = try GRDBMemoryItemRepository(database: makeDatabase())
        let deposited = try await repository.deposit(input())
        try await repository.softDelete(id: deposited.id)
        #expect(try await repository.listMemoryItems(spaceID: "space-1").isEmpty)
        #expect(try await repository.depositedEntryIDs(spaceID: "space-1").isEmpty)
    }

    @Test("candidate kinds map onto the two deposit kinds")
    func candidateKindMapping() {
        #expect(MemoryItemKind(.word) == .wordPhrase)
        #expect(MemoryItemKind(.phrase) == .wordPhrase)
        #expect(MemoryItemKind(.sentencePattern) == .sentence)
        #expect(MemoryItemKind(.grammarPoint) == .sentence)
        #expect(MemoryItemKind(.errorPattern) == .sentence)
    }
}
