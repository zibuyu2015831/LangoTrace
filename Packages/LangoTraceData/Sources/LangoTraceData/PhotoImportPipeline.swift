import CoreGraphics
import Foundation
import GRDB
import ImageIO
import LangoTraceCore

/// Result returned by a successful photo import.
public struct PhotoImportResult: Sendable {
    public var attachment: EntryPhotoAttachment
    public var originalArtifactID: String
    public var thumbnailArtifactID: String?
    public var relativeOriginalPath: String
    public var relativeThumbnailPath: String?

    public init(
        attachment: EntryPhotoAttachment,
        originalArtifactID: String,
        thumbnailArtifactID: String?,
        relativeOriginalPath: String,
        relativeThumbnailPath: String?
    ) {
        self.attachment = attachment
        self.originalArtifactID = originalArtifactID
        self.thumbnailArtifactID = thumbnailArtifactID
        self.relativeOriginalPath = relativeOriginalPath
        self.relativeThumbnailPath = relativeThumbnailPath
    }
}

public enum PhotoImportError: Error, Sendable {
    case invalidImageData
    case stagingWriteFailed(underlying: any Error)
    case fileMoveFailed(underlying: any Error)
    case metadataTransactionFailed(underlying: any Error)
}

public struct PhotoImportPipeline: @unchecked Sendable {
    private let fileStore: LocalMediaArtifactFileStore
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(
        fileStore: LocalMediaArtifactFileStore,
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.fileStore = fileStore
        databaseQueue = database.databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }

