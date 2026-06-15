import Foundation

public enum TTSProviderAdapterKind: String, Codable, CaseIterable, Sendable {
    case openAIAudioSpeech = "openai_audio_speech"
    case groqAudioSpeech = "groq_audio_speech"
    case openRouterAudioSpeech = "openrouter_audio_speech"
    case customOpenAICompatibleAudioSpeech = "custom_openai_compatible_audio_speech"
    case geminiGenerateContentTTS = "gemini_generate_content_tts"
    case mistralAudioSpeech = "mistral_audio_speech"
    case xAITTS = "xai_tts"
    case dashScopeCosyVoice = "dashscope_cosyvoice"
    case zhipuGLMTTS = "zhipu_glm_tts"
    case siliconFlowAudioSpeech = "siliconflow_audio_speech"
    case openAIMultimodalAudio = "openai_multimodal_audio"
    case openRouterMultimodalAudio = "openrouter_multimodal_audio"
}

public enum TTSAudioFormat: String, Codable, CaseIterable, Sendable {
    case mp3
    case wav
    case pcm
    case opus
    case flac
    case aac
    case mulaw
}

public enum TTSConfigurationStatus: String, Codable, CaseIterable, Sendable {
    case notConfigured = "not_configured"
    case notTested = "not_tested"
    case testing
    case succeeded
    case failed
    case requiresRetest = "requires_retest"
    case unsupported
}

public enum TTSProviderConfigurationError: Error, Equatable, Sendable {
    case unsupportedProviderParameter(String)
}

public enum TTSProviderParameterValue: Equatable, Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([TTSProviderParameterValue])
    case object([String: TTSProviderParameterValue])
}

public extension TTSProviderParameterValue {
    /// Canonical sorted-key serialization shared by configuration fingerprints and TTS artifact
    /// cache keys. The output must stay stable across launches and processes; changing it
    /// invalidates persisted TTS audio cache keys.
    static func canonicalSerialization(of parameters: [String: TTSProviderParameterValue]) -> String {
        parameters.keys.sorted().map { key in
            "\(key)=\(parameters[key]!.canonicalSerialization)"
        }.joined(separator: ";")
    }

    var canonicalSerialization: String {
        switch self {
        case let .string(string):
            "s:\(string)"
        case let .number(number):
            "n:\(number)"
        case let .bool(bool):
            "b:\(bool)"
        case let .array(values):
            "[" + values.map(\.canonicalSerialization).joined(separator: ",") + "]"
        case let .object(object):
            "{" + Self.canonicalSerialization(of: object) + "}"
        }
    }
}

public struct TTSProviderSettings: Equatable, Sendable {
    public var endpointID: AIProviderEndpointID
    public var adapterKind: TTSProviderAdapterKind

    public init(endpointID: AIProviderEndpointID, adapterKind: TTSProviderAdapterKind) {
        self.endpointID = endpointID
        self.adapterKind = adapterKind
    }
}

public struct TTSVoiceProfileSaveInput: Equatable, Sendable {
    public var endpointPurpose: AIProviderEndpointPurpose
    public var languageCode: String
    public var adapterKind: TTSProviderAdapterKind
    public var voiceID: String
    public var voiceDisplayName: String?
    public var outputFormat: TTSAudioFormat
    public var sampleRate: Int?
    public var speed: Double?
    public var volume: Double?
    public var pitch: Double?
    public var stylePrompt: String?
    public var instructions: String?
    public var streamingMode: Bool
    public var providerParameters: [String: TTSProviderParameterValue]

    public init(
        endpointPurpose: AIProviderEndpointPurpose,
        languageCode: String,
        adapterKind: TTSProviderAdapterKind,
        voiceID: String,
        voiceDisplayName: String?,
        outputFormat: TTSAudioFormat,
        sampleRate: Int?,
        speed: Double?,
        volume: Double?,
        pitch: Double?,
        stylePrompt: String?,
        instructions: String?,
        streamingMode: Bool,
        providerParameters: [String: TTSProviderParameterValue]
    ) {
        self.endpointPurpose = endpointPurpose
        self.languageCode = languageCode
        self.adapterKind = adapterKind
        self.voiceID = voiceID
        self.voiceDisplayName = voiceDisplayName
        self.outputFormat = outputFormat
        self.sampleRate = sampleRate
        self.speed = speed
        self.volume = volume
        self.pitch = pitch
        self.stylePrompt = stylePrompt
        self.instructions = instructions
        self.streamingMode = streamingMode
        self.providerParameters = providerParameters
    }
}

