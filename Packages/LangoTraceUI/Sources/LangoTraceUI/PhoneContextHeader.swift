import LangoTraceCore
import SwiftUI

struct PhoneContextHeader: View {
    let languageSpace: LanguageSpacePreview
    let onLanguageSpaceAction: () -> Void
    let onSettingsAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onLanguageSpaceAction) {
                Label(languageSpace.displayContext, systemImage: "text.badge.star")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localizedText("languageSpace.switcher.label"))
            .accessibilityValue(Text(languageSpace.displayContext))
            .accessibilityHint(localizedText("languageSpace.switcher.hint"))

            Spacer(minLength: 8)

            if let onSettingsAction {
                Button(action: onSettingsAction) {
                    Image(systemName: "gearshape")
                        .font(.headline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(LangoTraceDesign.ColorToken.surfacePanel)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(LangoTraceDesign.ColorToken.borderSubtle)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("tab.settings"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
