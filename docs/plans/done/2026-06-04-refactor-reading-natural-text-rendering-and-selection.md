# Reading 自然文本渲染与任意文本选择学习面板

状态：Draft
自审核状态：Reviewed（2026-06-06 架构重写后重新自审）
类型：refactor
创建日期：2026-06-04
最后更新日期：2026-06-06

## 用户确认记录

- 2026-06-04：用户在阅读功能深度 UX 评估中指出，当前自动对文本进行句子拆分、每句渲染为独立 Button 行的模型破坏了原始阅读体验；希望保持用户原始输入的文本连续性，改为用户选中文字后才出现学习功能菜单。
- 2026-06-04：用户要求创建正式 active plan 并完成自审。
- 2026-06-05：基于代码的复查确认方案对当前代码描述基本准确（`sentenceBlock` Button 行渲染 `ReadingViews.swift:774-802`，`segmentSentences` 双重调用，`selectText`/`selectSelection`/`ReadingCompactLearningPanel` 已存在）。
- 2026-06-06：用户决策：不分 Phase A/B，在单一方案中同时实现段落连续渲染和任意文本拖选触发学习面板。确认三个架构决策：①不实现单击句子触发面板，使用 Apple 原生文本手势（双击=单词，长按拖选=任意片段，三击=整句）；②选择触发面板最小长度 ≥2 个非空白字符；③iPad 侧边 inspector 折叠时降级为底部 compact 面板。技术基础改为 `UITextView`/`NSTextView` 包装，放弃 `AttributedString + URL-link` 过渡方案。本次重写已获用户确认，进入实现授权状态（自审完成后可开始）。

## 1. 需求描述

当前阅读 Canvas 把每一个 Markdown Block 内的句子拆分为若干独立 `Button` 行垂直堆叠渲染。每句之间有 2pt 间距和 4pt 上下 padding，选中状态用圆角背景色区分。视觉效果是：原本应该是连续段落的文本，在渲染后变成一行一行间隔的"列表"，完全失去段落阅读感。

用户核心诉求：

1. **保持用户原始输入的文本连续性**——粘贴或导入的文本应该像书籍或文章一样连续排版，不应被拆分为视觉上独立的行块。
2. **拖选任意文字后出现学习面板**——用户长按选词、双击选词或拖选短语/句子后，触发包含"解释、听"等动作的学习面板；采用 Apple 平台原生文本选择交互，不引入自定义手势覆盖。

## 2. 当前现状

### 2.1 渲染架构（导致问题的根本原因）

`ReadingMarkdownBlockRenderer.sentencePresentations()` 在渲染时对每个 selectable block 调用 `ReadingTextSegmenter.segmentSentences()`，把句子列表写入 `ReadingBlockPresentation.sentences`。

`ReadingDocumentCanvas.sentenceBlock()`（`ReadingViews.swift:774`）把同一 block 内的所有句子通过 `ForEach + Button` 垂直堆叠：

```swift
VStack(alignment: .leading, spacing: 2) {
    ForEach(block.sentences, id: \.id) { sentence in
        Button { onSelectSentence(sentence) } label: {
            Text(sentence.text)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(...))
        }
        .buttonStyle(.plain)
    }
}
```

渲染单元与交互单元耦合，导致必须以句子为行呈现文本，且 Button 手势覆盖了系统长按选词能力。

### 2.2 已有能力可直接复用

- `ReadingSelectionScope.textFragment`：Core 层已预留，`ReadingTextSegmentation.swift` 中枚举已存在。
- `ReadingSelectionContext`：已有 `characterOffset`/`characterLength`/`blockID`/`sentenceID`/`selectionScope` 等字段，无需新增字段。
- `ReadingDocumentStore.selectSelection(_:)`：完整的 selection context 入口，已处理 stale invalidation 和状态重置，`selectTextFragment` 最终调用此方法。
- `ReadingTextSegmenter.segmentSentences()`：已产出带精确 `characterOffset` 的 `ReadingSentenceSegment`，`makeFragmentSelectionContext` 可直接接受预计算结果，不重复扫描。
- `ReadingCompactLearningPanel`：iPhone 非模态底部学习面板，已完成 `hidden / collapsed / loading / content / failed` 五态状态机；`compactLearningPanelState` 由 `selectedSelection != nil` 驱动。
- `ReadingDocumentStore.compactLearningPanelState`：面板状态计算属性，选择建立后自动驱动面板可见性。

