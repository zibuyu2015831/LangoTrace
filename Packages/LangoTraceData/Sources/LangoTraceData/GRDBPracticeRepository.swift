import Foundation
import GRDB
import LangoTraceCore

public struct GRDBPracticeRepository: PracticeRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let diagnosticLogger: any DiagnosticLogging
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(
        database: AppDatabase,
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger(),
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        databaseQueue = database.databaseQueue
        self.diagnosticLogger = diagnosticLogger
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func createOrRestoreShadowingSession(
        languageSpaceID: String,
        snapshot: PracticeSentenceSnapshot
    ) async throws -> PracticeSession {
        try await databaseQueue.write { db in
            if let existing = try session(
                materialID: snapshot.learningMaterialID,
                sentenceID: snapshot.sentenceID,
                sentenceIndex: snapshot.sentenceIndex,
                exerciseType: snapshot.exerciseType,
                db: db
            ) {
                return try practiceSession(from: existing, db: db)
            }

            let id = idGenerator()
            let now = clock()
            try db.execute(
                sql: """
                INSERT INTO practice_sessions (
                    id, language_space_id, entry_id, learning_material_id, sentence_id,
                    sentence_index, target_text_snapshot, translation_snapshot, note_snapshot,
                    target_text_hash, target_language_code, source_entry_body_hash,
                    material_analysis_source_hash, exercise_type, status, problem_marked,
                    completed_recording_id, completed_at, created_at, updated_at, soft_deleted_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, NULL)
                """,
                arguments: [
                    id,
                    languageSpaceID,
                    snapshot.entryID,
                    snapshot.learningMaterialID,
                    snapshot.sentenceID,
                    snapshot.sentenceIndex,
                    snapshot.targetTextSnapshot,
                    snapshot.translationSnapshot,
                    snapshot.noteSnapshot,
                    snapshot.targetTextHash,
                    snapshot.targetLanguageCode,
                    snapshot.sourceEntryBodyHash,
                    snapshot.materialAnalysisSourceHash,
                    snapshot.exerciseType.rawValue,
                    PracticeSessionStatus.inProgress.rawValue,
                    false,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                ]
            )
            guard let inserted = try session(id: id, db: db) else {
                throw PracticeRepositoryError.sessionNotFound
            }
            return try practiceSession(from: inserted, db: db)
        }
    }

    public func session(id: String) async throws -> PracticeSession? {
        try await databaseQueue.read { db in
            guard let row = try session(id: id, db: db) else {
                return nil
            }
            return try practiceSession(from: row, db: db)
        }
    }

    public func completeSession(id: String, recordingID: String) async throws -> PracticeSession {
        try await databaseQueue.write { db in
            guard try readyRecordingExists(sessionID: id, recordingID: recordingID, db: db) else {
                throw PracticeRepositoryError.recordingNotReady
            }
            let now = clock()
            try db.execute(
                sql: """
                UPDATE practice_sessions
                SET status = ?,
                    completed_recording_id = COALESCE(completed_recording_id, ?),
                    completed_at = COALESCE(completed_at, ?),
                    updated_at = ?
                WHERE id = ? AND soft_deleted_at IS NULL
                """,
                arguments: [
                    PracticeSessionStatus.completed.rawValue,
                    recordingID,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                    id,
                ]
            )
            guard let row = try session(id: id, db: db) else {
                throw PracticeRepositoryError.sessionNotFound
            }
            return try practiceSession(from: row, db: db)
        }
    }

    public func readyRecordingArtifact(sessionID: String, recordingID: String) async throws -> MediaArtifact? {
        try await databaseQueue.read { db -> MediaArtifact? in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT media_artifacts.*
                FROM practice_recordings
                JOIN media_artifacts ON media_artifacts.id = practice_recordings.media_artifact_id
                WHERE practice_recordings.id = ?
                  AND practice_recordings.session_id = ?
                  AND practice_recordings.status = 'ready'
                  AND practice_recordings.invalidated_at IS NULL
                  AND media_artifacts.artifact_type = 'shadowingRecording'
                  AND media_artifacts.derivation_kind = 'practiceRecording'
                  AND media_artifacts.owner_type = 'practiceSession'
                  AND media_artifacts.owner_id = practice_recordings.session_id
                  AND media_artifacts.file_state = 'ready'
                  AND media_artifacts.invalidated_at IS NULL
                LIMIT 1
                """,
                arguments: [recordingID, sessionID]
            ) else {
                return nil
            }
            return mediaArtifact(from: row)
        }
    }

    public func completedSentenceIDs(
        materialID: String,
        exerciseType: PracticeExerciseType
    ) async throws -> Set<String> {
        try await databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT DISTINCT practice_sessions.sentence_id
                FROM practice_sessions
                WHERE practice_sessions.learning_material_id = ?
                  AND practice_sessions.exercise_type = ?
                  AND practice_sessions.sentence_id IS NOT NULL
                  AND practice_sessions.soft_deleted_at IS NULL
                  AND (
                    practice_sessions.status = 'completed'
                    OR EXISTS (
                        SELECT 1
                        FROM practice_recordings
                        WHERE practice_recordings.session_id = practice_sessions.id
                          AND practice_recordings.status = 'ready'
                          AND practice_recordings.invalidated_at IS NULL
                    )
                  )
                """,
                arguments: [materialID, exerciseType.rawValue]
            )
            return Set(rows.compactMap { row in row["sentence_id"] as String? })
        }
    }
}

