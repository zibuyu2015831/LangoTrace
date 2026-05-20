public struct AIProviderConfigurationSaveFailure: Error, Equatable, Sendable {
    public var operationID: DiagnosticOperationID?
    public var phase: AIProviderConfigurationSavePhase
    public var category: AIProviderConfigurationSaveFailureCategory
    public var cleanupFailure: AIProviderConfigurationSaveFailureCategory?

    public init(
        operationID: DiagnosticOperationID? = nil,
        phase: AIProviderConfigurationSavePhase,
        category: AIProviderConfigurationSaveFailureCategory,
        cleanupFailure: AIProviderConfigurationSaveFailureCategory? = nil
    ) {
        self.operationID = operationID
        self.phase = phase
        self.category = category
        self.cleanupFailure = cleanupFailure
    }
}

public enum AIProviderConfigurationSavePhase: String, Codable, Sendable {
    case inputValidation = "input_validation"
    case keychainWrite = "keychain_write"
    case databaseWrite = "database_write"
    case credentialCleanup = "credential_cleanup"
    case unknown
}

public enum AIProviderConfigurationSaveFailureCategory: String, Codable, Sendable {
    case missingRequiredEndpointField = "missing_required_endpoint_field"
    case missingRequiredAPIKey = "missing_required_api_key"
    case invalidBaseURL = "invalid_base_url"
    case keychainWriteFailed = "keychain_write_failed"
    case databaseWriteFailed = "database_write_failed"
    case credentialCleanupFailed = "credential_cleanup_failed"
    case unknown
}
