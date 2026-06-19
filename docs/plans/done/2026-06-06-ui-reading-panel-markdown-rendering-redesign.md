# Task Plan: Reading Panel Redesign and Markdown Rendering Fix

**Date**: 2026-06-06  
**Type**: bug-fix + ui-redesign  
**Status**: done  
**自审核状态**: Reviewed + post-review fixes applied

## Background

iOS testing revealed three functional problems and one visual consistency problem in the reading implementation.

**Functional problems:**

1. **Markdown rendering quality**: `ReadingSelectableTextView` renders unstyled plain text. Headings look identical to body text; bold/italic/code inline runs are computed but never applied to the UITextView. A separate bug: `ReadingMarkdownBlockRenderer.inlinePresentation` maps `.plain` inline run kind to `.emphasis` role.
2. **"听" button silent**: `playSelectionSentence` always plays `containingSentence` regardless of selection scope. For a text fragment selection (a word or phrase), users expect to hear that word/phrase pronounced. Playing the full containing sentence is unexpected and may be inaudible to users who expect word-level TTS.
3. **Learning panel button semantics**: "解释" already returns `meaningInNativeLanguage` (= translation) and `usageNote` (≈ grammar). The "More" menu with disabled "翻译" and "语法分析" buttons is dead UI that creates false affordance.

**Visual consistency problem:**

4. **阅读界面视觉风格与全局设计系统脱节**：选中高亮使用系统黄色（与 app 的 teal accent 体系冲突）；操作按钮使用系统 `.borderedProminent`/`.bordered`（system blue accent，与 app 的 teal 品牌色不一致）；iPhone 底部学习面板使用 `.ultraThinMaterial`（通用 iOS 磨砂，与 warm paper 调色盘不一致）；解释结果主文字使用 `.callout` 字号（阅读场景下偏小）；结果行标签 `minWidth: 36` 过窄（不足以容纳中文标签，如"翻译"）。

## Decision

1. Apply `NSAttributedString` styling to `ReadingSelectableTextView` based on block kind and inline runs — heading fonts (title2/title3/headline), body, italic blockquote, monospaced code block, bold/italic/code inline formatting.
2. Fix `playSelectionSentence`: `.textFragment` scope plays `selectedText`; `.sentence` scope plays `containingSentence`. Use a fragment-specific cache key.
3. Extend `ReadingSelectionExplanationResult` with `grammaticalNote: String?`. Remove the "More" menu. Redesign the result area to show all structured fields.
4. 对阅读界面进行 UI 一致性修缮，使视觉风格与 app 全局设计系统（warm paper 调色盘 + teal accent，见 `LangoTraceDesign`）对齐。不引入与已有组件重复的新抽象（见"组件边界"节）。

## Scope

**Core** (`LangoTraceCore`):
- `ReadingAppearance.swift`: Add `.plain` to `ReadingInlineRole`
- `ReadingAIExplanation.swift`: Add `grammaticalNote: String?`; bump schema version to `reading_selection_explanation.v2`

**UI** (`LangoTraceUI`):
- `ReadingMarkdownBlockRenderer.swift`: Fix `.plain` → `.plain` inline role mapping
- `ReadingSelectableTextView.swift`:
  - Accept `blockKind`, `inlineRuns`, `lineSpacing`; build `NSAttributedString`
  - 选中高亮颜色：iOS 动态 teal（`#126B5D` 15% light / `#72D2BF` 22% dark）；macOS 动态 teal（`NSColor(name:dynamicProvider:)`）
- `ReadingDocumentStore.swift`: Fix `playSelectionSentence` for fragment scope
- `ReadingViewComponents.swift`:
  - Remove "More" menu; redesign result area; add new localization strings
  - 新增 `ReadingActionPill` 私有组件（Capsule 图标+文字，primary = teal 填充，secondary = teal-muted 描边，含 loading/failed 状态，最小触控高度 44pt）
  - `ReadingInspectorPane`：操作按钮替换为 `ReadingActionPill`，左对齐不铺满
  - `ReadingCompactLearningPanel`：操作按钮替换为 `ReadingActionPill`；背景从 `.ultraThinMaterial` 改为 `surfacePanel`（FFFDF8 light / 1D2E2A dark）+ `.ignoresSafeArea(edges: .bottom)` + 上投影（`radius: 8, y: -3`）；保留 0.5pt 顶部分隔线
  - `ReadingExplanationResultView`：新增 `cardBackground` 参数（默认 `surfacePanel`）；主解释文字 `.callout` → `.body`；在 compact panel 中传入 `surfaceMuted` 实现面板与卡片的层次区分
  - `ReadingResultRow`：label `minWidth` 36 → 48，适配中文标签
