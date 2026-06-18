import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("GRDB practice text attempt repository (听写/回译作答)")
struct PracticeTextAttemptRepositoryTests {
    @Test("Migration creates practice_text_attempts table with the expected columns")
    func migrationCreatesPracticeTextAttemptsTable() async throws {
        let database = try AppDatabase.inMemory()
        let columns = try await database.databaseQueue.read { db in
            try Set(Row.fetchAll(db, sql: "PRAGMA table_info(practice_text_attempts)").compactMap { row in
                row["name"] as String?
            })
        }
        let expected: Set = [
            "id", "session_id", "language_space_id", "exercise_type", "attempt_number",
            "attempt_text", "reference_text_snapshot", "diff_difference_count",
            "diff_summary_json", "listen_count", "created_at", "soft_deleted_at",
        ]
        #expect(expected.isSubset(of: columns))
    }

    @Test("Repository creates and restores a dictation session via the generalized seam")
    func repositoryCreatesDictationSessionViaGeneralizedSeam() async throws {
        let database = try await makeSeededDatabase()
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: { "dictation-session-1" }
        )

        let created = try await repository.createOrRestoreSession(
            languageSpaceID: "space-1",
            snapshot: dictationSnapshot()
        )

        #expect(created.id == "dictation-session-1")
        #expect(created.exerciseType == .dictation)
    }

    @Test("Recording text attempts assigns incrementing attempt numbers and reports the latest")
    func recordsTextAttemptsWithIncrementingAttemptNumber() async throws {
        let database = try await makeSeededDatabase()
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator(prefix: "attempt").next
        )
        let session = try await repository.createOrRestoreSession(
            languageSpaceID: "space-1",
            snapshot: dictationSnapshot()
        )

        let first = try await repository.recordTextAttempt(
            draft: attemptDraft(sessionID: session.id, text: "I booked the train this morning", differenceCount: 0)
        )
        let second = try await repository.recordTextAttempt(
            draft: attemptDraft(sessionID: session.id, text: "I book the train", differenceCount: 2)
        )
        let latest = try await repository.latestTextAttempt(sessionID: session.id)

        #expect(first.attemptNumber == 1)
        #expect(second.attemptNumber == 2)
        #expect(latest?.attemptNumber == 2)
        #expect(latest?.attemptText == "I book the train")
        #expect(latest?.diffDifferenceCount == 2)
    }

    @Test("Dictation completed sentences derive from a submitted attempt, not a recording")
    func dictationCompletedSentencesDeriveFromAttempt() async throws {
        let database = try await makeSeededDatabase()
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator(prefix: "session").next
        )
        let session = try await repository.createOrRestoreSession(
            languageSpaceID: "space-1",
            snapshot: dictationSnapshot()
        )
        _ = try await repository.recordTextAttempt(
            draft: attemptDraft(sessionID: session.id, text: "I booked the train this morning", differenceCount: 0)
        )

        let dictationDone = try await repository.completedSentenceIDs(
            materialID: "material-1",
            exerciseType: .dictation
        )
        let shadowingDone = try await repository.completedSentenceIDs(
            materialID: "material-1",
            exerciseType: .shadowing
        )

        #expect(dictationDone == ["sentence-1"])
        #expect(shadowingDone.isEmpty)
    }

    @Test("Soft-deleted attempts are excluded from latest and from completion derivation")
    func softDeletedAttemptsAreExcluded() async throws {
        let database = try await makeSeededDatabase()
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator(prefix: "only").next
        )
        let session = try await repository.createOrRestoreSession(
            languageSpaceID: "space-1",
            snapshot: dictationSnapshot()
        )
        let attempt = try await repository.recordTextAttempt(
            draft: attemptDraft(sessionID: session.id, text: "I booked the train this morning", differenceCount: 0)
        )
        try await database.databaseQueue.write { db in
            try db.execute(
                sql: "UPDATE practice_text_attempts SET soft_deleted_at = 1 WHERE id = ?",
                arguments: [attempt.id]
            )
        }

        let latest = try await repository.latestTextAttempt(sessionID: session.id)
        let dictationDone = try await repository.completedSentenceIDs(
            materialID: "material-1",
            exerciseType: .dictation
        )

        #expect(latest == nil)
        #expect(dictationDone.isEmpty)
    }

    @Test("Backtranslation attempts store null diff fields")
    func backtranslationAttemptStoresNullDiff() async throws {
        let database = try await makeSeededDatabase()
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator(prefix: "bt").next
        )
        let session = try await repository.createOrRestoreSession(
            languageSpaceID: "space-1",
            snapshot: dictationSnapshot(exerciseType: .backtranslation)
        )
        let attempt = try await repository.recordTextAttempt(
            draft: PracticeTextAttemptDraft(
                sessionID: session.id,
                languageSpaceID: "space-1",
                exerciseType: .backtranslation,
                attemptText: "I booked it",
                referenceTextSnapshot: "I booked the train this morning.",
                diffDifferenceCount: nil,
                diffSummaryJSON: nil,
                listenCount: 0
            )
        )

        #expect(attempt.diffDifferenceCount == nil)
        #expect(attempt.diffSummaryJSON == nil)
    }

    @Test("Backtranslation diff columns are forced NULL by the repository even if a draft carries them")
    func backtranslationRepositoryForcesNullDiffEvenWhenDraftCarriesIt() async throws {
        let database = try await makeSeededDatabase()
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator(prefix: "bt").next
        )
        let session = try await repository.createOrRestoreSession(
            languageSpaceID: "space-1",
            snapshot: dictationSnapshot(exerciseType: .backtranslation)
        )

        // A misbehaving caller passes non-nil diff fields and a listen count;
        // "回译不判对错" is a North-Star boundary, so the repository (the sole
        // write path) must neutralize them regardless of the caller.
        let attempt = try await repository.recordTextAttempt(
            draft: PracticeTextAttemptDraft(
                sessionID: session.id,
                languageSpaceID: "space-1",
                exerciseType: .backtranslation,
                attemptText: "I booked it",
                referenceTextSnapshot: "I booked the train this morning.",
                diffDifferenceCount: 5,
                diffSummaryJSON: "{\"differenceCount\":5,\"segments\":[]}",
                listenCount: 3
            )
        )

        #expect(attempt.diffDifferenceCount == nil)
        #expect(attempt.diffSummaryJSON == nil)
        #expect(attempt.listenCount == 0)

        // Extract Sendable values inside the read closure; GRDB's `Row` is not
        // Sendable and must not cross the async boundary.
        let stored = try await database.databaseQueue.read { db -> (Int?, String?, Int?) in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT diff_difference_count, diff_summary_json, listen_count FROM practice_text_attempts WHERE id = ?",
                arguments: [attempt.id]
            ) else {
                return (nil, nil, nil)
            }
            return (row["diff_difference_count"], row["diff_summary_json"], row["listen_count"])
        }
        #expect(stored.0 == nil)
        #expect(stored.1 == nil)
        #expect(stored.2 == 0)
    }

    @Test("Backtranslation completed sentences derive from an attempt and stay isolated from other modes")
    func backtranslationCompletedSentencesAreIsolatedByMode() async throws {
        let database = try await makeSeededDatabase()
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: SequentialIDGenerator(prefix: "session").next
        )
        let session = try await repository.createOrRestoreSession(
            languageSpaceID: "space-1",
            snapshot: dictationSnapshot(exerciseType: .backtranslation)
        )
        _ = try await repository.recordTextAttempt(
            draft: PracticeTextAttemptDraft(
                sessionID: session.id,
                languageSpaceID: "space-1",
                exerciseType: .backtranslation,
                attemptText: "I booked it",
                referenceTextSnapshot: "I booked the train this morning.",
                diffDifferenceCount: nil,
                diffSummaryJSON: nil,
                listenCount: 0
            )
        )

        let backtranslationDone = try await repository.completedSentenceIDs(
            materialID: "material-1",
            exerciseType: .backtranslation
        )
        let shadowingDone = try await repository.completedSentenceIDs(
            materialID: "material-1",
            exerciseType: .shadowing
        )
        let dictationDone = try await repository.completedSentenceIDs(
            materialID: "material-1",
            exerciseType: .dictation
        )

        #expect(backtranslationDone == ["sentence-1"])
        #expect(shadowingDone.isEmpty)
        #expect(dictationDone.isEmpty)
    }

    @Test("Recording an attempt for a missing session fails without writing a row")
    func recordingAttemptForMissingSessionFails() async throws {
        let database = try await makeSeededDatabase()
        let repository = GRDBPracticeRepository(database: database)

        await #expect(throws: (any Error).self) {
            _ = try await repository.recordTextAttempt(
                draft: attemptDraft(sessionID: "missing-session", text: "x", differenceCount: 0)
            )
        }
        let count = try await database.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM practice_text_attempts") ?? 0
        }
        #expect(count == 0)
    }
}

