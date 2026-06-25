import LangoTraceCore
import SwiftUI

/// Drives the three-platform Language Companion chat. Loads the single per-space
/// thread, sends a turn (persisting user + assistant only on success), supports
/// delete-this-and-after / clear, and shows a local cold-start greeting with zero
/// outbound. Mid-exit safe — every persisted action goes through the repository
/// immediately. On failure the draft text is preserved and no reply is faked
/// (ADR-008 §7).
@MainActor
final class CompanionChatStore: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case unavailable
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var messages: [CompanionMessagePresentation] = []
    @Published var draftText: String = ""
    @Published private(set) var isSending = false
    @Published private(set) var failure: CompanionReplyFailure?
    /// True when the thread has no messages yet — the view shows the local
    /// greeting (idea-03 §3.10), produced without any outbound request.
    @Published private(set) var showsColdStartGreeting = false

    // MARK: - Chat reflux extraction (LM03-S2a)

    @Published private(set) var isExtracting = false
    /// Candidates surfaced after extraction, newest first. Carries the
    /// "source message deleted" display state per candidate (round-1 P2-2).
    @Published private(set) var candidates: [CompanionCandidatePresentation] = []
    /// Count of the last successful extraction read-back (nil before any run; 0 =
    /// the model found nothing — the view shows the "no vocabulary" copy).
    @Published private(set) var lastExtractionCount: Int?
    @Published private(set) var extractionFailure: CompanionExtractionError?

    private let spaceID: String
    private let sourceEntryID: String?
    private var actions: CompanionChatActions
    private var threadID: String?

    init(spaceID: String, sourceEntryID: String?, actions: CompanionChatActions) {
        self.spaceID = spaceID
        self.sourceEntryID = sourceEntryID
        self.actions = actions
    }

    /// Swaps in the environment-injected actions (created `.disabled` before the
    /// SwiftUI environment is available).
    func reconnect(_ actions: CompanionChatActions) {
        self.actions = actions
    }

    var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func load() async {
        phase = .loading
        guard let loaded = await actions.loadThread(spaceID, sourceEntryID) else {
            phase = .unavailable
            return
        }
        threadID = loaded.threadID
        messages = loaded.messages.map(CompanionMessagePresentation.init)
        showsColdStartGreeting = loaded.messages.isEmpty
        failure = nil
        phase = .ready
    }

    func send() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending, let threadID else { return }
        isSending = true
        failure = nil
        let outcome = await actions.send(threadID, text)
        switch outcome {
        case let .appended(user, assistant):
            messages.append(CompanionMessagePresentation(user))
            messages.append(CompanionMessagePresentation(assistant))
            showsColdStartGreeting = false
            draftText = ""
        case let .failed(reason):
            // Keep the draft so the user never loses their input; do not append a
            // faked assistant turn.
            failure = reason
        }
        isSending = false
    }

    /// True when extraction can run: the thread has at least one message and no
    /// extraction is in flight.
    var canExtract: Bool {
        threadID != nil && !messages.isEmpty && !isExtracting
    }

    /// Explicitly extracts vocabulary / expressions from the current conversation
    /// (LM03-S2a). Three outcomes: a count (>0), empty (count 0), or an honest
    /// failure that keeps the conversation. Mirrors `send()` — uses the internal
    /// thread id, never injects Memory / profile content.
    func extractCandidates() async {
        guard let threadID, !isExtracting else { return }
        isExtracting = true
        extractionFailure = nil
        let outcome = await actions.extract(threadID)
        switch outcome {
        case let .extracted(extracted):
            candidates = extracted.map(CompanionCandidatePresentation.init)
            lastExtractionCount = extracted.count
        case let .failed(error):
            extractionFailure = error
        }
        isExtracting = false
    }

    func deleteFrom(id: String) async {
        await actions.deleteFrom(id)
        await load()
    }

    func clear() async {
        guard let threadID else { return }
        await actions.clear(threadID)
        await load()
    }
}
