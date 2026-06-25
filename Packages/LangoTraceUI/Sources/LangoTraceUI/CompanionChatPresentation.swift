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
}

/// The single gate every platform's companion entry honors: the entry is shown
/// only when the feature switch is enabled (ADR-008 §2.6). Centralized so all
/// three platforms cannot drift.
public enum CompanionEntryAvailability {
    public static func isVisible(featureEnabled: Bool) -> Bool {
        featureEnabled
    }
}
