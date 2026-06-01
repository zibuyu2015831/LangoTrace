import LangoTraceCore
@testable import LangoTraceUI
import Testing

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

        store.selectText("図書館", sentenceID: "block-1", containingSentence: "今日は図書館で読みます。")
        await store.explainSelection()

        let request = await explanation.requests.first
        #expect(request?.selectedText == "図書館")
        #expect(request?.containingSentence == "今日は図書館で読みます。")
        #expect(request?.contextText == "今日は図書館で読みます。")
        #expect(request?.nativeLanguageCode == "zh-Hans")
        #expect(request?.targetLanguageCode == "ja")
        #expect(request?.proficiencyLevelCode == "a2")
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

        await store.playSentence(sentenceID: "block-1", text: "今日は図書館で読みます。")

        let request = await tts.requests.first
        #expect(request?.sentenceID == "block-1")
        #expect(request?.targetLanguageCode == "ja")
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

private actor CapturingReadingExplanationAction {
    private(set) var requests: [ReadingExplanationRequest] = []

    func explain(_ request: ReadingExplanationRequest) async throws -> ReadingSelectionExplanationResult {
        requests.append(request)
        return .sample(selection: request.selectedText)
    }
}

private actor CapturingReadingTTSAction {
    private(set) var requests: [ReadingTTSRequest] = []

    func play(_ request: ReadingTTSRequest) async {
        requests.append(request)
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
