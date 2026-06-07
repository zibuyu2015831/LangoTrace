import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Test("AppDatabase in-memory factory owns language space migrations")
func appDatabaseInMemoryFactoryOwnsLanguageSpaceMigrations() throws {
    let clock = FixedClock(epochSeconds: 100)
    let database = try AppDatabase.inMemory()
    let repository = GRDBLanguageSpaceRepository(
        database: database,
        clock: clock.now,
        idGenerator: { "space-1" }
    )

    let created = try repository.createLanguageSpace(
        input: CreateLanguageSpaceInput(
            nativeLanguageCode: "zh-Hans",
            targetLanguageCode: "en",
            level: .a2,
            displayName: "English"
        )
    )

    #expect(created.id == "space-1")
    #expect(try repository.currentLanguageSpace()?.id == "space-1")
}

@Test("AppDatabase persistent factory creates the parent directory")
func appDatabasePersistentFactoryCreatesParentDirectory() throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("nested", isDirectory: true)
        .appendingPathComponent("LangoTrace.sqlite")

    _ = try AppDatabase.persistent(at: databaseURL)

    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
        atPath: databaseURL.deletingLastPathComponent().path,
        isDirectory: &isDirectory
    )
    #expect(exists)
    #expect(isDirectory.boolValue)
}

@Test("Media artifact migration creates metadata tables constraints and active key uniqueness")
func mediaArtifactMigrationCreatesTablesConstraintsAndActiveKeyUniqueness() throws {
    let database = try AppDatabase.inMemory()

    try database.databaseQueue.write { db in
        let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        #expect(tables.contains("media_artifacts"))
        #expect(tables.contains("tts_audio_artifacts"))

        try insertMediaArtifactPrerequisites(db)
        try insertMediaArtifactRow(id: "artifact-1", db: db)

        let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(media_artifacts)")
            .map { $0["name"] as String }
        #expect(columns.contains("file_state"))

        #expect(throws: DatabaseError.self) {
            try insertMediaArtifactRow(id: "artifact-duplicate", db: db)
        }

        try db.execute(
            sql: "UPDATE media_artifacts SET invalidated_at = 200 WHERE id = 'artifact-1'"
        )
        try insertMediaArtifactRow(id: "artifact-2", db: db)

        #expect(throws: DatabaseError.self) {
            try insertMediaArtifactRow(
                id: "artifact-invalid-policy",
                backupPolicy: "invalid",
                derivationKeyHash: "different-hash",
                db: db
            )
        }

        #expect(throws: DatabaseError.self) {
            try insertMediaArtifactRow(
                id: "artifact-invalid-type",
                artifactType: "unknown",
                derivationKeyHash: "different-hash-2",
                db: db
            )
        }

        try db.execute(
            sql: """
            INSERT INTO tts_audio_artifacts (
                artifact_id, sentence_source_type, entry_id, learning_material_id,
                operation_id, sentence_index, sentence_text_hash, target_language_code,
                provider_profile_id, tts_endpoint_id, tts_voice_profile_id,
                adapter_kind, adapter_version, model_name, voice_id_hash,
                output_format, sample_rate, speed, pitch, volume,
                instructions_hash, provider_parameters_hash, configuration_fingerprint
            ) VALUES (
                'artifact-2', 'learningMaterialSentence', 'entry-1', 'material-1', NULL,
                0, 'sentence-hash', 'en', 'profile-1', 'endpoint-tts',
                'voice-en', 'openai_audio_speech', '2026-05-23',
                'tts-1', 'voice-hash', 'mp3', NULL, 1.0, NULL,
                NULL, NULL, NULL, 'fingerprint'
            )
            """
        )
        try db.execute(sql: "DELETE FROM media_artifacts WHERE id = 'artifact-2'")
        let ttsRows = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tts_audio_artifacts") ?? -1
        #expect(ttsRows == 0)

        #expect(throws: DatabaseError.self) {
            try insertMediaArtifactRow(id: "artifact-missing-space", languageSpaceID: "missing-space", db: db)
        }
    }
}

