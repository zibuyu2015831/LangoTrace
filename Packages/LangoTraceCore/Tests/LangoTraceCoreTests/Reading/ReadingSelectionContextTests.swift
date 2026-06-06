import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Reading selection context")
struct ReadingSelectionContextTests {
    @Test("fragment selection context finds containing sentence by character offset")
    func fragmentSelectionContextFindsSentenceByOffset() throws {
        let blockText = "The old clocktower had been silent for fifty years. Leo wanted to solve the mystery."
        let blockID = "block-1"
        let sentences = ReadingTextSegmenter.segmentSentences(
            blockText,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: blockID
        )
        let paragraphs = ReadingTextSegmenter.segmentParagraphs(
            blockText,
            documentID: "doc-1",
            contentRevision: 1
        )

        // Select "clocktower" (offset 8, length 10)
        let selectedText = "clocktower"
        let offset = try blockText.distance(
            from: blockText.startIndex,
            to: #require(blockText.range(of: selectedText)?.lowerBound)
        )

        let context = ReadingTextSegmenter.makeFragmentSelectionContext(
            input: ReadingFragmentSelectionInput(
                selectedText: selectedText,
                blockID: blockID,
                characterOffset: offset,
                characterLength: selectedText.count,
                precomputedSentences: sentences,
                documentID: "doc-1",
                contentRevision: 1,
                structureVersion: 1,
                paragraphs: paragraphs,
                fullDocumentText: blockText
            )
        )

        #expect(context.selectionScope == .textFragment)
        #expect(context.containingSentence == "The old clocktower had been silent for fifty years.")
        #expect(context.selectedText == selectedText)
    }

