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

    @Test("depositCandidate resolves the full candidate from storage and deposits")
    func depositCandidateResolvesAndDeposits() async throws {
        let database = try makeDatabase()
        try await database.databaseQueue.write { db in
            try db.execute(sql: """
            INSERT INTO learning_materials (
                id, entry_id, space_id, input_kind, prompt_mode, learning_text, original_generated_text,
                analysis_source_hash, analysis_status, prompt_id, prompt_version, provider_preset_id,
                model_name, is_current, created_at, updated_at
            ) VALUES ('mat-1','entry-1','space-1','nativeRecord','automaticLearningMaterial','text','text',
                'h','fresh','p','1','openai','m',1,0,0)
            """)
            try db.execute(sql: """
            INSERT INTO memory_candidates (
                id, space_id, entry_id, material_id, kind, text, explanation_native,
                example_target, example_native, difficulty, status, created_at, updated_at
            ) VALUES ('cand-x','space-1','entry-1','mat-1','grammarPoint','present perfect','recent past',
                'I have eaten','我吃过了','medium','candidate',0,0)
            """)
        }
        let repository = GRDBMemoryItemRepository(database: database)
        let deposited = try await repository.depositCandidate(candidateID: "cand-x", spaceID: "space-1")
        #expect(deposited?.kind == .sentence)
        #expect(deposited?.text == "present perfect")
        #expect(deposited?.entryID == "entry-1")
        // Idempotent: a second deposit returns the same row.
        let again = try await repository.depositCandidate(candidateID: "cand-x", spaceID: "space-1")
        #expect(again?.id == deposited?.id)
        #expect(try await repository.listMemoryItems(spaceID: "space-1").count == 1)
    }

    @Test("depositCandidate returns nil for an unknown candidate")
    func depositCandidateUnknownReturnsNil() async throws {
        let repository = try GRDBMemoryItemRepository(database: makeDatabase())
        let result = try await repository.depositCandidate(candidateID: "missing", spaceID: "space-1")
        #expect(result == nil)
    }

    @Test("a freshly deposited item is immediately due for review")
    func freshDepositIsDue() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let repository = try GRDBMemoryItemRepository(database: makeDatabase())
        let deposited = try await repository.deposit(input())
        let due = try await repository.dueItems(spaceID: "space-1", limit: 10, now: now)
        #expect(due.map(\.id) == [deposited.id])
    }

    @Test("recording 'remembered' advances state out of the immediate due window and bumps the count")
    func recordRememberedAdvances() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let repository = try GRDBMemoryItemRepository(database: makeDatabase())
        let deposited = try await repository.deposit(input())
        let updated = try await repository.recordReviewOutcome(id: deposited.id, outcome: .remembered, now: now)
        #expect(updated?.reviewState == .scheduled)
        #expect(updated?.reviewCount == 1)
        #expect(try await repository.dueItems(spaceID: "space-1", limit: 10, now: now).isEmpty)
    }

    @Test("statistics report deposited-this-week, due and mastered counts")
    func statistics() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let repository = try GRDBMemoryItemRepository(database: makeDatabase(), clock: { now })
        let a = try await repository.deposit(input(candidateID: "c-a"))
        _ = try await repository.deposit(input(candidateID: "c-b"))
        try await repository.markMastered(id: a.id, now: now)

        let stats = try await repository.memoryStatistics(spaceID: "space-1", now: now)
        #expect(stats.depositedThisWeek == 2)
        #expect(stats.masteredCount == 1)
        #expect(stats.dueCount == 1)
    }

    @Test("resume review brings a mastered item back into the due queue")
    func resumeReviewRequeues() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let repository = try GRDBMemoryItemRepository(database: makeDatabase())
        let deposited = try await repository.deposit(input())
        try await repository.markMastered(id: deposited.id, now: now)
        #expect(try await repository.dueItems(spaceID: "space-1", limit: 10, now: now).isEmpty)
        try await repository.resumeReview(id: deposited.id, now: now)
        let later = now.addingTimeInterval(2 * 86400)
        #expect(try await repository.dueItems(spaceID: "space-1", limit: 10, now: later).map(\.id) == [deposited.id])
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
