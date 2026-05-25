import Foundation
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

private extension MediaArtifactTestFixtures {
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
