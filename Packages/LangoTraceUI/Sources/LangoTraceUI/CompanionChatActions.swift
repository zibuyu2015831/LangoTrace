import LangoTraceCore
import SwiftUI

/// A loaded companion thread: its id plus the persisted messages, oldest-first.
public struct CompanionLoadedThread: Equatable, Sendable {
    public var threadID: String
    public var messages: [CompanionMessage]

    public init(threadID: String, messages: [CompanionMessage]) {
        self.threadID = threadID
        self.messages = messages
    }
}

/// Result of one send: either the user + assistant turns were both persisted, or
/// the request failed and nothing was persisted (so the user's input is never lost
/// and no reply is faked — ADR-008 §7).
public enum CompanionSendOutcome: Equatable, Sendable {
    case appended(user: CompanionMessage, assistant: CompanionMessage)
    case failed(CompanionReplyFailure)
}

/// Companion conversation seam, injected from App Shell and backed by
/// `GRDBCompanionRepository` + `CompanionConversationEngine`. The `send` closure
/// runs the engine against the persisted history and persists the user + assistant
/// turns **only on success** — local-first, no system-auto-injection in S1.
public struct CompanionChatActions: Sendable {
    public var loadThread: @Sendable (_ spaceID: String, _ sourceEntryID: String?) async -> CompanionLoadedThread?
    public var send: @Sendable (_ threadID: String, _ userInput: String) async -> CompanionSendOutcome
    public var deleteFrom: @Sendable (_ messageID: String) async -> Void
    public var clear: @Sendable (_ threadID: String) async -> Void

    public init(
        loadThread: @escaping @Sendable (String, String?) async -> CompanionLoadedThread?,
        send: @escaping @Sendable (String, String) async -> CompanionSendOutcome,
        deleteFrom: @escaping @Sendable (String) async -> Void,
        clear: @escaping @Sendable (String) async -> Void
    ) {
        self.loadThread = loadThread
        self.send = send
        self.deleteFrom = deleteFrom
        self.clear = clear
    }

    public static let disabled = CompanionChatActions(
        loadThread: { _, _ in nil },
        send: { _, _ in .failed(.providerUnavailable) },
        deleteFrom: { _ in },
        clear: { _ in }
    )
}

public extension EnvironmentValues {
    @Entry var companionChatActions = CompanionChatActions.disabled
    /// App-level feature flag; gates whether the companion entries appear at all.
    @Entry var companionFeatureEnabled = false
    /// Persists the feature flag (default OFF). Injected by App Shell.
    @Entry var setCompanionFeatureEnabled: @Sendable (Bool) -> Void = { _ in }
}
