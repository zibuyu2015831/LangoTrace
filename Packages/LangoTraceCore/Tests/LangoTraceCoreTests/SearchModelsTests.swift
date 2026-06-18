import Foundation
import LangoTraceCore
import Testing

/// Pins the UTF-safe highlight computation + search grouping models (系列 E9).
@Suite("Search models")
struct SearchModelsTests {
    @Test("highlight ranges are character offsets, case-insensitive, multi-match")
    func highlightRanges() {
        let ranges = SearchHighlighting.ranges(of: "café", in: "A café and another Café here")
        #expect(ranges.count == 2)
        #expect(ranges.first?.lowerBound == 2)
        #expect(ranges.first?.length == 4)
    }

    @Test("highlight ranges over CJK use grapheme offsets, not bytes")
    func highlightRangesCJK() {
        let text = "今天去了图书馆"
        let ranges = SearchHighlighting.ranges(of: "图书馆", in: text)
        #expect(ranges.count == 1)
        #expect(ranges.first?.lowerBound == 4)
        #expect(ranges.first?.length == 3)
    }

    @Test("an empty query yields no highlights")
    func emptyQueryNoHighlights() {
        #expect(SearchHighlighting.ranges(of: "  ", in: "anything").isEmpty)
    }

    @Test("SearchResults.isEmpty reflects whether any group has hits")
    func resultsEmptiness() {
        #expect(SearchResults.empty(query: "x").isEmpty)
        let nonEmpty = SearchResults(
            query: "x",
            groups: [SearchResultGroup(kind: .entry, hits: [
                SearchHit(id: "1", kind: .entry, spaceID: "s", objectID: "e1", title: "t", snippet: "s"),
            ])]
        )
        #expect(!nonEmpty.isEmpty)
    }
}
