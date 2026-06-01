import Foundation

public struct ReadingMarkdownDocument: Equatable, Sendable {
    public var sourceFormat: ReadingSourceFormat
    public var blocks: [ReadingMarkdownBlock]
    public var plainText: String

    public var inlineRuns: [ReadingInlineRun] {
        blocks.flatMap(\.inlineRuns)
    }
}

public struct ReadingMarkdownBlock: Equatable, Sendable {
    public var id: String
    public var kind: ReadingMarkdownBlockKind
    public var text: String
    public var inlineRuns: [ReadingInlineRun]
    public var sourceRange: Range<String.Index>?
}

public enum ReadingMarkdownBlockKind: Equatable, Hashable, Sendable {
    case heading(level: Int)
    case paragraph
    case blockquote
    case unorderedList
    case orderedList
    case codeBlock(language: String?)
    case horizontalRule
    case unsupported
}

public struct ReadingInlineRun: Equatable, Sendable {
    public var kind: ReadingInlineRunKind
    public var text: String
    public var sourceRange: Range<String.Index>?
}

public enum ReadingInlineRunKind: Equatable, Hashable, Sendable {
    case plain
    case emphasis
    case strong
    case inlineCode
    case link
}

public enum ReadingMarkdownParser {
    public static func parse(_ markdown: String, sourceFormat: ReadingSourceFormat) -> ReadingMarkdownDocument {
        var blocks: [ReadingMarkdownBlock] = []
        var currentIndex = markdown.startIndex
        var blockCounter = 0
        var codeFenceLanguage: String?
        var codeFenceStart: String.Index?
        var codeLines: [String] = []
        var plainTextParts: [String] = []

        func appendBlock(
            kind: ReadingMarkdownBlockKind,
            text: String,
            sourceRange: Range<String.Index>?,
            inlineRuns: [ReadingInlineRun]? = nil
        ) {
            blockCounter += 1
            let blockRuns = inlineRuns ?? parseInlineRuns(text, baseRange: sourceRange, in: markdown)
            blocks.append(ReadingMarkdownBlock(
                id: "block-\(blockCounter)",
                kind: kind,
                text: text,
                inlineRuns: blockRuns,
                sourceRange: sourceRange
            ))
            if !text.isEmpty {
                plainTextParts.append(text)
            }
        }

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStart = currentIndex
            let lineEnd = markdown.index(lineStart, offsetBy: rawLine.count)
            let nextIndex = lineEnd < markdown.endIndex ? markdown.index(after: lineEnd) : lineEnd
            defer { currentIndex = nextIndex }

            let line = String(rawLine)
            let range = lineStart ..< lineEnd

            if let start = codeFenceStart {
                if line.hasPrefix("```") {
                    let codeText = codeLines.joined(separator: "\n")
                    appendBlock(
                        kind: .codeBlock(language: codeFenceLanguage),
                        text: codeText,
                        sourceRange: start ..< lineEnd,
                        inlineRuns: [ReadingInlineRun(kind: .plain, text: codeText, sourceRange: start ..< lineEnd)]
                    )
                    codeFenceStart = nil
                    codeFenceLanguage = nil
                    codeLines = []
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if line.hasPrefix("```") {
                codeFenceStart = lineStart
                let language = line.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)
                codeFenceLanguage = language.isEmpty ? nil : language
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                continue
            }

            if trimmed == "---" || trimmed == "***" {
                appendBlock(kind: .horizontalRule, text: "", sourceRange: range, inlineRuns: [])
            } else if trimmed.hasPrefix("#") {
                let level = min(trimmed.prefix { $0 == "#" }.count, 6)
                let text = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
                appendBlock(kind: .heading(level: level), text: text, sourceRange: range)
            } else if trimmed.hasPrefix(">") {
                let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                appendBlock(kind: .blockquote, text: text, sourceRange: range)
            } else if isOrderedListLine(trimmed) {
                appendBlock(kind: .orderedList, text: stripOrderedMarker(trimmed), sourceRange: range)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                appendBlock(kind: .unorderedList, text: String(trimmed.dropFirst(2)), sourceRange: range)
            } else if trimmed.hasPrefix("<"), trimmed.contains(">") {
                appendBlock(kind: .unsupported, text: stripSimpleHTML(trimmed), sourceRange: range)
            } else {
                appendBlock(kind: .paragraph, text: line, sourceRange: range)
            }
        }

        if let start = codeFenceStart {
            let codeText = codeLines.joined(separator: "\n")
            appendBlock(kind: .codeBlock(language: codeFenceLanguage), text: codeText, sourceRange: start ..< markdown.endIndex)
        }

        return ReadingMarkdownDocument(
            sourceFormat: sourceFormat,
            blocks: blocks,
            plainText: plainTextParts.joined(separator: "\n")
        )
    }

    private static func isOrderedListLine(_ line: String) -> Bool {
        guard let dot = line.firstIndex(of: ".") else {
            return false
        }
        return line[..<dot].allSatisfy(\.isNumber)
            && line.index(after: dot) < line.endIndex
            && line[line.index(after: dot)] == " "
    }

    private static func stripOrderedMarker(_ line: String) -> String {
        guard let dot = line.firstIndex(of: ".") else {
            return line
        }
        return String(line[line.index(dot, offsetBy: 2)...])
    }

    private static func stripSimpleHTML(_ line: String) -> String {
        var result = ""
        var insideTag = false
        for char in line {
            if char == "<" {
                insideTag = true
                continue
            }
            if char == ">" {
                insideTag = false
                continue
            }
            if !insideTag {
                result.append(char)
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseInlineRuns(
        _ text: String,
        baseRange: Range<String.Index>?,
        in source: String
    ) -> [ReadingInlineRun] {
        var runs = [ReadingInlineRun(kind: .plain, text: text, sourceRange: baseRange)]

        func appendDelimited(_ delimiter: String, kind: ReadingInlineRunKind) {
            var searchStart = text.startIndex
            while let open = text.range(of: delimiter, range: searchStart ..< text.endIndex),
                  let close = text.range(of: delimiter, range: open.upperBound ..< text.endIndex)
            {
                let value = String(text[open.upperBound ..< close.lowerBound])
                if !value.isEmpty {
                    runs.append(ReadingInlineRun(kind: kind, text: value, sourceRange: nil))
                }
                searchStart = close.upperBound
            }
        }

        appendDelimited("**", kind: .strong)
        appendDelimited("*", kind: .emphasis)
        appendDelimited("`", kind: .inlineCode)

        var searchStart = text.startIndex
        while let labelStart = text.range(of: "[", range: searchStart ..< text.endIndex),
              let labelEnd = text.range(of: "](", range: labelStart.upperBound ..< text.endIndex),
              let urlEnd = text.range(of: ")", range: labelEnd.upperBound ..< text.endIndex)
        {
            let label = String(text[labelStart.upperBound ..< labelEnd.lowerBound])
            if !label.isEmpty {
                runs.append(ReadingInlineRun(kind: .link, text: label, sourceRange: nil))
            }
            searchStart = urlEnd.upperBound
        }

        _ = source
        return runs
    }
}
