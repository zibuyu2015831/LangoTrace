import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Practice session reducer")
struct PracticeSessionReducerTests {
    @Test("Session starts as single sentence shadowing from immutable snapshot")
    func sessionStartsFromSentenceSnapshot() {
        let session = PracticeSession(
            id: "session-1",
            languageSpaceID: "space-1",
            snapshot: sentenceSnapshot(),
            createdAt: Date(timeIntervalSince1970: 100)
        )

        #expect(session.exerciseType == .shadowing)
        #expect(session.currentStep == .shadowing)
        #expect(session.snapshot.targetTextSnapshot == "I booked the train this morning.")
        #expect(session.snapshot.targetTextHash == "target-hash-1")
        #expect(session.completedRecordingID == nil)
    }

    @Test("Reducer rejects recording while demo playback is active")
    func reducerRejectsRecordingWhileDemoPlaybackIsActive() {
        var session = practiceSession()
        session = PracticeSessionReducer.reduce(session, .demoPlaybackStarted).session

        let reduction = PracticeSessionReducer.reduce(session, .startRecordingRequested(recordingID: "recording-1"))

        #expect(reduction.session.audioActivity == .demoPlayback)
        #expect(reduction.rejection == .audioResourceBusy)
    }

    @Test("Completed recording remains stable when user records a newer attempt")
    func completedRecordingRemainsStableAcrossLaterAttempts() {
        var session = practiceSession()
        session = PracticeSessionReducer.reduce(session, .startRecordingRequested(recordingID: "recording-1")).session
        session = PracticeSessionReducer.reduce(
            session,
            .recordingReady(recordingID: "recording-1", durationSeconds: 1.4)
        ).session
        session = PracticeSessionReducer.reduce(session, .complete(recordingID: "recording-1")).session

        session = PracticeSessionReducer.reduce(session, .startRecordingRequested(recordingID: "recording-2")).session
        session = PracticeSessionReducer.reduce(
            session,
            .recordingReady(recordingID: "recording-2", durationSeconds: 1.2)
        ).session

        #expect(session.status == .completed)
        #expect(session.completedRecordingID == "recording-1")
        #expect(session.latestReadyRecordingID == "recording-2")
    }

    @Test("Completion requires a ready recording from the same session")
    func completionRequiresReadyRecording() {
        let session = practiceSession()

        let reduction = PracticeSessionReducer.reduce(session, .complete(recordingID: "missing-recording"))

        #expect(reduction.session.status == .inProgress)
        #expect(reduction.session.completedRecordingID == nil)
        #expect(reduction.rejection == .recordingNotReady)
    }
}

private func practiceSession() -> PracticeSession {
    PracticeSession(
        id: "session-1",
        languageSpaceID: "space-1",
        snapshot: sentenceSnapshot(),
        createdAt: Date(timeIntervalSince1970: 100)
    )
}

private func sentenceSnapshot() -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: 0,
        targetTextSnapshot: "I booked the train this morning.",
        targetTextHash: "target-hash-1",
        targetLanguageCode: "en",
        translationSnapshot: "我今天早上订了火车票。",
        noteSnapshot: "booked 表示已经完成预订。",
        sourceEntryBodyHash: "entry-body-hash-1",
        materialAnalysisSourceHash: "analysis-hash-1",
        exerciseType: .shadowing,
        capturedAt: Date(timeIntervalSince1970: 100)
    )
}
