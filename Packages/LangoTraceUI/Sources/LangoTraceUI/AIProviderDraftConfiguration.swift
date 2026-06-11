import Foundation
import LangoTraceCore

enum AIProviderAPIKeyStorage: Equatable {
    case encryptedStoragePending
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
    public var endpoint: AIProviderEndpointInput?
    public var plaintextSecret: String?
    public var ttsEndpoint: AIProviderEndpointInput?
    public var ttsSettings: TTSProviderSettings?
    public var ttsVoiceProfile: TTSVoiceProfile?
    public var ttsPlaintextSecret: String?
    public var embeddingEndpoint: AIProviderEndpointInput?
    public var embeddingPlaintextSecret: String?
    public var languageContext: AIProviderProbeLanguageContext?
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
    case cancelled(AIProviderConfigurationProbeResult?)
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
        case .cancelled:
            "aiProviderSettings.testState.cancelled"
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

    var hasUsableCredential: Bool {
        independentCredential.isComplete || credentialID != nil
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
        endpoint.hasBaseURLAndModel && endpoint.hasUsableCredential
    }

    mutating func updateProvider(_ provider: AIProviderPreset) {
        endpoint.updateProvider(
            provider,
            defaultModel: provider.defaultTextModel,
            credentialReference: .independent
        )
        if !endpoint.imageInputDecision(purpose: .textGeneration).canToggle {
            imageUnderstandingEnabled = false
        }
    }
}

enum AIOptionalModelPurpose: Equatable {
    case speech
    case embedding

    var endpointPurpose: AIProviderEndpointPurpose {
        switch self {
        case .speech:
            .tts
        case .embedding:
            .embedding
        }
    }

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
    var voiceID: String
    var voiceDisplayName: String?
    var outputFormat: TTSAudioFormat
    var speed: Double?
    var instructions: String?

    init(provider: AIProviderPreset, purpose: AIOptionalModelPurpose) {
        isEnabled = false
        self.purpose = purpose
        endpoint = AIProviderEndpointDraftConfiguration(
            provider: provider,
            model: purpose.defaultModel(for: provider),
            credentialReference: .textModelCredential
        )
        voiceID = purpose == .speech ? provider.defaultTTSVoiceID : ""
        voiceDisplayName = nil
        outputFormat = .mp3
        speed = purpose == .speech ? 1.0 : nil
        instructions = nil
    }

    var isCompleteWithSharedCredential: Bool {
        !isEnabled || endpoint.hasBaseURLAndModel
    }

