import Foundation
import LangoTraceCore

/// Read seam for the LM02-S4b internal proficiency band. Exposed as its own method
/// alongside Ability / Memory / blind spots / Style (not a union, idea-01 §12.2).
///
/// Pure local read; no network, no AI. The band evolves from **independent**
/// behaviour signals and never overwrites the user-visible `LanguageLevel`.
public protocol LearnerBandProvider: Sendable {
    /// The internal band estimate for one target language, seeded by the user's
    /// onboarding level. Returns the seed when signals are too sparse to move it.
    func band(languageCode: String, seedLevel: LanguageLevel) throws -> LearnerBand
}
