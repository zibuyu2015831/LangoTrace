import SwiftUI

struct SidebarSectionTitle: View {
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

struct FilterPill: View {
    let title: String
    let count: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(count)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        active ? LangoTraceDesign.ColorToken.whiteInk : LangoTraceDesign.ColorToken.mutedInk
                    )
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(active ? LangoTraceDesign.ColorToken.whiteInk : LangoTraceDesign.ColorToken.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(active ? LangoTraceDesign.ColorToken.deepTeal : LangoTraceDesign.ColorToken.elevatedPaper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(active ? "当前选中，\(count) 条" : "未选中，\(count) 条")
    }
}

struct PadRouteButton: View {
    let title: String
    let systemImage: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, 12)
                .foregroundStyle(active ? LangoTraceDesign.ColorToken.whiteInk : LangoTraceDesign.ColorToken.ink)
                .background(active ? LangoTraceDesign.ColorToken.deepTeal : LangoTraceDesign.ColorToken.elevatedPaper)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(active ? "当前选中" : "未选中")
    }
}

struct SectionCaption: View {
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

struct EmptyWorkspacePanel: View {
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
