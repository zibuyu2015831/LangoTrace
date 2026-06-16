import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("PhoneTabNavigationModel")
struct PhoneTabNavigationModelTests {
    @Test("push on entries tab does not affect practice tab path")
    func pushOnRecordTabDoesNotAffectPracticeTabPath() {
        let model = PhoneTabNavigationModel()
        model.push(.entryDetail("abc"), on: .entries)
        #expect(model.path(for: .practice).isEmpty)
        #expect(model.path(for: .reading).isEmpty)
        #expect(model.path(for: .memory).isEmpty)
    }

    @Test("each tab holds an independent navigation stack")
    func eachTabHoldsIndependentStack() {
        let model = PhoneTabNavigationModel()
        model.push(.entryDetail("e1"), on: .entries)
        model.push(.readingDocument("d1"), on: .reading)
        model.push(.practiceSentenceList("p1"), on: .practice)

        #expect(model.path(for: .entries) == [.entryDetail("e1")])
        #expect(model.path(for: .reading) == [.readingDocument("d1")])
        #expect(model.path(for: .practice) == [.practiceSentenceList("p1")])
        #expect(model.path(for: .memory).isEmpty)
    }

    @Test("settings push on one tab does not pollute other tabs")
    func settingsPushIsolatedToTab() {
        let model = PhoneTabNavigationModel()
        model.push(.settingsList, on: .entries)
        #expect(model.path(for: .reading).isEmpty)
        #expect(model.path(for: .practice).isEmpty)
        #expect(model.path(for: .memory).isEmpty)
    }

    @Test("replaceCurrentRoute replaces last item on active tab")
    func replaceCurrentRouteReplacesLastItemOnActiveTab() {
        let model = PhoneTabNavigationModel()
        model.selectedTab = .entries
        model.push(.settingsList, on: .entries)
        model.push(.settings(.aiProvider), on: .entries)
        model.replaceCurrentRoute(with: .settings(.sync), on: .entries)

        let path = model.path(for: .entries)
        #expect(path.count == 2)
        if case let .settings(kind) = path.last {
            #expect(kind == .sync)
        } else {
            Issue.record("expected settings(.ttsProvider) as last route")
        }
    }

    @Test("replaceCurrentRoute on empty stack appends instead")
    func replaceCurrentRouteOnEmptyStackAppends() {
        let model = PhoneTabNavigationModel()
        model.selectedTab = .entries
        model.replaceCurrentRoute(with: .settingsList, on: .entries)
        #expect(model.path(for: .entries) == [.settingsList])
    }

    @Test("initial state has no navigation and entries selected")
    func initialStateHasNoNavigationAndEntriesSelected() {
        let model = PhoneTabNavigationModel()
        #expect(model.selectedTab == .entries)
        for tab in PhoneRootTab.allCases {
            #expect(model.path(for: tab).isEmpty)
        }
    }
}
