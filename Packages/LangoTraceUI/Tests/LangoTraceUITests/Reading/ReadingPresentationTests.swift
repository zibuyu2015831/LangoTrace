@testable import LangoTraceUI
import Testing

@Suite("Reading presentation")
struct ReadingPresentationTests {
    @Test("phone compact uses single column and inline learning panel instead of bottom sheet")
    func phoneCompactUsesInlineLearningPanelInsteadOfBottomSheet() {
        let model = ReadingLayoutModel.platform(.phone)

        #expect(model.primaryColumnCount == 1)
        #expect(model.inspectorPresentation == .inlineBottomPanel)
        #expect(!model.showsPersistentInspector)
    }

    @Test("pad uses reading body plus side inspector")
    func padLayoutUsesSideInspector() {
        let model = ReadingLayoutModel.platform(.pad)

        #expect(model.primaryColumnCount == 2)
        #expect(model.inspectorPresentation == .sidePanel)
        #expect(model.workspaceStyle == .focusedCanvas)
        #expect(model.showsPersistentInspector)
    }

    @Test("mac supports library body and inspector columns")
    func macLayoutSupportsThreeColumns() {
        let model = ReadingLayoutModel.platform(.mac)

        #expect(model.primaryColumnCount == 3)
        #expect(model.inspectorPresentation == .sidePanel)
        #expect(model.workspaceStyle == .balancedWorkbench)
        #expect(model.showsPersistentInspector)
    }

    @Test("selection opens inspector without mutating document chunks")
    func selectionOpensInspector() {
        var state = ReadingPresentationState(
            layout: .platform(.phone),
            chunks: [
                .init(id: "chunk-1", text: "A short sentence for lookup."),
            ]
        )

        state.selectText("sentence", inChunkID: "chunk-1")

        #expect(state.selectedText == "sentence")
        #expect(state.isInspectorPresented)
        #expect(state.chunks.map(\.text) == ["A short sentence for lookup."])
    }

    @Test("phone reading starts on library home instead of inline document detail")
    func phoneReadingStartsOnLibraryHome() {
        let state = ReadingPhoneNavigationState()

        #expect(state.destination == .libraryHome)
        #expect(state.showsLibraryChrome)
        #expect(!state.showsDocumentDetail)
    }

    @Test("opening a phone reading document pushes independent detail")
    func phoneReadingOpensIndependentDetail() {
        var state = ReadingPhoneNavigationState()

        state.openDocument(id: "doc-1")

        #expect(state.destination == .documentDetail(documentID: "doc-1"))
        #expect(!state.showsLibraryChrome)
        #expect(state.showsDocumentDetail)
    }

    @Test("closing phone reading detail returns to library home")
    func closingPhoneReadingDetailReturnsHome() {
        var state = ReadingPhoneNavigationState(destination: .documentDetail(documentID: "doc-1"))

        state.closeDetail()

        #expect(state.destination == .libraryHome)
        #expect(state.showsLibraryChrome)
    }

    @Test("phone reading detail chrome uses toolbar edit action without repeated metadata header")
    func phoneReadingDetailChromeUsesToolbarEditAction() {
        let chrome = ReadingDetailChromeModel.phoneReading

        #expect(chrome.showsToolbarEditAction)
        #expect(!chrome.showsInlineMetadataHeader)
    }
}
