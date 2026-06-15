import Foundation

public struct DiagnosticOperationID: RawRepresentable, Equatable, Hashable, Codable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct DiagnosticEvent: Equatable, Sendable {
    public var id: String
    public var name: DiagnosticEventName
    public var domain: DiagnosticDomain
    public var level: DiagnosticLevel
    public var outcome: DiagnosticOutcome?
    public var attributes: [DiagnosticAttribute]
    public var createdAt: Date

    public init(
        id: String,
        name: DiagnosticEventName,
        domain: DiagnosticDomain,
        level: DiagnosticLevel,
        outcome: DiagnosticOutcome?,
        attributes: [DiagnosticAttribute],
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.level = level
        self.outcome = outcome
        self.attributes = attributes
        self.createdAt = createdAt
    }
}

public enum DiagnosticEventName: String, Codable, Sendable {
    case aiProviderSettingsSaveTapped = "ai_provider_settings.save_tapped"
    case aiProviderSettingsSaveInputInvalid = "ai_provider_settings.save_input_invalid"
    case aiProviderSettingsSaveStarted = "ai_provider_settings.save_started"
    case aiProviderSettingsSaveSucceeded = "ai_provider_settings.save_succeeded"
    case aiProviderSettingsSaveFailed = "ai_provider_settings.save_failed"
    case aiProviderSettingsCredentialFailed = "ai_provider_settings.credential_resolve_failed"
    case aiProviderConfigurationKeychainWriteStarted = "ai_provider_configuration.keychain_write_started"
    case aiProviderConfigurationKeychainWriteSucceeded = "ai_provider_configuration.keychain_write_succeeded"
    case aiProviderConfigurationKeychainWriteFailed = "ai_provider_configuration.keychain_write_failed"
    case aiProviderConfigurationDatabaseWriteStarted = "ai_provider_configuration.database_write_started"
    case aiProviderConfigurationDatabaseWriteSucceeded = "ai_provider_configuration.database_write_succeeded"
    case aiProviderConfigurationDatabaseWriteFailed = "ai_provider_configuration.database_write_failed"
    case aiProviderConfigurationCleanupStarted = "ai_provider_configuration.cleanup_started"
    case aiProviderConfigurationCleanupSucceeded = "ai_provider_configuration.cleanup_succeeded"
    case aiProviderConfigurationCleanupFailed = "ai_provider_configuration.cleanup_failed"
    case aiProviderConfigurationProbeStarted = "ai_provider_configuration.probe_started"
    case aiProviderConfigurationProbeSucceeded = "ai_provider_configuration.probe_succeeded"
    case aiProviderConfigurationProbePartial = "ai_provider_configuration.probe_partial"
    case aiProviderConfigurationProbeFailed = "ai_provider_configuration.probe_failed"
    case aiProviderConfigurationProbeUnsupported = "ai_provider_configuration.probe_unsupported"
    case aiProviderConfigurationProbeCancelled = "ai_provider_configuration.probe_cancelled"
    case sentenceTTSGenerationStarted = "sentence_tts_generation.started"
    case sentenceTTSGenerationSucceeded = "sentence_tts_generation.succeeded"
    case sentenceTTSGenerationFailed = "sentence_tts_generation.failed"
    case sentenceAudioPlaybackStarted = "sentence_audio_playback.started"
    case sentenceAudioPlaybackPaused = "sentence_audio_playback.paused"
    case sentenceAudioPlaybackResumed = "sentence_audio_playback.resumed"
    case sentenceAudioPlaybackStopped = "sentence_audio_playback.stopped"
    case sentenceAudioPlaybackCompleted = "sentence_audio_playback.completed"
    case sentenceAudioPlaybackFailed = "sentence_audio_playback.failed"
    case practiceRecordingFailed = "practice_recording.failed"
    case learningContentRepositoryReadFailed = "learning_content.repository_read_failed"
}

public enum DiagnosticDomain: String, Codable, Sendable {
    case aiProviderSettings = "ai_provider_settings"
    case permissions
    case dataStorage = "data_storage"
    case appLifecycle = "app_lifecycle"
    case practiceRecording = "practice_recording"
}

public enum DiagnosticLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
}

public enum DiagnosticOutcome: String, Codable, Sendable {
    case started
    case succeeded
    case failed
    case cancelled
}

public enum DiagnosticAttribute: Equatable, Sendable {
    case operationID(DiagnosticOperationID)
    case providerPresetID(String)
    case endpointPurpose(AIProviderEndpointPurpose)
    case endpointCount(Int)
    case enabledEndpointCount(Int)
    case modelName(String)
    case durationMilliseconds(Int)
    case errorCategory(String)
    case failurePhase(String)
    case adapterKind(AIProviderAdapterKind)
    case probeCapability(AIProviderProbeCapability)
    case probeCapabilityStatus(AIProviderProbeCapabilityStatus)
    case languageSupportFailureReason(String)
    case platform(String)
    case appVersion(String)
    case diagnosticsMode(String)
    case outputFormat(TTSAudioFormat)
    case textLengthBucket(SentenceAudioTextLengthBucket)
    case byteSizeBucket(SentenceAudioByteSizeBucket)
    case durationBucket(SentenceAudioDurationBucket)
    case cacheResult(SentenceAudioCacheResult)
    case repositoryReadOperation(String)

    public var key: String {
        switch self {
        case .operationID:
            "operation_id"
        case .providerPresetID:
            "provider_preset_id"
        case .endpointPurpose:
            "endpoint_purpose"
        case .endpointCount:
            "endpoint_count"
        case .enabledEndpointCount:
            "enabled_endpoint_count"
        case .modelName:
            "model_name"
        case .durationMilliseconds:
            "duration_ms"
        case .errorCategory:
            "error_category"
        case .failurePhase:
            "failure_phase"
        case .adapterKind:
            "adapter_kind"
        case .probeCapability:
            "probe_capability"
        case .probeCapabilityStatus:
            "probe_capability_status"
        case .languageSupportFailureReason:
            "language_support_failure_reason"
        case .platform:
            "platform"
        case .appVersion:
            "app_version"
        case .diagnosticsMode:
            "diagnostics_mode"
        case .outputFormat:
            "output_format"
        case .textLengthBucket:
            "text_length_bucket"
        case .byteSizeBucket:
            "byte_size_bucket"
        case .durationBucket:
            "duration_bucket"
        case .cacheResult:
            "cache_result"
        case .repositoryReadOperation:
            "repository_read_operation"
        }
    }

    public var valueDescription: String {
        switch self {
        case let .operationID(value):
            value.rawValue
        case let .providerPresetID(value):
            value
        case let .endpointPurpose(value):
            value.rawValue
        case let .endpointCount(value),
             let .enabledEndpointCount(value),
             let .durationMilliseconds(value):
            String(value)
        case let .modelName(value),
             let .errorCategory(value),
             let .failurePhase(value),
             let .languageSupportFailureReason(value),
             let .platform(value),
             let .appVersion(value),
             let .diagnosticsMode(value):
            value
        case let .adapterKind(value):
            value.rawValue
        case let .probeCapability(value):
            value.rawValue
        case let .probeCapabilityStatus(value):
            value.rawValue
        case let .outputFormat(value):
            value.rawValue
        case let .textLengthBucket(value):
            value.rawValue
        case let .byteSizeBucket(value):
            value.rawValue
        case let .durationBucket(value):
            value.rawValue
        case let .cacheResult(value):
            value.rawValue
        case let .repositoryReadOperation(value):
            value
        }
    }
}
