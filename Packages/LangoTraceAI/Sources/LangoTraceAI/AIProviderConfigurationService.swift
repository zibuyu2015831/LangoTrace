import Foundation
import LangoTraceCore

// swiftlint:disable file_length

public struct AIProviderConfigurationService: Sendable {
    private let repository: any AIProviderConfigurationRepository
    private let credentialStore: (any AIProviderCredentialStore)?
    private let configurationProbeService: AIProviderConfigurationProbeService?
    private let ttsConfigurationProbeService: TTSConfigurationProbeService?
    private let embeddingConfigurationProbeService: EmbeddingConfigurationProbeService?
    private let diagnosticLogger: any DiagnosticLogging
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(repository: any AIProviderConfigurationRepository) {
        self.repository = repository
        credentialStore = nil
        configurationProbeService = nil
        ttsConfigurationProbeService = nil
        embeddingConfigurationProbeService = nil
        diagnosticLogger = DisabledDiagnosticLogger()
        clock = Date.init
        idGenerator = { UUID().uuidString }
    }

    public init(
        repository: any AIProviderConfigurationRepository,
        credentialStore: any AIProviderCredentialStore,
        configurationProbeService: AIProviderConfigurationProbeService? = nil,
        ttsConfigurationProbeService: TTSConfigurationProbeService? = nil,
        embeddingConfigurationProbeService: EmbeddingConfigurationProbeService? = nil,
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger(),
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
        self.configurationProbeService = configurationProbeService
        self.ttsConfigurationProbeService = ttsConfigurationProbeService
        self.embeddingConfigurationProbeService = embeddingConfigurationProbeService
        self.diagnosticLogger = diagnosticLogger
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func loadDefaultProfile() async throws -> AIProviderConfigurationProfile? {
        try await repository.loadDefaultProfile()
    }

    public func loadTTSVoiceProfile(
        endpointID: AIProviderEndpointID,
        languageCode: String
    ) async throws -> TTSVoiceProfile? {
        try await repository.loadTTSVoiceProfile(endpointID: endpointID, languageCode: languageCode)
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

        var createdReferences: [AIProviderCredentialKeychainReference] = []
        do {
            let materialized = try await makeProfile(
                from: input,
                operationID: operationID,
                credentialStore: credentialStore,
                createdReferences: &createdReferences
            )
            try await saveProfile(
                materialized.profile,
                ttsSettings: materialized.ttsSettings,
                ttsVoiceProfiles: materialized.ttsVoiceProfiles,
                operationID: operationID,
                createdReferences: createdReferences,
                credentialStore: credentialStore
            )
            return materialized.profile
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

    public func testDraftConfiguration(
        _ input: AIProviderConfigurationProbeDraftInput
    ) async throws -> AIProviderConfigurationProbeResult {
        guard let configurationProbeService else {
            throw AIProviderConfigurationError.unsupportedCapabilityForProvider
        }
        let textResult = try await configurationProbeService.probeDraftConfiguration(input)
        guard let ttsConfigurationProbeService,
              let ttsEndpoint = input.ttsEndpoint,
              let ttsSettings = input.ttsSettings,
              let ttsVoiceProfile = input.ttsVoiceProfile
        else {
            return await mergedDraftEmbeddingProbeResult(textResult, input: input)
        }
        let ttsResult = await ttsConfigurationProbeService.probeDraftTTSConfiguration(
            TTSDraftProbeInput(
                endpoint: ttsEndpoint,
                settings: ttsSettings,
                voiceProfile: ttsVoiceProfile,
                plaintextSecret: input.ttsPlaintextSecret,
                operationID: input.operationID
            )
        )
        let merged = textResult.replacingCapabilityResult(ttsResult)
        return await mergedDraftEmbeddingProbeResult(merged, input: input)
    }

    public func testDefaultConfiguration(
        languageContext: AIProviderProbeLanguageContext? = nil,
        operationID: DiagnosticOperationID = DiagnosticOperationID(rawValue: UUID().uuidString)
    ) async throws -> AIProviderConfigurationProbeResult {
        guard let credentialStore else {
            throw AIProviderConfigurationError.keychainWriteFailed
        }
        guard let profile = try await repository.loadDefaultProfile()
        else {
            throw AIProviderConfigurationError.missingRequiredEndpointField
        }

        let credentialsByID = Dictionary(uniqueKeysWithValues: profile.credentials.map { ($0.id, $0) })
        let textEndpoint = profile.endpoints.first(where: { $0.purpose == .textGeneration && $0.isEnabled })
        let embeddingEndpoint = profile.endpoints.first(where: { $0.purpose == .embedding && $0.isEnabled })
        let ttsEndpoint = profile.endpoints.first(where: { $0.purpose == .tts && $0.isEnabled })
        guard textEndpoint != nil || embeddingEndpoint != nil || ttsEndpoint != nil else {
            throw AIProviderConfigurationError.missingRequiredEndpointField
        }

        let textResult = try await savedTextProbeResult(
            profile: profile,
            endpoint: textEndpoint,
            credentialsByID: credentialsByID,
            credentialStore: credentialStore,
            languageContext: languageContext,
            operationID: operationID
        )
        var result = await mergedSavedTTSProbeResult(
            textResult,
            profile: profile,
            credentialsByID: credentialsByID,
            credentialStore: credentialStore,
            languageContext: languageContext,
            operationID: operationID
        )
        result = await mergedSavedEmbeddingProbeResult(
            result,
            profile: profile,
            embeddingEndpoint: embeddingEndpoint,
            credentialsByID: credentialsByID,
            credentialStore: credentialStore
        )
        var persisted = result
        if let endpoint = textEndpoint {
            persisted = try await persistSyntheticProbeResult(result, profileID: profile.id, endpointID: endpoint.id)
        }
        if let embeddingResult = result.capabilities.first(where: { $0.capability == .embedding }),
           let embeddingEndpointID = embeddingResult.endpointMetadata?.endpointID,
           embeddingResult.status != .notEnabled,
           embeddingResult.status != .notConfigured
        {
            try await persistEmbeddingProbeResult(
                embeddingResult,
                profileID: profile.id,
                endpointID: embeddingEndpointID
            )
        }
        if let speechResult = result.capabilities.first(where: { $0.capability == .speechSynthesis }),
           let ttsEndpointID = speechResult.endpointMetadata?.endpointID,
           let languageCode = languageContext?.languageCode,
           speechResult.status != .notEnabled,
           speechResult.status != .notConfigured
        {
            try await persistTTSProbeResult(
                speechResult,
                profileID: profile.id,
                endpointID: ttsEndpointID,
                languageCode: languageCode
            )
        }
        return persisted
    }

    public func loadDefaultPlayableTTSConfiguration(
        languageCode: String
    ) async throws -> PlayableTTSConfigurationStatus {
        guard let credentialStore else {
            return .credentialMissing
        }
        guard let profile = try await repository.loadDefaultProfile(),
              let endpoint = profile.endpoints.first(where: { $0.purpose == .tts && $0.isEnabled })
        else {
            return .notConfigured
        }
        guard let settings = try await repository.loadTTSSettings(endpointID: endpoint.id),
              let voiceProfile = try await repository.loadTTSVoiceProfile(
                  endpointID: endpoint.id,
                  languageCode: languageCode
              )
        else {
            return .notConfigured
        }
        guard settings.adapterKind == .openAIAudioSpeech || settings.adapterKind == .openRouterAudioSpeech else {
            return .unsupportedProvider
        }
        guard let credentialID = endpoint.credentialID,
              let credential = profile.credentials.first(where: { $0.id == credentialID })
        else {
            return .credentialMissing
        }
        do {
            _ = try await credentialStore.resolveSecret(
                for: AIProviderCredentialKeychainReference(metadata: credential)
            )
        } catch {
            return .credentialMissing
        }
        switch voiceProfile.playbackReadiness {
        case .succeeded:
            return .available(
                PlayableTTSConfiguration(
                    endpoint: endpoint,
                    settings: settings,
                    voiceProfile: voiceProfile
                )
            )
        case .notTested:
            return .notTested
        case .requiresRetest:
            return .requiresRetest
        case .failed:
            return .failedLastTest(voiceProfile.lastTestErrorCategory)
        case .notConfigured:
            return .notConfigured
        case .testing:
            return .notTested
        case .unsupported:
            return .unsupportedProvider
        }
    }
}

extension AIProviderConfigurationService: TTSConfigurationAvailabilityService {}

private extension AIProviderConfigurationProbeResult {
    var firstFailureCategory: AIProviderValidationErrorCategory? {
        persistableCapabilities.first { $0.errorCategory != nil }?.errorCategory
    }

    var totalDurationMilliseconds: Int? {
        let durations = capabilities.compactMap(\.durationMilliseconds)
        guard !durations.isEmpty else {
            return nil
        }
        return durations.reduce(0, +)
    }

    var persistableCapabilities: [AIProviderProbeCapabilityResult] {
        capabilities.filter {
            $0.capability != .languageSupport &&
                $0.capability != .speechSynthesis &&
                $0.capability != .embedding
        }
    }

    var persistenceStatus: AIProviderValidationStatus {
        if overallStatus == .cancelled {
            return .cancelled
        }
        if persistableCapabilities.contains(where: { $0.status == .cancelled }) {
            return .cancelled
        }
        let textStatus = persistableCapabilities.first { $0.capability == .textReply }?.status
        let jsonStatus = persistableCapabilities.first { $0.capability == .structuredJSON }?.status
        let imageStatus = persistableCapabilities.first { $0.capability == .imageUnderstanding }?.status
        guard textStatus == .succeeded,
              jsonStatus == .succeeded,
              imageStatus == .succeeded || imageStatus == .notEnabled || imageStatus == .unsupported
        else {
            return .failed
        }
        return .succeeded
    }

    func replacingCapabilityResult(
        _ replacement: AIProviderProbeCapabilityResult
    ) -> AIProviderConfigurationProbeResult {
        var updated = self
        updated.capabilities = capabilities.map { result in
            result.capability == replacement.capability ? replacement : result
        }
        if !updated.capabilities.contains(where: { $0.capability == replacement.capability }) {
            updated.capabilities.append(replacement)
        }
        updated.overallStatus = updated.mergedOverallStatus
        return updated
    }

    var mergedOverallStatus: AIProviderValidationStatus {
        if capabilities.contains(where: { $0.status == .cancelled }) {
            return .cancelled
        }
        let required: Set<AIProviderProbeCapability> = [.textReply, .structuredJSON, .speechSynthesis]
        let requiredResults = capabilities.filter { required.contains($0.capability) }
        guard !requiredResults.contains(where: { $0.status == .failed || $0.status == .unsupported }) else {
            return requiredResults.contains(where: { $0.status == .succeeded }) ? .failed : .failed
        }
        return requiredResults.allSatisfy { result in
            result.status == .succeeded || result.status == .notEnabled || result.status == .notConfigured
        } ? .succeeded : .failed
    }
}

private extension AIProviderConfigurationService {
    struct CredentialValidationResult {
        var status: AIProviderValidationStatus
        var secretPresence: AIProviderSecretPresence
        var errorCategory: AIProviderValidationErrorCategory?
    }

    func persistSyntheticProbeResult(
        _ result: AIProviderConfigurationProbeResult,
        profileID: AIProviderProfileID,
        endpointID: AIProviderEndpointID
    ) async throws -> AIProviderConfigurationProbeResult {
        guard result.overallStatus != .cancelled else {
            return result
        }
        let eventID = idGenerator()
        let event = AIProviderValidationEvent(
            id: eventID,
            profileID: profileID,
            endpointID: endpointID,
            eventType: .syntheticTest,
            status: result.persistenceStatus,
            errorCategory: result.firstFailureCategory,
            providerPresetID: result.providerPresetID,
            modelName: result.modelName,
            durationMilliseconds: result.totalDurationMilliseconds,
            createdAt: clock()
        )
        try await repository.recordValidationOutcome(event)
        var persisted = result
        persisted.persistedValidationEventID = eventID
        return persisted
    }

    func persistTTSProbeResult(
        _ result: AIProviderProbeCapabilityResult,
        profileID: AIProviderProfileID,
        endpointID: AIProviderEndpointID,
        languageCode: String
    ) async throws {
        guard result.status != .cancelled else {
            return
        }
        let event = AIProviderValidationEvent(
            id: idGenerator(),
            profileID: profileID,
            endpointID: endpointID,
            eventType: .syntheticTest,
            status: result.status == .succeeded ? .succeeded : .failed,
            errorCategory: result.errorCategory,
            providerPresetID: result.endpointMetadata?.providerPresetID ?? "",
            modelName: result.endpointMetadata?.modelName,
            durationMilliseconds: result.durationMilliseconds,
            createdAt: clock()
        )
        try await repository.recordTTSVoiceProfileProbeOutcome(event, languageCode: languageCode)
    }

    func persistEmbeddingProbeResult(
        _ result: AIProviderProbeCapabilityResult,
        profileID: AIProviderProfileID,
        endpointID: AIProviderEndpointID
    ) async throws {
        guard result.status != .cancelled,
              let fingerprint = result.endpointMetadata?.configurationFingerprint
        else {
            return
        }
        let event = AIProviderValidationEvent(
            id: idGenerator(),
            profileID: profileID,
            endpointID: endpointID,
            eventType: .syntheticTest,
            status: result.status == .succeeded ? .succeeded : .failed,
            errorCategory: result.errorCategory,
            providerPresetID: result.endpointMetadata?.providerPresetID ?? "",
            modelName: result.endpointMetadata?.modelName,
            durationMilliseconds: result.durationMilliseconds,
            createdAt: clock()
        )
        try await repository.recordEndpointValidationOutcome(
            AIProviderEndpointValidationOutcome(event: event, configurationFingerprint: fingerprint)
        )
    }

    func savedTextProbeResult(
        profile: AIProviderConfigurationProfile,
        endpoint: AIProviderEndpointConfiguration?,
        credentialsByID: [AIProviderCredentialID: AIProviderCredentialMetadata],
        credentialStore: any AIProviderCredentialStore,
        languageContext: AIProviderProbeLanguageContext?,
        operationID: DiagnosticOperationID
    ) async throws -> AIProviderConfigurationProbeResult {
        guard let endpoint else {
            return noTextSavedProbeResult(profile: profile)
        }
        guard let configurationProbeService else {
            throw AIProviderConfigurationError.unsupportedCapabilityForProvider
        }
        let resolvedSecret: String?
        if endpoint.providerPresetID == "ollama-local" {
            resolvedSecret = nil
        } else {
            guard let credentialID = endpoint.credentialID,
                  let credential = credentialsByID[credentialID]
            else {
                let result = missingSavedCredentialResult(endpoint: endpoint, category: .missingCredential)
                await recordSavedProbePreflightFailure(
                    endpoint: endpoint,
                    category: .missingCredential,
                    operationID: operationID
                )
                return result
            }
            do {
                let secret = try await credentialStore.resolveSecret(
                    for: AIProviderCredentialKeychainReference(metadata: credential)
                )
                resolvedSecret = secret.value
            } catch let error as AIProviderCredentialStoreError {
                let category = validationErrorCategory(for: error)
                let result = missingSavedCredentialResult(endpoint: endpoint, category: category)
                await recordSavedProbePreflightFailure(
                    endpoint: endpoint,
                    category: category,
                    operationID: operationID
                )
                return result
            }
        }

        return try await configurationProbeService.probeSavedConfiguration(
            AIProviderConfigurationProbeSavedInput(
                endpoint: endpoint.makeProbeInput(),
                plaintextSecret: resolvedSecret,
                languageContext: languageContext,
                operationID: operationID
            )
        )
    }

    func mergedDraftEmbeddingProbeResult(
        _ current: AIProviderConfigurationProbeResult,
        input: AIProviderConfigurationProbeDraftInput
    ) async -> AIProviderConfigurationProbeResult {
        guard let embeddingConfigurationProbeService,
              let embeddingEndpoint = input.embeddingEndpoint
        else {
            return current
        }
        let embeddingResult = await embeddingConfigurationProbeService.probeDraftEmbeddingConfiguration(
            EmbeddingDraftProbeInput(
                endpoint: embeddingEndpoint,
                plaintextSecret: input.embeddingPlaintextSecret
            )
        )
        return current.replacingCapabilityResult(embeddingResult)
    }

    func mergedSavedTTSProbeResult(
        _ textResult: AIProviderConfigurationProbeResult,
        profile: AIProviderConfigurationProfile,
        credentialsByID: [AIProviderCredentialID: AIProviderCredentialMetadata],
        credentialStore: any AIProviderCredentialStore,
        languageContext: AIProviderProbeLanguageContext?,
        operationID: DiagnosticOperationID
    ) async -> AIProviderConfigurationProbeResult {
        guard let ttsConfigurationProbeService,
              let languageCode = languageContext?.languageCode,
              let ttsEndpoint = profile.endpoints.first(where: { $0.purpose == .tts && $0.isEnabled })
        else {
            return textResult
        }
        do {
            guard let settings = try await repository.loadTTSSettings(endpointID: ttsEndpoint.id),
                  let voiceProfile = try await repository.loadTTSVoiceProfile(
                      endpointID: ttsEndpoint.id,
                      languageCode: languageCode
                  )
            else {
                return textResult.replacingCapabilityResult(
                    AIProviderProbeCapabilityResult(
                        capability: .speechSynthesis,
                        status: .notConfigured,
                        errorCategory: nil,
                        durationMilliseconds: nil,
                        endpointMetadata: AIProviderEndpointProbeMetadata(
                            endpointID: ttsEndpoint.id,
                            endpointPurpose: .tts,
                            providerPresetID: ttsEndpoint.providerPresetID,
                            modelName: ttsEndpoint.modelName
                        )
                    )
                )
            }
            let secret = try await resolveSecretForProbe(
                endpoint: ttsEndpoint,
                credentialsByID: credentialsByID,
                credentialStore: credentialStore
            )
            let speechResult = await ttsConfigurationProbeService.probeDraftTTSConfiguration(
                TTSDraftProbeInput(
                    endpoint: ttsEndpoint.makeProbeInput(),
                    settings: settings,
                    voiceProfile: voiceProfile,
                    plaintextSecret: secret,
                    operationID: operationID
                )
            )
            return textResult.replacingCapabilityResult(speechResult)
        } catch let error as AIProviderCredentialStoreError {
            return textResult.replacingCapabilityResult(
                ttsPreflightFailureResult(
                    endpoint: ttsEndpoint,
                    category: validationErrorCategory(for: error)
                )
            )
        } catch {
            return textResult.replacingCapabilityResult(
                ttsPreflightFailureResult(endpoint: ttsEndpoint, category: .credentialInaccessible)
            )
        }
    }

    func ttsPreflightFailureResult(
        endpoint: AIProviderEndpointConfiguration,
        category: AIProviderValidationErrorCategory
    ) -> AIProviderProbeCapabilityResult {
        AIProviderProbeCapabilityResult(
            capability: .speechSynthesis,
            status: .failed,
            errorCategory: category,
            durationMilliseconds: nil,
            endpointMetadata: AIProviderEndpointProbeMetadata(
                endpointID: endpoint.id,
                endpointPurpose: .tts,
                providerPresetID: endpoint.providerPresetID,
                modelName: endpoint.modelName
            )
        )
    }

    func mergedSavedEmbeddingProbeResult(
        _ current: AIProviderConfigurationProbeResult,
        profile _: AIProviderConfigurationProfile,
        embeddingEndpoint: AIProviderEndpointConfiguration?,
        credentialsByID: [AIProviderCredentialID: AIProviderCredentialMetadata],
        credentialStore: any AIProviderCredentialStore
    ) async -> AIProviderConfigurationProbeResult {
        guard let embeddingConfigurationProbeService,
              let embeddingEndpoint
        else {
            return current
        }
        let secret: String?
        do {
            secret = try await resolveSecretForProbe(
                endpoint: embeddingEndpoint,
                credentialsByID: credentialsByID,
                credentialStore: credentialStore
            )
        } catch let error as AIProviderCredentialStoreError {
            return current.replacingCapabilityResult(
                embeddingPreflightFailureResult(
                    endpoint: embeddingEndpoint,
                    category: validationErrorCategory(for: error)
                )
            )
        } catch {
            return current.replacingCapabilityResult(
                embeddingPreflightFailureResult(endpoint: embeddingEndpoint, category: .credentialInaccessible)
            )
        }
        let result = await embeddingConfigurationProbeService.probeDraftEmbeddingConfiguration(
            EmbeddingDraftProbeInput(endpoint: embeddingEndpoint.makeProbeInput(), plaintextSecret: secret)
        )
        return current.replacingCapabilityResult(result)
    }

    func resolveSecretForProbe(
        endpoint: AIProviderEndpointConfiguration,
        credentialsByID: [AIProviderCredentialID: AIProviderCredentialMetadata],
        credentialStore: any AIProviderCredentialStore
    ) async throws -> String? {
        if endpoint.providerPresetID == "ollama-local" {
            return nil
        }
        guard let credentialID = endpoint.credentialID,
              let credential = credentialsByID[credentialID]
        else {
            return nil
        }
        let secret = try await credentialStore.resolveSecret(
            for: AIProviderCredentialKeychainReference(metadata: credential)
        )
        return secret.value
    }

    func missingSavedCredentialResult(
        endpoint: AIProviderEndpointConfiguration,
        category: AIProviderValidationErrorCategory
    ) -> AIProviderConfigurationProbeResult {
        AIProviderConfigurationProbeResult(
            source: .savedProfile,
            overallStatus: .failed,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            capabilities: [
                .init(capability: .textReply, status: .failed, errorCategory: category, durationMilliseconds: nil),
                .init(capability: .structuredJSON, status: .notRun, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .languageSupport, status: .notRun, errorCategory: nil, durationMilliseconds: nil),
                .init(
                    capability: .imageUnderstanding,
                    status: .unsupported,
                    errorCategory: .unsupportedEndpointPurpose,
                    durationMilliseconds: nil
                ),
                .init(capability: .speechSynthesis, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .embedding, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
            ],
            persistedValidationEventID: nil
        )
    }

    func noTextSavedProbeResult(profile: AIProviderConfigurationProfile) -> AIProviderConfigurationProbeResult {
        let representative = profile.endpoints.first { $0.isEnabled }
        return AIProviderConfigurationProbeResult(
            source: .savedProfile,
            overallStatus: .succeeded,
            providerPresetID: representative?.providerPresetID ?? "",
            modelName: representative?.modelName ?? "",
            capabilities: [
                .init(capability: .textReply, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .structuredJSON, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .languageSupport, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .imageUnderstanding, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .speechSynthesis, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
                .init(capability: .embedding, status: .notEnabled, errorCategory: nil, durationMilliseconds: nil),
            ],
            persistedValidationEventID: nil
        )
    }

    func embeddingPreflightFailureResult(
        endpoint: AIProviderEndpointConfiguration,
        category: AIProviderValidationErrorCategory
    ) -> AIProviderProbeCapabilityResult {
        AIProviderProbeCapabilityResult(
            capability: .embedding,
            status: .failed,
            errorCategory: category,
            durationMilliseconds: nil,
            endpointMetadata: AIProviderEndpointProbeMetadata(
                endpointID: endpoint.id,
                endpointPurpose: .embedding,
                providerPresetID: endpoint.providerPresetID,
                modelName: endpoint.modelName,
                configurationFingerprint: endpoint.configurationFingerprint
            )
        )
    }

    func validationErrorCategory(for error: AIProviderCredentialStoreError) -> AIProviderValidationErrorCategory {
        switch error {
        case .missingCredential:
            .missingCredential
        case .credentialInaccessible, .credentialCorrupted, .userInteractionRequired:
            .credentialInaccessible
        }
    }

    func recordSavedProbePreflightFailure(
        endpoint: AIProviderEndpointConfiguration,
        category: AIProviderValidationErrorCategory,
        operationID: DiagnosticOperationID
    ) async {
        await diagnosticLogger.record(
            DiagnosticEvent(
                id: UUID().uuidString,
                name: .aiProviderConfigurationProbeFailed,
                domain: .aiProviderSettings,
                level: .warning,
                outcome: .failed,
                attributes: [
                    .operationID(operationID),
                    .providerPresetID(endpoint.providerPresetID),
                    .endpointPurpose(endpoint.purpose),
                    .modelName(endpoint.modelName),
                    .adapterKind(endpoint.adapterKind),
                    .errorCategory(category.rawValue),
                    .probeCapability(.textReply),
                    .probeCapabilityStatus(.failed),
                    .probeCapability(.structuredJSON),
                    .probeCapabilityStatus(.notRun),
                ],
                createdAt: clock()
            )
        )
    }

    struct MaterializedProfileSave {
        var profile: AIProviderConfigurationProfile
        var ttsSettings: TTSProviderSettings?
        var ttsVoiceProfiles: [TTSVoiceProfile]
    }

    struct CredentialMaterializationContext {
        var profileID: AIProviderProfileID
        var date: Date
        var operationID: DiagnosticOperationID
        var credentialStore: any AIProviderCredentialStore
        var existingCredentialsByID: [AIProviderCredentialID: AIProviderCredentialMetadata]
    }

    func makeProfile(
        from input: AIProviderProfileSaveInput,
        operationID: DiagnosticOperationID,
        credentialStore: any AIProviderCredentialStore,
        createdReferences: inout [AIProviderCredentialKeychainReference]
    ) async throws -> MaterializedProfileSave {
        let now = clock()
        let profileID = input.profileID ?? idGenerator()
        let existingCredentialsByID = try await repository.loadDefaultProfile()?.credentials.reduce(
            into: [AIProviderCredentialID: AIProviderCredentialMetadata]()
        ) { partialResult, credential in
            partialResult[credential.id] = credential
        } ?? [:]
        var credentialsByPurpose: [AIProviderEndpointPurpose: AIProviderCredentialID] = [:]
        var credentials: [AIProviderCredentialMetadata] = []
        var endpoints: [AIProviderEndpointConfiguration] = []
        let credentialContext = CredentialMaterializationContext(
            profileID: profileID,
            date: now,
            operationID: operationID,
            credentialStore: credentialStore,
            existingCredentialsByID: existingCredentialsByID
        )

        for endpointInput in input.endpoints {
            let credentialID = try await credentialID(
                for: endpointInput,
                context: credentialContext,
                credentialsByPurpose: credentialsByPurpose,
                credentials: &credentials,
                createdReferences: &createdReferences
            )
            let endpoint = try endpointConfiguration(
                from: endpointInput,
                profileID: profileID,
                credentialID: credentialID,
                createdAt: now
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
        let ttsEndpoint = endpoints.first { $0.purpose == input.ttsVoiceProfile?.endpointPurpose }
        let ttsSettings: TTSProviderSettings? = if let ttsVoiceProfile = input.ttsVoiceProfile, let ttsEndpoint {
            TTSProviderSettings(endpointID: ttsEndpoint.id, adapterKind: ttsVoiceProfile.adapterKind)
        } else {
            nil
        }
        let ttsVoiceProfiles: [TTSVoiceProfile] = if let ttsVoiceProfile = input.ttsVoiceProfile, let ttsEndpoint {
            try [
                TTSVoiceProfile.make(
                    id: idGenerator(),
                    endpointID: ttsEndpoint.id,
                    languageCode: ttsVoiceProfile.languageCode,
                    adapterKind: ttsVoiceProfile.adapterKind,
                    modelName: ttsEndpoint.modelName,
                    voiceID: ttsVoiceProfile.voiceID,
                    voiceDisplayName: ttsVoiceProfile.voiceDisplayName,
                    outputFormat: ttsVoiceProfile.outputFormat,
                    sampleRate: ttsVoiceProfile.sampleRate,
                    speed: ttsVoiceProfile.speed,
                    volume: ttsVoiceProfile.volume,
                    pitch: ttsVoiceProfile.pitch,
                    stylePrompt: ttsVoiceProfile.stylePrompt,
                    instructions: ttsVoiceProfile.instructions,
                    streamingMode: ttsVoiceProfile.streamingMode,
                    providerParameters: ttsVoiceProfile.providerParameters
                ),
            ]
        } else {
            []
        }
        return MaterializedProfileSave(
            profile: profile,
            ttsSettings: ttsSettings,
            ttsVoiceProfiles: ttsVoiceProfiles
        )
    }

    func endpointConfiguration(
        from endpointInput: AIProviderEndpointSaveInput,
        profileID: AIProviderProfileID,
        credentialID: AIProviderCredentialID?,
        createdAt: Date
    ) throws -> AIProviderEndpointConfiguration {
        try AIProviderEndpointConfiguration(
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
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    func saveProfile(
        _ profile: AIProviderConfigurationProfile,
        ttsSettings: TTSProviderSettings?,
        ttsVoiceProfiles: [TTSVoiceProfile],
        operationID: DiagnosticOperationID,
        createdReferences: [AIProviderCredentialKeychainReference],
        credentialStore: any AIProviderCredentialStore
    ) async throws {
        await record(
            .aiProviderConfigurationDatabaseWriteStarted,
            domain: .dataStorage,
            level: .debug,
            outcome: .started,
            operationID: operationID
        )
        do {
            try await repository.saveProfile(
                profile,
                ttsSettings: ttsSettings,
                ttsVoiceProfiles: ttsVoiceProfiles
            )
        } catch {
            await recordDatabaseWriteFailure(operationID)
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
        context: CredentialMaterializationContext,
        credentialsByPurpose: [AIProviderEndpointPurpose: AIProviderCredentialID],
        credentials: inout [AIProviderCredentialMetadata],
        createdReferences: inout [AIProviderCredentialKeychainReference]
    ) async throws -> AIProviderCredentialID? {
        switch endpointInput.credentialMode {
        case .none:
            return nil
        case let .existing(credentialID):
            if let credential = context.existingCredentialsByID[credentialID],
               !credentials.contains(where: { $0.id == credentialID })
            {
                credentials.append(credential)
            }
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
                profileID: context.profileID,
                providerPresetID: endpointInput.providerPresetID,
                kind: secretInput.kind,
                label: secretInput.label,
                secretPresence: .present,
                createdAt: context.date,
                updatedAt: context.date
            )
            let reference = AIProviderCredentialKeychainReference(metadata: metadata)
            await record(
                .aiProviderConfigurationKeychainWriteStarted,
                domain: .aiProviderSettings,
                level: .debug,
                outcome: .started,
                operationID: context.operationID
            )
            do {
                try await context.credentialStore.upsertSecret(
                    AIProviderSecretInput(value: secret),
                    for: reference
                )
            } catch {
                await record(
                    .aiProviderConfigurationKeychainWriteFailed,
                    domain: .aiProviderSettings,
                    level: .error,
                    outcome: .failed,
                    operationID: context.operationID,
                    attributes: [
                        .failurePhase(AIProviderConfigurationSavePhase.keychainWrite.rawValue),
                        .errorCategory(AIProviderConfigurationSaveFailureCategory.keychainWriteFailed.rawValue),
                    ]
                )
                throw AIProviderConfigurationSaveFailure(
                    operationID: context.operationID,
                    phase: .keychainWrite,
                    category: .keychainWriteFailed
                )
            }
            await record(
                .aiProviderConfigurationKeychainWriteSucceeded,
                domain: .aiProviderSettings,
                level: .debug,
                outcome: .succeeded,
                operationID: context.operationID
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

    func recordDatabaseWriteFailure(_ operationID: DiagnosticOperationID) async {
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

private extension AIProviderEndpointConfiguration {
    func makeProbeInput() -> AIProviderEndpointInput {
        AIProviderEndpointInput(
            id: id,
            profileID: profileID,
            purpose: purpose,
            isEnabled: isEnabled,
            providerPresetID: providerPresetID,
            adapterKind: adapterKind,
            baseURL: baseURL,
            modelName: modelName,
            credentialID: credentialID,
            supportsImageInput: supportsImageInput,
            imageInputEnabled: imageInputEnabled,
            requestTimeoutSeconds: requestTimeoutSeconds
        )
    }
}
