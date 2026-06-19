import Foundation
import LangoTraceCore
import SwiftUI

public struct AIProviderSettingsActions: Sendable {
    public var loadDefaultProfile: @Sendable () async throws -> AIProviderConfigurationProfile?
    public var loadTTSVoiceProfile: @Sendable (AIProviderEndpointID, String) async throws -> TTSVoiceProfile?
    public var resolveCredentialSecret: @Sendable (AIProviderCredentialMetadata) async throws -> String?
    public var saveDefaultProfile: @Sendable (AIProviderProfileSaveInput, DiagnosticOperationID) async throws
        -> AIProviderConfigurationProfile
    public var validateDefaultProfileCredentials: @Sendable () async throws -> AIProviderValidationStatus
    var testProviderConfiguration: @Sendable (
        AIProviderProbeSource,
        AIProviderDraftProbeSnapshot?,
        AIProviderProbeLanguageContext?,
        DiagnosticOperationID
    ) async throws -> AIProviderConfigurationProbeResult
    public var playSpeechPreview: @Sendable (TTSAudioPreviewResource) async -> Void
    public var recordDiagnosticEvent: @Sendable (DiagnosticEvent) async -> Void
    public var operationIDGenerator: @Sendable () -> DiagnosticOperationID

    public init(
        loadDefaultProfile: @escaping @Sendable () async throws -> AIProviderConfigurationProfile? = { nil },
        loadTTSVoiceProfile: @escaping @Sendable (
            AIProviderEndpointID,
            String
        ) async throws -> TTSVoiceProfile? = { _, _ in nil },
        resolveCredentialSecret: @escaping @Sendable (
            AIProviderCredentialMetadata
        ) async throws -> String? = { _ in nil },
        saveDefaultProfile: @escaping @Sendable (AIProviderProfileSaveInput, DiagnosticOperationID) async throws
            -> AIProviderConfigurationProfile = { _, operationID in
                throw AIProviderConfigurationSaveFailure(
                    operationID: operationID,
                    phase: .databaseWrite,
                    category: .databaseWriteFailed
                )
            },
        validateDefaultProfileCredentials: @escaping @Sendable () async throws -> AIProviderValidationStatus = {
            throw AIProviderConfigurationError.keychainWriteFailed
        },
        testProviderConfiguration: @escaping @Sendable (
            AIProviderProbeSource,
            AIProviderDraftProbeSnapshot?,
            AIProviderProbeLanguageContext?,
            DiagnosticOperationID
        ) async throws -> AIProviderConfigurationProbeResult = { _, _, _, _ in
            AIProviderConfigurationProbeResult(
                source: .draft,
                overallStatus: .failed,
                providerPresetID: "unknown",
                modelName: "",
                capabilities: [
                    .init(
                        capability: .textReply,
                        status: .unsupported,
                        errorCategory: .unsupportedEndpointPurpose,
                        durationMilliseconds: nil
                    ),
                ],
                persistedValidationEventID: nil
            )
        },
        playSpeechPreview: @escaping @Sendable (TTSAudioPreviewResource) async -> Void = { _ in },
        recordDiagnosticEvent: @escaping @Sendable (DiagnosticEvent) async -> Void = { _ in },
        operationIDGenerator: @escaping @Sendable () -> DiagnosticOperationID = {
            DiagnosticOperationID(rawValue: UUID().uuidString)
        }
    ) {
        self.loadDefaultProfile = loadDefaultProfile
        self.loadTTSVoiceProfile = loadTTSVoiceProfile
        self.resolveCredentialSecret = resolveCredentialSecret
        self.saveDefaultProfile = saveDefaultProfile
        self.validateDefaultProfileCredentials = validateDefaultProfileCredentials
        self.testProviderConfiguration = testProviderConfiguration
        self.playSpeechPreview = playSpeechPreview
        self.recordDiagnosticEvent = recordDiagnosticEvent
        self.operationIDGenerator = operationIDGenerator
    }
}

public extension EnvironmentValues {
    @Entry var aiProviderSettingsActions = AIProviderSettingsActions()
}
