import LangoTraceData
import SwiftUI

struct UnavailableCapabilityView: View {
    let title: String
    let summary: String
    let nextRequirement: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CapabilityStatusRow(
                title: title,
                summary: summary,
                status: .unavailable,
                systemImage: systemImage,
                action: nil
            )
            TextPanel(title: "后续接入条件", text: nextRequirement)
            TextPanel(
                title: "不会发生",
                text: "当前不会访问照片、麦克风、网络、Keychain、真实数据库、同步服务或导出文件。"
            )
        }
        .padding(20)
        .langoPageBackground()
    }
}
