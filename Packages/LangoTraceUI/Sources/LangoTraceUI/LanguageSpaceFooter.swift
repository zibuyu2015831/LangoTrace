import LangoTraceCore
import SwiftUI

struct LanguageSpaceFooter: View {
    let languageSpace: LanguageSpacePreview
    let showsPrivacyStatus: Bool
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {} label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(languageSpace.name)
                            .font(isCompact ? .callout.weight(.semibold) : .headline)
                            .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                            .lineLimit(1)
                        Text(languageSpace.displayContext)
                            .font(.footnote)
                            .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("当前语言空间，\(languageSpace.displayContext)")

                Button {} label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .frame(width: isCompact ? 34 : 44, height: isCompact ? 34 : 44)
                        .background(LangoTraceDesign.ColorToken.elevatedPaper)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("设置")
            }

            if showsPrivacyStatus {
                Label("本地优先 · AI 未配置", systemImage: "lock")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    .accessibilityLabel("本地优先，AI 未配置")
            }
        }
        .padding(.top, isCompact ? 10 : 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LangoTraceDesign.ColorToken.hairline)
                .frame(height: 1)
        }
    }
}
