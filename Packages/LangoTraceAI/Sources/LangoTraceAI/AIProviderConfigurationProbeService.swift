@preconcurrency import Foundation
import LangoTraceCore

public struct AIProviderConfigurationProbeDraftInput {
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?
    public var languageContext: AIProviderProbeLanguageContext?
    public var operationID: DiagnosticOperationID

    public init(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        languageContext: AIProviderProbeLanguageContext? = nil,
        operationID: DiagnosticOperationID
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
        self.languageContext = languageContext
        self.operationID = operationID
    }
}

public struct AIProviderConfigurationProbeSavedInput {
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?
    public var languageContext: AIProviderProbeLanguageContext?
    public var operationID: DiagnosticOperationID

    public init(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        languageContext: AIProviderProbeLanguageContext? = nil,
        operationID: DiagnosticOperationID
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
        self.languageContext = languageContext
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
        try await probeConfiguration(
            source: .draft,
            endpoint: input.endpoint,
            plaintextSecret: input.plaintextSecret,
            languageContext: input.languageContext,
            operationID: input.operationID
        )
    }

    public func probeSavedConfiguration(
        _ input: AIProviderConfigurationProbeSavedInput
    ) async throws -> AIProviderConfigurationProbeResult {
        try await probeConfiguration(
            source: .savedProfile,
            endpoint: input.endpoint,
            plaintextSecret: input.plaintextSecret,
            languageContext: input.languageContext,
            operationID: input.operationID
        )
    }

    private func probeConfiguration(
        source: AIProviderProbeSource,
        endpoint inputEndpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        languageContext: AIProviderProbeLanguageContext?,
        operationID: DiagnosticOperationID
    ) async throws -> AIProviderConfigurationProbeResult {
        let endpoint = try inputEndpoint.normalized()
        await record(
            .aiProviderConfigurationProbeStarted,
            outcome: .started,
            level: .info,
            operationID: operationID,
            endpoint: endpoint,
            attributes: [
                .probeCapability(.textReply),
                .probeCapability(.structuredJSON),
            ]
        )

        let result: AIProviderConfigurationProbeResult = switch endpoint.adapterKind {
        case .openAICompatibleChat, .openAIResponses:
            await runTextProbes(
                source: source,
                endpoint: endpoint,
                secret: plaintextSecret,
                languageContext: languageContext
            )
        case .anthropicMessages, .geminiGenerateContent:
            unsupportedResult(source: source, endpoint: endpoint)
        }

        await recordCompletion(result, endpoint: endpoint, operationID: operationID)
        return result
    }
}

private extension AIProviderConfigurationProbeService {
    enum ProbeKind {
        case textReply
        case structuredJSON
        case languageSupport(context: AIProviderProbeLanguageContext, prompt: String)
        case imageUnderstanding

        var capability: AIProviderProbeCapability {
            switch self {
            case .textReply:
                .textReply
            case .structuredJSON:
                .structuredJSON
            case .languageSupport:
                .languageSupport
            case .imageUnderstanding:
                .imageUnderstanding
            }
        }

        var prompt: String {
            switch self {
            case .textReply:
                "Configuration test. Reply with OK only."
            case .structuredJSON:
                "Configuration test. Return a single JSON object with exactly one field named ok. " +
                    "The value must be the boolean true. Do not include markdown, code fences, or any other text."
            case let .languageSupport(_, prompt):
                prompt
            case .imageUnderstanding:
                "Describe the image using exactly two lowercase English words: color then shape. " +
                    "Do not include punctuation or any other text."
            }
        }

        var isStructuredJSON: Bool {
            if case .structuredJSON = self {
                return true
            }
            return false
        }

        var isImageUnderstanding: Bool {
            if case .imageUnderstanding = self {
                return true
            }
            return false
        }
    }

