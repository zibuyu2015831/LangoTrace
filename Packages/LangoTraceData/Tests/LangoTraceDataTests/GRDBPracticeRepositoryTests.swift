import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("GRDB practice repository")
struct GRDBPracticeRepositoryTests {
    @Test("Repository creates shadowing session with sentence snapshot and restores after source sentence deletion")
    func repositoryCreatesSnapshotSessionAndRestoresAfterSentenceDeletion() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        try await MediaArtifactTestFixtures.seedPracticeSessionSourceSentence(in: database)
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: { "session-1" }
        )

        let created = try await repository.createOrRestoreShadowingSession(
            languageSpaceID: "space-1",
            snapshot: practiceSnapshot()
        )
        try await database.databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM learning_material_sentences WHERE id = 'sentence-1'")
        }
        let restored = try await repository.session(id: created.id)

        #expect(created.id == "session-1")
        #expect(restored?.snapshot.sentenceID == nil)
        #expect(restored?.snapshot.targetTextSnapshot == "I booked the train this morning.")
        #expect(restored?.snapshot.translationSnapshot == "我今天早上订了火车票。")
    }

    @Test("Repository completes only ready recordings and keeps completed recording stable")
    func repositoryCompletesOnlyReadyRecordingsAndKeepsCompletedRecordingStable() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        try await MediaArtifactTestFixtures.seedPracticeSessionSourceSentence(in: database)
        let repository = GRDBPracticeRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: { "session-1" }
        )
        let mediaRepository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let session = try await repository.createOrRestoreShadowingSession(
            languageSpaceID: "space-1",
            snapshot: practiceSnapshot()
        )
        let firstArtifact = try await mediaRepository.commitPracticeRecordingArtifact(
            MediaArtifactTestFixtures.practiceRecordingCommitInput()
        )
        _ = firstArtifact

        let completed = try await repository.completeSession(id: session.id, recordingID: "recording-1")
        _ = try await mediaRepository.commitPracticeRecordingArtifact(
            MediaArtifactTestFixtures.practiceRecordingCommitInput(
                key: MediaArtifactTestFixtures.practiceRecordingKey(recordingID: "recording-2", attemptNumber: 2),
                stagedFile: MediaArtifactStagedFileReference(
                    relativeStagingPath: "staging/practice-recording-2.tmp",
                    byteSize: 256,
                    contentHash: "practice-content-hash-2"
                )
            )
        )
        let restored = try await repository.session(id: session.id)

        #expect(completed.status == .completed)
        #expect(completed.completedRecordingID == "recording-1")
        #expect(restored?.completedRecordingID == "recording-1")
        #expect(restored?.latestReadyRecordingID == "recording-2")
    }

    @Test("Repository resolves ready practice recording artifact for playback")
    func repositoryResolvesReadyPracticeRecordingArtifactForPlayback() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        try await MediaArtifactTestFixtures.seedPracticeSession(in: database)
        let repository = GRDBPracticeRepository(database: database)
        let mediaRepository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let artifact = try await mediaRepository.commitPracticeRecordingArtifact(
            MediaArtifactTestFixtures.practiceRecordingCommitInput()
        )

        let resolved = try await repository.readyRecordingArtifact(
            sessionID: "session-1",
            recordingID: "recording-1"
        )

        #expect(resolved?.id == artifact.id)
        #expect(resolved?.type == .shadowingRecording)
        #expect(resolved?.derivationKind == .practiceRecording)
    }

    @Test("Repository lists completed sentence ids by material and exercise type")
    func repositoryListsCompletedSentenceIDsByMaterialAndExerciseType() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        try await MediaArtifactTestFixtures.seedPracticeSessionSourceSentences(in: database, count: 3)
        let repository = GRDBPracticeRepository(database: database)
        try await database.databaseQueue.write { db in
            try insertPracticeSession(
                id: "session-shadowing-1",
                sentenceID: "sentence-1",
                sentenceIndex: 0,
                exerciseType: .shadowing,
                status: .completed,
                db: db
            )
            try insertPracticeSession(
                id: "session-shadowing-2",
                sentenceID: "sentence-2",
                sentenceIndex: 1,
                exerciseType: .shadowing,
                status: .completed,
                db: db
            )
            try insertPracticeSession(
                id: "session-dictation-1",
                sentenceID: "sentence-1",
                sentenceIndex: 0,
                exerciseType: .dictation,
                status: .completed,
                db: db
            )
            try insertPracticeSession(
                id: "session-shadowing-active",
                sentenceID: "sentence-3",
                sentenceIndex: 2,
                exerciseType: .shadowing,
                status: .inProgress,
                db: db
            )
        }

        let shadowing = try await repository.completedSentenceIDs(
            materialID: "material-1",
            exerciseType: .shadowing
        )
        let dictation = try await repository.completedSentenceIDs(
            materialID: "material-1",
            exerciseType: .dictation
        )

        #expect(shadowing == ["sentence-1", "sentence-2"])
        #expect(dictation == ["sentence-1"])
    }

    @Test("Repository rejects ready recording artifacts with non practice derivation")
    func repositoryRejectsReadyRecordingArtifactsWithNonPracticeDerivation() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        try await MediaArtifactTestFixtures.seedPracticeSession(in: database)
        let repository = GRDBPracticeRepository(database: database)
        let mediaRepository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let artifact = try await mediaRepository.commitPracticeRecordingArtifact(
            MediaArtifactTestFixtures.practiceRecordingCommitInput()
        )
        try await database.databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE media_artifacts
                SET derivation_kind = 'ttsAudio'
                WHERE id = ?
                """,
                arguments: [artifact.id]
            )
        }

        let resolved = try await repository.readyRecordingArtifact(
            sessionID: "session-1",
            recordingID: "recording-1"
        )

        #expect(resolved == nil)
    }
}

private func practiceSnapshot() -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: 0,
        targetTextSnapshot: "I booked the train this morning.",
        targetTextHash: "target-hash-1",
        targetLanguageCode: "en",
        translationSnapshot: "我今天早上订了火车票。",
        noteSnapshot: "booked 表示已经完成预订。",
        sourceEntryBodyHash: "source-hash",
        materialAnalysisSourceHash: "analysis-hash",
        exerciseType: .shadowing,
        capturedAt: Date(timeIntervalSince1970: 100)
    )
}

private func insertPracticeSession(
    id: String,
    sentenceID: String,
    sentenceIndex: Int,
    exerciseType: PracticeExerciseType,
    status: PracticeSessionStatus,
    db: Database
) throws {
    try db.execute(
        sql: """
        INSERT INTO practice_sessions (
            id, language_space_id, entry_id, learning_material_id, sentence_id,
            sentence_index, target_text_snapshot, translation_snapshot, note_snapshot,
            target_text_hash, target_language_code, source_entry_body_hash,
            material_analysis_source_hash, exercise_type, status, problem_marked,
            completed_recording_id, completed_at, created_at, updated_at, soft_deleted_at
        ) VALUES (?, 'space-1', 'entry-1', 'material-1', ?, ?, 'Target', '译文', 'Note',
            'target-hash', 'en', 'source-hash', 'analysis-hash', ?, ?, 0,
            NULL, ?, 100, 100, NULL)
        """,
        arguments: [
            id,
            sentenceID,
            sentenceIndex,
            exerciseType.rawValue,
            status.rawValue,
            status == .completed ? 100.0 : nil,
        ]
    )
}

private extension MediaArtifactTestFixtures {
    static func seedPracticeSessionSourceSentences(in database: AppDatabase, count: Int) async throws {
        try await database.databaseQueue.write { db in
            for index in 1 ... count {
                try db.execute(
                    sql: """
                    INSERT INTO learning_material_sentences (
                        id, material_id, position, native_sentence, target_sentence,
                        literal_translation, natural_translation, grammar_notes_json,
                        key_points_json, created_at, updated_at
                    ) VALUES (?, 'material-1', ?, ?, ?, ?, ?, '[]', '[]', 1, 1)
                    """,
                    arguments: [
                        "sentence-\(index)",
                        index - 1,
                        "原文 \(index)",
                        "Target sentence \(index).",
                        "Target sentence \(index).",
                        "译文 \(index)",
                    ]
                )
            }
        }
    }

    static func seedPracticeSessionSourceSentence(in database: AppDatabase) async throws {
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
    }
}
