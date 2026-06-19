import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Reading library progress & favorites UI presentation", .serialized)
struct ReadingLibraryProgressPresentationTests {
    // MARK: - Filter state

    @Test("selectedLibraryFilter defaults to .all")
    func filterDefaultsToAll() {
        let store = makeStore(documents: [])
        #expect(store.selectedLibraryFilter == .all)
    }

    @Test("updateLibraryFilter switches to favoritesOnly")
    func updateLibraryFilterToFavorites() {
        let store = makeStore(documents: [])
        store.updateLibraryFilter(.favoritesOnly)
        #expect(store.selectedLibraryFilter == .favoritesOnly)
    }

    @Test("updateLibraryFilter switches back to all")
    func updateLibraryFilterRoundTrip() {
        let store = makeStore(documents: [])
        store.updateLibraryFilter(.favoritesOnly)
        store.updateLibraryFilter(.all)
        #expect(store.selectedLibraryFilter == .all)
    }

    // MARK: - filteredDocuments respects favorites filter

    @Test("filteredDocuments returns all when filter is .all")
    func filteredDocumentsAllFilter() async {
        let docs = [
            makeDoc(id: "a", isFavorite: true),
            makeDoc(id: "b", isFavorite: false),
        ]
        let store = makeStore(documents: docs)
        await store.reload()
        store.updateLibraryFilter(.all)
        #expect(store.filteredDocuments.count == 2)
    }

    @Test("filteredDocuments returns only favorites when filter is .favoritesOnly")
    func filteredDocumentsOnlyFavorites() async {
        let docs = [
            makeDoc(id: "a", isFavorite: true),
            makeDoc(id: "b", isFavorite: false),
            makeDoc(id: "c", isFavorite: true),
        ]
        let store = makeStore(documents: docs)
        await store.reload()
        store.updateLibraryFilter(.favoritesOnly)
        let ids = store.filteredDocuments.map(\.id)
        #expect(Set(ids) == ["a", "c"])
    }

    @Test("filteredDocuments returns empty when favoritesOnly but none favorited")
    func filteredDocumentsEmptyFavorites() async {
        let docs = [makeDoc(id: "a", isFavorite: false)]
        let store = makeStore(documents: docs)
        await store.reload()
        store.updateLibraryFilter(.favoritesOnly)
        #expect(store.filteredDocuments.isEmpty)
    }

    // MARK: - replaceLanguageSpace resets filter

    @Test("replaceLanguageSpace resets selectedLibraryFilter to .all")
    func replaceLanguageSpaceResetsFilter() {
        let store = makeStore(documents: [])
        store.updateLibraryFilter(.favoritesOnly)
        let newSpace = LanguageSpacePreview(
            id: "space-2", name: "French",
            nativeLanguage: "English", targetLanguage: "French",
            targetLanguageCode: "fr", level: .a2
        )
        store.replaceLanguageSpace(newSpace)
        #expect(store.selectedLibraryFilter == .all)
    }

    // MARK: - withFavorite helper on summary

    @Test("withFavorite returns copy with updated isFavorite, original unchanged")
    func withFavoriteReturnsCopy() {
        let original = makeDoc(id: "d", isFavorite: false)
        let toggled = original.withFavorite(true)
        #expect(toggled.isFavorite == true)
        #expect(original.isFavorite == false)
        #expect(toggled.id == original.id)
    }

    // MARK: - ReadingProgressState on summary

    @Test("readingProgressState .unstarted is stored correctly")
    func progressUnstarted() {
        let doc = makeDoc(id: "e", progressState: .unstarted)
        #expect(doc.readingProgressState == .unstarted)
    }

    @Test("readingProgressState .reading stores percent correctly")
    func progressReading() {
        let doc = makeDoc(id: "f", progressState: .reading(percent: 42))
        if case let .reading(pct) = doc.readingProgressState {
            #expect(pct == 42)
        } else {
            Issue.record("Expected .reading state")
        }
    }

    @Test("readingProgressState .completed stores date correctly")
    func progressCompleted() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let doc = makeDoc(id: "g", progressState: .completed(at: completedAt))
        if case let .completed(at: date) = doc.readingProgressState {
            #expect(date == completedAt)
        } else {
            Issue.record("Expected .completed state")
        }
    }

    // MARK: - bodyWordCount

    @Test("bodyWordCount is stored and retrievable via summary")
    func bodyWordCount() {
        let doc = makeDoc(id: "h", wordCount: 123)
        #expect(doc.bodyWordCount == 123)
    }

    // MARK: - Helpers

    private func makeStore(documents: [ReadingLibraryDocumentSummary]) -> ReadingLibraryStore {
        let spaceID = "space-1"
        let actions = ReadingLibraryActions(
            listDocuments: { _, includeDeleted, _ in
                includeDeleted ? [] : documents
            },
            importPastedText: { _ in throw ReadingLibraryActionError.unavailable },
            loadDocument: { _, _ in nil },
            updateDocument: { _ in throw ReadingLibraryActionError.unavailable },
            softDeleteDocument: { _, _ in },
            restoreDocument: { _, _ in },
            markDocumentOpened: { _, _ in }
        )
        return ReadingLibraryStore(
            languageSpace: LanguageSpacePreview(
                id: spaceID, name: "English",
                nativeLanguage: "中文", targetLanguage: "English",
                targetLanguageCode: "en", level: .a2
            ),
            actions: actions
        )
    }

    private func makeDoc(
        id: String,
        isFavorite: Bool = false,
        progressState: ReadingProgressState = .unstarted,
        wordCount: Int = 0
    ) -> ReadingLibraryDocumentSummary {
        ReadingLibraryDocumentSummary(
            id: id,
            spaceID: "space-1",
            title: "Doc \(id)",
            sourceFormat: .plainText,
            importStatus: .ready,
            libraryStatus: .active,
            tagNames: [],
            collectionTitles: [],
            lastOpenedAt: nil,
            isFavorite: isFavorite,
            readingProgressState: progressState,
            bodyWordCount: wordCount
        )
    }
}
