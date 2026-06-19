import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceUI

enum PracticeActionsAssembly {
    static func makeActions(
        database: AppDatabase,
        mediaArtifactsRoot: URL,
        recordingEngine: (any PracticeRecordingEngine)? = nil,
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger(),
        credentialStore: (any AIProviderCredentialStore)? = nil,
        aiRequestLogRecorder: AIRequestLogRecorder = AIRequestLogRecorder(repository: nil)
    ) throws -> PracticeActions {
        let fileStore = try LocalMediaArtifactFileStore(rootDirectory: mediaArtifactsRoot)
        let mediaStore = LocalMediaArtifactStore(
            repository: GRDBMediaArtifactRepository(database: database),
            fileStore: fileStore,
            audioFileValidator: TTSAudioFileValidator(mediaArtifactsRoot: mediaArtifactsRoot)
        )
        let repository = GRDBPracticeRepository(database: database)
        let learningContentRepository = GRDBLearningContentRepository(database: database)
        let playbackSourceResolver = LocalMediaArtifactPlaybackSourceResolver(fileStore: fileStore)
        let recordingPlayer = TTSAudioPlaybackService()
        let recordingService = PracticeRecordingService(
            engine: recordingEngine ?? AppPracticeRecordingEngine(fileStore: fileStore),
            limits: .singleSentenceDefault
        )

        return PracticeActions(
            availableExerciseTypes: [.shadowing, .dictation, .backtranslation],
            createOrRestoreSession: { languageSpaceID, snapshot in
                try await repository.createOrRestoreSession(
                    languageSpaceID: languageSpaceID,
                    snapshot: snapshot
                )
            },
            completedSentenceIDs: { materialID, exerciseType in
                try await repository.completedSentenceIDs(
                    materialID: materialID,
                    exerciseType: exerciseType
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
            stopRecording: makeStopRecordingAction(
                recordingService: recordingService,
                mediaStore: mediaStore,
                repository: repository,
                diagnosticLogger: diagnosticLogger
            ),
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
            },
            submitDictationAttempt: makeSubmitDictationAttempt(repository: repository),
            submitBacktranslationAttempt: makeSubmitBacktranslationAttempt(repository: repository),
            fetchSentenceAnalysis: { materialID, sentenceIndex in
                try learningContentRepository.sentenceAnalysis(
                    materialID: materialID,
                    sentenceIndex: sentenceIndex
                )
            },
            reviewBacktranslation: makeReviewBacktranslation(
                database: database,
                credentialStore: credentialStore,
                aiRequestLogRecorder: aiRequestLogRecorder
            )
        )
    }

    /// Explicitly-triggered optional AI critique (系列 E5 Slice 2). Resolves the
    /// default text endpoint + the language space's target language / proficiency,
    /// sends only the three short texts, writes a non-sensitive request log, and
    /// maps failures onto `PracticeBacktranslationReviewFailure`. Never auto-runs —
    /// only the "请 AI 点评" button reaches here.
    private static func makeReviewBacktranslation(
        database: AppDatabase,
        credentialStore: (any AIProviderCredentialStore)?,
        aiRequestLogRecorder: AIRequestLogRecorder
    ) -> @Sendable (String, PracticeBacktranslationReviewSubmission) async throws -> PracticeBacktranslationReviewResult {
        { languageSpaceID, submission in
            guard let credentialStore else {
                throw PracticeBacktranslationReviewFailure(category: .providerNotConfigured)
            }
            let configurationRepository = GRDBAIProviderConfigurationRepository(database: database)
            guard let profile = try await configurationRepository.loadDefaultProfile(),
                  let endpoint = profile.textGenerationEndpointInput
            else {
                throw PracticeBacktranslationReviewFailure(category: .providerNotConfigured)
            }
            let space = try? GRDBLanguageSpaceRepository(database: database).languageSpace(id: languageSpaceID)
            let input = PracticeBacktranslationReviewInput(
                nativeSentence: submission.nativeSentence,
                userAttempt: submission.userAttempt,
                referenceSentence: submission.referenceSentence,
                targetLanguageCode: space?.targetLanguageCode ?? "",
                proficiencyLevelCode: space?.level.rawValue ?? "",
                explanationLanguageMode: .bilingualBridge
            )
            let secret: String?
            do {
                secret = try await resolveLearningMaterialSecret(
                    endpoint: endpoint,
                    profile: profile,
                    credentialStore: credentialStore
                )
            } catch {
                throw PracticeBacktranslationReviewFailure(category: .providerNotConfigured)
            }
            let request = PracticeBacktranslationReviewServiceRequest(
                endpoint: endpoint,
                plaintextSecret: secret,
                input: input
            )
            let service = PracticeBacktranslationReviewService(httpClient: URLSessionAIProviderHTTPClient())
            let logID = UUID().uuidString
            do {
                let result = try await service.review(request)
                await aiRequestLogRecorder.record(request.makeLogEntry(id: logID, outcome: .success, createdAt: Date()))
                return result
            } catch let error as PracticeBacktranslationReviewServiceError {
                let outcome: AIRequestLogOutcome = error.category == .cancelled
                    ? .cancelled
                    : .failed(AIRequestLogFailureBucket(error.category))
                await aiRequestLogRecorder.record(request.makeLogEntry(id: logID, outcome: outcome, createdAt: Date()))
                throw PracticeBacktranslationReviewFailure(category: error.category)
            } catch is CancellationError {
                await aiRequestLogRecorder.record(request.makeLogEntry(id: logID, outcome: .cancelled, createdAt: Date()))
                throw PracticeBacktranslationReviewFailure(category: .cancelled)
            }
        }
    }

    private static func makeSubmitDictationAttempt(
        repository: GRDBPracticeRepository
    ) -> @Sendable (PracticeSession, PracticeDictationAttemptSubmission) async throws -> Void {
        { session, submission in
            _ = try await repository.recordTextAttempt(
                draft: PracticeTextAttemptDraft(
                    sessionID: session.id,
                    languageSpaceID: session.languageSpaceID,
                    exerciseType: .dictation,
                    attemptText: submission.attemptText,
                    referenceTextSnapshot: submission.referenceText,
                    diffDifferenceCount: submission.differenceCount,
                    diffSummaryJSON: encodeDiffSummary(submission.summary),
                    listenCount: submission.listenCount
                )
            )
        }
    }

    private static func makeSubmitBacktranslationAttempt(
        repository: GRDBPracticeRepository
    ) -> @Sendable (PracticeSession, PracticeBacktranslationAttemptSubmission) async throws -> Void {
        { session, submission in
            // Backtranslation is not judged: the repository forces the diff
            // columns and listen count to neutral values regardless of what is
            // passed here (see GRDBPracticeRepository.recordTextAttempt).
            _ = try await repository.recordTextAttempt(
                draft: PracticeTextAttemptDraft(
                    sessionID: session.id,
                    languageSpaceID: session.languageSpaceID,
                    exerciseType: .backtranslation,
                    attemptText: submission.attemptText,
                    referenceTextSnapshot: submission.referenceText,
                    diffDifferenceCount: nil,
                    diffSummaryJSON: nil,
                    listenCount: 0
                )
            )
        }
    }

    private static func encodeDiffSummary(_ summary: PracticeDictationDiffSummary) -> String? {
        guard let data = try? JSONEncoder().encode(summary) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func makeStopRecordingAction(
        recordingService: PracticeRecordingService,
        mediaStore: LocalMediaArtifactStore,
        repository: GRDBPracticeRepository,
        diagnosticLogger: any DiagnosticLogging
    ) -> @Sendable (PracticeSession, String) async throws -> PracticeSession {
        { session, recordingID in
            let result = try await stopRecordingService(
                recordingService,
                recordingID: recordingID,
                diagnosticLogger: diagnosticLogger
            )
            let input = practiceRecordingCommitInput(
                session: session,
                recordingID: recordingID,
                result: result
            )
            try await commitPracticeRecordingArtifact(
                input,
                mediaStore: mediaStore,
                diagnosticLogger: diagnosticLogger
            )
            return try await reloadReadyPracticeSession(
                sessionID: session.id,
                recordingID: recordingID,
                repository: repository,
                diagnosticLogger: diagnosticLogger
            )
        }
    }

    private static func stopRecordingService(
        _ recordingService: PracticeRecordingService,
        recordingID: String,
        diagnosticLogger: any DiagnosticLogging
    ) async throws -> PracticeRecordingResult {
        do {
            return try await recordingService.stop(recordingID: recordingID)
        } catch {
            await recordPracticeRecordingFailure(
                logger: diagnosticLogger,
                phase: "recording_stop",
                error: error
            )
            throw error
        }
    }

    private static func commitPracticeRecordingArtifact(
        _ input: PracticeRecordingArtifactCommitInput,
        mediaStore: LocalMediaArtifactStore,
        diagnosticLogger: any DiagnosticLogging
    ) async throws {
        do {
            _ = try await mediaStore.commitPracticeRecordingArtifact(input)
        } catch {
            await recordPracticeRecordingFailure(
                logger: diagnosticLogger,
                phase: "artifact_commit",
                error: error
            )
            throw error
        }
    }

    private static func reloadReadyPracticeSession(
        sessionID: String,
        recordingID: String,
        repository: GRDBPracticeRepository,
        diagnosticLogger: any DiagnosticLogging
    ) async throws -> PracticeSession {
        let refreshed: PracticeSession?
        do {
            refreshed = try await repository.session(id: sessionID)
        } catch {
            await recordPracticeRecordingFailure(
                logger: diagnosticLogger,
                phase: "session_reload",
                error: error
            )
            throw error
        }
        guard let refreshed, refreshed.latestReadyRecordingID == recordingID else {
            await recordPracticeRecordingFailure(
                logger: diagnosticLogger,
                phase: "session_reload",
                error: PracticeActionFailure.recordingUnavailable
            )
            throw PracticeActionFailure.recordingUnavailable
        }
        return refreshed
    }

    private static func practiceRecordingCommitInput(
        session: PracticeSession,
        recordingID: String,
        result: PracticeRecordingResult
    ) -> PracticeRecordingArtifactCommitInput {
        let attemptNumber = session.readyRecordings.count + 1
        let createdAt = Date()
        return PracticeRecordingArtifactCommitInput(
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
    }

    private static func createdAtBucket(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func recordPracticeRecordingFailure(
        logger: any DiagnosticLogging,
        phase: String,
        error: Error
    ) async {
        await logger.record(
            DiagnosticEvent(
                id: UUID().uuidString,
                name: .practiceRecordingFailed,
                domain: .practiceRecording,
                level: .error,
                outcome: .failed,
                attributes: [
                    .operationID(DiagnosticOperationID(rawValue: UUID().uuidString)),
                    .failurePhase(phase),
                    .errorCategory(practiceRecordingErrorCategory(error)),
                    .platform(platformName()),
                ],
                createdAt: Date()
            )
        )
    }

    private static func practiceRecordingErrorCategory(_ error: Error) -> String {
        if let failure = error as? PracticeRecordingFailure {
            switch failure {
            case .permissionDenied:
                return "permission_denied"
            case .permissionRestricted:
                return "permission_restricted"
            case .deviceUnavailable:
                return "device_unavailable"
            case .alreadyRecording:
                return "already_recording"
            case .noActiveRecording:
                return "no_active_recording"
            case .recordingIDMismatch:
                return "recording_id_mismatch"
            case .startFailed:
                return "start_failed"
            case .stopFailed:
                return "stop_failed"
            case .fileTooLarge:
                return "file_too_large"
            case .durationTooLong:
                return "duration_too_long"
            }
        }
        if let failure = error as? PracticeActionFailure {
            switch failure {
            case .recordingUnavailable:
                return "recording_unavailable"
            case .missingReadyRecording:
                return "missing_ready_recording"
            case .missingSession:
                return "missing_session"
            case .audioBusy:
                return "audio_busy"
            case .playbackUnavailable:
                return "playback_unavailable"
            case .disabled:
                return "disabled"
            case .inputTooLong:
                return "input_too_long"
            case .attemptSaveFailed:
                return "attempt_save_failed"
            }
        }
        return "unexpected_error"
    }

    private static func platformName() -> String {
        #if os(iOS)
            return "iOS"
        #elseif os(macOS)
            return "macOS"
        #else
            return "unknown"
        #endif
    }
}
