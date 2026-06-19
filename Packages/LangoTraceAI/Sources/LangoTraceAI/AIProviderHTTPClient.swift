@preconcurrency import Foundation

public protocol AIProviderHTTPClient: Sendable {
    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> AIProviderHTTPResponse
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
}

public struct URLSessionAIProviderHTTPClient: AIProviderHTTPClient {
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
}