    func isComplete(
        textCredential: AIProviderCredentialDraftConfiguration,
        textCredentialID: AIProviderCredentialID?
    ) -> Bool {
        guard isEnabled, endpoint.hasBaseURLAndModel else {
            return !isEnabled
        }
        if purpose == .speech, voiceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        switch endpoint.credentialReference {
        case .textModelCredential:
            return textCredential.isComplete || textCredentialID != nil
        case .independent:
            return endpoint.hasUsableCredential
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
        if purpose == .speech {
            voiceID = provider.defaultTTSVoiceID
            voiceDisplayName = nil
            outputFormat = .mp3
            speed = 1.0
            instructions = nil
        }
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
    private var hasUnsavedEdits: Bool

    init(provider: AIProviderPreset) {
        profileID = nil
        text = AITextModelDraftConfiguration(provider: provider)
        speech = AIOptionalModelDraftConfiguration(provider: provider, purpose: .speech)
        embedding = AIOptionalModelDraftConfiguration(provider: provider, purpose: .embedding)
        saveState = .idle
        testState = .idle
        hasPersistedConfiguration = false
        hasUnsavedEdits = false
    }

    var saveReadiness: AIProviderTestReadiness {
        let textCredential = text.endpoint.independentCredential
        let allEnabledConfigurationsComplete = text.isComplete &&
            speech.isComplete(
                textCredential: textCredential,
                textCredentialID: text.endpoint.credentialID
            ) &&
            embedding.isComplete(
                textCredential: textCredential,
                textCredentialID: text.endpoint.credentialID
            )

        return allEnabledConfigurationsComplete ? .readyForRequest : .missingRequiredFields
    }

    var textProbeReadiness: AIProviderTestReadiness {
        guard text.endpoint.hasBaseURLAndModel else {
            return .missingRequiredFields
        }
        if textProbeSource == .savedProfile {
            return .readyForRequest
        }
        return text.endpoint.hasUsableCredential ? .readyForRequest : .missingRequiredFields
    }

    var configurationProbeReadiness: AIProviderTestReadiness {
        if textProbeReadiness == .readyForRequest {
            return .readyForRequest
        }
        let embeddingDecision = embedding.endpoint.embeddingDecision()
        let hasCompleteEmbeddingProbe = embedding.isEnabled &&
            embeddingDecision.canProbe &&
            embedding.isComplete(
                textCredential: text.endpoint.independentCredential,
                textCredentialID: text.endpoint.credentialID
            )
        return hasCompleteEmbeddingProbe ? .readyForRequest : .missingRequiredFields
    }

    var textProbeSource: AIProviderTextProbeSource {
        if hasPersistedConfiguration, !hasUnsavedEdits {
            return .savedProfile
        }
        return .draft
    }

    func makeProfileSaveInput(
        languageContext: AIProviderProbeLanguageContext? = nil
    ) throws -> AIProviderProfileSaveInput {
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
            endpoints: endpoints,
            ttsVoiceProfile: speech.isEnabled ? speech.makeTTSVoiceProfileSaveInput(
                languageCode: languageContext?.languageCode ?? "en"
            ) : nil
        )
    }

    var configurationProbeRequestedCapabilities: [AIProviderProbeCapability] {
        configurationProbeRequestedCapabilities(languageContext: nil, includePlaceholders: false)
    }

    func configurationProbeRequestedCapabilities(
        languageContext: AIProviderProbeLanguageContext?,
        includePlaceholders: Bool = false
    ) -> [AIProviderProbeCapability] {
        var capabilities: [AIProviderProbeCapability] = [.textReply, .structuredJSON]
        if languageContext != nil {
            capabilities.append(.languageSupport)
        }
        let imageInputDecision = text.endpoint.imageInputDecision(purpose: .textGeneration)
        if includePlaceholders || (text.imageUnderstandingEnabled && imageInputDecision.canProbe) {
            capabilities.append(.imageUnderstanding)
        }
        let embeddingDecision = embedding.endpoint.embeddingDecision()
        if includePlaceholders {
            capabilities.append(.speechSynthesis)
            capabilities.append(.embedding)
        } else if speech.isEnabled {
            capabilities.append(.speechSynthesis)
        }
        // swiftlint:disable opening_brace
        if !includePlaceholders,
           embedding.isEnabled,
           embeddingDecision.canProbe,
           embedding.isComplete(
               textCredential: text.endpoint.independentCredential,
               textCredentialID: text.endpoint.credentialID
           )
        {
            // swiftlint:enable opening_brace
            capabilities.append(.embedding)
        }
        return capabilities
    }

    func applyingLocalProbeCapabilityOverrides(
        to result: AIProviderConfigurationProbeResult,
        languageContext _: AIProviderProbeLanguageContext?
    ) -> AIProviderConfigurationProbeResult {
        guard result.source == .draft else {
            return result
        }

        var updated = result
        // swiftlint:disable opening_brace
        if speech.isEnabled,
           !speech.isComplete(
               textCredential: text.endpoint.independentCredential,
               textCredentialID: text.endpoint.credentialID
           )
        {
            // swiftlint:enable opening_brace
            updated = updated.replacingLocalCapabilityResult(.init(
                capability: .speechSynthesis,
                status: .notConfigured,
                errorCategory: nil,
                durationMilliseconds: nil
            ))
        }

        if embedding.isEnabled {
            let embeddingDecision = embedding.endpoint.embeddingDecision()
            let embeddingStatus: AIProviderProbeCapabilityStatus? = if !embeddingDecision.canProbe {
                .unsupported
            } else if !embedding.isComplete(
                textCredential: text.endpoint.independentCredential,
                textCredentialID: text.endpoint.credentialID
            ) {
                .notConfigured
            } else {
                nil
            }
            if let embeddingStatus {
                updated = updated.replacingLocalCapabilityResult(.init(
                    capability: .embedding,
                    status: embeddingStatus,
                    errorCategory: embeddingStatus == .unsupported ? .unsupportedEndpointPurpose : nil,
                    durationMilliseconds: nil
                ))
            }
        }

        return updated
    }

    func makeConfigurationProbeDraftSnapshot(
        operationID: DiagnosticOperationID,
        languageContext: AIProviderProbeLanguageContext? = nil
    ) throws -> AIProviderDraftProbeSnapshot {
        guard configurationProbeReadiness == .readyForRequest else {
            throw AIProviderConfigurationError.missingRequiredEndpointField
        }
        let imageInputDecision = text.endpoint.imageInputDecision(purpose: .textGeneration)
        let ttsEndpointID = speech.endpoint.id ?? "draft-tts-endpoint"
        let endpoint = try makeTextDraftProbeEndpoint(imageInputDecision: imageInputDecision)
        let ttsSnapshot = try makeTTSDraftProbeSnapshot(
            endpointID: ttsEndpointID,
            profileID: profileID ?? "draft-profile",
            languageCode: languageContext?.languageCode ?? "en"
        )
        let embeddingSnapshot = try makeEmbeddingDraftProbeSnapshot(
            endpointID: embedding.endpoint.id ?? "draft-embedding-endpoint",
            profileID: profileID ?? "draft-profile"
        )
        return AIProviderDraftProbeSnapshot(
            source: .draft,
            endpoint: endpoint,
            plaintextSecret: endpoint != nil && text.endpoint.independentCredential.requiresAPIKey
                ? text.endpoint.independentCredential.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil,
            ttsEndpoint: ttsSnapshot?.endpoint,
            ttsSettings: ttsSnapshot?.settings,
            ttsVoiceProfile: ttsSnapshot?.voiceProfile,
            ttsPlaintextSecret: ttsSnapshot?.plaintextSecret,
            embeddingEndpoint: embeddingSnapshot?.endpoint,
            embeddingPlaintextSecret: embeddingSnapshot?.plaintextSecret,
            languageContext: languageContext,
            requestedCapabilities: configurationProbeRequestedCapabilities(languageContext: languageContext),
            operationID: operationID
        )
    }

    mutating func applySavedProfile(
        _ profile: AIProviderConfigurationProfile,
        resolvedSecretsByCredentialID: [AIProviderCredentialID: String] = [:]
    ) {
        applyLoadedProfile(profile, resolvedSecretsByCredentialID: resolvedSecretsByCredentialID)
        hasPersistedConfiguration = true
        hasUnsavedEdits = false
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
            let imageInputDecision = text.endpoint.imageInputDecision(purpose: .textGeneration)
            text.imageUnderstandingEnabled = textEndpoint.imageInputEnabled &&
                imageInputDecision.canToggle &&
                imageInputDecision.canProbe
        }

        if let speechEndpoint {
            speech.isEnabled = speechEndpoint.isEnabled
            speech.endpoint.apply(
                endpoint: speechEndpoint,
                sharedCredentialID: textCredentialID
            )
            speech.voiceID = speech.endpoint.provider.defaultTTSVoiceID
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
        hasUnsavedEdits = false
        saveState = .idle
        testState = .idle
    }

    mutating func applyLoadedTTSVoiceProfile(_ voiceProfile: TTSVoiceProfile) {
        guard speech.isEnabled,
              speech.endpoint.id == voiceProfile.endpointID
        else {
            return
        }
        speech.voiceID = voiceProfile.voiceID
        speech.voiceDisplayName = voiceProfile.voiceDisplayName
        speech.outputFormat = voiceProfile.outputFormat
        speech.speed = voiceProfile.speed
        speech.instructions = voiceProfile.instructions
    }

    mutating func applyEndpointIdentities(from profile: AIProviderConfigurationProfile) {
        text.endpoint.id = profile.endpoints.first { $0.purpose == .textGeneration }?.id
        speech.endpoint.id = profile.endpoints.first { $0.purpose == .tts }?.id
        embedding.endpoint.id = profile.endpoints.first { $0.purpose == .embedding }?.id
    }

    mutating func markInputChanged() {
        hasUnsavedEdits = true
        switch saveState {
        case .idle, .saved, .failed:
            saveState = hasPersistedConfiguration ? .unsavedChanges : .idle
        case .missingRequiredFields:
            if saveReadiness == .readyForRequest {
                saveState = hasPersistedConfiguration ? .unsavedChanges : .idle
            }
        case .unsavedChanges, .saving:
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
        // swiftlint:disable opening_brace
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
            // swiftlint:enable opening_brace
            embedding.endpoint.independentCredential.apiKeyDraft = secret
        }
    }
}

private extension AIProviderConfigurationProbeResult {
    func replacingLocalCapabilityResult(
        _ replacement: AIProviderProbeCapabilityResult
    ) -> AIProviderConfigurationProbeResult {
        var updated = self
        updated.capabilities = capabilities.map { result in
            result.capability == replacement.capability ? replacement : result
        }
        if !updated.capabilities.contains(where: { $0.capability == replacement.capability }) {
            updated.capabilities.append(replacement)
        }
        return updated
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
        let imageInputDecision = imageInputDecision(purpose: purpose)
        return AIProviderEndpointSaveInput(
            id: id,
            purpose: purpose,
            isEnabled: isEnabled,
            providerPresetID: provider.id,
            adapterKind: provider.coreAdapterKind,
            baseURL: baseURL,
            modelName: model,
            credentialMode: credentialMode,
            supportsImageInput: imageInputDecision.shouldPersistImageSupport,
            imageInputEnabled: imageInputEnabled && imageInputDecision.canProbe
        )
    }

