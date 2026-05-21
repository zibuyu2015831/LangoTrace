import Foundation
import ImageIO
import LangoTraceAI
import LangoTraceCore
import Testing

@Test("Image understanding probe fixture loads a small PNG data URL from package resources")
func imageUnderstandingProbeFixtureLoadsPNGDataURL() throws {
    let fixture = try AIProviderProbeImageFixture.blueSquare()

    #expect(fixture.mimeType == "image/png")
    #expect(fixture.data.count > 0)
    #expect(fixture.data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    #expect(fixture.dataURLString.hasPrefix("data:image/png;base64,"))
    #expect(!fixture.dataURLString.contains("\n"))

    let imageSource = try #require(CGImageSourceCreateWithData(fixture.data as CFData, nil))
    let properties = try #require(
        CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
    )
    #expect(properties[kCGImagePropertyPixelWidth] as? Int == 256)
    #expect(properties[kCGImagePropertyPixelHeight] as? Int == 256)
}

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
    #expect(!bodies[1].contains(#"{\"ok\":true}"#))
    #expect(bodies[1].contains("field named ok"))
    #expect(bodies[1].contains("boolean true"))
    #expect(bodies[1].contains("Do not include markdown"))

    let events = await logger.events()
    #expect(events.map(\.name).contains(.aiProviderConfigurationProbeStarted))
    #expect(events.map(\.name).contains(.aiProviderConfigurationProbeSucceeded))
    #expect(events.flatMap(\.attributes).contains(.providerPresetID("openai")))
    #expect(events.flatMap(\.attributes).contains(.adapterKind(.openAICompatibleChat)))
    #expect(!String(describing: events).contains("sk-test-secret"))
}

@Test("OpenAI-compatible Chat probe runs language support after structured JSON success")
func openAICompatibleChatProbeRunsLanguageSupportAfterStructuredJSONSuccess() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"sample\":\"Today I opened the kitchen window before breakfast and wrote a short note about the rain, the quiet street, and the warm cup of tea beside my notebook. Later, I planned to review the moment in English so the simple details would become useful practice.\"}"}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(
            adapterKind: .openAICompatibleChat,
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capability(.languageSupport)?.status == .succeeded)
    #expect(await httpClient.requests.count == 3)

    let requests = await httpClient.requests
    let languageBody = try #require(String(data: requests[2].httpBody ?? Data(), encoding: .utf8))
    #expect(languageBody.contains("field named sample"))
    #expect(languageBody.contains("English"))
    #expect(languageBody.contains("40 to 70 words"))
    #expect(!languageBody.contains("life record"))
    #expect(!languageBody.contains("Prompt Preset"))
}

@Test("Language support probe is not configured and sends no request without language context")
func languageSupportProbeIsNotConfiguredWithoutLanguageContext() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(draftInput(adapterKind: .openAICompatibleChat))

    #expect(result.overallStatus == .succeeded)
    #expect(result.capability(.languageSupport)?.status == .notConfigured)
    #expect(await httpClient.requests.count == 2)
}

@Test("Structured JSON failure skips language support but keeps existing image probe behavior")
func structuredJSONFailureSkipsLanguageSupportButKeepsImageProbeBehavior() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"not json"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"blue square"}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(
            adapterKind: .openAICompatibleChat,
            imageInputEnabled: true,
            languageContext: AIProviderProbeLanguageContext(languageCode: "en")
        )
    )

    #expect(result.overallStatus == .failed)
    #expect(result.capability(.structuredJSON)?.status == .failed)
    #expect(result.capability(.languageSupport)?.status == .notRun)
    #expect(result.capability(.imageUnderstanding)?.status == .succeeded)
    #expect(await httpClient.requests.count == 3)
}

