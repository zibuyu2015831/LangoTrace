import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Test("Draft TTS probe sends current language fixed text and returns endpoint metadata")
func draftTTSProbeSendsCurrentLanguageFixedTextAndReturnsEndpointMetadata() async throws {
    let httpClient = CapturingTTSProbeHTTPClient(
        responses: [
            AIProviderProbeHTTPResponse(
                statusCode: 200,
                body: Data([0x49, 0x44, 0x33, 0x04]),
                contentType: "audio/mpeg"
            ),
        ]
    )
    let audioValidation = AcceptingTTSAudioValidationService()
    let service = TTSConfigurationProbeService(
        httpClient: httpClient,
        audioValidationService: audioValidation,
        clock: { Date(timeIntervalSince1970: 1000) }
    )
    let voiceProfile = try makeVoiceProfile(languageCode: "ja")

    let result = await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: voiceProfile,
            plaintextSecret: "sk-test"
        )
    )

    #expect(result.status == .succeeded)
    #expect(result.endpointMetadata?.endpointID == "tts-endpoint")
    #expect(result.endpointMetadata?.endpointPurpose == .tts)
    #expect(result.endpointMetadata?.providerPresetID == "openai")
    #expect(result.endpointMetadata?.modelName == "gpt-4o-mini-tts")
    #expect(result.endpointMetadata?.configurationFingerprint == voiceProfile.configurationFingerprint)

    let requests = await httpClient.requests
    #expect(requests.count == 1)
    #expect(requests[0].url?.absoluteString == "https://api.openai.com/v1/audio/speech")
    #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    let body = try #require(String(data: requests[0].httpBody ?? Data(), encoding: .utf8))
    #expect(body.contains("今日は短い文を一つ書きました。"))
    #expect(!body.contains("life record"))
    #expect(!body.contains("Prompt Preset"))
}

@Test("Draft TTS probe maps missing credential without sending HTTP")
func draftTTSProbeMapsMissingCredentialWithoutSendingHTTP() async throws {
    let httpClient = CapturingTTSProbeHTTPClient(responses: [])
    let service = TTSConfigurationProbeService(
        httpClient: httpClient,
        audioValidationService: AcceptingTTSAudioValidationService()
    )

    let result = try await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: makeVoiceProfile(languageCode: "en"),
            plaintextSecret: nil
        )
    )

    #expect(result.status == .failed)
    #expect(result.errorCategory == .missingCredential)
    #expect(await httpClient.requests.isEmpty)
}

@Test("Draft TTS probe delegates audio validation failures")
func draftTTSProbeDelegatesAudioValidationFailures() async throws {
    let httpClient = CapturingTTSProbeHTTPClient(
        responses: [
            AIProviderProbeHTTPResponse(
                statusCode: 200,
                body: Data([0x00]),
                contentType: "application/octet-stream"
            ),
        ]
    )
    let service = TTSConfigurationProbeService(
        httpClient: httpClient,
        audioValidationService: FailingTTSAudioValidationService(category: .audioDecodeFailed)
    )

    let result = try await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: makeVoiceProfile(languageCode: "en"),
            plaintextSecret: "sk-test"
        )
    )

    #expect(result.status == .failed)
    #expect(result.errorCategory == .audioDecodeFailed)
}

@Test("Draft TTS probe rejects oversized audio response before validation")
func draftTTSProbeRejectsOversizedAudioResponseBeforeValidation() async throws {
    let httpClient = CapturingTTSProbeHTTPClient(
        responses: [
            AIProviderProbeHTTPResponse(
                statusCode: 200,
                body: Data(repeating: 0x49, count: 2 * 1024 * 1024 + 1),
                contentType: "audio/mpeg"
            ),
        ]
    )
    let audioValidation = CountingTTSAudioValidationService()
    let service = TTSConfigurationProbeService(
        httpClient: httpClient,
        audioValidationService: audioValidation
    )

    let result = try await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: makeVoiceProfile(languageCode: "en"),
            plaintextSecret: "sk-test"
        )
    )

    #expect(result.status == .failed)
    #expect(result.errorCategory == .invalidAudioResponse)
    #expect(await audioValidation.validationCount == 0)
}

private actor CapturingTTSProbeHTTPClient: AIProviderProbeHTTPClient {
    private(set) var requests: [URLRequest] = []
    private var responses: [AIProviderProbeHTTPResponse]

    init(responses: [AIProviderProbeHTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> AIProviderProbeHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw AIProviderProbeHTTPClientError.transportUnavailable
        }
        return responses.removeFirst()
    }
}

private struct AcceptingTTSAudioValidationService: TTSAudioValidationService {
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
                durationSeconds: 1.0,
                sampleRate: nil
            ),
            previewResource: TTSAudioPreviewResource(storage: .memory, byteCount: data.count)
        )
    }
}

private struct FailingTTSAudioValidationService: TTSAudioValidationService {
    var category: AIProviderValidationErrorCategory

    func validateAudio(
        _: Data,
        declaredFormat _: TTSAudioFormat,
        contentType _: String?,
        previewPolicy _: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        TTSAudioValidationResult(status: .failed(category), metadata: nil, previewResource: nil)
    }
}

private actor CountingTTSAudioValidationService: TTSAudioValidationService {
    private(set) var validationCount = 0

    func validateAudio(
        _: Data,
        declaredFormat _: TTSAudioFormat,
        contentType _: String?,
        previewPolicy _: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        validationCount += 1
        return TTSAudioValidationResult(status: .failed(.audioDecodeFailed), metadata: nil, previewResource: nil)
    }
}

private func ttsEndpoint() -> AIProviderEndpointInput {
    AIProviderEndpointInput(
        id: "tts-endpoint",
        profileID: "profile-1",
        purpose: .tts,
        isEnabled: true,
        providerPresetID: "openai",
        adapterKind: .openAICompatibleChat,
        baseURL: "https://api.openai.com/v1",
        modelName: "gpt-4o-mini-tts",
        credentialID: "credential-1",
        supportsImageInput: false,
        imageInputEnabled: false
    )
}

private func makeVoiceProfile(languageCode: String) throws -> TTSVoiceProfile {
    try TTSVoiceProfile.make(
        id: "voice-\(languageCode)",
        endpointID: "tts-endpoint",
        languageCode: languageCode,
        adapterKind: .openAIAudioSpeech,
        modelName: "gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3,
        providerParameters: ["response_format": .string("mp3")]
    )
}
