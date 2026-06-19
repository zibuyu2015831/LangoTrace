@testable import LangoTraceUI
import Testing

@Suite("Reading inspector collapse / fold (Phase 3)")
struct ReadingInspectorCollapseTests {
    // MARK: - canFoldInspector on ReadingLayoutModel

    @Test("iPad layout supports inspector fold")
    func padLayoutCanFoldInspector() {
        let model = ReadingLayoutModel.platform(.pad)
        #expect(model.canFoldInspector == true)
    }

    @Test("mac layout does not support inspector fold (always resident)")
    func macLayoutCannotFoldInspector() {
        let model = ReadingLayoutModel.platform(.mac)
        #expect(model.canFoldInspector == false)
    }

    @Test("phone layout does not support inspector fold (uses inline panel)")
    func phoneLayoutCannotFoldInspector() {
        let model = ReadingLayoutModel.platform(.phone)
        #expect(model.canFoldInspector == false)
    }

    // MARK: - inspector fold only applies when showsPersistentInspector

    @Test("canFoldInspector is false when showsPersistentInspector is false")
    func cannotFoldWhenNoInspector() {
        let model = ReadingLayoutModel(
            platform: .pad,
            primaryColumnCount: 2,
            inspectorPresentation: .sidePanel,
            workspaceStyle: .focusedCanvas,
            showsPersistentInspector: false
        )
        #expect(model.canFoldInspector == false)
    }

    @Test("canFoldInspector is true only for pad with persistent inspector")
    func foldOnlyForPadWithInspector() {
        let padWithInspector = ReadingLayoutModel(
            platform: .pad,
            primaryColumnCount: 2,
            inspectorPresentation: .sidePanel,
            workspaceStyle: .focusedCanvas,
            showsPersistentInspector: true
        )
        let padWithoutInspector = ReadingLayoutModel(
            platform: .pad,
            primaryColumnCount: 2,
            inspectorPresentation: .inlineBottomPanel,
            workspaceStyle: .focusedCanvas,
            showsPersistentInspector: false
        )
        let macWithInspector = ReadingLayoutModel(
            platform: .mac,
            primaryColumnCount: 3,
            inspectorPresentation: .sidePanel,
            workspaceStyle: .balancedWorkbench,
            showsPersistentInspector: true
        )

        #expect(padWithInspector.canFoldInspector == true)
        #expect(padWithoutInspector.canFoldInspector == false)
        #expect(macWithInspector.canFoldInspector == false)
    }
}
