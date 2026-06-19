# Practice Session Prompt Card Disclosure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 优化 iPhone 单句练习页顶部内容卡，让目标语言句子保持主视觉，中文释义低权重但可完整展开，语法讲解按需查看，并减少切换句子时的高度跳动。

**Architecture:** 将当前 `PracticeSessionViews.swift` 中的 `PracticeSnapshotPanel` 收敛为独立 `PracticePromptCard.swift`，并提供明确 presentation model。展示状态只属于当前单句页面本地 UI，不写入数据库、不影响 `PracticeSession`、TTS、录音或 media artifact；presentation model 负责清洗空白文本、判断长译文是否需要 disclosure、输出本地化 key 和可访问状态。三端继续共享 `PracticeSessionView`，route identity 变化时重置本地展开状态。

**Tech Stack:** SwiftUI、Swift Testing、LangoTraceUI package、现有 `PracticeSessionRouteSeed` / `PracticeSentenceSnapshot`。

---

状态：Verified
类型：feature
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户基于 iPhone 17 模拟器截图指出，单句练习页顶部文本展示区同时展示英文、中文和语法分析，用户不一定全部需要；内容长短不同时，切换句子会造成高度变化，观感不稳定。

2026-05-26：已完成并打开静态原型 `prototypes/practice-session-prompt-card/index.html`。用户确认采纳该设计，并要求立即创建方案文档。

已确认的设计：

- 目标语言句子常驻并保持最高视觉权重。
- 中文释义默认低权重展示。
- 中文释义较长时不能只省略，必须允许用户完整查阅。
- 短中文释义默认完整展示，不出现无效的展开 / 收起按钮。
- 语法讲解与中文释义分层，默认不展开，通过独立入口查看。
- 切换句子时默认收起译文和讲解，保持练习操作区位置更稳定。

## 2. 需求描述

当前 `PracticeSnapshotPanel` 直接纵向展示：

1. `translationSnapshot`
2. `targetTextSnapshot`
3. `noteSnapshot`

该结构更像“阅读分析卡”，不够贴合单句跟读页面。单句跟读的主任务是听示范、开始录音、回放录音和句间切换；中文释义和讲解应服务理解，不应持续挤压主流程。

## 3. 现状描述

当前实现位置：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
  - `PracticeSessionView`
  - `PracticeSnapshotPanel`
  - `PracticeSentenceNavigationBar`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

现有问题：

- `PracticeSnapshotPanel` 没有 presentation model，无法用单元测试表达信息层级和展开规则。
- `translationSnapshot` 与 `noteSnapshot` 都是可选文本，但 UI 没有区分“辅助释义”和“深入讲解”。
- `targetTextSnapshot`、`translationSnapshot`、`noteSnapshot` 全部参与卡片自然高度，切换句子时卡片高度容易明显变化。
- 当前页面已有 `PracticeControlBar` 和 `PracticeSentenceNavigationBar` 的简洁化规则，顶部内容卡仍需要同步收敛。
- iPhone、iPad 和 macOS 当前都复用 `PracticeSessionView`，三端 route host 已通过 `.id(seed.practiceRouteIdentity)` 重建练习页；本任务仍应在组件内部绑定 route identity 重置，避免后续父级 host 调整后泄漏旧展开状态。

## 4. 目标

- 将顶部内容区重命名或重构为练习语义更明确的 prompt card，例如 `PracticePromptCard`。
- 目标语言句子常驻，视觉权重最高。
- 中文释义默认低权重展示；短译文完整展示且不显示无效展开按钮。
- 中文释义存在长文本时默认最多显示 2 行，并显示 `展开译文` / `收起译文`，展开后用户可完整查看。
- 语法讲解默认收起，使用 `查看讲解` / `收起讲解` 独立入口。
- 切换句子时，译文和讲解展开状态回到收起状态。
- 展开 / 收起按钮提供明确 accessibility value / hint，VoiceOver 可以识别当前展开状态。
- 保持 `听`、`回放录音`、`开始录音` 和句间导航的现有行为，不引入新的音频或录音状态。
- 增加自动化测试覆盖 presentation 规则和句子切换重置规则。

