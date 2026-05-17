import LangoTraceCore
import LangoTraceData
import SwiftUI

struct SettingsCapabilityDetailView: View {
    let languageSpace: LanguageSpacePreview
    let capability: SettingsCapability
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void

    var body: some View {
        let localizationKeys = settingsCapabilityDetailLocalizationKeys(for: capability.kind)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    localizedSummaryKey: localizationKeys.summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    action: nil
                )
                if capability.kind == .interfaceLanguage {
                    interfaceLanguagePicker
                }
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
            .padding(20)
        }
        .navigationTitle(localizedText(capability.kind.localizedTitleKey))
        .langoInlineNavigationTitle()
        .langoPageBackground()
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

    private var interfaceLanguagePicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(
                selection: Binding(
                    get: { interfaceLanguagePreference },
                    set: { preference in
                        onInterfaceLanguagePreferenceChange(preference)
                    }
                )
            ) {
                ForEach(InterfaceLanguagePreference.allCases) { preference in
                    localizedText(interfaceLanguagePreferenceTitleKey(for: preference))
                        .tag(preference)
                }
            } label: {
                localizedText("settings.interfaceLanguage.title")
            }
            .pickerStyle(.inline)

            localizedText("settings.interfaceLanguage.explanation")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            localizedText("settings.interfaceLanguage.systemBoundary")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            localizedText("settings.interfaceLanguage.contentBoundary")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .langoPanel()
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
