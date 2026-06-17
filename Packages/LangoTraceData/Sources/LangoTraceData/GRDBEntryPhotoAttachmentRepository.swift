import Foundation
import GRDB
import LangoTraceCore

public struct GRDBEntryPhotoAttachmentRepository: @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        databaseQueue = database.databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }

    // MARK: - Insert

    public func insertAttachment(
        entryID: String,
        spaceID: String,
        originalArtifactID: String,
        width: Int?,
        height: Int?
    ) throws -> EntryPhotoAttachment {
        try databaseQueue.write { db in
            let id = idGenerator()
            let now = clock()

            let sortOrder = try nextSortOrder(forEntryID: entryID, db: db)

            try db.execute(
                sql: """
                INSERT INTO entry_photo_attachments (
                    id, entry_id, language_space_id,
                    original_artifact_id, thumbnail_artifact_id,
                    status, width, height, exif_stripped, created_at, sort_order
                ) VALUES (?, ?, ?, ?, NULL, 'ready', ?, ?, 1, ?, ?)
                """,
                arguments: [
                    id,
                    entryID,
                    spaceID,
                    originalArtifactID,
                    width,
                    height,
                    now.timeIntervalSince1970,
                    sortOrder,
                ]
            )

            return EntryPhotoAttachment(
                id: id,
                entryID: entryID,
                spaceID: spaceID,
                originalArtifactID: originalArtifactID,
                thumbnailArtifactID: nil,
                width: width,
                height: height,
                createdAt: now,
                sortOrder: sortOrder
            )
        }
    }

    // MARK: - Fetch

    public func attachments(forEntryID entryID: String) throws -> [EntryPhotoAttachment] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                                        SELECT id, entry_id, language_space_id,
                                               original_artifact_id, thumbnail_artifact_id,
                                               width, height, created_at, sort_order
                                        FROM entry_photo_attachments
                                        WHERE entry_id = ?
                                        ORDER BY sort_order ASC
                                        """,
                                        arguments: [entryID])
            return rows.map(attachment(from:))
        }
    }

    // MARK: - Thumbnail update

    public func updateThumbnailArtifact(
        attachmentID: String,
        thumbnailArtifactID: String?
    ) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE entry_photo_attachments
                SET thumbnail_artifact_id = ?
                WHERE id = ?
                """,
                arguments: [thumbnailArtifactID, attachmentID]
            )
        }
    }

    // MARK: - Private helpers

    private func nextSortOrder(forEntryID entryID: String, db: Database) throws -> Int {
        let maxOrder = try Int.fetchOne(db, sql: """
        SELECT MAX(sort_order) FROM entry_photo_attachments WHERE entry_id = ?
        """, arguments: [entryID])
        return (maxOrder ?? -1) + 1
    }

    private func attachment(from row: Row) -> EntryPhotoAttachment {
        EntryPhotoAttachment(
            id: row["id"],
            entryID: row["entry_id"],
            spaceID: row["language_space_id"],
            originalArtifactID: row["original_artifact_id"],
            thumbnailArtifactID: row["thumbnail_artifact_id"],
            width: row["width"],
            height: row["height"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            sortOrder: row["sort_order"]
        )
    }
}
