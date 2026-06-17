import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

// Phase 0 spike gate (E2): verifies that the v17 migration extends media_artifacts
// CHECK constraints to accept photo artifact types, and that a v16-state database
// with existing TTS/recording artifacts survives the rebuild intact.

@Suite("Media artifact photo migration (E2 Phase 0 spike gate)")
struct MediaArtifactPhotoMigrationTests {
    // MARK: - Forward path: fresh schema accepts photo types

    @Test("v17 migration accepts entryPhotoOriginal with photoImage derivation kind")
    func v17MigrationAcceptsEntryPhotoOriginalArtifactType() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertPhotoMigrationPrerequisites(db)
            try insertPhotoArtifactRow(
                id: "photo-original-1",
                artifactType: "entryPhotoOriginal",
                derivationKind: "photoImage",
                db: db
            )
            let count = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM media_artifacts WHERE artifact_type = 'entryPhotoOriginal'
            """) ?? 0
            #expect(count == 1)
        }
    }

    @Test("v17 migration accepts entryPhotoThumbnail with photoImage derivation kind")
    func v17MigrationAcceptsEntryPhotoThumbnailArtifactType() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertPhotoMigrationPrerequisites(db)
            try insertPhotoArtifactRow(
                id: "photo-thumb-1",
                artifactType: "entryPhotoThumbnail",
                derivationKind: "photoImage",
                db: db
            )
            let count = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM media_artifacts WHERE artifact_type = 'entryPhotoThumbnail'
            """) ?? 0
            #expect(count == 1)
        }
    }

    @Test("v17 migration still rejects unknown artifact types")
    func v17MigrationStillRejectsUnknownArtifactTypes() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertPhotoMigrationPrerequisites(db)
            #expect(throws: DatabaseError.self) {
                try insertPhotoArtifactRow(
                    id: "bad-1",
                    artifactType: "unknownPhotoType",
                    derivationKind: "photoImage",
                    db: db
                )
            }
        }
    }

    @Test("v17 migration still accepts pre-existing TTS artifact types")
    func v17MigrationStillAcceptsExistingTTSArtifactTypes() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertPhotoMigrationPrerequisites(db)
            try insertPhotoArtifactRow(
                id: "tts-1",
                artifactType: "ttsSentenceAudio",
                derivationKind: "ttsAudio",
                db: db
            )
            let count = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM media_artifacts WHERE artifact_type = 'ttsSentenceAudio'
            """) ?? 0
            #expect(count == 1)
        }
    }

    // MARK: - Upgrade path: existing v16 artifacts survive CHECK constraint table rebuild

    @Test("v17 migration preserves existing TTS artifact after CHECK constraint rebuild")
    func v17MigrationPreservesExistingTTSArtifactAfterCheckConstraintRebuild() throws {
        let queue = try DatabaseQueue()
        try buildV16FixtureWithTTSArtifact(queue)

        _ = try AppDatabase(databaseQueue: queue)

        try queue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM media_artifacts") ?? 0
            #expect(count == 1)
            let row = try Row.fetchOne(db, sql: """
            SELECT artifact_type, derivation_kind, backup_policy, sync_policy, export_policy
            FROM media_artifacts WHERE id = 'tts-artifact-v16'
            """)
            #expect(row?["artifact_type"] as String? == "ttsSentenceAudio")
            #expect(row?["derivation_kind"] as String? == "ttsAudio")
            #expect(row?["backup_policy"] as String? == "excludedFromSystemBackup")
            #expect(row?["sync_policy"] as String? == "localOnly")
            #expect(row?["export_policy"] as String? == "excludedByDefault")
        }
    }

    // MARK: - v17 creates entry_photo_attachments table

    @Test("v17 migration creates entry_photo_attachments table")
    func v17MigrationCreatesEntryPhotoAttachmentsTable() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.read { db in
            let tables = try String.fetchAll(db, sql: """
            SELECT name FROM sqlite_master WHERE type='table' ORDER BY name
            """)
            #expect(tables.contains("entry_photo_attachments"))
        }
    }

    @Test("v17 migration allows inserting a photo attachment row")
    func v17MigrationAllowsInsertingPhotoAttachmentRow() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertPhotoMigrationPrerequisites(db)
            try insertPhotoArtifactRow(
                id: "orig-1",
                artifactType: "entryPhotoOriginal",
                derivationKind: "photoImage",
                db: db
            )
            try db.execute(sql: """
            INSERT INTO entry_photo_attachments (
                id, entry_id, language_space_id,
                original_artifact_id, thumbnail_artifact_id,
                status, width, height, exif_stripped, created_at, sort_order
            ) VALUES (
                'attach-1', 'entry-1', 'space-1',
                'orig-1', NULL,
                'ready', 1920, 1080, 1, 1.0, 0
            )
            """)
            let count = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM entry_photo_attachments
            """) ?? 0
            #expect(count == 1)
        }
    }

    @Test("v17 migration enforces unique constraint on entry_id + sort_order")
    func v17MigrationRejectsDuplicateSortOrderForSameEntry() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertPhotoMigrationPrerequisites(db)
            try insertPhotoArtifactRow(
                id: "orig-a",
                artifactType: "entryPhotoOriginal",
                derivationKind: "photoImage",
                db: db
            )
            try insertPhotoArtifactRow(
                id: "orig-b",
                artifactType: "entryPhotoOriginal",
                derivationKind: "photoImage",
                db: db
            )
            try db.execute(sql: """
            INSERT INTO entry_photo_attachments (
                id, entry_id, language_space_id,
                original_artifact_id, thumbnail_artifact_id,
                status, width, height, exif_stripped, created_at, sort_order
            ) VALUES ('attach-a', 'entry-1', 'space-1', 'orig-a', NULL, 'ready', NULL, NULL, 1, 1.0, 0)
            """)
            #expect(throws: DatabaseError.self) {
                try db.execute(sql: """
                INSERT INTO entry_photo_attachments (
                    id, entry_id, language_space_id,
                    original_artifact_id, thumbnail_artifact_id,
                    status, width, height, exif_stripped, created_at, sort_order
                ) VALUES ('attach-b', 'entry-1', 'space-1', 'orig-b', NULL, 'ready', NULL, NULL, 1, 1.0, 0)
                """)
            }
        }
    }

    @Test("v17 migration cascades attachment deletion when entry is deleted")
    func v17MigrationCascadesAttachmentDeletionWhenEntryDeleted() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertPhotoMigrationPrerequisites(db)
            try insertPhotoArtifactRow(
                id: "orig-cascade",
                artifactType: "entryPhotoOriginal",
                derivationKind: "photoImage",
                db: db
            )
            try db.execute(sql: """
            INSERT INTO entry_photo_attachments (
                id, entry_id, language_space_id,
                original_artifact_id, thumbnail_artifact_id,
                status, width, height, exif_stripped, created_at, sort_order
            ) VALUES ('attach-cascade', 'entry-1', 'space-1', 'orig-cascade', NULL, 'ready', NULL, NULL, 1, 1.0, 0)
            """)

            try db.execute(sql: "DELETE FROM entries WHERE id = 'entry-1'")

            let count = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM entry_photo_attachments
            """) ?? 0
            #expect(count == 0, "Attachment must be deleted when its entry is deleted")
        }
    }

    @Test("v17 upgrade from v16 fixture also creates entry_photo_attachments table")
    func v17UpgradeFromV16CreatesEntryPhotoAttachmentsTable() throws {
        let queue = try DatabaseQueue()
        try buildV16FixtureWithTTSArtifact(queue)

        _ = try AppDatabase(databaseQueue: queue)

        try queue.read { db in
            let tables = try String.fetchAll(db, sql: """
            SELECT name FROM sqlite_master WHERE type='table' ORDER BY name
            """)
            #expect(tables.contains("entry_photo_attachments"))
        }
    }

    // MARK: - v19 repair: entry_photo_attachments missing from old v17 runs

    @Test("v19 repair migration creates entry_photo_attachments when v17 ran without it")
    func v19RepairMigrationCreatesEntryPhotoAttachmentsForLegacyV17Database() throws {
        let queue = try DatabaseQueue()
        try buildV17FixtureWithoutPhotoAttachmentsTable(queue)

        _ = try AppDatabase(databaseQueue: queue)

        try queue.read { db in
            let tables = try String.fetchAll(db, sql: """
            SELECT name FROM sqlite_master WHERE type='table' ORDER BY name
            """)
            #expect(tables.contains("entry_photo_attachments"))
        }
    }

    @Test("v19 repair migration is idempotent when entry_photo_attachments already exists")
    func v19RepairMigrationIsIdempotentWhenTableAlreadyExists() throws {
        // Fresh inMemory DB: v17 already creates the table, v19 must not fail.
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.read { db in
            let tables = try String.fetchAll(db, sql: """
            SELECT name FROM sqlite_master WHERE type='table' ORDER BY name
            """)
            #expect(tables.contains("entry_photo_attachments"))
        }
    }

    @Test("v20 repair migration backfills attachments from existing photo artifacts")
    func v20RepairMigrationBackfillsAttachmentsFromExistingPhotoArtifacts() throws {
        let queue = try DatabaseQueue()
        try buildV19FixtureWithPhotoArtifactsButMissingAttachmentRows(queue)

        _ = try AppDatabase(databaseQueue: queue)

        try queue.read { db in
            let row = try Row.fetchOne(db, sql: """
            SELECT
                epa.entry_id,
                epa.language_space_id,
                epa.original_artifact_id,
                epa.thumbnail_artifact_id,
                epa.status,
                epa.sort_order
            FROM entry_photo_attachments epa
            WHERE epa.entry_id = 'entry-legacy-photo'
            """)
            #expect(row?["entry_id"] as String? == "entry-legacy-photo")
            #expect(row?["language_space_id"] as String? == "space-legacy")
            #expect(row?["original_artifact_id"] as String? == "legacy-original")
            #expect(row?["thumbnail_artifact_id"] as String? == "legacy-thumbnail")
            #expect(row?["status"] as String? == "ready")
            #expect(row?["sort_order"] as Int? == 0)
        }
    }

    // MARK: - Primary asset semantics: photo originals must not carry delete_after

    @Test("photo original artifact written with null delete_after satisfying primary asset policy")
    func photoOriginalArtifactWrittenWithNullDeleteAfterSatisfyingPrimaryAssetPolicy() throws {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try insertPhotoMigrationPrerequisites(db)
            try db.execute(sql: """
            INSERT INTO media_artifacts (
                id, language_space_id, owner_type, owner_id, owner_sub_id,
                artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
                mime_type, byte_size, duration_seconds, content_hash, created_at,
                last_accessed_at, invalidated_at, delete_after, backup_policy,
                file_state, sync_policy, export_policy
            ) VALUES (
                'photo-primary-asset', 'space-1', 'entry', 'entry-1', NULL,
                'entryPhotoOriginal', 'photoImage', 'photo-key-hash-primary',
                'entryPhotoOriginal/space-1/photo-primary-asset.jpg', 'image/jpeg',
                204800, NULL, 'content-hash-primary', 1, 1, NULL, NULL,
                'excludedFromSystemBackup', 'ready', 'localOnly', 'excludedByDefault'
            )
            """)
            let row = try Row.fetchOne(db, sql: """
            SELECT delete_after FROM media_artifacts WHERE id = 'photo-primary-asset'
            """)
            let deleteAfter = row?["delete_after"] as Double?
            #expect(deleteAfter == nil, "Photo originals are primary assets and must never carry delete_after")
        }
    }
}

// MARK: - Fixture helpers

private func insertPhotoMigrationPrerequisites(_ db: Database) throws {
    try db.execute(sql: """
    INSERT INTO language_spaces (
        id, native_language_code, target_language_code, level,
        display_name, display_name_normalized, created_at, updated_at,
        last_opened_at, deleted_at
    ) VALUES ('space-1', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
    """)
    try db.execute(sql: """
    INSERT INTO entries (
        id, space_id, title, body, source, scene, created_at, updated_at, deleted_at
    ) VALUES ('entry-1', 'space-1', 'Photo Day', 'Body', 'photoWriting', '生活记录', 1, 1, NULL)
    """)
}

private func insertPhotoArtifactRow(
    id: String,
    artifactType: String,
    derivationKind: String,
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
        ) VALUES (?, 'space-1', 'entry', 'entry-1', NULL, ?, ?,
            ?, ?, 'image/jpeg', 204800, NULL, 'content-hash', 1, 1,
            NULL, NULL, 'excludedFromSystemBackup', 'ready', 'localOnly', 'excludedByDefault')
        """,
        arguments: [
            id,
            artifactType,
            derivationKind,
            "\(artifactType)-\(id)-key-hash",
            "\(artifactType)/space-1/\(id).jpg",
        ]
    )
}

