public struct ReadingTextChunk: Equatable, Sendable {
    public var id: String
    public var documentID: String
    public var contentRevision: Int
    public var text: String
    public var range: Range<String.Index>
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
}
