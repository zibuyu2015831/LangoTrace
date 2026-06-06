import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Reading document store AI and TTS")
struct ReadingDocumentStoreAIAndTTSTests {
    @Test("stale AI response is ignored after selection changes")
    func staleAIResponseIgnoredAfterSelectionChanges() async {
        let explanation = ControlledReadingExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: explanation.explain,
            ttsAction: { _ in }
        )

        #expect(store.compactLearningPanelState == .hidden)
        store.selectText("first", sentenceID: "s1")
        #expect(store.compactLearningPanelState == .collapsed)
        store.explainSelection()
        store.selectText("second", sentenceID: "s2")
        await explanation.complete(.success(.sample(selection: "first")))
        await Task.yield()

        #expect(store.selectedText == "second")
        #expect(store.explanationResult == nil)
        #expect(store.explanationState == .idle)
        #expect(store.compactLearningPanelState == .collapsed)
    }

    @Test("stale TTS response is ignored after document changes")
    func staleTTSResponseIgnoredAfterDocumentChanges() async {
        let tts = ControlledReadingTTSAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: tts.play
        )

        store.playSentence(sentenceID: "s1", text: "First")
        store.replaceDocument(documentID: "doc-2", spaceID: "space-1")
        await tts.complete()
        await Task.yield()

        #expect(store.audioState == .idle)
        #expect(await tts.requestCount() == 1)
    }

    @Test("language space switch clears state and invalidates active tasks")
    func languageSpaceSwitchClearsStateAndInvalidatesActiveTasks() async {
        let explanation = ControlledReadingExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: explanation.explain,
            ttsAction: { _ in }
        )

        store.selectText("first", sentenceID: "s1")
        store.explainSelection()
        store.replaceDocument(documentID: "doc-2", spaceID: "space-2")
        await explanation.complete(.success(.sample(selection: "first")))
        await Task.yield()

        #expect(store.spaceID == "space-2")
        #expect(store.selectedText == nil)
        #expect(store.explanationResult == nil)
        #expect(store.explanationState == .idle)
    }

    @Test("double tap explain keeps one active operation")
    func doubleTapExplainKeepsOneActiveOperation() async {
        let explanation = ControlledReadingExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: explanation.explain,
            ttsAction: { _ in }
        )

        store.selectText("first", sentenceID: "s1")
        store.explainSelection()
        store.explainSelection()
        await explanation.waitForRequestCount(1)

        #expect(await explanation.requestCount() == 1)
        #expect(store.explanationState == .loading)
    }

    @Test("explanation request carries selection sentence context and language metadata")
    func explanationRequestCarriesContextAndLanguageMetadata() async {
        let explanation = CapturingReadingExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            nativeLanguageCode: "zh-Hans",
            targetLanguageCode: "ja",
            proficiencyLevelCode: "a2",
            explanationAction: explanation.explain,
            ttsAction: { _ in }
        )

        store.selectSelection(.sample(
            selectedText: "図書館",
            selectionScope: .textFragment,
            sentenceID: "sentence-1",
            containingSentence: "今日は図書館で読みます。",
            context: .init(
                previousSentence: "朝ごはんを食べました。",
                nextSentence: "静かな午後でした。",
                containingParagraph: "朝ごはんを食べました。今日は図書館で読みます。静かな午後でした。",
                contextMode: .currentParagraph,
                contextText: "朝ごはんを食べました。今日は図書館で読みます。静かな午後でした。"
            )
        ))
        store.explainSelection()
        await explanation.waitForRequestCount(1)

        let request = await explanation.requests.first
        #expect(request?.selectedText == "図書館")
        #expect(request?.selectionScope == .textFragment)
        #expect(request?.sourceAnchorID == "anchor-doc-1-sentence-1-3-3")
        #expect(request?.sentenceID == "sentence-1")
        #expect(request?.containingSentence == "今日は図書館で読みます。")
        #expect(request?.previousSentence == "朝ごはんを食べました。")
        #expect(request?.nextSentence == "静かな午後でした。")
        #expect(request?.containingParagraph == "朝ごはんを食べました。今日は図書館で読みます。静かな午後でした。")
        #expect(request?.contextMode == .currentParagraph)
        #expect(request?.contextText == "朝ごはんを食べました。今日は図書館で読みます。静かな午後でした。")
        #expect(request?.nativeLanguageCode == "zh-Hans")
        #expect(request?.targetLanguageCode == "ja")
        #expect(request?.proficiencyLevelCode == "a2")
    }

    @Test("explanation request chooses full document for short text")
    func explanationRequestChoosesFullDocumentForShortText() async {
        let explanation = CapturingReadingExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: explanation.explain,
            ttsAction: { _ in }
        )

        store.selectSelection(.sample(
            selectedText: "clocktower",
            selectionScope: .sentence,
            sentenceID: "sentence-1",
            containingSentence: "The clocktower had been silent for fifty years.",
            context: .init(
                previousSentence: nil,
                nextSentence: "Leo wanted to solve the mystery.",
                containingParagraph: "The clocktower had been silent for fifty years. Leo wanted to solve the mystery.",
                contextMode: .fullDocument,
                contextText: "The clocktower had been silent for fifty years. Leo wanted to solve the mystery."
            )
        ))
        store.explainSelection()
        await explanation.waitForRequestCount(1)

        let request = await explanation.requests.first
        #expect(request?.selectionScope == .sentence)
        #expect(request?.contextMode == .fullDocument)
        #expect(request?.contextText == "The clocktower had been silent for fifty years. Leo wanted to solve the mystery.")
    }

    @Test("compact learning panel state progresses from collapsed to loading to content")
    func compactLearningPanelStateProgressesFromCollapsedToLoadingToContent() async {
        let explanation = ControlledReadingExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: explanation.explain,
            ttsAction: { _ in }
        )

        store.selectText("clocktower", sentenceID: "s1")
        #expect(store.compactLearningPanelState == .collapsed)

        store.explainSelection()
        #expect(store.compactLearningPanelState == .loading)
        await explanation.waitForRequestCount(1)

        await explanation.complete(.success(.sample(selection: "clocktower")))
        await waitForPanelState(.content, store: store)

        #expect(store.compactLearningPanelState == .content)
    }

    @Test("compact learning panel state moves to failed and clears to hidden")
    func compactLearningPanelStateMovesToFailedAndClearsToHidden() async {
        let explanation = ControlledReadingExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: explanation.explain,
            ttsAction: { _ in }
        )

        store.selectText("clocktower", sentenceID: "s1")
        store.explainSelection()
        await explanation.waitForRequestCount(1)

        await explanation.complete(.failure(ReadingDocumentStoreSaveFailureFixture()))
        await waitForPanelState(.failed, store: store)

        #expect(store.compactLearningPanelState == .failed)

        store.clearSelection()

        #expect(store.compactLearningPanelState == .hidden)
    }

    @Test("fragment selection invalidates stale explanation")
    func fragmentSelectionInvalidatesStaleExplanation() async {
        let explanation = ControlledReadingExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: explanation.explain,
            ttsAction: { _ in }
        )

        store.selectSelection(.sample(
            selectedText: "clocktower",
            selectionScope: .textFragment,
            sentenceID: "sentence-1",
            containingSentence: "The old clocktower had been silent.",
            context: .init(
                previousSentence: nil,
                nextSentence: nil,
                containingParagraph: "The old clocktower had been silent.",
                contextMode: .currentParagraph,
                contextText: "The old clocktower had been silent."
            )
        ))
        store.explainSelection()
        store.selectSelection(.sample(
            selectedText: "mystery",
            selectionScope: .textFragment,
            sentenceID: "sentence-2",
            containingSentence: "Leo wanted to solve the mystery.",
            context: .init(
                previousSentence: nil,
                nextSentence: nil,
                containingParagraph: "Leo wanted to solve the mystery.",
                contextMode: .currentParagraph,
                contextText: "Leo wanted to solve the mystery."
            )
        ))
        await explanation.complete(.success(.sample(selection: "clocktower")))
        await Task.yield()

        #expect(store.selectedText == "mystery")
        #expect(store.explanationResult == nil)
        #expect(store.explanationState == .idle)
    }

    @Test("playSelectionSentence plays selected text for fragment scope with offset-keyed sentence ID")
    func playSelectionSentencePlaysFragmentText() async {
        let tts = CapturingReadingTTSAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: tts.play
        )

        store.selectSelection(.sample(
            selectedText: "ticket",
            selectionScope: .textFragment,
            sentenceID: "sentence-1",
            containingSentence: "I bought a ticket.",
            context: .init(
                previousSentence: nil,
                nextSentence: nil,
                containingParagraph: "I bought a ticket.",
                contextMode: .currentParagraph,
                contextText: "I bought a ticket."
            )
        ))
        store.playSelectionSentence()
        await tts.waitForRequestCount(1)

        let request = await tts.requests.first
        #expect(request?.text == "ticket")
        #expect(request?.sentenceID == "sentence-1-frag-3")
    }

    @Test("playSelectionSentence plays containing sentence for sentence scope with original sentence ID")
    func playSelectionSentencePlaysSentenceText() async {
        let tts = CapturingReadingTTSAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: tts.play
        )

        store.selectSelection(.sample(
            selectedText: "The old clocktower had been silent.",
            selectionScope: .sentence,
            sentenceID: "sentence-2",
            containingSentence: "The old clocktower had been silent.",
            context: .init(
                previousSentence: nil,
                nextSentence: nil,
                containingParagraph: "The old clocktower had been silent.",
                contextMode: .currentParagraph,
                contextText: "The old clocktower had been silent."
            )
        ))
        store.playSelectionSentence()
        await tts.waitForRequestCount(1)

        let request = await tts.requests.first
        #expect(request?.text == "The old clocktower had been silent.")
        #expect(request?.sentenceID == "sentence-2")
    }

    @Test("selectSelection resets audioState immediately")
    func selectSelectionResetsAudioState() {
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: { _ in }
        )

        store.selectText("first", sentenceID: "s1")
        store.playSentence(sentenceID: "s1", text: "First")
        #expect(store.audioState == .loading)

        store.selectText("second", sentenceID: "s2")

        #expect(store.audioState == .idle)
    }

    @Test("TTS request carries target language metadata")
    func ttsRequestCarriesTargetLanguageMetadata() async {
        let tts = CapturingReadingTTSAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            targetLanguageCode: "ja",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: tts.play
        )

        store.playSentence(sentenceID: "block-1", text: "今日は図書館で読みます。")
        await tts.waitForRequestCount(1)

        let request = await tts.requests.first
        #expect(request?.sentenceID == "block-1")
        #expect(request?.targetLanguageCode == "ja")
    }

    @Test("saving edited document invalidates in-flight explanation and TTS")
    func savingEditedDocumentInvalidatesInFlightExplanationAndTTS() async {
        let explanation = ControlledReadingExplanationAction()
        let tts = ControlledReadingTTSAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            contentRevision: 1,
            explanationAction: explanation.explain,
            ttsAction: tts.play
        )

        store.selectText("first", sentenceID: "s1")
        let explainTask = Task { store.explainSelection() }
        let playTask = Task { store.playSentence(sentenceID: "s1", text: "First") }
        await Task.yield()

        store.replaceDocument(documentID: "doc-1", spaceID: "space-1", contentRevision: 2)
        await explanation.complete(.success(.sample(selection: "first")))
        await tts.complete()
        await explainTask.value
        await playTask.value

        #expect(store.contentRevision == 2)
        #expect(store.selectedText == nil)
        #expect(store.selectedSentenceID == nil)
        #expect(store.explanationResult == nil)
        #expect(store.explanationState == .idle)
        #expect(store.audioState == .idle)
    }

    @Test("save failure maps empty body validation to explicit user-facing error")
    func saveFailureMapsEmptyBodyValidation() {
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: { _ in }
        )

        store.beginEditing(document: ReadingLibraryDocumentContent(
            id: "doc-1",
            spaceID: "space-1",
            title: "Title",
            body: "Body",
            sourceFormat: .plainText,
            targetLanguageCode: "en",
            contentRevision: 1,
            structureVersion: 1
        ))
        store.markSavingEdit()
        store.failSavingEdit(ReadingDocumentUpdateError.emptyBody)

        #expect(store.saveState == .failed)
        #expect(store.saveFailure?.messageKey == "reading.editor.error.emptyBody")
        #expect(store.isEditorPresented)
    }

    @Test("save failure resets when editing restarts and generic repository errors get fallback copy")
    func saveFailureResetsAndGenericErrorsUseFallbackCopy() {
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: { _ in }
        )
        let document = ReadingLibraryDocumentContent(
            id: "doc-1",
            spaceID: "space-1",
            title: "Title",
            body: "Body",
            sourceFormat: .plainText,
            targetLanguageCode: "en",
            contentRevision: 1,
            structureVersion: 1
        )

        store.beginEditing(document: document)
        store.markSavingEdit()
        store.failSavingEdit(ReadingDocumentStoreSaveFailureFixture())
        #expect(store.saveFailure?.messageKey == "reading.editor.error.generic")

        store.beginEditing(document: document)

        #expect(store.saveState == .idle)
        #expect(store.saveFailure == nil)
    }
}

