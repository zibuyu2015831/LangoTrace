import LangoTraceCore
import SwiftUI

/// A loaded companion thread: its id plus the persisted messages, oldest-first.
public struct CompanionLoadedThread: Equatable, Sendable {
    public var threadID: String
    public var messages: [CompanionMessage]
    /// Per-conversation learner-profile injection toggle (LM03-S2b-1 second
    /// privacy layer). Defaults true (follow global consent).
    public var usesLearnerProfile: Bool
    /// The space persona's correction posture (LM03-S3a). Carried out on load so
    /// the gentle-recast toggle reflects the persisted state instead of stale UI.
    /// A struct default keeps every existing `CompanionLoadedThread(...)`
    /// construction source-compatible.
    public var correction: CompanionCorrection

    public init(
        threadID: String,
        messages: [CompanionMessage],
        usesLearnerProfile: Bool = true,
        correction: CompanionCorrection = .ifNeeded
    ) {
        self.threadID = threadID
        self.messages = messages
        self.usesLearnerProfile = usesLearnerProfile
        self.correction = correction
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
    /// Runs one turn. `onPartial` streams the cumulative in-flight reply (LM03-S3a)
    /// for a UI-only bubble — it never persists; only the success outcome's full
    /// text is stored. The closure carries the *third* arity, so existing literal
    /// `{ _, _ in }` fixtures must become `{ _, _, _ in }` (a default value cannot
    /// rescue a closure literal's arity).
    public var send: @Sendable (
        _ threadID: String, _ userInput: String, _ onPartial: @escaping @Sendable (String) -> Void
    ) async -> CompanionSendOutcome
    public var deleteFrom: @Sendable (_ messageID: String) async -> Void
    public var clear: @Sendable (_ threadID: String) async -> Void
    /// Explicit chat reflux: extract vocabulary / expressions from the thread's
    /// conversation and persist them as review candidates (LM03-S2a deliverable A).
    /// A user-triggered action — same shape as generate / re-analyse learning
    /// material (re-send already-stored user content), not a system auto-injection.
    public var extract: @Sendable (_ threadID: String) async -> CompanionExtractionOutcome
    /// Sets the per-conversation learner-profile injection toggle (LM03-S2b-1).
    public var setUsesLearnerProfile: @Sendable (_ threadID: String, _ usesLearnerProfile: Bool) async -> Void
    /// Toggles the space persona's gentle-recast correction posture (LM03-S3a):
    /// on → `.warmRecast`, off → `.ifNeeded`. Keyed by spaceID because the persona
    /// is per-space (`conversation_companions`), not per-conversation. The App
    /// implements this read-modify-write to preserve tone / formality.
    public var setGentleRecast: @Sendable (_ spaceID: String, _ enabled: Bool) async -> Void
    /// The "will-send" projection for a companion send *with* Memory injection —
    /// backs the one-time consent preview (discloses the curated subset that is
    /// sent and the full memory store that is not). nil when no provider is
    /// configured (the preview falls back to local-only copy).
    public var memoryPreviewProjection: @Sendable (_ threadID: String) async -> AIRequestPreviewProjection?
    /// The "will-send" projection for a companion send that auto-sources a topic
    /// from records (LM03-S2b-2) — backs the one-time topic-sourcing preview
    /// (discloses that a record body is sent). nil when no provider is configured.
    public var recordTopicPreviewProjection: @Sendable (_ threadID: String) async -> AIRequestPreviewProjection?
    /// Batch-deposits all of the space's companion chat candidates into the memory
    /// review system (LM03-S3b-2 session summary — closes the chat → memory loop). A
    /// purely local action (no provider call); idempotent (already-deposited
    /// candidates are skipped). Returns the count of candidates now deposited.
    public var depositAllCandidates: @Sendable (_ spaceID: String) async -> Int
    /// Source-candidate ids already deposited in the space — drives the per-candidate
    /// "added" state. Includes all deposit sources; the store intersects it with the
    /// companion candidate ids it displays (LM03-S3b-2).
    public var depositedCandidateIDs: @Sendable (_ spaceID: String) async -> Set<String>

    public init(
        loadThread: @escaping @Sendable (String, String?) async -> CompanionLoadedThread?,
        send: @escaping @Sendable (
            String, String, @escaping @Sendable (String) -> Void
        ) async -> CompanionSendOutcome,
        deleteFrom: @escaping @Sendable (String) async -> Void,
        clear: @escaping @Sendable (String) async -> Void,
        extract: @escaping @Sendable (String) async -> CompanionExtractionOutcome,
        setUsesLearnerProfile: @escaping @Sendable (String, Bool) async -> Void = { _, _ in },
        setGentleRecast: @escaping @Sendable (String, Bool) async -> Void = { _, _ in },
        memoryPreviewProjection: @escaping @Sendable (String) async -> AIRequestPreviewProjection? = { _ in nil },
        recordTopicPreviewProjection: @escaping @Sendable (String) async -> AIRequestPreviewProjection? = { _ in nil },
        depositAllCandidates: @escaping @Sendable (String) async -> Int = { _ in 0 },
        depositedCandidateIDs: @escaping @Sendable (String) async -> Set<String> = { _ in [] }
    ) {
        self.loadThread = loadThread
        self.send = send
        self.deleteFrom = deleteFrom
        self.clear = clear
        self.extract = extract
        self.setUsesLearnerProfile = setUsesLearnerProfile
        self.setGentleRecast = setGentleRecast
        self.memoryPreviewProjection = memoryPreviewProjection
        self.recordTopicPreviewProjection = recordTopicPreviewProjection
        self.depositAllCandidates = depositAllCandidates
        self.depositedCandidateIDs = depositedCandidateIDs
    }

    public static let disabled = CompanionChatActions(
        loadThread: { _, _ in nil },
        send: { _, _, _ in .failed(.providerUnavailable) },
        deleteFrom: { _ in },
        clear: { _ in },
        extract: { _ in .failed(.providerUnavailable) },
        setUsesLearnerProfile: { _, _ in },
        setGentleRecast: { _, _ in },
        memoryPreviewProjection: { _ in nil },
        recordTopicPreviewProjection: { _ in nil },
        depositAllCandidates: { _ in 0 },
        depositedCandidateIDs: { _ in [] }
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
