import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

private func entry(id: String, scene: String) -> LearningEntry {
    LearningEntry(
        id: id,
        spaceID: "en",
        title: "记录 \(id)",
        body: "内容 \(id)",
        source: .typedText,
        scene: scene,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        practiceStatus: .notStarted
    )
}

@Test("Available scenes list presets in enum order then free-form by code point")
func availableScenesOrdersPresetsThenFreeForm() {
    // Mixed data: presets out of order, free-form values (as the E10 import
    // path can introduce), and untagged entries.
    let entries = [
        entry(id: "1", scene: "work"),
        entry(id: "2", scene: "今天"),
        entry(id: "3", scene: "daily"),
        entry(id: "4", scene: ""),
        entry(id: "5", scene: "Zoo"),
        entry(id: "6", scene: "work"),
    ]

    #expect(EntrySceneFacet.availableScenes(in: entries) == ["daily", "work", "Zoo", "今天"])
}

@Test("Empty scenes never appear as a selectable facet value")
func availableScenesExcludesEmpty() {
    let entries = [entry(id: "1", scene: ""), entry(id: "2", scene: "")]

    #expect(EntrySceneFacet.availableScenes(in: entries).isEmpty)
}

@Test("Scene facet filters with AND semantics against the status filter")
func sceneFacetComposesWithStatusFilter() {
    let entries = [
        entry(id: "1", scene: "work"),
        entry(id: "2", scene: "travel"),
        entry(id: "3", scene: "work"),
    ]

    let bySc = EntrySceneFacet.entriesMatching(scene: "work", in: entries)
    #expect(bySc.map(\.id) == ["1", "3"])

    // nil means "all scenes" — the facet is a no-op.
    #expect(EntrySceneFacet.entriesMatching(scene: nil, in: entries).count == 3)

    // AND composition: apply the status filter on the scene-narrowed list.
    let both = bySc.filter { candidate in
        EntryTimelineFilter.all.includes(
            entry: candidate,
            hasMaterialWithoutRecording: false,
            hasPhotoAttachment: false
        )
    }
    #expect(both.map(\.id) == ["1", "3"])
}

@Test("Scene counts are computed over the full entry list")
func sceneCountsUseFullEntryList() {
    let entries = [
        entry(id: "1", scene: "work"),
        entry(id: "2", scene: "work"),
        entry(id: "3", scene: "今天"),
        entry(id: "4", scene: ""),
    ]

    let counts = EntrySceneFacet.counts(in: entries)
    #expect(counts["work"] == 2)
    #expect(counts["今天"] == 1)
    #expect(counts[""] == nil)
}

@Test("Stale scene selections fall back to nil instead of an empty timeline")
func staleSelectionNormalizesToNil() {
    let entries = [entry(id: "1", scene: "work")]

    #expect(EntrySceneFacet.normalizedSelection("work", in: entries) == "work")
    #expect(EntrySceneFacet.normalizedSelection("travel", in: entries) == nil)
    #expect(EntrySceneFacet.normalizedSelection(nil, in: entries) == nil)
}
