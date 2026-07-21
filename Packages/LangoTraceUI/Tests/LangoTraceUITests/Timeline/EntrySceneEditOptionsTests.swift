import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Test("Scene edit options are a static closed set: no-scene first, then presets in enum order")
func sceneEditOptionsAreClosedSet() {
    let options = EntrySceneEditOptions.options()

    #expect(options.first?.slug == nil)
    #expect(options.dropFirst().map(\.slug) == EntryScenePreset.allCases.map(\.rawValue))
    // No option ever carries free-form user text.
    #expect(options.allSatisfy { option in
        option.slug == nil || EntryScenePreset(rawValue: option.slug ?? "") != nil
    })
    #expect(options.allSatisfy { !$0.label.isEmpty })
}

@Test("Scene edit current value shows three states: preset label, verbatim free text, explicit none")
func sceneEditCurrentValueLabelThreeStates() {
    let presetLabel = EntrySceneEditOptions.currentValueLabel(forStoredScene: "work")
    #expect(presetLabel == EntrySceneDisplay.label(for: .work))

    // Free-form scene text (importable via E10) is user content, shown verbatim.
    #expect(EntrySceneEditOptions.currentValueLabel(forStoredScene: "今天") == "今天")

    // Editing context: an empty scene shows the explicit "no scene" label and
    // must NOT fall back to the timeline's default-scene display name.
    let noneLabel = EntrySceneEditOptions.currentValueLabel(forStoredScene: "")
    #expect(!noneLabel.isEmpty)
    #expect(noneLabel != EntrySceneDisplay.label(forStoredScene: ""))
}
