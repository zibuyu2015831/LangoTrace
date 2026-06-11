import CryptoKit
import Foundation

public struct ReadingTextChunk: Equatable, Sendable {
    public var id: String
    public var documentID: String
    public var contentRevision: Int
    public var text: String
    public var range: Range<String.Index>

    public init(
        id: String,
        documentID: String,
        contentRevision: Int,
        text: String,
        range: Range<String.Index>
    ) {
        self.id = id
        self.documentID = documentID
        self.contentRevision = contentRevision
        self.text = text
        self.range = range
    }
}

public struct ReadingSelection: Equatable, Sendable {
    public var documentID: String
    public var contentRevision: Int
    public var selectedText: String
    public var contextText: String
    public var characterOffset: Int
    public var characterLength: Int

    public init(
        documentID: String,
        contentRevision: Int,
        selectedText: String,
        contextText: String,
        characterOffset: Int,
        characterLength: Int? = nil
    ) {
        self.documentID = documentID
        self.contentRevision = contentRevision
        self.selectedText = selectedText
        self.contextText = contextText
        self.characterOffset = characterOffset
        self.characterLength = characterLength ?? selectedText.count
    }
}

public enum ReadingSelectionScope: String, Codable, Equatable, Hashable, Sendable {
    case sentence
    case textFragment = "text_fragment"
}

public enum ReadingContextMode: String, Equatable, Hashable, Sendable {
    case fullDocument = "full_document"
    case adjacentParagraphs = "adjacent_paragraphs"
    case currentParagraph = "current_paragraph"
}

public struct ReadingSentenceSegment: Equatable, Sendable {
    public var id: String
    public var documentID: String
    public var contentRevision: Int
    public var structureVersion: Int
    public var blockID: String
    public var paragraphIndex: Int
    public var sentenceIndex: Int
    public var text: String
    public var containingParagraph: String
    public var characterOffset: Int
    public var characterLength: Int

    public init(
        id: String,
        documentID: String,
        contentRevision: Int,
        structureVersion: Int,
        blockID: String,
        paragraphIndex: Int,
        sentenceIndex: Int,
        text: String,
        containingParagraph: String,
        characterOffset: Int,
        characterLength: Int
    ) {
        self.id = id
        self.documentID = documentID
        self.contentRevision = contentRevision
        self.structureVersion = structureVersion
        self.blockID = blockID
        self.paragraphIndex = paragraphIndex
        self.sentenceIndex = sentenceIndex
        self.text = text
        self.containingParagraph = containingParagraph
        self.characterOffset = characterOffset
        self.characterLength = characterLength
    }
}

public struct ReadingSelectionContext: Equatable, Sendable {
    public var sourceAnchorID: String
    public var blockID: String
    public var sentenceID: String
    public var selectionScope: ReadingSelectionScope
    public var selectedText: String
    public var selectedTextHash: String
    public var characterOffset: Int
    public var characterLength: Int
    public var containingSentence: String
    public var previousSentence: String?
    public var nextSentence: String?
    public var containingParagraph: String
    public var contextMode: ReadingContextMode
    public var contextText: String

    public init(
        sourceAnchorID: String,
        blockID: String,
        sentenceID: String,
        selectionScope: ReadingSelectionScope,
        selectedText: String,
        selectedTextHash: String,
        characterOffset: Int,
        characterLength: Int,
        containingSentence: String,
        previousSentence: String?,
        nextSentence: String?,
        containingParagraph: String,
        contextMode: ReadingContextMode,
        contextText: String
    ) {
        self.sourceAnchorID = sourceAnchorID
        self.blockID = blockID
        self.sentenceID = sentenceID
        self.selectionScope = selectionScope
        self.selectedText = selectedText
        self.selectedTextHash = selectedTextHash
        self.characterOffset = characterOffset
        self.characterLength = characterLength
        self.containingSentence = containingSentence
        self.previousSentence = previousSentence
        self.nextSentence = nextSentence
        self.containingParagraph = containingParagraph
        self.contextMode = contextMode
        self.contextText = contextText
    }
}

public struct ReadingFragmentSelectionInput: Sendable {
    public var selectedText: String
    public var blockID: String
    public var characterOffset: Int
    public var characterLength: Int
    public var precomputedSentences: [ReadingSentenceSegment]
    public var documentID: String
    public var contentRevision: Int
    public var structureVersion: Int
    public var paragraphs: [ReadingTextChunk]
    public var fullDocumentText: String

    public init(
        selectedText: String,
        blockID: String,
        characterOffset: Int,
        characterLength: Int,
        precomputedSentences: [ReadingSentenceSegment],
        documentID: String,
        contentRevision: Int,
        structureVersion: Int,
        paragraphs: [ReadingTextChunk],
        fullDocumentText: String
    ) {
        self.selectedText = selectedText
        self.blockID = blockID
        self.characterOffset = characterOffset
        self.characterLength = characterLength
        self.precomputedSentences = precomputedSentences
        self.documentID = documentID
        self.contentRevision = contentRevision
        self.structureVersion = structureVersion
        self.paragraphs = paragraphs
        self.fullDocumentText = fullDocumentText
    }
}

