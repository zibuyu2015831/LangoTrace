import Foundation
import LangoTraceCore
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

@Test("Creating an entry stores it without generated learning material")
func creatingEntryStoresItWithoutGeneratedLearningMaterial() throws {
    let repository = InMemoryLearningContentRepository(seedEntries: [])

    let entry = try repository.createEntry(
        spaceID: "en",
        title: "晚饭散步",
        body: "晚饭后我绕着小区走了一圈。",
        source: .typedText
    )

    #expect(repository.entries(for: "en").map(\.id) == [entry.id])
    #expect(repository.selectedEntry(for: "en")?.id == entry.id)
    #expect(repository.rendering(for: entry.id) == nil)
    #expect(repository.practiceItems(for: entry.id).isEmpty)
    #expect(repository.practiceSession(for: entry.id) == nil)
    #expect(repository.memoryItems(for: "en").filter { $0.entryID == entry.id }.isEmpty)
}

@Test("Updating an in-memory entry body keeps selection and trims persisted text")
func updatingInMemoryEntryBodyKeepsSelection() throws {
    let repository = InMemoryLearningContentRepository(seedEntries: [])
    let entry = try repository.createEntry(
        spaceID: "en",
        title: "晚饭散步",
        body: "晚饭后我绕着小区走了一圈。",
        source: .typedText
    )

    let updated = try repository.updateEntryBody(
        entryID: entry.id,
        spaceID: "en",
        body: "  晚饭后我走了更远的一圈。  "
    )

    #expect(updated.body == "晚饭后我走了更远的一圈。")
    #expect(repository.selectedEntry(for: "en")?.id == entry.id)
    #expect(repository.selectedEntry(for: "en")?.body == "晚饭后我走了更远的一圈。")
    #expect(repository.entries(for: "en").first?.body == "晚饭后我走了更远的一圈。")
}

@Test("Updating an in-memory entry body rejects empty or foreign entries")
func updatingInMemoryEntryBodyRejectsInvalidInputs() throws {
    let repository = InMemoryLearningContentRepository(seedEntries: [])
    let entry = try repository.createEntry(spaceID: "en", title: "记录", body: "原始内容", source: .typedText)

    #expect(throws: LearningContentRepositoryError.emptyEntryBody) {
        _ = try repository.updateEntryBody(entryID: entry.id, spaceID: "en", body: " \n ")
    }
    #expect(throws: LearningContentRepositoryError.entryNotFound) {
        _ = try repository.updateEntryBody(entryID: entry.id, spaceID: "ja", body: "新内容")
    }
    #expect(repository.selectedEntry(for: "en")?.body == "原始内容")
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
        .appearance,
        .aiProvider,
        .sync,
        .localData,
        .privacy,
        .importExport,
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
    #expect(capabilities.first { $0.kind == .importExport }?.status == .unavailable)
}

@Test("Data capability and status models do not expose Chinese UI chrome")
func dataCapabilityAndStatusModelsDoNotExposeChineseUIChrome() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let capabilityText = repository.settingsCapabilities(for: "en").flatMap {
        [$0.summary, $0.detail, $0.nextRequirement, $0.kind.title, $0.status.title]
    }
    let sourceTitles = [EntrySource.typedText, .photoWriting, .targetLanguageWriting].map { source in
        LearningEntry(
            id: "entry-\(source.rawValue)",
            spaceID: "en",
            title: "Fixture",
            body: "Fixture",
            source: source,
            scene: "fixture",
            createdAt: Date(timeIntervalSince1970: 0)
        ).sourceTitle
    }
    let practiceStepTitles = PracticeSessionStep.allCases.map(\.title)

    for text in capabilityText + sourceTitles + practiceStepTitles {
        #expect(!containsChineseCharacters(text))
    }
}

private func containsChineseCharacters(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        (0x4E00 ... 0x9FFF).contains(Int(scalar.value))
    }
}

@Test("Practice session progresses through local-only steps")
func practiceSessionProgressesThroughLocalOnlySteps() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let entry = repository.entries(for: "en")[0]

    let session = repository.practiceSession(for: entry.id)

    #expect(session?.entryID == entry.id)
    #expect(session?.providerLabel == "LangoTrace Draft")
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

@Test("Created entries receive local preview only after explicit generation")
func createdEntriesReceiveLocalPreviewOnlyAfterExplicitGeneration() throws {
    let repository = InMemoryLearningContentRepository(seedEntries: [])

    let entry = try repository.createEntry(
        spaceID: "en",
        title: "晚饭散步",
        body: "晚饭后我绕着小区走了一圈。",
        source: .typedText
    )
    #expect(repository.rendering(for: entry.id) == nil)

    let generated = repository.generateLocalPreview(for: entry.id, spaceID: "en")
    let rendering = repository.rendering(for: entry.id)
    let session = repository.practiceSession(for: entry.id)

    #expect(generated?.entryID == entry.id)
    #expect(rendering?.isMock == true)
    #expect(session?.targetText == rendering?.targetText)
    #expect(session?.providerLabel == "LangoTrace Draft")
    #expect(session?.isLocalOnly == true)
    #expect(repository.practiceItems(for: entry.id).count == 1)
    #expect(repository.memoryItems(for: "en").contains { $0.entryID == entry.id })
}
