import Foundation
@testable import LangoTraceCore
import Testing

/// E12 settings row-value derivation. These are pure value-object computations — there is
/// no credential store or network client in scope, so the "render path never reads Keychain
/// / never probes the network" boundary holds by construction.
@Suite("Settings projection models")
struct SettingsProjectionModelsTests {
    private let now = Date(timeIntervalSince1970: 100)

    private func endpoint(id: String, enabled: Bool, credentialID: String?) throws -> AIProviderEndpointConfiguration {
        try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: id,
                profileID: "profile-1",
                purpose: .textGeneration,
                isEnabled: enabled,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-5.2",
                credentialID: credentialID,
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            createdAt: now,
            updatedAt: now
        )
    }

    private func credential(id: String, presence: AIProviderSecretPresence) -> AIProviderCredentialMetadata {
        AIProviderCredentialMetadata(
            id: id,
            profileID: "profile-1",
            providerPresetID: "openai",
            kind: .apiKey,
            label: "Key",
            secretPresence: presence,
            createdAt: now,
            updatedAt: now
        )
    }

    private func profile(
        status: AIProviderProfileStatus,
        endpoints: [AIProviderEndpointConfiguration],
        credentials: [AIProviderCredentialMetadata]
    ) -> AIProviderConfigurationProfile {
        AIProviderConfigurationProfile(
            id: "profile-1",
            displayName: "Default",
            isDefault: true,
            status: status,
            createdAt: now,
            updatedAt: now,
            endpoints: endpoints,
            credentials: credentials
        )
    }

    @Test("no profile is not configured")
    func nilProfile() {
        #expect(AIProviderListStatus.make(from: nil) == .notConfigured)
    }

    @Test("a draft profile is not configured regardless of endpoints")
    func draftProfile() throws {
        let p = try profile(
            status: .draft,
            endpoints: [endpoint(id: "e1", enabled: true, credentialID: "c1")],
            credentials: [credential(id: "c1", presence: .present)]
        )
        #expect(AIProviderListStatus.make(from: p) == .notConfigured)
    }

    @Test("a profile with no enabled endpoint is not configured")
    func noEnabledEndpoint() throws {
        let p = try profile(
            status: .configured,
            endpoints: [endpoint(id: "e1", enabled: false, credentialID: "c1")],
            credentials: [credential(id: "c1", presence: .present)]
        )
        #expect(AIProviderListStatus.make(from: p) == .notConfigured)
    }

    @Test("an enabled endpoint with a present credential is configured")
    func configured() throws {
        let p = try profile(
            status: .configured,
            endpoints: [endpoint(id: "e1", enabled: true, credentialID: "c1")],
            credentials: [credential(id: "c1", presence: .present)]
        )
        #expect(AIProviderListStatus.make(from: p) == .configured)
        #expect(AIProviderListStatus.configured.footerStatus == .configured)
    }

    @Test("an enabled endpoint whose credential is missing reports missing key")
    func missingKey() throws {
        let p = try profile(
            status: .configured,
            endpoints: [endpoint(id: "e1", enabled: true, credentialID: "c1")],
            credentials: [credential(id: "c1", presence: .missing)]
        )
        #expect(AIProviderListStatus.make(from: p) == .missingKey)
        #expect(AIProviderListStatus.missingKey.footerStatus == .error)
    }

    @Test("a mix of present and missing enabled endpoints is partially available")
    func partiallyAvailable() throws {
        let p = try profile(
            status: .configured,
            endpoints: [
                endpoint(id: "e1", enabled: true, credentialID: "c1"),
                endpoint(id: "e2", enabled: true, credentialID: "c2"),
            ],
            credentials: [
                credential(id: "c1", presence: .present),
                credential(id: "c2", presence: .missing),
            ]
        )
        #expect(AIProviderListStatus.make(from: p) == .partiallyAvailable)
        #expect(AIProviderListStatus.partiallyAvailable.footerStatus == .configured)
    }

    @Test("an enabled endpoint with no credential reference reports missing key")
    func noCredentialReference() throws {
        let p = try profile(
            status: .configured,
            endpoints: [endpoint(id: "e1", enabled: true, credentialID: nil)],
            credentials: []
        )
        #expect(AIProviderListStatus.make(from: p) == .missingKey)
    }

    @Test("each AI status has a distinct localized value key")
    func aiValueKeys() {
        let keys = Set(AIProviderListStatus.allCases.map(\.localizedValueKey))
        #expect(keys.count == AIProviderListStatus.allCases.count)
        #expect(AIProviderListStatus.configured.localizedValueKey == "settings.value.aiProvider.configured")
    }

    @Test("sync status maps a disabled service to not enabled / off")
    func syncStatus() {
        #expect(SyncListStatus.make(isEnabled: false) == .notEnabled)
        #expect(SyncListStatus.notEnabled.footerStatus == .off)
        #expect(SyncListStatus.notEnabled.localizedValueKey == "settings.value.sync.notEnabled")
    }

    @Test("local data usage carries raw bytes")
    func localDataUsage() {
        #expect(LocalDataUsage(totalBytes: 1234).totalBytes == 1234)
    }
}
