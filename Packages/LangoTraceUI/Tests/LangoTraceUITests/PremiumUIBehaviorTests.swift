import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Premium UI behavior")
struct PremiumUIBehaviorTests {
    @Test("Local mock request previews do not say content is about to be sent")
    func localMockRequestPreviewDoesNotUseExternalSendingCopy() {
        let copy = RequestPreviewCopy.localMock(
            entryTitle: "雨天咖啡馆",
            promptLabel: "自然表达"
        )

        #expect(!copy.body.contains("即将发送"))
        #expect(copy.body.contains("当前不会发送"))
        #expect(copy.body.contains("真实接入后"))
    }

    @Test("External request previews are reserved for explicit provider requests")
    func externalRequestPreviewUsesSendingCopy() {
        let copy = RequestPreviewCopy.externalRequest(
            entryTitle: "雨天咖啡馆",
            promptLabel: "自然表达"
        )

        #expect(copy.body.contains("将发送"))
        #expect(!copy.body.contains("当前不会发送"))
    }

    @Test("iPad compact width protects the main column by hiding the learning panel")
    func compactWidthHidesLearningPanel() {
        let current = PadPanelVisibility(timeline: true, learningPanel: true)

        #expect(PadAdaptivePanelLayout.visibility(
            for: .compact,
            current: current
        ) == PadPanelVisibility(timeline: true, learningPanel: false))
    }

    @Test("iPad regular width preserves the current panel visibility")
    func regularWidthPreservesPanelVisibility() {
        let current = PadPanelVisibility(timeline: false, learningPanel: false)

        #expect(PadAdaptivePanelLayout.visibility(
            for: .regular,
            current: current
        ) == current)
    }

    @Test("Mac minimum window widths keep narrow layouts usable")
    func macMinimumWindowWidthsKeepNarrowLayoutsUsable() {
        #expect(MacWindowLayout.minimumWidth(sidebarVisible: true, inspectorVisible: true) == 1040)
        #expect(MacWindowLayout.minimumWidth(sidebarVisible: true, inspectorVisible: false) == 820)
        #expect(MacWindowLayout.minimumWidth(sidebarVisible: false, inspectorVisible: true) == 780)
        #expect(MacWindowLayout.minimumWidth(sidebarVisible: false, inspectorVisible: false) == 560)
    }

    @Test("Capability statuses map to distinct visual tones")
    func capabilityStatusesMapToDistinctVisualTones() {
        #expect(CapabilityStatus.ready.visualTone == .ready)
        #expect(CapabilityStatus.mockOnly.visualTone == .localMock)
        #expect(CapabilityStatus.unavailable.visualTone == .unavailable)
    }

    @Test("Entry header status distinguishes missing, mock, and ready renderings")
    func entryHeaderStatusDistinguishesRenderingAvailability() {
        #expect(EntryRenderingStatus.status(for: nil) == .unavailable)
        #expect(EntryRenderingStatus.status(for: rendering(isMock: true)) == .mockOnly)
        #expect(EntryRenderingStatus.status(for: rendering(isMock: false)) == .ready)
    }

    private func rendering(isMock: Bool) -> LearningRendering {
        LearningRendering(
            id: "rendering-1",
            entryID: "entry-1",
            targetText: "I wrote a sentence.",
            promptLabel: "natural",
            providerLabel: isMock ? "Local Mock" : "External Provider",
            isMock: isMock,
            sentences: []
        )
    }
}
