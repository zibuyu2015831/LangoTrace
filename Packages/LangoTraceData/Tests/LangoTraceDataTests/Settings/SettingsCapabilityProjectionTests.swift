import Foundation
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// E12 Slice A: the settings projection service derives the AI provider row value from the
/// non-sensitive SQLite snapshot (profile status + per-credential `secretPresence`) with zero
/// Keychain access. The service depends only on `AIProviderConfigurationRepository`, whose
/// GRDB implementation imports no Keychain type — so this exercises the full read path.
@Suite("Settings capability projection")
struct SettingsCapabilityProjectionTests {
    private let now = Date(timeIntervalSince1970: 100)

    private func configuredProfile(presence: AIProviderSecretPresence) throws -> AIProviderConfigurationProfile {
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
            label: "Key",
            secretPresence: presence,
            createdAt: now,
            updatedAt: now
        )
        return AIProviderConfigurationProfile(
            id: "profile-1",
            displayName: "Default",
            isDefault: true,
            status: .configured,
            createdAt: now,
            updatedAt: now,
            endpoints: [endpoint],
            credentials: [credential]
        )
    }

    @Test("an empty database projects to not configured")
    func emptyDatabase() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIProviderConfigurationRepository(database: database)
        let service = SettingsCapabilityProjectionService(configurationRepository: repository)
        #expect(await service.aiProviderStatus() == .notConfigured)
    }

    @Test("a saved profile with a present credential projects to configured")
    func configuredProfileProjects() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIProviderConfigurationRepository(database: database)
        try await repository.saveProfile(configuredProfile(presence: .present))
        let service = SettingsCapabilityProjectionService(configurationRepository: repository)
        #expect(await service.aiProviderStatus() == .configured)
    }

    @Test("clearing the credential snapshot projects to missing key")
    func missingCredentialProjects() async throws {
        let database = try AppDatabase.inMemory()
        let repository = GRDBAIProviderConfigurationRepository(database: database)
        try await repository.saveProfile(configuredProfile(presence: .present))
        try await repository.markCredentialState(.missing, credentialID: "credential-1")
        let service = SettingsCapabilityProjectionService(configurationRepository: repository)
        #expect(await service.aiProviderStatus() == .missingKey)
    }

    @Test("sync row value comes from the service's isEnabled flag")
    func syncStatus() throws {
        let database = try AppDatabase.inMemory()
        let service = SettingsCapabilityProjectionService(
            configurationRepository: GRDBAIProviderConfigurationRepository(database: database)
        )
        #expect(service.syncStatus(isEnabled: false) == .notEnabled)
    }
}
