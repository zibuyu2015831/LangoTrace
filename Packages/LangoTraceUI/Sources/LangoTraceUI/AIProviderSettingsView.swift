import Foundation
import LangoTraceCore
import SwiftUI

struct AIProviderSettingsView: View {
    @Environment(\.aiProviderSettingsActions) private var actions
    @State private var draft = AIProviderDraftConfiguration(provider: .openAI)
    @State private var transientSaveStatusClearTask: Task<Void, Never>?

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
        .onDisappear {
            transientSaveStatusClearTask?.cancel()
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
            .disabled(draft.testReadiness == .missingRequiredFields)

            if let statusTitleKey {
                statusPanel(titleKey: statusTitleKey)
            }
        }
        .langoPanel()
    }

    private func statusPanel(titleKey: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: statusIconName)
                .foregroundStyle(statusTone)
                .frame(width: 28, height: 28)
            localizedText(titleKey)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        let secretsByCredentialID = await resolvedSecretsByCredentialID(for: profile)
        draft.applyLoadedProfile(profile, resolvedSecretsByCredentialID: secretsByCredentialID)
    }

    func saveConfiguration() {
        Task { @MainActor in
            guard !isSaving else {
                return
            }
            let operationID = actions.operationIDGenerator()
            await recordSaveEvent(
                .aiProviderSettingsSaveTapped,
                outcome: .started,
                operationID: operationID
            )
            let input: AIProviderProfileSaveInput
            do {
                input = try draft.makeProfileSaveInput()
            } catch {
                cancelTransientSaveStatusClear()
                let failure = AIProviderSaveFailureDisplay(error: error)
                draft.saveState = .missingRequiredFields
                await recordSaveEvent(
                    .aiProviderSettingsSaveInputInvalid,
                    outcome: .failed,
                    operationID: operationID,
                    attributes: [
                        .failurePhase(failure.phase.rawValue),
                        .errorCategory(failure.category.rawValue),
                    ]
                )
                return
            }

            draft.saveState = .saving
            do {
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
                scheduleTransientSaveStatusClear()
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
                scheduleTransientSaveStatusClear()
            }
        }
    }

    func validateConfiguration() {
        Task { @MainActor in
            guard !isSaving else {
                return
            }
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

    var statusTitleKey: String? {
        switch draft.saveState {
        case .unsavedChanges, .saved, .failed:
            draft.saveState.titleKey
        case .idle, .missingRequiredFields, .saving:
            nil
        }
    }

    var statusIconName: String {
        switch draft.saveState {
        case .unsavedChanges:
            "exclamationmark.circle"
        case .saved:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        case .idle, .missingRequiredFields, .saving:
            "lock.circle"
        }
    }

    var statusTone: Color {
        switch draft.saveState {
        case .unsavedChanges:
            LangoTraceDesign.ColorToken.warning
        case .saved:
            LangoTraceDesign.ColorToken.stateReady
        case .failed:
            LangoTraceDesign.ColorToken.danger
        case .idle, .missingRequiredFields, .saving:
            LangoTraceDesign.ColorToken.accent
        }
    }

    var isSaving: Bool {
        draft.saveState == .saving
    }

    @discardableResult
    func markDraftInputChanged<Value: Equatable>(from oldValue: Value, to newValue: Value) -> Bool {
        if draft.markInputChanged(from: oldValue, to: newValue) {
            cancelTransientSaveStatusClear()
            return true
        }
        return false
    }

    func resolvedSecretsByCredentialID(
        for profile: AIProviderConfigurationProfile
    ) async -> [AIProviderCredentialID: String] {
        var secretsByCredentialID: [AIProviderCredentialID: String] = [:]
        for credential in profile.credentials {
            if let secret = try? await actions.resolveCredentialSecret(credential) {
                secretsByCredentialID[credential.id] = secret
            }
        }
        return secretsByCredentialID
    }

    func scheduleTransientSaveStatusClear() {
        transientSaveStatusClearTask?.cancel()
        transientSaveStatusClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            switch draft.saveState {
            case .saved, .failed:
                draft.saveState = .idle
            case .idle, .missingRequiredFields, .unsavedChanges, .saving:
                break
            }
            transientSaveStatusClearTask = nil
        }
    }

    func cancelTransientSaveStatusClear() {
        transientSaveStatusClearTask?.cancel()
        transientSaveStatusClearTask = nil
    }

    var textProviderBinding: Binding<AIProviderPreset> {
        Binding(
            get: { draft.text.endpoint.provider },
            set: { newValue in
                guard markDraftInputChanged(from: draft.text.endpoint.provider, to: newValue) else {
                    return
                }
                draft.text.updateProvider(newValue)
            }
        )
    }

    var textBaseURLBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.baseURL },
            set: { newValue in
                guard markDraftInputChanged(from: draft.text.endpoint.baseURL, to: newValue) else {
                    return
                }
                draft.text.endpoint.baseURL = newValue
            }
        )
    }

    var textModelBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.model },
            set: { newValue in
                guard markDraftInputChanged(from: draft.text.endpoint.model, to: newValue) else {
                    return
                }
                draft.text.endpoint.model = newValue
            }
        )
    }

    var textAPIKeyBinding: Binding<String> {
        Binding(
            get: { draft.text.endpoint.independentCredential.apiKeyDraft },
            set: { newValue in
                guard markDraftInputChanged(
                    from: draft.text.endpoint.independentCredential.apiKeyDraft,
                    to: newValue
                ) else {
                    return
                }
                draft.text.endpoint.independentCredential.apiKeyDraft = newValue
            }
        )
    }

    var imageUnderstandingBinding: Binding<Bool> {
        Binding(
            get: { draft.text.imageUnderstandingEnabled },
            set: { newValue in
                let acceptedValue = newValue &&
                    draft.text.endpoint.provider.capabilities.imageUnderstanding
                guard markDraftInputChanged(from: draft.text.imageUnderstandingEnabled, to: acceptedValue) else {
                    return
                }
                draft.text.imageUnderstandingEnabled = acceptedValue
            }
        )
    }

    var speechBinding: Binding<AIOptionalModelDraftConfiguration> {
        Binding(
            get: { draft.speech },
            set: { newValue in
                guard markDraftInputChanged(from: draft.speech, to: newValue) else {
                    return
                }
                draft.speech = newValue
            }
        )
    }

    var embeddingBinding: Binding<AIOptionalModelDraftConfiguration> {
        Binding(
            get: { draft.embedding },
            set: { newValue in
                guard markDraftInputChanged(from: draft.embedding, to: newValue) else {
                    return
                }
                draft.embedding = newValue
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
