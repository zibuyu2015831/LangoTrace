import LangoTraceData
import SwiftUI

struct EntryDetailHeader: View {
    let entry: LearningEntry

    var body: some View {
        Text(entry.title)
            .font(.title2.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
    }
}
