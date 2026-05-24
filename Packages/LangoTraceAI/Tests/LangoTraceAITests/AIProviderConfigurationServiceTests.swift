import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

// swiftlint:disable file_length

@Test("Configuration service loads non secret default profile through Core repository")
func configurationServiceLoadsNonSecretDefaultProfile() async throws {
    let repository = StubAIProviderConfigurationRepository(
        profile: AIProviderConfigurationProfile(
            id: "profile-1",
            displayName: "Default AI Provider",
            isDefault: true,
            status: .configured,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    )
    let service = AIProviderConfigurationService(repository: repository)

    let profile = try await service.loadDefaultProfile()

    #expect(profile?.id == "profile-1")
    #expect(profile?.displayName == "Default AI Provider")
}

@Test("Configuration service delegates endpoint safety validation to Core model")
func configurationServiceDelegatesEndpointSafetyValidationToCoreModel() {
    let service = AIProviderConfigurationService(repository: StubAIProviderConfigurationRepository(profile: nil))
    let endpoint = AIProviderEndpointInput(
        id: "endpoint-1",
        profileID: "profile-1",
        purpose: .textGeneration,
        isEnabled: true,
        providerPresetID: "custom-openai-compatible",
        adapterKind: .openAICompatibleChat,
        baseURL: "http://api.example.com/v1",
        modelName: "custom-model",
        credentialID: "credential-1",
        supportsImageInput: false,
        imageInputEnabled: false
    )

    #expect(throws: AIProviderConfigurationError.invalidBaseURL) {
        try service.validateEndpointInput(endpoint)
    }
}

@Test("Configuration service saves secrets before metadata and cleans up when database fails")
func configurationServiceSavesSecretsBeforeMetadataAndCleansUpWhenDatabaseFails() async throws {
    let repository = StubAIProviderConfigurationRepository(
        profile: nil,
        saveError: AIProviderConfigurationError.databaseWriteFailed
    )
    let store = TrackingAIProviderCredentialStore()
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        clock: { Date(timeIntervalSince1970: 100) },
        idGenerator: IncrementingIDGenerator().next
    )

    await #expect(throws: AIProviderConfigurationSaveFailure.self) {
        try await service.saveDefaultProfile(
            saveInput(),
            operationID: DiagnosticOperationID(rawValue: "operation-1")
        )
    }

    #expect(await store.upsertedAccounts == ["ai-provider-credential:id-2:api_key"])
    #expect(await store.deletedAccounts == ["ai-provider-credential:id-2:api_key"])
}

@Test("Configuration service preserves database failure when cleanup also fails")
func configurationServicePreservesDatabaseFailureWhenCleanupAlsoFails() async throws {
    let repository = StubAIProviderConfigurationRepository(
        profile: nil,
        saveError: AIProviderConfigurationError.databaseWriteFailed
    )
    let store = TrackingAIProviderCredentialStore(deleteError: AIProviderCredentialStoreError.credentialInaccessible)
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        clock: { Date(timeIntervalSince1970: 100) },
        idGenerator: IncrementingIDGenerator().next
    )

    do {
        _ = try await service.saveDefaultProfile(
            saveInput(),
            operationID: DiagnosticOperationID(rawValue: "operation-cleanup")
        )
        Issue.record("Expected save to fail")
    } catch let failure as AIProviderConfigurationSaveFailure {
        #expect(failure.operationID?.rawValue == "operation-cleanup")
        #expect(failure.phase == .databaseWrite)
        #expect(failure.category == .databaseWriteFailed)
        #expect(failure.cleanupFailure == .credentialCleanupFailed)
    }
}

@Test("Configuration service records save phase diagnostics with operation id")
func configurationServiceRecordsSavePhaseDiagnosticsWithOperationID() async throws {
    let repository = StubAIProviderConfigurationRepository(profile: nil)
    let store = TrackingAIProviderCredentialStore()
    let logger = InMemoryDiagnosticLogger()
    let operationID = DiagnosticOperationID(rawValue: "operation-log")
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        diagnosticLogger: logger,
        clock: { Date(timeIntervalSince1970: 100) },
        idGenerator: IncrementingIDGenerator().next
    )

    _ = try await service.saveDefaultProfile(saveInput(), operationID: operationID)

    let events = await logger.events()
    #expect(events.map(\.name) == [
        .aiProviderConfigurationKeychainWriteStarted,
        .aiProviderConfigurationKeychainWriteSucceeded,
        .aiProviderConfigurationDatabaseWriteStarted,
        .aiProviderConfigurationDatabaseWriteSucceeded,
    ])
    #expect(events.allSatisfy { $0.attributes.contains(.operationID(operationID)) })
}

