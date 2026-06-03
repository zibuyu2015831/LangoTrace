@testable import LangoTraceCore
import Testing

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
    func selectionRecordsCharacterRange() throws {
        let text = "Read this sentence carefully."
        let start = try #require(text.range(of: "sentence")?.lowerBound)
        let end = text.index(start, offsetBy: 8)
        let selection = ReadingSelection(
            documentID: "doc-1",
            contentRevision: 1,
            selectedText: String(text[start ..< end]),
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

        #expect(text.count > 10000)
        #expect(chunks.count == 16)
        #expect(chunks.allSatisfy { !$0.text.isEmpty })
    }

    @Test("sentence segmentation preserves indices within paragraph")
    func sentenceSegmentationPreservesIndicesWithinParagraph() {
        let paragraph = "The old clocktower had been silent for fifty years. Leo wanted to solve the mystery."

        let sentences = ReadingTextSegmenter.segmentSentences(
            paragraph,
            documentID: "doc-1",
            contentRevision: 2,
            structureVersion: 3,
            blockID: "block-1"
        )

        #expect(sentences.count == 2)
        #expect(sentences[0].sentenceIndex == 0)
        #expect(sentences[1].sentenceIndex == 1)
        #expect(sentences[0].text == "The old clocktower had been silent for fifty years.")
        #expect(sentences[1].characterOffset > sentences[0].characterOffset)
    }

    @Test("short document selection uses full document context")
    func shortDocumentSelectionUsesFullDocumentContext() throws {
        let document = """
        The old clocktower had been silent for fifty years. Leo wanted to solve the mystery.
        """

        let paragraphs = ReadingTextSegmenter.segmentParagraphs(
            document,
            documentID: "doc-1",
            contentRevision: 1
        )
        let sentence = try #require(ReadingTextSegmenter.segmentSentences(
            document,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: "block-1"
        ).first)

        let context = ReadingTextSegmenter.makeSentenceSelectionContext(
            sentence,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            paragraphs: paragraphs,
            fullDocumentText: document
        )

        #expect(context.contextMode == .fullDocument)
        #expect(context.contextText == document)
    }

    @Test("long document selection uses adjacent paragraph context")
    func longDocumentSelectionUsesAdjacentParagraphContext() throws {
        let first = String(repeating: "First paragraph sentence. ", count: 30)
        let second = String(repeating: "Middle paragraph sentence. ", count: 30)
        let third = String(repeating: "Last paragraph sentence. ", count: 30)
        let document = "\(first)\n\n\(second)\n\n\(third)"

        let paragraphs = ReadingTextSegmenter.segmentParagraphs(
            document,
            documentID: "doc-1",
            contentRevision: 1
        )
        let middleParagraph = paragraphs[1]
        let sentence = try #require(ReadingTextSegmenter.segmentSentences(
            middleParagraph.text,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: "block-2",
            paragraphIndex: 1
        ).first)

        let context = ReadingTextSegmenter.makeSentenceSelectionContext(
            sentence,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            paragraphs: paragraphs,
            fullDocumentText: document
        )

        #expect(context.contextMode == .adjacentParagraphs)
        #expect(context.contextText.contains(first.trimmingCharacters(in: .whitespacesAndNewlines)))
        #expect(context.contextText.contains(second.trimmingCharacters(in: .whitespacesAndNewlines)))
        #expect(context.contextText.contains(third.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
}
