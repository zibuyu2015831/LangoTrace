import LangoTraceCore
import LangoTraceData
import SwiftUI

enum SettingsCapabilityDetailPresentation: Equatable {
    case standaloneScrollable
    case embeddedInExistingScroll
}

struct SettingsCapabilityDetailView: View {
    let languageSpace: LanguageSpacePreview?
    let capability: SettingsCapability
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onAppearancePreferenceChange: (AppearancePreference) -> Void
    let presentation: SettingsCapabilityDetailPresentation

    init(
        languageSpace: LanguageSpacePreview?,
        capability: SettingsCapability,
        interfaceLanguagePreference: InterfaceLanguagePreference,
        appearancePreference: AppearancePreference,
        presentation: SettingsCapabilityDetailPresentation = .standaloneScrollable,
        onInterfaceLanguagePreferenceChange: @escaping (InterfaceLanguagePreference) -> Void,
        onAppearancePreferenceChange: @escaping (AppearancePreference) -> Void
    ) {
        self.languageSpace = languageSpace
        self.capability = capability
        self.interfaceLanguagePreference = interfaceLanguagePreference
        self.appearancePreference = appearancePreference
        self.presentation = presentation
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
        self.onAppearancePreferenceChange = onAppearancePreferenceChange
    }

    var body: some View {
        Group {
            switch presentation {
            case .standaloneScrollable:
                ScrollView {
                    detailContent
                }
            case .embeddedInExistingScroll:
                detailContent
            }
        }
        .navigationTitle(localizedText(capability.kind.localizedTitleKey))
        .langoInlineNavigationTitle()
        .langoPageBackground()
    }

    private var detailContent: some View {
        let localizationKeys = settingsCapabilityDetailLocalizationKeys(for: capability.kind)

        return VStack(alignment: .leading, spacing: 18) {
            if capability.requiresLanguageSpaceContext, languageSpace == nil {
                noLanguageSpaceBoundaryContent(localizationKeys: localizationKeys)
            } else if capability.kind != .interfaceLanguage, capability.kind != .appearance {
                header
            }

            if !capability.requiresLanguageSpaceContext || languageSpace != nil {
                if capability.kind == .aiProvider {
                    aiProviderSettingsContainer
                } else if capability.kind == .sync {
                    syncSettingsContainer
                } else if capability.kind == .interfaceLanguage {
                    interfaceLanguageSettingsContent
                } else if capability.kind == .appearance {
                    appearanceSettingsContent
                } else {
                    defaultCapabilityContent(localizationKeys: localizationKeys)
                }
            }
        }
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            localizedText(capability.kind.localizedTitleKey)
                .font(.headline)
            Text(languageSpace?.displayContext ?? localizedString("settings.globalDeviceContext"))
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .padding(.top, 4)
    }

    private var aiProviderSettingsContainer: some View {
        let languageSpace = requiredLanguageSpace

        return AIProviderSettingsView(
            languageContext: AIProviderProbeLanguageContext(languageCode: languageSpace.targetLanguageCode)
        )
        .frame(maxWidth: aiProviderSettingsContentMaxWidth, alignment: .leading)
    }

    private var syncSettingsContainer: some View {
        SyncSettingsView(languageSpace: requiredLanguageSpace)
            .frame(maxWidth: syncSettingsContentMaxWidth, alignment: .leading)
    }

    private var requiredLanguageSpace: LanguageSpacePreview {
        guard let languageSpace else {
            preconditionFailure("Space-scoped settings require a real language space.")
        }
        return languageSpace
    }

    private var aiProviderSettingsContentMaxWidth: CGFloat {
        #if os(macOS)
            860
        #else
            820
        #endif
    }

    private var syncSettingsContentMaxWidth: CGFloat {
        #if os(macOS)
            860
        #else
            820
        #endif
    }

    private var interfaceLanguageSettingsContent: some View {
        let preferences = InterfaceLanguagePreference.allCases

        return VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(preferences.enumerated()), id: \.element.id) { index, preference in
                    interfaceLanguageOptionRow(for: preference)
                    if index < preferences.count - 1 {
                        Divider()
                    }
                }
            }
            .langoPanel(padding: 0)

            localizedText("settings.interfaceLanguage.selectionFootnote")
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private var appearanceSettingsContent: some View {
        let preferences = AppearancePreference.allCases

        return VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(preferences.enumerated()), id: \.element.id) { index, preference in
                    appearanceOptionRow(for: preference)
                    if index < preferences.count - 1 {
                        Divider()
                    }
                }
            }
            .langoPanel(padding: 0)

            localizedText("settings.appearance.selectionFootnote")
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private func interfaceLanguageOptionRow(for preference: InterfaceLanguagePreference) -> some View {
        let isSelected = interfaceLanguagePreference == preference

        return Button {
            guard interfaceLanguagePreference != preference else {
                return
            }
            onInterfaceLanguagePreferenceChange(preference)
        } label: {
            HStack(spacing: 12) {
                localizedText(interfaceLanguagePreferenceTitleKey(for: preference))
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedText(interfaceLanguagePreferenceTitleKey(for: preference)))
        .accessibilityValue(localizedText(isSelected ? "accessibility.selected" : "accessibility.unselected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func appearanceOptionRow(for preference: AppearancePreference) -> some View {
        let isSelected = appearancePreference == preference

        return Button {
            guard appearancePreference != preference else {
                return
            }
            onAppearancePreferenceChange(preference)
        } label: {
            HStack(spacing: 12) {
                localizedText(appearancePreferenceTitleKey(for: preference))
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedText(appearancePreferenceTitleKey(for: preference)))
        .accessibilityValue(localizedText(isSelected ? "accessibility.selected" : "accessibility.unselected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func defaultCapabilityContent(
        localizationKeys: SettingsCapabilityDetailLocalizationKeys
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            CapabilityStatusRow(
                localizedTitleKey: capability.kind.localizedTitleKey,
                localizedSummaryKey: localizationKeys.summary,
                status: capability.status,
                systemImage: capability.kind.systemImage,
                action: nil
            )
            LocalizedTextPanel(
                titleKey: settingsCurrentBoundaryTitleKey,
                textKey: localizationKeys.detail
            )
            LocalizedTextPanel(
                titleKey: settingsNextRequirementTitleKey,
                textKey: localizationKeys.nextRequirement
            )
            LocalizedTextPanel(
                titleKey: settingsNoSideEffectsTitleKey,
                textKey: settingsNoSideEffectsBodyKey
            )
        }
    }

    private func noLanguageSpaceBoundaryContent(
        localizationKeys: SettingsCapabilityDetailLocalizationKeys
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            CapabilityStatusRow(
                localizedTitleKey: capability.kind.localizedTitleKey,
                localizedSummaryKey: localizationKeys.summary,
                status: capability.status,
                systemImage: capability.kind.systemImage,
                action: nil
            )
            LocalizedTextPanel(
                titleKey: "settings.languageSpace.title",
                textKey: "settings.languageSpace.detail"
            )
            LocalizedTextPanel(
                titleKey: settingsCurrentBoundaryTitleKey,
                textKey: localizationKeys.detail
            )
        }
    }
}

private extension SettingsCapability {
    var requiresLanguageSpaceContext: Bool {
        kind != .appearance && kind != .interfaceLanguage
    }
}

private extension View {
    @ViewBuilder
    func langoInlineNavigationTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
