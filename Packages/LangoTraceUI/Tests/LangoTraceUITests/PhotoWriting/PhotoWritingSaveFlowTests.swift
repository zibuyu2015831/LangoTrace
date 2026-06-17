@testable import LangoTraceUI
import Testing

@Suite("Photo writing save flow (E2 Phase 3)")
struct PhotoWritingSaveFlowTests {
    // MARK: - Guidance chip semantics

    @Test("Guidance chip tap does not mutate draft text")
    func guidanceChipTapDoesNotMutateDraftText() {
        var state = PhotoWritingDraftState(draftText: "My original text")
        let textBefore = state.draftText
        state.selectGuidanceChip(.describeScene)
        #expect(state.draftText == textBefore)
    }

    @Test("Guidance chip tap sets active chip")
    func guidanceChipTapSetsActiveChip() {
        var state = PhotoWritingDraftState()
        state.selectGuidanceChip(.describeScene)
        #expect(state.activeGuidanceChip == .describeScene)
    }

    @Test("Guidance chip tap on same chip deactivates it")
    func guidanceChipTapOnSameChipDeactivatesIt() {
        var state = PhotoWritingDraftState()
        state.selectGuidanceChip(.describeScene)
        state.selectGuidanceChip(.describeScene)
        #expect(state.activeGuidanceChip == nil)
    }

    @Test("Guidance chip switching replaces active chip without writing to draft")
    func guidanceChipSwitchingReplacesActiveChipWithoutWritingToDraft() {
        var state = PhotoWritingDraftState(draftText: "Some draft")
        state.selectGuidanceChip(.describeScene)
        state.selectGuidanceChip(.recordFeelings)
        #expect(state.activeGuidanceChip == .recordFeelings)
        #expect(state.draftText == "Some draft")
    }

    // MARK: - Save enablement logic

    @Test("Save is disabled without photo")
    func saveIsDisabledWithoutPhoto() {
        let state = PhotoWritingDraftState(draftText: "Some text")
        #expect(state.isSaveEnabled(hasPhoto: false) == false)
    }

    @Test("Save is disabled with photo but empty text")
    func saveIsDisabledWithPhotoButEmptyText() {
        let state = PhotoWritingDraftState(draftText: "")
        #expect(state.isSaveEnabled(hasPhoto: true) == false)
    }

    @Test("Save is disabled with photo and whitespace-only text")
    func saveIsDisabledWithPhotoAndWhitespaceOnlyText() {
        let state = PhotoWritingDraftState(draftText: "   \n  ")
        #expect(state.isSaveEnabled(hasPhoto: true) == false)
    }

    @Test("Save is enabled with photo and non-empty text")
    func saveIsEnabledWithPhotoAndText() {
        let state = PhotoWritingDraftState(draftText: "Some text")
        #expect(state.isSaveEnabled(hasPhoto: true) == true)
    }

    // MARK: - Guidance chip kind coverage

    @Test("All guidance chip kinds have title and hint keys")
    func allGuidanceChipKindsHaveTitleAndHintKeys() {
        for chip in GuidanceChipKind.allCases {
            #expect(!chip.titleKey.isEmpty)
            #expect(!chip.hintKey.isEmpty)
        }
    }
}
