@preconcurrency import Foundation
import LangoTraceCore

public struct AIProviderConfigurationProbeDraftInput {
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?
    public var operationID: DiagnosticOperationID

    public init(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        operationID: DiagnosticOperationID
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
        self.operationID = operationID
    }
}

public struct AIProviderConfigurationProbeService: Sendable {
    private let httpClient: any AIProviderProbeHTTPClient
    private let diagnosticLogger: any DiagnosticLogging
    private let clock: @Sendable () -> Date

    public init(
        httpClient: any AIProviderProbeHTTPClient,
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger(),
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.diagnosticLogger = diagnosticLogger
        self.clock = clock
    }

    public func probeDraftConfiguration(
        _ input: AIProviderConfigurationProbeDraftInput
    ) async throws -> AIProviderConfigurationProbeResult {
        let endpoint = try input.endpoint.normalized()
        await record(
            .aiProviderConfigurationProbeStarted,
            outcome: .started,
            level: .info,
            operationID: input.operationID,
            endpoint: endpoint,
            attributes: [
                .probeCapability(.textReply),
                .probeCapability(.structuredJSON),
            ]
        )

        let result: AIProviderConfigurationProbeResult
        switch endpoint.adapterKind {
        case .openAICompatibleChat, .openAIResponses:
            result = await runTextProbes(endpoint: endpoint, secret: input.plaintextSecret)
        case .anthropicMessages, .geminiGenerateContent:
            result = unsupportedResult(endpoint: endpoint)
        }

        await recordCompletion(result, endpoint: endpoint, operationID: input.operationID)
        return result
    }
}

private extension AIProviderConfigurationProbeService {
    enum ProbeKind {
        case textReply
        case structuredJSON

        var capability: AIProviderProbeCapability {
            switch self {
            case .textReply:
                .textReply
            case .structuredJSON:
                .structuredJSON
            }
        }

        var prompt: String {
            switch self {
            case .textReply:
                "Configuration test. Reply with OK only."
            case .structuredJSON:
                #"Configuration test. Reply only with {"ok":true}."#
            }
        }
    }

    func runTextProbes(
        endpoint: AIProviderEndpointInput,
        secret: String?
    ) async -> AIProviderConfigurationProbeResult {
        if endpointRequiresCredential(endpoint), secret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return result(
                endpoint: endpoint,
                textStatus: .failed,
                textError: .missingCredential,
                jsonStatus: .notRun,
                jsonError: nil
            )
        }

        let textResult = await runProbe(.textReply, endpoint: endpoint, secret: secret)
        guard textResult.status == .succeeded else {
            return result(
                endpoint: endpoint,
                textStatus: textResult.status,
                textError: textResult.errorCategory,
                textDuration: textResult.durationMilliseconds,
                jsonStatus: .notRun,
                jsonError: nil
            )
        }

