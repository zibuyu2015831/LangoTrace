# Reading 自然文本渲染与句子选择模型重构

状态：Draft
自审核状态：Reviewed
类型：refactor
创建日期：2026-06-04
最后更新日期：2026-06-05

## 用户确认记录

- 2026-06-04：用户在阅读功能深度 UX 评估中指出，当前自动对文本进行句子拆分、每句渲染为独立 Button 行的模型破坏了原始阅读体验；希望保持用户原始输入的文本连续性，改为用户选中文字后才出现学习功能菜单。
- 2026-06-04：用户要求创建正式 active plan 并完成自审。本方案尚未获得生产代码实现授权。
- 2026-06-05：基于代码的复查（子代理）确认本方案对当前代码的描述基本准确（`sentenceBlock` Button 行渲染、`segmentSentences` 双重调用 ~`ReadingTextSegmentation.swift:265`、`selectText`/`selectSelection`/`ReadingCompactLearningPanel` 已存在、`selectTextFragment`/`makeFragmentSelectionContext` 均不存在、spec/012 §5 选择契约引用属实）。本轮已修正以下文档不准确项：§2.1 与 H1 行号 `774-820`→`774-802`；H2/H4 行号 `783-799`/`783-800`→`777-799`（指向 Button 手势而非 label）；§4 代码范围误将 Phase B 的 `selectTextFragment` / `textFragment` scope 列入 Phase A，已标注为 Phase B 延后并与 §5/§6.5 对齐；§5/§16/§17 残留“几何估算 fallback”措辞已与 §6.1 已否决几何方案的结论对齐为“点击选中 block 内第一个未选中句子”；§6.1 补充 `highlightColor: Color` 的 `import SwiftUI` / 颜色 token 测试编译约束。本方案仍为 Draft，待用户回答 §15 两个开放问题后方可进入 Phase A 实现。

## 1. 需求描述

当前阅读 Canvas 把每一个 Markdown Block 内的句子拆分为若干独立 `Button` 行垂直堆叠渲染。每句之间有 2pt 间距和 4pt 上下 padding，选中状态用圆角背景色区分。视觉效果是：原本应该是连续段落的文本，在渲染后变成一行一行间隔的"列表"，完全失去段落阅读感。

用户的核心诉求：

1. **保持用户原始输入的文本连续性**——粘贴或导入的文本应该像书籍或文章一样连续排版，不应被拆分为视觉上独立的行块。
2. **选中文字后才出现功能菜单**——参考 Apple Books / Safari 的交互模式：用户长按或拖选文字后，弹出包含"解释、听、翻译……"等动作的学习面板，而不是预先把文本切成可点击的块。

## 2. 当前现状

### 2.1 渲染架构（导致问题的根本原因）

`ReadingMarkdownBlockRenderer.sentencePresentations()`（`ReadingMarkdownBlockRenderer.swift`）在渲染时对每个 selectable block 调用 `ReadingTextSegmenter.segmentSentences()`，把句子列表写入 `ReadingBlockPresentation.sentences`。

`ReadingDocumentCanvas.sentenceBlock()`（`ReadingViews.swift:774-802`）把同一 block 内的所有句子通过 `ForEach + Button` 垂直堆叠：

```swift
VStack(alignment: .leading, spacing: 2) {
    ForEach(block.sentences, id: \.id) { sentence in
        Button { ... } label: {
            Text(sentence.text)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(...))
        }
        .buttonStyle(.plain)
    }
}
```

这等同于把"句子"同时作为渲染单元和交互单元。渲染与交互的耦合导致必须以句子为行来呈现文本。

### 2.2 已有能力

- `ReadingDocumentStore.selectText(_:sentenceID:containingSentence:)`：已存在，可接受任意文本、可选 sentenceID 作为选择入口，无需完整 `ReadingSelectionContext`。
- `ReadingDocumentStore.selectSelection(_:)`：完整的 selection context 路径，已处理 stale invalidation。
- `ReadingTextSegmenter.segmentSentences()`：当前仍需保留，为 AI 解释构建 context（`containingSentence`、`previousSentence`、`nextSentence`）。
- `ReadingCompactLearningPanel`：iPhone 非模态底部学习面板，已完成 `hidden / collapsed / loading / content / failed` 五态状态机。