@Test("Configuration service saves profile with generated credential metadata")
func configurationServiceSavesProfileWithGeneratedCredentialMetadata() async throws {
    let repository = StubAIProviderConfigurationRepository(profile: nil)
    let store = TrackingAIProviderCredentialStore()
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        clock: { Date(timeIntervalSince1970: 100) },
        idGenerator: IncrementingIDGenerator().next
    )

    let profile = try await service.saveDefaultProfile(saveInput())

    #expect(profile.id == "id-1")
    #expect(profile.credentials.first?.id == "id-2")
    #expect(profile.endpoints.first?.credentialID == "id-2")
    #expect(profile.credentials.first?.secretPresence == .present)
    #expect(await repository.savedProfile?.id == "id-1")
}

@Test("Configuration service preserves existing credential metadata when resaving profile")
func configurationServicePreservesExistingCredentialMetadataWhenResavingProfile() async throws {
    let repository = try StubAIProviderConfigurationRepository(profile: savedProfile())
    let store = TrackingAIProviderCredentialStore()
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        clock: { Date(timeIntervalSince1970: 140) },
        idGenerator: IncrementingIDGenerator().next
    )

    let profile = try await service.saveDefaultProfile(AIProviderProfileSaveInput(
        profileID: "profile-1",
        displayName: "Default AI Provider",
        endpoints: [
            AIProviderEndpointSaveInput(
                id: "endpoint-1",
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-5.3",
                credentialMode: .existing("credential-1"),
                supportsImageInput: true,
                imageInputEnabled: false
            ),
        ]
    ))

    #expect(profile.credentials.first?.id == "credential-1")
    #expect(profile.endpoints.first?.credentialID == "credential-1")
    #expect(await store.upsertedAccounts.isEmpty)
}

@Test("Configuration service materializes TTS settings with generated endpoint identity")
func configurationServiceMaterializesTTSSettingsWithGeneratedEndpointIdentity() async throws {
    let repository = StubAIProviderConfigurationRepository(profile: nil)
    let store = TrackingAIProviderCredentialStore()
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        clock: { Date(timeIntervalSince1970: 100) },
        idGenerator: IncrementingIDGenerator().next
    )

    let profile = try await service.saveDefaultProfile(ttsSaveInput())

    let ttsEndpoint = try #require(profile.endpoints.first { $0.purpose == .tts })
    #expect(ttsEndpoint.id == "id-4")
    #expect(await repository.savedTTSSettings?.endpointID == "id-4")
    #expect(await repository.savedTTSSettings?.adapterKind == .openAIAudioSpeech)
    let voice = try #require(await repository.savedTTSVoiceProfiles.first)
    #expect(voice.endpointID == "id-4")
    #expect(voice.languageCode == "en")
    #expect(voice.voiceID == "coral")
    #expect(voice.outputFormat == .mp3)
    #expect(voice.playbackReadiness == .notTested)
}

@Test("Configuration service validates saved credentials through Keychain without network")
func configurationServiceValidatesSavedCredentialsThroughKeychainWithoutNetwork() async throws {
    let repository = try StubAIProviderConfigurationRepository(profile: savedProfile())
    let store = TrackingAIProviderCredentialStore()
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        clock: { Date(timeIntervalSince1970: 120) },
        idGenerator: IncrementingIDGenerator().next
    )

    let status = try await service.validateDefaultProfileCredentials()

    #expect(status == .succeeded)
    #expect(await store.resolvedAccounts == ["ai-provider-credential:credential-1:api_key"])
    #expect(await repository.markedCredentialStates == [.present])
    #expect(await repository.recordedValidationEvents.first?.eventType == .credentialValidation)
    #expect(await repository.recordedValidationEvents.first?.status == .succeeded)
    #expect(await repository.recordedValidationEvents.first?.errorCategory == nil)
}

@Test("Configuration service records missing Keychain credentials as non secret validation events")
func configurationServiceRecordsMissingKeychainCredentialsAsNonSecretValidationEvents() async throws {
    let repository = try StubAIProviderConfigurationRepository(profile: savedProfile())
    let store = TrackingAIProviderCredentialStore(resolveError: AIProviderCredentialStoreError.missingCredential)
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        clock: { Date(timeIntervalSince1970: 120) },
        idGenerator: IncrementingIDGenerator().next
    )

    let status = try await service.validateDefaultProfileCredentials()

    #expect(status == .failed)
    #expect(await repository.markedCredentialStates == [.missing])
    #expect(await repository.recordedValidationEvents.first?.status == .failed)
    #expect(await repository.recordedValidationEvents.first?.errorCategory == .missingCredential)
}

