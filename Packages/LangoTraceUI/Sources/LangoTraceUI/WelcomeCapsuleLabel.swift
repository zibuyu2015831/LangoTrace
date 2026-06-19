import SwiftUI

struct CapsuleLabel<Title: View>: View {
    let systemImage: String
    @ViewBuilder let title: Title

    var body: some View {
        Label {
            title
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        .background(LangoTraceDesign.ColorToken.paleTeal)
        .clipShape(Capsule())
    }
}
