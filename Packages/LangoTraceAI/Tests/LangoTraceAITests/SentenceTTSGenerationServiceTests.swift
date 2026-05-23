import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Sentence TTS generation service")
struct SentenceTTSGenerationServiceTests {
    @Test("OpenAI generation sends speech request with short lived secret and writes staging")
    func openAIGenerationWritesValidatedAudioToStaging() async throws {
        let httpClient = CapturingAIProviderHTTPClient(response: AIProviderHTTPResponse(
            statusCode: 200,
            body: Data([0x49, 0x44, 0x33, 0x04]),
            contentType: "audio/mpeg"
        ))
        let stagingWriter = CapturingTTSStagingWriter()
        let service = SentenceTTSGenerationService(
            httpClient: httpClient,
            responseValidator: TTSAudioResponseValidator(audioValidationService: AcceptingAudioValidationService()),
            stagingWriter: stagingWriter,
            maximumResponseBytes: 128
        )
        let request = try generationRequest(text: "My private sentence should not appear in diagnostics.")

        let result = try await service.generateSpeech(request)

        let sentRequest = try await #require(httpClient.lastRequest)
        #expect(sentRequest.value(forHTTPHeaderField: "Authorization") == "Bearer sk-short-lived")
        #expect(sentRequest.url?.absoluteString == "https://api.openai.com/v1/audio/speech")
        #expect(await stagingWriter.writes.count == 1)
        #expect(result.stagedFile.relativeStagingPath == "staging/tts-1.mp3")
        #expect(result.mimeType == "audio/mpeg")
        #expect(result.byteSize == 4)
        #expect(result.durationSeconds == 0.4)
        #expect(result.diagnostics.textLengthBucket == .short)
        #expect(!result.diagnostics.description.contains("private sentence"))
    }

    @Test("Generation maps provider failures and does not write staging")
    func generationMapsProviderFailuresWithoutWritingStaging() async throws {
        let httpClient = CapturingAIProviderHTTPClient(response: AIProviderHTTPResponse(
            statusCode: 429,
            body: Data(#"{"error":"quota exceeded"}"#.utf8),
            contentType: "application/json"
        ))
        let stagingWriter = CapturingTTSStagingWriter()
        let service = SentenceTTSGenerationService(
            httpClient: httpClient,
            responseValidator: TTSAudioResponseValidator(audioValidationService: AcceptingAudioValidationService()),
            stagingWriter: stagingWriter,
            maximumResponseBytes: 128
        )

        await #expect(throws: SentenceAudioPlaybackFailure.quotaExceeded) {
            _ = try await service.generateSpeech(try generationRequest(text: "Hello"))
        }
        #expect(await stagingWriter.writes.isEmpty)
    }

    @Test("Generation maps cancellation and does not write staging")
    func generationMapsCancellationWithoutWritingStaging() async throws {
        let httpClient = CapturingAIProviderHTTPClient(error: AIProviderHTTPClientError.cancelled)
        let stagingWriter = CapturingTTSStagingWriter()
        let service = SentenceTTSGenerationService(
            httpClient: httpClient,
            responseValidator: TTSAudioResponseValidator(audioValidationService: AcceptingAudioValidationService()),
            stagingWriter: stagingWriter,
            maximumResponseBytes: 128
        )

        await #expect(throws: SentenceAudioPlaybackFailure.cancelled) {
            _ = try await service.generateSpeech(try generationRequest(text: "Hello"))
        }
        #expect(await stagingWriter.writes.isEmpty)
    }
}

private actor CapturingAIProviderHTTPClient: AIProviderHTTPClient {
    private let response: AIProviderHTTPResponse?
    private let error: AIProviderHTTPClientError?
    private(set) var lastRequest: URLRequest?
    private(set) var maximumResponseBytes: Int?

    init(response: AIProviderHTTPResponse) {
        self.response = response
        error = nil
    }

    init(error: AIProviderHTTPClientError) {
        response = nil
        self.error = error
    }

    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> AIProviderHTTPResponse {
        lastRequest = request
        self.maximumResponseBytes = maximumResponseBytes
        if let error {
            throw error
        }
        return try #require(response)
    }
}

private actor CapturingTTSStagingWriter: TTSAudioStagingWriting {
    private(set) var writes: [(data: Data, preferredExtension: String)] = []

    func writeTTSAudioToStaging(
        _ data: Data,
        preferredExtension: String
    ) async throws -> MediaArtifactStagedFileReference {
        writes.append((data, preferredExtension))
        return MediaArtifactStagedFileReference(
            relativeStagingPath: "staging/tts-1.\(preferredExtension)",
            byteSize: Int64(data.count),
            contentHash: String(repeating: "c", count: 64)
        )
    }
}

private struct AcceptingAudioValidationService: TTSAudioValidationService {
    func validateAudio(
        _ data: Data,
        declaredFormat: TTSAudioFormat,
        contentType _: String?,
        previewPolicy _: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        TTSAudioValidationResult(
            status: .succeeded,
            metadata: TTSAudioMetadata(
                format: declaredFormat,
                byteCount: data.count,
                durationSeconds: 0.4,
                sampleRate: nil
            ),
            previewResource: nil
        )
    }
}

private func generationRequest(text: String) throws -> SentenceTTSGenerationRequest {
    let endpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-tts",
            profileID: "profile-1",
            purpose: .tts,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-4o-mini-tts",
            credentialID: "credential-1",
            supportsImageInput: false,
            imageInputEnabled: false,
            requestTimeoutSeconds: 30
        ),
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    let voiceProfile = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3,
        lastSuccessfulConfigurationFingerprint: nil,
        lastTestStatus: .succeeded
    )
    let configuration = PlayableTTSConfiguration(
        endpoint: endpoint,
        settings: TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
        voiceProfile: voiceProfile
    )
    let audioRequest = SentenceAudioRequest(
        languageSpaceID: "space-1",
        owner: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        sentenceSource: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        sentenceIndex: 0,
        targetText: text,
        targetLanguageCode: "en"
    )
    return SentenceTTSGenerationRequest(
        audioRequest: audioRequest,
        artifactKey: TTSAudioArtifactKey(
            sentenceSource: audioRequest.sentenceSource,
            sentenceTextHash: "sentence-hash",
            targetLanguageCode: "en",
            providerProfileID: "profile-1",
            ttsEndpointID: "endpoint-tts",
            ttsVoiceProfileID: "voice-en",
            adapterKind: TTSProviderAdapterKind.openAIAudioSpeech.rawValue,
            adapterVersion: "v1",
            modelName: "gpt-4o-mini-tts",
            voiceIDHash: "voice-hash",
            outputFormat: .mp3,
            sampleRate: nil,
            speed: nil,
            pitch: nil,
            volume: nil,
            instructionsHash: nil,
            providerParametersHash: nil,
            configurationFingerprint: voiceProfile.configurationFingerprint
        ),
        playableConfiguration: configuration,
        plaintextSecret: "sk-short-lived"
    )
}