## 5. 范围

涉及代码文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

涉及测试文件：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

涉及文档：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/platform-page-inventory.md`
- `prototypes/practice-session-prompt-card/README.md`
- `prototypes/practice-session-prompt-card/index.html`

参考代码路径：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/ThreePlatformPresentationCopyTests.swift`

## 6. 不做什么

- 不改 `PracticeSession`、`PracticeActions`、`PracticeSessionViewModel` 的录音状态机。
- 不改 TTS Provider、逐句播放、音频缓存、media artifact 或 GRDB schema。
- 不新增用户偏好设置，不持久化“默认展开讲解”。
- 不把中文释义放入单独页面；第一版只在当前练习页内完整展开。
- 不在完成前引入复杂动画；如果使用展开动效，必须尊重 Reduce Motion。

## 7. 证据与决策依据

- 原型证据：`prototypes/practice-session-prompt-card/index.html` 已验证默认态、展开译文、查看讲解和句子切换重置的交互方向。
- UI 规范依据：`docs/spec/003-ui-design-system.md` 已要求单句练习页把视觉权重留给句子内容和真实可执行动作，`PracticeControlBar` 只承载真实操作。
- Apple 交互依据：`docs/spec/010-apple-platform-interaction-and-accessibility.md` 要求 iPhone 触控目标不小于 44pt、Dynamic Type 和长文案不能导致主操作不可见或互相遮挡。
- 当前代码依据：`PracticeSnapshotPanel` 直接展示全部文本，没有展开状态和 presentation 层，无法稳定表达主次层级。
- 代码审查依据：`PracticeSessionView` 被 iPhone、iPad、macOS 三端 route host 复用，当前 host 使用 `.id(seed.practiceRouteIdentity)` 重建 route；组件内部仍应按 route identity 显式重置 disclosure state，避免未来 host 变化后出现状态串句。

## 7.1 架构审查修订记录

2026-05-26：严格方案审查后补强以下内容：

- 长译文 disclosure 不能等同于“有译文”。短译文应完整展示且不显示展开按钮；只有超过确定阈值或包含多行的译文才显示 `展开译文`。
- 自动化测试必须覆盖默认收起、展开后完整展示、短译文无 toggle、空白文本不渲染和讲解展开状态。
- 三端共享 `PracticeSessionView`，状态重置应绑定 `routeSeed.practiceRouteIdentity`，而不仅依赖用户点击上一句 / 下一句。
- 新增本地化 key 必须进入 `ThreePlatformPresentationCopyTests.practiceSessionInteractionKeysAreLocalized` 的 required list。
- 展开 / 收起控件必须满足 44pt 触控目标，并提供 accessibility value / hint。
- 默认高度稳定只针对 collapsed 基准态；用户展开长译文或讲解时允许卡片自然增高，不为了稳定高度牺牲完整阅读。

## 8. 实施方案

### Task 1: 增加 prompt card presentation 测试

**Files:**

- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`

- [x] **Step 1: 写失败测试，覆盖长译文默认收起与展开态**

在 `PracticeRouteSeedTests` 中新增测试：

```swift
@Test("Practice prompt card presentation collapses long translation and expands to full text")
func practicePromptCardPresentationCollapsesAndExpandsLongTranslation() {
    let snapshot = promptSnapshot(
        translation: "鸟儿轻声鸣叫，标志着另一个宁静的一天结束，也提醒用户这句话描述的是安静收束的生活场景。",
        note: "chirp 是动词，表示鸟儿发出短促轻快的叫声。"
    )

    let collapsed = PracticePromptCardPresentation(
        snapshot: snapshot,
        isTranslationExpanded: false,
        isExplanationExpanded: false
    )
    let expanded = PracticePromptCardPresentation(
        snapshot: snapshot,
        isTranslationExpanded: true,
        isExplanationExpanded: true
    )

    #expect(collapsed.targetText == "Birds chirp softly, signaling the end of another peaceful day.")
    #expect(collapsed.translationLineLimit == PracticePromptCardPresentation.collapsedTranslationLineLimit)
    #expect(collapsed.translationNeedsDisclosure)
    #expect(collapsed.shouldShowTranslationToggle)
    #expect(collapsed.translationToggleTitleKey == "practice.prompt.translation.expand")
    #expect(collapsed.translationAccessibilityValueKey == "accessibility.hidden")
    #expect(collapsed.explanationToggleTitleKey == "practice.prompt.explanation.expand")
    #expect(collapsed.explanationAccessibilityValueKey == "accessibility.hidden")

    #expect(expanded.translationLineLimit == nil)
    #expect(expanded.translationToggleTitleKey == "practice.prompt.translation.collapse")
    #expect(expanded.translationAccessibilityValueKey == "accessibility.visible")
    #expect(expanded.explanationToggleTitleKey == "practice.prompt.explanation.collapse")
    #expect(expanded.explanationAccessibilityValueKey == "accessibility.visible")
}

