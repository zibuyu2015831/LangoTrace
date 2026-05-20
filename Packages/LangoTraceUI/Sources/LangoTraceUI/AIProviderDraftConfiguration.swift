import Foundation
import LangoTraceCore

enum AIProviderAPIKeyStorage: Equatable {
    case encryptedStoragePending
    case keychainUnavailableInMock
}

enum AIProviderCredentialReference: Equatable {
    case textModelCredential
    case independent
}

enum AIProviderTestReadiness: Equatable {
    case missingRequiredFields
    case readyForRequest
}

public struct AIProviderDraftProbeSnapshot: Sendable {
    public var source: AIProviderProbeSource
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?
    public var requestedCapabilities: [AIProviderProbeCapability]
    public var operationID: DiagnosticOperationID
}

enum AIProviderTextProbeSource: Equatable {
    case draft
    case savedProfile
}

enum AIProviderSaveState: Equatable {
    case idle
    case missingRequiredFields
    case unsavedChanges
    case saving
    case saved
    case failed(AIProviderSaveFailureDisplay)

    var titleKey: String {
        switch self {
        case .idle:
            "aiProviderSettings.saveState.idle"
        case .missingRequiredFields:
            "aiProviderSettings.saveState.missingRequiredFields"
        case .unsavedChanges:
            "aiProviderSettings.saveState.unsavedChanges"
        case .saving:
            "aiProviderSettings.saveState.saving"
        case .saved:
            "aiProviderSettings.saveState.saved"
        case .failed:
            "aiProviderSettings.saveState.failed"
        }
    }
}

struct AIProviderSaveFailureDisplay: Equatable {
    var phase: AIProviderConfigurationSavePhase
    var category: AIProviderConfigurationSaveFailureCategory

    init(
        phase: AIProviderConfigurationSavePhase = .unknown,
        category: AIProviderConfigurationSaveFailureCategory = .unknown
    ) {
        self.phase = phase
        self.category = category
    }

    init(error: Error) {
        if let failure = error as? AIProviderConfigurationSaveFailure {
            phase = failure.phase
            category = failure.category
        } else if let error = error as? AIProviderConfigurationError {
            switch error {
            case .missingRequiredEndpointField:
                phase = .inputValidation
                category = .missingRequiredEndpointField
            case .invalidBaseURL, .unsupportedCapabilityForProvider:
                phase = .inputValidation
                category = .invalidBaseURL
            case .missingRequiredAPIKey:
                phase = .inputValidation
                category = .missingRequiredAPIKey
            case .keychainWriteFailed:
                phase = .keychainWrite
                category = .keychainWriteFailed
            case .databaseWriteFailed:
                phase = .databaseWrite
                category = .databaseWriteFailed
            case .orphanedCredentialCleanupFailed:
                phase = .credentialCleanup
                category = .credentialCleanupFailed
            }
        } else {
            phase = .unknown
            category = .unknown
        }
    }
}

enum AIProviderTestState: Equatable {
    case idle
    case missingRequiredFields
    case testing
    case succeeded(AIProviderConfigurationProbeResult)
    case partial(AIProviderConfigurationProbeResult)
    case failed(AIProviderValidationErrorCategory?, AIProviderConfigurationProbeResult?)
    case unsupportedProvider(AIProviderConfigurationProbeResult?)

    var titleKey: String {
        switch self {
        case .idle:
            "aiProviderSettings.testState.idle"
        case .missingRequiredFields:
            "aiProviderSettings.testState.missingRequiredFields"
        case .testing:
            "aiProviderSettings.testState.testing"
        case .succeeded:
            "aiProviderSettings.testState.succeeded"
        case .partial:
            "aiProviderSettings.testState.partial"
        case .failed:
            "aiProviderSettings.testState.failed"
        case .unsupportedProvider:
            "aiProviderSettings.testState.unsupportedProvider"
        }
    }
}

struct AIProviderCredentialDraftConfiguration: Equatable {
    var provider: AIProviderPreset
    var apiKeyDraft: String
    var requiresAPIKey: Bool
    var apiKeyStorage: AIProviderAPIKeyStorage

    init(provider: AIProviderPreset) {
        self.provider = provider
        apiKeyDraft = ""
        requiresAPIKey = provider.requiresAPIKey
        apiKeyStorage = .encryptedStoragePending
    }

    var isComplete: Bool {
        !requiresAPIKey || !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func updateProvider(_ provider: AIProviderPreset) {
        self.provider = provider
        requiresAPIKey = provider.requiresAPIKey
        apiKeyDraft = ""
    }
}

struct AIProviderEndpointDraftConfiguration: Equatable {
    var id: AIProviderEndpointID?
    var credentialID: AIProviderCredentialID?
    var provider: AIProviderPreset
    var baseURL: String
    var model: String
    var credentialReference: AIProviderCredentialReference
    var independentCredential: AIProviderCredentialDraftConfiguration

