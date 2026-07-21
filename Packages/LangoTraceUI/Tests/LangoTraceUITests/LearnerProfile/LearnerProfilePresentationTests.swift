import Foundation
import LangoTraceCore
import LangoTraceLearnerModel
@testable import LangoTraceUI
import Testing

/// Covers the LM02 Slice 1 learner-profile presentation mapping: the gentle,
/// never-downgrading level display (约束 5), the empty-state guidance, and the
/// reserved blind-spot placeholder (filled by a later slice, never fabricated).
@Suite("Learner profile presentation")
struct LearnerProfilePresentationTests {
    private func snapshot(
        coverageCount: Int = 0,
        facts: [MemoryFact] = [],
        reviewStatistics: MemoryStatistics = .zero
    ) -> LearnerProfileSnapshot {
        let entries = (0 ..< coverageCount).map { index in
            AbilityCoverageEntry(text: "w\(index)", kind: .wordPhrase, occurrenceCount: 1, evidence: [])
        }
        return LearnerProfileSnapshot(
            abilityCoverage: AbilityCoverage(
                languageCode: "ja",
                entries: entries,
                generatedAt: Date(timeIntervalSince1970: 0)
            ),
            memoryFacts: facts,
            reviewStatistics: reviewStatistics,
            trend: LearnerProfileTrend(
                depositedThisWeek: reviewStatistics.depositedThisWeek,
                coverageEntryCount: entries.count
            )
        )
    }

    @Test("level display is the gentle onboarding level, never a downgrade")
    func neverShowsLevelDowngrade() {
        // Even with an utterly empty snapshot, the level shown is exactly the
        // onboarding level, marked as still-calibrating — there is no field that
        // could express "you dropped from B1 to A2" (约束 5).
        let presentation = LearnerProfilePresentation(snapshot: snapshot(), level: .b1)
        #expect(presentation.levelDisplay.level == .b1)
        #expect(presentation.levelDisplay.isCalibrating)
    }

    @Test("empty snapshot drives the empty-state guidance")
    func emptySnapshotIsEmpty() {
        let presentation = LearnerProfilePresentation(snapshot: snapshot(), level: .a2)
        #expect(presentation.isEmpty)
    }

    @Test("any coverage, fact, or review activity exits the empty state")
    func nonEmptyWhenAnySignalPresent() {
        let withCoverage = LearnerProfilePresentation(snapshot: snapshot(coverageCount: 1), level: .a2)
        #expect(!withCoverage.isEmpty)

        let withFact = LearnerProfilePresentation(
            snapshot: snapshot(facts: [MemoryFact(id: "f1", kind: .goal, text: "g")]),
            level: .a2
        )
        #expect(!withFact.isEmpty)

        let withReview = LearnerProfilePresentation(
            snapshot: snapshot(reviewStatistics: MemoryStatistics(depositedThisWeek: 0, dueCount: 3, masteredCount: 0)),
            level: .a2
        )
        #expect(!withReview.isEmpty)
    }

    @Test("memory facts map to presentation rows preserving order")
    func memoryFactsMapToRows() {
        let presentation = LearnerProfilePresentation(
            snapshot: snapshot(facts: [
                MemoryFact(id: "f1", kind: .lifeFact, text: "住在上海"),
                MemoryFact(id: "f2", kind: .goal, text: "考过 N2"),
            ]),
            level: .b1
        )
        #expect(presentation.memoryFacts.map(\.id) == ["f1", "f2"])
        #expect(presentation.memoryFacts.map(\.kind) == [.lifeFact, .goal])
        #expect(presentation.memoryFacts[0].text == "住在上海")
    }

    @Test("blind-spot section is a reserved placeholder, never fabricated entries")
    func blindSpotsArePlaceholder() {
        let presentation = LearnerProfilePresentation(snapshot: snapshot(coverageCount: 3), level: .b1)
        // v1 never invents blind spots (needs产出 signals not yet available, §6).
        #expect(presentation.blindSpotsPlaceholder)
    }

    @Test("review counts surface from the borrowed statistics")
    func reviewCountsSurface() {
        let presentation = LearnerProfilePresentation(
            snapshot: snapshot(reviewStatistics: MemoryStatistics(depositedThisWeek: 2, dueCount: 5, masteredCount: 7)),
            level: .b1
        )
        #expect(presentation.dueCount == 5)
        #expect(presentation.masteredCount == 7)
        #expect(presentation.depositedThisWeek == 2)
    }
}
