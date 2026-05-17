@testable import LangoTraceUI
import Testing

struct PadPanelGestureTests {
    @Test
    func hiddenLeftPanelOnlyOpensFromLeadingEdgeWithClearHorizontalIntent() {
        #expect(PadPanelGestureAction.action(in: PadPanelGestureContext(
            startX: 12,
            translationX: 72,
            translationY: 10,
            workspaceWidth: 1024,
            isTimelineVisible: false,
            isLearningPanelVisible: true
        )) == .showTimeline)

        #expect(PadPanelGestureAction.action(in: PadPanelGestureContext(
            startX: 60,
            translationX: 72,
            translationY: 10,
            workspaceWidth: 1024,
            isTimelineVisible: false,
            isLearningPanelVisible: true
        )) == nil)

        #expect(PadPanelGestureAction.action(in: PadPanelGestureContext(
            startX: 12,
            translationX: 72,
            translationY: 82,
            workspaceWidth: 1024,
            isTimelineVisible: false,
            isLearningPanelVisible: true
        )) == nil)
    }

    @Test
    func visiblePanelsHideFromTheirOwnPanelRegionsOnly() {
        #expect(PadPanelGestureAction.action(in: PadPanelGestureContext(
            startX: 180,
            translationX: -72,
            translationY: 8,
            workspaceWidth: 1024,
            isTimelineVisible: true,
            isLearningPanelVisible: true
        )) == .hideTimeline)

        #expect(PadPanelGestureAction.action(in: PadPanelGestureContext(
            startX: 844,
            translationX: 72,
            translationY: 8,
            workspaceWidth: 1024,
            isTimelineVisible: true,
            isLearningPanelVisible: true
        )) == .hideLearningPanel)

        #expect(PadPanelGestureAction.action(in: PadPanelGestureContext(
            startX: 512,
            translationX: -120,
            translationY: 8,
            workspaceWidth: 1024,
            isTimelineVisible: true,
            isLearningPanelVisible: true
        )) == nil)
    }

    @Test
    func hiddenRightPanelOnlyOpensFromTrailingEdge() {
        #expect(PadPanelGestureAction.action(in: PadPanelGestureContext(
            startX: 1014,
            translationX: -72,
            translationY: 10,
            workspaceWidth: 1024,
            isTimelineVisible: true,
            isLearningPanelVisible: false
        )) == .showLearningPanel)

        #expect(PadPanelGestureAction.action(in: PadPanelGestureContext(
            startX: 960,
            translationX: -72,
            translationY: 10,
            workspaceWidth: 1024,
            isTimelineVisible: true,
            isLearningPanelVisible: false
        )) == nil)
    }
}
