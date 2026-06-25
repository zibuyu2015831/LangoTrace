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
