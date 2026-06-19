import LangoTraceCore
import SwiftUI

struct LanguageSpaceSwitcherPresentation {
    let rows: [LanguageSpaceSwitcherRowPresentation]

    init(spaces: [LanguageSpace], currentSpaceID: String?) {
        let orderedSpaces = spaces.sorted { lhs, rhs in
            switch (lhs.id == currentSpaceID, rhs.id == currentSpaceID) {
            case (true, false):
                return true
            case (false, true):
                return false
            default:
                let lhsDate = lhs.lastOpenedAt ?? lhs.updatedAt
                let rhsDate = rhs.lastOpenedAt ?? rhs.updatedAt
                if lhsDate == rhsDate {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return lhsDate > rhsDate
            }
        }

        rows = orderedSpaces.map { space in
            LanguageSpaceSwitcherRowPresentation(
                space: space,
                isCurrent: space.id == currentSpaceID
            )
        }
    }
}

struct LanguageSpaceSwitcherRowPresentation {
    let space: LanguageSpace
    let isCurrent: Bool

    var isSelectable: Bool {
        !isCurrent
    }

    var selectionID: String? {
        isSelectable ? space.id : nil
    }
}

struct LanguageSpaceSwitcherSheet: View {
    let spaces: [LanguageSpace]
    let currentSpaceID: String?
    let onSelect: (String) -> Void
    let onAdd: (CreateLanguageSpaceInput) -> Void
    let onManage: () -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Destination: Hashable {
        case add
    }

    private var presentation: LanguageSpaceSwitcherPresentation {
        LanguageSpaceSwitcherPresentation(spaces: spaces, currentSpaceID: currentSpaceID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switcherHeader
                rowsPanel
                actionsPanel
                footerText
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .navigationTitle(localizedText("languageSpace.switcher.title"))
        .langoLanguageSpaceInlineNavigationTitle()
        .langoPageBackground()
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case .add:
                LanguageSpaceEditorView(mode: .add, spaces: spaces) { _, input in
                    onAdd(
                        CreateLanguageSpaceInput(
                            nativeLanguageCode: input.nativeLanguageCode,
                            targetLanguageCode: input.targetLanguageCode,
                            level: input.level,
                            displayName: input.displayName
                        )
                    )
                    dismiss()
                }
            }
        }
    }

    private var switcherHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            localizedText("languageSpace.switcher.allSection")
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            localizedText("languageSpace.switcher.headerSummary")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rowsPanel: some View {
        VStack(spacing: 0) {
            if presentation.rows.isEmpty {
                emptyRow
            } else {
                ForEach(Array(presentation.rows.enumerated()), id: \.element.space.id) { index, row in
                    if index > 0 {
                        divider
                    }
                    LanguageSpaceSwitcherRow(row: row) {
                        if let selectionID = row.selectionID {
                            onSelect(selectionID)
                            dismiss()
                        }
                    }
                }
            }
        }
        .langoPanel(padding: 0)
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            localizedText("settings.languageSpace.management.noSpacesTitle")
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            localizedText("settings.languageSpace.management.noSpacesBody")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var actionsPanel: some View {
        VStack(spacing: 0) {
            NavigationLink(value: Destination.add) {
                actionRow(
                    titleKey: "languageSpace.switcher.add",
                    systemImage: "plus.circle.fill",
                    foregroundStyle: LangoTraceDesign.ColorToken.teal
                )
            }
            .buttonStyle(.plain)

            divider

            Button {
                onManage()
                dismiss()
            } label: {
                actionRow(
                    titleKey: "languageSpace.switcher.manage",
                    systemImage: "slider.horizontal.3",
                    foregroundStyle: LangoTraceDesign.ColorToken.textPrimary
                )
            }
            .buttonStyle(.plain)
        }
        .langoPanel(padding: 0)
    }

    private func actionRow(titleKey: String, systemImage: String, foregroundStyle: Color) -> some View {
        Label {
            localizedText(titleKey)
                .font(.body.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(foregroundStyle)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    private var footerText: some View {
        localizedText("languageSpace.switcher.localFirstFootnote")
            .font(.footnote)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private var divider: some View {
        Rectangle()
            .fill(LangoTraceDesign.ColorToken.hairline.opacity(0.65))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

private struct LanguageSpaceSwitcherRow: View {
    let row: LanguageSpaceSwitcherRowPresentation
    let onSelect: () -> Void

    var body: some View {
        Group {
            if row.isSelectable {
                Button(action: onSelect) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(row.isCurrent ? .isSelected : [])
        .accessibilityValue(row.isCurrent ? localizedText("languageSpace.switcher.currentBadge") : Text(""))
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            if row.isCurrent {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(LangoTraceDesign.ColorToken.teal)
                    .frame(width: 4)
                    .frame(maxHeight: 42)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.space.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.space.preview.displayContext)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if row.isCurrent {
                currentPill
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(row.isCurrent ? LangoTraceDesign.ColorToken.surfaceSelected : .clear)
        .contentShape(Rectangle())
    }

    private var currentPill: some View {
        localizedText("languageSpace.switcher.currentBadge")
            .font(.caption.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.teal)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(LangoTraceDesign.ColorToken.paleTeal)
            .clipShape(Capsule())
            .accessibilityHidden(true)
    }
}
