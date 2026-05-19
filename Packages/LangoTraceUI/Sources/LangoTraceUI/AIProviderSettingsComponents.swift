import SwiftUI

struct AIProviderOptionalModelSection: View {
    let titleKey: String
    let enabledKey: String
    let modelTitleKey: String
    let textProvider: AIProviderPreset
    @Binding var configuration: AIOptionalModelDraftConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                AIProviderSectionTitle(titleKey)
                Spacer(minLength: 0)
                Toggle(isOn: $configuration.isEnabled) {
                    localizedText(enabledKey)
                }
                .labelsHidden()
            }
            if configuration.isEnabled {
                AIProviderEndpointFields(
                    provider: providerBinding,
                    baseURL: baseURLBinding,
                    model: modelBinding,
                    modelTitleKey: modelTitleKey
                )
                credentialReferencePicker
                if configuration.endpoint.credentialReference == .independent {
                    AIProviderAPIKeyField(text: independentAPIKeyBinding)
                }
            }
        }
        .langoPanel()
    }

    private var credentialReferencePicker: some View {
        Picker(selection: credentialReferenceBinding) {
            localizedText("aiProviderSettings.apiKey.useText")
                .tag(AIProviderCredentialReference.textModelCredential)
            localizedText("aiProviderSettings.apiKey.useIndependent")
                .tag(AIProviderCredentialReference.independent)
        } label: {
            localizedText("aiProviderSettings.apiKey.title")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
    }

    private var providerBinding: Binding<AIProviderPreset> {
        Binding(
            get: { configuration.endpoint.provider },
            set: { provider in
                configuration.updateProvider(
                    provider,
                    shareTextCredentialWhenSameProvider: provider == textProvider
                )
            }
        )
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { configuration.endpoint.baseURL },
            set: { configuration.endpoint.baseURL = $0 }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { configuration.endpoint.model },
            set: { configuration.endpoint.model = $0 }
        )
    }

    private var credentialReferenceBinding: Binding<AIProviderCredentialReference> {
        Binding(
            get: { configuration.endpoint.credentialReference },
            set: { configuration.endpoint.credentialReference = $0 }
        )
    }

    private var independentAPIKeyBinding: Binding<String> {
        Binding(
            get: { configuration.endpoint.independentCredential.apiKeyDraft },
            set: { configuration.endpoint.independentCredential.apiKeyDraft = $0 }
        )
    }
}

struct AIProviderEndpointFields: View {
    @Binding var provider: AIProviderPreset
    @Binding var baseURL: String
    @Binding var model: String
    let modelTitleKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AIProviderRowPicker(provider: $provider)
            AIProviderSettingsTextField(
                titleKey: "aiProviderSettings.baseURL.title",
                text: $baseURL,
                keyboardHint: .url
            )
            AIProviderSettingsTextField(
                titleKey: modelTitleKey,
                text: $model,
                keyboardHint: .plain
            )
        }
    }
}

struct AIProviderRowPicker: View {
    @Binding var provider: AIProviderPreset

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            localizedText("aiProviderSettings.provider.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)

            Menu {
                ForEach(AIProviderPreset.allCases) { provider in
                    Button {
                        self.provider = provider
                    } label: {
                        Text(provider.displayName)
                    }
                }
            } label: {
                selectedProviderLabel
            }
            .tint(LangoTraceDesign.ColorToken.accent)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(localizedText("aiProviderSettings.provider.picker"))
            .accessibilityValue(Text(provider.displayName))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
    }

    private var selectedProviderLabel: some View {
        HStack(spacing: 4) {
            Text(provider.displayName)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .truncationMode(.tail)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
        }
        .font(.callout)
        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct AIProviderCapabilityBoundaryView: View {
    let supportsImageUnderstanding: Bool
    @Binding var imageUnderstandingEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIProviderSectionTitle("aiProviderSettings.capabilities.title")
            AIProviderLockedCapabilityRow(
                titleKey: "aiProviderSettings.capability.chat",
                statusKey: "aiProviderSettings.capability.enabled"
            )
            Toggle(isOn: $imageUnderstandingEnabled) {
                localizedText("aiProviderSettings.capability.image")
                    .font(.callout.weight(.semibold))
            }
            .disabled(!supportsImageUnderstanding)
            if !supportsImageUnderstanding {
                localizedText("aiProviderSettings.capability.unsupported")
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
    }
}

private struct AIProviderLockedCapabilityRow: View {
    let titleKey: String
    let statusKey: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            localizedText(titleKey)
                .font(.callout.weight(.semibold))
            Spacer(minLength: 0)
            localizedText(statusKey)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
    }
}

struct AIProviderAPIKeyField: View {
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText("aiProviderSettings.apiKey.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            HStack(spacing: 8) {
                Group {
                    if isVisible {
                        TextField(localizedString("aiProviderSettings.apiKey.placeholder"), text: $text)
                    } else {
                        SecureField(localizedString("aiProviderSettings.apiKey.placeholder"), text: $text)
                    }
                }
                .langoProviderTextInput(keyboardHint: .plain)
                .font(.body.monospaced())

                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .frame(
                            width: LangoTraceDesign.Density.minimumTouchTarget,
                            height: LangoTraceDesign.Density.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .accessibilityLabel(localizedText(visibilityLabelKey))
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .background(LangoTraceDesign.ColorToken.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        }
    }

    private var visibilityLabelKey: String {
        isVisible ? "aiProviderSettings.apiKey.hide" : "aiProviderSettings.apiKey.show"
    }
}

struct AIProviderSectionTitle: View {
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

struct AIProviderSettingsTextField: View {
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

extension View {
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

enum AIProviderKeyboardHint {
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
