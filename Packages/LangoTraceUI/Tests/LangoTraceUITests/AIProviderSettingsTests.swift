import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("AI provider settings")
struct AIProviderSettingsTests {
    @Test("Provider presets expose the complete first-run set")
    func providerPresetsExposeCompleteFirstRunSet() {
        #expect(AIProviderPreset.allCases.map(\.id) == [
            "openai",
            "anthropic",
            "gemini",
            "deepseek",
            "mistral",
            "groq",
            "xai",
            "moonshot-kimi",
            "openrouter",
            "dashscope-qwen",
            "zhipu-glm",
            "siliconflow",
            "ollama-local",
            "custom-openai-compatible",
        ])

        #expect(AIProviderPreset.deepSeek.defaultChatModel != "deepseek-chat")
        #expect(AIProviderPreset.deepSeek.defaultChatModel != "deepseek-reasoner")
    }

    @Test("Draft model validates save readiness without persisting credentials")
    func draftModelValidatesSaveReadinessWithoutPersistingCredentials() {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        #expect(draft.text.endpoint.independentCredential.apiKeyStorage == .encryptedStoragePending)
        #expect(draft.saveReadiness == .missingRequiredFields)
        #expect(draft.saveState == .idle)

        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        #expect(draft.saveReadiness == .readyForRequest)

        draft.saveMockConfiguration()
        #expect(draft.saveState == .saved)
    }

    @Test("Draft save states expose independent saving saved and failed titles")
    func draftSaveStatesExposeIndependentSavingSavedAndFailedTitles() {
        let failure = AIProviderSaveFailureDisplay(
            phase: .databaseWrite,
            category: .databaseWriteFailed
        )

        #expect(AIProviderSaveState.saving.titleKey == "aiProviderSettings.saveState.saving")
        #expect(AIProviderSaveState.saved.titleKey == "aiProviderSettings.saveState.saved")
        #expect(AIProviderSaveState.failed(failure).titleKey == "aiProviderSettings.saveState.failed")
        #expect(AIProviderSaveState.failed(failure).titleKey != AIProviderSaveState.missingRequiredFields.titleKey)
    }

    @Test("Draft model separates text speech and embedding endpoints from credentials")
    func draftModelSeparatesEndpointsFromCredentials() {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        #expect(draft.text.textGenerationEnabled)
        #expect(!draft.text.imageUnderstandingEnabled)
        #expect(!draft.speech.isEnabled)
        #expect(!draft.embedding.isEnabled)
        #expect(draft.speech.endpoint.credentialReference == .textModelCredential)
        #expect(draft.embedding.endpoint.credentialReference == .textModelCredential)

        draft.text.endpoint.independentCredential.apiKeyDraft = "shared-key"
        draft.speech.isEnabled = true
        draft.speech.endpoint.model = "gpt-4o-mini-tts"
        #expect(draft.saveReadiness == .readyForRequest)

        draft.embedding.isEnabled = true
        draft.embedding.endpoint.credentialReference = .independent
        draft.embedding.endpoint.independentCredential.apiKeyDraft = ""
        #expect(draft.saveReadiness == .missingRequiredFields)

        draft.embedding.endpoint.independentCredential.apiKeyDraft = "embedding-key"
        #expect(draft.saveReadiness == .readyForRequest)
    }

    @Test("Draft model separates save readiness from text probe readiness")
    func draftModelSeparatesSaveReadinessFromTextProbeReadiness() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        draft.speech.isEnabled = true
        draft.speech.endpoint.model = ""
        draft.embedding.isEnabled = true
        draft.embedding.endpoint.model = ""

        #expect(draft.saveReadiness == .missingRequiredFields)
        #expect(draft.textProbeReadiness == .readyForRequest)
        #expect(draft.textProbeSource == .draft)

        let snapshot = try draft.makeTextProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-ui-probe")
        )
        #expect(snapshot.source == .draft)
        #expect(snapshot.endpoint.purpose == .textGeneration)
        #expect(snapshot.endpoint.providerPresetID == "openai")
        #expect(snapshot.plaintextSecret == "sk-local-draft")
        #expect(snapshot.requestedCapabilities == [.textReply, .structuredJSON])
    }

    @Test("Loaded profile without edits uses saved profile as text probe source")
    func loadedProfileWithoutEditsUsesSavedProfileAsTextProbeSource() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        try draft.applyLoadedProfile(loadedProfile())

        #expect(draft.textProbeReadiness == .readyForRequest)
        #expect(draft.textProbeSource == .savedProfile)

        draft.markInputChanged()
        #expect(draft.textProbeSource == .draft)
    }

    @Test("Changing optional model provider defaults to independent credential")
    func changingOptionalModelProviderDefaultsToIndependentCredential() {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        draft.speech.endpoint.credentialReference = .textModelCredential
        draft.speech.updateProvider(.mistral, shareTextCredentialWhenSameProvider: false)

        #expect(draft.speech.endpoint.provider == .mistral)
        #expect(draft.speech.endpoint.credentialReference == .independent)
    }

    @Test("Provider capabilities are not flattened across all providers")
    func providerCapabilitiesAreNotFlattenedAcrossAllProviders() {
        #expect(AIProviderPreset.openAI.capabilities.embedding)
        #expect(AIProviderPreset.openAI.capabilities.tts)
        #expect(!AIProviderPreset.anthropic.capabilities.openAICompatible)
        #expect(!AIProviderPreset.deepSeek.capabilities.embedding)
        #expect(!AIProviderPreset.gemini.capabilities.tts)
    }

    @Test("Settings source has test button without network or bearer calls")
    func settingsSourceHasTestButtonWithoutNetworkOrBearerCalls() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)

        #expect(source.contains("aiProviderSettings.testRequest.button"))
        #expect(source.contains("validateConfiguration()"))
        #expect(source.contains("actions.testProviderConfiguration"))
        #expect(source.contains("makeTextProbeDraftSnapshot"))
        #expect(source.contains("AIProviderProbeResultPanelContent"))
        #expect(source.contains(".sheet(isPresented: $isProbeResultPresented)"))
        #expect(source.contains("aiProviderProbePresentationDetents(compactWidth: isCompactWidth)"))
        #expect(source.contains("horizontalSizeClass == .compact"))
        #expect(!source.contains("actions.validateDefaultProfileCredentials"))
        #expect(!source.contains("URLSession"))
        #expect(!source.contains("dataTask"))
        #expect(!source.contains("uploadTask"))
        #expect(!source.contains("Authorization"))
        #expect(!source.contains("Bearer "))
    }

    @Test("Probe result content is presentation independent and shows all capability rows")
    func probeResultContentIsPresentationIndependentAndShowsAllCapabilityRows() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )

        #expect(source.contains("struct AIProviderProbeResultPanelContent"))
        #expect(source.contains("AIProviderProbeCapability.allCases"))
        #expect(source.contains("aiProviderSettings.probeCapability.textReply"))
        #expect(source.contains("aiProviderSettings.probeCapability.structuredJSON"))
        #expect(source.contains("aiProviderSettings.probeCapability.imageUnderstanding"))
        #expect(source.contains("aiProviderSettings.probeCapability.speechSynthesis"))
        #expect(source.contains("aiProviderSettings.probeCapability.embedding"))
        #expect(!source.contains(".sheet("))
        #expect(!source.contains("presentationDetents"))
    }

    @Test("Draft probe snapshot is not equatable codable or a profile save input")
    func draftProbeSnapshotIsNotEquatableCodableOrProfileSaveInput() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderDraftConfiguration.swift"),
            encoding: .utf8
        )

        #expect(source.contains("struct AIProviderDraftProbeSnapshot: Sendable"))
        #expect(!source.contains("struct AIProviderDraftProbeSnapshot: Equatable"))
        #expect(!source.contains("struct AIProviderDraftProbeSnapshot: Codable"))
        #expect(source.contains("makeTextProbeDraftSnapshot"))
        #expect(!source.contains("makeTextProbeDraftSnapshot(operationID: DiagnosticOperationID) throws -> AIProviderProfileSaveInput"))
    }

    @Test("Settings source has save-first secure-storage UI")
    func settingsSourceHasSaveFirstSecureStorageUI() throws {
        let viewSource = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
        let draftSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderDraftConfiguration.swift"),
            encoding: .utf8
        )
        let source = viewSource + draftSource

        #expect(source.contains("aiProviderSettings.save.button"))
        #expect(!viewSource.contains("aiProviderSettings.save.boundary"))
        #expect(!viewSource.contains("aiProviderSettings.saveState.saving"))
        #expect(!source.contains("ProgressView"))
        #expect(!source.contains("saveButtonTitleKey"))
        #expect(source.contains("guard !isSaving else"))
        #expect(source.contains("operationID"))
        #expect(source.contains("aiProviderSettings.saveState.unsavedChanges"))
        #expect(source.contains("statusTitleKey: String?"))
        #expect(source.contains("aiProviderSettings.saveState.failed"))
        #expect(source.contains("saveConfiguration()"))
        #expect(source.contains("actions.saveDefaultProfile"))
    }

    @Test("Save boundary copy is short enough for compact iPhone status panel")
    func statusPanelUsesTitleOnlyCopyWithoutTip() throws {
        let strings = try String(
            contentsOf: sourceFileURL(named: "Resources/Localizable.xcstrings"),
            encoding: .utf8
        )
        let viewSource = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)

        #expect(strings.contains("\"value\": \"配置未保存\""))
        #expect(strings.contains("\"value\": \"配置已更新\""))
        #expect(!viewSource.contains("localizedText(\"aiProviderSettings.save.boundary\")"))
        #expect(!strings.contains("数据会加密存储"))
        #expect(!strings.contains("保存后的凭证会加密留在本机，并供后续 AI 请求使用。"))
    }

    @Test("Loaded profile stays quiet until edited and saved")
    func loadedProfileStaysQuietUntilEditedAndSaved() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        try draft.applyLoadedProfile(loadedProfile())
        #expect(draft.saveState == .idle)

        draft.markInputChanged()
        #expect(draft.saveState == .unsavedChanges)

        draft.applySavedProfile(emptySavedProfile())
        #expect(draft.saveState == .saved)

        draft.markInputChanged()
        #expect(draft.saveState == .unsavedChanges)
    }

    @Test("New incomplete or draft configuration stays visually quiet before save")
    func newIncompleteOrDraftConfigurationStaysQuietBeforeSave() {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        #expect(draft.saveState == .idle)
        draft.markInputChanged()
        #expect(draft.saveState == .idle)
    }

    @Test("Settings source records invalid save input separately from save failure")
    func settingsSourceRecordsInvalidSaveInputSeparatelyFromSaveFailure() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)

        #expect(source.contains(".aiProviderSettingsSaveInputInvalid"))
        #expect(source.contains("draft.saveState = .missingRequiredFields"))
        #expect(source.contains("return"))
    }

    @Test("Draft save input maps endpoints and clears plaintext after saved profile")
    func draftSaveInputMapsEndpointsAndClearsPlaintextAfterSavedProfile() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "text-secret"
        draft.speech.isEnabled = true
        draft.speech.endpoint.credentialReference = .textModelCredential
        draft.embedding.isEnabled = true
        draft.embedding.endpoint.credentialReference = .independent
        draft.embedding.endpoint.independentCredential.apiKeyDraft = "embedding-secret"

        let input = try draft.makeProfileSaveInput()

        #expect(input.endpoints.map(\.purpose) == [.textGeneration, .tts, .embedding])
        #expect(input.endpoints[0].credentialMode == .newSecret(.init(
            kind: .apiKey,
            label: "OpenAI API Key",
            plaintextSecret: "text-secret"
        )))
        #expect(input.endpoints[1].credentialMode == .sharedWithPurpose(.textGeneration))
        #expect(input.endpoints[2].credentialMode == .newSecret(.init(
            kind: .apiKey,
            label: "OpenAI API Key",
            plaintextSecret: "embedding-secret"
        )))

        draft.applySavedProfile(emptySavedProfile())
        #expect(draft.text.endpoint.independentCredential.apiKeyDraft.isEmpty)
        #expect(draft.embedding.endpoint.independentCredential.apiKeyDraft.isEmpty)
        #expect(draft.saveState == .saved)
    }

    @Test("Loaded profile restores non secret endpoint fields without API key plaintext")
    func loadedProfileRestoresNonSecretEndpointFieldsWithoutAPIKeyPlaintext() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "old-plaintext"

        try draft.applyLoadedProfile(loadedProfile())

        #expect(draft.text.endpoint.baseURL == "https://api.openai.com/v1")
        #expect(draft.text.endpoint.model == "gpt-5.2")
        #expect(draft.speech.isEnabled)
        #expect(draft.speech.endpoint.credentialReference == .textModelCredential)
        #expect(draft.text.endpoint.independentCredential.apiKeyDraft.isEmpty)
        #expect(draft.speech.endpoint.independentCredential.apiKeyDraft.isEmpty)
    }

    @Test("Settings source keeps provider form concise and full width")
    func settingsSourceKeepsProviderFormConciseAndFullWidth() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)

        #expect(source.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(!source.contains("riskNoteKey"))
        #expect(!source.contains("aiProviderSettings.privacy.body"))
        #expect(!source.contains("AIProviderReadonlyMetadataRow"))
    }

    @Test("Settings source uses model-purpose sections instead of advanced models")
    func settingsSourceUsesModelPurposeSectionsInsteadOfAdvancedModels() throws {
        let viewSource = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
        let componentSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )
        let source = viewSource + componentSource

        #expect(!source.contains("showsAdvancedModels"))
        #expect(!source.contains("aiProviderSettings.advancedModels.title"))
        #expect(source.contains("aiProviderSettings.textModel.title"))
        #expect(source.contains("aiProviderSettings.speechModel.title"))
        #expect(source.contains("aiProviderSettings.embeddingModelGroup.title"))
        #expect(source.contains("aiProviderSettings.apiKey.useText"))
        #expect(source.contains("aiProviderSettings.apiKey.useIndependent"))
        #expect(!source.contains("aiProviderSettings.credential.useText"))
        #expect(!source.contains("aiProviderSettings.credential.useIndependent"))
    }

    @Test("Settings source uses concise provider row and visible API key control")
    func settingsSourceUsesConciseProviderRowAndVisibleAPIKeyControl() throws {
        let viewSource = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
        let componentSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )
        let source = viewSource + componentSource

        #expect(source.contains("AIProviderRowPicker"))
        #expect(source.contains("AIProviderAPIKeyField"))
        #expect(source.contains("aiProviderSettings.apiKey.title"))
        #expect(source.contains("eye.slash"))
        #expect(source.contains("eye"))
        #expect(source.contains("accessibilityLabel(localizedText(visibilityLabelKey))"))
    }

    @Test("Provider row keeps long names on one line")
    func providerRowKeepsLongNamesOnOneLine() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )

        #expect(source.contains("selectedProviderLabel"))
        #expect(source.contains("Text(provider.displayName)"))
        #expect(source.contains("lineLimit(1)"))
        #expect(source.contains("minimumScaleFactor(0.82)"))
        #expect(source.contains("truncationMode(.tail)"))
        #expect(source.contains(".frame(maxWidth: .infinity, alignment: .trailing)"))
    }

    @Test("Settings detail constrains shared AI provider form on large platforms")
    func settingsDetailConstrainsSharedAIProviderFormOnLargePlatforms() throws {
        let detailSource = try String(
            contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"),
            encoding: .utf8
        )
        let settingsSceneSource = try String(
            contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"),
            encoding: .utf8
        )

        #expect(detailSource.contains("AIProviderSettingsView()"))
        #expect(detailSource.contains("aiProviderSettingsContainer"))
        #expect(detailSource.contains("aiProviderSettingsContentMaxWidth"))
        #expect(detailSource.contains(".frame(maxWidth: aiProviderSettingsContentMaxWidth, alignment: .leading)"))
        #expect(detailSource.contains("#if os(macOS)"))
        #expect(detailSource.contains("860"))
        #expect(detailSource.contains("820"))

        #expect(!detailSource.contains("PadAIProviderSettingsView"))
        #expect(!detailSource.contains("MacAIProviderSettingsView"))
        #expect(!settingsSceneSource.contains("AIProviderSettingsView"))
        #expect(settingsSceneSource.contains("SettingsCapabilityDetailView("))
        #expect(settingsSceneSource.contains("selection = .capability(capability.kind)"))
    }

    @Test("Text input modifier is a single chained iOS expression")
    func textInputModifierIsSingleChainedIOSExpression() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )
        let chainedInputModifiers = "textInputAutocapitalization(.never)\n" +
            "                .keyboardType(keyboardHint.keyboardType)\n" +
            "                .autocorrectionDisabled()"
        let separateInputModifiers = "textInputAutocapitalization(.never)\n" +
            "            keyboardType(keyboardHint.keyboardType)\n" +
            "            autocorrectionDisabled()"

        #expect(source.contains(chainedInputModifiers))
        #expect(!source.contains(separateInputModifiers))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }

    private func emptySavedProfile() -> AIProviderConfigurationProfile {
        AIProviderConfigurationProfile(
            id: "profile-1",
            displayName: "Default AI Provider",
            isDefault: true,
            status: .configured,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func loadedProfile() throws -> AIProviderConfigurationProfile {
        let now = Date(timeIntervalSince1970: 100)
        let text = try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: "text-endpoint",
                profileID: "profile-1",
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-5.2",
                credentialID: "credential-1",
                supportsImageInput: true,
                imageInputEnabled: false
            ),
            createdAt: now,
            updatedAt: now
        )
        let speech = try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: "speech-endpoint",
                profileID: "profile-1",
                purpose: .tts,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-4o-mini-tts",
                credentialID: "credential-1",
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            createdAt: now,
            updatedAt: now
        )
        return AIProviderConfigurationProfile(
            id: "profile-1",
            displayName: "Default AI Provider",
            isDefault: true,
            status: .configured,
            createdAt: now,
            updatedAt: now,
            endpoints: [text, speech]
        )
    }
}

