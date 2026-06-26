import Foundation

/// The register the learner tends toward in their **native-language** writing —
/// the one surface-Style signal safe to *mirror* in target-language replies
/// (matching how formal or casual they are), as distinct from complexity, which
/// must be down-projected through the Ability band (LM03-S4a / idea-01 §13.5).
public enum CompanionStyleFormality: String, Codable, CaseIterable, Equatable, Sendable {
    case casual
    case neutral
    case formal
}

/// How elaborate the learner's native-language writing tends to be (sentence
/// length + vocabulary range, combined). Carried as a **tendency description
/// only** — it is NOT mirrored directly; the companion's actual reply complexity
/// is capped by the band ceiling (i+1 down-projection), so a learner whose native
/// writing is `elaborate` is never given native-language complexity beyond their
/// current target-language ability.
public enum CompanionStyleElaboration: String, Codable, CaseIterable, Equatable, Sendable {
    case concise
    case moderate
    case elaborate
}

/// The controlled Style fragment the companion injects (LM03-S4a): the learner's
/// native-language register + elaboration tendency, plus the **band-derived
/// complexity ceiling** that down-projects it to their current target-language
/// ability (idea-01 §13.5).
///
/// Carries **no raw user content** — only these quantized categories and a CEFR
/// ceiling — so, unlike injected Memory facts, it needs no PII scrubbing. It is
/// produced by `CompanionStyleProjection` (LangoTraceLearnerModel) from the
/// surface `StyleImprint` + the read-only Ability band, and rendered into the
/// `<<<STYLE>>>` reference block by `CompanionPromptRegistry`.
public struct CompanionStyleDescriptor: Equatable, Sendable {
    public let formality: CompanionStyleFormality
    public let nativeElaboration: CompanionStyleElaboration
    /// The i+1 cap: the learner's current Ability band level. The companion may
    /// mirror register but never exceeds this complexity, however elaborate the
    /// native-language writing is.
    public let complexityCeiling: LanguageLevel

    public init(
        formality: CompanionStyleFormality,
        nativeElaboration: CompanionStyleElaboration,
        complexityCeiling: LanguageLevel
    ) {
        self.formality = formality
        self.nativeElaboration = nativeElaboration
        self.complexityCeiling = complexityCeiling
    }
}
