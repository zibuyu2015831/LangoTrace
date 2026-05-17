import LangoTraceCore
import LangoTraceData
import SwiftUI

struct TodayView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let renderingForEntry: (LearningEntry) -> LearningRendering?
    let onNewEntry: () -> Void
    let onPhotoWriting: () -> Void
    let onListenOne: () -> Void
    let onLanguageSpaceAction: () -> Void
    let onSelectEntry: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            title: "今日",
            languageSpace: languageSpace,
            statusText: "本地优先 · 未配置 AI",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            HeroActionCard(
                languageSpace: languageSpace,
                onNewEntry: onNewEntry,
                onPhotoWriting: onPhotoWriting,
                onListenOne: onListenOne
            )
            SectionHeader(title: "最近记录", subtitle: "生活内容会成为之后的听读和跟读材料")
            if entries.isEmpty {
                EmptyEntryPanel(onNewEntry: onNewEntry)
            } else {
                ForEach(entries.prefix(2)) { entry in
                    EntryCard(
                        entry: entry,
                        targetLanguage: languageSpace.targetLanguage,
                        rendering: renderingForEntry(entry),
                        action: { onSelectEntry(entry) }
                    )
                }
            }
        }
    }
}

struct EntriesView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let onNewEntry: () -> Void
    let onLanguageSpaceAction: () -> Void
    let onSelectEntry: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            title: "记录",
            languageSpace: languageSpace,
            statusText: "日记 · 照片 · 目标语言写作",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            HStack {
                SectionHeader(title: "继续记录", subtitle: "每条记录都归入当前语言空间")
                Spacer()
                Button(action: onNewEntry) {
                    Label("新建", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            ForEach(entries) { entry in
                Button {
                    onSelectEntry(entry)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title)
                                .font(.headline)
                            Text("\(entry.sourceTitle) · \(languageSpace.targetLanguage) · \(entry.scene)")
                                .font(.footnote)
                                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                    .langoPanel(padding: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PracticeView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let repository: InMemoryLearningContentRepository
    let onLanguageSpaceAction: () -> Void
    let onPractice: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            title: "练习",
            languageSpace: languageSpace,
            statusText: "\(languageSpace.targetLanguage) 听说读写",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            SectionHeader(title: "从生活记录练起", subtitle: "练习入口与原始记录保持关联")
            if entries.isEmpty {
                CompactPanel(title: "暂无练习", text: "先创建生活记录，再生成本地 mock 练习。", systemImage: "waveform")
            } else {
                ForEach(entries) { entry in
                    let items = repository.practiceItems(for: entry.id)
                    if items.isEmpty {
                        CapabilityStatusRow(
                            title: entry.title,
                            summary: "还没有可练习内容",
                            status: .unavailable,
                            systemImage: "waveform",
                            action: nil
                        )
                    } else {
                        ForEach(items) { item in
                            CapabilityStatusRow(
                                title: item.title,
                                summary: "\(entry.title) · \(item.summary)",
                                status: .mockOnly,
                                systemImage: icon(for: item.kind),
                                action: { onPractice(entry) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func icon(for kind: PracticeItem.Kind) -> String {
        switch kind {
        case .listening:
            "ear"
        case .shadowing:
            "waveform"
        case .dictation:
            "character.cursor.ibeam"
        case .backTranslation:
            "arrow.left.arrow.right"
        }
    }
}

struct MemoryView: View {
    let languageSpace: LanguageSpacePreview
    let memoryItems: [MemoryItem]
    let onLanguageSpaceAction: () -> Void

    var body: some View {
        PhonePage(
            title: "记忆",
            languageSpace: languageSpace,
            statusText: "词句、相似片段和长期轨迹",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            SectionHeader(title: "个人语言记忆", subtitle: "不是孤立单词，而是来自生活上下文的表达")
            ForEach(memoryItems) { item in
                CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
            }
            CompactPanel(title: "向量索引", text: "本地可重建 · 默认不同步", systemImage: "square.stack.3d.up")
        }
    }
}

struct SettingsView: View {
    let languageSpace: LanguageSpacePreview
    let capabilities: [SettingsCapability]
    let onLanguageSpaceAction: () -> Void
    let onSelectCapability: (SettingsCapability.Kind) -> Void

    var body: some View {
        PhonePage(
            title: "设置",
            languageSpace: languageSpace,
            statusText: "隐私、同步和 AI 请求由用户掌控",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            SectionHeader(title: "当前空间", subtitle: "配置不抢占记录和学习主流程")
            ForEach(capabilities) { capability in
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    summary: capability.summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    action: { onSelectCapability(capability.kind) }
                )
            }
        }
    }
}

struct PhonePage<Content: View>: View {
    let title: String
    let languageSpace: LanguageSpacePreview
    let statusText: String
    let onLanguageSpaceAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhoneContextHeader(languageSpace: languageSpace, statusText: statusText)
                content
            }
            .padding(20)
            .padding(.bottom, 92)
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: onLanguageSpaceAction) {
                    Image(systemName: "chevron.down.circle")
                }
                .accessibilityLabel("切换语言空间")
                .accessibilityHint("后续版本将支持多语言空间切换")
            }
        }
        .langoPageBackground()
    }
}