@Suite("AI provider platform consistency")
struct AIProviderPlatformConsistencyTests {
    @Test("iPad and Mac workspace route AI provider through shared settings detail")
    func iPadAndMacWorkspaceRouteAIProviderThroughSharedSettingsDetail() throws {
        let padSource = try String(contentsOf: sourceFileURL(named: "PadMainSections.swift"), encoding: .utf8)
        let macSource = try String(contentsOf: sourceFileURL(named: "MacWorkspaceContentView.swift"), encoding: .utf8)

        #expect(padSource.contains("SettingsCapabilityDetailView("))
        #expect(padSource.contains("capability: capability"))
        #expect(padSource.contains("onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange"))
        #expect(!padSource.contains("AIProviderSettingsView()"))
        #expect(!padSource.contains("PadAIProviderSettingsView"))

        #expect(macSource.contains("SettingsCapabilityDetailView("))
        #expect(macSource.contains("presentation: .embeddedInExistingScroll"))
        #expect(macSource.contains("onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange"))
        #expect(!macSource.contains("AIProviderSettingsView()"))
        #expect(!macSource.contains("MacAIProviderSettingsView"))
    }

    @Test("macOS settings scene and root inject the same AI provider actions")
    func macOSSettingsSceneAndRootInjectSameAIProviderActions() throws {
        let appSource = try String(contentsOf: appSourceFileURL(named: "LangoTraceApp.swift"), encoding: .utf8)
        let sceneSource = try String(
            contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"),
            encoding: .utf8
        )

        let actionInjectionNeedle = ".environment(\\.aiProviderSettingsActions, environment.aiProviderSettingsActions)"
        let actionInjectionCount = appSource
            .components(separatedBy: actionInjectionNeedle)
            .count - 1

        #expect(sceneSource.contains("SettingsCapabilityDetailView("))
        #expect(sceneSource.contains("selection = .capability(capability.kind)"))
        #expect(!sceneSource.contains("AIProviderSettingsView()"))
        #expect(appSource.contains("Settings {"))
        #expect(appSource.contains("LangoTraceSettingsSceneView("))
        #expect(actionInjectionCount == 2)
    }