### 2.3 问题汇总

| 编号 | 问题 | 代码位置 |
|------|------|----------|
| H1 | 句子拆分为 Button 行，段落感完全丢失 | `ReadingViews.swift:774` |
| H2 | ScrollView 中每行 Button 极易滚动误触 | `ReadingViews.swift:776-799` |
| H3 | 无法选择单词或短语，只能选整句 | 架构级缺失 |
| H4 | 系统长按选词/翻译被 Button 手势覆盖 | `ReadingViews.swift:776-799` |
| M1 | 学习面板出现/消失无动画过渡 | `ReadingViews.swift:409-424` |

## 3. 目标

1. 去除句子级 Button 行渲染，让每个 Block 的文本连续呈现，保持段落阅读感。
2. 使用系统原生文本选择能力（双击选词、长按拖选、三击选句）替代自定义手势。
3. 拖选文字后（150ms debounce，≥2 个非空白字符），触发底部学习面板（iPhone）或更新侧边 inspector（iPad/macOS）。
4. `ReadingTextSegmenter.segmentSentences()` 结果保留，用于为 AI 解释构建 `containingSentence` / `contextText`；不再用于渲染。
5. 学习面板出现/消失加动画过渡。

## 4. 范围

### 新增代码文件

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSelectableTextView.swift`：`UIViewRepresentable`（iOS/iPadOS）和 `NSViewRepresentable`（macOS）包装，用 `#if canImport(UIKit)` 平台分支实现，暴露统一接口。

### 修改代码文件

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`：新增 `makeFragmentSelectionContext()` 静态方法。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`：新增 `selectTextFragment()` 方法。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`：`sentenceBlock()` 替换为 `ReadingSelectableTextView`；iPad inspector 折叠检测；面板动画。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`：学习面板动画包裹。

