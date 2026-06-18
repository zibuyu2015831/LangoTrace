import Foundation
import LangoTraceCore
import SwiftUI

/// Local search seam injected from App Shell (系列 E9). Pure local — backed by
/// `GRDBLocalSearchRepository`. `rebuildIndex` repopulates the FTS index from
/// main data; the palette calls it on open so results are fresh without
/// per-write index maintenance in v1.
public struct LocalSearchActions: Sendable {
    public var search: @Sendable (_ query: String, _ spaceID: String) async -> SearchResults
    public var rebuildIndex: @Sendable (_ spaceID: String) async -> Void

    public init(
        search: @escaping @Sendable (String, String) async -> SearchResults,
        rebuildIndex: @escaping @Sendable (String) async -> Void
    ) {
        self.search = search
        self.rebuildIndex = rebuildIndex
    }

    public static let disabled = LocalSearchActions(
        search: { query, _ in .empty(query: query) },
        rebuildIndex: { _ in }
    )
}

public extension EnvironmentValues {
    @Entry var localSearchActions = LocalSearchActions.disabled
}

/// Drives the search palette / overlay: debounced query, cancel-safe in-flight
/// search, keyboard selection across groups, and zero/indexing states. Memory
/// results degrade to empty until E7 lands (the repository simply returns no
/// memory group).
@MainActor
final class SearchPaletteStore: ObservableObject {
    @Published private(set) var query = ""
    @Published private(set) var results: SearchResults = .empty(query: "")
    @Published private(set) var isSearching = false
    @Published private(set) var isIndexing = false
    @Published private(set) var selectedHitID: String?

    private let spaceID: String
    private let actions: LocalSearchActions
    private let perGroupLimit: Int
    private let debounceMilliseconds: Int
    private var searchTask: Task<Void, Never>?

    init(
        spaceID: String,
        actions: LocalSearchActions,
        perGroupLimit: Int = 5,
        debounceMilliseconds: Int = 150
    ) {
        self.spaceID = spaceID
        self.actions = actions
        self.perGroupLimit = perGroupLimit
        self.debounceMilliseconds = debounceMilliseconds
    }

    /// All hits flattened in group order — the keyboard selection order.
    var flatHits: [SearchHit] {
        results.groups.flatMap(\.hits)
    }

    var selectedHit: SearchHit? {
        guard let selectedHitID else { return nil }
        return flatHits.first { $0.id == selectedHitID }
    }

    var showsZeroState: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSearching
            && results.isEmpty
    }

    /// Rebuilds the index on open so the palette reflects current content.
    func prepare() async {
        isIndexing = true
        await actions.rebuildIndex(spaceID)
        isIndexing = false
    }

    /// Updates the query and schedules a debounced, cancel-safe search.
    func updateQuery(_ newValue: String) {
        query = newValue
        searchTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = .empty(query: newValue)
            isSearching = false
            selectedHitID = nil
            return
        }
        isSearching = true
        searchTask = Task { [weak self, debounceMilliseconds] in
            if debounceMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(debounceMilliseconds) * 1_000_000)
            }
            if Task.isCancelled { return }
            guard let self else { return }
            let fetched = await actions.search(newValue, spaceID)
            if Task.isCancelled { return }
            // Only the latest query's result is applied (stale results dropped).
            guard newValue == query else { return }
            results = fetched
            isSearching = false
            selectedHitID = fetched.groups.first?.hits.first?.id
        }
    }

    func moveSelectionDown() {
        moveSelection(by: 1)
    }

    func moveSelectionUp() {
        moveSelection(by: -1)
    }

    func close() {
        searchTask?.cancel()
        query = ""
        results = .empty(query: "")
        isSearching = false
        selectedHitID = nil
    }

    /// Test seam: await the in-flight debounced search.
    func drainForTesting() async {
        await searchTask?.value
    }

    private func moveSelection(by delta: Int) {
        let hits = flatHits
        guard !hits.isEmpty else {
            selectedHitID = nil
            return
        }
        guard let currentID = selectedHitID,
              let index = hits.firstIndex(where: { $0.id == currentID })
        else {
            selectedHitID = hits.first?.id
            return
        }
        let next = (index + delta + hits.count) % hits.count
        selectedHitID = hits[next].id
    }
}
