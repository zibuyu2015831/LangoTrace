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

/// A dictation answer ready to persist. The Core diff has already been computed
/// against the reference; this carries only the persistable fields (no network
/// or AI path is involved — the comparison is fully local).
public struct PracticeDictationAttemptSubmission: Sendable {
    public var attemptText: String
    public var referenceText: String
    public var differenceCount: Int
    public var summary: PracticeDictationDiffSummary
    public var listenCount: Int

    public init(
        attemptText: String,
        referenceText: String,
        differenceCount: Int,
        summary: PracticeDictationDiffSummary,
        listenCount: Int
    ) {
        self.attemptText = attemptText
        self.referenceText = referenceText
        self.differenceCount = differenceCount
        self.summary = summary
        self.listenCount = listenCount
    }
}

/// A backtranslation answer ready to persist. Backtranslation never judges
/// right/wrong, so the payload carries only the user's answer and the reference
/// text snapshot — no diff, no summary, no listen count (never judged right or
/// wrong). The
/// reference text comes from the sentence snapshot, decoupled from the lazily
/// fetched rich analysis, so persistence succeeds even if the analysis seam
/// yields nothing.
public struct PracticeBacktranslationAttemptSubmission: Sendable {
    public var attemptText: String
    public var referenceText: String

    public init(attemptText: String, referenceText: String) {
        self.attemptText = attemptText
        self.referenceText = referenceText
    }
}

/// The content the user explicitly chooses to send for an AI critique (系列 E5
/// Slice 2). Only the three short texts — the native-meaning prompt, the user's
/// own answer, and the reference sentence. App Shell resolves the language /
/// proficiency codes from the language space; nothing else is sent.
public struct PracticeBacktranslationReviewSubmission: Sendable {
    public var nativeSentence: String
    public var userAttempt: String
    public var referenceSentence: String

    public init(nativeSentence: String, userAttempt: String, referenceSentence: String) {
        self.nativeSentence = nativeSentence
        self.userAttempt = userAttempt
        self.referenceSentence = referenceSentence
    }
}

public struct PracticeActions: Sendable {
    public var availableExerciseTypes: [PracticeExerciseType]
    public var createOrRestoreSession: @Sendable (
        String,
        PracticeSentenceSnapshot
    ) async throws -> PracticeSession
    public var completedSentenceIDs: @Sendable (
        String,
        PracticeExerciseType
    ) async throws -> Set<String>
    public var startRecording: @Sendable (PracticeSession) async throws -> PracticeRecordingStart
    public var stopRecording: @Sendable (PracticeSession, String) async throws -> PracticeSession
    public var complete: @Sendable (PracticeSession, String) async throws -> PracticeSession
    public var playRecording: @Sendable (PracticeSession, String) async throws -> Void
    public var submitDictationAttempt: @Sendable (
        PracticeSession,
        PracticeDictationAttemptSubmission
    ) async throws -> Void
    public var submitBacktranslationAttempt: @Sendable (
        PracticeSession,
        PracticeBacktranslationAttemptSubmission
    ) async throws -> Void
    /// Lazily reads the rich per-sentence analysis (materialID, sentenceIndex)
    /// for the backtranslation reference card. Returns nil when no analysis
    /// exists; the reference card then degrades to the snapshot fields.
    public var fetchSentenceAnalysis: @Sendable (
        String,
        Int
    ) async throws -> LearningSentenceAnalysis?
    /// Explicitly-triggered optional AI critique (系列 E5 Slice 2). Only invoked
    /// from the "请 AI 点评" button — never automatically. App Shell resolves the
    /// endpoint + language/proficiency, sends the three short texts, writes a
    /// non-sensitive request log, and maps failures to
    /// `PracticeBacktranslationReviewFailure`.
    public var reviewBacktranslation: @Sendable (
        String,
        PracticeBacktranslationReviewSubmission
    ) async throws -> PracticeBacktranslationReviewResult

    public init(
        availableExerciseTypes: [PracticeExerciseType] = [.shadowing],
        createOrRestoreSession: @escaping @Sendable (
            String,
            PracticeSentenceSnapshot
        ) async throws -> PracticeSession,
        completedSentenceIDs: @escaping @Sendable (
            String,
            PracticeExerciseType
        ) async throws -> Set<String> = { _, _ in [] },
        startRecording: @escaping @Sendable (PracticeSession) async throws -> PracticeRecordingStart,
        stopRecording: @escaping @Sendable (PracticeSession, String) async throws -> PracticeSession,
        complete: @escaping @Sendable (PracticeSession, String) async throws -> PracticeSession,
        playRecording: @escaping @Sendable (PracticeSession, String) async throws -> Void,
        submitDictationAttempt: @escaping @Sendable (
            PracticeSession,
            PracticeDictationAttemptSubmission
        ) async throws -> Void = { _, _ in throw PracticeActionFailure.disabled },
        submitBacktranslationAttempt: @escaping @Sendable (
            PracticeSession,
            PracticeBacktranslationAttemptSubmission
        ) async throws -> Void = { _, _ in throw PracticeActionFailure.disabled },
        fetchSentenceAnalysis: @escaping @Sendable (
            String,
            Int
        ) async throws -> LearningSentenceAnalysis? = { _, _ in nil },
        reviewBacktranslation: @escaping @Sendable (
            String,
            PracticeBacktranslationReviewSubmission
        ) async throws -> PracticeBacktranslationReviewResult = { _, _ in
            throw PracticeBacktranslationReviewFailure(category: .providerNotConfigured)
        }
    ) {
        self.availableExerciseTypes = availableExerciseTypes
        self.createOrRestoreSession = createOrRestoreSession
        self.completedSentenceIDs = completedSentenceIDs
        self.startRecording = startRecording
        self.stopRecording = stopRecording
        self.complete = complete
        self.playRecording = playRecording
        self.submitDictationAttempt = submitDictationAttempt
        self.submitBacktranslationAttempt = submitBacktranslationAttempt
        self.fetchSentenceAnalysis = fetchSentenceAnalysis
        self.reviewBacktranslation = reviewBacktranslation
    }

    public static let disabled = PracticeActions(
        createOrRestoreSession: { languageSpaceID, snapshot in
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
        },
        submitDictationAttempt: { _, _ in
            throw PracticeActionFailure.disabled
        }
    )
}

public enum PracticeActionFailure: Error, Equatable, Sendable {
    case disabled
    case missingSession
    case missingReadyRecording
    case audioBusy
    case recordingUnavailable
    case playbackUnavailable
    case inputTooLong
    case attemptSaveFailed

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
        case .recordingUnavailable:
            "practice.failure.recordingUnavailable"
        case .playbackUnavailable:
            "practice.failure.playbackUnavailable"
        case .inputTooLong:
            "practice.failure.inputTooLong"
        case .attemptSaveFailed:
            "practice.failure.attemptSaveFailed"
        }
    }
}