    @Test("Shared detail is the only platform owner for AI provider form")
    func sharedDetailIsOnlyPlatformOwnerForAIProviderForm() throws {
        let detailSource = try String(
            contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"),
            encoding: .utf8
        )

        #expect(detailSource.contains("AIProviderSettingsView()"))
        #expect(detailSource.contains("aiProviderSettingsContainer"))
        #expect(detailSource.contains("aiProviderSettingsContentMaxWidth"))
        #expect(detailSource.contains(".frame(maxWidth: aiProviderSettingsContentMaxWidth, alignment: .leading)"))
        #expect(detailSource.contains("#if os(macOS)"))
        #expect(detailSource.contains("860"))
        #expect(detailSource.contains("820"))
        #expect(!detailSource.contains("PadAIProviderSettingsView"))
        #expect(!detailSource.contains("MacAIProviderSettingsView"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }

    private func appSourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LangoTraceApp")
            .appendingPathComponent(fileName)
    }
}

@Suite("AI provider settings save status repair")
struct AIProviderSettingsSaveStatusRepairTests {
    @Test("Loaded profile save input preserves profile and endpoint identities")
    func loadedProfileSaveInputPreservesProfileAndEndpointIdentities() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        try draft.applyLoadedProfile(loadedProfile())

        draft.text.endpoint.independentCredential.apiKeyDraft = "replacement-key"
        let input = try draft.makeProfileSaveInput()