@Test("Practice prompt card presentation avoids empty controls for short or blank auxiliary text")
func practicePromptCardPresentationAvoidsEmptyControlsForShortOrBlankAuxiliaryText() {
    let short = PracticePromptCardPresentation(
        snapshot: promptSnapshot(translation: "鸟儿轻声鸣叫。", note: " "),
        isTranslationExpanded: false,
        isExplanationExpanded: false
    )
    let blank = PracticePromptCardPresentation(
        snapshot: promptSnapshot(translation: " \n ", note: "\t"),
        isTranslationExpanded: false,
        isExplanationExpanded: false
    )

    #expect(short.translationText == "鸟儿轻声鸣叫。")
    #expect(short.translationLineLimit == nil)
    #expect(!short.translationNeedsDisclosure)
    #expect(!short.shouldShowTranslationToggle)
    #expect(short.translationToggleTitleKey == nil)
    #expect(short.explanationText == nil)
    #expect(!short.shouldShowExplanationToggle)

    #expect(blank.translationText == nil)
    #expect(blank.explanationText == nil)
    #expect(!blank.shouldShowTranslationToggle)
    #expect(!blank.shouldShowExplanationToggle)
}
```

同时在测试文件底部新增 helper，避免测试样例散落重复：

```swift
private func promptSnapshot(translation: String?, note: String?) -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: "entry-1",
        learningMaterialID: "material-1",
        sentenceID: "sentence-1",
        sentenceIndex: 0,
        targetTextSnapshot: "Birds chirp softly, signaling the end of another peaceful day.",
        targetTextHash: String(repeating: "a", count: 64),
        targetLanguageCode: "en",
        translationSnapshot: translation,
        noteSnapshot: note,
        sourceEntryBodyHash: "source-hash",
        materialAnalysisSourceHash: nil,
        exerciseType: .shadowing,
        capturedAt: Date(timeIntervalSince1970: 1)
    )
}
```

- [x] **Step 2: 运行测试并确认失败**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter PracticeRouteSeedTests
```

Expected: FAIL，原因是 `PracticePromptCardPresentation`、`collapsedTranslationLineLimit`、`translationNeedsDisclosure` 和 accessibility state 尚未定义。

### Task 2: 实现 prompt card presentation model

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`

- [x] **Step 1: 新增 prompt card presentation 类型**

新增 `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift`，并定义与 `PracticeSentenceNavigationBarPresentation` 同一 package 可测试边界的 presentation：

```swift
struct PracticePromptCardPresentation: Equatable {
    static let collapsedTranslationLineLimit = 2
    static let translationDisclosureCharacterThreshold = 42

    var targetText: String
    var translationText: String?
    var explanationText: String?
    var translationLineLimit: Int?
    var translationToggleTitleKey: String?
    var explanationToggleTitleKey: String?
    var translationAccessibilityValueKey: String?
    var explanationAccessibilityValueKey: String?
    var translationNeedsDisclosure: Bool
    var shouldShowTranslationToggle: Bool
    var shouldShowExplanationToggle: Bool

