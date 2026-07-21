import Foundation
import LangoTraceCore

/// Google Gemini `generateContent` adapter.
///
/// Wire differences from the OpenAI-compatible family that this adapter owns:
/// - The model lives in the URL path (`models/{model}:generateContent`), not in
///   the body, and streaming switches the method name
///   (`models/{model}:streamGenerateContent?alt=sse`) — so this kind overrides
///   the `makeRequest` protocol requirement instead of using `pathSuffix`.
/// - Auth is the `x-goog-api-key` header (the UI preset's declared intent),
///   not `Authorization: Bearer`.
/// - Prompts travel as `contents[].parts[].text` with an optional
///   `systemInstruction`; multi-turn assistant messages use the role name
///   `model`.
/// - Structured output is best-effort: only `generationConfig.responseMimeType`
///   is set and the registered prompt's own format instructions carry the
///   schema (mirroring the Anthropic precedent; native `responseSchema` strict
///   mode is a registered follow-up).
struct GeminiGenerateContentTextAdapter: AIProviderTextRequestAdapter {
    /// Placeholder only: Gemini does not route through the default
    /// single-suffix URL builder — see the `makeRequest` override.
    var pathSuffix: String {
        "models"
    }

    func providerRequestHeaders(secret: String?) -> [String: String] {
        guard let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [:]
        }
        return ["x-goog-api-key": secret]
    }

    func makeRequest(
        baseURL: String,
        secret: String?,
        timeoutSeconds: Double?,
        model: String,
        streaming: Bool,
        body: [String: Any]
    ) throws -> URLRequest {
        let method = streaming ? "streamGenerateContent" : "generateContent"
        let suffix = "models/\(Self.normalizedModelName(model)):\(method)"
        guard let base = AIProviderEndpointURLBuilder.endpointURL(baseURL: baseURL, pathSuffix: suffix),
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else {
            throw AIProviderTextRequestAdapterError.invalidEndpointURL
        }
        if streaming {
            // Load-bearing: without `alt=sse` the streaming endpoint returns a
            // pretty-printed JSON array that the SSE parser cannot consume.
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "alt", value: "sse"))
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw AIProviderTextRequestAdapterError.invalidEndpointURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (field, value) in providerRequestHeaders(secret: secret) {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let timeoutSeconds {
            request.timeoutInterval = timeoutSeconds
        }
        return request
    }

    func structuredCompletionBody(
        model _: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName _: String,
        schema _: [String: Any]
    ) -> [String: Any] {
        // Best-effort JSON: the registered prompt's own format instructions
        // carry the schema; the adapter only pins the response MIME type and
        // deliberately synthesizes no unregistered outbound prompt text.
        [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [
                ["role": "user", "parts": [["text": user]]],
            ],
            "generationConfig": [
                "temperature": temperature,
                "responseMimeType": "application/json",
            ],
        ]
    }

    func plainPromptBody(model _: String, prompt: String) -> [String: Any] {
        [
            "contents": [
                ["role": "user", "parts": [["text": prompt]]],
            ],
        ]
    }

    func imagePromptBody(
        model: String,
        prompt: String,
        imageDataURL _: String,
        maximumOutputTokens _: Int
    ) -> [String: Any] {
        // Unreachable in production: `AIProviderImageSupport.supportsInlineImage`
        // keeps `.geminiGenerateContent` out of every image path (architecture
        // note 2026-06-24 defers Gemini multimodal bodies until capability-driven).
        plainPromptBody(model: model, prompt: prompt)
    }

    func streamingChatBody(
        model _: String,
        system: String?,
        messages: [ConversationMessage]
    ) -> [String: Any]? {
        var body: [String: Any] = [
            "contents": messages.map { message in
                [
                    // Gemini's wire role for assistant turns is `model`.
                    "role": message.role == .assistant ? "model" : "user",
                    "parts": [["text": message.content]],
                ] as [String: Any]
            },
        ]
        if let system, !system.isEmpty {
            body["systemInstruction"] = ["parts": [["text": system]]]
        }
        return body
    }

    func streamContentDelta(fromDataPayload payload: String) -> String? {
        GeminiStreamDeltaExtractor.contentDelta(fromDataPayload: payload)
    }

    func outputText(fromResponseObject object: [String: Any]) -> String? {
        GeminiResponseTextParser.candidatesText(fromResponseObject: object)
    }

    /// Strips a user-typed `models/` prefix so the path never doubles up.
    static func normalizedModelName(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("models/") {
            return String(trimmed.dropFirst("models/".count))
        }
        return trimmed
    }
}

/// Extracts concatenated candidate text from a decoded Gemini
/// `GenerateContentResponse` object.
enum GeminiResponseTextParser {
    static func candidatesText(fromResponseObject object: [String: Any]) -> String? {
        guard let candidates = object["candidates"] as? [[String: Any]] else {
            return nil
        }
        let fragments = candidates.flatMap { candidate -> [String] in
            guard let content = candidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]]
            else {
                return []
            }
            return parts.compactMap { $0["text"] as? String }
        }
        guard !fragments.isEmpty else {
            return nil
        }
        return fragments.joined()
    }
}

/// Extracts the incremental text delta from one Gemini `alt=sse` `data:`
/// payload (each chunk is a complete `GenerateContentResponse` JSON object).
enum GeminiStreamDeltaExtractor {
    static func contentDelta(fromDataPayload payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return GeminiResponseTextParser.candidatesText(fromResponseObject: object)
    }
}