        #expect(input.profileID == "profile-1")
        #expect(input.endpoints.first { $0.purpose == .textGeneration }?.id == "text-endpoint")
        #expect(input.endpoints.first { $0.purpose == .tts }?.id == "speech-endpoint")
    }

    @Test("Status panel is vertically centered and transient success or failure is scheduled")
    func statusPanelIsCenteredAndTransientResultIsScheduled() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)

        #expect(source.contains("HStack(alignment: .center"))
        #expect(!source.contains("HStack(alignment: .top"))
        #expect(source.contains("scheduleTransientSaveStatusClear()"))
        #expect(source.contains("try? await Task.sleep"))
        #expect(source.contains("transientSaveStatusClearTask?.cancel()"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }

    private func loadedProfile() throws -> AIProviderConfigurationProfile {
        let now = Date(timeIntervalSince1970: 100)
        let text = try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: "text-endpoint",
                profileID: "profile-1",
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-5.2",
                credentialID: "credential-1",
                supportsImageInput: true,
                imageInputEnabled: false
            ),
            createdAt: now,
            updatedAt: now
        )
        let speech = try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: "speech-endpoint",
                profileID: "profile-1",
                purpose: .tts,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-4o-mini-tts",
                credentialID: "credential-1",
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            createdAt: now,
            updatedAt: now
        )
        return AIProviderConfigurationProfile(
            id: "profile-1",
            displayName: "Default AI Provider",
            isDefault: true,
            status: .configured,
            createdAt: now,
            updatedAt: now,
            endpoints: [text, speech]
        )
    }
}