public struct TTSVoiceProfile: Equatable, Sendable {
    public var id: String
    public var endpointID: AIProviderEndpointID
    public var languageCode: String
    public var adapterKind: TTSProviderAdapterKind
    public var modelName: String
    public var voiceID: String
    public var voiceDisplayName: String?
    public var outputFormat: TTSAudioFormat
    public var sampleRate: Int?
    public var speed: Double?
    public var volume: Double?
    public var pitch: Double?
    public var stylePrompt: String?
    public var instructions: String?
    public var streamingMode: Bool
    public var providerParameters: [String: TTSProviderParameterValue]
    public private(set) var configurationFingerprint: String
    public var lastSuccessfulConfigurationFingerprint: String?
    public var lastTestStatus: TTSConfigurationStatus
    public var lastTestErrorCategory: AIProviderValidationErrorCategory?
    public var lastTestedAt: Date?

    public static func make(
        id: String,
        endpointID: AIProviderEndpointID,
        languageCode: String,
        adapterKind: TTSProviderAdapterKind,
        modelName: String,
        voiceID: String,
        voiceDisplayName: String? = nil,
        outputFormat: TTSAudioFormat,
        sampleRate: Int? = nil,
        speed: Double? = nil,
        volume: Double? = nil,
        pitch: Double? = nil,
        stylePrompt: String? = nil,
        instructions: String? = nil,
        streamingMode: Bool = false,
        providerParameters: [String: TTSProviderParameterValue] = [:],
        lastSuccessfulConfigurationFingerprint: String? = nil,
        lastTestStatus: TTSConfigurationStatus = .notTested,
        lastTestErrorCategory: AIProviderValidationErrorCategory? = nil,
        lastTestedAt: Date? = nil
    ) throws -> TTSVoiceProfile {
        try validate(providerParameters: providerParameters, adapterKind: adapterKind)
        let fingerprint = configurationFingerprint(
            languageCode: languageCode,
            adapterKind: adapterKind,
            modelName: modelName,
            voiceID: voiceID,
            outputFormat: outputFormat,
            sampleRate: sampleRate,
            speed: speed,
            volume: volume,
            pitch: pitch,
            stylePrompt: stylePrompt,
            instructions: instructions,
            streamingMode: streamingMode,
            providerParameters: providerParameters
        )
        return TTSVoiceProfile(
            id: id,
            endpointID: endpointID,
            languageCode: languageCode,
            adapterKind: adapterKind,
            modelName: modelName,
            voiceID: voiceID,
            voiceDisplayName: voiceDisplayName,
            outputFormat: outputFormat,
            sampleRate: sampleRate,
            speed: speed,
            volume: volume,
            pitch: pitch,
            stylePrompt: stylePrompt,
            instructions: instructions,
            streamingMode: streamingMode,
            providerParameters: providerParameters,
            configurationFingerprint: fingerprint,
            lastSuccessfulConfigurationFingerprint: lastSuccessfulConfigurationFingerprint,
            lastTestStatus: lastTestStatus,
            lastTestErrorCategory: lastTestErrorCategory,
            lastTestedAt: lastTestedAt
        )
    }

    public func reconfigured(
        voiceID: String? = nil,
        voiceDisplayName: String? = nil,
        speed: Double? = nil,
        instructions: String? = nil
    ) throws -> TTSVoiceProfile {
        try Self.make(
            id: id,
            endpointID: endpointID,
            languageCode: languageCode,
            adapterKind: adapterKind,
            modelName: modelName,
            voiceID: voiceID ?? self.voiceID,
            voiceDisplayName: voiceDisplayName ?? self.voiceDisplayName,
            outputFormat: outputFormat,
            sampleRate: sampleRate,
            speed: speed ?? self.speed,
            volume: volume,
            pitch: pitch,
            stylePrompt: stylePrompt,
            instructions: instructions ?? self.instructions,
            streamingMode: streamingMode,
            providerParameters: providerParameters,
            lastSuccessfulConfigurationFingerprint: lastSuccessfulConfigurationFingerprint,
            lastTestStatus: lastTestStatus,
            lastTestErrorCategory: lastTestErrorCategory,
            lastTestedAt: lastTestedAt
        )
    }

    public func withProbeOutcome(
        _ status: TTSConfigurationStatus,
        errorCategory: AIProviderValidationErrorCategory? = nil,
        testedAt: Date?
    ) -> TTSVoiceProfile {
        var copy = self
        copy.lastTestStatus = status
        copy.lastTestErrorCategory = errorCategory
        copy.lastTestedAt = testedAt
        if status == .succeeded {
            copy.lastSuccessfulConfigurationFingerprint = configurationFingerprint
            copy.lastTestErrorCategory = nil
        }
        return copy
    }

