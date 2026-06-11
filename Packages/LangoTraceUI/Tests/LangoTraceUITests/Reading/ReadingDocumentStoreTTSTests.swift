import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Reading document store TTS")
struct ReadingDocumentStoreTTSTests {
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

    @Test("late stale TTS completion keeps the newer request loading")
    func lateStaleTTSCompletionKeepsNewerRequestLoading() async {
        let tts = ControlledReadingTTSAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: tts.play
        )

        store.playSentence(sentenceID: "s1", text: "First")
        await tts.waitForRequestCount(1)

        store.selectText("second", sentenceID: "s2")
        store.playSentence(sentenceID: "s2", text: "Second")
        await tts.waitForRequestCount(2)
        #expect(store.audioState == .loading)

        await tts.complete()
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(store.audioState == .loading)

        await tts.complete()
        while store.audioState == .loading {
            await Task.yield()
        }
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

private actor ControlledReadingTTSAction {
    private(set) var requests: [ReadingTTSRequest] = []
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func play(_ request: ReadingTTSRequest) async {
        requests.append(request)
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func complete() {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume()
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
            schemaVersion: "reading_selection_explanation.v3",
            selection: selection,
            shortExplanation: "Explanation",
            meaningInNativeLanguage: "释义",
            usageNote: "Usage",
            exampleSentence: "Example.",
            grammaticalNote: "Noun, singular."
        )
    }
}