    init(
        provider: AIProviderPreset,
        model: String,
        credentialReference: AIProviderCredentialReference = .independent
    ) {
        id = nil
        credentialID = nil
        self.provider = provider
        baseURL = provider.defaultBaseURL
        self.model = model
        self.credentialReference = credentialReference
        independentCredential = AIProviderCredentialDraftConfiguration(provider: provider)
    }

    var hasBaseURLAndModel: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func updateProvider(
        _ provider: AIProviderPreset,
        defaultModel: String,
        credentialReference: AIProviderCredentialReference
    ) {
        self.provider = provider
        baseURL = provider.defaultBaseURL
        model = defaultModel
        self.credentialReference = credentialReference
        independentCredential.updateProvider(provider)
    }
}

struct AITextModelDraftConfiguration: Equatable {
    var endpoint: AIProviderEndpointDraftConfiguration
    var textGenerationEnabled: Bool
    var imageUnderstandingEnabled: Bool

    init(provider: AIProviderPreset) {
        endpoint = AIProviderEndpointDraftConfiguration(provider: provider, model: provider.defaultTextModel)
        textGenerationEnabled = true
        imageUnderstandingEnabled = false
    }

    var isComplete: Bool {
        endpoint.hasBaseURLAndModel && endpoint.independentCredential.isComplete
    }

    mutating func updateProvider(_ provider: AIProviderPreset) {
        endpoint.updateProvider(
            provider,
            defaultModel: provider.defaultTextModel,
            credentialReference: .independent
        )
        if !provider.capabilities.imageUnderstanding {
            imageUnderstandingEnabled = false
        }
    }
}

enum AIOptionalModelPurpose: Equatable {
    case speech
    case embedding

    func defaultModel(for provider: AIProviderPreset) -> String {
        switch self {
        case .speech:
            provider.defaultSpeechModel
        case .embedding:
            provider.defaultEmbeddingModel
        }
    }
}

struct AIOptionalModelDraftConfiguration: Equatable {
    var isEnabled: Bool
    var endpoint: AIProviderEndpointDraftConfiguration
    let purpose: AIOptionalModelPurpose

    init(provider: AIProviderPreset, purpose: AIOptionalModelPurpose) {
        isEnabled = false
        self.purpose = purpose
        endpoint = AIProviderEndpointDraftConfiguration(
            provider: provider,
            model: purpose.defaultModel(for: provider),
            credentialReference: .textModelCredential
        )
    }

    var isCompleteWithSharedCredential: Bool {
        !isEnabled || endpoint.hasBaseURLAndModel
    }

    func isComplete(textCredential: AIProviderCredentialDraftConfiguration) -> Bool {
        guard isEnabled, endpoint.hasBaseURLAndModel else {
            return !isEnabled
        }

        switch endpoint.credentialReference {
        case .textModelCredential:
            return textCredential.isComplete
        case .independent:
            return endpoint.independentCredential.isComplete
        }
    }

    mutating func updateProvider(
        _ provider: AIProviderPreset,
        shareTextCredentialWhenSameProvider: Bool
    ) {
        endpoint.updateProvider(
            provider,
            defaultModel: purpose.defaultModel(for: provider),
            credentialReference: shareTextCredentialWhenSameProvider ? .textModelCredential : .independent
        )
    }
}

struct AIProviderDraftConfiguration: Equatable {
    var profileID: AIProviderProfileID?
    var text: AITextModelDraftConfiguration
    var speech: AIOptionalModelDraftConfiguration
    var embedding: AIOptionalModelDraftConfiguration
    var saveState: AIProviderSaveState
    var testState: AIProviderTestState
    private var hasPersistedConfiguration: Bool

    init(provider: AIProviderPreset) {
        profileID = nil
        text = AITextModelDraftConfiguration(provider: provider)
        speech = AIOptionalModelDraftConfiguration(provider: provider, purpose: .speech)
        embedding = AIOptionalModelDraftConfiguration(provider: provider, purpose: .embedding)
        saveState = .idle
        testState = .idle
        hasPersistedConfiguration = false
    }

    var saveReadiness: AIProviderTestReadiness {
        let textCredential = text.endpoint.independentCredential
        let allEnabledConfigurationsComplete = text.isComplete &&
            speech.isComplete(textCredential: textCredential) &&
            embedding.isComplete(textCredential: textCredential)

        return allEnabledConfigurationsComplete ? .readyForRequest : .missingRequiredFields
    }

