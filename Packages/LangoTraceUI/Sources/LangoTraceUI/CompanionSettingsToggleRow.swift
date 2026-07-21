import SwiftUI

/// Settings row for the Language Companion on/off switch (ADR-008 §2.6, default
/// OFF). Reads + writes the feature flag straight from the environment, so it can
/// be dropped into any of the three platforms' settings lists without threading
/// the flag through every view initializer.
struct CompanionSettingsToggleRow: View {
    @Environment(\.companionFeatureEnabled) private var isEnabled
    @Environment(\.setCompanionFeatureEnabled) private var setEnabled

    var body: some View {
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { setEnabled($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                localizedText(CompanionChatCopy.settingsToggleKey)
                localizedText(CompanionChatCopy.settingsToggleDescriptionKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
