import Foundation
import LangoTraceCore

public extension ReadingDocumentStore {
    func selectText(_ text: String, sentenceID: String?, containingSentence: String = "") {
        let sentenceIdentifier = sentenceID ?? "\(documentID)-selection"
        selectSelection(ReadingSelectionContext(
            sourceAnchorID: ReadingTextSegmenter.sourceAnchorID(
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: 0,
                blockID: sentenceIdentifier,
                sentenceID: sentenceIdentifier,
                selectedTextHash: StableHashing.sha256Hex(text),
                characterOffset: 0,
                characterLength: text.count
            ),
            blockID: sentenceIdentifier,
            sentenceID: sentenceIdentifier,
            selectionScope: .sentence,
            selectedText: text,
            selectedTextHash: StableHashing.sha256Hex(text),
            characterOffset: 0,
            characterLength: text.count,
            containingSentence: containingSentence.isEmpty ? text : containingSentence,
            previousSentence: nil,
            nextSentence: nil,
            containingParagraph: containingSentence.isEmpty ? text : containingSentence,
            contextMode: .currentParagraph,
            contextText: containingSentence.isEmpty ? text : containingSentence
        ))
    }

    func selectTextFragment(
        selectedText: String,
        blockID: String,
        characterOffset: Int,
        characterLength: Int,
        sentences: [ReadingSentenceSegment],
        paragraphs: [ReadingTextChunk],
        fullDocumentText: String
    ) {
        let context = ReadingTextSegmenter.makeFragmentSelectionContext(
            input: ReadingFragmentSelectionInput(
                selectedText: selectedText,
                blockID: blockID,
                characterOffset: characterOffset,
                characterLength: characterLength,
                precomputedSentences: sentences,
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: 0,
                paragraphs: paragraphs,
                fullDocumentText: fullDocumentText
            )
        )
        selectSelection(context)
    }

    /// Convenience overload: reconstructs ReadingSentenceSegment from the presentation layer's
    /// ReadingSentencePresentation array, using blockText as a single-block context document.
    func selectTextFragment(
        selectedText: String,
        blockID: String,
        characterOffset: Int,
        characterLength: Int,
        sentencePresentations: [ReadingSentencePresentation],
        blockText: String
    ) {
        let sentences = sentencePresentations.map { pres in
            ReadingSentenceSegment(
                id: pres.selection.sentenceID,
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: 0,
                blockID: pres.blockID,
                paragraphIndex: 0,
                sentenceIndex: pres.sentenceIndex,
                text: pres.text,
                containingParagraph: pres.selection.containingParagraph,
                characterOffset: pres.selection.characterOffset,
                characterLength: pres.selection.characterLength
            )
        }
        let paragraphs = [ReadingTextChunk(
            id: "\(documentID)-\(blockID)-p0",
            documentID: documentID,
            contentRevision: contentRevision,
            text: blockText,
            range: TextUnitRange(blockText.startIndex ..< blockText.endIndex, in: blockText)
        )]
        selectTextFragment(
            selectedText: selectedText,
            blockID: blockID,
            characterOffset: characterOffset,
            characterLength: characterLength,
            sentences: sentences,
            paragraphs: paragraphs,
            fullDocumentText: blockText
        )
    }

    func selectSelection(_ selection: ReadingSelectionContext) {
        selectedSelection = selection
        selectedText = selection.selectedText
        selectedSentenceID = selection.sentenceID
        containingSentence = selection.containingSentence
        explanationResult = nil
        explanationState = .idle
        audioState = .idle
        invalidateInFlightWork()
    }

    func playSentence(sentenceID: String, text: String) {
        guard audioState != .loading else {
            return
        }
        audioState = .loading
        let token = nextToken()
        let request = ReadingTTSRequest(
            documentID: documentID,
            spaceID: spaceID,
            sentenceID: sentenceID,
            text: text,
            targetLanguageCode: targetLanguageCode
        )
        ttsTask?.cancel()
        ttsTask = Task {
            await ttsAction(request)
            completeTTS(token: token, request: request)
        }
    }

    func playSelectionSentence() {
        guard let selection = selectedSelection ?? fallbackSelection else { return }
        if selection.selectionScope == .textFragment {
            // For a word/phrase selection, play just the selected text (pronunciation).
            // Use an offset-keyed sentenceID to avoid overwriting the sentence-level TTS cache.
            let fragmentSentenceID = "\(selection.sentenceID)-frag-\(selection.characterOffset)"
            playSentence(sentenceID: fragmentSentenceID, text: selection.selectedText)
        } else {
            playSentence(sentenceID: selection.sentenceID, text: selection.containingSentence)
        }
    }

    internal var fallbackSelection: ReadingSelectionContext? {
        guard let selectedText, let selectedSentenceID else { return nil }
        return ReadingSelectionContext(
            sourceAnchorID: ReadingTextSegmenter.sourceAnchorID(
                documentID: documentID,
                contentRevision: contentRevision,
                structureVersion: 0,
                blockID: selectedSentenceID,
                sentenceID: selectedSentenceID,
                selectedTextHash: StableHashing.sha256Hex(selectedText),
                characterOffset: 0,
                characterLength: selectedText.count
            ),
            blockID: selectedSentenceID,
            sentenceID: selectedSentenceID,
            selectionScope: .sentence,
            selectedText: selectedText,
            selectedTextHash: StableHashing.sha256Hex(selectedText),
            characterOffset: 0,
            characterLength: selectedText.count,
            containingSentence: containingSentence.isEmpty ? selectedText : containingSentence,
            previousSentence: nil,
            nextSentence: nil,
            containingParagraph: containingSentence.isEmpty ? selectedText : containingSentence,
            contextMode: .currentParagraph,
            contextText: containingSentence.isEmpty ? selectedText : containingSentence
        )
    }
}
