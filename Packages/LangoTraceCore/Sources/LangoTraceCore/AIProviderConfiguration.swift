import Foundation

public typealias AIProviderProfileID = String
public typealias AIProviderEndpointID = String
public typealias AIProviderCredentialID = String
public typealias AIProviderValidationEventID = String

public enum AIProviderConfigurationError: Error, Equatable, Sendable {
    case missingRequiredEndpointField
    case invalidBaseURL
    case unsupportedCapabilityForProvider
    case missingRequiredAPIKey
    case keychainWriteFailed
    case databaseWriteFailed
    case orphanedCredentialCleanupFailed
    /// The secure credential store is unavailable in the current session
    /// (e.g. validation requested while no credential store is wired). Distinct
    /// from `keychainWriteFailed`, which means a write was attempted and failed.
    case configurationStoreUnavailable
    /// No default AI provider profile is configured, so there is nothing to
    /// validate. Distinct from `missingRequiredEndpointField`, which means a
    /// configured profile is missing a required field.
    case defaultProfileMissing
}

public struct AIProviderCredentialResolveFailure: Error, Equatable, Sendable {
    public var category: AIProviderValidationErrorCategory

    public init(category: AIProviderValidationErrorCategory) {
        self.category = category
    }
}

public enum AIProviderProfileStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case configured
    case incomplete
    case credentialMissing = "credential_missing"
    case credentialInaccessible = "credential_inaccessible"
    case validationFailed = "validation_failed"
}

public enum AIProviderValidationStatus: String, Codable, CaseIterable, Sendable {
    case notRun = "not_run"
    case succeeded
    case failed
    case cancelled
}

public enum AIProviderEndpointPurpose: String, Codable, CaseIterable, Sendable {
    case textGeneration = "text_generation"
    case tts
    case embedding
}

public enum AIProviderAdapterKind: String, Codable, CaseIterable, Sendable {
    case openAIResponses = "openai_responses"
    case openAICompatibleChat = "openai_compatible_chat"
    case anthropicMessages = "anthropic_messages"
    case geminiGenerateContent = "gemini_generate_content"
    case mimoCompatibleChat = "mimo_compatible_chat"
}

public enum AIProviderCredentialKind: String, Codable, CaseIterable, Sendable {
    case apiKey = "api_key"
    case bearerToken = "bearer_token"
    case customHeaderSecret = "custom_header_secret"
}

public enum AIProviderSecretPresence: String, Codable, CaseIterable, Sendable {
    case present
    case missing
    case inaccessible
    case unknown
}

public enum AIProviderCredentialCleanupState: String, Codable, CaseIterable, Sendable {
    case active
    case pendingKeychainDelete = "pending_keychain_delete"
    case cleanupFailed = "cleanup_failed"
}

public enum AIProviderCustomHeaderValueKind: String, Codable, CaseIterable, Sendable {
    case plainText = "plain_text"
    case secretCredential = "secret_credential"
}

public enum AIProviderValidationEventType: String, Codable, CaseIterable, Sendable {
    case credentialValidation = "credential_validation"
    case syntheticTest = "synthetic_test"
    case realRequestProbe = "real_request_probe"
}

public enum AIProviderValidationErrorCategory: String, Codable, CaseIterable, Sendable {
    case missingCredential = "missing_credential"
    case credentialInaccessible = "credential_inaccessible"
    case networkUnavailable = "network_unavailable"
    case timeout
    case providerRejected = "provider_rejected"
    case authenticationFailed = "authentication_failed"
    case unsupportedModel = "unsupported_model"
    case unsupportedEndpointPurpose = "unsupported_endpoint_purpose"
    case invalidResponse = "invalid_response"
    case invalidAudioResponse = "invalid_audio_response"
    case invalidVoice = "invalid_voice"
    case unsupportedLanguage = "unsupported_language"
    case unsupportedAudioFormat = "unsupported_audio_format"
    case audioDecodeFailed = "audio_decode_failed"
    case rateLimited = "rate_limited"
    case quotaExceeded = "quota_exceeded"
    case invalidEmbeddingResponse = "invalid_embedding_response"
}

public enum AIProviderProbeSource: String, Codable, Sendable {
    case draft
    case savedProfile = "saved_profile"
}

