import Foundation

/// Which half of the Style layer a metric belongs to (ADR-006 §2 / idea-01 §13.4).
/// v1 produces only `surface` (mechanical writing metrics from `NaturalLanguage`).
/// `cognitive` (observation angle / thinking style) is a reserved case slot — it needs
/// AI semantic analysis (= outbound) and is v2 opt-in, NOT produced in v1.
public enum StyleMetricKind: String, CaseIterable, Sendable, Equatable {
    case surface
    case cognitive
}

/// Confidence in a Style signal, encoding the source/target discipline (idea-01
/// §13.4/§13.5): writing in the **source (native)** language is a clean, high-
/// confidence imprint; target-language production is discounted to `.low` or
/// excluded (it reflects developing ability, not stable style).
public enum StyleSignalConfidence: String, Sendable, Equatable {
    case high
    case low
}

/// Mechanical surface writing metrics for one native language. Deliberately
/// language-relative (sentence length / vocabulary richness / formality are not
/// comparable across languages), so they live inside a per-native-language group.
public struct StyleSurfaceMetrics: Sendable, Equatable {
    /// Average words (or CJK glyphs) per sentence.
    public let averageSentenceLength: Double
    /// Type-token ratio (distinct / total tokens) — a vocabulary-range proxy.
    public let vocabularyRichness: Double
    /// Heuristic 0…1 formality tendency (longer-word ratio).
    public let formalityTendency: Double

    public init(averageSentenceLength: Double, vocabularyRichness: Double, formalityTendency: Double) {
        self.averageSentenceLength = averageSentenceLength
        self.vocabularyRichness = vocabularyRichness
        self.formalityTendency = formalityTendency
    }
}

/// Surface writing imprint for one native language, with confidence and the
/// evidence-set distribution (ADR-006 §9: a batch of entries, sampled to a cap).
public struct StyleNativeLanguageImprint: Sendable, Equatable, Identifiable {
    public let nativeLanguageCode: String
    public let metrics: StyleSurfaceMetrics
    public let confidence: StyleSignalConfidence
    /// Number of entries that contributed (may exceed `evidence.count`, which is
    /// sampled to a cap).
    public let sampleCount: Int
    public let evidence: [LearnerEvidenceRef]

    public var id: String {
        nativeLanguageCode
    }

    public init(
        nativeLanguageCode: String,
        metrics: StyleSurfaceMetrics,
        confidence: StyleSignalConfidence,
        sampleCount: Int,
        evidence: [LearnerEvidenceRef]
    ) {
        self.nativeLanguageCode = nativeLanguageCode
        self.metrics = metrics
        self.confidence = confidence
        self.sampleCount = sampleCount
        self.evidence = evidence
    }
}

/// System-level (cross-space) surface writing imprint (LM02-S2), aggregated
/// compute-on-read from the learner's own source-language entries. Pure value
/// type; no persistence (v1 surface metrics are a real derived quantity, fully
/// recomputable from `entries`).
public struct StyleImprint: Sendable, Equatable {
    public let kind: StyleMetricKind
    /// One group per native language (surface metrics are not cross-language
    /// comparable, so they are never arithmetic-averaged across languages).
    public let groups: [StyleNativeLanguageImprint]
    public let generatedAt: Date

    public init(kind: StyleMetricKind, groups: [StyleNativeLanguageImprint], generatedAt: Date) {
        self.kind = kind
        self.groups = groups
        self.generatedAt = generatedAt
    }
}
