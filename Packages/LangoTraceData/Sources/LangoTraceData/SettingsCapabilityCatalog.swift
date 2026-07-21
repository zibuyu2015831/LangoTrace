import Foundation

/// Single source of truth for the settings capability list.
///
/// Ordering follows `SettingsCapability.Kind.allCases` (the enum declaration
/// order) and per-kind metadata (localization keys) lives only here, so the
/// real GRDB-backed repository and the in-memory fixture repository cannot
/// drift apart. Callers inject only the per-kind `CapabilityStatus`.
public enum SettingsCapabilityCatalog {
    /// Builds the full capability list in canonical order.
    ///
    /// - Parameter statuses: per-kind status supplied by the caller. Kinds
    ///   missing from the map fall back to `.unavailable` so a forgotten
    ///   entry degrades honestly instead of overstating readiness.
    public static func capabilities(
        statuses: [SettingsCapability.Kind: CapabilityStatus]
    ) -> [SettingsCapability] {
        SettingsCapability.Kind.allCases.map { kind in
            let metadata = metadata(for: kind)
            return SettingsCapability(
                kind: kind,
                status: statuses[kind] ?? .unavailable,
                summary: metadata.summary,
                detail: metadata.detail,
                nextRequirement: metadata.nextRequirement
            )
        }
    }

    private struct Metadata {
        let summary: String
        let detail: String
        let nextRequirement: String
    }

    /// Localization keys stay literal (not derived from rawValue) so they
    /// remain greppable against the UI string catalog.
    private static func metadata(for kind: SettingsCapability.Kind) -> Metadata {
        switch kind {
        case .companion:
            Metadata(
                summary: "settings.companion.summary",
                detail: "settings.companion.detail",
                nextRequirement: "settings.companion.nextRequirement"
            )
        case .languageSpace:
            Metadata(
                summary: "settings.languageSpace.summary",
                detail: "settings.languageSpace.detail",
                nextRequirement: "settings.languageSpace.nextRequirement"
            )
        case .interfaceLanguage:
            Metadata(
                summary: "settings.interfaceLanguage.summary",
                detail: "settings.interfaceLanguage.detail",
                nextRequirement: "settings.interfaceLanguage.nextRequirement"
            )
        case .appearance:
            Metadata(
                summary: "settings.appearance.summary",
                detail: "settings.appearance.detail",
                nextRequirement: "settings.appearance.nextRequirement"
            )
        case .aiProvider:
            Metadata(
                summary: "settings.aiProvider.summary",
                detail: "settings.aiProvider.detail",
                nextRequirement: "settings.aiProvider.nextRequirement"
            )
        case .sync:
            Metadata(
                summary: "settings.sync.summary",
                detail: "settings.sync.detail",
                nextRequirement: "settings.sync.nextRequirement"
            )
        case .localData:
            Metadata(
                summary: "settings.localData.summary",
                detail: "settings.localData.detail",
                nextRequirement: "settings.localData.nextRequirement"
            )
        case .privacy:
            Metadata(
                summary: "settings.privacy.summary",
                detail: "settings.privacy.detail",
                nextRequirement: "settings.privacy.nextRequirement"
            )
        case .importExport:
            Metadata(
                summary: "settings.importExport.summary",
                detail: "settings.importExport.detail",
                nextRequirement: "settings.importExport.nextRequirement"
            )
        }
    }
}
