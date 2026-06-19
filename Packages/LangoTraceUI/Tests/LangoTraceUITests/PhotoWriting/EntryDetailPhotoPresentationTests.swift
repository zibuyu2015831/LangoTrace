import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Entry detail photo presentation")
struct EntryDetailPhotoPresentationTests {
    @Test("Typed text entries do not reserve a photo region")
    func typedTextEntriesDoNotReservePhotoRegion() {
        let entry = entry(source: .typedText)
        let state = EntryDetailPhotoPresentation.initialState(for: entry)

        #expect(state == .notApplicable)
        #expect(state.shouldRenderRegion == false)
    }

    @Test("Photo writing entries start with a visible loading photo region")
    func photoWritingEntriesStartWithVisibleLoadingPhotoRegion() {
        let entry = entry(source: .photoWriting)
        let state = EntryDetailPhotoPresentation.initialState(for: entry)

        #expect(state == .loading)
        #expect(state.shouldRenderRegion == true)
    }

    @Test("Missing photo data resolves to unavailable instead of hiding the region")
    func missingPhotoDataResolvesToUnavailableInsteadOfHidingTheRegion() {
        let state = EntryDetailPhotoPresentation.resolvedState(photoDataWasLoaded: false)

        #expect(state == .unavailable)
        #expect(state.shouldRenderRegion == true)
        #expect(state.titleKey == "entry.detail.photo.unavailable.title")
    }

    @Test("Undecodable photo data resolves to failed instead of hiding the region")
    func undecodablePhotoDataResolvesToFailedInsteadOfHidingTheRegion() {
        let state = EntryDetailPhotoPresentation.resolvedState(photoDataWasLoaded: true, imageWasDecoded: false)

        #expect(state == .failed)
        #expect(state.shouldRenderRegion == true)
        #expect(state.titleKey == "entry.detail.photo.failed.title")
    }

    private func entry(source: EntrySource) -> LearningEntry {
        LearningEntry(
            id: "entry-\(source.rawValue)",
            spaceID: "space-en",
            title: "Photo note",
            body: "Photo note body",
            source: source,
            scene: "今天",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            practiceStatus: .notStarted
        )
    }
}
