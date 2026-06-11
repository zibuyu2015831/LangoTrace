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
            text: request.audioRequest.targetText
        ))

        let httpResponse: AIProviderHTTPResponse
        do {
            httpResponse = try await httpClient.send(urlRequest, maximumResponseBytes: maximumResponseBytes)
        } catch let error as AIProviderHTTPClientError {
            throw playbackFailure(for: error)
        }

        let decodedBody: Data
        if (200 ... 299).contains(httpResponse.statusCode) {
            do {
                decodedBody = try adapter.decodeAudio(from: httpResponse.body)
            } catch {
                throw playbackFailure(for: .invalidAudioResponse)
            }
        } else {
            decodedBody = httpResponse.body
        }

        let validationContentType: String?
        if (200 ... 299).contains(httpResponse.statusCode),
           let originalContentType = httpResponse.contentType,
           !originalContentType.lowercased().contains("audio") {
            validationContentType = nil
        } else {
            validationContentType = httpResponse.contentType
        }

        let actualAudioFormat = adapter.decodedAudioFormat(for: request.playableConfiguration.voiceProfile)
        let validation = await responseValidator.validate(
            response: AIProviderHTTPResponse(
                statusCode: httpResponse.statusCode,
                body: decodedBody,
                contentType: httpResponse.contentType
            ),
            declaredFormat: actualAudioFormat,
            contentType: validationContentType
        )
        guard validation.status == .succeeded else {
            throw playbackFailure(for: validation.status)
        }
        let stagedFile = try await stagingWriter.writeTTSAudioToStaging(
            decodedBody,
            preferredExtension: actualAudioFormat.rawValue
        )
        let elapsedMilliseconds = Int(startedAt.duration(to: ContinuousClock.now).components.seconds * 1000)
        let byteSize = Int64(decodedBody.count)
        return SentenceTTSGenerationResult(
            stagedFile: stagedFile,
            mimeType: httpResponse.contentType ?? mimeType(for: actualAudioFormat),
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
                elapsedMilliseconds: max(elapsedMilliseconds, 0)
            )
        )
    }
}

private extension SentenceTTSGenerationService {
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
