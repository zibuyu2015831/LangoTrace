import LangoTraceCore
import LangoTraceData

struct PracticeModeAvailability: Equatable {
    var availableModes: [PracticeExerciseType]

    init(availableModes: [PracticeExerciseType]) {
        var seen: Set<PracticeExerciseType> = []
        self.availableModes = availableModes.filter { seen.insert($0).inserted }
    }

    static let shadowingOnly = PracticeModeAvailability(availableModes: [.shadowing])
}

struct PracticeSentenceListPresentation: Equatable {
    var selectedMode: PracticeExerciseType
    var availableModes: [PracticeExerciseType]
    var rows: [PracticeSentenceListRowPresentation]
    var continueTarget: PracticeSentenceListContinueTarget?

    init(
        sentences: [RenderingSentence],
        selectedMode: PracticeExerciseType,
        practicedSentenceIDs: Set<String>,
        availability: PracticeModeAvailability
    ) {
        self.selectedMode = selectedMode
        availableModes = availability.availableModes
        rows = sentences.enumerated().map { index, sentence in
            PracticeSentenceListRowPresentation(
                sentenceID: sentence.id,
                sentenceIndex: index,
                position: index + 1,
                isPracticed: practicedSentenceIDs.contains(sentence.id)
            )
        }
        continueTarget = rows.first(where: { !$0.isPracticed }).map { row in
            PracticeSentenceListContinueTarget(
                sentenceID: row.sentenceID,
                sentenceIndex: row.sentenceIndex,
                position: row.position,
                titleKey: "practice.sentenceList.continueFrom"
            )
        }
    }

    var shouldShowModeSelector: Bool {
        availableModes.count > 1
    }
}

struct PracticeSentenceListRowPresentation: Equatable {
    var sentenceID: String
    var sentenceIndex: Int
    var position: Int
    var isPracticed: Bool

    var statusTitleKey: String? {
        isPracticed ? "practice.sentenceList.practiced" : nil
    }
}

struct PracticeSentenceListContinueTarget: Equatable {
    var sentenceID: String
    var sentenceIndex: Int
    var position: Int
    var titleKey: String
}
