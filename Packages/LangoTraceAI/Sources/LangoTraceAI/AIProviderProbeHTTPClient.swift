@preconcurrency import Foundation

public protocol AIProviderProbeHTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> AIProviderProbeHTTPResponse
}

public struct AIProviderProbeHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var body: Data
    public var contentType: String?

    public init(statusCode: Int, body: Data, contentType: String? = nil) {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
    }
}

public enum AIProviderProbeHTTPClientError: Error, Equatable, Sendable {
    case transportUnavailable
    case timedOut
    case cancelled
}

public struct URLSessionAIProviderProbeHTTPClient: AIProviderProbeHTTPClient {
    private let client: any AIProviderHTTPClient

    public init(session: URLSession = .shared) {
        client = URLSessionAIProviderHTTPClient(session: session)
    }

    public init(client: any AIProviderHTTPClient) {
        self.client = client
    }

    public func send(_ request: URLRequest) async throws -> AIProviderProbeHTTPResponse {
        do {
            let response = try await client.send(request, maximumResponseBytes: 2 * 1024 * 1024)
            return AIProviderProbeHTTPResponse(
                statusCode: response.statusCode,
                body: response.body,
                contentType: response.contentType
            )
        } catch let error as AIProviderHTTPClientError {
            switch error {
            case .cancelled:
                throw AIProviderProbeHTTPClientError.cancelled
            case .timedOut:
                throw AIProviderProbeHTTPClientError.timedOut
            case .networkUnavailable, .invalidHTTPResponse, .responseTooLarge, .unacceptableStatusCode:
                throw AIProviderProbeHTTPClientError.transportUnavailable
            }
        }
    }
}
