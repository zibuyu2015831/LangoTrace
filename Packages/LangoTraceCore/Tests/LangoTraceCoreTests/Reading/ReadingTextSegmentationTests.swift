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

    @Test("fragment selection context finds containing sentence by character offset")
    func fragmentSelectionContextFindsContainingSentenceByCharacterOffset() {
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
        // "clocktower" starts at offset 8 in the first sentence
        let selectedText = "clocktower"
        let offset = blockText.distance(
            from: blockText.startIndex,
            to: blockText.range(of: selectedText)!.lowerBound
        )

        let context = ReadingTextSegmenter.makeFragmentSelectionContext(
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

        #expect(context.selectionScope == .textFragment)
        // Fallback: containingSentence = block text (trimmed)
        #expect(context.containingSentence == blockText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test("fragment selection context returns correct previous and next sentences")
    func fragmentSelectionContextPreviousAndNextSentenceFromPrecomputedArray() {
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
        let offset = blockText.distance(
            from: blockText.startIndex,
            to: blockText.range(of: selectedText)!.lowerBound
        )

        let context = ReadingTextSegmenter.makeFragmentSelectionContext(
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
        #expect(longContext.contextMode != .fullDocument)
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