@Test("Media artifact v8 migration upgrades legacy v7 metadata tables")
func mediaArtifactV8MigrationUpgradesLegacyV7MetadataTables() throws {
    let queue = try DatabaseQueue()
    try migrateMinimalLegacyMediaArtifactV7(queue)

    _ = try AppDatabase(databaseQueue: queue)

    try queue.read { db in
        let mediaColumns = try Row.fetchAll(db, sql: "PRAGMA table_info(media_artifacts)")
            .map { $0["name"] as String }
        let ttsColumns = try Row.fetchAll(db, sql: "PRAGMA table_info(tts_audio_artifacts)")
            .map { $0["name"] as String }
        #expect(mediaColumns.contains("file_state"))
        #expect(ttsColumns.contains("operation_id"))
    }
}

@Test("Practice recording migration creates snapshot sessions recordings and typed artifact metadata")
func practiceRecordingMigrationCreatesSnapshotSessionsRecordingsAndTypedArtifactMetadata() throws {
    let database = try AppDatabase.inMemory()

    try database.databaseQueue.write { db in
        let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        #expect(tables.contains("practice_sessions"))
        #expect(tables.contains("practice_recordings"))
        #expect(tables.contains("practice_recording_artifacts"))

        try insertMediaArtifactPrerequisites(db)
        try insertLearningMaterialSentence(db)
        try insertPracticeSession(db)
        try insertMediaArtifactRow(
            id: "artifact-practice-1",
            artifactType: "shadowingRecording",
            derivationKind: "practiceRecording",
            derivationKeyHash: "practice-recording-key",
            db: db
        )
        try insertPracticeRecording(db)
        try db.execute(
            sql: """
            UPDATE practice_sessions
            SET completed_recording_id = 'recording-1', status = 'completed', completed_at = 20
            WHERE id = 'session-1'
            """
        )
        try insertPracticeRecordingArtifact(db)

        try db.execute(sql: "DELETE FROM learning_material_sentences WHERE id = 'sentence-1'")
        let session = try Row.fetchOne(db, sql: "SELECT * FROM practice_sessions WHERE id = 'session-1'")

        #expect(session?["sentence_id"] as String? == nil)
        #expect(session?["target_text_snapshot"] as String? == "I booked the train this morning.")
        #expect(session?["exercise_type"] as String? == "shadowing")
        #expect(session?["completed_recording_id"] as String? == "recording-1")
    }
}

