import Foundation
@testable import LangoTraceUI
import Testing

/// Guards the fix for the bug where switching the interface language left some
/// home fields (filter chips, empty-state card) stuck in the previous language.
///
/// Root cause: those leaf views received only value-stable inputs and did not
/// depend on any value that changes with the language, so SwiftUI's structural
/// diff skipped re-evaluating their `body`. The fix makes the affected leaves
/// read `@Environment(\.locale)` (which the App injects from the resolved
/// interface-language code) and resolve copy from that locale, via `LocalizedText`.
///
/// Real re-rendering is verified manually on the simulator; these checks are the
/// structural + resolution guardrails, matching the source-assertion style used
/// across the UI test target.
@Suite("Interface language reactivity")
struct InterfaceLanguageReactivityTests {
    @Test("LocalizedText leaf reads the locale environment")
    func localizedTextLeafReadsLocaleEnvironment() throws {
        let source = try chromeSource(named: "LocalizedChrome.swift")
        #expect(source.contains("struct LocalizedText"))
        #expect(source.contains("@Environment(\\.locale)"))
    }

    @Test("Affected value-stable leaves use LocalizedText")
    func affectedLeavesUseLocalizedText() throws {
        let utility = try chromeSource(named: "ContentUtilityComponents.swift")
        #expect(utility.contains("LocalizedText"), "LocalizedCompactPanel must render via LocalizedText")

        let sections = try chromeSource(named: "PhoneMainSections.swift")
        #expect(sections.contains("LocalizedText"), "FilterChipButton must render via LocalizedText")
    }

    @Test("localizedString resolves per supplied locale")
    func localizedStringResolvesPerLocale() {
        #expect(localizedString("timeline.empty.title", locale: Locale(identifier: "en")) == "No entries yet")
        #expect(localizedString("timeline.empty.title", locale: Locale(identifier: "zh-Hans")) == "暂无记录")
        #expect(localizedString("pad.filter.all", locale: Locale(identifier: "zh-Hans")) == "全部")
    }

    private func chromeSource(named fileName: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