    init(
        snapshot: PracticeSentenceSnapshot,
        isTranslationExpanded: Bool,
        isExplanationExpanded: Bool
    ) {
        targetText = snapshot.targetTextSnapshot
        translationText = Self.normalizedText(snapshot.translationSnapshot)
        explanationText = Self.normalizedText(snapshot.noteSnapshot)

        translationNeedsDisclosure = Self.needsTranslationDisclosure(translationText)
        shouldShowTranslationToggle = translationNeedsDisclosure
        translationLineLimit = translationNeedsDisclosure && !isTranslationExpanded
            ? Self.collapsedTranslationLineLimit
            : nil
        translationToggleTitleKey = shouldShowTranslationToggle
            ? (isTranslationExpanded ? "practice.prompt.translation.collapse" : "practice.prompt.translation.expand")
            : nil

        shouldShowExplanationToggle = explanationText != nil
        explanationToggleTitleKey = shouldShowExplanationToggle
            ? (isExplanationExpanded ? "practice.prompt.explanation.collapse" : "practice.prompt.explanation.expand")
            : nil
        translationAccessibilityValueKey = shouldShowTranslationToggle
            ? (isTranslationExpanded ? "accessibility.visible" : "accessibility.hidden")
            : nil
        explanationAccessibilityValueKey = shouldShowExplanationToggle
            ? (isExplanationExpanded ? "accessibility.visible" : "accessibility.hidden")
            : nil
    }

    private static func normalizedText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func needsTranslationDisclosure(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        return value.count > translationDisclosureCharacterThreshold || value.contains("\n")
    }
}
```

- [x] **Step 2: 运行聚焦测试并确认通过**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter PracticeRouteSeedTests
```

Expected: PASS。

### Task 3: 替换顶部内容卡 UI

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- Create: `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift`

- [x] **Step 1: 将 `PracticeSnapshotPanel` 改为带展开状态的 prompt card**

在 `PracticeSessionView` 增加本地状态：

```swift
@State private var isTranslationExpanded = false
@State private var isExplanationExpanded = false
```

新增本地 reset helper，并在 route identity 变化时重置 disclosure state：

```swift
private func resetPromptDisclosures() {
    isTranslationExpanded = false
    isExplanationExpanded = false
}
```

在 `body` 修饰链中追加：

```swift
.onChange(of: routeSeed.practiceRouteIdentity) { _, _ in
    resetPromptDisclosures()
}
```

把调用替换为：

```swift
PracticePromptCard(
    snapshot: routeSeed.snapshot,
    isTranslationExpanded: isTranslationExpanded,
    isExplanationExpanded: isExplanationExpanded,
    onToggleTranslation: {
        isTranslationExpanded.toggle()
    },
    onToggleExplanation: {
        isExplanationExpanded.toggle()
    }
)
```

在 `PracticePromptCard.swift` 中新增 `PracticePromptCard`：

```swift
struct PracticePromptCard: View {
    let snapshot: PracticeSentenceSnapshot
    let isTranslationExpanded: Bool
    let isExplanationExpanded: Bool
    let onToggleTranslation: () -> Void
    let onToggleExplanation: () -> Void

    private var presentation: PracticePromptCardPresentation {
        PracticePromptCardPresentation(
            snapshot: snapshot,
            isTranslationExpanded: isTranslationExpanded,
            isExplanationExpanded: isExplanationExpanded
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(presentation.targetText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let translationText = presentation.translationText {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(localizedText("practice.prompt.translation.title"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        Spacer()
                        if let titleKey = presentation.translationToggleTitleKey {
                            Button(localizedText(titleKey), action: onToggleTranslation)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                                .frame(minHeight: 44)
                                .accessibilityValue(localizedText(presentation.translationAccessibilityValueKey ?? "accessibility.hidden"))
                                .accessibilityHint(localizedText("practice.prompt.translation.toggle.hint"))
                        }
                    }
                    Text(translationText)
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .lineLimit(presentation.translationLineLimit)
                }
            }

            if presentation.shouldShowExplanationToggle,
               let titleKey = presentation.explanationToggleTitleKey {
                Button(localizedText(titleKey), action: onToggleExplanation)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                    .frame(minHeight: 44)
                    .accessibilityValue(localizedText(presentation.explanationAccessibilityValueKey ?? "accessibility.hidden"))
                    .accessibilityHint(localizedText("practice.prompt.explanation.toggle.hint"))
            }

            if isExplanationExpanded, let explanationText = presentation.explanationText {
                Text(explanationText)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: PracticePromptCardLayout.collapsedMinHeight, alignment: .topLeading)
        .langoPanel()
    }
}

private enum PracticePromptCardLayout {
    static let collapsedMinHeight: CGFloat = 220
}
```

