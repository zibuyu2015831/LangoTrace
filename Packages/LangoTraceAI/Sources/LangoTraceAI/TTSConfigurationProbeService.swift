@preconcurrency import Foundation
import LangoTraceCore

private let maxTTSProbeAudioResponseBytes = 2 * 1024 * 1024

public struct TTSDraftProbeInput: Sendable {
    public var endpoint: AIProviderEndpointInput
    public var settings: TTSProviderSettings
    public var voiceProfile: TTSVoiceProfile
    public var plaintextSecret: String?

    public init(
        endpoint: AIProviderEndpointInput,
        settings: TTSProviderSettings,
        voiceProfile: TTSVoiceProfile,
        plaintextSecret: String?
    ) {
        self.endpoint = endpoint
        self.settings = settings
        self.voiceProfile = voiceProfile
        self.plaintextSecret = plaintextSecret
    }
}

public struct TTSConfigurationProbeService: Sendable {
    private let httpClient: any AIProviderProbeHTTPClient
    private let responseValidator: TTSAudioResponseValidator
    private let clock: @Sendable () -> Date

    public init(
        httpClient: any AIProviderProbeHTTPClient,
        audioValidationService: any TTSAudioValidationService,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        responseValidator = TTSAudioResponseValidator(audioValidationService: audioValidationService)
        self.clock = clock
    }

    public func probeDraftTTSConfiguration(
        _ input: TTSDraftProbeInput
    ) async -> AIProviderProbeCapabilityResult {
        await probe(
            endpoint: input.endpoint,
            settings: input.settings,
            voiceProfile: input.voiceProfile,
            plaintextSecret: input.plaintextSecret
        )
    }
}

private extension TTSConfigurationProbeService {
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
                    text: fixedTestText(languageCode: voiceProfile.languageCode)
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
            let validation = await responseValidator.validate(
                response: response,
                declaredFormat: voiceProfile.outputFormat,
                contentType: response.contentType
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

    func adapter(for kind: TTSProviderAdapterKind) throws -> any TTSProviderAdapter {
        switch kind {
        case .openAIAudioSpeech:
            OpenAIAudioSpeechAdapter()
        case .openRouterAudioSpeech:
            OpenRouterAudioSpeechAdapter()
        case .groqAudioSpeech,
             .customOpenAICompatibleAudioSpeech,
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
