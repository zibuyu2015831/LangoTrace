import LangoTraceCore
import SwiftUI

/// Single-select preset scene picker used by the entry editors.
/// Tapping the selected chip clears the selection back to "untagged".
struct EntrySceneChipsRow: View {
    @Binding var selection: EntryScenePreset?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EntryScenePreset.allCases, id: \.self) { preset in
                    SceneChipButton(
                        text: EntrySceneDisplay.label(for: preset),
                        isSelected: selection == preset,
                        action: { selection = selection == preset ? nil : preset }
                    )
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

/// Capsule chip that renders an already-resolved display string.
///
/// Scene labels resolve upstream (preset slug -> localized label, free-form
/// scene text -> verbatim user content), so this button deliberately takes
/// display text instead of a localization key — user content must never be
/// routed through a String Catalog lookup.
struct SceneChipButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(
                    isSelected
                        ? LangoTraceDesign.ColorToken.whiteInk
                        : LangoTraceDesign.ColorToken.ink
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? LangoTraceDesign.ColorToken.accent
                        : LangoTraceDesign.ColorToken.surfaceBase
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(text))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
