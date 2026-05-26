import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

private func langoTraceUIPackageRootURL(currentFilePath: String = #filePath) -> URL {
    var url = URL(fileURLWithPath: currentFilePath)
    while url.lastPathComponent != "LangoTraceUI" {
        let parent = url.deletingLastPathComponent()
        precondition(parent.path != url.path, "Could not locate LangoTraceUI package root")
        url = parent
    }
    return url
}

private func langoTraceUISourceFileURL(named fileName: String, currentFilePath: String = #filePath) -> URL {
    langoTraceUIPackageRootURL(currentFilePath: currentFilePath)
        .appendingPathComponent("Sources")
        .appendingPathComponent("LangoTraceUI")
        .appendingPathComponent(fileName)
}

private func langoTraceAppSourceFileURL(named fileName: String, currentFilePath: String = #filePath) -> URL {
    langoTraceUIPackageRootURL(currentFilePath: currentFilePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("LangoTraceApp")
        .appendingPathComponent(fileName)
}

@Suite("AI provider settings")
// swiftlint:disable:next type_body_length
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

    @Test("Saved profile applies returned credential IDs so later edits remain saveable")
    func savedProfileAppliesReturnedCredentialIDsSoLaterEditsRemainSaveable() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "text-secret"
        draft.speech.isEnabled = true
        draft.speech.endpoint.credentialReference = .textModelCredential

        let savedProfile = try loadedProfile()
        draft.applySavedProfile(savedProfile)

        #expect(draft.text.endpoint.credentialID == "credential-1")
        #expect(draft.speech.endpoint.credentialID == "credential-1")
        #expect(draft.speech.endpoint.credentialReference == .textModelCredential)
        #expect(draft.text.endpoint.independentCredential.apiKeyDraft.isEmpty)
        #expect(draft.saveReadiness == .readyForRequest)

        draft.text.endpoint.model = "gpt-5.3"
        let input = try draft.makeProfileSaveInput()
        #expect(input.endpoints.first?.credentialMode == .existing("credential-1"))
    }

    @Test("Saved profile can restore resolved API key without marking unsaved")
    func savedProfileCanRestoreResolvedAPIKeyWithoutMarkingUnsaved() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "text-secret"

        try draft.applySavedProfile(
            loadedProfile(),
            resolvedSecretsByCredentialID: ["credential-1": "text-secret"]
        )

        #expect(draft.text.endpoint.independentCredential.apiKeyDraft == "text-secret")
        #expect(draft.saveState == .saved)
        #expect(draft.saveReadiness == .readyForRequest)
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

        #expect(detailSource.contains("AIProviderSettingsView("))
        #expect(detailSource.contains("AIProviderProbeLanguageContext(languageCode: languageSpace.targetLanguageCode)"))
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
        langoTraceUISourceFileURL(named: fileName)
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

@Suite("AI provider capability resolver")
struct AIProviderCapabilityResolverTests {
    @Test("OpenAI image input is supported through the responses adapter")
    func openAIImageInputIsSupportedThroughResponsesAdapter() {
        let decision = imageInputDecision(
            provider: .openAI,
            adapterKind: .openAIResponses,
            modelName: "gpt-5.2"
        )

        #expect(decision.support == .supported)
        #expect(decision.canToggle)
        #expect(decision.canProbe)
        #expect(!decision.requiresUserAssertion)
        #expect(decision.shouldPersistImageSupport)
    }

    @Test("OpenRouter and custom image input are model dependent")
    func openRouterAndCustomImageInputAreModelDependent() {
        let openRouter = imageInputDecision(
            provider: .openRouter,
            adapterKind: .openAICompatibleChat,
            modelName: "openai/gpt-5.4-image-2"
        )
        let custom = imageInputDecision(
            provider: .customOpenAICompatible,
            adapterKind: .openAICompatibleChat,
            modelName: "vision-model"
        )

        #expect(openRouter.support == .modelDependent)
        #expect(openRouter.canToggle)
        #expect(openRouter.canProbe)
        #expect(openRouter.requiresUserAssertion)
        #expect(openRouter.shouldPersistImageSupport)
        #expect(custom.support == .modelDependent)
        #expect(custom.canToggle)
        #expect(custom.canProbe)
        #expect(custom.requiresUserAssertion)
    }

