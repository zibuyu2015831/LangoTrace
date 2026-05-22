import Combine
import Foundation
import LangoTraceCore
import LangoTraceData

@MainActor
final class LearningContentStore: ObservableObject {
    private let repository: any LearningContentRepository
    private let spaceID: String
    private let generationActions: LearningMaterialGenerationActions
    private var generatedRenderingsByEntryID: [String: LearningRendering] = [:]

    @Published private(set) var entries: [LearningEntry] = []
    @Published private(set) var selectedEntry: LearningEntry?
    @Published private(set) var memoryItems: [MemoryItem] = []
    @Published private(set) var settingsCapabilities: [SettingsCapability] = []
    @Published private(set) var generationStates: [String: LearningMaterialGenerationState] = [:]

    init(
        repository: any LearningContentRepository,
        spaceID: String,
        generationActions: LearningMaterialGenerationActions = .disabled
    ) {
        self.repository = repository
        self.spaceID = spaceID
        self.generationActions = generationActions
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

    @discardableResult
    func createMockPhotoWritingEntry() -> LearningEntry {
        let entry = repository.createMockPhotoWritingEntry(spaceID: spaceID)
        reload()
        return entry
    }

    func rendering(for entry: LearningEntry) -> LearningRendering? {
        rendering(for: entry.id)
    }

    func rendering(for entryID: String) -> LearningRendering? {
        generatedRenderingsByEntryID[entryID] ?? repository.rendering(for: entryID)
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

    func generationState(for entry: LearningEntry) -> LearningMaterialGenerationState {
        generationState(for: entry.id)
    }

    func generationState(for entryID: String) -> LearningMaterialGenerationState {
        if let state = generationStates[entryID] {
            return state
        }
        if let rendering = rendering(for: entryID) {
            return .generated(materialID: rendering.id)
        }
        return .idle
    }

    func generateLearningMaterial(
        for entry: LearningEntry,
        languageSpace: LanguageSpacePreview
    ) async {
        guard entry.spaceID == spaceID else {
            return
        }
        guard generationState(for: entry).canStartGeneration else {
            generationStates[entry.id] = .blocked(.operationInProgress)
            return
        }
        let sourceText = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else {
            generationStates[entry.id] = .blocked(.contentEmpty)
            return
        }
        let lengthBucket = LearningMaterialLengthEstimator.bucket(for: sourceText)
        guard lengthBucket != .tooLong else {
            generationStates[entry.id] = .blocked(.contentTooLong)
            return
        }

        let operationID = generationActions.operationIDGenerator()
        generationStates[entry.id] = .generating(operationID: operationID)
        let input = LearningMaterialGenerationInput(
            entryID: entry.id,
            spaceID: spaceID,
            sourceText: sourceText,
            entrySource: entry.source,
            nativeLanguageCode: languageSpace.nativeLanguage,
            targetLanguageCode: languageSpace.targetLanguageCode,
            proficiencyLevelCode: languageSpace.level.rawValue.lowercased(),
            promptMode: .automaticLearningMaterial
        )

        let result = await generationActions.generateMaterial(input, operationID, lengthBucket)
        switch result {
        case let .generated(material):
            generatedRenderingsByEntryID[entry.id] = Self.rendering(from: material)
            generationStates[entry.id] = .generated(materialID: material.id)
            reload()
        case let .failed(category):
            generationStates[entry.id] = .failed(
                LearningMaterialGenerationFailureDisplay(category: category, operationID: operationID)
            )
        }
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

    private static func rendering(from material: LearningMaterial) -> LearningRendering {
        LearningRendering(
            id: material.id,
            entryID: material.entryID,
            targetText: material.learningText,
            promptLabel: material.metadata.promptID,
            providerLabel: material.metadata.modelName,
            isMock: false,
            sentences: material.analysis.sentences.map { sentence in
                RenderingSentence(
                    id: sentence.id,
                    translation: sentence.nativeSentence,
                    targetText: sentence.targetSentence,
                    note: sentence.grammarNotes.joined(separator: "\n")
                )
            }
        )
    }
}
