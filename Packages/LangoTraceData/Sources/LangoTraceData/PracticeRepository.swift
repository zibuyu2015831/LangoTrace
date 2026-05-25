import LangoTraceCore

public protocol PracticeRepository: Sendable {
    func createOrRestoreShadowingSession(
        languageSpaceID: String,
        snapshot: PracticeSentenceSnapshot
    ) async throws -> PracticeSession

    func session(id: String) async throws -> PracticeSession?
    func completeSession(id: String, recordingID: String) async throws -> PracticeSession
}
