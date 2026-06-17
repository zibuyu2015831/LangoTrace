import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

enum LangoTraceDesign {
    struct LangoTracePalette: Equatable {
        let paper: Color
        let elevatedPaper: Color
        let panelSoft: Color
        let panelStrong: Color
        let ink: Color
        let mutedInk: Color
        let hairline: Color
        let lineSoft: Color
        let accent: Color
        let accentStrong: Color
        let accentMuted: Color
        let warning: Color
        let warningMuted: Color
        let danger: Color
        let privacyLocal: Color
        let privacyExternal: Color
        let tabBackground: Color
        let shadow: Color

        static let light = LangoTracePalette(
            paper: Color(hex: 0xF6F1E8),
            elevatedPaper: Color(hex: 0xFFFDF8),
            panelSoft: Color(hex: 0xEEE7DC),
            panelStrong: Color(hex: 0xFFFFFF),
            ink: Color(hex: 0x192220),
            mutedInk: Color(hex: 0x5A6963),
            hairline: Color(hex: 0xD7CEC0),
            lineSoft: Color(hex: 0xE9E0D3),
            accent: Color(hex: 0x126B5D),
            accentStrong: Color(hex: 0x0D544B),
            accentMuted: Color(hex: 0xE2F1EC),
            warning: Color(hex: 0x835B1F),
            warningMuted: Color(hex: 0xF3E4C9),
            danger: Color(hex: 0xAD2D25),
            privacyLocal: Color(hex: 0x23786A),
            privacyExternal: Color(hex: 0x835B1F),
            tabBackground: Color(hex: 0xFFFDF8).opacity(0.92),
            shadow: Color(hex: 0x192220).opacity(0.10)
        )

        static let dark = LangoTracePalette(
            paper: Color(hex: 0x101A18),
            elevatedPaper: Color(hex: 0x172522),
            panelSoft: Color(hex: 0x13201D),
            panelStrong: Color(hex: 0x1D2E2A),
            ink: Color(hex: 0xE8F0EA),
            mutedInk: Color(hex: 0x9AA8A1),
            hairline: Color(hex: 0x2D3C38),
            lineSoft: Color(hex: 0x24332F),
            accent: Color(hex: 0x72D2BF),
            accentStrong: Color(hex: 0x9AE5D5),
            accentMuted: Color(hex: 0x203A35),
            warning: Color(hex: 0xD8AE64),
            warningMuted: Color(hex: 0x332818),
            danger: Color(hex: 0xFF8B80),
            privacyLocal: Color(hex: 0x86D9C9),
            privacyExternal: Color(hex: 0xD8AE64),
            tabBackground: Color(hex: 0x172522).opacity(0.92),
            shadow: Color.black.opacity(0.34)
        )
    }

    enum ColorToken {
        static var paper: Color {
            dynamicColor(\.paper)
        }

        static var elevatedPaper: Color {
            dynamicColor(\.elevatedPaper)
        }

        static var ink: Color {
            dynamicColor(\.ink)
        }

        static var mutedInk: Color {
            dynamicColor(\.mutedInk)
        }

        static var hairline: Color {
            dynamicColor(\.hairline)
        }

        static var teal: Color {
            dynamicColor(\.accent)
        }

        static var deepTeal: Color {
            dynamicColor(\.accentStrong)
        }

        static var paleTeal: Color {
            dynamicColor(\.accentMuted)
        }

        static var gold: Color {
            dynamicColor(\.warning)
        }

        static var paleGold: Color {
            dynamicColor(\.warningMuted)
        }

        static var whiteInk: Color {
            dynamicColor(light: 0xFFFFFF, dark: 0x101A18)
        }

        static var surfaceBase: Color {
            paper
        }

        static var surfaceRaised: Color {
            elevatedPaper
        }

        static var surfaceMuted: Color {
            dynamicColor(\.panelSoft)
        }

        static var surfaceAccentMuted: Color {
            paleTeal
        }

        static var textPrimary: Color {
            ink
        }

        static var textSecondary: Color {
            mutedInk
        }

        static var borderSubtle: Color {
            hairline
        }

        static var accent: Color {
            teal
        }

        static var accentStrong: Color {
            deepTeal
        }

        static var primaryActionFill: Color {
            dynamicColor(light: 0x0D544B, dark: 0x23786A)
        }

        static var primaryActionForeground: Color {
            dynamicColor(light: 0xFFFFFF, dark: 0xFFFFFF)
        }

        static var switchOnFill: Color {
            dynamicColor(light: 0x126B5D, dark: 0x2C8A7B)
        }

        static var warning: Color {
            gold
        }

        static var danger: Color {
            dynamicColor(\.danger)
        }

