import Foundation

/// Honest companion failure categories (ADR-008 §7 / idea-03 §6.7): when a turn
/// fails, the UI shows one of these and keeps the user's input — it never fakes a
/// reply. Lives in Core so the AI engine produces it and the UI store consumes it
/// without the UI layer depending on the AI package.
public enum CompanionReplyFailure: Equatable, Sendable {
    case providerUnavailable
    case rejected
    case cancelled
    case empty
    case other
}
