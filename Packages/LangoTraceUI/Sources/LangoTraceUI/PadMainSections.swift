import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PadSidebarView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let filteredEntries: [LearningEntry]
    let memoryItems: [MemoryItem]
    let selectedEntry: LearningEntry?
    let activeFilter: PadFilter
    let route: PadWorkspaceRoute
    let onSelectEntry: (LearningEntry) -> Void
    let onSelectFilter: (PadFilter) -> Void
    let onRoute: (PadWorkspaceRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SidebarSectionTitle("时间线")
            VStack(spacing: 10) {
                ForEach(filteredEntries) { entry in
                    EntryTimelineRow(
                        entry: entry,
                        targetLanguage: languageSpace.targetLanguage,
                        isSelected: entry.id == selectedEntry?.id
                    ) {
                        onSelectEntry(entry)
                    }
                }
            }

            SidebarSectionTitle("筛选")
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(PadFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.title,
                        count: "\(entries.count { filter.includes(entry: $0, memoryItems: memoryItems) })",
                        active: activeFilter == filter
                    ) {
                        onSelectFilter(filter)
                    }
                }
            }

            SidebarSectionTitle("页面")
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                PadRouteButton(title: "记忆", systemImage: "archivebox", active: route == .memory) {
                    onRoute(.memory)
                }
                PadRouteButton(title: "导入导出", systemImage: "tray.and.arrow.down", active: route == .importExport) {
                    onRoute(.importExport)
                }
                PadRouteButton(title: "设置", systemImage: "gearshape", active: route == .settingsList) {
                    onRoute(.settingsList)
                }
            }

            Spacer()

            LanguageSpaceFooter(
                languageSpace: languageSpace,
                aiStatus: .notConfigured,
                syncStatus: .off,
                isCompact: false,
                onLanguageSpace: { onRoute(PadFooterAction.languageSpace.route) },
                onAIStatus: { onRoute(PadFooterAction.aiProvider.route) },
                onSyncStatus: { onRoute(PadFooterAction.sync.route) },
                onSettings: { onRoute(PadFooterAction.settings.route) }
            )
        }
        .padding(22)
        .frame(minWidth: 240, idealWidth: 270, maxWidth: 300, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.paper.opacity(0.72))
    }
}

struct PadWorkspaceContentView: View {
    let route: PadWorkspaceRoute
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let selectedEntry: LearningEntry?
    let selectedRendering: LearningRendering?
    let memoryItems: [MemoryItem]
    let settingsCapabilities: [SettingsCapability]
    let contentRepository: InMemoryLearningContentRepository
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onRoute: (PadWorkspaceRoute) -> Void

    var body: some View {
        Group {
            switch route {
            case .workspace:
                workspaceOverview
            case let .entryDetail(entryID):
                entryDetail(entryID: entryID)
            case let .practice(entryID):
                practice(entryID: entryID)
            case let .settings(kind):
                settingDetail(kind: kind)
            case .settingsList:
                settingsList
            case .memory:
                memoryPage
            case .importExport:
                importExportPage
            case .languageSpaceUnavailable:
                languageSpaceUnavailablePage
            }
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }

    private var workspaceOverview: some View {
        ScrollView {
            if let selectedEntry {
                VStack(alignment: .leading, spacing: 18) {
                    workspaceHeader(for: selectedEntry)
                    HStack(alignment: .top, spacing: 14) {
                        TextPanel(title: "母语记录", text: selectedEntry.body)
                        TextPanel(title: "目标语言", text: selectedRendering?.targetText ?? "等待生成")
                    }
                    AudioPanel()
                    sentenceList(for: selectedEntry)
                }
                .padding(26)
                .frame(maxWidth: 820, alignment: .leading)
            } else {
                EmptyWorkspacePanel()
                    .padding(26)
            }
        }
    }

    private func workspaceHeader(for entry: LearningEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.system(.largeTitle, design: .default, weight: .semibold))
            Text("把中文生活记录转换为 \(languageSpace.targetLanguage) 学习材料，支持逐句朗读、解释和练习。")
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sentenceList(for entry: LearningEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaption(title: "逐句练习", subtitle: "从真实记录进入听、读、跟读和回译")
            ForEach(Array((selectedRendering?.sentences ?? []).enumerated()), id: \.element.id) { index, sentence in
                SentencePairView(
                    index: index + 1,
                    sentence: sentence,
                    onPractice: { onRoute(.practice(entry.id)) }
                )
            }
        }
    }

