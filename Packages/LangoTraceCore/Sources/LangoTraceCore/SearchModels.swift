import Foundation

/// The kind of object a local search hit points to (系列 E9). Closed set; the
/// FTS index stores this as a non-indexed metadata column and search results are
/// grouped by it.
public enum SearchObjectKind: String, Codable, CaseIterable, Equatable, Sendable {
    case entry
    case readingDocument
    case memoryItem
}

/// A UTF-safe highlight span inside a hit's title or snippet, expressed as a
/// character (extended grapheme) range so UI rendering never mis-slices
/// multi-byte text.
public struct SearchHighlightRange: Equatable, Sendable {
    public var lowerBound: Int
    public var length: Int

    public init(lowerBound: Int, length: Int) {
        self.lowerBound = max(0, lowerBound)
        self.length = max(0, length)
    }
}

/// A single local search hit. Carries only what the UI needs to render and
/// navigate — never any provider/network data (search is fully local).
public struct SearchHit: Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: SearchObjectKind
    public var spaceID: String
    /// Navigation target: entry id, reading document id, or memory item id.
    public var objectID: String
    public var title: String
    public var snippet: String
    public var titleHighlights: [SearchHighlightRange]
    public var snippetHighlights: [SearchHighlightRange]
    /// Optional reading per-block anchor (block index) for in-document scroll.
    public var readingBlockIndex: Int?

    public init(
        id: String,
        kind: SearchObjectKind,
        spaceID: String,
        objectID: String,
        title: String,
        snippet: String,
        titleHighlights: [SearchHighlightRange] = [],
        snippetHighlights: [SearchHighlightRange] = [],
        readingBlockIndex: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.spaceID = spaceID
        self.objectID = objectID
        self.title = title
        self.snippet = snippet
        self.titleHighlights = titleHighlights
        self.snippetHighlights = snippetHighlights
        self.readingBlockIndex = readingBlockIndex
    }
}

/// Hits for one object kind, in rank order (already truncated to the per-group
/// limit by the repository).
public struct SearchResultGroup: Equatable, Sendable {
    public var kind: SearchObjectKind
    public var hits: [SearchHit]

    public init(kind: SearchObjectKind, hits: [SearchHit]) {
        self.kind = kind
        self.hits = hits
    }
}

/// Grouped local search results for one query, scoped to one language space.
public struct SearchResults: Equatable, Sendable {
    public var query: String
    public var groups: [SearchResultGroup]

    public init(query: String, groups: [SearchResultGroup]) {
        self.query = query
        self.groups = groups
    }

    public var isEmpty: Bool {
        groups.allSatisfy(\.hits.isEmpty)
    }

    public static func empty(query: String) -> SearchResults {
        SearchResults(query: query, groups: [])
    }
}

/// Local full-text search boundary (系列 E9). Pure local — implementations
/// depend only on the local store, never on any Provider/network. The FTS index
/// is rebuildable derived data (核心决策 12 / spec 007): never synced, never a
/// required export, always reconstructable from main data via `rebuildSearchIndex`.
public protocol LocalSearchRepository: Sendable {
    /// Grouped, rank-ordered, space-scoped results. `perGroupLimit` truncates
    /// each group. An empty/whitespace query returns empty results.
    func search(query: String, spaceID: String, perGroupLimit: Int) async throws -> SearchResults
    /// Fully rebuilds the index for one space from main data (backfill / repair).
    func rebuildSearchIndex(spaceID: String) async throws
}

/// Highlight computation shared by repository + UI: case-insensitive substring
/// match positions of `query` inside `text`, as UTF-safe character ranges.
public enum SearchHighlighting {
    public static func ranges(of query: String, in text: String) -> [SearchHighlightRange] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !text.isEmpty else {
            return []
        }
        var ranges: [SearchHighlightRange] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let found = text.range(of: trimmed, options: .caseInsensitive, range: searchStart ..< text.endIndex)
        {
            let lower = text.distance(from: text.startIndex, to: found.lowerBound)
            let length = text.distance(from: found.lowerBound, to: found.upperBound)
            ranges.append(SearchHighlightRange(lowerBound: lower, length: length))
            searchStart = found.upperBound
        }
        return ranges
    }
}
