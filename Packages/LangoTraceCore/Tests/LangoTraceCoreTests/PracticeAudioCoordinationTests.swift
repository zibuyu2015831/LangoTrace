@testable import LangoTraceCore
import Testing

@Suite("Practice audio coordination")
struct PracticeAudioCoordinationTests {
    @Test("Coordinator state rejects recording in another session while demo is playing")
    func rejectsRecordingInAnotherSessionWhileDemoIsPlaying() {
        var state = PracticeAudioCoordinationState()
        state = state.reduce(.demoPlaybackStarted(sessionID: "session-a")).state

        let reduction = state.reduce(.recordingStartRequested(sessionID: "session-b"))

        #expect(reduction.state.activeResource == .demoPlayback(sessionID: "session-a"))
        #expect(reduction.rejection == .busyWithDemoPlayback)
    }

    @Test("Coordinator state rejects playback while recording is active")
    func rejectsPlaybackWhileRecordingIsActive() {
        var state = PracticeAudioCoordinationState()
        state = state.reduce(.recordingStarted(sessionID: "session-a")).state

        let reduction = state.reduce(.recordingPlaybackStartRequested(sessionID: "session-a", recordingID: "recording-1"))

        #expect(reduction.state.activeResource == .recording(sessionID: "session-a"))
        #expect(reduction.rejection == .busyWithRecording)
    }

    @Test("Coordinator clears active resource when matching session stops")
    func clearsMatchingActiveResource() {
        var state = PracticeAudioCoordinationState()
        state = state.reduce(.recordingStarted(sessionID: "session-a")).state

        let reduction = state.reduce(.recordingStopped(sessionID: "session-a"))

        #expect(reduction.state.activeResource == nil)
        #expect(reduction.rejection == nil)
    }
}
