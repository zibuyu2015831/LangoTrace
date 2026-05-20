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
    case aiProviderConfigurationKeychainWriteStarted = "ai_provider_configuration.keychain_write_started"
    case aiProviderConfigurationKeychainWriteSucceeded = "ai_provider_configuration.keychain_write_succeeded"
    case aiProviderConfigurationKeychainWriteFailed = "ai_provider_configuration.keychain_write_failed"
    case aiProviderConfigurationDatabaseWriteStarted = "ai_provider_configuration.database_write_started"
    case aiProviderConfigurationDatabaseWriteSucceeded = "ai_provider_configuration.database_write_succeeded"
    case aiProviderConfigurationDatabaseWriteFailed = "ai_provider_configuration.database_write_failed"
    case aiProviderConfigurationCleanupStarted = "ai_provider_configuration.cleanup_started"
    case aiProviderConfigurationCleanupSucceeded = "ai_provider_configuration.cleanup_succeeded"
    case aiProviderConfigurationCleanupFailed = "ai_provider_configuration.cleanup_failed"
}

public enum DiagnosticDomain: String, Codable, Sendable {
    case aiProviderSettings = "ai_provider_settings"
    case permissions
    case dataStorage = "data_storage"
    case appLifecycle = "app_lifecycle"
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
    case platform(String)
    case appVersion(String)
    case diagnosticsMode(String)

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
        case .platform:
            "platform"
        case .appVersion:
            "app_version"
        case .diagnosticsMode:
            "diagnostics_mode"
        }
    }
}
