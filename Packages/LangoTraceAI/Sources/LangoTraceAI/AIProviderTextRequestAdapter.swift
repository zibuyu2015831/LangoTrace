@preconcurrency import Foundation
import LangoTraceCore

/// Errors surfaced by the shared text-provider request adapters. Each calling
/// service maps these into its own failure category so the adapter stays
/// independent of any one service's error enum.
enum AIProviderTextRequestAdapterError: Error, Equatable {
    /// The endpoint base URL could not be turned into a request URL.
    case invalidEndpointURL
    /// The adapter kind has no text-provider implementation. As of the Gemini
    /// wiring (2026-07-22) every closed-set kind dispatches, so this case has
    /// no factory producer; it stays as the stable error vocabulary for future
    /// kinds and the services' catch mappings.
    case unsupportedProvider
    /// The response body could not be decoded into model output text.
    case invalidResponseBody
}

/// Single dispatch entry mapping an `AIProviderAdapterKind` to its text-request
/// adapter. The switch is exhaustive with no default, so adding a new kind
/// forces an implementation decision at compile time. All text services obtain
/// their adapter here instead of switching on the kind inline.
enum AIProviderTextRequestAdapterFactory {
    static func adapter(
        for kind: AIProviderAdapterKind
    ) throws -> any AIProviderTextRequestAdapter {
        switch kind {
        case .openAICompatibleChat:
            OpenAICompatibleChatTextAdapter()
        case .openAIResponses:
            OpenAIResponsesTextAdapter()
        case .mimoCompatibleChat:
            MimoCompatibleChatTextAdapter()
        case .anthropicMessages:
            AnthropicMessagesTextAdapter()
        case .geminiGenerateContent:
            GeminiGenerateContentTextAdapter()
        }
    }
}

/// Per-kind construction of OpenAI-compatible text requests and response
/// parsing. Request finalization (auth header, content type, body
/// serialization, timeout) is shared in the protocol extension so the only
/// per-kind code is the path suffix, the JSON body shapes, and the text
/// extraction strategy.
protocol AIProviderTextRequestAdapter: Sendable {
    /// Path appended to the endpoint base URL (e.g. `chat/completions`).
    var pathSuffix: String { get }

    /// Body for a structured-output (JSON schema) text completion, used by the
    /// learning-material and reading-selection services.
    func structuredCompletionBody(
        model: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName: String,
        schema: [String: Any]
    ) -> [String: Any]

    /// Body for a plain single-prompt request (text / structured-JSON /
    /// language-support configuration probes).
    func plainPromptBody(model: String, prompt: String) -> [String: Any]

    /// Body for a single-prompt request carrying one inline image
    /// (image-understanding configuration probe).
    func imagePromptBody(
        model: String,
        prompt: String,
        imageDataURL: String,
        maximumOutputTokens: Int
    ) -> [String: Any]

    /// Body for a **structured-output (JSON schema) request that also carries one
    /// inline image** — the contract the photo-writing assist capability needs.
    ///
    /// This is deliberately separate from `imagePromptBody` (which is plain-text,
    /// schema-less, and capped at a tiny probe token budget) and from
    /// `structuredCompletionBody` (which carries no image). Returns `nil` for
    /// adapter kinds that do not support combining an image with structured
    /// output; the photo-writing assist service treats `nil` as
    /// "unsupported adapter" so support stays structural rather than implicit.
    func structuredImagePromptBody(
        model: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName: String,
        schema: [String: Any],
        imageDataURL: String,
        maximumOutputTokens: Int
    ) -> [String: Any]?

    /// Extracts model output text from a decoded response object, or `nil` when
    /// the payload carries no recognizable output text.
    func outputText(fromResponseObject object: [String: Any]) -> String?

    /// Provider-specific request headers (auth scheme plus any version pins) to
    /// apply to a finalized request. This is a **protocol requirement** — not an
    /// extension-only helper — so per-kind overrides dispatch through the
    /// `any AIProviderTextRequestAdapter` existential the services hold. The
    /// OpenAI-compatible default returns `Authorization: Bearer`; Anthropic
    /// overrides to `x-api-key` + `anthropic-version`; mimo overrides to
    /// `api-key`. Returns an empty dictionary when no secret is present.
    func providerRequestHeaders(secret: String?) -> [String: String]

    /// Body for a **multi-turn, streaming** chat request (the language-companion
    /// transport seam). Carries an ordered `[ConversationMessage]` plus an
    /// optional leading system segment, with `stream: true` baked in.
    ///
    /// Returns `nil` for adapter kinds with no streaming chat implementation
    /// (mimo — streaming remains deferred, so it inherits the default `nil`).
    /// OpenAI Chat / Responses, Anthropic and Gemini override it. The
    /// streaming service treats `nil` as "unsupported provider" so support stays
    /// structural.
    func streamingChatBody(
        model: String,
        system: String?,
        messages: [ConversationMessage]
    ) -> [String: Any]?

    /// Extracts the incremental text delta from a single SSE `data:` payload for
    /// this adapter's stream shape (chat/completions vs Responses events), or
    /// `nil` for chunks that carry no text.
    func streamContentDelta(fromDataPayload payload: String) -> String?

