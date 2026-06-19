@testable import LangoTraceUI
import Testing

@Suite("iPad settings focus policy")
struct PadSettingsFocusPolicyTests {
    @Test("iPad settings routes default to a focused main column")
    func iPadSettingsRoutesDefaultToFocusedMainColumn() {
        let current = PadPanelVisibility(timeline: true, learningPanel: true)

        #expect(PadSettingsFocusPolicy.visibility(
            whenEntering: .settings(.sync),
            current: current
        ) == PadPanelVisibility(timeline: true, learningPanel: false))
        #expect(PadSettingsFocusPolicy.visibility(
            whenEntering: .settings(.aiProvider),
            current: current
        ) == PadPanelVisibility(timeline: true, learningPanel: false))
        #expect(PadSettingsFocusPolicy.visibility(
            whenEntering: .entryDetail("entry-1"),
            current: current
        ) == current)
    }

    @Test("iPad settings focus preserves manual panel reopening in regular width")
    func iPadSettingsFocusPreservesManualPanelReopeningInRegularWidth() {
        let manuallyReopened = PadPanelVisibility(timeline: true, learningPanel: true)

        #expect(PadSettingsFocusPolicy.visibilityAfterResize(
            route: .settings(.sync),
            workspaceWidth: 1180,
            horizontalSizeClass: .regular,
            current: manuallyReopened
        ) == manuallyReopened)
        #expect(PadSettingsFocusPolicy.visibilityAfterResize(
            route: .settings(.sync),
            workspaceWidth: 620,
            horizontalSizeClass: .regular,
            current: manuallyReopened
        ) == PadPanelVisibility(timeline: false, learningPanel: false))
    }
}
