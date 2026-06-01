import Testing
@testable import LangoTraceCore

@Suite("Reading text segmentation")
struct ReadingTextSegmentationTests {
    @Test("paragraph chunks preserve character ranges")
    func paragraphChunksPreserveRanges() {
        let text = "First sentence.\n\nSecond paragraph has two sentences. Another one."

        let chunks = ReadingTextSegmenter.segmentParagraphs(
            text,
            documentID: "doc-1",
            contentRevision: 3
        )

        #expect(chunks.count == 2)
        #expect(chunks[0].range.lowerBound == text.startIndex)
        #expect(String(text[chunks[0].range]).contains("First sentence."))
        #expect(chunks[1].contentRevision == 3)
    }

    @Test("manual selection does not require whitespace tokenization")
    func selectionSupportsCJKAndRTL() {
        let text = "今日は図書館で読みます。 שלום עולם"
        let selection = ReadingSelection(
            documentID: "doc-1",
            contentRevision: 1,
            selectedText: "図書館",
            contextText: text,
            characterOffset: 3
        )

        #expect(selection.selectedText == "図書館")
        #expect(selection.contextText.contains("שלום"))
    }

    @Test("manual selection records character range for later anchoring")
    func selectionRecordsCharacterRange() {
        let text = "Read this sentence carefully."
        let start = text.range(of: "sentence")!.lowerBound
        let end = text.index(start, offsetBy: 8)
        let selection = ReadingSelection(
            documentID: "doc-1",
            contentRevision: 1,
            selectedText: String(text[start..<end]),
            contextText: text,
            characterOffset: text.distance(from: text.startIndex, to: start),
            characterLength: text.distance(from: start, to: end)
        )

        #expect(selection.selectedText == "sentence")
        #expect(selection.characterOffset > 0)
        #expect(selection.characterLength == 8)
    }

    @Test("10k character text is chunked instead of represented as one view unit")
    func tenThousandCharacterTextIsChunked() {
        let paragraph = String(repeating: "This is a language learning sentence. ", count: 25)
        let text = Array(repeating: paragraph, count: 16).joined(separator: "\n\n")

        let chunks = ReadingTextSegmenter.segmentParagraphs(
            text,
            documentID: "doc-long",
            contentRevision: 1
        )

        #expect(text.count > 10_000)
        #expect(chunks.count == 16)
        #expect(chunks.allSatisfy { !$0.text.isEmpty })
    }
}
