import LangoTraceData
import SwiftUI

struct EntryDetailHeader: View {
    let entry: LearningEntry
    let targetLanguage: String
    let rendering: LearningRendering?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                CapabilityStatusBadge(status: EntryRenderingStatus.status(for: rendering))
            }
            Text("\(entry.displaySourceTitle) · \(targetLanguage) · \(entry.scene)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            localizedText("entryDetail.header.boundary")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
