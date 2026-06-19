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
                accessibilityLabelKey: isTimelineVisible ? "ipad.timeline.hide" : "ipad.timeline.show",
                action: onToggleTimeline
            )
            .keyboardShortcut("[", modifiers: [.command, .option])

            Button(action: onSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    localizedText("pad.search.placeholder")
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    localizedText("capabilityStatus.unavailable")
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
            .accessibilityLabel(localizedText("pad.search.placeholder"))
            .accessibilityHint(localizedText("pad.search.hint"))
            .keyboardShortcut("f", modifiers: .command)

            Button(action: onNewEntry) {
                Label {
                    localizedText("common.newEntry")
                } icon: {
                    Image(systemName: "plus")
                }
                .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.primaryActionFill)
            .keyboardShortcut("n", modifiers: .command)

            LangoPanelToggleButton(
                systemImage: "sidebar.right",
                isActive: isLearningPanelVisible,
                accessibilityLabelKey: isLearningPanelVisible ? "ipad.learningPanel.hide" : "ipad.learningPanel.show",
                action: onToggleLearningPanel
            )
            .keyboardShortcut("]", modifiers: [.command, .option])
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(LangoTraceDesign.ColorToken.paper)
    }
}
