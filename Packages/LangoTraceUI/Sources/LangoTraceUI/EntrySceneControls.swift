import LangoTraceCore
import LangoTraceData
import SwiftUI

/// Pure presentation logic for the entry-detail scene edit menu.
enum EntrySceneEditOptions {
    /// One selectable option: `nil` slug clears the tag, otherwise a preset slug.
    struct Option: Equatable {
        let slug: String?
        let label: String
    }

    /// Static closed set: "no scene" first, then the presets in enum order.
    /// Free-form scene text (E10 imports) is never an option — it shows as the
    /// current value only and is overwritten by whichever option is picked.
    static func options() -> [Option] {
        [Option(slug: nil, label: String(localized: "entryScene.none", bundle: .module))]
            + EntryScenePreset.allCases.map { preset in
                Option(slug: preset.rawValue, label: EntrySceneDisplay.label(for: preset))
            }
    }

    /// Current-value display for the *edit* context. Unlike the timeline's
    /// `displayScene`, an empty scene shows the explicit "no scene" label
    /// instead of falling back to the default scene name — otherwise the row
    /// would appear to carry a scene called "Journal" next to a "No scene"
    /// option.
    static func currentValueLabel(forStoredScene scene: String) -> String {
        if scene.isEmpty {
            return String(localized: "entryScene.none", bundle: .module)
        }
        if let preset = EntryScenePreset(rawValue: scene) {
            return EntrySceneDisplay.label(for: preset)
        }
        // Free-form scene text is user content and stays verbatim.
        return scene
    }
}

/// Entry-detail row for editing the scene tag of an existing entry.
///
/// The row takes the whole entry (not the raw scene string) so call sites in
/// the detail view never spell `entry.scene` — the timeline source-boundary
/// guard forbids raw scene interpolation outside this controls file. The
/// current value is always derived from the entry prop (no `@State` copy);
/// only the transient error key is local state.
struct EntrySceneEditRow: View {
    let entry: LearningEntry
    let onUpdateScene: (String) throws -> Void

    @State private var saveErrorKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText("entryEditor.scene.section")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)

            Menu {
                ForEach(EntrySceneEditOptions.options(), id: \.slug) { option in
                    Button {
                        do {
                            try onUpdateScene(option.slug ?? "")
                            saveErrorKey = nil
                        } catch {
                            // Keep the row visible and surface the failure;
                            // re-picking an option retries.
                            saveErrorKey = "entryEditor.saveFailed"
                        }
                    } label: {
                        if isCurrent(option) {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .font(.footnote.weight(.medium))
                    Text(EntrySceneEditOptions.currentValueLabel(forStoredScene: entry.scene))
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
                .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(LangoTraceDesign.ColorToken.surfaceBase)
                .clipShape(Capsule())
            }
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .contentShape(Rectangle())
            .accessibilityLabel(localizedText("entryEditor.scene.section"))
            .accessibilityValue(Text(EntrySceneEditOptions.currentValueLabel(forStoredScene: entry.scene)))

            if let saveErrorKey {
                localizedText(saveErrorKey)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.stateError)
            }
        }
    }

    private func isCurrent(_ option: EntrySceneEditOptions.Option) -> Bool {
        (option.slug ?? "") == entry.scene
    }
}

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
