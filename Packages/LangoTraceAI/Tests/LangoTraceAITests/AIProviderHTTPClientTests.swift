import Foundation
import LangoTraceAI
import Testing

@Suite("AI provider production HTTP client")
struct AIProviderHTTPClientTests {
    @Test("URLSession client forwards content type and rejects oversized response bodies")
    func urlSessionClientRejectsOversizedResponses() async throws {
        URLProtocolOversizedStub.response = (
            statusCode: 200,
            headers: ["Content-Type": "audio/mpeg"],
            body: Data(repeating: 1, count: 8)
        )
        let client = URLSessionAIProviderHTTPClient(session: Self.stubbedSession(URLProtocolOversizedStub.self))
        let request = try URLRequest(url: #require(URL(string: "https://example.test/audio/speech")))

        await #expect(throws: AIProviderHTTPClientError.responseTooLarge) {
            _ = try await client.send(request, maximumResponseBytes: 4)
        }

        let response = try await client.send(request, maximumResponseBytes: 16)
        #expect(response.statusCode == 200)
        #expect(response.body.count == 8)
        #expect(response.contentType == "audio/mpeg")
    }

    @Test("URLSession client maps transport errors to stable categories")
    func urlSessionClientMapsTransportErrors() async throws {
        URLProtocolTransportErrorStub.error = URLError(.timedOut)
        let client = URLSessionAIProviderHTTPClient(session: Self.stubbedSession(URLProtocolTransportErrorStub.self))
        let request = try URLRequest(url: #require(URL(string: "https://example.test/audio/speech")))

        await #expect(throws: AIProviderHTTPClientError.timedOut) {
            _ = try await client.send(request, maximumResponseBytes: 16)
        }

        URLProtocolTransportErrorStub.error = URLError(.cannotFindHost)
        await #expect(throws: AIProviderHTTPClientError.networkUnavailable) {
            _ = try await client.send(request, maximumResponseBytes: 16)
        }
    }

    private static func stubbedSession(_ protocolClass: AnyClass) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        return URLSession(configuration: configuration)
    }
}

private final class URLProtocolOversizedStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: (statusCode: Int, headers: [String: String], body: Data)?

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let response = Self.response,
              let url = request.url,
              let httpResponse = HTTPURLResponse(
                  url: url,
                  statusCode: response.statusCode,
                  httpVersion: nil,
                  headerFields: response.headers
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class URLProtocolTransportErrorStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var error: Error?

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: Self.error ?? URLError(.cannotConnectToHost))
    }

    override func stopLoading() {}
}
