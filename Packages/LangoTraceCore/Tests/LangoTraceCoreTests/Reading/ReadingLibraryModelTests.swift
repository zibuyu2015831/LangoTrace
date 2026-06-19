@testable import LangoTraceCore
import Testing

@Suite("Reading library models")
struct ReadingLibraryModelTests {
    @Test("library summary separates document facts from library state")
    func summarySeparatesDocumentAndLibraryState() {
        let summary = ReadingLibraryDocumentSummary(
            id: "doc-1",
            spaceID: "space-1",
            title: "Article",
            sourceFormat: .markdown,
            importStatus: .ready,
            libraryStatus: .active,
            tagNames: ["travel"],
            collectionTitles: ["Essays"],
            lastOpenedAt: nil
        )

        #expect(summary.id == "doc-1")
        #expect(summary.libraryStatus == .active)
        #expect(summary.sourceFormat == .markdown)
    }

    @Test("deleted document is not active but remains restorable")
    func deletedDocumentRemainsRestorable() {
        #expect(ReadingLibraryStatus.active.isVisibleInActiveLibrary)
        #expect(!ReadingLibraryStatus.softDeleted.isVisibleInActiveLibrary)
        #expect(ReadingLibraryStatus.softDeleted.isRestorable)
    }

    @Test("reading document update input rejects empty body and preserves source format")
    func readingDocumentUpdateInputRejectsEmptyBodyAndPreservesSourceFormat() throws {
        #expect(throws: ReadingDocumentUpdateError.emptyBody) {
            try ReadingDocumentUpdateInput(
                documentID: "doc-1",
                spaceID: "space-1",
                title: "Updated",
                body: "   \n",
                sourceFormat: .markdown
            )
        }

        let input = try ReadingDocumentUpdateInput(
            documentID: "doc-1",
            spaceID: "space-1",
            title: " Updated Title ",
            body: "## Updated body",
            sourceFormat: .markdown
        )

        #expect(input.documentID == "doc-1")
        #expect(input.spaceID == "space-1")
        #expect(input.title == "Updated Title")
        #expect(input.body == "## Updated body")
        #expect(input.sourceFormat == .markdown)
    }
}
