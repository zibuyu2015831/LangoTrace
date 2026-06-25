import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

/// Covers the multi-turn + text-streaming Provider seam (independent infra, LM03
/// 消费): multi-turn body shape, the `AsyncThrowingStream` chat service mapping
/// cancellation / failure / oversize to the existing error categories, and the
/// projection-readiness metadata that carries no message bodies / credentials.
@Suite("AI chat streaming service")
struct AIChatStreamingServiceTests {
    // MARK: - Fixtures

    // `endpoint(adapterKind:)` is the shared fixture (providerPresetID "openai",
    // model "gpt-4.1-mini") from LearningMaterialGenerationServiceFixtures.

    private func request(
        messages: [ConversationMessage] = [
            ConversationMessage(role: .user, content: "Hi"),
        ],
        system: String? = "You are grounded.",
        adapterKind: AIProviderAdapterKind = .openAICompatibleChat
    ) -> AIChatStreamingServiceRequest {
        AIChatStreamingServiceRequest(
            endpoint: endpoint(adapterKind: adapterKind),
            plaintextSecret: "secret",
            system: system,
            messages: messages
        )
    }

    /// SSE bytes for an OpenAI-compatible chat stream emitting "He" + "llo".
    private func helloStreamBytes() -> [UInt8] {
        let sse = """
        data: {"choices":[{"delta":{"role":"assistant"}}]}
        data: {"choices":[{"delta":{"content":"He"}}]}
        data: {"choices":[{"delta":{"content":"llo"}}]}
        data: [DONE]

        """
        return Array(sse.utf8)
    }

    // MARK: - Multi-turn body