### 2.3 问题汇总（来自 UX 评估）

| 编号 | 问题 | 代码位置 |
|------|------|----------|
| H1 | 句子拆分为 Button 行，段落感完全丢失 | `ReadingViews.swift:774-802` |
| H2 | ScrollView 中每行 Button 极易滚动误触 | `ReadingViews.swift:777-799` |
| H3 | 无法选择单词或短语，只能选整句 | 架构级缺失 |
| H4 | 系统长按选词/翻译被 Button 手势覆盖 | `ReadingViews.swift:777-799` |
| M1 | 学习面板出现/消失无动画过渡 | `ReadingViews.swift:409-424` |

## 3. 目标

1. 去除句子级 Button 行渲染，让每个 Block 的文本连续呈现，保持段落阅读感。
2. 恢复系统级文本选择能力：用户可以长按选词、拖选短语或句子。
3. 文字选中后，触发现有底部学习面板，承接解释/听等动作。
4. 保留快速句子级点击（Phase A 过渡方案），降低初始改动风险。
5. 学习面板出现/消失加动画过渡，改善视觉体验。

## 4. 范围

### 代码范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`：核心渲染变更（`ReadingDocumentCanvas`）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingMarkdownBlockRenderer.swift`：句子数据保留但渲染模型解耦
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`：Phase A 不新增 `selectTextFragment`（片段选择入口划入独立 Phase B plan，见 §6.5）；句子点击经 View 层 `handleSentenceTap` 复用既有 `onSelectSentence` → `selectSelection`，本文件本阶段不改动
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`：学习面板动画包裹
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`：Phase A 不新增 `textFragment` scope 的 `makeFragmentSelectionContext`（划入 Phase B，见 §6.5）；仅复用既有 `segmentSentences` / `makeSentenceSelectionContext`，本阶段只在 §7 测试 #5 中对既有句子切分的 `characterOffset` 连续性补充断言
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`：更新并补充 TDD 测试
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`：补充片段选择路径测试

### 文档范围

- `docs/platform-page-inventory.md`：更新 iPhone / iPad / macOS 阅读详情交互事实
- `docs/spec/012-reading-learning-domain.md`：更新 Selection and Source Anchor 章节

## 5. 不做什么

- 不改变 `ReadingTextSegmenter.segmentSentences()` 的逻辑——句子分割仍需运行，用于构建 AI 解释的 context。
- 不改变 GRDB schema、`GRDBReadingLibraryRepository` 或任何数据层代码。
- 不改变 AI 解释请求 contract、TTS artifact key 或 `ReadingSelectionExplanationService`。
- 不改变 iPad / macOS inspector 的展示逻辑（side panel 继续复用现有 selection seam）。
- 不实现词典查词、翻译、语法分析等新学习动作（学习面板的动作扩展是独立任务）。
- 不引入 `UIViewRepresentable`/`NSViewRepresentable` 包装的 `UITextView`/`NSTextView`（Phase B 范围，工程复杂度高）。
- 不实现自定义 FlowLayout 或 TextKit 2 深度集成。
- 不实现 `selectTextFragment` Store 方法或 Phase B 的系统文本选择 → 学习面板路径（划入独立 Phase B plan）。
- 不修复预存的 `segmentSentences` 双重调用性能问题（后续优化 plan）。
- macOS Phase A 不保证与 iOS 完全一致的句子点击体验——macOS 使用“点击选中 block 内第一个未选中句子”的 tap fallback（§6.1 已否决几何估算方案），显式标注为过渡方案。

## 6. 推荐方案

### 6.0 核心架构判断

句子分割（`segmentSentences`）**继续作为数据/上下文层操作**，其结果用于：
- 构建 AI 解释的 `containingSentence` / `contextText`
- 为 TTS 提供 sentenceID
- 为 `sourceAnchor` 提供 characterOffset / characterLength

句子分割**不再作为视觉渲染单元**。"渲染单元"回归到 Block（段落/标题等），以连续文本呈现。

### 6.1 Phase A：AttributedString + URL-link 句子点击（本 plan 范围）

**渲染变更**：`ReadingDocumentCanvas.sentenceBlock()` 改为对同一 block 内所有句子拼接成一个 `AttributedString`，整体渲染为一个 `Text` 视图。

每个句子 span 通过 `AttributedString.link` 属性携带 URL（如 `sentence://blockID/sentenceID`），在 iOS/iPadOS 上单点触发 `openURL` 回调，实现无视觉差异但可点击的句子选择：

