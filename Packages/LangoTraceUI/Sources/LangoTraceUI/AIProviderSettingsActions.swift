import LangoTraceCore
import SwiftUI

public struct AIProviderSettingsActions: Sendable {
    public var loadDefaultProfile: @Sendable () async throws -> AIProviderConfigurationProfile?
    public var saveDefaultProfile: @Sendable (AIProviderProfileSaveInput) async throws -> AIProviderConfigurationProfile
    public var validateDefaultProfileCredentials: @Sendable () async throws -> AIProviderValidationStatus

    public init(
        loadDefaultProfile: @escaping @Sendable () async throws -> AIProviderConfigurationProfile? = { nil },
        saveDefaultProfile: @escaping @Sendable (AIProviderProfileSaveInput) async throws
            -> AIProviderConfigurationProfile = { _ in
                throw AIProviderConfigurationError.databaseWriteFailed
            },
        validateDefaultProfileCredentials: @escaping @Sendable () async throws -> AIProviderValidationStatus = {
            throw AIProviderConfigurationError.keychainWriteFailed
        }
    ) {
        self.loadDefaultProfile = loadDefaultProfile
        self.saveDefaultProfile = saveDefaultProfile
        self.validateDefaultProfileCredentials = validateDefaultProfileCredentials
    }
}

public extension EnvironmentValues {
    @Entry var aiProviderSettingsActions = AIProviderSettingsActions()
}
