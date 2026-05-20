import LangoTraceCore

public struct AIProviderConfigurationService: Sendable {
    private let repository: any AIProviderConfigurationRepository

    public init(repository: any AIProviderConfigurationRepository) {
        self.repository = repository
    }

    public func loadDefaultProfile() async throws -> AIProviderConfigurationProfile? {
        try await repository.loadDefaultProfile()
    }

    public func validateEndpointInput(
        _ input: AIProviderEndpointInput
    ) throws -> AIProviderEndpointInput {
        try input.normalized()
    }
}