`PracticePromptCardLayout.collapsedMinHeight` 只用于稳定默认 collapsed 基准高度；当用户展开长译文或讲解时，卡片允许自然增高，以保证完整阅读。

- [x] **Step 2: 移除旧 `PracticeSnapshotPanel`**

删除原 `private struct PracticeSnapshotPanel`，避免同一职责保留两套组件。

- [x] **Step 3: 运行聚焦 UI 测试**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests'
```

Expected: PASS。

### Task 4: 句子切换与 route identity 变化时重置展开状态

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

- [x] **Step 1: 增加源代码收敛测试**

在 `PhoneIOSConvergenceTests` 中新增：

```swift
@Test("Practice prompt disclosures reset when route identity changes")
func practicePromptDisclosuresResetWhenRouteIdentityChanges() throws {
    let source = try String(contentsOf: sourceFileURL(named: "PracticeSessionViews.swift"), encoding: .utf8)
    let promptCard = try String(contentsOf: sourceFileURL(named: "PracticePromptCard.swift"), encoding: .utf8)

    #expect(source.contains("@State private var isTranslationExpanded = false"))
    #expect(source.contains("@State private var isExplanationExpanded = false"))
    #expect(source.contains("private func resetPromptDisclosures()"))
    #expect(source.contains(".onChange(of: routeSeed.practiceRouteIdentity)"))
    #expect(source.contains("resetPromptDisclosures()"))
    #expect(source.contains("PracticePromptCard("))
    #expect(promptCard.contains("PracticePromptCardLayout.collapsedMinHeight"))
    #expect(promptCard.contains("practice.prompt.translation.toggle.hint"))
    #expect(promptCard.contains("practice.prompt.explanation.toggle.hint"))
    #expect(!source.contains("PracticeSnapshotPanel("))
}
```

- [x] **Step 2: 实现重置逻辑**

在 `navigateSentence(direction:)` 成功导航前重置本地展开状态。当前三端 host 仍通过 `.id(seed.practiceRouteIdentity)` 重建页面，但这里保留组件内部 reset，防止未来 host 不重建时串句：

```swift
resetPromptDisclosures()
onNavigateSentence(nextSeed)
```

- [x] **Step 3: 运行聚焦测试**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests'
```

Expected: PASS。

### Task 5: 补齐本地化文案

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

- [x] **Step 1: 添加新 key**

新增以下本地化 key，并至少补齐当前 String Catalog 已覆盖语言的值：

```text
practice.prompt.translation.title
practice.prompt.translation.expand
practice.prompt.translation.collapse
practice.prompt.translation.toggle.hint
practice.prompt.explanation.expand
practice.prompt.explanation.collapse
practice.prompt.explanation.toggle.hint
```

中文建议值：

```text
中文释义
展开译文
收起译文
展开或收起完整中文释义。
查看讲解
收起讲解
展开或收起词句讲解。
```

英文建议值：

```text
Translation
Show translation
Hide translation
Show or hide the full translation.
Show notes
Hide notes
Show or hide the sentence notes.
```

- [x] **Step 2: 更新本地化必检测试**

修改 `Packages/LangoTraceUI/Tests/LangoTraceUITests/ThreePlatformPresentationCopyTests.swift` 中 `practiceSessionInteractionKeysAreLocalized` 的 `requiredKeys`，加入本任务新增的 key：

