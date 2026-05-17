import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PhoneMainView: View {
    let languageSpace: LanguageSpacePreview
    let contentRepository: InMemoryLearningContentRepository

    @State private var selectedTab: PhoneRootTab = .today
    @State private var navigationPath: [PhoneRoute] = []
    @State private var presentedSheet: PhoneSheet?
    @State private var contentRevision = 0

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView(selection: $selectedTab) {
                TodayView(
                    languageSpace: languageSpace,
                    entries: entries,
                    renderingForEntry: rendering(for:),
                    onNewEntry: { presentedSheet = .entryEditor },
                    onSelectEntry: showEntryDetail
                )
                .tabItem { Label(PhoneRootTab.today.title, systemImage: "sun.max") }
                .tag(PhoneRootTab.today)

                EntriesView(
                    languageSpace: languageSpace,
                    entries: entries,
                    onNewEntry: { presentedSheet = .entryEditor },
                    onSelectEntry: showEntryDetail
                )
                .tabItem { Label(PhoneRootTab.entries.title, systemImage: "square.and.pencil") }
                .tag(PhoneRootTab.entries)

                PracticeView(
                    languageSpace: languageSpace,
                    entries: entries,
                    repository: contentRepository,
                    onPractice: { entry in navigationPath.append(.practice(entry.id)) }
                )
                .tabItem { Label(PhoneRootTab.practice.title, systemImage: "waveform") }
                .tag(PhoneRootTab.practice)

                MemoryView(
                    languageSpace: languageSpace,
                    memoryItems: contentRepository.memoryItems(for: languageSpace.id)
                )
                .tabItem { Label(PhoneRootTab.memory.title, systemImage: "archivebox") }
                .tag(PhoneRootTab.memory)

                SettingsView(
                    languageSpace: languageSpace,
                    capabilities: contentRepository.settingsCapabilities(for: languageSpace.id),
                    onSelectCapability: { kind in navigationPath.append(.settings(kind)) }
                )
                .tabItem { Label(PhoneRootTab.settings.title, systemImage: "gearshape") }
                .tag(PhoneRootTab.settings)
            }
            .simultaneousGesture(tabSwipeGesture)
            .phoneTabBarBackground()
            .navigationDestination(for: PhoneRoute.self) { route in
                switch route {
                case let .entryDetail(entryID):
                    if let entry = entry(id: entryID) {
                        EntryDetailView(
                            languageSpace: languageSpace,
                            entry: entry,
                            rendering: rendering(for: entry),
                            practiceItems: contentRepository.practiceItems(for: entry.id),
                            onPractice: { navigationPath.append(.practice(entry.id)) }
                        )
                    }
                case let .practice(entryID):
                    if let entry = entry(id: entryID) {
                        PracticeSessionView(
                            entry: entry,
                            rendering: rendering(for: entry),
                            session: contentRepository.practiceSession(for: entry.id)
                        )
                    }
                case let .settings(kind):
                    if let capability = capability(kind: kind) {
                        SettingsCapabilityDetailView(
                            languageSpace: languageSpace,
                            capability: capability
                        )
                    }
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .entryEditor:
                    EntryEditorView(languageSpace: languageSpace) { title, body in
                        let entry = contentRepository.createEntry(
                            spaceID: languageSpace.id,
                            title: title,
                            body: body,
                            source: .typedText
                        )
                        contentRevision += 1
                        presentedSheet = nil
                        navigationPath.append(.entryDetail(entry.id))
                    }
                }
            }
            .onAppear {
                contentRepository.ensureSeeded(spaceID: languageSpace.id)
                contentRevision += 1
            }
        }
    }

    private var entries: [LearningEntry] {
        _ = contentRevision
        return contentRepository.entries(for: languageSpace.id)
    }

    private func entry(id: String) -> LearningEntry? {
        entries.first { $0.id == id }
    }

    private func rendering(for entry: LearningEntry) -> LearningRendering? {
        contentRepository.rendering(for: entry.id)
    }

    private func capability(kind: SettingsCapability.Kind) -> SettingsCapability? {
        contentRepository
            .settingsCapabilities(for: languageSpace.id)
            .first { $0.kind == kind }
    }

    private func showEntryDetail(_ entry: LearningEntry) {
        contentRepository.selectEntry(id: entry.id, spaceID: languageSpace.id)
        navigationPath.append(.entryDetail(entry.id))
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                selectedTab = selectedTab.tab(
                    horizontalTranslation: Double(value.translation.width),
                    verticalTranslation: Double(value.translation.height)
                )
            }
    }
}

private enum PhoneRoute: Hashable {
    case entryDetail(String)
    case practice(String)
    case settings(SettingsCapability.Kind)
}

private enum PhoneSheet: Identifiable {
    case entryEditor

    var id: String {
        switch self {
        case .entryEditor:
            "entry-editor"
        }
    }
}

private extension View {
    @ViewBuilder
    func phoneTabBarBackground() -> some View {
        #if os(iOS)
            toolbarBackground(LangoTraceDesign.ColorToken.surfaceBase, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        #else
            self
        #endif
    }
}

private struct TodayView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let renderingForEntry: (LearningEntry) -> LearningRendering?
    let onNewEntry: () -> Void
    let onSelectEntry: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            title: "今日",
            languageSpace: languageSpace,
            statusText: "本地优先 · 未配置 AI"
        ) {
            HeroActionCard(languageSpace: languageSpace, onNewEntry: onNewEntry)
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

private struct EntriesView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let onNewEntry: () -> Void
    let onSelectEntry: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            title: "记录",
            languageSpace: languageSpace,
            statusText: "日记 · 照片 · 目标语言写作"
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

private struct PracticeView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let repository: InMemoryLearningContentRepository
    let onPractice: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            title: "练习",
            languageSpace: languageSpace,
            statusText: "\(languageSpace.targetLanguage) 听说读写"
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

private struct MemoryView: View {
    let languageSpace: LanguageSpacePreview
    let memoryItems: [MemoryItem]

    var body: some View {
        PhonePage(
            title: "记忆",
            languageSpace: languageSpace,
            statusText: "词句、相似片段和长期轨迹"
        ) {
            SectionHeader(title: "个人语言记忆", subtitle: "不是孤立单词，而是来自生活上下文的表达")
            ForEach(memoryItems) { item in
                CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
            }
            CompactPanel(title: "向量索引", text: "本地可重建 · 默认不同步", systemImage: "square.stack.3d.up")
        }
    }
}

private struct SettingsView: View {
    let languageSpace: LanguageSpacePreview
    let capabilities: [SettingsCapability]
    let onSelectCapability: (SettingsCapability.Kind) -> Void

    var body: some View {
        PhonePage(
            title: "设置",
            languageSpace: languageSpace,
            statusText: "隐私、同步和 AI 请求由用户掌控"
        ) {
            SectionHeader(title: "当前空间", subtitle: "配置不抢占记录和学习主流程")
            ForEach(capabilities) { capability in
                CapabilityStatusRow(
                    title: capability.kind.title,
                    summary: capability.summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    action: { onSelectCapability(capability.kind) }
                )
            }
        }
    }
}

private struct PhonePage<Content: View>: View {
    let title: String
    let languageSpace: LanguageSpacePreview
    let statusText: String
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
                Button {} label: {
                    Image(systemName: "chevron.down.circle")
                }
                .accessibilityLabel("切换语言空间")
                .accessibilityHint("后续版本将支持多语言空间切换")
            }
        }
        .langoPageBackground()
    }
}
