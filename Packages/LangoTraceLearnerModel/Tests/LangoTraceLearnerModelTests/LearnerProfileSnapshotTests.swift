import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM02 Slice 1 `LearnerProfileSnapshot` aggregation (§12.4): combines
/// Learner-owned Ability coverage + Memory facts with the **borrowed** per-space
/// review statistics, and proves a system-level reset does not touch the borrowed
/// review statistics (which come from `memory_items`, not the Memory layer).
@Suite("Learner profile snapshot")
struct LearnerProfileSnapshotTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private struct Stack {
        let builder: LearnerProfileSnapshotBuilder
        let memoryRepository: GRDBLearnerMemoryRepository
        let queue: DatabaseQueue
    }

    private func makeStack() throws -> Stack {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        let provider = GRDBLearnerContextProvider(reader: database.reader, clock: { now })
        let memoryRepository = GRDBLearnerMemoryRepository(writer: database.writer)
        let itemRepository = GRDBMemoryItemRepository(database: database)
        let builder = LearnerProfileSnapshotBuilder(provider: provider, memoryItemRepository: itemRepository)
        return Stack(builder: builder, memoryRepository: memoryRepository, queue: queue)
    }

    private func seedSpaceAndCoverage(_ queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.execute(sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at)
            VALUES ('space-1', 'zh-Hans', 'ja', 'b1', 's', 's', 0, 0)
            """)
            // A deposited memory_item drives both Ability coverage and review stats.
            try db.execute(
                sql: """
                INSERT INTO memory_items
                (id, space_id, source_kind, kind, text, note, example_target, example_native,
                 difficulty, review_state, created_at)
                VALUES ('mi-1', 'space-1', 'candidate', 'wordPhrase', '勉強', 'n', 'e', 'e',
                 'easy', 'new', ?)
                """,
                arguments: [now.timeIntervalSince1970]
            )
        }
    }

    @Test("snapshot combines owned coverage + facts with borrowed review statistics")
    func snapshotCombinesOwnedAndBorrowed() async throws {
        let stack = try makeStack()
        let builder = stack.builder
        let memoryRepository = stack.memoryRepository
        let queue = stack.queue
        try seedSpaceAndCoverage(queue)
        try memoryRepository.save(MemoryFact(id: "f1", kind: .goal, text: "考过 N2"))

        let snapshot = try await builder.snapshot(spaceID: "space-1", languageCode: "ja", now: now)
        #expect(snapshot.abilityCoverage.entries.count == 1)
        #expect(snapshot.memoryFacts.map(\.id) == ["f1"])
        #expect(snapshot.reviewStatistics.depositedThisWeek == 1)
        #expect(snapshot.trend.coverageEntryCount == 1)
        #expect(snapshot.trend.depositedThisWeek == 1)
    }

    @Test("system reset clears Memory facts but does not change borrowed review statistics")
    func systemResetDoesNotChangeReviewStatistics() async throws {
        let stack = try makeStack()
        let builder = stack.builder
        let memoryRepository = stack.memoryRepository
        let queue = stack.queue
        try seedSpaceAndCoverage(queue)
        try memoryRepository.save(MemoryFact(id: "f1", kind: .goal, text: "考过 N2"))

        let before = try await builder.snapshot(spaceID: "space-1", languageCode: "ja", now: now)
        try memoryRepository.resetAll()
        let after = try await builder.snapshot(spaceID: "space-1", languageCode: "ja", now: now)

        // Memory facts gone...
        #expect(after.memoryFacts.isEmpty)
        // ...but the borrowed review statistics (from memory_items) are untouched.
        #expect(after.reviewStatistics == before.reviewStatistics)
        #expect(after.reviewStatistics.depositedThisWeek == 1)
        // Ability coverage (also from memory_items) likewise unaffected.
        #expect(after.abilityCoverage.entries.count == 1)
    }
}