```swift
let requiredKeys = [
    "practice.navigation.previous",
    "practice.navigation.next",
    "practice.navigation.position",
    "practice.action.markComplete",
    "practice.prompt.translation.title",
    "practice.prompt.translation.expand",
    "practice.prompt.translation.collapse",
    "practice.prompt.translation.toggle.hint",
    "practice.prompt.explanation.expand",
    "practice.prompt.explanation.collapse",
    "practice.prompt.explanation.toggle.hint",
]
```

同时将 `PracticePromptCard.swift` 和 `PracticeSessionViews.swift` 加入 `mainPlatformSwiftUISurfacesAvoidHardCodedEngineeringStageWording` 的扫描列表：

```swift
for fileName in [
    "PhoneMainSections.swift",
    "PhoneMainSupportingViews.swift",
    "PadMainSections.swift",
    "MacMainView.swift",
    "MacWorkspaceContentView.swift",
    "LearningContentComponents.swift",
    "PracticePromptCard.swift",
    "PracticeSessionViews.swift",
    "LanguageSpaceSwitcherSheet.swift",
    "LangoTraceSettingsSceneView.swift",
] {
    let source = try String(contentsOf: sourceFileURL(named: fileName), encoding: .utf8)
    let matches = forbiddenHardCodedTerms.filter { term in
        source.localizedCaseInsensitiveContains(term)
    }

    #expect(
        matches.isEmpty,
        "\(fileName) exposes hard-coded engineering wording: \(matches.joined(separator: ", "))"
    )
}
```

- [x] **Step 3: 运行本地化相关测试**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PhoneIOSConvergenceTests|ThreePlatformPresentationCopyTests'
```

Expected: PASS。

### Task 6: 更新长期 UI 规范和页面事实源

**Files:**

- Modify: `docs/spec/003-ui-design-system.md`
- Modify: `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- Modify: `docs/platform-page-inventory.md`

- [x] **Step 1: 更新 UI 设计系统规范**

在 `docs/spec/003-ui-design-system.md` 单句练习页规则中补充：

```markdown
单句练习页顶部内容卡应优先展示目标语言句子。中文释义属于低权重理解辅助，默认可限制为摘要展示，但必须提供完整展开入口；语法讲解或词句说明属于更深层学习信息，默认收起并通过独立入口查看。句间切换时，译文和讲解的展开状态默认重置，避免不同句子长度导致练习控制区持续跳动。
```

同时补充：短译文应完整展示且不出现无效展开控件；默认 collapsed 高度只用于稳定练习页基准态，用户主动展开长译文或讲解时，内容卡可以自然增高。

- [x] **Step 2: 更新 Apple 交互规范**

在 `docs/spec/010-apple-platform-interaction-and-accessibility.md` iPhone 交互部分补充：

```markdown
练习页的可展开学习辅助信息不得遮挡或挤压主操作。展开 / 收起按钮应满足 44pt 触控目标，长译文必须可完整查看，不能只依赖省略号表达不可见内容。
```

同时补充：展开 / 收起按钮必须提供可访问名称、当前展开状态 value 和操作 hint；Reduce Motion 开启时，展开 / 收起不能依赖动画表达状态变化。

- [x] **Step 3: 更新平台页面清单**

在 `docs/platform-page-inventory.md` 的 iPhone 练习页或单句练习页条目中记录：

```markdown
单句练习页顶部内容卡采用目标句常驻、中文释义可展开、讲解按需查看的结构；`PracticeControlBar` 继续只承载听、回放录音和录音主操作。
```

页面事实源还应记录：iPhone、iPad、macOS 共享同一 `PracticeSessionView`，prompt card disclosure state 只是 route-local UI state，不进入 `PracticeSession`、recording metadata、TTS cache 或 media artifact。

- [x] **Step 4: 运行文档检查**

Run:

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

Expected: `scripts/check-docs.sh` 输出 `check-docs: ok`；占位词扫描无输出；`git diff --check` 无输出。

### Task 7: 收口验证

**Files:**

