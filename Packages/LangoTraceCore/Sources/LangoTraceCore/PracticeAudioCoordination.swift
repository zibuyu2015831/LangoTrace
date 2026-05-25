public enum PracticeAudioResource: Equatable, Sendable {
    case demoPlayback(sessionID: String)
    case recording(sessionID: String)
    case recordingPlayback(sessionID: String, recordingID: String)
}

public enum PracticeAudioCoordinationEvent: Equatable, Sendable {
    case demoPlaybackStarted(sessionID: String)
    case demoPlaybackStopped(sessionID: String)
    case recordingStartRequested(sessionID: String)
    case recordingStarted(sessionID: String)
    case recordingStopped(sessionID: String)
    case recordingPlaybackStartRequested(sessionID: String, recordingID: String)
    case recordingPlaybackStopped(sessionID: String, recordingID: String)
}

public enum PracticeAudioCoordinationRejection: Equatable, Sendable {
    case busyWithDemoPlayback
    case busyWithRecording
    case busyWithRecordingPlayback
}

public struct PracticeAudioCoordinationReduction: Equatable, Sendable {
    public var state: PracticeAudioCoordinationState
    public var rejection: PracticeAudioCoordinationRejection?

    public init(
        state: PracticeAudioCoordinationState,
        rejection: PracticeAudioCoordinationRejection? = nil
    ) {
        self.state = state
        self.rejection = rejection
    }
}

public struct PracticeAudioCoordinationState: Equatable, Sendable {
    public var activeResource: PracticeAudioResource?

    public init(activeResource: PracticeAudioResource? = nil) {
        self.activeResource = activeResource
    }

    public func reduce(_ event: PracticeAudioCoordinationEvent) -> PracticeAudioCoordinationReduction {
        var next = self

        switch event {
        case let .demoPlaybackStarted(sessionID):
            if let rejection = rejection(for: activeResource) {
                return PracticeAudioCoordinationReduction(state: next, rejection: rejection)
            }
            next.activeResource = .demoPlayback(sessionID: sessionID)

        case let .demoPlaybackStopped(sessionID):
            if activeResource == .demoPlayback(sessionID: sessionID) {
                next.activeResource = nil
            }

        case .recordingStartRequested:
            if let rejection = rejection(for: activeResource) {
                return PracticeAudioCoordinationReduction(state: next, rejection: rejection)
            }

        case let .recordingStarted(sessionID):
            if let rejection = rejection(for: activeResource) {
                return PracticeAudioCoordinationReduction(state: next, rejection: rejection)
            }
            next.activeResource = .recording(sessionID: sessionID)

        case let .recordingStopped(sessionID):
            if activeResource == .recording(sessionID: sessionID) {
                next.activeResource = nil
            }

        case let .recordingPlaybackStartRequested(sessionID, recordingID):
            if let rejection = rejection(for: activeResource) {
                return PracticeAudioCoordinationReduction(state: next, rejection: rejection)
            }
            next.activeResource = .recordingPlayback(sessionID: sessionID, recordingID: recordingID)

        case let .recordingPlaybackStopped(sessionID, recordingID):
            if activeResource == .recordingPlayback(sessionID: sessionID, recordingID: recordingID) {
                next.activeResource = nil
            }
        }

        return PracticeAudioCoordinationReduction(state: next)
    }

    private func rejection(for resource: PracticeAudioResource?) -> PracticeAudioCoordinationRejection? {
        switch resource {
        case .none:
            nil
        case .demoPlayback:
            .busyWithDemoPlayback
        case .recording:
            .busyWithRecording
        case .recordingPlayback:
            .busyWithRecordingPlayback
        }
    }
}
