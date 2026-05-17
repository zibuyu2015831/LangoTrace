import LangoTraceCore
import SwiftUI

struct PadMainView: View {
    let languageSpace: LanguageSpacePreview

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTimelineVisible = true
    @State private var isLearningPanelVisible = true

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
                SideItem(title: "雨天咖啡馆", subtitle: "照片写作 · \(languageSpace.targetLanguage) · 今天", active: true)
                SideItem(title: "写给朋友的感谢", subtitle: "正式表达 · 昨天", active: false)
                SideItem(title: "会议复盘", subtitle: "职场表达 · 本周", active: false)
            }

            SidebarSectionTitle("筛选")
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                FilterPill(title: "全部记录", count: "128", active: true)
                FilterPill(title: "照片写作", count: "16", active: false)
                FilterPill(title: "待练习", count: "7", active: false)
                FilterPill(title: "已入记忆", count: "42", active: false)
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
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("雨天咖啡馆")
                        .font(.system(.largeTitle, design: .default, weight: .semibold))
                    Text("把中文生活记录转换为 \(languageSpace.targetLanguage) 学习材料，支持逐句朗读、解释、跟读、听写和回译。")
                        .font(.body)
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 14) {
                    TextPanel(
                        title: "母语记录",
                        text: "今天在咖啡馆坐了很久。外面一直下小雨，我没有急着回家，只是听着雨声，看窗外的人来来往往。"
                    )
                    TextPanel(
                        title: "目标语言",
                        text: """
                        I spent a long time at the cafe today. It kept drizzling outside, \
                        and I was in no hurry to go home. I just listened to the rain and \
                        watched people passing by outside the window.
                        """
                    )
                }

                AudioPanel()

                VStack(alignment: .leading, spacing: 10) {
                    SectionCaption(title: "逐句练习", subtitle: "从真实记录进入听、读、跟读和回译")
                    SentenceRow(
                        index: 1,
                        text: "I spent a long time at the cafe today.",
                        translation: "今天在咖啡馆坐了很久。"
                    )
                    SentenceRow(
                        index: 2,
                        text: "I just listened to the rain and watched people passing by outside the window.",
                        translation: "我只是听着雨声，看窗外的人来来往往。"
                    )
                }
            }
            .padding(26)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }

    private var learningPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: "学习面板", subtitle: "围绕当前记录生成")
                TextPanel(title: "当前句讲解", text: "spent a long time 比 stayed for a long time 更自然地表达“度过一段时间”。")
                TextPanel(
                    title: "词句提取",
                    text: "drizzling, in no hurry, listened to the rain, watched people passing by."
                )
                TextPanel(title: "练习入口", text: "听写 3 句 · 回译 3 句 · 跟读录音 2 轮。")
                TextPanel(title: "相似生活片段", text: "去年写过“在车站等雨停”，可复用 listening to the rain。")
                RequestPreviewPanel()
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

struct SideItem: View {
    let title: String
    let subtitle: String
    let active: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(active ? LangoTraceDesign.ColorToken.teal : LangoTraceDesign.ColorToken.hairline)
                .frame(width: 8, height: 8)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? LangoTraceDesign.ColorToken.elevatedPaper : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(active ? LangoTraceDesign.ColorToken.teal.opacity(0.35) : .clear, lineWidth: 1)
        }
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

struct TextPanel: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .langoPanel()
    }
}

struct AudioPanel: View {
    private static let waveformHeights = [24, 38, 28, 46, 40, 32, 26, 38, 46, 20]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("朗读音频", systemImage: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                Spacer()
                Text("0.85x")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            HStack(alignment: .center, spacing: 5) {
                ForEach(Self.waveformHeights.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LangoTraceDesign.ColorToken.teal.opacity(0.45))
                        .frame(width: 8, height: CGFloat(Self.waveformHeights[index]))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(LangoTraceDesign.ColorToken.paleTeal)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .langoPanel()
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

private struct SentenceRow: View {
    let index: Int
    let text: String
    let translation: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(LangoTraceDesign.ColorToken.paleTeal)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(translation)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                Text(text)
                    .font(.headline)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("听") {}
                    .buttonStyle(.bordered)
                Button("练") {}
                    .buttonStyle(.bordered)
            }
        }
        .langoPanel()
    }
}

private struct RequestPreviewPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("请求预览", systemImage: "eye")
                .font(.headline)
            Text("即将发送：目标语言文本、用户选中的照片摘要、相似记忆 3 条。")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            Divider()
            Text("不会发送：本地数据库、完整照片库、API Key、未选中的历史记录。")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
        .langoPanel()
    }
}
