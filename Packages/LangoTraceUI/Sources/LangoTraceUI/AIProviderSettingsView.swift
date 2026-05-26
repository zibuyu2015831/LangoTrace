import Foundation
import LangoTraceCore
import SwiftUI

struct AIProviderSettingsView: View {
    @Environment(\.aiProviderSettingsActions) private var actions
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    let languageContext: AIProviderProbeLanguageContext?
    @State private var draft = AIProviderDraftConfiguration(provider: .openAI)
    @State private var transientSaveStatusClearTask: Task<Void, Never>?
    @State private var transientTestStatusClearTask: Task<Void, Never>?
    @State private var isProbeResultPresented = false
    @State private var latestProbeResult: AIProviderConfigurationProbeResult?
    @State private var activeProbeCapabilities: [AIProviderProbeCapability] = []

    init(languageContext: AIProviderProbeLanguageContext? = nil) {
        self.languageContext = languageContext
    }

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
            transientTestStatusClearTask?.cancel()
        }
        .sheet(isPresented: $isProbeResultPresented) {
            AIProviderProbeResultPanelSheet(
                result: latestProbeResult,
                isTesting: isTesting,
                activeCapabilities: activeProbeCapabilities,
                displayedCapabilities: displayedProbeCapabilities,
                usesRegularWidth: usesRegularProbeWidth,
                onRetry: validateConfiguration,
                onClose: { isProbeResultPresented = false },
                onPlaySpeechPreview: playSpeechPreview
            )
            .aiProviderProbePresentationStyle(compactWidth: isCompactWidth)
        }
    }

    private var isCompactWidth: Bool {
        #if os(iOS)
            horizontalSizeClass == .compact
        #else
            false
        #endif
    }

    private var usesRegularProbeWidth: Bool {
        #if os(iOS)
            horizontalSizeClass != .compact
        #else
            false
        #endif
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
                imageInputDecision: textImageInputDecision,
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
                .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
                .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.primaryActionFill)
            .disabled(draft.saveReadiness == .missingRequiredFields)

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
            .disabled(draft.configurationProbeReadiness == .missingRequiredFields || isTesting)

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

private extension View {
    @ViewBuilder
    func aiProviderProbePresentationStyle(compactWidth: Bool) -> some View {
        #if os(iOS)
            if compactWidth {
                presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            } else {
                presentationSizing(.fitted)
            }
        #else
            self
        #endif
    }
}

private extension AIProviderSettingsView {
    @MainActor
    func loadSavedConfiguration() async {
        guard let profile = try? await actions.loadDefaultProfile() else {
            return
        }
        draft.applyLoadedProfile(profile)
        await applyLoadedTTSVoiceProfile(from: profile)
    }

