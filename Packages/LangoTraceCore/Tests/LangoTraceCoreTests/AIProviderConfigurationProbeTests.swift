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
