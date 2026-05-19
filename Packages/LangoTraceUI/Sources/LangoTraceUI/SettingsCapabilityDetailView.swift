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
            header
            if capability.kind == .aiProvider {
                aiProviderSettingsContainer
            } else if capability.kind == .sync {
                syncSettingsContainer
            } else {
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    localizedSummaryKey: localizationKeys.summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    action: nil
                )
            }
            if capability.kind == .interfaceLanguage {
                interfaceLanguagePicker
            }
            if capability.kind != .aiProvider, capability.kind != .sync {
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
        AIProviderSettingsView()
            .frame(maxWidth: aiProviderSettingsContentMaxWidth, alignment: .leading)
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