// swiftlint:disable:next file_length
public enum ReadingTextSegmenter {
    public static func segmentParagraphs(
        _ text: String,
        documentID: String,
        contentRevision: Int
    ) -> [ReadingTextChunk] {
        var chunks: [ReadingTextChunk] = []
        var chunkIndex = 0
        var paragraphStart = text.startIndex

        func appendParagraph(upTo end: String.Index) {
            let rawRange = paragraphStart ..< end
            let trimmed = text[rawRange].trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                chunkIndex += 1
                chunks.append(ReadingTextChunk(
                    id: "\(documentID)-paragraph-\(chunkIndex)",
                    documentID: documentID,
                    contentRevision: contentRevision,
                    text: String(text[rawRange]),
                    range: rawRange
                ))
            }
            paragraphStart = end
        }

        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            if isLineBreak(text[currentIndex]) {
                let nextIndex = text.index(after: currentIndex)
                if nextIndex < text.endIndex, isLineBreak(text[nextIndex]) {
                    appendParagraph(upTo: currentIndex)
                    paragraphStart = text.index(after: nextIndex)
                    currentIndex = paragraphStart
                    continue
                }
            }
            currentIndex = text.index(after: currentIndex)
        }
        appendParagraph(upTo: text.endIndex)
        return chunks
    }

    /// Treats "\n", "\r\n", and lone "\r" as one line break each. "\r\n" is a single grapheme
    /// cluster, so CRLF documents segment into paragraphs without rewriting the input string
    /// and all chunk ranges keep pointing into the original text.
    private static func isLineBreak(_ character: Character) -> Bool {
        character == "\n" || character == "\r\n" || character == "\r"
    }

    public static func segmentSentences(
        _ text: String,
        documentID: String,
        contentRevision: Int,
        structureVersion: Int,
        blockID: String,
        paragraphIndex: Int = 0
    ) -> [ReadingSentenceSegment] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var segments: [ReadingSentenceSegment] = []

        nsText.enumerateSubstrings(in: fullRange, options: [.bySentences, .substringNotRequired]) { _, range, _, _ in
            let sentenceText = nsText.substring(with: range)
            let trimmedSentence = sentenceText.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedSentence.isEmpty else { return }

            // Find the actual offset of the trimmed part within the original block
            let leadingWhitespaceCount = sentenceText.prefix(while: { $0.isWhitespace || $0.isNewline }).count
            let characterOffset = range.location + leadingWhitespaceCount
            let characterLength = trimmedSentence.count

            let sentenceIndex = segments.count
            segments.append(ReadingSentenceSegment(
                id: "\(blockID)-sentence-\(sentenceIndex)",
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: structureVersion,
                blockID: blockID,
                paragraphIndex: paragraphIndex,
                sentenceIndex: sentenceIndex,
                text: trimmedSentence,
                containingParagraph: text,
                characterOffset: characterOffset,
                characterLength: characterLength
            ))
        }

        if segments.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            return [
                ReadingSentenceSegment(
                    id: "\(blockID)-sentence-0",
                    documentID: documentID,
                    contentRevision: contentRevision,
                    structureVersion: structureVersion,
                    blockID: blockID,
                    paragraphIndex: paragraphIndex,
                    sentenceIndex: 0,
                    text: text,
                    containingParagraph: text,
                    characterOffset: 0,
                    characterLength: trimmed.count
                ),
            ]
        }

        return segments
    }

    public static func makeFragmentSelectionContext(
        input: ReadingFragmentSelectionInput
    ) -> ReadingSelectionContext {
        // Find the sentence that contains this character offset
        var containingSeg = input.precomputedSentences.first(where: {
            $0.characterOffset <= input.characterOffset &&
                input.characterOffset < $0.characterOffset + $0.characterLength
        })

        // If the offset falls in whitespace between sentences, try the midpoint
        if containingSeg == nil {
            let mid = input.characterOffset + input.characterLength / 2
            containingSeg = input.precomputedSentences.first(where: {
                $0.characterOffset <= mid &&
                    mid < $0.characterOffset + $0.characterLength
            })
        }

        let sentenceID: String
        let containingSentence: String
        var previousSentence: String?
        var nextSentence: String?

        if let seg = containingSeg {
            sentenceID = seg.id
            containingSentence = seg.text
            let idx = input.precomputedSentences.firstIndex(where: { $0.id == seg.id })
            if let idx {
                if idx > 0 {
                    previousSentence = input.precomputedSentences[idx - 1].text
                }
                if idx < input.precomputedSentences.count - 1 {
                    nextSentence = input.precomputedSentences[idx + 1].text
                }
            }
        } else {
            // Fallback: use the block's full text as containing sentence
            let trimmed = input.fullDocumentText.trimmingCharacters(in: .whitespacesAndNewlines)
            sentenceID = "\(input.blockID)-fragment"
            containingSentence = trimmed
            previousSentence = nil
            nextSentence = nil
        }

        let allParagraphs = input.paragraphs.map(\.text).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let paragraphIndex = input.precomputedSentences.first?.paragraphIndex ?? 0
        let previousParagraph = paragraphIndex > 0 ? allParagraphs[paragraphIndex - 1] : nil
        let nextParagraph = paragraphIndex + 1 < allParagraphs.count ? allParagraphs[paragraphIndex + 1] : nil

        let normalizedDocument = input.fullDocumentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextMode: ReadingContextMode
        let contextText: String
        if normalizedDocument.count <= 1200 {
            contextMode = .fullDocument
            contextText = normalizedDocument
        } else if let prev = previousParagraph, let next = nextParagraph {
            contextMode = .adjacentParagraphs
            contextText = "\(prev)\n\n\(containingSentence)\n\n\(next)"
        } else {
            contextMode = .currentParagraph
            contextText = containingSentence
        }

        let selectedTextHash = sha256Hex(input.selectedText)
        return ReadingSelectionContext(
            sourceAnchorID: sourceAnchorID(
                documentID: input.documentID,
                contentRevision: input.contentRevision,
                structureVersion: input.structureVersion,
                blockID: input.blockID,
                sentenceID: sentenceID,
                selectedTextHash: selectedTextHash,
                characterOffset: input.characterOffset,
                characterLength: input.characterLength
            ),
            blockID: input.blockID,
            sentenceID: sentenceID,
            selectionScope: .textFragment,
            selectedText: input.selectedText,
            selectedTextHash: selectedTextHash,
            characterOffset: input.characterOffset,
            characterLength: input.characterLength,
            containingSentence: containingSentence,
            previousSentence: previousSentence,
            nextSentence: nextSentence,
            containingParagraph: containingSentence,
            contextMode: contextMode,
            contextText: contextText
        )
    }

    public static func makeSentenceSelectionContext(
        _ sentence: ReadingSentenceSegment,
        documentID: String,
        contentRevision: Int,
        structureVersion: Int,
        paragraphs: [ReadingTextChunk],
        fullDocumentText: String
    ) -> ReadingSelectionContext {
        let allParagraphs = paragraphs.map(\.text).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let currentParagraph = sentence.containingParagraph
        let previousParagraph = sentence.paragraphIndex > 0 ? allParagraphs[sentence.paragraphIndex - 1] : nil
        let nextParagraph = sentence.paragraphIndex + 1 < allParagraphs.count ? allParagraphs[sentence.paragraphIndex + 1] : nil

        let sentencesInParagraph = segmentSentences(
            currentParagraph,
            documentID: documentID,
            contentRevision: contentRevision,
            structureVersion: structureVersion,
            blockID: sentence.blockID,
            paragraphIndex: sentence.paragraphIndex
        )

        var previousSentence: String?
        var nextSentence: String?

        if let idx = sentencesInParagraph.firstIndex(where: { $0.id == sentence.id }) {
            if idx > 0 {
                previousSentence = sentencesInParagraph[idx - 1].text
            }
            if idx < sentencesInParagraph.count - 1 {
                nextSentence = sentencesInParagraph[idx + 1].text
            }
        }

        let normalizedDocument = fullDocumentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextMode: ReadingContextMode
        let contextText: String
        if normalizedDocument.count <= 1200 {
            contextMode = .fullDocument
            contextText = normalizedDocument
        } else if let prev = previousParagraph, let next = nextParagraph {
            contextMode = .adjacentParagraphs
            contextText = "\(prev)\n\n\(currentParagraph)\n\n\(next)"
        } else {
            contextMode = .currentParagraph
            contextText = currentParagraph
        }

        let selectedTextHash = sha256Hex(sentence.text)
        return ReadingSelectionContext(
            sourceAnchorID: sourceAnchorID(
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: structureVersion,
                blockID: sentence.blockID,
                sentenceID: sentence.id,
                selectedTextHash: selectedTextHash,
                characterOffset: sentence.characterOffset,
                characterLength: sentence.characterLength
            ),
            blockID: sentence.blockID,
            sentenceID: sentence.id,
            selectionScope: .sentence,
            selectedText: sentence.text,
            selectedTextHash: selectedTextHash,
            characterOffset: sentence.characterOffset,
            characterLength: sentence.characterLength,
            containingSentence: sentence.text,
            previousSentence: previousSentence,
            nextSentence: nextSentence,
            containingParagraph: currentParagraph,
            contextMode: contextMode,
            contextText: contextText
        )
    }

    public static func sourceAnchorID(
        documentID: String,
        contentRevision: Int,
        structureVersion: Int,
        blockID: String,
        sentenceID: String,
        selectedTextHash: String,
        characterOffset: Int,
        characterLength: Int
    ) -> String {
        let components = [
            documentID,
            "\(contentRevision)",
            "\(structureVersion)",
            blockID,
            sentenceID,
            selectedTextHash,
            "\(characterOffset)",
            "\(characterLength)",
        ]
        return sha256Hex(components.joined(separator: "|"))
    }

    public static func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
