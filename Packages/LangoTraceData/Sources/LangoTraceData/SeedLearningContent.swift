import Foundation
import LangoTraceCore

enum SeedLearningContent {
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
            providerLabel: "LangoTrace Draft",
            isMock: true,
            sourceEntryBodyHash: LearningMaterialTextHash.sha256(for: "今天在咖啡馆坐了很久。外面一直下小雨，我没有急着回家。"),
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
