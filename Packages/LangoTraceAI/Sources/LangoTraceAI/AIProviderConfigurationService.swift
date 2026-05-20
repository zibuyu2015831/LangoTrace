import Foundation
import LangoTraceCore

public struct AIProviderConfigurationService: Sendable {
    private let repository: any AIProviderConfigurationRepository
    private let credentialStore: (any AIProviderCredentialStore)?
    private let diagnosticLogger: any DiagnosticLogging
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(repository: any AIProviderConfigurationRepository) {
        self.repository = repository
        credentialStore = nil
        diagnosticLogger = DisabledDiagnosticLogger()
        clock = Date.init
        idGenerator = { UUID().uuidString }
    }

    public init(
        repository: any AIProviderConfigurationRepository,
        credentialStore: any AIProviderCredentialStore,
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger(),
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
        self.diagnosticLogger = diagnosticLogger
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
        _ input: AIProviderProfileSaveInput,
        operationID: DiagnosticOperationID? = nil
    ) async throws -> AIProviderConfigurationProfile {
        let operationID = operationID ?? DiagnosticOperationID(rawValue: UUID().uuidString)
        guard let credentialStore else {
            throw AIProviderConfigurationSaveFailure(
                operationID: operationID,
                phase: .keychainWrite,
                category: .keychainWriteFailed
            )
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
                    operationID: operationID,
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
            await record(
                .aiProviderConfigurationDatabaseWriteStarted,
                domain: .dataStorage,
                level: .debug,
                outcome: .started,
                operationID: operationID
            )
            do {
                try await repository.saveProfile(profile)
            } catch {
                await record(
                    .aiProviderConfigurationDatabaseWriteFailed,
                    domain: .dataStorage,
                    level: .error,
                    outcome: .failed,
                    operationID: operationID,
                    attributes: [
                        .failurePhase(AIProviderConfigurationSavePhase.databaseWrite.rawValue),
                        .errorCategory(AIProviderConfigurationSaveFailureCategory.databaseWriteFailed.rawValue),
                    ]
                )
                let cleanupFailure = await cleanupCreatedSecrets(
                    createdReferences,
                    operationID: operationID,
                    credentialStore: credentialStore
                )
                throw AIProviderConfigurationSaveFailure(
                    operationID: operationID,
                    phase: .databaseWrite,
                    category: .databaseWriteFailed,
                    cleanupFailure: cleanupFailure
                )
            }
            await record(
                .aiProviderConfigurationDatabaseWriteSucceeded,
                domain: .dataStorage,
                level: .debug,
                outcome: .succeeded,
                operationID: operationID
            )
            return profile
        } catch let failure as AIProviderConfigurationSaveFailure {
            if failure.phase == .databaseWrite {
                throw failure
            }
            let cleanupFailure = await cleanupCreatedSecrets(
                createdReferences,
                operationID: operationID,
                credentialStore: credentialStore
            )
            if cleanupFailure == nil || failure.cleanupFailure != nil {
                throw failure
            }
            throw AIProviderConfigurationSaveFailure(
                operationID: failure.operationID,
                phase: failure.phase,
                category: failure.category,
                cleanupFailure: cleanupFailure
            )
        } catch let error as AIProviderConfigurationError {
            let cleanupFailure = await cleanupCreatedSecrets(
                createdReferences,
                operationID: operationID,
                credentialStore: credentialStore
            )
            throw saveFailure(from: error, operationID: operationID, cleanupFailure: cleanupFailure)
        } catch {
            let cleanupFailure = await cleanupCreatedSecrets(
                createdReferences,
                operationID: operationID,
                credentialStore: credentialStore
            )
            throw AIProviderConfigurationSaveFailure(
                operationID: operationID,
                phase: .unknown,
                category: .unknown,
                cleanupFailure: cleanupFailure
            )
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
        operationID: DiagnosticOperationID,
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
            await record(
                .aiProviderConfigurationKeychainWriteStarted,
                domain: .aiProviderSettings,
                level: .debug,
                outcome: .started,
                operationID: operationID
            )
            do {
                try await credentialStore.upsertSecret(
                    AIProviderSecretInput(value: secret),
                    for: reference
                )
            } catch {
                await record(
                    .aiProviderConfigurationKeychainWriteFailed,
                    domain: .aiProviderSettings,
                    level: .error,
                    outcome: .failed,
                    operationID: operationID,
                    attributes: [
                        .failurePhase(AIProviderConfigurationSavePhase.keychainWrite.rawValue),
                        .errorCategory(AIProviderConfigurationSaveFailureCategory.keychainWriteFailed.rawValue),
                    ]
                )
                throw AIProviderConfigurationSaveFailure(
                    operationID: operationID,
                    phase: .keychainWrite,
                    category: .keychainWriteFailed
                )
            }
            await record(
                .aiProviderConfigurationKeychainWriteSucceeded,
                domain: .aiProviderSettings,
                level: .debug,
                outcome: .succeeded,
                operationID: operationID
            )
            createdReferences.append(reference)
            credentials.append(metadata)
            return credentialID
        }
    }