- `ReadingViews.swift`: Pass new parameters to `ReadingSelectableTextView`
- `Localizable.xcstrings`: Add result label strings

**Tests**:
- Update `.sample()` helpers in AI/TTS and selection test files for new schema fields

## 组件边界说明

阅读界面引入 `ReadingActionPill` 前，已存在两个操作按钮抽象：

| 组件 | 位置 | 形态 | 文字标签 | 使用场景 |
|------|------|------|---------|---------|
| `SentencePairActionButton` | `SentencePairActionControls.swift` | 圆形图标（无文字） | 无 | 学习材料句子对的"听"和"练习"按钮 |
| `ReadingActionPill` | `ReadingViewComponents.swift`（private） | Capsule 图标+文字 | 有 | 阅读选择面板的"解释"和"听"按钮 |

两者形态和使用场景不同，不需要合并。`ReadingActionPill` 限定为 `private`，不对 ReadingViewComponents 以外的组件暴露。

阅读界面的学习面板与 iPad 学习面板同样无重叠：

| 组件 | 位置 | 触发方式 | 内容来源 |
|------|------|---------|---------|
| `ReadingInspectorPane` | `ReadingViewComponents.swift` | 在阅读视图内选中文本 | `ReadingDocumentStore.selectedSelection` |
| `ReadingCompactLearningPanel` | `ReadingViewComponents.swift` | 在 iPhone 阅读视图内选中文本 | `ReadingDocumentStore.selectedSelection` |
| `PadLearningPanelView`（`.reading` route） | `PadLearningPanelView.swift` | iPad 主界面路由到阅读 tab | 仅展示静态引导文字，不接管阅读选择 |

`PadLearningPanelView` 的 `.reading` case 目前只渲染 `routeContextContent`（静态标题+提示），不显示选中词解释。阅读词语解释由 `ReadingInspectorPane`（作为 `ReadingLibraryView` 的内嵌面板）独立承担，两者不存在重叠，也不需要合并。

## TDD Touchpoints

- `ReadingSelectableTextView.makeAttributedString` 是 `static func`，可在不依赖 UIKit/AppKit 布局引擎的情况下断言 NSAttributedString attribute（字体 trait、颜色、背景色），属于可自动化的回归测试路径。当前未补充，建议后续在 `ReadingAttributedStringTests` 中覆盖。
- `playSelectionSentence` 的 `.textFragment` 分支行为（播放 selectedText 而非 containingSentence）和 fragment-specific cache key 格式，**没有专项单元测试覆盖**。方案原 TDD 节写"covered by existing test infrastructure"为过度乐观声明；实际 `grep playSelectionSentence Tests/` 无命中。需在 `ReadingDocumentStoreAIAndTTSTests.swift` 中补充两个测试：textFragment 分支和 sentence 基础路径。
- `grammaticalNote` AI 服务层尚未实施（见 Risks），补充测试应与服务层修复同步进行，包含 fixture 含 `grammatical_note` 时解析成功、不含时 `grammaticalNote == nil` 两个用例。
- Schema extension：update existing `.sample()` helpers；existing tests verify `explanationResult` fields are populated。
- UI 修缮变更（高亮颜色、按钮样式、面板背景、字体大小）属于纯视觉层，无需新增单元测试；手动验证见下方。

