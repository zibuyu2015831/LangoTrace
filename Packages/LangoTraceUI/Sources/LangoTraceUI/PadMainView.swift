import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PadMainView: View {
    let languageSpace: LanguageSpacePreview
    let contentRepository: InMemoryLearningContentRepository

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTimelineVisible = true
    @State private var isLearningPanelVisible = true
    @State private var selectedEntryID: String?

    var body: some View {
        VStack(spacing: 0) {
            PadWorkspaceBar(
                isTimelineVisible: isTimelineVisible,
                isLearningPanelVisible: isLearningPanelVisible,
                onToggleTimeline: { isTimelineVisible.toggle() },
                onToggleLearningPanel: { isLearningPanelVisible.toggle() }
            )
            Divider()
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    if isTimelineVisible {
                        sidebar
                            .transition(panelTransition(edge: .leading))
                            .simultaneousGesture(panelGesture(workspaceWidth: proxy.size.width))
                        Divider()
                    }
                    writingDesk
                    if isLearningPanelVisible {
                        Divider()
                        learningPanel
                            .transition(panelTransition(edge: .trailing))
                            .simultaneousGesture(
                                panelGesture(
                                    workspaceWidth: proxy.size.width,
                                    startXOffset: max(0, proxy.size.width - 360)
                                )
                            )
                    }
                }
                .overlay(alignment: .leading) {
                    if !isTimelineVisible {
                        edgeGestureZone(workspaceWidth: proxy.size.width)
                    }
                }
                .overlay(alignment: .trailing) {
                    if !isLearningPanelVisible {
                        edgeGestureZone(
                            workspaceWidth: proxy.size.width,
                            startXOffset: max(0, proxy.size.width - 32)
                        )
                    }
                }
            }
        }
        .langoPageBackground()
        .animation(panelAnimation, value: isTimelineVisible)
        .animation(panelAnimation, value: isLearningPanelVisible)
        .onAppear {
            contentRepository.ensureSeeded(spaceID: languageSpace.id)
            selectedEntryID = selectedEntryID ?? contentRepository.selectedEntry(for: languageSpace.id)?.id
        }
    }

    private var entries: [LearningEntry] {
        contentRepository.entries(for: languageSpace.id)
    }

    private var selectedEntry: LearningEntry? {
        if let selectedEntryID {
            if let entry = entries.first(where: { $0.id == selectedEntryID }) {
                return entry
            }
        }

        return contentRepository.selectedEntry(for: languageSpace.id)
    }

    private var selectedRendering: LearningRendering? {
        guard let selectedEntry else {
            return nil
        }

        return contentRepository.rendering(for: selectedEntry.id)
    }

    private var panelAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private func panelTransition(edge: Edge) -> AnyTransition {
        reduceMotion ? .identity : .move(edge: edge).combined(with: .opacity)
    }

    private func edgeGestureZone(workspaceWidth: CGFloat, startXOffset: CGFloat = 0) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: 32)
            .gesture(panelGesture(workspaceWidth: workspaceWidth, startXOffset: startXOffset))
    }

    private func panelGesture(workspaceWidth: CGFloat, startXOffset: CGFloat = 0) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                let context = PadPanelGestureContext(
                    startX: startXOffset + value.startLocation.x,
                    translationX: value.translation.width,
                    translationY: value.translation.height,
                    workspaceWidth: workspaceWidth,
                    isTimelineVisible: isTimelineVisible,
                    isLearningPanelVisible: isLearningPanelVisible
                )

                guard let action = PadPanelGestureAction.action(in: context) else {
                    return
                }

                applyPanelGestureAction(action)
            }
    }

    private func applyPanelGestureAction(_ action: PadPanelGestureAction) {
        switch action {
        case .showTimeline:
            isTimelineVisible = true
        case .hideTimeline:
            isTimelineVisible = false
        case .showLearningPanel:
            isLearningPanelVisible = true
        case .hideLearningPanel:
            isLearningPanelVisible = false
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            SidebarSectionTitle("时间线")
            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    EntryTimelineRow(
                        entry: entry,
                        targetLanguage: languageSpace.targetLanguage,
                        isSelected: entry.id == selectedEntry?.id
                    ) {
                        selectedEntryID = entry.id
                        contentRepository.selectEntry(id: entry.id, spaceID: languageSpace.id)
                    }
                }
            }

            SidebarSectionTitle("筛选")
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                FilterPill(title: "全部记录", count: "\(entries.count)", active: true)
                FilterPill(
                    title: "照片写作",
                    count: "\(entries.count(where: { $0.source == .photoWriting }))",
                    active: false
                )
                FilterPill(
                    title: "待练习",
                    count: "\(entries.count(where: { $0.practiceSummary.contains("待") }))",
                    active: false
                )
                FilterPill(
                    title: "已入记忆",
                    count: "\(contentRepository.memoryItems(for: languageSpace.id).count)",
                    active: false
                )
            }

            Spacer()

            LanguageSpaceFooter(
                languageSpace: languageSpace,
                aiStatus: .notConfigured,
                syncStatus: .off,
                isCompact: false
            )
        }
        .padding(22)
        .frame(minWidth: 240, idealWidth: 270, maxWidth: 300, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.paper.opacity(0.72))
    }

    private var writingDesk: some View {
        ScrollView {
            if let selectedEntry {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedEntry.title)
                            .font(.system(.largeTitle, design: .default, weight: .semibold))
                        Text("把中文生活记录转换为 \(languageSpace.targetLanguage) 学习材料，支持逐句朗读、解释和练习。")
                            .font(.body)
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .top, spacing: 14) {
                        TextPanel(title: "母语记录", text: selectedEntry.body)
                        TextPanel(title: "目标语言", text: selectedRendering?.targetText ?? "等待生成")
                    }

                    AudioPanel()

                    VStack(alignment: .leading, spacing: 10) {
                        SectionCaption(title: "逐句练习", subtitle: "从真实记录进入听、读、跟读和回译")
                        ForEach(
                            Array((selectedRendering?.sentences ?? []).enumerated()),
                            id: \.element.id
                        ) { index, sentence in
                            SentencePairView(index: index + 1, sentence: sentence) {}
                        }
                    }
                }
                .padding(26)
                .frame(maxWidth: 820, alignment: .leading)
            } else {
                EmptyWorkspacePanel()
                    .padding(26)
            }
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }

    private var learningPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: "学习面板", subtitle: "围绕当前记录生成")
                if let selectedEntry {
                    TextPanel(
                        title: "当前句讲解",
                        text: selectedRendering?.sentences.first?.note ?? "等待生成后显示句子讲解。"
                    )
                    TextPanel(
                        title: "词句提取",
                        text: contentRepository.memoryItems(for: languageSpace.id)
                            .filter { $0.entryID == selectedEntry.id }
                            .map(\.text)
                            .joined(separator: ", ")
                    )
                    TextPanel(
                        title: "练习入口",
                        text: contentRepository.practiceItems(for: selectedEntry.id)
                            .map(\.summary)
                            .joined(separator: " · ")
                    )
                    RequestPreviewCard(entry: selectedEntry, rendering: selectedRendering)
                } else {
                    TextPanel(title: "没有记录", text: "创建第一条生活记录后，这里会展示请求预览、词句提取和练习入口。")
                }
            }
            .padding(22)
        }
        .frame(minWidth: 300, idealWidth: 330, maxWidth: 360, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.paper.opacity(0.58))
    }
}

private struct SidebarSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
    }
}

private struct FilterPill: View {
    let title: String
    let count: String
    let active: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(count)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? LangoTraceDesign.ColorToken.whiteInk : LangoTraceDesign.ColorToken.mutedInk)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(active ? LangoTraceDesign.ColorToken.whiteInk : LangoTraceDesign.ColorToken.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(active ? LangoTraceDesign.ColorToken.deepTeal : LangoTraceDesign.ColorToken.elevatedPaper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SectionCaption: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
    }
}

private struct EmptyWorkspacePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("还没有记录", systemImage: "square.and.pencil")
                .font(.headline)
            Text("创建第一条生活记录后，中间工作台会显示母语记录、目标语言 mock rendering 和逐句练习。")
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .langoPanel()
    }
}
