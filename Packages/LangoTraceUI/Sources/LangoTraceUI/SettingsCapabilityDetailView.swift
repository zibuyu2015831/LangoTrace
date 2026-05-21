import LangoTraceCore
import LangoTraceData
import SwiftUI

enum SettingsCapabilityDetailPresentation: Equatable {
    case standaloneScrollable
    case embeddedInExistingScroll
}

struct SettingsCapabilityDetailView: View {
    let languageSpace: LanguageSpacePreview
    let capability: SettingsCapability
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let presentation: SettingsCapabilityDetailPresentation

    init(
        languageSpace: LanguageSpacePreview,
        capability: SettingsCapability,
        interfaceLanguagePreference: InterfaceLanguagePreference,
        presentation: SettingsCapabilityDetailPresentation = .standaloneScrollable,
        onInterfaceLanguagePreferenceChange: @escaping (InterfaceLanguagePreference) -> Void
    ) {
        self.languageSpace = languageSpace
        self.capability = capability
        self.interfaceLanguagePreference = interfaceLanguagePreference
        self.presentation = presentation
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
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
            if capability.kind != .interfaceLanguage {
                header
            }
            if capability.kind == .aiProvider {
                aiProviderSettingsContainer
            } else if capability.kind == .sync {
                syncSettingsContainer
            } else if capability.kind == .interfaceLanguage {
                interfaceLanguageSettingsContent
            } else {
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
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            localizedText(capability.kind.localizedTitleKey)
                .font(.headline)
            Text(languageSpace.displayContext)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .padding(.top, 4)
    }

    private var aiProviderSettingsContainer: some View {
        #if os(iOS)
            AIProviderSettingsView(
                languageContext: AIProviderProbeLanguageContext(languageCode: languageSpace.targetLanguageCode)
            )
            .frame(maxWidth: aiProviderSettingsContentMaxWidth, alignment: .leading)
        #else
            AIProviderSettingsView()
            .frame(maxWidth: aiProviderSettingsContentMaxWidth, alignment: .leading)
        #endif
    }

    private var syncSettingsContainer: some View {
        SyncSettingsView(languageSpace: languageSpace)
            .frame(maxWidth: syncSettingsContentMaxWidth, alignment: .leading)
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