    @MainActor
    func applyLoadedTTSVoiceProfile(from profile: AIProviderConfigurationProfile) async {
        guard let languageCode = languageContext?.languageCode,
              let ttsEndpoint = profile.endpoints.first(where: { $0.purpose == .tts && $0.isEnabled }),
              let voiceProfile = try? await actions.loadTTSVoiceProfile(ttsEndpoint.id, languageCode)
        else {
            return
        }
        draft.applyLoadedTTSVoiceProfile(voiceProfile)
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
                input = try draft.makeProfileSaveInput(languageContext: languageContext)
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
                await applyLoadedTTSVoiceProfile(from: profile)
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
            guard draft.configurationProbeReadiness == .readyForRequest else {
                draft.testState = .missingRequiredFields
                return
            }
            cancelTransientTestStatusClear()
            let operationID = actions.operationIDGenerator()
            let source = draft.textProbeSource == .savedProfile
                ? AIProviderProbeSource.savedProfile
                : AIProviderProbeSource.draft
            let snapshot: AIProviderDraftProbeSnapshot?
            do {
                snapshot = source == .draft
                    ? try draft.makeConfigurationProbeDraftSnapshot(
                        operationID: operationID,
                        languageContext: languageContext
                    )
                    : nil
            } catch {
                draft.testState = .missingRequiredFields
                return
            }
            draft.testState = .testing
            latestProbeResult = nil
            activeProbeCapabilities = snapshot?.requestedCapabilities
                ?? draft.configurationProbeRequestedCapabilities(languageContext: languageContext)
            isProbeResultPresented = true
            do {
                let result = try await actions.testProviderConfiguration(
                    source,
                    snapshot,
                    languageContext,
                    operationID
                )
                let displayResult = draft.applyingLocalProbeCapabilityOverrides(
                    to: result,
                    languageContext: languageContext
                )
                latestProbeResult = displayResult
                activeProbeCapabilities = []
                draft.testState = testState(for: displayResult)
            } catch {
                activeProbeCapabilities = []
                draft.testState = .failed(nil, nil)
            }
            scheduleTransientTestStatusClear()
        }
    }

    func playSpeechPreview(_ resource: TTSAudioPreviewResource) {
        Task {
            await actions.playSpeechPreview(resource)
        }
    }

    var statusTitleKey: String? {
        switch draft.testState {
        case .idle:
            break
        case .missingRequiredFields, .testing, .succeeded, .partial, .failed, .cancelled, .unsupportedProvider:
            return draft.testState.titleKey
        }
        return switch draft.saveState {
        case .unsavedChanges, .saved, .failed:
            draft.saveState.titleKey
        case .idle, .missingRequiredFields, .saving:
            nil
        }
    }

    var displayedProbeCapabilities: [AIProviderProbeCapability] {
        draft.configurationProbeRequestedCapabilities(
            languageContext: languageContext,
            includePlaceholders: true
        )
    }

    var statusIconName: String {
        switch draft.testState {
        case .testing:
            return "clock.arrow.circlepath"
        case .succeeded:
            return "checkmark.circle"
        case .partial:
            return "exclamationmark.circle"
        case .cancelled:
            return "xmark.circle"
        case .missingRequiredFields, .failed, .unsupportedProvider:
            return "exclamationmark.triangle"
        case .idle:
            break
        }
        return switch draft.saveState {
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
        switch draft.testState {
        case .testing:
            return LangoTraceDesign.ColorToken.accent
        case .succeeded:
            return LangoTraceDesign.ColorToken.stateReady
        case .partial, .unsupportedProvider:
            return LangoTraceDesign.ColorToken.warning
        case .cancelled:
            return LangoTraceDesign.ColorToken.textSecondary
        case .missingRequiredFields, .failed:
            return LangoTraceDesign.ColorToken.danger
        case .idle:
            break
        }
        return switch draft.saveState {
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

    var isTesting: Bool {
        draft.testState == .testing
    }

    @discardableResult
    func markDraftInputChanged<Value: Equatable>(from oldValue: Value, to newValue: Value) -> Bool {
        if draft.markInputChanged(from: oldValue, to: newValue) {
            cancelTransientSaveStatusClear()
            return true
        }
        return false
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

    func scheduleTransientTestStatusClear() {
        transientTestStatusClearTask?.cancel()
        transientTestStatusClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            switch draft.testState {
            case .succeeded, .partial, .failed, .cancelled, .unsupportedProvider, .missingRequiredFields:
                draft.testState = .idle
            case .idle, .testing:
                break
            }
            transientTestStatusClearTask = nil
        }
    }

    func cancelTransientSaveStatusClear() {
        transientSaveStatusClearTask?.cancel()
        transientSaveStatusClearTask = nil
    }

    func cancelTransientTestStatusClear() {
        transientTestStatusClearTask?.cancel()
        transientTestStatusClearTask = nil
    }

    func testState(for result: AIProviderConfigurationProbeResult) -> AIProviderTestState {
        if result.overallStatus == .succeeded {
            return .succeeded(result)
        }
        if result.overallStatus == .cancelled {
            return .cancelled(result)
        }
        if result.isUnsupportedTextProbeResult {
            return .unsupportedProvider(result)
        }
        if result.capabilities.contains(where: { $0.status == .succeeded }) {
            return .partial(result)
        }
        return .failed(result.primaryProbeFailureCategory, result)
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
                let acceptedValue = newValue && textImageInputDecision.canToggle
                guard markDraftInputChanged(from: draft.text.imageUnderstandingEnabled, to: acceptedValue) else {
                    return
                }
                draft.text.imageUnderstandingEnabled = acceptedValue
            }
        )
    }

    var textImageInputDecision: AIProviderCapabilityDecision {
        AIProviderEndpointCapabilityResolver.imageInputDecision(
            provider: draft.text.endpoint.provider,
            adapterKind: draft.text.endpoint.provider.adapterKind,
            purpose: .textGeneration,
            modelName: draft.text.endpoint.model
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
