import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("EntryTimelineFilter")
struct EntryTimelineFilterTests {
    // MARK: - Fixtures

    private func makeEntry(source: EntrySource = .typedText) -> LearningEntry {
        LearningEntry(
            id: UUID().uuidString,
            spaceID: "test",
            title: "Test",
            body: "body",
            source: source,
            scene: "今天",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    // MARK: - all

    @Test("all includes every entry regardless of source or practice state")
    func allIncludesEverything() {
        let entry = makeEntry(source: .typedText)
        #expect(EntryTimelineFilter.all.includes(entry: entry, hasMaterialWithoutRecording: false, hasPhotoAttachment: false))
        #expect(EntryTimelineFilter.all.includes(entry: entry, hasMaterialWithoutRecording: true, hasPhotoAttachment: false))

        let photoEntry = makeEntry(source: .photoWriting)
        #expect(EntryTimelineFilter.all.includes(entry: photoEntry, hasMaterialWithoutRecording: false, hasPhotoAttachment: false))
    }

    // MARK: - photo

    @Test("photo only includes photoWriting entries when no attachment")
    func photoOnlyIncludesPhotoWriting() {
        let typed = makeEntry(source: .typedText)
        let photo = makeEntry(source: .photoWriting)

        #expect(!EntryTimelineFilter.photo.includes(entry: typed, hasMaterialWithoutRecording: false, hasPhotoAttachment: false))
        #expect(EntryTimelineFilter.photo.includes(entry: photo, hasMaterialWithoutRecording: false, hasPhotoAttachment: false))
    }

    @Test("photo does not depend on hasMaterialWithoutRecording")
    func photoIgnoresPracticeState() {
        let photo = makeEntry(source: .photoWriting)
        #expect(EntryTimelineFilter.photo.includes(entry: photo, hasMaterialWithoutRecording: true, hasPhotoAttachment: false))
        #expect(EntryTimelineFilter.photo.includes(entry: photo, hasMaterialWithoutRecording: false, hasPhotoAttachment: false))
    }

    @Test("photo filter matches non-photoWriting entry that has a photo attachment")
    func photoFilterMatchesEntryWithAttachment() {
        let typed = makeEntry(source: .typedText)
        #expect(EntryTimelineFilter.photo.includes(entry: typed, hasMaterialWithoutRecording: false, hasPhotoAttachment: true))
        #expect(!EntryTimelineFilter.photo.includes(entry: typed, hasMaterialWithoutRecording: false, hasPhotoAttachment: false))
    }

    // MARK: - needsPractice

    @Test("needsPractice requires hasMaterialWithoutRecording to be true")
    func needsPracticeRequiresHasMaterialWithoutRecordingTrue() {
        let entry = makeEntry()
        #expect(EntryTimelineFilter.needsPractice.includes(entry: entry, hasMaterialWithoutRecording: true, hasPhotoAttachment: false))
        #expect(!EntryTimelineFilter.needsPractice.includes(entry: entry, hasMaterialWithoutRecording: false, hasPhotoAttachment: false))
    }

    @Test("needsPractice does not depend on entry source")
    func needsPracticeIsSourceAgnostic() {
        let typed = makeEntry(source: .typedText)
        let photo = makeEntry(source: .photoWriting)
        #expect(EntryTimelineFilter.needsPractice.includes(entry: typed, hasMaterialWithoutRecording: true, hasPhotoAttachment: false))
        #expect(EntryTimelineFilter.needsPractice.includes(entry: photo, hasMaterialWithoutRecording: true, hasPhotoAttachment: false))
    }

    // MARK: - settled

    @Test("settled always returns false until E7 fills real judgment")
    func settledAlwaysReturnsFalse() {
        let entry = makeEntry()
        #expect(!EntryTimelineFilter.settled.includes(entry: entry, hasMaterialWithoutRecording: false, hasPhotoAttachment: false))
        #expect(!EntryTimelineFilter.settled.includes(entry: entry, hasMaterialWithoutRecording: true, hasPhotoAttachment: false))
    }

    // MARK: - settled chip guard

    @Test("allCases filtered by not-settled produces three visible filters")
    func settledExcludedFromVisibleCases() {
        let visible = EntryTimelineFilter.allCases.filter { $0 != .settled }
        #expect(visible == [.all, .photo, .needsPractice])
    }
}
