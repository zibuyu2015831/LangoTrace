import CryptoKit
import Foundation
import LangoTraceCore
import LangoTraceData

struct PracticeSessionRouteSeed: Hashable {
    var entryID: String
    var learningMaterialID: String
    var sentenceID: String
    var sentenceIndex: Int
    var targetTextHash: String
    var targetLanguageCode: String
    var exerciseType: PracticeExerciseType
    var snapshot: PracticeSentenceSnapshot

    init(
        entry: LearningEntry,
        rendering: LearningRendering,
        sentence: RenderingSentence,
        sentenceIndex: Int,
        targetLanguageCode: String,
        capturedAt: Date
    ) {
        let targetTextHash = Self.sha256Hex(for: sentence.targetText)
        entryID = entry.id
        learningMaterialID = rendering.id
        sentenceID = sentence.id
        self.sentenceIndex = sentenceIndex
        self.targetTextHash = targetTextHash
        self.targetLanguageCode = targetLanguageCode
        exerciseType = .shadowing
        snapshot = PracticeSentenceSnapshot(
            entryID: entry.id,
            learningMaterialID: rendering.id,
            sentenceID: sentence.id,
            sentenceIndex: sentenceIndex,
            targetTextSnapshot: sentence.targetText,
            targetTextHash: targetTextHash,
            targetLanguageCode: targetLanguageCode,
            translationSnapshot: sentence.translation.isEmpty ? nil : sentence.translation,
            noteSnapshot: sentence.note.isEmpty ? nil : sentence.note,
            sourceEntryBodyHash: rendering.sourceEntryBodyHash,
            materialAnalysisSourceHash: nil,
            exerciseType: .shadowing,
            capturedAt: capturedAt
        )
    }

    private static func sha256Hex(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct PracticeEntryCardProjection: Equatable {
    var title: String
    var targetPreview: String
    var sentenceCount: Int
    var completedCount: Int
    var problemCount: Int
    var statusText: String

    let titleLineLimit = 1
    let previewLineLimit = 2
    let metadataLineLimit = 1
    let estimatedRegularHeightRange = 112 ... 132
}
