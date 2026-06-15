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
    var navigationContext: PracticeSessionNavigationContext?

    init(
        entry: LearningEntry,
        rendering: LearningRendering,
        sentence: RenderingSentence,
        sentenceIndex: Int,
        targetLanguageCode: String,
        capturedAt: Date
    ) {
        let targetTextHash = StableHashing.sha256Hex(sentence.targetText)
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
        navigationContext = PracticeSessionNavigationContext(
            entryID: entry.id,
            learningMaterialID: rendering.id,
            targetLanguageCode: targetLanguageCode,
            sourceEntryBodyHash: rendering.sourceEntryBodyHash,
            items: rendering.sentences.enumerated().map { offset, sentence in
                PracticeSessionNavigationItem(
                    sentenceID: sentence.id,
                    sentenceIndex: offset,
                    targetTextSnapshot: sentence.targetText,
                    translationSnapshot: sentence.translation.isEmpty ? nil : sentence.translation,
                    noteSnapshot: sentence.note.isEmpty ? nil : sentence.note
                )
            }
        )
    }

    init(snapshot: PracticeSentenceSnapshot) {
        entryID = snapshot.entryID
        learningMaterialID = snapshot.learningMaterialID
        sentenceID = snapshot.sentenceID ?? "\(snapshot.entryID)-sentence-\(snapshot.sentenceIndex)"
        sentenceIndex = snapshot.sentenceIndex
        targetTextHash = snapshot.targetTextHash
        targetLanguageCode = snapshot.targetLanguageCode
        exerciseType = snapshot.exerciseType
        self.snapshot = snapshot
        navigationContext = nil
    }

    var practiceRouteIdentity: String {
        [
            entryID,
            learningMaterialID,
            sentenceID,
            String(sentenceIndex),
            targetTextHash,
            targetLanguageCode,
        ].joined(separator: "::")
    }

    var hasPreviousSentence: Bool {
        guard let navigationContext,
              let index = navigationContext.index(for: sentenceID)
        else {
            return false
        }
        return index > 0
    }

    var hasNextSentence: Bool {
        guard let navigationContext,
              let index = navigationContext.index(for: sentenceID)
        else {
            return false
        }
        return index < navigationContext.items.count - 1
    }

    var navigationProjection: PracticeSessionNavigationProjection {
        guard let navigationContext,
              let index = navigationContext.index(for: sentenceID)
        else {
            // Degraded projection without navigation context: keep position/total readable
            // by treating the current sentence as the last known one.
            return PracticeSessionNavigationProjection(
                currentPosition: sentenceIndex + 1,
                totalCount: max(1, sentenceIndex + 1),
                positionKey: "practice.navigation.position",
                boundaryKey: nil
            )
        }

        return PracticeSessionNavigationProjection(
            currentPosition: index + 1,
            totalCount: navigationContext.items.count,
            positionKey: "practice.navigation.position",
            boundaryKey: nil
        )
    }

    func neighboringSeed(
        direction: PracticeSentenceNavigationDirection,
        capturedAt: Date
    ) -> PracticeSessionRouteSeed? {
        guard let navigationContext,
              let index = navigationContext.index(for: sentenceID)
        else {
            return nil
        }
        let nextIndex = index + direction.offset
        guard navigationContext.items.indices.contains(nextIndex) else {
            return nil
        }

        let item = navigationContext.items[nextIndex]
        let nextTargetTextHash = StableHashing.sha256Hex(item.targetTextSnapshot)
        let nextSnapshot = PracticeSentenceSnapshot(
            entryID: navigationContext.entryID,
            learningMaterialID: navigationContext.learningMaterialID,
            sentenceID: item.sentenceID,
            sentenceIndex: item.sentenceIndex,
            targetTextSnapshot: item.targetTextSnapshot,
            targetTextHash: nextTargetTextHash,
            targetLanguageCode: navigationContext.targetLanguageCode,
            translationSnapshot: item.translationSnapshot,
            noteSnapshot: item.noteSnapshot,
            sourceEntryBodyHash: navigationContext.sourceEntryBodyHash,
            materialAnalysisSourceHash: nil,
            exerciseType: .shadowing,
            capturedAt: capturedAt
        )

        var seed = PracticeSessionRouteSeed(snapshot: nextSnapshot)
        seed.navigationContext = navigationContext
        seed.targetTextHash = nextTargetTextHash
        return seed
    }
}

enum PracticeSentenceNavigationDirection: Hashable {
    case previous
    case next

    var offset: Int {
        switch self {
        case .previous:
            -1
        case .next:
            1
        }
    }
}

struct PracticeSessionNavigationContext: Hashable {
    var entryID: String
    var learningMaterialID: String
    var targetLanguageCode: String
    var sourceEntryBodyHash: String
    var items: [PracticeSessionNavigationItem]

    func index(for sentenceID: String) -> Int? {
        items.firstIndex { $0.sentenceID == sentenceID }
    }
}

struct PracticeSessionNavigationItem: Hashable {
    var sentenceID: String
    var sentenceIndex: Int
    var targetTextSnapshot: String
    var translationSnapshot: String?
    var noteSnapshot: String?
}

struct PracticeSessionNavigationProjection: Equatable {
    var currentPosition: Int
    var totalCount: Int
    var positionKey: String
    var boundaryKey: String?
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