@Test("Legacy media artifact derivation constraint is relaxed for practice recordings")
func legacyMediaArtifactDerivationConstraintIsRelaxedForPracticeRecordings() throws {
    let queue = try DatabaseQueue()

    try migrateLegacyRestrictiveMediaArtifactV9(queue)
    _ = try AppDatabase(databaseQueue: queue)

    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO language_spaces (
                id, native_language_code, target_language_code, level,
                display_name, display_name_normalized, created_at, updated_at,
                last_opened_at, deleted_at
            ) VALUES ('space-1', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
            """
        )
        try db.execute(
            sql: """
            INSERT INTO media_artifacts (
                id, language_space_id, owner_type, owner_id, owner_sub_id,
                artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
                mime_type, byte_size, duration_seconds, content_hash, created_at,
                last_accessed_at, invalidated_at, delete_after, backup_policy,
                sync_policy, export_policy, file_state
            ) VALUES (
                'recording-artifact-1', 'space-1', 'practiceSession', 'session-1', NULL,
                'shadowingRecording', 'practiceRecording', 'practice-key',
                'shadowingRecording/en/recording-artifact-1.m4a', 'audio/mp4',
                1024, 1.5, 'hash', 1, 1, NULL, NULL, 'excludedFromSystemBackup',
                'localOnly', 'excludedByDefault', 'ready'
            )
            """
        )
        let failures = try Row.fetchAll(db, sql: "PRAGMA foreign_key_check")
        #expect(failures.isEmpty)
    }
}

private final class FixedClock: @unchecked Sendable {
    private let epochSeconds: TimeInterval

    init(epochSeconds: TimeInterval) {
        self.epochSeconds = epochSeconds
    }

    func now() -> Date {
        Date(timeIntervalSince1970: epochSeconds)
    }
}

private func migrateMinimalLegacyMediaArtifactV7(_ queue: DatabaseQueue) throws {
    var migrator = DatabaseMigrator()
    for migration in [
        "v1_create_language_space_infrastructure",
        "v2_create_ai_provider_configuration",
        "v3_create_diagnostic_events",
        "v4_create_learning_content_infrastructure",
        "v5_add_learning_material_source_entry_body_hash",
        "v6_create_ai_provider_tts_configuration",
    ] {
        migrator.registerMigration(migration) { _ in }
    }
    migrator.registerMigration("v7_create_media_artifact_infrastructure") { db in
        try db.execute(sql: """
        CREATE TABLE media_artifacts (
          id TEXT PRIMARY KEY,
          language_space_id TEXT NOT NULL,
          owner_type TEXT NOT NULL,
          owner_id TEXT NOT NULL,
          owner_sub_id TEXT,
          artifact_type TEXT NOT NULL,
          derivation_kind TEXT NOT NULL,
          derivation_key_hash TEXT NOT NULL,
          relative_file_path TEXT NOT NULL,
          mime_type TEXT NOT NULL,
          byte_size INTEGER NOT NULL,
          duration_seconds REAL,
          content_hash TEXT NOT NULL,
          created_at REAL NOT NULL,
          last_accessed_at REAL NOT NULL,
          invalidated_at REAL,
          delete_after REAL,
          backup_policy TEXT NOT NULL,
          sync_policy TEXT NOT NULL,
          export_policy TEXT NOT NULL
        )
        """)
        try db.execute(sql: """
        CREATE TABLE tts_audio_artifacts (
          artifact_id TEXT PRIMARY KEY REFERENCES media_artifacts(id) ON DELETE CASCADE,
          sentence_source_type TEXT NOT NULL,
          entry_id TEXT,
          learning_material_id TEXT,
          sentence_index INTEGER,
          sentence_text_hash TEXT NOT NULL,
          target_language_code TEXT NOT NULL,
          provider_profile_id TEXT NOT NULL,
          tts_endpoint_id TEXT NOT NULL,
          tts_voice_profile_id TEXT NOT NULL,
          adapter_kind TEXT NOT NULL,
          adapter_version TEXT NOT NULL,
          model_name TEXT NOT NULL,
          voice_id_hash TEXT NOT NULL,
          output_format TEXT NOT NULL,
          sample_rate INTEGER,
          speed REAL,
          pitch REAL,
          volume REAL,
          instructions_hash TEXT,
          provider_parameters_hash TEXT,
          configuration_fingerprint TEXT NOT NULL
        )
        """)
    }
    try migrator.migrate(queue)
}

private func migrateLegacyRestrictiveMediaArtifactV9(_ queue: DatabaseQueue) throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1_create_language_space_infrastructure") { db in
        try createLegacyLanguageSpacesTable(db)
    }
    for migration in [
        "v2_create_ai_provider_configuration",
        "v3_create_diagnostic_events",
        "v4_create_learning_content_infrastructure",
        "v5_add_learning_material_source_entry_body_hash",
        "v6_create_ai_provider_tts_configuration",
    ] {
        migrator.registerMigration(migration) { _ in }
    }
    migrator.registerMigration("v7_create_media_artifact_infrastructure") { db in
        try createLegacyRestrictiveMediaArtifactTables(db)
    }
    migrator.registerMigration("v8_add_media_artifact_file_state") { db in
        try db.execute(sql: """
        ALTER TABLE media_artifacts
        ADD COLUMN file_state TEXT NOT NULL DEFAULT 'ready'
        CHECK (file_state IN ('pending', 'ready'))
        """)
    }
    migrator.registerMigration("v9_create_practice_recording_infrastructure") { db in
        try createLegacyPracticeRecordingTables(db)
    }
    try migrator.migrate(queue)
}

private func createLegacyLanguageSpacesTable(_ db: Database) throws {
    try db.execute(sql: """
    CREATE TABLE language_spaces (
      id TEXT PRIMARY KEY,
      native_language_code TEXT NOT NULL,
      target_language_code TEXT NOT NULL,
      level TEXT NOT NULL,
      display_name TEXT NOT NULL,
      display_name_normalized TEXT NOT NULL,
      created_at REAL NOT NULL,
      updated_at REAL NOT NULL,
      last_opened_at REAL,
      deleted_at REAL
    )
    """)
}

private func createLegacyRestrictiveMediaArtifactTables(_ db: Database) throws {
    try db.execute(sql: """
    CREATE TABLE media_artifacts (
      id TEXT PRIMARY KEY,
      language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
      owner_type TEXT NOT NULL,
      owner_id TEXT NOT NULL,
      owner_sub_id TEXT,
      artifact_type TEXT NOT NULL,
      derivation_kind TEXT NOT NULL,
      derivation_key_hash TEXT NOT NULL,
      relative_file_path TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      byte_size INTEGER NOT NULL,
      duration_seconds REAL,
      content_hash TEXT NOT NULL,
      created_at REAL NOT NULL,
      last_accessed_at REAL NOT NULL,
      invalidated_at REAL,
      delete_after REAL,
      backup_policy TEXT NOT NULL,
      sync_policy TEXT NOT NULL,
      export_policy TEXT NOT NULL,
      CHECK (byte_size >= 0),
      CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
      CHECK (artifact_type IN (
        'ttsSentenceAudio', 'ttsDocumentAudio', 'shadowingRecording',
        'dictationRecording', 'ocrIntermediate', 'exportTemporary'
      )),
      CHECK (derivation_kind IN ('ttsAudio')),
      CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
      CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
      CHECK (export_policy IN (
        'excludedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'
      ))
    )
    """)
    try createLegacyMediaArtifactExtensionTablesAndIndexes(db)
}

private func createLegacyMediaArtifactExtensionTablesAndIndexes(_ db: Database) throws {
    try db.execute(sql: """
    CREATE TABLE tts_audio_artifacts (
      artifact_id TEXT PRIMARY KEY REFERENCES media_artifacts(id) ON DELETE CASCADE
    )
    """)
    try db.execute(sql: """
    CREATE UNIQUE INDEX idx_media_artifacts_active_derivation_key
    ON media_artifacts(artifact_type, derivation_kind, derivation_key_hash)
    WHERE invalidated_at IS NULL
    """)
    try db.execute(sql: """
    CREATE INDEX idx_media_artifacts_language_type_accessed
    ON media_artifacts(language_space_id, artifact_type, invalidated_at, last_accessed_at)
    """)
    try db.execute(sql: """
    CREATE INDEX idx_media_artifacts_owner
    ON media_artifacts(owner_type, owner_id, owner_sub_id, invalidated_at)
    """)
}

private func createLegacyPracticeRecordingTables(_ db: Database) throws {
    try db.execute(sql: """
    CREATE TABLE practice_sessions (
      id TEXT PRIMARY KEY,
      language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE
    )
    """)
    try db.execute(sql: """
    CREATE TABLE practice_recordings (
      id TEXT PRIMARY KEY,
      media_artifact_id TEXT NOT NULL REFERENCES media_artifacts(id) ON DELETE RESTRICT
    )
    """)
    try db.execute(sql: """
    CREATE TABLE practice_recording_artifacts (
      artifact_id TEXT PRIMARY KEY REFERENCES media_artifacts(id) ON DELETE CASCADE
    )
    """)
}

private func insertMediaArtifactPrerequisites(_ db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO language_spaces (
            id, native_language_code, target_language_code, level,
            display_name, display_name_normalized, created_at, updated_at,
            last_opened_at, deleted_at
        ) VALUES ('space-1', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
        """
    )
    try db.execute(
        sql: """
        INSERT INTO ai_provider_profiles (
            id, display_name, is_default, status, created_at, updated_at, last_validated_at,
            last_validation_status, deleted_at
        ) VALUES ('profile-1', 'Default', 1, 'configured', 1, 1, NULL, NULL, NULL)
        """
    )
    try db.execute(
        sql: """
        INSERT INTO ai_provider_endpoints (
            id, profile_id, purpose, is_enabled, provider_preset_id, adapter_kind,
            base_url, model_name, credential_id, supports_image_input, image_input_enabled,
            request_timeout_seconds, created_at, updated_at, deleted_at
        ) VALUES (
            'endpoint-tts', 'profile-1', 'tts', 1, 'openai', 'openAIResponses',
            'https://api.openai.com/v1', 'tts-1', NULL, 0, 0, NULL, 1, 1, NULL
        )
        """
    )
    try db.execute(
        sql: """
        INSERT INTO ai_provider_tts_voice_profiles (
            id, endpoint_id, language_code, tts_adapter_kind, model_name, voice_id,
            voice_display_name, output_format, sample_rate, speed, volume, pitch,
            style_prompt, instructions, streaming_mode, provider_parameters_json,
            configuration_fingerprint, last_successful_configuration_fingerprint,
            last_test_status, last_test_error_category, last_tested_at, created_at, updated_at
        ) VALUES (
            'voice-en', 'endpoint-tts', 'en', 'openai_audio_speech', 'tts-1',
            'alloy', NULL, 'mp3', NULL, 1.0, NULL, NULL, NULL, NULL, 0, '{}',
            'fingerprint', 'fingerprint', 'succeeded', NULL, 1, 1, 1
        )
        """
    )
    try db.execute(
        sql: """
        INSERT INTO entries (
            id, space_id, title, body, source, scene, created_at, updated_at, deleted_at
        ) VALUES ('entry-1', 'space-1', 'Title', 'Body', 'typedText', '生活记录', 1, 1, NULL)
        """
    )
    try db.execute(
        sql: """
        INSERT INTO learning_materials (
            id, entry_id, space_id, input_kind, prompt_mode, learning_text,
            original_generated_text, source_entry_body_hash, analysis_source_hash,
            analysis_status, prompt_id, prompt_version, provider_profile_id,
            provider_endpoint_id, provider_preset_id, model_name, is_current,
            created_at, updated_at, deleted_at
        ) VALUES (
            'material-1', 'entry-1', 'space-1', 'nativeRecord', 'automaticLearningMaterial',
            'Learning text', 'Learning text', 'source-hash', 'analysis-hash',
            'fresh', 'prompt', '1', 'profile-1', 'endpoint-tts', 'openai',
            'gpt-4o-mini', 1, 1, 1, NULL
        )
        """
    )
}

