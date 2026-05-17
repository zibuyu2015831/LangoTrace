import LangoTraceCore
import LangoTraceData
import SwiftUI

struct MacWorkspaceContentView: View {
    let selectedSection: MacWorkspaceSection
    let route: MacWorkspaceRoute
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let selectedEntryID: String?
    let selectedEntry: LearningEntry?
    let selectedRendering: LearningRendering?
    let memoryItems: [MemoryItem]
    let settingsCapabilities: [SettingsCapability]
    let contentRepository: InMemoryLearningContentRepository
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onShowEntry: (LearningEntry) -> Void
    let onRoute: (MacWorkspaceRoute) -> Void

    var body: some View {
        sectionContent
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch route {
        case .overview:
            overviewContent
        case let .entryDetail(entryID):
            entryDetail(entryID: entryID)
        case let .practice(entryID):
            practice(entryID: entryID)
        case let .settings(kind):
            settingDetail(kind: kind)
        case let .unavailable(kind):
            macUnavailableView(kind: kind)
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        switch selectedSection {
        case .today:
            todayContent
        case .entries:
            entriesContent
        case .practice:
            practiceContent
        case .memory:
            memoryContent
        case .importExport:
            macUnavailableView(kind: "import-export")
        case .settings:
            settingsContent
        }
    }

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedEntry {
                EntryDetailView(
                    languageSpace: languageSpace,
                    entry: selectedEntry,
                    rendering: selectedRendering,
                    practiceItems: contentRepository.practiceItems(for: selectedEntry.id),
                    onPractice: { onRoute(.practice(selectedEntry.id)) }
                )
            } else {
                CompactPanel(title: "还没有记录", text: "创建第一条生活记录后，这里会显示请求预览和学习材料。", systemImage: "square.and.pencil")
            }
            HStack(alignment: .top, spacing: 14) {
                CapabilityStatusRow(
                    title: "搜索与筛选",
                    summary: "后续接 SQLite FTS5 与本地向量索引；当前不会查询真实数据库。",
                    status: .unavailable,
                    systemImage: "magnifyingglass",
                    action: { onRoute(.unavailable("search")) }
                )
                CapabilityStatusRow(
                    title: "批量导入",
                    summary: "拖入 Markdown、图片或音频前，需要先完成本地数据层和附件存储。",
                    status: .unavailable,
                    systemImage: "tray.and.arrow.down",
                    action: { onRoute(.unavailable("import-export")) }
                )
            }
        }
    }

    private var entriesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "记录库", subtitle: "当前为 Local Mock 列表，后续接 SQLite / FTS。")
            ForEach(entries) { entry in
                EntryTimelineRow(
                    entry: entry,
                    targetLanguage: languageSpace.targetLanguage,
                    isSelected: entry.id == selectedEntryID,
                    action: { onShowEntry(entry) }
                )
            }
        }
    }

    private var practiceContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "练习", subtitle: "从生活记录进入听读、跟读、听写和回译。")
            ForEach(entries) { entry in
                let items = contentRepository.practiceItems(for: entry.id)
                if items.isEmpty {
                    CapabilityStatusRow(
                        title: entry.title,
                        summary: "这条记录还没有 mock rendering，暂不能进入练习。",
                        status: .unavailable,
                        systemImage: "waveform",
                        action: nil
                    )
                } else {
                    practiceItems(items, for: entry)
                }
            }
        }
    }

    private func practiceItems(_ items: [PracticeItem], for entry: LearningEntry) -> some View {
        ForEach(items) { item in
            CapabilityStatusRow(
                title: item.title,
                summary: "\(entry.title) · \(item.summary)",
                status: .mockOnly,
                systemImage: "waveform",
                action: { onRoute(.practice(entry.id)) }
            )
        }
    }

    private var memoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "词句记忆", subtitle: "记忆项来自生活记录上下文，向量索引仍为未接入。")
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
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "设置", subtitle: "当前只读说明能力边界，不保存真实配置。")
            ForEach(settingsCapabilities) { capability in
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    localizedSummaryKey: settingsCapabilityDetailLocalizationKeys(for: capability.kind).summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    action: { onRoute(.settings(capability.kind)) }
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
            CompactPanel(title: "记录不存在", text: "请选择记录库中的其他生活记录。", systemImage: "exclamationmark.circle")
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
            CompactPanel(title: "练习不可用", text: "请选择一条已有记录后再进入练习。", systemImage: "waveform")
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
            CompactPanel(title: "设置项不存在", text: "请选择侧边栏中的设置项。", systemImage: "gearshape")
        }
    }

    private func macUnavailableView(kind: String) -> some View {
        let content = MacUnavailableContent(kind: kind)
        return UnavailableCapabilityView(
            title: content.title,
            summary: content.summary,
            nextRequirement: content.nextRequirement,
            systemImage: content.systemImage
        )
    }
}
