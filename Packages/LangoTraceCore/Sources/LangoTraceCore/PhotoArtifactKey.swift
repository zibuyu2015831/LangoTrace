import Foundation

public struct PhotoArtifactKey: Equatable, Sendable {
    /// The entry this photo belongs to.
    public var entryID: String
    /// SHA-256 hex of the photo bytes after EXIF stripping.
    public var contentHash: String
    /// ISO-8601 date bucket (YYYY-MM-DD) when the photo was imported.
    public var importedAtBucket: String
    /// Whether GPS and other sensitive EXIF tags were stripped before storage.
    public var exifStripped: Bool

    public init(
        entryID: String,
        contentHash: String,
        importedAtBucket: String,
        exifStripped: Bool
    ) {
        self.entryID = entryID
        self.contentHash = contentHash
        self.importedAtBucket = importedAtBucket
        self.exifStripped = exifStripped
    }

    public var derivationKind: MediaArtifactDerivationKind {
        .photoImage
    }

    public var derivationKeyHash: String {
        StableHashing.sha256Hex(canonicalRepresentation)
    }
}

public struct PhotoArtifactCommitInput: Sendable {
    public var key: PhotoArtifactKey
    public var languageSpaceID: String
    public var entryID: String
    public var stagedFile: MediaArtifactStagedFileReference
    public var mimeType: String
    public var width: Int?
    public var height: Int?
    public var createdAt: Date

    public init(
        key: PhotoArtifactKey,
        languageSpaceID: String,
        entryID: String,
        stagedFile: MediaArtifactStagedFileReference,
        mimeType: String,
        width: Int?,
        height: Int?,
        createdAt: Date
    ) {
        self.key = key
        self.languageSpaceID = languageSpaceID
        self.entryID = entryID
        self.stagedFile = stagedFile
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.createdAt = createdAt
    }
}

private extension PhotoArtifactKey {
    var canonicalRepresentation: String {
        [
            "contentHash=\(contentHash)",
            "entryID=\(entryID)",
            "exifStripped=\(exifStripped ? "1" : "0")",
            "importedAtBucket=\(importedAtBucket)",
        ].joined(separator: "\n")
    }
}
