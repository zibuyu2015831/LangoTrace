import Foundation

public struct EntryPhotoAttachment: Equatable, Sendable {
    public var id: String
    public var entryID: String
    public var spaceID: String
    public var originalArtifactID: String
    public var thumbnailArtifactID: String?
    public var width: Int?
    public var height: Int?
    public var createdAt: Date
    public var sortOrder: Int

    public init(
        id: String,
        entryID: String,
        spaceID: String,
        originalArtifactID: String,
        thumbnailArtifactID: String?,
        width: Int?,
        height: Int?,
        createdAt: Date,
        sortOrder: Int
    ) {
        self.id = id
        self.entryID = entryID
        self.spaceID = spaceID
        self.originalArtifactID = originalArtifactID
        self.thumbnailArtifactID = thumbnailArtifactID
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