    init(
        fileStore: LocalMediaArtifactFileStore,
        databaseQueue: DatabaseQueue,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.fileStore = fileStore
        self.databaseQueue = databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func importPhoto(
        data: Data,
        entryID: String,
        spaceID: String
    ) throws -> PhotoImportResult {
        let createdAt = clock()

        // Step 1: Validate and process image data (no I/O yet — reject invalid data early)
        guard let processedData = Self.stripGPS(from: data) else {
            throw PhotoImportError.invalidImageData
        }

        let contentHash = StableHashing.sha256Hex(processedData)
        let thumbnailData = Self.generateThumbnail(from: processedData)

        // Step 2: Write processed bytes to staging
        // operationID uses UUID directly (not idGenerator) — it's a transient path, not a record ID.
        let operationID = UUID().uuidString
        let stagedOriginal: MediaArtifactStagedFileReference
        do {
            stagedOriginal = try fileStore.writeStagingFile(processedData, operationID: "\(operationID)-orig")
        } catch {
            throw PhotoImportError.stagingWriteFailed(underlying: error)
        }

        // From here: clean up staging on failure
        var stagedThumbnailPath: String?
        var movedPermanentPaths: [String] = []
        var success = false
        defer {
            if !success {
                _ = try? fileStore.deleteFile(relativePath: stagedOriginal.relativeStagingPath)
                if let thumbPath = stagedThumbnailPath {
                    _ = try? fileStore.deleteFile(relativePath: thumbPath)
                }
                for path in movedPermanentPaths {
                    _ = try? fileStore.deleteFile(relativePath: path)
                }
            }
        }

        // Stage thumbnail (failure is not fatal — thumbnail can be rebuilt from original)
        var stagedThumb: MediaArtifactStagedFileReference?
        if let thumbData = thumbnailData {
            if let ref = try? fileStore.writeStagingFile(thumbData, operationID: "\(operationID)-thumb") {
                stagedThumb = ref
                stagedThumbnailPath = ref.relativeStagingPath
            }
        }

        // Step 3: Assign IDs and compute paths
        let originalArtifactID = idGenerator()
        let thumbnailArtifactID: String? = stagedThumb != nil ? idGenerator() : nil
        let attachmentID = idGenerator()

        let originalPath = "entryPhotoOriginal/\(spaceID)/\(originalArtifactID).jpg"
        let thumbnailPath = thumbnailArtifactID.map { "entryPhotoThumbnail/\(spaceID)/\($0).jpg" }

        // Step 4: Move staged files to permanent locations
        do {
            try fileStore.moveStagedFile(stagedOriginal, to: originalPath)
            movedPermanentPaths.append(originalPath)
        } catch {
            throw PhotoImportError.fileMoveFailed(underlying: error)
        }

        if let thumb = stagedThumb, let thumbPath = thumbnailPath {
            // Thumbnail failure is non-fatal — log and continue without thumbnail
            if (try? fileStore.moveStagedFile(thumb, to: thumbPath)) == nil {
                _ = try? fileStore.deleteFile(relativePath: thumb.relativeStagingPath)
                stagedThumbnailPath = nil
            } else {
                movedPermanentPaths.append(thumbPath)
                stagedThumbnailPath = nil
            }
        }

        // Step 5: GRDB write transaction — all metadata in one atomic write
        let photoKey = PhotoArtifactKey(
            entryID: entryID,
            contentHash: contentHash,
            importedAtBucket: Self.dateBucket(from: createdAt),
            exifStripped: true
        )

        let attachment: EntryPhotoAttachment
        do {
            attachment = try databaseQueue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO media_artifacts (
                        id, language_space_id, owner_type, owner_id, owner_sub_id,
                        artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
                        mime_type, byte_size, duration_seconds, content_hash, created_at,
                        last_accessed_at, invalidated_at, delete_after, backup_policy,
                        file_state, sync_policy, export_policy
                    ) VALUES (?, ?, 'entry', ?, NULL,
                        'entryPhotoOriginal', 'photoImage', ?, ?,
                        'image/jpeg', ?, NULL, ?, ?, ?,
                        NULL, NULL, 'excludedFromSystemBackup', 'ready',
                        'localOnly', 'excludedByDefault')
                    """,
                    arguments: [
                        originalArtifactID, spaceID, entryID,
                        photoKey.derivationKeyHash, originalPath,
                        Int64(processedData.count), contentHash,
                        createdAt.timeIntervalSince1970, createdAt.timeIntervalSince1970,
                    ]
                )

                // Insert thumbnail artifact if available
                if let thumbID = thumbnailArtifactID, let thumbPath = thumbnailPath,
                   let thumbRef = stagedThumb
                {
                    let thumbKey = PhotoArtifactKey(
                        entryID: entryID,
                        contentHash: StableHashing.sha256Hex(thumbnailData ?? processedData),
                        importedAtBucket: Self.dateBucket(from: createdAt),
                        exifStripped: true
                    )
                    try db.execute(
                        sql: """
                        INSERT INTO media_artifacts (
                            id, language_space_id, owner_type, owner_id, owner_sub_id,
                            artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
                            mime_type, byte_size, duration_seconds, content_hash, created_at,
                            last_accessed_at, invalidated_at, delete_after, backup_policy,
                            file_state, sync_policy, export_policy
                        ) VALUES (?, ?, 'entry', ?, NULL,
                            'entryPhotoThumbnail', 'photoImage', ?, ?,
                            'image/jpeg', ?, NULL, ?, ?, ?,
                            NULL, NULL, 'excludedFromSystemBackup', 'ready',
                            'localOnly', 'excludedByDefault')
                        """,
                        arguments: [
                            thumbID, spaceID, entryID,
                            thumbKey.derivationKeyHash, thumbPath,
                            thumbRef.byteSize,
                            StableHashing.sha256Hex(thumbnailData ?? Data()),
                            createdAt.timeIntervalSince1970, createdAt.timeIntervalSince1970,
                        ]
                    )
                }

                // Insert entry_photo_attachment
                let sortOrder = try (Int.fetchOne(db, sql: """
                SELECT MAX(sort_order) FROM entry_photo_attachments WHERE entry_id = ?
                """, arguments: [entryID]) ?? -1) + 1

                let imageSize = Self.imageSize(from: processedData)
                try db.execute(
                    sql: """
                    INSERT INTO entry_photo_attachments (
                        id, entry_id, language_space_id,
                        original_artifact_id, thumbnail_artifact_id,
                        status, width, height, exif_stripped, created_at, sort_order
                    ) VALUES (?, ?, ?, ?, ?, 'ready', ?, ?, 1, ?, ?)
                    """,
                    arguments: [
                        attachmentID, entryID, spaceID,
                        originalArtifactID, thumbnailArtifactID,
                        imageSize?.width, imageSize?.height,
                        createdAt.timeIntervalSince1970, sortOrder,
                    ]
                )

                return EntryPhotoAttachment(
                    id: attachmentID,
                    entryID: entryID,
                    spaceID: spaceID,
                    originalArtifactID: originalArtifactID,
                    thumbnailArtifactID: thumbnailArtifactID,
                    width: imageSize?.width,
                    height: imageSize?.height,
                    createdAt: createdAt,
                    sortOrder: sortOrder
                )
            }
        } catch {
            throw PhotoImportError.metadataTransactionFailed(underlying: error)
        }

        success = true
        return PhotoImportResult(
            attachment: attachment,
            originalArtifactID: originalArtifactID,
            thumbnailArtifactID: thumbnailArtifactID,
            relativeOriginalPath: originalPath,
            relativeThumbnailPath: thumbnailPath
        )
    }
}

// MARK: - ImageIO helpers

private extension PhotoImportPipeline {
    /// Strips GPS and other sensitive EXIF, preserving only orientation.
    /// Re-encodes from the decoded CGImage to guarantee no GPS leaks through.
    /// Returns nil if data cannot be parsed as an image.
    static func stripGPS(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(source),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        // Preserve orientation only — strip everything else (including GPS)
        var safeProps: [CFString: Any] = [:]
        if let allProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if let tiff = allProps[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
               let orientation = tiff[kCGImagePropertyTIFFOrientation]
            {
                safeProps[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFOrientation: orientation]
            }
            if let orientation = allProps[kCGImagePropertyOrientation] {
                safeProps[kCGImagePropertyOrientation] = orientation
            }
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, uti, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, safeProps as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Generates a JPEG thumbnail with max edge of `maxEdge` pixels.
    /// Returns nil if the source data cannot be decoded.
    static func generateThumbnail(from data: Data, maxEdge: Int = 256) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
        ]
        guard let thumbImage = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else {
            return nil
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, "public.jpeg" as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, thumbImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func imageSize(from data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (w, h)
    }

    static func dateBucket(from date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
