import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// Covers LM03-S1 Phase 2: the v30 companion migration (three tables, per-space
/// FK cascade, source_entry_id SET NULL, voice seam columns, explicit export
/// policy) and the repository (single active thread, linear sequence, delete-and-
/// subsequent, clear, persona round-trip).
@Suite("GRDB companion repository")
struct GRDBCompanionRepositoryTests {
    private func makeDatabase() throws -> (AppDatabase, DatabaseQueue) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        return (database, queue)
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

    private func seedEntry(_ db: Database, id: String = "e1", space: String = "s1") throws {
        try db.execute(
            sql: """
            INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at, deleted_at)
            VALUES (?, ?, 'title', 'body text', 'typedText', 'general', 0, 0, NULL)
            """,
            arguments: [id, space]
        )
    }

    // MARK: - Migration structure

    @Test("v30 creates the three companion tables with the documented columns")
    func migrationCreatesCompanionTables() throws {
        let (_, queue) = try makeDatabase()
        try queue.read { db in
            let companionExists = try db.tableExists("conversation_companions")
            let threadExists = try db.tableExists("companion_threads")
            let messageExists = try db.tableExists("companion_messages")
            #expect(companionExists)
            #expect(threadExists)
            #expect(messageExists)
        }
    }

    @Test("companionMessageSchemaReservesVoiceSeam — input_modality + audio_artifact_id columns exist")
    func companionMessageSchemaReservesVoiceSeam() throws {
        let (_, queue) = try makeDatabase()
        try queue.read { db in
            let columns = try db.columns(in: "companion_messages").map(\.name)
            #expect(columns.contains("input_modality"))
            #expect(columns.contains("audio_artifact_id"))
        }
    }

    @Test("companionTablesIncludedInExportNotExcluded — policy columns mark recoverable main data")
    func companionTablesIncludedInExportNotExcluded() throws {
        let (database, queue) = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        try repository.appendMessage(threadID: thread.id, role: .user, content: "hi", targetLanguageCode: "en", id: "m1")
        let row = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT sync_policy, backup_policy, export_policy FROM companion_messages WHERE id = 'm1'")
        }
        #expect(row?["sync_policy"] == "localOnly")
        #expect(row?["backup_policy"] == "includedInSystemBackup")
        #expect(row?["export_policy"] == "includedByDefault")
    }

    // MARK: - Thread

    @Test("oneActiveThreadPerSpace — load-or-create returns the same thread")
    func oneActiveThreadPerSpace() throws {
        let (database, _) = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let first = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        let second = try repository.loadOrCreateThread(spaceID: "s1", id: "t2-should-not-be-used")
        #expect(first.id == "t1")
        #expect(second.id == "t1")
    }

    // MARK: - Messages

    @Test("Messages persist with linear sequence, ordered on read")
    func messagesPersistInSequence() throws {
        let (database, _) = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        try repository.appendMessage(threadID: thread.id, role: .user, content: "a", targetLanguageCode: "en", id: "m0")
        try repository.appendMessage(threadID: thread.id, role: .assistant, content: "b", targetLanguageCode: "en", id: "m1")
        let messages = try repository.messages(threadID: thread.id)
        #expect(messages.map(\.id) == ["m0", "m1"])
        #expect(messages.map(\.sequence) == [0, 1])
    }

    @Test("deleteMessageCascadesSubsequent — removes the target and everything after it")
    func deleteMessageCascadesSubsequent() throws {
        let (database, _) = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        for index in 0 ..< 4 {
            try repository.appendMessage(threadID: thread.id, role: .user, content: "m\(index)", targetLanguageCode: "en", id: "m\(index)")
        }
        try repository.deleteMessageAndSubsequent(messageID: "m1")
        let messages = try repository.messages(threadID: thread.id)
        #expect(messages.map(\.id) == ["m0"])
    }

    @Test("clearThreadRemovesAllMessages — keeps the thread, drops messages")
    func clearThreadRemovesAllMessages() throws {
        let (database, _) = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        try repository.appendMessage(threadID: thread.id, role: .user, content: "a", targetLanguageCode: "en", id: "m0")
        try repository.clearThread(threadID: thread.id)
        #expect(try repository.messages(threadID: thread.id).isEmpty)
        // Thread survives.
        let reloaded = try repository.loadOrCreateThread(spaceID: "s1", id: "t-other")
        #expect(reloaded.id == "t1")
    }

    // MARK: - Cascade / weak link

    @Test("deletingSpaceCascadesCompanionThreadAndMessages")
    func deletingSpaceCascadesCompanionThreadAndMessages() throws {
        let (database, queue) = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        try repository.appendMessage(threadID: thread.id, role: .user, content: "a", targetLanguageCode: "en", id: "m0")
        try database.writer.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "DELETE FROM language_spaces WHERE id = 's1'")
        }
        try queue.read { db in
            let threads = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM companion_threads") ?? -1
            let messages = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM companion_messages") ?? -1
            #expect(threads == 0)
            #expect(messages == 0)
        }
    }

    @Test("source_entry_id is a weak link — deleting the entry nulls it, thread survives")
    func sourceEntryIsWeakLink() throws {
        let (database, queue) = try makeDatabase()
        try database.writer.write {
            try seedSpace($0)
            try seedEntry($0)
        }
        let repository = GRDBCompanionRepository(writer: database.writer)
        _ = try repository.loadOrCreateThread(spaceID: "s1", sourceEntryID: "e1", id: "t1")
        try database.writer.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "DELETE FROM entries WHERE id = 'e1'")
        }
        try queue.read { db in
            let threadCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM companion_threads WHERE id = 't1'") ?? -1
            let origin = try String.fetchOne(db, sql: "SELECT source_entry_id FROM companion_threads WHERE id = 't1'")
            #expect(threadCount == 1)
            #expect(origin == nil)
        }
    }

    // MARK: - Persona

    @Test("loadPersona returns the recommended default when none is stored")
    func loadPersonaDefault() throws {
        let (database, _) = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        #expect(try repository.loadPersona(spaceID: "s1") == .default)
    }

    @Test("savePersona round-trips through upsert")
    func savePersonaRoundTrips() throws {
        let (database, _) = try makeDatabase()
        try database.writer.write { try seedSpace($0) }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let persona = CompanionPersona(tone: .humorous, formality: .formal, correction: .warmRecast)
        try repository.savePersona(persona, spaceID: "s1")
        #expect(try repository.loadPersona(spaceID: "s1") == persona)
        // Upsert again to a new value.
        try repository.savePersona(.default, spaceID: "s1")
        #expect(try repository.loadPersona(spaceID: "s1") == .default)
    }
}
