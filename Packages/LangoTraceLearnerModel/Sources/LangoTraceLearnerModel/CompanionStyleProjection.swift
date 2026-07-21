import Foundation
import LangoTraceCore

/// Pure i+1 down-projection (LM03-S4a): quantizes one native-language surface
/// `StyleImprint` group plus the learner's current Ability `LearnerBand` into a
/// controlled `CompanionStyleDescriptor`. The band supplies the **complexity
/// ceiling** so the companion never imposes native-language complexity on a
/// learner whose target-language ability is lower (idea-01 §13.5).
///
/// **Band is READ-ONLY here**: this consumes an already-resolved `LearnerBand`
/// value and never touches the band hysteresis or explanation-mode write path
/// (ADR-006 §10 red line) — it only reads the estimate.
public enum CompanionStyleProjection {
    /// Projects the imprint group matching `nativeLanguageCode` against `band`.
    /// Returns `nil` when there is no qualifying group, or its evidence is below
    /// `minimumSampleCount` — don't inject Style from too little signal (a single
    /// stray entry should not shape the companion's register).
    public static func project(
        imprint: StyleImprint,
        nativeLanguageCode: String,
        band: LearnerBand,
        minimumSampleCount: Int = 3
    ) -> CompanionStyleDescriptor? {
        guard
            let group = imprint.groups.first(where: {
                primarySubtag($0.nativeLanguageCode) == primarySubtag(nativeLanguageCode)
            }),
            group.sampleCount >= minimumSampleCount
        else {
            return nil
        }
        return CompanionStyleDescriptor(
            formality: formality(fromTendency: group.metrics.formalityTendency),
            nativeElaboration: elaboration(from: group.metrics),
            complexityCeiling: band.estimatedLevel
        )
    }

    /// Quantizes the heuristic 0…1 formality tendency into a coarse register. This
    /// is the one signal mirrored directly (matching how formal/casual the learner
    /// is); the complexity signals are ceiling-capped instead.
    static func formality(fromTendency tendency: Double) -> CompanionStyleFormality {
        switch tendency {
        case ..<0.4: .casual
        case 0.4 ..< 0.6: .neutral
        default: .formal
        }
    }

    /// Combines sentence length + vocabulary richness into a coarse elaboration
    /// tendency. Thresholds are heuristic v1 (idea-01 §13.9 left the mapping open);
    /// this tendency is described to the model but capped by the band ceiling, not
    /// mirrored raw.
    static func elaboration(from metrics: StyleSurfaceMetrics) -> CompanionStyleElaboration {
        let lengthScore: Double = metrics.averageSentenceLength >= 18
            ? 1 : (metrics.averageSentenceLength >= 10 ? 0.5 : 0)
        let richnessScore: Double = metrics.vocabularyRichness >= 0.6
            ? 1 : (metrics.vocabularyRichness >= 0.4 ? 0.5 : 0)
        let combined = lengthScore + richnessScore
        if combined < 1 {
            return .concise
        }
        if combined < 2 {
            return .moderate
        }
        return .elaborate
    }

    /// Compares language codes on their primary subtag (`zh-Hans` → `zh`), matching
    /// the source/target discipline the style provider applies when grouping.
    private static func primarySubtag(_ code: String) -> String {
        String(code.split(separator: "-").first ?? Substring(code)).lowercased()
    }
}
