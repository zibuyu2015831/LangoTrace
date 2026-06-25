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

/// Result of one explicit "extract vocabulary / expressions" action (LM03-S2a).
/// On success it carries the space's current candidate list (empty = the model
/// found nothing this run — a success, not a failure); on failure the conversation
/// is untouched and the error is reported honestly.
public enum CompanionExtractionOutcome: Equatable, Sendable {
    case extracted([CompanionMemoryCandidate])
    case failed(CompanionExtractionError)
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
    /// Explicit chat reflux: extract vocabulary / expressions from the thread's
    /// conversation and persist them as review candidates (LM03-S2a deliverable A).
    /// A user-triggered action — same shape as generate / re-analyse learning
    /// material (re-send already-stored user content), not a system auto-injection.
    public var extract: @Sendable (_ threadID: String) async -> CompanionExtractionOutcome

    public init(
        loadThread: @escaping @Sendable (String, String?) async -> CompanionLoadedThread?,
        send: @escaping @Sendable (String, String) async -> CompanionSendOutcome,
        deleteFrom: @escaping @Sendable (String) async -> Void,
        clear: @escaping @Sendable (String) async -> Void,
        extract: @escaping @Sendable (String) async -> CompanionExtractionOutcome
    ) {
        self.loadThread = loadThread
        self.send = send
        self.deleteFrom = deleteFrom
        self.clear = clear
        self.extract = extract
    }

    public static let disabled = CompanionChatActions(
        loadThread: { _, _ in nil },
        send: { _, _ in .failed(.providerUnavailable) },
        deleteFrom: { _ in },
        clear: { _ in },
        extract: { _ in .failed(.providerUnavailable) }
    )
}

public extension EnvironmentValues {
    @Entry var companionChatActions = CompanionChatActions.disabled
    /// App-level feature flag; gates whether the companion entries appear at all.
    @Entry var companionFeatureEnabled = false
    /// Persists the feature flag (default OFF). Injected by App Shell. Main-actor
    /// (EnvironmentValues is main-actor isolated), so it can update view state.
    @Entry var setCompanionFeatureEnabled: (Bool) -> Void = { _ in }
}
