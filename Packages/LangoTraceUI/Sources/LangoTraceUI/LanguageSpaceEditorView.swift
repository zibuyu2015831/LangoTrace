import LangoTraceCore
import SwiftUI

enum LanguageSpaceEditorMode: Identifiable {
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

struct LanguageSpaceEditorView: View {
    let mode: LanguageSpaceEditorMode
    let spaces: [LanguageSpace]
    let onSave: (LanguageSpaceEditorMode, UpdateLanguageSpaceInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var nativeLanguageCode = LearningLanguage.defaultNative.code
    @State private var targetLanguageCode = LearningLanguage.defaultTarget.code
    @State private var level: LanguageLevel = .b1

    var body: some View {
        ZStack {
            LangoTraceDesign.ColorToken.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LanguageSpaceEditorCard(
                        displayName: $displayName,
                        nativeLanguageCode: $nativeLanguageCode,
                        targetLanguageCode: $targetLanguageCode,
                        level: $level
                    )

                    if duplicateNameExists {
                        warningRow("settings.languageSpace.management.duplicateNameWarning")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(editorTitle)
        .langoLanguageSpaceInlineNavigationTitle()
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

    private var editorTitle: Text {
        switch mode {
        case .add:
            localizedText("settings.languageSpace.management.add")
        case .edit:
            localizedText("settings.languageSpace.management.editTitle")
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
        .font(.callout)
        .foregroundStyle(.orange)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LangoTraceDesign.ColorToken.dangerMuted.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.gold.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct LanguageSpaceEditorCard: View {
    @Binding var displayName: String
    @Binding var nativeLanguageCode: String
    @Binding var targetLanguageCode: String
    @Binding var level: LanguageLevel

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LangoTraceDesign.ColorToken.teal)
                .frame(width: 4)
                .padding(.vertical, 18)

            VStack(spacing: 0) {
                LanguageSpaceEditorFieldRow(title: localizedText("settings.languageSpace.management.name")) {
                    TextField(
                        localizedString("settings.languageSpace.management.name"),
                        text: $displayName
                    )
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                }

                editorDivider

                LanguageSpaceEditorFieldRow(title: localizedText("onboarding.nativeLanguage")) {
                    Picker(localizedString("onboarding.nativeLanguage"), selection: $nativeLanguageCode) {
                        ForEach(LearningLanguage.supportedNativeLanguages) { language in
                            Text(language.displayTitle(for: .selectedValue)).tag(language.code)
                        }
                    }
                    .pickerStyle(.menu)
                }

                editorDivider

                LanguageSpaceEditorFieldRow(title: localizedText("onboarding.targetLanguage")) {
                    Picker(localizedString("onboarding.targetLanguage"), selection: $targetLanguageCode) {
                        ForEach(LearningLanguage.targetLanguages(excludingNativeCode: nativeLanguageCode)) { language in
                            Text(language.displayTitle(for: .selectedValue)).tag(language.code)
                        }
                    }
                    .pickerStyle(.menu)
                }

                editorDivider

                LanguageSpaceEditorFieldRow(title: localizedText("onboarding.level.title")) {
                    Picker(localizedString("onboarding.level.title"), selection: $level) {
                        ForEach(LanguageLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }

                editorDivider

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.bubble")
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .padding(.top, 1)
                    localizedText("settings.languageSpace.management.explanationLanguageAdaptsToLevel")
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 10)
            }
            .padding(.leading, 18)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
        }
        .tint(LangoTraceDesign.ColorToken.teal)
        .langoPanel(padding: 0)
        .langoSoftShadow()
    }

    private var editorDivider: some View {
        Rectangle()
            .fill(LangoTraceDesign.ColorToken.hairline.opacity(0.70))
            .frame(height: 1)
            .padding(.leading, 2)
    }
}

private struct LanguageSpaceEditorFieldRow<Content: View>: View {
    let title: Text
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            title
                .font(.body.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Spacer(minLength: 12)

            content
                .font(.body.weight(.medium))
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 56)
    }
}

extension View {
    @ViewBuilder
    func langoEditorSheetPresentation() -> some View {
        #if os(iOS)
            presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        #else
            self
        #endif
    }

    @ViewBuilder
    func langoLanguageSpaceInlineNavigationTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
