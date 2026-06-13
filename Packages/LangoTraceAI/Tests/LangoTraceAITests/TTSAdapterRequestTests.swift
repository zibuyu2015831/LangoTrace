import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Test("OpenAI TTS adapter builds audio speech request with voice format and instructions")
func openAITTSAdapterBuildsAudioSpeechRequest() throws {
    let adapter = OpenAIAudioSpeechAdapter()
    let voice = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "tts-1",
        voiceID: "coral",
        outputFormat: .mp3,
        instructions: "Calm and clear."
    )

    let request = try adapter.makeRequest(
        input: TTSProviderAdapterRequestInput(
            endpointID: "endpoint-tts",
            baseURL: "https://api.openai.com/v1",
            modelName: "tts-1",
            voiceProfile: voice,
            plaintextSecret: "sk-test",
            text: "Today I wrote one short sentence for practice."
        )
    )

    #expect(request.url?.absoluteString == "https://api.openai.com/v1/audio/speech")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    let body = try #require(String(data: request.httpBody ?? Data(), encoding: .utf8))
    #expect(body.contains(#""model":"tts-1""#))
    #expect(body.contains(#""voice":"coral""#))
    #expect(body.contains(#""response_format":"mp3""#))
    #expect(body.contains(#""instructions":"Calm and clear.""#))
    #expect(body.contains("Today I wrote one short sentence for practice."))
    #expect(!body.contains(#""speed""#))
}

@Test("OpenAI TTS adapter serializes configured voice profile speed with OpenAI range clamping")
func openAITTSAdapterSerializesConfiguredSpeed() throws {
    let adapter = OpenAIAudioSpeechAdapter()

    func request(speed: Double?) throws -> String {
        let voice = try TTSVoiceProfile.make(
            id: "voice-en",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "coral",
            outputFormat: .mp3,
            speed: speed
        )
        let request = try adapter.makeRequest(
            input: TTSProviderAdapterRequestInput(
                endpointID: "endpoint-tts",
                baseURL: "https://api.openai.com/v1",
                modelName: "tts-1",
                voiceProfile: voice,
                plaintextSecret: "sk-test",
                text: "Today I wrote one short sentence for practice."
            )
        )
        return try #require(String(data: request.httpBody ?? Data(), encoding: .utf8))
    }

    #expect(try request(speed: 1.5).contains(#""speed":1.5"#))
    #expect(try request(speed: 9).contains(#""speed":4"#))
    #expect(try request(speed: 0.1).contains(#""speed":0.25"#))
    #expect(try !request(speed: nil).contains(#""speed""#))
}

@Test("TTS adapter applies the configured request timeout to the URL request")
func ttsAdapterAppliesConfiguredRequestTimeout() throws {
    let adapter = OpenAIAudioSpeechAdapter()
    let voice = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "tts-1",
        voiceID: "coral",
        outputFormat: .mp3
    )

    let request = try adapter.makeRequest(
        input: TTSProviderAdapterRequestInput(
            endpointID: "endpoint-tts",
            baseURL: "https://api.openai.com/v1",
            modelName: "tts-1",
            voiceProfile: voice,
            plaintextSecret: "sk-test",
            text: "Today I wrote one short sentence for practice.",
            requestTimeoutSeconds: 42
        )
    )

    #expect(request.timeoutInterval == 42)
}

@Test("TTS adapter deduplicates a base URL that already contains the audio speech suffix")
func ttsAdapterDeduplicatesBaseURLContainingAudioSpeechSuffix() throws {
    let adapter = OpenAIAudioSpeechAdapter()
    let voice = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "tts-1",
        voiceID: "coral",
        outputFormat: .mp3
    )

    let request = try adapter.makeRequest(
        input: TTSProviderAdapterRequestInput(
            endpointID: "endpoint-tts",
            baseURL: "https://api.openai.com/v1/audio/speech",
            modelName: "tts-1",
            voiceProfile: voice,
            plaintextSecret: "sk-test",
            text: "Today I wrote one short sentence for practice."
        )
    )

    #expect(request.url?.absoluteString == "https://api.openai.com/v1/audio/speech")
}

@Test("OpenRouter TTS adapter uses OpenRouter endpoint and keeps model dependent inputs manual")
func openRouterTTSAdapterBuildsAudioSpeechRequest() throws {
    let adapter = OpenRouterAudioSpeechAdapter()
    let voice = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openRouterAudioSpeech,
        modelName: "openai/tts-1",
        voiceID: "coral",
        outputFormat: .mp3
    )

    let request = try adapter.makeRequest(
        input: TTSProviderAdapterRequestInput(
            endpointID: "endpoint-tts",
            baseURL: "https://openrouter.ai/api/v1",
            modelName: "openai/tts-1",
            voiceProfile: voice,
            plaintextSecret: "or-test",
            text: "Today I wrote one short sentence for practice."
        )
    )

    #expect(request.url?.absoluteString == "https://openrouter.ai/api/v1/audio/speech")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer or-test")
    let body = try #require(String(data: request.httpBody ?? Data(), encoding: .utf8))
    #expect(body.contains(#""model":"openai\/tts-1""#))
    #expect(body.contains(#""voice":"coral""#))
}

