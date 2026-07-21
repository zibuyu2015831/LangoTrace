import Foundation

/// Read seam for the LM02 Slice 3 blind-spot surface. Exposed as its own method
/// alongside Ability / Memory (not a "difficulty ∪ facts" union, idea-01 §12.2).
///
/// Pure local read; no network, no AI provider, no proficiency judgement.
public protocol LearnerBlindSpotProvider: Sendable {
    /// Recurring practice error patterns for one target language, aggregated
    /// compute-on-read from the learner's own dictation attempts. Returns an empty
    /// array (not nil/throw) when there are no dictation attempts.
    func blindSpots(languageCode: String) throws -> [BlindSpot]
}