### 测试文件

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`：新增 `makeFragmentSelectionContext` 测试。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreSelectionTests.swift`：新增 `selectTextFragment` Store 层测试（新文件，与已有 AI/TTS 测试分离）。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingSelectionFilterTests.swift`：新增选择过滤纯函数测试（新文件）。

### 文档范围

- `docs/platform-page-inventory.md`：更新 iPhone / iPad / macOS 阅读详情交互事实。
- `docs/spec/012-reading-learning-domain.md`：更新 Selection and Source Anchor 章节。

## 5. 不做什么

- 不实现"单击句子触发面板"——UITextView 单击放置光标是 Apple 平台约定行为，不对抗。
- 不实现 `AttributedString + URL-link` 句子点击方案（已否决）。
- 不改变 `ReadingTextSegmenter.segmentSentences()` 逻辑——继续运行，用于 AI 上下文构建。
- 不改变 GRDB schema、`GRDBReadingLibraryRepository` 或任何数据层代码。
- 不改变 AI 解释请求 contract、TTS artifact key 或 `ReadingSelectionExplanationService`。
- 不实现词典查词、翻译、语法分析等新学习动作（学习面板动作扩展是独立任务）。
- 不实现自定义 FlowLayout 或 TextKit 2 深度集成。
- 不修复预存的 `segmentSentences` 双重调用性能问题（`makeFragmentSelectionContext` 接受预计算 sentences，顺手解决；原有 `makeSentenceSelectionContext` 内部仍有双重调用，记录为后续优化项）。
- 不引入全文档单一 UITextView——本方案采用 per-block 粒度，与现有 block-based 数据模型对齐；全文档单一 TextKit 视图是独立的长期优化。
- 不实现跨 block 边界的文本选择——per-block 粒度下选择不跨段落，符合语言学习场景主要用例。

## 6. 推荐方案

### 6.0 核心架构判断

句子分割（`segmentSentences`）**继续作为数据/上下文层操作**，其结果用于：

- 通过 `makeFragmentSelectionContext` 为任意文本选择查找 `containingSentence` / `previousSentence` / `nextSentence`
- 为 TTS 提供 sentenceID
- 为 `sourceAnchor` 提供 characterOffset / characterLength

句子分割**不再作为视觉渲染单元**。渲染单元回归到 Block，以连续文本呈现。

### 6.1 ReadingSelectableTextView 包装

新文件 `ReadingSelectableTextView.swift`，包含平台条件实现：

```swift
// 概念签名（两个平台共享此接口）
struct ReadingSelectableTextView: /* UIViewRepresentable or NSViewRepresentable */ {
    let attributedText: NSAttributedString
    let committedHighlightRange: NSRange?  // 选择已提交后的持久高亮范围
    var onSelectionChange: (String, NSRange) -> Void  // debounce 150ms 后调用
    var onSelectionCleared: () -> Void
}
```

**iOS/iPadOS 实现要点：**

- `UITextView(frame: .zero)`，`isEditable = false`，`isSelectable = true`，`isScrollEnabled = false`
- `textContainerInset = .zero`，`textContainer.lineFragmentPadding = 0`
- 高度通过 `sizeThatFits` 计算：在 `updateUIView` 中调用 `textView.sizeThatFits(CGSize(width: proposedWidth, height: .greatestFiniteMagnitude))`，更新 `@Binding var height: CGFloat`，SwiftUI 侧用 `.frame(height: height)` 固定
- `UITextViewDelegate.textViewDidChangeSelection`：取 `textView.selectedRange`，若 `length == 0` 则调用 `onSelectionCleared`；否则启动 150ms debounce（取消上一个 `DispatchWorkItem`，新建一个），debounce 触发时提取文本并调用 `onSelectionChange`
- `committedHighlightRange` 变化时，用 `textView.textStorage.addAttribute(.backgroundColor, value: UIColor(...), range: committedHighlightRange)` 设置持久高亮

**macOS 实现要点：**

- 使用独立 `NSTextView`（不包在 `NSScrollView` 内），`isEditable = false`，`isSelectable = true`
- `NotificationCenter` 监听 `NSTextView.didChangeSelectionNotification`，同样 150ms debounce
- 右键 context menu：覆盖 `menu(for:)`，在系统菜单顶部插入"用语迹解释"（`NSMenuItem`），触发 `onSelectionChange` 路径

**选择过滤纯函数**（提取为可测试独立函数）：

```swift
// ReadingSelectableTextView.swift 或同级文件
func shouldTriggerPanel(for selectedText: String, minimumNonWhitespaceLength: Int = 2) -> Bool {
    selectedText.filter { !$0.isWhitespace }.count >= minimumNonWhitespaceLength
}
```

**NSRange → 字符偏移量的多字节安全转换：**

```swift
// NSRange 来自 UITextView/NSTextView，text 是 block 的完整字符串
if let range = Range(nsRange, in: blockText) {
    let characterOffset = blockText.distance(from: blockText.startIndex, to: range.lowerBound)
    let characterLength = blockText.distance(from: range.lowerBound, to: range.upperBound)
    // 传入 selectTextFragment
}
```

此转换正确处理 emoji、CJK 等多字节字符，不依赖 `NSRange.location` 直接作为 Swift 字符索引。

### 6.2 makeFragmentSelectionContext（Core 层新增）

```swift
// ReadingTextSegmentation.swift 新增静态方法
public static func makeFragmentSelectionContext(
    selectedText: String,
    blockID: String,
    characterOffset: Int,
    characterLength: Int,
    precomputedSentences: [ReadingSentenceSegment],  // 直接传入，避免重复扫描
    documentID: String,
    contentRevision: Int,
    structureVersion: Int,
    paragraphs: [ReadingTextChunk],
    fullDocumentText: String
) -> ReadingSelectionContext
```

**内部逻辑：**

1. 从 `precomputedSentences` 中找 containingSentence：`first(where: { $0.characterOffset <= characterOffset && characterOffset < $0.characterOffset + $0.characterLength })`
2. 若未命中（选择跨句或在句间空格），取覆盖选择中点的句子；仍未命中则以 block 完整文本作为 containingSentence 降级
3. 找到 containingSentence 后，previous/next sentence 从 `precomputedSentences` 数组按 `sentenceIndex` 取相邻项
4. contextMode / contextText 计算逻辑复用 `makeSentenceSelectionContext` 的 fullDocument / adjacentParagraphs / currentParagraph 三档判断（按字符数阈值：≤1200 → fullDocument，≤3000 → adjacentParagraphs，otherwise → currentParagraph）
5. `selectionScope` 固定设为 `.textFragment`
6. `sentenceID` 使用 containingSentence 的 `id`（如果降级，使用 `"\(blockID)-fragment"`）

### 6.3 selectTextFragment（Store 层新增）

```swift
// ReadingDocumentStore.swift 新增方法
public func selectTextFragment(
    selectedText: String,
    blockID: String,
    characterOffset: Int,
    characterLength: Int,
    sentences: [ReadingSentenceSegment],
    paragraphs: [ReadingTextChunk],
    fullDocumentText: String
) {
    let context = ReadingTextSegmenter.makeFragmentSelectionContext(
        selectedText: selectedText,
        blockID: blockID,
        characterOffset: characterOffset,
        characterLength: characterLength,
        precomputedSentences: sentences,
        documentID: documentID,
        contentRevision: contentRevision,
        structureVersion: 0,
        paragraphs: paragraphs,
        fullDocumentText: fullDocumentText
    )
    selectSelection(context)  // 复用已有入口，自动清除旧 explanation
}
```

Store 层不感知 UITextView 的存在；所有 selection 状态变更、explanation 清除和 panel 状态驱动均由已有 `selectSelection` 完成。

### 6.4 平台适配

**iPhone：**

- `ReadingDocumentCanvas.sentenceBlock()` 替换为 `ReadingSelectableTextView`
- `onSelectionChange` 回调 → 调用 `documentStore.selectTextFragment(...)`
- `compactLearningPanelState` 自动从 `.hidden` 升为 `.collapsed`，底部面板浮出
- `committedHighlightRange`：`documentStore.selectedSelection?.characterOffset + characterLength` 映射回 block NSRange，设置持久高亮

**iPad：**

- 已有 `showsPersistentInspector = true`，选择建立后 side inspector 自动更新
- 当 inspector 折叠时（通过 `ReadingLayoutModel` 或 `sidebarIsCollapsed` 状态检测），降级渲染 `ReadingCompactLearningPanel`，与 iPhone 路径一致
- 降级检测：`layout.inspectorPresentation == .sidePanel && !isInspectorExpanded` → 展示 compact panel

**macOS：**

- Side inspector 始终可见（`showsPersistentInspector = true`），选择 → inspector 更新
- 右键 context menu "用语迹解释" 菜单项通过 `NSTextView.menu(for:)` 注入，触发同一 `selectTextFragment` 路径
- macOS 不展示底部 compact panel

### 6.5 选中状态高亮

选择提交到 Store 后（panel 已触发），把 `committedHighlightRange` 传回 `ReadingSelectableTextView`，通过 `NSAttributedString.backgroundColor` 属性标注持久高亮（颜色使用设计系统已有的浅色品牌 token）。用户开始新选择时，清除上一个持久高亮。

选择过程中（dragging）：系统蓝色高亮负责实时反馈，不干预。选择稳定（debounce 触发）后：panel 出现，持久高亮设置。

### 6.6 学习面板动画

`ReadingDocumentDetailView` 中 `safeAreaInset` 的面板出现/消失包裹 `withAnimation(.easeInOut(duration: 0.22))`，面板内容加 `.transition(.move(edge: .bottom).combined(with: .opacity))`。

## 7. TDD 落点

### 红测顺序

**第一批（`ReadingTextSegmentationTests`，测试 `makeFragmentSelectionContext` 纯函数）：**

1. `fragmentSelectionContextFindsContainingSentenceByCharacterOffset`
   - 失败原因：`makeFragmentSelectionContext` 不存在
   - 验证：offset 落在某句范围内 → containingSentence = 该句文本，selectionScope = `.textFragment`

2. `fragmentSelectionContextFallsBackToBlockTextWhenOffsetOutOfAllSentences`
   - 失败原因：`makeFragmentSelectionContext` 不存在
   - 验证：offset 超出所有句子范围（如选择句间空格）→ containingSentence 降级为 block 完整文本，不崩溃

3. `fragmentSelectionContextPreviousAndNextSentenceFromPrecomputedArray`
   - 失败原因：`makeFragmentSelectionContext` 不存在
   - 验证：选中第二句 → previousSentence = 第一句文本，nextSentence = 第三句文本

4. `fragmentSelectionContextModeFollowsDocumentLengthThreshold`
   - 失败原因：`makeFragmentSelectionContext` 不存在
   - 验证：短文档（≤1200 字符）→ `contextMode = .fullDocument`；长文档 → `.adjacentParagraphs` 或 `.currentParagraph`

5. `sentenceSegmentationProducesContinuousCharacterOffsets`（沿用旧方案 #5）
   - 验证同一 block 内多句 characterOffset 连续递增、无重叠，确保 `makeFragmentSelectionContext` 的 offset 查找不出现间隙

**第二批（`ReadingSelectionFilterTests`，测试选择过滤纯函数）：**

6. `shouldTriggerPanelReturnsTrueForNormalWord`
   - 失败原因：`shouldTriggerPanel` 不存在
   - 验证："hello" → true；"  " → false；"a" → false；"ab" → true

7. `shouldTriggerPanelHandlesCJKCharacters`
   - 验证："你好" → true（2个非空白字符）；"的" → false（1个）

**第三批（`ReadingDocumentStoreSelectionTests`，新文件，测试 Store 层）：**

8. `selectTextFragmentBuildsSelectionContextWithFragmentScope`
   - 失败原因：`selectTextFragment` 不存在
   - 验证：调用后 `documentStore.selectedSelection?.selectionScope == .textFragment`

9. `selectTextFragmentClearsExistingExplanationResult`
   - 失败原因：`selectTextFragment` 不存在
   - 验证：先设置 `explanationResult`，再调用 `selectTextFragment` → `explanationResult == nil`

10. `selectTextFragmentUpdatesSelectedTextAndSentenceID`
    - 验证：`selectedText` 等于传入的 `selectedText`，`selectedSentenceID` 等于 containingSentence 的 sentenceID

## 8. 证据与决策依据

- `ReadingSelectionScope.textFragment` 已预留——Core 层设计者已预见到 fragment 选择场景，本方案是对该预留的实现落地。
- `ReadingSelectionContext` 字段完备——`characterOffset`/`characterLength`/`blockID`/`sentenceID`/`selectionScope` 等字段已存在，无需改动 Core 数据结构。
- `docs/spec/004-swiftui-architecture.md`：View 不直接访问数据库；选择状态集中在 Store。`ReadingSelectableTextView` 通过回调暴露选择事件，Store 层负责所有状态变更，符合规范。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`：系统级文本选择（长按、拖选）是 Apple 平台基础能力，不应被应用层覆盖。UITextView/NSTextView 是实现该能力的正确工具，Button 行是对该规范的违背。
- `docs/spec/003-ui-design-system.md`：阅读环境应保持安静，不在内容层叠加过多操作控件。UITextView 连续段落渲染完全符合设计系统要求。
- **放弃 AttributedString URL-link 的理由**：URL-link 是专为"不引入 UITextView 的 Phase A 过渡"设计的妥协方案；既然本方案直接引入 UITextView，URL-link hack 无存在价值，也无法解决任意文本选择需求。
- **per-block 粒度的理由**：语言学习选词/选句的场景绝大多数发生在同一段落内；per-block 与现有 block-based 数据模型完全对齐；全文档单一 UITextView 可作为后续长期优化。

