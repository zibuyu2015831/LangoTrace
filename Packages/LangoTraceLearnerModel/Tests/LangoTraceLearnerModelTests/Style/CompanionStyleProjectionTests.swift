import Foundation
import LangoTraceCore
@testable import LangoTraceLearnerModel
import Testing

/// LM03-S4a: the pure i+1 down-projection from a surface `StyleImprint` group +
/// the read-only Ability band into a `CompanionStyleDescriptor`.
@Suite("Companion style projection (LM03-S4a)")
struct CompanionStyleProjectionTests {
    private func imprint(
        nativeLanguageCode: String = "zh-Hans",
        averageSentenceLength: Double = 20,
        vocabularyRichness: Double = 0.7,
        formalityTendency: Double = 0.8,
        sampleCount: Int = 10
    ) -> StyleImprint {
        StyleImprint(
            kind: .surface,
            groups: [
                StyleNativeLanguageImprint(
                    nativeLanguageCode: nativeLanguageCode,
                    metrics: StyleSurfaceMetrics(
                        averageSentenceLength: averageSentenceLength,
                        vocabularyRichness: vocabularyRichness,
                        formalityTendency: formalityTendency
                    ),
                    confidence: .high,
                    sampleCount: sampleCount,
                    evidence: []
                ),
            ],
            generatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func band(_ level: LanguageLevel) -> LearnerBand {
        LearnerBand(languageCode: "en", estimatedLevel: level, confidence: .low, trend: .steady)
    }

    @Test("Ceiling is the band estimate — complexity is down-projected to current ability")
    func ceilingFollowsBand() {
        // Native writing is elaborate/formal, but a beginner band caps the ceiling.
        let descriptor = CompanionStyleProjection.project(
            imprint: imprint(), nativeLanguageCode: "zh-Hans", band: band(.a2)
        )
        #expect(descriptor?.complexityCeiling == .a2)
        #expect(descriptor?.formality == .formal)
        #expect(descriptor?.nativeElaboration == .elaborate)
    }

    @Test("Formality quantizes across the casual/neutral/formal thresholds")
    func formalityQuantization() {
        #expect(CompanionStyleProjection.formality(fromTendency: 0.2) == .casual)
        #expect(CompanionStyleProjection.formality(fromTendency: 0.5) == .neutral)
        #expect(CompanionStyleProjection.formality(fromTendency: 0.9) == .formal)
    }

    @Test("Elaboration combines sentence length + vocabulary richness")
    func elaborationQuantization() {
        let concise = CompanionStyleProjection.elaboration(from: StyleSurfaceMetrics(
            averageSentenceLength: 6, vocabularyRichness: 0.2, formalityTendency: 0.5
        ))
        #expect(concise == .concise)
        let elaborate = CompanionStyleProjection.elaboration(from: StyleSurfaceMetrics(
            averageSentenceLength: 22, vocabularyRichness: 0.7, formalityTendency: 0.5
        ))
        #expect(elaborate == .elaborate)
    }

    @Test("No qualifying native-language group → nil (no injection)")
    func nilWhenNoMatchingGroup() {
        let descriptor = CompanionStyleProjection.project(
            imprint: imprint(nativeLanguageCode: "ja"), nativeLanguageCode: "zh-Hans", band: band(.b1)
        )
        #expect(descriptor == nil)
    }

    @Test("Evidence below the minimum sample count → nil (don't inject from too little signal)")
    func nilWhenSampleCountTooLow() {
        let descriptor = CompanionStyleProjection.project(
            imprint: imprint(sampleCount: 2), nativeLanguageCode: "zh-Hans", band: band(.b1), minimumSampleCount: 3
        )
        #expect(descriptor == nil)
    }

    @Test("Matches the native language on its primary subtag (zh-Hans ↔ zh)")
    func matchesOnPrimarySubtag() {
        let descriptor = CompanionStyleProjection.project(
            imprint: imprint(nativeLanguageCode: "zh"), nativeLanguageCode: "zh-Hans", band: band(.b1)
        )
        #expect(descriptor != nil)
    }
}
