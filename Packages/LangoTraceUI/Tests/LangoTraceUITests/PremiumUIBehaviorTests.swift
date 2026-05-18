import Foundation
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

    @Test("Unavailable capability content uses stable localization keys")
    func unavailableCapabilityContentUsesStableLocalizationKeys() {
        #expect(PhoneUnavailableAction.photoWriting.content == .photoWriting)
        #expect(PhoneUnavailableAction.listenOne.content == .listenOne)
        #expect(PhoneUnavailableAction.languageSwitcher.content == .languageSpace)
        #expect(MacUnavailableContent(kind: "search").content == .search)
        #expect(MacUnavailableContent(kind: "import-export").content == .importExport)
        #expect(MacUnavailableContent(kind: "language-space").content == .languageSpace)
        #expect(MacUnavailableContent(kind: "unknown").content == .generic)
    }

    @Test("Stage two sample paths keep migrated chrome in localization resources")
    func stageTwoSamplePathsKeepMigratedChromeLocalized() throws {
        let files = [
            "PadWorkspaceBar.swift",
            "PhoneMainSupportingViews.swift",
            "EntryDetailHeader.swift",
            "MacMainView.swift",
            "MacInspectorContent.swift",
            "LearningContentComponents.swift",
            "PadSidebarControls.swift",
            "ContentUtilityComponents.swift",
        ]
        let forbiddenSnippets = [
            "搜索记录、词句、相似生活片段",
            "照片和语音当前为未接入能力",
            "今天记录一点生活",
            "生活记录和目标语言版本保持来源关系",
            "词句候选",
            "保持完成状态",
            "当前步骤",
            "当前为本地 mock，不播放真实语音",
            "朗读音频",
        ]

        for file in files {
            let source = try String(contentsOf: sourceFileURL(named: file), encoding: .utf8)
            for snippet in forbiddenSnippets {
                #expect(!source.contains(snippet))
            }
        }
    }

    @Test("Stage three unavailable pages keep migrated chrome localized")
    func stageThreeUnavailablePagesKeepMigratedChromeLocalized() throws {
        let files = [
            "UnavailableCapabilityView.swift",
            "PhoneMainModels.swift",
            "PhoneMainView.swift",
            "PadMainView.swift",
            "PadMainSections.swift",
            "MacMainModels.swift",
            "MacWorkspaceContentView.swift",
        ]
        let forbiddenSnippets = [
            "后续接入条件",
            "不会发生",
            "照片写作尚未接入",
            "听一句尚未接入",
            "语言空间切换尚未接入",
            "导入导出尚未接入",
            "搜索尚未接入",
            "本地向量索引尚未接入",
            "当前不会访问照片、麦克风、网络、Keychain、真实数据库、同步服务或导出文件",
        ]

        for file in files {
            let source = try String(contentsOf: sourceFileURL(named: file), encoding: .utf8)
            for snippet in forbiddenSnippets {
                #expect(!source.contains(snippet))
            }
        }
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

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
