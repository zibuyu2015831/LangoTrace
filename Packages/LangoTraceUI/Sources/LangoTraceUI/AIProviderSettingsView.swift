import SwiftUI

struct AIProviderSettingsView: View {
    @State private var draft = AIProviderDraftConfiguration(provider: .openAI)
    @State private var showsAdvancedModels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            providerSection
            connectionSection
            credentialsSection
            modelSection
            actionSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIProviderSectionTitle("aiProviderSettings.provider.title")
            Picker(selection: providerBinding) {
                ForEach(AIProviderPreset.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            } label: {
                localizedText("aiProviderSettings.provider.picker")
            }
            .pickerStyle(.menu)
            .tint(LangoTraceDesign.ColorToken.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        }
        .langoPanel()
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AIProviderSectionTitle("aiProviderSettings.connection.title")
            AIProviderSettingsTextField(
                titleKey: "aiProviderSettings.baseURL.title",
                text: $draft.baseURL,
                keyboardHint: .url
            )
        }
        .langoPanel()
    }

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AIProviderSectionTitle("aiProviderSettings.credentials.title")
            SecureField(
                localizedString("aiProviderSettings.apiKey.placeholder"),
                text: $draft.apiKeyDraft
            )
            .langoProviderTextInput(keyboardHint: .plain)
            .font(.body.monospaced())
            .padding(12)
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .background(LangoTraceDesign.ColorToken.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        }
        .langoPanel()
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AIProviderSectionTitle("aiProviderSettings.models.title")
            AIProviderSettingsTextField(
                titleKey: "aiProviderSettings.chatModel.title",
                text: $draft.chatModel,
                keyboardHint: .plain
            )
            DisclosureGroup(isExpanded: $showsAdvancedModels) {
                VStack(alignment: .leading, spacing: 12) {
                    if draft.capabilities.embedding {
                        AIProviderSettingsTextField(
                            titleKey: "aiProviderSettings.embeddingModel.title",
                            text: $draft.embeddingModel,
                            keyboardHint: .plain
                        )
                    }
                    if draft.capabilities.tts {
                        AIProviderSettingsTextField(
                            titleKey: "aiProviderSettings.ttsModel.title",
                            text: $draft.ttsModel,
                            keyboardHint: .plain
                        )
                    }
                    capabilitySummary
                }
                .padding(.top, 10)
            } label: {
                localizedText("aiProviderSettings.advancedModels.title")
                    .font(.callout.weight(.semibold))
            }
        }
        .langoPanel()
    }

    private var capabilitySummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText("aiProviderSettings.capabilities.title")
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                AIProviderCapabilityChip(
                    titleKey: "aiProviderSettings.capability.chat",
                    isEnabled: draft.capabilities.chat
                )
                AIProviderCapabilityChip(
                    titleKey: "aiProviderSettings.capability.embedding",
                    isEnabled: draft.capabilities.embedding
                )
                AIProviderCapabilityChip(
                    titleKey: "aiProviderSettings.capability.tts",
                    isEnabled: draft.capabilities.tts
                )
                AIProviderCapabilityChip(
                    titleKey: "aiProviderSettings.capability.image",
                    isEnabled: draft.capabilities.imageUnderstanding
                )
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                draft.saveMockConfiguration()
            } label: {
                Label {
                    localizedText("aiProviderSettings.save.button")
                } icon: {
                    Image(systemName: "lock.shield")
                }
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.testReadiness == .missingRequiredFields)

            Button {
                draft.runMockTest()
            } label: {
                Label {
                    localizedText("aiProviderSettings.testRequest.button")
                } icon: {
                    Image(systemName: "checkmark.seal")
                }
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .buttonStyle(.bordered)
            .disabled(draft.testReadiness == .missingRequiredFields)

            statusPanel
        }
        .langoPanel()
    }

    private var statusPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusIconName)
                .foregroundStyle(statusTone)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 5) {
                localizedText(statusTitleKey)
                    .font(.callout.weight(.semibold))
                localizedText("aiProviderSettings.save.boundary")
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if draft.testState == .mockSucceeded {
                    localizedText("aiProviderSettings.testRequest.boundary")
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(LangoTraceDesign.ColorToken.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
    }
}

private extension AIProviderSettingsView {
    private var statusTitleKey: String {
        if draft.testReadiness == .missingRequiredFields {
            return "aiProviderSettings.saveState.missingRequiredFields"
        }

        if draft.saveState == .mockSavedSecurely {
            return draft.saveState.titleKey
        }

        return "aiProviderSettings.saveState.idle"
    }

    private var statusIconName: String {
        if draft.saveState == .mockSavedSecurely {
            return "checkmark.circle"
        }

        if draft.testReadiness == .missingRequiredFields {
            return "exclamationmark.triangle"
        }

        return "lock.circle"
    }

    private var statusTone: Color {
        if draft.testReadiness == .missingRequiredFields {
            return LangoTraceDesign.ColorToken.warning
        }

        return LangoTraceDesign.ColorToken.accent
    }

    private var providerBinding: Binding<AIProviderPreset> {
        Binding(
            get: { draft.provider },
            set: { draft.provider = $0 }
        )
    }
}

private struct AIProviderSectionTitle: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        localizedText(key)
            .font(.caption.weight(.bold))
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
    }
}

private struct AIProviderSettingsTextField: View {
    let titleKey: String
    @Binding var text: String
    let keyboardHint: AIProviderKeyboardHint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText(titleKey)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            TextField("", text: $text)
                .langoProviderTextInput(keyboardHint: keyboardHint)
                .font(.body.monospaced())
                .padding(12)
                .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
                .background(LangoTraceDesign.ColorToken.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        }
    }
}

private struct AIProviderCapabilityChip: View {
    let titleKey: String
    let isEnabled: Bool

    var body: some View {
        Label {
            localizedText(titleKey)
        } icon: {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "minus.circle")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isEnabled ? LangoTraceDesign.ColorToken.accent : LangoTraceDesign.ColorToken.textSecondary)
        .frame(minHeight: 32)
    }
}

private extension View {
    @ViewBuilder
    func langoProviderTextInput(keyboardHint: AIProviderKeyboardHint) -> some View {
        #if os(iOS)
            textInputAutocapitalization(.never)
                .keyboardType(keyboardHint.keyboardType)
                .autocorrectionDisabled()
        #else
            self
        #endif
    }
}

private enum AIProviderKeyboardHint {
    case plain
    case url

    #if os(iOS)
        var keyboardType: UIKeyboardType {
            switch self {
            case .plain:
                .default
            case .url:
                .URL
            }
        }
    #endif
}
