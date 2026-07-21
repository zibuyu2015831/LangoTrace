import Foundation
import LangoTraceCore
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM02 Slice 3 blind-spot domain model: `BlindSpotKind` directly
/// mirrors the existing mechanical `PracticeDictationDiff.SegmentKind`
/// ({missing, changed, extra}) — no invented or linguistic taxonomy (which would
/// drift toward AI judgement, ADR-006 §4).
@Suite("Blind spot model")
struct BlindSpotModelTests {
    @Test("kind maps one-to-one to the diff SegmentKind")
    func kindMapsToSegmentKind() {
        #expect(BlindSpotKind(segmentKind: .missing) == .missing)
        #expect(BlindSpotKind(segmentKind: .changed) == .changed)
        #expect(BlindSpotKind(segmentKind: .extra) == .extra)
        // Raw values stay aligned with the diff's stable wire identifiers.
        #expect(BlindSpotKind.missing.rawValue == PracticeDictationDiff.SegmentKind.missing.rawValue)
        #expect(BlindSpotKind.changed.rawValue == PracticeDictationDiff.SegmentKind.changed.rawValue)
        #expect(BlindSpotKind.extra.rawValue == PracticeDictationDiff.SegmentKind.extra.rawValue)
        #expect(BlindSpotKind.allCases.count == 3)
    }

    @Test("blind spot carries language, kind, representative text, count and evidence set")
    func blindSpotCarriesEvidenceSet() {
        let spot = BlindSpot(
            languageCode: "en",
            kind: .changed,
            representativeText: "their",
            occurrenceCount: 2,
            evidence: [
                LearnerEvidenceRef(sourceType: .practiceTextAttempt, sourceID: "a1"),
                LearnerEvidenceRef(sourceType: .practiceTextAttempt, sourceID: "a2"),
            ]
        )
        #expect(spot.occurrenceCount == 2)
        // Provenance is an evidence set distribution (ADR-006 §9), not a single FK.
        #expect(spot.evidence.count == 2)
        #expect(spot.evidence.allSatisfy { $0.sourceType == .practiceTextAttempt })
    }
}
