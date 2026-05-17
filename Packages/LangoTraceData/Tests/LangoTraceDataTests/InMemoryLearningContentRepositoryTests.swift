@testable import LangoTraceData
import Testing

@Test("Seeded repository exposes entries for the active language space")
func seededRepositoryExposesEntriesForActiveSpace() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")

    #expect(repository.entries(for: "en").count == 3)
    #expect(repository.selectedEntry(for: "en")?.title == "雨天咖啡馆")
    #expect(repository.rendering(for: "rain-cafe-en")?.sentences.count == 2)
    #expect(repository.memoryItems(for: "en").contains { $0.text == "in no hurry" })
}

@Test("Creating an entry stores it in the current space and creates mock rendering")
func creatingEntryStoresItAndCreatesMockRendering() {
    let repository = InMemoryLearningContentRepository(seedEntries: [])

    let entry = repository.createEntry(
        spaceID: "en",
        title: "晚饭散步",
        body: "晚饭后我绕着小区走了一圈。",
        source: .typedText
    )

    #expect(repository.entries(for: "en").map(\.id) == [entry.id])
    #expect(repository.selectedEntry(for: "en")?.id == entry.id)
    #expect(repository.rendering(for: entry.id)?.entryID == entry.id)
    #expect(repository.rendering(for: entry.id)?.isMock == true)
    #expect(repository.practiceItems(for: entry.id).count == 1)
}

@Test("Selecting a missing entry keeps the current selection unchanged")
func selectingMissingEntryKeepsCurrentSelectionUnchanged() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let originalSelection = repository.selectedEntry(for: "en")

    repository.selectEntry(id: "missing", spaceID: "en")

    #expect(repository.selectedEntry(for: "en") == originalSelection)
}