public enum PracticeRepositoryError: Error, Equatable, Sendable {
    case sessionNotFound
    case recordingNotReady
}

private extension GRDBPracticeRepository {
    func session(id: String, db: Database) throws -> Row? {
        try Row.fetchOne(
            db,
            sql: "SELECT * FROM practice_sessions WHERE id = ? AND soft_deleted_at IS NULL",
            arguments: [id]
        )
    }

    func session(
        materialID: String,
        sentenceID: String?,
        sentenceIndex: Int,
        exerciseType: PracticeExerciseType,
        db: Database
    ) throws -> Row? {
        if let sentenceID {
            return try Row.fetchOne(
                db,
                sql: """
                SELECT * FROM practice_sessions
                WHERE learning_material_id = ?
                  AND sentence_id = ?
                  AND exercise_type = ?
                  AND soft_deleted_at IS NULL
                LIMIT 1
                """,
                arguments: [materialID, sentenceID, exerciseType.rawValue]
            )
        }
        return try Row.fetchOne(
            db,
            sql: """
            SELECT * FROM practice_sessions
            WHERE learning_material_id = ?
              AND sentence_id IS NULL
              AND sentence_index = ?
              AND exercise_type = ?
              AND soft_deleted_at IS NULL
            LIMIT 1
            """,
            arguments: [materialID, sentenceIndex, exerciseType.rawValue]
        )
    }

    func practiceSession(from row: Row, db: Database) throws -> PracticeSession {
        let exerciseType = StoredEnumDecoding.decode(
            PracticeExerciseType.self,
            from: row["exercise_type"] as String,
            fallback: .shadowing,
            context: "practice_sessions.exercise_type",
            diagnosticLogger: diagnosticLogger,
            clock: clock
        )
        let snapshot = PracticeSentenceSnapshot(
            entryID: row["entry_id"],
            learningMaterialID: row["learning_material_id"],
            sentenceID: row["sentence_id"],
            sentenceIndex: row["sentence_index"],
            targetTextSnapshot: row["target_text_snapshot"],
            targetTextHash: row["target_text_hash"],
            targetLanguageCode: row["target_language_code"],
            translationSnapshot: row["translation_snapshot"],
            noteSnapshot: row["note_snapshot"],
            sourceEntryBodyHash: row["source_entry_body_hash"],
            materialAnalysisSourceHash: row["material_analysis_source_hash"],
            exerciseType: exerciseType,
            capturedAt: Date(timeIntervalSince1970: row["created_at"])
        )
        var session = PracticeSession(
            id: row["id"],
            languageSpaceID: row["language_space_id"],
            snapshot: snapshot,
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"])
        )
        session.status = StoredEnumDecoding.decode(
            PracticeSessionStatus.self,
            from: row["status"] as String,
            fallback: .inProgress,
            context: "practice_sessions.status",
            diagnosticLogger: diagnosticLogger,
            clock: clock
        )
        session.problemMarked = (row["problem_marked"] as Int) == 1
        session.completedRecordingID = row["completed_recording_id"]
        session.completedAt = (row["completed_at"] as Double?).map(Date.init(timeIntervalSince1970:))
        session.readyRecordings = try readyRecordings(sessionID: session.id, db: db)
        if session.status == .completed {
            session.currentStep = .completion
        } else if !session.readyRecordings.isEmpty {
            session.currentStep = .completion
        }
        return session
    }

