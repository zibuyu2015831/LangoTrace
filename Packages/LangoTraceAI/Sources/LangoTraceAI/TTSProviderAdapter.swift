@preconcurrency import Foundation
import LangoTraceCore

public struct TTSProviderAdapterRequestInput: Sendable {
    public var endpointID: AIProviderEndpointID
    public var baseURL: String
    public var modelName: String
    public var voiceProfile: TTSVoiceProfile
    public var plaintextSecret: String?
    public var text: String
    public var requestTimeoutSeconds: TimeInterval?

    public init(
        endpointID: AIProviderEndpointID,
        baseURL: String,
        modelName: String,
        voiceProfile: TTSVoiceProfile,
        plaintextSecret: String?,
        text: String,
        requestTimeoutSeconds: TimeInterval? = nil
    ) {
        self.endpointID = endpointID
        self.baseURL = baseURL
        self.modelName = modelName
        self.voiceProfile = voiceProfile
        self.plaintextSecret = plaintextSecret
        self.text = text
        self.requestTimeoutSeconds = requestTimeoutSeconds
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

private let openAISpeechMinimumSpeed = 0.25
private let openAISpeechMaximumSpeed = 4.0

private func makeOpenAIStyleAudioSpeechRequest(input: TTSProviderAdapterRequestInput) throws -> URLRequest {
    guard let url = AIProviderEndpointURLBuilder.endpointURL(baseURL: input.baseURL, pathSuffix: "audio/speech")
    else {
        throw AIProviderConfigurationError.invalidBaseURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let timeout = input.requestTimeoutSeconds {
        request.timeoutInterval = timeout
    }
    if let plaintextSecret = input.plaintextSecret, !plaintextSecret.isEmpty {
        request.setValue("Bearer \(plaintextSecret)", forHTTPHeaderField: "Authorization")
    }

    var body: [String: Any] = [
        "model": input.modelName,
        "input": input.text,
        "voice": input.voiceProfile.voiceID,
        "response_format": input.voiceProfile.outputFormat.rawValue,
    ]
    if let speed = input.voiceProfile.speed {
        body["speed"] = min(max(speed, openAISpeechMinimumSpeed), openAISpeechMaximumSpeed)
    }
    if let instructions = input.voiceProfile.instructions, !instructions.isEmpty {
        body["instructions"] = instructions
    }
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return request
}
