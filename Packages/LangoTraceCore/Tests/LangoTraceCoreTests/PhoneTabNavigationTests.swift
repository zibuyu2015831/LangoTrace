@testable import LangoTraceCore
import Testing

struct PhoneTabNavigationTests {
    @Test
    func tabOrderMatchesPrimaryPhoneNavigation() {
        #expect(PhoneRootTab.allCases.map(\.title) == ["记录", "阅读", "练习", "记忆"])
    }

    @Test
    func swipeNavigationDoesNotWrapAtEdges() {
        #expect(PhoneRootTab.entries.tab(after: .previous) == .entries)
        #expect(PhoneRootTab.memory.tab(after: .next) == .memory)
    }

    @Test
    func swipeNavigationMovesWithinBounds() {
        #expect(PhoneRootTab.entries.tab(after: .next) == .reading)
        #expect(PhoneRootTab.reading.tab(after: .next) == .practice)
        #expect(PhoneRootTab.practice.tab(after: .next) == .memory)
        #expect(PhoneRootTab.practice.tab(after: .previous) == .reading)
    }

    @Test
    func swipeNavigationRequiresClearHorizontalIntent() {
        #expect(PhoneRootTab.entries.tab(horizontalTranslation: -61, verticalTranslation: 12) == .reading)
        #expect(PhoneRootTab.practice.tab(horizontalTranslation: 61, verticalTranslation: 12) == .reading)
        #expect(PhoneRootTab.entries.tab(horizontalTranslation: -59, verticalTranslation: 0) == .entries)
        #expect(PhoneRootTab.entries.tab(horizontalTranslation: -90, verticalTranslation: 100) == .entries)
    }
}
