@preconcurrency import Foundation
import LangoTraceCore

public struct TTSProviderAdapterRequestInput: Sendable {
    public var endpointID: AIProviderEndpointID
    public var baseURL: String
    public var modelName: String
    public var voiceProfile: TTSVoiceProfile
    public var plaintextSecret: String?
    public var text: String

    public init(
        endpointID: AIProviderEndpointID,
        baseURL: String,
        modelName: String,
        voiceProfile: TTSVoiceProfile,
        plaintextSecret: String?,
        text: String
    ) {
        self.endpointID = endpointID
        self.baseURL = baseURL
        self.modelName = modelName
        self.voiceProfile = voiceProfile
        self.plaintextSecret = plaintextSecret
        self.text = text
    }
}

public protocol TTSProviderAdapter: Sendable {
    func makeRequest(input: TTSProviderAdapterRequestInput) throws -> URLRequest
}

public struct OpenAIAudioSpeechAdapter: TTSProviderAdapter {
    public init() {}

    public func makeRequest(input: TTSProviderAdapterRequestInput) throws -> URLRequest {
        try makeOpenAIStyleAudioSpeechRequest(input: input)
    }
}

public struct OpenRouterAudioSpeechAdapter: TTSProviderAdapter {
    public init() {}

    public func makeRequest(input: TTSProviderAdapterRequestInput) throws -> URLRequest {
        try makeOpenAIStyleAudioSpeechRequest(input: input)
    }
}

private func makeOpenAIStyleAudioSpeechRequest(input: TTSProviderAdapterRequestInput) throws -> URLRequest {
    guard let baseURL = URL(string: input.baseURL) else {
        throw AIProviderConfigurationError.invalidBaseURL
    }
    let url = baseURL.appendingPathComponent("audio").appendingPathComponent("speech")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let plaintextSecret = input.plaintextSecret, !plaintextSecret.isEmpty {
        request.setValue("Bearer \(plaintextSecret)", forHTTPHeaderField: "Authorization")
    }

    var body: [String: Any] = [
        "model": input.modelName,
        "input": input.text,
        "voice": input.voiceProfile.voiceID,
        "response_format": input.voiceProfile.outputFormat.rawValue,
    ]
    if let instructions = input.voiceProfile.instructions, !instructions.isEmpty {
        body["instructions"] = instructions
    }
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return request
}