    /// Builds the finalized POST `URLRequest`. This is a **protocol
    /// requirement** — not an extension-only helper — so per-kind URL schemes
    /// dispatch through the `any AIProviderTextRequestAdapter` existential the
    /// services hold (Gemini puts the model in the path and switches method
    /// name for streaming). The default implementation keeps the single
    /// `pathSuffix` scheme and ignores `model` / `streaming`; services always
    /// pass both so a kind that needs them can act on them.
    func makeRequest(
        baseURL: String,
        secret: String?,
        timeoutSeconds: Double?,
        model: String,
        streaming: Bool,
        body: [String: Any]
    ) throws -> URLRequest
}

extension AIProviderTextRequestAdapter {
    /// Default: no structured-image support. Kinds that support it (OpenAI Chat /
    /// Responses) override this; mimo, Anthropic and Gemini inherit `nil`.
    func structuredImagePromptBody(
        model _: String,
        system _: String,
        user _: String,
        temperature _: Double,
        structuredOutputName _: String,
        schema _: [String: Any],
        imageDataURL _: String,
        maximumOutputTokens _: Int
    ) -> [String: Any]? {
        nil
    }

    /// Default: no streaming chat support. OpenAI Chat / Responses, Anthropic
    /// and Gemini override; mimo inherits `nil` (streaming deferred).
    func streamingChatBody(
        model _: String,
        system _: String?,
        messages _: [ConversationMessage]
    ) -> [String: Any]? {
        nil
    }

    /// Default: no stream delta shape. Overridden per kind.
    func streamContentDelta(fromDataPayload _: String) -> String? {
        nil
    }

    /// Default OpenAI-compatible auth: `Authorization: Bearer` when a non-blank
    /// secret is present, no auth header otherwise. Anthropic / mimo override
    /// this requirement; OpenAI Chat / Responses inherit the default.
    func providerRequestHeaders(secret: String?) -> [String: String] {
        guard let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [:]
        }
        return ["Authorization": "Bearer \(secret)"]
    }

    /// Shared `messages`/`input` wire array builder: optional leading system
    /// segment, then the ordered turns mapped to `{role, content}` dictionaries.
    func conversationWireMessages(
        system: String?,
        messages: [ConversationMessage]
    ) -> [[String: String]] {
        var wire: [[String: String]] = []
        if let system, !system.isEmpty {
            wire.append(["role": ConversationRole.system.rawValue, "content": system])
        }
        wire.append(contentsOf: messages.map { ["role": $0.role.rawValue, "content": $0.content] })
        return wire
    }

    /// Builds a finalized POST `URLRequest`: resolves the URL via the shared
    /// URL builder, sets JSON content type, injects the credential headers,
    /// serializes `body`, and applies the optional timeout. `model` and
    /// `streaming` are ignored here — the OpenAI-compatible family and
    /// Anthropic carry the model in the body and switch streaming via a body
    /// flag; Gemini overrides this requirement to fold both into the URL.
    func makeRequest(
        baseURL: String,
        secret: String?,
        timeoutSeconds: Double?,
        model _: String,
        streaming _: Bool,
        body: [String: Any]
    ) throws -> URLRequest {
        guard let url = AIProviderEndpointURLBuilder.endpointURL(baseURL: baseURL, pathSuffix: pathSuffix)
        else {
            throw AIProviderTextRequestAdapterError.invalidEndpointURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Auth scheme + any version pins come from the per-kind requirement so
        // a non-Bearer provider (Anthropic `x-api-key`, mimo `api-key`) dispatches
        // through the existential the services hold rather than being locked to
        // the OpenAI Bearer default here.
        for (field, value) in providerRequestHeaders(secret: secret) {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let timeoutSeconds {
            request.timeoutInterval = timeoutSeconds
        }
        return request
    }

    /// Decodes `data` to a JSON object and extracts model output text, throwing
    /// `.invalidResponseBody` when the payload is not a JSON object or carries
    /// no output text.
    func extractText(fromResponseBody data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = outputText(fromResponseObject: object)
        else {
            throw AIProviderTextRequestAdapterError.invalidResponseBody
        }
        return text
    }
}

/// OpenAI-compatible Chat Completions adapter (`chat/completions`).
struct OpenAICompatibleChatTextAdapter: AIProviderTextRequestAdapter {
    var pathSuffix: String {
        "chat/completions"
    }

    func structuredCompletionBody(
        model: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName: String,
        schema: [String: Any]
    ) -> [String: Any] {
        [
            "model": model,
            "temperature": temperature,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": structuredOutputName,
                    "strict": true,
                    "schema": schema,
                ],
            ],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
    }

    func plainPromptBody(model: String, prompt: String) -> [String: Any] {
        [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt],
            ],
        ]
    }

    func imagePromptBody(
        model: String,
        prompt: String,
        imageDataURL: String,
        maximumOutputTokens: Int
    ) -> [String: Any] {
        [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": imageDataURL]],
                    ],
                ],
            ],
            "max_tokens": maximumOutputTokens,
        ]
    }

    func structuredImagePromptBody(
        model: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName: String,
        schema: [String: Any],
        imageDataURL: String,
        maximumOutputTokens: Int
    ) -> [String: Any]? {
        [
            "model": model,
            "temperature": temperature,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": structuredOutputName,
                    "strict": true,
                    "schema": schema,
                ],
            ],
            "messages": [
                ["role": "system", "content": system],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": user],
                        ["type": "image_url", "image_url": ["url": imageDataURL]],
                    ],
                ],
            ],
            "max_tokens": maximumOutputTokens,
        ]
    }

    func outputText(fromResponseObject object: [String: Any]) -> String? {
        OpenAICompatibleResponseTextParser.chatCompletionsText(fromResponseObject: object)
    }

    func streamingChatBody(
        model: String,
        system: String?,
        messages: [ConversationMessage]
    ) -> [String: Any]? {
        [
            "model": model,
            "messages": conversationWireMessages(system: system, messages: messages),
            "stream": true,
        ]
    }

    func streamContentDelta(fromDataPayload payload: String) -> String? {
        OpenAIStreamDeltaExtractor.chatCompletionsContentDelta(fromDataPayload: payload)
    }
}

