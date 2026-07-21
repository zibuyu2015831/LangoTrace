import Foundation
import LangoTraceCore
import LangoTraceLearnerModel
@testable import LangoTraceUI
import Testing

/// Covers the LM02 Slice 1 learner-profile store: snapshot load → presentation,
/// the explicit-remember add flow (blank rejected), single delete, and the
/// system reset — all reloading from the actions seam.
@MainActor
@Suite("Learner profile store")
struct LearnerProfileStoreTests {
    /// In-memory backing for the actions seam.
    private final class Backing: @unchecked Sendable {
        var facts: [MemoryFact] = []
        var coverageCount = 0
        func snapshot() -> LearnerProfileSnapshot {
            let entries = (0 ..< coverageCount).map { index in
                AbilityCoverageEntry(text: "w\(index)", kind: .wordPhrase, occurrenceCount: 1, evidence: [])
            }
            return LearnerProfileSnapshot(
                abilityCoverage: AbilityCoverage(
                    languageCode: "ja",
                    entries: entries,
                    generatedAt: Date(timeIntervalSince1970: 0)
                ),
                memoryFacts: facts,
                reviewStatistics: .zero,
                trend: LearnerProfileTrend(depositedThisWeek: 0, coverageEntryCount: entries.count)
            )
        }
    }

    private func makeStore(_ backing: Backing) -> LearnerProfileStore {
        let actions = LearnerProfileActions(
            loadSnapshot: { _, _, _ in backing.snapshot() },
            addFact: { kind, text in
                backing.facts.append(MemoryFact(id: "f\(backing.facts.count)", kind: kind, text: text))
            },
            deleteFact: { id in backing.facts.removeAll { $0.id == id } },
            resetAllFacts: { backing.facts.removeAll() }
        )
        return LearnerProfileStore(spaceID: "s", languageCode: "ja", level: .b1, actions: actions)
    }

    @Test("load maps snapshot into a ready presentation")
    func loadMapsSnapshot() async {
        let backing = Backing()
        backing.coverageCount = 2
        let store = makeStore(backing)
        await store.load()
        #expect(store.phase == .ready)
        #expect(store.presentation?.levelDisplay.level == .b1)
        #expect(store.presentation?.coverageEntryCount == 2)
    }

    @Test("add fact rejects blank draft, accepts trimmed text, and reloads")
    func addFactFlow() async {
        let backing = Backing()
        let store = makeStore(backing)
        await store.load()

        store.draftText = "   "
        #expect(!store.canSubmitDraft)
        await store.addDraftFact()
        #expect(backing.facts.isEmpty)

        store.draftKind = .goal
        store.draftText = "  考过 N2  "
        #expect(store.canSubmitDraft)
        await store.addDraftFact()
        #expect(backing.facts.map(\.text) == ["考过 N2"]) // trimmed
        #expect(store.draftText.isEmpty) // draft cleared
        #expect(store.presentation?.memoryFacts.count == 1)
    }

    @Test("delete removes a single fact and reloads")
    func deleteFact() async {
        let backing = Backing()
        backing.facts = [MemoryFact(id: "f1", kind: .lifeFact, text: "a")]
        let store = makeStore(backing)
        await store.load()
        await store.deleteFact(id: "f1")
        #expect(store.presentation?.memoryFacts.isEmpty == true)
    }

    @Test("system reset clears all facts and reloads to an empty presentation")
    func systemReset() async {
        let backing = Backing()
        backing.facts = [
            MemoryFact(id: "f1", kind: .lifeFact, text: "a"),
            MemoryFact(id: "f2", kind: .goal, text: "b"),
        ]
        let store = makeStore(backing)
        await store.load()
        await store.resetAllFacts()
        #expect(backing.facts.isEmpty)
        #expect(store.presentation?.memoryFacts.isEmpty == true)
        #expect(store.presentation?.isEmpty == true)
    }

    @Test("nil snapshot drives the unavailable phase")
    func unavailableWhenNoDatabase() async {
        let actions = LearnerProfileActions(
            loadSnapshot: { _, _, _ in nil },
            addFact: { _, _ in },
            deleteFact: { _ in },
            resetAllFacts: {}
        )
        let store = LearnerProfileStore(spaceID: "s", languageCode: "ja", level: .a1, actions: actions)
        await store.load()
        #expect(store.phase == .unavailable)
        #expect(store.presentation == nil)
    }
}
