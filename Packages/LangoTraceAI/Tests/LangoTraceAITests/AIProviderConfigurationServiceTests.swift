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

    await #expect(throws: AIProviderConfigurationError.databaseWriteFailed) {
        try await service.saveDefaultProfile(saveInput())
    }

    #expect(await store.upsertedAccounts == ["ai-provider-credential:id-2:api_key"])
    #expect(await store.deletedAccounts == ["ai-provider-credential:id-2:api_key"])
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
}

private actor RepositoryStorage {
    var savedProfile: AIProviderConfigurationProfile?
    var markedCredentialStates: [AIProviderSecretPresence] = []
    var recordedValidationEvents: [AIProviderValidationEvent] = []

    func setSavedProfile(_ profile: AIProviderConfigurationProfile) {
        savedProfile = profile
    }

    func appendCredentialState(_ state: AIProviderSecretPresence) {
        markedCredentialStates.append(state)
    }

    func appendValidationEvent(_ event: AIProviderValidationEvent) {
        recordedValidationEvents.append(event)
    }
}

private actor TrackingAIProviderCredentialStore: AIProviderCredentialStore {
    private(set) var upsertedAccounts: [String] = []
    private(set) var deletedAccounts: [String] = []
    private(set) var resolvedAccounts: [String] = []
    private let resolveError: (any Error)?

    init(resolveError: (any Error)? = nil) {
        self.resolveError = resolveError
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
