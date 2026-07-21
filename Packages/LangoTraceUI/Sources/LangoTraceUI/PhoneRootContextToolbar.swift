import LangoTraceCore
import SwiftUI

/// Presentation model for the iPhone root context toolbar (language space chip
/// + settings gear). Pure and `Equatable` so the chrome decision is unit-testable
/// without rendering SwiftUI.
struct PhoneRootContextChrome: Equatable {
    /// Full native -> target · level string, exposed to VoiceOver as the chip value.
    let displayContext: String
    /// Target language alone, shown in the chip (design review round 4). One space
    /// maps to one language (core decision #4), so the language identifies the space;
    /// the level is a rarely-changing self-assessment and stays in the VoiceOver value.
    /// spec/002 §54 / §157 phrase the example with "e.g." before the target+level
    /// string, so showing the lighter target language alone is within bounds.
    let compactContext: String
    let showsLanguageSwitcher: Bool
    let showsSettings: Bool

    static func make(languageSpace: LanguageSpacePreview, hasSettings: Bool) -> PhoneRootContextChrome {
        PhoneRootContextChrome(
            displayContext: languageSpace.displayContext,
            compactContext: languageSpace.targetLanguage,
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

/// Borderless, restrained controls (design review round 2): the language chip and
/// the settings gear carry no outline or fill — strokes are reserved for the
/// content cards below. Balance comes from shared low contrast, not matched width.
/// Touch targets stay ≥44pt even though the painted glyphs are small.
private enum PhoneRootControlMetrics {
    static let touchTarget: CGFloat = LangoTraceDesign.Density.minimumTouchTarget
}

/// Language space context as a quiet, tappable label: compact target + level with
/// a small chevron to signal the switcher. No border, no fill.
struct PhoneLanguageSpaceChip: View {
    let label: String
    let accessibilityContext: String
    let onLanguageSpaceAction: () -> Void

    var body: some View {
        Button(action: onLanguageSpaceAction) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    // Keep intrinsic width so the centered inline title cannot
                    // compress the leading item into a single glyph.
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: PhoneRootControlMetrics.touchTarget)
        .accessibilityLabel(localizedText("languageSpace.switcher.label"))
        .accessibilityValue(Text(accessibilityContext))
        .accessibilityHint(localizedText("languageSpace.switcher.hint"))
    }
}

/// Settings gear as a bare icon — no outline or fill, matching the chip's
/// restraint. Hit area kept at ≥44pt.
struct PhoneSettingsGearButton: View {
    let onSettingsAction: () -> Void

    var body: some View {
        Button(action: onSettingsAction) {
            Image(systemName: "gearshape")
                .font(.body.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .frame(width: PhoneRootControlMetrics.touchTarget, height: PhoneRootControlMetrics.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedText("tab.settings"))
    }
}

extension View {
    /// Shared iPhone root chrome: inline centered title (page identity + push-back
    /// label) with the language space chip as a leading toolbar item and the
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
            let chrome = PhoneRootContextChrome.make(
                languageSpace: languageSpace,
                hasSettings: onSettingsAction != nil
            )
            navigationTitle(localizedText(titleKey))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        PhoneLanguageSpaceChip(
                            label: chrome.compactContext,
                            accessibilityContext: chrome.displayContext,
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
