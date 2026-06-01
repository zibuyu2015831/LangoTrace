@testable import LangoTraceUI
import Testing

@Suite("Reading presentation")
struct ReadingPresentationTests {
    @Test("phone uses single column and bottom sheet inspector")
    func phoneLayoutUsesBottomSheetInspector() {
        let model = ReadingLayoutModel.platform(.phone)

        #expect(model.primaryColumnCount == 1)
        #expect(model.inspectorPresentation == .bottomSheet)
    }

    @Test("pad uses reading body plus side inspector")
    func padLayoutUsesSideInspector() {
        let model = ReadingLayoutModel.platform(.pad)

        #expect(model.primaryColumnCount == 2)
        #expect(model.inspectorPresentation == .sidePanel)
    }

    @Test("mac supports library body and inspector columns")
    func macLayoutSupportsThreeColumns() {
        let model = ReadingLayoutModel.platform(.mac)

        #expect(model.primaryColumnCount == 3)
        #expect(model.inspectorPresentation == .sidePanel)
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
}
