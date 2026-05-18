import Foundation
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Learning content store")
@MainActor
struct LearningContentStoreTests {
    @Test("Store centralizes seed, selection, creation, and derived content reads")
    func storeCentralizesRepositoryReadsAndMutations() {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let store = LearningContentStore(repository: repository, spaceID: "en")

        store.ensureSeeded()
        let originalEntries = store.entries

        #expect(originalEntries.count == 3)
        #expect(store.selectedEntry?.id == originalEntries.first?.id)

        let created = store.createEntry(
            title: "Evening walk",
            body: "I walked after dinner.",
            source: .typedText
        )

        #expect(store.entries.first?.id == created.id)
        #expect(store.selectedEntry?.id == created.id)
        #expect(store.rendering(for: created)?.entryID == created.id)
        #expect(store.practiceItems(for: created).count == 1)
        #expect(store.practiceSession(for: created)?.entryID == created.id)
        #expect(store.memoryItems.contains { $0.entryID == created.id })
        #expect(store.settingsCapabilities.map(\.kind).contains(.interfaceLanguage))
    }

    @Test("Store selection ignores entries outside the active space")
    func storeSelectionIgnoresEntriesOutsideActiveSpace() {
        let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
        let store = LearningContentStore(repository: repository, spaceID: "en")
        store.ensureSeeded()
        let originalSelection = store.selectedEntry?.id

        let foreignEntry = LearningEntry(
            id: "foreign-entry",
            spaceID: "ja",
            title: "Foreign",
            body: "Foreign",
            source: .typedText,
            scene: "Fixture",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        store.selectEntry(foreignEntry)

        #expect(store.selectedEntry?.id == originalSelection)
    }
}
