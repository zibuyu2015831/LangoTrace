import Foundation
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("EntryPracticeStatus model")
struct EntryPracticeStatusTests {
    @Test("LearningEntry defaults to notStarted practice status")
    func defaultPracticeStatusIsNotStarted() {
        let entry = LearningEntry(
            id: "e1",
            spaceID: "s1",
            title: "test",
            body: "body",
            source: .typedText,
            scene: "",
            createdAt: Date()
        )
        #expect(entry.practiceStatus == .notStarted)
    }

    @Test("practiced status carries session count")
    func practicedStatusCarriesCount() {
        let entry = LearningEntry(
            id: "e2",
            spaceID: "s1",
            title: "test",
            body: "body",
            source: .typedText,
            scene: "",
            createdAt: Date(),
            practiceStatus: .practiced(sessionCount: 3)
        )
        if case let .practiced(count) = entry.practiceStatus {
            #expect(count == 3)
        } else {
            Issue.record("expected .practiced(3), got \(entry.practiceStatus)")
        }
    }

    @Test("memorized is distinct from practiced")
    func memorizedIsDistinct() {
        let e1 = EntryPracticeStatus.memorized
        let e2 = EntryPracticeStatus.practiced(sessionCount: 10)
        #expect(e1 != e2)
    }
}
