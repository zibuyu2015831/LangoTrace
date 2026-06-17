import Foundation
import LangoTraceCore

/// State machine for a single dictation sentence: listen to the existing TTS,
/// type what you heard, submit for a local string comparison, then review the
/// diff. The reference sentence is withheld until the answer is compared so the
/// user cannot read the answer while listening.
@MainActor
final class PracticeDictationSessionViewModel: ObservableObject {
    enum Phase: Equatable {
        case listening
        case compared
    }

    private let languageSpaceID: String
    private let snapshot: PracticeSentenceSnapshot
    private let actions: PracticeActions
    private let playDemoAction: @MainActor @Sendable () async -> SentenceAudioPresentationState
    private let stopDemoAction: @MainActor @Sendable () async -> Void

    @Published private(set) var session: PracticeSession?
    @Published private(set) var isLoading = false
    @Published private(set) var phase: Phase = .listening
    @Published var attemptText = ""
    @Published private(set) var listenCount = 0
    @Published private(set) var isPlayingDemo = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var diffResult: PracticeDictationDiff.Result?
    @Published private(set) var failure: PracticeActionFailure?

    private var isDemoTapInFlight = false

    init(
        languageSpaceID: String,
        snapshot: PracticeSentenceSnapshot,
        actions: PracticeActions,
        playDemo: @escaping @MainActor @Sendable () async -> SentenceAudioPresentationState = { .idle },
        stopDemo: @escaping @MainActor @Sendable () async -> Void = {}
    ) {
        self.languageSpaceID = languageSpaceID
        self.snapshot = snapshot
        self.actions = actions
        playDemoAction = playDemo
        stopDemoAction = stopDemo
    }

    /// The reference sentence, exposed only after comparison. Returns `nil`
    /// while listening so the answer can never be rendered prematurely.
    var visibleReferenceText: String? {
        phase == .compared ? snapshot.targetTextSnapshot : nil
    }

    var canSubmit: Bool {
        !attemptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    func load() async {
        guard session == nil else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            session = try await actions.createOrRestoreSession(languageSpaceID, snapshot)
            failure = nil
        } catch {
            failure = .missingSession
        }
    }

    /// Plays the existing TTS demo for this sentence. Replays are unlimited; the
    /// listen count is low-weight informational state, never a score.
    func playDemo() async {
        guard !isSubmitting else {
            return
        }
        guard !isDemoTapInFlight else {
            failure = .audioBusy
            return
        }
        isDemoTapInFlight = true
        isPlayingDemo = true
        defer {
            isDemoTapInFlight = false
            isPlayingDemo = false
        }
        let state = await playDemoAction()
        switch state {
        case .failed:
            failure = .playbackUnavailable
        default:
            listenCount += 1
            failure = nil
        }
    }

    func stopDemoPlayback() async {
        await stopDemoAction()
        isPlayingDemo = false
    }

    /// Compares the typed answer against the reference (local, no AI) and
    /// persists the attempt. The diff is computed first so a persistence failure
    /// never discards the comparison the user is looking at.
    func submit() async {
        guard let session else {
            failure = .missingSession
            return
        }
        let result: PracticeDictationDiff.Result
        do {
            result = try PracticeDictationDiff.compare(
                attempt: attemptText,
                reference: snapshot.targetTextSnapshot
            )
        } catch {
            failure = .inputTooLong
            return
        }

        diffResult = result
        phase = .compared
        failure = nil

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await actions.submitDictationAttempt(
                session,
                PracticeDictationAttemptSubmission(
                    attemptText: attemptText,
                    referenceText: snapshot.targetTextSnapshot,
                    differenceCount: result.differenceCount,
                    summary: result.summary,
                    listenCount: listenCount
                )
            )
        } catch {
            failure = .attemptSaveFailed
        }
    }

    /// Starts a fresh attempt: hides the reference, clears the input and diff.
    func retry() {
        phase = .listening
        attemptText = ""
        diffResult = nil
        failure = nil
    }

    /// Stops demo playback before the session leaves for another sentence.
    /// The stop is unconditional so a coordinator still finishing playback is
    /// halted even if `isPlayingDemo` has already been cleared locally
    /// (sentence switches must not carry playback across).
    func prepareForNavigation() async {
        await stopDemoPlayback()
    }
}
