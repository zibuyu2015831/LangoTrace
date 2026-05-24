import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("AI provider settings language support probe boundaries")
struct AIProviderSettingsLanguageSupportProbeTests {
    @Test("Draft model omits language support capability when no language context exists")
    func draftModelOmitsLanguageSupportCapabilityWhenNoLanguageContextExists() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"

        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-ui-no-language-probe")
        )

        #expect(snapshot.languageContext == nil)
        #expect(snapshot.requestedCapabilities == [.textReply, .structuredJSON])
    }

    @Test("AI provider settings source keeps language support out of SwiftUI network and language recognition boundaries")
    func aiProviderSettingsSourceKeepsLanguageSupportOutOfSwiftUINetworkAndLanguageRecognitionBoundaries() throws {
        let viewSource = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
        let draftSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderDraftConfiguration.swift"),
            encoding: .utf8
        )
        let detailSource = try String(
            contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("languageContext"))
        #expect(draftSource.contains("languageContext"))
        #expect(!detailSource.contains("#if os(iOS)\n            AIProviderSettingsView("))
        #expect(detailSource.contains("AIProviderProbeLanguageContext(languageCode: languageSpace.targetLanguageCode)"))
        #expect(!viewSource.contains("NLLanguageRecognizer"))
        #expect(!draftSource.contains("NLLanguageRecognizer"))
        #expect(!viewSource.contains("NaturalLanguage"))
        #expect(!draftSource.contains("NaturalLanguage"))
        #expect(!viewSource.contains("URLSession"))
        #expect(!draftSource.contains("URLSession"))
        #expect(!viewSource.contains("Authorization"))
        #expect(!draftSource.contains("Authorization"))
        #expect(!viewSource.contains("Bearer "))
        #expect(!draftSource.contains("Bearer "))
    }
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

@Suite("AI provider settings probe flow")
// swiftlint:disable:next type_body_length
struct AIProviderSettingsProbeTests {
    @Test("Draft model separates save readiness from configuration probe readiness")
    func draftModelSeparatesSaveReadinessFromConfigurationProbeReadiness() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        draft.speech.isEnabled = true
        draft.speech.endpoint.model = ""
        draft.embedding.isEnabled = true
        draft.embedding.endpoint.model = ""

