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

    public func settingsCapabilities(for spaceID: String) -> [SettingsCapability] {
        [
            SettingsCapability(
                kind: .languageSpace,
                status: .mockOnly,
                summary: "当前空间 \(spaceID) 使用内存 preview",
                detail: "当前语言空间只存在于 App 会话状态中，用于验证首次启动和页面闭环。",
                nextRequirement: "接入真实语言空间持久化和启动恢复。"
            ),
            SettingsCapability(
                kind: .interfaceLanguage,
                status: .mockOnly,
                summary: "当前默认跟随系统，未支持的系统语言回退英文",
                detail: "界面语言只影响 App chrome，不改变用户母语、不改变目标语言，也不重写已生成内容。",
                nextRequirement: "接入 String Catalog、系统 per-app language 关系说明和界面语言偏好持久化。"
            ),
        ] + Self.serviceSettingsCapabilities
    }

    private static var serviceSettingsCapabilities: [SettingsCapability] {
        [
            SettingsCapability(
                kind: .aiProvider,
                status: .mockOnly,
                summary: "未配置真实 Provider，所有生成均为 Local Mock",
                detail: "请求预览只说明将来会发送哪些内容，当前不会读取 Keychain，也不会发起网络请求。",
                nextRequirement: "设计 Provider 配置、Keychain API Key 和请求日志。"
            ),
            SettingsCapability(
                kind: .sync,
                status: .unavailable,
                summary: "同步引擎尚未接入",
                detail: "记录、照片、向量索引和 API Key 当前都不会同步。",
                nextRequirement: "设计 Sync Engine、Adapter、冲突处理和同步范围。"
            ),
            SettingsCapability(
                kind: .localData,
                status: .mockOnly,
                summary: "当前使用内存 repository",
                detail: "重启后 mock 内容会恢复为示例数据；当前没有 SQLite schema、迁移或附件存储。",
                nextRequirement: "接入 SQLite / GRDB Repository、迁移和导出边界。"
            ),
            SettingsCapability(
                kind: .privacy,
                status: .ready,
                summary: "本地优先边界已在 UI 中表达",
                detail: "敏感内容只有在用户明确触发对应能力时才应进入请求预览和 Provider 调用。",
                nextRequirement: "在真实 AI、语音、照片和同步接入时保留确认路径。"
            ),
            SettingsCapability(
                kind: .export,
                status: .unavailable,
                summary: "导出尚未实现",
                detail: "当前没有真实数据库和附件目录，因此不能生成完整导出包。",
                nextRequirement: "在数据层稳定后设计 Markdown、JSON 和附件导出。"
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