        static var dangerMuted: Color {
            danger.opacity(0.14)
        }

        static var privacyLocal: Color {
            dynamicColor(\.privacyLocal)
        }

        static var privacyExternal: Color {
            dynamicColor(\.privacyExternal)
        }

        static var surfaceCanvas: Color {
            surfaceBase
        }

        static var surfaceSidebar: Color {
            surfaceMuted
        }

        static var surfacePanel: Color {
            surfaceRaised
        }

        static var surfaceInspector: Color {
            dynamicColor(light: 0xEEE7DC, dark: 0x13201D)
        }

        static var surfaceSelected: Color {
            surfaceAccentMuted
        }

        static var stateReady: Color {
            privacyLocal
        }

        static var stateLocalMock: Color {
            accent
        }

        static var stateUnavailable: Color {
            textSecondary
        }

        static var stateWarning: Color {
            warning
        }

        static var stateError: Color {
            danger
        }

        static var separator: Color {
            dynamicColor(\.lineSoft)
        }

        static var shadow: Color {
            dynamicColor(\.shadow)
        }

        private static func dynamicColor(_ keyPath: KeyPath<LangoTracePalette, Color>) -> Color {
            dynamicColor(
                light: LangoTracePalette.light[keyPath: keyPath],
                dark: LangoTracePalette.dark[keyPath: keyPath]
            )
        }

        private static func dynamicColor(light: UInt32, dark: UInt32) -> Color {
            dynamicColor(light: Color(hex: light), dark: Color(hex: dark))
        }

        private static func dynamicColor(light: Color, dark: Color) -> Color {
            #if os(iOS)
                Color(UIColor { traits in
                    UIColor(traits.userInterfaceStyle == .dark ? dark : light)
                })
            #elseif os(macOS)
                Color(NSColor(name: nil) { appearance in
                    let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
                    return NSColor(bestMatch == .darkAqua ? dark : light)
                })
            #else
                light
            #endif
        }
    }

    enum Typography {
        static let screenTitle = Font.largeTitle.weight(.semibold)
        static let sectionTitle = Font.headline
        static let body = Font.body
        static let bodyEmphasis = Font.body.weight(.semibold)
        static let caption = Font.caption
        static let controlLabel = Font.callout.weight(.semibold)

        /// Welcome hero display title base sizes. Usage sites must scale these with
        /// `@ScaledMetric(relativeTo: .largeTitle)` so Dynamic Type keeps working (spec 003 §4.9.2).
        static let welcomeWideTitleBaseSize: CGFloat = 46
        static let welcomeMacHeroTitleBaseSize: CGFloat = 64
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

    /// Platform (UIKit / AppKit) colors for text-storage attributes that cannot use SwiftUI `Color`.
    /// Keeps the raw accent component values (light 0x126B5D / dark 0x72D2BF) defined exactly once.
    enum PlatformColorToken {
        private static let lightAccentComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) =
            (0x12 / 255.0, 0x6B / 255.0, 0x5D / 255.0)
        private static let darkAccentComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) =
            (0x72 / 255.0, 0xD2 / 255.0, 0xBF / 255.0)

        #if os(iOS)
            static func accentHighlight(lightAlpha: CGFloat, darkAlpha: CGFloat) -> UIColor {
                UIColor { traits in
                    if traits.userInterfaceStyle == .dark {
                        UIColor(
                            red: darkAccentComponents.red,
                            green: darkAccentComponents.green,
                            blue: darkAccentComponents.blue,
                            alpha: darkAlpha
                        )
                    } else {
                        UIColor(
                            red: lightAccentComponents.red,
                            green: lightAccentComponents.green,
                            blue: lightAccentComponents.blue,
                            alpha: lightAlpha
                        )
                    }
                }
            }

        #elseif os(macOS)
            static func accentHighlight(lightAlpha: CGFloat, darkAlpha: CGFloat) -> NSColor {
                NSColor(name: nil) { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    if isDark {
                        return NSColor(
                            srgbRed: darkAccentComponents.red,
                            green: darkAccentComponents.green,
                            blue: darkAccentComponents.blue,
                            alpha: darkAlpha
                        )
                    }
                    return NSColor(
                        srgbRed: lightAccentComponents.red,
                        green: lightAccentComponents.green,
                        blue: lightAccentComponents.blue,
                        alpha: lightAlpha
                    )
                }
            }
        #endif
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
        shadow(color: LangoTraceDesign.ColorToken.shadow, radius: 16, x: 0, y: 8)
    }

    func langoTextFieldStyle() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(LangoTraceDesign.ColorToken.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(LangoTraceDesign.ColorToken.borderSubtle, lineWidth: 1)
            }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
