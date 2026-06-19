import LangoTraceCore
import SwiftUI

/// Presentation model for the iPhone root context toolbar (language space capsule
/// + settings gear). Pure and `Equatable` so the chrome decision is unit-testable
/// without rendering SwiftUI.
struct PhoneRootContextChrome: Equatable {
    let displayContext: String
    let showsLanguageSwitcher: Bool
    let showsSettings: Bool

    static func make(languageSpace: LanguageSpacePreview, hasSettings: Bool) -> PhoneRootContextChrome {
        PhoneRootContextChrome(
            displayContext: languageSpace.displayContext,
            showsLanguageSwitcher: true,
            showsSettings: hasSettings
        )
    }
}

extension PhoneRootTab {
    /// Every root tab — including Reading — exposes the shared context toolbar.
    /// Structural guard against the original "reading tab missing gear" regression.
    var providesRootContextToolbar: Bool {
        switch self {
        case .entries, .reading, .practice, .memory:
            true
        }
    }
}

/// Direction B "unified outlined controls": the language space capsule and the
/// settings gear share one visual family — same height, same 1px hairline, no
/// shadow, same pill shape — flanking a centered inline title. Touch targets stay
/// ≥44pt even though the painted control is smaller.
private enum PhoneRootControlMetrics {
    static let controlHeight: CGFloat = 34
    static let touchTarget: CGFloat = LangoTraceDesign.Density.minimumTouchTarget
}

private struct PhoneRootControlSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: PhoneRootControlMetrics.controlHeight)
            .background(LangoTraceDesign.ColorToken.surfacePanel, in: Capsule())
            .overlay {
                Capsule().stroke(LangoTraceDesign.ColorToken.borderSubtle, lineWidth: 1)
            }
    }
}

private extension View {
    func phoneRootControlSurface() -> some View {
        modifier(PhoneRootControlSurface())
    }
}

/// Language space context as a tappable outlined capsule (text only — the
/// displayContext string (e.g. "ZH -> EN · B1") already carries the language
/// meaning, so no leading SF Symbol). Opens the language space quick switcher.
struct PhoneLanguageSpaceChip: View {
    let displayContext: String
    let onLanguageSpaceAction: () -> Void

    var body: some View {
        Button(action: onLanguageSpaceAction) {
            Text(displayContext)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                .padding(.horizontal, 12)
                .phoneRootControlSurface()
        }
        .buttonStyle(.plain)
        .frame(minHeight: PhoneRootControlMetrics.touchTarget)
        .contentShape(Capsule())
        .accessibilityLabel(localizedText("languageSpace.switcher.label"))
        .accessibilityValue(Text(displayContext))
        .accessibilityHint(localizedText("languageSpace.switcher.hint"))
    }
}

/// Settings gear as the matching outlined control (same hairline family as the
/// chip). Visually compact; hit area kept at ≥44pt.
struct PhoneSettingsGearButton: View {
    let onSettingsAction: () -> Void

    var body: some View {
        Button(action: onSettingsAction) {
            Image(systemName: "gearshape")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                .frame(width: PhoneRootControlMetrics.controlHeight)
                .phoneRootControlSurface()
        }
        .buttonStyle(.plain)
        .frame(minWidth: PhoneRootControlMetrics.touchTarget, minHeight: PhoneRootControlMetrics.touchTarget)
        .contentShape(Capsule())
        .accessibilityLabel(localizedText("tab.settings"))
    }
}

extension View {
    /// Shared iPhone root chrome: inline centered title (page identity + push-back
    /// label) with the language space capsule as a leading toolbar item and the
    /// settings gear as a trailing toolbar item. Applying this from one modifier is
    /// what keeps all four root tabs (including Reading) structurally consistent.
    @ViewBuilder
    func phoneRootContextToolbar(
        titleKey: String,
        languageSpace: LanguageSpacePreview,
        onLanguageSpaceAction: @escaping () -> Void,
        onSettingsAction: (() -> Void)?
    ) -> some View {
        #if os(iOS)
            navigationTitle(localizedText(titleKey))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        PhoneLanguageSpaceChip(
                            displayContext: languageSpace.displayContext,
                            onLanguageSpaceAction: onLanguageSpaceAction
                        )
                    }
                    if let onSettingsAction {
                        ToolbarItem(placement: .topBarTrailing) {
                            PhoneSettingsGearButton(onSettingsAction: onSettingsAction)
                        }
                    }
                }
        #else
            navigationTitle(localizedText(titleKey))
        #endif
    }
}
