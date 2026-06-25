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
    /// LM02-S4a: fired when the user requests an explanation (lookup behaviour
    /// signal). nil disables capture. Pure local persistence — never outbound.
    /// Settable so the SwiftUI environment-injected action can be reconnected
    /// after construction (the store is a `StateObject` built before the
    /// environment is available).
    private(set) var lookupCaptureAction: ReadingLookupCaptureAction?
    let nativeLanguageCode: String
    let targetLanguageCode: String
    let proficiencyLevelCode: String
    @Published public internal(set) var currentExplanationMode: ExplanationLanguageMode

    /// LM02-S4b: band-driven derive() source. Given the target language + seed
    /// level, returns the internal band level (or nil to leave the static seed in
    /// effect). Injected from the environment (reconnected after construction).
    private(set) var bandLevelSource: (@Sendable (String, LanguageLevel) async -> LanguageLevel?)?
    /// Per-language hysteresis guarding derive() against drift (ADR-006 §10.1).
    private var bandHysteresis: BandHysteresis
    /// User manual mode selection always wins (per-document): once set, band
    /// suggestions are suppressed for this document.
    private(set) var userDidOverrideMode = false

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
        lookupCaptureAction: ReadingLookupCaptureAction? = nil,
        cacheStorage: (any ExplanationCacheStorage)? = nil
    ) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.contentRevision = contentRevision
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
        currentExplanationMode = ExplanationLanguageMode.derive(from: proficiencyLevelCode)
        bandHysteresis = BandHysteresis(seed: LanguageLevel(rawValue: proficiencyLevelCode) ?? .b1)
        self.explanationAction = explanationAction
        self.ttsAction = ttsAction
        self.lookupCaptureAction = lookupCaptureAction
        self.cacheStorage = cacheStorage
    }

    /// Swaps in the environment-injected lookup-capture action (the store is built
    /// before the SwiftUI environment is available).
    public func reconnectLookupCapture(_ action: ReadingLookupCaptureAction?) {
        guard let action else { return }
        lookupCaptureAction = action
    }

    public func explainSelection() {
        guard explanationState != .loading, let selection = selectedSelection ?? fallbackSelection else {
            return
        }

        // LM02-S4a: capture the lookup behaviour signal — the user explicitly
        // requested an explanation for this term, regardless of cache outcome.
        lookupCaptureAction?(ReadingLookupCaptureInput(
            spaceID: spaceID,
            documentID: documentID,
            lookedUpTerm: selection.selectedText
        ))

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
        // LM02-S4b: a manual mode choice always wins — suppress band suggestions
        // for this document from here on (constraint 6).
        userDidOverrideMode = true
        guard mode != currentExplanationMode else { return }
        currentExplanationMode = mode
        if selectedSelection != nil {
            explainSelection()
        }
    }

    /// LM02-S4b: reconnects the environment-injected band source (the store is
    /// built before the SwiftUI environment is available).
    public func reconnectBandSource(_ source: (@Sendable (String, LanguageLevel) async -> LanguageLevel?)?) {
        guard let source else { return }
        bandLevelSource = source
    }

    /// LM02-S4b: one document-open band evaluation. Feeds the band level through
    /// the hysteresis state machine and updates the explanation tier **for new
    /// content only** — already-rendered explanations (cached per anchor+mode) are
    /// never re-rendered. Suppressed when the user has manually overridden the mode.
    public func evaluateBandForDocumentOpen() async {
        guard !userDidOverrideMode, let bandLevelSource else { return }
        let seedLevel = LanguageLevel(rawValue: proficiencyLevelCode) ?? .b1
        guard let bandLevel = await bandLevelSource(targetLanguageCode, seedLevel) else { return }
        let effective = bandHysteresis.evaluate(bandLevel: bandLevel)
        let newMode = ExplanationLanguageMode.derive(from: effective.rawValue)
        // Update the tier for subsequent selections; do NOT re-issue existing ones.
        if newMode != currentExplanationMode {
            currentExplanationMode = newMode
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
        // LM02-S4b: a new document clears the per-document manual override; the
        // band hysteresis state persists (per-language continuity).
        userDidOverrideMode = false
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
