import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Practice sentence list presentation")
struct PracticeSentenceListPresentationTests {
    @Test("Single available mode hides the mode selector")
    func singleAvailableModeHidesModeSelector() {
        let presentation = PracticeSentenceListPresentation(
            sentences: sentences(count: 2),
            selectedMode: .shadowing,
            practicedSentenceIDs: [],
            availability: PracticeModeAvailability(availableModes: [.shadowing])
        )

        #expect(presentation.shouldShowModeSelector == false)
        #expect(presentation.availableModes == [.shadowing])
    }

    @Test("Multiple available modes show the selector without rendering unavailable modes")
    func multipleAvailableModesShowSelectorWithoutUnavailableModes() {
        let presentation = PracticeSentenceListPresentation(
            sentences: sentences(count: 2),
            selectedMode: .dictation,
            practicedSentenceIDs: [],
            availability: PracticeModeAvailability(availableModes: [.shadowing, .dictation])
        )

        #expect(presentation.shouldShowModeSelector)
        #expect(presentation.availableModes == [.shadowing, .dictation])
        #expect(!presentation.availableModes.contains(.backtranslation))
    }

    @Test("Rows and continue target are derived from practiced sentence ids")
    func rowsAndContinueTargetAreDerivedFromPracticedSentenceIDs() throws {
        let presentation = PracticeSentenceListPresentation(
            sentences: sentences(count: 3),
            selectedMode: .shadowing,
            practicedSentenceIDs: ["sentence-1"],
            availability: PracticeModeAvailability(availableModes: [.shadowing])
        )

        #expect(presentation.rows.map(\.isPracticed) == [true, false, false])
        #expect(presentation.rows[0].statusTitleKey == "practice.sentenceList.practiced")
        let target = try #require(presentation.continueTarget)
        #expect(target.sentenceID == "sentence-2")
        #expect(target.sentenceIndex == 1)
        #expect(target.position == 2)
        #expect(target.titleKey == "practice.sentenceList.continueFrom")
    }

    @Test("Continue target is hidden after every sentence in the selected mode is practiced")
    func continueTargetIsHiddenAfterEverySentenceIsPracticed() {
        let presentation = PracticeSentenceListPresentation(
            sentences: sentences(count: 2),
            selectedMode: .shadowing,
            practicedSentenceIDs: ["sentence-1", "sentence-2"],
            availability: PracticeModeAvailability(availableModes: [.shadowing])
        )

        #expect(presentation.rows.map(\.isPracticed) == [true, true])
        #expect(presentation.continueTarget == nil)
    }

    private func sentences(count: Int) -> [RenderingSentence] {
        (1 ... count).map { index in
            RenderingSentence(
                id: "sentence-\(index)",
                translation: "译文 \(index)",
                targetText: "Target sentence \(index).",
                note: "Note \(index)"
            )
        }
    }
}