    func imageInputDecision(
        purpose: LangoTraceCore.AIProviderEndpointPurpose
    ) -> AIProviderCapabilityDecision {
        AIProviderEndpointCapabilityResolver.imageInputDecision(
            provider: provider,
            adapterKind: provider.adapterKind,
            purpose: purpose,
            modelName: model
        )
    }

    func embeddingDecision() -> AIProviderCapabilityDecision {
        AIProviderEndpointCapabilityResolver.embeddingDecision(
            provider: provider,
            adapterKind: provider.adapterKind,
            purpose: .embedding,
            modelName: model
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
        // swiftlint:disable opening_brace
        if independentCredential.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let credentialID
        {
            // swiftlint:enable opening_brace
            return .existing(credentialID)
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

private extension AIOptionalModelDraftConfiguration {
    func makeTTSVoiceProfileSaveInput(languageCode: String) -> TTSVoiceProfileSaveInput? {
        guard purpose == .speech, let adapterKind = endpoint.provider.defaultTTSAdapterKind else {
            return nil
        }
        return TTSVoiceProfileSaveInput(
            endpointPurpose: .tts,
            languageCode: languageCode,
            adapterKind: adapterKind,
            voiceID: voiceID.trimmingCharacters(in: .whitespacesAndNewlines),
            voiceDisplayName: voiceDisplayName,
            outputFormat: outputFormat,
            sampleRate: nil,
            speed: speed,
            volume: nil,
            pitch: nil,
            stylePrompt: nil,
            instructions: instructions,
            streamingMode: false,
            providerParameters: ["response_format": .string(outputFormat.rawValue)]
        )
    }
}

private extension AIProviderDraftConfiguration {
    func makeTextDraftProbeEndpoint(
        imageInputDecision: AIProviderCapabilityDecision
    ) throws -> AIProviderEndpointInput? {
        guard textProbeReadiness == .readyForRequest else {
            return nil
        }
        return try AIProviderEndpointInput(
            id: text.endpoint.id ?? "draft-text-endpoint",
            profileID: profileID ?? "draft-profile",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: text.endpoint.provider.id,
            adapterKind: text.endpoint.provider.coreAdapterKind,
            baseURL: text.endpoint.baseURL,
            modelName: text.endpoint.model,
            credentialID: text.endpoint.credentialID ?? "draft-text-credential",
            supportsImageInput: imageInputDecision.shouldPersistImageSupport,
            imageInputEnabled: text.imageUnderstandingEnabled && imageInputDecision.canProbe
        ).normalized()
    }

    struct TTSDraftProbeSnapshotParts {
        var endpoint: AIProviderEndpointInput
        var settings: TTSProviderSettings
        var voiceProfile: TTSVoiceProfile
        var plaintextSecret: String?
    }

    struct EmbeddingDraftProbeSnapshotParts {
        var endpoint: AIProviderEndpointInput
        var plaintextSecret: String?
    }

    func makeTTSDraftProbeSnapshot(
        endpointID: AIProviderEndpointID,
        profileID: AIProviderProfileID,
        languageCode: String
    ) throws -> TTSDraftProbeSnapshotParts? {
        guard speech.isEnabled,
              speech.isComplete(
                  textCredential: text.endpoint.independentCredential,
                  textCredentialID: text.endpoint.credentialID
              ),
              let adapterKind = speech.endpoint.provider.defaultTTSAdapterKind,
              let voiceInput = speech.makeTTSVoiceProfileSaveInput(languageCode: languageCode)
        else {
            return nil
        }
        let endpoint = try AIProviderEndpointInput(
            id: endpointID,
            profileID: profileID,
            purpose: .tts,
            isEnabled: true,
            providerPresetID: speech.endpoint.provider.id,
            adapterKind: speech.endpoint.provider.coreAdapterKind,
            baseURL: speech.endpoint.baseURL,
            modelName: speech.endpoint.model,
            credentialID: speech.endpoint.credentialID ?? "draft-tts-credential",
            supportsImageInput: false,
            imageInputEnabled: false
        ).normalized()
        let voiceProfile = try TTSVoiceProfile.make(
            id: "draft-tts-voice-\(languageCode)",
            endpointID: endpoint.id,
            languageCode: voiceInput.languageCode,
            adapterKind: adapterKind,
            modelName: endpoint.modelName,
            voiceID: voiceInput.voiceID,
            voiceDisplayName: voiceInput.voiceDisplayName,
            outputFormat: voiceInput.outputFormat,
            sampleRate: voiceInput.sampleRate,
            speed: voiceInput.speed,
            volume: voiceInput.volume,
            pitch: voiceInput.pitch,
            stylePrompt: voiceInput.stylePrompt,
            instructions: voiceInput.instructions,
            streamingMode: voiceInput.streamingMode,
            providerParameters: voiceInput.providerParameters
        )
        let plaintextSecret: String? = switch speech.endpoint.credentialReference {
        case .textModelCredential:
            text.endpoint.independentCredential.requiresAPIKey
                ? text.endpoint.independentCredential.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil
        case .independent:
            speech.endpoint.independentCredential.requiresAPIKey
                ? speech.endpoint.independentCredential.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil
        }
        return TTSDraftProbeSnapshotParts(
            endpoint: endpoint,
            settings: TTSProviderSettings(endpointID: endpoint.id, adapterKind: adapterKind),
            voiceProfile: voiceProfile,
            plaintextSecret: plaintextSecret
        )
    }

    func makeEmbeddingDraftProbeSnapshot(
        endpointID: AIProviderEndpointID,
        profileID: AIProviderProfileID
    ) throws -> EmbeddingDraftProbeSnapshotParts? {
        guard embedding.isEnabled,
              embedding.endpoint.embeddingDecision().canProbe,
              embedding.isComplete(
                  textCredential: text.endpoint.independentCredential,
                  textCredentialID: text.endpoint.credentialID
              )
        else {
            return nil
        }
        let endpoint = try AIProviderEndpointInput(
            id: endpointID,
            profileID: profileID,
            purpose: .embedding,
            isEnabled: true,
            providerPresetID: embedding.endpoint.provider.id,
            adapterKind: embedding.endpoint.provider.coreAdapterKind,
            baseURL: embedding.endpoint.baseURL,
            modelName: embedding.endpoint.model,
            credentialID: embedding.endpoint.credentialID ?? "draft-embedding-credential",
            supportsImageInput: false,
            imageInputEnabled: false
        ).normalized()
        let plaintextSecret: String? = switch embedding.endpoint.credentialReference {
        case .textModelCredential:
            text.endpoint.independentCredential.requiresAPIKey
                ? text.endpoint.independentCredential.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil
        case .independent:
            embedding.endpoint.independentCredential.requiresAPIKey
                ? embedding.endpoint.independentCredential.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil
        }
        return EmbeddingDraftProbeSnapshotParts(
            endpoint: endpoint,
            plaintextSecret: plaintextSecret
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
