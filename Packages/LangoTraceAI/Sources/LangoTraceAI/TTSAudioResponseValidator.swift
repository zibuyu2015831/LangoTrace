import Foundation
import LangoTraceCore
import os

public struct TTSAudioResponseValidator: Sendable {
    private let audioValidationService: any TTSAudioValidationService

    public init(audioValidationService: any TTSAudioValidationService) {
        self.audioValidationService = audioValidationService
    }

    public func validate(
        response: AIProviderProbeHTTPResponse,
        declaredFormat: TTSAudioFormat,
        contentType: String?
    ) async -> TTSAudioValidationResult {
        guard (200 ... 299).contains(response.statusCode) else {
            return TTSAudioValidationResult(
                status: .failed(errorCategory(for: response.statusCode, body: response.body)),
                metadata: nil,
                previewResource: nil
            )
        }
        guard !response.body.isEmpty else {
            return TTSAudioValidationResult(status: .failed(.invalidAudioResponse), metadata: nil, previewResource: nil)
        }
        return await audioValidationService.validateAudio(
            response.body,
            declaredFormat: declaredFormat,
            contentType: contentType,
            previewPolicy: .shortLived
        )
    }

    public func validate(
        response: AIProviderHTTPResponse,
        declaredFormat: TTSAudioFormat,
        contentType: String?
    ) async -> TTSAudioValidationResult {
        await validate(
            response: AIProviderProbeHTTPResponse(
                statusCode: response.statusCode,
                body: response.body,
                contentType: response.contentType
            ),
            declaredFormat: declaredFormat,
            contentType: contentType
        )
    }
}

private extension TTSAudioResponseValidator {
    func errorCategory(for statusCode: Int, body: Data) -> AIProviderValidationErrorCategory {
        switch statusCode {
        case 401, 403:
            return .authenticationFailed
        case 404:
            return .unsupportedModel
        case 429:
            return providerBody(body).contains("quota") ? .quotaExceeded : .rateLimited
        default:
            let bodyString = providerBody(body)
            os_log("LangoTrace Debug: TTS Error Body: %{public}@", type: .error, bodyString)
            if bodyString.contains("voice") {
                return .invalidVoice
            }
            if bodyString.contains("language") {
                return .unsupportedLanguage
            }
            if bodyString.contains("quota") {
                return .quotaExceeded
            }
            return .providerRejected
        }
    }

    func providerBody(_ data: Data) -> String {
        String(data: data, encoding: .utf8)?.lowercased() ?? ""
    }
}
