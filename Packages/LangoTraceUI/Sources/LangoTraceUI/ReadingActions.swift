import LangoTraceCore

public struct ReadingExplanationRequest: Equatable, Sendable {
    public var documentID: String
    public var spaceID: String
    public var selectedText: String
    public var sentenceID: String?
    public var containingSentence: String
    public var contextText: String
    public var nativeLanguageCode: String
    public var targetLanguageCode: String
    public var proficiencyLevelCode: String

    public init(
        documentID: String,
        spaceID: String,
        selectedText: String,
        sentenceID: String?,
        containingSentence: String = "",
        contextText: String = "",
        nativeLanguageCode: String = "",
        targetLanguageCode: String = "",
        proficiencyLevelCode: String = ""
    ) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.selectedText = selectedText
        self.sentenceID = sentenceID
        self.containingSentence = containingSentence
        self.contextText = contextText
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
    }
}

public struct ReadingTTSRequest: Equatable, Sendable {
    public var documentID: String
    public var spaceID: String
    public var sentenceID: String
    public var text: String
    public var targetLanguageCode: String

    public init(
        documentID: String,
        spaceID: String,
        sentenceID: String,
        text: String,
        targetLanguageCode: String = ""
    ) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.sentenceID = sentenceID
        self.text = text
        self.targetLanguageCode = targetLanguageCode
    }
}

public typealias ReadingExplanationAction = @Sendable (ReadingExplanationRequest) async throws
    -> ReadingSelectionExplanationResult
public typealias ReadingTTSAction = @Sendable (ReadingTTSRequest) async -> Void

public struct ReadingLibraryActions: Sendable {
    public var listDocuments: @Sendable (String, Bool, ReadingLibrarySearchQuery?) async throws
        -> [ReadingLibraryDocumentSummary]
    public var importPastedText: @Sendable (ReadingInlineDocumentImportInput) async throws
        -> ReadingLibraryDocumentSummary
    public var loadDocument: @Sendable (String, String) async throws -> ReadingLibraryDocumentContent?
    public var softDeleteDocument: @Sendable (String, String) async throws -> Void
    public var restoreDocument: @Sendable (String, String) async throws -> Void
    public var markDocumentOpened: @Sendable (String, String) async throws -> Void
    public var assignCollection: @Sendable (String, String, String) async throws -> Void
    public var tagDocument: @Sendable (String, String, String) async throws -> Void

    public init(
        listDocuments: @escaping @Sendable (String, Bool, ReadingLibrarySearchQuery?) async throws
            -> [ReadingLibraryDocumentSummary],
        importPastedText: @escaping @Sendable (ReadingInlineDocumentImportInput) async throws
            -> ReadingLibraryDocumentSummary,
        loadDocument: @escaping @Sendable (String, String) async throws -> ReadingLibraryDocumentContent?,
        softDeleteDocument: @escaping @Sendable (String, String) async throws -> Void,
        restoreDocument: @escaping @Sendable (String, String) async throws -> Void,
        markDocumentOpened: @escaping @Sendable (String, String) async throws -> Void,
        assignCollection: @escaping @Sendable (String, String, String) async throws -> Void = { _, _, _ in },
        tagDocument: @escaping @Sendable (String, String, String) async throws -> Void = { _, _, _ in }
    ) {
        self.listDocuments = listDocuments
        self.importPastedText = importPastedText
        self.loadDocument = loadDocument
        self.softDeleteDocument = softDeleteDocument
        self.restoreDocument = restoreDocument
        self.markDocumentOpened = markDocumentOpened
        self.assignCollection = assignCollection
        self.tagDocument = tagDocument
    }

    public static let disabled = ReadingLibraryActions(
        listDocuments: { _, _, _ in [] },
        importPastedText: { _ in
            throw ReadingLibraryActionError.unavailable
        },
        loadDocument: { _, _ in nil },
        softDeleteDocument: { _, _ in },
        restoreDocument: { _, _ in },
        markDocumentOpened: { _, _ in },
        assignCollection: { _, _, _ in },
        tagDocument: { _, _, _ in }
    )
}

public enum ReadingLibraryActionError: Error, Equatable, Sendable {
    case unavailable
}
