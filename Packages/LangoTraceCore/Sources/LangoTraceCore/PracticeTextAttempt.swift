import Foundation

/// A persisted text answer for a text-based practice exercise (dictation 听写
/// or, later, backtranslation 回译).
///
/// Attempts are the user's practice evidence — local primary data, not
/// rebuildable cache. They are never synced, exported by default, written to
/// diagnostics, or sent to any provider (plan §5 / §7 constraint 3; analogous
/// to practice recordings).
///
/// `diffDifferenceCount` / `diffSummaryJSON` apply only to dictation; for
/// backtranslation they stay `nil` (回译参考不判对错). `listenCount` is a
/// low-weight informational counter, never a score or penalty.
public struct PracticeTextAttempt: Hashable, Sendable {
    public var id: String
    public var sessionID: String
    public var languageSpaceID: String
    public var exerciseType: PracticeExerciseType
    public var attemptNumber: Int
    public var attemptText: String
    public var referenceTextSnapshot: String
    public var diffDifferenceCount: Int?
    public var diffSummaryJSON: String?
    public var listenCount: Int
    public var createdAt: Date
    public var softDeletedAt: Date?

    public init(
        id: String,
        sessionID: String,
        languageSpaceID: String,
        exerciseType: PracticeExerciseType,
        attemptNumber: Int,
        attemptText: String,
        referenceTextSnapshot: String,
        diffDifferenceCount: Int?,
        diffSummaryJSON: String?,
        listenCount: Int,
        createdAt: Date,
        softDeletedAt: Date? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.languageSpaceID = languageSpaceID
        self.exerciseType = exerciseType
        self.attemptNumber = attemptNumber
        self.attemptText = attemptText
        self.referenceTextSnapshot = referenceTextSnapshot
        self.diffDifferenceCount = diffDifferenceCount
        self.diffSummaryJSON = diffSummaryJSON
        self.listenCount = listenCount
        self.createdAt = createdAt
        self.softDeletedAt = softDeletedAt
    }
}

/// Input for recording a new text attempt; the repository assigns
/// `attemptNumber`, `id`, and `createdAt`.
public struct PracticeTextAttemptDraft: Hashable, Sendable {
    public var sessionID: String
    public var languageSpaceID: String
    public var exerciseType: PracticeExerciseType
    public var attemptText: String
    public var referenceTextSnapshot: String
    public var diffDifferenceCount: Int?
    public var diffSummaryJSON: String?
    public var listenCount: Int

    public init(
        sessionID: String,
        languageSpaceID: String,
        exerciseType: PracticeExerciseType,
        attemptText: String,
        referenceTextSnapshot: String,
        diffDifferenceCount: Int?,
        diffSummaryJSON: String?,
        listenCount: Int
    ) {
        self.sessionID = sessionID
        self.languageSpaceID = languageSpaceID
        self.exerciseType = exerciseType
        self.attemptText = attemptText
        self.referenceTextSnapshot = referenceTextSnapshot
        self.diffDifferenceCount = diffDifferenceCount
        self.diffSummaryJSON = diffSummaryJSON
        self.listenCount = listenCount
    }
}
