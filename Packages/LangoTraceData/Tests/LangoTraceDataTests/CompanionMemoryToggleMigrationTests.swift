import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// LM03-S2b-1 Phase 4: the v32 `companion_threads.uses_learner_profile`
/// per-conversation injection toggle — migration column, default, writer, and the
/// `loadOrCreateThread` → `thread(id:)` read-back consistency the self-review
/// (P1-R2-2) flagged.
@Suite("Companion memory toggle (v32)")
struct CompanionMemoryToggleMigrationTests {
    private func makeDatabase() throws -> AppDatabase {
        try AppDatabase(databaseQueue: DatabaseQueue())
    }

    private func seedSpace(_ db: Database, id: String = "s1") throws {
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

    @Test("columnExistsWithDefaultOne — v32 adds uses_learner_profile defaulting to 1")
    func columnExistsWithDefaultOne() throws {
        let database = try makeDatabase()
        let columns = try database.reader.read { db in
            try db.columns(in: "companion_threads").map(\.name)
        }
        #expect(columns.contains("uses_learner_profile"))

        let repository = GRDBCompanionRepository(writer: database.writer)
        try database.writer.write { try seedSpace($0) }
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        // A freshly created thread follows the global consent (default true), and
        // the in-memory object matches what thread(id:) reads back.
        #expect(thread.usesLearnerProfile == true)
        #expect(try repository.thread(id: "t1")?.usesLearnerProfile == true)
    }

    @Test("writerPersistsToggle — setUsesLearnerProfile(false) writes and reads back")
    func writerPersistsToggle() throws {
        let database = try makeDatabase()
        let repository = GRDBCompanionRepository(writer: database.writer)
        try database.writer.write { try seedSpace($0) }
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")

        try repository.setUsesLearnerProfile(threadID: thread.id, false)
        #expect(try repository.thread(id: "t1")?.usesLearnerProfile == false)

        try repository.setUsesLearnerProfile(threadID: thread.id, true)
        #expect(try repository.thread(id: "t1")?.usesLearnerProfile == true)
    }
}