## 9. 涉及代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSelectableTextView.swift`（新建）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreSelectionTests.swift`（新建）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingSelectionFilterTests.swift`（新建）
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`

## 10. 参考代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSourceAnchor.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`
- `LangoTraceApp/AppEnvironment.swift`

## 11. 涉及文档路径

- `docs/spec/012-reading-learning-domain.md`：更新 Selection and Source Anchor 章节，补充"sentence segment data is retained for AI context but sentences are no longer rendered as discrete button rows；system text selection via UITextView/NSTextView is the primary selection mechanism"。
- `docs/platform-page-inventory.md`：iPhone / iPad / macOS 阅读详情的交互描述从"点击句子行"更新为"连续段落文本 + 系统原生文本选择（双击/长按拖选/三击）触发学习面板；iPad 侧边 inspector 折叠时降级为底部 compact 面板；macOS 侧边 inspector + 右键菜单"。

## 12. 复查方法

- 在 iOS 模拟器中打开一篇多段落文本（含至少 3 段、每段 3 句以上），确认段落连续展示，无多行分隔感、无 Button 圆角背景。
- 双击单词，确认系统选择菜单出现，同时底部学习面板浮现（持久高亮标注选中词）。
- 长按 + 拖选跨句短语，确认面板内容更新为新选文本，旧 explanation 结果清空。
- 选择仅含空格的文本，确认面板不出现。
- 三击选中整句，确认面板出现，`containingSentence` 正确。
- 单击文本（仅放置光标），确认面板不出现、不崩溃。
- 学习面板出现和关闭有平滑动画过渡（无瞬间切换）。
- iPad：选择文本后 side inspector 正确更新；折叠 inspector 后选择文本，底部 compact 面板出现。
- macOS：选择文本后 side inspector 更新；右键选中文本，菜单中"用语迹解释"可点击并触发 inspector 更新。
- 确认开发构建中不出现"UITextView 高度为 0"问题（`sizeThatFits` 正常工作）。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentation
swift test --package-path Packages/LangoTraceUI --filter ReadingDocumentStoreSelectionTests
swift test --package-path Packages/LangoTraceUI --filter ReadingSelectionFilterTests
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

