import LangoTraceCore
import LangoTraceData
import SwiftUI

public struct LangoTraceSettingsSceneView: View {
    private let capabilities: [SettingsCapability]
    private let languageSpace: LanguageSpacePreview?
    private let languageSpaces: [LanguageSpace]
    private let interfaceLanguagePreference: InterfaceLanguagePreference
    private let appearancePreference: AppearancePreference
    private let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    private let onSelectLanguageSpace: (String) -> Void
    private let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    private let onDeleteLanguageSpace: (String) -> Void
    private let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    private let onAppearancePreferenceChange: (AppearancePreference) -> Void
    @State private var selection: LangoTraceSettingsSceneSelection?

    public init(
        capabilities: [SettingsCapability],
        languageSpace: LanguageSpacePreview?,
        languageSpaces: [LanguageSpace] = [],
        interfaceLanguagePreference: InterfaceLanguagePreference,
        appearancePreference: AppearancePreference,
        onAddLanguageSpace: @escaping (CreateLanguageSpaceInput) -> Void = { _ in },
        onSelectLanguageSpace: @escaping (String) -> Void = { _ in },
        onUpdateLanguageSpace: @escaping (String, UpdateLanguageSpaceInput) -> Void = { _, _ in },
        onDeleteLanguageSpace: @escaping (String) -> Void = { _ in },
        onInterfaceLanguagePreferenceChange: @escaping (InterfaceLanguagePreference) -> Void,
        onAppearancePreferenceChange: @escaping (AppearancePreference) -> Void
    ) {
        self.capabilities = capabilities
        self.languageSpace = languageSpace
        self.languageSpaces = languageSpaces
        self.interfaceLanguagePreference = interfaceLanguagePreference
        self.appearancePreference = appearancePreference
        self.onAddLanguageSpace = onAddLanguageSpace
        self.onSelectLanguageSpace = onSelectLanguageSpace
        self.onUpdateLanguageSpace = onUpdateLanguageSpace
        self.onDeleteLanguageSpace = onDeleteLanguageSpace
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
        self.onAppearancePreferenceChange = onAppearancePreferenceChange
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
                    showsStatusBadge: false,
                    action: {
                        if capability.kind == .languageSpace {
                            selection = .languageSpaces
                        } else {
                            selection = .capability(capability.kind)
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var settingsDetail: some View {
        if selection == .languageSpaces {
            languageSpaceManagement
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let selectedCapability, canShowDetail(for: selectedCapability.kind) {
            SettingsCapabilityDetailView(
                languageSpace: languageSpace,
                capability: selectedCapability,
                interfaceLanguagePreference: interfaceLanguagePreference,
                appearancePreference: appearancePreference,
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                onAppearancePreferenceChange: onAppearancePreferenceChange
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

    private var selectedCapabilityKind: SettingsCapability.Kind? {
        guard case let .capability(kind) = selection else {
            return nil
        }

        return kind
    }

    private var selectedCapability: SettingsCapability? {
        guard let selectedCapabilityKind else {
            return nil
        }

        return capabilities.first { $0.kind == selectedCapabilityKind }
    }

    private func canShowDetail(for kind: SettingsCapability.Kind) -> Bool {
        languageSpace != nil
            || kind == SettingsCapability.Kind.appearance
            || kind == .interfaceLanguage
    }

    private var languageSpaceManagement: some View {
        LanguageSpaceManagementView(
            spaces: languageSpaces,
            currentSpaceID: languageSpace?.id,
            onAdd: onAddLanguageSpace,
            onSelect: onSelectLanguageSpace,
            onUpdate: onUpdateLanguageSpace,
            onDelete: onDeleteLanguageSpace
        )
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

private enum LangoTraceSettingsSceneSelection: Equatable {
    case languageSpaces
    case capability(SettingsCapability.Kind)
}
