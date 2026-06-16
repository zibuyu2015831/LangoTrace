import Foundation
import LangoTraceCore
import SwiftUI

struct AIProviderSettingsView: View {
    @Environment(\.aiProviderSettingsActions) private var actions
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    let languageContext: AIProviderProbeLanguageContext?
    @State private var draft = AIProviderDraftConfiguration(provider: .openAI)
    @State private var savedCredentialMetadataByID: [AIProviderCredentialID: AIProviderCredentialMetadata] = [:]
    @State private var store = AIProviderSettingsStore()
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
            store.cancelAllDraftClears()
            clearPlaintextSecretsForCredentialDisclosure()
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                clearPlaintextSecretsForCredentialDisclosure()
            }
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
            AIProviderAPIKeyField(
                text: textAPIKeyBinding,
                savedCredential: textCredentialMetadata,
                onRevealSavedCredential: revealTextCredential
            )
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
            credentialMetadataByID: savedCredentialMetadataByID,
            revealIndependentCredential: revealIndependentCredential,
            configuration: configuration
        )
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                saveConfiguration()
            } label: {
                saveButtonLabel
            }
            .buttonStyle(.borderedProminent)
            .tint(draft.saveState == .saved
                ? LangoTraceDesign.ColorToken.stateReady
                : LangoTraceDesign.ColorToken.primaryActionFill)
            .disabled(draft.saveReadiness == .missingRequiredFields || isSaving)
            .animation(.snappy, value: draft.saveState)

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

    @ViewBuilder
    private var saveButtonLabel: some View {
        switch draft.saveState {
        case .saving:
            Label {
                localizedText("aiProviderSettings.saveState.saving")
            } icon: {
                ProgressView()
                    .controlSize(.small)
                    .tint(LangoTraceDesign.ColorToken.primaryActionForeground)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
            .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        case .saved:
            Label {
                localizedText("aiProviderSettings.saveState.saved")
            } icon: {
                Image(systemName: "lock.badge.checkmark.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
            .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        case .failed:
            Label {
                localizedText("aiProviderSettings.saveState.failed")
            } icon: {
                Image(systemName: "lock.badge.xmark.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
            .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        case .unsavedChanges:
            Label {
                localizedText("aiProviderSettings.save.saveChanges.button")
            } icon: {
                Image(systemName: "exclamationmark.lock.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
            .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        default:
            Label {
                localizedText("aiProviderSettings.save.button")
            } icon: {
                Image(systemName: "lock.shield")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
            .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        }
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
        savedCredentialMetadataByID = credentialMetadataByID(from: profile)
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
                savedCredentialMetadataByID = credentialMetadataByID(from: profile)
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
                if source == .draft {
                    // When apiKeyDraft was cleared after a profile load but the saved credential
                    // still exists in the Keychain, temporarily restore it so the probe snapshot
                    // carries a usable secret. The resolved value is cleared immediately after.
                    var resolvedForSnapshot = false
                    if draft.text.endpoint.independentCredential.requiresAPIKey,
                       draft.text.endpoint.independentCredential.apiKeyDraft
                           .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let credentialID = draft.text.endpoint.credentialID,
                       let metadata = savedCredentialMetadataByID[credentialID],
                       let secret = try? await actions.resolveCredentialSecret(metadata),
                       !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        draft.text.endpoint.independentCredential.apiKeyDraft = secret
                        resolvedForSnapshot = true
                    }
                    snapshot = try draft.makeConfigurationProbeDraftSnapshot(
                        operationID: operationID,
                        languageContext: languageContext
                    )
                    if resolvedForSnapshot {
                        draft.clearPlaintextSecrets()
                    }
                } else {
                    snapshot = nil
                }
            } catch {
                draft.clearPlaintextSecrets()
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

    func revealTextCredential() async -> AIProviderCredentialRevealResult {
        await revealCredential(for: .textGeneration)
    }

    func revealIndependentCredential(
        _ purpose: AIProviderEndpointPurpose
    ) async -> AIProviderCredentialRevealResult {
        await revealCredential(for: purpose)
    }

    @MainActor
    func revealCredential(for purpose: AIProviderEndpointPurpose) async -> AIProviderCredentialRevealResult {
        guard let metadata = credentialMetadata(for: purpose) else {
            return .failed(.missingCredential)
        }

        do {
            guard let secret = try await actions.resolveCredentialSecret(metadata),
                  !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return .failed(.missingCredential)
            }
            applyRevealedSecret(secret, for: purpose)
            return .succeeded(secret)
        } catch let failure as AIProviderCredentialResolveFailure {
            await recordCredentialRevealFailedEvent(category: failure.category)
            return .failed(revealFailure(from: failure.category))
        } catch {
            await recordCredentialRevealFailedEvent(category: .credentialInaccessible)
            return .failed(.credentialInaccessible)
        }
    }

    func credentialMetadata(for purpose: AIProviderEndpointPurpose) -> AIProviderCredentialMetadata? {
        let credentialID: AIProviderCredentialID? = switch purpose {
        case .textGeneration:
            draft.text.endpoint.credentialID
        case .tts:
            draft.speech.endpoint.credentialReference == .independent
                ? draft.speech.endpoint.credentialID
                : nil
        case .embedding:
            draft.embedding.endpoint.credentialReference == .independent
                ? draft.embedding.endpoint.credentialID
                : nil
        }

        guard let credentialID else {
            return nil
        }
        return savedCredentialMetadataByID[credentialID]
    }

    var textCredentialMetadata: AIProviderCredentialMetadata? {
        guard let credentialID = draft.text.endpoint.credentialID else {
            return nil
        }
        return savedCredentialMetadataByID[credentialID]
    }

    func applyRevealedSecret(_ secret: String, for purpose: AIProviderEndpointPurpose) {
        switch purpose {
        case .textGeneration:
            draft.text.endpoint.independentCredential.apiKeyDraft = secret
        case .tts:
            guard draft.speech.endpoint.credentialReference == .independent else {
                return
            }
            draft.speech.endpoint.independentCredential.apiKeyDraft = secret
        case .embedding:
            guard draft.embedding.endpoint.credentialReference == .independent else {
                return
            }
            draft.embedding.endpoint.independentCredential.apiKeyDraft = secret
        }
    }

    func clearPlaintextSecretsForCredentialDisclosure() {
        draft.clearPlaintextSecrets()
    }

    func credentialMetadataByID(
        from profile: AIProviderConfigurationProfile
    ) -> [AIProviderCredentialID: AIProviderCredentialMetadata] {
        Dictionary(uniqueKeysWithValues: profile.credentials.map { ($0.id, $0) })
    }

    func revealFailure(
        from category: AIProviderValidationErrorCategory
    ) -> AIProviderCredentialRevealFailure {
        switch category {
        case .missingCredential:
            .missingCredential
        case .credentialInaccessible:
            .credentialInaccessible
        case .authenticationFailed:
            .userInteractionRequired
        case .networkUnavailable, .timeout, .providerRejected, .unsupportedModel,
             .unsupportedEndpointPurpose, .invalidResponse, .invalidAudioResponse,
             .invalidVoice, .unsupportedLanguage, .unsupportedAudioFormat,
             .audioDecodeFailed, .rateLimited, .quotaExceeded, .invalidEmbeddingResponse:
            .credentialInaccessible
        }
    }

    var statusTitleKey: String? {
        switch draft.testState {
        case .idle:
            break
        case .missingRequiredFields, .testing, .succeeded, .partial, .failed, .cancelled, .unsupportedProvider:
            return draft.testState.titleKey
        }
        return draft.saveReadiness == .missingRequiredFields
            ? "aiProviderSettings.saveState.missingRequiredFields"
            : nil
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
            return "lock.circle"
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
            return LangoTraceDesign.ColorToken.accent
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
        store.scheduleDraftSaveClear(after: .seconds(2.2)) { [self] in
            switch draft.saveState {
            case .saved, .failed:
                draft.saveState = .idle
            case .idle, .missingRequiredFields, .unsavedChanges, .saving:
                break
            }
        }
    }

    func scheduleTransientTestStatusClear() {
        store.scheduleDraftTestClear(after: .seconds(3)) { [self] in
            switch draft.testState {
            case .succeeded, .partial, .failed, .cancelled, .unsupportedProvider, .missingRequiredFields:
                draft.testState = .idle
            case .idle, .testing:
                break
            }
        }
    }

    func cancelTransientSaveStatusClear() {
        store.cancelDraftSaveClear()
    }

    func cancelTransientTestStatusClear() {
        store.cancelDraftTestClear()
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
                clearPlaintextSecretsForCredentialDisclosure()
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
                if shouldClearPlaintextSecretsForEndpointChange(
                    from: draft.speech.endpoint,
                    to: newValue.endpoint
                ) {
                    clearPlaintextSecretsForCredentialDisclosure()
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
                if shouldClearPlaintextSecretsForEndpointChange(
                    from: draft.embedding.endpoint,
                    to: newValue.endpoint
                ) {
                    clearPlaintextSecretsForCredentialDisclosure()
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

    func recordCredentialRevealFailedEvent(
        category: AIProviderValidationErrorCategory
    ) async {
        await actions.recordDiagnosticEvent(
            DiagnosticEvent(
                id: UUID().uuidString,
                name: .aiProviderSettingsCredentialFailed,
                domain: .aiProviderSettings,
                level: .warning,
                outcome: .failed,
                attributes: [
                    .failurePhase("credential_reveal"),
                    .errorCategory(category.rawValue),
                ],
                createdAt: Date()
            )
        )
    }

    func shouldClearPlaintextSecretsForEndpointChange(
        from oldEndpoint: AIProviderEndpointDraftConfiguration,
        to newEndpoint: AIProviderEndpointDraftConfiguration
    ) -> Bool {
        oldEndpoint.provider != newEndpoint.provider ||
            oldEndpoint.credentialReference != newEndpoint.credentialReference ||
            oldEndpoint.credentialID != newEndpoint.credentialID
    }
}
