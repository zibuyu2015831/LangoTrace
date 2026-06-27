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
            } else if showsCapabilityHeader {
                header
            }

            if !capability.requiresLanguageSpaceContext || languageSpace != nil {
                if capability.kind == .companion {
                    companionSettingsContent
                } else if capability.kind == .aiProvider {
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

    private var showsCapabilityHeader: Bool {
        switch capability.kind {
        case .aiProvider:
            false
        case .interfaceLanguage, .appearance:
            false
        case .companion:
            // The companion toggle row carries its own title + description, so a separate
            // capability header would duplicate it.
            false
        default:
            true
        }
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

    @ViewBuilder
    private var aiProviderSettingsContainer: some View {
        if let languageSpace {
            VStack(alignment: .leading, spacing: 16) {
                AIProviderSettingsView(
                    languageContext: AIProviderProbeLanguageContext(languageCode: languageSpace.targetLanguageCode)
                )
                // E6: request log lives in system settings, reachable on every
                // platform (iPhone has no persistent preview card — red line).
                AIRequestLogListView()
            }
            .frame(maxWidth: aiProviderSettingsContentMaxWidth, alignment: .leading)
        } else {
            // Defensive boundary: never crash when a space-scoped detail is shown without a space.
            noLanguageSpaceBoundaryContent(
                localizationKeys: settingsCapabilityDetailLocalizationKeys(for: capability.kind)
            )
        }
    }

    @ViewBuilder
    private var syncSettingsContainer: some View {
        if let languageSpace {
            SyncSettingsView(languageSpace: languageSpace)
                .frame(maxWidth: syncSettingsContentMaxWidth, alignment: .leading)
        } else {
            // Defensive boundary: never crash when a space-scoped detail is shown without a space.
            noLanguageSpaceBoundaryContent(
                localizationKeys: settingsCapabilityDetailLocalizationKeys(for: capability.kind)
            )
        }
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

        // Appearance is purely cosmetic (light/dark/system); no clarifying
        // footnote is needed. The macOS inspector still surfaces the
        // settings.appearance.selectionFootnote copy as its descriptive panel.
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

    private var companionSettingsContent: some View {
        // The on/off switch (ADR-008 §2.6, default OFF) lives here, framed as a card, plus a
        // grounding/privacy explanation. The companion has real side effects when enabled
        // (it can send records to the provider on explicit use), so — unlike read-only
        // capabilities — it does NOT show the "no side effects" panel.
        VStack(alignment: .leading, spacing: 18) {
            CompanionSettingsToggleRow()
                .langoPanel(padding: 16)
            LocalizedTextPanel(
                titleKey: settingsCurrentBoundaryTitleKey,
                textKey: "settings.companion.detail"
            )
            LocalizedTextPanel(
                titleKey: settingsNextRequirementTitleKey,
                textKey: "settings.companion.nextRequirement"
            )
        }
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
        // Companion, appearance and interface language are device-global settings — they are
        // reachable and meaningful without a language space.
        kind != .appearance && kind != .interfaceLanguage && kind != .companion
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