        #expect(draft.saveReadiness == .missingRequiredFields)
        #expect(draft.textProbeReadiness == .readyForRequest)
        #expect(draft.textProbeSource == .draft)

        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-ui-probe"),
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
        #expect(snapshot.source == .draft)
        #expect(snapshot.endpoint.purpose == .textGeneration)
        #expect(snapshot.endpoint.providerPresetID == "openai")
        #expect(snapshot.plaintextSecret == "sk-local-draft")
        #expect(snapshot.languageContext == AIProviderProbeLanguageContext(languageCode: "en"))
        #expect(snapshot.requestedCapabilities == [.textReply, .structuredJSON, .languageSupport, .speechSynthesis])
    }

    @Test("Draft configuration probe snapshot includes image capability only when enabled and supported")
    func draftConfigurationProbeSnapshotIncludesImageCapabilityOnlyWhenEnabledAndSupported() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        draft.text.imageUnderstandingEnabled = true

        #expect(draft.configurationProbeRequestedCapabilities == [.textReply, .structuredJSON, .imageUnderstanding])

        let openAISnapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-ui-image-probe")
        )
        #expect(openAISnapshot.endpoint.imageInputEnabled)
        #expect(openAISnapshot.requestedCapabilities == [.textReply, .structuredJSON, .imageUnderstanding])

        draft.text.updateProvider(.deepSeek)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        let textOnlySnapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-ui-text-only-probe")
        )
        #expect(draft.configurationProbeRequestedCapabilities == [.textReply, .structuredJSON])
        #expect(!textOnlySnapshot.endpoint.imageInputEnabled)
        #expect(textOnlySnapshot.requestedCapabilities == [.textReply, .structuredJSON])
    }

    @Test("OpenRouter model dependent image input can be enabled for configuration probe")
    func openRouterModelDependentImageInputCanBeEnabledForConfigurationProbe() throws {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        draft.text.endpoint.model = "openai/gpt-5.4-image-2"
        draft.text.imageUnderstandingEnabled = true

        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-openrouter-image-probe")
        )

        #expect(draft.configurationProbeRequestedCapabilities == [.textReply, .structuredJSON, .imageUnderstanding])
        #expect(snapshot.endpoint.providerPresetID == "openrouter")
        #expect(snapshot.endpoint.adapterKind == .openAICompatibleChat)
        #expect(snapshot.endpoint.supportsImageInput)
        #expect(snapshot.endpoint.imageInputEnabled)
        #expect(snapshot.requestedCapabilities == [.textReply, .structuredJSON, .imageUnderstanding])
    }

    @Test("OpenRouter image input is not requested until user enables it")
    func openRouterImageInputIsNotRequestedUntilUserEnablesIt() throws {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        draft.text.endpoint.model = "openai/gpt-5.4-image-2"

        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "operation-openrouter-text-probe")
        )

        #expect(snapshot.endpoint.supportsImageInput)
        #expect(!snapshot.endpoint.imageInputEnabled)
        #expect(snapshot.requestedCapabilities == [.textReply, .structuredJSON])
    }

    @Test("Enabled incomplete speech probe stays visible as not configured")
    func enabledIncompleteSpeechProbeStaysVisibleAsNotConfigured() {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        draft.text.endpoint.independentCredential.apiKeyDraft = "sk-local-draft"
        draft.speech.isEnabled = true
        draft.speech.endpoint.model = ""

        #expect(draft.configurationProbeRequestedCapabilities(
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        ) == [.textReply, .structuredJSON, .languageSupport, .speechSynthesis])

        let textOnlyResult = AIProviderConfigurationProbeResult(
            source: .draft,
            overallStatus: .succeeded,
            providerPresetID: "openrouter",
            modelName: "openai/gpt-5.4",
            capabilities: [
                .init(capability: .textReply, status: .succeeded, errorCategory: nil, durationMilliseconds: 10),
                .init(capability: .structuredJSON, status: .succeeded, errorCategory: nil, durationMilliseconds: 12),
                .init(capability: .languageSupport, status: .succeeded, errorCategory: nil, durationMilliseconds: 14),
                .init(capability: .imageUnderstanding, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .speechSynthesis, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .embedding, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
            ],
            persistedValidationEventID: nil
        )

        let displayedResult = draft.applyingLocalProbeCapabilityOverrides(
            to: textOnlyResult,
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )

        #expect(displayedResult.capabilities.first { $0.capability == .speechSynthesis }?.status == .notConfigured)
    }

    @Test("Saved speech probe result is not downgraded by local draft completeness")
    func savedSpeechProbeResultIsNotDowngradedByLocalDraftCompleteness() {
        var draft = AIProviderDraftConfiguration(provider: .openRouter)
        draft.speech.isEnabled = true
        draft.speech.endpoint.model = ""

        let savedResult = AIProviderConfigurationProbeResult(
            source: .savedProfile,
            overallStatus: .succeeded,
            providerPresetID: "openrouter",
            modelName: "openai/gpt-4o",
            capabilities: [
                .init(capability: .textReply, status: .succeeded, errorCategory: nil, durationMilliseconds: 10),
                .init(capability: .structuredJSON, status: .succeeded, errorCategory: nil, durationMilliseconds: 12),
                .init(capability: .languageSupport, status: .succeeded, errorCategory: nil, durationMilliseconds: 14),
                .init(capability: .speechSynthesis, status: .succeeded, errorCategory: nil, durationMilliseconds: 120),
            ],
            persistedValidationEventID: "event-saved"
        )

        let displayedResult = draft.applyingLocalProbeCapabilityOverrides(
            to: savedResult,
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )

        #expect(displayedResult.capabilities.first { $0.capability == .speechSynthesis }?.status == .succeeded)
    }

    @Test("Loaded profile image state is downgraded by live resolver instead of persisted support")
    func loadedProfileImageStateIsDowngradedByLiveResolverInsteadOfPersistedSupport() throws {
        var textOnlyDraft = AIProviderDraftConfiguration(provider: .openAI)
        try textOnlyDraft.applyLoadedProfile(loadedProfile(
            providerPresetID: "deepseek",
            adapterKind: .openAICompatibleChat,
            modelName: "deepseek-v4-flash",
            supportsImageInput: true,
            imageInputEnabled: true
        ))
        #expect(textOnlyDraft.text.endpoint.provider == .deepSeek)
        #expect(!textOnlyDraft.text.imageUnderstandingEnabled)

        var openRouterDraft = AIProviderDraftConfiguration(provider: .openAI)
        try openRouterDraft.applyLoadedProfile(loadedProfile(
            providerPresetID: "openrouter",
            adapterKind: .openAICompatibleChat,
            modelName: "openai/gpt-5.4-image-2",
            supportsImageInput: false,
            imageInputEnabled: true
        ))
        #expect(openRouterDraft.text.endpoint.provider == .openRouter)
        #expect(openRouterDraft.text.imageUnderstandingEnabled)
    }

    @Test("Settings source uses resolver instead of provider image boolean for image toggle")
    func settingsSourceUsesResolverInsteadOfProviderImageBooleanForImageToggle() throws {
        let viewSource = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
        let draftSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderDraftConfiguration.swift"),
            encoding: .utf8
        )
        let componentSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("imageInputDecision"))
        #expect(draftSource.contains("imageInputDecision"))
        #expect(componentSource.contains("AIProviderCapabilityDecision"))
        #expect(!viewSource.contains("provider.capabilities.imageUnderstanding"))
        #expect(!draftSource.contains("provider.capabilities.imageUnderstanding"))
        #expect(!componentSource.contains("supportsImageUnderstanding"))
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
        #expect(source.contains("makeConfigurationProbeDraftSnapshot"))
        #expect(source.contains("draft.configurationProbeRequestedCapabilities"))
        #expect(!source.contains("makeTextProbeDraftSnapshot"))
        #expect(source.contains("AIProviderProbeResultPanelSheet"))
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

    @Test("Probe result content is presentation independent and uses caller supplied capability rows")
    func probeResultContentIsPresentationIndependentAndUsesCallerSuppliedCapabilityRows() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )

        #expect(source.contains("struct AIProviderProbeResultPanelContent"))
        #expect(source.contains("AIProviderProbeResultChrome"))
        #expect(source.contains("AIProviderProbeCapabilityList"))
        #expect(source.contains("ProgressView()"))
        #expect(source.contains("return \"aiProviderSettings.testState.testing\""))
        #expect(source.contains("return \"aiProviderSettings.probeResult.title\""))
        #expect(!source.contains("return result?.probePanelTitleKey"))
        #expect(!source.contains("var probePanelTitleKey"))
        #expect(source.contains("if showsRetryButton"))
        #expect(source.contains("private var showsRetryButton: Bool"))
        #expect(source.contains("result?.overallStatus != .succeeded"))
        #expect(!source.contains("if !isTesting"))
        #expect(source.contains("displayedCapabilities"))
        #expect(source.contains("activeCapabilities"))
        #expect(!source.contains("capability == .textReply || capability == .structuredJSON"))
        #expect(source.contains("aiProviderSettings.probeCapability.textReply"))
        #expect(source.contains("aiProviderSettings.probeCapability.structuredJSON"))
        #expect(source.contains("aiProviderSettings.probeCapability.languageSupport"))
        #expect(source.contains("aiProviderSettings.probeCapability.imageUnderstanding"))
        #expect(source.contains("aiProviderSettings.probeCapability.speechSynthesis"))
        #expect(source.contains("aiProviderSettings.probeCapability.embedding"))
        #expect(source.contains("aiProviderSettings.probeCapabilityStatus.cancelled"))
        #expect(source.contains("Divider()"))
        #expect(source.contains(".background(LangoTraceDesign.ColorToken.surfaceRaised)"))
        #expect(source.contains(".clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.panel"))
        #expect(!source.contains(".sheet("))
        #expect(!source.contains("presentationDetents"))
    }

    @Test("Probe result sheet uses fitted sizing on regular width and compact detents only on compact width")
    func probeResultSheetUsesFittedSizingOnRegularWidthAndCompactDetentsOnlyOnCompactWidth() throws {
        let viewSource = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
        let componentSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("AIProviderProbeResultPanelSheet("))
        #expect(viewSource.contains("usesRegularWidth: usesRegularProbeWidth"))
        #expect(viewSource.contains("aiProviderProbePresentationStyle(compactWidth: isCompactWidth)"))
        #expect(viewSource.contains("presentationSizing(.fitted)"))
        #expect(viewSource.contains("presentationDetents([.medium, .large])"))
        #expect(viewSource.contains(".presentationDragIndicator(.hidden)"))
        #expect(viewSource.contains("#if os(iOS)"))
        #expect(viewSource.contains("if compactWidth"))
        #expect(viewSource.contains("else"))
        #expect(componentSource.contains("struct AIProviderProbeResultPanelSheet"))
        #expect(componentSource.contains("let aiProviderProbeRegularWidth: CGFloat = 520"))
        #expect(componentSource.contains("let usesRegularWidth: Bool"))
        #expect(componentSource.contains(".frame(width: usesRegularWidth ? aiProviderProbeRegularWidth : nil"))
        #expect(componentSource.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(!viewSource.contains(".frame(maxWidth: aiProviderProbeRegularWidth, alignment: .leading)"))
        #expect(!viewSource.contains("private let aiProviderProbeRegularWidth"))
        #expect(!viewSource.contains("aiProviderProbePresentationDetents"))
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
        #expect(source.contains("makeConfigurationProbeDraftSnapshot"))
        #expect(!source.contains(
            "makeTextProbeDraftSnapshot(operationID: DiagnosticOperationID) throws -> AIProviderProfileSaveInput"
        ))
    }

    private func loadedProfile() throws -> AIProviderConfigurationProfile {
        try loadedProfile(
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            modelName: "gpt-5.2",
            supportsImageInput: true,
            imageInputEnabled: false
        )
    }

    private func loadedProfile(
        providerPresetID: String,
        adapterKind: LangoTraceCore.AIProviderAdapterKind,
        modelName: String,
        supportsImageInput: Bool,
        imageInputEnabled: Bool
    ) throws -> AIProviderConfigurationProfile {
        let now = Date(timeIntervalSince1970: 100)
        let text = try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: "text-endpoint",
                profileID: "profile-1",
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: providerPresetID,
                adapterKind: adapterKind,
                baseURL: "https://api.openai.com/v1",
                modelName: modelName,
                credentialID: "credential-1",
                supportsImageInput: supportsImageInput,
                imageInputEnabled: imageInputEnabled
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
