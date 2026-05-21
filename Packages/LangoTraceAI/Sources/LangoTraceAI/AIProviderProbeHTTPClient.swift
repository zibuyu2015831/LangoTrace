@preconcurrency import Foundation

public protocol AIProviderProbeHTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> AIProviderProbeHTTPResponse
}

public struct AIProviderProbeHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

public enum AIProviderProbeHTTPClientError: Error, Equatable, Sendable {
    case transportUnavailable
    case timedOut
    case cancelled
}

public struct URLSessionAIProviderProbeHTTPClient: AIProviderProbeHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> AIProviderProbeHTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            return AIProviderProbeHTTPResponse(statusCode: statusCode, body: data)
        } catch is CancellationError {
            throw AIProviderProbeHTTPClientError.cancelled
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw AIProviderProbeHTTPClientError.timedOut
            case .cancelled:
                throw AIProviderProbeHTTPClientError.cancelled
            default:
                throw AIProviderProbeHTTPClientError.transportUnavailable
            }
        }
    }
}
