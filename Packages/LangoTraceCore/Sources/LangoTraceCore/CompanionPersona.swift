import Foundation

/// Conversational tone the user may pick for the Language Companion. Closed
/// enum — the user never types free text into the persona (AI-17 injection
/// hardening, ADR-008 §4 / idea-03 §3.3).
public enum CompanionTone: String, CaseIterable, Codable, Equatable, Sendable {
    case friendly
    case neutral
    case humorous
}

/// Formality register for the companion's replies. Closed enum.
public enum CompanionFormality: String, CaseIterable, Codable, Equatable, Sendable {
    case casual
    case formal
}

/// Correction posture. `ifNeeded` = only confirm / correct when comprehension
/// breaks; `warmRecast` = naturally restate the correct form without lecturing;
/// `none` = never correct. Difficulty is NOT a persona option — it is driven by
/// the Ability layer (idea-03 §3.9), so there is no "practice intensity" knob.
public enum CompanionCorrection: String, CaseIterable, Codable, Equatable, Sendable {
    case ifNeeded
    case warmRecast
    case none
}

/// User-tunable persona for the Language Companion: three closed enums mapped to
/// controlled system-prompt fragments. The mapping never echoes user free text
/// into the prompt — only fixed, vetted fragments — so a malformed or hostile
/// input cannot corrupt the persona or escalate the companion into a general
/// assistant (ADR-008 §2 six boundaries / §4).
public struct CompanionPersona: Codable, Equatable, Sendable {
    public var tone: CompanionTone
    public var formality: CompanionFormality
    public var correction: CompanionCorrection

    /// Recommended default (idea-03 §10.6): friendly / casual / only-when-needed.
    public static let `default` = CompanionPersona(
        tone: .friendly,
        formality: .casual,
        correction: .ifNeeded
    )

    public init(
        tone: CompanionTone,
        formality: CompanionFormality,
        correction: CompanionCorrection
    ) {
        self.tone = tone
        self.formality = formality
        self.correction = correction
    }

    /// Maps the three enums to fixed English instruction fragments embedded into
    /// the companion system prompt. Pure function of the enums — no user string
    /// is ever returned, so the persona is injection-safe by construction.
    public func controlledFragments() -> [String] {
        [toneFragment, formalityFragment, correctionFragment]
    }

    private var toneFragment: String {
        switch tone {
        case .friendly:
            "Keep a warm, friendly tone that puts a nervous learner at ease."
        case .neutral:
            "Keep a calm, neutral tone."
        case .humorous:
            "Allow light, kind humor, but never at the learner's expense."
        }
    }

    private var formalityFragment: String {
        switch formality {
        case .casual:
            "Speak casually, the way a friend would in everyday conversation."
        case .formal:
            "Speak in a polite, formal register."
        }
    }

    private var correctionFragment: String {
        switch correction {
        case .ifNeeded:
            "Do not correct grammar inline. Only when an error genuinely "
                + "blocks understanding, confirm or restate like a real person would."
        case .warmRecast:
            "Do not lecture. When the learner makes a mistake, naturally "
                + "restate the correct form in your own reply without calling it out."
        case .none:
            "Never correct the learner; just keep the conversation going."
        }
    }
}
