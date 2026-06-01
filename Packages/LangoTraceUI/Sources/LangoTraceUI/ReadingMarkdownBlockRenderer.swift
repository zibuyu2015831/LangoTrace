import LangoTraceCore

public enum ReadingMarkdownBlockRenderer {
    public static func render(
        document: ReadingMarkdownDocument,
        appearance: ReadingAppearanceProfile,
        platform _: ReadingPlatformRole
    ) -> ReadingDocumentPresentation {
        ReadingDocumentPresentation(
            blocks: document.blocks.map { block in
                ReadingBlockPresentation(
                    id: block.id,
                    kind: block.kind,
                    text: block.text,
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

    private static func inlinePresentation(for run: ReadingInlineRun) -> ReadingInlinePresentation {
        let role: ReadingInlineRole = switch run.kind {
        case .plain:
            .emphasis
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