- `docs/spec/012-reading-learning-domain.md` §5：补充 UITextView/NSTextView 为 selection 基础，sentence segment 仅作数据层。
- `docs/platform-page-inventory.md`：三端交互描述更新（见 §11）。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`：本方案通过 UITextView/NSTextView 完全符合该 spec 要求，无需修改规范内容，实施记录中注明对齐。
- `docs/spec/004-swiftui-architecture.md`：`ReadingSelectableTextView` 作为 UIViewRepresentable，通过回调暴露事件，符合 View 不直接访问 Store 的规范，无需修改。
- `docs/architecture/notes/`：实施完成后创建备忘录，记录：per-block UITextView 的高度计算模式、NSRange 多字节安全转换约定、macOS NSTextView 不包裹 NSScrollView 的原因，供后续全文档单一 TextKit 视图优化 plan 引用。

## 15. 严格方案自审核记录

审核日期：2026-06-06
审核方式：架构重写后同轮自审（用户已确认三个核心决策，技术方案与决策对齐验证）
审核轮次：1 轮（补充 2026-06-04 原始两轮审查结论）

**已解决的旧方案 P0/P1 问题：**

- ~~P0：macOS URL-link 需要 Cmd+Click~~ → 改为 NSTextView，消除该问题
- ~~P0：macOS fallback "点击选第一句" 误导 UX~~ → 改为 NSTextView + side inspector，消除该问题
- ~~P1：handleSentenceTap 位置和 percent-encoding~~ → 整个 URL-link 方案已放弃，问题不再存在
- ~~P1：selectTextFragment 混入 Phase A 范围~~ → 本方案统一实现，问题不再存在

**本轮新发现问题及处置：**

- P1-A：NSRange 来自 UITextView/NSTextView，直接作为 Swift 字符索引在 CJK/emoji 内容下会越界 → 已在 §6.1 明确 `Range(nsRange, in: blockText)` + `distance` 的多字节安全转换，并标注为红测 #5 的前置约束。
- P1-B：UITextView 在 SwiftUI ScrollView 内高度不确定 → 已在 §6.1 明确 `sizeThatFits` 方案和 `@Binding var height` 模式；列为 §17 剩余风险并在 §12 复查方法中补充验证项。
- P1-C：iPad inspector 折叠状态检测依赖 `isInspectorExpanded` 状态，但当前 `ReadingLayoutModel` 未暴露该字段 → §6.4 标注"通过 `layout.inspectorPresentation` 或 `sidebarIsCollapsed` 状态检测"，实施时需确认该状态来源，若不存在需新增 `@Published var isInspectorExpanded: Bool`。列为 §17 剩余风险。
- P2-A：持久高亮 `NSAttributedString.backgroundColor` 与 `textStorage` 直接操作可能与 UITextView 内部 layout 产生冲突 → 备用方案记录于 §17：在 `Text` 上叠加透明 `overlay` 高亮层（SwiftUI 层实现）。
- P2-B：debounce 使用 `DispatchWorkItem` 在 `UIViewRepresentable.Coordinator` 中需注意线程安全（Coordinator 不一定是 @MainActor）→ 明确要求 debounce 回调必须 `DispatchQueue.main.async` 回调，或改用 `Task { @MainActor in ... }`；列为实施注意项。

仍需用户确认的问题：无（三个核心决策已全部确认）。

是否允许进入实现：**是**，可以进入 Phase 实施。

## 16. 完成标准

- 阅读 Canvas 中块级文本连续渲染，无多行 Button 断行感（三端均使用 UITextView/NSTextView）。
- 双击单词触发学习面板，面板内 selectedText 正确。
- 长按拖选任意片段触发学习面板，containingSentence 为正确的包含句。
- 三击选中整句触发学习面板。
- 单击文本（仅放置光标）不触发面板。
- 仅空白字符的选择不触发面板。
- 学习面板出现/消失有动画过渡。
- iPad side inspector 折叠时底部 compact 面板出现。
- macOS 右键菜单中"用语迹解释"可用。
- NSRange 多字节安全转换，CJK 文本选择不崩溃。
- 所有聚焦测试和完整验证通过。
- 文档事实源同步更新。

## 17. 剩余风险

- **UITextView 高度计算**：UITextView 在 SwiftUI ScrollView 内需正确实现 `sizeThatFits` 才能自适应高度；若实现有误会导致文本截断或无限高度。备用方案：使用 `GeometryReader` + `PreferenceKey` 传递高度。
- **iPad inspector 折叠状态字段**：`ReadingDocumentCanvas` 当前是否已有 `isInspectorExpanded` 或等价状态暴露尚未确认，实施前需检查；若不存在需在 `ReadingDocumentDetailView` 层新增并向下传递。
- **持久高亮与 textStorage 冲突**：`NSAttributedString.backgroundColor` 通过 `textStorage.addAttribute` 设置，若 UITextView 内部 layout 操作覆盖了该属性，高亮可能丢失。备用方案：在 SwiftUI 层叠加一个透明高亮 overlay（使用 GeometryReader 获取字符坐标，仅在简单单行场景有效）。
- **debounce 线程安全**：`Coordinator` 中的 debounce 回调需确保在主线程执行才能安全调用 `@MainActor` 的 Store 方法；使用 `DispatchQueue.main.async` 或 `Task { @MainActor in ... }` 封装。
- **`segmentSentences` 双重调用**：`makeSentenceSelectionContext` 内部仍会再次调用 `segmentSentences`（`ReadingTextSegmentation.swift` 第 265 行附近），是预存性能问题。本方案新增的 `makeFragmentSelectionContext` 不引入新的双重调用（接受 precomputedSentences），但原有问题保留为后续优化项。
- **macOS NSTextView 不包 NSScrollView**：独立 `NSTextView` 在 `NSViewRepresentable` 中需正确设置 `translatesAutoresizingMaskIntoConstraints = false` 和宽度约束，否则 macOS 侧高度计算可能出错。
- **跨 block 选择**：per-block 方案下用户无法跨段落拖选，这是已知限制，符合 §5 不做什么的声明。

## 18. 实施记录

（实施完成后填写）
