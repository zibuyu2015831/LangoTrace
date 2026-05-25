import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Practice route seed")
struct PracticeRouteSeedTests {
    @Test("Route seed captures sentence identity and immutable sentence snapshot")
    func routeSeedCapturesSentenceIdentityAndSnapshot() {
        let entry = LearningEntry(
            id: "entry-1",
            spaceID: "space-1",
            title: "Morning commute",
            body: "我今天早上订了火车票。",
            source: .typedText,
            scene: "生活记录",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let rendering = LearningRendering(
            id: "material-1",
            entryID: "entry-1",
            targetText: "I booked the train this morning.",
            promptLabel: "Auto",
            providerLabel: "OpenAI",
            isMock: false,
            sourceEntryBodyHash: "source-hash",
            sentences: [
                RenderingSentence(
                    id: "sentence-1",
                    translation: "我今天早上订了火车票。",
                    targetText: "I booked the train this morning.",
                    note: "booked 表示已经完成预订。"
                ),
            ]
        )

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