public enum AIProviderProbeCapability: String, Codable, CaseIterable, Sendable {
    case textReply = "text_reply"
    case structuredJSON = "structured_json"
    case languageSupport = "language_support"
    case imageUnderstanding = "image_understanding"
    case speechSynthesis = "speech_synthesis"
    case embedding
}

public struct AIProviderProbeLanguageContext: Equatable, Sendable {
    public var languageCode: String

    public init(languageCode: String) {
        self.languageCode = languageCode
    }
}

public enum AIProviderProbeCapabilityStatus: String, Codable, Sendable {
    case notConfigured = "not_configured"
    case notEnabled = "not_enabled"
    case testing
    case succeeded
    case failed
    case cancelled
    case unsupported
    case notRun = "not_run"
}

public struct AIProviderEndpointProbeMetadata: Equatable, Sendable {
    public var endpointID: AIProviderEndpointID
    public var endpointPurpose: AIProviderEndpointPurpose
    public var providerPresetID: String
    public var modelName: String
    public var configurationFingerprint: String?

    public init(
        endpointID: AIProviderEndpointID,
        endpointPurpose: AIProviderEndpointPurpose,
        providerPresetID: String,
        modelName: String,
        configurationFingerprint: String? = nil
    ) {
        self.endpointID = endpointID
        self.endpointPurpose = endpointPurpose
        self.providerPresetID = providerPresetID
        self.modelName = modelName
        self.configurationFingerprint = configurationFingerprint
    }
}

public struct AIProviderConfigurationProbeDescriptor: Equatable, Sendable {
    public var source: AIProviderProbeSource
    public var requestedCapabilities: [AIProviderProbeCapability]
    public var operationID: DiagnosticOperationID

    public init(
        source: AIProviderProbeSource,
        requestedCapabilities: [AIProviderProbeCapability],
        operationID: DiagnosticOperationID
    ) {
        self.source = source
        self.requestedCapabilities = requestedCapabilities
        self.operationID = operationID
    }
}

public struct AIProviderProbeCapabilityResult: Equatable, Sendable {
    public var capability: AIProviderProbeCapability
    public var status: AIProviderProbeCapabilityStatus
    public var errorCategory: AIProviderValidationErrorCategory?
    public var durationMilliseconds: Int?
    public var endpointMetadata: AIProviderEndpointProbeMetadata?
    public var languageSupportFailureReason: String?
    public var audioMetadata: TTSAudioMetadata?
    public var audioPreviewResource: TTSAudioPreviewResource?

    public init(
        capability: AIProviderProbeCapability,
        status: AIProviderProbeCapabilityStatus,
        errorCategory: AIProviderValidationErrorCategory?,
        durationMilliseconds: Int?,
        endpointMetadata: AIProviderEndpointProbeMetadata? = nil,
        languageSupportFailureReason: String? = nil,
        audioMetadata: TTSAudioMetadata? = nil,
        audioPreviewResource: TTSAudioPreviewResource? = nil
    ) {
        self.capability = capability
        self.status = status
        self.errorCategory = errorCategory
        self.durationMilliseconds = durationMilliseconds
        self.endpointMetadata = endpointMetadata
        self.languageSupportFailureReason = languageSupportFailureReason
        self.audioMetadata = audioMetadata
        self.audioPreviewResource = audioPreviewResource
    }
}

public struct AIProviderProfileProbeResult: Equatable, Sendable {
    public var source: AIProviderProbeSource
    public var overallStatus: AIProviderValidationStatus
    public var profileID: AIProviderProfileID?
    public var capabilities: [AIProviderProbeCapabilityResult]
    public var persistedValidationEventIDs: [AIProviderValidationEventID]

    public init(
        source: AIProviderProbeSource,
        overallStatus: AIProviderValidationStatus,
        profileID: AIProviderProfileID?,
        capabilities: [AIProviderProbeCapabilityResult],
        persistedValidationEventIDs: [AIProviderValidationEventID]
    ) {
        self.source = source
        self.overallStatus = overallStatus
        self.profileID = profileID
        self.capabilities = capabilities
        self.persistedValidationEventIDs = persistedValidationEventIDs
    }
}

public struct AIProviderConfigurationProbeResult: Equatable, Sendable {
    public var source: AIProviderProbeSource
    public var overallStatus: AIProviderValidationStatus
    public var providerPresetID: String
    public var modelName: String
    public var capabilities: [AIProviderProbeCapabilityResult]
    public var persistedValidationEventID: AIProviderValidationEventID?

