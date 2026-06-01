import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Reading selection explanation service")
struct ReadingSelectionExplanationServiceTests {
    @Test("prompt registry renders selection-only request contract")
    func promptRegistryRendersSelectionOnlyContract() {
        let prompt = ReadingSelectionExplanationPromptRegistry.prompt(
            input: sampleInput(selection: "図書館", context: "今日は図書館で読みます。")
        )

        #expect(prompt.id == "builtin.reading.selection_explanation.v1")
        #expect(prompt.version == "1")
        #expect(prompt.user.contains("selected_text: 図書館"))
        #expect(prompt.user.contains("context_text: 今日は図書館で読みます。"))
        #expect(!prompt.user.contains("full_document"))
    }

    @Test("service builds chat request with selection limited payload and parses response")
    func serviceBuildsChatRequestAndParsesResponse() async throws {
        let httpClient = try CapturingReadingExplanationHTTPClient(responses: [
            .success(AIProviderHTTPResponse(statusCode: 200, body: chatResponse(explanationJSON()))),
        ])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)

        let result = try await service.explain(
            ReadingSelectionExplanationServiceRequest(
                endpoint: endpoint(adapterKind: .openAICompatibleChat),
                plaintextSecret: "sk-test-secret",
                input: sampleInput(selection: "ticket", context: "I bought a ticket at the station.")
            )
        )

        let requests = await httpClient.requests
        #expect(requests.count == 1)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret")
        #expect(requests[0].jsonBodyValue("response_format.type") == "json_schema")
        #expect(requests[0].httpBodyText?.contains("selected_text: ticket") == true)
        #expect(requests[0].httpBodyText?.contains("full_document") == false)
        #expect(result.selection == "ticket")
        #expect(result.shortExplanation == "A travel noun in this sentence.")
    }

    @Test("service maps cancellation without parsing or returning stale content")
    func serviceMapsCancellation() async throws {
        let httpClient = CapturingReadingExplanationHTTPClient(responses: [
            .failure(AIProviderHTTPClientError.cancelled),
        ])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)

        await #expect(throws: ReadingSelectionExplanationServiceError(category: .cancelled)) {
            try await service.explain(
                ReadingSelectionExplanationServiceRequest(
                    endpoint: endpoint(adapterKind: .openAICompatibleChat),
                    plaintextSecret: "sk-test-secret",
                    input: sampleInput(selection: "ticket", context: "I bought a ticket.")
                )
            )
        }
    }

    @Test("service rejects unsupported adapters before HTTP")
    func serviceRejectsUnsupportedAdaptersBeforeHTTP() async throws {
        let httpClient = CapturingReadingExplanationHTTPClient(responses: [])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)

        await #expect(throws: ReadingSelectionExplanationServiceError(category: .unsupportedProvider)) {
            try await service.explain(
                ReadingSelectionExplanationServiceRequest(
                    endpoint: endpoint(adapterKind: .anthropicMessages),
                    plaintextSecret: "sk-test-secret",
                    input: sampleInput(selection: "ticket", context: "I bought a ticket.")
                )
            )
        }
        #expect(await httpClient.requests.isEmpty)
    }
}

private actor CapturingReadingExplanationHTTPClient: AIProviderHTTPClient {
    private(set) var requests: [URLRequest] = []
    private var responses: [Result<AIProviderHTTPResponse, Error>]

    init(responses: [Result<AIProviderHTTPResponse, Error>]) {
        self.responses = responses
    }

    func send(_ request: URLRequest, maximumResponseBytes _: Int) async throws -> AIProviderHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw AIProviderHTTPClientError.networkUnavailable
        }
        return try responses.removeFirst().get()
    }
}

private func sampleInput(selection: String, context: String) -> ReadingSelectionExplanationInput {
    ReadingSelectionExplanationInput(
        documentID: "doc-1",
        sourceAnchorID: "anchor-1",
        selectedText: selection,
        containingSentence: context,
        contextText: context,
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        proficiencyLevelCode: "b1"
    )
}

private func explanationJSON() -> String {
    """
    {
      "schema_version": "reading_selection_explanation.v1",
      "selection": "ticket",
      "short_explanation": "A travel noun in this sentence.",
      "meaning_in_native_language": "票",
      "usage_note": "Used for trains, events, and travel.",
      "example_sentence": "I bought a ticket online."
    }
    """
}
