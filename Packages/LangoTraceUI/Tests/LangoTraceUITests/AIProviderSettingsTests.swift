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

        #expect(draft.apiKeyStorage == .encryptedStoragePending)
        #expect(draft.testReadiness == .missingRequiredFields)
        #expect(draft.saveState == .idle)

        draft.apiKeyDraft = "sk-local-draft"
        #expect(draft.testReadiness == .readyForMockRequest)

        draft.saveMockConfiguration()
        #expect(draft.saveState == .mockSavedSecurely)
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

    @Test("Text input modifier is a single chained iOS expression")
    func textInputModifierIsSingleChainedIOSExpression() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
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
