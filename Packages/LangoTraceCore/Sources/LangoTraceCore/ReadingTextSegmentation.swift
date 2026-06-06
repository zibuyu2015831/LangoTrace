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

public enum ReadingSelectionScope: String, Equatable, Hashable, Sendable {
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
            let paragraph = String(text[rawRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraph.isEmpty else {
                return
            }
            chunkIndex += 1
            chunks.append(ReadingTextChunk(
                id: "\(documentID)-paragraph-\(chunkIndex)",
                documentID: documentID,
                contentRevision: contentRevision,
                text: String(text[rawRange]),
                range: rawRange
            ))
        }

        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if text[index] == "\n", next < text.endIndex, text[next] == "\n" {
                appendParagraph(upTo: index)
                paragraphStart = text.index(after: next)
                index = paragraphStart
            } else {
                index = next
            }
        }
        appendParagraph(upTo: text.endIndex)
        return chunks
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
            let sentenceRange = Range(range, in: text) ?? text.startIndex ..< text.startIndex
            let rawSentence = String(text[sentenceRange])
            let trimmedSentence = rawSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSentence.isEmpty else { return }
            guard let trimmedRange = rawSentence.range(of: trimmedSentence) else { return }
            let offsetInRaw = rawSentence.distance(from: rawSentence.startIndex, to: trimmedRange.lowerBound)
            let characterOffset = range.location + offsetInRaw
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
                containingParagraph: text.trimmingCharacters(in: .whitespacesAndNewlines),
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
                    text: trimmed,
                    containingParagraph: trimmed,
                    characterOffset: 0,
                    characterLength: trimmed.count
                ),
            ]
        }

        return segments
    }

    public static func makeFragmentSelectionContext(
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
    ) -> ReadingSelectionContext {
        // Find the sentence that contains this character offset
        var containingSeg = precomputedSentences.first(where: {
            $0.characterOffset <= characterOffset &&
                characterOffset < $0.characterOffset + $0.characterLength
        })

        // If the offset falls in whitespace between sentences, try the midpoint
        if containingSeg == nil {
            let midpoint = characterOffset + characterLength / 2
            containingSeg = precomputedSentences.first(where: {
                $0.characterOffset <= midpoint &&
                    midpoint < $0.characterOffset + $0.characterLength
            })
        }

        let sentenceID: String
        let containingSentence: String
        let previousSentence: String?
        let nextSentence: String?
        let containingParagraph: String

        if let seg = containingSeg {
            sentenceID = seg.id
            containingSentence = seg.text
            let idx = seg.sentenceIndex
            previousSentence = idx > 0 ? precomputedSentences[idx - 1].text : nil
            nextSentence = idx + 1 < precomputedSentences.count ? precomputedSentences[idx + 1].text : nil
            containingParagraph = seg.containingParagraph
        } else {
            // Fallback: use the block's full text as containing sentence
            let trimmed = fullDocumentText.trimmingCharacters(in: .whitespacesAndNewlines)
            sentenceID = "\(blockID)-fragment"
            containingSentence = trimmed
            previousSentence = nil
            nextSentence = nil
            containingParagraph = trimmed
        }

        let allParagraphs = paragraphs.map(\.text).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let paragraphIndex = precomputedSentences.first?.paragraphIndex ?? 0
        let previousParagraph = paragraphIndex > 0 ? allParagraphs[paragraphIndex - 1] : nil
        let nextParagraph = paragraphIndex + 1 < allParagraphs.count ? allParagraphs[paragraphIndex + 1] : nil

        let normalizedDocument = fullDocumentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextMode: ReadingContextMode
        let contextText: String
        if normalizedDocument.count <= 1200 {
            contextMode = .fullDocument
            contextText = normalizedDocument
        } else {
            let adjacentParts = [previousParagraph, containingParagraph, nextParagraph].compactMap(\.self)
            let adjacentParagraphText = adjacentParts.joined(separator: "\n\n")
            if adjacentParagraphText.count <= 3000 {
                contextMode = .adjacentParagraphs
                contextText = adjacentParagraphText
            } else {
                contextMode = .currentParagraph
                contextText = containingParagraph
            }
        }

        let selectedTextHash = sha256Hex(selectedText)
        return ReadingSelectionContext(
            sourceAnchorID: sourceAnchorID(
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: structureVersion,
                blockID: blockID,
                sentenceID: sentenceID,
                selectedTextHash: selectedTextHash,
                characterOffset: characterOffset,
                characterLength: characterLength
            ),
            blockID: blockID,
            sentenceID: sentenceID,
            selectionScope: .textFragment,
            selectedText: selectedText,
            selectedTextHash: selectedTextHash,
            characterOffset: characterOffset,
            characterLength: characterLength,
            containingSentence: containingSentence,
            previousSentence: previousSentence,
            nextSentence: nextSentence,
            containingParagraph: containingParagraph,
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

        let allSentences = segmentSentences(
            currentParagraph,
            documentID: documentID,
            contentRevision: contentRevision,
            structureVersion: structureVersion,
            blockID: sentence.blockID,
            paragraphIndex: sentence.paragraphIndex
        )
        let previousSentence = sentence.sentenceIndex > 0 ? allSentences[sentence.sentenceIndex - 1].text : nil
        let nextSentence = sentence.sentenceIndex + 1 < allSentences.count ? allSentences[sentence.sentenceIndex + 1].text : nil

        let normalizedDocument = fullDocumentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextMode: ReadingContextMode
        let contextText: String
        if normalizedDocument.count <= 1200 {
            contextMode = .fullDocument
            contextText = normalizedDocument
        } else {
            let adjacentParts = [previousParagraph, currentParagraph, nextParagraph].compactMap(\.self)
            let adjacentParagraphText = adjacentParts.joined(separator: "\n\n")
            if adjacentParagraphText.count <= 3000 {
                contextMode = .adjacentParagraphs
                contextText = adjacentParagraphText
            } else {
                contextMode = .currentParagraph
                contextText = currentParagraph
            }
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
        [
            "readingSelection",
            documentID,
            "\(contentRevision)",
            "\(structureVersion)",
            blockID,
            sentenceID,
            selectedTextHash,
            "\(characterOffset)",
            "\(characterLength)",
        ].joined(separator: "|")
    }

    public static func sha256Hex(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