    public init(
        source: AIProviderProbeSource,
        overallStatus: AIProviderValidationStatus,
        providerPresetID: String,
        modelName: String,
        capabilities: [AIProviderProbeCapabilityResult],
        persistedValidationEventID: AIProviderValidationEventID?
    ) {
        self.source = source
        self.overallStatus = overallStatus
        self.providerPresetID = providerPresetID
        self.modelName = modelName
        self.capabilities = capabilities
        self.persistedValidationEventID = persistedValidationEventID
    }
}

public struct AIProviderConfigurationProfile: Equatable, Sendable {
    public var id: AIProviderProfileID
    public var displayName: String
    public var isDefault: Bool
    public var status: AIProviderProfileStatus
    public var createdAt: Date
    public var updatedAt: Date
    public var lastValidatedAt: Date?
    public var lastValidationStatus: AIProviderValidationStatus?
    public var deletedAt: Date?
    public var endpoints: [AIProviderEndpointConfiguration]
    public var credentials: [AIProviderCredentialMetadata]

    public init(
        id: AIProviderProfileID,
        displayName: String,
        isDefault: Bool,
        status: AIProviderProfileStatus,
        createdAt: Date,
        updatedAt: Date,
        lastValidatedAt: Date? = nil,
        lastValidationStatus: AIProviderValidationStatus? = nil,
        deletedAt: Date? = nil,
        endpoints: [AIProviderEndpointConfiguration] = [],
        credentials: [AIProviderCredentialMetadata] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.isDefault = isDefault
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastValidatedAt = lastValidatedAt
        self.lastValidationStatus = lastValidationStatus
        self.deletedAt = deletedAt
        self.endpoints = endpoints
        self.credentials = credentials
    }
}

public struct AIProviderEndpointInput: Equatable, Sendable {
    public var id: AIProviderEndpointID
    public var profileID: AIProviderProfileID
    public var purpose: AIProviderEndpointPurpose
    public var isEnabled: Bool
    public var providerPresetID: String
    public var adapterKind: AIProviderAdapterKind
    public var baseURL: String
    public var modelName: String
    public var credentialID: AIProviderCredentialID?
    public var supportsImageInput: Bool
    public var imageInputEnabled: Bool
    public var requestTimeoutSeconds: Double?

    public init(
        id: AIProviderEndpointID,
        profileID: AIProviderProfileID,
        purpose: AIProviderEndpointPurpose,
        isEnabled: Bool,
        providerPresetID: String,
        adapterKind: AIProviderAdapterKind,
        baseURL: String,
        modelName: String,
        credentialID: AIProviderCredentialID?,
        supportsImageInput: Bool,
        imageInputEnabled: Bool,
        requestTimeoutSeconds: Double? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.purpose = purpose
        self.isEnabled = isEnabled
        self.providerPresetID = providerPresetID
        self.adapterKind = adapterKind
        self.baseURL = baseURL
        self.modelName = modelName
        self.credentialID = credentialID
        self.supportsImageInput = supportsImageInput
        self.imageInputEnabled = imageInputEnabled
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }

    public func normalized() throws -> AIProviderEndpointInput {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty, !trimmedModelName.isEmpty else {
            throw AIProviderConfigurationError.missingRequiredEndpointField
        }
        guard Self.isAllowedBaseURL(trimmedBaseURL) else {
            throw AIProviderConfigurationError.invalidBaseURL
        }

        var normalized = self
        normalized.baseURL = trimmedBaseURL
        normalized.modelName = trimmedModelName
        if normalized.purpose != .textGeneration {
            normalized.supportsImageInput = false
            normalized.imageInputEnabled = false
        }
        return normalized
    }

    public var configurationFingerprint: String {
        AIProviderEndpointConfigurationFingerprint.make(EndpointFingerprintFields(
            purpose: purpose.rawValue,
            providerPresetID: providerPresetID,
            adapterKind: adapterKind.rawValue,
            baseURL: baseURL,
            modelName: modelName,
            credentialID: credentialID,
            requestTimeoutSeconds: requestTimeoutSeconds,
            supportsImageInput: supportsImageInput,
            imageInputEnabled: imageInputEnabled
        ))
    }
}

