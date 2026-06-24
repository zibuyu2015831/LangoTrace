import LangoTraceCore
import SwiftUI

struct LanguageSpaceManagementView: View {
    let spaces: [LanguageSpace]
    let currentSpaceID: String?
    let onAdd: (CreateLanguageSpaceInput) -> Void
    let onSelect: (String) -> Void
    let onUpdate: (String, UpdateLanguageSpaceInput) -> Void
    let onDelete: (String) -> Void

    @State private var editorMode: LanguageSpaceEditorMode?
    @State private var pendingDelete: LanguageSpace?

    var body: some View {
        List {
            allSpacesSection
        }
        .navigationTitle(localizedText("settings.languageSpace.management.title"))
        .langoLanguageSpaceInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorMode = .add
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(localizedText("settings.languageSpace.management.add"))
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                LanguageSpaceEditorView(
                    mode: mode,
                    spaces: spaces,
                    onSave: { mode, input in
                        switch mode {
                        case .add:
                            onAdd(
                                CreateLanguageSpaceInput(
                                    nativeLanguageCode: input.nativeLanguageCode,
                                    targetLanguageCode: input.targetLanguageCode,
                                    level: input.level,
                                    displayName: input.displayName
                                )
                            )
                        case let .edit(space):
                            onUpdate(space.id, input)
                        }
                        editorMode = nil
                    }
                )
            }
            .langoEditorSheetPresentation()
        }
        .confirmationDialog(
            localizedString("settings.languageSpace.management.deleteTitle"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(localizedString("settings.languageSpace.management.delete"), role: .destructive) {
                if let pendingDelete {
                    onDelete(pendingDelete.id)
                }
                pendingDelete = nil
            }
            Button(localizedString("common.cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(deleteMessage)
        }
        .scrollContentBackground(.hidden)
        .langoPageBackground()
    }

    private var allSpacesSection: some View {
        Section {
            if spaces.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    localizedText("settings.languageSpace.management.noSpacesTitle")
                        .font(.headline)
                    localizedText("settings.languageSpace.management.noSpacesBody")
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(displayedSpaces) { space in
                    Button {
                        onSelect(space.id)
                    } label: {
                        LanguageSpaceManagementRow(space: space, isCurrent: space.id == currentSpaceID)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        space.id == currentSpaceID
                            ? LangoTraceDesign.ColorToken.surfaceSelected
                            : LangoTraceDesign.ColorToken.elevatedPaper
                    )
                    .contextMenu {
                        Button {
                            editorMode = .edit(space)
                        } label: {
                            Label(localizedString("settings.languageSpace.management.edit"), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            pendingDelete = space
                        } label: {
                            Label(localizedString("settings.languageSpace.management.delete"), systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            editorMode = .edit(space)
                        } label: {
                            Label(localizedString("settings.languageSpace.management.edit"), systemImage: "pencil")
                        }
                        .tint(LangoTraceDesign.ColorToken.teal)
                        Button(role: .destructive) {
                            pendingDelete = space
                        } label: {
                            Label(localizedString("settings.languageSpace.management.delete"), systemImage: "trash")
                        }
                        .accessibilityLabel(
                            Text(localizedString("settings.languageSpace.management.delete") + " " + space.displayName)
                        )
                    }
                }
            }
        } header: {
            localizedText("settings.languageSpace.management.allSection")
        }
    }

    private var displayedSpaces: [LanguageSpace] {
        guard let currentSpaceID,
              let currentIndex = spaces.firstIndex(where: { $0.id == currentSpaceID })
        else {
            return spaces
        }
        var orderedSpaces = spaces
        let current = orderedSpaces.remove(at: currentIndex)
        orderedSpaces.insert(current, at: 0)
        return orderedSpaces
    }

    private var deleteMessage: String {
        guard let pendingDelete else {
            return localizedString("settings.languageSpace.management.deleteMessage")
        }
        if spaces.count <= 1 {
            return localizedString("settings.languageSpace.management.deleteLastSpaceMessage")
        }
        if pendingDelete.id == currentSpaceID {
            return localizedString("settings.languageSpace.management.deleteCurrentFallbackMessage")
        }
        return localizedString("settings.languageSpace.management.deleteMessage")
    }
}

private struct LanguageSpaceManagementRow: View {
    let space: LanguageSpace
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isCurrent {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(LangoTraceDesign.ColorToken.teal)
                    .frame(width: 4)
                    .frame(maxHeight: 42)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(space.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(space.preview.displayContext)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if isCurrent {
                currentPill
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityValue(isCurrent ? localizedText("settings.languageSpace.management.currentBadge") : Text(""))
    }

    private var currentPill: some View {
        localizedText("settings.languageSpace.management.currentBadge")
            .font(.caption.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.teal)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(LangoTraceDesign.ColorToken.paleTeal)
            .clipShape(Capsule())
            .accessibilityHidden(true)
    }
}
