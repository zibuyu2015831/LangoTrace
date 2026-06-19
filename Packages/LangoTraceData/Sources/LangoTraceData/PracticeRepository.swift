import LangoTraceCore

public protocol PracticeRepository: Sendable {
    /// Creates or restores a practice session for any exercise type, keyed on
    /// `snapshot.exerciseType`. Session rows are structurally identical across
    /// modes; the exercise type carried by the snapshot disambiguates them.
    func createOrRestoreSession(
        languageSpaceID: String,
        snapshot: PracticeSentenceSnapshot
    ) async throws -> PracticeSession

    func session(id: String) async throws -> PracticeSession?
    func completeSession(id: String, recordingID: String) async throws -> PracticeSession
    func readyRecordingArtifact(sessionID: String, recordingID: String) async throws -> MediaArtifact?

    /// Records a text answer (dictation / backtranslation), assigning the next
    /// per-session `attempt_number` inside a transaction.
    func recordTextAttempt(draft: PracticeTextAttemptDraft) async throws -> PracticeTextAttempt

    /// Returns the most recent non-soft-deleted text attempt for a session.
    func latestTextAttempt(sessionID: String) async throws -> PracticeTextAttempt?
}
