import Foundation

public final class InMemoryLearningContentRepository {
    private var entriesBySpace: [String: [LearningEntry]]
    private var selectedEntryIDs: [String: String]
    private var renderingsByEntryID: [String: LearningRendering]
    private var practiceItemsByEntryID: [String: [PracticeItem]]
    private var memoryItemsBySpace: [String: [MemoryItem]]
    private var nextEntryNumber: Int

    public init(
        seedEntries: [LearningEntry],
        renderings: [LearningRendering] = [],
        practiceItems: [PracticeItem] = [],
        memoryItems: [MemoryItem] = []
    ) {
        entriesBySpace = Dictionary(grouping: seedEntries, by: \.spaceID)
        selectedEntryIDs = entriesBySpace.compactMapValues { $0.first?.id }
        renderingsByEntryID = Dictionary(uniqueKeysWithValues: renderings.map { ($0.entryID, $0) })
        practiceItemsByEntryID = Dictionary(grouping: practiceItems, by: \.entryID)
        memoryItemsBySpace = Dictionary(grouping: memoryItems, by: \.spaceID)
        nextEntryNumber = seedEntries.count + 1
    }

    public static func seeded(spaceID: String) -> InMemoryLearningContentRepository {
        let entries = SeedLearningContent.entries(spaceID: spaceID)
        return InMemoryLearningContentRepository(
            seedEntries: entries,
            renderings: SeedLearningContent.renderings,
            practiceItems: SeedLearningContent.practiceItems,
            memoryItems: SeedLearningContent.memoryItems(spaceID: spaceID)
        )
    }

    public func ensureSeeded(spaceID: String) {
        guard entriesBySpace[spaceID, default: []].isEmpty else {
            return
        }

        let seeded = Self.seeded(spaceID: spaceID)
        entriesBySpace[spaceID] = seeded.entries(for: spaceID)
        selectedEntryIDs[spaceID] = seeded.selectedEntry(for: spaceID)?.id
        seeded.renderingsByEntryID.forEach { renderingsByEntryID[$0.key] = $0.value }
        seeded.practiceItemsByEntryID.forEach { practiceItemsByEntryID[$0.key] = $0.value }
        memoryItemsBySpace[spaceID] = seeded.memoryItems(for: spaceID)
    }

    public func entries(for spaceID: String) -> [LearningEntry] {
        entriesBySpace[spaceID, default: []]
    }

    public func selectedEntry(for spaceID: String) -> LearningEntry? {
        guard let selectedID = selectedEntryIDs[spaceID] else {
            return entries(for: spaceID).first
        }

        return entries(for: spaceID).first { $0.id == selectedID }
    }

    public func selectEntry(id: String, spaceID: String) {
        guard entries(for: spaceID).contains(where: { $0.id == id }) else {
            return
        }

        selectedEntryIDs[spaceID] = id
    }

    @discardableResult
    public func createEntry(
        spaceID: String,
        title: String,
        body: String,
        source: EntrySource
    ) -> LearningEntry {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryID = "entry-\(nextEntryNumber)-\(spaceID)"
        nextEntryNumber += 1

        let entry = LearningEntry(
            id: entryID,
            spaceID: spaceID,
            title: trimmedTitle.isEmpty ? "新的生活记录" : trimmedTitle,
            body: trimmedBody,
            source: source,
            scene: "今天",
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + nextEntryNumber)),
            practiceSummary: "练习 1 组"
        )

        entriesBySpace[spaceID, default: []].insert(entry, at: 0)
        selectedEntryIDs[spaceID] = entry.id
        renderingsByEntryID[entry.id] = Self.makeMockRendering(for: entry)
        practiceItemsByEntryID[entry.id] = [
            PracticeItem(
                id: "\(entry.id)-practice-shadowing",
                entryID: entry.id,
                title: "跟读",
                kind: .shadowing,
                summary: "从 mock rendering 选择 1 句开始"
            ),
        ]
        memoryItemsBySpace[spaceID, default: []].insert(
            MemoryItem(
                id: "\(entry.id)-memory",
                spaceID: spaceID,
                entryID: entry.id,
                text: "mock expression",
                note: "本地 mock 提取，等待真实 AI Provider"
            ),
            at: 0
        )

        return entry
    }

    public func rendering(for entryID: String) -> LearningRendering? {
        renderingsByEntryID[entryID]
    }

    public func practiceItems(for entryID: String) -> [PracticeItem] {
        practiceItemsByEntryID[entryID, default: []]
    }

    public func memoryItems(for spaceID: String) -> [MemoryItem] {
        memoryItemsBySpace[spaceID, default: []]
    }

    public func settingsCapabilities(for _: String) -> [SettingsCapability] {
        [
            SettingsCapability(
                kind: .languageSpace,
                status: .mockOnly,
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
        ] + Self.serviceSettingsCapabilities
    }

    private static var serviceSettingsCapabilities: [SettingsCapability] {
        [
            SettingsCapability(
                kind: .aiProvider,
                status: .mockOnly,
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
                status: .mockOnly,
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
                kind: .export,
                status: .unavailable,
                summary: "settings.export.summary",
                detail: "settings.export.detail",
                nextRequirement: "settings.export.nextRequirement"
            ),
        ]
    }

    public func practiceSession(for entryID: String) -> PracticeSessionState? {
        guard let rendering = rendering(for: entryID) else {
            return nil
        }

        return PracticeSessionState(
            entryID: entryID,
            providerLabel: rendering.providerLabel,
            isExternalRequestRequired: false,
            steps: PracticeSessionStep.allCases,
            targetText: rendering.targetText
        )
    }

    private static func makeMockRendering(for entry: LearningEntry) -> LearningRendering {
        let targetText = "I wrote down a small moment from my day, and I can turn it into language practice."
        return LearningRendering(
            id: "\(entry.id)-rendering",
            entryID: entry.id,
            targetText: targetText,
            promptLabel: "自然表达",
            providerLabel: "Local Mock",
            isMock: true,
            sentences: [
                RenderingSentence(
                    id: "\(entry.id)-sentence-1",
                    translation: entry.body.isEmpty ? "这是一条新的生活记录。" : entry.body,
                    targetText: targetText,
                    note: "本地 mock 生成，用于验证页面闭环。"
                ),
            ]
        )
    }
}
