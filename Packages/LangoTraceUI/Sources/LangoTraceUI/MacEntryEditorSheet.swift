import LangoTraceCore
import SwiftUI

#if os(macOS)
    struct MacEntryEditorSheet: View {
        let languageSpace: LanguageSpacePreview
        @Binding var hasDraftContent: Bool
        let onCancel: () -> Void
        let onSave: (String, String) throws -> Void

        @State private var title = ""
        @State private var bodyText = ""
        @State private var saveErrorKey: String?
        @FocusState private var focusedField: Field?

        var body: some View {
            VStack(spacing: 0) {
                header
                Divider()
                    .overlay(LangoTraceDesign.ColorToken.hairline)
                content
                Divider()
                    .overlay(LangoTraceDesign.ColorToken.hairline)
                footer
            }
            .onChange(of: title) {
                updateDraftContentFlag()
            }
            .onChange(of: bodyText) {
                updateDraftContentFlag()
            }
            .frame(minWidth: 520, idealWidth: 580, maxWidth: 620)
            .background(LangoTraceDesign.ColorToken.paper)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.sheet, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.sheet, style: .continuous)
                    .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
            }
            .langoSoftShadow()
            .defaultFocus($focusedField, .body)
            .accessibilityLabel(localizedText("entryEditor.title"))
        }

        private var header: some View {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "pencil.and.scribble")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                    .frame(width: 34, height: 34)
                    .background(LangoTraceDesign.ColorToken.paleTeal)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    localizedText("entryEditor.title")
                        .font(.title3.weight(.semibold))
                    Text("\(languageSpace.name) · \(languageSpace.displayContext)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 16) {
                fieldGroup(titleKey: "entryEditor.titleField") {
                    TextField(
                        text: $title,
                        prompt: localizedText("entryEditor.titleField")
                    ) {
                        localizedText("entryEditor.titleField")
                    }
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($focusedField, equals: .title)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(fieldBackground(focusedField == .title))
                }

                fieldGroup(titleKey: "entryEditor.section.content") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $bodyText)
                            .font(.body)
                            .lineSpacing(4)
                            .scrollContentBackground(.hidden)
                            .focused($focusedField, equals: .body)
                            .padding(8)
                            .frame(minHeight: 230)
                            .background(fieldBackground(focusedField == .body))
                            .accessibilityLabel(localizedText("entryEditor.bodyField.accessibilityLabel"))
                            .accessibilityHint(localizedText("entryEditor.bodyField.accessibilityHint"))

                        if bodyText.isEmpty {
                            localizedText("entryEditor.bodyField.accessibilityLabel")
                                .font(.body)
                                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk.opacity(0.62))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                }

                privacyCallout
            }
            .padding(22)
            .background(LangoTraceDesign.ColorToken.elevatedPaper)
        }

        private var privacyCallout: some View {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.privacyLocal)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    localizedText("entryEditor.section.privacy")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    localizedText("entryEditor.privacy.localOnly")
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(LangoTraceDesign.ColorToken.paleTeal.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                    .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
            }
        }

        private var footer: some View {
            HStack(spacing: 12) {
                if let saveErrorKey {
                    localizedText(saveErrorKey)
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.stateError)
                }
                Spacer()
                Button {
                    onCancel()
                } label: {
                    localizedText("common.cancel")
                        .frame(minWidth: 92, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button {
                    do {
                        try onSave(title, bodyText)
                        saveErrorKey = nil
                    } catch {
                        // Keep the draft on screen and surface the failure instead of closing.
                        saveErrorKey = "entryEditor.saveFailed"
                    }
                } label: {
                    localizedText("common.save")
                        .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
                        .frame(minWidth: 92, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(LangoTraceDesign.ColorToken.primaryActionFill)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(LangoTraceDesign.ColorToken.paper)
        }

        private func fieldGroup(
            titleKey: String,
            @ViewBuilder content: () -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                localizedText(titleKey)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                content()
            }
        }

        private func fieldBackground(_ isFocused: Bool) -> some View {
            RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                .fill(LangoTraceDesign.ColorToken.surfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                        .stroke(
                            isFocused
                                ? LangoTraceDesign.ColorToken.accent.opacity(0.45)
                                : LangoTraceDesign.ColorToken.hairline,
                            lineWidth: 1
                        )
                }
        }

        private var canSave: Bool {
            !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private func updateDraftContentFlag() {
            hasDraftContent = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private enum Field: Hashable {
            case title
            case body
        }
    }
#else
    struct MacEntryEditorSheet: View {
        let languageSpace: LanguageSpacePreview
        @Binding var hasDraftContent: Bool
        let onCancel: () -> Void
        let onSave: (String, String) throws -> Void

        var body: some View {
            EmptyView()
        }
    }
#endif