```swift
// 概念伪代码
var attrStr = AttributedString()
for sentence in block.sentences {
    var span = AttributedString(sentence.text)
    if sentence.id != selectedSentenceID {
        span.link = URL(string: "sentence://\(sentence.blockID)/\(sentence.id)")
    } else {
        // 选中句：不设 link（避免选中态可再次点击），设置背景色
        span.backgroundColor = selectionHighlightColor
    }
    attrStr += span
    attrStr += AttributedString(" ")
}
Text(attrStr)
    .environment(\.openURL, OpenURLAction { url in
        handleSentenceTap(from: url, sentences: block.sentences)
        return .handled
    })
    .textSelection(.enabled)
```

**macOS 特殊处理**：macOS 上 SwiftUI `Text` 中的 `AttributedString.link` 需要 Cmd+Click 才能触发 `openURL`，普通单击不生效。`Text` 视图不暴露字符位置 API，无法通过几何估算精确映射点击到句子（所有超过单行的段落都会触发多行回绕，几何映射不可行）。因此 macOS 采用简单 fallback：在 `Text` 上叠加 `onTapGesture`，点击后选中 block 内第一个未选中句子（即当前 `selectedSentenceID` 之外的第一条）。该 fallback 在 macOS Phase A 实施记录中显式标注为过渡方案，Phase B 统一使用 `NSTextView` 包装替换后具备精确句子命中。

**`AttributedString` 构建逻辑提取为纯函数**：`AttributedString` 构建逻辑必须从 View 体中提取为包级可测试纯函数（或 `ReadingBlockPresentation` 上的扩展方法），签名类似：

```swift
// Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingMarkdownBlockRenderer.swift 或同级文件
extension ReadingBlockPresentation {
    func attributedString(
        selectedSentenceID: String?,
        highlightColor: Color
    ) -> AttributedString
}
```

该函数返回完整的 `AttributedString`，其中非选中句 span 携带 percent-encoded URL 的 `link` 属性，选中句 span 携带 `backgroundColor`。将逻辑放在扩展方法中，使其可在 SPM `swift test` 中通过 `@Suite` 直接测试，无需实例化 SwiftUI 视图。

注意：`highlightColor: Color` 引用 SwiftUI `Color`，而红测文件 `ReadingPresentationTests.swift` 当前仅 `@testable import LangoTraceUI`。新增测试需补 `import SwiftUI` 才能引用 `Color`；或将签名改为接受平台无关颜色 token（如既有 `LangoTraceDesign` 颜色抽象），使纯函数不依赖 SwiftUI。实施时需在第一批红测落地前确定该签名，避免红测无法编译。

**URL percent-encoding 要求**：构建 URL 时对 blockID 和 sentenceID 必须做 percent-encoding：

```swift
let encodedBlockID = sentence.blockID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sentence.blockID
let encodedSentenceID = sentence.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sentence.id
span.link = URL(string: "sentence://\(encodedBlockID)/\(encodedSentenceID)")
```

`handleSentenceTap` 解析时做对称 percent-decoding：

```swift
func handleSentenceTap(from url: URL, sentences: [ReadingSentencePresentation]) -> ReadingSentencePresentation? {
    guard url.scheme == "sentence" else { return nil }
    let pathComponents = url.pathComponents // 已自动 percent-decoded
    guard pathComponents.count >= 2 else { return nil }
    let sentenceID = pathComponents[1]
    return sentences.first { $0.id == sentenceID }
}
```

