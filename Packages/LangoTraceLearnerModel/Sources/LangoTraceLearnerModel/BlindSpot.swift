import Foundation
import LangoTraceCore

/// Category of a blind spot, mirroring the **mechanical** dictation-diff
/// `PracticeDictationDiff.SegmentKind` one-to-one (LM02 Slice 3). v1 deliberately
/// does NOT invent a linguistic taxonomy — classification beyond the mechanical
/// diff would approach AI judgement (ADR-006 §4 red line). Stable raw values stay
/// aligned with the diff's segment kinds.
public enum BlindSpotKind: String, CaseIterable, Sendable, Equatable {
    /// A reference word the attempt omitted.
    case missing
    /// A reference word the attempt rendered differently.
    case changed
    /// An extra word the attempt added.
    case extra

    public init(segmentKind: PracticeDictationDiff.SegmentKind) {
        switch segmentKind {
        case .missing: self = .missing
        case .changed: self = .changed
        case .extra: self = .extra
        }
    }
}

/// A recurring practice error pattern aggregated compute-on-read from a learner's
/// own dictation attempts (LM02 Slice 3). A **language-level** Ability fact
/// (ADR-006 §3): aggregated by `target_language_code`, shared across same-language
/// spaces. Pure value type; no persistence.
///
/// Honest framing: this is a "repeated practice error pattern (from dictation)",
/// NOT a complete grammar diagnosis and NOT a level verdict (约束 4).
public struct BlindSpot: Sendable, Equatable, Identifiable {
    public let languageCode: String
    public let kind: BlindSpotKind
    /// The representative word for this pattern (the reference word for
    /// missing/changed, the extra word for extra).
    public let representativeText: String
    public let occurrenceCount: Int
    /// Evidence-set distribution (ADR-006 §9): one ref per supporting attempt,
    /// `weight` reserved. Provenance is a distribution, not a single FK.
    public let evidence: [LearnerEvidenceRef]

    public var id: String {
        "\(languageCode)|\(kind.rawValue)|\(representativeText)"
    }

    public init(
        languageCode: String,
        kind: BlindSpotKind,
        representativeText: String,
        occurrenceCount: Int,
        evidence: [LearnerEvidenceRef]
    ) {
        self.languageCode = languageCode
        self.kind = kind
        self.representativeText = representativeText
        self.occurrenceCount = occurrenceCount
        self.evidence = evidence
    }
}
