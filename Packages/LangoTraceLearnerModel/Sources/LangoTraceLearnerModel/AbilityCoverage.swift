import Foundation

/// Ability-layer "knowledge coverage" for a single target language (ADR-006 §2/§3).
///
/// A purely factual map of which knowledge points the learner has touched through
/// explicit deposit actions — NOT a proficiency verdict. It carries no CEFR / band /
/// level / difficulty signal of any kind (those are LM02 and must come from learner
/// output, not AI candidates — ADR-006 §4). Coverage is a true derivation: it is
/// computed on read from active source rows and is never persisted, backed up, or
/// synced (ADR-006 §8).
public struct AbilityCoverage: Sendable, Equatable {
    /// The target language this coverage describes (e.g. "en"). Keyed by language
    /// code, not by language space, so multiple spaces of the same language merge.
    public let languageCode: String
    /// Distinct knowledge points the learner has deposited, grouped by structural kind.
    public let entries: [AbilityCoverageEntry]
    /// When this snapshot was computed (compute-on-read; not a stored timestamp).
    public let generatedAt: Date

    public init(languageCode: String, entries: [AbilityCoverageEntry], generatedAt: Date) {
        self.languageCode = languageCode
        self.entries = entries
        self.generatedAt = generatedAt
    }
}

/// A single covered knowledge point: a deposited target-language text, its structural
/// kind, how many times the learner deposited it, and provenance evidence.
public struct AbilityCoverageEntry: Sendable, Equatable {
    /// The target-language knowledge point snapshot (deposited text).
    public let text: String
    /// Structural grouping only — carries no difficulty or proficiency meaning.
    public let kind: AbilityCoverageKind
    /// How many deposit actions touched this knowledge point (a behaviour count, not a score).
    public let occurrenceCount: Int
    /// Provenance: which source rows back this entry.
    public let evidence: [LearnerEvidenceRef]

    public init(text: String, kind: AbilityCoverageKind, occurrenceCount: Int, evidence: [LearnerEvidenceRef]) {
        self.text = text
        self.kind = kind
        self.occurrenceCount = occurrenceCount
        self.evidence = evidence
    }
}

/// Structural kind of a covered knowledge point. v1 mirrors the two real
/// `memory_items.kind` values one-to-one. `grammarPoint` / `errorPattern` need
/// practice-grading or lookup signals (and only exist on the AI candidate table that
/// LM01 must not read — ADR-006 §4), so they are deferred to LM02. This is a
/// structural grouping, never a difficulty or level indicator.
public enum AbilityCoverageKind: String, Sendable, CaseIterable, Equatable {
    case wordPhrase
    case sentence
}
