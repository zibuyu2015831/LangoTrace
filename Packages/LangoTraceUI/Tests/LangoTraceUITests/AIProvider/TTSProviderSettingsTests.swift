import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

private func ttsSettingsSourceFileURL(named fileName: String) -> URL {
    var url = URL(fileURLWithPath: #filePath)
    while url.lastPathComponent != "LangoTraceUI" {
        let parent = url.deletingLastPathComponent()
        precondition(parent.path != url.path, "Could not locate LangoTraceUI package root")
        url = parent
    }
    return url
        .appendingPathComponent("Sources")
        .appendingPathComponent("LangoTraceUI")
        .appendingPathComponent(fileName)
}

@Suite("TTS provider settings")
struct TTSProviderSettingsTests {
    @Test("First stage TTS matrix exposes only OpenAI and OpenRouter for real probe")
    func firstStageTTSMatrixExposesOnlyOpenAIAndOpenRouterForRealProbe() {
        #expect(AIProviderPreset.openAI.capabilityPolicy.speechSynthesis == .supported)
        #expect(AIProviderPreset.openRouter.capabilityPolicy.speechSynthesis == .modelDependent)
        #expect(AIProviderPreset.customOpenAICompatible.capabilityPolicy.speechSynthesis == .modelDependent)

        #expect(AIProviderPreset.openAI.firstStageTTSProbeAvailability == .realProbe)
        #expect(AIProviderPreset.openRouter.firstStageTTSProbeAvailability == .realProbe)
        #expect(AIProviderPreset.customOpenAICompatible.firstStageTTSProbeAvailability == .futureCompatible)

        for provider in [
            AIProviderPreset.anthropic,
            .deepSeek,
            .moonshotKimi,
            .ollamaLocal,
        ] {
            #expect(provider.capabilityPolicy.speechSynthesis == .unsupported)
            #expect(provider.firstStageTTSProbeAvailability == .unsupported)
        }

        for provider in [
            AIProviderPreset.gemini,
            .mistral,
            .groq,
            .xAI,
            .dashScopeQwen,
            .zhipuGLM,
            .siliconFlow,
        ] {
            #expect(provider.firstStageTTSProbeAvailability == .futureProviderSpecific)
        }
    }

    @Test("OpenAI, OpenRouter and Custom use dedicated TTS adapter kinds")
    func openAIOpenRouterAndCustomUseDedicatedTTSAdapterKinds() {
        #expect(AIProviderPreset.openAI.defaultTTSAdapterKind == .openAIAudioSpeech)
        #expect(AIProviderPreset.openRouter.defaultTTSAdapterKind == .openRouterAudioSpeech)
        #expect(AIProviderPreset.customOpenAICompatible.defaultTTSAdapterKind == .customOpenAICompatibleAudioSpeech)
    }

    @Test("OpenRouter speech defaults make an enabled TTS draft saveable and probeable")
    func openRouterSpeechDefaultsMakeEnabledTTSDraftSaveableAndProbeable() throws {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-openrouter"
        draft.speech.isEnabled = true

        #expect(draft.speech.endpoint.model == "openai/tts-1")
        #expect(draft.speech.voiceID == "nova")
        #expect(draft.saveReadiness == .readyForRequest)

        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-openrouter-tts"),
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )

        #expect(snapshot.requestedCapabilities.contains(.speechSynthesis))
        #expect(snapshot.ttsEndpoint?.providerPresetID == "openrouter")
        #expect(snapshot.ttsEndpoint?.modelName == "openai/tts-1")
        #expect(snapshot.ttsSettings?.adapterKind == .openRouterAudioSpeech)
        #expect(snapshot.ttsVoiceProfile?.voiceID == "nova")
        #expect(snapshot.ttsPlaintextSecret == "sk-openrouter")
    }

    @Test("Draft save input includes current language TTS voice profile")
    func draftSaveInputIncludesCurrentLanguageTTSVoiceProfile() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-test"
        draft.speech.isEnabled = true
        draft.speech.endpoint.model = "tts-1"
        draft.speech.voiceID = "coral"
        draft.speech.outputFormat = .mp3
        draft.speech.speed = 1.0

        let input = try draft.makeProfileSaveInput(
            languageContext: AIProviderProbeLanguageContext(languageCode: "ja")
        )

        #expect(input.ttsVoiceProfile?.endpointPurpose == .tts)
        #expect(input.ttsVoiceProfile?.languageCode == "ja")
        #expect(input.ttsVoiceProfile?.adapterKind == .openAIAudioSpeech)
        #expect(input.ttsVoiceProfile?.voiceID == "coral")
        #expect(input.ttsVoiceProfile?.outputFormat == .mp3)
        #expect(input.ttsVoiceProfile?.speed == 1.0)
    }

    @Test("Loaded profile reapplies persisted TTS voice profile fields")
    func loadedProfileReappliesPersistedTTSVoiceProfileFields() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        let profile = try loadedTTSProfile()
        draft.applyLoadedProfile(profile)
        let persistedVoice = try TTSVoiceProfile.make(
            id: "voice-ja",
            endpointID: "endpoint-tts",
            languageCode: "ja",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "alloy",
            voiceDisplayName: "Alloy",
            outputFormat: .wav,
            speed: 0.85,
            instructions: "Read gently."
        )

        draft.applyLoadedTTSVoiceProfile(persistedVoice)

        #expect(draft.speech.voiceID == "alloy")
        #expect(draft.speech.voiceDisplayName == "Alloy")
        #expect(draft.speech.outputFormat == .wav)
        #expect(draft.speech.speed == 0.85)
        #expect(draft.speech.instructions == "Read gently.")
    }

    @Test("Draft probe snapshot carries TTS endpoint settings and current language voice profile")
    func draftProbeSnapshotCarriesTTSEndpointSettingsAndCurrentLanguageVoiceProfile() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-test"
        draft.speech.isEnabled = true
        draft.speech.endpoint.model = "tts-1"
        draft.speech.voiceID = "coral"

        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-tts"),
            languageContext: AIProviderProbeLanguageContext(languageCode: "ko")
        )

        #expect(snapshot.requestedCapabilities.contains(.speechSynthesis))
        #expect(snapshot.ttsEndpoint?.purpose == .tts)
        #expect(snapshot.ttsSettings?.adapterKind == .openAIAudioSpeech)
        #expect(snapshot.ttsVoiceProfile?.languageCode == "ko")
        #expect(snapshot.ttsVoiceProfile?.voiceID == "coral")
        #expect(snapshot.ttsPlaintextSecret == "sk-test")
    }

    @Test("Speech model section exposes user-facing TTS controls")
    func speechModelSectionExposesUserFacingTTSControls() throws {
        let componentSource = try String(
            contentsOf: ttsSettingsSourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: ttsSettingsSourceFileURL(named: "AIProviderSettingsView.swift"),
            encoding: .utf8
        )
        let actionsSource = try String(
            contentsOf: ttsSettingsSourceFileURL(named: "AIProviderSettingsActions.swift"),
            encoding: .utf8
        )
        let strings = try String(
            contentsOf: ttsSettingsSourceFileURL(named: "Resources/Localizable.xcstrings"),
            encoding: .utf8
        )

        assertSpeechTTSControlResources(componentSource: componentSource, strings: strings)
        assertSpeechTTSControlStructure(componentSource: componentSource, strings: strings)
        #expect(componentSource.contains("onPlaySpeechPreview"))
        #expect(componentSource.contains("speaker.wave.2"))
        #expect(viewSource.contains("actions.playSpeechPreview"))
        #expect(actionsSource.contains("playSpeechPreview"))
        #expect(!componentSource.contains("aiProviderSettings.speechModel.adapter"))
    }
}