@Test("Configuration service tests saved configuration through Keychain and records synthetic outcome")
func configurationServiceTestsSavedConfigurationThroughKeychainAndRecordsSyntheticOutcome() async throws {
    let repository = try StubAIProviderConfigurationRepository(profile: savedProfile())
    let store = TrackingAIProviderCredentialStore()
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"ok\":true}"}]}]}"#),
    ])
    let probeService = AIProviderConfigurationProbeService(httpClient: httpClient)
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        configurationProbeService: probeService,
        clock: { Date(timeIntervalSince1970: 220) },
        idGenerator: IncrementingIDGenerator().next
    )

    let result = try await service.testDefaultConfiguration(
        operationID: DiagnosticOperationID(rawValue: "operation-saved-probe")
    )

    #expect(result.source == .savedProfile)
    #expect(result.overallStatus == .succeeded)
    #expect(result.persistedValidationEventID == "id-1")
    #expect(await store.resolvedAccounts == ["ai-provider-credential:credential-1:api_key"])
    #expect(await repository.recordedValidationOutcomes.first?.eventType == .syntheticTest)
    #expect(await repository.recordedValidationOutcomes.first?.status == .succeeded)
    #expect(await repository.recordedValidationOutcomes.first?.createdAt == Date(timeIntervalSince1970: 220))
}

@Test("Configuration service saved configuration can include image understanding probe")
func configurationServiceSavedConfigurationCanIncludeImageUnderstandingProbe() async throws {
    let repository = try StubAIProviderConfigurationRepository(profile: savedProfile(imageInputEnabled: true))
    let store = TrackingAIProviderCredentialStore()
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"ok\":true}"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"blue square"}]}]}"#),
    ])
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        configurationProbeService: AIProviderConfigurationProbeService(httpClient: httpClient),
        idGenerator: IncrementingIDGenerator().next
    )

    let result = try await service.testDefaultConfiguration(
        operationID: DiagnosticOperationID(rawValue: "operation-saved-image-probe")
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capabilities.first { $0.capability == .imageUnderstanding }?.status == .succeeded)
    #expect(result.persistedValidationEventID == "id-1")
    #expect(await httpClient.requests.count == 3)
    #expect(await repository.recordedValidationOutcomes.first?.status == .succeeded)
    let recordedValidationOutcomes = await repository.recordedValidationOutcomes
    #expect(!String(describing: recordedValidationOutcomes).contains("data:image"))
}

@Test("Configuration service tests saved TTS voice profile without updating text validation outcome")
func configurationServiceTestsSavedTTSVoiceProfileWithoutUpdatingTextValidationOutcome() async throws {
    let savedTTS = try savedProfileWithTTS()
    let repository = StubAIProviderConfigurationRepository(
        profile: savedTTS.profile,
        ttsSettings: savedTTS.settings,
        ttsVoiceProfile: savedTTS.voiceProfile
    )
    let store = TrackingAIProviderCredentialStore()
    let textHTTPClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"ok\":true}"}]}]}"#),
        .json(openAIOutputTextJSON(languageSupportSampleJSON())),
    ])
    let ttsHTTPClient = CapturingProbeHTTPClient(
        responses: [.http(statusCode: 200, body: Data([0x49, 0x44, 0x33]), contentType: "audio/mpeg")]
    )
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        configurationProbeService: AIProviderConfigurationProbeService(httpClient: textHTTPClient),
        ttsConfigurationProbeService: TTSConfigurationProbeService(
            httpClient: ttsHTTPClient,
            audioValidationService: AcceptingTTSAudioValidationService()
        ),
        clock: { Date(timeIntervalSince1970: 250) },
        idGenerator: IncrementingIDGenerator().next
    )

    let result = try await service.testDefaultConfiguration(
        languageContext: AIProviderProbeLanguageContext(languageCode: "en"),
        operationID: DiagnosticOperationID(rawValue: "operation-saved-tts-probe")
    )

    #expect(result.overallStatus == .succeeded)
    let speechResult = try #require(result.capabilities.first { $0.capability == .speechSynthesis })
    #expect(speechResult.status == .succeeded)
    #expect(speechResult.endpointMetadata?.endpointID == "endpoint-tts")
    #expect(await repository.recordedValidationOutcomes.count == 1)
    #expect(await repository.recordedTTSVoiceProfileOutcomes.count == 1)
    #expect(await repository.recordedTTSVoiceProfileOutcomes.first?.endpointID == "endpoint-tts")
    #expect(await repository.recordedTTSOutcomeLanguageCodes == ["en"])
}

