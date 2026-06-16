import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("GRDB practice readiness query")
struct GRDBPracticeReadinessTests {
    @Test("Entry with current material but no practice session returns false")
    func noSessionReturnsFalse() throws {
        let (_, repo) = try makeRepositoryWithEntryAndMaterial()
        let readiness = try repo.learningPracticeReadiness(for: "space-1")
        #expect(readiness == ["entry-1": false])
    }

    @Test("Entry with in-progress session (no completed recording) returns false")
    func inProgressSessionReturnsFalse() throws {
        let (database, repo) = try makeRepositoryWithEntryAndMaterial()
        try database.databaseQueue.write { db in
            try insertPracticeSession(id: "session-1", entryID: "entry-1", db: db)
        }
        let readiness = try repo.learningPracticeReadiness(for: "space-1")
        #expect(readiness == ["entry-1": false])
    }

    @Test("Entry with completed recording returns true")
    func completedRecordingReturnsTrue() throws {
        let (database, repo) = try makeRepositoryWithEntryAndMaterial()
        try database.databaseQueue.write { db in
            try insertPracticeSession(id: "session-1", entryID: "entry-1", db: db)
            try insertMediaArtifact(id: "artifact-1", db: db)
            try insertPracticeRecording(id: "recording-1", sessionID: "session-1", artifactID: "artifact-1", db: db)
            try db.execute(
                sql: "UPDATE practice_sessions SET completed_recording_id = 'recording-1', status = 'completed', completed_at = 20 WHERE id = 'session-1'"
            )
        }
        let readiness = try repo.learningPracticeReadiness(for: "space-1")
        #expect(readiness == ["entry-1": true])
    }

    @Test("Entry without a current learning material is absent from readiness dict")
    func entryWithoutMaterialIsAbsent() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertLanguageSpace(id: "space-1", db: db)
            try insertEntry(id: "entry-1", spaceID: "space-1", db: db)
        }
        let repo = GRDBLearningContentRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: { "id-1" }
        )
        let readiness = try repo.learningPracticeReadiness(for: "space-1")
        #expect(readiness.isEmpty)
    }
}

// MARK: - Fixtures

private func makeRepositoryWithEntryAndMaterial() throws -> (AppDatabase, GRDBLearningContentRepository) {
    let database = try AppDatabase.inMemory()
    try database.databaseQueue.write { db in
        try insertLanguageSpace(id: "space-1", db: db)
        try insertEntry(id: "entry-1", spaceID: "space-1", db: db)
        try insertLearningMaterial(id: "material-1", entryID: "entry-1", db: db)
    }
    let repo = GRDBLearningContentRepository(
        database: database,
        clock: { Date(timeIntervalSince1970: 100) },
        idGenerator: { "id-1" }
    )
    return (database, repo)
}

private func insertLanguageSpace(id: String, db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO language_spaces (
            id, native_language_code, target_language_code, level,
            display_name, display_name_normalized, created_at, updated_at,
            last_opened_at, deleted_at
        ) VALUES (?, 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
        """,
        arguments: [id]
    )
}

private func insertEntry(id: String, spaceID: String, db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO entries (
            id, space_id, title, body, source, scene, created_at, updated_at, deleted_at
        ) VALUES (?, ?, 'Title', 'Body', 'typedText', '生活记录', 1, 1, NULL)
        """,
        arguments: [id, spaceID]
    )
}

private func insertLearningMaterial(id: String, entryID: String, db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO learning_materials (
            id, entry_id, space_id, input_kind, prompt_mode, learning_text,
            original_generated_text, source_entry_body_hash, analysis_source_hash,
            analysis_status, prompt_id, prompt_version, provider_profile_id,
            provider_endpoint_id, provider_preset_id, model_name, is_current,
            created_at, updated_at, deleted_at
        ) VALUES (
            ?, ?, 'space-1', 'nativeRecord', 'automaticLearningMaterial',
            'I went to a cafe today.', 'I went to a cafe today.',
            'source-hash', 'analysis-hash', 'fresh',
            'prompt', '1', 'profile-1', 'endpoint-1', 'openai',
            'gpt-4o-mini', 1, 1, 1, NULL
        )
        """,
        arguments: [id, entryID]
    )
}

private func insertPracticeSession(id: String, entryID: String, db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO practice_sessions (
            id, language_space_id, entry_id, learning_material_id, sentence_id,
            sentence_index, target_text_snapshot, translation_snapshot, note_snapshot,
            target_text_hash, target_language_code, source_entry_body_hash,
            material_analysis_source_hash, exercise_type, status, problem_marked,
            completed_recording_id, completed_at, created_at, updated_at, soft_deleted_at
        ) VALUES (
            ?, 'space-1', ?, 'material-1', NULL,
            0, 'I went to a cafe today.', NULL, NULL,
            'text-hash', 'en', NULL,
            NULL, 'shadowing', 'inProgress', 0,
            NULL, NULL, 10, 10, NULL
        )
        """,
        arguments: [id, entryID]
    )
}

private func insertMediaArtifact(id: String, db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO media_artifacts (
            id, language_space_id, owner_type, owner_id, owner_sub_id,
            artifact_type, derivation_kind, derivation_key_hash,
            relative_file_path, mime_type, byte_size, duration_seconds,
            content_hash, created_at, last_accessed_at, invalidated_at,
            delete_after, backup_policy, sync_policy, export_policy
        ) VALUES (
            ?, 'space-1', 'practiceSession', 'session-1', NULL,
            'shadowingRecording', 'practiceRecording', 'derivation-hash-1',
            'practice/recording-1.m4a', 'audio/m4a', 256, 1.5,
            'content-hash-1', 1, 1, NULL,
            NULL, 'excludedFromSystemBackup', 'localOnly', 'excludedByDefault'
        )
        """,
        arguments: [id]
    )
}

private func insertPracticeRecording(id: String, sessionID: String, artifactID: String, db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO practice_recordings (
            id, session_id, language_space_id, media_artifact_id, attempt_number,
            status, duration_seconds, byte_size, content_hash, created_at,
            ready_at, invalidated_at
        ) VALUES (?, ?, 'space-1', ?, 1, 'ready', 1.5, 256, 'content-hash-1', 10, 11, NULL)
        """,
        arguments: [id, sessionID, artifactID]
    )
}