/// Builds a database where v1-v18 are already recorded but entry_photo_attachments was never created.
/// Simulates a device that ran v17 before the entry_photo_attachments creation was added to that migration.
private func buildV17FixtureWithoutPhotoAttachmentsTable(_ queue: DatabaseQueue) throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1_create_language_space_infrastructure") { db in
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
    migrator.registerMigration("v4_create_learning_content_infrastructure") { db in
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
          deleted_at REAL
        )
        """)
    }
    for stub in [
        "v2_create_ai_provider_configuration",
        "v3_create_diagnostic_events",
        "v5_add_learning_material_source_entry_body_hash",
        "v6_create_ai_provider_tts_configuration",
        "v7_create_media_artifact_infrastructure",
        "v8_add_media_artifact_file_state",
        "v9_create_practice_recording_infrastructure",
        "v10_allow_practice_recording_media_derivation_kind",
        "v11_add_ai_provider_endpoint_validation_summary",
        "v12_create_reading_domain_infrastructure",
        "v13_upgrade_reading_lifecycle_events_for_document_updates",
        "v14_create_reading_explanation_cache",
        "v15_reset_reading_explanation_cache_for_unix_epoch",
        "v16_add_reading_fk_and_check_constraints",
        "v17_add_photo_artifact_types", // recorded but did NOT create entry_photo_attachments
        "v18_allow_practice_mode_exercise_types",
    ] {
        migrator.registerMigration(stub) { _ in }
    }
    try migrator.migrate(queue)
}

/// Builds a database where v19 is recorded and entry_photo_attachments exists, but legacy
/// photo media_artifacts were written without the attachment join row.
private func buildV19FixtureWithPhotoArtifactsButMissingAttachmentRows(_ queue: DatabaseQueue) throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1_create_language_space_infrastructure") { db in
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
    migrator.registerMigration("v4_create_learning_content_infrastructure") { db in
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
          deleted_at REAL
        )
        """)
    }
    migrator.registerMigration("v7_create_media_artifact_infrastructure") { db in
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
            CHECK (file_state IN ('pending', 'ready'))
        )
        """)
    }
    migrator.registerMigration("v19_ensure_entry_photo_attachments") { db in
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
    }
    for stub in [
        "v2_create_ai_provider_configuration",
        "v3_create_diagnostic_events",
        "v5_add_learning_material_source_entry_body_hash",
        "v6_create_ai_provider_tts_configuration",
        "v8_add_media_artifact_file_state",
        "v9_create_practice_recording_infrastructure",
        "v10_allow_practice_recording_media_derivation_kind",
        "v11_add_ai_provider_endpoint_validation_summary",
        "v12_create_reading_domain_infrastructure",
        "v13_upgrade_reading_lifecycle_events_for_document_updates",
        "v14_create_reading_explanation_cache",
        "v15_reset_reading_explanation_cache_for_unix_epoch",
        "v16_add_reading_fk_and_check_constraints",
        "v17_add_photo_artifact_types",
        "v18_allow_practice_mode_exercise_types",
    ] {
        migrator.registerMigration(stub) { _ in }
    }
    try migrator.migrate(queue)

    try queue.write { db in
        try db.execute(sql: """
        INSERT INTO language_spaces (
            id, native_language_code, target_language_code, level,
            display_name, display_name_normalized, created_at, updated_at,
            last_opened_at, deleted_at
        ) VALUES ('space-legacy', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
        """)
        try db.execute(sql: """
        INSERT INTO entries (
            id, space_id, title, body, source, scene, created_at, updated_at, deleted_at
        ) VALUES (
            'entry-legacy-photo', 'space-legacy', 'Legacy Photo', 'Body',
            'photoWriting', '生活记录', 1, 1, NULL
        )
        """)
        try db.execute(sql: """
        INSERT INTO media_artifacts (
            id, language_space_id, owner_type, owner_id, owner_sub_id,
            artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
            mime_type, byte_size, duration_seconds, content_hash, created_at,
            last_accessed_at, invalidated_at, delete_after, backup_policy,
            file_state, sync_policy, export_policy
        ) VALUES
        (
            'legacy-original', 'space-legacy', 'entry', 'entry-legacy-photo', NULL,
            'entryPhotoOriginal', 'photoImage', 'legacy-original-key',
            'entryPhotoOriginal/space-legacy/legacy-original.jpg', 'image/jpeg',
            1024, NULL, 'legacy-original-hash', 10, 10, NULL, NULL,
            'excludedFromSystemBackup', 'ready', 'localOnly', 'excludedByDefault'
        ),
        (
            'legacy-thumbnail', 'space-legacy', 'entry', 'entry-legacy-photo', NULL,
            'entryPhotoThumbnail', 'photoImage', 'legacy-thumbnail-key',
            'entryPhotoThumbnail/space-legacy/legacy-thumbnail.jpg', 'image/jpeg',
            128, NULL, 'legacy-thumbnail-hash', 11, 11, NULL, NULL,
            'excludedFromSystemBackup', 'ready', 'localOnly', 'excludedByDefault'
        )
        """)
    }
}

/// Builds a v16-state database with one TTS artifact seeded.
/// When AppDatabase(databaseQueue:) is called on this queue, it applies only v17.
/// The TTS artifact must survive the v17 CHECK constraint table rebuild intact.
private func buildV16FixtureWithTTSArtifact(_ queue: DatabaseQueue) throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1_create_language_space_infrastructure") { db in
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
    for stub in [
        "v2_create_ai_provider_configuration",
        "v3_create_diagnostic_events",
        "v4_create_learning_content_infrastructure",
        "v5_add_learning_material_source_entry_body_hash",
        "v6_create_ai_provider_tts_configuration",
    ] {
        migrator.registerMigration(stub) { _ in }
    }

    // Create media_artifacts at v16 final state (v10 rebuild + file_state column added in v8).
    // This simulates the schema a real device at v16 would have before v17 migration.
    migrator.registerMigration("v7_create_media_artifact_infrastructure") { db in
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

    for stub in [
        "v8_add_media_artifact_file_state",
        "v9_create_practice_recording_infrastructure",
        "v10_allow_practice_recording_media_derivation_kind",
        "v11_add_ai_provider_endpoint_validation_summary",
        "v12_create_reading_domain_infrastructure",
        "v13_upgrade_reading_lifecycle_events_for_document_updates",
        "v14_create_reading_explanation_cache",
        "v15_reset_reading_explanation_cache_for_unix_epoch",
        "v16_add_reading_fk_and_check_constraints",
    ] {
        migrator.registerMigration(stub) { _ in }
    }

    try migrator.migrate(queue)

    try queue.write { db in
        try db.execute(sql: """
        INSERT INTO language_spaces (
            id, native_language_code, target_language_code, level,
            display_name, display_name_normalized, created_at, updated_at,
            last_opened_at, deleted_at
        ) VALUES ('space-v16', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
        """)
        try db.execute(sql: """
        INSERT INTO media_artifacts (
            id, language_space_id, owner_type, owner_id, owner_sub_id,
            artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
            mime_type, byte_size, duration_seconds, content_hash, created_at,
            last_accessed_at, invalidated_at, delete_after, backup_policy,
            file_state, sync_policy, export_policy
        ) VALUES (
            'tts-artifact-v16', 'space-v16', 'learningMaterialSentence', 'material-1', '0',
            'ttsSentenceAudio', 'ttsAudio', 'tts-key-hash-v16',
            'ttsSentenceAudio/space-v16/tts-artifact-v16.mp3', 'audio/mpeg',
            8192, 2.5, 'tts-content-hash', 1, 1, NULL, NULL,
            'excludedFromSystemBackup', 'ready', 'localOnly', 'excludedByDefault'
        )
        """)
    }
}
