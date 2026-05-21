import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Test("OpenAI-compatible Chat probe builds POST requests and maps text and JSON success")
func openAICompatibleChatProbeBuildsRequestsAndMapsSuccess() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
    ])
    let logger = InMemoryDiagnosticLogger()
    let service = AIProviderConfigurationProbeService(
        httpClient: httpClient,
        diagnosticLogger: logger,
        clock: { Date(timeIntervalSince1970: 1000) }
    )

    let result = try await service.probeDraftConfiguration(
        draftInput(
            adapterKind: .openAICompatibleChat,
            baseURL: "https://api.example.com/v1",
            plaintextSecret: "sk-test-secret"
        )
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capability(.textReply)?.status == .succeeded)
    #expect(result.capability(.structuredJSON)?.status == .succeeded)
    #expect(result.persistedValidationEventID == nil)

    let requests = await httpClient.requests
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { $0.httpMethod == "POST" })
    #expect(requests.allSatisfy { $0.url?.absoluteString == "https://api.example.com/v1/chat/completions" })
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret" })

    let bodies = requests.compactMap(\.httpBody).compactMap { String(data: $0, encoding: .utf8) }
    #expect(bodies.allSatisfy { !$0.contains("life record") && !$0.contains("Prompt Preset") })
    #expect(bodies[0].contains("OK"))
    #expect(bodies[1].contains(#"{\"ok\":true}"#))

    let events = await logger.events()
    #expect(events.map(\.name).contains(.aiProviderConfigurationProbeStarted))
    #expect(events.map(\.name).contains(.aiProviderConfigurationProbeSucceeded))
    #expect(events.flatMap(\.attributes).contains(.providerPresetID("openai")))
    #expect(events.flatMap(\.attributes).contains(.adapterKind(.openAICompatibleChat)))
    #expect(!String(describing: events).contains("sk-test-secret"))
}

@Test("Structured JSON probe rejects markdown wrapped JSON without failing text reply")
func structuredJSONProbeRejectsMarkdownWrappedJSON() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"```json\n{\"ok\":true}\n```"}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(adapterKind: .openAICompatibleChat)
    )

    #expect(result.overallStatus == .failed)
    #expect(result.capability(.textReply)?.status == .succeeded)
    #expect(result.capability(.structuredJSON)?.status == .failed)
    #expect(result.capability(.structuredJSON)?.errorCategory == .invalidResponse)
}

@Test("OpenAI Responses probe parses raw output items instead of SDK convenience output_text")
func openAIResponsesProbeParsesRawOutputItems() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"ok\":true}"}]}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(adapterKind: .openAIResponses, baseURL: "https://api.openai.com/v1")
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capability(.textReply)?.status == .succeeded)
    #expect(result.capability(.structuredJSON)?.status == .succeeded)
    #expect(await httpClient.requests.map { $0.url?.absoluteString } == [
        "https://api.openai.com/v1/responses",
        "https://api.openai.com/v1/responses",
    ])
}

@Test("Provider failures map to non secret validation categories")
func providerFailuresMapToValidationCategories() async throws {
    let authClient = CapturingProbeHTTPClient(responses: [.http(statusCode: 401, body: #"{"error":"bad key"}"#)])
    let authService = AIProviderConfigurationProbeService(httpClient: authClient)

    let authResult = try await authService.probeDraftConfiguration(draftInput())
    #expect(authResult.overallStatus == .failed)
    #expect(authResult.capability(.textReply)?.errorCategory == .authenticationFailed)

    let modelClient = CapturingProbeHTTPClient(responses: [.http(statusCode: 404, body: #"{"error":"missing model"}"#)])
    let modelService = AIProviderConfigurationProbeService(httpClient: modelClient)

    let modelResult = try await modelService.probeDraftConfiguration(draftInput())
    #expect(modelResult.capability(.textReply)?.errorCategory == .unsupportedModel)

    let networkClient = CapturingProbeHTTPClient(
        responses: [.failure(AIProviderProbeHTTPClientError.transportUnavailable)]
    )
    let networkService = AIProviderConfigurationProbeService(httpClient: networkClient)

    let networkResult = try await networkService.probeDraftConfiguration(draftInput())
    #expect(networkResult.capability(.textReply)?.errorCategory == .networkUnavailable)

    let timeoutClient = CapturingProbeHTTPClient(responses: [.failure(AIProviderProbeHTTPClientError.timedOut)])
    let timeoutService = AIProviderConfigurationProbeService(httpClient: timeoutClient)

    let timeoutResult = try await timeoutService.probeDraftConfiguration(draftInput())
    #expect(timeoutResult.capability(.textReply)?.errorCategory == .timeout)
}

@Test("Cancelled probes record cancellation without treating it as a validation failure")
func cancelledProbesRecordCancellation() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [.failure(AIProviderProbeHTTPClientError.cancelled)])
    let logger = InMemoryDiagnosticLogger()
    let service = AIProviderConfigurationProbeService(httpClient: httpClient, diagnosticLogger: logger)

    let result = try await service.probeDraftConfiguration(draftInput())

    #expect(result.overallStatus == .cancelled)
    #expect(result.capability(.textReply)?.status == .cancelled)
    #expect(result.capability(.textReply)?.errorCategory == nil)
    #expect(await logger.events().map(\.name).contains(.aiProviderConfigurationProbeCancelled))
}

@Test("Unsupported adapters and placeholder capabilities do not send HTTP")
func unsupportedAdaptersAndPlaceholderCapabilitiesDoNotSendHTTP() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(adapterKind: .anthropicMessages)
    )

    #expect(result.overallStatus == .failed)
    #expect(result.capability(.textReply)?.status == .unsupported)
    #expect(result.capability(.structuredJSON)?.status == .unsupported)
    #expect(result.capability(.imageUnderstanding)?.status == .unsupported)
    #expect(result.capability(.speechSynthesis)?.status == .notEnabled)
    #expect(result.capability(.embedding)?.status == .notEnabled)
    #expect(await httpClient.requests.isEmpty)
}

@Test("Local providers can probe without Authorization header")
func localProvidersCanProbeWithoutAuthorizationHeader() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(
            providerPresetID: "ollama-local",
            adapterKind: .openAICompatibleChat,
            baseURL: "http://localhost:11434/v1",
            plaintextSecret: nil
        )
    )

    #expect(result.overallStatus == .succeeded)
    #expect(await httpClient.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
}

private extension AIProviderConfigurationProbeResult {
    func capability(_ capability: AIProviderProbeCapability) -> AIProviderProbeCapabilityResult? {
        capabilities.first { $0.capability == capability }
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

private func draftInput(
    providerPresetID: String = "openai",
    adapterKind: AIProviderAdapterKind = .openAICompatibleChat,
    baseURL: String = "https://api.example.com/v1",
    modelName: String = "gpt-5.2",
    plaintextSecret: String? = "sk-test"
) -> AIProviderConfigurationProbeDraftInput {
    AIProviderConfigurationProbeDraftInput(
        endpoint: AIProviderEndpointInput(
            id: "endpoint-1",
            profileID: "draft-profile",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: providerPresetID,
            adapterKind: adapterKind,
            baseURL: baseURL,
            modelName: modelName,
            credentialID: plaintextSecret == nil ? nil : "credential-1",
            supportsImageInput: true,
            imageInputEnabled: false
        ),
        plaintextSecret: plaintextSecret,
        operationID: DiagnosticOperationID(rawValue: "operation-probe")
    )
}