@Test("Configuration service reports playable TTS only for matching successful fingerprint and language")
func configurationServiceReportsPlayableTTSOnlyForMatchingSuccessfulFingerprintAndLanguage() async throws {
    let savedTTS = try savedProfileWithTTS(lastTestStatus: .succeeded, markSuccessfulFingerprint: true)
    let repository = StubAIProviderConfigurationRepository(
        profile: savedTTS.profile,
        ttsSettings: savedTTS.settings,
        ttsVoiceProfile: savedTTS.voiceProfile
    )
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: TrackingAIProviderCredentialStore()
    )

    let available = try await service.loadDefaultPlayableTTSConfiguration(languageCode: "en")
    guard case let .available(configuration) = available else {
        Issue.record("Expected available playable TTS configuration")
        return
    }
    #expect(configuration.endpoint.id == "endpoint-tts")
    #expect(configuration.voiceProfile.languageCode == "en")

    let missingLanguage = try await service.loadDefaultPlayableTTSConfiguration(languageCode: "ja")
    #expect(missingLanguage == .notConfigured)
}

@Test("Configuration service reports TTS requires retest when fingerprint changed")
func configurationServiceReportsTTSRequiresRetestWhenFingerprintChanged() async throws {
    let savedTTS = try savedProfileWithTTS(lastTestStatus: .succeeded, markSuccessfulFingerprint: false)
    let repository = StubAIProviderConfigurationRepository(
        profile: savedTTS.profile,
        ttsSettings: savedTTS.settings,
        ttsVoiceProfile: savedTTS.voiceProfile
    )
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: TrackingAIProviderCredentialStore()
    )

    let status = try await service.loadDefaultPlayableTTSConfiguration(languageCode: "en")

    #expect(status == .requiresRetest)
}

@Test("Configuration service reports failed playable TTS with last probe error category")
func configurationServiceReportsFailedPlayableTTSWithLastProbeErrorCategory() async throws {
    let savedTTS = try savedProfileWithTTS(
        lastTestStatus: .failed,
        lastTestErrorCategory: .invalidVoice,
        markSuccessfulFingerprint: false
    )
    let repository = StubAIProviderConfigurationRepository(
        profile: savedTTS.profile,
        ttsSettings: savedTTS.settings,
        ttsVoiceProfile: savedTTS.voiceProfile
    )
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: TrackingAIProviderCredentialStore()
    )

    let status = try await service.loadDefaultPlayableTTSConfiguration(languageCode: "en")

    #expect(status == .failedLastTest(.invalidVoice))
}

@Test("Configuration service requires resolvable credential before playable TTS is available")
func configurationServiceRequiresResolvableCredentialBeforePlayableTTSAvailable() async throws {
    let savedTTS = try savedProfileWithTTS(lastTestStatus: .succeeded, markSuccessfulFingerprint: true)
    let repository = StubAIProviderConfigurationRepository(
        profile: savedTTS.profile,
        ttsSettings: savedTTS.settings,
        ttsVoiceProfile: savedTTS.voiceProfile
    )
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: TrackingAIProviderCredentialStore(resolveError: AIProviderCredentialStoreError.missingCredential)
    )

    let status = try await service.loadDefaultPlayableTTSConfiguration(languageCode: "en")

    #expect(status == .credentialMissing)
}

@Test("Configuration service does not persist language support failure as global profile failure")
func configurationServiceDoesNotPersistLanguageSupportFailureAsGlobalProfileFailure() async throws {
    let repository = try StubAIProviderConfigurationRepository(profile: savedProfile())
    let store = TrackingAIProviderCredentialStore()
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"ok\":true}"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"sample\":\"I wrote a note today.\"}"}]}]}"#),
    ])
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        configurationProbeService: AIProviderConfigurationProbeService(httpClient: httpClient),
        clock: { Date(timeIntervalSince1970: 240) },
        idGenerator: IncrementingIDGenerator().next
    )

    let result = try await service.testDefaultConfiguration(
        languageContext: AIProviderProbeLanguageContext(languageCode: "en"),
        operationID: DiagnosticOperationID(rawValue: "operation-saved-language-probe")
    )

    #expect(result.overallStatus == .failed)
    #expect(result.capabilities.first { $0.capability == .textReply }?.status == .succeeded)
    #expect(result.capabilities.first { $0.capability == .structuredJSON }?.status == .succeeded)
    #expect(result.capabilities.first { $0.capability == .languageSupport }?.status == .failed)
    #expect(result.persistedValidationEventID == "id-1")
    #expect(await repository.recordedValidationOutcomes.first?.eventType == .syntheticTest)
    #expect(await repository.recordedValidationOutcomes.first?.status == .succeeded)
    #expect(await repository.recordedValidationOutcomes.first?.errorCategory == nil)
    let recordedValidationOutcomes = await repository.recordedValidationOutcomes
    #expect(!String(describing: recordedValidationOutcomes).contains("I wrote a note today"))
}

