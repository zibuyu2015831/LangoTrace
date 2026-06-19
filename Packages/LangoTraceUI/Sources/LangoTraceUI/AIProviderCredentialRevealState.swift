import Foundation

enum AIProviderCredentialRevealFailure: Equatable {
    case missingCredential
    case credentialInaccessible
    case userInteractionRequired
    case cancelled

    var messageKey: String {
        switch self {
        case .missingCredential:
            "aiProviderSettings.apiKey.revealError.missingCredential"
        case .credentialInaccessible:
            "aiProviderSettings.apiKey.revealError.credentialInaccessible"
        case .userInteractionRequired:
            "aiProviderSettings.apiKey.revealError.userInteractionRequired"
        case .cancelled:
            "aiProviderSettings.apiKey.revealError.cancelled"
        }
    }
}

enum AIProviderCredentialRevealResult: Equatable {
    case succeeded(String)
    case failed(AIProviderCredentialRevealFailure)
}

enum AIProviderCredentialRevealState: Equatable {
    case idle
    case authenticating
    case revealedVisible
    case revealedHidden
    case failed(AIProviderCredentialRevealFailure)
    case cancelled
}

struct AIProviderAPIKeyFieldPresentation: Equatable {
    var text: String
    var hasSavedCredential: Bool
    var revealState: AIProviderCredentialRevealState

    var placeholderKey: String {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              hasSavedCredential
        else {
            return "aiProviderSettings.apiKey.placeholder.unsaved"
        }
        return "aiProviderSettings.apiKey.placeholder.saved"
    }

    var helperKey: String? {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if !hasSavedCredential {
            return "aiProviderSettings.apiKey.helper.unsaved"
        }
        return revealFailure?.messageKey
    }

    var shouldResolveSavedCredential: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasSavedCredential
    }

    private var revealFailure: AIProviderCredentialRevealFailure? {
        switch revealState {
        case let .failed(failure):
            failure
        case .cancelled:
            .cancelled
        case .idle, .authenticating, .revealedVisible, .revealedHidden:
            nil
        }
    }
}
