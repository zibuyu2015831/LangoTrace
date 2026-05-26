import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Test("Embedding probe builds OpenAI compatible embeddings request and returns metadata")
func embeddingProbeBuildsOpenAICompatibleEmbeddingsRequestAndReturnsMetadata() async throws {
    let httpClient = CapturingEmbeddingProbeHTTPClient(responses: [
        .json(#"{"data":[{"embedding":[0.1,0.2,0.3]}]}"#),
    ])
    let service = EmbeddingConfigurationProbeService(
        httpClient: httpClient,
        clock: { Date(timeIntervalSince1970: 1000) }
    )

    let result = await service.probeDraftEmbeddingConfiguration(
        EmbeddingDraftProbeInput(
            endpoint: embeddingEndpoint(
                providerPresetID: "openai",
                baseURL: "https://api.openai.com/v1",
                modelName: "text-embedding-3-small",
                requestTimeoutSeconds: 11
            ),
            plaintextSecret: "sk-test"
        )
    )

    #expect(result.status == .succeeded)
    #expect(result.capability == .embedding)
    #expect(result.endpointMetadata?.endpointID == "embedding-endpoint")
    #expect(result.endpointMetadata?.endpointPurpose == .embedding)
    #expect(result.endpointMetadata?.providerPresetID == "openai")
    #expect(result.endpointMetadata?.modelName == "text-embedding-3-small")
    #expect(result.endpointMetadata?.configurationFingerprint != nil)

    let requests = await httpClient.requests
    #expect(requests.count == 1)
    #expect(requests[0].url?.absoluteString == "https://api.openai.com/v1/embeddings")
    #expect(requests[0].httpMethod == "POST")
    #expect(requests[0].timeoutInterval == 11)
    #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    let body = try #require(String(data: requests[0].httpBody ?? Data(), encoding: .utf8))
    #expect(body.contains(#""model":"text-embedding-3-small""#))
    #expect(body.contains(#""input":"LangoTrace embedding configuration test.""#))
    #expect(body.contains(#""encoding_format":"float""#))
    #expect(!body.contains("life record"))
    #expect(!body.contains("Prompt Preset"))
    #expect(!body.contains("sk-test"))
}

@Test("Embedding probe supports OpenRouter and custom OpenAI compatible base URLs")
func embeddingProbeSupportsOpenRouterAndCustomBaseURLs() async throws {
    let httpClient = CapturingEmbeddingProbeHTTPClient(responses: [
        .json(#"{"data":[{"embedding":[1]}]}"#),
        .json(#"{"data":[{"embedding":[2]}]}"#),
    ])
    let service = EmbeddingConfigurationProbeService(httpClient: httpClient)

    let openRouter = await service.probeDraftEmbeddingConfiguration(
        EmbeddingDraftProbeInput(
            endpoint: embeddingEndpoint(
                providerPresetID: "openrouter",
                baseURL: "https://openrouter.ai/api/v1",
                modelName: "openai/text-embedding-3-small"
            ),
            plaintextSecret: "sk-router"
        )
    )
    let custom = await service.probeDraftEmbeddingConfiguration(
        EmbeddingDraftProbeInput(
            endpoint: embeddingEndpoint(
                providerPresetID: "custom-openai-compatible",
                baseURL: "https://custom.example/openai/v1/",
                modelName: "embedding-model"
            ),
            plaintextSecret: "sk-custom"
        )
    )

    #expect(openRouter.status == .succeeded)
    #expect(custom.status == .succeeded)
    #expect(await httpClient.requests.map { $0.url?.absoluteString } == [
        "https://openrouter.ai/api/v1/embeddings",
        "https://custom.example/openai/v1/embeddings",
    ])
}

@Test("Embedding probe rejects invalid embedding response shapes")
func embeddingProbeRejectsInvalidResponseShapes() async throws {
    for payload in [
        #"{"data":[{"embedding":[]}]}"#,
        #"{"data":[{"embedding":["0.1"]}]}"#,
        #"{"data":[{}]}"#,
        #"{"not_data":[]}"#,
        #"not json"#,
    ] {
        let httpClient = CapturingEmbeddingProbeHTTPClient(responses: [.json(payload)])
        let service = EmbeddingConfigurationProbeService(httpClient: httpClient)

        let result = await service.probeDraftEmbeddingConfiguration(
            EmbeddingDraftProbeInput(endpoint: embeddingEndpoint(), plaintextSecret: "sk-test")
        )

        #expect(result.status == .failed)
        #expect(result.errorCategory == .invalidEmbeddingResponse)
    }
}

@Test("Embedding probe maps provider and transport failures")
func embeddingProbeMapsProviderAndTransportFailures() async throws {
    let cases: [(CapturingEmbeddingProbeHTTPClient.Response, AIProviderProbeCapabilityStatus, AIProviderValidationErrorCategory?)] = [
        (.http(statusCode: 401, body: "{}"), .failed, .authenticationFailed),
        (.http(statusCode: 403, body: "{}"), .failed, .authenticationFailed),
        (.http(statusCode: 404, body: "{}"), .failed, .unsupportedModel),
        (.http(statusCode: 429, body: "{}"), .failed, .rateLimited),
        (.http(statusCode: 500, body: "{}"), .failed, .providerRejected),
        (.failure(AIProviderProbeHTTPClientError.transportUnavailable), .failed, .networkUnavailable),
        (.failure(AIProviderProbeHTTPClientError.timedOut), .failed, .timeout),
        (.failure(AIProviderProbeHTTPClientError.cancelled), .cancelled, nil),
    ]

    for (response, status, category) in cases {
        let httpClient = CapturingEmbeddingProbeHTTPClient(responses: [response])
        let service = EmbeddingConfigurationProbeService(httpClient: httpClient)

        let result = await service.probeDraftEmbeddingConfiguration(
            EmbeddingDraftProbeInput(endpoint: embeddingEndpoint(), plaintextSecret: "sk-test")
        )

        #expect(result.status == status)
        #expect(result.errorCategory == category)
    }
}

@Test("Embedding probe maps missing credential and unsupported provider without HTTP")
func embeddingProbeMapsMissingCredentialAndUnsupportedProviderWithoutHTTP() async throws {
    let missingCredentialClient = CapturingEmbeddingProbeHTTPClient(responses: [])
    let missingCredentialService = EmbeddingConfigurationProbeService(httpClient: missingCredentialClient)
    let missingCredential = await missingCredentialService.probeDraftEmbeddingConfiguration(
        EmbeddingDraftProbeInput(endpoint: embeddingEndpoint(), plaintextSecret: nil)
    )

    #expect(missingCredential.status == .failed)
    #expect(missingCredential.errorCategory == .missingCredential)
    #expect(await missingCredentialClient.requests.isEmpty)

    let unsupportedClient = CapturingEmbeddingProbeHTTPClient(responses: [])
    let unsupportedService = EmbeddingConfigurationProbeService(httpClient: unsupportedClient)
    let unsupported = await unsupportedService.probeDraftEmbeddingConfiguration(
        EmbeddingDraftProbeInput(
            endpoint: embeddingEndpoint(providerPresetID: "deepseek", modelName: "deepseek-embedding"),
            plaintextSecret: "sk-test"
        )
    )

    #expect(unsupported.status == .unsupported)
    #expect(unsupported.errorCategory == .unsupportedEndpointPurpose)
    #expect(await unsupportedClient.requests.isEmpty)
}

private actor CapturingEmbeddingProbeHTTPClient: AIProviderProbeHTTPClient {
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
        return AIProviderProbeHTTPResponse(statusCode: response.statusCode, body: response.body)
    }

    struct Response {
        var statusCode: Int
        var body: Data
        var error: (any Error)?

        static func json(_ value: String) -> Response {
            .http(statusCode: 200, body: value)
        }

        static func http(statusCode: Int, body: String) -> Response {
            Response(statusCode: statusCode, body: Data(body.utf8))
        }

        static func failure(_ error: any Error) -> Response {
            Response(statusCode: 0, body: Data(), error: error)
        }
    }
}

private func embeddingEndpoint(
    providerPresetID: String = "openai",
    baseURL: String = "https://api.openai.com/v1",
    modelName: String = "text-embedding-3-small",
    requestTimeoutSeconds: Double? = nil
) -> AIProviderEndpointInput {
    AIProviderEndpointInput(
        id: "embedding-endpoint",
        profileID: "profile-1",
        purpose: .embedding,
        isEnabled: true,
        providerPresetID: providerPresetID,
        adapterKind: .openAICompatibleChat,
        baseURL: baseURL,
        modelName: modelName,
        credentialID: "credential-1",
        supportsImageInput: false,
        imageInputEnabled: false,
        requestTimeoutSeconds: requestTimeoutSeconds
    )
}
