import SwiftUI

struct PadWorkspaceBar: View {
    let isTimelineVisible: Bool
    let isLearningPanelVisible: Bool
    let onToggleTimeline: () -> Void
    let onToggleLearningPanel: () -> Void
    let onSearch: () -> Void
    let onNewEntry: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            LangoPanelToggleButton(
                systemImage: "sidebar.left",
                isActive: isTimelineVisible,
                accessibilityLabel: isTimelineVisible ? "隐藏时间线" : "显示时间线",
                action: onToggleTimeline
            )

            Button(action: onSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("搜索记录、词句、相似生活片段")
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("未接入")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(LangoTraceDesign.ColorToken.elevatedPaper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索记录、词句、相似生活片段")
            .accessibilityHint("搜索尚未接入，会显示能力边界说明")

            LangoPanelToggleButton(
                systemImage: "sidebar.right",
                isActive: isLearningPanelVisible,
                accessibilityLabel: isLearningPanelVisible ? "隐藏学习面板" : "显示学习面板",
                action: onToggleLearningPanel
            )

            Button(action: onNewEntry) {
                Label("新建记录", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(LangoTraceDesign.ColorToken.paper)
    }
}
