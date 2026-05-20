import LangoTraceCore
import SwiftUI

struct LanguageMenu: View {
    let titleKey: String
    let selectedLanguage: LearningLanguage
    let languages: [LearningLanguage]
    let onSelect: (LearningLanguage) -> Void

    var body: some View {
        Menu {
            ForEach(languages) { language in
                Button {
                    onSelect(language)
                } label: {
                    Text(language.displayTitle(for: .onboardingPicker))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedLanguage.displayTitle(for: .selectedValue))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.headline)
            .foregroundStyle(LangoTraceDesign.ColorToken.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(LangoTraceDesign.ColorToken.hairline.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.button)
        .accessibilityLabel(localizedText(titleKey))
        .accessibilityValue(selectedLanguage.displayTitle(for: .onboardingPicker))
        .accessibilityHint(localizedText(titleKey))
    }
}

struct PickerRow<PickerContent: View>: View {
    let titleKey: String
    let systemImage: String
    @ViewBuilder let picker: PickerContent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                .frame(width: 30, height: 30)
                .background(LangoTraceDesign.ColorToken.paleTeal)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                localizedText(titleKey)
                    .font(.headline)
            }
            Spacer(minLength: 12)
            picker
                .labelsHidden()
                .pickerStyle(.menu)
        }
        .frame(minHeight: 52)
    }
}
