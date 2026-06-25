@preconcurrency import Foundation
import LangoTraceCore

/// Errors surfaced by the shared text-provider request adapters. Each calling
/// service maps these into its own failure category so the adapter stays
/// independent of any one service's error enum.
enum AIProviderTextRequestAdapterError: Error, Equatable {
    /// The endpoint base URL could not be turned into a request URL.
    case invalidEndpointURL
    /// The adapter kind has no text-provider implementation yet
    /// (`anthropicMessages` / `geminiGenerateContent` are reserved extension
    /// points; real wiring happens via `docs/workflows/add-ai-provider.md`).
    case unsupportedProvider
    /// The response body could not be decoded into model output text.
    case invalidResponseBody
}

/// Single dispatch entry mapping an `AIProviderAdapterKind` to its text-request
/// adapter, or throwing `.unsupportedProvider` for kinds without a
/// text-provider implementation. All three OpenAI-compatible text services
/// (learning-material generation, reading-selection explanation, configuration
/// probe) obtain their adapter here instead of switching on the kind inline.
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
        case .anthropicMessages, .geminiGenerateContent:
            throw AIProviderTextRequestAdapterError.unsupportedProvider
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

    /// Body for a **multi-turn, streaming** chat request (the language-companion
    /// transport seam). Carries an ordered `[ConversationMessage]` plus an
    /// optional leading system segment, with `stream: true` baked in.
    ///
    /// Returns `nil` for adapter kinds with no streaming chat implementation
    /// (`anthropicMessages` / `geminiGenerateContent` — already rejected by the
    /// factory; the default inherits `nil`). The streaming service treats `nil`
    /// as "unsupported provider" so support stays structural.
    func streamingChatBody(
        model: String,
        system: String?,
        messages: [ConversationMessage]
    ) -> [String: Any]?

    /// Extracts the incremental text delta from a single SSE `data:` payload for
    /// this adapter's stream shape (chat/completions vs Responses events), or
    /// `nil` for chunks that carry no text.
    func streamContentDelta(fromDataPayload payload: String) -> String?
}

extension AIProviderTextRequestAdapter {
    /// Default: no structured-image support. Kinds that support it (OpenAI Chat /
    /// Responses) override this; mimo and the reserved kinds inherit `nil`.
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

    /// Default: no streaming chat support. OpenAI Chat / Responses / mimo
    /// override; the reserved kinds inherit `nil`.
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
    /// URL builder, sets JSON content type, injects the Bearer credential when
    /// present, serializes `body`, and applies the optional timeout.
    func makeRequest(
        baseURL: String,
        secret: String?,
        timeoutSeconds: Double?,
        body: [String: Any]
    ) throws -> URLRequest {
        guard let url = AIProviderEndpointURLBuilder.endpointURL(baseURL: baseURL, pathSuffix: pathSuffix)
        else {
            throw AIProviderTextRequestAdapterError.invalidEndpointURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Bearer is the OpenAI-compatible scheme. Anthropic's `x-api-key`
            // header strategy will be injected by its own adapter when added.
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
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

    func makeRequest(
        baseURL: String,
        secret: String?,
        body: [String: Any],
        timeoutSeconds: TimeInterval?
    ) throws -> URLRequest {
        guard let url = AIProviderEndpointURLBuilder.endpointURL(baseURL: baseURL, pathSuffix: pathSuffix)
        else {
            throw AIProviderTextRequestAdapterError.invalidEndpointURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(secret, forHTTPHeaderField: "api-key")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let timeoutSeconds {
            request.timeoutInterval = timeoutSeconds
        }
        return request
    }
}
