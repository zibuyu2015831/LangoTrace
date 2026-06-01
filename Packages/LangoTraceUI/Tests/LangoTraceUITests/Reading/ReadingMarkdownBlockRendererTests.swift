import LangoTraceCore
import Testing
@testable import LangoTraceUI

@Suite("Reading Markdown block renderer")
struct ReadingMarkdownBlockRendererTests {
    @Test("renderer maps markdown blocks without flattening to one chunk")
    func rendererMapsBlocksWithoutFlattening() {
        let document = ReadingMarkdownParser.parse(
            """
            # Title

            Body with **strong**, *emphasis*, `code`, and [link](https://example.com).

            > Quote

            1. First

            ```swift
            let value = 1
            ```
            """,
            sourceFormat: .markdown
        )

        let rendered = ReadingMarkdownBlockRenderer.render(
            document: document,
            appearance: .default,
            platform: .phone
        )

        #expect(rendered.blocks.count > 1)
        #expect(rendered.blocks.contains { $0.kind == .heading(level: 1) })
        #expect(rendered.blocks.contains { $0.kind == .paragraph })
        #expect(rendered.blocks.contains { $0.kind == .blockquote })
        #expect(rendered.blocks.contains { $0.kind == .orderedList })
        #expect(rendered.blocks.contains { $0.kind == .codeBlock(language: "swift") })
        #expect(rendered.inlineRuns.contains { $0.role == .strong })
        #expect(rendered.inlineRuns.contains { $0.role == .inlineCode })
        #expect(rendered.inlineRuns.contains { $0.role == .link })
    }

    @Test("dynamic type changes style without changing source identity")
    func dynamicTypeChangesStyleWithoutChangingSourceIdentity() {
        let document = ReadingMarkdownParser.parse("# Title\n\nこんにちは café שלום", sourceFormat: .markdown)
        var compact = ReadingAppearanceProfile.default
        compact.lineSpacing = 4
        var accessible = ReadingAppearanceProfile.default
        accessible.lineSpacing = 8

        let first = ReadingMarkdownBlockRenderer.render(document: document, appearance: compact, platform: .phone)
        let second = ReadingMarkdownBlockRenderer.render(document: document, appearance: accessible, platform: .phone)

        #expect(first.blocks.map(\.id) == second.blocks.map(\.id))
        #expect(first.blocks.map(\.sourceRangeDescription) == second.blocks.map(\.sourceRangeDescription))
        #expect(first.style.lineSpacing == 4)
        #expect(second.style.lineSpacing == 8)
        #expect(second.style.colorRoles.contains(.darkModeBackground))
    }
}
