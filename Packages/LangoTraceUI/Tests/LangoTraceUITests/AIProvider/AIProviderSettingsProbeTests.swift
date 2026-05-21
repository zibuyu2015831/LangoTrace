import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("AI provider settings probe flow")
struct AIProviderSettingsProbeTests {
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

    @Test("Settings source has test button without network or bearer calls")
    func settingsSourceHasTestButtonWithoutNetworkOrBearerCalls() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)

        #expect(source.contains("aiProviderSettings.testRequest.button"))
        #expect(source.contains("validateConfiguration()"))
        #expect(source.contains("actions.testProviderConfiguration"))
        #expect(source.contains("makeTextProbeDraftSnapshot"))
        #expect(source.contains("AIProviderProbeResultPanelContent"))
        #expect(source.contains(".sheet(isPresented: $isProbeResultPresented)"))
        #expect(source.contains("aiProviderProbePresentationStyle(compactWidth: isCompactWidth)"))
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
        #expect(source.contains("aiProviderSettings.testState.cancelled"))
        #expect(source.contains("aiProviderSettings.probeCapabilityStatus.cancelled"))
        #expect(!source.contains(".sheet("))
        #expect(!source.contains("presentationDetents"))
    }

    @Test("Probe result sheet has a large platform width rule without applying compact detents everywhere")
    func probeResultSheetHasLargePlatformWidthRuleWithoutApplyingCompactDetentsEverywhere() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)

        #expect(source.contains("aiProviderProbePresentationStyle(compactWidth: isCompactWidth)"))
        #expect(source.contains("private let aiProviderProbeRegularWidth"))
        #expect(source.contains(".frame(maxWidth: aiProviderProbeRegularWidth, alignment: .leading)"))
        #expect(source.contains("presentationDetents([.medium, .large])"))
        #expect(source.contains("#if os(iOS)"))
        #expect(source.contains("if compactWidth"))
        #expect(!source.contains("aiProviderProbePresentationDetents"))
    }

    @Test("Unsupported optional capabilities do not mask authentication failure")
    func unsupportedOptionalCapabilitiesDoNotMaskAuthenticationFailure() {
        let result = AIProviderConfigurationProbeResult(
            source: .savedProfile,
            overallStatus: .failed,
            providerPresetID: "custom-openai-compatible",
            modelName: "mimo-v2.5-pro",
            capabilities: [
                .init(
                    capability: .textReply,
                    status: .failed,
                    errorCategory: .authenticationFailed,
                    durationMilliseconds: 17
                ),
                .init(capability: .structuredJSON, status: .notRun, errorCategory: nil, durationMilliseconds: nil),
                .init(
                    capability: .imageUnderstanding,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
                .init(capability: .speechSynthesis, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .embedding, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
            ],
            persistedValidationEventID: nil
        )

        #expect(!result.isUnsupportedTextProbeResult)
        #expect(result.primaryProbeFailureCategory == AIProviderValidationErrorCategory.authenticationFailed)
        #expect(result.probePanelTitleKey == "aiProviderSettings.testState.failed")
    }

    @Test("Text probe unsupported result remains unsupported provider")
    func textProbeUnsupportedResultRemainsUnsupportedProvider() {
        let result = AIProviderConfigurationProbeResult(
            source: .draft,
            overallStatus: .failed,
            providerPresetID: "anthropic",
            modelName: "claude-sonnet-4-5",
            capabilities: [
                .init(
                    capability: .textReply,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
                .init(
                    capability: .structuredJSON,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
                .init(
                    capability: .imageUnderstanding,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
            ],
            persistedValidationEventID: nil
        )

        #expect(result.isUnsupportedTextProbeResult)
        #expect(result.probePanelTitleKey == "aiProviderSettings.testState.unsupportedProvider")
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
        #expect(!source.contains(
            "makeTextProbeDraftSnapshot(operationID: DiagnosticOperationID) throws -> AIProviderProfileSaveInput"
        ))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        packageRootURL()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }

    private func packageRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "LangoTraceUI" {
            let parent = url.deletingLastPathComponent()
            precondition(parent.path != url.path, "Could not locate LangoTraceUI package root")
            url = parent
        }
        return url
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
