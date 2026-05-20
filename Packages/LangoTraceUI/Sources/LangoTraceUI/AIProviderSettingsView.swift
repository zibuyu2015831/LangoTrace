import Foundation
import LangoTraceCore
import SwiftUI

struct AIProviderSettingsView: View {
    @Environment(\.aiProviderSettingsActions) private var actions
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
        .task {
            await loadSavedConfiguration()
        }
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
                saveConfiguration()
            } label: {
                Label {
                    localizedText(saveButtonTitleKey)
                } icon: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "lock.shield")
                    }
                }
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.testReadiness == .missingRequiredFields || isSaving)

            Button {
                validateConfiguration()
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
            .disabled(draft.testReadiness == .missingRequiredFields || isSaving)

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
    @MainActor
    func loadSavedConfiguration() async {
        guard let profile = try? await actions.loadDefaultProfile() else {
            return
        }
        draft.applyLoadedProfile(profile)
    }

    func saveConfiguration() {
        Task { @MainActor in
            let operationID = actions.operationIDGenerator()
            draft.saveState = .saving
            await recordSaveEvent(
                .aiProviderSettingsSaveTapped,
                outcome: .started,
                operationID: operationID
            )
            do {
                let input = try draft.makeProfileSaveInput()
                await recordSaveEvent(
                    .aiProviderSettingsSaveStarted,
                    outcome: .started,
                    operationID: operationID
                )
                let profile = try await actions.saveDefaultProfile(input, operationID)
                draft.applySavedProfile(profile)
                await recordSaveEvent(
                    .aiProviderSettingsSaveSucceeded,
                    outcome: .succeeded,
                    operationID: operationID
                )
            } catch {
                let failure = AIProviderSaveFailureDisplay(error: error)
                draft.saveState = .failed(failure)
                await recordSaveEvent(
                    .aiProviderSettingsSaveFailed,
                    outcome: .failed,
                    operationID: operationID,
                    attributes: [
                        .failurePhase(failure.phase.rawValue),
                        .errorCategory(failure.category.rawValue),
                    ]
                )
            }
        }
    }

    func validateConfiguration() {
        Task { @MainActor in
            guard draft.testReadiness == .readyForMockRequest else {
                draft.testState = .missingRequiredFields
                return
            }
            draft.testState = .mockTesting
            do {
                let status = try await actions.validateDefaultProfileCredentials()
                draft.testState = status == .succeeded ? .mockSucceeded : .mockFailed
            } catch {
                draft.testState = .mockFailed
            }
        }
    }

    var statusTitleKey: String {
        switch draft.saveState {
        case .saving, .saved, .failed:
            return draft.saveState.titleKey
        case .idle, .missingRequiredFields:
            break
        }

        if draft.testReadiness == .missingRequiredFields {
            return "aiProviderSettings.saveState.missingRequiredFields"
        }

        return "aiProviderSettings.saveState.idle"
    }

    var statusIconName: String {
        switch draft.saveState {
        case .saving:
            return "clock"
        case .saved:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case .idle, .missingRequiredFields:
            break
        }

        if draft.testReadiness == .missingRequiredFields {
            return "exclamationmark.triangle"
        }

        return "lock.circle"
    }

    var statusTone: Color {
        switch draft.saveState {
        case .saved:
            return LangoTraceDesign.ColorToken.stateReady
        case .failed:
            return LangoTraceDesign.ColorToken.danger
        case .saving:
            return LangoTraceDesign.ColorToken.accent
        case .idle, .missingRequiredFields:
            break
        }

        if draft.testReadiness == .missingRequiredFields {
            return LangoTraceDesign.ColorToken.warning
        }

        return LangoTraceDesign.ColorToken.accent
    }

    var saveButtonTitleKey: String {
        isSaving ? "aiProviderSettings.saveState.saving" : "aiProviderSettings.save.button"
    }

    var isSaving: Bool {
        draft.saveState == .saving
    }

    var textProviderBinding: Binding<AIProviderPreset> {
        Binding(
            get: { draft.text.endpoint.provider },
            set: {
                draft.markInputChanged()
                draft.text.updateProvider($0)
            }
        )
    }

    var textBaseURLBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.baseURL },
            set: {
                draft.markInputChanged()
                draft.text.endpoint.baseURL = $0
            }
        )
    }

    var textModelBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.model },
            set: {
                draft.markInputChanged()
                draft.text.endpoint.model = $0
            }
        )
    }

    var textAPIKeyBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.independentCredential.apiKeyDraft },
            set: {
                draft.markInputChanged()
                draft.text.endpoint.independentCredential.apiKeyDraft = $0
            }
        )
    }

    var imageUnderstandingBinding: Binding<Bool> {
        Binding(
            get: { draft.text.imageUnderstandingEnabled },
            set: {
                draft.markInputChanged()
                draft.text.imageUnderstandingEnabled = $0 &&
                    draft.text.endpoint.provider.capabilities.imageUnderstanding
            }
        )
    }

    var speechBinding: Binding<AIOptionalModelDraftConfiguration> {
        Binding(
            get: { draft.speech },
            set: {
                draft.markInputChanged()
                draft.speech = $0
            }
        )
    }

    var embeddingBinding: Binding<AIOptionalModelDraftConfiguration> {
        Binding(
            get: { draft.embedding },
            set: {
                draft.markInputChanged()
                draft.embedding = $0
            }
        )
    }

    func recordSaveEvent(
        _ name: DiagnosticEventName,
        outcome: DiagnosticOutcome,
        operationID: DiagnosticOperationID,
        attributes: [DiagnosticAttribute] = []
    ) async {
        await actions.recordDiagnosticEvent(
            DiagnosticEvent(
                id: UUID().uuidString,
                name: name,
                domain: .aiProviderSettings,
                level: outcome == .failed ? .error : .info,
                outcome: outcome,
                attributes: [.operationID(operationID)] + attributes,
                createdAt: Date()
            )
        )
    }
}
