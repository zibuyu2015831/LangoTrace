import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("AI text request adapter")
struct AIProviderTextRequestAdapterTests {
    private func decodedBody(_ request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test("factory dispatches OpenAI-compatible kinds to concrete adapters")
    func factoryDispatchesSupportedKinds() throws {
        #expect(try AIProviderTextRequestAdapterFactory.adapter(for: .openAICompatibleChat).pathSuffix == "chat/completions")
        #expect(try AIProviderTextRequestAdapterFactory.adapter(for: .openAIResponses).pathSuffix == "responses")
        // LM03-S4b: Anthropic Messages is now wired (path `messages`); only Gemini
        // remains a reserved/throwing kind.
        #expect(try AIProviderTextRequestAdapterFactory.adapter(for: .anthropicMessages).pathSuffix == "messages")
    }

    @Test("factory throws unsupportedProvider for the remaining reserved kind")
    func factoryRejectsReservedKinds() {
        #expect(throws: AIProviderTextRequestAdapterError.unsupportedProvider) {
            _ = try AIProviderTextRequestAdapterFactory.adapter(for: .geminiGenerateContent)
        }
    }

    // MARK: - Anthropic Messages adapter (LM03-S4b)

    @Test("Anthropic adapter authorizes with x-api-key + anthropic-version, not Bearer")
    func anthropicAdapterUsesApiKeyAndVersionHeaders() throws {
        let adapter = AnthropicMessagesTextAdapter()
        let request = try adapter.makeRequest(
            baseURL: "https://api.anthropic.com/v1",
            secret: "sk-ant-secret",
            timeoutSeconds: 30,
            body: adapter.plainPromptBody(model: "claude-test", prompt: "hi")
        )
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-secret")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Anthropic version header is present even without a secret; x-api-key is omitted", arguments: [nil, "", "  "])
    func anthropicOmitsKeyButKeepsVersionWithoutSecret(secret: String?) throws {
        let adapter = AnthropicMessagesTextAdapter()
        let request = try adapter.makeRequest(
            baseURL: "https://api.anthropic.com/v1",
            secret: secret,
            timeoutSeconds: nil,
            body: adapter.plainPromptBody(model: "claude-test", prompt: "hi")
        )
        #expect(request.value(forHTTPHeaderField: "x-api-key") == nil)
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    }

