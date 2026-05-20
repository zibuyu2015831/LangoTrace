import Foundation
import LangoTraceCore

public struct AIProviderConfigurationService: Sendable {
    private let repository: any AIProviderConfigurationRepository
    private let credentialStore: (any AIProviderCredentialStore)?
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(repository: any AIProviderConfigurationRepository) {
        self.repository = repository
        credentialStore = nil
        clock = Date.init
        idGenerator = { UUID().uuidString }
    }

    public init(
        repository: any AIProviderConfigurationRepository,
        credentialStore: any AIProviderCredentialStore,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func loadDefaultProfile() async throws -> AIProviderConfigurationProfile? {
        try await repository.loadDefaultProfile()
    }

    public func validateEndpointInput(
        _ input: AIProviderEndpointInput
    ) throws -> AIProviderEndpointInput {
        try input.normalized()
    }

    public func saveDefaultProfile(
        _ input: AIProviderProfileSaveInput
    ) async throws -> AIProviderConfigurationProfile {
        guard let credentialStore else {
            throw AIProviderConfigurationError.keychainWriteFailed
        }

        let now = clock()
        var credentialsByPurpose: [AIProviderEndpointPurpose: AIProviderCredentialID] = [:]
        var credentials: [AIProviderCredentialMetadata] = []
        var endpoints: [AIProviderEndpointConfiguration] = []
        var createdReferences: [AIProviderCredentialKeychainReference] = []
        let profileID = input.profileID ?? idGenerator()

        do {
            for endpointInput in input.endpoints {
                let credentialID = try await credentialID(
                    for: endpointInput,
                    profileID: profileID,
                    at: now,
                    credentialsByPurpose: credentialsByPurpose,
                    credentials: &credentials,
                    createdReferences: &createdReferences,
                    credentialStore: credentialStore
                )
                let endpoint = try AIProviderEndpointConfiguration(
                    input: AIProviderEndpointInput(
                        id: endpointInput.id ?? idGenerator(),
                        profileID: profileID,
                        purpose: endpointInput.purpose,
                        isEnabled: endpointInput.isEnabled,
                        providerPresetID: endpointInput.providerPresetID,
                        adapterKind: endpointInput.adapterKind,
                        baseURL: endpointInput.baseURL,
                        modelName: endpointInput.modelName,
                        credentialID: credentialID,
                        supportsImageInput: endpointInput.supportsImageInput,
                        imageInputEnabled: endpointInput.imageInputEnabled,
                        requestTimeoutSeconds: endpointInput.requestTimeoutSeconds
                    ),
                    createdAt: now,
                    updatedAt: now
                )
                endpoints.append(endpoint)
                if let credentialID {
                    credentialsByPurpose[endpointInput.purpose] = credentialID
                }
            }

            let profile = AIProviderConfigurationProfile(
                id: profileID,
                displayName: input.displayName,
                isDefault: true,
                status: .configured,
                createdAt: now,
                updatedAt: now,
                lastValidationStatus: .notRun,
                endpoints: endpoints,
                credentials: credentials
            )
            try await repository.saveProfile(profile)
            return profile
        } catch let error as AIProviderConfigurationError {
            try await cleanupCreatedSecrets(createdReferences, credentialStore: credentialStore)
            throw error
        } catch {
            try await cleanupCreatedSecrets(createdReferences, credentialStore: credentialStore)
            throw AIProviderConfigurationError.databaseWriteFailed
        }
    }

    public func validateDefaultProfileCredentials() async throws -> AIProviderValidationStatus {
        guard let credentialStore else {
            throw AIProviderConfigurationError.keychainWriteFailed
        }
        guard let profile = try await repository.loadDefaultProfile() else {
            throw AIProviderConfigurationError.missingRequiredEndpointField
        }

        var didFail = false
        let credentialsByID = Dictionary(uniqueKeysWithValues: profile.credentials.map { ($0.id, $0) })

        for endpoint in profile.endpoints where endpoint.isEnabled {
            let validation = await validateCredential(
                for: endpoint,
                credentialsByID: credentialsByID,
                credentialStore: credentialStore
            )
            if validation.status != .succeeded {
                didFail = true
            }
            if let credentialID = endpoint.credentialID {
                try await repository.markCredentialState(validation.secretPresence, credentialID: credentialID)
            }
            try await repository.recordValidationEvent(
                AIProviderValidationEvent(
                    id: idGenerator(),
                    profileID: profile.id,
                    endpointID: endpoint.id,
                    eventType: .credentialValidation,
                    status: validation.status,
                    errorCategory: validation.errorCategory,
                    providerPresetID: endpoint.providerPresetID,
                    modelName: endpoint.modelName,
                    durationMilliseconds: nil,
                    createdAt: clock()
                )
            )
        }

        return didFail ? .failed : .succeeded
    }
}

private extension AIProviderConfigurationService {
    struct CredentialValidationResult {
        var status: AIProviderValidationStatus
        var secretPresence: AIProviderSecretPresence
        var errorCategory: AIProviderValidationErrorCategory?
    }