## Verification

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentation
swift test --package-path Packages/LangoTraceUI --filter ReadingDocumentStore
swift test --package-path Packages/LangoTraceUI --filter ReadingSelection
swift test --package-path Packages/LangoTraceAI --filter ReadingSelectionExplanation
```

Manual (iOS Simulator):
- 构建 iOS simulator，打开阅读文档
- 验证标题字体与正文字体差异，粗体/斜体/代码内联样式渲染
- 选中单个词语，验证"听"播放选中词（不是整句）
- 选中整句，验证"听"播放整句
- 验证面板展示翻译 + 语法（grammaticalNote）字段
- 验证选中高亮为 teal 色（不是黄色）
- 验证底部面板背景为 warm paper（不是磨砂）
- 验证操作按钮为 teal Capsule 样式（解释=填充，听=描边）
- dark mode 下验证面板背景、高亮色和按钮的对比度

## Risks

- `NSAttributedString` rendering with `UITextView.attributedText` resets selection state; mitigated by only rebuilding when text or block kind changes (Coordinator tracks `lastRenderedText` + `lastRenderedKind`).
- Adding `grammaticalNote` as optional means AI responses that don't populate it will show no grammar section — acceptable fallback.
- Early stage: no migration needed for persisted data (schema version bump is for AI response identification only, not DB schema).
- 底部面板背景从 material 改为 solid color：`.ultraThinMaterial` 在 `safeAreaInset` 内会自动向下延伸至 home indicator 区域；改为 solid color 后通过 `ignoresSafeArea(edges: .bottom)` 实现同等延伸，需真机验证 home indicator 区域渲染无异常。
- `ReadingExplanationResultView.cardBackground` 默认值为 `LangoTraceDesign.ColorToken.surfacePanel`（静态 computed property），Swift 将在每次调用方初始化时求值，行为符合预期。
- **[回溯发现] `grammaticalNote` AI 服务层实施缺口**：`ReadingSelectionExplanationService` 的 `schemaVersion` 仍为 v1，`responseSchema()` 和 `parseResult()` 均未包含 `grammatical_note` 字段，Prompt Return fields 也未更新。UI 层渲染逻辑已就位，但真实 Provider 调用时 `grammaticalNote` 永远为 `nil`，语法栏不显示。需后续任务补充服务层实施（建议与"阅读解析缓存"方案合并）。
- **[回溯发现] `audioState = .failed` 为不可达状态**：`ReadingTTSAction` 类型签名为 `async -> Void`（无 throw 路径），`ReadingDocumentStore` 中无路径将 `audioState` 置为 `.failed`。`ReadingActionPill` 的 `isFailed` 参数及对应的 `speaker.slash` 失败态 UI 为 dead code；TTS 静默失败时用户无反馈。后续若需要 TTS 错误提示，需将 `ReadingTTSAction` 改为可 throw，并补充 `audioState = .failed` 转换路径。
- **[回溯发现] macOS `NSTextView` 不更新 `height` binding**：`ReadingSelectableTextView` 的 macOS `updateNSView` 缺少高度计算逻辑（iOS 对应路径存在），导致 macOS 所有 selectable block 固定为默认 44pt，文字超出部分被截断。已写入架构备忘录（见 `docs/architecture/notes/`），待 macOS 阅读体验专项修复。
- **[回溯发现] `selectSelection()` 未重置 `audioState`**：切换选区时 `audioState` 未立即归 `.idle`，存在短暂 UI 不一致窗口（已取消的 TTS 任务完成时才归 idle）。建议在 `selectSelection()` 中加入 `audioState = .idle`。

---

## 严格方案自审核记录

审核日期：2026-06-06
审核方式：两轮子代理隔离审查（回溯性，方案实现已完成）
审核轮次：第一轮（系统架构师）+ 第二轮（TDD / 安全 / 落地性）并行执行
未使用隔离审查的原因：N/A（已使用隔离子代理）

### 发现摘要

#### P1 — 方案 Scope 与实现不一致：`grammaticalNote` 未完整落地到 AI 层

**问题**
方案 Scope 写明"Add `grammaticalNote: String?`; bump schema version to `reading_selection_explanation.v2`"，但 `ReadingSelectionExplanationService.swift` 中：
- `promptID` / `schemaVersion` 仍为 `v1`（第 13–15 行）
- `responseSchema()` 的 `required` 数组及 `properties` 未包含 `grammatical_note`（第 207–226 行）
- `parseResult()` 未解析 `grammatical_note` 字段（第 262–285 行）
- 用户侧 Prompt 的 Return fields 列表未包含 `grammatical_note`（第 42–49 行）
- AI 服务测试 fixture `explanationJSON()` 仍使用 v1 schema，无 `grammatical_note` 字段（第 151–161 行）

**证据**
`Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`：行 13–15 (`schemaVersion = "reading_selection_explanation.v1"`)；行 203–226 (`responseSchema`)；行 262–285 (`parseResult`)。
`Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`：行 151–161 (`explanationJSON`)。
对比：`ReadingAIExplanation.swift` 第 54 行存在 `grammaticalNote: String?`，`.sample()` helper 已填充该字段。

**影响**
UI 层的 `ReadingExplanationResultView` 展示 `grammaticalNote` 的逻辑已就位，但 AI 服务永远不会返回该字段（模型被 JSON Schema 约束为 required 字段集，`grammatical_note` 不在其中），导致语法栏在真实环境中始终不显示。这是一个显现不出的功能缺口，不会造成崩溃，但目标功能未完成。

**建议修改**
在 `ReadingSelectionExplanationService.swift` 中：
1. 将 `schemaVersion` 更新为 `reading_selection_explanation.v2`
2. 在 `responseSchema()` 的 `properties` 中加入 `"grammatical_note": ["type": "string"]`（optional，不加入 `required`）
3. 在 `parseResult()` 中解析 `object["grammatical_note"] as? String` 并传入 `grammaticalNote:` 参数
4. 在 Prompt 的 Return fields 中加入 `- grammatical_note (optional)`
5. 更新 AI 服务测试 fixture 为 v2 schema 并加入 `grammatical_note` 字段

**是否阻塞实现**：否（方案已完成；回溯修复建议，不影响已有功能，但 grammaticalNote 功能不完整）

---

#### P2 — `selectSelection()` 未重置 `audioState`

**问题**
`ReadingDocumentStore.selectSelection()` 在用户选中新文本时重置了 `explanationResult`、`explanationState` 并调用了 `invalidateInFlightWork()`，但没有重置 `audioState`（第 167–175 行）。
- 若 TTS 请求正在进行（`audioState == .loading`）时用户切换选中文本，`audioState` 仍保持 `.loading`，"听"按钮会继续显示加载状态，直到前一个 TTS 请求完成或被 token 机制丢弃后才归 `.idle`。
- `invalidateInFlightWork()` 已取消 `ttsTask`，但被取消的任务走 `completeTTS(token:request:)` 时检查 `isCurrent`——取消后 generation 已增加，token 不匹配，`audioState` 会在 `completeTTS` 中被正确归 `.idle`，所以实际上最终会恢复。但在 task cancel 和 completeTTS 执行之间存在短暂的 UI 不一致窗口。
- 没有单元测试覆盖"TTS 加载中切换选中文本后 audioState 立即回到 idle"的路径。

**证据**
`ReadingDocumentStore.swift` 第 167–175 行（`selectSelection` 方法体）：无 `audioState = .idle`。
对比 `clearSelection()` 第 266–275 行和 `replaceDocument()` 第 177–190 行均包含 `audioState = .idle`。

**影响**
在切换选区时存在短暂的 audioState 不一致窗口（"听"按钮显示加载中，但 TTS 已被取消）。属于 UI 可见异常，不崩溃，概率较低但可复现。

**建议修改**
在 `selectSelection()` 方法中加入 `audioState = .idle`，并补充单元测试：TTS loading 状态下调用 `selectSelection` 后 `audioState` 立即为 `.idle`。

**是否阻塞实现**：否（已完成实现；建议回溯修复）

---

#### P2 — `playSelectionSentence()` 行为缺少专项单元测试

**问题**
方案修复了 `playSelectionSentence()` 的核心行为（`.textFragment` 播放选中词，`.sentence` 播放整句），并使用 fragment-specific cache key。但没有专项单元测试覆盖：
- `.textFragment` scope 下播放 `selectedText` 而非 `containingSentence`
- fragment sentenceID 使用 `-frag-<offset>` 格式，与 sentence sentenceID 不冲突

方案的 TDD Touchpoints 节写道"covered by existing test infrastructure"，但实际搜索测试目录中没有 `playSelectionSentence` 的调用。

**证据**
`grep -rn "playSelectionSentence"` 在 `Packages/LangoTraceUI/Tests` 中无结果。
方案 TDD Touchpoints 节（第 77 行）："ReadingDocumentStore TTS change is behavior on the store, covered by existing test infrastructure."——实为过度乐观声明。

**影响**
若后续有人修改 `playSelectionSentence` 逻辑（如调整 fragment key 格式或 scope 判断），无测试保护。

**建议修改**
在 `ReadingDocumentStoreAIAndTTSTests.swift` 中新增两个测试：
1. `.textFragment` scope 下 `playSelectionSentence` 发送 `selectedText` 给 TTS，sentenceID 包含 `-frag-` 标记
2. `.sentence` scope 下 `playSelectionSentence` 发送 `containingSentence` 给 TTS

**是否阻塞实现**：否（建议补充测试）

---

#### P2 — `NSAttributedString` 重建条件未追踪 `inlineRuns` 变化

**问题**
`ReadingSelectableTextView` 的 `needsRebuild` 条件只比较 `blockText` 和 `blockKind`（`ReadingSelectableTextView.swift` iOS 第 69–71 行，macOS 第 279–281 行），但不比较 `inlineRuns`。
若未来 inline 标注在不改变文字或 block 类型的情况下发生变化（例如同一段落经过重新分析后 inline runs 更新），`NSAttributedString` 不会被重建，视图停留在旧的渲染状态。
方案的 Risks 节提到了重建条件，但未说明 `inlineRuns` 的漏追踪。

**证据**
`ReadingSelectableTextView.swift` 第 69–81 行（iOS）和第 279–291 行（macOS）：`lastRenderedInlineRuns` 不存在。

**影响**
在当前阶段不影响正确性（inline runs 与 block text 绑定，text 不变时 runs 几乎不变）。但若引入动态 inline 标注（如"已解析词语下划线"），将出现视图不更新的缺陷。

**建议修改**
如后续功能（如阅读解析结果缓存与句子指示器）需要动态修改 inline runs，应同时追踪 `lastRenderedInlineRuns`。当前阶段可写入架构备忘录而不强制立即修复。

**是否阻塞实现**：否

---

#### P2 — macOS `NSTextView` 不更新 `height` binding，导致所有 selectable block 高度固定为 44pt

**问题**
`ReadingDocumentCanvas` 通过 `.frame(height: blockHeights[block.id, default: 44])` 控制 selectable block 高度，并将 `Binding<CGFloat>` 传给 `ReadingSelectableTextView`。iOS 的 `updateUIView` 在每次 `updateUIView` 调用时通过 `sizeThatFits` 更新该 binding（第 87–91 行）。macOS 的 `updateNSView` 完全没有对应的高度更新逻辑（第 275–296 行），导致 macOS 上所有 selectable block 高度永远为默认值 44pt，文字内容被裁切。

**证据**
`ReadingSelectableTextView.swift` macOS `updateNSView`（第 275–296 行）：无 `height` 赋值调用。
iOS `updateUIView`（第 87–91 行）：有 `sizeThatFits` + `DispatchQueue.main.async { self.height = size.height }` 路径。

**影响**
macOS 阅读页面中超过 44pt 高度的段落文字被截断，不可读。这是一个平台体验级缺陷。

**建议修改**
在 macOS `updateNSView` 中，当 `needsRebuild` 时（或每次 `applyCommittedHighlight` 后），通过 `nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)` + `nsView.frame` 或 `nsView.intrinsicContentSize` 计算高度并异步写入 binding。

**是否阻塞实现**：否（已完成实现，但 macOS 阅读视图存在可见布局缺陷，需后续修复）

---

#### P3 — 方案 Scope 与实现不一致：`ReadingAppearance.swift` 的 `.plain` 项为冗余说明

**问题**
方案 Scope 写明"Add `.plain` to `ReadingInlineRole`"（Core 部分）。但检查 `ReadingAppearance.swift`，`ReadingInlineRole` 早已包含 `.plain`（第 10–15 行）。实际修复在 `ReadingMarkdownBlockRenderer.swift` 的 `inlinePresentation` 函数中（将 `.plain` -> `.emphasis` 的错误映射改为 `.plain` -> `.plain`），Core 无需改动。
这是方案描述的不精确，不影响实现正确性。

**证据**
`ReadingAppearance.swift` 第 9–15 行：`ReadingInlineRole` 已有 `.plain` 成员。
方案 Scope 第 31 行："Add `.plain` to `ReadingInlineRole`"——实为误导性描述，实际变更在 Renderer 映射层。

**影响**：无功能影响，仅文档精确性问题。

**建议修改**：可在完成后将 Scope 说明修正为"Fix `.plain` → `.plain` mapping in `ReadingMarkdownBlockRenderer.inlinePresentation`；Core 层 `ReadingInlineRole` 无需改动"。

**是否阻塞实现**：否

---

#### P3 — 方案未包含自审核状态字段和严格方案自审核记录

**问题**
方案头部缺少 `自审核状态：` 字段，方案正文缺少"严格方案自审核记录"节。按照 `plan-review-protocol.md` 第 6 节，active plan 应包含该记录；方案在完成前也未执行自审核（此次为回溯性审查）。

**影响**：流程合规性问题，不影响功能。

**建议修改**：此次回溯审查完成后即补充本节内容（已完成）。

**是否阻塞实现**：否

---

### 写回修改（双轮完成）

以下内容均已写入本方案文档：

1. **方案头部** — 增加 `自审核状态: Reviewed`
2. **TDD Touchpoints** — 更正 `playSelectionSentence` 覆盖声明（移除"covered by existing test infrastructure"误导性说明），补充 `grammaticalNote` AI 服务测试落点要求
3. **Verification 命令** — 增加 `swift test --package-path Packages/LangoTraceAI --filter ReadingSelectionExplanation`
4. **Risks 节** — 补充 4 条 `[回溯发现]` 条目：grammaticalNote AI 服务层断点（P1）、`audioState = .failed` 不可达状态（P2）、macOS NSTextView height 未更新（P2）、`selectSelection()` 未重置 audioState（P2）
5. **自审核记录** — 更新审核方式为"两轮子代理隔离审查（回溯性）"

### 后续修复（post-review，2026-06-06 已完成）

以下回溯发现的问题在自审核后已全部修复：

| 严重度 | 问题 | 修复 |
|--------|------|------|
| P1 | `grammaticalNote` AI 服务层未更新（v1 → v2） | `ReadingSelectionExplanationService.swift` 升级至 v2，增加 `grammatical_note` 可空字段；AI 测试 fixture 同步更新；新增 `grammatical_note` 解析专项测试；Prompt 文档同步 v2 |
| P2 | `selectSelection()` 未重置 `audioState` | 加入 `audioState = .idle`；新增专项单元测试 `selectSelectionResetsAudioState` |
| P2 | `playSelectionSentence` 缺少单元测试 | 新增 `playSelectionSentencePlaysFragmentText` 和 `playSelectionSentencePlaysSentenceText` 两个测试 |
| P2 | `audioState = .failed` dead code（`isFailed` 参数不可达） | 从 `ReadingActionPill` 移除 `isFailed`/`failureTitleKey`/`failureSystemImage` 参数及相关分支；两处调用方同步清理 |
| P2 | macOS `NSTextView` 不更新 `height` binding | 在 macOS `updateNSView` 末尾加入 `layoutManager.ensureLayout` + `usedRect` 高度计算 |
| P3 | Prompt Registry 文档滞后 | `docs/prompts/reading/selection-explanation.md` 更新至 v2，补充 `grammatical_note` 字段说明和版本记录 |

剩余未修复（低优先级）：

- **P2（架构）**：`inlineRuns` 未被纳入 NSAttributedString 重建条件 — 已写入 `docs/architecture/notes/`，待动态 inline 标注需求确定时跟进。
- **P2**：`makeAttributedString` 可补充 NSAttributedString attribute 单元测试（attribute 断言）— 建议在后续 reading 测试补充轮中覆盖。

### 是否允许进入实现

方案全部完成，包含原始实现和回溯修复。无阻塞问题。
