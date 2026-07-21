import Foundation

/// Read seam for the LM02 Slice 2 Style surface imprint. Exposed as its own
/// method alongside Ability / Memory / blind spots (not a union, idea-01 §12.2).
///
/// Pure local read; no network, no AI provider, no proficiency judgement. v1
/// produces only surface metrics from the learner's own source-language entries.
public protocol LearnerStyleProvider: Sendable {
    /// System-level surface writing imprint, aggregated compute-on-read from the
    /// learner's source-language `entries`. Returns an empty imprint (not nil/throw)
    /// when there are no qualifying entries.
    func styleImprint() throws -> StyleImprint
}
