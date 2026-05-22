import Foundation
import LangoTraceCore

public final class GRDBLearningContentRepositoryBridge: LearningContentRepository {
    private let repository: GRDBLearningContentRepository
    private var selectedEntryIDs: [String: String] = [:]

    public init(repository: GRDBLearningContentRepository) {
        self.repository = repository
    }

    public func ensureSeeded(spaceID _: String) {}

    public func entries(for spaceID: String) -> [LearningEntry] {
        (try? repository.entries(for: spaceID)) ?? []
    }

    public func selectedEntry(for spaceID: String) -> LearningEntry? {
        let entries = entries(for: spaceID)
        if let selectedID = selectedEntryIDs[spaceID],
           let selected = entries.first(where: { $0.id == selectedID })
        {
            return selected
        }
        return entries.first
    }

    public func selectEntry(id: String, spaceID: String) {
        guard entries(for: spaceID).contains(where: { $0.id == id }) else {
            return
        }
        selectedEntryIDs[spaceID] = id
    }

    @discardableResult
    public func createEntry(spaceID: String, title: String, body: String, source: EntrySource) -> LearningEntry {
        let draft = NewLearningEntryDraft(title: title, body: body, source: source, scene: "生活记录")
        do {
            let entry = try repository.createEntry(draft, in: spaceID)
            selectedEntryIDs[spaceID] = entry.id
            return entry
        } catch {
            return LearningEntry(
                id: "unsaved-\(UUID().uuidString)",
                spaceID: spaceID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                scene: "生活记录",
                createdAt: Date()
            )
        }
    }

    @discardableResult
    public func createMockPhotoWritingEntry(spaceID: String) -> LearningEntry {
        createEntry(
            spaceID: spaceID,
            title: "窗边早餐",
            body: "早上在窗边吃早餐，阳光照在桌子上。我突然觉得今天可以慢一点开始。",
            source: .photoWriting
        )
    }

    @discardableResult
    public func generateLocalPreview(for entryID: String, spaceID _: String) -> LearningRendering? {
        rendering(for: entryID)
    }

    public func rendering(for entryID: String) -> LearningRendering? {
        guard let material = try? repository.currentMaterial(for: entryID) else {
            return nil
        }
        return Self.rendering(from: material)
    }

    public func practiceItems(for entryID: String) -> [PracticeItem] {
        (try? repository.practiceItems(for: entryID)) ?? []
    }

    public func memoryItems(for spaceID: String) -> [MemoryItem] {
        (try? repository.memoryItems(for: spaceID)) ?? []
    }

    public func settingsCapabilities(for _: String) -> [SettingsCapability] {
        Self.settingsCapabilities
    }

    public func practiceSession(for entryID: String) -> PracticeSessionState? {
        guard let rendering = rendering(for: entryID) else {
            return nil
        }
        return PracticeSessionState(
            entryID: entryID,
            providerLabel: rendering.providerLabel,
            isExternalRequestRequired: true,
            steps: PracticeSessionStep.allCases,
            targetText: rendering.targetText
        )
    }
}

private extension GRDBLearningContentRepositoryBridge {
    static func rendering(from material: LearningMaterial) -> LearningRendering {
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

    static var settingsCapabilities: [SettingsCapability] {
        [
            SettingsCapability(
                kind: .languageSpace,
                status: .ready,
                summary: "settings.languageSpace.summary",
                detail: "settings.languageSpace.detail",
                nextRequirement: "settings.languageSpace.nextRequirement"
            ),
            SettingsCapability(
                kind: .interfaceLanguage,
                status: .mockOnly,
                summary: "settings.interfaceLanguage.summary",
                detail: "settings.interfaceLanguage.detail",
                nextRequirement: "settings.interfaceLanguage.nextRequirement"
            ),
            SettingsCapability(
                kind: .appearance,
                status: .ready,
                summary: "settings.appearance.summary",
                detail: "settings.appearance.detail",
                nextRequirement: "settings.appearance.nextRequirement"
            ),
            SettingsCapability(
                kind: .aiProvider,
                status: .ready,
                summary: "settings.aiProvider.summary",
                detail: "settings.aiProvider.detail",
                nextRequirement: "settings.aiProvider.nextRequirement"
            ),
            SettingsCapability(
                kind: .sync,
                status: .unavailable,
                summary: "settings.sync.summary",
                detail: "settings.sync.detail",
                nextRequirement: "settings.sync.nextRequirement"
            ),
            SettingsCapability(
                kind: .localData,
                status: .ready,
                summary: "settings.localData.summary",
                detail: "settings.localData.detail",
                nextRequirement: "settings.localData.nextRequirement"
            ),
            SettingsCapability(
                kind: .privacy,
                status: .ready,
                summary: "settings.privacy.summary",
                detail: "settings.privacy.detail",
                nextRequirement: "settings.privacy.nextRequirement"
            ),
            SettingsCapability(
                kind: .importExport,
                status: .unavailable,
                summary: "settings.importExport.summary",
                detail: "settings.importExport.detail",
                nextRequirement: "settings.importExport.nextRequirement"
            ),
        ]
    }
}
