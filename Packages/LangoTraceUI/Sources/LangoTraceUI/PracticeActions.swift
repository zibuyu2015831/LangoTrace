import Foundation
import LangoTraceCore

public struct PracticeRecordingStart: Sendable {
    public var session: PracticeSession
    public var recordingID: String

    public init(session: PracticeSession, recordingID: String) {
        self.session = session
        self.recordingID = recordingID
    }
}

public struct PracticeActions: Sendable {
    public var createOrRestoreShadowingSession: @Sendable (
        String,
        PracticeSentenceSnapshot
    ) async throws -> PracticeSession
    public var startRecording: @Sendable (PracticeSession) async throws -> PracticeRecordingStart
    public var stopRecording: @Sendable (PracticeSession, String) async throws -> PracticeSession
    public var complete: @Sendable (PracticeSession, String) async throws -> PracticeSession
    public var playRecording: @Sendable (PracticeSession, String) async throws -> Void

    public init(
        createOrRestoreShadowingSession: @escaping @Sendable (
            String,
            PracticeSentenceSnapshot
        ) async throws -> PracticeSession,
        startRecording: @escaping @Sendable (PracticeSession) async throws -> PracticeRecordingStart,
        stopRecording: @escaping @Sendable (PracticeSession, String) async throws -> PracticeSession,
        complete: @escaping @Sendable (PracticeSession, String) async throws -> PracticeSession,
        playRecording: @escaping @Sendable (PracticeSession, String) async throws -> Void
    ) {
        self.createOrRestoreShadowingSession = createOrRestoreShadowingSession
        self.startRecording = startRecording
        self.stopRecording = stopRecording
        self.complete = complete
        self.playRecording = playRecording
    }

    public static let disabled = PracticeActions(
        createOrRestoreShadowingSession: { languageSpaceID, snapshot in
            PracticeSession(
                id: "disabled-\(snapshot.learningMaterialID)-\(snapshot.sentenceIndex)",
                languageSpaceID: languageSpaceID,
                snapshot: snapshot,
                createdAt: snapshot.capturedAt
            )
        },
        startRecording: { _ in
            throw PracticeActionFailure.disabled
        },
        stopRecording: { session, _ in
            session
        },
        complete: { session, _ in
            session
        },
        playRecording: { _, _ in
            throw PracticeActionFailure.disabled
        }
    )
}

public enum PracticeActionFailure: Error, Equatable, Sendable {
    case disabled
    case missingSession
    case missingReadyRecording
    case audioBusy
    case playbackUnavailable

    var localizedSummaryKey: String {
        switch self {
        case .disabled:
            "practice.failure.unavailable"
        case .missingSession:
            "practice.failure.missingSession"
        case .missingReadyRecording:
            "practice.failure.missingReadyRecording"
        case .audioBusy:
            "practice.failure.audioBusy"
        case .playbackUnavailable:
            "practice.failure.playbackUnavailable"
        }
    }
}