@Test("Configuration service records missing Keychain secret as synthetic probe failure")
func configurationServiceRecordsMissingKeychainSecretAsSyntheticProbeFailure() async throws {
    let repository = try StubAIProviderConfigurationRepository(profile: savedProfile())
    let store = TrackingAIProviderCredentialStore(resolveError: AIProviderCredentialStoreError.missingCredential)
    let logger = InMemoryDiagnosticLogger()
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        configurationProbeService: AIProviderConfigurationProbeService(
            httpClient: CapturingProbeHTTPClient(responses: [])
        ),
        diagnosticLogger: logger,
        clock: { Date(timeIntervalSince1970: 230) },
        idGenerator: IncrementingIDGenerator().next
    )

    let result = try await service.testDefaultConfiguration(
        operationID: DiagnosticOperationID(rawValue: "operation-missing-secret-probe")
    )

    #expect(result.source == .savedProfile)
    #expect(result.overallStatus == .failed)
    #expect(result.persistedValidationEventID == "id-1")
    #expect(result.capabilities.first?.errorCategory == .missingCredential)
    #expect(await repository.recordedValidationOutcomes.first?.eventType == .syntheticTest)
    #expect(await repository.recordedValidationOutcomes.first?.errorCategory == .missingCredential)
    #expect(await repository.recordedValidationOutcomes.first?.status == .failed)
    let diagnosticEvents = await logger.events()
    #expect(diagnosticEvents.map(\.name).contains(.aiProviderConfigurationProbeFailed))
    #expect(diagnosticEvents.flatMap(\.attributes).contains(.errorCategory("missing_credential")))
    #expect(!String(describing: diagnosticEvents).contains("ai-provider-credential:credential-1:api_key"))
}

@Test("Configuration service does not persist cancelled saved synthetic probe")
func configurationServiceDoesNotPersistCancelledSavedSyntheticProbe() async throws {
    let repository = try StubAIProviderConfigurationRepository(profile: savedProfile())
    let store = TrackingAIProviderCredentialStore()
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        configurationProbeService: AIProviderConfigurationProbeService(
            httpClient: CapturingProbeHTTPClient(responses: [.failure(AIProviderProbeHTTPClientError.cancelled)])
        ),
        idGenerator: IncrementingIDGenerator().next
    )

    let result = try await service.testDefaultConfiguration(
        operationID: DiagnosticOperationID(rawValue: "operation-cancelled-probe")
    )

    #expect(result.overallStatus == .cancelled)
    #expect(result.persistedValidationEventID == nil)
    #expect(await repository.recordedValidationOutcomes.isEmpty)
}

@Test("Configuration service draft configuration probe does not write Keychain or validation event")
func configurationServiceDraftConfigurationProbeDoesNotWriteKeychainOrValidationEvent() async throws {
    let repository = StubAIProviderConfigurationRepository(profile: nil)
    let store = TrackingAIProviderCredentialStore()
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
    ])
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        configurationProbeService: AIProviderConfigurationProbeService(httpClient: httpClient)
    )

    let result = try await service.testDraftConfiguration(
        AIProviderConfigurationProbeDraftInput(
            endpoint: AIProviderEndpointInput(
                id: "draft-endpoint",
                profileID: "draft-profile",
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: "custom-openai-compatible",
                adapterKind: .openAICompatibleChat,
                baseURL: "https://api.example.com/v1",
                modelName: "model",
                credentialID: "draft-credential",
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            plaintextSecret: "draft-secret",
            operationID: DiagnosticOperationID(rawValue: "operation-draft-probe")
        )
    )

    #expect(result.source == .draft)
    #expect(result.overallStatus == .succeeded)
    #expect(result.persistedValidationEventID == nil)
    #expect(await store.upsertedAccounts.isEmpty)
    #expect(await store.resolvedAccounts.isEmpty)
    #expect(await repository.recordedValidationEvents.isEmpty)
    #expect(await repository.recordedValidationOutcomes.isEmpty)
}

