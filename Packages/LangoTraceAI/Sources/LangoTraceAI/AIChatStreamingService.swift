@preconcurrency import Foundation
import LangoTraceCore

/// One incremental event from a multi-turn chat stream.
public enum AIChatStreamEvent: Equatable, Sendable {
    /// An incremental text delta to append to the assistant turn.
    case delta(String)
}

/// Failure categories a chat stream can terminate with. Maps the transport-level
/// `AIProviderHTTPClientError` onto the same vocabulary the single-shot AI
/// services use, so LM03 can classify a streaming outcome identically.
public enum AIChatStreamingError: Error, Equatable, Sendable {
    /// The adapter kind has no streaming chat implementation
    /// (`anthropicMessages` / `geminiGenerateContent`; mimo streaming is also
    /// unverified and deferred — see plan §20).
    case unsupportedProvider
    case cancelled
    case timedOut
    case networkUnavailable
    case responseTooLarge
    case invalidResponse
    /// A non-2xx provider response, classified into the shared validation
    /// category (auth / model / rate-limit / rejected).
    case providerRejected(AIProviderValidationErrorCategory)
}

/// Non-sensitive projection-readiness metadata for a multi-turn chat request.
///
/// This is the "投影就绪" contract from plan §3 target 4: it carries only the
/// descriptors LM03 needs to build an E6 preview / log row (provider preset,
/// model, a coarse size bucket, the message count) — and **never** the message
/// bodies, the system persona, or the credential. The actual
/// `AIRequestPreviewProjection` / log row (with its capability case) is assembled
/// by LM03, which owns those closed Core enums.
public struct AIChatRequestProjectionMetadata: Equatable, Sendable {
    public var providerPresetID: String
    public var modelName: String
    public var lengthBucket: AIRequestLengthBucket
    public var messageCount: Int

    public init(
        providerPresetID: String,
        modelName: String,
        lengthBucket: AIRequestLengthBucket,
        messageCount: Int
    ) {
        self.providerPresetID = providerPresetID
        self.modelName = modelName
        self.lengthBucket = lengthBucket
        self.messageCount = messageCount
    }
}

/// A multi-turn streaming chat request: the endpoint, the plaintext secret, an
/// optional system segment, and the ordered transcript. Pure value type so LM03
/// UI / store can build it; the streaming service consumes it.
public struct AIChatStreamingServiceRequest: Sendable {
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?
    public var system: String?
    public var messages: [ConversationMessage]

    public init(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        system: String?,
        messages: [ConversationMessage]
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
        self.system = system
        self.messages = messages
    }

    /// Builds the non-sensitive projection-readiness metadata. The size bucket is
    /// derived from the **total character count** of system + all message bodies,
    /// never the bodies themselves.
    public func projectionMetadata() -> AIChatRequestProjectionMetadata {
        let totalCharacters = (system?.count ?? 0) + messages.reduce(0) { $0 + $1.content.count }
        return AIChatRequestProjectionMetadata(
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            lengthBucket: AIRequestLengthBucket(characterCount: totalCharacters),
            messageCount: messages.count
        )
    }
}

/// Streaming, multi-turn AI chat service. Exposes the response as an
/// `AsyncThrowingStream<AIChatStreamEvent, Error>` — the codebase's first
/// throwing async stream — mapping cancellation / timeout / network / oversize /
/// non-2xx onto `AIChatStreamingError`.
///
/// Stays a pure executor (spec 005 §3): it builds the request via the existing
/// adapter seam and consumes the injected streaming HTTP client. It does **not**
/// write `ai_request_logs` — per the E6 dependency direction the log is written
/// by an App-Shell recorder after the request terminates; that wiring is LM03.
public struct AIChatStreamingService: Sendable {
    private let httpClient: any AIProviderStreamingHTTPClient
    private let maximumResponseBytes: Int

    /// Default 2 MiB cap mirrors the order of magnitude used by the single-shot
    /// text paths; a multi-turn reply far past this is treated as runaway.
    public init(
        httpClient: any AIProviderStreamingHTTPClient,
        maximumResponseBytes: Int = 2_000_000
    ) {
        self.httpClient = httpClient
        self.maximumResponseBytes = maximumResponseBytes
    }

    public func stream(_ request: AIChatStreamingServiceRequest) -> AsyncThrowingStream<AIChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let adapter = try AIProviderTextRequestAdapterFactory.adapter(for: request.endpoint.adapterKind)
                    guard let body = adapter.streamingChatBody(
                        model: request.endpoint.modelName,
                        system: request.system,
                        messages: request.messages
                    ) else {
                        throw AIChatStreamingError.unsupportedProvider
                    }
                    let urlRequest = try adapter.makeRequest(
                        baseURL: request.endpoint.baseURL,
                        secret: request.plaintextSecret,
                        timeoutSeconds: request.endpoint.requestTimeoutSeconds,
                        body: body
                    )
                    var parser = ServerSentEventParser()
                    let byteStream = httpClient.streamBytes(urlRequest, maximumResponseBytes: maximumResponseBytes)
                    for try await byte in byteStream {
                        for event in parser.consume([byte]) {
                            switch event {
                            case let .data(payload):
                                if let delta = adapter.streamContentDelta(fromDataPayload: payload) {
                                    continuation.yield(.delta(delta))
                                }
                            case .done:
                                continuation.finish()
                                return
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.mapError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Maps adapter / transport errors onto the streaming error vocabulary.
    static func mapError(_ error: Error) -> Error {
        if let streamingError = error as? AIChatStreamingError {
            return streamingError
        }
        if let adapterError = error as? AIProviderTextRequestAdapterError {
            switch adapterError {
            case .unsupportedProvider:
                return AIChatStreamingError.unsupportedProvider
            case .invalidEndpointURL, .invalidResponseBody:
                return AIChatStreamingError.invalidResponse
            }
        }
        if let httpError = error as? AIProviderHTTPClientError {
            switch httpError {
            case .cancelled:
                return AIChatStreamingError.cancelled
            case .timedOut:
                return AIChatStreamingError.timedOut
            case .networkUnavailable:
                return AIChatStreamingError.networkUnavailable
            case .responseTooLarge:
                return AIChatStreamingError.responseTooLarge
            case .invalidHTTPResponse:
                return AIChatStreamingError.invalidResponse
            case let .unacceptableStatusCode(code):
                return AIChatStreamingError.providerRejected(
                    AIProviderHTTPStatusErrorMapper.errorCategory(forHTTPStatusCode: code)
                )
            }
        }
        if error is CancellationError {
            return AIChatStreamingError.cancelled
        }
        return error
    }
}
