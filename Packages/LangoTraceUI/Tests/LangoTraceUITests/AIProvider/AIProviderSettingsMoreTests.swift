import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

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

        #expect(source.contains("revealTextCredential()"))
        #expect(source.contains("actions.resolveCredentialSecret(metadata)"))
        #expect(source.contains("clearPlaintextSecretsForCredentialDisclosure()"))
        #expect(source.contains("savedCredentialMetadataByID"))
        #expect(source.contains("draft.applyLoadedProfile(profile)"))
        #expect(!source.contains("resolvedSecretsByCredentialID(for: profile)"))
        #expect(!source.contains("credential.keychainAccount"))
        #expect(!source.contains("credential.keychainService"))
    }

    @Test("Reveal credential failure emits credential_resolve_failed diagnostic event")
    func revealCredentialFailureEmitsCredentialResolveFailedDiagnosticEvent() throws {
        let source = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
        // revealCredential failure path must emit the credential_resolve_failed diagnostic event
        #expect(source.contains(".aiProviderSettingsCredentialFailed"))
        // the event must carry a failure_phase attribute identifying the reveal stage
        #expect(source.contains("credential_reveal"))
    }

    @Test("Draft probe source switches to draft after non-credential edit on loaded profile")
    func draftProbeSourceSwitchesToDraftAfterNonCredentialEditOnLoadedProfile() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        try draft.applyLoadedProfile(loadedProfile())

        #expect(draft.textProbeSource == .savedProfile)
        #expect(draft.text.endpoint.independentCredential.apiKeyDraft == "")
        #expect(draft.text.endpoint.credentialID == "credential-1")

        draft.text.endpoint.model = "gpt-5.3"
        draft.markInputChanged(from: "gpt-5.2", to: "gpt-5.3")

        #expect(draft.textProbeSource == .draft)
        #expect(draft.configurationProbeReadiness == .readyForRequest)
    }

    @Test("Draft probe snapshot has empty secret when apiKeyDraft cleared after profile load")
    func draftProbeSnapshotHasEmptySecretWhenAPIKeyDraftClearedAfterProfileLoad() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        try draft.applyLoadedProfile(loadedProfile())
        draft.text.endpoint.model = "gpt-5.3"
        draft.markInputChanged(from: "gpt-5.2", to: "gpt-5.3")

        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "op-scenario-c-empty")
        )

        // Without credential resolution, plaintextSecret is empty — probe would fail with missingCredential
        #expect(snapshot.plaintextSecret == "")
        #expect(snapshot.source == .draft)
        #expect(snapshot.endpoint?.modelName == "gpt-5.3")
    }

    @Test("Applying resolved secrets before draft snapshot passes credential to probe")
    func applyingResolvedSecretsBeforeDraftSnapshotPassesCredentialToProbe() throws {
        var draft = AIProviderDraftConfiguration(provider: .openAI)
        try draft.applyLoadedProfile(loadedProfile())
        draft.text.endpoint.model = "gpt-5.3"
        draft.markInputChanged(from: "gpt-5.2", to: "gpt-5.3")

        // Simulate what validateConfiguration() does: temporarily restore the saved secret
        draft.applyResolvedSecrets(["credential-1": "sk-resolved-from-keychain"])
        let snapshot = try draft.makeConfigurationProbeDraftSnapshot(
            operationID: DiagnosticOperationID(rawValue: "op-scenario-c-resolved")
        )
        draft.clearPlaintextSecrets()

        #expect(snapshot.plaintextSecret == "sk-resolved-from-keychain")
        #expect(snapshot.endpoint?.modelName == "gpt-5.3")
        #expect(draft.text.endpoint.independentCredential.apiKeyDraft == "")
    }

    @Test("Settings view resolves saved credential before building draft test snapshot")
    func settingsViewResolvesSavedCredentialBeforeBuildingDraftTestSnapshot() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"),
            encoding: .utf8
        )

        // View must resolve the saved credential when apiKeyDraft is empty during draft probe
        #expect(source.contains("resolveCredentialSecret(metadata)"))
        #expect(source.contains("resolvedForSnapshot"))
        #expect(source.contains("clearPlaintextSecrets()"))
    }

    @Test("Status hint is shown when all enabled model configurations are incomplete")
    func statusHintIsShownWhenAllEnabledModelConfigurationsAreIncomplete() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"),
            encoding: .utf8
        )

        // statusTitleKey must show the missingRequiredFields hint during idle state
        #expect(source.contains("saveReadiness == .missingRequiredFields"))
        #expect(source.contains("aiProviderSettings.saveState.missingRequiredFields"))
    }

    @Test("Settings source wires reveal only to independent API key fields")
    func settingsSourceWiresRevealOnlyToIndependentAPIKeyFields() throws {
        let viewSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"),
            encoding: .utf8
        )
        let componentSource = try String(
            contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("onRevealSavedCredential: revealTextCredential"))
        #expect(componentSource.contains("await revealIndependentCredential(configuration.purpose.endpointPurpose)"))
        #expect(componentSource.contains("if configuration.endpoint.credentialReference == .independent"))
        #expect(componentSource.contains("credentialReferencePicker"))
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
