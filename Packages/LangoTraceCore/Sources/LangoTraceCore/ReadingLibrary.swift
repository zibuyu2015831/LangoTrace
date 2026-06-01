import Foundation

public enum ReadingSourceFormat: String, Equatable, Hashable, Sendable {
    case pastedText
    case plainText
    case markdown
    case epub
    case pdf
    case htmlClip
    case webArticle
}

public enum ReadingImportStatus: String, Equatable, Hashable, Sendable {
    case pending
    case ready
    case failed
}

public enum ReadingLibraryStatus: String, Equatable, Hashable, Sendable {
    case active
    case softDeleted

    public var isVisibleInActiveLibrary: Bool {
        self == .active
    }

    public var isRestorable: Bool {
        self == .softDeleted
    }
}

public struct ReadingLibraryDocumentSummary: Equatable, Sendable {
    public var id: String
    public var spaceID: String
    public var title: String
    public var sourceFormat: ReadingSourceFormat
    public var importStatus: ReadingImportStatus
    public var libraryStatus: ReadingLibraryStatus
    public var tagNames: [String]
    public var collectionTitles: [String]
    public var lastOpenedAt: Date?

    public init(
        id: String,
        spaceID: String,
        title: String,
        sourceFormat: ReadingSourceFormat,
        importStatus: ReadingImportStatus,
        libraryStatus: ReadingLibraryStatus,
        tagNames: [String],
        collectionTitles: [String],
        lastOpenedAt: Date?
    ) {
        self.id = id
        self.spaceID = spaceID
        self.title = title
        self.sourceFormat = sourceFormat
        self.importStatus = importStatus
        self.libraryStatus = libraryStatus
        self.tagNames = tagNames
        self.collectionTitles = collectionTitles
        self.lastOpenedAt = lastOpenedAt
    }
}

public struct ReadingLibraryDocumentContent: Equatable, Sendable {
    public var id: String
    public var spaceID: String
    public var title: String
    public var body: String
    public var sourceFormat: ReadingSourceFormat
    public var targetLanguageCode: String
    public var contentRevision: Int
    public var structureVersion: Int

    public init(
        id: String,
        spaceID: String,
        title: String,
        body: String,
        sourceFormat: ReadingSourceFormat,
        targetLanguageCode: String,
        contentRevision: Int,
        structureVersion: Int
    ) {
        self.id = id
        self.spaceID = spaceID
        self.title = title
        self.body = body
        self.sourceFormat = sourceFormat
        self.targetLanguageCode = targetLanguageCode
        self.contentRevision = contentRevision
        self.structureVersion = structureVersion
    }
}

public struct ReadingInlineDocumentImportInput: Equatable, Sendable {
    public var spaceID: String
    public var title: String
    public var body: String
    public var sourceFormat: ReadingSourceFormat
    public var adapterID: String
    public var adapterVersion: Int
    public var targetLanguageCode: String
    public var originalFilename: String?
    public var originalFileExtension: String?
    public var originalMimeType: String?
    public var originalUTI: String?
    public var originalByteSize: Int?

    public init(
        spaceID: String,
        title: String,
        body: String,
        sourceFormat: ReadingSourceFormat,
        adapterID: String,
        adapterVersion: Int,
        targetLanguageCode: String,
        originalFilename: String?,
        originalFileExtension: String?,
        originalMimeType: String?,
        originalUTI: String?,
        originalByteSize: Int?
    ) {
        self.spaceID = spaceID
        self.title = title
        self.body = body
        self.sourceFormat = sourceFormat
        self.adapterID = adapterID
        self.adapterVersion = adapterVersion
        self.targetLanguageCode = targetLanguageCode
        self.originalFilename = originalFilename
        self.originalFileExtension = originalFileExtension
        self.originalMimeType = originalMimeType
        self.originalUTI = originalUTI
        self.originalByteSize = originalByteSize
    }
}

public enum ReadingImportBatchStatus: String, Equatable, Hashable, Sendable {
    case pending
    case completed
    case partialFailure
    case failed
    case cancelled
}

public struct ReadingImportBatchCreateInput: Equatable, Sendable {
    public var spaceID: String
    public var adapterID: String
    public var adapterVersion: Int
    public var itemCount: Int

    public init(spaceID: String, adapterID: String, adapterVersion: Int, itemCount: Int) {
        self.spaceID = spaceID
        self.adapterID = adapterID
        self.adapterVersion = adapterVersion
        self.itemCount = itemCount
    }
}

public struct ReadingImportBatchSummary: Equatable, Sendable {
    public var id: String
    public var spaceID: String
    public var status: ReadingImportBatchStatus
    public var itemCount: Int
    public var successCount: Int
    public var failureCount: Int

    public init(
        id: String,
        spaceID: String,
        status: ReadingImportBatchStatus,
        itemCount: Int,
        successCount: Int,
        failureCount: Int
    ) {
        self.id = id
        self.spaceID = spaceID
        self.status = status
        self.itemCount = itemCount
        self.successCount = successCount
        self.failureCount = failureCount
    }
}

public struct ReadingImportItemRecordInput: Equatable, Sendable {
    public var batchID: String
    public var spaceID: String
    public var documentID: String?
    public var sourceFormat: ReadingSourceFormat
    public var adapterID: String
    public var adapterVersion: Int
    public var originalFilename: String?
    public var originalFileExtension: String?
    public var originalMimeType: String?
    public var originalUTI: String?
    public var originalByteSize: Int?
    public var byteSizeBucket: String?
    public var status: ReadingImportStatus
    public var failureCategory: String?

    public init(
        batchID: String,
        spaceID: String,
        documentID: String?,
        sourceFormat: ReadingSourceFormat,
        adapterID: String,
        adapterVersion: Int,
        originalFilename: String?,
        originalFileExtension: String?,
        originalMimeType: String?,
        originalUTI: String?,
        originalByteSize: Int?,
        byteSizeBucket: String?,
        status: ReadingImportStatus,
        failureCategory: String?
    ) {
        self.batchID = batchID
        self.spaceID = spaceID
        self.documentID = documentID
        self.sourceFormat = sourceFormat
        self.adapterID = adapterID
        self.adapterVersion = adapterVersion
        self.originalFilename = originalFilename
        self.originalFileExtension = originalFileExtension
        self.originalMimeType = originalMimeType
        self.originalUTI = originalUTI
        self.originalByteSize = originalByteSize
        self.byteSizeBucket = byteSizeBucket
        self.status = status
        self.failureCategory = failureCategory
    }
}
