import Foundation

/// Where a piece of learner evidence came from. An extensible enum: future behaviour
/// signals (e.g. practice results) can be added without breaking the provider contract.
/// v1 only sources from explicit memory deposits.
public enum LearnerSourceType: String, Sendable, Equatable {
    case memoryItem
    /// A Memory-layer fact the user explicitly saved (LM02). No source row in
    /// any table — provenance is the user's own action.
    case manualMemory
}

/// Provenance reference for a covered knowledge point (ADR-006 §9). Single-row FK
/// granularity in v1; `weight` is reserved (optional, unused in v1) so Ability / Style
/// can later move to an "evidence set + weight" granularity without a schema break.
public struct LearnerEvidenceRef: Sendable, Equatable {
    public let sourceType: LearnerSourceType
    public let sourceID: String
    public let weight: Double?

    public init(sourceType: LearnerSourceType, sourceID: String, weight: Double? = nil) {
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.weight = weight
    }
}

/// The single stable seam through which consumers (LM02 overview UI, future companion)
/// obtain learner context. LM01 fills only the Ability "knowledge coverage" surface;
/// Memory / Style layers attach here later without changing existing consumers.
///
/// Pure local read; no network, no AI provider, no proficiency judgement.
public protocol LearnerContextProvider: Sendable {
    /// Factual knowledge coverage for one target language, aggregated compute-on-read
    /// from active deposited sources. Returns an empty coverage (not nil/throw) when the
    /// language has no active deposits.
    func abilityCoverage(languageCode: String) throws -> AbilityCoverage

    /// System-level Memory facts (LM02), oldest-first. `visibility == nil` returns
    /// every active fact (the governance / overview view); a non-nil value filters
    /// to that visibility (future companion consumption). Two real consumers — the
    /// overview page and the future companion — lift idea-01 §12.2's YAGNI concern,
    /// so this is exposed as its own read method (not a "difficulty ∪ facts" union).
    func memoryFacts(visibility: MemoryFactVisibility?) throws -> [MemoryFact]
}