    @Test("Unsupported adapters and providers cannot probe image input")
    func unsupportedAdaptersAndProvidersCannotProbeImageInput() {
        let gemini = imageInputDecision(
            provider: .gemini,
            adapterKind: .geminiGenerateContent,
            modelName: "gemini-2.5-flash"
        )
        let anthropic = imageInputDecision(
            provider: .anthropic,
            adapterKind: .anthropicMessages,
            modelName: "claude-sonnet-4-5"
        )
        let deepSeek = imageInputDecision(
            provider: .deepSeek,
            adapterKind: .openAICompatibleChat,
            modelName: "deepseek-v4-flash"
        )

        #expect(gemini.support == .adapterUnsupported)
        #expect(!gemini.canToggle)
        #expect(!gemini.canProbe)
        #expect(anthropic.support == .adapterUnsupported)
        #expect(!anthropic.canToggle)
        #expect(!anthropic.canProbe)
        #expect(deepSeek.support == .unsupported)
        #expect(!deepSeek.canToggle)
        #expect(!deepSeek.canProbe)
    }

    @Test("Non text endpoints cannot carry image input capability")
    func nonTextEndpointsCannotCarryImageInputCapability() {
        let decision = AIProviderEndpointCapabilityResolver.imageInputDecision(
            provider: .openRouter,
            adapterKind: .openAICompatibleChat,
            purpose: .embedding,
            modelName: "openai/gpt-5.4-image-2"
        )

        #expect(decision.support == .unsupported)
        #expect(!decision.canToggle)
        #expect(!decision.canProbe)
    }

    @Test("Embedding probe is allowlisted to first stage providers")
    func embeddingProbeIsAllowlistedToFirstStageProviders() {
        let openAI = embeddingDecision(provider: .openAI, modelName: "text-embedding-3-small")
        let openRouter = embeddingDecision(provider: .openRouter, modelName: "openai/text-embedding-3-small")
        let custom = embeddingDecision(provider: .customOpenAICompatible, modelName: "embedding-model")
        let deepSeek = embeddingDecision(provider: .deepSeek, modelName: "deepseek-embedding")
        let anthropic = AIProviderEndpointCapabilityResolver.embeddingDecision(
            provider: .anthropic,
            adapterKind: .anthropicMessages,
            purpose: .embedding,
            modelName: "claude-sonnet-4-5"
        )

        #expect(openAI.support == .supported)
        #expect(openAI.canProbe)
        #expect(openRouter.support == .modelDependent)
        #expect(openRouter.canProbe)
        #expect(custom.support == .modelDependent)
        #expect(custom.canProbe)
        #expect(deepSeek.support == .unsupported)
        #expect(!deepSeek.canProbe)
        #expect(anthropic.support == .unsupported)
        #expect(!anthropic.canProbe)
    }

    private func imageInputDecision(
        provider: AIProviderPreset,
        adapterKind: LangoTraceUI.AIProviderAdapterKind,
        modelName: String
    ) -> AIProviderCapabilityDecision {
        AIProviderEndpointCapabilityResolver.imageInputDecision(
            provider: provider,
            adapterKind: adapterKind,
            purpose: .textGeneration,
            modelName: modelName
        )
    }

