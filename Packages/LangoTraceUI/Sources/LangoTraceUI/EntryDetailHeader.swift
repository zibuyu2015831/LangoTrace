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
            Text("生活记录和目标语言版本保持来源关系；当前学习材料为本地示例，不会发送外部请求。")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