private func makeSeededDatabase() async throws -> AppDatabase {
    let database = try AppDatabase.inMemory()
    try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
    try await database.databaseQueue.write { db in
        try db.execute(
            sql: """
            INSERT INTO learning_material_sentences (
                id, material_id, position, native_sentence, target_sentence,
                literal_translation, natural_translation, grammar_notes_json,
                key_points_json, created_at, updated_at
            ) VALUES (
                'sentence-1', 'material-1', 0, '我今天早上订了火车票。',
                'I booked the train this morning.', 'I booked the train this morning.',
                '我今天早上订了火车票。', '[]', '[]', 1, 1
            )
            """
        )
    }
    return database
}

private func dictationSnapshot(exerciseType: PracticeExerciseType = .dictation) -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: 0,
        targetTextSnapshot: "I booked the train this morning.",
        targetTextHash: "target-hash-1",
        targetLanguageCode: "en",
        translationSnapshot: "我今天早上订了火车票。",
        noteSnapshot: nil,
        sourceEntryBodyHash: "source-hash",
        materialAnalysisSourceHash: "analysis-hash",
        exerciseType: exerciseType,
        capturedAt: Date(timeIntervalSince1970: 100)
    )
}

private func attemptDraft(sessionID: String, text: String, differenceCount: Int) -> PracticeTextAttemptDraft {
    PracticeTextAttemptDraft(
        sessionID: sessionID,
        languageSpaceID: "space-1",
        exerciseType: .dictation,
        attemptText: text,
        referenceTextSnapshot: "I booked the train this morning.",
        diffDifferenceCount: differenceCount,
        diffSummaryJSON: "{\"differenceCount\":\(differenceCount),\"segments\":[]}",
        listenCount: 1
    )
}

private final class SequentialIDGenerator: @unchecked Sendable {
    private let prefix: String
    private var counter = 0
    private let lock = NSLock()

    init(prefix: String) {
        self.prefix = prefix
    }

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return "\(prefix)-\(counter)"
    }
}
