@testable import LangoTraceCore
import Testing

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

    @Test("CRLF markdown parses headings lists and paragraphs")
    func crlfMarkdownParsesBlockStructure() {
        let markdown = "# Title\r\n\r\nFirst paragraph.\r\n\r\n- Item one\r\n1. Ordered item\r\n\r\nSecond paragraph."

        let document = ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown)

        #expect(document.blocks.contains { $0.kind == .heading(level: 1) && $0.text == "Title" })
        #expect(document.blocks.contains { $0.kind == .paragraph && $0.text == "First paragraph." })
        #expect(document.blocks.contains { $0.kind == .unorderedList && $0.text == "Item one" })
        #expect(document.blocks.contains { $0.kind == .orderedList && $0.text == "Ordered item" })
        #expect(document.blocks.contains { $0.kind == .paragraph && $0.text == "Second paragraph." })
        #expect(!document.plainText.contains("\r"))
    }

    @Test("line starting with a bare dot is a paragraph not an ordered list")
    func bareDotLineIsNotOrderedList() {
        let document = ReadingMarkdownParser.parse(". hello world", sourceFormat: .markdown)

        #expect(document.blocks.count == 1)
        #expect(document.blocks[0].kind == .paragraph)
        #expect(document.blocks[0].text == ". hello world")
    }

    @Test("unsupported markdown falls back without losing readable text")
    func unsupportedMarkdownFallsBack() {
        let markdown = "<custom-block data-x=\"1\">Hidden</custom-block>\n\nVisible text."

        let document = ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown)

        #expect(document.plainText.contains("Visible text."))
        #expect(document.blocks.contains { $0.kind == .unsupported || $0.kind == .paragraph })
    }
}
