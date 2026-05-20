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
    case readyForMockRequest
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
    case mockTesting
    case mockSucceeded
    case mockFailed
    case realTestingUnavailable

    var titleKey: String {
        switch self {
        case .idle:
            "aiProviderSettings.testState.idle"
        case .missingRequiredFields:
            "aiProviderSettings.testState.missingRequiredFields"
        case .mockTesting:
            "aiProviderSettings.testState.mockTesting"
        case .mockSucceeded:
            "aiProviderSettings.testState.mockSucceeded"
        case .mockFailed:
            "aiProviderSettings.testState.mockFailed"
        case .realTestingUnavailable:
            "aiProviderSettings.testState.realTestingUnavailable"
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
    var text: AITextModelDraftConfiguration
    var speech: AIOptionalModelDraftConfiguration
    var embedding: AIOptionalModelDraftConfiguration
    var saveState: AIProviderSaveState
    var testState: AIProviderTestState
    private var hasPersistedConfiguration: Bool

    init(provider: AIProviderPreset) {
        text = AITextModelDraftConfiguration(provider: provider)
        speech = AIOptionalModelDraftConfiguration(provider: provider, purpose: .speech)
        embedding = AIOptionalModelDraftConfiguration(provider: provider, purpose: .embedding)
        saveState = .idle
        testState = .idle
        hasPersistedConfiguration = false
    }

    var testReadiness: AIProviderTestReadiness {
        let textCredential = text.endpoint.independentCredential
        let allEnabledConfigurationsComplete = text.isComplete &&
            speech.isComplete(textCredential: textCredential) &&
            embedding.isComplete(textCredential: textCredential)

        return allEnabledConfigurationsComplete ? .readyForMockRequest : .missingRequiredFields
    }

    mutating func runMockTest() {
        guard testReadiness == .readyForMockRequest else {
            testState = .missingRequiredFields
            return
        }

        testState = .mockSucceeded
    }

    mutating func saveMockConfiguration() {
        guard testReadiness == .readyForMockRequest else {
            saveState = .missingRequiredFields
            return
        }

        hasPersistedConfiguration = true
        saveState = .saved
    }

    func makeProfileSaveInput() throws -> AIProviderProfileSaveInput {
        guard testReadiness == .readyForMockRequest else {
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
            displayName: "Default AI Provider",
            endpoints: endpoints
        )
    }

    mutating func applySavedProfile(_: AIProviderConfigurationProfile) {
        clearPlaintextSecrets()
        hasPersistedConfiguration = true
        saveState = .saved
        testState = .idle
    }

    mutating func applyLoadedProfile(_ profile: AIProviderConfigurationProfile) {
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
        hasPersistedConfiguration = profile.status == .configured
        saveState = .idle
        testState = .idle
    }

    mutating func markInputChanged() {
        switch saveState {
        case .idle, .saved, .failed:
            saveState = hasPersistedConfiguration ? .unsavedChanges : .idle
        case .missingRequiredFields, .unsavedChanges, .saving:
            break
        }
    }

    mutating func clearPlaintextSecrets() {
        text.endpoint.independentCredential.apiKeyDraft = ""
        speech.endpoint.independentCredential.apiKeyDraft = ""
        embedding.endpoint.independentCredential.apiKeyDraft = ""
    }
}

private extension AIProviderEndpointDraftConfiguration {
    mutating func apply(
        endpoint: AIProviderEndpointConfiguration,
        sharedCredentialID: AIProviderCredentialID? = nil
    ) {
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
