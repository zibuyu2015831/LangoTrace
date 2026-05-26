import LangoTraceCore
import Testing

@Test("Configuration probe descriptor is non secret and capability result can represent draft and saved outcomes")
func configurationProbeDescriptorIsNonSecretAndResultTracksPersistence() {
    let operationID = DiagnosticOperationID(rawValue: "probe-operation-1")
    let descriptor = AIProviderConfigurationProbeDescriptor(
        source: .draft,
        requestedCapabilities: [.textReply, .structuredJSON],
        operationID: operationID
    )

    #expect(descriptor.source == .draft)
    #expect(descriptor.requestedCapabilities == [.textReply, .structuredJSON])
    #expect(descriptor.operationID == operationID)

    let draftResult = AIProviderConfigurationProbeResult(
        source: .draft,
        overallStatus: .succeeded,
        providerPresetID: "openai",
        modelName: "gpt-5.2",
        capabilities: [
            AIProviderProbeCapabilityResult(
                capability: .textReply,
                status: .succeeded,
                errorCategory: nil,
                durationMilliseconds: 120
            ),
        ],
        persistedValidationEventID: nil
    )
    let savedResult = AIProviderConfigurationProbeResult(
        source: .savedProfile,
        overallStatus: .failed,
        providerPresetID: "openai",
        modelName: "gpt-5.2",
        capabilities: [
            AIProviderProbeCapabilityResult(
                capability: .structuredJSON,
                status: .failed,
                errorCategory: .invalidResponse,
                durationMilliseconds: 140
            ),
        ],
        persistedValidationEventID: "validation-event-1"
    )

    #expect(draftResult.persistedValidationEventID == nil)
    #expect(savedResult.persistedValidationEventID == "validation-event-1")
}

@Test("Configuration probe capabilities include future non text placeholders")
func configurationProbeCapabilitiesIncludeFuturePlaceholders() {
    #expect(AIProviderProbeCapability.allCases == [
        .textReply,
        .structuredJSON,
        .languageSupport,
        .imageUnderstanding,
        .speechSynthesis,
        .embedding,
    ])
}

@Test("Configuration probe language context carries only stable language code")
func configurationProbeLanguageContextCarriesOnlyStableLanguageCode() {
    let context = AIProviderProbeLanguageContext(languageCode: "ja")

    #expect(context.languageCode == "ja")
}

@Test("Capability probe result carries endpoint metadata for mixed profile probes")
func capabilityProbeResultCarriesEndpointMetadataForMixedProfileProbes() {
    let textEndpoint = AIProviderEndpointProbeMetadata(
        endpointID: "endpoint-text",
        endpointPurpose: .textGeneration,
        providerPresetID: "openai",
        modelName: "gpt-5.2",
        configurationFingerprint: "text-fingerprint"
    )
    let ttsEndpoint = AIProviderEndpointProbeMetadata(
        endpointID: "endpoint-tts",
        endpointPurpose: .tts,
        providerPresetID: "openrouter",
        modelName: "openai/gpt-4o-mini-tts",
        configurationFingerprint: "tts-fingerprint"
    )

    let result = AIProviderProfileProbeResult(
        source: .draft,
        overallStatus: .succeeded,
        profileID: "profile-1",
        capabilities: [
            AIProviderProbeCapabilityResult(
                capability: .textReply,
                status: .succeeded,
                errorCategory: nil,
                durationMilliseconds: 100,
                endpointMetadata: textEndpoint
            ),
            AIProviderProbeCapabilityResult(
                capability: .speechSynthesis,
                status: .succeeded,
                errorCategory: nil,
                durationMilliseconds: 240,
                endpointMetadata: ttsEndpoint
            ),
        ],
        persistedValidationEventIDs: []
    )

    #expect(result.capability(.textReply)?.endpointMetadata == textEndpoint)
    #expect(result.capability(.speechSynthesis)?.endpointMetadata == ttsEndpoint)
    #expect(result.capability(.speechSynthesis)?.endpointMetadata?.endpointPurpose == .tts)
    #expect(result.capability(.speechSynthesis)?.endpointMetadata?.providerPresetID == "openrouter")
}

@Test("Embedding validation error category exposes stable raw value")
func embeddingValidationErrorCategoryExposesStableRawValue() {
    #expect(AIProviderValidationErrorCategory.invalidEmbeddingResponse.rawValue == "invalid_embedding_response")
}

@Test("TTS validation error categories expose stable raw values")
func ttsValidationErrorCategoriesExposeStableRawValues() {
    #expect(AIProviderValidationErrorCategory.invalidVoice.rawValue == "invalid_voice")
    #expect(AIProviderValidationErrorCategory.unsupportedLanguage.rawValue == "unsupported_language")
    #expect(AIProviderValidationErrorCategory.unsupportedAudioFormat.rawValue == "unsupported_audio_format")
    #expect(AIProviderValidationErrorCategory.audioDecodeFailed.rawValue == "audio_decode_failed")
    #expect(AIProviderValidationErrorCategory.rateLimited.rawValue == "rate_limited")
    #expect(AIProviderValidationErrorCategory.quotaExceeded.rawValue == "quota_exceeded")
}

@Test("Configuration probe diagnostics use typed event names and attributes")
func configurationProbeDiagnosticsUseTypedEventNamesAndAttributes() {
    #expect(
        DiagnosticEventName.aiProviderConfigurationProbeStarted.rawValue ==
            "ai_provider_configuration.probe_started"
    )
    #expect(
        DiagnosticEventName.aiProviderConfigurationProbeSucceeded.rawValue ==
            "ai_provider_configuration.probe_succeeded"
    )
    #expect(
        DiagnosticEventName.aiProviderConfigurationProbePartial.rawValue ==
            "ai_provider_configuration.probe_partial"
    )
    #expect(
        DiagnosticEventName.aiProviderConfigurationProbeFailed.rawValue ==
            "ai_provider_configuration.probe_failed"
    )
    #expect(
        DiagnosticEventName.aiProviderConfigurationProbeUnsupported.rawValue ==
            "ai_provider_configuration.probe_unsupported"
    )
    #expect(
        DiagnosticEventName.aiProviderConfigurationProbeCancelled.rawValue ==
            "ai_provider_configuration.probe_cancelled"
    )

    #expect(DiagnosticAttribute.adapterKind(.openAIResponses).key == "adapter_kind")
    #expect(DiagnosticAttribute.probeCapability(.structuredJSON).key == "probe_capability")
    #expect(DiagnosticAttribute.probeCapabilityStatus(.unsupported).key == "probe_capability_status")
    #expect(DiagnosticAttribute.probeCapabilityStatus(.cancelled).key == "probe_capability_status")
}

private extension AIProviderProfileProbeResult {
    func capability(_ capability: AIProviderProbeCapability) -> AIProviderProbeCapabilityResult? {
        capabilities.first { $0.capability == capability }
    }
}
