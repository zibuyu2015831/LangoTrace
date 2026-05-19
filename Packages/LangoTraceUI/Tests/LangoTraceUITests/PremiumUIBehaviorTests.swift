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
        #expect(copy.body.contains("雨天咖啡馆"))
        #expect(copy.body.contains("自然表达"))
        #expect(copy.body != RequestPreviewCopy.externalRequest(entryTitle: "雨天咖啡馆", promptLabel: "自然表达").body)
    }

    @Test("External request previews are reserved for explicit provider requests")
    func externalRequestPreviewUsesSendingCopy() {
        let copy = RequestPreviewCopy.externalRequest(
            entryTitle: "雨天咖啡馆",
            promptLabel: "自然表达"
        )

        #expect(copy.body.contains("雨天咖啡馆"))
        #expect(copy.body.contains("自然表达"))
        #expect(copy.body != RequestPreviewCopy.localMock(entryTitle: "雨天咖啡馆", promptLabel: "自然表达").body)
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

    @Test("iPad workspace width classes protect the writing desk")
    func iPadWorkspaceWidthClassesProtectWritingDesk() {
        let current = PadPanelVisibility(timeline: true, learningPanel: true)

        #expect(PadWorkspaceWidthClass.classify(width: 1180) == .threeColumn)
        #expect(PadAdaptivePanelLayout.visibility(
            forWidth: 1180,
            horizontalSizeClass: .regular,
            current: current
        ) == current)

        #expect(PadWorkspaceWidthClass.classify(width: 820) == .twoColumn)
        #expect(PadAdaptivePanelLayout.visibility(
            forWidth: 820,
            horizontalSizeClass: .regular,
            current: current
        ) == PadPanelVisibility(timeline: true, learningPanel: false))

        #expect(PadWorkspaceWidthClass.classify(width: 620) == .singleColumn)
        #expect(PadAdaptivePanelLayout.visibility(
            forWidth: 620,
            horizontalSizeClass: .regular,
            current: current
        ) == PadPanelVisibility(timeline: false, learningPanel: false))
    }

    @Test("iPad workspace bar keeps utility actions and keyboard shortcuts reachable")
    func iPadWorkspaceBarKeepsUtilityActionsAndKeyboardShortcutsReachable() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PadWorkspaceBar.swift"), encoding: .utf8)

        for expected in [
            "onSettings",
            ".keyboardShortcut(\"n\"",
            ".keyboardShortcut(\"f\"",
            ".keyboardShortcut(\",\"",
            ".keyboardShortcut(\"[\"",
            ".keyboardShortcut(\"]\"",
        ] {
            #expect(source.contains(expected))
        }
    }

    @Test("iPad timeline and filter controls expose pointer focus and context affordances")
    func iPadTimelineAndFilterControlsExposePointerFocusAndContextAffordances() throws {
        let timelineSource = try String(
            contentsOf: sourceFileURL(named: "LearningContentComponents.swift"),
            encoding: .utf8
        )
        let sidebarSource = try String(contentsOf: sourceFileURL(named: "PadSidebarControls.swift"), encoding: .utf8)

        for source in [timelineSource, sidebarSource] {
            #expect(source.contains(".focusable()"))
            #expect(source.contains(".onHover"))
            #expect(source.contains(".contextMenu"))
        }
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

    @Test("Status matrix uses text icon and tone for every supported state")
    func statusMatrixUsesTextIconAndToneForEverySupportedState() {
        for status in LangoTraceStatusKind.allCases {
            #expect(!status.titleKey.isEmpty)
            #expect(!status.summaryKey.isEmpty)
            #expect(!status.systemImage.isEmpty)
        }

        #expect(LangoTraceStatusKind.permissionDenied.visualTone == .warning)
        #expect(LangoTraceStatusKind.syncConflict.visualTone == .error)
        #expect(LangoTraceStatusKind.loading.visualTone == .info)
    }

    @Test("Memory pages use the shared three-layer memory summary")
    func memoryPagesUseSharedThreeLayerMemorySummary() throws {
        for file in ["PhoneMainSections.swift", "PadMainSections.swift", "MacWorkspaceContentView.swift"] {
            let source = try String(contentsOf: sourceFileURL(named: file), encoding: .utf8)

            #expect(source.contains("MemoryLayerSummaryView("))
        }
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
        #expect(MacUnavailableContent(kind: "search").content == .search)
        #expect(MacUnavailableContent(kind: "import-export").content == .importExport)
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

    @Test("Stage four visible interaction and accessibility gaps stay closed")
    func stageFourVisibleInteractionAndAccessibilityGapsStayClosed() throws {
        let learningContentComponents = try String(
            contentsOf: sourceFileURL(named: "LearningContentComponents.swift"),
            encoding: .utf8
        )
        let welcomeView = try [
            String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8),
            String(contentsOf: sourceFileURL(named: "WelcomeView+Layout.swift"), encoding: .utf8),
        ].joined(separator: "\n")
        let phoneSupportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let unavailableView = try String(
            contentsOf: sourceFileURL(named: "UnavailableCapabilityView.swift"),
            encoding: .utf8
        )

        #expect(!learningContentComponents.contains("Button {}"))
        #expect(learningContentComponents.contains("onListen"))
        #expect(!welcomeView.contains(".task {"))
        #expect(welcomeView.contains("Button(action: onFinished)"))
        #expect(phoneSupportingViews.contains(
            #"accessibilityLabel(localizedText("entryEditor.bodyField.accessibilityLabel"))"#
        ))
        #expect(unavailableView.contains("ScrollView"))
        #expect(unavailableView.contains("presentationTitleKey"))
        #expect(unavailableView.contains("onDismiss"))
    }

    @Test("LangoTraceUI Swift chrome contains no hard-coded Han characters")
    func langoTraceUISwiftChromeContainsNoHardCodedHanCharacters() throws {
        let sourcesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
        let sourceFiles = FileManager.default
            .enumerator(at: sourcesRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        for sourceFile in sourceFiles {
            let source = try String(contentsOf: sourceFile, encoding: .utf8)
            #expect(source.range(of: #"\p{script=Han}"#, options: .regularExpression) == nil)
        }
    }
}

private extension PremiumUIBehaviorTests {
    func rendering(isMock: Bool) -> LearningRendering {
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

    func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
