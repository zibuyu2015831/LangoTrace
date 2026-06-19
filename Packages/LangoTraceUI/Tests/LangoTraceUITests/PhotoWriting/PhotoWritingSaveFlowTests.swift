import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Photo writing save flow (E2 Phase 3)")
struct PhotoWritingSaveFlowTests {
    // MARK: - Save orchestration

    @Test("Photo writing save fails and rolls back the entry when photo import fails")
    func photoWritingSaveFailsAndRollsBackEntryWhenPhotoImportFails() throws {
        let createdEntry = LearningEntry(
            id: "entry-photo-1",
            spaceID: "space-en",
            title: "Photo note",
            body: "Photo note body",
            source: .photoWriting,
            scene: "今天",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            practiceStatus: .notStarted
        )
        var deletedEntryIDs: [String] = []

        let coordinator = PhotoWritingSaveCoordinator(
            createEntry: { title, body, source in
                #expect(title == "Photo note body")
                #expect(body == "Photo note body")
                #expect(source == .photoWriting)
                return createdEntry
            },
            deleteEntry: { entryID in
                deletedEntryIDs.append(entryID)
            },
            importPhoto: { _, _, _ in
                throw PhotoWritingSaveFlowTestError.importFailed
            }
        )

        #expect(throws: PhotoWritingSaveError.self) {
            _ = try coordinator.save(
                body: "Photo note body",
                imageData: Data([0x01, 0x02]),
                spaceID: "space-en"
            )
        }
        #expect(deletedEntryIDs == ["entry-photo-1"])
    }

    @Test("Photo writing save succeeds only after the photo import succeeds")
    func photoWritingSaveSucceedsOnlyAfterPhotoImportSucceeds() throws {
        let createdEntry = LearningEntry(
            id: "entry-photo-2",
            spaceID: "space-en",
            title: "Photo note",
            body: "Photo note body",
            source: .photoWriting,
            scene: "今天",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            practiceStatus: .notStarted
        )
        var importedEntryID: String?

        let coordinator = PhotoWritingSaveCoordinator(
            createEntry: { _, _, _ in createdEntry },
            deleteEntry: { _ in },
            importPhoto: { data, entryID, spaceID in
                #expect(data == Data([0x01, 0x02]))
                #expect(spaceID == "space-en")
                importedEntryID = entryID
            }
        )

        let savedEntry = try coordinator.save(
            body: "Photo note body",
            imageData: Data([0x01, 0x02]),
            spaceID: "space-en"
        )

        #expect(savedEntry.id == createdEntry.id)
        #expect(importedEntryID == createdEntry.id)
    }

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

private enum PhotoWritingSaveFlowTestError: Error {
    case importFailed
}
