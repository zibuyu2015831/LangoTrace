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
}
