import Testing
@testable import LangoTraceCore

@Suite("Reading search query")
struct ReadingSearchQueryTests {
    @Test("empty search query normalizes to nil")
    func emptyQueryNormalizesToNil() {
        #expect(ReadingLibrarySearchQuery(rawValue: "   ") == nil)
    }

    @Test("search query trims and limits length")
    func queryTrimsAndLimitsLength() {
        let raw = String(repeating: "a", count: 300)
        let query = ReadingLibrarySearchQuery(rawValue: "  \(raw)  ")

        #expect(query?.normalized.count == ReadingLibrarySearchQuery.maxLength)
    }
}
