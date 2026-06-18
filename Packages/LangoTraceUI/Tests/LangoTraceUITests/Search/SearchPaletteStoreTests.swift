import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

/// Covers the E9 search palette state machine: debounced cancel-safe search,
/// keyboard selection across groups, zero state, and rebuild-on-open.
private func makeHit(_ id: String, kind: SearchObjectKind = .entry) -> SearchHit {
    SearchHit(id: id, kind: kind, spaceID: "s", objectID: id, title: id, snippet: id)
}

private func makeResults(_ ids: [String]) -> SearchResults {
    SearchResults(query: "q", groups: [SearchResultGroup(kind: .entry, hits: ids.map { makeHit($0) })])
}

@Suite("Search palette store")
@MainActor
struct SearchPaletteStoreTests {
    private func makeStore(
        onSearch: @escaping @Sendable (String, String) async -> SearchResults,
        onRebuild: @escaping @Sendable (String) async -> Void = { _ in }
    ) -> SearchPaletteStore {
        SearchPaletteStore(
            spaceID: "s",
            actions: LocalSearchActions(search: onSearch, rebuildIndex: onRebuild),
            perGroupLimit: 5,
            debounceMilliseconds: 0
        )
    }

    @Test("an empty query clears results without searching")
    func emptyQueryClears() async {
        let store = makeStore(onSearch: { _, _ in makeResults(["e1"]) })
        store.updateQuery("   ")
        await store.drainForTesting()
        #expect(store.results.isEmpty)
        #expect(!store.isSearching)
    }

    @Test("a query produces grouped results and selects the first hit")
    func queryProducesResults() async {
        let store = makeStore(onSearch: { _, _ in makeResults(["e1", "e2"]) })
        store.updateQuery("coffee")
        await store.drainForTesting()
        #expect(store.flatHits.map(\.id) == ["e1", "e2"])
        #expect(store.selectedHitID == "e1")
    }

    @Test("only the latest query's result is applied (stale result dropped)")
    func staleResultDropped() async {
        // First search resolves to old; but query changes before it applies.
        let store = makeStore(onSearch: { query, _ in
            query == "old" ? makeResults(["OLD"]) : makeResults(["NEW"])
        })
        store.updateQuery("old")
        store.updateQuery("new")
        await store.drainForTesting()
        #expect(store.flatHits.map(\.id) == ["NEW"])
    }

    @Test("keyboard selection wraps across the flattened hit list")
    func keyboardSelectionWraps() async {
        let store = makeStore(onSearch: { _, _ in makeResults(["a", "b", "c"]) })
        store.updateQuery("x")
        await store.drainForTesting()
        #expect(store.selectedHitID == "a")
        store.moveSelectionDown()
        #expect(store.selectedHitID == "b")
        store.moveSelectionUp()
        store.moveSelectionUp()
        #expect(store.selectedHitID == "c") // wrapped past the top
    }

    @Test("zero state shows when a non-empty query returns nothing")
    func zeroState() async {
        let store = makeStore(onSearch: { query, _ in .empty(query: query) })
        store.updateQuery("zzz")
        await store.drainForTesting()
        #expect(store.showsZeroState)
    }

    @Test("prepare rebuilds the index on open")
    func prepareRebuilds() async {
        let counter = RebuildCounter()
        let store = makeStore(onSearch: { query, _ in .empty(query: query) }, onRebuild: { _ in await counter.increment() })
        await store.prepare()
        #expect(await counter.value == 1)
        #expect(!store.isIndexing)
    }
}

private actor RebuildCounter {
    private(set) var value = 0
    func increment() {
        value += 1
    }
}
