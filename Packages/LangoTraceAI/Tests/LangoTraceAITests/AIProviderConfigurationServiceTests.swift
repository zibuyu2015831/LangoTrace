import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

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

@Test("Configuration service tests saved text endpoint through Keychain and records synthetic outcome")
func configurationServiceTestsSavedTextEndpointThroughKeychainAndRecordsSyntheticOutcome() async throws {
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

    let result = try await service.testDefaultTextEndpoint(
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

    let result = try await service.testDefaultTextEndpoint(
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

    let result = try await service.testDefaultTextEndpoint(
        operationID: DiagnosticOperationID(rawValue: "operation-cancelled-probe")
    )

    #expect(result.overallStatus == .cancelled)
    #expect(result.persistedValidationEventID == nil)
    #expect(await repository.recordedValidationOutcomes.isEmpty)
}

@Test("Configuration service draft text endpoint probe does not write Keychain or validation event")
func configurationServiceDraftTextEndpointProbeDoesNotWriteKeychainOrValidationEvent() async throws {
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

    let result = try await service.testDraftTextEndpoint(
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

private struct StubAIProviderConfigurationRepository: AIProviderConfigurationRepository {
    var profile: AIProviderConfigurationProfile?
    var saveError: (any Error)?
    private let storage = RepositoryStorage()

    func loadDefaultProfile() async throws -> AIProviderConfigurationProfile? {
        profile
    }

    func saveProfile(_ profile: AIProviderConfigurationProfile) async throws {
        if let saveError {
            throw saveError
        }
        await storage.setSavedProfile(profile)
    }

    var savedProfile: AIProviderConfigurationProfile? {
        get async {
            await storage.savedProfile
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
}

private actor RepositoryStorage {
    var savedProfile: AIProviderConfigurationProfile?
    var markedCredentialStates: [AIProviderSecretPresence] = []
    var recordedValidationEvents: [AIProviderValidationEvent] = []
    var recordedValidationOutcomes: [AIProviderValidationEvent] = []

    func setSavedProfile(_ profile: AIProviderConfigurationProfile) {
        savedProfile = profile
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
}

private actor CapturingProbeHTTPClient: AIProviderProbeHTTPClient {
    private var responses: [Response]

    init(responses: [Response]) {
        self.responses = responses
    }

    func send(_: URLRequest) async throws -> AIProviderProbeHTTPResponse {
        guard !responses.isEmpty else {
            throw AIProviderProbeHTTPClientError.transportUnavailable
        }
        let response = responses.removeFirst()
        if let error = response.error {
            throw error
        }
        return AIProviderProbeHTTPResponse(statusCode: response.statusCode, body: response.body)
    }

    struct Response {
        var statusCode: Int
        var body: Data
        var error: (any Error)?

        static func json(_ value: String) -> Response {
            Response(statusCode: 200, body: Data(value.utf8))
        }

        static func failure(_ error: any Error) -> Response {
            Response(statusCode: 0, body: Data(), error: error)
        }
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

private func savedProfile() throws -> AIProviderConfigurationProfile {
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
        endpoints: [endpoint],
        credentials: [credential]
    )
}
