import LangoTraceCore
import LangoTraceLearnerModel
import SwiftUI

/// Drives the three-platform learner-profile overview page: loads the
/// compute-on-read snapshot for the active space, exposes the never-downgrading
/// presentation, and mediates the unified-governance actions (explicit-remember
/// add, single delete, system reset). Mid-exit safe — every governance action
/// persists immediately.
@MainActor
final class LearnerProfileStore: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case unavailable
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var presentation: LearnerProfilePresentation?
    /// Add-fact draft state (the explicit-remember form).
    @Published var draftKind: MemoryFactKind = .lifeFact
    @Published var draftText: String = ""

    private let spaceID: String
    private let languageCode: String
    private let level: LanguageLevel
    private var actions: LearnerProfileActions
    private let now: @Sendable () -> Date

    init(
        spaceID: String,
        languageCode: String,
        level: LanguageLevel,
        actions: LearnerProfileActions,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.spaceID = spaceID
        self.languageCode = languageCode
        self.level = level
        self.actions = actions
        self.now = now
    }

    /// Swaps in the environment-injected actions (created with `.disabled` before
    /// the SwiftUI environment is available).
    func reconnect(_ actions: LearnerProfileActions) {
        self.actions = actions
    }

    /// Whether the add-fact draft is submittable (non-blank after trimming).
    var canSubmitDraft: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        phase = .loading
        guard let snapshot = await actions.loadSnapshot(spaceID, languageCode) else {
            presentation = nil
            phase = .unavailable
            return
        }
        presentation = LearnerProfilePresentation(snapshot: snapshot, level: level)
        phase = .ready
    }

    func addDraftFact() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await actions.addFact(draftKind, trimmed)
        draftText = ""
        await load()
    }

    func deleteFact(id: String) async {
        await actions.deleteFact(id)
        await load()
    }

    /// System-level "reset what the App knows about me" (§12.3). The confirmation
    /// flow is the view's responsibility; this performs the reset and reloads.
    func resetAllFacts() async {
        await actions.resetAllFacts()
        await load()
    }
}
