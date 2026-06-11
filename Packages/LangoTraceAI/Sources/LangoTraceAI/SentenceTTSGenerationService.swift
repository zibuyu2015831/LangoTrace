import Foundation
import LangoTraceCore

public struct SentenceTTSGenerationService: SentenceTTSGenerating {
    private let httpClient: any AIProviderHTTPClient
    private let responseValidator: TTSAudioResponseValidator
    private let stagingWriter: any TTSAudioStagingWriting
    private let maximumResponseBytes: Int

    public init(
        httpClient: any AIProviderHTTPClient,
        responseValidator: TTSAudioResponseValidator,
        stagingWriter: any TTSAudioStagingWriting,
        maximumResponseBytes: Int = 10 * 1024 * 1024
    ) {
        self.httpClient = httpClient
        self.responseValidator = responseValidator
        self.stagingWriter = stagingWriter
        self.maximumResponseBytes = maximumResponseBytes
    }

    public func generateSentenceTTS(
        _ request: SentenceTTSGenerationRequest
    ) async throws -> SentenceTTSGenerationResult {
        try await generateSpeech(request)
    }

    public func generateSpeech(_ request: SentenceTTSGenerationRequest) async throws -> SentenceTTSGenerationResult {
        let startedAt = ContinuousClock.now
        let adapter = try adapter(for: request.playableConfiguration.settings.adapterKind)
        let urlRequest = try adapter.makeRequest(input: TTSProviderAdapterRequestInput(
            endpointID: request.playableConfiguration.endpoint.id,
            baseURL: request.playableConfiguration.endpoint.baseURL,
            modelName: request.playableConfiguration.endpoint.modelName,
            voiceProfile: request.playableConfiguration.voiceProfile,
            plaintextSecret: request.plaintextSecret,
            text: request.audioRequest.targetText,
            requestTimeoutSeconds: request.playableConfiguration.endpoint.requestTimeoutSeconds
        ))

        let httpResponse: AIProviderHTTPResponse
        do {
            httpResponse = try await httpClient.send(urlRequest, maximumResponseBytes: maximumResponseBytes)
        } catch let error as AIProviderHTTPClientError {
            throw playbackFailure(for: error)
        }

        let validation = await responseValidator.validate(
            response: httpResponse,
            declaredFormat: request.artifactKey.outputFormat,
            contentType: httpResponse.contentType
        )
        guard validation.status == .succeeded else {
            throw playbackFailure(for: validation.status)
        }
        let stagedFile = try await stagingWriter.writeTTSAudioToStaging(
            httpResponse.body,
            preferredExtension: request.artifactKey.outputFormat.rawValue
        )
        let elapsedMilliseconds = Self.elapsedMilliseconds(for: startedAt.duration(to: ContinuousClock.now))
        let byteSize = Int64(httpResponse.body.count)
        return SentenceTTSGenerationResult(
            stagedFile: stagedFile,
            mimeType: httpResponse.contentType ?? mimeType(for: request.artifactKey.outputFormat),
            byteSize: byteSize,
            durationSeconds: validation.metadata?.durationSeconds,
            diagnostics: SentenceTTSGenerationDiagnostics(
                providerPresetID: request.playableConfiguration.endpoint.providerPresetID,
                endpointPurpose: request.playableConfiguration.endpoint.purpose,
                modelName: request.playableConfiguration.endpoint.modelName,
                outputFormat: request.artifactKey.outputFormat,
                textLengthBucket: .bucket(for: request.audioRequest.targetText),
                byteSizeBucket: byteSizeBucket(for: byteSize),
                durationBucket: durationBucket(for: validation.metadata?.durationSeconds),
                elapsedMilliseconds: elapsedMilliseconds
            )
        )
    }
}

extension SentenceTTSGenerationService {
    /// Converts a `Duration` to whole milliseconds without truncating
    /// sub-second elapsed time to zero.
    static func elapsedMilliseconds(for duration: Duration) -> Int {
        let components = duration.components
        let milliseconds = components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000
        return max(0, Int(clamping: milliseconds))
    }
}

private extension SentenceTTSGenerationService {
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
            throw SentenceAudioPlaybackFailure.unsupportedProvider
        }
    }

    func playbackFailure(for error: AIProviderHTTPClientError) -> SentenceAudioPlaybackFailure {
        switch error {
        case .cancelled:
            .cancelled
        case .timedOut, .networkUnavailable, .invalidHTTPResponse:
            .networkFailed
        case .responseTooLarge:
            .audioTooLarge
        }
    }

    func playbackFailure(for status: TTSAudioValidationStatus) -> SentenceAudioPlaybackFailure {
        switch status {
        case .succeeded:
            .playbackFailed
        case let .failed(category):
            playbackFailure(for: category)
        }
    }

    func playbackFailure(for category: AIProviderValidationErrorCategory) -> SentenceAudioPlaybackFailure {
        switch category {
        case .authenticationFailed, .missingCredential, .credentialInaccessible:
            .authenticationFailed
        case .rateLimited:
            .rateLimited
        case .quotaExceeded:
            .quotaExceeded
        case .invalidAudioResponse, .audioDecodeFailed, .unsupportedAudioFormat, .invalidResponse:
            .nonAudioResponse
        case .networkUnavailable, .timeout:
            .networkFailed
        case .unsupportedModel, .unsupportedEndpointPurpose, .invalidVoice, .unsupportedLanguage:
            .unsupportedProvider
        case .providerRejected, .invalidEmbeddingResponse:
            .playbackFailed
        }
    }

    func mimeType(for format: TTSAudioFormat) -> String {
        switch format {
        case .mp3:
            "audio/mpeg"
        case .wav:
            "audio/wav"
        case .pcm:
            "audio/L16"
        case .opus:
            "audio/opus"
        case .flac:
            "audio/flac"
        case .aac:
            "audio/aac"
        case .mulaw:
            "audio/basic"
        }
    }

    func byteSizeBucket(for byteSize: Int64) -> SentenceAudioByteSizeBucket {
        switch byteSize {
        case 0:
            .empty
        case 1 ..< 256_000:
            .small
        case 256_000 ..< 2_000_000:
            .medium
        default:
            .large
        }
    }

    func durationBucket(for duration: Double?) -> SentenceAudioDurationBucket {
        guard let duration else {
            return .unknown
        }
        switch duration {
        case 0 ..< 8:
            return .short
        case 8 ..< 60:
            return .medium
        default:
            return .long
        }
    }
}
