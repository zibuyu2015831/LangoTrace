import LangoTraceCore
import LangoTraceData
import SwiftUI

public struct LangoTraceSettingsSceneView: View {
    private let capabilities: [SettingsCapability]
    private let languageSpace: LanguageSpacePreview?
    private let interfaceLanguagePreference: InterfaceLanguagePreference
    private let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    @State private var selectedCapabilityKind: SettingsCapability.Kind?

    public init(
        capabilities: [SettingsCapability],
        languageSpace: LanguageSpacePreview?,
        interfaceLanguagePreference: InterfaceLanguagePreference,
        onInterfaceLanguagePreferenceChange: @escaping (InterfaceLanguagePreference) -> Void
    ) {
        self.capabilities = capabilities
        self.languageSpace = languageSpace
        self.interfaceLanguagePreference = interfaceLanguagePreference
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
    }

    public var body: some View {
        HStack(spacing: 0) {
            settingsList
            Divider()
            settingsDetail
        }
        .frame(minWidth: 760, minHeight: 520)
        .langoPageBackground()
    }

    private var settingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsHeader
                capabilityRows
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 300, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.surfaceSidebar.opacity(0.72))
    }

    private var settingsHeader: some View {
        SectionCaption(
            titleKey: "pad.settings.section.title",
            subtitleKey: "pad.settings.section.subtitle"
        )
    }

    private var capabilityRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(capabilities) { capability in
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    localizedSummaryKey: settingsCapabilityDetailLocalizationKeys(for: capability.kind).summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    action: { selectedCapabilityKind = capability.kind }
                )
            }
        }
    }

    @ViewBuilder
    private var settingsDetail: some View {
        if let languageSpace, let selectedCapability {
            SettingsCapabilityDetailView(
                languageSpace: languageSpace,
                capability: selectedCapability,
                interfaceLanguagePreference: interfaceLanguagePreference,
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if languageSpace == nil {
            noLanguageSpaceBoundary
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            settingsOverview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var selectedCapability: SettingsCapability? {
        guard let selectedCapabilityKind else {
            return nil
        }

        return capabilities.first { $0.kind == selectedCapabilityKind }
    }

    private var settingsOverview: some View {
        ScrollView {
            LocalizedCompactPanel(
                titleKey: "pad.settings.section.title",
                textKey: "pad.settings.section.subtitle",
                systemImage: "gearshape"
            )
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private var noLanguageSpaceBoundary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LocalizedCompactPanel(
                    titleKey: "settings.languageSpace.title",
                    textKey: "settings.languageSpace.detail",
                    systemImage: "rectangle.stack.badge.person.crop"
                )
                LocalizedTextPanel(
                    titleKey: settingsCurrentBoundaryTitleKey,
                    textKey: "settings.sync.detail"
                )
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }
}
