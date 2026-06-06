import Foundation

public struct ReadingExplanationCacheEntry: Codable, Equatable, Sendable {
    public var id: String
    public var documentID: String
    public var spaceID: String
    public var contentRevision: Int
    public var structureVersion: Int
    public var selectionScope: ReadingSelectionScope
    public var sourceAnchorID: String
    public var explanationLanguageMode: ExplanationLanguageMode
    public var sentenceID: String
    public var blockID: String
    public var charOffset: Int
    public var charLength: Int
    public var selectedText: String
    public var selectedTextHash: String
    public var result: ReadingSelectionExplanationResult
    public var providerID: String?
    public var modelID: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        documentID: String,
        spaceID: String,
        contentRevision: Int,
        structureVersion: Int,
        selectionScope: ReadingSelectionScope,
        sourceAnchorID: String,
        explanationLanguageMode: ExplanationLanguageMode,
        sentenceID: String,
        blockID: String,
        charOffset: Int,
        charLength: Int,
        selectedText: String,
        selectedTextHash: String,
        result: ReadingSelectionExplanationResult,
        providerID: String? = nil,
        modelID: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.documentID = documentID
        self.spaceID = spaceID
        self.contentRevision = contentRevision
        self.structureVersion = structureVersion
        self.selectionScope = selectionScope
        self.sourceAnchorID = sourceAnchorID
        self.explanationLanguageMode = explanationLanguageMode
        self.sentenceID = sentenceID
        self.blockID = blockID
        self.charOffset = charOffset
        self.charLength = charLength
        self.selectedText = selectedText
        self.selectedTextHash = selectedTextHash
        self.result = result
        self.providerID = providerID
        self.modelID = modelID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ExplanationResultSource: Equatable, Sendable {
    case fresh
    case cache
}

public protocol ReadingExplanationCacheRepositoryProtocol: Sendable {
    func insert(_ entry: ReadingExplanationCacheEntry) async throws
    func lookup(
        documentID: String,
        sourceAnchorID: String,
        mode: ExplanationLanguageMode
    ) async throws -> ReadingExplanationCacheEntry?
    func lookupBySentenceID(
        documentID: String,
        contentRevision: Int,
        sentenceID: String
    ) async throws -> ReadingExplanationCacheEntry?
    func loadExplainedSentenceIDs(
        documentID: String,
        contentRevision: Int
    ) async throws -> Set<String>
    func delete(id: String) async throws
    func pruneStale(documentID: String, currentContentRevision: Int) async throws
}
