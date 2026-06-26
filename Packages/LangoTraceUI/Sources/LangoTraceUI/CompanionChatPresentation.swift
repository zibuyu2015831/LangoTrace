import LangoTraceCore

/// A single chat bubble for the companion conversation view. Pure value type — no
/// SwiftUI, fully testable.
public struct CompanionMessagePresentation: Equatable, Sendable, Identifiable {
    public let id: String
    public let isUser: Bool
    public let text: String

    public init(id: String, isUser: Bool, text: String) {
        self.id = id
        self.isUser = isUser
        self.text = text
    }

    init(_ message: CompanionMessage) {
        id = message.id
        isUser = message.role == .user
        text = message.content
    }
}

/// A single extracted vocabulary / expression candidate for display (LM03-S2a).
/// Pure value type — no SwiftUI, fully testable. `isSourceMessageDeleted` is true
/// once the source companion message was deleted (its weak link was nulled): the
/// candidate survives and the view shows a "source message deleted" note
/// (round-1 P2-2).
public struct CompanionCandidatePresentation: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: LearningMemoryCandidate.Kind
    public let text: String
    public let explanationNative: String
    public let exampleTarget: String
    public let exampleNative: String
    public let isSourceMessageDeleted: Bool

    public init(
        id: String,
        kind: LearningMemoryCandidate.Kind,
        text: String,
        explanationNative: String,
        exampleTarget: String,
        exampleNative: String,
        isSourceMessageDeleted: Bool
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.explanationNative = explanationNative
        self.exampleTarget = exampleTarget
        self.exampleNative = exampleNative
        self.isSourceMessageDeleted = isSourceMessageDeleted
    }

    init(_ candidate: CompanionMemoryCandidate) {
        id = candidate.id
        kind = candidate.kind
        text = candidate.text
        explanationNative = candidate.explanationNative
        exampleTarget = candidate.exampleTarget
        exampleNative = candidate.exampleNative
        isSourceMessageDeleted = candidate.messageID == nil
    }
}

/// Localized-string keys + entry gating for the Language Companion UI. Centralized
/// so the three-platform views and the tests reference one source of truth.
public enum CompanionChatCopy {
    public static let entryTitleKey = "companion.entry.title"
    public static let settingsToggleKey = "companion.settings.toggle"
    public static let settingsToggleDescriptionKey = "companion.settings.toggle.description"
    public static let coldStartGreetingKey = "companion.greeting.coldStart"
    public static let entryDetailActionKey = "companion.entry.talkAboutRecord"
    public static let retryKey = "companion.failure.retry"
    public static let inputPlaceholderKey = "companion.input.placeholder"
    public static let clearKey = "companion.action.clear"

    /// LM03-S3a gentle-recast correction posture toggle.
    public static let gentleRecastToggleKey = "companion.recast.toggle"

    // LM03-S2b-1 memory-injection two-layer privacy copy.
    public static let memoryToggleKey = "companion.memory.toggle"
    public static let memoryPreviewTitleKey = "companion.memory.preview.title"
    public static let memoryPreviewSendsKey = "companion.memory.preview.sends"
    public static let memoryPreviewNotSendsKey = "companion.memory.preview.notSends"
    public static let memoryUseKey = "companion.memory.preview.use"
    public static let memoryDeclineKey = "companion.memory.preview.decline"

    // LM03-S2b-2 record topic-sourcing one-time preview copy.
    public static let topicPreviewTitleKey = "companion.topic.preview.title"
    public static let topicDeclineKey = "companion.topic.preview.decline"

    // LM03-S3b-2 session-summary deposit copy.
    public static let depositAllKey = "companion.deposit.all"
    public static let depositedBadgeKey = "companion.deposit.added"

    // LM03-S2a chat-reflux extraction copy.
    public static let extractActionKey = "companion.extraction.action"
    public static let extractLoadingKey = "companion.extraction.loading"
    public static let extractSuccessCountKey = "companion.extraction.successCount"
    public static let extractEmptyKey = "companion.extraction.empty"
    public static let extractFailureKey = "companion.extraction.failure"
    public static let extractSourceDeletedKey = "companion.extraction.sourceDeleted"

    /// Honest failure copy (ADR-008 §7): "the companion can't be reached" — never a
    /// faked reply. All non-rejection failures collapse to the unavailable copy.
    public static func failureKey(_ failure: CompanionReplyFailure) -> String {
        switch failure {
        case .rejected:
            "companion.failure.rejected"
        case .cancelled:
            "companion.failure.cancelled"
        case .providerUnavailable, .empty, .other:
            "companion.failure.unavailable"
        }
    }

    /// Honest extraction-failure copy: every category collapses to one "extraction
    /// failed, your conversation is kept" message — the conversation is never lost
    /// and no candidates are faked (plan §D2 honest-failure rule).
    public static func extractionFailureKey(_ error: CompanionExtractionError) -> String {
        switch error {
        case .invalidStructuredOutput, .providerUnavailable, .rejected, .cancelled, .other:
            extractFailureKey
        }
    }
}

/// The single gate every platform's companion entry honors: the entry is shown
/// only when the feature switch is enabled (ADR-008 §2.6). Centralized so all
/// three platforms cannot drift.
public enum CompanionEntryAvailability {
    public static func isVisible(featureEnabled: Bool) -> Bool {
        featureEnabled
    }
}