    public var playbackReadiness: TTSConfigurationStatus {
        if lastTestStatus == .succeeded {
            return lastSuccessfulConfigurationFingerprint == configurationFingerprint ? .succeeded : .requiresRetest
        }
        return lastTestStatus
    }
}

public struct PlayableTTSConfiguration: Equatable, Sendable {
    public var endpoint: AIProviderEndpointConfiguration
    public var settings: TTSProviderSettings
    public var voiceProfile: TTSVoiceProfile

    public init(
        endpoint: AIProviderEndpointConfiguration,
        settings: TTSProviderSettings,
        voiceProfile: TTSVoiceProfile
    ) {
        self.endpoint = endpoint
        self.settings = settings
        self.voiceProfile = voiceProfile
    }
}

public enum PlayableTTSConfigurationStatus: Equatable, Sendable {
    case available(PlayableTTSConfiguration)
    case notConfigured
    case notTested
    case requiresRetest
    case failedLastTest(AIProviderValidationErrorCategory?)
    case credentialMissing
    case unsupportedProvider
}

public protocol TTSConfigurationAvailabilityService: Sendable {
    func loadDefaultPlayableTTSConfiguration(
        languageCode: String
    ) async throws -> PlayableTTSConfigurationStatus
}

private extension TTSVoiceProfile {
    static func validate(
        providerParameters: [String: TTSProviderParameterValue],
        adapterKind: TTSProviderAdapterKind
    ) throws {
        let allowed = adapterKind.allowedProviderParameterKeys
        for key in providerParameters.keys where !allowed.contains(key) {
            throw TTSProviderConfigurationError.unsupportedProviderParameter(key)
        }
    }

    // The fingerprint intentionally includes every user-visible and provider-specific TTS parameter.
    // swiftlint:disable:next function_parameter_count
    static func configurationFingerprint(
        languageCode: String,
        adapterKind: TTSProviderAdapterKind,
        modelName: String,
        voiceID: String,
        outputFormat: TTSAudioFormat,
        sampleRate: Int?,
        speed: Double?,
        volume: Double?,
        pitch: Double?,
        stylePrompt: String?,
        instructions: String?,
        streamingMode: Bool,
        providerParameters: [String: TTSProviderParameterValue]
    ) -> String {
        var parts: [String] = []
        parts.append("language=\(languageCode)")
        parts.append("adapter=\(adapterKind.rawValue)")
        parts.append("model=\(modelName)")
        parts.append("voice=\(voiceID)")
        parts.append("format=\(outputFormat.rawValue)")
        parts.append("sampleRate=\(optionalString(sampleRate))")
        parts.append("speed=\(optionalString(speed))")
        parts.append("volume=\(optionalString(volume))")
        parts.append("pitch=\(optionalString(pitch))")
        parts.append("style=\(stylePrompt ?? "")")
        parts.append("instructions=\(instructions ?? "")")
        parts.append("streaming=\(streamingMode)")
        parts.append("parameters=\(TTSProviderParameterValue.canonicalSerialization(of: providerParameters))")
        return stableFingerprint(for: parts.joined(separator: "\n"))
    }

    static func optionalString(_ value: (some Any)?) -> String {
        value.map { "\($0)" } ?? ""
    }

    static func stableFingerprint(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

private extension TTSProviderAdapterKind {
    var allowedProviderParameterKeys: Set<String> {
        switch self {
        case .openAIAudioSpeech:
            ["instructions", "response_format"]
        case .openRouterAudioSpeech:
            ["response_format", "provider_options"]
        case .groqAudioSpeech:
            ["response_format"]
        case .customOpenAICompatibleAudioSpeech:
            ["response_format", "path_override"]
        case .geminiGenerateContentTTS:
            ["voice_name", "style_prompt"]
        case .mistralAudioSpeech:
            ["voice_id", "response_format"]
        case .xAITTS:
            ["voice_id", "language", "output_format"]
        case .dashScopeCosyVoice:
            ["format", "sample_rate", "rate", "pitch", "volume", "enable_ssml"]
        case .zhipuGLMTTS:
            ["voice", "response_format", "speed", "volume", "stream"]
        case .siliconFlowAudioSpeech:
            ["response_format", "sample_rate", "speed", "gain", "stream"]
        case .openAIMultimodalAudio, .openRouterMultimodalAudio:
            ["response_format", "provider_options"]
        }
    }
}
