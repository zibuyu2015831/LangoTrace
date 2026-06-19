import Foundation

/// Input for the optional back-translation AI critique (系列 E5 Slice 2).
///
/// Exactly the five fields E5-D2 authorizes sending: the native-meaning prompt,
/// the user's own attempt, the reference sentence, and the language/proficiency
/// codes. Nothing else (no other sentences, no history, no attachments).
public struct PracticeBacktranslationReviewInput: Equatable, Sendable {
    public var nativeSentence: String
    public var userAttempt: String
    public var referenceSentence: String
    public var targetLanguageCode: String
    public var proficiencyLevelCode: String
    public var explanationLanguageMode: ExplanationLanguageMode

    public init(
        nativeSentence: String,
        userAttempt: String,
        referenceSentence: String,
        targetLanguageCode: String,
        proficiencyLevelCode: String,
        explanationLanguageMode: ExplanationLanguageMode = .bilingualBridge
    ) {
        self.nativeSentence = nativeSentence
        self.userAttempt = userAttempt
        self.referenceSentence = referenceSentence
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
        self.explanationLanguageMode = explanationLanguageMode
    }
}

/// One observation in a critique: a phenomenon and its explanation. Deliberately
/// NOT a judgement — no correctness/score field exists (约束 5: 回译不判对错).
public struct PracticeBacktranslationReviewObservation: Equatable, Sendable {
    public var phenomenon: String
    public var explanation: String

    public init(phenomenon: String, explanation: String) {
        self.phenomenon = phenomenon
        self.explanation = explanation
    }
}

/// Structured back-translation critique result. Observation + suggestion shaped,
/// never a verdict. Short-lived UI state — not persisted.
public struct PracticeBacktranslationReviewResult: Equatable, Sendable {
    public var schemaVersion: String
    public var acknowledgement: String
    public var observations: [PracticeBacktranslationReviewObservation]
    public var suggestions: [String]
    public var registerNote: String?
    public var explanationLanguageMode: ExplanationLanguageMode

    public init(
        schemaVersion: String,
        acknowledgement: String,
        observations: [PracticeBacktranslationReviewObservation],
        suggestions: [String],
        registerNote: String? = nil,
        explanationLanguageMode: ExplanationLanguageMode = .bilingualBridge
    ) {
        self.schemaVersion = schemaVersion
        self.acknowledgement = acknowledgement
        self.observations = observations
        self.suggestions = suggestions
        self.registerNote = registerNote
        self.explanationLanguageMode = explanationLanguageMode
    }
}

/// Failure vocabulary for the back-translation critique service. Mirrors
/// `ReadingSelectionExplanationFailureCategory` (spec 005 §4.6) so the AI text
/// services share one failure shape.
public enum PracticeBacktranslationReviewFailureCategory: Equatable, Sendable {
    case providerNotConfigured
    case unsupportedProvider
    case authenticationFailed
    case rateLimited
    case unsupportedModel
    case providerRejected
    case networkUnavailable
    case timeout
    case cancelled
    case invalidStructuredResponse
}

/// UI-facing failure for the critique action, carrying the category so the
/// session can show a precise, non-network-masking failure state. App Shell maps
/// the AI service error onto this so the UI layer stays decoupled from the AI
/// package.
public struct PracticeBacktranslationReviewFailure: Error, Equatable, Sendable {
    public var category: PracticeBacktranslationReviewFailureCategory

    public init(category: PracticeBacktranslationReviewFailureCategory) {
        self.category = category
    }
}