    @Test("fragment selection context falls back to block text when offset is out of all sentences")
    func fragmentSelectionContextFallsBackToBlockTextWhenOffsetOutOfAllSentences() {
        // Construct text where the selection lands in whitespace between sentences
        let blockText = "First sentence.  Second sentence."
        let blockID = "block-1"
        // Manually create a single sentence that covers only "First sentence."
        let sentences = [
            ReadingSentenceSegment(
                id: "\(blockID)-sentence-0",
                documentID: "doc-1",
                contentRevision: 1,
                structureVersion: 1,
                blockID: blockID,
                paragraphIndex: 0,
                sentenceIndex: 0,
                text: "First sentence.",
                containingParagraph: blockText,
                characterOffset: 0,
                characterLength: 15
            ),
        ]
        let paragraphs = ReadingTextSegmenter.segmentParagraphs(
            blockText,
            documentID: "doc-1",
            contentRevision: 1
        )
        // Select the space gap between sentences (offset 15, single space)
        let context = ReadingTextSegmenter.makeFragmentSelectionContext(
            input: ReadingFragmentSelectionInput(
                selectedText: " ",
                blockID: blockID,
                characterOffset: 15,
                characterLength: 1,
                precomputedSentences: sentences,
                documentID: "doc-1",
                contentRevision: 1,
                structureVersion: 1,
                paragraphs: paragraphs,
                fullDocumentText: blockText
            )
        )

        #expect(context.selectionScope == .textFragment)
        // Fallback: containingSentence = block text (trimmed)
        #expect(context.containingSentence == blockText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test("fragment selection context returns correct previous and next sentences")
    func fragmentSelectionContextPreviousAndNextSentenceFromPrecomputedArray() throws {
        let blockText = "First sentence. Second sentence. Third sentence."
        let blockID = "block-1"
        let sentences = ReadingTextSegmenter.segmentSentences(
            blockText,
            documentID: "doc-1",
            contentRevision: 1,
            structureVersion: 1,
            blockID: blockID
        )
        let paragraphs = ReadingTextSegmenter.segmentParagraphs(
            blockText,
            documentID: "doc-1",
            contentRevision: 1
        )
        // Select a word in the second sentence
        let selectedText = "Second"
        let offset = try blockText.distance(
            from: blockText.startIndex,
            to: #require(blockText.range(of: selectedText)?.lowerBound)
        )

        let context = ReadingTextSegmenter.makeFragmentSelectionContext(
            input: ReadingFragmentSelectionInput(
                selectedText: selectedText,
                blockID: blockID,
                characterOffset: offset,
                characterLength: selectedText.count,
                precomputedSentences: sentences,
                documentID: "doc-1",
                contentRevision: 1,
                structureVersion: 1,
                paragraphs: paragraphs,
                fullDocumentText: blockText
            )
        )

        #expect(context.previousSentence == "First sentence.")
        #expect(context.nextSentence == "Third sentence.")
    }

    @Test("fragment selection context mode follows document length threshold")
    func fragmentSelectionContextModeFollowsDocumentLengthThreshold() {
        let shortDoc = "The old clocktower had been silent for fifty years. Leo wanted to solve the mystery."
        let blockID = "block-1"
        let shortSentences = ReadingTextSegmenter.segmentSentences(
            shortDoc,
            documentID: "doc-short",
            contentRevision: 1,
            structureVersion: 1,
            blockID: blockID
        )
        let shortParagraphs = ReadingTextSegmenter.segmentParagraphs(
            shortDoc,
            documentID: "doc-short",
            contentRevision: 1
        )

        let shortContext = ReadingTextSegmenter.makeFragmentSelectionContext(
            input: ReadingFragmentSelectionInput(
                selectedText: "clocktower",
                blockID: blockID,
                characterOffset: 8,
                characterLength: 10,
                precomputedSentences: shortSentences,
                documentID: "doc-short",
                contentRevision: 1,
                structureVersion: 1,
                paragraphs: shortParagraphs,
                fullDocumentText: shortDoc
            )
        )
        #expect(shortContext.contextMode == .fullDocument)

        // Long document (>1200 chars)
        let longParagraph = String(repeating: "Long document sentence content here. ", count: 40)
        let longDoc = "\(longParagraph)\n\n\(longParagraph)"
        let longBlockID = "block-long"
        let longSentences = ReadingTextSegmenter.segmentSentences(
            longParagraph,
            documentID: "doc-long",
            contentRevision: 1,
            structureVersion: 1,
            blockID: longBlockID,
            paragraphIndex: 0
        )
        let longParagraphs = ReadingTextSegmenter.segmentParagraphs(
            longDoc,
            documentID: "doc-long",
            contentRevision: 1
        )

        let longContext = ReadingTextSegmenter.makeFragmentSelectionContext(
            input: ReadingFragmentSelectionInput(
                selectedText: "document",
                blockID: longBlockID,
                characterOffset: 5,
                characterLength: 8,
                precomputedSentences: longSentences,
                documentID: "doc-long",
                contentRevision: 1,
                structureVersion: 1,
                paragraphs: longParagraphs,
                fullDocumentText: longDoc
            )
        )
        #expect(longContext.contextMode != .fullDocument)
    }

    @Test("fragment selection context with empty sentence array falls back to block text")
    func fragmentSelectionContextWithEmptySentencesUsesBlockText() {
        let blockText = "Some text without precomputed segments."
        let blockID = "block-x"
        let paragraphs = ReadingTextSegmenter.segmentParagraphs(
            blockText,
            documentID: "doc-1",
            contentRevision: 1
        )

        let context = ReadingTextSegmenter.makeFragmentSelectionContext(
            input: ReadingFragmentSelectionInput(
                selectedText: "text",
                blockID: blockID,
                characterOffset: 5,
                characterLength: 4,
                precomputedSentences: [],
                documentID: "doc-1",
                contentRevision: 1,
                structureVersion: 1,
                paragraphs: paragraphs,
                fullDocumentText: blockText
            )
        )

        #expect(context.selectionScope == .textFragment)
        #expect(context.selectedText == "text")
        #expect(context.sentenceID == "\(blockID)-fragment")
        #expect(context.containingSentence == blockText.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(context.previousSentence == nil)
        #expect(context.nextSentence == nil)
    }
}
