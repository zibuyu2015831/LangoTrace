import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Reading text segmentation")
struct ReadingTextSegmentationTests {
    @Test("paragraph chunks preserve character ranges")
    func paragraphChunksPreserveRanges() throws {
        let text = "Paragraph 1\n\nParagraph 2\n\nParagraph 3"
        let documentID = "doc-1"
        let revision = 1
        let chunks = ReadingTextSegmenter.segmentParagraphs(text, documentID: documentID, contentRevision: revision)

        #expect(chunks.count == 3)
        #expect(chunks[0].text == "Paragraph 1")
        #expect(chunks[1].text == "Paragraph 2")
        #expect(chunks[2].text == "Paragraph 3")

        for chunk in chunks {
            let swiftRange = try #require(chunk.range.toRange(in: text))
            #expect(text[swiftRange] == chunk.text)
        }
    }

    @Test("CRLF text segments into multiple paragraphs with ranges into the original text")
    func crlfTextSegmentsIntoParagraphs() throws {
        let text = "Paragraph 1\r\n\r\nParagraph 2\r\n\r\nParagraph 3"
        let chunks = ReadingTextSegmenter.segmentParagraphs(text, documentID: "doc-1", contentRevision: 1)

        #expect(chunks.count == 3)
        #expect(chunks[0].text == "Paragraph 1")
        #expect(chunks[1].text == "Paragraph 2")
        #expect(chunks[2].text == "Paragraph 3")

        for chunk in chunks {
            let swiftRange = try #require(chunk.range.toRange(in: text))
            #expect(text[swiftRange] == chunk.text)
        }

        let lonelyCarriageReturns = ReadingTextSegmenter.segmentParagraphs(
            "Alpha\r\rBeta",
            documentID: "doc-1",
            contentRevision: 1
        )
        #expect(lonelyCarriageReturns.map(\.text) == ["Alpha", "Beta"])
    }

    @Test("sentence segmentation handles mixed CJK and Latin text")
    func sentenceSegmentationHandlesMixedCJK() {
        let text = "Hello world. 你好世界。This is a test. 这是一个测试。"
        let blockID = "block-1"
        let segments = ReadingTextSegmenter.segmentSentences(
            text,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: blockID
        )

        #expect(segments.count == 4)
        #expect(segments[0].text == "Hello world.")
        #expect(segments[1].text == "你好世界。")
        #expect(segments[2].text == "This is a test.")
        #expect(segments[3].text == "这是一个测试。")
    }

    @Test("sentence segmentation preserves indices within paragraph")
    func sentenceSegmentationPreservesIndices() {
        let text = "The old clocktower had been silent for fifty years. Leo wanted to solve the mystery."
        let blockID = "block-1"
        let sentences = ReadingTextSegmenter.segmentSentences(
            text,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: blockID,
            paragraphIndex: 2
        )

        #expect(sentences.count == 2)
        #expect(sentences[0].paragraphIndex == 2)
        #expect(sentences[0].sentenceIndex == 0)
        #expect(sentences[0].text == "The old clocktower had been silent for fifty years.")

        #expect(sentences[1].paragraphIndex == 2)
        #expect(sentences[1].sentenceIndex == 1)
        #expect(sentences[1].text == "Leo wanted to solve the mystery.")
    }

    @Test("manual selection does not require whitespace tokenization")
    func manualSelectionNoWhitespaceTokenization() {
        let text = "ThisIsAWord"
        let blockID = "block-1"
        let segments = ReadingTextSegmenter.segmentSentences(
            text,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: blockID
        )

        #expect(segments.count == 1)
        #expect(segments[0].text == "ThisIsAWord")
    }

    @Test("short document selection uses full document context")
    func shortDocumentSelectionUsesFullDocument() {
        let text = "Short doc."
        let sentences = ReadingTextSegmenter.segmentSentences(
            text,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: "block-1"
        )
        let paragraphs = ReadingTextSegmenter.segmentParagraphs(
            text,
            documentID: "doc-1",
            contentRevision: 1
        )

        let context = ReadingTextSegmenter.makeSentenceSelectionContext(
            sentences[0],
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            paragraphs: paragraphs,
            fullDocumentText: text
        )

        #expect(context.contextMode == .fullDocument)
        #expect(context.contextText == "Short doc.")
    }

    @Test("sentence segmentation produces continuous non-overlapping character offsets")
    func sentenceSegmentationProducesContinuousCharacterOffsets() {
        let blockText = "The old clocktower had been silent for fifty years. Leo wanted to solve the mystery. He climbed the stairs at midnight."
        let sentences = ReadingTextSegmenter.segmentSentences(
            blockText,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: "block-1"
        )

        #expect(sentences.count >= 3)
        for i in 1 ..< sentences.count {
            let prev = sentences[i - 1]
            let curr = sentences[i]
            // Each sentence starts after the previous one ends (no overlap)
            #expect(curr.characterOffset >= prev.characterOffset + prev.characterLength)
            // Offsets are strictly increasing
            #expect(curr.characterOffset > prev.characterOffset)
        }
    }
}
