import LangoTraceCore
import Testing

@Test("TTS core enums use stable raw values")
func ttsCoreEnumsUseStableRawValues() {
    #expect(TTSProviderAdapterKind.openAIAudioSpeech.rawValue == "openai_audio_speech")
    #expect(TTSProviderAdapterKind.openRouterAudioSpeech.rawValue == "openrouter_audio_speech")
    #expect(TTSAudioFormat.mp3.rawValue == "mp3")
    #expect(TTSConfigurationStatus.requiresRetest.rawValue == "requires_retest")
}

@Test("Voice profile fingerprint changes only for output-affecting fields")
func voiceProfileFingerprintChangesOnlyForOutputAffectingFields() throws {
    let baseline = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "tts-1",
        voiceID: "coral",
        outputFormat: .mp3,
        speed: 1.0,
        instructions: "Calm and clear.",
        providerParameters: ["response_format": .string("mp3")]
    )

    let displayNameChanged = try baseline.reconfigured(voiceDisplayName: "Coral voice")
    #expect(displayNameChanged.configurationFingerprint == baseline.configurationFingerprint)

    let voiceChanged = try baseline.reconfigured(voiceID: "alloy")
    let speedChanged = try baseline.reconfigured(speed: 1.12)
    let instructionsChanged = try baseline.reconfigured(instructions: "Energetic.")

    #expect(voiceChanged.configurationFingerprint != baseline.configurationFingerprint)
    #expect(speedChanged.configurationFingerprint != baseline.configurationFingerprint)
    #expect(instructionsChanged.configurationFingerprint != baseline.configurationFingerprint)
}

@Test("Voice profile successful fingerprint updates only after successful probe")
func voiceProfileSuccessfulFingerprintUpdatesOnlyAfterSuccessfulProbe() throws {
    let profile = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "tts-1",
        voiceID: "coral",
        outputFormat: .mp3
    )

    #expect(profile.playbackReadiness == .notTested)
    #expect(profile.withProbeOutcome(.failed, testedAt: nil).lastSuccessfulConfigurationFingerprint == nil)

    let succeeded = profile.withProbeOutcome(.succeeded, testedAt: nil)
    #expect(succeeded.lastSuccessfulConfigurationFingerprint == profile.configurationFingerprint)
    #expect(succeeded.playbackReadiness == .succeeded)

    let changedAfterSuccess = try succeeded.reconfigured(speed: 1.2)
    #expect(changedAfterSuccess.playbackReadiness == .requiresRetest)
}

@Test("Provider parameter canonical serialization sorts keys and stays stable")
func providerParameterCanonicalSerializationSortsKeysAndStaysStable() {
    let parameters: [String: TTSProviderParameterValue] = [
        "response_format": .string("mp3"),
        "provider_options": .object([
            "order": .array([.string("openai"), .number(1), .bool(true)]),
            "allow_fallbacks": .bool(false),
        ]),
    ]

    let expected = "provider_options={allow_fallbacks=b:false;order=[s:openai,n:1.0,b:true]};response_format=s:mp3"
    #expect(TTSProviderParameterValue.canonicalSerialization(of: parameters) == expected)
}

@Test("Voice profile fingerprint ignores provider parameter insertion order")
func voiceProfileFingerprintIgnoresProviderParameterInsertionOrder() throws {
    let first = try TTSVoiceProfile.make(
        id: "voice-or",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openRouterAudioSpeech,
        modelName: "openai/tts-1",
        voiceID: "coral",
        outputFormat: .mp3,
        providerParameters: [
            "response_format": .string("mp3"),
            "provider_options": .object(["order": .array([.string("openai")])]),
        ]
    )
    let second = try TTSVoiceProfile.make(
        id: "voice-or",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openRouterAudioSpeech,
        modelName: "openai/tts-1",
        voiceID: "coral",
        outputFormat: .mp3,
        providerParameters: [
            "provider_options": .object(["order": .array([.string("openai")])]),
            "response_format": .string("mp3"),
        ]
    )

    #expect(first.configurationFingerprint == second.configurationFingerprint)
}

@Test("Provider parameter allowlist rejects unknown keys")
func providerParameterAllowlistRejectsUnknownKeys() throws {
    #expect(throws: TTSProviderConfigurationError.unsupportedProviderParameter("unknown")) {
        _ = try TTSVoiceProfile.make(
            id: "voice-en",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "coral",
            outputFormat: .mp3,
            providerParameters: ["unknown": .string("value")]
        )
    }

    #expect(throws: Never.self) {
        _ = try TTSVoiceProfile.make(
            id: "voice-or",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openRouterAudioSpeech,
            modelName: "openai/tts-1",
            voiceID: "coral",
            outputFormat: .mp3,
            providerParameters: [
                "response_format": .string("mp3"),
                "provider_options": .object(["order": .array([.string("openai")])]),
            ]
        )
    }
}
