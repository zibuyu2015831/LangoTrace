import Foundation
import LangoTraceCore
import LangoTraceLearnerModel
@testable import LangoTraceUI
import Testing

/// Covers the LM02-S4b band presentation: even when the internal band estimates a
/// lower level than the onboarding level, the page shows the onboarding level (not
/// a downgrade) and only surfaces a gentle trend / confidence (ADR-006 §10).
@Suite("Band presentation (S4b)")
struct BandPresentationTests {
    private func snapshot(band: LearnerBand?) -> LearnerProfileSnapshot {
        LearnerProfileSnapshot(
            abilityCoverage: AbilityCoverage(languageCode: "en", entries: [], generatedAt: Date(timeIntervalSince1970: 0)),
            memoryFacts: [],
            band: band,
            reviewStatistics: .zero,
            trend: LearnerProfileTrend(depositedThisWeek: 0, coverageEntryCount: 0)
        )
    }

    @Test("a lower internal band never downgrades the displayed level")
    func bandPresentationNeverShowsDowngrade() {
        // Onboarding level B1; the internal band estimates A2 (lower → more support
        // in derive()). The page must still show B1, never "you dropped".
        let band = LearnerBand(languageCode: "en", estimatedLevel: .a2, confidence: .low, trend: .steady)
        let presentation = LearnerProfilePresentation(snapshot: snapshot(band: band), level: .b1)
        // Displayed level is the onboarding level, never the lower band estimate.
        #expect(presentation.levelDisplay.level == .b1)
        #expect(presentation.levelDisplay.isCalibrating)
        // Only gentle trend / confidence is surfaced — and trend never carries a
        // "downgrade" case (the enum only has steady / growing).
        #expect(presentation.bandTrend == .steady)
        #expect(presentation.bandConfidence == .low)
        #expect(BandTrend.allCases.allSatisfy { $0 == .steady || $0 == .growing })
    }

    @Test("no band leaves the trend absent")
    func noBandLeavesTrendAbsent() {
        let presentation = LearnerProfilePresentation(snapshot: snapshot(band: nil), level: .b1)
        #expect(presentation.bandTrend == nil)
        #expect(presentation.bandConfidence == nil)
    }
}
