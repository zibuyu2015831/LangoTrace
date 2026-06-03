import Foundation
import LangoTraceCore

public enum ReadingAsyncState: Equatable, Sendable {
    case idle
    case loading
    case failed
}

public enum ReadingDocumentSaveFailure: Equatable, Sendable {
    case emptyBody
    case generic

    var messageKey: String {
        switch self {
        case .emptyBody:
            "reading.editor.error.emptyBody"
        case .generic:
            "reading.editor.error.generic"
        }
    }
}

@MainActor
public final class ReadingDocumentStore: ObservableObject {
    @Published public private(set) var documentID: String
    @Published public private(set) var spaceID: String
    @Published public private(set) var contentRevision: Int
    @Published public private(set) var selectedSelection: ReadingSelectionContext?
    @Published public private(set) var selectedText: String?
    @Published public private(set) var selectedSentenceID: String?
    @Published public private(set) var containingSentence: String = ""
    @Published public private(set) var explanationState: ReadingAsyncState = .idle
    @Published public private(set) var explanationResult: ReadingSelectionExplanationResult?
    @Published public private(set) var audioState: ReadingAsyncState = .idle
    @Published public private(set) var isEditorPresented = false
    @Published public private(set) var draftTitle = ""
    @Published public private(set) var draftBody = ""
    @Published public private(set) var saveState: ReadingAsyncState = .idle
    @Published public private(set) var saveFailure: ReadingDocumentSaveFailure?

    private let explanationAction: ReadingExplanationAction
    private let ttsAction: ReadingTTSAction
    private let nativeLanguageCode: String
    private let targetLanguageCode: String
    private let proficiencyLevelCode: String
    private var generation = 0
    private var explanationTask: Task<Void, Never>?
    private var ttsTask: Task<Void, Never>?

