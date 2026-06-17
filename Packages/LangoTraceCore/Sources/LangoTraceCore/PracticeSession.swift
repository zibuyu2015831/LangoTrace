import Foundation

public enum PracticeExerciseType: String, CaseIterable, Hashable, Sendable {
    case shadowing
    case dictation
    case backtranslation
}

public enum PracticeSessionPhase: String, CaseIterable, Hashable, Sendable {
    case shadowing
    case recording
    case completion
}

public enum PracticeSessionStatus: String, CaseIterable, Hashable, Sendable {
    case inProgress
    case completed
}

public enum PracticeSessionAudioActivity: Hashable, Sendable {
    case idle
    case demoPlayback
    case recording(recordingID: String)
    case recordingPlayback(recordingID: String)
}

public struct PracticeSentenceSnapshot: Hashable, Sendable {
    public var entryID: String
    public var learningMaterialID: String
    public var sentenceID: String?
    public var sentenceIndex: Int
    public var targetTextSnapshot: String
    public var targetTextHash: String
    public var targetLanguageCode: String
    public var translationSnapshot: String?
    public var noteSnapshot: String?
    public var sourceEntryBodyHash: String?
    public var materialAnalysisSourceHash: String?
    public var exerciseType: PracticeExerciseType
    public var capturedAt: Date

    public init(
        entryID: String,
        learningMaterialID: String,
        sentenceID: String?,
        sentenceIndex: Int,
        targetTextSnapshot: String,
        targetTextHash: String,
        targetLanguageCode: String,
        translationSnapshot: String?,
        noteSnapshot: String?,
        sourceEntryBodyHash: String?,
        materialAnalysisSourceHash: String?,
        exerciseType: PracticeExerciseType,
        capturedAt: Date
    ) {
        self.entryID = entryID
        self.learningMaterialID = learningMaterialID
        self.sentenceID = sentenceID
        self.sentenceIndex = sentenceIndex
        self.targetTextSnapshot = targetTextSnapshot
        self.targetTextHash = targetTextHash
        self.targetLanguageCode = targetLanguageCode
        self.translationSnapshot = translationSnapshot
        self.noteSnapshot = noteSnapshot
        self.sourceEntryBodyHash = sourceEntryBodyHash
        self.materialAnalysisSourceHash = materialAnalysisSourceHash
        self.exerciseType = exerciseType
        self.capturedAt = capturedAt
    }
}

public struct PracticeRecordingAttempt: Hashable, Sendable {
    public var id: String
    public var durationSeconds: Double

    public init(id: String, durationSeconds: Double) {
        self.id = id
        self.durationSeconds = durationSeconds
    }
}

public struct PracticeSession: Hashable, Sendable {
    public var id: String
    public var languageSpaceID: String
    public var snapshot: PracticeSentenceSnapshot
    public var exerciseType: PracticeExerciseType
    public var currentStep: PracticeSessionPhase
    public var status: PracticeSessionStatus
    public var audioActivity: PracticeSessionAudioActivity
    public var readyRecordings: [PracticeRecordingAttempt]
    public var completedRecordingID: String?
    public var problemMarked: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?

    public init(
        id: String,
        languageSpaceID: String,
        snapshot: PracticeSentenceSnapshot,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.languageSpaceID = languageSpaceID
        self.snapshot = snapshot
        exerciseType = snapshot.exerciseType
        currentStep = .shadowing
        status = .inProgress
        audioActivity = .idle
        readyRecordings = []
        completedRecordingID = nil
        problemMarked = false
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        completedAt = nil
    }

    public var latestReadyRecordingID: String? {
        readyRecordings.last?.id
    }
}
