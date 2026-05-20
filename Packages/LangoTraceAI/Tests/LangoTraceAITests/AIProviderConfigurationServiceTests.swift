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

private struct StubAIProviderConfigurationRepository: AIProviderConfigurationRepository {
    var profile: AIProviderConfigurationProfile?

    func loadDefaultProfile() async throws -> AIProviderConfigurationProfile? {
        profile
    }

    func saveProfile(_: AIProviderConfigurationProfile) async throws {}

    func markCredentialState(
        _: AIProviderSecretPresence,
        credentialID _: AIProviderCredentialID
    ) async throws {}

    func recordValidationEvent(_: AIProviderValidationEvent) async throws {}
}
