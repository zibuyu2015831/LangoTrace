import SwiftUI

struct LocalizedTextPanel: View {
    let titleKey: String
    let textKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LocalizedText(titleKey)
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            LocalizedText(textKey)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .langoPanel()
    }
}
