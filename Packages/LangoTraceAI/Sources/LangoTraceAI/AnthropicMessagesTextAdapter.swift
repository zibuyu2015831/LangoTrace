@preconcurrency import Foundation
import LangoTraceCore

/// Anthropic Messages API adapter (`messages`).
///
/// Differs from the OpenAI-compatible adapters in four wire-level ways, all
/// handled here so the shared streaming service / probe path stays unchanged:
/// - **Auth**: `x-api-key` + `anthropic-version` headers, not `Authorization:
///   Bearer` (via the dispatched `providerRequestHeaders` requirement).
/// - **System**: a top-level `system` string, never a `role: system` turn in the
///   `messages` array.
/// - **max_tokens**: required on every request (a missing value is a 400).
/// - **Response / stream shape**: output text lives in `content[].text`; stream
///   text deltas arrive as `content_block_delta` events (no `[DONE]` sentinel —
///   the stream ends on connection EOF, which `AIChatStreamingService` already
///   finishes on).
///
/// Strict-schema structured output (Anthropic `tool_use`) and inline-image
/// understanding are deferred (LM03-S4b §2): `structuredCompletionBody` returns a
/// plain Anthropic body whose JSON-as-text reply is parsed best-effort, and
/// `structuredImagePromptBody` inherits the `nil` default.
struct AnthropicMessagesTextAdapter: AIProviderTextRequestAdapter {
    /// Anthropic requires `max_tokens`; the endpoint config carries no override
    /// field, so a sensible chat-scale default is baked in for the non-probe
    /// paths. The image / structured-image probe paths pass their own ceiling.
    static let defaultMaxTokens = 4096

    /// Pinned Messages API version. Required on every request.
    static let anthropicVersion = "2023-06-01"

    var pathSuffix: String {
        "messages"
    }

    func providerRequestHeaders(secret: String?) -> [String: String] {
        var headers = ["anthropic-version": Self.anthropicVersion]
        if let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            headers["x-api-key"] = secret
        }
        return headers
    }

    func structuredCompletionBody(
        model: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName _: String,
        schema _: [String: Any]
    ) -> [String: Any] {
        // Best-effort structured output: Anthropic has no `response_format`
        // json_schema, so the schema is not enforced on the wire here. The
        // consuming service parses the JSON-as-text reply; strict `tool_use`
        // enforcement is a deferred hardening (plan §2).
        [
            "model": model,
            "max_tokens": Self.defaultMaxTokens,
            "temperature": temperature,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
    }

    func plainPromptBody(model: String, prompt: String) -> [String: Any] {
        [
            "model": model,
            "max_tokens": Self.defaultMaxTokens,
            "messages": [["role": "user", "content": prompt]],
        ]
    }

    func imagePromptBody(
        model: String,
        prompt: String,
        imageDataURL: String,
        maximumOutputTokens: Int
    ) -> [String: Any] {
        var content: [[String: Any]] = [["type": "text", "text": prompt]]
        if let source = Self.anthropicImageSource(fromDataURL: imageDataURL) {
            content.append(["type": "image", "source": source])
        }
        return [
            "model": model,
            "max_tokens": maximumOutputTokens,
            "messages": [["role": "user", "content": content]],
        ]
    }

    func outputText(fromResponseObject object: [String: Any]) -> String? {
        AnthropicResponseTextParser.messagesText(fromResponseObject: object)
    }

    func streamingChatBody(
        model: String,
        system: String?,
        messages: [ConversationMessage]
    ) -> [String: Any]? {
        // Anthropic carries the system segment top-level, not as a turn — so this
        // does NOT use the shared `conversationWireMessages` (which prepends a
        // `role: system` entry). Only user / assistant turns go in `messages`.
        var body: [String: Any] = [
            "model": model,
            "max_tokens": Self.defaultMaxTokens,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "stream": true,
        ]
        if let system, !system.isEmpty {
            body["system"] = system
        }
        return body
    }

    func streamContentDelta(fromDataPayload payload: String) -> String? {
        AnthropicStreamDeltaExtractor.contentDelta(fromDataPayload: payload)
    }

    /// Splits a `data:<media_type>;base64,<data>` URL into the Anthropic image
    /// `source` object (`{type: base64, media_type, data}`), or `nil` when the
    /// string is not a base64 data URL.
    static func anthropicImageSource(fromDataURL dataURL: String) -> [String: String]? {
        guard dataURL.hasPrefix("data:"),
              let commaIndex = dataURL.firstIndex(of: ",")
        else {
            return nil
        }
        let header = dataURL[dataURL.index(dataURL.startIndex, offsetBy: "data:".count) ..< commaIndex]
        guard header.hasSuffix(";base64") else {
            return nil
        }
        let mediaType = String(header.dropLast(";base64".count))
        let data = String(dataURL[dataURL.index(after: commaIndex)...])
        guard !mediaType.isEmpty, !data.isEmpty else {
            return nil
        }
        return ["type": "base64", "media_type": mediaType, "data": data]
    }
}

/// Pure extraction of model output text from an Anthropic Messages response
/// object (`content[].text` across `type == "text"` blocks).
enum AnthropicResponseTextParser {
    static func messagesText(fromResponseObject object: [String: Any]) -> String? {
        guard let content = object["content"] as? [[String: Any]] else {
            return nil
        }
        let chunks = content.compactMap { block -> String? in
            guard block["type"] as? String == "text",
                  let text = block["text"] as? String
            else {
                return nil
            }
            return text
        }
        guard !chunks.isEmpty else {
            return nil
        }
        return chunks.joined()
    }
}

/// Pure extraction of the incremental text delta from an Anthropic Messages
/// streaming `data:` payload (`content_block_delta` events carrying a
/// `text_delta`). Returns `nil` for the non-text events (`message_start`,
/// `content_block_start`, `ping`, `message_delta`, `message_stop`).
enum AnthropicStreamDeltaExtractor {
    static func contentDelta(fromDataPayload payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "content_block_delta",
              let delta = object["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta",
              let text = delta["text"] as? String,
              !text.isEmpty
        else {
            return nil
        }
        return text
    }
}
