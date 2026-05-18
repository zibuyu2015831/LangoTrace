import LangoTraceData
import SwiftUI

public struct LangoTraceSettingsSceneView: View {
    private let capabilities: [SettingsCapability]

    public init(capabilities: [SettingsCapability]) {
        self.capabilities = capabilities
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionCaption(
                    titleKey: "pad.settings.section.title",
                    subtitleKey: "pad.settings.section.subtitle"
                )
                ForEach(capabilities) { capability in
                    CapabilityStatusRow(
                        localizedTitleKey: capability.kind.localizedTitleKey,
                        localizedSummaryKey: settingsCapabilityDetailLocalizationKeys(for: capability.kind).summary,
                        status: capability.status,
                        systemImage: capability.kind.systemImage,
                        action: nil
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 480)
        .langoPageBackground()
    }
}
