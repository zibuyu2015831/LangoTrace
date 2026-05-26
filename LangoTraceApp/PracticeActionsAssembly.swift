import Foundation
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceUI

enum PracticeActionsAssembly {
    static func makeActions(database: AppDatabase, mediaArtifactsRoot: URL) throws -> PracticeActions {
        let fileStore = try LocalMediaArtifactFileStore(rootDirectory: mediaArtifactsRoot)
        let mediaStore = LocalMediaArtifactStore(
            repository: GRDBMediaArtifactRepository(database: database),
            fileStore: fileStore,
            audioFileValidator: TTSAudioFileValidator(mediaArtifactsRoot: mediaArtifactsRoot)
        )
        let repository = GRDBPracticeRepository(database: database)
        let playbackSourceResolver = LocalMediaArtifactPlaybackSourceResolver(fileStore: fileStore)
        let recordingPlayer = TTSAudioPlaybackService()
        let recordingService = PracticeRecordingService(
            engine: AppPracticeRecordingEngine(fileStore: fileStore),
            limits: .singleSentenceDefault
        )

        return PracticeActions(
            createOrRestoreShadowingSession: { languageSpaceID, snapshot in
                try await repository.createOrRestoreShadowingSession(
                    languageSpaceID: languageSpaceID,
                    snapshot: snapshot
                )
            },
            startRecording: { session in
                let recordingID = UUID().uuidString
                let request = PracticeRecordingStartRequest(
                    sessionID: session.id,
                    recordingID: recordingID,
                    stagingRelativePath: "staging/\(recordingID).m4a",
                    format: .m4a
                )
                try await recordingService.start(request)
                let reduction = PracticeSessionReducer.reduce(
                    session,
                    .startRecordingRequested(recordingID: recordingID)
                )
                return PracticeRecordingStart(session: reduction.session, recordingID: recordingID)
            },
            stopRecording: { session, recordingID in
                let result = try await recordingService.stop(recordingID: recordingID)
                let attemptNumber = session.readyRecordings.count + 1
                let createdAt = Date()
                let input = PracticeRecordingArtifactCommitInput(
                    key: PracticeRecordingArtifactKey(
                        sessionID: session.id,
                        recordingID: recordingID,
                        attemptNumber: attemptNumber,
                        targetTextHash: session.snapshot.targetTextHash,
                        targetLanguageCode: session.snapshot.targetLanguageCode,
                        recordingFormat: .m4a,
                        createdAtBucket: createdAtBucket(for: createdAt)
                    ),
                    languageSpaceID: session.languageSpaceID,
                    sessionID: session.id,
                    recordingID: recordingID,
                    attemptNumber: attemptNumber,
                    stagedFile: result.stagedFile,
                    mimeType: "audio/mp4",
                    durationSeconds: result.durationSeconds,
                    sampleRate: 44100,
                    channelCount: 1,
                    createdAt: createdAt
                )
                _ = try await mediaStore.commitPracticeRecordingArtifact(input)
                return try await repository.session(id: session.id) ?? session
            },
            complete: { session, recordingID in
                try await repository.completeSession(id: session.id, recordingID: recordingID)
            },
            playRecording: { session, recordingID in
                guard let artifact = try await repository.readyRecordingArtifact(
                    sessionID: session.id,
                    recordingID: recordingID
                ) else {
                    throw PracticeActionFailure.playbackUnavailable
                }
                let source = try await playbackSourceResolver.playbackSource(for: artifact)
                let playbackSession = try await recordingPlayer.play(source)
                let result = await playbackSession.completion()
                if case .failure = result {
                    throw PracticeActionFailure.playbackUnavailable
                }
            }
        )
    }

    private static func createdAtBucket(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
