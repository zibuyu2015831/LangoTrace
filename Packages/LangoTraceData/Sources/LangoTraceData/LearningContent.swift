import Foundation

public enum EntrySource: String, Equatable, Sendable {
    case typedText
    case photoWriting
    case targetLanguageWriting
}

public struct LearningEntry: Equatable, Identifiable, Sendable {
    public let id: String
    public let spaceID: String
    public var title: String
    public var body: String
    public var source: EntrySource
    public var scene: String
    public var createdAt: Date
    public var practiceSummary: String

    public init(
        id: String,
        spaceID: String,
        title: String,
        body: String,
        source: EntrySource,
        scene: String,
        createdAt: Date,
        practiceSummary: String = "待练习"
    ) {
        self.id = id
        self.spaceID = spaceID
        self.title = title
        self.body = body
        self.source = source
        self.scene = scene
        self.createdAt = createdAt
        self.practiceSummary = practiceSummary
    }

    public var sourceTitle: String {
        switch source {
        case .typedText:
            "文字记录"
        case .photoWriting:
            "照片写作"
        case .targetLanguageWriting:
            "目标语言写作"
        }
    }
}

public struct RenderingSentence: Equatable, Identifiable, Sendable {
    public let id: String
    public let translation: String
    public let targetText: String
    public let note: String

    public init(id: String, translation: String, targetText: String, note: String) {
        self.id = id
        self.translation = translation
        self.targetText = targetText
        self.note = note
    }
}

public struct LearningRendering: Equatable, Identifiable, Sendable {
    public let id: String
    public let entryID: String
    public let targetText: String
    public let promptLabel: String
    public let providerLabel: String
    public let isMock: Bool
    public let sentences: [RenderingSentence]

    public init(
        id: String,
        entryID: String,
        targetText: String,
        promptLabel: String,
        providerLabel: String,
        isMock: Bool,
        sentences: [RenderingSentence]
    ) {
        self.id = id
        self.entryID = entryID
        self.targetText = targetText
        self.promptLabel = promptLabel
        self.providerLabel = providerLabel
        self.isMock = isMock
        self.sentences = sentences
    }
}

public struct PracticeItem: Equatable, Identifiable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case listening
        case shadowing
        case dictation
        case backTranslation
    }

    public let id: String
    public let entryID: String
    public let title: String
    public let kind: Kind
    public let summary: String

    public init(id: String, entryID: String, title: String, kind: Kind, summary: String) {
        self.id = id
        self.entryID = entryID
        self.title = title
        self.kind = kind
        self.summary = summary
    }
}

public struct MemoryItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let spaceID: String
    public let entryID: String
    public let text: String
    public let note: String

    public init(id: String, spaceID: String, entryID: String, text: String, note: String) {
        self.id = id
        self.spaceID = spaceID
        self.entryID = entryID
        self.text = text
        self.note = note
    }
}

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

private enum SeedLearningContent {
    static func entries(spaceID: String) -> [LearningEntry] {
        [
            LearningEntry(
                id: "rain-cafe-en",
                spaceID: spaceID,
                title: "雨天咖啡馆",
                body: "今天在咖啡馆坐了很久。外面一直下小雨，我没有急着回家。",
                source: .photoWriting,
                scene: "今天",
                createdAt: Date(timeIntervalSince1970: 1_799_900_000),
                practiceSummary: "跟读 2 句"
            ),
            LearningEntry(
                id: "thank-friend-en",
                spaceID: spaceID,
                title: "写给朋友的感谢",
                body: "我想认真感谢朋友这周帮我处理了很多麻烦事。",
                source: .typedText,
                scene: "昨天",
                createdAt: Date(timeIntervalSince1970: 1_799_800_000),
                practiceSummary: "待练习"
            ),
            LearningEntry(
                id: "meeting-review-en",
                spaceID: spaceID,
                title: "会议复盘",
                body: "今天的会议让我意识到，提前准备例子比临场解释更有效。",
                source: .typedText,
                scene: "本周",
                createdAt: Date(timeIntervalSince1970: 1_799_700_000),
                practiceSummary: "已入记忆"
            ),
        ]
    }

    static let renderings: [LearningRendering] = [
        LearningRendering(
            id: "rain-cafe-en-rendering",
            entryID: "rain-cafe-en",
            targetText: """
            I spent a long time at the cafe today. It kept drizzling outside, \
            and I was in no hurry to go home.
            """,
            promptLabel: "自然表达",
            providerLabel: "Local Mock",
            isMock: true,
            sentences: [
                RenderingSentence(
                    id: "rain-cafe-en-sentence-1",
                    translation: "今天在咖啡馆坐了很久。",
                    targetText: "I spent a long time at the cafe today.",
                    note: "spent a long time 比 stayed for a long time 更自然地表达“度过一段时间”。"
                ),
                RenderingSentence(
                    id: "rain-cafe-en-sentence-2",
                    translation: "外面一直下小雨，我没有急着回家。",
                    targetText: "It kept drizzling outside, and I was in no hurry to go home.",
                    note: "in no hurry 可以表达“不着急做某事”。"
                ),
            ]
        ),
    ]

    static let practiceItems: [PracticeItem] = [
        PracticeItem(
            id: "rain-cafe-en-shadowing",
            entryID: "rain-cafe-en",
            title: "跟读",
            kind: .shadowing,
            summary: "2 句待练 · 0.85x"
        ),
        PracticeItem(
            id: "rain-cafe-en-dictation",
            entryID: "rain-cafe-en",
            title: "听写",
            kind: .dictation,
            summary: "雨天咖啡馆 · 3 分钟"
        ),
    ]

    static func memoryItems(spaceID: String) -> [MemoryItem] {
        [
            MemoryItem(
                id: "rain-cafe-memory-in-no-hurry",
                spaceID: spaceID,
                entryID: "rain-cafe-en",
                text: "in no hurry",
                note: "来自“雨天咖啡馆”，表达“不急着做某事”。"
            ),
            MemoryItem(
                id: "rain-cafe-memory-drizzling",
                spaceID: spaceID,
                entryID: "rain-cafe-en",
                text: "drizzling",
                note: "来自照片写作，用于描述小雨。"
            ),
        ]
    }
}