**`handleSentenceTap` 实现位置**：在 View 层，不在 Store 层。`ReadingDocumentCanvas` 接受一个 `onSelectSentence: (ReadingSentencePresentation) -> Void` 闭包（已有），`handleSentenceTap` 解析 URL 中的 sentenceID，在 `block.sentences` 数组中查找对应 `ReadingSentencePresentation`，找到后调用 `onSelectSentence`。URL 解析失败或 sentenceID 未命中时，静默忽略，选择状态不变。

**文本选择**：Block 级 `Text` 加 `.textSelection(.enabled)`，恢复系统长按选词和拖选能力（Copy / Look Up / Translate）。iOS 上单点触发 URL-link，长按触发系统选择；两者手势不冲突（短 tap vs 长 press）。

**选择回调**：Phase A 不实现系统文本选择 → 学习面板的联通（SwiftUI `Text` 没有 `onTextSelection` 回调）。系统选择仍走系统菜单。学习面板触发路径仅通过 URL-link / macOS tap fallback 实现。

### 6.2 Phase B（独立后续 plan）：文本选择触发学习面板

在 Phase A 基础上，后续通过以下方式实现"选中文字 → 学习面板"：

- 在 `UITextView`/`NSTextView` 包装中监听 `selectedRange` 变化，调用 `documentStore.selectTextFragment(text:characterOffset:characterLength:)`
- 或使用 iOS 18+ `TextSelectability` 相关 API

Phase B 不在本 plan 范围内，须另建 active plan。

### 6.3 学习面板动画（本 plan 范围）

`ReadingDocumentDetailView` 中 `safeAreaInset` 的面板出现/消失包裹 `withAnimation(.easeInOut(duration: 0.22))`，面板内容加 `.transition(.move(edge: .bottom).combined(with: .opacity))`。

### 6.4 渲染性能边界说明

`ReadingMarkdownBlockRenderer.sentencePresentations()` 在计算 presentation 时仍会调用 `ReadingTextSegmenter.segmentSentences()`。当前存在一个预存的性能问题：`makeSentenceSelectionContext()` 内部会再次调用 `segmentSentences()`（`ReadingTextSegmenter.swift` 第 265 行附近），导致同一 block 被 NLTokenizer 扫描两遍。

本 plan 不修复该双重扫描问题，原因是：
1. 该问题是预存问题，与本次渲染模型变更无关。
2. presentation 计算是懒求值（只在 document 打开或 contentRevision 变化时触发），不在每帧运行。

剩余风险章节已记录该问题为后续优化项。Phase B 或独立性能优化 plan 中应考虑在 block 级缓存句子分割结果。

### 6.5 Phase B 预留（本 plan 不实现）

`ReadingDocumentStore.selectTextFragment(text:blockID:sentenceID:characterOffset:characterLength:...)` 方法和对应 Core 层的 `makeFragmentSelectionContext` 静态方法，以及相关 TDD 测试，划入独立 Phase B plan，本 plan 不实现，不测试，不计入完成标准。

## 7. TDD 落点

### 红测顺序

**第一批红测（`ReadingPresentationTests`，测试对象为 `ReadingBlockPresentation.attributedString(selectedSentenceID:highlightColor:)` 纯函数）**：

