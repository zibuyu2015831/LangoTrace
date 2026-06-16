import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Practice session view model")
@MainActor
struct PracticeSessionViewModelTests {
    @Test("View model creates session and keeps latest recording repeatable")
    func viewModelCreatesSessionAndKeepsLatestRecordingRepeatable() async {
        let actions = RecordingPracticeActions()
        let viewModel = PracticeSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )

        await viewModel.load()
        #expect(viewModel.session?.id == "session-1")

        await viewModel.startRecording()
        #expect(viewModel.isRecording)
        #expect(viewModel.activeRecordingID == "recording-1")

        await viewModel.stopRecording()
        #expect(!viewModel.isRecording)
        #expect(viewModel.session?.latestReadyRecordingID == "recording-1")

        await viewModel.startRecording()
        #expect(viewModel.isRecording)
        #expect(viewModel.activeRecordingID == "recording-2")

        await viewModel.stopRecording()
        #expect(viewModel.session?.readyRecordings.map(\.id) == ["recording-1", "recording-2"])
        #expect(viewModel.session?.latestReadyRecordingID == "recording-2")
        #expect(viewModel.session?.status == .inProgress)
    }

    @Test("View model plays demo and latest ready recording without mutating completion")
    func viewModelPlaysDemoAndLatestReadyRecording() async {
        let actions = RecordingPracticeActions()
        let viewModel = PracticeSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )

        await viewModel.load()
        await viewModel.playDemo()
        #expect(actions.playedDemoCount == 1)
        #expect(!viewModel.isPlayingDemo)

        await viewModel.startRecording()
        await viewModel.stopRecording()
        await viewModel.playLatestRecording()

        #expect(actions.playedRecordingID == "recording-1")
        #expect(!viewModel.isPlayingRecording)
        #expect(viewModel.session?.status == .inProgress)
    }

    @Test("View model marks demo playback active while demo action is in progress")
    func viewModelMarksDemoPlaybackActiveWhileActionInProgress() async {
        let actions = RecordingPracticeActions()
        actions.shouldSuspendDemoPlayback = true
        let viewModel = PracticeSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )

        await viewModel.load()
        let task = Task {
            await viewModel.playDemo()
        }
        await actions.waitForSuspendedDemoPlayback()

        #expect(viewModel.isPlayingDemo)

        actions.resumeSuspendedDemoPlayback()
        await task.value
        #expect(!viewModel.isPlayingDemo)
    }

    @Test("View model plays the latest ready recording after repeated attempts")
    func viewModelPlaysLatestReadyRecordingAfterRepeatedAttempts() async {
        let actions = RecordingPracticeActions()
        let viewModel = PracticeSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )

        await viewModel.load()
        await viewModel.startRecording()
        await viewModel.stopRecording()
        await viewModel.startRecording()
        await viewModel.stopRecording()
        await viewModel.playLatestRecording()

        #expect(viewModel.session?.readyRecordings.map(\.id) == ["recording-1", "recording-2"])
        #expect(viewModel.session?.latestReadyRecordingID == "recording-2")
        #expect(actions.playedRecordingID == "recording-2")
    }

    @Test("View model blocks playback while recording is active")
    func viewModelBlocksPlaybackWhileRecordingIsActive() async {
        let actions = RecordingPracticeActions()
        let viewModel = PracticeSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )

        await viewModel.load()
        await viewModel.startRecording()
        await viewModel.playDemo()
        await viewModel.playLatestRecording()

        #expect(actions.playedDemoCount == 0)
        #expect(actions.playedRecordingID == nil)
        #expect(viewModel.failure == .audioBusy)
        #expect(viewModel.failure?.localizedSummaryKey == "practice.failure.audioBusy")
    }

    @Test("View model exposes a user-visible failure key when recording playback is unavailable")
    func viewModelExposesVisibleFailureWhenPlaybackUnavailable() async {
        let actions = RecordingPracticeActions()
        actions.shouldFailPlayback = true
        let viewModel = PracticeSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )

        await viewModel.load()
        await viewModel.startRecording()
        await viewModel.stopRecording()
        await viewModel.playLatestRecording()

        #expect(viewModel.failure == .playbackUnavailable)
        #expect(viewModel.failure?.localizedSummaryKey == "practice.failure.playbackUnavailable")
    }

    @Test("View model exposes visible failure when recording stop cannot produce a ready recording")
    func viewModelExposesVisibleFailureWhenStopRecordingFails() async {
        let actions = RecordingPracticeActions()
        actions.shouldFailStopRecording = true
        let viewModel = PracticeSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )

        await viewModel.load()
        await viewModel.startRecording()
        await viewModel.stopRecording()

        #expect(!viewModel.isRecording)
        #expect(viewModel.session?.latestReadyRecordingID == nil)
        #expect(viewModel.failure == .recordingUnavailable)
        #expect(viewModel.visibleFailure == .recordingUnavailable)
    }

    @Test("View model stops active demo playback before starting recording")
    func viewModelStopsActiveDemoBeforeStartingRecording() async {
        let actions = RecordingPracticeActions()
        let viewModel = PracticeSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            actions: actions.actions,
            playDemo: actions.playDemo,
            stopDemo: actions.stopDemo
        )

        await viewModel.load()
        await viewModel.startRecording()

        #expect(actions.stoppedDemoCount == 1)
        #expect(viewModel.isRecording)
    }

    @Test("Control bar presentation keeps recording action repeatable after ready recordings")
    func controlBarPresentationKeepsRecordingActionRepeatableAfterReadyRecordings() {
        let base = PracticeSession(
            id: "session-1",
            languageSpaceID: "space-1",
            snapshot: snapshot(),
            createdAt: Date(timeIntervalSince1970: 1)
        )

        #expect(
            PracticeControlBarPresentation(session: base, isRecording: true, isPlayingRecording: false)
                .primaryTitleKey == "practice.recording.stop"
        )

        var withRecording = base
        withRecording.readyRecordings = [
            PracticeRecordingAttempt(id: "recording-1", durationSeconds: 2.4),
        ]
        #expect(
            PracticeControlBarPresentation(session: withRecording, isRecording: false, isPlayingRecording: false)
                .primaryTitleKey == "practice.recording.recordAgain"
        )

        var completed = withRecording
        completed.status = .completed
        completed.completedRecordingID = "recording-1"
        #expect(
            PracticeControlBarPresentation(session: completed, isRecording: false, isPlayingRecording: false)
                .primaryTitleKey == "practice.recording.recordAgain"
        )
    }
}