@Test("Configuration service merges draft TTS probe into single result without persistence")
func configurationServiceMergesDraftTTSProbeIntoSingleResultWithoutPersistence() async throws {
    let repository = StubAIProviderConfigurationRepository(profile: nil)
    let store = TrackingAIProviderCredentialStore()
    let textHTTPClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
    ])
    let ttsHTTPClient = CapturingProbeHTTPClient(
        responses: [.http(statusCode: 200, body: Data([0x49, 0x44, 0x33]), contentType: "audio/mpeg")]
    )
    let service = AIProviderConfigurationService(
        repository: repository,
        credentialStore: store,
        configurationProbeService: AIProviderConfigurationProbeService(httpClient: textHTTPClient),
        ttsConfigurationProbeService: TTSConfigurationProbeService(
            httpClient: ttsHTTPClient,
            audioValidationService: AcceptingTTSAudioValidationService()
        )
    )
    let voiceProfile = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "draft-tts-endpoint",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3,
        providerParameters: ["response_format": .string("mp3")]
    )

    let result = try await service.testDraftConfiguration(
        AIProviderConfigurationProbeDraftInput(
            endpoint: AIProviderEndpointInput(
                id: "draft-text-endpoint",
                profileID: "draft-profile",
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAICompatibleChat,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-5.2",
                credentialID: "draft-text-credential",
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            plaintextSecret: "sk-test",
            ttsEndpoint: AIProviderEndpointInput(
                id: "draft-tts-endpoint",
                profileID: "draft-profile",
                purpose: .tts,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAICompatibleChat,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-4o-mini-tts",
                credentialID: "draft-text-credential",
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            ttsSettings: TTSProviderSettings(endpointID: "draft-tts-endpoint", adapterKind: .openAIAudioSpeech),
            ttsVoiceProfile: voiceProfile,
            ttsPlaintextSecret: "sk-test",
            operationID: DiagnosticOperationID(rawValue: "operation-draft-tts-probe")
        )
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capabilities.first { $0.capability == .speechSynthesis }?.status == .succeeded)
    #expect(
        result.capabilities.first { $0.capability == .speechSynthesis }?.endpointMetadata?.endpointID ==
            "draft-tts-endpoint"
    )
    #expect(result.persistedValidationEventID == nil)
    #expect(await repository.recordedValidationOutcomes.isEmpty)
    #expect(await ttsHTTPClient.requests.count == 1)
}

private struct StubAIProviderConfigurationRepository: AIProviderConfigurationRepository {
    var profile: AIProviderConfigurationProfile?
    var saveError: (any Error)?
    var initialTTSSettings: TTSProviderSettings?
    var initialTTSVoiceProfile: TTSVoiceProfile?
    private let storage = RepositoryStorage()

    init(
        profile: AIProviderConfigurationProfile?,
        saveError: (any Error)? = nil,
        ttsSettings: TTSProviderSettings? = nil,
        ttsVoiceProfile: TTSVoiceProfile? = nil
    ) {
        self.profile = profile
        self.saveError = saveError
        initialTTSSettings = ttsSettings
        initialTTSVoiceProfile = ttsVoiceProfile
    }

    func loadDefaultProfile() async throws -> AIProviderConfigurationProfile? {
        profile
    }

    func saveProfile(_ profile: AIProviderConfigurationProfile) async throws {
        if let saveError {
            throw saveError
        }
        await storage.setSavedProfile(profile)
    }

    func saveProfile(
        _ profile: AIProviderConfigurationProfile,
        ttsSettings: TTSProviderSettings?,
        ttsVoiceProfiles: [TTSVoiceProfile]
    ) async throws {
        if let saveError {
            throw saveError
        }
        await storage.setSavedProfile(profile)
        await storage.setTTSSettings(ttsSettings, voiceProfiles: ttsVoiceProfiles)
    }

    var savedProfile: AIProviderConfigurationProfile? {
        get async {
            await storage.savedProfile
        }
    }

    var savedTTSSettings: TTSProviderSettings? {
        get async {
            await storage.savedTTSSettings
        }
    }

    var savedTTSVoiceProfiles: [TTSVoiceProfile] {
        get async {
            await storage.savedTTSVoiceProfiles
        }
    }

    func markCredentialState(
        _ state: AIProviderSecretPresence,
        credentialID _: AIProviderCredentialID
    ) async throws {
        await storage.appendCredentialState(state)
    }

    var markedCredentialStates: [AIProviderSecretPresence] {
        get async {
            await storage.markedCredentialStates
        }
    }

    func recordValidationEvent(_ event: AIProviderValidationEvent) async throws {
        await storage.appendValidationEvent(event)
    }

    var recordedValidationEvents: [AIProviderValidationEvent] {
        get async {
            await storage.recordedValidationEvents
        }
    }

    func recordValidationOutcome(_ event: AIProviderValidationEvent) async throws {
        await storage.appendValidationOutcome(event)
    }

    var recordedValidationOutcomes: [AIProviderValidationEvent] {
        get async {
            await storage.recordedValidationOutcomes
        }
    }

    func loadTTSSettings(endpointID: AIProviderEndpointID) async throws -> TTSProviderSettings? {
        if let saved = await storage.savedTTSSettings, saved.endpointID == endpointID {
            return saved
        }
        guard initialTTSSettings?.endpointID == endpointID else {
            return nil
        }
        return initialTTSSettings
    }

    func loadTTSVoiceProfile(
        endpointID: AIProviderEndpointID,
        languageCode: String
    ) async throws -> TTSVoiceProfile? {
        if let saved = await storage.savedTTSVoiceProfiles.first(where: {
            $0.endpointID == endpointID && $0.languageCode == languageCode
        }) {
            return saved
        }
        guard initialTTSVoiceProfile?.endpointID == endpointID,
              initialTTSVoiceProfile?.languageCode == languageCode
        else {
            return nil
        }
        return initialTTSVoiceProfile
    }