1. `nonSelectedSentenceSpanCarriesPercentEncodedLinkURL`
   - 失败原因：`ReadingBlockPresentation` 当前无 `attributedString(selectedSentenceID:highlightColor:)` 扩展方法；新测试验证非选中句子的 span 在结果 `AttributedString` 中携带正确 percent-encoded 格式的 `link` URL（`sentence://encodedBlockID/encodedSentenceID`）。
   - Package：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`

2. `selectedSentenceSpanHasBackgroundColorAndNoLinkAttribute`
   - 失败原因：当前无该扩展方法；新测试验证 selectedSentenceID 对应的 span 无 `link` 属性（避免选中态可再次点击）且有背景色属性。

3. `handleSentenceTapParsesPercentEncodedURLCorrectly`
   - 失败原因：当前无 `handleSentenceTap` 函数；新测试验证以下场景：
     - 合法 URL（blockID/sentenceID 含特殊字符后 percent-encoded）→ 返回正确 `ReadingSentencePresentation`
     - `scheme != "sentence"` 或路径不足 → 返回 `nil`
     - sentenceID 未在 sentences 中命中 → 返回 `nil`

**第二批红测（`ReadingDocumentStoreAIAndTTSTests`）**：

4. `handleSentenceTapWithValidURLCallsOnSelectSentenceWithMatchingPresentation`
   - 失败原因：当前无 URL 解析到 `onSelectSentence` 的端到端测试；新测试验证解析到正确 `ReadingSentencePresentation` 后 `onSelectSentence` 被调用（与已有 `staleAIResponseIgnoredAfterSelectionChanges` 不重叠，该测试验证的是"选中后 explanation 被清空"的 Store 行为，本测试验证的是"URL → 正确句子对象的匹配"这一新行为）。

**Core 补充测试（`ReadingTextSegmentationTests`）**：

5. `sentenceSegmentationForMultiSentenceBlockProducesContinuousCharacterOffsets`
   - 验证同一 block 内多句的 `characterOffset` 连续递增、无重叠，确保 `attributedString` 扩展方法拼接时的 span 范围映射正确。

## 8. 证据与决策依据

- `docs/spec/012-reading-learning-domain.md` 第 5 节：已明确"sentence selection is the default supported reading-learning selection model on compact iPhone detail"但同时规定"request and anchor contract must already distinguish `selection_scope = sentence` and `selection_scope = text_fragment`"。本方案的 Phase A 在渲染层去除 Button 分割后，仍通过 URL-link 保持句子级快速选择，完全符合本节要求。
- `docs/spec/004-swiftui-architecture.md`：View 不直接访问数据库；选择状态集中在 Store。本方案不改变 Store 职责边界。
- `docs/spec/003-ui-design-system.md`：阅读环境应保持安静，不在内容层叠加过多操作控件。URL-link 句子点击在视觉上不增加任何控件，完全符合设计系统要求。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`：系统级文本选择（长按、拖选）是 Apple 平台基础能力，不应被应用层覆盖。恢复 `.textSelection(.enabled)` 是对该规范的回归。
- `ReadingDocumentStore.selectText(_:sentenceID:)` 已存在并用于 iPad/macOS 侧面板的直接选择路径，说明 store 层架构已为 fragment selection 预留了扩展位，Phase B 可在此基础上扩展。
- 选择 `AttributedString + URL-link` 而非"直接去掉 Button + 零 spacing"的理由：后者（`ForEach + Text + spacing:0`）虽然可以减少视觉间隔，但每个句子仍是一个独立 `Text` 视图，在 SwiftUI 的 `VStack` 中不会真正做段落内自然换行——最后一句的末尾到下一句的开头仍会断行。`AttributedString` 拼接成单一 `Text` 是实现真正段落连续感的必要条件。

## 9. 涉及代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingMarkdownBlockRenderer.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`

## 10. 参考代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSourceAnchor.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`
- `LangoTraceApp/AppEnvironment.swift`

## 11. 涉及文档路径

- `docs/spec/012-reading-learning-domain.md`（更新 Selection and Source Anchor 章节）
- `docs/platform-page-inventory.md`（更新 iPhone / iPad / macOS 阅读详情交互描述）

## 12. 复查方法

