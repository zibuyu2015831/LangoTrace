import SwiftUI

struct LangoPanelToggleButton: View {
    let systemImage: String
    let isActive: Bool
    let accessibilityLabelKey: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? LangoTraceDesign.ColorToken.teal
                        : LangoTraceDesign.ColorToken.mutedInk
                )
                .frame(width: 44, height: 44)
                .background(
                    isActive
                        ? LangoTraceDesign.ColorToken.paleTeal
                        : LangoTraceDesign.ColorToken.elevatedPaper
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedText(accessibilityLabelKey))
        .accessibilityValue(localizedText(isActive ? "accessibility.visible" : "accessibility.hidden"))
    }

    private var strokeColor: Color {
        isActive
            ? LangoTraceDesign.ColorToken.teal.opacity(0.35)
            : LangoTraceDesign.ColorToken.hairline
    }
}
