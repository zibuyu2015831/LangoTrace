import LangoTraceCore

public enum ReadingMarkdownBlockRenderer {
    public static func render(
        document: ReadingMarkdownDocument,
        appearance: ReadingAppearanceProfile,
        platform _: ReadingPlatformRole,
        identity: ReadingDocumentRenderIdentity
    ) -> ReadingDocumentPresentation {
        let fullDocumentText = document.blocks
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        let paragraphChunks = document.blocks.map { block in
            let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return ReadingTextChunk(
                id: "\(block.id)-paragraph",
                documentID: identity.documentID,
                contentRevision: identity.contentRevision,
                text: trimmed,
                range: trimmed.startIndex ..< trimmed.endIndex
            )
        }
        let context = RenderContext(
            identity: identity,
            paragraphChunks: paragraphChunks,
            fullDocumentText: fullDocumentText
        )
        return ReadingDocumentPresentation(
            blocks: document.blocks.enumerated().map { blockIndex, block in
                ReadingBlockPresentation(
                    id: block.id,
                    kind: block.kind,
                    text: block.text,
                    sentences: sentencePresentations(
                        for: block,
                        blockIndex: blockIndex,
                        context: context
                    ),
                    inlineRuns: block.inlineRuns.map(inlinePresentation(for:)),
                    sourceRangeDescription: sourceRangeDescription(block.sourceRange)
                )
            },
            style: ReadingPresentationStyle(
                typographyRoles: appearance.typographyRoles,
                colorRoles: appearance.colorRoles,
                readingWidth: appearance.readingWidth,
                lineSpacing: appearance.lineSpacing,
                paragraphSpacing: appearance.paragraphSpacing
            )
        )
    }

    private static func sentencePresentations(
        for block: ReadingMarkdownBlock,
        blockIndex: Int,
        context: RenderContext
    ) -> [ReadingSentencePresentation] {
        guard isSelectable(block.kind) else { return [] }
        let sentences = ReadingTextSegmenter.segmentSentences(
            block.text,
            documentID: context.identity.documentID,
            contentRevision: context.identity.contentRevision,
            structureVersion: context.identity.structureVersion,
            blockID: block.id,
            paragraphIndex: blockIndex
        )
        return sentences.map { sentence in
            let selection = ReadingTextSegmenter.makeSentenceSelectionContext(
                sentence,
                documentID: context.identity.documentID,
                contentRevision: context.identity.contentRevision,
                structureVersion: context.identity.structureVersion,
                paragraphs: context.paragraphChunks,
                fullDocumentText: context.fullDocumentText
            )
            return ReadingSentencePresentation(
                id: sentence.id,
                blockID: block.id,
                sentenceIndex: sentence.sentenceIndex,
                text: sentence.text,
                selection: selection
            )
        }
    }

    private static func isSelectable(_ kind: ReadingMarkdownBlockKind) -> Bool {
        switch kind {
        case .codeBlock, .horizontalRule, .unsupported:
            false
        case .heading, .paragraph, .blockquote, .unorderedList, .orderedList:
            true
        }
    }

    private static func inlinePresentation(for run: ReadingInlineRun) -> ReadingInlinePresentation {
        let role: ReadingInlineRole = switch run.kind {
        case .plain:
            .plain
        case .emphasis:
            .emphasis
        case .strong:
            .strong
        case .inlineCode:
            .inlineCode
        case .link:
            .link
        }
        return ReadingInlinePresentation(role: role, text: run.text)
    }

    private static func sourceRangeDescription(_ range: Range<String.Index>?) -> String? {
        guard let range else {
            return nil
        }
        return "\(range.lowerBound)..<\(range.upperBound)"
    }
}

public struct ReadingDocumentRenderIdentity: Sendable, Equatable {
    public let documentID: String
    public let contentRevision: Int
    public let structureVersion: Int

    public init(documentID: String, contentRevision: Int, structureVersion: Int) {
        self.documentID = documentID
        self.contentRevision = contentRevision
        self.structureVersion = structureVersion
    }
}

private struct RenderContext {
    let identity: ReadingDocumentRenderIdentity
    let paragraphChunks: [ReadingTextChunk]
    let fullDocumentText: String
}