    @ViewBuilder
    private func entryDetail(entryID: String) -> some View {
        if let entry = entries.first(where: { $0.id == entryID }) {
            EntryDetailView(
                languageSpace: languageSpace,
                entry: entry,
                rendering: contentRepository.rendering(for: entry.id),
                practiceItems: contentRepository.practiceItems(for: entry.id),
                onPractice: { onRoute(.practice(entry.id)) }
            )
        } else {
            EmptyWorkspacePanel()
                .padding(26)
        }
    }

    @ViewBuilder
    private func practice(entryID: String) -> some View {
        if let entry = entries.first(where: { $0.id == entryID }) {
            PracticeSessionView(
                entry: entry,
                rendering: contentRepository.rendering(for: entry.id),
                session: contentRepository.practiceSession(for: entry.id)
            )
        } else {
            EmptyWorkspacePanel()
                .padding(26)
        }
    }

    @ViewBuilder
    private func settingDetail(kind: SettingsCapability.Kind) -> some View {
        if let capability = settingsCapabilities.first(where: { $0.kind == kind }) {
            SettingsCapabilityDetailView(
                languageSpace: languageSpace,
                capability: capability,
                interfaceLanguagePreference: interfaceLanguagePreference,
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
            )
        } else {
            EmptyWorkspacePanel()
                .padding(26)
        }
    }

    private var settingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: "设置", subtitle: "当前只读说明能力边界，不保存真实配置。")
                ForEach(settingsCapabilities) { capability in
                    CapabilityStatusRow(
                        localizedTitleKey: capability.kind.localizedTitleKey,
                        summary: capability.summary,
                        status: capability.status,
                        systemImage: capability.kind.systemImage,
                        action: { onRoute(.settings(capability.kind)) }
                    )
                }
            }
            .padding(26)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var memoryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: "记忆", subtitle: "词句、相似片段和长期轨迹。")
                ForEach(memoryItems) { item in
                    CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
                }
                UnavailableCapabilityView(
                    title: "本地向量索引尚未接入",
                    summary: "当前只展示 mock 记忆项，不建立 embedding，也不写入向量索引。",
                    nextRequirement: "完成 SQLite / GRDB、embedding provider、可重建索引和同步排除边界。",
                    systemImage: "square.stack.3d.up"
                )
            }
            .padding(26)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var importExportPage: some View {
        ScrollView {
            UnavailableCapabilityView(
                title: "导入导出尚未接入",
                summary: "当前不会打开文件面板、读取磁盘文件、写入导出包或访问附件目录。",
                nextRequirement: "完成 SQLite / GRDB、附件存储、安全作用域文件访问和导出格式设计。",
                systemImage: "tray.and.arrow.down"
            )
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var languageSpaceUnavailablePage: some View {
        ScrollView {
            UnavailableCapabilityView(
                title: "语言空间切换尚未接入",
                summary: "当前只有一个内存语言空间 preview，不会创建、切换或持久化多语言空间。",
                nextRequirement: "完成语言空间持久化、最近使用空间恢复和多空间选择 UI。",
                systemImage: "text.badge.star"
            )
            .frame(maxWidth: 820, alignment: .leading)
        }
    }
}

struct PadLearningPanelView: View {
    let selectedEntry: LearningEntry?
    let selectedRendering: LearningRendering?
    let memoryItems: [MemoryItem]
    let contentRepository: InMemoryLearningContentRepository
    let onRoute: (PadWorkspaceRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: "学习面板", subtitle: "围绕当前记录生成")
                if let selectedEntry {
                    selectedEntryContent(selectedEntry)
                } else {
                    TextPanel(title: "没有记录", text: "创建第一条生活记录后，这里会展示请求预览、词句提取和练习入口。")
                }
            }
            .padding(22)
        }
        .frame(minWidth: 300, idealWidth: 330, maxWidth: 360, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.paper.opacity(0.58))
    }

    private func selectedEntryContent(_ entry: LearningEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TextPanel(
                title: "当前句讲解",
                text: selectedRendering?.sentences.first?.note ?? "等待生成后显示句子讲解。"
            )
            TextPanel(
                title: "词句提取",
                text: memoryItems
                    .filter { $0.entryID == entry.id }
                    .map(\.text)
                    .joined(separator: ", ")
            )
            CapabilityStatusRow(
                title: "进入练习",
                summary: contentRepository.practiceItems(for: entry.id)
                    .map(\.summary)
                    .joined(separator: " · "),
                status: .mockOnly,
                systemImage: "waveform",
                action: { onRoute(.practice(entry.id)) }
            )
            CapabilityStatusRow(
                title: "空间设置",
                summary: "查看 AI、同步、本地数据和隐私边界的只读说明。",
                status: .mockOnly,
                systemImage: "gearshape",
                action: { onRoute(.settingsList) }
            )
            RequestPreviewCard(entry: entry, rendering: selectedRendering)
        }
    }
}
