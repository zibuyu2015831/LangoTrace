import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("GRDBEntryPhotoAttachmentRepository (E2 Phase 1)")
struct PhotoAttachmentRepositoryTests {
    // MARK: - Helpers

    private func makeDatabase() throws -> AppDatabase {
        try AppDatabase.inMemory()
    }

    private func makeRepository(
        database: AppDatabase,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString },
        clock: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000_000) }
    ) -> GRDBEntryPhotoAttachmentRepository {
        GRDBEntryPhotoAttachmentRepository(
            database: database,
            clock: clock,
            idGenerator: idGenerator
        )
    }

    private func seedPrerequisites(in database: AppDatabase) throws {
        try database.databaseQueue.write { db in
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
            ) VALUES ('entry-1', 'space-1', 'Photo Day', 'Some text', 'photoWriting', '生活记录', 1, 1, NULL)
            """)
            // Seed a media_artifact for the original photo
            try db.execute(sql: """
            INSERT INTO media_artifacts (
                id, language_space_id, owner_type, owner_id, owner_sub_id,
                artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
                mime_type, byte_size, duration_seconds, content_hash, created_at,
                last_accessed_at, invalidated_at, delete_after, backup_policy,
                file_state, sync_policy, export_policy
            ) VALUES (
                'orig-1', 'space-1', 'entry', 'entry-1', NULL,
                'entryPhotoOriginal', 'photoImage', 'key-hash-orig-1',
                'entryPhotoOriginal/space-1/orig-1.jpg', 'image/jpeg',
                204800, NULL, 'content-hash-orig-1', 1.0, 1.0,
                NULL, NULL, 'excludedFromSystemBackup', 'ready', 'localOnly', 'excludedByDefault'
            )
            """)
        }
    }

    // MARK: - Insert and fetch

    @Test("insert attachment and fetch by entry ID")
    func insertAndFetchByEntryID() throws {
        let db = try makeDatabase()
        try seedPrerequisites(in: db)
        let repo = makeRepository(database: db, idGenerator: { "attach-1" })

        let attachment = try repo.insertAttachment(
            entryID: "entry-1",
            spaceID: "space-1",
            originalArtifactID: "orig-1",
            width: 1920,
            height: 1080
        )

        #expect(attachment.id == "attach-1")
        #expect(attachment.entryID == "entry-1")
        #expect(attachment.spaceID == "space-1")
        #expect(attachment.originalArtifactID == "orig-1")
        #expect(attachment.thumbnailArtifactID == nil)
        #expect(attachment.width == 1920)
        #expect(attachment.height == 1080)
        #expect(attachment.sortOrder == 0)

        let fetched = try repo.attachments(forEntryID: "entry-1")
        #expect(fetched.count == 1)
        #expect(fetched[0].id == "attach-1")
    }

    @Test("fetch returns empty array for entry with no attachments")
    func fetchReturnsEmptyForNoAttachments() throws {
        let db = try makeDatabase()
        try seedPrerequisites(in: db)
        let repo = makeRepository(database: db)

        let fetched = try repo.attachments(forEntryID: "entry-with-no-photos")
        #expect(fetched.isEmpty)
    }

    // MARK: - Thumbnail update

    @Test("update thumbnail sets thumbnail artifact ID")
    func updateThumbnailSetsID() throws {
        let db = try makeDatabase()
        try seedPrerequisites(in: db)
        let repo = makeRepository(database: db, idGenerator: { "attach-1" })

        let attachment = try repo.insertAttachment(
            entryID: "entry-1",
            spaceID: "space-1",
            originalArtifactID: "orig-1",
            width: nil,
            height: nil
        )
        #expect(attachment.thumbnailArtifactID == nil)

        try repo.updateThumbnailArtifact(attachmentID: "attach-1", thumbnailArtifactID: "thumb-1")

        let fetched = try repo.attachments(forEntryID: "entry-1")
        #expect(fetched[0].thumbnailArtifactID == "thumb-1")
    }

    @Test("update thumbnail can clear thumbnail artifact ID")
    func updateThumbnailCanClear() throws {
        let db = try makeDatabase()
        try seedPrerequisites(in: db)
        let repo = makeRepository(database: db, idGenerator: { "attach-1" })

        _ = try repo.insertAttachment(
            entryID: "entry-1",
            spaceID: "space-1",
            originalArtifactID: "orig-1",
            width: nil,
            height: nil
        )
        try repo.updateThumbnailArtifact(attachmentID: "attach-1", thumbnailArtifactID: "thumb-1")
        try repo.updateThumbnailArtifact(attachmentID: "attach-1", thumbnailArtifactID: nil)

        let fetched = try repo.attachments(forEntryID: "entry-1")
        #expect(fetched[0].thumbnailArtifactID == nil)
    }

    // MARK: - Deletion propagation

    @Test("deleting entry cascades to attachment deletion")
    func deletingEntryDeletesAttachment() throws {
        let db = try makeDatabase()
        try seedPrerequisites(in: db)
        let repo = makeRepository(database: db, idGenerator: { "attach-1" })

        _ = try repo.insertAttachment(
            entryID: "entry-1",
            spaceID: "space-1",
            originalArtifactID: "orig-1",
            width: nil,
            height: nil
        )

        try db.databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM entries WHERE id = 'entry-1'")
        }

        let fetched = try repo.attachments(forEntryID: "entry-1")
        #expect(fetched.isEmpty, "Attachments must be deleted when entry is deleted")
    }
}
