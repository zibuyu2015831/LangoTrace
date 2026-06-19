import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Practice dictation session view model")
@MainActor
struct PracticeDictationSessionTests {
    @Test("Reference stays hidden until the answer is compared and never auto-plays on load")
    func referenceHiddenUntilComparedAndNoAutoPlay() async {
        let actions = DictationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()

        #expect(viewModel.session?.id == "dictation-session-1")
        #expect(viewModel.phase == .listening)
        #expect(viewModel.visibleReferenceText == nil)
        #expect(viewModel.isPlayingDemo == false)
        #expect(actions.playedDemoCount == 0)
    }

    @Test("Listening increments the listen count without limit")
    func listeningIncrementsListenCount() async {
        let actions = DictationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        await viewModel.playDemo()
        await viewModel.playDemo()

        #expect(viewModel.listenCount == 2)
        #expect(actions.playedDemoCount == 2)
        #expect(viewModel.isPlayingDemo == false)
    }

    @Test("Submitting compares locally, reveals the reference, and persists the attempt")
    func submitComparesRevealsReferenceAndPersists() async {
        let actions = DictationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        await viewModel.playDemo()
        viewModel.attemptText = "The owner says he only stay for three hours a day."
        await viewModel.submit()

        #expect(viewModel.phase == .compared)
        #expect(viewModel.visibleReferenceText == "The owner says he only stays for three hours a day.")
        #expect(viewModel.diffResult?.differenceCount == 1)
        #expect(viewModel.failure == nil)
        let submission = actions.lastSubmission
        #expect(submission?.differenceCount == 1)
        #expect(submission?.attemptText == "The owner says he only stay for three hours a day.")
        #expect(submission?.listenCount == 1)
    }

    @Test("Retry returns to listening and hides the reference again")
    func retryReturnsToListeningAndHidesReference() async {
        let actions = DictationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "The owner says he only stay for three hours a day."
        await viewModel.submit()
        viewModel.retry()

        #expect(viewModel.phase == .listening)
        #expect(viewModel.attemptText.isEmpty)
        #expect(viewModel.visibleReferenceText == nil)
        #expect(viewModel.diffResult == nil)
    }

    @Test("Overlong input is rejected without persisting and stays in listening")
    func overlongInputRejectedWithoutPersisting() async {
        let actions = DictationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = String(repeating: "word ", count: PracticeDictationDiff.maxInputLength)
        await viewModel.submit()

        #expect(viewModel.phase == .listening)
        #expect(viewModel.failure == .inputTooLong)
        #expect(viewModel.visibleReferenceText == nil)
        #expect(actions.lastSubmission == nil)
    }

    @Test("Persistence failure keeps the compared diff so the user can retry without losing it")
    func persistenceFailureKeepsComparedState() async {
        let actions = DictationPracticeActions()
        actions.shouldFailSubmit = true
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "The owner says he only stay for three hours a day."
        await viewModel.submit()

        #expect(viewModel.phase == .compared)
        #expect(viewModel.diffResult?.differenceCount == 1)
        #expect(viewModel.failure == .attemptSaveFailed)
    }

    @Test("Preparing for navigation stops active demo playback")
    func prepareForNavigationStopsDemoPlayback() async {
        let actions = DictationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        await viewModel.prepareForNavigation()

        #expect(actions.stoppedDemoCount == 1)
        #expect(viewModel.isPlayingDemo == false)
    }

    private func makeViewModel(actions: DictationPracticeActions) -> PracticeDictationSessionViewModel {
        PracticeDictationSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: dictationSnapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )
    }
}

private final class DictationPracticeActions: @unchecked Sendable {
    var playedDemoCount = 0
    var stoppedDemoCount = 0
    var shouldFailSubmit = false
    private(set) var lastSubmission: PracticeDictationAttemptSubmission?

    var actions: PracticeActions {
        PracticeActions(
            availableExerciseTypes: [.shadowing, .dictation],
            createOrRestoreSession: { _, snapshot in
                PracticeSession(
                    id: "dictation-session-1",
                    languageSpaceID: "space-1",
                    snapshot: snapshot,
                    createdAt: Date(timeIntervalSince1970: 1)
                )
            },
            startRecording: { _ in throw PracticeActionFailure.disabled },
            stopRecording: { session, _ in session },
            complete: { session, _ in session },
            playRecording: { _, _ in throw PracticeActionFailure.disabled },
            submitDictationAttempt: { [weak self] _, submission in
                if self?.shouldFailSubmit == true {
                    throw PracticeActionFailure.attemptSaveFailed
                }
                self?.lastSubmission = submission
            }
        )
    }

    func playDemo() async -> SentenceAudioPresentationState {
        playedDemoCount += 1
        return .idle
    }

    func stopDemo() async {
        stoppedDemoCount += 1
    }
}

private func dictationSnapshot() -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: 0,
        targetTextSnapshot: "The owner says he only stays for three hours a day.",
        targetTextHash: String(repeating: "a", count: 64),
        targetLanguageCode: "en",
        translationSnapshot: "房主说他每天只待三个小时。",
        noteSnapshot: nil,
        sourceEntryBodyHash: "source-hash",
        materialAnalysisSourceHash: nil,
        exerciseType: .dictation,
        capturedAt: Date(timeIntervalSince1970: 1)
    )
}