    func readyRecordings(sessionID: String, db: Database) throws -> [PracticeRecordingAttempt] {
        try Row.fetchAll(
            db,
            sql: """
            SELECT id, duration_seconds
            FROM practice_recordings
            WHERE session_id = ?
              AND status = 'ready'
              AND invalidated_at IS NULL
            ORDER BY attempt_number ASC
            """,
            arguments: [sessionID]
        ).map { row in
            PracticeRecordingAttempt(
                id: row["id"],
                durationSeconds: row["duration_seconds"] ?? 0
            )
        }
    }

    func readyRecordingExists(sessionID: String, recordingID: String, db: Database) throws -> Bool {
        let count = try Int.fetchOne(
            db,
            sql: """
            SELECT COUNT(*)
            FROM practice_recordings
            JOIN media_artifacts ON media_artifacts.id = practice_recordings.media_artifact_id
            WHERE practice_recordings.id = ?
              AND practice_recordings.session_id = ?
              AND practice_recordings.status = 'ready'
              AND practice_recordings.invalidated_at IS NULL
              AND media_artifacts.file_state = 'ready'
              AND media_artifacts.invalidated_at IS NULL
            """,
            arguments: [recordingID, sessionID]
        ) ?? 0
        return count > 0
    }

    func mediaArtifact(from row: Row) -> MediaArtifact {
        let policy = MediaArtifactPolicy(
            backupPolicy: MediaArtifactBackupPolicy(rawValue: row["backup_policy"] as String)
                ?? .excludedFromSystemBackup,
            syncPolicy: StoredEnumDecoding.decode(
                MediaArtifactSyncPolicy.self,
                from: row["sync_policy"] as String,
                fallback: .localOnly,
                context: "media_artifacts.sync_policy",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            exportPolicy: StoredEnumDecoding.decode(
                MediaArtifactExportPolicy.self,
                from: row["export_policy"] as String,
                fallback: .excludedByDefault,
                context: "media_artifacts.export_policy",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            )
        )
        return MediaArtifact(
            id: row["id"],
            languageSpaceID: row["language_space_id"],
            owner: owner(
                type: row["owner_type"],
                id: row["owner_id"],
                subID: row["owner_sub_id"]
            ),
            type: StoredEnumDecoding.decode(
                MediaArtifactType.self,
                from: row["artifact_type"] as String,
                fallback: .shadowingRecording,
                context: "media_artifacts.artifact_type",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            derivationKind: StoredEnumDecoding.decode(
                MediaArtifactDerivationKind.self,
                from: row["derivation_kind"] as String,
                fallback: .practiceRecording,
                context: "media_artifacts.derivation_kind",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            derivationKeyHash: row["derivation_key_hash"],
            relativeFilePath: row["relative_file_path"],
            mimeType: row["mime_type"],
            byteSize: row["byte_size"],
            durationSeconds: row["duration_seconds"],
            contentHash: row["content_hash"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            lastAccessedAt: Date(timeIntervalSince1970: row["last_accessed_at"]),
            invalidatedAt: (row["invalidated_at"] as Double?).map(Date.init(timeIntervalSince1970:)),
            deleteAfter: (row["delete_after"] as Double?).map(Date.init(timeIntervalSince1970:)),
            policy: policy
        )
    }

    func owner(type: String, id: String, subID: String?) -> MediaArtifactOwner {
        switch type {
        case "entry":
            .entry(id: id)
        case "learningMaterial":
            .learningMaterial(id: id)
        case "learningMaterialSentence":
            .learningMaterialSentence(materialID: id, sentenceIndex: Int(subID ?? "") ?? 0)
        case "practiceSession":
            .practiceSession(id: id)
        default:
            .temporaryOperation(id: id)
        }
    }
}
