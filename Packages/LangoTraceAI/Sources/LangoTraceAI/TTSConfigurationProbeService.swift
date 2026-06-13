@preconcurrency import Foundation
import LangoTraceCore

private let maxTTSProbeAudioResponseBytes = 2 * 1024 * 1024

public struct TTSDraftProbeInput: Sendable {
    public var endpoint: AIProviderEndpointInput
    public var settings: TTSProviderSettings
    public var voiceProfile: TTSVoiceProfile
    public var plaintextSecret: String?
    public var operationID: DiagnosticOperationID

    public init(
        endpoint: AIProviderEndpointInput,
        settings: TTSProviderSettings,
        voiceProfile: TTSVoiceProfile,
        plaintextSecret: String?,
        operationID: DiagnosticOperationID
    ) {
        self.endpoint = endpoint
        self.settings = settings
        self.voiceProfile = voiceProfile
        self.plaintextSecret = plaintextSecret
        self.operationID = operationID
    }
}

public struct TTSConfigurationProbeService: Sendable {
    private let httpClient: any AIProviderProbeHTTPClient
    private let responseValidator: TTSAudioResponseValidator
    private let diagnosticLogger: any DiagnosticLogging
    private let clock: @Sendable () -> Date

    public init(
        httpClient: any AIProviderProbeHTTPClient,
        audioValidationService: any TTSAudioValidationService,
        diagnosticLogger: any DiagnosticLogging,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        responseValidator = TTSAudioResponseValidator(audioValidationService: audioValidationService)
        self.diagnosticLogger = diagnosticLogger
        self.clock = clock
    }

    public func probeDraftTTSConfiguration(
        _ input: TTSDraftProbeInput
    ) async -> AIProviderProbeCapabilityResult {
        let result = await probe(
            endpoint: input.endpoint,
            settings: input.settings,
            voiceProfile: input.voiceProfile,
            plaintextSecret: input.plaintextSecret
        )
        await recordCompletion(result, endpoint: input.endpoint, operationID: input.operationID)
        return result
    }
}

private extension TTSConfigurationProbeService {
    func recordCompletion(
        _ result: AIProviderProbeCapabilityResult,
        endpoint: AIProviderEndpointInput,
        operationID: DiagnosticOperationID
    ) async {
        let eventName: DiagnosticEventName = if result.status == .succeeded {
            .aiProviderConfigurationProbeSucceeded
        } else {
            .aiProviderConfigurationProbeFailed
        }

        await diagnosticLogger.record(
            DiagnosticEvent(
                id: UUID().uuidString,
                name: eventName,
                domain: .aiProviderSettings,
                level: result.status == .succeeded ? .info : .warning,
                outcome: result.status == .succeeded ? .succeeded : .failed,
                attributes: [
                    .operationID(operationID),
                    .providerPresetID(endpoint.providerPresetID),
                    .endpointPurpose(.tts),
                    .modelName(endpoint.modelName),
                    .adapterKind(endpoint.adapterKind),
                    .probeCapability(.speechSynthesis),
                    .probeCapabilityStatus(result.status),
                ] + (result.errorCategory.map { [.errorCategory($0.rawValue)] } ?? [])
                    + (result.durationMilliseconds.map { [.durationMilliseconds($0)] } ?? []),
                createdAt: clock()
            )
        )
    }

