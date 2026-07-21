import SwiftUI

struct SidebarSectionTitle: View {
    let titleKey: String

    init(_ titleKey: String) {
        self.titleKey = titleKey
    }

    var body: some View {
        LocalizedText(titleKey)
            .font(.caption.weight(.bold))
            .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
    }
}

struct FilterPill: View {
    /// Pills either localize a String Catalog key (status filters) or render
    /// already-resolved display text (scene facet: preset labels localize
    /// upstream, free-form scene text is user content shown verbatim and must
    /// never be routed through a localization lookup).
    private enum TitleSource {
        case key(String)
        case text(String)
    }

    private let title: TitleSource
    let count: String
    let active: Bool
    let action: () -> Void
    @State private var isHovered = false

    init(titleKey: String, count: String, active: Bool, action: @escaping () -> Void) {
        title = .key(titleKey)
        self.count = count
        self.active = active
        self.action = action
    }

    init(text: String, count: String, active: Bool, action: @escaping () -> Void) {
        title = .text(text)
        self.count = count
        self.active = active
        self.action = action
    }

    private var titleView: Text {
        switch title {
        case let .key(titleKey):
            localizedText(titleKey)
        case let .text(text):
            Text(text)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                titleView
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
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // Keep the pill visual while extending the hit area to the minimum touch target.
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: action) {
                titleView
            }
        }
        .accessibilityLabel(titleView)
        .accessibilityValue(
            active
                ? localizedString("accessibility.selectedCount", count)
                : localizedString("accessibility.unselectedCount", count)
        )
    }

    private var backgroundColor: Color {
        if active {
            return LangoTraceDesign.ColorToken.deepTeal
        }

        return isHovered ? LangoTraceDesign.ColorToken.surfaceRaised : LangoTraceDesign.ColorToken.elevatedPaper
    }
}

struct PadRouteButton: View {
    let titleKey: String
    let systemImage: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                localizedText(titleKey)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .padding(.horizontal, 12)
            .foregroundStyle(active ? LangoTraceDesign.ColorToken.whiteInk : LangoTraceDesign.ColorToken.ink)
            .background(active ? LangoTraceDesign.ColorToken.deepTeal : LangoTraceDesign.ColorToken.elevatedPaper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // Keep the row visual while extending the hit area to the minimum touch target.
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedText(titleKey))
        .accessibilityValue(localizedText(active ? "accessibility.selected" : "accessibility.unselected"))
    }
}

struct SectionCaption: View {
    let titleKey: String
    let subtitleKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LocalizedText(titleKey)
                .font(.headline)
            LocalizedText(subtitleKey)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
    }
}

struct EmptyWorkspacePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                LocalizedText("entry.empty.title")
            } icon: {
                Image(systemName: "square.and.pencil")
            }
            .font(.headline)
            LocalizedText("ipad.emptyWorkspace.body")
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .langoPanel()
    }
}
