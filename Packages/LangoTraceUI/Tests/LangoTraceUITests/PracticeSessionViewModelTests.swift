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
            actions: actions.actions
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
}

private final class RecordingPracticeActions: @unchecked Sendable {
    var completedRecordingID: String?

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
            }
        )
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