private struct ReadingSelectionFixtureContext {
    let previousSentence: String?
    let nextSentence: String?
    let containingParagraph: String
    let contextMode: ReadingContextMode
    let contextText: String
}

private extension ReadingSelectionContext {
    static func sample(
        selectedText: String,
        selectionScope: ReadingSelectionScope,
        sentenceID: String,
        containingSentence: String,
        context: ReadingSelectionFixtureContext
    ) -> ReadingSelectionContext {
        ReadingSelectionContext(
            sourceAnchorID: "anchor-doc-1-\(sentenceID)-3-\(selectedText.count)",
            blockID: "block-1",
            sentenceID: sentenceID,
            selectionScope: selectionScope,
            selectedText: selectedText,
            selectedTextHash: "hash-\(selectedText)",
            characterOffset: 3,
            characterLength: selectedText.count,
            containingSentence: containingSentence,
            previousSentence: context.previousSentence,
            nextSentence: context.nextSentence,
            containingParagraph: context.containingParagraph,
            contextMode: context.contextMode,
            contextText: context.contextText
        )
    }
}

private actor ControlledReadingExplanationAction {
    private(set) var requests: [ReadingExplanationRequest] = []
    private var continuation: CheckedContinuation<ReadingSelectionExplanationResult, Error>?

    func explain(_ request: ReadingExplanationRequest) async throws -> ReadingSelectionExplanationResult {
        requests.append(request)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func complete(_ result: Result<ReadingSelectionExplanationResult, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    func requestCount() -> Int {
        requests.count
    }

    func waitForRequestCount(_ count: Int) async {
        while requests.count < count {
            await Task.yield()
        }
    }
}

@MainActor
private func waitForPanelState(
    _ expected: ReadingCompactLearningPanelState,
    store: ReadingDocumentStore
) async {
    for _ in 0 ..< 20 {
        if store.compactLearningPanelState == expected {
            return
        }
        await Task.yield()
    }
}

private actor ControlledReadingTTSAction {
    private(set) var requests: [ReadingTTSRequest] = []
    private var continuation: CheckedContinuation<Void, Never>?

    func play(_ request: ReadingTTSRequest) async {
        requests.append(request)
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func complete() {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume()
    }

    func requestCount() -> Int {
        requests.count
    }

    func waitForRequestCount(_ count: Int) async {
        while requests.count < count {
            await Task.yield()
        }
    }
}

private struct ReadingDocumentStoreSaveFailureFixture: Error {}

private actor CapturingReadingExplanationAction {
    private(set) var requests: [ReadingExplanationRequest] = []

    func explain(_ request: ReadingExplanationRequest) async throws -> ReadingSelectionExplanationResult {
        requests.append(request)
        return .sample(selection: request.selectedText)
    }

    func waitForRequestCount(_ count: Int) async {
        while requests.count < count {
            await Task.yield()
        }
    }
}

private actor CapturingReadingTTSAction {
    private(set) var requests: [ReadingTTSRequest] = []

    func play(_ request: ReadingTTSRequest) async {
        requests.append(request)
    }

    func waitForRequestCount(_ count: Int) async {
        while requests.count < count {
            await Task.yield()
        }
    }
}

private extension ReadingSelectionExplanationResult {
    static func sample(selection: String) -> ReadingSelectionExplanationResult {
        ReadingSelectionExplanationResult(
            schemaVersion: "reading_selection_explanation.v2",
            selection: selection,
            shortExplanation: "Explanation",
            meaningInNativeLanguage: "释义",
            usageNote: "Usage",
            exampleSentence: "Example.",
            grammaticalNote: "Noun, singular."
        )
    }
}
