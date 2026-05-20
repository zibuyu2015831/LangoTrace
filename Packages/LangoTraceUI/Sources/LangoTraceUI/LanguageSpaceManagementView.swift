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
            currentSection
            allSpacesSection
            guidanceSection
        }
        .navigationTitle(localizedText("settings.languageSpace.management.title"))
        .langoInlineNavigationTitle()
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
        .langoPageBackground()
    }

    private var currentSection: some View {
        Section {
            if let current = spaces.first(where: { $0.id == currentSpaceID }) {
                LanguageSpaceManagementRow(space: current, isCurrent: true)
            } else {
                localizedText("settings.languageSpace.management.selectSpacePrompt")
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        } header: {
            localizedText("settings.languageSpace.management.currentSection")
        }
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
                ForEach(spaces) { space in
                    Button {
                        onSelect(space.id)
                    } label: {
                        LanguageSpaceManagementRow(space: space, isCurrent: space.id == currentSpaceID)
                    }
                    .id(space.updatedAt)
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editorMode = .edit(space)
                        } label: {
                            Label(localizedString("settings.languageSpace.management.rename"), systemImage: "pencil")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            editorMode = .edit(space)
                        } label: {
                            Label(localizedString("settings.languageSpace.management.rename"), systemImage: "pencil")
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

    private var guidanceSection: some View {
        Section {
            localizedText("settings.languageSpace.management.sameTargetLanguageWarning")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            localizedText("settings.languageSpace.management.deleteMessage")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
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
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                    .accessibilityLabel(localizedText("settings.languageSpace.management.currentBadge"))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

private enum LanguageSpaceEditorMode: Identifiable {
    case add
    case edit(LanguageSpace)

    var id: String {
        switch self {
        case .add:
            "add"
        case let .edit(space):
            "edit-\(space.id)"
        }
    }

    var editedSpace: LanguageSpace? {
        if case let .edit(space) = self {
            space
        } else {
            nil
        }
    }
}

private struct LanguageSpaceEditorView: View {
    let mode: LanguageSpaceEditorMode
    let spaces: [LanguageSpace]
    let onSave: (LanguageSpaceEditorMode, UpdateLanguageSpaceInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var nativeLanguageCode = LearningLanguage.defaultNative.code
    @State private var targetLanguageCode = LearningLanguage.defaultTarget.code
    @State private var level: LanguageLevel = .b1

    var body: some View {
        Form {
            Section {
                TextField(
                    localizedString("settings.languageSpace.management.name"),
                    text: $displayName
                )
                Picker(localizedString("onboarding.nativeLanguage.title"), selection: $nativeLanguageCode) {
                    ForEach(LearningLanguage.supportedNativeLanguages) { language in
                        Text(language.displayTitle(for: .selectedValue)).tag(language.code)
                    }
                }
                Picker(localizedString("onboarding.targetLanguage.title"), selection: $targetLanguageCode) {
                    ForEach(LearningLanguage.targetLanguages(excludingNativeCode: nativeLanguageCode)) { language in
                        Text(language.displayTitle(for: .selectedValue)).tag(language.code)
                    }
                }
                Picker(localizedString("onboarding.level.title"), selection: $level) {
                    ForEach(LanguageLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }

            if duplicateNameExists {
                warningRow("settings.languageSpace.management.duplicateNameWarning")
            }
            if sameTargetLanguageExists {
                warningRow("settings.languageSpace.management.sameTargetLanguageWarning")
            }
        }
        .navigationTitle(editorTitle)
        .langoInlineNavigationTitle()
        .onAppear(perform: populateFromEditedSpace)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(localizedString("common.cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(localizedString("common.save")) {
                    onSave(
                        mode,
                        UpdateLanguageSpaceInput(
                            nativeLanguageCode: nativeLanguageCode,
                            targetLanguageCode: targetLanguageCode,
                            level: level,
                            displayName: displayName
                        )
                    )
                }
            }
        }
    }

    private var duplicateNameExists: Bool {
        let normalizedName = CreateLanguageSpaceInput.normalizedDisplayName(displayName)
        return !normalizedName.isEmpty && spaces.contains { space in
            space.id != mode.editedSpace?.id && space.displayNameNormalized == normalizedName
        }
    }

    private var sameTargetLanguageExists: Bool {
        spaces.contains { space in
            space.id != mode.editedSpace?.id && space.targetLanguageCode == targetLanguageCode
        }
    }

    private var editorTitle: Text {
        switch mode {
        case .add:
            localizedText("settings.languageSpace.management.add")
        case .edit:
            localizedText("settings.languageSpace.management.rename")
        }
    }

    private func populateFromEditedSpace() {
        guard let space = mode.editedSpace else {
            return
        }
        displayName = space.displayName
        nativeLanguageCode = space.nativeLanguageCode
        targetLanguageCode = space.targetLanguageCode
        level = space.level
    }

    private func warningRow(_ key: String) -> some View {
        Label {
            localizedText(key)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(.orange)
    }
}

private extension View {
    @ViewBuilder
    func langoInlineNavigationTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