    public init(
        documentID: String,
        spaceID: String,
        contentRevision: Int = 1,
        nativeLanguageCode: String = "",
        targetLanguageCode: String = "",
        proficiencyLevelCode: String = "",
        explanationAction: @escaping ReadingExplanationAction,
        ttsAction: @escaping ReadingTTSAction
    ) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.contentRevision = contentRevision
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
        self.explanationAction = explanationAction
        self.ttsAction = ttsAction
    }

    public func selectText(_ text: String, sentenceID: String?, containingSentence: String = "") {
        let sentenceIdentifier = sentenceID ?? "\(documentID)-selection"
        selectSelection(ReadingSelectionContext(
            sourceAnchorID: ReadingTextSegmenter.sourceAnchorID(
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: 0,
                blockID: sentenceIdentifier,
                sentenceID: sentenceIdentifier,
                selectedTextHash: ReadingTextSegmenter.sha256Hex(text),
                characterOffset: 0,
                characterLength: text.count
            ),
            blockID: sentenceIdentifier,
            sentenceID: sentenceIdentifier,
            selectionScope: .sentence,
            selectedText: text,
            selectedTextHash: ReadingTextSegmenter.sha256Hex(text),
            characterOffset: 0,
            characterLength: text.count,
            containingSentence: containingSentence.isEmpty ? text : containingSentence,
            previousSentence: nil,
            nextSentence: nil,
            containingParagraph: containingSentence.isEmpty ? text : containingSentence,
            contextMode: .currentParagraph,
            contextText: containingSentence.isEmpty ? text : containingSentence
        ))
    }

    public func selectSelection(_ selection: ReadingSelectionContext) {
        selectedSelection = selection
        selectedText = selection.selectedText
        selectedSentenceID = selection.sentenceID
        containingSentence = selection.containingSentence
        explanationResult = nil
        explanationState = .idle
        invalidateInFlightWork()
    }

    public func replaceDocument(documentID: String, spaceID: String, contentRevision: Int = 1) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.contentRevision = contentRevision
        selectedSelection = nil
        selectedText = nil
        selectedSentenceID = nil
        containingSentence = ""
        explanationResult = nil
        explanationState = .idle
        audioState = .idle
        saveState = .idle
        saveFailure = nil
        isEditorPresented = false
        draftTitle = ""
        draftBody = ""
        invalidateInFlightWork()
    }

    public func beginEditing(document: ReadingLibraryDocumentContent) {
        draftTitle = document.title
        draftBody = document.body
        saveState = .idle
        saveFailure = nil
        isEditorPresented = true
    }

    public func updateDraft(title: String, body: String) {
        draftTitle = title
        draftBody = body
        if saveState == .failed {
            saveState = .idle
            saveFailure = nil
        }
    }

    public func markSavingEdit() {
        saveState = .loading
        saveFailure = nil
    }

    public func completeSavingEdit(with document: ReadingLibraryDocumentContent) {
        replaceDocument(
            documentID: document.id,
            spaceID: document.spaceID,
            contentRevision: document.contentRevision
        )
        draftTitle = document.title
        draftBody = document.body
        saveState = .idle
        saveFailure = nil
        isEditorPresented = false
    }

    public func failSavingEdit(_ error: Error) {
        saveState = .failed
        if let updateError = error as? ReadingDocumentUpdateError, updateError == .emptyBody {
            saveFailure = .emptyBody
        } else {
            saveFailure = .generic
        }
    }

    public func cancelEditing() {
        isEditorPresented = false
        saveState = .idle
        saveFailure = nil
    }

    public var canSaveDraft: Bool {
        !draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var compactLearningPanelState: ReadingCompactLearningPanelState {
        guard selectedSelection != nil || fallbackSelection != nil else {
            return .hidden
        }
        if explanationState == .loading {
            return .loading
        }
        if explanationResult != nil {
            return .content
        }
        if explanationState == .failed {
            return .failed
        }
        return .collapsed
    }

    public func clearSelection() {
        selectedText = nil
        selectedSentenceID = nil
        containingSentence = ""
        selectedSelection = nil
        explanationResult = nil
        explanationState = .idle
        audioState = .idle
        invalidateInFlightWork()
    }

    public func explainSelection() {
        guard explanationState != .loading, let selection = selectedSelection ?? fallbackSelection else {
            return
        }
        explanationState = .loading
        let token = nextToken()
        let request = ReadingExplanationRequest(
            documentID: documentID,
            spaceID: spaceID,
            sourceAnchorID: selection.sourceAnchorID,
            selectedText: selection.selectedText,
            selectionScope: selection.selectionScope,
            sentenceID: selection.sentenceID,
            containingSentence: selection.containingSentence,
            previousSentence: selection.previousSentence,
            nextSentence: selection.nextSentence,
            containingParagraph: selection.containingParagraph,
            contextMode: selection.contextMode,
            contextText: selection.contextText,
            nativeLanguageCode: nativeLanguageCode,
            targetLanguageCode: targetLanguageCode,
            proficiencyLevelCode: proficiencyLevelCode
        )
        explanationTask?.cancel()
        explanationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await explanationAction(request)
                completeExplanation(result, token: token, request: request)
            } catch {
                failExplanation(token: token, request: request)
            }
        }
    }

    public func playSentence(sentenceID: String, text: String) {
        guard audioState != .loading else {
            return
        }
        audioState = .loading
        let token = nextToken()
        let request = ReadingTTSRequest(
            documentID: documentID,
            spaceID: spaceID,
            sentenceID: sentenceID,
            text: text,
            targetLanguageCode: targetLanguageCode
        )
        ttsTask?.cancel()
        ttsTask = Task { [weak self] in
            guard let self else { return }
            await ttsAction(request)
            completeTTS(token: token, request: request)
        }
    }

    public func playSelectionSentence() {
        guard let selection = selectedSelection ?? fallbackSelection else { return }
        playSentence(sentenceID: selection.sentenceID, text: selection.containingSentence)
    }

    private func nextToken() -> Int {
        generation += 1
        return generation
    }

    private func invalidateInFlightWork() {
        explanationTask?.cancel()
        ttsTask?.cancel()
        generation += 1
    }

    private func isCurrent(token: Int, documentID: String, spaceID: String) -> Bool {
        token == generation && self.documentID == documentID && self.spaceID == spaceID
    }

    private func completeExplanation(
        _ result: ReadingSelectionExplanationResult,
        token: Int,
        request: ReadingExplanationRequest
    ) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID),
              selectedText == request.selectedText,
              selectedSentenceID == request.sentenceID
        else {
            if explanationState == .loading {
                explanationState = .idle
            }
            return
        }
        explanationResult = result
        explanationState = .idle
    }

    private func failExplanation(token: Int, request: ReadingExplanationRequest) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            explanationState = .idle
            return
        }
        explanationState = .failed
    }

    private func completeTTS(token: Int, request: ReadingTTSRequest) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            audioState = .idle
            return
        }
        audioState = .idle
    }

    private var fallbackSelection: ReadingSelectionContext? {
        guard let selectedText, let selectedSentenceID else { return nil }
        return ReadingSelectionContext(
            sourceAnchorID: ReadingTextSegmenter.sourceAnchorID(
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: 0,
                blockID: selectedSentenceID,
                sentenceID: selectedSentenceID,
                selectedTextHash: ReadingTextSegmenter.sha256Hex(selectedText),
                characterOffset: 0,
                characterLength: selectedText.count
            ),
            blockID: selectedSentenceID,
            sentenceID: selectedSentenceID,
            selectionScope: .sentence,
            selectedText: selectedText,
            selectedTextHash: ReadingTextSegmenter.sha256Hex(selectedText),
            characterOffset: 0,
            characterLength: selectedText.count,
            containingSentence: containingSentence.isEmpty ? selectedText : containingSentence,
            previousSentence: nil,
            nextSentence: nil,
            containingParagraph: containingSentence.isEmpty ? selectedText : containingSentence,
            contextMode: .currentParagraph,
            contextText: containingSentence.isEmpty ? selectedText : containingSentence
        )
    }
}
