import Foundation

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
    case mockSavedSecurely

    var titleKey: String {
        switch self {
        case .idle:
            "aiProviderSettings.saveState.idle"
        case .missingRequiredFields:
            "aiProviderSettings.saveState.missingRequiredFields"
        case .mockSavedSecurely:
            "aiProviderSettings.saveState.mockSavedSecurely"
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

    init(provider: AIProviderPreset) {
        text = AITextModelDraftConfiguration(provider: provider)
        speech = AIOptionalModelDraftConfiguration(provider: provider, purpose: .speech)
        embedding = AIOptionalModelDraftConfiguration(provider: provider, purpose: .embedding)
        saveState = .idle
        testState = .idle
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

        saveState = .mockSavedSecurely
    }
}
