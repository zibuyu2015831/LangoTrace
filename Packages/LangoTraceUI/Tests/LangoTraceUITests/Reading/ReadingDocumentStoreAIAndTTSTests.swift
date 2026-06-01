import LangoTraceCore
import Testing
@testable import LangoTraceUI

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

        store.selectText("first", sentenceID: "s1")
        await store.explainSelection()
        store.selectText("second", sentenceID: "s2")
        await explanation.complete(.success(.sample(selection: "first")))
        await Task.yield()

        #expect(store.selectedText == "second")
        #expect(store.explanationResult == nil)
        #expect(store.explanationState == .idle)
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

        await store.playSentence(sentenceID: "s1", text: "First")
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
        await store.explainSelection()
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
        await store.explainSelection()
        await store.explainSelection()
        await Task.yield()

        #expect(await explanation.requestCount() == 1)
        #expect(store.explanationState == .loading)
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
}

private extension ReadingSelectionExplanationResult {
    static func sample(selection: String) -> ReadingSelectionExplanationResult {
        ReadingSelectionExplanationResult(
            schemaVersion: "reading_selection_explanation.v1",
            selection: selection,
            shortExplanation: "Explanation",
            meaningInNativeLanguage: "释义",
            usageNote: "Usage",
            exampleSentence: "Example."
        )
    }
}
