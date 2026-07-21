@preconcurrency import Foundation

public protocol AIProviderHTTPClient: Sendable {
    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> AIProviderHTTPResponse
}

/// Streaming counterpart to `AIProviderHTTPClient`: yields response body bytes
/// incrementally as an `AsyncThrowingStream` so multi-turn chat responses can be
/// surfaced token-by-token (LM03 消费). Kept a separate protocol so existing
/// single-shot conformers and their test fakes stay untouched.
///
/// Contract: the stream throws on a non-2xx status
/// (`unacceptableStatusCode`), on transport failure / cancellation / timeout
/// (the existing `AIProviderHTTPClientError` cases), and on accumulation past
/// `maximumResponseBytes` (`responseTooLarge`) — the same volume cap the
/// single-shot path enforces, preserved under streaming.
public protocol AIProviderStreamingHTTPClient: Sendable {
    func streamBytes(_ request: URLRequest, maximumResponseBytes: Int) -> AsyncThrowingStream<UInt8, Error>
}

public struct AIProviderHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var body: Data
    public var contentType: String?

    public init(statusCode: Int, body: Data, contentType: String? = nil) {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
    }
}

public enum AIProviderHTTPClientError: Error, Equatable, Sendable {
    case cancelled
    case timedOut
    case networkUnavailable
    case invalidHTTPResponse
    case responseTooLarge
    /// A non-2xx HTTP status on a streaming request. Carries the raw status code
    /// so the streaming service can classify it via `AIProviderHTTPStatusErrorMapper`
    /// (the single-shot path classifies status inside each calling service instead).
    case unacceptableStatusCode(Int)
}

public struct URLSessionAIProviderHTTPClient: AIProviderHTTPClient, AIProviderStreamingHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> AIProviderHTTPResponse {
        do {
            let (asyncBytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIProviderHTTPClientError.invalidHTTPResponse
            }
            var accumulated = Data()
            for try await byte in asyncBytes {
                accumulated.append(byte)
                if accumulated.count > maximumResponseBytes {
                    throw AIProviderHTTPClientError.responseTooLarge
                }
            }
            return AIProviderHTTPResponse(
                statusCode: httpResponse.statusCode,
                body: accumulated,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type")
            )
        } catch let error as AIProviderHTTPClientError {
            throw error
        } catch is CancellationError {
            throw AIProviderHTTPClientError.cancelled
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw AIProviderHTTPClientError.cancelled
            case .timedOut:
                throw AIProviderHTTPClientError.timedOut
            default:
                throw AIProviderHTTPClientError.networkUnavailable
            }
        }
    }

    public func streamBytes(_ request: URLRequest, maximumResponseBytes: Int) -> AsyncThrowingStream<UInt8, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIProviderHTTPClientError.invalidHTTPResponse
                    }
                    guard (200 ..< 300).contains(httpResponse.statusCode) else {
                        throw AIProviderHTTPClientError.unacceptableStatusCode(httpResponse.statusCode)
                    }
                    var count = 0
                    for try await byte in asyncBytes {
                        count += 1
                        // The single-shot volume cap, preserved under streaming:
                        // already-yielded deltas are delivered (streaming本义),
                        // but accumulation past the cap terminates the stream.
                        if count > maximumResponseBytes {
                            throw AIProviderHTTPClientError.responseTooLarge
                        }
                        continuation.yield(byte)
                    }
                    continuation.finish()
                } catch let error as AIProviderHTTPClientError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish(throwing: AIProviderHTTPClientError.cancelled)
                } catch let error as URLError {
                    switch error.code {
                    case .cancelled:
                        continuation.finish(throwing: AIProviderHTTPClientError.cancelled)
                    case .timedOut:
                        continuation.finish(throwing: AIProviderHTTPClientError.timedOut)
                    default:
                        continuation.finish(throwing: AIProviderHTTPClientError.networkUnavailable)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Consumer cancellation (breaking the for-await) cancels the URLSession task.
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
