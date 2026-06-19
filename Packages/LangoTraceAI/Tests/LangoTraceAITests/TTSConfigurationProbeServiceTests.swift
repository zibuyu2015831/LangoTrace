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
        diagnosticLogger: DisabledDiagnosticLogger(),
        clock: { Date(timeIntervalSince1970: 1000) }
    )
    let voiceProfile = try makeVoiceProfile(languageCode: "ja")

    let result = await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: voiceProfile,
            plaintextSecret: "sk-test",
            operationID: DiagnosticOperationID(rawValue: "op-1")
        )
    )

    #expect(result.status == .succeeded)
    #expect(result.endpointMetadata?.endpointID == "tts-endpoint")
    #expect(result.endpointMetadata?.endpointPurpose == .tts)
    #expect(result.endpointMetadata?.providerPresetID == "openai")
    #expect(result.endpointMetadata?.modelName == "tts-1")
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
        audioValidationService: AcceptingTTSAudioValidationService(),
        diagnosticLogger: DisabledDiagnosticLogger()
    )

    let result = try await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: makeVoiceProfile(languageCode: "en"),
            plaintextSecret: nil,
            operationID: DiagnosticOperationID(rawValue: "op-1")
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
        audioValidationService: FailingTTSAudioValidationService(category: .audioDecodeFailed),
        diagnosticLogger: DisabledDiagnosticLogger()
    )

    let result = try await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: makeVoiceProfile(languageCode: "en"),
            plaintextSecret: "sk-test",
            operationID: DiagnosticOperationID(rawValue: "op-1")
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
        audioValidationService: audioValidation,
        diagnosticLogger: DisabledDiagnosticLogger()
    )

    let result = try await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: makeVoiceProfile(languageCode: "en"),
            plaintextSecret: "sk-test",
            operationID: DiagnosticOperationID(rawValue: "op-1")
        )
    )

    #expect(result.status == .failed)
    #expect(result.errorCategory == .invalidAudioResponse)
    #expect(await audioValidation.validationCount == 0)
}

@Test("Draft TTS probe decodes streamed SSE audio chunks for OpenRouter multimodal adapter")
func draftTTSProbeDecodesStreamedSSEAudioChunks() async throws {
    let ssePayload = "data: {\"choices\":[{\"delta\":{\"audio\":{\"data\":\"AAAA\"}}}]}\n"
    let httpClient = CapturingTTSProbeHTTPClient(
        responses: [
            AIProviderProbeHTTPResponse(
                statusCode: 200,
                body: Data(ssePayload.utf8),
                contentType: "text/event-stream"
            ),
        ]
    )
    let audioValidation = AcceptingTTSAudioValidationService()
    let service = TTSConfigurationProbeService(
        httpClient: httpClient,
        audioValidationService: audioValidation,
        diagnosticLogger: DisabledDiagnosticLogger()
    )

    let voiceProfile = try TTSVoiceProfile.make(
        id: "voice-ja",
        endpointID: "tts-endpoint",
        languageCode: "ja",
        adapterKind: .openRouterMultimodalAudio,
        modelName: "openai/gpt-audio-mini",
        voiceID: "alloy",
        outputFormat: .wav
    )

    let result = await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: AIProviderEndpointInput(
                id: "tts-endpoint",
                profileID: "profile-1",
                purpose: .tts,
                isEnabled: true,
                providerPresetID: "openrouter",
                adapterKind: .openAICompatibleChat,
                baseURL: "https://openrouter.ai/api/v1",
                modelName: "openai/gpt-audio-mini",
                credentialID: "credential-1",
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openRouterMultimodalAudio),
            voiceProfile: voiceProfile,
            plaintextSecret: "sk-test",
            operationID: DiagnosticOperationID(rawValue: "op-2")
        )
    )

    #expect(result.status == .succeeded)
    #expect(result.audioMetadata?.format == .wav)
}

