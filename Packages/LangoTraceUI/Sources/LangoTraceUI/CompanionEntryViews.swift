import SwiftUI

/// Practice-tab secondary entry into the Language Companion (ADR-008 §3). Shown
/// only when the feature is enabled. Launches a cold-start conversation (no seed).
struct CompanionEntryCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                VStack(alignment: .leading, spacing: 2) {
                    localizedText(CompanionChatCopy.entryTitleKey)
                        .font(.headline)
                    localizedText(CompanionChatCopy.settingsToggleDescriptionKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LangoTraceDesign.ColorToken.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Entry-detail "talk about this record" button (ADR-008 §3 / plan-A seed). Shown
/// only when the feature is enabled; passes the entry id as the conversation seed.
struct CompanionEntryDetailButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                localizedText(CompanionChatCopy.entryDetailActionKey)
            } icon: {
                Image(systemName: "bubble.left.and.bubble.right")
            }
        }
    }
}
