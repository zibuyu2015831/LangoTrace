import Foundation
import LangoTraceCore

@MainActor
public final class ReadingDocumentStore: ObservableObject {
    @Published public var documentID: String
    @Published public var spaceID: String
    @Published public var contentRevision: Int
    @Published public var title: String = ""
    @Published public var body: String = ""

    @Published public var selectedText: String?
    @Published public var selectedSentenceID: String?
    @Published public var containingSentence: String = ""
    @Published public var selectedSelection: ReadingSelectionContext?
    @Published public var explanationResult: ReadingSelectionExplanationResult?
    @Published public var explanationState: ReadingAsyncState = .idle
    @Published public var audioState: ReadingAsyncState = .idle

    @Published public var isEditorPresented: Bool = false
    @Published public var draftTitle: String = ""
    @Published public var draftBody: String = ""
    @Published public var saveState: ReadingAsyncState = .idle
    @Published public var saveFailure: ReadingDocumentSaveFailure?

    let explanationAction: ReadingExplanationAction
    let ttsAction: ReadingTTSAction
    let nativeLanguageCode: String
    let targetLanguageCode: String
    let proficiencyLevelCode: String
    public internal(set) var currentExplanationMode: ExplanationLanguageMode

    var generation: Int = 0
    var explanationTask: Task<Void, Never>?
    var ttsTask: Task<Void, Never>?

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
        currentExplanationMode = ExplanationLanguageMode.derive(from: proficiencyLevelCode)
        self.explanationAction = explanationAction
        self.ttsAction = ttsAction
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
            proficiencyLevelCode: proficiencyLevelCode,
            explanationLanguageMode: currentExplanationMode
        )

        explanationTask?.cancel()
        explanationTask = Task {
            do {
                let result = try await explanationAction(request)
                completeExplanation(result, token: token, request: request)
            } catch {
                failExplanation(token: token, request: request)
            }
        }
    }

    public func playAudio() {
        guard audioState != .loading, let selection = selectedSelection ?? fallbackSelection else {
            return
        }
        audioState = .loading
        let token = nextToken()
        let request = ReadingTTSRequest(
            documentID: documentID,
            spaceID: spaceID,
            sentenceID: selection.sentenceID,
            text: selection.containingSentence,
            targetLanguageCode: targetLanguageCode
        )

        ttsTask?.cancel()
        ttsTask = Task {
            await ttsAction(request)
            completeTTS(token: token, request: request)
        }
    }

    public func replaceDocument(documentID: String, spaceID: String, contentRevision: Int = 1) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.contentRevision = contentRevision
        clearSelection()
        invalidateInFlightWork()
        saveState = .idle
        saveFailure = nil
        isEditorPresented = false
        draftTitle = ""
        draftBody = ""
    }

    public func clearSelection() {
        selectedSelection = nil
        selectedText = nil
        selectedSentenceID = nil
        containingSentence = ""
        explanationResult = nil
        explanationState = .idle
        audioState = .idle
        invalidateInFlightWork()
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

    func nextToken() -> Int {
        generation += 1
        return generation
    }

    func isCurrent(token: Int, documentID: String, spaceID: String) -> Bool {
        token == generation && self.documentID == documentID && self.spaceID == spaceID
    }

    func invalidateInFlightWork() {
        explanationTask?.cancel()
        ttsTask?.cancel()
        generation += 1
    }

    func completeExplanation(_ result: ReadingSelectionExplanationResult, token: Int, request: ReadingExplanationRequest) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            return
        }
        explanationResult = result
        explanationState = .idle
    }

    func failExplanation(token: Int, request: ReadingExplanationRequest) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            explanationState = .idle
            return
        }
        explanationState = .failed
    }

    func completeTTS(token: Int, request: ReadingTTSRequest) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            audioState = .idle
            return
        }
        audioState = .idle
    }
}