- 在 iOS 模拟器中打开一篇多段落文本（含至少 3 段、每段 3 句以上），确认段落连续展示，无多行分隔感。
- 点击段落内的句子，确认该句出现高亮背景，底部学习面板浮现（不崩溃、不出现系统 URL 打开日志）。
- 长按文本，确认系统选择菜单（Copy / Look Up）出现，且不触发学习面板。
- 切换点击不同句子，确认学习面板内容刷新，旧 explanation 结果清空。
- 学习面板出现和关闭有平滑动画过渡（无瞬间切换）。
- iPad 阅读工作台：点击句子后 side inspector 正确更新选中内容。
- macOS 阅读工作台：点击段落后触发 block 内第一个未选中句子高亮（macOS fallback），实施记录中有显式标注。
- 确认开发构建中 `openURL` 回调被 `.handled`（无"Can't open URL of this type"系统日志）。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentation
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
swift test --package-path Packages/LangoTraceUI --filter ReadingDocumentStoreAIAndTTSTests
scripts/check-docs.sh
git diff --check
```

完整验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

## 14. 文档影响检查

- `docs/spec/012-reading-learning-domain.md` 第 5 节：补充"sentence segment data is retained for AI context but sentences are no longer rendered as discrete button rows；Phase B fragment selection UI remains deferred"。
- `docs/platform-page-inventory.md`：iPhone / iPad / macOS 阅读详情的交互描述从"点击句子行"更新为"连续段落文本 + 点击句子触发学习面板（iOS URL-link；macOS tap fallback）"。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`：本方案恢复 `.textSelection(.enabled)` 符合该 spec 要求（"系统级文本选择不应被应用层覆盖"），无需修改规范内容，实施记录中注明对齐。
- `docs/spec/002-navigation-and-routing.md`：本方案不引入新路由，无需改动。
- `Localizable.xcstrings`：本方案不新增 UI 文案，无需改动。
- `docs/architecture/notes/`：Phase B 的 `selectTextFragment` 预留签名、`makeFragmentSelectionContext` 位置约束和 Phase B 入口依赖，在本 plan 实施完成后创建对应备忘录，确保 Phase B plan 创建时可引用。

## 15. 严格方案自审核记录

审核日期：2026-06-04
审核方式：两轮独立子代理隔离审查（Round 1：架构评审；Round 2：TDD / 安全 / 可行性评审）
审核轮次：2 轮
未使用隔离审查的原因：N/A（已使用子代理隔离审查）

发现摘要：

**Round 1（架构评审）**

- P0-1：macOS `AttributedString.link` 需要 Cmd+Click 才能触发 `openURL`，普通单击不响应 → 原方案未提供 macOS fallback。
- P0-2：`sentencePresentations()` 中 `segmentSentences` 被双重调用的情况在方案中描述模糊，可能导致实施中产生歧义。
- P1-1：`handleSentenceTap` 实现位置（View 层还是 Store 层）及 URL percent-decode 逻辑未明确说明。
- P1-2：`selectTextFragment` 方法签名出现在 Phase A 范围内，但该方法属于 Phase B（系统拖选 → 学习面板）能力，不应出现在本 plan。

**Round 2（TDD / 安全 / 可行性评审）**

- P1-A：`AttributedString` 构建逻辑放在 View body 内无法在 `swift test` 中测试 → 需提取为纯函数。
- P1-B：blockID / sentenceID 来自用户导入内容，若含 URL 特殊字符（如 `#`、`?`、`&`、空格）会导致 URL 解析失败 → 需显式 percent-encoding。
- P2（macOS fallback 可行性）：方案中"几何估算最近句子"在 SwiftUI `Text` 中无法获取精确字符边界，属于不可行设计 → 替换为更简单的"点击时选中 block 内第一个未选中句子"的临时方案，Phase B 通过 `NSTextView` 替换。
- P2（TDD 红测试 #4 重叠）：原红测试 #4 与已有 `staleAIResponseIgnoredAfterSelectionChanges` 重叠 → 改为测试 URL 解析 → 正确 `ReadingSentencePresentation` 匹配的行为。
- P2（`openURL` 失败路径未文档化）：Section 12（验证方法）和 Section 17（剩余风险）需补充。
- P2（`spec/010` 未列入文档影响检查）：`.textSelection(.enabled)` 恢复应与 spec/010 对齐并记录。
- P2（Phase B architecture note 缺失）：Phase B 预留接口和位置约束需在本 plan 完成后写入 `architecture/notes/`。

写回修改：

