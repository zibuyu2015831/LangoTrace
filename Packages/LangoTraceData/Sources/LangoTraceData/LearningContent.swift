import Foundation
import LangoTraceCore

public protocol LearningContentRepository: AnyObject {
    func ensureSeeded(spaceID: String)
    func entries(for spaceID: String) -> [LearningEntry]
    func selectedEntry(for spaceID: String) -> LearningEntry?
    func selectEntry(id: String, spaceID: String)
    @discardableResult
    func createEntry(spaceID: String, title: String, body: String, source: EntrySource) -> LearningEntry
    @discardableResult
    func createMockPhotoWritingEntry(spaceID: String) -> LearningEntry
    @discardableResult
    func generateLocalPreview(for entryID: String, spaceID: String) -> LearningRendering?
    func rendering(for entryID: String) -> LearningRendering?
    func practiceItems(for entryID: String) -> [PracticeItem]
    func memoryItems(for spaceID: String) -> [MemoryItem]
    func settingsCapabilities(for spaceID: String) -> [SettingsCapability]
    func practiceSession(for entryID: String) -> PracticeSessionState?
}

public final class InMemoryLearningContentRepository: LearningContentRepository {
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
        return entry
    }

    @discardableResult
    public func createMockPhotoWritingEntry(spaceID: String) -> LearningEntry {
        let entryID = "photo-writing-\(nextEntryNumber)-\(spaceID)"
        nextEntryNumber += 1

        let entry = MockPhotoWritingContent.entry(
            id: entryID,
            spaceID: spaceID,
            sequenceNumber: nextEntryNumber
        )
        let rendering = MockPhotoWritingContent.rendering(for: entry)

        entriesBySpace[spaceID, default: []].insert(entry, at: 0)
        selectedEntryIDs[spaceID] = entry.id
        renderingsByEntryID[entry.id] = rendering
        practiceItemsByEntryID[entry.id] = MockPhotoWritingContent.practiceItems(for: entry)
        memoryItemsBySpace[spaceID, default: []].insert(MockPhotoWritingContent.memoryItem(for: entry), at: 0)

        return entry
    }

    @discardableResult
    public func generateLocalPreview(for entryID: String, spaceID: String) -> LearningRendering? {
        guard let entry = entries(for: spaceID).first(where: { $0.id == entryID }) else {
            return nil
        }

        if let existingRendering = renderingsByEntryID[entry.id] {
            return existingRendering
        }

        let rendering = Self.makeMockRendering(for: entry)
        renderingsByEntryID[entry.id] = rendering
        practiceItemsByEntryID[entry.id] = [
            PracticeItem(
                id: "\(entry.id)-practice-shadowing",
                entryID: entry.id,
                title: "跟读",
                kind: .shadowing,
                summary: "选择 1 句开始跟读"
            ),
        ]
        memoryItemsBySpace[spaceID, default: []].insert(
            MemoryItem(
                id: "\(entry.id)-memory",
                spaceID: spaceID,
                entryID: entry.id,
                text: "everyday expression",
                note: "从生活记录中提取的常用表达"
            ),
            at: 0
        )

        return rendering
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
            SettingsCapability(
                kind: .appearance,
                status: .ready,
                summary: "settings.appearance.summary",
                detail: "settings.appearance.detail",
                nextRequirement: "settings.appearance.nextRequirement"
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
                kind: .importExport,
                status: .unavailable,
                summary: "settings.importExport.summary",
                detail: "settings.importExport.detail",
                nextRequirement: "settings.importExport.nextRequirement"
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
            providerLabel: "LangoTrace Draft",
            isMock: true,
            sentences: [
                RenderingSentence(
                    id: "\(entry.id)-sentence-1",
                    translation: entry.body.isEmpty ? "这是一条新的生活记录。" : entry.body,
                    targetText: targetText,
                    note: "适合改写成自然目标语言表达。"
                ),
            ]
        )
    }
}

private enum MockPhotoWritingContent {
    static func entry(id: String, spaceID: String, sequenceNumber: Int) -> LearningEntry {
        LearningEntry(
            id: id,
            spaceID: spaceID,
            title: "窗边早餐",
            body: "早上在窗边吃早餐，阳光照在桌子上。我突然觉得今天可以慢一点开始。",
            source: .photoWriting,
            scene: "今天",
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_800_100_000 + sequenceNumber)),
            practiceSummary: "跟读 2 句"
        )
    }

    static func rendering(for entry: LearningEntry) -> LearningRendering {
        LearningRendering(
            id: "\(entry.id)-rendering",
            entryID: entry.id,
            targetText: """
            I had breakfast by the window this morning, with sunlight falling across the table. \
            It made me feel like I could start the day a little more slowly.
            """,
            promptLabel: "照片写作预览",
            providerLabel: "LangoTrace Local Preview",
            isMock: true,
            sentences: sentences(for: entry)
        )
    }

    static func practiceItems(for entry: LearningEntry) -> [PracticeItem] {
        [
            PracticeItem(
                id: "\(entry.id)-practice-listening",
                entryID: entry.id,
                title: "听",
                kind: .listening,
                summary: "照片写作 · 2 句"
            ),
            PracticeItem(
                id: "\(entry.id)-practice-shadowing",
                entryID: entry.id,
                title: "跟读",
                kind: .shadowing,
                summary: "选一句开始跟读"
            ),
        ]
    }

    static func memoryItem(for entry: LearningEntry) -> MemoryItem {
        MemoryItem(
            id: "\(entry.id)-memory",
            spaceID: entry.spaceID,
            entryID: entry.id,
            text: "start the day slowly",
            note: "来自“窗边早餐”，表达放慢一天开始的节奏。"
        )
    }

    private static func sentences(for entry: LearningEntry) -> [RenderingSentence] {
        [
            RenderingSentence(
                id: "\(entry.id)-sentence-1",
                translation: "早上在窗边吃早餐，阳光照在桌子上。",
                targetText: "I had breakfast by the window this morning, with sunlight falling across the table.",
                note: "with sunlight falling across the table 比直译更自然。"
            ),
            RenderingSentence(
                id: "\(entry.id)-sentence-2",
                translation: "我突然觉得今天可以慢一点开始。",
                targetText: "It made me feel like I could start the day a little more slowly.",
                note: "start the day a little more slowly 适合表达放慢节奏。"
            ),
        ]
    }
}
