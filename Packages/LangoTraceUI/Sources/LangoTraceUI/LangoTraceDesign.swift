import SwiftUI

enum LangoTraceDesign {
    enum ColorToken {
        static let paper = Color(red: 0.965, green: 0.949, blue: 0.918)
        static let elevatedPaper = Color(red: 0.992, green: 0.984, blue: 0.961)
        static let ink = Color(red: 0.105, green: 0.121, blue: 0.126)
        static let mutedInk = Color(red: 0.425, green: 0.467, blue: 0.500)
        static let hairline = Color(red: 0.865, green: 0.835, blue: 0.780)
        static let teal = Color(red: 0.070, green: 0.420, blue: 0.365)
        static let deepTeal = Color(red: 0.050, green: 0.330, blue: 0.295)
        static let paleTeal = Color(red: 0.875, green: 0.945, blue: 0.925)
        static let gold = Color(red: 0.690, green: 0.505, blue: 0.215)
        static let paleGold = Color(red: 0.965, green: 0.920, blue: 0.800)
        static let whiteInk = Color(red: 0.985, green: 0.980, blue: 0.960)
        static let surfaceBase = paper
        static let surfaceRaised = elevatedPaper
        static let surfaceMuted = Color(red: 0.945, green: 0.930, blue: 0.895)
        static let surfaceAccentMuted = paleTeal
        static let textPrimary = ink
        static let textSecondary = mutedInk
        static let borderSubtle = hairline
        static let accent = teal
        static let accentStrong = deepTeal
        static let warning = gold
        static let danger = Color(red: 0.680, green: 0.155, blue: 0.130)
        static let dangerMuted = Color(red: 0.985, green: 0.900, blue: 0.860)
        static let privacyLocal = deepTeal
        static let privacyExternal = gold
        static let surfaceCanvas = surfaceBase
        static let surfaceSidebar = surfaceMuted
        static let surfacePanel = surfaceRaised
        static let surfaceInspector = Color(red: 0.955, green: 0.942, blue: 0.910)
        static let surfaceSelected = surfaceAccentMuted
        static let stateReady = privacyLocal
        static let stateLocalMock = accent
        static let stateUnavailable = textSecondary
        static let stateWarning = warning
        static let stateError = danger
        static let separator = borderSubtle
    }

    enum Typography {
        static let screenTitle = Font.largeTitle.weight(.semibold)
        static let sectionTitle = Font.headline
        static let body = Font.body
        static let bodyEmphasis = Font.body.weight(.semibold)
        static let caption = Font.caption
        static let controlLabel = Font.callout.weight(.semibold)
    }

    enum Radius {
        static let panel: CGFloat = 18
        static let control: CGFloat = 12
        static let badge: CGFloat = 999
        static let sheet: CGFloat = 22
    }

    enum Spacing {
        static let page: CGFloat = 24
        static let section: CGFloat = 18
        static let compact: CGFloat = 10
    }

    enum Density {
        static let minimumTouchTarget: CGFloat = 44
        static let phonePagePadding: CGFloat = 20
        static let padSidebarWidth: CGFloat = 270
        static let padInspectorWidth: CGFloat = 330
        static let macSidebarWidth: CGFloat = 300
        static let macInspectorWidth: CGFloat = 340
    }

    enum Motion {
        static let panelTransitionDuration: TimeInterval = 0.18
        static let microFeedbackDuration: TimeInterval = 0.12
    }
}

extension View {
    func langoPanel(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(LangoTraceDesign.ColorToken.elevatedPaper)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.panel, style: .continuous)
                    .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
            }
    }

    func langoPageBackground() -> some View {
        background(LangoTraceDesign.ColorToken.paper)
            .foregroundStyle(LangoTraceDesign.ColorToken.ink)
    }

    func langoSoftShadow() -> some View {
        shadow(color: LangoTraceDesign.ColorToken.ink.opacity(0.07), radius: 16, x: 0, y: 8)
    }
}
