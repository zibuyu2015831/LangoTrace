import LangoTraceCore

public enum AIProviderCredentialStoreError: Error, Equatable, Sendable {
    case missingCredential
    case credentialInaccessible
    case credentialCorrupted
    case userInteractionRequired
}

public struct AIProviderSecretInput: Equatable, Sendable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

public struct AIProviderResolvedSecret: Equatable, Sendable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

public struct AIProviderCredentialKeychainReference: Equatable, Hashable, Sendable {
    public var credentialID: AIProviderCredentialID
    public var kind: AIProviderCredentialKind
    public var service: String
    public var account: String
    public var accessGroup: String?
    public var synchronizable: Bool
    public var accessibility: String

    public init(
        credentialID: AIProviderCredentialID,
        kind: AIProviderCredentialKind,
        service: String = AIProviderCredentialMetadata.defaultKeychainService,
        accessGroup: String? = nil,
        synchronizable: Bool = false,
        accessibility: String = "when_unlocked_this_device_only"
    ) {
        self.credentialID = credentialID
        self.kind = kind
        self.service = service
        account = AIProviderCredentialMetadata.keychainAccount(
            credentialID: credentialID,
            kind: kind
        )
        self.accessGroup = accessGroup
        self.synchronizable = synchronizable
        self.accessibility = accessibility
    }

    public init(metadata: AIProviderCredentialMetadata) {
        self.init(
            credentialID: metadata.id,
            kind: metadata.kind,
            service: metadata.keychainService,
            accessGroup: metadata.keychainAccessGroup,
            synchronizable: metadata.keychainSynchronizable,
            accessibility: metadata.keychainAccessibility
        )
    }
}

public protocol AIProviderCredentialStore: Sendable {
    func upsertSecret(
        _ secret: AIProviderSecretInput,
        for reference: AIProviderCredentialKeychainReference
    ) async throws
    func hasSecret(for reference: AIProviderCredentialKeychainReference) async -> AIProviderSecretPresence
    func resolveSecret(for reference: AIProviderCredentialKeychainReference) async throws -> AIProviderResolvedSecret
    func deleteSecret(for reference: AIProviderCredentialKeychainReference) async throws
}

public actor InMemoryAIProviderCredentialStore: AIProviderCredentialStore {
    private var secrets: [AIProviderCredentialKeychainReference: String] = [:]

    public init() {}

    public func upsertSecret(
        _ secret: AIProviderSecretInput,
        for reference: AIProviderCredentialKeychainReference
    ) throws {
        secrets[reference] = secret.value
    }

    public func hasSecret(for reference: AIProviderCredentialKeychainReference) -> AIProviderSecretPresence {
        secrets[reference] == nil ? .missing : .present
    }

    public func resolveSecret(
        for reference: AIProviderCredentialKeychainReference
    ) throws -> AIProviderResolvedSecret {
        guard let value = secrets[reference] else {
            throw AIProviderCredentialStoreError.missingCredential
        }
        return AIProviderResolvedSecret(value: value)
    }

    public func deleteSecret(for reference: AIProviderCredentialKeychainReference) {
        secrets[reference] = nil
    }
}

public struct AIProviderCredentialResolver: Sendable {
    private let store: any AIProviderCredentialStore

    public init(store: any AIProviderCredentialStore) {
        self.store = store
    }

    public func resolve(
        _ reference: AIProviderCredentialKeychainReference
    ) async throws -> AIProviderResolvedSecret {
        try await store.resolveSecret(for: reference)
    }
}