@Test("OpenAI-compatible Chat image understanding probe sends data URL and validates blue square")
func openAICompatibleChatImageUnderstandingProbeSendsDataURLAndMapsSuccess() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"blue square"}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(adapterKind: .openAICompatibleChat, imageInputEnabled: true)
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capability(.imageUnderstanding)?.status == .succeeded)

    let requests = await httpClient.requests
    #expect(requests.count == 3)
    let imageBody = try #require(String(data: requests[2].httpBody ?? Data(), encoding: .utf8))
    #expect(imageBody.contains(#""type":"image_url""#))
    #expect(imageBody.contains(#""url":"data:image\/png;base64,"#))
    #expect(imageBody.contains("Describe the image using exactly two lowercase English words"))
    #expect(!imageBody.contains("life record"))
    #expect(!imageBody.contains("Prompt Preset"))
    #expect(!imageBody.contains("sk-test"))
}

@Test("OpenAI Responses image understanding probe sends input image detail low")
func openAIResponsesImageUnderstandingProbeSendsInputImageDetailLow() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"ok\":true}"}]}]}"#),
        .json(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"blue square"}]}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(adapterKind: .openAIResponses, baseURL: "https://api.openai.com/v1", imageInputEnabled: true)
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capability(.imageUnderstanding)?.status == .succeeded)
    #expect(await httpClient.requests.map { $0.url?.absoluteString } == [
        "https://api.openai.com/v1/responses",
        "https://api.openai.com/v1/responses",
        "https://api.openai.com/v1/responses",
    ])

    let requests = await httpClient.requests
    let imageBody = try #require(String(data: requests[2].httpBody ?? Data(), encoding: .utf8))
    #expect(imageBody.contains(#""type":"input_image""#))
    #expect(imageBody.contains(#""image_url":"data:image\/png;base64,"#))
    #expect(imageBody.contains(#""detail":"low""#))
    #expect(imageBody.contains(#""max_output_tokens":8"#))
}

@Test("Image understanding probe rejects non canonical visual response")
func imageUnderstandingProbeRejectsNonCanonicalVisualResponse() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"a blue square."}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(adapterKind: .openAICompatibleChat, imageInputEnabled: true)
    )

    #expect(result.overallStatus == .failed)
    #expect(result.capability(.textReply)?.status == .succeeded)
    #expect(result.capability(.structuredJSON)?.status == .succeeded)
    #expect(result.capability(.imageUnderstanding)?.status == .failed)
    #expect(result.capability(.imageUnderstanding)?.errorCategory == .invalidResponse)
}

@Test("Image understanding probe does not send image request when image input is not enabled")
func imageUnderstandingProbeDoesNotRunWhenImageInputIsNotEnabled() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(adapterKind: .openAICompatibleChat, imageInputEnabled: false)
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capability(.imageUnderstanding)?.status == .notEnabled)
    #expect(await httpClient.requests.count == 2)
}

@Test("Image understanding probe does not trust enabled flag when endpoint cannot support images")
func imageUnderstandingProbeDoesNotRunWhenEndpointCannotSupportImages() async throws {
    let httpClient = CapturingProbeHTTPClient(responses: [
        .json(#"{"choices":[{"message":{"content":"OK"}}]}"#),
        .json(#"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#),
    ])
    let service = AIProviderConfigurationProbeService(httpClient: httpClient)

    let result = try await service.probeDraftConfiguration(
        draftInput(adapterKind: .openAICompatibleChat, supportsImageInput: false, imageInputEnabled: true)
    )

    #expect(result.overallStatus == .succeeded)
    #expect(result.capability(.imageUnderstanding)?.status == .unsupported)
    #expect(await httpClient.requests.count == 2)
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
    plaintextSecret: String? = "sk-test",
    supportsImageInput: Bool = true,
    imageInputEnabled: Bool = false,
    languageContext: AIProviderProbeLanguageContext? = nil
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
            supportsImageInput: supportsImageInput,
            imageInputEnabled: imageInputEnabled
        ),
        plaintextSecret: plaintextSecret,
        languageContext: languageContext,
        operationID: DiagnosticOperationID(rawValue: "operation-probe")
    )
}
