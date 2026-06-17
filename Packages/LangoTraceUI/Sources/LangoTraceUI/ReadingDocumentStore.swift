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
    @Published public var explainedSentenceIDs: Set<String> = []
    @Published public var explanationSource: ExplanationResultSource?

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
    @Published public internal(set) var currentExplanationMode: ExplanationLanguageMode

    var generation: Int = 0
    var explanationTask: Task<Void, Never>?
    var ttsTask: Task<Void, Never>?
    var explanationCache: [String: ReadingExplanationCacheEntry] = [:]
    let cacheStorage: (any ExplanationCacheStorage)?

    public init(
        documentID: String,
        spaceID: String,
        contentRevision: Int = 1,
        nativeLanguageCode: String = "",
        targetLanguageCode: String = "",
        proficiencyLevelCode: String = "",
        explanationAction: @escaping ReadingExplanationAction,
        ttsAction: @escaping ReadingTTSAction,
        cacheStorage: (any ExplanationCacheStorage)? = nil
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
        self.cacheStorage = cacheStorage
    }

    public func explainSelection() {
        guard explanationState != .loading, let selection = selectedSelection ?? fallbackSelection else {
            return
        }

        let cacheKey = "\(selection.sourceAnchorID):\(currentExplanationMode.rawValue)"
        if let cached = explanationCache[cacheKey] {
            explanationResult = cached.result
            explanationSource = .cache
            explanationState = .idle
            return
        }

        explanationState = .loading
        explanationSource = nil
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
                completeExplanation(result, token: token, request: request, selection: selection)
            } catch {
                failExplanation(token: token, request: request)
            }
        }
    }

    /// Switches the active explanation language mode and re-issues the explanation for the current
    /// selection if one exists and the mode changed. A no-op when the mode is unchanged.
    public func switchExplanationMode(_ mode: ExplanationLanguageMode) {
        guard mode != currentExplanationMode else { return }
        currentExplanationMode = mode
        if selectedSelection != nil {
            explainSelection()
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
        explanationCache = [:]
        explainedSentenceIDs = []
        currentExplanationMode = ExplanationLanguageMode.derive(from: proficiencyLevelCode)
        Task { await loadCacheForDocument() }
    }

    public func clearSelection() {
        selectedSelection = nil
        selectedText = nil
        selectedSentenceID = nil
        containingSentence = ""
        explanationResult = nil
        explanationState = .idle
        explanationSource = nil
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

    func completeExplanation(
        _ result: ReadingSelectionExplanationResult,
        token: Int,
        request: ReadingExplanationRequest,
        selection: ReadingSelectionContext
    ) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            return
        }
        explanationResult = result
        explanationSource = .fresh
        explanationState = .idle

        let cacheKey = "\(selection.sourceAnchorID):\(result.explanationLanguageMode.rawValue)"
        let entry = ReadingExplanationCacheEntry(
            id: UUID().uuidString,
            documentID: request.documentID,
            spaceID: request.spaceID,
            contentRevision: contentRevision,
            structureVersion: 0,
            selectionScope: selection.selectionScope,
            sourceAnchorID: selection.sourceAnchorID,
            explanationLanguageMode: result.explanationLanguageMode,
            sentenceID: selection.sentenceID,
            blockID: selection.blockID,
            charOffset: selection.characterOffset,
            charLength: selection.characterLength,
            selectedText: selection.selectedText,
            selectedTextHash: selection.selectedTextHash,
            result: result,
            createdAt: Date(),
            updatedAt: Date()
        )
        explanationCache[cacheKey] = entry
        explainedSentenceIDs.insert(selection.sentenceID)

        let repo = cacheStorage
        Task { try? await repo?.insert(entry) }
    }

    func failExplanation(token: Int, request: ReadingExplanationRequest) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            // Stale completion must not touch state owned by a newer request.
            return
        }
        explanationState = .failed
    }

    func completeTTS(token: Int, request: ReadingTTSRequest, outcome: ReadingTTSOutcome) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            return
        }
        switch outcome {
        case .success, .cancelled:
            audioState = .idle
        case .failed:
            audioState = .failed
        }
    }
}