public struct AIProviderProfileSaveInput: Equatable, Sendable {
    public var profileID: AIProviderProfileID?
    public var displayName: String
    public var endpoints: [AIProviderEndpointSaveInput]
    public var ttsVoiceProfile: TTSVoiceProfileSaveInput?

    public init(
        profileID: AIProviderProfileID? = nil,
        displayName: String,
        endpoints: [AIProviderEndpointSaveInput],
        ttsVoiceProfile: TTSVoiceProfileSaveInput? = nil
    ) {
        self.profileID = profileID
        self.displayName = displayName
        self.endpoints = endpoints
        self.ttsVoiceProfile = ttsVoiceProfile
    }
}

public struct AIProviderEndpointSaveInput: Equatable, Sendable {
    public var id: AIProviderEndpointID?
    public var purpose: AIProviderEndpointPurpose
    public var isEnabled: Bool
    public var providerPresetID: String
    public var adapterKind: AIProviderAdapterKind
    public var baseURL: String
    public var modelName: String
    public var credentialMode: AIProviderEndpointCredentialSaveMode
    public var supportsImageInput: Bool
    public var imageInputEnabled: Bool
    public var requestTimeoutSeconds: Double?

    public init(
        id: AIProviderEndpointID? = nil,
        purpose: AIProviderEndpointPurpose,
        isEnabled: Bool,
        providerPresetID: String,
        adapterKind: AIProviderAdapterKind,
        baseURL: String,
        modelName: String,
        credentialMode: AIProviderEndpointCredentialSaveMode,
        supportsImageInput: Bool,
        imageInputEnabled: Bool,
        requestTimeoutSeconds: Double? = nil
    ) {
        self.id = id
        self.purpose = purpose
        self.isEnabled = isEnabled
        self.providerPresetID = providerPresetID
        self.adapterKind = adapterKind
        self.baseURL = baseURL
        self.modelName = modelName
        self.credentialMode = credentialMode
        self.supportsImageInput = supportsImageInput
        self.imageInputEnabled = imageInputEnabled
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }
}

public enum AIProviderEndpointCredentialSaveMode: Equatable, Sendable {
    case none
    case existing(AIProviderCredentialID)
    case sharedWithPurpose(AIProviderEndpointPurpose)
    case newSecret(AIProviderCredentialSecretSaveInput)
}

public struct AIProviderCredentialSecretSaveInput: Equatable, Sendable {
    public var kind: AIProviderCredentialKind
    public var label: String
    public var plaintextSecret: RedactedSecret

    public init(
        kind: AIProviderCredentialKind,
        label: String,
        plaintextSecret: RedactedSecret
    ) {
        self.kind = kind
        self.label = label
        self.plaintextSecret = plaintextSecret
    }
}

public struct AIProviderEndpointConfiguration: Equatable, Sendable {
    public var id: AIProviderEndpointID
    public var profileID: AIProviderProfileID
    public var purpose: AIProviderEndpointPurpose
    public var isEnabled: Bool
    public var providerPresetID: String
    public var adapterKind: AIProviderAdapterKind
    public var baseURL: String
    public var modelName: String
    public var credentialID: AIProviderCredentialID?
    public var supportsImageInput: Bool
    public var imageInputEnabled: Bool
    public var requestTimeoutSeconds: Double?
    public var lastValidatedAt: Date?
    public var lastValidationStatus: AIProviderValidationStatus?
    public var lastValidationErrorCategory: AIProviderValidationErrorCategory?
    public var lastSuccessfulConfigurationFingerprint: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        input: AIProviderEndpointInput,
        createdAt: Date,
        updatedAt: Date,
        lastValidatedAt: Date? = nil,
        lastValidationStatus: AIProviderValidationStatus? = nil,
        lastValidationErrorCategory: AIProviderValidationErrorCategory? = nil,
        lastSuccessfulConfigurationFingerprint: String? = nil
    ) throws {
        let normalized = try input.normalized()
        id = normalized.id
        profileID = normalized.profileID
        purpose = normalized.purpose
        isEnabled = normalized.isEnabled
        providerPresetID = normalized.providerPresetID
        adapterKind = normalized.adapterKind
        baseURL = normalized.baseURL
        modelName = normalized.modelName
        credentialID = normalized.credentialID
        supportsImageInput = normalized.supportsImageInput
        imageInputEnabled = normalized.imageInputEnabled
        requestTimeoutSeconds = normalized.requestTimeoutSeconds
        self.lastValidatedAt = lastValidatedAt
        self.lastValidationStatus = lastValidationStatus
        self.lastValidationErrorCategory = lastValidationErrorCategory
        self.lastSuccessfulConfigurationFingerprint = lastSuccessfulConfigurationFingerprint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var configurationFingerprint: String {
        AIProviderEndpointConfigurationFingerprint.make(EndpointFingerprintFields(
            purpose: purpose.rawValue,
            providerPresetID: providerPresetID,
            adapterKind: adapterKind.rawValue,
            baseURL: baseURL,
            modelName: modelName,
            credentialID: credentialID,
            requestTimeoutSeconds: requestTimeoutSeconds,
            supportsImageInput: supportsImageInput,
            imageInputEnabled: imageInputEnabled
        ))
    }
}

