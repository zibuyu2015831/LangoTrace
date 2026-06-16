import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("EntryTimeline projection functions")
struct EntryTimelineProjectionTests {
    // MARK: - Fixtures

    private static let fixedToday = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15
    private static let fixedYesterday = Date(timeIntervalSince1970: 1_800_000_000 - 86400)
    private static let fixedTwoDaysAgo = Date(timeIntervalSince1970: 1_800_000_000 - 172800)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func entry(id: String, createdAt: Date, source: EntrySource = .typedText) -> LearningEntry {
        LearningEntry(
            id: id,
            spaceID: "test",
            title: "T",
            body: "b",
            source: source,
            scene: "s",
            createdAt: createdAt
        )
    }

    // MARK: - groupEntriesByDay

    @Test("groups entries by calendar day with newest day first")
    func groupsEntriesByDayWithTodayFirst() {
        let e1 = entry(id: "e1", createdAt: Self.fixedToday)
        let e2 = entry(id: "e2", createdAt: Self.fixedYesterday)
        let entries = [e1, e2]  // already newest-first from repository
        let groups = groupEntriesByDay(entries, calendar: calendar)

        #expect(groups.count == 2)
        #expect(groups[0].entries.map(\.id) == ["e1"])
        #expect(groups[1].entries.map(\.id) == ["e2"])
    }

    @Test("entries from the same day are grouped together")
    func groupsEntriesFromSameDayTogether() {
        let t0 = Self.fixedToday
        let t1 = t0 - 3600   // 1 hour earlier, same day
        let e1 = entry(id: "e1", createdAt: t0)
        let e2 = entry(id: "e2", createdAt: t1)
        let groups = groupEntriesByDay([e1, e2], calendar: calendar)

        #expect(groups.count == 1)
        #expect(groups[0].entries.count == 2)
    }

    @Test("empty input produces no groups")
    func emptyInputProducesNoGroups() {
        let groups = groupEntriesByDay([], calendar: calendar)
        #expect(groups.isEmpty)
    }

    @Test("single entry produces one group")
    func singleEntryProducesOneGroup() {
        let e = entry(id: "e1", createdAt: Self.fixedToday)
        let groups = groupEntriesByDay([e], calendar: calendar)
        #expect(groups.count == 1)
        #expect(groups[0].entries.count == 1)
    }

    // MARK: - timelineCounts

    @Test("total count equals entry count")
    func totalCountEqualsEntryCount() {
        let entries = [
            entry(id: "e1", createdAt: Self.fixedToday),
            entry(id: "e2", createdAt: Self.fixedYesterday),
        ]
        let counts = timelineCounts(
            entries: entries,
            practiceReadiness: [:],
            today: Self.fixedToday,
            calendar: calendar
        )
        #expect(counts.total == 2)
    }

    @Test("today count only includes entries from today")
    func todayCountOnlyIncludesToday() {
        let entries = [
            entry(id: "today1", createdAt: Self.fixedToday),
            entry(id: "today2", createdAt: Self.fixedToday - 3600),
            entry(id: "yesterday", createdAt: Self.fixedYesterday),
        ]
        let counts = timelineCounts(
            entries: entries,
            practiceReadiness: [:],
            today: Self.fixedToday,
            calendar: calendar
        )
        #expect(counts.today == 2)
    }

    @Test("photo count only includes photoWriting entries")
    func photoCountOnlyIncludesPhotoWriting() {
        let entries = [
            entry(id: "e1", createdAt: Self.fixedToday, source: .photoWriting),
            entry(id: "e2", createdAt: Self.fixedToday, source: .typedText),
        ]
        let counts = timelineCounts(
            entries: entries,
            practiceReadiness: [:],
            today: Self.fixedToday,
            calendar: calendar
        )
        #expect(counts.photo == 1)
    }

    @Test("needsPractice count from practiceReadiness false values")
    func needsPracticeCountFromReadinessDict() {
        let e1 = entry(id: "e1", createdAt: Self.fixedToday)
        let e2 = entry(id: "e2", createdAt: Self.fixedToday)
        let e3 = entry(id: "e3", createdAt: Self.fixedToday)
        // e1: no key (no material) → not counted
        // e2: false (material, no recording) → counted
        // e3: true (material + completed recording) → not counted
        let practiceReadiness: [String: Bool] = ["e2": false, "e3": true]
        let counts = timelineCounts(
            entries: [e1, e2, e3],
            practiceReadiness: practiceReadiness,
            today: Self.fixedToday,
            calendar: calendar
        )
        #expect(counts.needsPractice == 1)
    }

    @Test("settled count is always 0 until E7")
    func settledCountIsAlwaysZero() {
        let entries = [entry(id: "e1", createdAt: Self.fixedToday)]
        let counts = timelineCounts(
            entries: entries,
            practiceReadiness: ["e1": true],
            today: Self.fixedToday,
            calendar: calendar
        )
        #expect(counts.settled == 0)
    }
}
