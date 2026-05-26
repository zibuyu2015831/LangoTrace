import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

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
}

private func makeEntry() -> LearningEntry {
    LearningEntry(
        id: "entry-1",
        spaceID: "space-1",
        title: "Morning commute",
        body: "我今天早上订了火车票。",
        source: .typedText,
        scene: "生活记录",
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

private func snapshot() -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: 0,
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