    func validateCredential(
        for endpoint: AIProviderEndpointConfiguration,
        credentialsByID: [AIProviderCredentialID: AIProviderCredentialMetadata],
        credentialStore: any AIProviderCredentialStore
    ) async -> CredentialValidationResult {
        guard let credentialID = endpoint.credentialID,
              let credential = credentialsByID[credentialID]
        else {
            return CredentialValidationResult(
                status: .failed,
                secretPresence: .missing,
                errorCategory: .missingCredential
            )
        }

        do {
            _ = try await credentialStore.resolveSecret(
                for: AIProviderCredentialKeychainReference(metadata: credential)
            )
            return CredentialValidationResult(
                status: .succeeded,
                secretPresence: .present,
                errorCategory: nil
            )
        } catch let error as AIProviderCredentialStoreError {
            switch error {
            case .missingCredential:
                return CredentialValidationResult(
                    status: .failed,
                    secretPresence: .missing,
                    errorCategory: .missingCredential
                )
            case .credentialInaccessible, .credentialCorrupted, .userInteractionRequired:
                return CredentialValidationResult(
                    status: .failed,
                    secretPresence: .inaccessible,
                    errorCategory: .credentialInaccessible
                )
            }
        } catch {
            return CredentialValidationResult(
                status: .failed,
                secretPresence: .inaccessible,
                errorCategory: .credentialInaccessible
            )
        }
    }

    func credentialID(
        for endpointInput: AIProviderEndpointSaveInput,
        profileID: AIProviderProfileID,
        at date: Date,
        credentialsByPurpose: [AIProviderEndpointPurpose: AIProviderCredentialID],
        credentials: inout [AIProviderCredentialMetadata],
        createdReferences: inout [AIProviderCredentialKeychainReference],
        credentialStore: any AIProviderCredentialStore
    ) async throws -> AIProviderCredentialID? {
        switch endpointInput.credentialMode {
        case .none:
            return nil
        case let .existing(credentialID):
            return credentialID
        case let .sharedWithPurpose(purpose):
            return credentialsByPurpose[purpose]
        case let .newSecret(secretInput):
            let secret = secretInput.plaintextSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !secret.isEmpty else {
                throw AIProviderConfigurationError.missingRequiredAPIKey
            }
            let credentialID = idGenerator()
            let metadata = AIProviderCredentialMetadata(
                id: credentialID,
                profileID: profileID,
                providerPresetID: endpointInput.providerPresetID,
                kind: secretInput.kind,
                label: secretInput.label,
                secretPresence: .present,
                createdAt: date,
                updatedAt: date
            )
            let reference = AIProviderCredentialKeychainReference(metadata: metadata)
            do {
                try await credentialStore.upsertSecret(
                    AIProviderSecretInput(value: secret),
                    for: reference
                )
            } catch {
                throw AIProviderConfigurationError.keychainWriteFailed
            }
            createdReferences.append(reference)
            credentials.append(metadata)
            return credentialID
        }
    }

    func cleanupCreatedSecrets(
        _ references: [AIProviderCredentialKeychainReference],
        credentialStore: any AIProviderCredentialStore
    ) async throws {
        for reference in references {
            do {
                try await credentialStore.deleteSecret(for: reference)
            } catch {
                throw AIProviderConfigurationError.orphanedCredentialCleanupFailed
            }
        }
    }
}
