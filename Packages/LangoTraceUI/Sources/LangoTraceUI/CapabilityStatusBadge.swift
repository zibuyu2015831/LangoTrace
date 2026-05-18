import LangoTraceData
import SwiftUI

struct CapabilityStatusBadge: View {
    let status: CapabilityStatus

    var body: some View {
        localizedText(status.localizedTitleKey)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status.visualTone {
        case .ready:
            LangoTraceDesign.ColorToken.stateReady
        case .localMock:
            LangoTraceDesign.ColorToken.stateLocalMock
        case .unavailable:
            LangoTraceDesign.ColorToken.stateUnavailable
        case .warning:
            LangoTraceDesign.ColorToken.stateWarning
        case .error:
            LangoTraceDesign.ColorToken.stateError
        case .info:
            LangoTraceDesign.ColorToken.accent
        }
    }
}
