import Foundation

enum AIProviderAPIKeyStorage: Equatable {
    case encryptedStoragePending
    case keychainUnavailableInMock
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

struct AIProviderDraftConfiguration: Equatable {
    var provider: AIProviderPreset {
        didSet {
            applyProviderDefaults()
        }
    }

    var displayName: String
    var baseURL: String
    var authHeaderKind: String
    var apiKeyDraft: String
    var chatModel: String
    var embeddingModel: String
    var ttsModel: String
    var adapterKind: AIProviderAdapterKind
    var capabilities: AIProviderCapabilitySet
    var customHeadersAllowed: Bool
    var apiKeyStorage: AIProviderAPIKeyStorage
    var saveState: AIProviderSaveState
    var testState: AIProviderTestState

    init(provider: AIProviderPreset) {
        self.provider = provider
        displayName = provider.displayName
        baseURL = provider.defaultBaseURL
        authHeaderKind = provider.authHeaderKind
        apiKeyDraft = ""
        chatModel = provider.defaultChatModel
        embeddingModel = provider.defaultEmbeddingModel
        ttsModel = provider.defaultTTSModel
        adapterKind = provider.adapterKind
        capabilities = provider.capabilities
        customHeadersAllowed = provider.capabilities.customHeaders
        apiKeyStorage = .encryptedStoragePending
        saveState = .idle
        testState = .idle
    }

    var testReadiness: AIProviderTestReadiness {
        let requiredFields = [
            baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            chatModel.trimmingCharacters(in: .whitespacesAndNewlines),
        ]

        return requiredFields.allSatisfy { !$0.isEmpty } ? .readyForMockRequest : .missingRequiredFields
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

    private mutating func applyProviderDefaults() {
        displayName = provider.displayName
        baseURL = provider.defaultBaseURL
        authHeaderKind = provider.authHeaderKind
        chatModel = provider.defaultChatModel
        embeddingModel = provider.defaultEmbeddingModel
        ttsModel = provider.defaultTTSModel
        adapterKind = provider.adapterKind
        capabilities = provider.capabilities
        customHeadersAllowed = provider.capabilities.customHeaders
        saveState = .idle
        testState = .idle
    }
}