    var textProbeReadiness: AIProviderTestReadiness {
        guard text.endpoint.hasBaseURLAndModel else {
            return .missingRequiredFields
        }
        if textProbeSource == .savedProfile {
            return .readyForRequest
        }
        return text.endpoint.independentCredential.isComplete ? .readyForRequest : .missingRequiredFields
    }

    var textProbeSource: AIProviderTextProbeSource {
        if hasPersistedConfiguration, saveState != .unsavedChanges {
            return .savedProfile
        }
        return .draft
    }

    var testReadiness: AIProviderTestReadiness {
        saveReadiness
    }

    mutating func runMockTest() {
        guard textProbeReadiness == .readyForRequest else {
            testState = .missingRequiredFields
            return
        }

        testState = .testing
    }

    mutating func saveMockConfiguration() {
        guard saveReadiness == .readyForRequest else {
            saveState = .missingRequiredFields
            return
        }

        hasPersistedConfiguration = true
        saveState = .saved
    }

    func makeProfileSaveInput() throws -> AIProviderProfileSaveInput {
        guard saveReadiness == .readyForRequest else {
            throw AIProviderConfigurationError.missingRequiredEndpointField
        }

        var endpoints = try [
            text.endpoint.makeSaveInput(
                purpose: .textGeneration,
                isEnabled: text.textGenerationEnabled,
                credentialMode: text.endpoint.makeNewSecretCredentialMode(),
                imageInputEnabled: text.imageUnderstandingEnabled
            ),
        ]

        if speech.isEnabled {
            try endpoints.append(
                speech.endpoint.makeSaveInput(
                    purpose: .tts,
                    isEnabled: true,
                    credentialMode: speech.endpoint.makeCredentialMode(),
                    imageInputEnabled: false
                )
            )
        }

        if embedding.isEnabled {
            try endpoints.append(
                embedding.endpoint.makeSaveInput(
                    purpose: .embedding,
                    isEnabled: true,
                    credentialMode: embedding.endpoint.makeCredentialMode(),
                    imageInputEnabled: false
                )
            )
        }

        return AIProviderProfileSaveInput(
            profileID: profileID,
            displayName: "Default AI Provider",
            endpoints: endpoints
        )
    }

    func makeTextProbeDraftSnapshot(operationID: DiagnosticOperationID) throws -> AIProviderDraftProbeSnapshot {
        guard textProbeReadiness == .readyForRequest else {
            throw AIProviderConfigurationError.missingRequiredEndpointField
        }
        let endpoint = try AIProviderEndpointInput(
            id: text.endpoint.id ?? "draft-text-endpoint",
            profileID: profileID ?? "draft-profile",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: text.endpoint.provider.id,
            adapterKind: text.endpoint.provider.coreAdapterKind,
            baseURL: text.endpoint.baseURL,
            modelName: text.endpoint.model,
            credentialID: text.endpoint.credentialID ?? "draft-text-credential",
            supportsImageInput: text.endpoint.provider.capabilities.imageUnderstanding,
            imageInputEnabled: text.imageUnderstandingEnabled && text.endpoint.provider.capabilities.imageUnderstanding
        ).normalized()
        return AIProviderDraftProbeSnapshot(
            source: .draft,
            endpoint: endpoint,
            plaintextSecret: text.endpoint.independentCredential.requiresAPIKey
                ? text.endpoint.independentCredential.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil,
            requestedCapabilities: [.textReply, .structuredJSON],
            operationID: operationID
        )
    }

    mutating func applySavedProfile(_ profile: AIProviderConfigurationProfile) {
        profileID = profile.id
        applyEndpointIdentities(from: profile)
        clearPlaintextSecrets()
        hasPersistedConfiguration = true
        saveState = .saved
        testState = .idle
    }

    mutating func applyLoadedProfile(
        _ profile: AIProviderConfigurationProfile,
        resolvedSecretsByCredentialID: [AIProviderCredentialID: String] = [:]
    ) {
        profileID = profile.id
        let textEndpoint = profile.endpoints.first { $0.purpose == .textGeneration }
        let speechEndpoint = profile.endpoints.first { $0.purpose == .tts }
        let embeddingEndpoint = profile.endpoints.first { $0.purpose == .embedding }
        let textCredentialID = textEndpoint?.credentialID

        if let textEndpoint {
            text.endpoint.apply(endpoint: textEndpoint)
            text.imageUnderstandingEnabled = textEndpoint.imageInputEnabled
        }

        if let speechEndpoint {
            speech.isEnabled = speechEndpoint.isEnabled
            speech.endpoint.apply(
                endpoint: speechEndpoint,
                sharedCredentialID: textCredentialID
            )
        }

        if let embeddingEndpoint {
            embedding.isEnabled = embeddingEndpoint.isEnabled
            embedding.endpoint.apply(
                endpoint: embeddingEndpoint,
                sharedCredentialID: textCredentialID
            )
        }

        clearPlaintextSecrets()
        applyResolvedSecrets(resolvedSecretsByCredentialID)
        hasPersistedConfiguration = profile.status == .configured
        saveState = .idle
        testState = .idle
    }

