@testable import LangoTraceCore
import Testing

/// Raw values are the storage contract: they are persisted into
/// `entries.scene`, so changing any slug silently orphans historical rows.
@Test("Entry scene preset slugs are a stable storage contract")
func entryScenePresetSlugsAreStable() {
    #expect(EntryScenePreset.daily.rawValue == "daily")
    #expect(EntryScenePreset.work.rawValue == "work")
    #expect(EntryScenePreset.travel.rawValue == "travel")
    #expect(EntryScenePreset.mood.rawValue == "mood")
    #expect(EntryScenePreset.meeting.rawValue == "meeting")
    #expect(EntryScenePreset.email.rawValue == "email")
}

/// Declaration order only drives presentation ordering (scene facet lists);
/// it is asserted separately from the slugs so an intentional reorder does
/// not read as a storage-contract break.
@Test("Entry scene preset order drives facet presentation")
func entryScenePresetOrderIsPinned() {
    #expect(EntryScenePreset.allCases == [.daily, .work, .travel, .mood, .meeting, .email])
}
