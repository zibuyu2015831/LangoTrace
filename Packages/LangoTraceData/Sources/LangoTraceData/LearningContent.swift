import Foundation
import LangoTraceCore

/// A repository for learning content entries and their associated materials.
///
/// Conforming types are expected to be used from the main actor context.
/// The primary consumer (`LearningContentStore`) is `@MainActor`, and all
/// protocol methods are synchronous. Full `@MainActor` protocol isolation
/// is deferred to E0b (UI architecture debt) to avoid cascading async
/// changes across all implementations and test sites.
public protocol LearningContentRepository: AnyObject {
    func ensureSeeded(spaceID: String)
    func entries(for spaceID: String) -> [LearningEntry]
    func selectedEntry(for spaceID: String) -> LearningEntry?
    func selectEntry(id: String, spaceID: String)
    @discardableResult
    func createEntry(spaceID: String, title: String, body: String, source: EntrySource) throws -> LearningEntry
    @discardableResult
    func updateEntryBody(entryID: String, spaceID: String, body: String) throws -> LearningEntry
    @discardableResult
    func createMockPhotoWritingEntry(spaceID: String) throws -> LearningEntry
    @discardableResult
    func generateLocalPreview(for entryID: String, spaceID: String) -> LearningRendering?
    func rendering(for entryID: String) -> LearningRendering?
    func practiceItems(for entryID: String) -> [PracticeItem]
    func memoryItems(for spaceID: String) -> [MemoryItem]
    func settingsCapabilities(for spaceID: String) -> [SettingsCapability]
    func practiceSession(for entryID: String) -> PracticeSessionState?
    func saveRendering(_ rendering: LearningRendering)
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
    ) throws -> LearningEntry {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryID = "entry-\(nextEntryNumber)-\(spaceID)"
        nextEntryNumber += 1

        let entry = LearningEntry(
            id: entryID,
            spaceID: spaceID,
            title: trimmedTitle,
            body: trimmedBody,
            source: source,
            scene: "今天",
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + nextEntryNumber)),
            practiceStatus: .practiced(sessionCount: 1)
        )

        entriesBySpace[spaceID, default: []].insert(entry, at: 0)
        selectedEntryIDs[spaceID] = entry.id
        return entry
    }

    @discardableResult
    public func updateEntryBody(entryID: String, spaceID: String, body: String) throws -> LearningEntry {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw LearningContentRepositoryError.emptyEntryBody }
        guard var entries = entriesBySpace[spaceID],
              let index = entries.firstIndex(where: { $0.id == entryID })
        else {
            throw LearningContentRepositoryError.entryNotFound
        }

        entries[index].body = trimmedBody
        entriesBySpace[spaceID] = entries
        return entries[index]
    }

    @discardableResult
    public func createMockPhotoWritingEntry(spaceID: String) throws -> LearningEntry {
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
                note: "Extracted from a life record entry."
            ),
            at: 0
        )

        return rendering
    }

    public func rendering(for entryID: String) -> LearningRendering? {
        renderingsByEntryID[entryID]
    }

    public func saveRendering(_ rendering: LearningRendering) {
        renderingsByEntryID[rendering.entryID] = rendering
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
            sourceEntryBodyHash: LearningMaterialTextHash.sha256(for: entry.body),
            sentences: [
                RenderingSentence(
                    id: "\(entry.id)-sentence-1",
                    translation: entry.body.isEmpty ? "" : entry.body,
                    targetText: targetText,
                    note: "适合改写成自然目标语言表达。"
                ),
            ]
        )
    }
}

public final class UnavailableLearningContentRepository: LearningContentRepository {
    public init() {}

    public func ensureSeeded(spaceID _: String) {}

    public func entries(for _: String) -> [LearningEntry] {
        []
    }

    public func selectedEntry(for _: String) -> LearningEntry? {
        nil
    }

    public func selectEntry(id _: String, spaceID _: String) {}

    public func createEntry(spaceID _: String, title _: String, body _: String, source _: EntrySource) throws -> LearningEntry {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    public func updateEntryBody(entryID _: String, spaceID _: String, body _: String) throws -> LearningEntry {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    public func createMockPhotoWritingEntry(spaceID _: String) throws -> LearningEntry {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    public func generateLocalPreview(for _: String, spaceID _: String) -> LearningRendering? {
        nil
    }

    public func rendering(for _: String) -> LearningRendering? {
        nil
    }

    public func saveRendering(_ rendering: LearningRendering) {}

    public func practiceItems(for _: String) -> [PracticeItem] {
        []
    }

    public func memoryItems(for _: String) -> [MemoryItem] {
        []
    }

    public func settingsCapabilities(for _: String) -> [SettingsCapability] {
        []
    }

    public func practiceSession(for _: String) -> PracticeSessionState? {
        nil
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
            practiceStatus: .practiced(sessionCount: 2)
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
            sourceEntryBodyHash: LearningMaterialTextHash.sha256(for: entry.body),
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
