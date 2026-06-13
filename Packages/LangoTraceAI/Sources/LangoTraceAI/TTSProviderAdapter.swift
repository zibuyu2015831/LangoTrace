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
    func decodeAudio(from responseBody: Data) throws -> Data
    /// The actual audio format produced by decodeAudio(from:).
    /// Multimodal adapters always decode to WAV (PCM16-wrapped), regardless of the voice profile's declared outputFormat.
    func decodedAudioFormat(for voiceProfile: TTSVoiceProfile) -> TTSAudioFormat
}

public extension TTSProviderAdapter {
    func decodeAudio(from responseBody: Data) throws -> Data {
        responseBody
    }

    func decodedAudioFormat(for voiceProfile: TTSVoiceProfile) -> TTSAudioFormat {
        voiceProfile.outputFormat
    }
}

public struct OpenAIMultimodalAudioSpeechAdapter: TTSProviderAdapter {
    public init() {}

    public func makeRequest(input: TTSProviderAdapterRequestInput) throws -> URLRequest {
        try makeOpenAIStyleMultimodalAudioRequest(input: input)
    }

    public func decodeAudio(from responseBody: Data) throws -> Data {
        try decodeOpenAIStyleMultimodalAudioResponse(responseBody)
    }

    /// Multimodal audio is always decoded and wrapped as WAV (PCM16), regardless of voiceProfile.outputFormat.
    public func decodedAudioFormat(for _: TTSVoiceProfile) -> TTSAudioFormat {
        .wav
    }
}

public struct OpenRouterMultimodalAudioSpeechAdapter: TTSProviderAdapter {
    public init() {}

    public func makeRequest(input: TTSProviderAdapterRequestInput) throws -> URLRequest {
        var request = try makeOpenAIStyleMultimodalAudioRequest(input: input)
        // OpenRouter requires stream: true for audio output
        if let body = request.httpBody,
           var json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        {
            json["stream"] = true
            request.httpBody = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        }

        // OpenRouter recommends these headers to identify the app and avoid being flagged as a bot/naked request
        request.setValue("https://github.com/zibuyu2015831/LangoTrace", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("LangoTrace", forHTTPHeaderField: "X-Title")
        return request
    }

    public func decodeAudio(from responseBody: Data) throws -> Data {
        try decodeOpenAIStyleMultimodalAudioResponse(responseBody)
    }

    /// Multimodal audio is always decoded and wrapped as WAV (PCM16), regardless of voiceProfile.outputFormat.
    public func decodedAudioFormat(for _: TTSVoiceProfile) -> TTSAudioFormat {
        .wav
    }
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
        var request = try makeOpenAIStyleAudioSpeechRequest(input: input)
        // OpenRouter recommends these headers to identify the app and avoid being flagged as a bot/naked request
        request.setValue("https://github.com/zibuyu2015831/LangoTrace", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("LangoTrace", forHTTPHeaderField: "X-Title")
        return request
    }
}

public struct CustomOpenAICompatibleAudioSpeechAdapter: TTSProviderAdapter {
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

private func makeOpenAIStyleMultimodalAudioRequest(input: TTSProviderAdapterRequestInput) throws -> URLRequest {
    guard let baseURL = URL(string: input.baseURL) else {
        throw AIProviderConfigurationError.invalidBaseURL
    }
    let url = baseURL.appendingPathComponent("chat").appendingPathComponent("completions")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let plaintextSecret = input.plaintextSecret, !plaintextSecret.isEmpty {
        request.setValue("Bearer \(plaintextSecret)", forHTTPHeaderField: "Authorization")
    }

    let audioOptions: [String: Any] = [
        "voice": input.voiceProfile.voiceID,
        // When using stream=true (required by OpenRouter for audio), OpenAI requires pcm16
        "format": "pcm16",
    ]

    var messages: [[String: Any]] = []

    let defaultTTSInstruction = "You are a pure text-to-speech engine. Your only task is to read the user's text out loud exactly as written. "
        + "Do NOT answer the user, do NOT add conversational filler, and do NOT interpret the text as a question or command. "
        + "Simply dictate the provided text verbatim."

    let finalInstructions: String = if let userInstructions = input.voiceProfile.instructions, !userInstructions.isEmpty {
        "\(defaultTTSInstruction)\n\nAdditional instructions: \(userInstructions)"
    } else {
        defaultTTSInstruction
    }

    messages.append([
        "role": "system",
        "content": finalInstructions,
    ])

    messages.append([
        "role": "user",
        "content": input.text,
    ])

    let body: [String: Any] = [
        "model": input.modelName,
        "modalities": ["text", "audio"],
        "audio": audioOptions,
        "messages": messages,
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return request
}

private func decodeOpenAIStyleMultimodalAudioResponse(_ data: Data) throws -> Data {
    guard let string = String(data: data, encoding: .utf8) else {
        throw AIProviderHTTPClientError.invalidHTTPResponse
    }

    // Detect SSE stream: OpenRouter may start with blank lines before "data: " chunks,
    // so we check for the presence of any "data: " line rather than just hasPrefix.
    let lines = string.components(separatedBy: .newlines)
    let hasSSEChunks = lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("data: ") })

    if hasSSEChunks {
        var combinedAudioData = Data()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data: ") else { continue }
            let payload = trimmed.dropFirst("data: ".count)
            guard payload != "[DONE]" else { continue }

            guard let jsonData = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let delta = firstChoice["delta"] as? [String: Any],
                  let audio = delta["audio"] as? [String: Any],
                  let base64Data = audio["data"] as? String,
                  let decoded = Data(base64Encoded: base64Data)
            else {
                continue
            }
            combinedAudioData.append(decoded)
        }
        if combinedAudioData.isEmpty {
            throw AIProviderHTTPClientError.invalidHTTPResponse
        }
        return wrapPCM16InWAV(pcmData: combinedAudioData, sampleRate: 24000)
    }

    // Non-streaming JSON path
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let choices = json["choices"] as? [[String: Any]],
          let firstChoice = choices.first,
          let message = firstChoice["message"] as? [String: Any],
          let audio = message["audio"] as? [String: Any],
          let base64Data = audio["data"] as? String,
          let decoded = Data(base64Encoded: base64Data)
    else {
        throw AIProviderHTTPClientError.invalidHTTPResponse
    }
    return decoded
}

private func wrapPCM16InWAV(pcmData: Data, sampleRate: Int) -> Data {
    let numChannels = 1
    let bitsPerSample = 16
    let byteRate = sampleRate * numChannels * (bitsPerSample / 8)
    let blockAlign = numChannels * (bitsPerSample / 8)
    let dataSize = pcmData.count
    let fileSize = dataSize + 36

    var wavData = Data()
    wavData.append(contentsOf: "RIFF".utf8)
    wavData.append(withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Data($0) })
    wavData.append(contentsOf: "WAVE".utf8)
    wavData.append(contentsOf: "fmt ".utf8)
    wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // Subchunk1Size
    wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // AudioFormat (PCM)
    wavData.append(withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Data($0) })
    wavData.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
    wavData.append(withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Data($0) })
    wavData.append(withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Data($0) })
    wavData.append(withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })
    wavData.append(contentsOf: "data".utf8)
    wavData.append(withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
    wavData.append(pcmData)

    return wavData
}