public struct AIProviderCredentialMetadata: Equatable, Sendable {
    public static let defaultKeychainService = "com.langotrace.ai-provider"

    public var id: AIProviderCredentialID
    public var profileID: AIProviderProfileID
    public var providerPresetID: String
    public var kind: AIProviderCredentialKind
    public var label: String
    public var keychainService: String
    public var keychainAccount: String
    public var keychainAccessGroup: String?
    public var keychainSynchronizable: Bool
    public var keychainAccessibility: String
    public var secretPresence: AIProviderSecretPresence
    public var cleanupState: AIProviderCredentialCleanupState
    public var createdAt: Date
    public var updatedAt: Date
    public var lastResolvedAt: Date?
    public var deletedAt: Date?

    public init(
        id: AIProviderCredentialID,
        profileID: AIProviderProfileID,
        providerPresetID: String,
        kind: AIProviderCredentialKind,
        label: String,
        keychainService: String = AIProviderCredentialMetadata.defaultKeychainService,
        keychainAccessGroup: String? = nil,
        keychainSynchronizable: Bool = false,
        keychainAccessibility: String = "when_unlocked_this_device_only",
        secretPresence: AIProviderSecretPresence = .unknown,
        cleanupState: AIProviderCredentialCleanupState = .active,
        createdAt: Date,
        updatedAt: Date,
        lastResolvedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.providerPresetID = providerPresetID
        self.kind = kind
        self.label = label
        self.keychainService = keychainService
        keychainAccount = Self.keychainAccount(credentialID: id, kind: kind)
        self.keychainAccessGroup = keychainAccessGroup
        self.keychainSynchronizable = keychainSynchronizable
        self.keychainAccessibility = keychainAccessibility
        self.secretPresence = secretPresence
        self.cleanupState = cleanupState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastResolvedAt = lastResolvedAt
        self.deletedAt = deletedAt
    }

    public static func keychainAccount(
        credentialID: AIProviderCredentialID,
        kind: AIProviderCredentialKind
    ) -> String {
        "ai-provider-credential:\(credentialID):\(kind.rawValue)"
    }
}

public struct AIProviderCustomHeaderConfiguration: Equatable, Sendable {
    public var id: String
    public var endpointID: AIProviderEndpointID
    public var headerName: String
    public var valueKind: AIProviderCustomHeaderValueKind
    public var plainValue: String?
    public var credentialID: AIProviderCredentialID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        endpointID: AIProviderEndpointID,
        headerName: String,
        valueKind: AIProviderCustomHeaderValueKind,
        plainValue: String? = nil,
        credentialID: AIProviderCredentialID? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.endpointID = endpointID
        self.headerName = headerName
        self.valueKind = valueKind
        self.plainValue = plainValue
        self.credentialID = credentialID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AIProviderValidationEvent: Equatable, Sendable {
    public var id: AIProviderValidationEventID
    public var profileID: AIProviderProfileID
    public var endpointID: AIProviderEndpointID?
    public var eventType: AIProviderValidationEventType
    public var status: AIProviderValidationStatus
    public var errorCategory: AIProviderValidationErrorCategory?
    public var providerPresetID: String
    public var modelName: String?
    public var durationMilliseconds: Int?
    public var createdAt: Date

    public init(
        id: AIProviderValidationEventID,
        profileID: AIProviderProfileID,
        endpointID: AIProviderEndpointID?,
        eventType: AIProviderValidationEventType,
        status: AIProviderValidationStatus,
        errorCategory: AIProviderValidationErrorCategory?,
        providerPresetID: String,
        modelName: String?,
        durationMilliseconds: Int?,
        createdAt: Date
    ) {
        self.id = id
        self.profileID = profileID
        self.endpointID = endpointID
        self.eventType = eventType
        self.status = status
        self.errorCategory = errorCategory
        self.providerPresetID = providerPresetID
        self.modelName = modelName
        self.durationMilliseconds = durationMilliseconds
        self.createdAt = createdAt
    }
}

public struct AIProviderEndpointValidationOutcome: Equatable, Sendable {
    public var event: AIProviderValidationEvent
    public var configurationFingerprint: String

