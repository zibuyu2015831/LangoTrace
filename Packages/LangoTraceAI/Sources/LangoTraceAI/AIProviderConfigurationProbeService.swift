@preconcurrency import Foundation
import LangoTraceCore

public struct AIProviderConfigurationProbeDraftInput {
    public var endpoint: AIProviderEndpointInput?
    public var plaintextSecret: String?
    public var ttsEndpoint: AIProviderEndpointInput?
    public var ttsSettings: TTSProviderSettings?
    public var ttsVoiceProfile: TTSVoiceProfile?
    public var ttsPlaintextSecret: String?
    public var embeddingEndpoint: AIProviderEndpointInput?
    public var embeddingPlaintextSecret: String?
    public var languageContext: AIProviderProbeLanguageContext?
    public var operationID: DiagnosticOperationID

    public init(
        endpoint: AIProviderEndpointInput?,
        plaintextSecret: String?,
        ttsEndpoint: AIProviderEndpointInput? = nil,
        ttsSettings: TTSProviderSettings? = nil,
        ttsVoiceProfile: TTSVoiceProfile? = nil,
        ttsPlaintextSecret: String? = nil,
        embeddingEndpoint: AIProviderEndpointInput? = nil,
        embeddingPlaintextSecret: String? = nil,
        languageContext: AIProviderProbeLanguageContext? = nil,
        operationID: DiagnosticOperationID
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
        self.ttsEndpoint = ttsEndpoint
        self.ttsSettings = ttsSettings
        self.ttsVoiceProfile = ttsVoiceProfile
        self.ttsPlaintextSecret = ttsPlaintextSecret
        self.embeddingEndpoint = embeddingEndpoint
        self.embeddingPlaintextSecret = embeddingPlaintextSecret
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
        guard let endpoint = input.endpoint else {
            let representative = input.embeddingEndpoint ?? input.ttsEndpoint
            return AIProviderConfigurationProbeResult(
                source: .draft,
                overallStatus: .succeeded,
                providerPresetID: representative?.providerPresetID ?? "",
                modelName: representative?.modelName ?? "",
                capabilities: [
                    .init(capability: .textReply, status: .notConfigured, errorCategory: nil, durationMilliseconds: nil),
                    .init(capability: .structuredJSON, status: .notConfigured, errorCategory: nil, durationMilliseconds: nil),
                    .init(capability: .languageSupport, status: .notConfigured, errorCategory: nil, durationMilliseconds: nil),
                    .init(capability: .imageUnderstanding, status: .notConfigured, errorCategory: nil, durationMilliseconds: nil),
                    .init(capability: .speechSynthesis, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                    .init(capability: .embedding, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                ],
                persistedValidationEventID: nil
            )
        }
        return try await probeConfiguration(
            source: .draft,
            endpoint: endpoint,
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

        // Single dispatch point: a kind without a text-provider adapter
        // yields the unsupported capability result (no closed-set kind hits
        // this today; it guards future kinds).
        let adapter: any AIProviderTextRequestAdapter
        do {
            adapter = try AIProviderTextRequestAdapterFactory.adapter(for: endpoint.adapterKind)
        } catch {
            let unsupported = unsupportedResult(source: source, endpoint: endpoint)
            await recordCompletion(unsupported, endpoint: endpoint, operationID: operationID)
            return unsupported
        }

        let result = await runTextProbes(
            source: source,
            endpoint: endpoint,
            secret: plaintextSecret,
            languageContext: languageContext,
            adapter: adapter
        )

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

    struct ProbeAggregate {
        var text: AIProviderProbeCapabilityResult
        var json: AIProviderProbeCapabilityResult
        var language: AIProviderProbeCapabilityResult
        var image: AIProviderProbeCapabilityResult
    }

    func runTextProbes(
        source: AIProviderProbeSource,
        endpoint: AIProviderEndpointInput,
        secret: String?,
        languageContext: AIProviderProbeLanguageContext?,
        adapter: any AIProviderTextRequestAdapter
    ) async -> AIProviderConfigurationProbeResult {
        if endpointRequiresCredential(endpoint), secret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return result(
                source: source,
                endpoint: endpoint,
                aggregate: ProbeAggregate(
                    text: .init(
                        capability: .textReply,
                        status: .failed,
                        errorCategory: .missingCredential,
                        durationMilliseconds: nil
                    ),
                    json: .init(
                        capability: .structuredJSON,
                        status: .notRun,
                        errorCategory: nil,
                        durationMilliseconds: nil
                    ),
                    language: .init(
                        capability: .languageSupport,
                        status: .notRun,
                        errorCategory: nil,
                        durationMilliseconds: nil
                    ),
                    image: .init(
                        capability: .imageUnderstanding,
                        status: .notRun,
                        errorCategory: nil,
                        durationMilliseconds: nil
                    )
                )
            )
        }

        let textResult = await runProbe(.textReply, endpoint: endpoint, secret: secret, adapter: adapter)
        guard textResult.status == .succeeded else {
            return result(
                source: source,
                endpoint: endpoint,
                aggregate: ProbeAggregate(
                    text: textResult,
                    json: .init(
                        capability: .structuredJSON,
                        status: .notRun,
                        errorCategory: nil,
                        durationMilliseconds: nil
                    ),
                    language: .init(
                        capability: .languageSupport,
                        status: .notRun,
                        errorCategory: nil,
                        durationMilliseconds: nil
                    ),
                    image: .init(
                        capability: .imageUnderstanding,
                        status: .notRun,
                        errorCategory: nil,
                        durationMilliseconds: nil
                    )
                )
            )
        }

        let jsonResult = await runProbe(.structuredJSON, endpoint: endpoint, secret: secret, adapter: adapter)
        let languageResult = await languageSupportProbeResult(
            afterStructuredJSON: jsonResult,
            endpoint: endpoint,
            secret: secret,
            languageContext: languageContext,
            adapter: adapter
        )
        let imageResult = await imageProbeResult(afterTextSucceededFor: endpoint, secret: secret, adapter: adapter)
        return result(
            source: source,
            endpoint: endpoint,
            aggregate: ProbeAggregate(
                text: textResult,
                json: jsonResult,
                language: languageResult,
                image: imageResult
            )
        )
    }

    func languageSupportProbeResult(
        afterStructuredJSON jsonResult: AIProviderProbeCapabilityResult,
        endpoint: AIProviderEndpointInput,
        secret: String?,
        languageContext: AIProviderProbeLanguageContext?,
        adapter: any AIProviderTextRequestAdapter
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
            secret: secret,
            adapter: adapter
        )
    }

    func imageProbeResult(
        afterTextSucceededFor endpoint: AIProviderEndpointInput,
        secret: String?,
        adapter: any AIProviderTextRequestAdapter
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
        return await runProbe(.imageUnderstanding, endpoint: endpoint, secret: secret, adapter: adapter)
    }

    func runProbe(
        _ kind: ProbeKind,
        endpoint: AIProviderEndpointInput,
        secret: String?,
        adapter: any AIProviderTextRequestAdapter
    ) async -> AIProviderProbeCapabilityResult {
        let startedAt = clock()
        do {
            let request = try makeRequest(kind, endpoint: endpoint, secret: secret, adapter: adapter)
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

            let text = try adapter.extractText(fromResponseBody: response.body)
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
                        durationMilliseconds: duration,
                        languageSupportFailureReason: validation.failureReason?.rawValue
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
        secret: String?,
        adapter: any AIProviderTextRequestAdapter
    ) throws -> URLRequest {
        let body: [String: Any]
        if kind.isImageUnderstanding {
            let fixture = try AIProviderProbeImageFixture.blueSquare()
            body = adapter.imagePromptBody(
                model: endpoint.modelName,
                prompt: ProbeKind.imageUnderstanding.prompt,
                imageDataURL: fixture.dataURLString,
                maximumOutputTokens: 8
            )
        } else {
            body = adapter.plainPromptBody(model: endpoint.modelName, prompt: kind.prompt)
        }
        do {
            return try adapter.makeRequest(
                baseURL: endpoint.baseURL,
                secret: secret,
                timeoutSeconds: endpoint.requestTimeoutSeconds,
                model: endpoint.modelName,
                streaming: false,
                body: body
            )
        } catch AIProviderTextRequestAdapterError.invalidEndpointURL {
            throw AIProviderConfigurationError.invalidBaseURL
        }
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
        For Chinese, Japanese, or Korean, write at least 60 visible characters.
        For English, French, German, or Spanish, write at least 50 words.
        The sample should describe a person recording an ordinary moment from daily life in detail.
        Do not include translation, language names, markdown, code fences, explanations, or any other text.
        """
    }

    func result(
        source: AIProviderProbeSource,
        endpoint: AIProviderEndpointInput,
        aggregate: ProbeAggregate
    ) -> AIProviderConfigurationProbeResult {
        let overallStatus: AIProviderValidationStatus = if aggregate.text.status == .cancelled
            || aggregate.json.status == .cancelled
            || aggregate.language.status == .cancelled
            || aggregate.image.status == .cancelled
        {
            .cancelled
        } else {
            aggregate.text.status == .succeeded
                && aggregate.json.status == .succeeded
                && (aggregate.language.status == .succeeded || aggregate.language.status == .notConfigured)
                && (
                    aggregate.image.status == .succeeded
                        || aggregate.image.status == .notEnabled
                        || aggregate.image.status == .unsupported
                )
                ? .succeeded
                : .failed
        }
        return AIProviderConfigurationProbeResult(
            source: source,
            overallStatus: overallStatus,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            capabilities: [
                aggregate.text,
                aggregate.json,
                aggregate.language,
                aggregate.image,
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
                .init(
                    capability: .textReply,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
                .init(
                    capability: .structuredJSON,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
                .init(
                    capability: .languageSupport,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
                .init(
                    capability: .imageUnderstanding,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
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
        // Shared with photo-writing assist via the single allowlist so the probe
        // and the real image request can never diverge (self-review P1-6).
        AIProviderImageSupport.supportsInlineImage(adapterKind)
    }

    func errorCategory(forHTTPStatusCode statusCode: Int) -> AIProviderValidationErrorCategory {
        AIProviderHTTPStatusErrorMapper.errorCategory(forHTTPStatusCode: statusCode)
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
                var attributes = [
                    DiagnosticAttribute.probeCapability(capability.capability),
                    DiagnosticAttribute.probeCapabilityStatus(capability.status),
                ]
                if let errorCategory = capability.errorCategory {
                    attributes.append(
                        .errorCategory("\(capability.capability.rawValue):\(errorCategory.rawValue)")
                    )
                }
                if capability.capability == .languageSupport,
                   let failureReason = capability.languageSupportFailureReason
                {
                    attributes.append(.languageSupportFailureReason(failureReason))
                }
                return attributes
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