    func runTextProbes(
        source: AIProviderProbeSource,
        endpoint: AIProviderEndpointInput,
        secret: String?,
        languageContext: AIProviderProbeLanguageContext?
    ) async -> AIProviderConfigurationProbeResult {
        if endpointRequiresCredential(endpoint), secret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return result(
                source: source,
                endpoint: endpoint,
                textStatus: .failed,
                textError: .missingCredential,
                jsonStatus: .notRun,
                jsonError: nil,
                languageStatus: .notRun,
                languageError: nil,
                imageStatus: .notRun,
                imageError: nil
            )
        }

        let textResult = await runProbe(.textReply, endpoint: endpoint, secret: secret)
        guard textResult.status == .succeeded else {
            return result(
                source: source,
                endpoint: endpoint,
                textStatus: textResult.status,
                textError: textResult.errorCategory,
                textDuration: textResult.durationMilliseconds,
                jsonStatus: .notRun,
                jsonError: nil,
                languageStatus: .notRun,
                languageError: nil,
                imageStatus: .notRun,
                imageError: nil
            )
        }

        let jsonResult = await runProbe(.structuredJSON, endpoint: endpoint, secret: secret)
        let languageResult = await languageSupportProbeResult(
            afterStructuredJSON: jsonResult,
            endpoint: endpoint,
            secret: secret,
            languageContext: languageContext
        )
        let imageResult = await imageProbeResult(afterTextSucceededFor: endpoint, secret: secret)
        return result(
            source: source,
            endpoint: endpoint,
            textStatus: textResult.status,
            textError: textResult.errorCategory,
            textDuration: textResult.durationMilliseconds,
            jsonStatus: jsonResult.status,
            jsonError: jsonResult.errorCategory,
            jsonDuration: jsonResult.durationMilliseconds,
            languageStatus: languageResult.status,
            languageError: languageResult.errorCategory,
            languageDuration: languageResult.durationMilliseconds,
            imageStatus: imageResult.status,
            imageError: imageResult.errorCategory,
            imageDuration: imageResult.durationMilliseconds
        )
    }

    func languageSupportProbeResult(
        afterStructuredJSON jsonResult: AIProviderProbeCapabilityResult,
        endpoint: AIProviderEndpointInput,
        secret: String?,
        languageContext: AIProviderProbeLanguageContext?
    ) async -> AIProviderProbeCapabilityResult {
        guard jsonResult.status == .succeeded else {
            return AIProviderProbeCapabilityResult(
                capability: .languageSupport,
                status: .notRun,
                errorCategory: nil,
                durationMilliseconds: nil
            )
        }
        guard let languageContext,
              let prompt = languageSupportPrompt(languageContext: languageContext)
        else {
            return AIProviderProbeCapabilityResult(
                capability: .languageSupport,
                status: .notConfigured,
                errorCategory: nil,
                durationMilliseconds: nil
            )
        }
        return await runProbe(
            .languageSupport(context: languageContext, prompt: prompt),
            endpoint: endpoint,
            secret: secret
        )
    }

    func imageProbeResult(
        afterTextSucceededFor endpoint: AIProviderEndpointInput,
        secret: String?
    ) async -> AIProviderProbeCapabilityResult {
        guard endpoint.supportsImageInput else {
            return AIProviderProbeCapabilityResult(
                capability: .imageUnderstanding,
                status: .unsupported,
                errorCategory: .unsupportedEndpointPurpose,
                durationMilliseconds: nil
            )
        }
        guard endpoint.imageInputEnabled else {
            return AIProviderProbeCapabilityResult(
                capability: .imageUnderstanding,
                status: .notEnabled,
                errorCategory: nil,
                durationMilliseconds: nil
            )
        }
        guard supportsImageProbe(endpoint.adapterKind) else {
            return AIProviderProbeCapabilityResult(
                capability: .imageUnderstanding,
                status: .unsupported,
                errorCategory: .unsupportedEndpointPurpose,
                durationMilliseconds: nil
            )
        }
        return await runProbe(.imageUnderstanding, endpoint: endpoint, secret: secret)
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
            if kind.isStructuredJSON, !isStrictOKJSON(text) {
                return AIProviderProbeCapabilityResult(
                    capability: kind.capability,
                    status: .failed,
                    errorCategory: .invalidResponse,
                    durationMilliseconds: duration
                )
            }
            if kind.isImageUnderstanding, !isStrictBlueSquare(text) {
                return AIProviderProbeCapabilityResult(
                    capability: kind.capability,
                    status: .failed,
                    errorCategory: .invalidResponse,
                    durationMilliseconds: duration
                )
            }
            if case let .languageSupport(context, _) = kind {
                let validation = AIProviderLanguageSupportValidator().validateResponseText(
                    text,
                    languageContext: context
                )
                guard validation.isValid else {
                    return AIProviderProbeCapabilityResult(
                        capability: kind.capability,
                        status: .failed,
                        errorCategory: validation.errorCategory,
                        durationMilliseconds: duration
                    )
                }
            }

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return AIProviderProbeCapabilityResult(
                    capability: kind.capability,
                    status: .failed,
                    errorCategory: .invalidResponse,
                    durationMilliseconds: duration
                )
            }

            return AIProviderProbeCapabilityResult(
                capability: kind.capability,
                status: .succeeded,
                errorCategory: nil,
                durationMilliseconds: duration
            )
        } catch let error as AIProviderProbeHTTPClientError {
            if error == .cancelled {
                return AIProviderProbeCapabilityResult(
                    capability: kind.capability,
                    status: .cancelled,
                    errorCategory: nil,
                    durationMilliseconds: durationMilliseconds(since: startedAt)
                )
            }
            return AIProviderProbeCapabilityResult(
                capability: kind.capability,
                status: .failed,
                errorCategory: error == .timedOut ? .timeout : .networkUnavailable,
                durationMilliseconds: durationMilliseconds(since: startedAt)
            )
        } catch is CancellationError {
            return AIProviderProbeCapabilityResult(
                capability: kind.capability,
                status: .cancelled,
                errorCategory: nil,
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

    func body(_ kind: ProbeKind, endpoint: AIProviderEndpointInput) throws -> [String: Any] {
        if kind.isImageUnderstanding {
            return try imageBody(endpoint: endpoint)
        }
        switch endpoint.adapterKind {
        case .openAIResponses:
            return [
                "model": endpoint.modelName,
                "input": kind.prompt,
            ]
        case .openAICompatibleChat:
            return [
                "model": endpoint.modelName,
                "messages": [
                    [
                        "role": "user",
                        "content": kind.prompt,
                    ],
                ],
            ]
        case .anthropicMessages, .geminiGenerateContent:
            return [:]
        }
    }

    func imageBody(endpoint: AIProviderEndpointInput) throws -> [String: Any] {
        let fixture = try AIProviderProbeImageFixture.blueSquare()
        switch endpoint.adapterKind {
        case .openAIResponses:
            return [
                "model": endpoint.modelName,
                "input": [
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "input_text",
                                "text": ProbeKind.imageUnderstanding.prompt,
                            ],
                            [
                                "type": "input_image",
                                "image_url": fixture.dataURLString,
                                "detail": "low",
                            ],
                        ],
                    ],
                ],
                "max_output_tokens": 8,
            ]
        case .openAICompatibleChat:
            return [
                "model": endpoint.modelName,
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "text",
                                "text": ProbeKind.imageUnderstanding.prompt,
                            ],
                            [
                                "type": "image_url",
                                "image_url": [
                                    "url": fixture.dataURLString,
                                ],
                            ],
                        ],
                    ],
                ],
                "max_tokens": 8,
            ]
        case .anthropicMessages, .geminiGenerateContent:
            return [:]
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

    func isStrictBlueSquare(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "blue square"
    }

    func languageSupportPrompt(languageContext: AIProviderProbeLanguageContext) -> String? {
        guard let language = LearningLanguage.supportedTargetLanguages.first(where: {
            $0.code == languageContext.languageCode
        }) else {
            return nil
        }
        let targetLanguageName = language.promptLanguageName
        return """
        Configuration test. Generate a natural sample in \(targetLanguageName).
        Return exactly one JSON object with exactly one field named sample.
        The sample must be written only in \(targetLanguageName).
        For Chinese, Japanese, or Korean, write approximately 45 to 80 visible characters.
        For English, French, German, or Spanish, write approximately 40 to 70 words.
        The sample should describe a person recording an ordinary moment from daily life.
        Do not include translation, language names, markdown, code fences, explanations, or any other text.
        """
    }

    func result(
        source: AIProviderProbeSource,
        endpoint: AIProviderEndpointInput,
        textStatus: AIProviderProbeCapabilityStatus,
        textError: AIProviderValidationErrorCategory?,
        textDuration: Int? = nil,
        jsonStatus: AIProviderProbeCapabilityStatus,
        jsonError: AIProviderValidationErrorCategory?,
        jsonDuration: Int? = nil,
        languageStatus: AIProviderProbeCapabilityStatus,
        languageError: AIProviderValidationErrorCategory?,
        languageDuration: Int? = nil,
        imageStatus: AIProviderProbeCapabilityStatus,
        imageError: AIProviderValidationErrorCategory?,
        imageDuration: Int? = nil
    ) -> AIProviderConfigurationProbeResult {
        let overallStatus: AIProviderValidationStatus = if textStatus == .cancelled
            || jsonStatus == .cancelled
            || imageStatus == .cancelled
        {
            .cancelled
        } else {
            textStatus == .succeeded
                && jsonStatus == .succeeded
                && (languageStatus == .succeeded || languageStatus == .notConfigured)
                && (imageStatus == .succeeded || imageStatus == .notEnabled || imageStatus == .unsupported)
                ? .succeeded
                : .failed
        }
        return AIProviderConfigurationProbeResult(
            source: source,
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
                    capability: .languageSupport,
                    status: languageStatus,
                    errorCategory: languageError,
                    durationMilliseconds: languageDuration
                ),
                AIProviderProbeCapabilityResult(
                    capability: .imageUnderstanding,
                    status: imageStatus,
                    errorCategory: imageError,
                    durationMilliseconds: imageDuration
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

    func unsupportedResult(source: AIProviderProbeSource, endpoint: AIProviderEndpointInput) -> AIProviderConfigurationProbeResult {
        AIProviderConfigurationProbeResult(
            source: source,
            overallStatus: .failed,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            capabilities: [
                .init(capability: .textReply, status: .unsupported, errorCategory: .unsupportedEndpointPurpose, durationMilliseconds: nil),
                .init(capability: .structuredJSON, status: .unsupported, errorCategory: .unsupportedEndpointPurpose, durationMilliseconds: nil),
                .init(capability: .languageSupport, status: .unsupported, errorCategory: .unsupportedEndpointPurpose, durationMilliseconds: nil),
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

    func supportsImageProbe(_ adapterKind: AIProviderAdapterKind) -> Bool {
        adapterKind == .openAIResponses || adapterKind == .openAICompatibleChat
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
        max(0, Int(clock().timeIntervalSince(start) * 1000))
    }

    func recordCompletion(
        _ result: AIProviderConfigurationProbeResult,
        endpoint: AIProviderEndpointInput,
        operationID: DiagnosticOperationID
    ) async {
        let name: DiagnosticEventName
        let outcome: DiagnosticOutcome
        let level: DiagnosticLevel
        if result.overallStatus == .cancelled {
            name = .aiProviderConfigurationProbeCancelled
            outcome = .cancelled
            level = .info
        } else if result.capabilities.contains(where: { $0.status == .unsupported }),
                  !result.capabilities.contains(where: { $0.status == .succeeded })
        {
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