@Test("Draft TTS probe uses WAV validation format for multimodal adapter even when voiceProfile declares MP3")
func draftTTSProbeUsesWAVFormatForMultimodalAdapterWhenVoiceProfileDeclaresMp3() async throws {
    // This is the real-world scenario: user configures outputFormat=.mp3 in their voice profile,
    // but openRouterMultimodalAudio always decodes to WAV (PCM16-wrapped). The probe must validate
    // against .wav, not .mp3, to avoid a format mismatch causing false invalidAudioResponse failures.
    let ssePayload = "data: {\"choices\":[{\"delta\":{\"audio\":{\"data\":\"AAAA\"}}}]}\n"
    let httpClient = CapturingTTSProbeHTTPClient(
        responses: [
            AIProviderProbeHTTPResponse(
                statusCode: 200,
                body: Data(ssePayload.utf8),
                contentType: "text/event-stream"
            ),
        ]
    )
    let audioValidation = CapturingTTSAudioValidationService()
    let service = TTSConfigurationProbeService(
        httpClient: httpClient,
        audioValidationService: audioValidation,
        diagnosticLogger: DisabledDiagnosticLogger()
    )

    let voiceProfile = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "tts-endpoint",
        languageCode: "en",
        adapterKind: .openRouterMultimodalAudio,
        modelName: "openai/gpt-audio-mini",
        voiceID: "nova",
        outputFormat: .mp3 // User configured MP3, but multimodal decodes to WAV
    )

    _ = await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: AIProviderEndpointInput(
                id: "tts-endpoint",
                profileID: "profile-1",
                purpose: .tts,
                isEnabled: true,
                providerPresetID: "openrouter",
                adapterKind: .openAICompatibleChat,
                baseURL: "https://openrouter.ai/api/v1",
                modelName: "openai/gpt-audio-mini",
                credentialID: "credential-1",
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openRouterMultimodalAudio),
            voiceProfile: voiceProfile,
            plaintextSecret: "sk-test",
            operationID: DiagnosticOperationID(rawValue: "op-3")
        )
    )

    // The validation service must have received .wav (the actual decoded format), not .mp3
    let capturedFormat = await audioValidation.lastDeclaredFormat
    #expect(capturedFormat == .wav)
}

@Test("Draft TTS probe records HTTP status code in diagnostic event on error response")
func draftTTSProbeRecordsHTTPStatusCodeInDiagnosticEvent() async throws {
    let httpClient = CapturingTTSProbeHTTPClient(
        responses: [
            AIProviderProbeHTTPResponse(
                statusCode: 400,
                body: Data("{\"error\":\"invalid request\"}".utf8),
                contentType: "application/json"
            ),
        ]
    )
    let diagnosticLogger = InMemoryDiagnosticLogger()
    let service = TTSConfigurationProbeService(
        httpClient: httpClient,
        audioValidationService: AcceptingTTSAudioValidationService(),
        diagnosticLogger: diagnosticLogger,
        clock: { Date(timeIntervalSince1970: 1000) }
    )

    let voiceProfile = try makeVoiceProfile(languageCode: "en")
    let result = await service.probeDraftTTSConfiguration(
        TTSDraftProbeInput(
            endpoint: ttsEndpoint(),
            settings: TTSProviderSettings(endpointID: "tts-endpoint", adapterKind: .openAIAudioSpeech),
            voiceProfile: voiceProfile,
            plaintextSecret: "sk-test",
            operationID: DiagnosticOperationID(rawValue: "op-http-status")
        )
    )

    #expect(result.status == .failed)
    let events = await diagnosticLogger.events()
    let probeEvent = try #require(events.first)
    #expect(probeEvent.attributes.contains(.httpStatusCode(400)))
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

private actor CapturingTTSAudioValidationService: TTSAudioValidationService {
    private(set) var lastDeclaredFormat: TTSAudioFormat?

    func validateAudio(
        _ data: Data,
        declaredFormat: TTSAudioFormat,
        contentType _: String?,
        previewPolicy _: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        lastDeclaredFormat = declaredFormat
        return TTSAudioValidationResult(
            status: .succeeded,
            metadata: TTSAudioMetadata(
                format: declaredFormat,
                byteCount: data.count,
                durationSeconds: 1.0,
                sampleRate: nil
            ),
            previewResource: nil
        )
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
        modelName: "tts-1",
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
        modelName: "tts-1",
        voiceID: "coral",
        outputFormat: .mp3,
        providerParameters: ["response_format": .string("mp3")]
    )
}