    func recordTTSVoiceProfileProbeOutcome(
        _ event: AIProviderValidationEvent,
        languageCode: String
    ) async throws {
        await storage.appendTTSVoiceProfileOutcome(event, languageCode: languageCode)
    }

    var recordedTTSVoiceProfileOutcomes: [AIProviderValidationEvent] {
        get async {
            await storage.recordedTTSVoiceProfileOutcomes
        }
    }

    var recordedTTSOutcomeLanguageCodes: [String] {
        get async {
            await storage.recordedTTSOutcomeLanguageCodes
        }
    }
}

private actor RepositoryStorage {
    var savedProfile: AIProviderConfigurationProfile?
    var savedTTSSettings: TTSProviderSettings?
    var savedTTSVoiceProfiles: [TTSVoiceProfile] = []
    var markedCredentialStates: [AIProviderSecretPresence] = []
    var recordedValidationEvents: [AIProviderValidationEvent] = []
    var recordedValidationOutcomes: [AIProviderValidationEvent] = []
    var recordedTTSVoiceProfileOutcomes: [AIProviderValidationEvent] = []
    var recordedTTSOutcomeLanguageCodes: [String] = []

    func setSavedProfile(_ profile: AIProviderConfigurationProfile) {
        savedProfile = profile
    }

    func setTTSSettings(_ settings: TTSProviderSettings?, voiceProfiles: [TTSVoiceProfile]) {
        savedTTSSettings = settings
        savedTTSVoiceProfiles = voiceProfiles
    }

    func appendCredentialState(_ state: AIProviderSecretPresence) {
        markedCredentialStates.append(state)
    }

    func appendValidationEvent(_ event: AIProviderValidationEvent) {
        recordedValidationEvents.append(event)
    }

    func appendValidationOutcome(_ event: AIProviderValidationEvent) {
        recordedValidationOutcomes.append(event)
    }

    func appendTTSVoiceProfileOutcome(_ event: AIProviderValidationEvent, languageCode: String) {
        recordedTTSVoiceProfileOutcomes.append(event)
        recordedTTSOutcomeLanguageCodes.append(languageCode)
    }
}

private actor CapturingProbeHTTPClient: AIProviderProbeHTTPClient {
    private(set) var requests: [URLRequest] = []
    private var responses: [Response]

    init(responses: [Response]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> AIProviderProbeHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw AIProviderProbeHTTPClientError.transportUnavailable
        }
        let response = responses.removeFirst()
        if let error = response.error {
            throw error
        }
        return AIProviderProbeHTTPResponse(
            statusCode: response.statusCode,
            body: response.body,
            contentType: response.contentType
        )
    }

    struct Response {
        var statusCode: Int
        var body: Data
        var contentType: String?
        var error: (any Error)?

        static func json(_ value: String) -> Response {
            Response(statusCode: 200, body: Data(value.utf8))
        }

        static func http(statusCode: Int, body: Data, contentType: String? = nil) -> Response {
            Response(statusCode: statusCode, body: body, contentType: contentType)
        }

        static func failure(_ error: any Error) -> Response {
            Response(statusCode: 0, body: Data(), error: error)
        }
    }
}

private struct AcceptingTTSAudioValidationService: TTSAudioValidationService {
    func validateAudio(
        _ data: Data,
        declaredFormat: TTSAudioFormat,
        contentType _: String?,
        previewPolicy _: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        TTSAudioValidationResult(
            status: .succeeded,
            metadata: TTSAudioMetadata(
                format: declaredFormat,
                byteCount: data.count,
                durationSeconds: 1,
                sampleRate: nil
            ),
            previewResource: TTSAudioPreviewResource(storage: .memory, byteCount: data.count)
        )
    }
}

private actor TrackingAIProviderCredentialStore: AIProviderCredentialStore {
    private(set) var upsertedAccounts: [String] = []
    private(set) var deletedAccounts: [String] = []
    private(set) var resolvedAccounts: [String] = []
    private let resolveError: (any Error)?
    private let deleteError: (any Error)?

    init(resolveError: (any Error)? = nil, deleteError: (any Error)? = nil) {
        self.resolveError = resolveError
        self.deleteError = deleteError
    }

    func upsertSecret(
        _: AIProviderSecretInput,
        for reference: AIProviderCredentialKeychainReference
    ) async throws {
        upsertedAccounts.append(reference.account)
    }

    func hasSecret(for _: AIProviderCredentialKeychainReference) async -> AIProviderSecretPresence {
        .present
    }

    func resolveSecret(for reference: AIProviderCredentialKeychainReference) async throws -> AIProviderResolvedSecret {
        resolvedAccounts.append(reference.account)
        if let resolveError {
            throw resolveError
        }
        return AIProviderResolvedSecret(value: "secret")
    }

    func deleteSecret(for reference: AIProviderCredentialKeychainReference) async throws {
        deletedAccounts.append(reference.account)
        if let deleteError {
            throw deleteError
        }
    }
}

