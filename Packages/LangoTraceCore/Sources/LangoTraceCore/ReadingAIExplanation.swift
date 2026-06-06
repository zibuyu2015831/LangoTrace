import Foundation

public struct ReadingSelectionExplanationInput: Equatable, Sendable {
    public var documentID: String
    public var sourceAnchorID: String
    public var selectedText: String
    public var selectionScope: ReadingSelectionScope
    public var containingSentence: String
    public var previousSentence: String?
    public var nextSentence: String?
    public var containingParagraph: String
    public var contextMode: ReadingContextMode
    public var contextText: String
    public var nativeLanguageCode: String
    public var targetLanguageCode: String
    public var proficiencyLevelCode: String
    public var explanationLanguageMode: ExplanationLanguageMode

    public init(
        documentID: String,
        sourceAnchorID: String,
        selectedText: String,
        selectionScope: ReadingSelectionScope,
        containingSentence: String,
        previousSentence: String?,
        nextSentence: String?,
        containingParagraph: String,
        contextMode: ReadingContextMode,
        contextText: String,
        nativeLanguageCode: String,
        targetLanguageCode: String,
        proficiencyLevelCode: String,
        explanationLanguageMode: ExplanationLanguageMode = .bilingualBridge
    ) {
        self.documentID = documentID
        self.sourceAnchorID = sourceAnchorID
        self.selectedText = selectedText
        self.selectionScope = selectionScope
        self.containingSentence = containingSentence
        self.previousSentence = previousSentence
        self.nextSentence = nextSentence
        self.containingParagraph = containingParagraph
        self.contextMode = contextMode
        self.contextText = contextText
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
        self.explanationLanguageMode = explanationLanguageMode
    }
}

public struct ReadingSelectionExplanationResult: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var selection: String
    public var shortExplanation: String
    public var meaningInNativeLanguage: String
    public var usageNote: String
    public var exampleSentence: String
    public var exampleSentenceTranslation: String?
    public var grammaticalNote: String?
    public var explanationLanguageMode: ExplanationLanguageMode

    public init(
        schemaVersion: String,
        selection: String,
        shortExplanation: String,
        meaningInNativeLanguage: String,
        usageNote: String,
        exampleSentence: String,
        exampleSentenceTranslation: String? = nil,
        grammaticalNote: String? = nil,
        explanationLanguageMode: ExplanationLanguageMode = .bilingualBridge
    ) {
        self.schemaVersion = schemaVersion
        self.selection = selection
        self.shortExplanation = shortExplanation
        self.meaningInNativeLanguage = meaningInNativeLanguage
        self.usageNote = usageNote
        self.exampleSentence = exampleSentence
        self.exampleSentenceTranslation = exampleSentenceTranslation
        self.grammaticalNote = grammaticalNote
        self.explanationLanguageMode = explanationLanguageMode
    }
}

public enum ReadingSelectionExplanationFailureCategory: Equatable, Sendable {
    case providerNotConfigured
    case unsupportedProvider
    case providerRejected
    case networkUnavailable
    case cancelled
    case invalidStructuredResponse
}