private func assertSpeechTTSControlResources(componentSource: String, strings: String) {
    for key in [
        "aiProviderSettings.speechModel.parametersTitle",
        "aiProviderSettings.speechModel.voiceTitle",
        "aiProviderSettings.speechModel.voiceHelp",
        "aiProviderSettings.speechModel.formatTitle",
        "aiProviderSettings.speechModel.formatHelp",
        "aiProviderSettings.speechModel.speedTitle",
        "aiProviderSettings.speechModel.speedHelp",
        "aiProviderSettings.speechModel.instructionsTitle",
        "aiProviderSettings.speechModel.instructionsHelp",
    ] {
        #expect(componentSource.contains(key))
        #expect(strings.contains("\"\(key)\""))
    }

    #expect(strings.contains("\"value\": \"Speaking style\""))
    #expect(strings.contains("\"value\": \"朗读风格\""))
    #expect(!strings.contains("\"value\": \"朗读指令\""))
}

private func assertSpeechTTSControlStructure(componentSource: String, strings _: String) {
    #expect(componentSource.contains("speechTTSFields"))
    #expect(componentSource.contains("TTSMenuSettingRow"))
    #expect(componentSource.contains("TTSSpeedSettingRow"))
    #expect(componentSource.contains("TTSAudioFormat.allCases"))
    #expect(!componentSource.contains("Stepper(value: speedBinding"))
}

private func loadedTTSProfile() throws -> AIProviderConfigurationProfile {
    let now = Date(timeIntervalSince1970: 10)
    let textEndpoint = try loadedTTSTextEndpoint(now: now)
    let ttsEndpoint = try loadedTTSEndpoint(now: now)
    let credential = loadedTTSCredential(now: now)
    return AIProviderConfigurationProfile(
        id: "profile",
        displayName: "Default AI Provider",
        isDefault: true,
        status: .configured,
        createdAt: now,
        updatedAt: now,
        endpoints: [textEndpoint, ttsEndpoint],
        credentials: [credential]
    )
}

private func loadedTTSTextEndpoint(now: Date) throws -> AIProviderEndpointConfiguration {
    try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-text",
            profileID: "profile",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-5-mini",
            credentialID: "credential",
            supportsImageInput: true,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
}

private func loadedTTSEndpoint(now: Date) throws -> AIProviderEndpointConfiguration {
    try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-tts",
            profileID: "profile",
            purpose: .tts,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "tts-1",
            credentialID: "credential",
            supportsImageInput: false,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
}

private func loadedTTSCredential(now: Date) -> AIProviderCredentialMetadata {
    AIProviderCredentialMetadata(
        id: "credential",
        profileID: "profile",
        providerPresetID: "openai",
        kind: .apiKey,
        label: "OpenAI API Key",
        keychainService: "LangoTrace.Tests",
        keychainAccessGroup: nil,
        keychainSynchronizable: false,
        keychainAccessibility: "afterFirstUnlockThisDeviceOnly",
        secretPresence: .unknown,
        cleanupState: .active,
        createdAt: now,
        updatedAt: now
    )
}