@Suite("AI provider settings loaded secret and focus repair")
struct AIProviderLoadedSecretRepairTests {
    @Test("Loaded profile restores resolved API key without marking unsaved")
    func loadedProfileRestoresResolvedAPIKeyWithoutMarkingUnsaved() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        try draft.applyLoadedProfile(
            loadedProfile(),
            resolvedSecretsByCredentialID: ["credential-1": "sk-saved"]
        )

        #expect(draft.text.endpoint.independentCredential.apiKeyDraft == "sk-saved")
        #expect(draft.saveReadiness == .readyForRequest)
        #expect(draft.saveState == .idle)
    }

    @Test("Unchanged field write does not mark loaded configuration unsaved")
    func unchangedFieldWriteDoesNotMarkLoadedConfigurationUnsaved() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        try draft.applyLoadedProfile(
            loadedProfile(),
            resolvedSecretsByCredentialID: ["credential-1": "sk-saved"]
        )

        draft.markInputChanged(
            from: draft.text.endpoint.independentCredential.apiKeyDraft,
            to: "sk-saved"
        )
        #expect(draft.saveState == .idle)

        draft.markInputChanged(
            from: draft.text.endpoint.independentCredential.apiKeyDraft,
            to: "sk-updated"
        )
        #expect(draft.saveState == .unsavedChanges)
    }

    @Test("Settings actions expose a non logging credential resolver")
    func settingsActionsExposeNonLoggingCredentialResolver() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsActions.swift"), encoding: .utf8)

        #expect(source.contains("resolveCredentialSecret"))
        #expect(!source.contains("print("))
        #expect(!source.contains("debugPrint("))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }

    private func loadedProfile() throws -> AIProviderConfigurationProfile {
        let now = Date(timeIntervalSince1970: 100)
        let text = try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: "text-endpoint",
                profileID: "profile-1",
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-5.2",
                credentialID: "credential-1",
                supportsImageInput: true,
                imageInputEnabled: false
            ),
            createdAt: now,
            updatedAt: now
        )
        let credential = AIProviderCredentialMetadata(
            id: "credential-1",
            profileID: "profile-1",
            providerPresetID: "openai",
            kind: .apiKey,
            label: "OpenAI API Key",
            secretPresence: .present,
            createdAt: now,
            updatedAt: now
        )
        return AIProviderConfigurationProfile(
            id: "profile-1",
            displayName: "Default AI Provider",
            isDefault: true,
            status: .configured,
            createdAt: now,
            updatedAt: now,
            endpoints: [text],
            credentials: [credential]
        )
    }
}