@Test("TTS response validator maps HTTP failures and delegates audio decode to Core service")
func ttsResponseValidatorMapsFailuresAndDelegatesAudioDecode() async {
    let validator = TTSAudioResponseValidator(audioValidationService: RecordingAudioValidationService(
        result: TTSAudioValidationResult(
            status: .failed(.audioDecodeFailed),
            metadata: nil,
            previewResource: nil
        )
    ))

    let auth = await validator.validate(
        response: AIProviderProbeHTTPResponse(statusCode: 401, body: Data()),
        declaredFormat: .mp3,
        contentType: "audio/mpeg"
    )
    let rateLimited = await validator.validate(
        response: AIProviderProbeHTTPResponse(statusCode: 429, body: Data()),
        declaredFormat: .mp3,
        contentType: "audio/mpeg"
    )
    let decode = await validator.validate(
        response: AIProviderProbeHTTPResponse(statusCode: 200, body: Data([0x49, 0x44, 0x33])),
        declaredFormat: .mp3,
        contentType: "audio/mpeg"
    )

    #expect(auth.status == .failed(.authenticationFailed))
    #expect(rateLimited.status == .failed(.rateLimited))
    #expect(decode.status == .failed(.audioDecodeFailed))
}

@Test("TTS response validator maps provider error bodies to stable TTS categories")
func ttsResponseValidatorMapsProviderErrorBodiesToStableTTSCategories() async {
    let validator = TTSAudioResponseValidator(audioValidationService: RecordingAudioValidationService(
        result: TTSAudioValidationResult(status: .failed(.audioDecodeFailed), metadata: nil, previewResource: nil)
    ))

    let invalidVoice = await validator.validate(
        response: AIProviderProbeHTTPResponse(
            statusCode: 400,
            body: Data(#"{"error":"voice coral is not available"}"#.utf8)
        ),
        declaredFormat: .mp3,
        contentType: "application/json"
    )
    let unsupportedLanguage = await validator.validate(
        response: AIProviderProbeHTTPResponse(
            statusCode: 400,
            body: Data(#"{"error":"language ja is unsupported for this route"}"#.utf8)
        ),
        declaredFormat: .mp3,
        contentType: "application/json"
    )
    let quotaExceeded = await validator.validate(
        response: AIProviderProbeHTTPResponse(
            statusCode: 429,
            body: Data(#"{"error":"quota exceeded"}"#.utf8)
        ),
        declaredFormat: .mp3,
        contentType: "application/json"
    )

    #expect(invalidVoice.status == .failed(.invalidVoice))
    #expect(unsupportedLanguage.status == .failed(.unsupportedLanguage))
    #expect(quotaExceeded.status == .failed(.quotaExceeded))
}

@Test("TTS response validator rejects empty audio before decode")
func ttsResponseValidatorRejectsEmptyAudioBeforeDecode() async {
    let audioValidation = CountingAudioValidationService()
    let validator = TTSAudioResponseValidator(audioValidationService: audioValidation)

    let result = await validator.validate(
        response: AIProviderProbeHTTPResponse(statusCode: 200, body: Data(), contentType: "audio/mpeg"),
        declaredFormat: .mp3,
        contentType: "audio/mpeg"
    )

    #expect(result.status == .failed(.invalidAudioResponse))
    #expect(await audioValidation.validationCount == 0)
}

@Test("TTS response validator forwards audio metadata boundary to Core validation service")
func ttsResponseValidatorForwardsAudioMetadataBoundaryToCoreValidationService() async throws {
    let audioValidation = CapturingAudioValidationService()
    let validator = TTSAudioResponseValidator(audioValidationService: audioValidation)

    let result = await validator.validate(
        response: AIProviderProbeHTTPResponse(
            statusCode: 200,
            body: Data([0x49, 0x44, 0x33]),
            contentType: "text/plain"
        ),
        declaredFormat: .mp3,
        contentType: "text/plain"
    )

    let lastCall = await audioValidation.lastCall
    let call = try #require(lastCall)
    #expect(result.status == .failed(.invalidAudioResponse))
    #expect(call.data == Data([0x49, 0x44, 0x33]))
    #expect(call.declaredFormat == .mp3)
    #expect(call.contentType == "text/plain")
    #expect(call.previewPolicy == .shortLived)
}

private struct RecordingAudioValidationService: TTSAudioValidationService {
    var result: TTSAudioValidationResult

    func validateAudio(
        _: Data,
        declaredFormat _: TTSAudioFormat,
        contentType _: String?,
        previewPolicy _: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        result
    }
}

private actor CountingAudioValidationService: TTSAudioValidationService {
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

private actor CapturingAudioValidationService: TTSAudioValidationService {
    private(set) var lastCall: Call?

    struct Call {
        var data: Data
        var declaredFormat: TTSAudioFormat
        var contentType: String?
        var previewPolicy: TTSAudioPreviewPolicy
    }

    func validateAudio(
        _ data: Data,
        declaredFormat: TTSAudioFormat,
        contentType: String?,
        previewPolicy: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        lastCall = Call(
            data: data,
            declaredFormat: declaredFormat,
            contentType: contentType,
            previewPolicy: previewPolicy
        )
        return TTSAudioValidationResult(status: .failed(.invalidAudioResponse), metadata: nil, previewResource: nil)
    }
}
