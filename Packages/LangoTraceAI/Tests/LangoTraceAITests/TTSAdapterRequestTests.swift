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
        modelName: "gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3,
        instructions: "Calm and clear."
    )

    let request = try adapter.makeRequest(
        input: TTSProviderAdapterRequestInput(
            endpointID: "endpoint-tts",
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-4o-mini-tts",
            voiceProfile: voice,
            plaintextSecret: "sk-test",
            text: "Today I wrote one short sentence for practice."
        )
    )

    #expect(request.url?.absoluteString == "https://api.openai.com/v1/audio/speech")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    let body = try #require(String(data: request.httpBody ?? Data(), encoding: .utf8))
    #expect(body.contains(#""model":"gpt-4o-mini-tts""#))
    #expect(body.contains(#""voice":"coral""#))
    #expect(body.contains(#""response_format":"mp3""#))
    #expect(body.contains(#""instructions":"Calm and clear.""#))
    #expect(body.contains("Today I wrote one short sentence for practice."))
}

@Test("OpenRouter TTS adapter uses OpenRouter endpoint and keeps model dependent inputs manual")
func openRouterTTSAdapterBuildsAudioSpeechRequest() throws {
    let adapter = OpenRouterAudioSpeechAdapter()
    let voice = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openRouterAudioSpeech,
        modelName: "openai/gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3
    )

    let request = try adapter.makeRequest(
        input: TTSProviderAdapterRequestInput(
            endpointID: "endpoint-tts",
            baseURL: "https://openrouter.ai/api/v1",
            modelName: "openai/gpt-4o-mini-tts",
            voiceProfile: voice,
            plaintextSecret: "or-test",
            text: "Today I wrote one short sentence for practice."
        )
    )

    #expect(request.url?.absoluteString == "https://openrouter.ai/api/v1/audio/speech")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer or-test")
    let body = try #require(String(data: request.httpBody ?? Data(), encoding: .utf8))
    #expect(body.contains(#""model":"openai\/gpt-4o-mini-tts""#))
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
