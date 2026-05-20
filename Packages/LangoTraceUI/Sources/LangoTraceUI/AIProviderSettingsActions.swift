import Foundation
import LangoTraceCore
import SwiftUI

public struct AIProviderSettingsActions: Sendable {
    public var loadDefaultProfile: @Sendable () async throws -> AIProviderConfigurationProfile?
    public var saveDefaultProfile: @Sendable (AIProviderProfileSaveInput, DiagnosticOperationID) async throws
        -> AIProviderConfigurationProfile
    public var validateDefaultProfileCredentials: @Sendable () async throws -> AIProviderValidationStatus
    public var recordDiagnosticEvent: @Sendable (DiagnosticEvent) async -> Void
    public var operationIDGenerator: @Sendable () -> DiagnosticOperationID

    public init(
        loadDefaultProfile: @escaping @Sendable () async throws -> AIProviderConfigurationProfile? = { nil },
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
        recordDiagnosticEvent: @escaping @Sendable (DiagnosticEvent) async -> Void = { _ in },
        operationIDGenerator: @escaping @Sendable () -> DiagnosticOperationID = {
            DiagnosticOperationID(rawValue: UUID().uuidString)
        }
    ) {
        self.loadDefaultProfile = loadDefaultProfile
        self.saveDefaultProfile = saveDefaultProfile
        self.validateDefaultProfileCredentials = validateDefaultProfileCredentials
        self.recordDiagnosticEvent = recordDiagnosticEvent
        self.operationIDGenerator = operationIDGenerator
    }
}

public extension EnvironmentValues {
    @Entry var aiProviderSettingsActions = AIProviderSettingsActions()
}