    func probe(
        endpoint inputEndpoint: AIProviderEndpointInput,
        settings: TTSProviderSettings,
        voiceProfile: TTSVoiceProfile,
        plaintextSecret: String?
    ) async -> AIProviderProbeCapabilityResult {
        let startedAt = clock()
        let metadata = AIProviderEndpointProbeMetadata(
            endpointID: inputEndpoint.id,
            endpointPurpose: .tts,
            providerPresetID: inputEndpoint.providerPresetID,
            modelName: inputEndpoint.modelName,
            configurationFingerprint: voiceProfile.configurationFingerprint
        )
        guard plaintextSecret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return AIProviderProbeCapabilityResult(
                capability: .speechSynthesis,
                status: .failed,
                errorCategory: .missingCredential,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        }

        do {
            let endpoint = try inputEndpoint.normalized()
            let adapter = try adapter(for: settings.adapterKind)
            let request = try adapter.makeRequest(
                input: TTSProviderAdapterRequestInput(
                    endpointID: endpoint.id,
                    baseURL: endpoint.baseURL,
                    modelName: endpoint.modelName,
                    voiceProfile: voiceProfile,
                    plaintextSecret: plaintextSecret,
                    text: fixedTestText(languageCode: voiceProfile.languageCode),
                    requestTimeoutSeconds: endpoint.requestTimeoutSeconds
                )
            )
            let response = try await httpClient.send(request)
            guard response.body.count <= maxTTSProbeAudioResponseBytes else {
                return AIProviderProbeCapabilityResult(
                    capability: .speechSynthesis,
                    status: .failed,
                    errorCategory: .invalidAudioResponse,
                    durationMilliseconds: durationMilliseconds(since: startedAt),
                    endpointMetadata: metadata
                )
            }
            let decodedBody: Data
            let isSuccess = (200 ... 299).contains(response.statusCode)
            if isSuccess {
                do {
                    decodedBody = try adapter.decodeAudio(from: response.body)
                } catch {
                    return AIProviderProbeCapabilityResult(
                        capability: .speechSynthesis,
                        status: .failed,
                        errorCategory: .invalidAudioResponse,
                        durationMilliseconds: durationMilliseconds(since: startedAt),
                        endpointMetadata: metadata
                    )
                }
            } else {
                decodedBody = response.body
            }

            return await validatedProbeResult(
                response: response,
                decodedBody: decodedBody,
                isSuccess: isSuccess,
                adapter: adapter,
                voiceProfile: voiceProfile,
                startedAt: startedAt,
                metadata: metadata
            )
        } catch let error as AIProviderProbeHTTPClientError {
            if error == .cancelled {
                return AIProviderProbeCapabilityResult(
                    capability: .speechSynthesis,
                    status: .cancelled,
                    errorCategory: nil,
                    durationMilliseconds: durationMilliseconds(since: startedAt),
                    endpointMetadata: metadata
                )
            }
            return AIProviderProbeCapabilityResult(
                capability: .speechSynthesis,
                status: .failed,
                errorCategory: error == .timedOut ? .timeout : .networkUnavailable,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        } catch {
            return AIProviderProbeCapabilityResult(
                capability: .speechSynthesis,
                status: .failed,
                errorCategory: .invalidAudioResponse,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        }
    }

    private func validatedProbeResult(
        response: AIProviderProbeHTTPResponse,
        decodedBody: Data,
        isSuccess: Bool,
        adapter: any TTSProviderAdapter,
        voiceProfile: TTSVoiceProfile,
        startedAt: Date,
        metadata: AIProviderEndpointProbeMetadata
    ) async -> AIProviderProbeCapabilityResult {
        let validationContentType: String? = if isSuccess, let originalContentType = response.contentType, !originalContentType.lowercased().contains("audio") {
            nil
        } else {
            response.contentType
        }

        let validation = await responseValidator.validate(
            response: AIProviderProbeHTTPResponse(
                statusCode: response.statusCode,
                body: decodedBody,
                contentType: response.contentType
            ),
            declaredFormat: adapter.decodedAudioFormat(for: voiceProfile),
            contentType: validationContentType
        )
        switch validation.status {
        case .succeeded:
            return AIProviderProbeCapabilityResult(
                capability: .speechSynthesis,
                status: .succeeded,
                errorCategory: nil,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata,
                audioMetadata: validation.metadata,
                audioPreviewResource: validation.previewResource
            )
        case let .failed(category):
            return AIProviderProbeCapabilityResult(
                capability: .speechSynthesis,
                status: .failed,
                errorCategory: category,
                durationMilliseconds: durationMilliseconds(since: startedAt),
                endpointMetadata: metadata
            )
        }
    }

    func adapter(for kind: TTSProviderAdapterKind) throws -> any TTSProviderAdapter {
        switch kind {
        case .openAIAudioSpeech:
            OpenAIAudioSpeechAdapter()
        case .openAIMultimodalAudio:
            OpenAIMultimodalAudioSpeechAdapter()
        case .openRouterAudioSpeech:
            OpenRouterAudioSpeechAdapter()
        case .openRouterMultimodalAudio:
            OpenRouterMultimodalAudioSpeechAdapter()
        case .customOpenAICompatibleAudioSpeech:
            CustomOpenAICompatibleAudioSpeechAdapter()
        case .groqAudioSpeech,
             .geminiGenerateContentTTS,
             .mistralAudioSpeech,
             .xAITTS,
             .dashScopeCosyVoice,
             .zhipuGLMTTS,
             .siliconFlowAudioSpeech:
            throw AIProviderConfigurationError.unsupportedCapabilityForProvider
        }
    }

    func fixedTestText(languageCode: String) -> String {
        switch languageCode {
        case "zh-Hans":
            "今天我写了一句很短的话。"
        case "ja":
            "今日は短い文を一つ書きました。"
        case "ko":
            "오늘 짧은 문장을 하나 썼습니다."
        default:
            "Today I wrote one short sentence for practice."
        }
    }

    func durationMilliseconds(since start: Date) -> Int {
        max(0, Int(clock().timeIntervalSince(start) * 1000))
    }
}
