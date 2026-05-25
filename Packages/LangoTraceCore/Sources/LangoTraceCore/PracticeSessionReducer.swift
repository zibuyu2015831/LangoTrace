import Foundation

public enum PracticeSessionEvent: Equatable, Sendable {
    case demoPlaybackStarted
    case demoPlaybackStopped
    case startRecordingRequested(recordingID: String)
    case recordingReady(recordingID: String, durationSeconds: Double)
    case recordingFailed(recordingID: String)
    case recordingPlaybackStarted(recordingID: String)
    case recordingPlaybackStopped
    case complete(recordingID: String)
    case toggleProblemMarked
}

public enum PracticeSessionRejection: Equatable, Sendable {
    case audioResourceBusy
    case recordingNotReady
}

public struct PracticeSessionReduction: Equatable, Sendable {
    public var session: PracticeSession
    public var rejection: PracticeSessionRejection?

    public init(session: PracticeSession, rejection: PracticeSessionRejection? = nil) {
        self.session = session
        self.rejection = rejection
    }
}

public enum PracticeSessionReducer {
    public static func reduce(
        _ session: PracticeSession,
        _ event: PracticeSessionEvent
    ) -> PracticeSessionReduction {
        var next = session

        switch event {
        case .demoPlaybackStarted:
            guard next.audioActivity == .idle else {
                return PracticeSessionReduction(session: next, rejection: .audioResourceBusy)
            }
            next.audioActivity = .demoPlayback

        case .demoPlaybackStopped:
            if next.audioActivity == .demoPlayback {
                next.audioActivity = .idle
            }

        case let .startRecordingRequested(recordingID):
            guard next.audioActivity == .idle else {
                return PracticeSessionReduction(session: next, rejection: .audioResourceBusy)
            }
            next.currentStep = .recording
            next.audioActivity = .recording(recordingID: recordingID)

        case let .recordingReady(recordingID, durationSeconds):
            if next.audioActivity == .recording(recordingID: recordingID) {
                next.audioActivity = .idle
            }
            if !next.readyRecordings.contains(where: { $0.id == recordingID }) {
                next.readyRecordings.append(PracticeRecordingAttempt(id: recordingID, durationSeconds: durationSeconds))
            }
            next.currentStep = .completion

        case let .recordingFailed(recordingID):
            if next.audioActivity == .recording(recordingID: recordingID) {
                next.audioActivity = .idle
            }

        case let .recordingPlaybackStarted(recordingID):
            guard next.audioActivity == .idle else {
                return PracticeSessionReduction(session: next, rejection: .audioResourceBusy)
            }
            guard next.readyRecordings.contains(where: { $0.id == recordingID }) else {
                return PracticeSessionReduction(session: next, rejection: .recordingNotReady)
            }
            next.audioActivity = .recordingPlayback(recordingID: recordingID)

        case .recordingPlaybackStopped:
            if case .recordingPlayback = next.audioActivity {
                next.audioActivity = .idle
            }

        case let .complete(recordingID):
            guard next.readyRecordings.contains(where: { $0.id == recordingID }) else {
                return PracticeSessionReduction(session: next, rejection: .recordingNotReady)
            }
            if next.completedRecordingID == nil {
                next.completedRecordingID = recordingID
            }
            next.status = .completed
            next.currentStep = .completion
            next.completedAt = next.completedAt ?? Date()

        case .toggleProblemMarked:
            next.problemMarked.toggle()
        }

        next.updatedAt = Date()
        return PracticeSessionReduction(session: next)
    }
}
