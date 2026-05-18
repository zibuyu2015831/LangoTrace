import Combine
import Foundation
import LangoTraceData

@MainActor
final class LearningContentStore: ObservableObject {
    private let repository: any LearningContentRepository
    private let spaceID: String

    @Published private(set) var entries: [LearningEntry] = []
    @Published private(set) var selectedEntry: LearningEntry?
    @Published private(set) var memoryItems: [MemoryItem] = []
    @Published private(set) var settingsCapabilities: [SettingsCapability] = []

    init(repository: any LearningContentRepository, spaceID: String) {
        self.repository = repository
        self.spaceID = spaceID
        reload()
    }

    func ensureSeeded() {
        repository.ensureSeeded(spaceID: spaceID)
        reload()
    }

    func selectEntry(_ entry: LearningEntry) {
        guard entry.spaceID == spaceID else {
            return
        }

        repository.selectEntry(id: entry.id, spaceID: spaceID)
        reload()
    }

    @discardableResult
    func createEntry(title: String, body: String, source: EntrySource) -> LearningEntry {
        let entry = repository.createEntry(
            spaceID: spaceID,
            title: title,
            body: body,
            source: source
        )
        reload()
        return entry
    }

    func rendering(for entry: LearningEntry) -> LearningRendering? {
        repository.rendering(for: entry.id)
    }

    func rendering(for entryID: String) -> LearningRendering? {
        repository.rendering(for: entryID)
    }

    @discardableResult
    func generateLocalPreview(for entry: LearningEntry) -> LearningRendering? {
        guard entry.spaceID == spaceID else {
            return nil
        }

        let rendering = repository.generateLocalPreview(for: entry.id, spaceID: spaceID)
        reload()
        return rendering
    }

    func practiceItems(for entry: LearningEntry) -> [PracticeItem] {
        repository.practiceItems(for: entry.id)
    }

    func practiceItems(for entryID: String) -> [PracticeItem] {
        repository.practiceItems(for: entryID)
    }

    func practiceSession(for entry: LearningEntry) -> PracticeSessionState? {
        repository.practiceSession(for: entry.id)
    }

    func practiceSession(for entryID: String) -> PracticeSessionState? {
        repository.practiceSession(for: entryID)
    }

    func memoryItems(for entry: LearningEntry) -> [MemoryItem] {
        memoryItems.filter { $0.entryID == entry.id }
    }

    func entry(id: String) -> LearningEntry? {
        entries.first { $0.id == id }
    }

    func capability(kind: SettingsCapability.Kind) -> SettingsCapability? {
        settingsCapabilities.first { $0.kind == kind }
    }

    private func reload() {
        entries = repository.entries(for: spaceID)
        selectedEntry = repository.selectedEntry(for: spaceID)
        memoryItems = repository.memoryItems(for: spaceID)
        settingsCapabilities = repository.settingsCapabilities(for: spaceID)
    }
}
