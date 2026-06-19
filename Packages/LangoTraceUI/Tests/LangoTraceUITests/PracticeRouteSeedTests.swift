import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Practice route seed")
struct PracticeRouteSeedTests {
    @Test("Route seed captures sentence identity and immutable sentence snapshot")
    func routeSeedCapturesSentenceIdentityAndSnapshot() {
        let entry = makeEntry()
        let rendering = makeRendering(sentenceCount: 1)

        let seed = PracticeSessionRouteSeed(
            entry: entry,
            rendering: rendering,
            sentence: rendering.sentences[0],
            sentenceIndex: 0,
            targetLanguageCode: "en",
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        #expect(seed.entryID == "entry-1")
        #expect(seed.learningMaterialID == "material-1")
        #expect(seed.sentenceID == "sentence-1")
        #expect(seed.sentenceIndex == 0)
        #expect(seed.exerciseType == .shadowing)
        #expect(seed.snapshot.targetTextSnapshot == "I booked the train this morning.")
        #expect(seed.snapshot.translationSnapshot == "我今天早上订了火车票。")
        #expect(seed.snapshot.noteSnapshot == "booked 表示已经完成预订。")
        #expect(seed.snapshot.sourceEntryBodyHash == "source-hash")
        #expect(seed.snapshot.targetTextHash.count == 64)
    }

    @Test("Route seed carries selected exercise type into snapshot neighbors and identity")
    func routeSeedCarriesSelectedExerciseTypeIntoSnapshotNeighborsAndIdentity() throws {
        let entry = makeEntry()
        let rendering = makeRendering(sentenceCount: 2)

        let seed = PracticeSessionRouteSeed(
            entry: entry,
            rendering: rendering,
            sentence: rendering.sentences[0],
            sentenceIndex: 0,
            targetLanguageCode: "en",
            exerciseType: .dictation,
            capturedAt: Date(timeIntervalSince1970: 100)
        )
        let next = try #require(seed.neighboringSeed(direction: .next, capturedAt: Date(timeIntervalSince1970: 200)))

        #expect(seed.exerciseType == .dictation)
        #expect(seed.snapshot.exerciseType == .dictation)
        #expect(next.exerciseType == .dictation)
        #expect(next.snapshot.exerciseType == .dictation)
        #expect(seed.practiceRouteIdentity.contains("dictation"))
        #expect(next.practiceRouteIdentity.contains("dictation"))
    }

    @Test("Route seed builds neighboring seeds within the same rendering")
    func routeSeedBuildsNeighboringSeeds() {
        let entry = makeEntry()
        let rendering = makeRendering(sentenceCount: 3)
        let seed = PracticeSessionRouteSeed(
            entry: entry,
            rendering: rendering,
            sentence: rendering.sentences[1],
            sentenceIndex: 1,
            targetLanguageCode: "en",
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        let previous = seed.neighboringSeed(direction: .previous, capturedAt: Date(timeIntervalSince1970: 200))
        let next = seed.neighboringSeed(direction: .next, capturedAt: Date(timeIntervalSince1970: 300))

        #expect(seed.hasPreviousSentence)
        #expect(seed.hasNextSentence)
        #expect(previous?.sentenceID == "sentence-1")
        #expect(previous?.sentenceIndex == 0)
        #expect(previous?.entryID == "entry-1")
        #expect(previous?.learningMaterialID == "material-1")
        #expect(previous?.targetLanguageCode == "en")
        #expect(previous?.snapshot.sourceEntryBodyHash == "source-hash")
        #expect(next?.sentenceID == "sentence-3")
        #expect(next?.sentenceIndex == 2)
        #expect(next?.snapshot.targetTextSnapshot == "Target sentence 3.")
        #expect(next?.practiceRouteIdentity != seed.practiceRouteIdentity)
    }

    @Test("Route seed exposes centered sentence position without boundary copy")
    func routeSeedExposesCenteredPositionWithoutBoundaryCopy() {
        let entry = makeEntry()
        let rendering = makeRendering(sentenceCount: 3)
        let first = PracticeSessionRouteSeed(
            entry: entry,
            rendering: rendering,
            sentence: rendering.sentences[0],
            sentenceIndex: 0,
            targetLanguageCode: "en",
            capturedAt: Date(timeIntervalSince1970: 100)
        )
        let last = PracticeSessionRouteSeed(
            entry: entry,
            rendering: rendering,
            sentence: rendering.sentences[2],
            sentenceIndex: 2,
            targetLanguageCode: "en",
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        #expect(!first.hasPreviousSentence)
        #expect(first.hasNextSentence)
        #expect(first.navigationProjection.positionKey == "practice.navigation.position")
        #expect(first.navigationProjection.boundaryKey == nil)
        #expect(first.neighboringSeed(direction: .previous, capturedAt: Date()) == nil)
        #expect(last.hasPreviousSentence)
        #expect(!last.hasNextSentence)
        #expect(last.navigationProjection.currentPosition == 3)
        #expect(last.navigationProjection.totalCount == 3)
        #expect(last.navigationProjection.boundaryKey == nil)
        #expect(last.neighboringSeed(direction: .next, capturedAt: Date()) == nil)
    }

    @Test("Practice sentence navigation presentation places position between previous and next controls")
    func practiceSentenceNavigationPresentationPlacesPositionBetweenControls() {
        let entry = makeEntry()
        let rendering = makeRendering(sentenceCount: 3)
        let middle = PracticeSessionRouteSeed(
            entry: entry,
            rendering: rendering,
            sentence: rendering.sentences[1],
            sentenceIndex: 1,
            targetLanguageCode: "en",
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        let presentation = PracticeSentenceNavigationBarPresentation(
            routeSeed: middle,
            isNavigationDisabled: false
        )

        #expect(presentation.previousTitleKey == "practice.navigation.previous")
        #expect(presentation.positionKey == "practice.navigation.position")
        #expect(presentation.currentPosition == 2)
        #expect(presentation.totalCount == 3)
        #expect(presentation.nextTitleKey == "practice.navigation.next")
        #expect(!presentation.isPreviousDisabled)
        #expect(!presentation.isNextDisabled)
    }

    @Test("Route seed without navigation context degrades safely")
    func routeSeedWithoutNavigationContextDegradesSafely() {
        let seed = PracticeSessionRouteSeed(snapshot: snapshot())

        #expect(!seed.hasPreviousSentence)
        #expect(!seed.hasNextSentence)
        #expect(seed.navigationProjection.currentPosition == 1)
        #expect(seed.navigationProjection.totalCount == 1)
        #expect(seed.navigationProjection.boundaryKey == nil)
        #expect(seed.neighboringSeed(direction: .next, capturedAt: Date()) == nil)
    }

    @Test("Route seed without navigation context keeps degraded position within total count")
    func routeSeedWithoutNavigationContextKeepsDegradedPositionWithinTotalCount() {
        let seed = PracticeSessionRouteSeed(snapshot: snapshot(sentenceIndex: 2))

        let projection = seed.navigationProjection

        #expect(projection.currentPosition == 3)
        #expect(projection.totalCount == 3)
        #expect(projection.currentPosition <= projection.totalCount)
    }

    @Test("Practice entry card projection has stable line limits")
    func practiceEntryCardProjectionHasStableLineLimits() {
        let projection = PracticeEntryCardProjection(
            title: "A very long entry title that should not expand a practice card forever",
            targetPreview: String(repeating: "Long target sentence ", count: 20),
            sentenceCount: 8,
            completedCount: 3,
            problemCount: 1,
            statusText: "In progress"
        )

        #expect(projection.titleLineLimit == 1)
        #expect(projection.previewLineLimit == 2)
        #expect(projection.metadataLineLimit == 1)
        #expect(projection.estimatedRegularHeightRange == 112 ... 132)
    }

    @Test("Practice entry card accessibility label combines title status and counts")
    func practiceEntryCardAccessibilityLabelCombinesTitleStatusAndCounts() {
        let card = PracticeEntryCard(
            projection: PracticeEntryCardProjection(
                title: "Morning commute",
                targetPreview: "Preview",
                sentenceCount: 8,
                completedCount: 3,
                problemCount: 2,
                statusText: "In progress"
            ),
            action: {}
        )

        let label = card.accessibilityLabelText

        #expect(label.contains("Morning commute"))
        #expect(label.contains("In progress"))
        #expect(label.contains("3"))
        #expect(label.contains("8"))
        #expect(label.contains("2"))
    }

    @Test("Practice entry card omits the problem fragment when nothing needs review")
    func practiceEntryCardOmitsProblemFragmentWhenNothingNeedsReview() {
        let card = PracticeEntryCard(
            projection: PracticeEntryCardProjection(
                title: "Morning commute",
                targetPreview: "Preview",
                sentenceCount: 8,
                completedCount: 3,
                problemCount: 0,
                statusText: "In progress"
            ),
            action: {}
        )

        #expect(!card.accessibilityLabelText.contains(localizedString("practice.entryCard.problems", "0")))
    }

    @Test("Practice prompt card presentation hides translation until user asks")
    func practicePromptCardPresentationHidesTranslationUntilUserAsks() {
        let snapshot = promptSnapshot(
            translation: "鸟儿轻声鸣叫，标志着另一个宁静的一天结束，也提醒用户这句话描述的是安静收束的生活场景。",
            note: "chirp 是动词，表示鸟儿发出短促轻快的叫声。"
        )

        let collapsed = PracticePromptCardPresentation(
            snapshot: snapshot,
            isTranslationExpanded: false,
            isExplanationExpanded: false
        )
        let expanded = PracticePromptCardPresentation(
            snapshot: snapshot,
            isTranslationExpanded: true,
            isExplanationExpanded: true
        )

        #expect(collapsed.targetText == "Birds chirp softly, signaling the end of another peaceful day.")
        #expect(collapsed.translationText == "鸟儿轻声鸣叫，标志着另一个宁静的一天结束，也提醒用户这句话描述的是安静收束的生活场景。")
        #expect(collapsed.displayedTranslationText == nil)
        #expect(collapsed.shouldShowTranslationToggle)
        #expect(collapsed.translationToggleTitleKey == "practice.prompt.translation.expand")
        #expect(collapsed.translationAccessibilityValueKey == "accessibility.hidden")
        #expect(collapsed.explanationToggleTitleKey == "practice.prompt.explanation.expand")
        #expect(collapsed.explanationAccessibilityValueKey == "accessibility.hidden")
        #expect(collapsed.explanationParagraphs == ["chirp 是动词，表示鸟儿发出短促轻快的叫声。"])

        #expect(expanded.displayedTranslationText == "鸟儿轻声鸣叫，标志着另一个宁静的一天结束，也提醒用户这句话描述的是安静收束的生活场景。")
        #expect(expanded.translationToggleTitleKey == "practice.prompt.translation.collapse")
        #expect(expanded.translationAccessibilityValueKey == "accessibility.visible")
        #expect(expanded.explanationToggleTitleKey == "practice.prompt.explanation.collapse")
        #expect(expanded.explanationAccessibilityValueKey == "accessibility.visible")
    }

    @Test("Practice prompt card presentation requires explicit reveal for short translation")
    func practicePromptCardPresentationRequiresExplicitRevealForShortTranslation() {
        let short = PracticePromptCardPresentation(
            snapshot: promptSnapshot(translation: "鸟儿轻声鸣叫。", note: " "),
            isTranslationExpanded: false,
            isExplanationExpanded: false
        )
        let expandedShort = PracticePromptCardPresentation(
            snapshot: promptSnapshot(translation: "鸟儿轻声鸣叫。", note: " "),
            isTranslationExpanded: true,
            isExplanationExpanded: false
        )
        let blank = PracticePromptCardPresentation(
            snapshot: promptSnapshot(translation: " \n ", note: "\t"),
            isTranslationExpanded: false,
            isExplanationExpanded: false
        )

        #expect(short.translationText == "鸟儿轻声鸣叫。")
        #expect(short.displayedTranslationText == nil)
        #expect(short.shouldShowTranslationToggle)
        #expect(short.translationToggleTitleKey == "practice.prompt.translation.expand")
        #expect(short.explanationText == nil)
        #expect(!short.shouldShowExplanationToggle)

        #expect(expandedShort.displayedTranslationText == "鸟儿轻声鸣叫。")
        #expect(expandedShort.translationToggleTitleKey == "practice.prompt.translation.collapse")

        #expect(blank.translationText == nil)
        #expect(blank.displayedTranslationText == nil)
        #expect(blank.explanationText == nil)
        #expect(!blank.shouldShowTranslationToggle)
        #expect(!blank.shouldShowExplanationToggle)
    }

    @Test("Practice prompt card presentation splits explanation into readable paragraphs")
    func practicePromptCardPresentationSplitsExplanationParagraphs() {
        let presentation = PracticePromptCardPresentation(
            snapshot: promptSnapshot(
                translation: "太阳轻轻地落下。",
                note: "set (太阳落下): 在英语中，'set' 可以用来描述太阳落下的动作。\n\npainting (动名词): 'painting' 在这里是动名词形式，表示一种持续的动作。"
            ),
            isTranslationExpanded: false,
            isExplanationExpanded: true
        )

        #expect(presentation.explanationParagraphs == [
            "set (太阳落下): 在英语中，'set' 可以用来描述太阳落下的动作。",
            "painting (动名词): 'painting' 在这里是动名词形式，表示一种持续的动作。",
        ])
    }
}

private func makeEntry() -> LearningEntry {
    LearningEntry(
        id: "entry-1",
        spaceID: "space-1",
        title: "Morning commute",
        body: "我今天早上订了火车票。",
        source: .typedText,
        scene: "今天",
        createdAt: Date(timeIntervalSince1970: 1)
    )
}

private func makeRendering(sentenceCount: Int) -> LearningRendering {
    LearningRendering(
        id: "material-1",
        entryID: "entry-1",
        targetText: "I booked the train this morning.",
        promptLabel: "Auto",
        providerLabel: "OpenAI",
        isMock: false,
        sourceEntryBodyHash: "source-hash",
        sentences: (1 ... sentenceCount).map { index in
            RenderingSentence(
                id: "sentence-\(index)",
                translation: index == 1 ? "我今天早上订了火车票。" : "译文 \(index)",
                targetText: index == 1 ? "I booked the train this morning." : "Target sentence \(index).",
                note: index == 1 ? "booked 表示已经完成预订。" : "Note \(index)"
            )
        }
    )
}

private func snapshot(sentenceIndex: Int = 0) -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: sentenceIndex,
        targetTextSnapshot: "Target sentence 1.",
        targetTextHash: String(repeating: "a", count: 64),
        targetLanguageCode: "en",
        translationSnapshot: "译文 1",
        noteSnapshot: "Note 1",
        sourceEntryBodyHash: "source-hash",
        materialAnalysisSourceHash: nil,
        exerciseType: .shadowing,
        capturedAt: Date(timeIntervalSince1970: 1)
    )
}

private func promptSnapshot(translation: String?, note: String?) -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: 0,
        targetTextSnapshot: "Birds chirp softly, signaling the end of another peaceful day.",
        targetTextHash: String(repeating: "a", count: 64),
        targetLanguageCode: "en",
        translationSnapshot: translation,
        noteSnapshot: note,
        sourceEntryBodyHash: "source-hash",
        materialAnalysisSourceHash: nil,
        exerciseType: .shadowing,
        capturedAt: Date(timeIntervalSince1970: 1)
    )
}