        let jsonResult = await runProbe(.structuredJSON, endpoint: endpoint, secret: secret)
        return result(
            endpoint: endpoint,
            textStatus: textResult.status,
            textError: textResult.errorCategory,
            textDuration: textResult.durationMilliseconds,
            jsonStatus: jsonResult.status,
            jsonError: jsonResult.errorCategory,
            jsonDuration: jsonResult.durationMilliseconds
        )
    }

    func runProbe(
        _ kind: ProbeKind,
        endpoint: AIProviderEndpointInput,
        secret: String?
    ) async -> AIProviderProbeCapabilityResult {
        let startedAt = clock()
        do {
            let request = try makeRequest(kind, endpoint: endpoint, secret: secret)
            let response = try await httpClient.send(request)
            let duration = durationMilliseconds(since: startedAt)
            guard (200 ... 299).contains(response.statusCode) else {
                return AIProviderProbeCapabilityResult(
                    capability: kind.capability,
                    status: .failed,
                    errorCategory: errorCategory(forHTTPStatusCode: response.statusCode),
                    durationMilliseconds: duration
                )
            }

            let text = try parseText(from: response.body, adapterKind: endpoint.adapterKind)
            if kind == .structuredJSON, !isStrictOKJSON(text) {
                return AIProviderProbeCapabilityResult(
                    capability: kind.capability,
                    status: .failed,
                    errorCategory: .invalidResponse,
                    durationMilliseconds: duration
                )
            }

            return AIProviderProbeCapabilityResult(
                capability: kind.capability,
                status: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .failed : .succeeded,
                errorCategory: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .invalidResponse : nil,
                durationMilliseconds: duration
            )
        } catch let error as AIProviderProbeHTTPClientError {
            return AIProviderProbeCapabilityResult(
                capability: kind.capability,
                status: .failed,
                errorCategory: error == .timedOut ? .timeout : .networkUnavailable,
                durationMilliseconds: durationMilliseconds(since: startedAt)
            )
        } catch {
            return AIProviderProbeCapabilityResult(
                capability: kind.capability,
                status: .failed,
                errorCategory: .invalidResponse,
                durationMilliseconds: durationMilliseconds(since: startedAt)
            )
        }
    }

    func makeRequest(
        _ kind: ProbeKind,
        endpoint: AIProviderEndpointInput,
        secret: String?
    ) throws -> URLRequest {
        let url = try probeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body(kind, endpoint: endpoint), options: [])
        return request
    }

    func probeURL(for endpoint: AIProviderEndpointInput) throws -> URL {
        guard var components = URLComponents(string: endpoint.baseURL) else {
            throw AIProviderConfigurationError.invalidBaseURL
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = endpoint.adapterKind == .openAIResponses ? "responses" : "chat/completions"
        components.path = "/" + ([basePath, suffix].filter { !$0.isEmpty }.joined(separator: "/"))
        guard let url = components.url else {
            throw AIProviderConfigurationError.invalidBaseURL
        }
        return url
    }

    func body(_ kind: ProbeKind, endpoint: AIProviderEndpointInput) -> [String: Any] {
        switch endpoint.adapterKind {
        case .openAIResponses:
            [
                "model": endpoint.modelName,
                "input": kind.prompt,
            ]
        case .openAICompatibleChat:
            [
                "model": endpoint.modelName,
                "messages": [
                    [
                        "role": "user",
                        "content": kind.prompt,
                    ],
                ],
            ]
        case .anthropicMessages, .geminiGenerateContent:
            [:]
        }
    }

    func parseText(from data: Data, adapterKind: AIProviderAdapterKind) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let object = json as? [String: Any] else {
            throw AIProviderConfigurationError.missingRequiredEndpointField
        }
        switch adapterKind {
        case .openAICompatibleChat:
            return parseChatText(from: object)
        case .openAIResponses:
            return parseResponsesText(from: object)
        case .anthropicMessages, .geminiGenerateContent:
            throw AIProviderConfigurationError.unsupportedCapabilityForProvider
        }
    }

    func parseChatText(from object: [String: Any]) -> String {
        guard let choices = object["choices"] as? [[String: Any]] else {
            return ""
        }
        return choices.compactMap { choice in
            let message = choice["message"] as? [String: Any]
            return message?["content"] as? String
        }.joined(separator: "\n")
    }

    func parseResponsesText(from object: [String: Any]) -> String {
        guard let output = object["output"] as? [[String: Any]] else {
            return ""
        }
        var chunks: [String] = []
        for outputItem in output {
            guard let content = outputItem["content"] as? [[String: Any]] else {
                continue
            }
            for contentItem in content where contentItem["type"] as? String == "output_text" {
                if let text = contentItem["text"] as? String {
                    chunks.append(text)
                }
            }
        }
        return chunks.joined(separator: "\n")
    }

    func isStrictOKJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object.count == 1,
              let ok = object["ok"] as? Bool
        else {
            return false
        }
        return ok == true
    }

    func result(
        endpoint: AIProviderEndpointInput,
        textStatus: AIProviderProbeCapabilityStatus,
        textError: AIProviderValidationErrorCategory?,
        textDuration: Int? = nil,
        jsonStatus: AIProviderProbeCapabilityStatus,
        jsonError: AIProviderValidationErrorCategory?,
        jsonDuration: Int? = nil
    ) -> AIProviderConfigurationProbeResult {
        let overallStatus: AIProviderValidationStatus = textStatus == .succeeded && jsonStatus == .succeeded ? .succeeded : .failed
        return AIProviderConfigurationProbeResult(
            source: .draft,
            overallStatus: overallStatus,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            capabilities: [
                AIProviderProbeCapabilityResult(
                    capability: .textReply,
                    status: textStatus,
                    errorCategory: textError,
                    durationMilliseconds: textDuration
                ),
                AIProviderProbeCapabilityResult(
                    capability: .structuredJSON,
                    status: jsonStatus,
                    errorCategory: jsonError,
                    durationMilliseconds: jsonDuration
                ),
                AIProviderProbeCapabilityResult(
                    capability: .imageUnderstanding,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
                AIProviderProbeCapabilityResult(
                    capability: .speechSynthesis,
                    status: .notEnabled,
                    errorCategory: nil,
                    durationMilliseconds: nil
                ),
                AIProviderProbeCapabilityResult(
                    capability: .embedding,
                    status: .notEnabled,
                    errorCategory: nil,
                    durationMilliseconds: nil
                ),
            ],
            persistedValidationEventID: nil
        )
    }

    func unsupportedResult(endpoint: AIProviderEndpointInput) -> AIProviderConfigurationProbeResult {
        AIProviderConfigurationProbeResult(
            source: .draft,
            overallStatus: .failed,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            capabilities: [
                .init(capability: .textReply, status: .unsupported, errorCategory: .unsupportedEndpointPurpose, durationMilliseconds: nil),
                .init(capability: .structuredJSON, status: .unsupported, errorCategory: .unsupportedEndpointPurpose, durationMilliseconds: nil),
                .init(capability: .imageUnderstanding, status: .unsupported, errorCategory: .unsupportedEndpointPurpose, durationMilliseconds: nil),
                .init(capability: .speechSynthesis, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .embedding, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
            ],
            persistedValidationEventID: nil
        )
    }

    func endpointRequiresCredential(_ endpoint: AIProviderEndpointInput) -> Bool {
        endpoint.providerPresetID != "ollama-local"
    }

    func errorCategory(forHTTPStatusCode statusCode: Int) -> AIProviderValidationErrorCategory {
        switch statusCode {
        case 401, 403:
            .authenticationFailed
        case 404:
            .unsupportedModel
        default:
            .providerRejected
        }
    }

    func durationMilliseconds(since start: Date) -> Int {
        max(0, Int(clock().timeIntervalSince(start) * 1_000))
    }

    func recordCompletion(
        _ result: AIProviderConfigurationProbeResult,
        endpoint: AIProviderEndpointInput,
        operationID: DiagnosticOperationID
    ) async {
        let name: DiagnosticEventName
        let outcome: DiagnosticOutcome
        let level: DiagnosticLevel
        if result.capabilities.contains(where: { $0.status == .unsupported }) &&
            !result.capabilities.contains(where: { $0.status == .succeeded }) {
            name = .aiProviderConfigurationProbeUnsupported
            outcome = .failed
            level = .warning
        } else if result.overallStatus == .succeeded {
            name = .aiProviderConfigurationProbeSucceeded
            outcome = .succeeded
            level = .info
        } else if result.capabilities.contains(where: { $0.status == .succeeded }) {
            name = .aiProviderConfigurationProbePartial
            outcome = .failed
            level = .warning
        } else {
            name = .aiProviderConfigurationProbeFailed
            outcome = .failed
            level = .warning
        }
        await record(
            name,
            outcome: outcome,
            level: level,
            operationID: operationID,
            endpoint: endpoint,
            attributes: result.capabilities.flatMap { capability in
                [
                    DiagnosticAttribute.probeCapability(capability.capability),
                    DiagnosticAttribute.probeCapabilityStatus(capability.status),
                ]
            }
        )
    }

    func record(
        _ name: DiagnosticEventName,
        outcome: DiagnosticOutcome,
        level: DiagnosticLevel,
        operationID: DiagnosticOperationID,
        endpoint: AIProviderEndpointInput,
        attributes: [DiagnosticAttribute] = []
    ) async {
        await diagnosticLogger.record(
            DiagnosticEvent(
                id: UUID().uuidString,
                name: name,
                domain: .aiProviderSettings,
                level: level,
                outcome: outcome,
                attributes: [
                    .operationID(operationID),
                    .providerPresetID(endpoint.providerPresetID),
                    .endpointPurpose(endpoint.purpose),
                    .modelName(endpoint.modelName),
                    .adapterKind(endpoint.adapterKind),
                ] + attributes,
                createdAt: clock()
            )
        )
    }
}
