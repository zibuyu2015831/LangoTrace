import Foundation
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM02 Slice 2 Style domain model: v1 produces only surface metrics
/// (cognitive is a reserved枚举位 not produced in v1), confidence encodes the
/// source/target language discipline, and the imprint groups by native language
/// (surface metrics are language-relative, ADR-006 §3 / idea-01 §13.4).
@Suite("Style imprint model")
struct StyleImprintModelTests {
    @Test("v1 produces only the surface metric kind; cognitive is reserved")
    func surfaceMetricKindIsV1Only() {
        #expect(StyleMetricKind.surface.rawValue == "surface")
        #expect(StyleMetricKind.cognitive.rawValue == "cognitive")
        let imprint = StyleImprint(kind: .surface, groups: [], generatedAt: Date(timeIntervalSince1970: 0))
        #expect(imprint.kind == .surface)
    }

    @Test("confidence encodes source-high / target-low discipline")
    func confidenceEncodesDiscipline() {
        #expect(StyleSignalConfidence.high.rawValue == "high")
        #expect(StyleSignalConfidence.low.rawValue == "low")
    }

    @Test("imprint groups carry per-native-language metrics, confidence and evidence set")
    func groupsCarryMetricsAndEvidence() {
        let group = StyleNativeLanguageImprint(
            nativeLanguageCode: "zh-Hans",
            metrics: StyleSurfaceMetrics(averageSentenceLength: 12, vocabularyRichness: 0.6, formalityTendency: 0.4),
            confidence: .high,
            sampleCount: 3,
            evidence: [
                LearnerEvidenceRef(sourceType: .entryBody, sourceID: "e1"),
                LearnerEvidenceRef(sourceType: .entryBody, sourceID: "e2"),
            ]
        )
        #expect(group.nativeLanguageCode == "zh-Hans")
        #expect(group.confidence == .high)
        #expect(group.sampleCount == 3)
        // Provenance is an evidence-set distribution (ADR-006 §9), not a single FK.
        #expect(group.evidence.allSatisfy { $0.sourceType == .entryBody })
    }
}
