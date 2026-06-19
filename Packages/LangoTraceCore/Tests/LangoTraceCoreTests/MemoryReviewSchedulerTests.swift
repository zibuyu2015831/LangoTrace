import Foundation
import LangoTraceCore
import Testing

/// Pins the E8 fixed-interval review scheduler: ladder advance, reset on
/// "needs another look", graduation to mastered, and manual master/resume.
@Suite("Memory review scheduler")
struct MemoryReviewSchedulerTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        Int((b.timeIntervalSince1970 - a.timeIntervalSince1970) / 86400)
    }

    @Test("a new item remembered enters the first rung, due in 1 day")
    func newRememberedEntersFirstRung() throws {
        let result = MemoryReviewScheduler.schedule(state: .new, rung: 0, outcome: .remembered, now: now)
        #expect(result.state == .scheduled)
        #expect(result.rung == 0)
        #expect(try daysBetween(now, #require(result.dueAt)) == 1)
    }

    @Test("remembering advances the ladder rung and interval")
    func rememberedAdvancesLadder() throws {
        let result = MemoryReviewScheduler.schedule(state: .scheduled, rung: 0, outcome: .remembered, now: now)
        #expect(result.rung == 1)
        #expect(try daysBetween(now, #require(result.dueAt)) == 3)
    }

    @Test("remembering at the top rung graduates to mastered")
    func topRungGraduatesToMastered() {
        let top = MemoryReviewScheduler.rungIntervalDays.count - 1
        let result = MemoryReviewScheduler.schedule(state: .scheduled, rung: top, outcome: .remembered, now: now)
        #expect(result.state == .mastered)
        #expect(result.dueAt == nil)
        #expect(result.masteredAt == now)
    }

    @Test("needs-another-look resets to the first rung, due tomorrow")
    func needsAnotherLookResets() throws {
        let result = MemoryReviewScheduler.schedule(state: .scheduled, rung: 3, outcome: .needsAnotherLook, now: now)
        #expect(result.state == .scheduled)
        #expect(result.rung == 0)
        #expect(try daysBetween(now, #require(result.dueAt)) == 1)
    }

    @Test("manual mastery and resume transition cleanly")
    func manualMasterAndResume() {
        let mastered = MemoryReviewScheduler.markMastered(now: now)
        #expect(mastered.state == .mastered)
        #expect(mastered.masteredAt == now)
        let resumed = MemoryReviewScheduler.resumeReview(now: now)
        #expect(resumed.state == .scheduled)
        #expect(resumed.rung == 0)
        #expect(resumed.masteredAt == nil)
    }
}