    func cleanupCreatedSecrets(
        _ references: [AIProviderCredentialKeychainReference],
        operationID: DiagnosticOperationID,
        credentialStore: any AIProviderCredentialStore
    ) async -> AIProviderConfigurationSaveFailureCategory? {
        guard !references.isEmpty else {
            return nil
        }

        await record(
            .aiProviderConfigurationCleanupStarted,
            domain: .aiProviderSettings,
            level: .debug,
            outcome: .started,
            operationID: operationID
        )
        for reference in references {
            do {
                try await credentialStore.deleteSecret(for: reference)
            } catch {
                await record(
                    .aiProviderConfigurationCleanupFailed,
                    domain: .aiProviderSettings,
                    level: .error,
                    outcome: .failed,
                    operationID: operationID,
                    attributes: [
                        .failurePhase(AIProviderConfigurationSavePhase.credentialCleanup.rawValue),
                        .errorCategory(AIProviderConfigurationSaveFailureCategory.credentialCleanupFailed.rawValue),
                    ]
                )
                return .credentialCleanupFailed
            }
        }
        await record(
            .aiProviderConfigurationCleanupSucceeded,
            domain: .aiProviderSettings,
            level: .debug,
            outcome: .succeeded,
            operationID: operationID
        )
        return nil
    }

    func record(
        _ name: DiagnosticEventName,
        domain: DiagnosticDomain,
        level: DiagnosticLevel,
        outcome: DiagnosticOutcome,
        operationID: DiagnosticOperationID,
        attributes: [DiagnosticAttribute] = []
    ) async {
        await diagnosticLogger.record(
            DiagnosticEvent(
                id: UUID().uuidString,
                name: name,
                domain: domain,
                level: level,
                outcome: outcome,
                attributes: [.operationID(operationID)] + attributes,
                createdAt: clock()
            )
        )
    }

    func saveFailure(
        from error: AIProviderConfigurationError,
        operationID: DiagnosticOperationID,
        cleanupFailure: AIProviderConfigurationSaveFailureCategory?
    ) -> AIProviderConfigurationSaveFailure {
        switch error {
        case .missingRequiredEndpointField:
            AIProviderConfigurationSaveFailure(
                operationID: operationID,
                phase: .inputValidation,
                category: .missingRequiredEndpointField,
                cleanupFailure: cleanupFailure
            )
        case .invalidBaseURL, .unsupportedCapabilityForProvider:
            AIProviderConfigurationSaveFailure(
                operationID: operationID,
                phase: .inputValidation,
                category: .invalidBaseURL,
                cleanupFailure: cleanupFailure
            )
        case .missingRequiredAPIKey:
            AIProviderConfigurationSaveFailure(
                operationID: operationID,
                phase: .inputValidation,
                category: .missingRequiredAPIKey,
                cleanupFailure: cleanupFailure
            )
        case .keychainWriteFailed:
            AIProviderConfigurationSaveFailure(
                operationID: operationID,
                phase: .keychainWrite,
                category: .keychainWriteFailed,
                cleanupFailure: cleanupFailure
            )
        case .databaseWriteFailed:
            AIProviderConfigurationSaveFailure(
                operationID: operationID,
                phase: .databaseWrite,
                category: .databaseWriteFailed,
                cleanupFailure: cleanupFailure
            )
        case .orphanedCredentialCleanupFailed:
            AIProviderConfigurationSaveFailure(
                operationID: operationID,
                phase: .credentialCleanup,
                category: .credentialCleanupFailed,
                cleanupFailure: cleanupFailure
            )
        }
    }
}
