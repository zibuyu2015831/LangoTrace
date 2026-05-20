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

@Test("Credential metadata derives stable non secret Keychain reference fields")
func credentialMetadataDerivesStableKeychainReferenceFields() {
    let metadata = AIProviderCredentialMetadata(
        id: "credential-1",
        profileID: "profile-1",
        providerPresetID: "openai",
        kind: .apiKey,
        label: "OpenAI API Key"
    )

    #expect(metadata.keychainService == "com.langotrace.ai-provider")
    #expect(metadata.keychainAccount == "ai-provider-credential:credential-1:api_key")
    #expect(metadata.keychainSynchronizable == false)
    #expect(metadata.cleanupState == .active)
    #expect(metadata.secretPresence == .unknown)
}

private func endpointInput(baseURL: String) -> AIProviderEndpointInput {
    AIProviderEndpointInput(
        id: "endpoint-1",
        profileID: "profile-1",
        purpose: .textGeneration,
        isEnabled: true,
        providerPresetID: "openai",
        adapterKind: .openAIResponses,
        baseURL: baseURL,
        modelName: "gpt-5.2",
        credentialID: "credential-1",
        supportsImageInput: true,
        imageInputEnabled: false
    )
}
