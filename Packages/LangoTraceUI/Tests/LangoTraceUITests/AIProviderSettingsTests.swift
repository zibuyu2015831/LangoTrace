import Foundation
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

    @Test("Draft model validates test readiness without persisting credentials")
    func draftModelValidatesTestReadinessWithoutPersistingCredentials() {
        var draft = AIProviderDraftConfiguration(provider: .openAI)

        #expect(draft.text.endpoint.independentCredential.apiKeyStorage == .encryptedStoragePending)
        #expect(draft.testReadiness == .missingRequiredFields)
        #expect(draft.saveState == .idle)

        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        #expect(draft.testReadiness == .readyForMockRequest)

        draft.saveMockConfiguration()
        #expect(draft.saveState == .mockSavedSecurely)
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
        #expect(draft.testReadiness == .readyForMockRequest)

        draft.embedding.isEnabled = true
        draft.embedding.endpoint.credentialReference = .independent
        draft.embedding.endpoint.independentCredential.apiKeyDraft = ""
        #expect(draft.testReadiness == .missingRequiredFields)

        draft.embedding.endpoint.independentCredential.apiKeyDraft = "embedding-key"
        #expect(draft.testReadiness == .readyForMockRequest)
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
        #expect(!source.contains("URLSession"))
        #expect(!source.contains("dataTask"))
        #expect(!source.contains("uploadTask"))
        #expect(!source.contains("Authorization"))
        #expect(!source.contains("Bearer "))
    }

    @Test("Settings source has save-first secure-storage UI")
    func settingsSourceHasSaveFirstSecureStorageUI() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)

        #expect(source.contains("aiProviderSettings.save.button"))
        #expect(source.contains("aiProviderSettings.save.boundary"))
        #expect(source.contains("saveMockConfiguration()"))
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
        #expect(settingsSceneSource.contains("action: { selectedCapabilityKind = capability.kind }"))
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
}
