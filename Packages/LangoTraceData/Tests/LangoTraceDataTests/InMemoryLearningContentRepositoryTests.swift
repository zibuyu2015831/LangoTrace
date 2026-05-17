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

@Test("Default settings capabilities are read-only and do not imply external services")
func defaultSettingsCapabilitiesAreReadOnly() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")

    let capabilities = repository.settingsCapabilities(for: "en")

    #expect(capabilities.map(\.kind) == [
        .languageSpace,
        .interfaceLanguage,
        .aiProvider,
        .sync,
        .localData,
        .privacy,
        .export,
    ])
    #expect(capabilities.first { $0.kind == .aiProvider }?.status == .mockOnly)
    #expect(capabilities.first { $0.kind == .sync }?.status == .unavailable)
    #expect(capabilities.filter { !$0.isReadOnly }.isEmpty)
}

@Test("Default settings capabilities expose complete readable detail pages")
func defaultSettingsCapabilitiesExposeCompleteDetailPages() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")

    let capabilities = repository.settingsCapabilities(for: "en")

    #expect(Set(capabilities.map(\.id)).count == SettingsCapability.Kind.allCases.count)
    #expect(capabilities.count == SettingsCapability.Kind.allCases.count)
    #expect(capabilities.filter(\.summary.isEmpty).isEmpty)
    #expect(capabilities.filter(\.detail.isEmpty).isEmpty)
    #expect(capabilities.filter(\.nextRequirement.isEmpty).isEmpty)
    #expect(capabilities.first { $0.kind == .privacy }?.status == .ready)
    #expect(capabilities.first { $0.kind == .export }?.status == .unavailable)
}

@Test("Mock practice session progresses through local-only steps")
func mockPracticeSessionProgressesThroughLocalOnlySteps() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let entry = repository.entries(for: "en")[0]

    let session = repository.practiceSession(for: entry.id)

    #expect(session?.entryID == entry.id)
    #expect(session?.providerLabel == "Local Mock")
    #expect(session?.steps == [.prepare, .shadow, .compare, .completed])
    #expect(session?.nextStep(after: .prepare) == .shadow)
    #expect(session?.nextStep(after: .completed) == .completed)
    #expect(session?.isExternalRequestRequired == false)
    #expect(session?.isLocalOnly == true)
}

@Test("Practice session is unavailable for entries without rendering")
func practiceSessionIsUnavailableWithoutRendering() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let entryWithoutRendering = repository.entries(for: "en")[1]

    let session = repository.practiceSession(for: entryWithoutRendering.id)

    #expect(session == nil)
    #expect(repository.practiceItems(for: entryWithoutRendering.id).isEmpty)
}

@Test("Created entries receive mock rendering and local-only practice session")
func createdEntriesReceiveLocalOnlyPracticeSession() {
    let repository = InMemoryLearningContentRepository(seedEntries: [])

    let entry = repository.createEntry(
        spaceID: "en",
        title: "晚饭散步",
        body: "晚饭后我绕着小区走了一圈。",
        source: .typedText
    )
    let rendering = repository.rendering(for: entry.id)
    let session = repository.practiceSession(for: entry.id)

    #expect(rendering?.isMock == true)
    #expect(session?.targetText == rendering?.targetText)
    #expect(session?.providerLabel == "Local Mock")
    #expect(session?.isLocalOnly == true)
}
