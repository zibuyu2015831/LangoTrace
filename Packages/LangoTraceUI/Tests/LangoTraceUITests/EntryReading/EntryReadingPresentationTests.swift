import Foundation
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Entry reading presentation")
struct EntryReadingPresentationTests {
    private func rendering(targetText: String, sentences: [RenderingSentence]) -> LearningRendering {
        LearningRendering(
            id: "rendering-1",
            entryID: "entry-1",
            targetText: targetText,
            promptLabel: "natural",
            providerLabel: "Local Mock",
            isMock: true,
            sourceEntryBodyHash: "hash",
            sentences: sentences
        )
    }

    @Test("Presentation maps sentences from the live rendering")
    func mapsSentences() {
        let rendering = rendering(
            targetText: "A. B.",
            sentences: [
                RenderingSentence(id: "s1", translation: "甲。", targetText: "A.", note: "note-a"),
                RenderingSentence(id: "s2", translation: "乙。", targetText: "B.", note: "note-b"),
            ]
        )

        let presentation = EntryReadingPresentation.make(from: rendering)

        #expect(presentation.hasSentences == true)
        #expect(presentation.sentences.map(\.id) == ["s1", "s2"])
        #expect(presentation.sentences.first?.translation == "甲。")
        #expect(presentation.fullTargetText == "A. B.")
        #expect(presentation.showsFullTextFallback == false)
    }

    @Test("When sentences are missing the full target text is still readable, never blank")
    func fullTextFallbackWhenNoSentences() {
        let presentation = EntryReadingPresentation.make(
            from: rendering(targetText: "The whole paragraph.", sentences: [])
        )

        #expect(presentation.hasSentences == false)
        #expect(presentation.showsFullTextFallback == true)
        #expect(presentation.isEmpty == false)
    }

    @Test("A nil rendering is empty")
    func nilRenderingIsEmpty() {
        let presentation = EntryReadingPresentation.make(from: nil)

        #expect(presentation.isEmpty == true)
        #expect(presentation.showsFullTextFallback == false)
    }
}

@Suite("Entry reading reveal state")
struct EntryReadingRevealStateTests {
    @Test("Toggling a sentence flips its revealed flag")
    func toggle() {
        var state = EntryReadingRevealState()
        #expect(state.isRevealed("s1") == false)

        state.toggle("s1")
        #expect(state.isRevealed("s1") == true)

        state.toggle("s1")
        #expect(state.isRevealed("s1") == false)
    }

    @Test("Reveal all and hide all operate across ids")
    func revealAllAndHideAll() {
        var state = EntryReadingRevealState()
        state.revealAll(["s1", "s2"])
        #expect(state.isRevealed("s1") && state.isRevealed("s2"))
        #expect(state.isAllHidden == false)

        state.hideAll()
        #expect(state.isAllHidden == true)
    }
}

@Suite("Entry reading font scale")
struct EntryReadingFontScaleTests {
    @Test("Increase and decrease clamp at the bounds")
    func clampsAtBounds() {
        #expect(EntryReadingFontScale.small.decreased() == .small)
        #expect(EntryReadingFontScale.extraLarge.increased() == .extraLarge)
        #expect(EntryReadingFontScale.standard.increased() == .large)
        #expect(EntryReadingFontScale.large.decreased() == .standard)
    }

    @Test("Bounds report whether further adjustment is possible")
    func boundsReportAdjustability() {
        #expect(EntryReadingFontScale.small.canDecrease == false)
        #expect(EntryReadingFontScale.small.canIncrease == true)
        #expect(EntryReadingFontScale.extraLarge.canIncrease == false)
        #expect(EntryReadingFontScale.extraLarge.canDecrease == true)
    }

    @Test("Multiplier increases monotonically with scale")
    func multiplierMonotonic() {
        let multipliers = EntryReadingFontScale.allCases.map(\.multiplier)
        #expect(multipliers == multipliers.sorted())
        #expect(EntryReadingFontScale.default == .standard)
    }
}