private final class IncrementingIDGenerator: @unchecked Sendable {
    private var nextValue = 0

    func next() -> String {
        nextValue += 1
        return "id-\(nextValue)"
    }
}

private func saveInput() -> AIProviderProfileSaveInput {
    AIProviderProfileSaveInput(
        displayName: "Default AI Provider",
        endpoints: [
            AIProviderEndpointSaveInput(
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-5.2",
                credentialMode: .newSecret(
                    AIProviderCredentialSecretSaveInput(
                        kind: .apiKey,
                        label: "OpenAI API Key",
                        plaintextSecret: "sk-test"
                    )
                ),
                supportsImageInput: true,
                imageInputEnabled: false
            ),
        ]
    )
}

private func ttsSaveInput() -> AIProviderProfileSaveInput {
    AIProviderProfileSaveInput(
        displayName: "Default AI Provider",
        endpoints: [
            AIProviderEndpointSaveInput(
                purpose: .textGeneration,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-5.2",
                credentialMode: .newSecret(
                    AIProviderCredentialSecretSaveInput(
                        kind: .apiKey,
                        label: "OpenAI API Key",
                        plaintextSecret: "sk-test"
                    )
                ),
                supportsImageInput: true,
                imageInputEnabled: false
            ),
            AIProviderEndpointSaveInput(
                purpose: .tts,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-4o-mini-tts",
                credentialMode: .sharedWithPurpose(.textGeneration),
                supportsImageInput: false,
                imageInputEnabled: false
            ),
        ],
        ttsVoiceProfile: TTSVoiceProfileSaveInput(
            endpointPurpose: .tts,
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            voiceID: "coral",
            voiceDisplayName: "Coral",
            outputFormat: .mp3,
            sampleRate: nil,
            speed: 1.0,
            volume: nil,
            pitch: nil,
            stylePrompt: nil,
            instructions: "Calm and clear.",
            streamingMode: false,
            providerParameters: ["response_format": .string("mp3")]
        )
    )
}

private func savedProfile(imageInputEnabled: Bool = false) throws -> AIProviderConfigurationProfile {
    let now = Date(timeIntervalSince1970: 100)
    let endpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-1",
            profileID: "profile-1",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-5.2",
            credentialID: "credential-1",
            supportsImageInput: true,
            imageInputEnabled: imageInputEnabled
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
        endpoints: [endpoint],
        credentials: [credential]
    )
}

private func savedProfileWithTTS(
    lastTestStatus: TTSConfigurationStatus = .notTested,
    lastTestErrorCategory: AIProviderValidationErrorCategory? = nil,
    markSuccessfulFingerprint: Bool = false
) throws -> (
    profile: AIProviderConfigurationProfile,
    settings: TTSProviderSettings,
    voiceProfile: TTSVoiceProfile
) {
    let now = Date(timeIntervalSince1970: 100)
    let textEndpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-1",
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
    let ttsEndpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-tts",
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
    let profile = AIProviderConfigurationProfile(
        id: "profile-1",
        displayName: "Default AI Provider",
        isDefault: true,
        status: .configured,
        createdAt: now,
        updatedAt: now,
        endpoints: [textEndpoint, ttsEndpoint],
        credentials: [credential]
    )
    let settings = TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech)
    var voiceProfile = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3,
        providerParameters: ["response_format": .string("mp3")],
        lastTestStatus: lastTestStatus,
        lastTestErrorCategory: lastTestErrorCategory
    )
    if markSuccessfulFingerprint {
        voiceProfile = voiceProfile.withProbeOutcome(TTSConfigurationStatus.succeeded, testedAt: now)
    }
    return (profile, settings, voiceProfile)
}

private func languageSupportSampleJSON() -> String {
    let sample = [
        "Today I opened the window before breakfast and wrote a short note about the rain,",
        "the quiet street, and the warm cup of tea beside my notebook.",
        "Later, I planned to review the moment in English so the simple details would become useful practice",
        "for ordinary life.",
    ].joined(separator: " ")
    return #"{"sample":"\#(sample)"}"#
}

private func openAIOutputTextJSON(_ text: String) -> String {
    let escapedText = text.replacingOccurrences(of: #"""#, with: #"\""#)
    return #"{"output":[{"type":"message","content":[{"type":"output_text","text":"\#(escapedText)"}]}]}"#
}
