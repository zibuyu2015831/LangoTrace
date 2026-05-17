@testable import LangoTraceCore
import Testing

struct PhoneTabNavigationTests {
    @Test
    func tabOrderMatchesPrimaryPhoneNavigation() {
        #expect(PhoneRootTab.allCases.map(\.title) == ["今日", "记录", "练习", "记忆", "设置"])
    }

    @Test
    func swipeNavigationDoesNotWrapAtEdges() {
        #expect(PhoneRootTab.today.tab(after: .previous) == .today)
        #expect(PhoneRootTab.settings.tab(after: .next) == .settings)
    }

    @Test
    func swipeNavigationMovesWithinBounds() {
        #expect(PhoneRootTab.entries.tab(after: .previous) == .today)
        #expect(PhoneRootTab.entries.tab(after: .next) == .practice)
    }

    @Test
    func swipeNavigationRequiresClearHorizontalIntent() {
        #expect(PhoneRootTab.entries.tab(horizontalTranslation: -61, verticalTranslation: 12) == .practice)
        #expect(PhoneRootTab.entries.tab(horizontalTranslation: 61, verticalTranslation: 12) == .today)
        #expect(PhoneRootTab.entries.tab(horizontalTranslation: -59, verticalTranslation: 0) == .entries)
        #expect(PhoneRootTab.entries.tab(horizontalTranslation: -90, verticalTranslation: 100) == .entries)
    }
}
