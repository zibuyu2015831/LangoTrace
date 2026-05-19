import SwiftUI

struct AIProviderSettingsView: View {
    @State private var draft = AIProviderDraftConfiguration(provider: .openAI)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            textModelSection
            optionalModelSection(
                titleKey: "aiProviderSettings.speechModel.title",
                enabledKey: "aiProviderSettings.speechModel.enable",
                modelTitleKey: "aiProviderSettings.speechModel.modelTitle",
                configuration: speechBinding
            )
            optionalModelSection(
                titleKey: "aiProviderSettings.embeddingModelGroup.title",
                enabledKey: "aiProviderSettings.embeddingModelGroup.enable",
                modelTitleKey: "aiProviderSettings.embeddingModelGroup.modelTitle",
                configuration: embeddingBinding
            )
            actionSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var textModelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AIProviderSectionTitle("aiProviderSettings.textModel.title")
            AIProviderEndpointFields(
                provider: textProviderBinding,
                baseURL: textBaseURLBinding,
                model: textModelBinding,
                modelTitleKey: "aiProviderSettings.textModel.modelTitle"
            )
            AIProviderAPIKeyField(text: textAPIKeyBinding)
            AIProviderCapabilityBoundaryView(
                supportsImageUnderstanding: draft.text.endpoint.provider.capabilities.imageUnderstanding,
                imageUnderstandingEnabled: imageUnderstandingBinding
            )
        }
        .langoPanel()
    }

    private func optionalModelSection(
        titleKey: String,
        enabledKey: String,
        modelTitleKey: String,
        configuration: Binding<AIOptionalModelDraftConfiguration>
    ) -> some View {
        AIProviderOptionalModelSection(
            titleKey: titleKey,
            enabledKey: enabledKey,
            modelTitleKey: modelTitleKey,
            textProvider: draft.text.endpoint.provider,
            configuration: configuration
        )
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
    var statusTitleKey: String {
        if draft.testReadiness == .missingRequiredFields {
            return "aiProviderSettings.saveState.missingRequiredFields"
        }

        if draft.saveState == .mockSavedSecurely {
            return draft.saveState.titleKey
        }

        return "aiProviderSettings.saveState.idle"
    }

    var statusIconName: String {
        if draft.saveState == .mockSavedSecurely {
            return "checkmark.circle"
        }

        if draft.testReadiness == .missingRequiredFields {
            return "exclamationmark.triangle"
        }

        return "lock.circle"
    }

    var statusTone: Color {
        if draft.testReadiness == .missingRequiredFields {
            return LangoTraceDesign.ColorToken.warning
        }

        return LangoTraceDesign.ColorToken.accent
    }

    var textProviderBinding: Binding<AIProviderPreset> {
        Binding(
            get: { draft.text.endpoint.provider },
            set: { draft.text.updateProvider($0) }
        )
    }

    var textBaseURLBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.baseURL },
            set: { draft.text.endpoint.baseURL = $0 }
        )
    }

    var textModelBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.model },
            set: { draft.text.endpoint.model = $0 }
        )
    }

    var textAPIKeyBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.independentCredential.apiKeyDraft },
            set: { draft.text.endpoint.independentCredential.apiKeyDraft = $0 }
        )
    }

    var imageUnderstandingBinding: Binding<Bool> {
        Binding(
            get: { draft.text.imageUnderstandingEnabled },
            set: {
                draft.text.imageUnderstandingEnabled = $0 &&
                    draft.text.endpoint.provider.capabilities.imageUnderstanding
            }
        )
    }

    var speechBinding: Binding<AIOptionalModelDraftConfiguration> {
        Binding(
            get: { draft.speech },
            set: { draft.speech = $0 }
        )
    }

    var embeddingBinding: Binding<AIOptionalModelDraftConfiguration> {
        Binding(
            get: { draft.embedding },
            set: { draft.embedding = $0 }
        )
    }
}