    private func embeddingDecision(
        provider: AIProviderPreset,
        modelName: String
    ) -> AIProviderCapabilityDecision {
        AIProviderEndpointCapabilityResolver.embeddingDecision(
            provider: provider,
            adapterKind: provider.adapterKind,
            purpose: .embedding,
            modelName: modelName
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

    @Test("iPad auxiliary AI provider shortcut does not advertise the real settings form as mock")
    func iPadAuxiliaryAIProviderShortcutDoesNotAdvertiseRealSettingsFormAsMock() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PadLearningPanelView.swift"), encoding: .utf8)
        let staleMockStatusNeedle = """
        status: .mockOnly,
                        systemImage: SettingsCapability.Kind.aiProvider.systemImage,
                        action: { onRoute(.settings(.aiProvider)) }
        """

        #expect(source.contains("localizedTitleKey: SettingsCapability.Kind.aiProvider.localizedTitleKey"))
        #expect(source.contains("action: { onRoute(.settings(.aiProvider)) }"))
        #expect(!source.contains(staleMockStatusNeedle))
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

        #expect(detailSource.contains("AIProviderSettingsView("))
        #expect(detailSource.contains("AIProviderProbeLanguageContext(languageCode: languageSpace.targetLanguageCode)"))
        #expect(detailSource.contains("aiProviderSettingsContainer"))
        #expect(detailSource.contains("aiProviderSettingsContentMaxWidth"))
        #expect(detailSource.contains(".frame(maxWidth: aiProviderSettingsContentMaxWidth, alignment: .leading)"))
        #expect(detailSource.contains("#if os(macOS)"))
        #expect(detailSource.contains("860"))
        #expect(detailSource.contains("820"))
        #expect(!detailSource.contains("PadAIProviderSettingsView"))
        #expect(!detailSource.contains("MacAIProviderSettingsView"))
    }

    @Test("AI provider detail keeps system settings chrome without language-space header")
    func aiProviderDetailKeepsSystemSettingsChromeWithoutLanguageSpaceHeader() throws {
        let detailSource = try String(
            contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"),
            encoding: .utf8
        )

        #expect(detailSource.contains("showsCapabilityHeader"))
        #expect(detailSource.contains("case .aiProvider:"))
        #expect(detailSource.contains("case .aiProvider:\n            false"))
        #expect(detailSource.contains("if showsCapabilityHeader {"))
        #expect(detailSource.contains("AIProviderProbeLanguageContext(languageCode: languageSpace.targetLanguageCode)"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        langoTraceUISourceFileURL(named: fileName)
    }

    private func appSourceFileURL(named fileName: String) -> URL {
        langoTraceAppSourceFileURL(named: fileName)
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
        langoTraceUISourceFileURL(named: fileName)
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

    @Test("Loaded profile can resave non secret edits with existing credential")
    func loadedProfileCanResaveNonSecretEditsWithExistingCredential() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        try draft.applyLoadedProfile(loadedProfile())
        draft.text.endpoint.model = "gpt-5.3"

        let input = try draft.makeProfileSaveInput()

        #expect(draft.saveReadiness == .readyForRequest)
        #expect(input.endpoints.first?.credentialMode == .existing("credential-1"))
    }

    @Test("Loaded text credential can be shared by newly enabled speech without plaintext")
    func loadedTextCredentialCanBeSharedByNewlyEnabledSpeechWithoutPlaintext() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        try draft.applyLoadedProfile(loadedProfile())
        draft.speech.isEnabled = true
        draft.speech.endpoint.provider = .openAI
        draft.speech.endpoint.baseURL = "https://api.openai.com/v1"
        draft.speech.endpoint.model = "gpt-4o-mini-tts"
        draft.speech.endpoint.credentialReference = .textModelCredential
        draft.speech.voiceID = "nova"

        let input = try draft.makeProfileSaveInput()

        #expect(draft.text.endpoint.independentCredential.apiKeyDraft.isEmpty)
        #expect(draft.saveReadiness == .readyForRequest)
        #expect(input.endpoints.first { $0.purpose == .textGeneration }?.credentialMode == .existing("credential-1"))
        #expect(input.endpoints.first { $0.purpose == .tts }?.credentialMode == .sharedWithPurpose(.textGeneration))
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

    @Test("Settings view does not resolve secrets when loading or saving profile")
    func settingsViewDoesNotResolveSecretsWhenLoadingOrSavingProfile() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("draft.applyLoadedProfile(profile)"))
        #expect(source.contains("draft.applySavedProfile(profile)"))
        #expect(!source.contains("resolvedSecretsByCredentialID(for: profile)"))
    }

    @Test("Settings view does not log secret metadata while avoiding load time resolution")
    func settingsViewDoesNotLogSecretMetadataWhileAvoidingLoadTimeResolution() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"),
            encoding: .utf8
        )

        #expect(!source.contains("actions.resolveCredentialSecret(credential)"))
        #expect(!source.contains("credential.keychainAccount"))
        #expect(!source.contains("credential.keychainService"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        langoTraceUISourceFileURL(named: fileName)
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