- Verify: all modified files

- [x] **Step 1: 聚焦验证**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests|ThreePlatformPresentationCopyTests'
```

Expected: PASS。

- [x] **Step 2: 完整验证**

Run:

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
scripts/verify.sh
```

Expected:

- `scripts/check-docs.sh` 输出 `check-docs: ok`
- 占位词扫描无输出
- `git diff --check` 无输出
- `scripts/verify.sh` 完成 Swift package tests、iPhone / iPad / macOS build、App tests 和 lint

- [x] **Step 3: 手动验证**

在 iPhone 17 模拟器检查：

1. 进入练习 Tab。
2. 打开记录卡片。
3. 进入单句练习页。
4. 确认顶部目标句视觉权重最高。
5. 找到短译文句子，确认译文完整显示且不出现 `展开译文`。
6. 找到长译文句子，点击 `展开译文`，确认长中文释义完整显示。
7. 点击 `查看讲解`，确认讲解独立展开。
8. 点击上一句或下一句，确认译文和讲解回到收起状态。
9. 确认 `听`、`回放录音`、`开始录音` 的按钮位置和状态没有因默认内容卡高度变化产生明显跳动。
10. 使用 Accessibility Inspector 或 VoiceOver spot check，确认译文和讲解按钮能读出当前展开状态。

iPad / macOS 人工检查：

1. 打开相同 practice route，确认共享 `PracticeSessionView` 的 prompt card 没有破坏主区布局。
2. 切换相邻句子，确认 disclosure state 重置。
3. 确认桌面窗口缩小时按钮文字不溢出，长译文展开后仍可滚动查看。

## 9. 复查方法

- 代码复查：确认 `PracticePromptCardPresentation` 是展示规则唯一入口，`PracticePromptCard` 只渲染 presentation，不直接散落业务判断。
- 测试复查：确认长译文、短译文、空白辅助文本、展开态、讲解态、本地化 key 和 route identity reset 都有覆盖。
- UI 复查：确认中文释义展开入口和讲解入口都满足 44pt 触控目标。
- 状态复查：确认句子切换和 route identity 变化时重置本地展开状态，不影响录音、播放或 session。
- 文档复查：确认长期规范、页面事实源和原型说明一致。

## 10. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests|ThreePlatformPresentationCopyTests'
```

文档验证：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

完整验证：

```bash
scripts/verify.sh
```

## 11. 文档影响检查

需要更新：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/platform-page-inventory.md`

不需要更新：

- ADR：本任务不改变核心产品或架构决策。
- 数据 / 存储 / 同步规范：本任务不改变持久化和同步边界。
- 权限 / 隐私规范：本任务不新增音频、AI、网络、Keychain 或权限触发。

## 12. 实施记录

2026-05-26：完成静态原型：

- `prototypes/practice-session-prompt-card/index.html`
- `prototypes/practice-session-prompt-card/styles.css`
- `prototypes/practice-session-prompt-card/README.md`

2026-05-26：用户确认采纳原型设计，本方案创建为实施控制面。

2026-05-26：完成代码实现：

- 新增 `PracticePromptCard.swift`，把顶部内容卡从 `PracticeSessionViews.swift` 中拆出，形成独立 `PracticePromptCard` 和 `PracticePromptCardPresentation`。
- `PracticePromptCardPresentation` 负责清洗空白辅助文本、判断长译文 disclosure、输出 line limit、本地化 key 和 accessibility state；短译文完整展示且不显示无效 toggle。
- `PracticeSessionView` 新增 `isTranslationExpanded` / `isExplanationExpanded` route-local UI state，并在 `routeSeed.practiceRouteIdentity` 变化和句间导航时调用 `resetPromptDisclosures()`。
- 旧 `PracticeSnapshotPanel` 已删除，避免同一职责保留两套实现。
- 补齐 `Localizable.xcstrings` 的中英文文案，并将新增 key 纳入 `ThreePlatformPresentationCopyTests` 必检列表。
- 拆分文件后聚焦验证曾暴露 `PracticePromptCard.swift` 缺少 `LangoTraceCore` import，已补齐；该类型依赖的 `PracticeSentenceSnapshot` 属于 Core，而不是 Data。

