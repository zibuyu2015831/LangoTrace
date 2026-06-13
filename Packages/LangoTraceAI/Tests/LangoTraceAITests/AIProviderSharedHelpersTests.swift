import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Shared endpoint URL builder")
struct AIProviderEndpointURLBuilderTests {
    @Test(
        "builder normalizes base URL variants identically for probes and real requests",
        arguments: [
            ("https://api.openai.com/v1", "chat/completions", "https://api.openai.com/v1/chat/completions"),
            ("https://api.openai.com/v1/", "chat/completions", "https://api.openai.com/v1/chat/completions"),
            (
                "https://api.openai.com/v1/chat/completions",
                "chat/completions",
                "https://api.openai.com/v1/chat/completions"
            ),
            ("https://api.openai.com/v1", "responses", "https://api.openai.com/v1/responses"),
            ("https://api.openai.com/v1/responses/", "responses", "https://api.openai.com/v1/responses"),
            ("https://gateway.example.com/openai/v1", "embeddings", "https://gateway.example.com/openai/v1/embeddings"),
            ("https://api.openai.com", "chat/completions", "https://api.openai.com/chat/completions"),
            ("https://api.openai.com/v1", "audio/speech", "https://api.openai.com/v1/audio/speech"),
            ("https://api.openai.com/v1/audio/speech", "audio/speech", "https://api.openai.com/v1/audio/speech"),
        ]
    )
    func builderNormalizesBaseURLVariants(testCase: (baseURL: String, suffix: String, expected: String)) {
        let url = AIProviderEndpointURLBuilder.endpointURL(
            baseURL: testCase.baseURL,
            pathSuffix: testCase.suffix
        )
        #expect(url?.absoluteString == testCase.expected)
    }
}

@Suite("Shared HTTP status error mapper")
struct AIProviderHTTPStatusErrorMapperTests {
    @Test(
        "mapper classifies provider HTTP status codes into stable categories",
        arguments: [
            (401, AIProviderValidationErrorCategory.authenticationFailed),
            (403, AIProviderValidationErrorCategory.authenticationFailed),
            (404, AIProviderValidationErrorCategory.unsupportedModel),
            (429, AIProviderValidationErrorCategory.rateLimited),
            (400, AIProviderValidationErrorCategory.providerRejected),
            (500, AIProviderValidationErrorCategory.providerRejected),
        ]
    )
    func mapperClassifiesStatusCodes(testCase: (statusCode: Int, expected: AIProviderValidationErrorCategory)) {
        #expect(
            AIProviderHTTPStatusErrorMapper.errorCategory(forHTTPStatusCode: testCase.statusCode)
                == testCase.expected
        )
    }
}

@Suite("Shared OpenAI-compatible response text parser")
struct OpenAICompatibleResponseTextParserTests {
    @Test("responses parser skips leading reasoning items from reasoning models")
    func responsesParserSkipsLeadingReasoningItems() throws {
        let json = """
        {
          "output": [
            {"type": "reasoning", "summary": []},
            {"type": "message", "content": [{"type": "output_text", "text": "OK"}]}
          ]
        }
        """
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        #expect(OpenAICompatibleResponseTextParser.responsesText(fromResponseObject: object) == "OK")
    }

    @Test("responses parser prefers the output_text convenience field")
    func responsesParserPrefersOutputTextConvenienceField() {
        let object: [String: Any] = ["output_text": "convenience"]
        #expect(OpenAICompatibleResponseTextParser.responsesText(fromResponseObject: object) == "convenience")
    }

    @Test("responses parser accepts content items without an explicit type field")
    func responsesParserAcceptsContentItemsWithoutTypeField() throws {
        let json = """
        {"output": [{"content": [{"text": "no type"}]}]}
        """
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        #expect(OpenAICompatibleResponseTextParser.responsesText(fromResponseObject: object) == "no type")
    }

    @Test("responses parser returns nil when only reasoning items are present")
    func responsesParserReturnsNilForReasoningOnlyOutput() throws {
        let json = """
        {"output": [{"type": "reasoning", "summary": []}]}
        """
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        #expect(OpenAICompatibleResponseTextParser.responsesText(fromResponseObject: object) == nil)
    }

    @Test("chat parser extracts message content and rejects missing choices")
    func chatParserExtractsMessageContent() throws {
        let json = """
        {"choices": [{"message": {"content": "OK"}}]}
        """
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        #expect(OpenAICompatibleResponseTextParser.chatCompletionsText(fromResponseObject: object) == "OK")
        #expect(OpenAICompatibleResponseTextParser.chatCompletionsText(fromResponseObject: [:]) == nil)
    }
}
