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
    /// The cumulative in-flight assistant reply while a send streams (LM03-S3a).
    /// UI-only — the view renders a transient bubble from it; it is NEVER persisted
    /// (only the success outcome's full text is stored) and is cleared on every
    /// completion path (success / failure / cancel).
    @Published private(set) var inFlightReply: String = ""
    /// Whether the space persona uses the gentle-recast correction posture
    /// (`.warmRecast`). Derived from the loaded thread's persona; the toolbar
    /// toggle flips it (LM03-S3a).
    @Published private(set) var gentleRecastEnabled = false

    // MARK: - Chat reflux extraction (LM03-S2a)

    @Published private(set) var isExtracting = false
    /// Candidates surfaced after extraction, newest first. Carries the
    /// "source message deleted" display state per candidate (round-1 P2-2).
    @Published private(set) var candidates: [CompanionCandidatePresentation] = []
    /// Count of the last successful extraction read-back (nil before any run; 0 =
    /// the model found nothing — the view shows the "no vocabulary" copy).
    @Published private(set) var lastExtractionCount: Int?
    @Published private(set) var extractionFailure: CompanionExtractionError?

    // MARK: - Session summary deposit (LM03-S3b-2)

    /// Source-candidate ids already deposited into the memory review system. Drives
    /// the per-candidate "added" badge; refreshed on load and after a deposit. The
    /// presentation stays unchanged — `isDeposited` is a dynamic, store-owned state
    /// (not a static presentation field), so the view queries it reactively.
    @Published private(set) var depositedCandidateIDs: Set<String> = []
    @Published private(set) var isDepositing = false

    // MARK: - Memory injection two-layer privacy (LM03-S2b-1)

    /// Global, three-state consent for injecting the learner's life facts. The
    /// authorization UX is a one-time preview (not per-send): `notDecided` surfaces
    /// the preview once, then never again.
    @Published private(set) var memoryConsent: CompanionMemoryConsent = .notDecided
    /// Per-conversation toggle (the second privacy layer), from the loaded thread.
    /// Shared by Memory injection (S2b-1) and record topic-sourcing (S2b-2):
    /// off → both disabled.
    @Published private(set) var usesLearnerProfile = true
    /// Global, three-state consent for the companion to draw a topic from the
    /// user's records (S2b-2). One-time preview, like Memory consent.
    @Published private(set) var topicConsent: CompanionTopicSourcingConsent = .notDecided

    private let spaceID: String
    private let sourceEntryID: String?
    private var actions: CompanionChatActions
    private let consentStore: any CompanionMemoryConsentStore
    private let topicConsentStore: any CompanionTopicSourcingConsentStore
    private var threadID: String?

    init(
        spaceID: String,
        sourceEntryID: String?,
        actions: CompanionChatActions,
        consentStore: any CompanionMemoryConsentStore = UserDefaultsCompanionMemoryConsentStore(),
        topicConsentStore: any CompanionTopicSourcingConsentStore = UserDefaultsCompanionTopicSourcingConsentStore()
    ) {
        self.spaceID = spaceID
        self.sourceEntryID = sourceEntryID
        self.actions = actions
        self.consentStore = consentStore
        self.topicConsentStore = topicConsentStore
    }

    /// UI-only derived state: would a send inject Memory right now? Authoritative
    /// egress gating happens in the App send path, never here.
    var canInjectMemory: Bool {
        memoryConsent == .enabled && usesLearnerProfile
    }

    /// True when the one-time injection preview must be shown (consent undecided).
    /// Not a per-send check — it stops surfacing once the user decides.
    var needsMemoryConsentPreview: Bool {
        memoryConsent == .notDecided
    }

    /// Records the user's one-time decision from the preview.
    func setMemoryConsent(_ consent: CompanionMemoryConsent) {
        consentStore.consent = consent
        memoryConsent = consent
    }

    /// UI-only: would a send auto-source a topic from records right now?
    /// Authoritative egress gating happens in the App send path, never here.
    var canSourceTopic: Bool {
        topicConsent == .enabled && usesLearnerProfile
    }

    /// True when the one-time topic-sourcing preview must be shown (undecided).
    var needsTopicSourcingPreview: Bool {
        topicConsent == .notDecided
    }

    /// Records the user's one-time topic-sourcing decision.
    func setTopicConsent(_ consent: CompanionTopicSourcingConsent) {
        topicConsentStore.consent = consent
        topicConsent = consent
    }

    /// Builds the one-time topic-sourcing preview from the real "will-send"
    /// projection (nil when no provider is configured).
    func topicPreviewModel() async -> CompanionMemoryPreviewModel? {
        guard let threadID else { return nil }
        guard let projection = await actions.recordTopicPreviewProjection(threadID) else { return nil }
        return CompanionMemoryPreviewModel(projection: projection)
    }

    /// Flips the per-conversation toggle and persists it.
    func setUsesLearnerProfile(_ enabled: Bool) async {
        guard let threadID else { return }
        await actions.setUsesLearnerProfile(threadID, enabled)
        usesLearnerProfile = enabled
    }

    /// Builds the one-time injection preview from the real "will-send" projection
    /// (nil when no provider is configured — the view falls back to local copy).
    func memoryPreviewModel() async -> CompanionMemoryPreviewModel? {
        guard let threadID else { return nil }
        guard let projection = await actions.memoryPreviewProjection(threadID) else { return nil }
        return CompanionMemoryPreviewModel(projection: projection)
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
        usesLearnerProfile = loaded.usesLearnerProfile
        gentleRecastEnabled = loaded.correction == .warmRecast
        memoryConsent = consentStore.consent
        topicConsent = topicConsentStore.consent
        depositedCandidateIDs = await actions.depositedCandidateIDs(spaceID)
        failure = nil
        phase = .ready
    }

    func send() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending, let threadID else { return }
        isSending = true
        failure = nil
        inFlightReply = ""

        // Stream the partial reply through a single AsyncStream consumed by one
        // ordered MainActor loop: `onPartial` only `yield`s (Sendable, in order),
        // so the in-flight bubble updates are race-free by construction — no Task
        // fan-out, no monotonic guard needed (LM03-S3a P0-1).
        let (partials, continuation) = AsyncStream<String>.makeStream()
        let consumer = Task { @MainActor in
            for await partial in partials {
                inFlightReply = partial
            }
        }
        let outcome = await actions.send(threadID, text) { continuation.yield($0) }
        continuation.finish()
        await consumer.value

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
        // The in-flight reply is UI-only — clear it on every path (success persists
        // the full text as a real message; failure / cancel discard the partial).
        inFlightReply = ""
        isSending = false
    }

    /// Flips the space persona's gentle-recast posture and persists it (LM03-S3a).
    /// The App does a read-modify-write so tone / formality are preserved.
    func setGentleRecast(_ enabled: Bool) async {
        await actions.setGentleRecast(spaceID, enabled)
        gentleRecastEnabled = enabled
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

    // MARK: - Session summary deposit (LM03-S3b-2)

    /// Whether a candidate has already been deposited into the memory review system
    /// (drives the per-candidate "added" badge). Reactive: backed by the
    /// `@Published depositedCandidateIDs`, so the view refreshes after a deposit.
    func isCandidateDeposited(_ id: String) -> Bool {
        depositedCandidateIDs.contains(id)
    }

    /// True when there are extracted candidates and no deposit is in flight.
    var canDeposit: Bool {
        !candidates.isEmpty && !isDepositing
    }

    /// Batch-deposits all of this space's companion candidates into the memory
    /// review system (LM03-S3b-2 — closes the chat → memory loop). Idempotent;
    /// refreshes the deposited set afterwards.
    func depositAllCandidates() async {
        guard !isDepositing else { return }
        isDepositing = true
        _ = await actions.depositAllCandidates(spaceID)
        depositedCandidateIDs = await actions.depositedCandidateIDs(spaceID)
        isDepositing = false
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