    @Test("chat/completions streaming body carries ordered messages + stream flag")
    func chatStreamingBodyCarriesOrderedMessages() throws {
        let adapter = OpenAICompatibleChatTextAdapter()
        let body = try #require(adapter.streamingChatBody(
            model: "gpt-4.1-mini",
            system: "sys",
            messages: [
                ConversationMessage(role: .user, content: "u1"),
                ConversationMessage(role: .assistant, content: "a1"),
                ConversationMessage(role: .user, content: "u2"),
            ]
        ))
        #expect(body["stream"] as? Bool == true)
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] } == ["system", "user", "assistant", "user"])
        #expect(messages.map { $0["content"] } == ["sys", "u1", "a1", "u2"])
    }

    @Test("responses streaming body carries ordered input + stream flag")
    func responsesStreamingBodyCarriesInput() throws {
        let adapter = OpenAIResponsesTextAdapter()
        let body = try #require(adapter.streamingChatBody(
            model: "gpt-4.1-mini",
            system: nil,
            messages: [ConversationMessage(role: .user, content: "u1")]
        ))
        #expect(body["stream"] as? Bool == true)
        let input = try #require(body["input"] as? [[String: String]])
        #expect(input.map { $0["role"] } == ["user"])
    }

    @Test("reserved provider kinds throw unsupportedProvider from the stream")
    func reservedProviderKindsAreUnsupported() async {
        let service = AIChatStreamingService(httpClient: ScriptedStreamingHTTPClient(steps: []))
        let stream = service.stream(request(adapterKind: .anthropicMessages))
        await #expect(throws: AIChatStreamingError.unsupportedProvider) {
            for try await _ in stream {}
        }
    }

    // MARK: - Streaming happy path

    @Test("yields ordered deltas then completes on [DONE]")
    func yieldsOrderedDeltasThenCompletes() async throws {
        let client = ScriptedStreamingHTTPClient(steps: [.bytes(helloStreamBytes())])
        let service = AIChatStreamingService(httpClient: client)
        var deltas: [String] = []
        for try await event in service.stream(request()) {
            if case let .delta(text) = event {
                deltas.append(text)
            }
        }
        #expect(deltas == ["He", "llo"])
    }

    // MARK: - Failure / cancellation / oversize mapping

    @Test("cancellation terminates the stream with .cancelled after delivered deltas")
    func cancellationTerminatesStream() async {
        // Deterministic: scripted client feeds one delta chunk, then injects a
        // cancellation. The already-yielded delta is delivered (streaming
        // semantics), then the stream throws .cancelled.
        let firstChunk = Array("data: {\"choices\":[{\"delta\":{\"content\":\"He\"}}]}\n".utf8)
        let client = ScriptedStreamingHTTPClient(steps: [
            .bytes(firstChunk),
            .fail(AIProviderHTTPClientError.cancelled),
        ])
        let service = AIChatStreamingService(httpClient: client)
        var deltas: [String] = []
        await #expect(throws: AIChatStreamingError.cancelled) {
            for try await event in service.stream(request()) {
                if case let .delta(text) = event { deltas.append(text) }
            }
        }
        #expect(deltas == ["He"])
    }

    @Test("timeout maps to .timedOut")
    func timeoutMapsToTimedOut() async {
        let client = ScriptedStreamingHTTPClient(steps: [.fail(AIProviderHTTPClientError.timedOut)])
        let service = AIChatStreamingService(httpClient: client)
        await #expect(throws: AIChatStreamingError.timedOut) {
            for try await _ in service.stream(request()) {}
        }
    }

    @Test("HTTP 429 status maps to providerRejected(.rateLimited)")
    func rateLimitedMapsToProviderRejected() async {
        let client = ScriptedStreamingHTTPClient(steps: [.fail(AIProviderHTTPClientError.unacceptableStatusCode(429))])
        let service = AIChatStreamingService(httpClient: client)
        await #expect(throws: AIChatStreamingError.providerRejected(.rateLimited)) {
            for try await _ in service.stream(request()) {}
        }
    }

    @Test("oversize accumulation maps to .responseTooLarge")
    func oversizeMapsToResponseTooLarge() async {
        let client = ScriptedStreamingHTTPClient(steps: [.fail(AIProviderHTTPClientError.responseTooLarge)])
        let service = AIChatStreamingService(httpClient: client)
        await #expect(throws: AIChatStreamingError.responseTooLarge) {
            for try await _ in service.stream(request()) {}
        }
    }

    // MARK: - Projection-readiness (no bodies / credentials)

    @Test("multi-turn request projection metadata omits message bodies and secret")
    func multiTurnRequestMetadataOmitsMessageBodies() {
        let req = request(
            messages: [
                ConversationMessage(role: .user, content: "a sensitive diary line"),
                ConversationMessage(role: .assistant, content: "reply"),
            ],
            system: "system persona text"
        )
        let metadata = req.projectionMetadata()
        // Carries only non-sensitive descriptors.
        #expect(metadata.providerPresetID == "openai")
        #expect(metadata.modelName == "gpt-4.1-mini")
        #expect(metadata.messageCount == 2)
        #expect(metadata.lengthBucket == .short)
        // No field anywhere in the metadata may carry the actual message body,
        // system persona, or the credential.
        let dumped = String(describing: metadata)
        #expect(!dumped.contains("sensitive diary"))
        #expect(!dumped.contains("system persona"))
        #expect(!dumped.contains("secret"))
        #expect(!dumped.contains("reply"))
    }

    @Test("length bucket grows with total conversation size")
    func lengthBucketGrowsWithSize() {
        let long = String(repeating: "x", count: 2000)
        let req = request(messages: [ConversationMessage(role: .user, content: long)], system: nil)
        #expect(req.projectionMetadata().lengthBucket == .long)
    }
}

/// Scripted streaming HTTP client for deterministic streaming-service tests:
/// feeds pre-baked byte chunks in order, then optionally injects a terminal
/// failure — no real URLSession timing involved.
struct ScriptedStreamingHTTPClient: AIProviderStreamingHTTPClient {
    enum Step {
        case bytes([UInt8])
        case fail(Error)
    }

    let steps: [Step]

    func streamBytes(_: URLRequest, maximumResponseBytes _: Int) -> AsyncThrowingStream<UInt8, Error> {
        AsyncThrowingStream { continuation in
            for step in steps {
                switch step {
                case let .bytes(bytes):
                    for byte in bytes {
                        continuation.yield(byte)
                    }
                case let .fail(error):
                    continuation.finish(throwing: error)
                    return
                }
            }
            continuation.finish()
        }
    }
}
