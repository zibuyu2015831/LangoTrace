import Foundation
import LangoTraceCore
import LangoTraceLearnerModel
@testable import LangoTraceUI
import Testing

/// Covers the LM02 Slice 3 blind-spot presentation: maps the compute-on-read blind
/// spots into honest, practice-source-limited rows, drives the empty-state when
/// there are none, and never expresses a level downgrade (约束 4).
@Suite("Blind spot presentation")
struct BlindSpotPresentationTests {
    private func snapshot(blindSpots: [BlindSpot]) -> LearnerProfileSnapshot {
        LearnerProfileSnapshot(
            abilityCoverage: AbilityCoverage(languageCode: "en", entries: [], generatedAt: Date(timeIntervalSince1970: 0)),
            memoryFacts: [],
            blindSpots: blindSpots,
            reviewStatistics: .zero,
            trend: LearnerProfileTrend(depositedThisWeek: 0, coverageEntryCount: 0)
        )
    }

    @Test("blind spots map to presentation rows; empty drives the placeholder")
    func blindSpotsMapAndEmptyState() {
        let empty = LearnerProfilePresentation(snapshot: snapshot(blindSpots: []), level: .b1)
        #expect(empty.blindSpots.isEmpty)
        #expect(empty.blindSpotsPlaceholder)

        let filled = LearnerProfilePresentation(
            snapshot: snapshot(blindSpots: [
                BlindSpot(
                    languageCode: "en", kind: .changed, representativeText: "their",
                    occurrenceCount: 3,
                    evidence: [LearnerEvidenceRef(sourceType: .practiceTextAttempt, sourceID: "a1")]
                ),
            ]),
            level: .b1
        )
        #expect(!filled.blindSpotsPlaceholder)
        #expect(filled.blindSpots.map(\.text) == ["their"])
        #expect(filled.blindSpots.map(\.kind) == [.changed])
        #expect(filled.blindSpots[0].occurrenceCount == 3)
    }

    @Test("never shows a level downgrade and labels the practice source honestly")
    func neverShowsLevelDowngradeAndLabelsPracticeSource() {
        let presentation = LearnerProfilePresentation(
            snapshot: snapshot(blindSpots: [
                BlindSpot(
                    languageCode: "en", kind: .missing, representativeText: "the",
                    occurrenceCount: 1, evidence: []
                ),
            ]),
            level: .a2
        )
        // The level surface is the gentle, never-downgrading onboarding level.
        #expect(presentation.levelDisplay.level == .a2)
        #expect(presentation.levelDisplay.isCalibrating)
        // The blind-spot framing names its limited source (dictation practice),
        // never a grammar/level verdict — asserted on the localized footer/title.
        let footer = localizedString("learnerProfile.blindSpots.footer")
        #expect(footer.range(of: "dictation", options: .caseInsensitive) != nil || footer.contains("听写"))
        let title = localizedString("learnerProfile.blindSpots.title")
        #expect(title.range(of: "downgrade", options: .caseInsensitive) == nil)
        #expect(title.range(of: "level", options: .caseInsensitive) == nil)
    }
}
