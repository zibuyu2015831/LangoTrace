import Testing
@testable import LangoTraceCore

@Suite("Reading Markdown rendering contract")
struct ReadingMarkdownRenderingTests {
    @Test("markdown parser emits structured reading blocks")
    func markdownParserEmitsStructuredBlocks() {
        let markdown = """
        # Title

        A paragraph with **strong**, *emphasis*, `code`, and [link](https://example.com).

        > Quote

        1. First
        2. Second

        ```swift
        let value = 1
        ```
        """

        let document = ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown)

        #expect(document.blocks.contains { $0.kind == .heading(level: 1) })
        #expect(document.blocks.contains { $0.kind == .paragraph })
        #expect(document.blocks.contains { $0.kind == .blockquote })
        #expect(document.blocks.contains { $0.kind == .orderedList })
        #expect(document.blocks.contains { $0.kind == .codeBlock(language: "swift") })
        #expect(document.inlineRuns.contains { $0.kind == .strong })
        #expect(document.inlineRuns.contains { $0.kind == .inlineCode })
        #expect(document.inlineRuns.contains { $0.kind == .link })
    }

    @Test("multilingual markdown keeps source ranges and protected code")
    func multilingualMarkdownKeepsSourceRanges() {
        let markdown = """
        # 多语言 Title

        中文与 Latin text、한국어、日本語、café 和 שלום mixed.

        1. 中文列表 item

        `Python3.11` should stay literal.
        """

        let document = ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown)

        #expect(document.plainText.contains("中文与 Latin"))
        #expect(document.plainText.contains("한국어"))
        #expect(document.plainText.contains("שלום"))
        #expect(document.inlineRuns.contains { $0.text == "Python3.11" && $0.kind == .inlineCode })
        #expect(document.blocks.allSatisfy { $0.sourceRange != nil })
    }

    @Test("unsupported markdown falls back without losing readable text")
    func unsupportedMarkdownFallsBack() {
        let markdown = "<custom-block data-x=\"1\">Hidden</custom-block>\n\nVisible text."

        let document = ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown)

        #expect(document.plainText.contains("Visible text."))
        #expect(document.blocks.contains { $0.kind == .unsupported || $0.kind == .paragraph })
    }
}
