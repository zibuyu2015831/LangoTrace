import Foundation
import LangoTraceCore
import SwiftUI

public struct ReadingExplanationRequest: Equatable, Sendable {
    public var documentID: String
    public var spaceID: String
    public var sourceAnchorID: String
    public var selectedText: String
    public var selectionScope: ReadingSelectionScope
    public var sentenceID: String?
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
        spaceID: String,
        sourceAnchorID: String,
        selectedText: String,
        selectionScope: ReadingSelectionScope,
        sentenceID: String?,
        containingSentence: String = "",
        previousSentence: String? = nil,
        nextSentence: String? = nil,
        containingParagraph: String = "",
        contextMode: ReadingContextMode = .currentParagraph,
        contextText: String = "",
        nativeLanguageCode: String = "",
        targetLanguageCode: String = "",
        proficiencyLevelCode: String = "",
        explanationLanguageMode: ExplanationLanguageMode = .bilingualBridge
    ) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.sourceAnchorID = sourceAnchorID
        self.selectedText = selectedText
        self.selectionScope = selectionScope
        self.sentenceID = sentenceID
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

public struct ReadingTTSRequest: Equatable, Sendable {
    public var documentID: String
    public var spaceID: String
    public var sentenceID: String
    public var sentenceIndex: Int
    public var text: String
    public var targetLanguageCode: String

    public init(
        documentID: String,
        spaceID: String,
        sentenceID: String,
        sentenceIndex: Int = 0,
        text: String,
        targetLanguageCode: String = ""
    ) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.sentenceID = sentenceID
        self.sentenceIndex = sentenceIndex
        self.text = text
        self.targetLanguageCode = targetLanguageCode
    }
}

public typealias ReadingExplanationAction = @Sendable (ReadingExplanationRequest) async throws
    -> ReadingSelectionExplanationResult

public enum ReadingTTSOutcome: Equatable, Sendable {
    case success
    case failed(String)
    case cancelled
}

public typealias ReadingTTSAction = @Sendable (ReadingTTSRequest) async -> ReadingTTSOutcome

/// Input for the LM02-S4a lookup-capture seam: the user explicitly requested an
/// explanation for `lookedUpTerm` on `documentID`. A behaviour signal only — never
/// the AI's returned explanation.
public struct ReadingLookupCaptureInput: Sendable, Equatable {
    public let spaceID: String
    public let documentID: String
    public let lookedUpTerm: String

    public init(spaceID: String, documentID: String, lookedUpTerm: String) {
        self.spaceID = spaceID
        self.documentID = documentID
        self.lookedUpTerm = lookedUpTerm
    }
}

/// Fired when the user requests an explanation (the lookup / explanation-request
/// behaviour signal). Pure local persistence — never outbound.
public typealias ReadingLookupCaptureAction = @Sendable (ReadingLookupCaptureInput) -> Void

public extension EnvironmentValues {
    /// LM02-S4a lookup-capture seam, injected from App Shell; nil disables capture.
    @Entry var readingLookupCaptureAction: ReadingLookupCaptureAction?
}

/// LM02-S4b band-level source for derive(): given the target language + seed level,
/// returns the internal band level (or nil to leave the static seed). Pure local.
public typealias ReadingBandLevelSource = @Sendable (String, LanguageLevel) async -> LanguageLevel?

public extension EnvironmentValues {
    /// LM02-S4b band source, injected from App Shell; nil leaves the static seed.
    @Entry var readingBandLevelSource: ReadingBandLevelSource?
}

public struct ReadingLibraryActions: Sendable {
    public var listDocuments: @Sendable (String, Bool, ReadingLibrarySearchQuery?) async throws
        -> [ReadingLibraryDocumentSummary]
    public var importPastedText: @Sendable (ReadingInlineDocumentImportInput) async throws
        -> ReadingLibraryDocumentSummary
    public var loadDocument: @Sendable (String, String) async throws -> ReadingLibraryDocumentContent?
    public var updateDocument: @Sendable (ReadingDocumentUpdateInput) async throws -> ReadingLibraryDocumentContent
    public var softDeleteDocument: @Sendable (String, String) async throws -> Void
    public var restoreDocument: @Sendable (String, String) async throws -> Void
    public var markDocumentOpened: @Sendable (String, String) async throws -> Void
    public var assignCollection: @Sendable (String, String, String) async throws -> Void
    public var tagDocument: @Sendable (String, String, String) async throws -> Void
    public var setFavorite: @Sendable (String, String, Bool) async throws -> Void
    public var updateReadingProgress: @Sendable (String, String, Int, Int, Int, Int, Int, Date?) async throws -> Void

    public init(
        listDocuments: @escaping @Sendable (String, Bool, ReadingLibrarySearchQuery?) async throws
            -> [ReadingLibraryDocumentSummary],
        importPastedText: @escaping @Sendable (ReadingInlineDocumentImportInput) async throws
            -> ReadingLibraryDocumentSummary,
        loadDocument: @escaping @Sendable (String, String) async throws -> ReadingLibraryDocumentContent?,
        updateDocument: @escaping @Sendable (ReadingDocumentUpdateInput) async throws
            -> ReadingLibraryDocumentContent,
        softDeleteDocument: @escaping @Sendable (String, String) async throws -> Void,
        restoreDocument: @escaping @Sendable (String, String) async throws -> Void,
        markDocumentOpened: @escaping @Sendable (String, String) async throws -> Void,
        assignCollection: @escaping @Sendable (String, String, String) async throws -> Void = { _, _, _ in },
        tagDocument: @escaping @Sendable (String, String, String) async throws -> Void = { _, _, _ in },
        setFavorite: @escaping @Sendable (String, String, Bool) async throws -> Void = { _, _, _ in },
        updateReadingProgress: @escaping @Sendable (String, String, Int, Int, Int, Int, Int, Date?) async throws
            -> Void = { _, _, _, _, _, _, _, _ in }
    ) {
        self.listDocuments = listDocuments
        self.importPastedText = importPastedText
        self.loadDocument = loadDocument
        self.updateDocument = updateDocument
        self.softDeleteDocument = softDeleteDocument
        self.restoreDocument = restoreDocument
        self.markDocumentOpened = markDocumentOpened
        self.assignCollection = assignCollection
        self.tagDocument = tagDocument
        self.setFavorite = setFavorite
        self.updateReadingProgress = updateReadingProgress
    }

    public static let disabled = ReadingLibraryActions(
        listDocuments: { _, _, _ in [] },
        importPastedText: { _ in
            throw ReadingLibraryActionError.unavailable
        },
        loadDocument: { _, _ in nil },
        updateDocument: { _ in
            throw ReadingLibraryActionError.unavailable
        },
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
