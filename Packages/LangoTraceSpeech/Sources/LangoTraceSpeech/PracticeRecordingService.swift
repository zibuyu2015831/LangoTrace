import Foundation
import LangoTraceCore

public enum PracticeMicrophonePermission: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

public enum PracticeRecordingFailure: Error, Equatable, Sendable {
    case permissionDenied
    case permissionRestricted
    case deviceUnavailable
    case alreadyRecording
    case noActiveRecording
    case recordingIDMismatch
    case startFailed
    case stopFailed
    case fileTooLarge
    case durationTooLong
}

public struct PracticeRecordingLimits: Equatable, Sendable {
    public var maxDurationSeconds: Double
    public var maxByteSize: Int64

    public init(maxDurationSeconds: Double, maxByteSize: Int64) {
        self.maxDurationSeconds = maxDurationSeconds
        self.maxByteSize = maxByteSize
    }

    public static let singleSentenceDefault = PracticeRecordingLimits(
        maxDurationSeconds: 60,
        maxByteSize: 25_000_000
    )
}

public struct PracticeRecordingStartRequest: Equatable, Sendable {
    public var sessionID: String
    public var recordingID: String
    public var stagingRelativePath: String
    public var format: PracticeRecordingFormat

    public init(
        sessionID: String,
        recordingID: String,
        stagingRelativePath: String,
        format: PracticeRecordingFormat
    ) {
        self.sessionID = sessionID
        self.recordingID = recordingID
        self.stagingRelativePath = stagingRelativePath
        self.format = format
    }
}

public struct PracticeRecordingEngineStopResult: Equatable, Sendable {
    public var stagedFile: MediaArtifactStagedFileReference
    public var durationSeconds: Double
    public var byteSize: Int64
    public var contentHash: String

    public init(
        stagedFile: MediaArtifactStagedFileReference,
        durationSeconds: Double,
        byteSize: Int64,
        contentHash: String
    ) {
        self.stagedFile = stagedFile
        self.durationSeconds = durationSeconds
        self.byteSize = byteSize
        self.contentHash = contentHash
    }
}

public typealias PracticeRecordingResult = PracticeRecordingEngineStopResult

public protocol PracticeRecordingEngine: Sendable {
    func requestPermission() async -> PracticeMicrophonePermission
    func start(_ request: PracticeRecordingStartRequest) async throws
    func stop(recordingID: String) async throws -> PracticeRecordingEngineStopResult
    func cancel(recordingID: String) async
}

public actor PracticeRecordingService {
    private let engine: any PracticeRecordingEngine
    private let limits: PracticeRecordingLimits
    private var activeRecordingID: String?

    public init(engine: any PracticeRecordingEngine, limits: PracticeRecordingLimits) {
        self.engine = engine
        self.limits = limits
    }

    public func start(_ request: PracticeRecordingStartRequest) async throws {
        guard activeRecordingID == nil else {
            throw PracticeRecordingFailure.alreadyRecording
        }
        switch await engine.requestPermission() {
        case .authorized:
            break
        case .denied:
            throw PracticeRecordingFailure.permissionDenied
        case .restricted:
            throw PracticeRecordingFailure.permissionRestricted
        case .unavailable:
            throw PracticeRecordingFailure.deviceUnavailable
        case .notDetermined:
            throw PracticeRecordingFailure.permissionDenied
        }
        do {
            try await engine.start(request)
            activeRecordingID = request.recordingID
        } catch let failure as PracticeRecordingFailure {
            throw failure
        } catch {
            throw PracticeRecordingFailure.startFailed
        }
    }

    public func stop(recordingID: String) async throws -> PracticeRecordingResult {
        guard let activeRecordingID else {
            throw PracticeRecordingFailure.noActiveRecording
        }
        guard activeRecordingID == recordingID else {
            throw PracticeRecordingFailure.recordingIDMismatch
        }
        do {
            let result = try await engine.stop(recordingID: recordingID)
            self.activeRecordingID = nil
            guard result.byteSize <= limits.maxByteSize else {
                throw PracticeRecordingFailure.fileTooLarge
            }
            guard result.durationSeconds <= limits.maxDurationSeconds else {
                throw PracticeRecordingFailure.durationTooLong
            }
            return result
        } catch let failure as PracticeRecordingFailure {
            self.activeRecordingID = nil
            throw failure
        } catch {
            self.activeRecordingID = nil
            throw PracticeRecordingFailure.stopFailed
        }
    }

    public func cancel(recordingID: String) async {
        guard activeRecordingID == recordingID else {
            return
        }
        activeRecordingID = nil
        await engine.cancel(recordingID: recordingID)
    }
}