private func insertMediaArtifactRow(
    id: String,
    languageSpaceID: String = "space-1",
    artifactType: String = "ttsSentenceAudio",
    derivationKind: String = "ttsAudio",
    backupPolicy: String = "excludedFromSystemBackup",
    derivationKeyHash: String = "derivation-hash",
    db: Database
) throws {
    try db.execute(
        sql: """
        INSERT INTO media_artifacts (
            id, language_space_id, owner_type, owner_id, owner_sub_id,
            artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
            mime_type, byte_size, duration_seconds, content_hash, created_at,
            last_accessed_at, invalidated_at, delete_after, backup_policy,
            file_state, sync_policy, export_policy
        ) VALUES (?, ?, 'learningMaterialSentence', 'material-1', '0', ?, ?,
            ?, 'ttsSentenceAudio/space-1/artifact.mp3', 'audio/mpeg', 10,
            1.0, 'content-hash', 1, 1, NULL, NULL, ?, 'ready', 'localOnly',
            'excludedByDefault')
        """,
        arguments: [id, languageSpaceID, artifactType, derivationKind, derivationKeyHash, backupPolicy]
    )
}

private func insertLearningMaterialSentence(_ db: Database) throws {
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

private func insertPracticeSession(_ db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO practice_sessions (
            id, language_space_id, entry_id, learning_material_id, sentence_id,
            sentence_index, target_text_snapshot, translation_snapshot, note_snapshot,
            target_text_hash, target_language_code, source_entry_body_hash,
            material_analysis_source_hash, exercise_type, status, problem_marked,
            completed_recording_id, completed_at, created_at, updated_at, soft_deleted_at
        ) VALUES (
            'session-1', 'space-1', 'entry-1', 'material-1', 'sentence-1',
            0, 'I booked the train this morning.', '我今天早上订了火车票。',
            'booked 表示已经完成预订。', 'target-hash-1', 'en', 'source-hash',
            'analysis-hash', 'shadowing', 'inProgress', 0, NULL, NULL, 10, 10, NULL
        )
        """
    )
}

private func insertPracticeRecording(_ db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO practice_recordings (
            id, session_id, language_space_id, media_artifact_id, attempt_number,
            status, duration_seconds, byte_size, content_hash, created_at,
            ready_at, invalidated_at
        ) VALUES (
            'recording-1', 'session-1', 'space-1', 'artifact-practice-1',
            1, 'ready', 1.4, 10, 'content-hash', 11, 12, NULL
        )
        """
    )
}

private func insertPracticeRecordingArtifact(_ db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO practice_recording_artifacts (
            artifact_id, session_id, recording_id, attempt_number,
            target_text_hash, target_language_code, recording_format,
            sample_rate, channel_count, duration_seconds, content_hash
        ) VALUES (
            'artifact-practice-1', 'session-1', 'recording-1', 1,
            'target-hash-1', 'en', 'm4a', 44100, 1, 1.4, 'content-hash'
        )
        """
    )
}