2026-05-26：完成测试和规范更新：

- `PracticeRouteSeedTests` 覆盖长译文默认收起 / 展开、短译文无 toggle、空白译文和空白讲解不渲染控制项。
- `PhoneIOSConvergenceTests` 覆盖 route identity 变化时 disclosure state reset、旧组件移除、新 prompt card 文件和 accessibility hint。
- `ThreePlatformPresentationCopyTests` 覆盖新增本地化 key，并把 `PracticePromptCard.swift` 纳入硬编码工程阶段文案扫描。
- `docs/spec/003-ui-design-system.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md` 和 `docs/platform-page-inventory.md` 已同步记录 prompt card disclosure 规则、触控 / 可访问性要求和三端共享边界。

2026-05-26：已通过聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests|ThreePlatformPresentationCopyTests'
```

结果：24 个相关测试通过。

2026-05-26：已通过文档基础检查：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

结果：`check-docs: ok`；占位词扫描无输出；`git diff --check` 无输出。

2026-05-26：已通过完整验证：

```bash
scripts/verify.sh
```

结果：完整验证退出码为 0，覆盖 XcodeGen 工程生成、各 Swift Package 测试、Python probe 单元测试、iPhone / iPad / macOS build、macOS App tests、SwiftLint 和 SwiftFormat lint。SwiftLint 仍报告 163 个 warning、0 个 serious，均未阻断验证；本任务新增的 `PracticePromptCard.swift` 参与 lint，未出现 serious violation。

2026-05-26：已完成运行态验收：

- iPhone 17 / iOS 26.5：安装 `scripts/verify.sh` 生成的 iOS 构建后进入练习 Tab、记录卡片和单句练习页。确认短译文句子默认完整展示且没有 `展开译文`；`查看讲解` 默认隐藏，点击后变为 `收起讲解`，accessibility value 从 `隐藏` 变为 `可见`；切换到下一句后讲解回到隐藏。
- iPhone 17 / iOS 26.5：为本地模拟器测试数据临时写入一条长中文释义，确认长译文默认显示 `展开译文` 且 accessibility value 为 `隐藏`；点击后变为 `收起译文`、value 为 `可见`，完整译文展示，主操作区和底部句间导航仍可见。
- iPad Pro 13-inch (M5) / iOS 26.5：使用同一测试数据进入共享 `PracticeSessionView`，确认长译文默认收起、可展开，操作区和右侧学习面板没有明显布局破坏。
- macOS：打开 `scripts/verify.sh` 生成的 `LangoTrace.app`，进入同一单句 practice route，确认长译文默认收起、可展开，窗口内主操作区、句间导航和右侧 inspector 仍可见。

## 13. 完成标准

- 单句练习页顶部内容卡默认只突出目标语言句子和低权重中文释义。
- 短中文释义完整展示且不显示无效展开按钮。
- 长中文释义可完整展开查看。
- 语法讲解默认收起，并可独立展开。
- 句间切换默认收起译文和讲解。
- 展开 / 收起按钮具备本地化文案、44pt 触控目标和可访问状态。
- `PracticeControlBar` 和句间导航行为不回退。
- 聚焦测试、文档检查和完整验证通过。
- iPhone 17 模拟器人工检查符合原型方向；iPad / macOS 已完成共享 route 的布局 smoke check。

## 14. 剩余风险

- Dynamic Type 下长英文目标句可能仍使卡片增高；本任务目标是降低辅助信息造成的默认跳动，不把目标句本身强行截断。
- 译文是否“足够长”采用 deterministic 阈值和换行判断，不能精确等价于真实渲染行数；本任务已通过短译文和长译文样例完成运行态验收，后续如改为基于真实渲染行数判断，应另开实现方案。
- iPad / macOS 共享组件会同步获得新 prompt card，但本任务不做平台专属重新排版；若 smoke check 发现大屏需要不同密度，应另开三端布局方案。
