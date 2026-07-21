import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Test("Preset scene slugs display through their localized labels")
func presetSlugDisplaysLocalizedLabel() {
    for preset in EntryScenePreset.allCases {
        let label = EntrySceneDisplay.label(forStoredScene: preset.rawValue)
        #expect(label == EntrySceneDisplay.label(for: preset))
        #expect(!label.isEmpty)
    }
}

@Test("Free-form scene text is user content and stays verbatim")
func freeFormSceneStaysVerbatim() {
    #expect(EntrySceneDisplay.label(forStoredScene: "今天") == "今天")
    #expect(EntrySceneDisplay.label(forStoredScene: "Client onsite") == "Client onsite")
}

@Test("Empty scene falls back to the default label")
func emptySceneFallsBackToDefaultLabel() {
    let fallback = EntrySceneDisplay.label(forStoredScene: "")

    #expect(!fallback.isEmpty)

    let entry = LearningEntry(
        id: "e1",
        spaceID: "en",
        title: "记录",
        body: "内容",
        source: .typedText,
        scene: "",
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    #expect(entry.displayScene == fallback)
}
