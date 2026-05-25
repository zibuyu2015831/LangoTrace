import LangoTraceData
import SwiftUI

struct PracticeContinuePanel: View {
    let entry: LearningEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                VStack(alignment: .leading, spacing: 5) {
                    localizedText("practice.continue.title")
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    Text(entry.title)
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            .langoPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("practice.continue.accessibilityLabel", entry.title))
    }
}

struct PracticeTaskRow: View {
    let title: String
    let summary: String
    let systemImage: String
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content(showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityHint(summary)
            } else {
                content(showsChevron: false)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func content(showsChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .frame(width: 36, height: 36)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Circle())
            textContent
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 16)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            Text(summary)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

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
                            Text("!")
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
            .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 132, alignment: .center)
            .langoPanel(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(projection.title)
    }
}
