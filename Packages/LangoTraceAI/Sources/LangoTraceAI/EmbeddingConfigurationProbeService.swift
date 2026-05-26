@preconcurrency import Foundation
import LangoTraceCore

private let fixedEmbeddingProbeText = "LangoTrace embedding configuration test."

public struct EmbeddingDraftProbeInput: Sendable {
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?

    public init(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
    }
}

public struct EmbeddingConfigurationProbeService: Sendable {
    private let httpClient: any AIProviderProbeHTTPClient
    private let clock: @Sendable () -> Date

    public init(
        httpClient: any AIProviderProbeHTTPClient,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.clock = clock
    }

    public func probeDraftEmbeddingConfiguration(
        _ input: EmbeddingDraftProbeInput
    ) async -> AIProviderProbeCapabilityResult {
        await probe(endpoint: input.endpoint, plaintextSecret: input.plaintextSecret)
    }
}

private extension EmbeddingConfigurationProbeService {
    func probe(
        endpoint inputEndpoint: AIProviderEndpointInput,
        plaintextSecret: String?
    ) async -> AIProviderProbeCapabilityResult {
        let startedAt = clock()
        let metadata = AIProviderEndpointProbeMetadata(
            endpointID: inputEndpoint.id,
            endpointPurpose: .embedding,
            providerPresetID: inputEndpoint.providerPresetID,
            modelName: inputEndpoint.modelName,
            configurationFingerprint: inputEndpoint.configurationFingerprint
        )

        guard isFirstStageProvider(inputEndpoint.providerPresetID) else {
            return AIProviderProbeCapabilityResult(
                capability: .embedding,
                status: .unsupported,
                errorCategory: .unsupportedEndpointPurpose,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        }

        guard plaintextSecret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return AIProviderProbeCapabilityResult(
                capability: .embedding,
                status: .failed,
                errorCategory: .missingCredential,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        }

        do {
            let endpoint = try inputEndpoint.normalized()
            let request = try makeRequest(endpoint: endpoint, secret: plaintextSecret)
            let response = try await httpClient.send(request)
            let duration = durationMilliseconds(since: startedAt)
            guard (200 ... 299).contains(response.statusCode) else {
                return AIProviderProbeCapabilityResult(
                    capability: .embedding,
                    status: .failed,
                    errorCategory: errorCategory(forHTTPStatusCode: response.statusCode),
                    durationMilliseconds: duration,
                    endpointMetadata: metadata
                )
            }
            guard hasValidEmbeddingShape(response.body) else {
                return AIProviderProbeCapabilityResult(
                    capability: .embedding,
                    status: .failed,
                    errorCategory: .invalidEmbeddingResponse,
                    durationMilliseconds: duration,
                    endpointMetadata: metadata
                )
            }
            return AIProviderProbeCapabilityResult(
                capability: .embedding,
                status: .succeeded,
                errorCategory: nil,
                durationMilliseconds: duration,
                endpointMetadata: metadata
            )
        } catch let error as AIProviderProbeHTTPClientError {
            if error == .cancelled {
                return AIProviderProbeCapabilityResult(
                    capability: .embedding,
                    status: .cancelled,
                    errorCategory: nil,
                    durationMilliseconds: durationMilliseconds(since: startedAt),
                    endpointMetadata: metadata
                )
            }
            return AIProviderProbeCapabilityResult(
                capability: .embedding,
                status: .failed,
                errorCategory: error == .timedOut ? .timeout : .networkUnavailable,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        } catch is CancellationError {
            return AIProviderProbeCapabilityResult(
                capability: .embedding,
                status: .cancelled,
                errorCategory: nil,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        } catch {
            return AIProviderProbeCapabilityResult(
                capability: .embedding,
                status: .failed,
                errorCategory: .invalidEmbeddingResponse,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        }
    }

    func makeRequest(endpoint: AIProviderEndpointInput, secret: String?) throws -> URLRequest {
        let url = try embeddingsURL(baseURL: endpoint.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let timeout = endpoint.requestTimeoutSeconds {
            request.timeoutInterval = timeout
        }
        if let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "model": endpoint.modelName,
                "input": fixedEmbeddingProbeText,
                "encoding_format": "float",
            ],
            options: [.sortedKeys]
        )
        return request
    }

    func embeddingsURL(baseURL: String) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw AIProviderConfigurationError.invalidBaseURL
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, "embeddings"].filter { !$0.isEmpty }.joined(separator: "/"))
        guard let url = components.url else {
            throw AIProviderConfigurationError.invalidBaseURL
        }
        return url
    }

    func hasValidEmbeddingShape(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = object["data"] as? [[String: Any]],
              let first = dataArray.first,
              let embedding = first["embedding"] as? [Any],
              !embedding.isEmpty
        else {
            return false
        }
        return embedding.allSatisfy { value in
            if let number = value as? NSNumber {
                return CFGetTypeID(number) != CFBooleanGetTypeID()
            }
            return value is Int || value is Double || value is Float
        }
    }

    func errorCategory(forHTTPStatusCode statusCode: Int) -> AIProviderValidationErrorCategory {
        switch statusCode {
        case 401, 403:
            .authenticationFailed
        case 404:
            .unsupportedModel
        case 429:
            .rateLimited
        default:
            .providerRejected
        }
    }

    func isFirstStageProvider(_ providerPresetID: String) -> Bool {
        providerPresetID == "openai" ||
            providerPresetID == "openrouter" ||
            providerPresetID == "custom-openai-compatible"
    }

    func durationMilliseconds(since start: Date) -> Int {
        max(0, Int(clock().timeIntervalSince(start) * 1000))
    }
}
