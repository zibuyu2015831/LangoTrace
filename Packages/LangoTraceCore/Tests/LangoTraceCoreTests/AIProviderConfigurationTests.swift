import Foundation
import LangoTraceCore
import Testing

@Test("Endpoint input rejects secrets in URLs and public HTTP")
func endpointInputRejectsSecretsInURLsAndPublicHTTP() throws {
    let querySecret = endpointInput(baseURL: "https://api.example.com/v1?api_key=secret")
    #expect(throws: AIProviderConfigurationError.invalidBaseURL) {
        try querySecret.normalized()
    }

    let userInfoSecret = endpointInput(baseURL: "https://token@example.com/v1")
    #expect(throws: AIProviderConfigurationError.invalidBaseURL) {
        try userInfoSecret.normalized()
    }

    let publicHTTP = endpointInput(baseURL: "http://api.example.com/v1")
    #expect(throws: AIProviderConfigurationError.invalidBaseURL) {
        try publicHTTP.normalized()
    }
}

@Test("Endpoint input allows HTTPS and loopback HTTP")
func endpointInputAllowsHTTPSAndLoopbackHTTP() throws {
    let https = try endpointInput(baseURL: " https://api.openai.com/v1 ").normalized()
    #expect(https.baseURL == "https://api.openai.com/v1")

    let localhost = try endpointInput(baseURL: "http://localhost:11434/v1").normalized()
    #expect(localhost.baseURL == "http://localhost:11434/v1")

    let loopback = try endpointInput(baseURL: "http://127.0.0.1:11434/v1").normalized()
    #expect(loopback.baseURL == "http://127.0.0.1:11434/v1")
}

@Test("Non text generation endpoints clear image input support and enablement")
func nonTextGenerationEndpointsClearImageInputSupportAndEnablement() throws {
    let endpoint = try endpointInput(
        baseURL: "https://api.openai.com/v1",
        purpose: .embedding,
        supportsImageInput: true,
        imageInputEnabled: true
    ).normalized()

    #expect(!endpoint.supportsImageInput)
    #expect(!endpoint.imageInputEnabled)
}

@Test("Endpoint configuration fingerprint is stable and excludes sensitive values")
func endpointConfigurationFingerprintIsStableAndExcludesSensitiveValues() throws {
    let endpoint = try endpointInput(
        baseURL: " https://api.openai.com/v1 ",
        purpose: .embedding,
        supportsImageInput: true,
        imageInputEnabled: true
    ).normalized()
    let sameOutputFields = AIProviderEndpointInput(
        id: "endpoint-other",
        profileID: "profile-other",
        purpose: endpoint.purpose,
        isEnabled: false,
        providerPresetID: endpoint.providerPresetID,
        adapterKind: endpoint.adapterKind,
        baseURL: endpoint.baseURL,
        modelName: endpoint.modelName,
        credentialID: endpoint.credentialID,
        supportsImageInput: endpoint.supportsImageInput,
        imageInputEnabled: endpoint.imageInputEnabled,
        requestTimeoutSeconds: endpoint.requestTimeoutSeconds
    )

    #expect(endpoint.configurationFingerprint == sameOutputFields.configurationFingerprint)
    #expect(!endpoint.configurationFingerprint.contains("endpoint-1"))
    #expect(!endpoint.configurationFingerprint.contains("profile-1"))
    #expect(!endpoint.configurationFingerprint.contains("ai-provider-credential"))
    #expect(!endpoint.configurationFingerprint.contains("sk-"))

    var changedModel = endpoint
    changedModel.modelName = "text-embedding-3-large"
    #expect(changedModel.configurationFingerprint != endpoint.configurationFingerprint)

    var changedBaseURL = endpoint
    changedBaseURL.baseURL = "https://openrouter.ai/api/v1"
    #expect(changedBaseURL.configurationFingerprint != endpoint.configurationFingerprint)

    var changedPurpose = endpoint
    changedPurpose.purpose = .textGeneration
    #expect(changedPurpose.configurationFingerprint != endpoint.configurationFingerprint)

    var changedTimeout = endpoint
    changedTimeout.requestTimeoutSeconds = 12
    #expect(changedTimeout.configurationFingerprint != endpoint.configurationFingerprint)
}

@Test("Credential metadata derives stable non secret Keychain reference fields")
func credentialMetadataDerivesStableKeychainReferenceFields() {
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let updatedAt = Date(timeIntervalSince1970: 1_700_000_100)
    let metadata = AIProviderCredentialMetadata(
        id: "credential-1",
        profileID: "profile-1",
        providerPresetID: "openai",
        kind: .apiKey,
        label: "OpenAI API Key",
        createdAt: createdAt,
        updatedAt: updatedAt
    )

    #expect(metadata.keychainService == "com.langotrace.ai-provider")
    #expect(metadata.keychainAccount == "ai-provider-credential:credential-1:api_key")
    #expect(metadata.keychainSynchronizable == false)
    #expect(metadata.cleanupState == .active)
    #expect(metadata.secretPresence == .unknown)
    #expect(metadata.createdAt == createdAt)
    #expect(metadata.updatedAt == updatedAt)
}

private func endpointInput(
    baseURL: String,
    purpose: AIProviderEndpointPurpose = .textGeneration,
    supportsImageInput: Bool = true,
    imageInputEnabled: Bool = false
) -> AIProviderEndpointInput {
    AIProviderEndpointInput(
        id: "endpoint-1",
        profileID: "profile-1",
        purpose: purpose,
        isEnabled: true,
        providerPresetID: "openai",
        adapterKind: .openAIResponses,
        baseURL: baseURL,
        modelName: "gpt-5.2",
        credentialID: "credential-1",
        supportsImageInput: supportsImageInput,
        imageInputEnabled: imageInputEnabled
    )
}
