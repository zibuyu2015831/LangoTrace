import SwiftUI

struct PracticeEntryCard: View {
    let projection: PracticeEntryCardProjection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "waveform")
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                    .frame(width: 40, height: 40)
                    .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(projection.title)
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .lineLimit(projection.titleLineLimit)
                        .truncationMode(.tail)
                    Text(projection.targetPreview)
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .lineLimit(projection.previewLineLimit)
                        .truncationMode(.tail)
                    HStack(spacing: 8) {
                        Text("\(projection.completedCount)/\(projection.sentenceCount)")
                        if projection.problemCount > 0 {
                            InlineStatusLabel(
                                text: problemCountText,
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                        Text(projection.statusText)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .lineLimit(projection.metadataLineLimit)
                    .truncationMode(.tail)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .center)
            .langoPanel(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabelText))
    }

    private var problemCountText: String {
        localizedString("practice.entryCard.problems", String(projection.problemCount))
    }

    var accessibilityLabelText: String {
        var label = localizedString(
            "practice.entryCard.accessibilityLabel",
            projection.title,
            projection.statusText,
            String(projection.completedCount),
            String(projection.sentenceCount)
        )
        if projection.problemCount > 0 {
            label += " " + problemCountText
        }
        return label
    }
}
