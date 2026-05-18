import LangoTraceCore
import SwiftUI

struct LanguageSpaceSummaryView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        localizedText("settings.languageSpace.title")
                    } icon: {
                        Image(systemName: "text.badge.star")
                    }
                    .font(.headline)

                    Text(languageSpace.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(languageSpace.displayContext)
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .langoPanel()

                CapabilityStatusRow(
                    localizedTitleKey: "app.badge.localFirst",
                    localizedSummaryKey: "settings.languageSpace.summary",
                    status: .mockOnly,
                    systemImage: "lock",
                    action: nil
                )

                LocalizedTextPanel(
                    titleKey: settingsCurrentBoundaryTitleKey,
                    textKey: "settings.languageSpace.detail"
                )
                LocalizedTextPanel(
                    titleKey: settingsNextRequirementTitleKey,
                    textKey: "settings.languageSpace.nextRequirement"
                )
                LocalizedTextPanel(
                    titleKey: settingsNoSideEffectsTitleKey,
                    textKey: settingsNoSideEffectsBodyKey
                )
            }
            .padding(20)
        }
        .navigationTitle(localizedText("settings.languageSpace.title"))
        .langoPageBackground()
    }
}
