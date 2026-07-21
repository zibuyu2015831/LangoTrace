import Foundation

// Settings list row values (E12). These decouple the "current value" a user sees at a
// settings row's trailing edge (a fact about *their configuration*) from
// `SettingsCapability.status` (a development-stage marker). Per the settings status
// projection notes (2026-05-24) §4, user-facing values must come from user-perceivable
// configuration, never from development completeness, and the render path must read only
// non-sensitive snapshots — never Keychain plaintext, never a network probe.
//
// All derivations here are pure functions over already-loaded value objects, so the
// "zero Keychain / zero network" guarantee is structural: there is nothing here that
// *could* reach a credential store or the network.

/// AI provider configuration state as shown on the settings list / language-space footer.
/// Derived from the non-sensitive profile snapshot (profile status + per-endpoint enable
/// state + per-credential `secretPresence`), not from Keychain.
public enum AIProviderListStatus: String, Sendable, Equatable, CaseIterable {
    /// No usable provider configured yet (no profile, draft profile, or no enabled endpoint).
    case notConfigured
    /// At least one enabled endpoint, and every enabled endpoint's credential is present.
    case configured
    /// Enabled endpoints exist but their credentials are all missing/inaccessible.
    case missingKey
    /// Some enabled endpoints have a present credential and some do not.
    case partiallyAvailable

    /// Localization key for the muted trailing value on the settings row.
    public var localizedValueKey: String {
        switch self {
        case .notConfigured: "settings.value.aiProvider.notConfigured"
        case .configured: "settings.value.aiProvider.configured"
        case .missingKey: "settings.value.aiProvider.missingKey"
        case .partiallyAvailable: "settings.value.aiProvider.partial"
        }
    }

    /// Maps onto the narrower footer status enum (4 cases, no missing/partial split).
    /// `missingKey` surfaces as `.error` (user-actionable problem); `partiallyAvailable`
    /// surfaces as `.configured` (broadly working).
    public var footerStatus: AIProviderStatus {
        switch self {
        case .notConfigured: .notConfigured
        case .configured, .partiallyAvailable: .configured
        case .missingKey: .error
        }
    }

    /// Derives the list status from a loaded default profile (or nil if none).
    /// Pure: operates only on the non-sensitive snapshot already in memory.
    public static func make(from profile: AIProviderConfigurationProfile?) -> AIProviderListStatus {
        guard let profile, profile.status != .draft else { return .notConfigured }
        let enabledEndpoints = profile.endpoints.filter(\.isEnabled)
        guard !enabledEndpoints.isEmpty else { return .notConfigured }

        let credentialsByID = Dictionary(
            profile.credentials.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // An enabled endpoint is "ready" when it has a credential whose secret is present.
        let readiness = enabledEndpoints.map { endpoint -> Bool in
            guard let credentialID = endpoint.credentialID,
                  let credential = credentialsByID[credentialID] else { return false }
            return credential.secretPresence == .present
        }

        let readyCount = readiness.count(where: { $0 })
        if readyCount == 0 {
            return .missingKey
        }
        if readyCount == readiness.count {
            return .configured
        }
        return .partiallyAvailable
    }
}

/// Sync configuration state as shown on the settings list / footer. v1 only distinguishes
/// "not enabled" — the real iCloud/CloudKit channel is deferred (E11), so the sole truthful
/// value is sourced from `SyncService.isEnabled` (currently always false). Extensible without
/// breaking the contract once a real channel lands.
public enum SyncListStatus: String, Sendable, Equatable, CaseIterable {
    case notEnabled

    public var localizedValueKey: String {
        switch self {
        case .notEnabled: "settings.value.sync.notEnabled"
        }
    }

    public var footerStatus: SyncProviderStatus {
        switch self {
        case .notEnabled: .off
        }
    }

    public static func make(isEnabled: Bool) -> SyncListStatus {
        // Only `false` is reachable today; `true` will map to richer states when the
        // real channel lands (E11 deferred), so this stays a switch-friendly seam.
        isEnabled ? .notEnabled : .notEnabled
    }
}

/// Aggregate on-device storage footprint (database + media artifacts), in bytes. The
/// formatted, user-facing string is produced at the presentation layer (ByteCountFormatter),
/// so this model carries only the raw fact. `nil` total means "not computed yet" (the render
/// path shows a computing placeholder rather than blocking on IO).
public struct LocalDataUsage: Sendable, Equatable {
    public let totalBytes: Int64

    public init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }
}

/// The full set of settings row values an observable store publishes for the UI to render.
/// Defaults match the truthful "fresh install" state (no provider, sync off, usage not yet
/// computed), so a view that has not refreshed shows correct values rather than a mock.
public struct SettingsStatusProjection: Sendable, Equatable {
    public var aiProvider: AIProviderListStatus
    public var sync: SyncListStatus
    public var localData: LocalDataUsage?

    public init(
        aiProvider: AIProviderListStatus = .notConfigured,
        sync: SyncListStatus = .notEnabled,
        localData: LocalDataUsage? = nil
    ) {
        self.aiProvider = aiProvider
        self.sync = sync
        self.localData = localData
    }
}
