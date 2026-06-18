import Foundation
import LangoTraceCore

/// Derives settings-list row values from non-sensitive configuration snapshots (E12).
///
/// It depends only on `AIProviderConfigurationRepository` (a pure-SQLite read; the GRDB
/// implementation does not import any Keychain type) and on `SyncService.isEnabled`. There
/// is intentionally NO reference to a credential store or HTTP client here, so the
/// "render path never reads Keychain plaintext or probes the network" boundary
/// (2026-05-24 notes §4) is enforced structurally, not by discipline.
public struct SettingsCapabilityProjectionService: Sendable {
    private let configurationRepository: any AIProviderConfigurationRepository

    public init(configurationRepository: any AIProviderConfigurationRepository) {
        self.configurationRepository = configurationRepository
    }

    /// AI provider row value, derived from the default profile's non-sensitive snapshot.
    /// Returns `.notConfigured` if the profile cannot be loaded — a stable fallback that
    /// never surfaces development-stage wording.
    public func aiProviderStatus() async -> AIProviderListStatus {
        let profile = await (try? configurationRepository.loadDefaultProfile()) ?? nil
        return AIProviderListStatus.make(from: profile)
    }

    /// Sync row value. v1 sources the sole truthful value from `isEnabled` (the real
    /// channel is deferred — E11), so this is a pure mapping with no IO.
    public nonisolated func syncStatus(isEnabled: Bool) -> SyncListStatus {
        SyncListStatus.make(isEnabled: isEnabled)
    }
}
