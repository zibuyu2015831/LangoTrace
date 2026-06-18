import Foundation
import LangoTraceCore
import LangoTraceData

/// Resolves the muted trailing value a settings row shows (E12). Returns an already-localized
/// string, or `nil` for rows that carry no current value (language space, privacy, import).
/// Pure presentation: it reads the projection and the user's preference values, never a
/// credential store or the network.
func settingsRowValue(
    for kind: SettingsCapability.Kind,
    status: SettingsStatusProjection,
    interfaceLanguage: InterfaceLanguagePreference,
    appearance: AppearancePreference
) -> String? {
    switch kind {
    case .interfaceLanguage:
        localizedString(interfaceLanguagePreferenceTitleKey(for: interfaceLanguage))
    case .appearance:
        localizedString(appearancePreferenceTitleKey(for: appearance))
    case .aiProvider:
        localizedString(status.aiProvider.localizedValueKey)
    case .sync:
        localizedString(status.sync.localizedValueKey)
    case .localData:
        status.localData.map { settingsLocalDataValue(bytes: $0.totalBytes) }
            ?? localizedString("settings.value.localData.computing")
    case .languageSpace, .privacy, .importExport:
        nil
    }
}

/// Formats an on-disk byte count for display (locale-aware, e.g. "1.2 MB").
func settingsLocalDataValue(bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

/// Maps the AI provider list status onto the learning panel's capability row tone.
func capabilityStatus(forAIProvider status: AIProviderListStatus) -> CapabilityStatus {
    switch status {
    case .configured, .partiallyAvailable: .ready
    case .missingKey, .notConfigured: .unavailable
    }
}

/// Maps the sync list status onto the learning panel's capability row tone.
func capabilityStatus(forSync status: SyncListStatus) -> CapabilityStatus {
    switch status {
    case .notEnabled: .unavailable
    }
}
