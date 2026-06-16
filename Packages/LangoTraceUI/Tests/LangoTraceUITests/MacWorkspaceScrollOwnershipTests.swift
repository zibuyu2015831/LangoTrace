import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Mac workspace scroll ownership")
struct MacWorkspaceScrollOwnershipTests {
    @Test("entryDetail route uses dedicated main scrolling to prevent nesting")
    func entryDetailUsesDedicatedScrolling() {
        #expect(MacWorkspaceRoute.entryDetail("x").usesDedicatedMainScrolling)
    }

    @Test("reading route uses dedicated main scrolling to prevent nesting")
    func readingUsesDedicatedScrolling() {
        #expect(MacWorkspaceRoute.reading.usesDedicatedMainScrolling)
    }

    @Test("overview route uses outer scrolling")
    func overviewUsesOuterScrolling() {
        #expect(!MacWorkspaceRoute.overview.usesDedicatedMainScrolling)
    }

    @Test("practiceSentenceList route uses dedicated main scrolling")
    func practiceListUsesDedicatedScrolling() {
        #expect(MacWorkspaceRoute.practiceSentenceList("e1").usesDedicatedMainScrolling)
    }

    @Test("settings route uses outer scrolling")
    func settingsUsesOuterScrolling() {
        #expect(!MacWorkspaceRoute.settings(.aiProvider).usesDedicatedMainScrolling)
    }
}