private final class RecordingPracticeActions: @unchecked Sendable {
    var completedRecordingID: String?
    var playedRecordingID: String?
    var playedDemoCount = 0
    var stoppedDemoCount = 0
    var shouldFailPlayback = false
    var shouldFailStopRecording = false
    var shouldSuspendDemoPlayback = false
    private var nextRecordingNumber = 1
    private var demoPlaybackStartedContinuation: CheckedContinuation<Void, Never>?
    private var suspendedDemoPlaybackContinuation: CheckedContinuation<Void, Never>?
    private var isSuspendedDemoPlaybackStarted = false

    var actions: PracticeActions {
        PracticeActions(
            createOrRestoreShadowingSession: { _, snapshot in
                PracticeSession(
                    id: "session-1",
                    languageSpaceID: "space-1",
                    snapshot: snapshot,
                    createdAt: Date(timeIntervalSince1970: 1)
                )
            },
            startRecording: { [weak self] session in
                let number = self?.nextRecordingNumber ?? 1
                self?.nextRecordingNumber = number + 1
                return PracticeRecordingStart(session: session, recordingID: "recording-\(number)")
            },
            stopRecording: { [weak self] session, recordingID in
                if self?.shouldFailStopRecording == true {
                    throw PracticeActionFailure.recordingUnavailable
                }
                var next = session
                next.readyRecordings.append(
                    PracticeRecordingAttempt(id: recordingID, durationSeconds: 2.4)
                )
                next.currentStep = .completion
                return next
            },
            complete: { [weak self] session, recordingID in
                self?.completedRecordingID = recordingID
                var next = session
                next.status = .completed
                next.completedRecordingID = recordingID
                return next
            },
            playRecording: { [weak self] _, recordingID in
                if self?.shouldFailPlayback == true {
                    throw PracticeActionFailure.playbackUnavailable
                }
                self?.playedRecordingID = recordingID
            }
        )
    }

    func playDemo() async -> SentenceAudioPresentationState {
        playedDemoCount += 1
        if shouldSuspendDemoPlayback {
            await withCheckedContinuation { continuation in
                isSuspendedDemoPlaybackStarted = true
                resumeDemoPlaybackStartedWaiter()
                suspendedDemoPlaybackContinuation = continuation
            }
        }
        return .idle
    }

    func stopDemo() async {
        stoppedDemoCount += 1
    }

    func waitForSuspendedDemoPlayback() async {
        guard !isSuspendedDemoPlaybackStarted else {
            return
        }
        await withCheckedContinuation { continuation in
            demoPlaybackStartedContinuation = continuation
        }
    }

    func resumeSuspendedDemoPlayback() {
        suspendedDemoPlaybackContinuation?.resume()
        suspendedDemoPlaybackContinuation = nil
    }

    private func resumeDemoPlaybackStartedWaiter() {
        demoPlaybackStartedContinuation?.resume()
        demoPlaybackStartedContinuation = nil
    }
}

private func snapshot() -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: 0,
        targetTextSnapshot: "I booked the train this morning.",
        targetTextHash: String(repeating: "a", count: 64),
        targetLanguageCode: "en",
        translationSnapshot: "我今天早上订了火车票。",
        noteSnapshot: "booked 表示已经完成预订。",
        sourceEntryBodyHash: "source-hash",
        materialAnalysisSourceHash: nil,
        exerciseType: .shadowing,
        capturedAt: Date(timeIntervalSince1970: 1)
    )
}
