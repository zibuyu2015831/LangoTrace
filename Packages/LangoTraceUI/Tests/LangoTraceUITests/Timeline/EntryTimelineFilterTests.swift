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
        #expect(EntryTimelineFilter.all.includes(entry: entry, hasMaterialWithoutRecording: false))
        #expect(EntryTimelineFilter.all.includes(entry: entry, hasMaterialWithoutRecording: true))

        let photoEntry = makeEntry(source: .photoWriting)
        #expect(EntryTimelineFilter.all.includes(entry: photoEntry, hasMaterialWithoutRecording: false))
    }

    // MARK: - photo

    @Test("photo only includes photoWriting entries")
    func photoOnlyIncludesPhotoWriting() {
        let typed = makeEntry(source: .typedText)
        let photo = makeEntry(source: .photoWriting)

        #expect(!EntryTimelineFilter.photo.includes(entry: typed, hasMaterialWithoutRecording: false))
        #expect(EntryTimelineFilter.photo.includes(entry: photo, hasMaterialWithoutRecording: false))
    }

    @Test("photo does not depend on hasMaterialWithoutRecording")
    func photoIgnoresPracticeState() {
        let photo = makeEntry(source: .photoWriting)
        #expect(EntryTimelineFilter.photo.includes(entry: photo, hasMaterialWithoutRecording: true))
        #expect(EntryTimelineFilter.photo.includes(entry: photo, hasMaterialWithoutRecording: false))
    }

    // MARK: - needsPractice

    @Test("needsPractice requires hasMaterialWithoutRecording to be true")
    func needsPracticeRequiresHasMaterialWithoutRecordingTrue() {
        let entry = makeEntry()
        #expect(EntryTimelineFilter.needsPractice.includes(entry: entry, hasMaterialWithoutRecording: true))
        #expect(!EntryTimelineFilter.needsPractice.includes(entry: entry, hasMaterialWithoutRecording: false))
    }

    @Test("needsPractice does not depend on entry source")
    func needsPracticeIsSourceAgnostic() {
        let typed = makeEntry(source: .typedText)
        let photo = makeEntry(source: .photoWriting)
        #expect(EntryTimelineFilter.needsPractice.includes(entry: typed, hasMaterialWithoutRecording: true))
        #expect(EntryTimelineFilter.needsPractice.includes(entry: photo, hasMaterialWithoutRecording: true))
    }

    // MARK: - settled

    @Test("settled always returns false until E7 fills real judgment")
    func settledAlwaysReturnsFalse() {
        let entry = makeEntry()
        #expect(!EntryTimelineFilter.settled.includes(entry: entry, hasMaterialWithoutRecording: false))
        #expect(!EntryTimelineFilter.settled.includes(entry: entry, hasMaterialWithoutRecording: true))
    }

    // MARK: - settled chip guard

    @Test("allCases filtered by not-settled produces three visible filters")
    func settledExcludedFromVisibleCases() {
        let visible = EntryTimelineFilter.allCases.filter { $0 != .settled }
        #expect(visible == [.all, .photo, .needsPractice])
    }
}