    public init(
        event: AIProviderValidationEvent,
        configurationFingerprint: String
    ) {
        self.event = event
        self.configurationFingerprint = configurationFingerprint
    }
}

public protocol AIProviderConfigurationRepository: Sendable {
    func loadDefaultProfile() async throws -> AIProviderConfigurationProfile?
    func saveProfile(_ profile: AIProviderConfigurationProfile) async throws
    func saveProfile(
        _ profile: AIProviderConfigurationProfile,
        ttsSettings: TTSProviderSettings?,
        ttsVoiceProfiles: [TTSVoiceProfile]
    ) async throws
    func markCredentialState(
        _ state: AIProviderSecretPresence,
        credentialID: AIProviderCredentialID
    ) async throws
    func recordValidationEvent(_ event: AIProviderValidationEvent) async throws
    func recordValidationOutcome(_ event: AIProviderValidationEvent) async throws
    func recordEndpointValidationOutcome(_ outcome: AIProviderEndpointValidationOutcome) async throws
    func loadTTSSettings(endpointID: AIProviderEndpointID) async throws -> TTSProviderSettings?
    func loadTTSVoiceProfile(
        endpointID: AIProviderEndpointID,
        languageCode: String
    ) async throws -> TTSVoiceProfile?
    func recordTTSVoiceProfileProbeOutcome(
        _ event: AIProviderValidationEvent,
        languageCode: String
    ) async throws
}

public extension AIProviderConfigurationRepository {
    func saveProfile(
        _ profile: AIProviderConfigurationProfile,
        ttsSettings _: TTSProviderSettings?,
        ttsVoiceProfiles _: [TTSVoiceProfile]
    ) async throws {
        try await saveProfile(profile)
    }

    func recordValidationOutcome(_ event: AIProviderValidationEvent) async throws {
        try await recordValidationEvent(event)
    }

    func recordEndpointValidationOutcome(_ outcome: AIProviderEndpointValidationOutcome) async throws {
        try await recordValidationEvent(outcome.event)
    }

    func recordTTSVoiceProfileProbeOutcome(
        _ event: AIProviderValidationEvent,
        languageCode _: String
    ) async throws {
        try await recordValidationEvent(event)
    }
}

private enum AIProviderEndpointConfigurationFingerprint {
    static func make(_ fields: EndpointFingerprintFields) -> String {
        let parts = [
            "v1",
            fields.purpose,
            fields.providerPresetID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            fields.adapterKind,
            fields.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            fields.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            fields.credentialID ?? "none",
            fields.requestTimeoutSeconds.map { String(format: "%.3f", $0) } ?? "default",
            fields.supportsImageInput ? "image-supported" : "image-unsupported",
            fields.imageInputEnabled ? "image-enabled" : "image-disabled",
        ].joined(separator: "\u{1F}")
        return "endpoint-v1-\(StableHashing.fnv1a64Hex(parts))"
    }
}

private struct EndpointFingerprintFields {
    var purpose: String
    var providerPresetID: String
    var adapterKind: String
    var baseURL: String
    var modelName: String
    var credentialID: String?
    var requestTimeoutSeconds: Double?
    var supportsImageInput: Bool
    var imageInputEnabled: Bool
}

private extension AIProviderEndpointInput {
    static func isAllowedBaseURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil
        else {
            return false
        }

        if scheme == "https" {
            return true
        }

        if scheme == "http" {
            return ["localhost", "127.0.0.1", "::1"].contains(host)
        }

        return false
    }
}
