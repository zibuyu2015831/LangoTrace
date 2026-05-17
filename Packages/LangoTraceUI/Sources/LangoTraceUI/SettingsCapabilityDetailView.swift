import LangoTraceCore
import LangoTraceData
import SwiftUI

struct SettingsCapabilityDetailView: View {
    let languageSpace: LanguageSpacePreview
    let capability: SettingsCapability
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    summary: capability.summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    action: nil
                )
                if capability.kind == .interfaceLanguage {
                    interfaceLanguagePicker
                }
                TextPanel(title: "当前边界", text: capability.detail)
                TextPanel(title: "后续接入条件", text: capability.nextRequirement)
                TextPanel(
                    title: "不会发生",
                    text: "本页不会保存密钥、不会写入真实数据库、不会访问照片或麦克风、不会发起网络请求。"
                )
            }
            .padding(20)
        }
        .navigationTitle(localizedText(capability.kind.localizedTitleKey))
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
