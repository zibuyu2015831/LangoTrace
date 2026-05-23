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
                sentence_index, sentence_text_hash, target_language_code,
                provider_profile_id, tts_endpoint_id, tts_voice_profile_id,
                adapter_kind, adapter_version, model_name, voice_id_hash,
                output_format, sample_rate, speed, pitch, volume,
                instructions_hash, provider_parameters_hash, configuration_fingerprint
            ) VALUES (
                'artifact-2', 'learningMaterialSentence', 'entry-1', 'material-1',
                0, 'sentence-hash', 'en', 'profile-1', 'endpoint-tts',
                'voice-en', 'openai_audio_speech', '2026-05-23',
                'gpt-4o-mini-tts', 'voice-hash', 'mp3', NULL, 1.0, NULL,
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

private final class FixedClock: @unchecked Sendable {
    private let epochSeconds: TimeInterval

    init(epochSeconds: TimeInterval) {
        self.epochSeconds = epochSeconds
    }

    func now() -> Date {
        Date(timeIntervalSince1970: epochSeconds)
    }
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
            'https://api.openai.com/v1', 'gpt-4o-mini-tts', NULL, 0, 0, NULL, 1, 1, NULL
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
            'voice-en', 'endpoint-tts', 'en', 'openai_audio_speech', 'gpt-4o-mini-tts',
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
            sync_policy, export_policy
        ) VALUES (?, ?, 'learningMaterialSentence', 'material-1', '0', ?, 'ttsAudio',
            ?, 'ttsSentenceAudio/space-1/artifact.mp3', 'audio/mpeg', 10,
            1.0, 'content-hash', 1, 1, NULL, NULL, ?, 'localOnly',
            'excludedByDefault')
        """,
        arguments: [id, languageSpaceID, artifactType, derivationKeyHash, backupPolicy]
    )
}