    @Test("Anthropic plain prompt body carries required max_tokens and a single user message")
    func anthropicPlainPromptBodyShape() throws {
        let body = AnthropicMessagesTextAdapter().plainPromptBody(model: "claude-test", prompt: "hello")
        #expect(body["model"] as? String == "claude-test")
        #expect(body["max_tokens"] as? Int == 4096)
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages.first?["role"] as? String == "user")
        #expect(messages.first?["content"] as? String == "hello")
    }

    @Test("Anthropic streaming body puts system top-level, keeps only user/assistant turns, requires max_tokens")
    func anthropicStreamingBodyShape() throws {
        let body = try #require(AnthropicMessagesTextAdapter().streamingChatBody(
            model: "claude-test",
            system: "You are grounded.",
            messages: [
                ConversationMessage(role: .user, content: "u1"),
                ConversationMessage(role: .assistant, content: "a1"),
                ConversationMessage(role: .user, content: "u2"),
            ]
        ))
        #expect(body["stream"] as? Bool == true)
        #expect(body["max_tokens"] as? Int == 4096)
        // System rides top-level, NOT inside the messages array.
        #expect(body["system"] as? String == "You are grounded.")
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] } == ["user", "assistant", "user"])
        #expect(!messages.contains { $0["role"] == "system" })
    }

    @Test("Anthropic streaming body omits system when none is provided")
    func anthropicStreamingBodyOmitsEmptySystem() throws {
        let body = try #require(AnthropicMessagesTextAdapter().streamingChatBody(
            model: "claude-test",
            system: nil,
            messages: [ConversationMessage(role: .user, content: "u1")]
        ))
        #expect(body["system"] == nil)
    }

    @Test("Anthropic outputText reads content[].text across text blocks")
    func anthropicOutputTextParsesContentBlocks() throws {
        let adapter = AnthropicMessagesTextAdapter()
        let payload = #"{"content":[{"type":"text","text":"Hel"},{"type":"text","text":"lo"}],"role":"assistant"}"#
        let text = try adapter.extractText(fromResponseBody: Data(payload.utf8))
        #expect(text == "Hello")
    }

    @Test("Anthropic outputText throws on payloads with no text block")
    func anthropicOutputTextRejectsNonText() {
        let adapter = AnthropicMessagesTextAdapter()
        #expect(throws: AIProviderTextRequestAdapterError.invalidResponseBody) {
            _ = try adapter.extractText(fromResponseBody: Data(#"{"content":[]}"#.utf8))
        }
    }

    @Test("Anthropic stream delta extracts content_block_delta text_delta and ignores other events")
    func anthropicStreamDeltaExtraction() {
        let textDelta = #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"He"}}"#
        #expect(AnthropicStreamDeltaExtractor.contentDelta(fromDataPayload: textDelta) == "He")
        // Non-text events yield nil.
        #expect(AnthropicStreamDeltaExtractor.contentDelta(fromDataPayload: #"{"type":"message_start"}"#) == nil)
        #expect(AnthropicStreamDeltaExtractor.contentDelta(
            fromDataPayload: #"{"type":"content_block_start","content_block":{"type":"text","text":""}}"#
        ) == nil)
        #expect(AnthropicStreamDeltaExtractor.contentDelta(fromDataPayload: "{}") == nil)
    }

    @Test("Anthropic image body splits a data URL into a base64 image source block")
    func anthropicImageBodyShape() throws {
        let body = AnthropicMessagesTextAdapter().imagePromptBody(
            model: "claude-test",
            prompt: "describe",
            imageDataURL: "data:image/png;base64,AAAA",
            maximumOutputTokens: 8
        )
        #expect(body["max_tokens"] as? Int == 8)
        let messages = try #require(body["messages"] as? [[String: Any]])
        let content = try #require(messages.first?["content"] as? [[String: Any]])
        #expect(content.contains { $0["type"] as? String == "text" })
        let image = try #require(content.first { $0["type"] as? String == "image" })
        let source = try #require(image["source"] as? [String: String])
        #expect(source["type"] == "base64")
        #expect(source["media_type"] == "image/png")
        #expect(source["data"] == "AAAA")
    }

    @Test("Anthropic inherits no structured-image body (deferred from v1)")
    func anthropicHasNoStructuredImageBody() {
        let body = AnthropicMessagesTextAdapter().structuredImagePromptBody(
            model: "m", system: "s", user: "u", temperature: 0.2,
            structuredOutputName: "x", schema: ["type": "object"],
            imageDataURL: "data:image/png;base64,AAAA", maximumOutputTokens: 8
        )
        #expect(body == nil)
    }

    // MARK: - mimo auth regression (LM03-S4b fixed the dead-override bug)

    @Test("mimo adapter now authorizes with the api-key header, not Bearer")
    func mimoAdapterUsesApiKeyHeader() throws {
        let adapter = MimoCompatibleChatTextAdapter()
        let request = try adapter.makeRequest(
            baseURL: "https://api.test/v1",
            secret: "mimo-secret",
            timeoutSeconds: nil,
            body: adapter.plainPromptBody(model: "m", prompt: "hi")
        )
        #expect(request.value(forHTTPHeaderField: "api-key") == "mimo-secret")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("chat adapter builds a Bearer-authorized JSON POST to chat/completions")
    func chatAdapterBuildsBearerAuthorizedRequest() throws {
        let adapter = OpenAICompatibleChatTextAdapter()
        let request = try adapter.makeRequest(
            baseURL: "https://api.test/v1",
            secret: "sk-secret",
            timeoutSeconds: 42,
            body: adapter.plainPromptBody(model: "gpt-test", prompt: "hello")
        )
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.test/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-secret")
        #expect(request.timeoutInterval == 42)
    }

    @Test("responses adapter targets the responses path")
    func responsesAdapterTargetsResponsesPath() throws {
        let adapter = OpenAIResponsesTextAdapter()
        let request = try adapter.makeRequest(
            baseURL: "https://api.test/v1",
            secret: "sk-secret",
            timeoutSeconds: nil,
            body: adapter.plainPromptBody(model: "gpt-test", prompt: "hello")
        )
        #expect(request.url?.absoluteString == "https://api.test/v1/responses")
    }

    @Test("no Authorization header when secret is missing or blank", arguments: [nil, "", "   "])
    func omitsAuthorizationWithoutSecret(secret: String?) throws {
        let adapter = OpenAICompatibleChatTextAdapter()
        let request = try adapter.makeRequest(
            baseURL: "https://api.test/v1",
            secret: secret,
            timeoutSeconds: nil,
            body: adapter.plainPromptBody(model: "gpt-test", prompt: "hello")
        )
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("chat structured body carries response_format json_schema and chat messages")
    func chatStructuredBodyShape() throws {
        let adapter = OpenAICompatibleChatTextAdapter()
        let body = adapter.structuredCompletionBody(
            model: "gpt-test",
            system: "sys",
            user: "usr",
            temperature: 0.2,
            structuredOutputName: "demo_schema",
            schema: ["type": "object"]
        )
        let responseFormat = try #require(body["response_format"] as? [String: Any])
        let jsonSchema = try #require(responseFormat["json_schema"] as? [String: Any])
        #expect(responseFormat["type"] as? String == "json_schema")
        #expect(jsonSchema["name"] as? String == "demo_schema")
        #expect(jsonSchema["strict"] as? Bool == true)
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.first?["role"] as? String == "system")
        #expect(messages.last?["content"] as? String == "usr")
        #expect(body["input"] == nil)
    }

    @Test("responses structured body carries text.format json_schema and input messages")
    func responsesStructuredBodyShape() throws {
        let adapter = OpenAIResponsesTextAdapter()
        let body = adapter.structuredCompletionBody(
            model: "gpt-test",
            system: "sys",
            user: "usr",
            temperature: 0.2,
            structuredOutputName: "demo_schema",
            schema: ["type": "object"]
        )
        let text = try #require(body["text"] as? [String: Any])
        let format = try #require(text["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect(format["name"] as? String == "demo_schema")
        let input = try #require(body["input"] as? [[String: Any]])
        #expect(input.first?["role"] as? String == "system")
        #expect(body["response_format"] == nil)
    }

    @Test("plain prompt body differs per kind: chat uses messages, responses uses input string")
    func plainPromptBodyShape() {
        let chat = OpenAICompatibleChatTextAdapter().plainPromptBody(model: "m", prompt: "p")
        #expect((chat["messages"] as? [[String: Any]])?.first?["content"] as? String == "p")

        let responses = OpenAIResponsesTextAdapter().plainPromptBody(model: "m", prompt: "p")
        #expect(responses["input"] as? String == "p")
    }

    @Test("image prompt body uses the correct token key and inline image per kind")
    func imagePromptBodyShape() {
        let chat = OpenAICompatibleChatTextAdapter().imagePromptBody(
            model: "m",
            prompt: "p",
            imageDataURL: "data:image/png;base64,AAAA",
            maximumOutputTokens: 8
        )
        #expect(chat["max_tokens"] as? Int == 8)
        #expect(chat["max_output_tokens"] == nil)

        let responses = OpenAIResponsesTextAdapter().imagePromptBody(
            model: "m",
            prompt: "p",
            imageDataURL: "data:image/png;base64,AAAA",
            maximumOutputTokens: 8
        )
        #expect(responses["max_output_tokens"] as? Int == 8)
        #expect(responses["max_tokens"] == nil)
    }

    @Test("chat structured-image body carries both an image part and a json_schema response_format")
    func chatStructuredImageBodyShape() throws {
        let adapter = OpenAICompatibleChatTextAdapter()
        let body = try #require(adapter.structuredImagePromptBody(
            model: "gpt-test",
            system: "sys",
            user: "usr",
            temperature: 0.4,
            structuredOutputName: "photo_writing_assist",
            schema: ["type": "object"],
            imageDataURL: "data:image/jpeg;base64,AAAA",
            maximumOutputTokens: 700
        ))
        // Structured output is present (the gap P0-1 found in imagePromptBody).
        let responseFormat = try #require(body["response_format"] as? [String: Any])
        #expect(responseFormat["type"] as? String == "json_schema")
        #expect((responseFormat["json_schema"] as? [String: Any])?["strict"] as? Bool == true)
        // The image rides in the user message content parts.
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.first?["role"] as? String == "system")
        let userContent = try #require(messages.last?["content"] as? [[String: Any]])
        #expect(userContent.contains { $0["type"] as? String == "text" })
        #expect(userContent.contains { $0["type"] as? String == "image_url" })
        // A real-output token budget, not the probe's tiny ceiling.
        #expect(body["max_tokens"] as? Int == 700)
    }

    @Test("responses structured-image body carries both an input_image and a text.format json_schema")
    func responsesStructuredImageBodyShape() throws {
        let adapter = OpenAIResponsesTextAdapter()
        let body = try #require(adapter.structuredImagePromptBody(
            model: "gpt-test",
            system: "sys",
            user: "usr",
            temperature: 0.4,
            structuredOutputName: "photo_writing_assist",
            schema: ["type": "object"],
            imageDataURL: "data:image/jpeg;base64,AAAA",
            maximumOutputTokens: 700
        ))
        let format = try #require((body["text"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let input = try #require(body["input"] as? [[String: Any]])
        let userContent = try #require(input.last?["content"] as? [[String: Any]])
        #expect(userContent.contains { $0["type"] as? String == "input_text" })
        #expect(userContent.contains { $0["type"] as? String == "input_image" })
        #expect(body["max_output_tokens"] as? Int == 700)
    }

    @Test("mimo adapter has no structured-image body (excluded from v1 image matrix)")
    func mimoHasNoStructuredImageBody() {
        let body = MimoCompatibleChatTextAdapter().structuredImagePromptBody(
            model: "m",
            system: "s",
            user: "u",
            temperature: 0.2,
            structuredOutputName: "x",
            schema: ["type": "object"],
            imageDataURL: "data:image/jpeg;base64,AAAA",
            maximumOutputTokens: 700
        )
        #expect(body == nil)
    }

    @Test("chat extractText reads choices[].message.content")
    func chatExtractText() throws {
        let adapter = OpenAICompatibleChatTextAdapter()
        let payload = #"{"choices":[{"message":{"content":"hi there"}}]}"#
        let text = try adapter.extractText(fromResponseBody: Data(payload.utf8))
        #expect(text == "hi there")
    }

    @Test("responses extractText reads output_text")
    func responsesExtractText() throws {
        let adapter = OpenAIResponsesTextAdapter()
        let payload = #"{"output_text":"hi there"}"#
        let text = try adapter.extractText(fromResponseBody: Data(payload.utf8))
        #expect(text == "hi there")
    }

    @Test("extractText throws invalidResponseBody on non-object or empty payloads")
    func extractTextRejectsInvalidBodies() {
        let adapter = OpenAICompatibleChatTextAdapter()
        #expect(throws: AIProviderTextRequestAdapterError.invalidResponseBody) {
            _ = try adapter.extractText(fromResponseBody: Data(#"[]"#.utf8))
        }
        #expect(throws: AIProviderTextRequestAdapterError.invalidResponseBody) {
            _ = try adapter.extractText(fromResponseBody: Data(#"{"choices":[]}"#.utf8))
        }
    }
}
