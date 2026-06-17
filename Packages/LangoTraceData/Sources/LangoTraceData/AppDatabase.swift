import Foundation
import GRDB
import LangoTraceCore

public struct AppDatabase: @unchecked Sendable {
    let databaseQueue: DatabaseQueue

    public init(databaseQueue: DatabaseQueue) throws {
        self.databaseQueue = databaseQueue
        // `PRAGMA foreign_keys` is a no-op inside a transaction, so it must run
        // outside `write {}` to take effect for externally provided queues.
        try databaseQueue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        try Self.migrate(databaseQueue)
    }

    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(databaseQueue: DatabaseQueue(configuration: configuration()))
    }

    public static func persistent(at databaseURL: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let databaseQueue = try DatabaseQueue(path: databaseURL.path, configuration: configuration())
        let database = try AppDatabase(databaseQueue: databaseQueue)
        try setFileProtectionIfAvailable(for: databaseURL)
        return database
    }
}

private extension AppDatabase {
    static func configuration() -> Configuration {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        return configuration
    }

    static func migrate(_ databaseQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_create_language_space_infrastructure") { db in
            try createLanguageSpaceInfrastructure(db)
        }
        migrator.registerMigration("v2_create_ai_provider_configuration") { db in
            try createAIProviderConfiguration(db)
        }
        migrator.registerMigration("v3_create_diagnostic_events") { db in
            try createDiagnosticEvents(db)
        }
        migrator.registerMigration("v4_create_learning_content_infrastructure") { db in
            try createLearningContentInfrastructure(db)
        }
        migrator.registerMigration("v5_add_learning_material_source_entry_body_hash") { db in
            try addLearningMaterialSourceEntryBodyHash(db)
        }
        migrator.registerMigration("v6_create_ai_provider_tts_configuration") { db in
            try createAIProviderTTSConfiguration(db)
        }
        migrator.registerMigration("v7_create_media_artifact_infrastructure") { db in
            try createMediaArtifactInfrastructure(db)
        }
        migrator.registerMigration("v8_add_media_artifact_file_state") { db in
            try addMediaArtifactFileState(db)
        }
        migrator.registerMigration("v9_create_practice_recording_infrastructure") { db in
            try createPracticeRecordingInfrastructure(db)
        }
        migrator.registerMigration("v10_allow_practice_recording_media_derivation_kind") { db in
            try allowPracticeRecordingMediaDerivationKind(db)
        }
        migrator.registerMigration("v11_add_ai_provider_endpoint_validation_summary") { db in
            try addAIProviderEndpointValidationSummary(db)
        }
        migrator.registerMigration("v12_create_reading_domain_infrastructure") { db in
            try createReadingDomainInfrastructure(db)
        }
        migrator.registerMigration("v13_upgrade_reading_lifecycle_events_for_document_updates") { db in
            try upgradeReadingLifecycleEventsForDocumentUpdatesIfNeeded(db)
        }
        migrator.registerMigration("v14_create_reading_explanation_cache") { db in
            try createReadingExplanationCache(db)
        }
        migrator.registerMigration("v15_reset_reading_explanation_cache_for_unix_epoch") { db in
            try resetReadingExplanationCacheForUnixEpoch(db)
        }
        migrator.registerMigration("v16_add_reading_fk_and_check_constraints") { db in
            try addReadingFKAndCheckConstraints(db)
        }
        migrator.registerMigration("v17_add_photo_artifact_types") { db in
            try addPhotoArtifactTypes(db)
        }
        migrator.registerMigration("v18_allow_practice_mode_exercise_types") { db in
            try allowPracticeModeExerciseTypes(db)
        }
        migrator.registerMigration("v19_ensure_entry_photo_attachments") { db in
            try ensureEntryPhotoAttachments(db)
        }
        migrator.registerMigration("v20_backfill_entry_photo_attachments_from_media_artifacts") { db in
            try backfillEntryPhotoAttachmentsFromMediaArtifacts(db)
        }
        migrator.registerMigration("v21_add_reading_structure_content_revision") { db in
            try addReadingStructureContentRevision(db)
        }
        migrator.registerMigration("v22_add_reading_progress_and_favorite_columns") { db in
            try addReadingProgressAndFavoriteColumns(db)
        }
        try migrator.migrate(databaseQueue)
    }

    static func createLanguageSpaceInfrastructure(_ db: Database) throws {
        try db.create(table: "language_spaces") { table in
            table.column("id", .text).primaryKey()
            table.column("native_language_code", .text).notNull()
            table.column("target_language_code", .text).notNull()
            table.column("level", .text).notNull()
            table.column("display_name", .text).notNull()
            table.column("display_name_normalized", .text).notNull()
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
            table.column("last_opened_at", .double)
            table.column("deleted_at", .double)
        }
        try db.create(
            index: "idx_language_spaces_active_updated_at",
            on: "language_spaces",
            columns: ["deleted_at", "updated_at"]
        )
        try db.create(
            index: "idx_language_spaces_target_language",
            on: "language_spaces",
            columns: ["target_language_code"]
        )
        try db.create(
            index: "idx_language_spaces_display_name_normalized",
            on: "language_spaces",
            columns: ["display_name_normalized"]
        )
        try db.create(table: "app_state") { table in
            table.column("key", .text).primaryKey()
            table.column("value", .text)
            table.column("updated_at", .double).notNull()
        }
    }

    static func createAIProviderConfiguration(_ db: Database) throws {
        try createAIProviderProfiles(db)
        try createAIProviderCredentials(db)
        try createAIProviderEndpoints(db)
        try createAIProviderCustomHeaders(db)
        try createAIProviderValidationEvents(db)
    }

    static func createAIProviderProfiles(_ db: Database) throws {
        try db.create(table: "ai_provider_profiles") { table in
            table.column("id", .text).primaryKey()
            table.column("display_name", .text).notNull()
            table.column("is_default", .boolean).notNull()
            table.column("status", .text).notNull()
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
            table.column("last_validated_at", .double)
            table.column("last_validation_status", .text)
            table.column("deleted_at", .double)
        }
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_ai_provider_profiles_active_default
        ON ai_provider_profiles(is_default)
        WHERE is_default = 1 AND deleted_at IS NULL
        """)
    }

    static func createAIProviderCredentials(_ db: Database) throws {
        try db.create(table: "ai_provider_credentials") { table in
            table.column("id", .text).primaryKey()
            table.column("profile_id", .text).notNull()
                .references("ai_provider_profiles", onDelete: .cascade)
            table.column("provider_preset_id", .text).notNull()
            table.column("kind", .text).notNull()
            table.column("label", .text).notNull()
            table.column("keychain_service", .text).notNull()
            table.column("keychain_account", .text).notNull()
            table.column("keychain_access_group", .text)
            table.column("keychain_synchronizable", .boolean).notNull()
            table.column("keychain_accessibility", .text).notNull()
            table.column("secret_presence", .text).notNull()
            table.column("cleanup_state", .text).notNull()
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
            table.column("last_resolved_at", .double)
            table.column("deleted_at", .double)
        }
        try db.create(
            index: "idx_ai_provider_credentials_keychain_reference",
            on: "ai_provider_credentials",
            columns: ["keychain_service", "keychain_account"],
            unique: true
        )
    }

    static func createAIProviderEndpoints(_ db: Database) throws {
        try db.create(table: "ai_provider_endpoints") { table in
            table.column("id", .text).primaryKey()
            table.column("profile_id", .text).notNull()
                .references("ai_provider_profiles", onDelete: .cascade)
            table.column("purpose", .text).notNull()
            table.column("is_enabled", .boolean).notNull()
            table.column("provider_preset_id", .text).notNull()
            table.column("adapter_kind", .text).notNull()
            table.column("base_url", .text).notNull()
            table.column("model_name", .text).notNull()
            table.column("credential_id", .text)
                .references("ai_provider_credentials", onDelete: .restrict)
            table.column("supports_image_input", .boolean).notNull()
            table.column("image_input_enabled", .boolean).notNull()
            table.column("request_timeout_seconds", .double)
            table.column("last_validated_at", .double)
            table.column("last_validation_status", .text)
            table.column("last_validation_error_category", .text)
            table.column("last_successful_configuration_fingerprint", .text)
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
            table.column("deleted_at", .double)
        }
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_ai_provider_endpoints_active_purpose
        ON ai_provider_endpoints(profile_id, purpose)
        WHERE deleted_at IS NULL
        """)
    }

    static func createAIProviderCustomHeaders(_ db: Database) throws {
        try db.create(table: "ai_provider_custom_headers") { table in
            table.column("id", .text).primaryKey()
            table.column("endpoint_id", .text).notNull()
                .references("ai_provider_endpoints", onDelete: .cascade)
            table.column("header_name", .text).notNull()
            table.column("header_name_normalized", .text).notNull()
            table.column("value_kind", .text).notNull()
            table.column("plain_value", .text)
            table.column("credential_id", .text)
                .references("ai_provider_credentials", onDelete: .restrict)
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
        }
        try db.create(
            index: "idx_ai_provider_custom_headers_name",
            on: "ai_provider_custom_headers",
            columns: ["endpoint_id", "header_name_normalized"],
            unique: true
        )
    }

    static func createAIProviderValidationEvents(_ db: Database) throws {
        try db.create(table: "ai_provider_validation_events") { table in
            table.column("id", .text).primaryKey()
            table.column("profile_id", .text).notNull()
                .references("ai_provider_profiles", onDelete: .cascade)
            table.column("endpoint_id", .text)
                .references("ai_provider_endpoints", onDelete: .setNull)
            table.column("event_type", .text).notNull()
            table.column("status", .text).notNull()
            table.column("error_category", .text)
            table.column("provider_preset_id", .text).notNull()
            table.column("model_name", .text)
            table.column("duration_ms", .integer)
            table.column("created_at", .double).notNull()
        }
    }

    static func addAIProviderEndpointValidationSummary(_ db: Database) throws {
        guard try db.tableExists("ai_provider_endpoints") else {
            return
        }
        let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(ai_provider_endpoints)")
            .map { $0["name"] as String }
        guard !columns.contains("last_validated_at") else {
            return
        }
        try db.alter(table: "ai_provider_endpoints") { table in
            table.add(column: "last_validated_at", .double)
            table.add(column: "last_validation_status", .text)
            table.add(column: "last_validation_error_category", .text)
            table.add(column: "last_successful_configuration_fingerprint", .text)
        }
    }

    static func createAIProviderTTSConfiguration(_ db: Database) throws {
        try db.create(table: "ai_provider_tts_settings") { table in
            table.column("endpoint_id", .text).primaryKey()
                .references("ai_provider_endpoints", onDelete: .cascade)
            table.column("tts_adapter_kind", .text).notNull()
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
        }
        try db.create(table: "ai_provider_tts_voice_profiles") { table in
            table.column("id", .text).primaryKey()
            table.column("endpoint_id", .text).notNull()
                .references("ai_provider_endpoints", onDelete: .cascade)
            table.column("language_code", .text).notNull()
            table.column("tts_adapter_kind", .text).notNull()
            table.column("model_name", .text).notNull()
            table.column("voice_id", .text).notNull()
            table.column("voice_display_name", .text)
            table.column("output_format", .text).notNull()
            table.column("sample_rate", .integer)
            table.column("speed", .double)
            table.column("volume", .double)
            table.column("pitch", .double)
            table.column("style_prompt", .text)
            table.column("instructions", .text)
            table.column("streaming_mode", .boolean).notNull()
            table.column("provider_parameters_json", .text).notNull()
            table.column("configuration_fingerprint", .text).notNull()
            table.column("last_successful_configuration_fingerprint", .text)
            table.column("last_test_status", .text).notNull()
            table.column("last_test_error_category", .text)
            table.column("last_tested_at", .double)
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
        }
        try db.create(
            index: "idx_ai_provider_tts_voice_profiles_endpoint_language",
            on: "ai_provider_tts_voice_profiles",
            columns: ["endpoint_id", "language_code"],
            unique: true
        )
    }

    static func createDiagnosticEvents(_ db: Database) throws {
        try db.create(table: "diagnostic_events") { table in
            table.column("id", .text).primaryKey()
            table.column("name", .text).notNull()
            table.column("domain", .text).notNull()
            table.column("level", .text).notNull()
            table.column("outcome", .text)
            table.column("operation_id", .text)
            table.column("attributes_json", .text).notNull()
            table.column("created_at", .double).notNull()
        }
        try db.create(
            index: "idx_diagnostic_events_created_at",
            on: "diagnostic_events",
            columns: ["created_at"]
        )
        try db.create(
            index: "idx_diagnostic_events_domain_created_at",
            on: "diagnostic_events",
            columns: ["domain", "created_at"]
        )
        try db.create(
            index: "idx_diagnostic_events_operation_id_created_at",
            on: "diagnostic_events",
            columns: ["operation_id", "created_at"]
        )
    }

    // swiftlint:disable:next function_body_length
    static func createLearningContentInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE entries (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          source TEXT NOT NULL,
          scene TEXT NOT NULL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          deleted_at REAL,
          CHECK (length(trim(body)) > 0),
          CHECK (source IN ('typedText', 'photoWriting', 'targetLanguageWriting'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_entries_space_created_at
        ON entries(space_id, deleted_at, created_at DESC)
        """)
        try db.execute(sql: """
        CREATE TABLE learning_materials (
          id TEXT PRIMARY KEY,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          input_kind TEXT NOT NULL,
          prompt_mode TEXT NOT NULL,
          learning_text TEXT NOT NULL,
          original_generated_text TEXT NOT NULL,
          source_entry_body_hash TEXT NOT NULL DEFAULT '',
          analysis_source_hash TEXT NOT NULL,
          analysis_status TEXT NOT NULL,
          prompt_id TEXT NOT NULL,
          prompt_version TEXT NOT NULL,
          provider_profile_id TEXT,
          provider_endpoint_id TEXT,
          provider_preset_id TEXT NOT NULL,
          model_name TEXT NOT NULL,
          is_current INTEGER NOT NULL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          deleted_at REAL,
          CHECK (length(trim(learning_text)) > 0),
          CHECK (input_kind IN ('nativeRecord', 'targetWriting', 'mixed', 'uncertain')),
          CHECK (prompt_mode IN ('automaticLearningMaterial', 'analyzeCurrentLearningText')),
          CHECK (analysis_status IN ('fresh', 'stale', 'missing', 'failed')),
          CHECK (is_current IN (0, 1))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_learning_materials_entry_created_at
        ON learning_materials(entry_id, deleted_at, created_at DESC)
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_learning_materials_current_per_entry
        ON learning_materials(entry_id)
        WHERE is_current = 1 AND deleted_at IS NULL
        """)
        try db.execute(sql: """
        CREATE TABLE learning_material_sentences (
          id TEXT PRIMARY KEY,
          material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
          position INTEGER NOT NULL,
          native_sentence TEXT NOT NULL,
          target_sentence TEXT NOT NULL,
          literal_translation TEXT NOT NULL,
          natural_translation TEXT NOT NULL,
          grammar_notes_json TEXT NOT NULL,
          key_points_json TEXT NOT NULL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          CHECK (position >= 0)
        )
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_learning_material_sentences_position
        ON learning_material_sentences(material_id, position)
        """)
        try db.execute(sql: """
        CREATE TABLE learning_material_revision_notes (
          id TEXT PRIMARY KEY,
          material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
          position INTEGER NOT NULL,
          original_text TEXT NOT NULL,
          revised_text TEXT NOT NULL,
          reason_native TEXT NOT NULL,
          category TEXT NOT NULL,
          created_at REAL NOT NULL,
          CHECK (position >= 0),
          CHECK (category IN ('grammar', 'wordChoice', 'naturalness', 'clarity', 'tone', 'structure'))
        )
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_learning_material_revision_notes_position
        ON learning_material_revision_notes(material_id, position)
        """)
        try db.execute(sql: """
        CREATE TABLE memory_candidates (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
          material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
          sentence_id TEXT REFERENCES learning_material_sentences(id) ON DELETE SET NULL,
          kind TEXT NOT NULL,
          text TEXT NOT NULL,
          explanation_native TEXT NOT NULL,
          example_target TEXT NOT NULL,
          example_native TEXT NOT NULL,
          difficulty TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          CHECK (kind IN ('word', 'phrase', 'sentencePattern', 'grammarPoint', 'errorPattern')),
          CHECK (difficulty IN ('easy', 'medium', 'hard')),
          CHECK (status IN ('candidate'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_memory_candidates_space_status
        ON memory_candidates(space_id, status, created_at DESC)
        """)
        try db.execute(sql: """
        CREATE TABLE practice_candidates (
          id TEXT PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
          material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
          sentence_id TEXT REFERENCES learning_material_sentences(id) ON DELETE SET NULL,
          kind TEXT NOT NULL,
          title TEXT NOT NULL,
          prompt_text TEXT NOT NULL,
          answer_text TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          CHECK (kind IN ('listening', 'shadowing', 'dictation', 'backTranslation')),
          CHECK (status IN ('candidate'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_practice_candidates_entry_kind
        ON practice_candidates(entry_id, kind, created_at DESC)
        """)
        try db.execute(sql: """
        CREATE TABLE learning_material_operations (
          id TEXT PRIMARY KEY,
          operation_id TEXT NOT NULL,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
          material_id TEXT REFERENCES learning_materials(id) ON DELETE SET NULL,
          operation_kind TEXT NOT NULL,
          status TEXT NOT NULL,
          failure_category TEXT,
          prompt_id TEXT NOT NULL,
          prompt_version TEXT NOT NULL,
          provider_profile_id TEXT,
          provider_endpoint_id TEXT,
          provider_preset_id TEXT,
          model_name TEXT,
          input_kind TEXT,
          estimated_token_bucket TEXT NOT NULL,
          duration_ms INTEGER,
          created_at REAL NOT NULL,
          completed_at REAL,
          CHECK (operation_kind IN ('generate', 'analyze')),
          CHECK (status IN ('started', 'succeeded', 'failed', 'cancelled')),
          CHECK (failure_category IS NULL OR failure_category IN (
            'providerNotConfigured', 'credentialMissing', 'networkUnavailable',
            'timeout', 'providerRejected', 'unsupportedProvider', 'unsupportedModel',
            'contentEmpty', 'contentTooLong', 'operationInProgress',
            'invalidStructuredResponse', 'cancelled', 'persistenceFailed', 'unknown'
          )),
          CHECK (input_kind IS NULL OR input_kind IN ('nativeRecord', 'targetWriting', 'mixed', 'uncertain')),
          CHECK (estimated_token_bucket IN ('short', 'medium', 'tooLong'))
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_learning_material_operations_entry_created_at
        ON learning_material_operations(entry_id, created_at DESC)
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_learning_material_operations_operation_id
        ON learning_material_operations(operation_id)
        """)
    }

    static func addLearningMaterialSourceEntryBodyHash(_ db: Database) throws {
        let existingColumns = try Row.fetchAll(db, sql: "PRAGMA table_info(learning_materials)").map { row in
            row["name"] as String
        }
        guard !existingColumns.contains("source_entry_body_hash") else {
            return
        }

        try db.execute(sql: """
        ALTER TABLE learning_materials
        ADD COLUMN source_entry_body_hash TEXT NOT NULL DEFAULT ''
        """)

        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT learning_materials.id AS material_id, entries.body AS entry_body
            FROM learning_materials
            JOIN entries ON entries.id = learning_materials.entry_id
            """
        )
        for row in rows {
            let materialID: String = row["material_id"]
            let entryBody: String = row["entry_body"]
            try db.execute(
                sql: "UPDATE learning_materials SET source_entry_body_hash = ? WHERE id = ?",
                arguments: [LearningMaterialTextHash.sha256(for: entryBody), materialID]
            )
        }
    }

    // swiftlint:disable:next function_body_length
    static func createMediaArtifactInfrastructure(_ db: Database) throws {
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
          CHECK (derivation_kind IN ('ttsAudio', 'practiceRecording')),
          CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
          CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
          CHECK (export_policy IN (
            'excludedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'
          ))
        )
        """)
        try db.execute(sql: """
        CREATE TABLE tts_audio_artifacts (
          artifact_id TEXT PRIMARY KEY REFERENCES media_artifacts(id) ON DELETE CASCADE,
          sentence_source_type TEXT NOT NULL,
          entry_id TEXT REFERENCES entries(id) ON DELETE CASCADE,
          learning_material_id TEXT REFERENCES learning_materials(id) ON DELETE CASCADE,
          reading_document_id TEXT,
          reading_sentence_id TEXT,
          sentence_index INTEGER,
          sentence_text_hash TEXT NOT NULL,
          target_language_code TEXT NOT NULL,
          provider_profile_id TEXT NOT NULL REFERENCES ai_provider_profiles(id) ON DELETE CASCADE,
          tts_endpoint_id TEXT NOT NULL REFERENCES ai_provider_endpoints(id) ON DELETE CASCADE,
          tts_voice_profile_id TEXT NOT NULL REFERENCES ai_provider_tts_voice_profiles(id) ON DELETE CASCADE,
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
          configuration_fingerprint TEXT NOT NULL,
          CHECK (sentence_index IS NULL OR sentence_index >= 0)
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
        try db.execute(sql: """
        CREATE INDEX idx_tts_audio_artifacts_entry_material_sentence
        ON tts_audio_artifacts(entry_id, learning_material_id, sentence_index)
        """)
        try db.execute(sql: """
        CREATE INDEX idx_tts_audio_artifacts_provider_config
        ON tts_audio_artifacts(
          provider_profile_id, tts_endpoint_id, tts_voice_profile_id, configuration_fingerprint
        )
        """)
    }

    static func addMediaArtifactFileState(_ db: Database) throws {
        try db.execute(sql: """
        ALTER TABLE media_artifacts
        ADD COLUMN file_state TEXT NOT NULL DEFAULT 'ready'
        CHECK (file_state IN ('pending', 'ready'))
        """)
        try db.execute(sql: """
        ALTER TABLE tts_audio_artifacts
        ADD COLUMN operation_id TEXT
        """)
    }

    static func createPracticeRecordingInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE practice_sessions (
          id TEXT PRIMARY KEY,
          language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
          learning_material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
          sentence_id TEXT REFERENCES learning_material_sentences(id) ON DELETE SET NULL,
          sentence_index INTEGER NOT NULL,
          target_text_snapshot TEXT NOT NULL,
          translation_snapshot TEXT,
          note_snapshot TEXT,
          target_text_hash TEXT NOT NULL,
          target_language_code TEXT NOT NULL,
          source_entry_body_hash TEXT,
          material_analysis_source_hash TEXT,
          exercise_type TEXT NOT NULL,
          status TEXT NOT NULL,
          problem_marked INTEGER NOT NULL,
          completed_recording_id TEXT REFERENCES practice_recordings(id) ON DELETE SET NULL,
          completed_at REAL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          soft_deleted_at REAL,
          CHECK (sentence_index >= 0),
          CHECK (length(trim(target_text_snapshot)) > 0),
          CHECK (exercise_type IN ('shadowing')),
          CHECK (status IN ('inProgress', 'completed')),
          CHECK (problem_marked IN (0, 1))
        )
        """)
        try db.execute(sql: """
        CREATE TABLE practice_recordings (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL REFERENCES practice_sessions(id) ON DELETE CASCADE,
          language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          media_artifact_id TEXT NOT NULL REFERENCES media_artifacts(id) ON DELETE RESTRICT,
          attempt_number INTEGER NOT NULL,
          status TEXT NOT NULL,
          duration_seconds REAL,
          byte_size INTEGER NOT NULL,
          content_hash TEXT NOT NULL,
          created_at REAL NOT NULL,
          ready_at REAL,
          invalidated_at REAL,
          CHECK (attempt_number >= 1),
          CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
          CHECK (byte_size >= 0),
          CHECK (status IN ('pending', 'ready', 'failed', 'cancelled', 'invalidated'))
        )
        """)
        try db.execute(sql: """
        CREATE TABLE practice_recording_artifacts (
          artifact_id TEXT PRIMARY KEY REFERENCES media_artifacts(id) ON DELETE CASCADE,
          session_id TEXT NOT NULL REFERENCES practice_sessions(id) ON DELETE CASCADE,
          recording_id TEXT NOT NULL REFERENCES practice_recordings(id) ON DELETE CASCADE,
          attempt_number INTEGER NOT NULL,
          target_text_hash TEXT NOT NULL,
          target_language_code TEXT NOT NULL,
          recording_format TEXT NOT NULL,
          sample_rate INTEGER,
          channel_count INTEGER,
          duration_seconds REAL,
          content_hash TEXT NOT NULL,
          CHECK (attempt_number >= 1),
          CHECK (sample_rate IS NULL OR sample_rate > 0),
          CHECK (channel_count IS NULL OR channel_count > 0),
          CHECK (duration_seconds IS NULL OR duration_seconds >= 0)
        )
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_practice_sessions_sentence_exercise
        ON practice_sessions(learning_material_id, sentence_id, sentence_index, exercise_type)
        WHERE soft_deleted_at IS NULL
        """)
        try db.execute(sql: """
        CREATE INDEX idx_practice_sessions_entry_status
        ON practice_sessions(entry_id, status, updated_at DESC)
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_practice_recordings_session_attempt
        ON practice_recordings(session_id, attempt_number)
        """)
        try db.execute(sql: """
        CREATE INDEX idx_practice_recordings_session_status
        ON practice_recordings(session_id, status, ready_at DESC)
        """)
        try db.execute(sql: """
        CREATE INDEX idx_practice_recording_artifacts_recording
        ON practice_recording_artifacts(recording_id)
        """)
    }

    static func allowPracticeModeExerciseTypes(_ db: Database) throws {
        if try !db.tableExists("practice_sessions") {
            try dropPracticeRecordingInfrastructureIfPresent(db)
            try createPracticeRecordingInfrastructure(db)
            return
        }

        let existingColumns = Set(try Row.fetchAll(db, sql: "PRAGMA table_info(practice_sessions)").compactMap { row in
            row["name"] as String?
        })
        let requiredColumns: Set<String> = [
            "id", "language_space_id", "entry_id", "learning_material_id", "sentence_id",
            "sentence_index", "target_text_snapshot", "translation_snapshot", "note_snapshot",
            "target_text_hash", "target_language_code", "source_entry_body_hash",
            "material_analysis_source_hash", "exercise_type", "status", "problem_marked",
            "completed_recording_id", "completed_at", "created_at", "updated_at", "soft_deleted_at",
        ]
        if !requiredColumns.isSubset(of: existingColumns) {
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM practice_sessions") ?? 0
            guard count == 0 else {
                throw DatabaseError(
                    resultCode: .SQLITE_CONSTRAINT,
                    message: "Cannot rebuild legacy practice_sessions with incomplete columns and existing data"
                )
            }
            try dropPracticeRecordingInfrastructureIfPresent(db)
            try createPracticeRecordingInfrastructure(db)
            return
        }

        try db.execute(sql: "PRAGMA legacy_alter_table = ON")
        defer {
            try? db.execute(sql: "PRAGMA legacy_alter_table = OFF")
        }

        try db.execute(sql: """
        DROP INDEX IF EXISTS idx_practice_sessions_sentence_exercise
        """)
        try db.execute(sql: """
        DROP INDEX IF EXISTS idx_practice_sessions_entry_status
        """)
        try db.execute(sql: """
        ALTER TABLE practice_sessions RENAME TO practice_sessions_v17
        """)
        try db.execute(sql: """
        CREATE TABLE practice_sessions (
          id TEXT PRIMARY KEY,
          language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
          learning_material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
          sentence_id TEXT REFERENCES learning_material_sentences(id) ON DELETE SET NULL,
          sentence_index INTEGER NOT NULL,
          target_text_snapshot TEXT NOT NULL,
          translation_snapshot TEXT,
          note_snapshot TEXT,
          target_text_hash TEXT NOT NULL,
          target_language_code TEXT NOT NULL,
          source_entry_body_hash TEXT,
          material_analysis_source_hash TEXT,
          exercise_type TEXT NOT NULL,
          status TEXT NOT NULL,
          problem_marked INTEGER NOT NULL,
          completed_recording_id TEXT REFERENCES practice_recordings(id) ON DELETE SET NULL,
          completed_at REAL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          soft_deleted_at REAL,
          CHECK (sentence_index >= 0),
          CHECK (length(trim(target_text_snapshot)) > 0),
          CHECK (exercise_type IN ('shadowing', 'dictation', 'backtranslation')),
          CHECK (status IN ('inProgress', 'completed')),
          CHECK (problem_marked IN (0, 1))
        )
        """)
        try db.execute(sql: """
        INSERT INTO practice_sessions (
          id, language_space_id, entry_id, learning_material_id, sentence_id,
          sentence_index, target_text_snapshot, translation_snapshot, note_snapshot,
          target_text_hash, target_language_code, source_entry_body_hash,
          material_analysis_source_hash, exercise_type, status, problem_marked,
          completed_recording_id, completed_at, created_at, updated_at, soft_deleted_at
        )
        SELECT
          id, language_space_id, entry_id, learning_material_id, sentence_id,
          sentence_index, target_text_snapshot, translation_snapshot, note_snapshot,
          target_text_hash, target_language_code, source_entry_body_hash,
          material_analysis_source_hash, exercise_type, status, problem_marked,
          completed_recording_id, completed_at, created_at, updated_at, soft_deleted_at
        FROM practice_sessions_v17
        """)
        try db.execute(sql: """
        DROP TABLE practice_sessions_v17
        """)
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_practice_sessions_sentence_exercise
        ON practice_sessions(learning_material_id, sentence_id, sentence_index, exercise_type)
        WHERE soft_deleted_at IS NULL
        """)
        try db.execute(sql: """
        CREATE INDEX idx_practice_sessions_entry_status
        ON practice_sessions(entry_id, status, updated_at DESC)
        """)
    }

    static func dropPracticeRecordingInfrastructureIfPresent(_ db: Database) throws {
        try db.execute(sql: "DROP TABLE IF EXISTS practice_recording_artifacts")
        try db.execute(sql: "DROP TABLE IF EXISTS practice_recordings")
        try db.execute(sql: "DROP TABLE IF EXISTS practice_sessions")
    }

    static func allowPracticeRecordingMediaDerivationKind(_ db: Database) throws {
        // `PRAGMA foreign_keys` is a no-op inside the migration transaction, so the
        // rebuild relies on the migrator's deferred foreign key handling instead.
        try db.execute(sql: "PRAGMA legacy_alter_table = ON")
        defer {
            try? db.execute(sql: "PRAGMA legacy_alter_table = OFF")
        }

        try db.execute(sql: """
        DROP INDEX IF EXISTS idx_media_artifacts_active_derivation_key
        """)
        try db.execute(sql: """
        DROP INDEX IF EXISTS idx_media_artifacts_language_type_accessed
        """)
        try db.execute(sql: """
        DROP INDEX IF EXISTS idx_media_artifacts_owner
        """)
        try db.execute(sql: """
        ALTER TABLE media_artifacts RENAME TO media_artifacts_v9
        """)
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
          file_state TEXT NOT NULL DEFAULT 'ready'
            CHECK (file_state IN ('pending', 'ready')),
          CHECK (byte_size >= 0),
          CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
          CHECK (artifact_type IN (
            'ttsSentenceAudio', 'ttsDocumentAudio', 'shadowingRecording',
            'dictationRecording', 'ocrIntermediate', 'exportTemporary'
          )),
          CHECK (derivation_kind IN ('ttsAudio', 'practiceRecording')),
          CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
          CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
          CHECK (export_policy IN (
            'excludedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'
          ))
        )
        """)
        try db.execute(sql: """
        INSERT INTO media_artifacts (
          id, language_space_id, owner_type, owner_id, owner_sub_id,
          artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
          mime_type, byte_size, duration_seconds, content_hash, created_at,
          last_accessed_at, invalidated_at, delete_after, backup_policy,
          sync_policy, export_policy, file_state
        )
        SELECT
          id, language_space_id, owner_type, owner_id, owner_sub_id,
          artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
          mime_type, byte_size, duration_seconds, content_hash, created_at,
          last_accessed_at, invalidated_at, delete_after, backup_policy,
          sync_policy, export_policy, file_state
        FROM media_artifacts_v9
        """)
        try db.execute(sql: """
        DROP TABLE media_artifacts_v9
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

    // swiftlint:disable:next function_body_length
    static func addPhotoArtifactTypes(_ db: Database) throws {
        // SQLite does not support ALTER TABLE … MODIFY COLUMN or CHECK constraint updates,
        // so extending the artifact_type and derivation_kind CHECK constraints requires a
        // full table rebuild — the same pattern used in v10 for practiceRecording.
        try db.execute(sql: "PRAGMA legacy_alter_table = ON")
        defer {
            try? db.execute(sql: "PRAGMA legacy_alter_table = OFF")
        }

        try db.execute(sql: """
        DROP INDEX IF EXISTS idx_media_artifacts_active_derivation_key
        """)
        try db.execute(sql: """
        DROP INDEX IF EXISTS idx_media_artifacts_language_type_accessed
        """)
        try db.execute(sql: """
        DROP INDEX IF EXISTS idx_media_artifacts_owner
        """)
        try db.execute(sql: """
        ALTER TABLE media_artifacts RENAME TO media_artifacts_v16
        """)
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
          file_state TEXT NOT NULL DEFAULT 'ready'
            CHECK (file_state IN ('pending', 'ready')),
          CHECK (byte_size >= 0),
          CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
          CHECK (artifact_type IN (
            'ttsSentenceAudio', 'ttsDocumentAudio', 'shadowingRecording',
            'dictationRecording', 'ocrIntermediate', 'exportTemporary',
            'entryPhotoOriginal', 'entryPhotoThumbnail'
          )),
          CHECK (derivation_kind IN ('ttsAudio', 'practiceRecording', 'photoImage')),
          CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
          CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
          CHECK (export_policy IN (
            'excludedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'
          ))
        )
        """)
        try db.execute(sql: """
        INSERT INTO media_artifacts (
          id, language_space_id, owner_type, owner_id, owner_sub_id,
          artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
          mime_type, byte_size, duration_seconds, content_hash, created_at,
          last_accessed_at, invalidated_at, delete_after, backup_policy,
          sync_policy, export_policy, file_state
        )
        SELECT
          id, language_space_id, owner_type, owner_id, owner_sub_id,
          artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
          mime_type, byte_size, duration_seconds, content_hash, created_at,
          last_accessed_at, invalidated_at, delete_after, backup_policy,
          sync_policy, export_policy, file_state
        FROM media_artifacts_v16
        """)
        try db.execute(sql: """
        DROP TABLE media_artifacts_v16
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

        // Create entry_photo_attachments table in the same migration transaction.
        // original_artifact_id and thumbnail_artifact_id are stored as plain text (no FK)
        // to avoid cascade ordering conflicts with media_artifacts cleanup.
        // entry_id carries ON DELETE CASCADE so deletion propagates from entries.
        try db.execute(sql: """
        CREATE TABLE entry_photo_attachments (
          id TEXT PRIMARY KEY,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
          language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          original_artifact_id TEXT NOT NULL,
          thumbnail_artifact_id TEXT,
          status TEXT NOT NULL DEFAULT 'ready'
            CHECK (status IN ('pending', 'ready')),
          width INTEGER,
          height INTEGER,
          exif_stripped INTEGER NOT NULL DEFAULT 1,
          created_at REAL NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          UNIQUE (entry_id, sort_order)
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_entry_photo_attachments_entry
        ON entry_photo_attachments(entry_id, sort_order)
        """)
        try db.execute(sql: """
        CREATE INDEX idx_entry_photo_attachments_space
        ON entry_photo_attachments(language_space_id, created_at DESC)
        """)
    }

    static func ensureEntryPhotoAttachments(_ db: Database) throws {
        guard try !db.tableExists("entry_photo_attachments") else { return }
        try db.execute(sql: """
        CREATE TABLE entry_photo_attachments (
          id TEXT PRIMARY KEY,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
          language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
          original_artifact_id TEXT NOT NULL,
          thumbnail_artifact_id TEXT,
          status TEXT NOT NULL DEFAULT 'ready'
            CHECK (status IN ('pending', 'ready')),
          width INTEGER,
          height INTEGER,
          exif_stripped INTEGER NOT NULL DEFAULT 1,
          created_at REAL NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          UNIQUE (entry_id, sort_order)
        )
        """)
        try db.execute(sql: """
        CREATE INDEX idx_entry_photo_attachments_entry
        ON entry_photo_attachments(entry_id, sort_order)
        """)
        try db.execute(sql: """
        CREATE INDEX idx_entry_photo_attachments_space
        ON entry_photo_attachments(language_space_id, created_at DESC)
        """)
    }

    static func backfillEntryPhotoAttachmentsFromMediaArtifacts(_ db: Database) throws {
        guard try db.tableExists("entries"),
              try db.tableExists("media_artifacts"),
              try db.tableExists("entry_photo_attachments")
        else {
            return
        }

        let rows = try Row.fetchAll(db, sql: """
        SELECT
          original.id AS original_artifact_id,
          original.language_space_id AS language_space_id,
          original.owner_id AS entry_id,
          original.created_at AS created_at,
          (
            SELECT thumb.id
            FROM media_artifacts thumb
            WHERE thumb.owner_type = 'entry'
              AND thumb.owner_id = original.owner_id
              AND thumb.artifact_type = 'entryPhotoThumbnail'
              AND thumb.derivation_kind = 'photoImage'
              AND thumb.file_state = 'ready'
              AND thumb.invalidated_at IS NULL
            ORDER BY thumb.created_at ASC, thumb.id ASC
            LIMIT 1
          ) AS thumbnail_artifact_id
        FROM media_artifacts original
        JOIN entries entry ON entry.id = original.owner_id
        WHERE original.owner_type = 'entry'
          AND original.artifact_type = 'entryPhotoOriginal'
          AND original.derivation_kind = 'photoImage'
          AND original.file_state = 'ready'
          AND original.invalidated_at IS NULL
          AND NOT EXISTS (
            SELECT 1
            FROM entry_photo_attachments existing
            WHERE existing.original_artifact_id = original.id
          )
        ORDER BY original.owner_id ASC, original.created_at ASC, original.id ASC
        """)

        var nextSortOrderByEntry: [String: Int] = [:]
        for row in rows {
            let entryID: String = row["entry_id"]
            if nextSortOrderByEntry[entryID] == nil {
                let maxSortOrder = try Int.fetchOne(db, sql: """
                SELECT MAX(sort_order) FROM entry_photo_attachments WHERE entry_id = ?
                """, arguments: [entryID]) ?? -1
                nextSortOrderByEntry[entryID] = maxSortOrder + 1
            }

            let sortOrder = nextSortOrderByEntry[entryID] ?? 0
            nextSortOrderByEntry[entryID] = sortOrder + 1
            let originalArtifactID: String = row["original_artifact_id"]
            let languageSpaceID: String = row["language_space_id"]
            let thumbnailArtifactID: String? = row["thumbnail_artifact_id"]
            let createdAt: Double = row["created_at"]

            try db.execute(
                sql: """
                INSERT INTO entry_photo_attachments (
                    id, entry_id, language_space_id,
                    original_artifact_id, thumbnail_artifact_id,
                    status, width, height, exif_stripped, created_at, sort_order
                ) VALUES (?, ?, ?, ?, ?, 'ready', NULL, NULL, 1, ?, ?)
                """,
                arguments: [
                    "repaired-\(originalArtifactID)",
                    entryID,
                    languageSpaceID,
                    originalArtifactID,
                    thumbnailArtifactID,
                    createdAt,
                    sortOrder,
                ]
            )
        }
    }

    static func setFileProtectionIfAvailable(for databaseURL: URL) throws {
        #if os(iOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: databaseURL.path
            )
        #endif
    }
}
