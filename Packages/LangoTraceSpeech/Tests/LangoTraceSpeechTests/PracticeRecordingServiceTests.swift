import Foundation
import LangoTraceCore
@testable import LangoTraceSpeech
import Testing

@Suite("Practice recording service")
struct PracticeRecordingServiceTests {
    @Test("Recording service requests permission and does not start when denied")
    func recordingServiceDoesNotStartWhenPermissionDenied() async throws {
        let engine = FakePracticeRecordingEngine(permission: .denied)
        let service = PracticeRecordingService(engine: engine, limits: .singleSentenceDefault)

        await #expect(throws: PracticeRecordingFailure.permissionDenied) {
            try await service.start(
                PracticeRecordingStartRequest(
                    sessionID: "session-1",
                    recordingID: "recording-1",
                    stagingRelativePath: "staging/recording-1.m4a",
                    format: .m4a
                )
            )
        }

        #expect(await engine.events == [.requestPermission])
    }

    @Test("Recording service stops active recording and returns staged artifact metadata")
    func recordingServiceStopsActiveRecordingAndReturnsMetadata() async throws {
        let stagedFile = MediaArtifactStagedFileReference(
            relativeStagingPath: "staging/recording-1.m4a",
            byteSize: 1024,
            contentHash: "recording-content-hash"
        )
        let engine = FakePracticeRecordingEngine(stopResult: PracticeRecordingEngineStopResult(
            stagedFile: stagedFile,
            durationSeconds: 1.2,
            byteSize: 1024,
            contentHash: "recording-content-hash"
        ))
        let service = PracticeRecordingService(engine: engine, limits: .singleSentenceDefault)

        try await service.start(
            PracticeRecordingStartRequest(
                sessionID: "session-1",
                recordingID: "recording-1",
                stagingRelativePath: "staging/recording-1.m4a",
                format: .m4a
            )
        )
        let result = try await service.stop(recordingID: "recording-1")

        #expect(result.stagedFile == stagedFile)
        #expect(result.durationSeconds == 1.2)
        #expect(await engine.events == [
            .requestPermission,
            .start("staging/recording-1.m4a"),
            .stop("recording-1"),
        ])
    }

    @Test("Recording service rejects files over configured size limit")
    func recordingServiceRejectsFilesOverSizeLimit() async throws {
        let engine = FakePracticeRecordingEngine(stopResult: PracticeRecordingEngineStopResult(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: "staging/recording-1.m4a",
                byteSize: 99,
                contentHash: "oversized"
            ),
            durationSeconds: 1.2,
            byteSize: 99,
            contentHash: "oversized"
        ))
        let service = PracticeRecordingService(
            engine: engine,
            limits: PracticeRecordingLimits(maxDurationSeconds: 60, maxByteSize: 10)
        )

        try await service.start(
            PracticeRecordingStartRequest(
                sessionID: "session-1",
                recordingID: "recording-1",
                stagingRelativePath: "staging/recording-1.m4a",
                format: .m4a
            )
        )

        await #expect(throws: PracticeRecordingFailure.fileTooLarge) {
            try await service.stop(recordingID: "recording-1")
        }

        #expect(await engine.events.contains(.discardStagedRecording("staging/recording-1.m4a")))
    }

    @Test("Recording service discards staged file when recording exceeds duration limit")
    func recordingServiceDiscardsStagedFileWhenRecordingExceedsDurationLimit() async throws {
        let engine = FakePracticeRecordingEngine(stopResult: PracticeRecordingEngineStopResult(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: "staging/recording-1.m4a",
                byteSize: 9,
                contentHash: "too-long"
            ),
            durationSeconds: 120,
            byteSize: 9,
            contentHash: "too-long"
        ))
        let service = PracticeRecordingService(
            engine: engine,
            limits: PracticeRecordingLimits(maxDurationSeconds: 60, maxByteSize: 10)
        )

        try await service.start(
            PracticeRecordingStartRequest(
                sessionID: "session-1",
                recordingID: "recording-1",
                stagingRelativePath: "staging/recording-1.m4a",
                format: .m4a
            )
        )

        await #expect(throws: PracticeRecordingFailure.durationTooLong) {
            try await service.stop(recordingID: "recording-1")
        }

        #expect(await engine.events.contains(.discardStagedRecording("staging/recording-1.m4a")))
    }
}

private actor FakePracticeRecordingEngine: PracticeRecordingEngine {
    enum Event: Equatable {
        case requestPermission
        case start(String)
        case stop(String)
        case cancel(String)
        case discardStagedRecording(String)
    }

    private let permission: PracticeMicrophonePermission
    private let stopResult: PracticeRecordingEngineStopResult
    private(set) var events: [Event] = []

    init(
        permission: PracticeMicrophonePermission = .authorized,
        stopResult: PracticeRecordingEngineStopResult = PracticeRecordingEngineStopResult(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: "staging/default.m4a",
                byteSize: 10,
                contentHash: "hash"
            ),
            durationSeconds: 1,
            byteSize: 10,
            contentHash: "hash"
        )
    ) {
        self.permission = permission
        self.stopResult = stopResult
    }

    func requestPermission() async -> PracticeMicrophonePermission {
        events.append(.requestPermission)
        return permission
    }

    func start(_ request: PracticeRecordingStartRequest) async throws {
        events.append(.start(request.stagingRelativePath))
    }

    func stop(recordingID: String) async throws -> PracticeRecordingEngineStopResult {
        events.append(.stop(recordingID))
        return stopResult
    }

    func cancel(recordingID: String) async {
        events.append(.cancel(recordingID))
    }

    func discardStagedRecording(_ stagedFile: MediaArtifactStagedFileReference) async {
        events.append(.discardStagedRecording(stagedFile.relativeStagingPath))
    }
}
