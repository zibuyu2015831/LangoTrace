import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Practice session view model")
@MainActor
struct PracticeSessionViewModelTests {
    @Test("View model creates session starts recording and completes latest ready attempt")
    func viewModelCreatesRecordsAndCompletesLatestReadyAttempt() async {
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

        await viewModel.completeLatestRecording()
        #expect(viewModel.session?.status == .completed)
        #expect(viewModel.session?.completedRecordingID == "recording-1")
        #expect(actions.completedRecordingID == "recording-1")
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
}

private final class RecordingPracticeActions: @unchecked Sendable {
    var completedRecordingID: String?
    var playedRecordingID: String?
    var playedDemoCount = 0
    var stoppedDemoCount = 0
    var shouldFailPlayback = false

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
            startRecording: { session in
                PracticeRecordingStart(session: session, recordingID: "recording-1")
            },
            stopRecording: { session, recordingID in
                var next = session
                next.readyRecordings = [
                    PracticeRecordingAttempt(id: recordingID, durationSeconds: 2.4),
                ]
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
        return .idle
    }

    func stopDemo() async {
        stoppedDemoCount += 1
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