/// OpenAI Responses API adapter (`responses`).
struct OpenAIResponsesTextAdapter: AIProviderTextRequestAdapter {
    var pathSuffix: String {
        "responses"
    }

    func structuredCompletionBody(
        model: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName: String,
        schema: [String: Any]
    ) -> [String: Any] {
        [
            "model": model,
            "temperature": temperature,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": structuredOutputName,
                    "strict": true,
                    "schema": schema,
                ],
            ],
            "input": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
    }

    func plainPromptBody(model: String, prompt: String) -> [String: Any] {
        [
            "model": model,
            "input": prompt,
        ]
    }

    func imagePromptBody(
        model: String,
        prompt: String,
        imageDataURL: String,
        maximumOutputTokens: Int
    ) -> [String: Any] {
        [
            "model": model,
            "input": [
                [
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": prompt],
                        ["type": "input_image", "image_url": imageDataURL, "detail": "low"],
                    ],
                ],
            ],
            "max_output_tokens": maximumOutputTokens,
        ]
    }

    func structuredImagePromptBody(
        model: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName: String,
        schema: [String: Any],
        imageDataURL: String,
        maximumOutputTokens: Int
    ) -> [String: Any]? {
        [
            "model": model,
            "temperature": temperature,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": structuredOutputName,
                    "strict": true,
                    "schema": schema,
                ],
            ],
            "input": [
                ["role": "system", "content": system],
                [
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": user],
                        ["type": "input_image", "image_url": imageDataURL],
                    ],
                ],
            ],
            "max_output_tokens": maximumOutputTokens,
        ]
    }

    func outputText(fromResponseObject object: [String: Any]) -> String? {
        OpenAICompatibleResponseTextParser.responsesText(fromResponseObject: object)
    }

    func streamingChatBody(
        model: String,
        system: String?,
        messages: [ConversationMessage]
    ) -> [String: Any]? {
        [
            "model": model,
            "input": conversationWireMessages(system: system, messages: messages),
            "stream": true,
        ]
    }

    func streamContentDelta(fromDataPayload payload: String) -> String? {
        OpenAIStreamDeltaExtractor.responsesContentDelta(fromDataPayload: payload)
    }
}

/// MIMO chat completions adapter.
/// Same request/response shape as OpenAI-compatible chat completions, but
/// uses `api-key: KEY` instead of `Authorization: Bearer KEY`.
struct MimoCompatibleChatTextAdapter: AIProviderTextRequestAdapter {
    var pathSuffix: String {
        "chat/completions"
    }

    func structuredCompletionBody(
        model: String,
        system: String,
        user: String,
        temperature: Double,
        structuredOutputName: String,
        schema: [String: Any]
    ) -> [String: Any] {
        [
            "model": model,
            "temperature": temperature,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": structuredOutputName,
                    "strict": true,
                    "schema": schema,
                ],
            ],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
    }

    func plainPromptBody(model: String, prompt: String) -> [String: Any] {
        [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt],
            ],
        ]
    }

    func imagePromptBody(
        model: String,
        prompt: String,
        imageDataURL: String,
        maximumOutputTokens: Int
    ) -> [String: Any] {
        [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": imageDataURL]],
                    ],
                ],
            ],
            "max_tokens": maximumOutputTokens,
        ]
    }

    func outputText(fromResponseObject object: [String: Any]) -> String? {
        OpenAICompatibleResponseTextParser.chatCompletionsText(fromResponseObject: object)
    }

    /// mimo authenticates with a bare `api-key` header rather than
    /// `Authorization: Bearer`. Overriding the dispatched requirement (instead of
    /// a same-name `makeRequest` overload, which the existential never reaches)
    /// is what actually applies this header on the shared request path.
    func providerRequestHeaders(secret: String?) -> [String: String] {
        guard let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [:]
        }
        return ["api-key": secret]
    }
}
