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

    @Test("OpenAI and Custom use dedicated audio/speech TTS adapter; OpenRouter uses openRouterAudioSpeech")
    func openAIAndCustomUseDedicatedTTSAdapterOpenRouterUsesAudioSpeech() {
        #expect(AIProviderPreset.openAI.defaultTTSAdapterKind == .openAIAudioSpeech)
        // OpenRouter /audio/speech works with kokoro-82m and other TTS models (confirmed 2026-06-16).
        #expect(AIProviderPreset.openRouter.defaultTTSAdapterKind == .openRouterAudioSpeech)
        #expect(AIProviderPreset.customOpenAICompatible.defaultTTSAdapterKind == .customOpenAICompatibleAudioSpeech)
    }

    @Test("MIMO uses mimoTTS adapter, supports TTS with real probe, and defaults to Chloe voice")
    func mimoUsesMimoTTSAdapterAndSupportsTTSWithRealProbe() {
        #expect(AIProviderPreset.mimo.defaultTTSAdapterKind == .mimoTTS)
        #expect(AIProviderPreset.mimo.defaultSpeechModel == "mimo-v2.5-tts")
        #expect(AIProviderPreset.mimo.defaultTTSVoiceID == "Chloe")
        #expect(AIProviderPreset.mimo.capabilityPolicy.speechSynthesis == .supported)
        #expect(AIProviderPreset.mimo.firstStageTTSProbeAvailability == .realProbe)
    }

    @Test("OpenAI default TTS model is gpt-4o-mini-tts which supports the coral voice default")
    func openAIDefaultTTSModelIsGptMiniTTSSupportingCoralVoice() {
        // coral is NOT supported by tts-1; using tts-1 as the default causes providerRejected probe failures.
        // The default model must be gpt-4o-mini-tts (dedicated TTS model, not conversational audio).
        #expect(AIProviderPreset.openAI.defaultSpeechModel == "gpt-4o-mini-tts")
        #expect(AIProviderPreset.openAI.defaultTTSVoiceID == "coral")

        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.speech.isEnabled = true
        #expect(draft.speech.endpoint.model == "gpt-4o-mini-tts")
    }

    @Test("OpenRouter speech defaults make an enabled TTS draft saveable and probeable")
    func openRouterSpeechDefaultsMakeEnabledTTSDraftSaveableAndProbeable() throws {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-openrouter"
        draft.speech.isEnabled = true

        // OpenRouter now uses /audio/speech with hexgrad/kokoro-82m (confirmed mp3 + pcm support).
        #expect(draft.speech.endpoint.model == "hexgrad/kokoro-82m")
        #expect(draft.speech.voiceID == "af_heart")
        #expect(draft.speech.outputFormat == .mp3)
        #expect(draft.saveReadiness == .readyForRequest)

        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-openrouter-tts"),
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )

        #expect(snapshot.requestedCapabilities.contains(.speechSynthesis))
        #expect(snapshot.ttsEndpoint?.providerPresetID == "openrouter")
        #expect(snapshot.ttsEndpoint?.modelName == "hexgrad/kokoro-82m")
        #expect(snapshot.ttsSettings?.adapterKind == .openRouterAudioSpeech)
        #expect(snapshot.ttsVoiceProfile?.voiceID == "af_heart")
        #expect(snapshot.ttsVoiceProfile?.outputFormat == .mp3)
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

    @Test("Loaded legacy OpenAI TTS config upgrades coral voice away from tts-1 before save and probe")
    func loadedLegacyOpenAITTSConfigUpgradesCoralVoiceAwayFromTTS1BeforeSaveAndProbe() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        try draft.applyLoadedProfile(loadedTTSProfile())
        try draft.applyLoadedTTSVoiceProfile(
            TTSVoiceProfile.make(
                id: "voice-en",
                endpointID: "endpoint-tts",
                languageCode: "en",
                adapterKind: .openAIAudioSpeech,
                modelName: "tts-1",
                voiceID: "coral",
                outputFormat: .mp3
            )
        )

        #expect(draft.speech.endpoint.model == "gpt-4o-mini-tts")

        let saveInput = try draft.makeProfileSaveInput(
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
        let ttsEndpoint = try #require(saveInput.endpoints.first { $0.purpose == .tts })
        #expect(ttsEndpoint.modelName == "gpt-4o-mini-tts")

        let probeSnapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-openai-legacy-tts"),
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
        #expect(probeSnapshot.ttsEndpoint?.modelName == "gpt-4o-mini-tts")
        #expect(probeSnapshot.ttsVoiceProfile?.voiceID == "coral")
    }

    @Test("Loaded legacy OpenRouter TTS config (gpt-4o-mini-audio-preview) normalizes to gpt-audio-mini before save and probe")
    func loadedLegacyOpenRouterTTSConfigNormalizesPreviewModelToGptAudioMini() throws {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        try draft.applyLoadedProfile(loadedOpenRouterTTSProfile())
        try draft.applyLoadedTTSVoiceProfile(
            TTSVoiceProfile.make(
                id: "voice-en-openrouter",
                endpointID: "endpoint-tts-openrouter",
                languageCode: "en",
                adapterKind: .openRouterMultimodalAudio,
                modelName: "openai/gpt-4o-mini-audio-preview",
                voiceID: "nova",
                outputFormat: .mp3,
                instructions: "Speak clearly and naturally for a language-learning app."
            )
        )

        // Legacy model must normalize to the working multimodal audio model.
        #expect(draft.speech.endpoint.model == "openai/gpt-audio-mini")

        let saveInput = try draft.makeProfileSaveInput(
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
        let ttsEndpoint = try #require(saveInput.endpoints.first { $0.purpose == .tts })
        #expect(ttsEndpoint.modelName == "openai/gpt-audio-mini")

        let probeSnapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-openrouter-legacy-tts"),
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
        #expect(probeSnapshot.ttsEndpoint?.modelName == "openai/gpt-audio-mini")
        #expect(probeSnapshot.ttsVoiceProfile?.voiceID == "nova")
    }

    @Test("Loaded legacy OpenRouter TTS config (gpt-audio-mini) stays on gpt-audio-mini (already the working model)")
    func loadedLegacyOpenRouterTTSConfigGptAudioMiniStaysOnGptAudioMini() throws {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        try draft.applyLoadedProfile(loadedOpenRouterTTSProfile())
        try draft.applyLoadedTTSVoiceProfile(
            TTSVoiceProfile.make(
                id: "voice-en-openrouter",
                endpointID: "endpoint-tts-openrouter",
                languageCode: "en",
                adapterKind: .openRouterMultimodalAudio,
                modelName: "openai/gpt-audio-mini",
                voiceID: "nova",
                outputFormat: .mp3
            )
        )

        #expect(draft.speech.endpoint.model == "openai/gpt-audio-mini")

        let probeSnapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-openrouter-legacy-tts-2"),
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
        #expect(probeSnapshot.ttsEndpoint?.modelName == "openai/gpt-audio-mini")
        #expect(probeSnapshot.ttsVoiceProfile?.voiceID == "nova")
    }

    // MARK: - supportedOutputFormats

    @Test("openAIAudioSpeech supports all 6 standard formats (mp3, opus, aac, flac, wav, pcm)")
    func openAIAudioSpeechSupportedFormats() {
        let formats = TTSProviderAdapterKind.openAIAudioSpeech.supportedOutputFormats
        #expect(formats.count == 6)
        #expect(formats.contains(.mp3))
        #expect(formats.contains(.opus))
        #expect(formats.contains(.aac))
        #expect(formats.contains(.flac))
        #expect(formats.contains(.wav))
        #expect(formats.contains(.pcm))
        #expect(!formats.contains(.mulaw))
    }

    @Test("openRouterAudioSpeech supports exactly mp3 and pcm (confirmed by live API probe 2026-06-16)")
    func openRouterAudioSpeechSupportedFormats() {
        let formats = TTSProviderAdapterKind.openRouterAudioSpeech.supportedOutputFormats
        #expect(formats == [.mp3, .pcm])
    }

    @Test("mimoTTS supports only wav (adapter and API hardcode WAV output)")
    func mimoTTSSupportedFormats() {
        let formats = TTSProviderAdapterKind.mimoTTS.supportedOutputFormats
        #expect(formats == [.wav])
    }

    @Test("openRouterMultimodalAudio supports only pcm (request hardcodes pcm16; user cannot change wire format)")
    func openRouterMultimodalAudioSupportedFormats() {
        let formats = TTSProviderAdapterKind.openRouterMultimodalAudio.supportedOutputFormats
        #expect(formats == [.pcm])
    }

    @Test("customOpenAICompatibleAudioSpeech exposes all TTSAudioFormat cases")
    func customOpenAICompatibleAudioSpeechSupportedFormats() {
        let formats = TTSProviderAdapterKind.customOpenAICompatibleAudioSpeech.supportedOutputFormats
        #expect(formats.count == TTSAudioFormat.allCases.count)
    }

    @Test("OpenRouter speech draft initialises with mp3 (first format in openRouterAudioSpeech.supportedOutputFormats)")
    func openRouterSpeechDraftInitialisesWithMp3() {
        let draft = AIProviderDraftConfiguration(provider: .openRouter)
        #expect(draft.speech.outputFormat == .mp3)
    }

    @Test("Switching TTS provider to OpenRouter resets output format to mp3")
    func switchingTTSProviderToOpenRouterResetsOutputFormatToMp3() {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.speech.outputFormat = .opus
        draft.speech.updateProvider(.openRouter, shareTextCredentialWhenSameProvider: false)
        #expect(draft.speech.outputFormat == .mp3)
    }

    @Test("Switching TTS provider from OpenRouter (mp3) to OpenAI keeps mp3 because OpenAI also supports it")
    func switchingFromOpenRouterToOpenAIKeepsMp3WhenOpenAISupportsIt() {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        // openRouter defaults to mp3; switching to openAI should default to mp3 (first supported format)
        draft.speech.updateProvider(.openAI, shareTextCredentialWhenSameProvider: false)
        #expect(draft.speech.outputFormat == .mp3)
    }

    // MARK: - MIMO save input omits response_format

    @Test("MIMO save input omits response_format from TTS providerParameters to avoid Keychain rollback")
    func mimoSaveInputOmitsResponseFormatFromTTSProviderParametersToAvoidKeychainRollback() throws {
        var draft = AIProviderDraftConfiguration(provider: .mimo)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-mimo-test-key"
        draft.speech.isEnabled = true

        // mimoTTS.allowedProviderParameterKeys == ["voice_design_prompt"] — "response_format" is NOT
        // allowed. If present, TTSVoiceProfile.make throws unsupportedProviderParameter, which causes
        // the service layer to call cleanupCreatedSecrets and delete the freshly written Keychain entry.
        let input = try draft.makeProfileSaveInput(
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
        #expect(input.ttsVoiceProfile?.adapterKind == .mimoTTS)
        #expect(input.ttsVoiceProfile?.providerParameters["response_format"] == nil)
        #expect(input.ttsVoiceProfile?.providerParameters.isEmpty == true)
    }

    @Test("MIMO speech draft initialises with WAV output format because adapter hardcodes WAV")
    func mimoSpeechDraftInitialisesWithWAVOutputFormat() {
        let draft = AIProviderDraftConfiguration(provider: .mimo)
        // MimoTTSAdapter.decodedAudioFormat always returns .wav regardless of outputFormat.
        // The draft must default to .wav so the stored voice profile matches the actual audio.
        #expect(draft.speech.outputFormat == .wav)
    }

    @Test("Switching TTS provider to MIMO resets output format to WAV")
    func switchingTTSProviderToMimoResetsOutputFormatToWAV() {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        #expect(draft.speech.outputFormat == .mp3)

        draft.speech.updateProvider(.mimo, shareTextCredentialWhenSameProvider: false)
        #expect(draft.speech.outputFormat == .wav)
    }

    @Test("MIMO speech draft can be saved without instructions field")
    func mimoSpeechDraftCanBeSavedWithoutInstructionsField() throws {
        var draft = AIProviderDraftConfiguration(provider: .mimo)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-mimo-test-key"
        draft.speech.isEnabled = true
        // instructions is nil by default; MIMO adapter ignores it.
        #expect(draft.speech.instructions == nil)
        #expect(draft.saveReadiness == .readyForRequest)
        let input = try draft.makeProfileSaveInput(
            languageContext: AIProviderProbeLanguageContext(languageCode: "zh")
        )
        #expect(input.ttsVoiceProfile != nil)
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
        "aiProviderSettings.speechModel.speedTitle",
        "aiProviderSettings.speechModel.instructionsTitle",
        "aiProviderSettings.speechModel.instructionsHelp",
    ] {
        #expect(componentSource.contains(key))
        #expect(strings.contains("\"\(key)\""))
    }

    // formatHelp and speedHelp are intentionally removed — those hints were noise.

    #expect(strings.contains("\"value\": \"Speaking style\""))
    #expect(strings.contains("\"value\": \"朗读风格\""))
    #expect(!strings.contains("\"value\": \"朗读指令\""))
}

private func assertSpeechTTSControlStructure(componentSource: String, strings _: String) {
    #expect(componentSource.contains("speechTTSFields"))
    #expect(componentSource.contains("TTSMenuSettingRow"))
    #expect(componentSource.contains("TTSSpeedSettingRow"))
    #expect(componentSource.contains("supportedOutputFormats"))
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

private func loadedOpenRouterTTSProfile() throws -> AIProviderConfigurationProfile {
    let now = Date(timeIntervalSince1970: 20)
    let textEndpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-text-openrouter",
            profileID: "profile-openrouter",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: "openrouter",
            adapterKind: .openAICompatibleChat,
            baseURL: "https://openrouter.ai/api/v1",
            modelName: "openai/gpt-4o",
            credentialID: "credential-openrouter",
            supportsImageInput: true,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
    let ttsEndpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-tts-openrouter",
            profileID: "profile-openrouter",
            purpose: .tts,
            isEnabled: true,
            providerPresetID: "openrouter",
            adapterKind: .openAICompatibleChat,
            baseURL: "https://openrouter.ai/api/v1",
            modelName: "openai/gpt-4o-mini-audio-preview",
            credentialID: "credential-openrouter",
            supportsImageInput: false,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
    let credential = AIProviderCredentialMetadata(
        id: "credential-openrouter",
        profileID: "profile-openrouter",
        providerPresetID: "openrouter",
        kind: .apiKey,
        label: "OpenRouter API Key",
        keychainService: "LangoTrace.Tests",
        keychainAccessGroup: nil,
        keychainSynchronizable: false,
        keychainAccessibility: "afterFirstUnlockThisDeviceOnly",
        secretPresence: .unknown,
        cleanupState: .active,
        createdAt: now,
        updatedAt: now
    )
    return AIProviderConfigurationProfile(
        id: "profile-openrouter",
        displayName: "OpenRouter",
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
