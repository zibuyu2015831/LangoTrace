import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Reading document store selection (text fragment)")
struct ReadingDocumentStoreSelectionTests {
    private static func makeStore() -> ReadingDocumentStore {
        ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: { _ in }
        )
    }

    private static func makeBlockData() -> (
        blockText: String,
        sentences: [ReadingSentenceSegment],
        paragraphs: [ReadingTextChunk]
    ) {
        let blockText = "The old clocktower had been silent for fifty years. Leo wanted to solve the mystery."
        let sentences = ReadingTextSegmenter.segmentSentences(
            blockText,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: "block-1"
        )
        let paragraphs = ReadingTextSegmenter.segmentParagraphs(
            blockText,
            documentID: "doc-1",
            contentRevision: 1
        )
        return (blockText, sentences, paragraphs)
    }

    @Test("selectTextFragment builds selection context with textFragment scope")
    func selectTextFragmentBuildsSelectionContextWithFragmentScope() {
        let store = Self.makeStore()
        let (blockText, sentences, paragraphs) = Self.makeBlockData()
        let selectedText = "clocktower"
        let offset = blockText.distance(
            from: blockText.startIndex,
            to: blockText.range(of: selectedText)!.lowerBound
        )

        store.selectTextFragment(
            selectedText: selectedText,
            blockID: "block-1",
            characterOffset: offset,
            characterLength: selectedText.count,
            sentences: sentences,
            paragraphs: paragraphs,
            fullDocumentText: blockText
        )

        #expect(store.selectedSelection?.selectionScope == .textFragment)
        #expect(store.selectedText == selectedText)
    }

    @Test("selectTextFragment clears existing explanation result")
    func selectTextFragmentClearsExistingExplanationResult() async {
        let store = Self.makeStore()
        let (blockText, sentences, paragraphs) = Self.makeBlockData()

        // First selection: trigger explain and fake a result via selectSelection directly
        store.selectText("first word", sentenceID: "s1")
        store.explainSelection()
        // Drive the explanation to completion synchronously via a stub
        await Task.yield()

        // Simulate having a result by selecting a pre-built context with known state
        store.selectText("prior selection", sentenceID: "prior-s")
        // Inject a fake result by going through the explanation path
        // Since we can't easily inject an explanationResult, instead verify
        // that after selectTextFragment the explanationState resets to idle
        store.explainSelection()
        await Task.yield()

        let selectedText = "clocktower"
        let offset = blockText.distance(
            from: blockText.startIndex,
            to: blockText.range(of: selectedText)!.lowerBound
        )
        store.selectTextFragment(
            selectedText: selectedText,
            blockID: "block-1",
            characterOffset: offset,
            characterLength: selectedText.count,
            sentences: sentences,
            paragraphs: paragraphs,
            fullDocumentText: blockText
        )

        #expect(store.explanationResult == nil)
        #expect(store.explanationState == .idle)
    }

    @Test("selectTextFragment updates selectedText and selectedSentenceID")
    func selectTextFragmentUpdatesSelectedTextAndSentenceID() {
        let store = Self.makeStore()
        let (blockText, sentences, paragraphs) = Self.makeBlockData()
        let selectedText = "Leo"
        let offset = blockText.distance(
            from: blockText.startIndex,
            to: blockText.range(of: selectedText)!.lowerBound
        )

        store.selectTextFragment(
            selectedText: selectedText,
            blockID: "block-1",
            characterOffset: offset,
            characterLength: selectedText.count,
            sentences: sentences,
            paragraphs: paragraphs,
            fullDocumentText: blockText
        )

        #expect(store.selectedText == selectedText)
        // selectedSentenceID should match the containing sentence's id
        let expectedSentenceID = sentences.first(where: {
            $0.characterOffset <= offset && offset < $0.characterOffset + $0.characterLength
        })?.id
        #expect(store.selectedSentenceID == expectedSentenceID)
    }
}
