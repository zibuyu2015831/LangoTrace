import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// LM03-S3b-1: the v33 rolling-summary columns and the delete/clear invalidation
/// consistency rule (idea-03 §3.2) — the highest-risk part of the slice.
@Suite("Companion rolling summary repository (LM03-S3b-1)")
struct CompanionRollingSummaryRepositoryTests {
    private func makeDatabase() throws -> AppDatabase {
        try AppDatabase(databaseQueue: DatabaseQueue())
    }

    private func seedSpace(_ db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at)
            VALUES ('s1', 'zh-Hans', 'en', 'b1', 's1', 's1', 0, 0)
            """
        )
    }

    /// Seeds a thread with `count` user messages at sequence 0..<count.
    private func seedThread(_ repository: GRDBCompanionRepository, count: Int) throws -> (thread: CompanionThread, ids: [String]) {
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        var ids: [String] = []
        for index in 0 ..< count {
            let message = try repository.appendMessage(
                threadID: thread.id, role: .user, content: "m\(index)",
                targetLanguageCode: "en", id: "m\(index)"
            )
            ids.append(message.id)
        }
        return (thread, ids)
    }

    // MARK: - Migration

    @Test("v33 adds the rolling-summary columns, defaulting null for existing rows")
    func migrationAddsRollingSummaryColumns() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")

        let columns = try database.reader.read { db in
            try db.columns(in: "companion_threads").map(\.name)
        }
        #expect(columns.contains("rolling_summary"))
        #expect(columns.contains("summary_covers_through_sequence"))
        #expect(columns.contains("summary_updated_at"))
        // A freshly created thread has no summary yet.
        #expect(try repository.loadRollingSummary(threadID: thread.id) == nil)
    }

    // MARK: - Round-trip

    @Test("updateRollingSummary / loadRollingSummary round-trip the value")
    func summaryRoundTrips() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")

        try repository.updateRollingSummary(
            threadID: thread.id, text: "We talked about her trip.", coversThroughSequence: 5,
            now: Date(timeIntervalSince1970: 1000)
        )
        let loaded = try repository.loadRollingSummary(threadID: thread.id)
        #expect(loaded == CompanionRollingSummary(
            text: "We talked about her trip.",
            coversThroughSequence: 5,
            updatedAt: Date(timeIntervalSince1970: 1000)
        ))
    }

    // MARK: - Invalidation consistency (idea-03 §3.2)

    @Test("deleting at or before the watermark invalidates the summary (same transaction)")
    func deleteAtOrBeforeWatermarkInvalidates() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let (thread, ids) = try seedThread(repository, count: 10)
        try repository.updateRollingSummary(threadID: thread.id, text: "summary", coversThroughSequence: 5)

        // Delete from sequence 3 (≤ watermark 5) → the summary covers deleted content.
        try repository.deleteMessageAndSubsequent(messageID: ids[3])
        // Read back immediately: no intermediate state — the summary is already gone.
        #expect(try repository.loadRollingSummary(threadID: thread.id) == nil)
    }

    @Test("deleting strictly after the watermark keeps the summary")
    func deleteAfterWatermarkKeepsSummary() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let (thread, ids) = try seedThread(repository, count: 10)
        try repository.updateRollingSummary(threadID: thread.id, text: "summary", coversThroughSequence: 5)

        // Delete from sequence 8 (> watermark 5) → only unsummarized recent turns go.
        try repository.deleteMessageAndSubsequent(messageID: ids[8])
        #expect(try repository.loadRollingSummary(threadID: thread.id)?.coversThroughSequence == 5)
    }

    @Test("deleting with no summary is a no-op (null watermark)")
    func deleteWithNoSummaryIsNoOp() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let (_, ids) = try seedThread(repository, count: 5)
        // No summary set → watermark is null → delete must not crash and leave none.
        try repository.deleteMessageAndSubsequent(messageID: ids[2])
        #expect(try repository.loadRollingSummary(threadID: "t1") == nil)
    }

    @Test("clearing the whole thread clears its summary")
    func clearThreadClearsSummary() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let (thread, _) = try seedThread(repository, count: 6)
        try repository.updateRollingSummary(threadID: thread.id, text: "summary", coversThroughSequence: 4)

        try repository.clearThread(threadID: thread.id)
        #expect(try repository.loadRollingSummary(threadID: thread.id) == nil)
    }
}
