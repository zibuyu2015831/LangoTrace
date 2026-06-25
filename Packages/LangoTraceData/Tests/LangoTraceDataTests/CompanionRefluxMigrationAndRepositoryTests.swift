import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// Covers LM03-S2a Phase 2: the v31 `companion_memory_candidates` migration (kind
/// / status checks, thread CASCADE, message SET NULL weak link, no policy columns)
/// and the three repository methods (`appendCompanionCandidates`,
/// `companionCandidates`, `productionUtterances`).
@Suite("GRDB companion reflux repository")
struct CompanionRefluxMigrationAndRepositoryTests {
    private func makeDatabase() throws -> AppDatabase {
        try AppDatabase(databaseQueue: DatabaseQueue())
    }

    private func seedSpace(_ db: Database, id: String, target: String = "en") throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at)
            VALUES (?, 'zh-Hans', ?, 'b1', ?, ?, 0, 0)
            """,
            arguments: [id, target, id, id]
        )
    }

    private func makeCandidate(
        id: String,
        kind: LearningMemoryCandidate.Kind = .word,
        text: String = "word",
        createdAt: Date
    ) -> CompanionMemoryCandidate {
        CompanionMemoryCandidate(
            id: id,
            kind: kind,
            text: text,
            explanationNative: "n",
            exampleTarget: "t",
            exampleNative: "v",
            createdAt: createdAt
        )
    }

    // MARK: - Migration

    @Test("companionCandidatesTableExistsAfterV31")
    func companionCandidatesTableExistsAfterV31() throws {
        let database = try makeDatabase()
        let exists = try database.reader.read { db in
            try db.tableExists("companion_memory_candidates")
        }
        #expect(exists)
    }

    @Test("candidateTableHasNoSyncBackupExportPolicyColumns — derived data, not main data (plan §D4)")
    func candidateTableHasNoPolicyColumns() throws {
        let database = try makeDatabase()
        let columns = try database.reader.read { db in
            try db.columns(in: "companion_memory_candidates").map(\.name)
        }
        #expect(!columns.contains("sync_policy"))
        #expect(!columns.contains("backup_policy"))
        #expect(!columns.contains("export_policy"))
    }

    // MARK: - Append / read round-trip

    @Test("appendThenReadReturnsCandidatesNewestFirst")
    func appendThenReadReturnsCandidatesNewestFirst() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0, id: "s1") }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        let message = try repository.appendMessage(
            threadID: thread.id, role: .user, content: "hi", targetLanguageCode: "en", id: "m1"
        )
        try repository.appendCompanionCandidates(
            threadID: thread.id,
            messageID: message.id,
            candidates: [
                makeCandidate(id: "c-old", text: "older", createdAt: Date(timeIntervalSince1970: 100)),
                makeCandidate(id: "c-new", text: "newer", createdAt: Date(timeIntervalSince1970: 200)),
            ]
        )
        let read = try repository.companionCandidates(spaceID: "s1")
        #expect(read.map(\.id) == ["c-new", "c-old"])
        #expect(read.first?.messageID == "m1")
    }

    @Test("appendEmptyBatchIsNoOp")
    func appendEmptyBatchIsNoOp() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0, id: "s1") }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        try repository.appendCompanionCandidates(threadID: thread.id, messageID: nil, candidates: [])
        #expect(try repository.companionCandidates(spaceID: "s1").isEmpty)
    }

    @Test("candidatesAreIsolatedAcrossSpaces")
    func candidatesAreIsolatedAcrossSpaces() throws {
        let database = try makeDatabase()
        try database.writer.write {
            try seedSpace($0, id: "s1")
            try seedSpace($0, id: "s2")
        }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let t1 = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        let t2 = try repository.loadOrCreateThread(spaceID: "s2", id: "t2")
        try repository.appendCompanionCandidates(
            threadID: t1.id, messageID: nil,
            candidates: [makeCandidate(id: "c1", createdAt: Date(timeIntervalSince1970: 1))]
        )
        try repository.appendCompanionCandidates(
            threadID: t2.id, messageID: nil,
            candidates: [makeCandidate(id: "c2", createdAt: Date(timeIntervalSince1970: 1))]
        )
        #expect(try repository.companionCandidates(spaceID: "s1").map(\.id) == ["c1"])
        #expect(try repository.companionCandidates(spaceID: "s2").map(\.id) == ["c2"])
    }

    // MARK: - Cascade / weak link

    @Test("deletingThreadCascadeDeletesCandidates")
    func deletingThreadCascadeDeletesCandidates() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0, id: "s1") }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        try repository.appendCompanionCandidates(
            threadID: thread.id, messageID: nil,
            candidates: [makeCandidate(id: "c1", createdAt: Date(timeIntervalSince1970: 1))]
        )
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM companion_threads WHERE id = 't1'")
        }
        #expect(try repository.companionCandidates(spaceID: "s1").isEmpty)
    }

    @Test("deletingMessageSetsCandidateMessageIdNullButRetainsCandidate")
    func deletingMessageSetsCandidateMessageIdNullButRetainsCandidate() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0, id: "s1") }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        let message = try repository.appendMessage(
            threadID: thread.id, role: .user, content: "hi", targetLanguageCode: "en", id: "m1"
        )
        try repository.appendCompanionCandidates(
            threadID: thread.id, messageID: message.id,
            candidates: [makeCandidate(id: "c1", createdAt: Date(timeIntervalSince1970: 1))]
        )
        // Deleting the single source message nulls the weak link, keeps the candidate.
        try repository.deleteMessageAndSubsequent(messageID: "m1")
        let read = try repository.companionCandidates(spaceID: "s1")
        #expect(read.count == 1)
        #expect(read.first?.id == "c1")
        #expect(read.first?.messageID == nil)
    }

    // MARK: - Production utterances (交付物 B forward read seam)

    @Test("productionUtterancesExcludeAssistantAndNonTargetMessages")
    func productionUtterancesExcludeAssistantAndNonTargetMessages() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0, id: "s1", target: "en") }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        // user + target language → included
        try repository.appendMessage(
            threadID: thread.id, role: .user, content: "I went hiking",
            detectedLanguage: "en", targetLanguageCode: "en", id: "u-en"
        )
        // user but native language → excluded
        try repository.appendMessage(
            threadID: thread.id, role: .user, content: "我去爬山了",
            detectedLanguage: "zh-Hans", targetLanguageCode: "en", id: "u-zh"
        )
        // assistant in target language → excluded (not a production signal)
        try repository.appendMessage(
            threadID: thread.id, role: .assistant, content: "Sounds fun!",
            detectedLanguage: "en", targetLanguageCode: "en", id: "a-en"
        )
        // user but no detected language → excluded
        try repository.appendMessage(
            threadID: thread.id, role: .user, content: "...",
            detectedLanguage: nil, targetLanguageCode: "en", id: "u-nil"
        )
        let utterances = try repository.productionUtterances(spaceID: "s1", after: nil)
        #expect(utterances.map(\.id) == ["u-en"])
    }

    @Test("productionUtterancesCursorReturnsOnlyAfter")
    func productionUtterancesCursorReturnsOnlyAfter() throws {
        let database = try makeDatabase()
        try database.writer.write { try seedSpace($0, id: "s1", target: "en") }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        try repository.appendMessage(
            threadID: thread.id, role: .user, content: "first",
            detectedLanguage: "en", targetLanguageCode: "en", id: "u1",
            now: Date(timeIntervalSince1970: 100)
        )
        try repository.appendMessage(
            threadID: thread.id, role: .user, content: "second",
            detectedLanguage: "en", targetLanguageCode: "en", id: "u2",
            now: Date(timeIntervalSince1970: 200)
        )
        let after = try repository.productionUtterances(spaceID: "s1", after: Date(timeIntervalSince1970: 150))
        #expect(after.map(\.id) == ["u2"])
        let all = try repository.productionUtterances(spaceID: "s1", after: nil)
        #expect(all.map(\.id) == ["u1", "u2"])
    }

    @Test("productionUtterancesAreScopedToSpace")
    func productionUtterancesAreScopedToSpace() throws {
        let database = try makeDatabase()
        try database.writer.write {
            try seedSpace($0, id: "s1", target: "en")
            try seedSpace($0, id: "s2", target: "ja")
        }
        let repository = GRDBCompanionRepository(writer: database.writer)
        let t1 = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        let t2 = try repository.loadOrCreateThread(spaceID: "s2", id: "t2")
        try repository.appendMessage(
            threadID: t1.id, role: .user, content: "hello",
            detectedLanguage: "en", targetLanguageCode: "en", id: "u-en"
        )
        try repository.appendMessage(
            threadID: t2.id, role: .user, content: "こんにちは",
            detectedLanguage: "ja", targetLanguageCode: "ja", id: "u-ja"
        )
        #expect(try repository.productionUtterances(spaceID: "s1", after: nil).map(\.id) == ["u-en"])
        #expect(try repository.productionUtterances(spaceID: "s2", after: nil).map(\.id) == ["u-ja"])
    }
}
