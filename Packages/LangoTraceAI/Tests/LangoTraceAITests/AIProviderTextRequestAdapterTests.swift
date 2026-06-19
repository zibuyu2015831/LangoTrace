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
    }

    @Test("factory throws unsupportedProvider for reserved kinds", arguments: [
        AIProviderAdapterKind.anthropicMessages,
        AIProviderAdapterKind.geminiGenerateContent,
    ])
    func factoryRejectsReservedKinds(kind: AIProviderAdapterKind) {
        #expect(throws: AIProviderTextRequestAdapterError.unsupportedProvider) {
            _ = try AIProviderTextRequestAdapterFactory.adapter(for: kind)
        }
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
