@testable import LangoTraceUI
import Testing

@Suite("Entry detail photo layout")
struct EntryDetailPhotoLayoutTests {
    @Test("Loaded photo uses fitted card chrome")
    func loadedPhotoUsesFittedCardChrome() {
        let layout = EntryDetailPhotoLayout.loadedCard

        #expect(layout.imageSizing == .fit)
        #expect(layout.hasVisibleChrome)
        #expect(layout.maximumImageHeight == 280)
    }
}