    mutating func applyEndpointIdentities(from profile: AIProviderConfigurationProfile) {
        text.endpoint.id = profile.endpoints.first { $0.purpose == .textGeneration }?.id
        speech.endpoint.id = profile.endpoints.first { $0.purpose == .tts }?.id
        embedding.endpoint.id = profile.endpoints.first { $0.purpose == .embedding }?.id
    }

    mutating func markInputChanged() {
        switch saveState {
        case .idle, .saved, .failed:
            saveState = hasPersistedConfiguration ? .unsavedChanges : .idle
        case .missingRequiredFields, .unsavedChanges, .saving:
            break
        }
        testState = .idle
    }

    @discardableResult
    mutating func markInputChanged<Value: Equatable>(from oldValue: Value, to newValue: Value) -> Bool {
        guard oldValue != newValue else {
            return false
        }
        markInputChanged()
        return true
    }

    mutating func clearPlaintextSecrets() {
        text.endpoint.independentCredential.apiKeyDraft = ""
        speech.endpoint.independentCredential.apiKeyDraft = ""
        embedding.endpoint.independentCredential.apiKeyDraft = ""
    }

    mutating func applyResolvedSecrets(_ secretsByCredentialID: [AIProviderCredentialID: String]) {
        if let credentialID = text.endpoint.credentialID,
           let secret = secretsByCredentialID[credentialID]
        {
            text.endpoint.independentCredential.apiKeyDraft = secret
        }

        if speech.endpoint.credentialReference == .independent,
           let credentialID = speech.endpoint.credentialID,
           let secret = secretsByCredentialID[credentialID]
        {
            speech.endpoint.independentCredential.apiKeyDraft = secret
        }

        if embedding.endpoint.credentialReference == .independent,
           let credentialID = embedding.endpoint.credentialID,
           let secret = secretsByCredentialID[credentialID]
        {
            embedding.endpoint.independentCredential.apiKeyDraft = secret
        }
    }
}

private extension AIProviderEndpointDraftConfiguration {
    mutating func apply(
        endpoint: AIProviderEndpointConfiguration,
        sharedCredentialID: AIProviderCredentialID? = nil
    ) {
        id = endpoint.id
        credentialID = endpoint.credentialID
        if let provider = AIProviderPreset.allCases.first(where: { $0.id == endpoint.providerPresetID }) {
            self.provider = provider
            independentCredential.updateProvider(provider)
        }
        baseURL = endpoint.baseURL
        model = endpoint.modelName
        if let sharedCredentialID, endpoint.credentialID == sharedCredentialID {
            credentialReference = .textModelCredential
        } else {
            credentialReference = .independent
        }
    }

    func makeSaveInput(
        purpose: LangoTraceCore.AIProviderEndpointPurpose,
        isEnabled: Bool,
        credentialMode: AIProviderEndpointCredentialSaveMode,
        imageInputEnabled: Bool
    ) throws -> AIProviderEndpointSaveInput {
        AIProviderEndpointSaveInput(
            id: id,
            purpose: purpose,
            isEnabled: isEnabled,
            providerPresetID: provider.id,
            adapterKind: provider.coreAdapterKind,
            baseURL: baseURL,
            modelName: model,
            credentialMode: credentialMode,
            supportsImageInput: provider.capabilities.imageUnderstanding,
            imageInputEnabled: imageInputEnabled && provider.capabilities.imageUnderstanding
        )
    }

    func makeCredentialMode() -> AIProviderEndpointCredentialSaveMode {
        switch credentialReference {
        case .textModelCredential:
            .sharedWithPurpose(.textGeneration)
        case .independent:
            makeNewSecretCredentialMode()
        }
    }

    func makeNewSecretCredentialMode() -> AIProviderEndpointCredentialSaveMode {
        guard independentCredential.requiresAPIKey else {
            return .none
        }
        return .newSecret(
            AIProviderCredentialSecretSaveInput(
                kind: .apiKey,
                label: "\(provider.displayName) API Key",
                plaintextSecret: independentCredential.apiKeyDraft
            )
        )
    }
}

private extension AIProviderPreset {
    var coreAdapterKind: LangoTraceCore.AIProviderAdapterKind {
        switch adapterKind {
        case .openAICompatibleChat:
            .openAICompatibleChat
        case .openAIResponses:
            .openAIResponses
        case .anthropicMessages:
            .anthropicMessages
        case .geminiGenerateContent:
            .geminiGenerateContent
        }
    }
}