- Section 6.2：添加 macOS fallback 策略（`onTapGesture` 选中 block 内第一个未选中句子），标注为 Phase A 过渡方案。
- Section 6.1：添加 `handleSentenceTap` 的实现位置（View 层）和 percent-decode 代码示例；添加 blockID / sentenceID percent-encoding 要求和代码示例。
- Section 8（或原 Phase B 段落）：移除 `selectTextFragment` 签名，改为 Phase B 范围说明和独立 plan 引用。
- Section 7（TDD 红测试）：提取 `ReadingBlockPresentation.attributedString(selectedSentenceID:highlightColor:)` 纯函数，更新 #4 红测试为 URL 解析正确性测试。
- Section 12（验证方法）：添加 `openURL` 拦截失败场景的回归验证说明。
- Section 14（文档影响检查）：添加 `spec/010` 引用；添加 Phase B architecture note 写入任务。
- Section 17（剩余风险）：补充 `openURL` 拦截未配置导致系统 URL 打开的风险。

仍需用户确认的问题：

1. macOS Phase A fallback（点击 block 选中第一个未选中句子）是否满足当前验收标准，还是希望 macOS 阶段先跳过点选交互、仅保留系统文本选择和 side inspector？
2. Phase B（系统拖选文字 → 学习面板）是否在本次方案批准后立即启动，还是等 Phase A 上线验证后再开始？

是否允许进入实现：待用户确认上述两个问题后，可进入 Phase A 实现。

## 16. 完成标准

- 阅读 Canvas 中块级文本连续渲染，无多行 Button 断行感（iOS/iPadOS 使用 AttributedString URL-link，macOS 使用“点击选中 block 内第一个未选中句子”的 tap fallback）。
- 系统长按选词功能恢复（`.textSelection(.enabled)`）。
- 点击文本中的句子可触发学习面板（iOS/iPadOS URL-link 路径；macOS tap fallback 路径）。
- 学习面板出现/消失有动画过渡。
- URL 解析失败时不崩溃，选择状态不变。
- 所有聚焦测试和完整验证通过。
- 文档事实源同步更新。
- macOS Phase A fallback 在实施记录中显式标注为过渡方案。

## 17. 剩余风险

- `AttributedString.link` 在 iOS/iPadOS `Text` 中需要 `environment(\.openURL)` 拦截，否则会尝试真实 URL 打开。必须确保拦截环境在 iPhone 详情页和 iPad 工作台的每个渲染路径上都正确配置。
- macOS Phase A 使用“点击选中 block 内第一个未选中句子”的 tap fallback（§6.1 已否决几何估算方案），不保证句子级精确命中（特别是多行回绕文本场景），是显式的过渡方案，不应视为生产质量交互。Phase B 通过 `NSTextView` 包装替换。
- 选中句高亮用 `AttributedString.backgroundColor` 实现（iOS 15+/macOS 12+）。若出现平台兼容问题，备用方案是在 `Text` 上叠加透明 `overlay` 高亮层。
- `AttributedString.backgroundColor` 与系统文本选择高亮色（蓝色）在同一 `Text` 上可能叠加显示，造成视觉混乱。Phase A 接受该视觉现象；若需消除，可在 `.onAppear` 时检测选择状态并清除句子背景色（后续优化）。
- Phase A 只实现 URL-link 句子点击，不实现"系统拖选文字 → 学习面板"的联通。用户若希望拖选单词后直接触发解释，Phase A 不满足；此边界已在用户确认记录中明确。
- iPad/macOS side inspector 通过 `documentStore.selectedSentenceID` 展示选中态；改为 AttributedString 渲染后，sentenceID 仍通过 URL-link → `onSelectSentence` → `documentStore.selectSelection()` 路径回传，需在 iPad/macOS 上做回归验证。
- `segmentSentences` 在 `ReadingMarkdownBlockRenderer` 中仍被双重调用（一次在 `sentencePresentations`，一次在 `makeSentenceSelectionContext` 内部），是预存性能问题，本 plan 不修复，记录为后续优化项。
- Phase B（系统文本选择 → 学习面板）需要独立 plan，本 plan 不实现，不计入完成标准。

## 18. 实施记录

（实施完成后填写）
