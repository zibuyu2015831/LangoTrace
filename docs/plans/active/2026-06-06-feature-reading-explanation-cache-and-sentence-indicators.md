---
title: 阅读解析结果持久化缓存与已解析句子视觉标记
type: feature
status: active
created: 2026-06-06
updated: 2026-06-06
related_specs:
  - docs/spec/012-reading-learning-domain.md
  - docs/spec/007-data-storage-migration-export-and-attachments.md
related_adrs:
  - docs/decisions/005-local-first-and-user-owned-providers.md
---

# 阅读解析结果持久化缓存与已解析句子视觉标记

状态：Draft
自审核状态：Not Reviewed
类型：feature
创建日期：2026-06-06
最后更新日期：2026-06-06

## 1. 背景与动机

当前阅读学习面板在用户关闭后不保留解析结果——下次选中同一句子需要重新请求 AI，无法离线使用。同时阅读视图没有任何已解析句子的视觉标记，用户无法知道哪些句子已经被自己研究过。

用户场景：

1. 用户选中句子 S1 并完成解析，关闭面板继续阅读。
2. 稍后重新选中 S1 → 应直接恢复缓存结果，无需重发 AI 请求。
3. 用户处于离线状态，重新选中 S1 → 仍能看到之前的解析结果。
4. 解析结果过时或用户希望刷新 → 支持"重新生成"。
5. 用户之前解析了 S1，后来选中了包含 S1 的更大片段 F → F 是新的选区，视为独立请求；但视图中 S1 的已解析下划线标记依然可见，面板内可提示"该选区包含已解析句子"。

## 2. 设计决策

### 2.1 缓存键

使用 `ReadingSelectionContext.sourceAnchorID` 作为主查找键。`sourceAnchorID` 已编码文档 ID、内容版本、结构版本、block、字符范围和文本哈希，是天然的精确匹配键。

缓存命中条件：`sourceAnchorID` 完全一致。

含义：
- 句子 S1 解析后，选中包含 S1 的更大片段 F → `sourceAnchorID` 不同 → 缓存未命中 → 触发新请求。
- 视觉标记独立于缓存命中：已解析句子集合（`explainedSentenceIDs`）按 `sentenceID` 索引，涵盖所有已缓存条目的 `sentenceID` 字段。

### 2.2 失效策略

`contentRevision` 变化（文档编辑保存）后旧缓存条目自动失效，不删除，按需 prune：

- 文档打开时：调用 `pruneStale(documentID:currentContentRevision:)` 清理旧版本条目。
- 语言空间切换或文档关闭时：内存索引（`explainedSentenceIDs`、`explanationCache`）随 store 状态清空。

### 2.3 选区重叠提示

当用户选中的片段 F 的 `sentenceID`（即 `containingSentence` 对应的 sentenceID）已在 `explainedSentenceIDs` 中，且当前 F 的 `sourceAnchorID` 不在缓存中时，面板展示一条提示链接"包含已解析句子 · 查看"。点击后展示对应句子的缓存结果（按 `sentenceID` 查询缓存）。

此提示不阻塞主流程，用户仍可直接点击"解释"获取新的片段级解析。

### 2.4 持久化 vs 仅内存缓存

采用 **GRDB 持久化**（不仅是内存缓存），支持：
- 离线恢复（App 重启后仍可读到历史解析）
- 未来"学习记录"功能复用（已解析历史）

`ReadingSelectionExplanationResult` 以 JSON 存储在 `result_json` 列，反序列化失败降级为缓存未命中（触发重新解析）。

内存中同时维护 `[String: ReadingSelectionExplanationResult]`（键为 `sourceAnchorID`）和 `Set<String>`（已解析 `sentenceID`），避免文档打开期间的重复查询。

### 2.5 "重新生成"操作

当面板显示缓存结果时，面板头部或操作区展示"重新生成"按钮。操作：
1. 删除当前 `sourceAnchorID` 对应的 DB 条目。
2. 从内存缓存移除。
3. 触发 AI 请求（状态切换至 `.loading`）。
4. 成功后写入新缓存条目，更新内存。

`explainedSentenceIDs` 中的 `sentenceID` 不在此时移除（因为该句子仍会有新结果进来）；仅在 DB 写入失败或 AI 请求取消时，`sentenceID` 才需要从集合中移除。

## 3. 落点汇总

### 3.1 数据层（LangoTraceData）

**迁移 v14：`v14_create_reading_explanation_cache`**

```sql
CREATE TABLE reading_explanation_cache (
  id                TEXT    PRIMARY KEY,
  document_id       TEXT    NOT NULL REFERENCES reading_documents(id) ON DELETE CASCADE,
  space_id          TEXT    NOT NULL,
  content_revision  INTEGER NOT NULL,
  structure_version INTEGER NOT NULL,
  selection_scope   TEXT    NOT NULL,   -- 'sentence' | 'text_fragment'
  source_anchor_id  TEXT    NOT NULL,
  sentence_id       TEXT    NOT NULL,   -- 含义：包含该选区的句子 ID，始终非空（text_fragment 也记录其 containingSentence）
  block_id          TEXT    NOT NULL,
  char_offset       INTEGER NOT NULL,
  char_length       INTEGER NOT NULL,
  selected_text     TEXT    NOT NULL,
  selected_text_hash TEXT   NOT NULL,
  result_json       TEXT    NOT NULL,
  provider_id       TEXT,
  model_id          TEXT,
  created_at        TEXT    NOT NULL,
  updated_at        TEXT    NOT NULL
);
CREATE UNIQUE INDEX idx_rec_source_anchor ON reading_explanation_cache(document_id, source_anchor_id);
CREATE INDEX idx_rec_sentence ON reading_explanation_cache(document_id, content_revision, sentence_id);
```

**新增类型：`ReadingExplanationCacheRecord`**（`LangoTraceData`，FetchableRecord + PersistableRecord）

**新增 Repository：`GRDBReadingExplanationCacheRepository`**（注入 `AppDatabase`）

协议接口（`LangoTraceCore` 定义协议，`LangoTraceData` 提供实现）：

```swift
public protocol ReadingExplanationCacheRepositoryProtocol: Sendable {
    func insert(_ entry: ReadingExplanationCacheEntry) async throws
    func lookup(documentID: String, sourceAnchorID: String) async throws -> ReadingExplanationCacheEntry?
    func lookupBySentenceID(documentID: String, contentRevision: Int, sentenceID: String) async throws -> ReadingExplanationCacheEntry?
    func loadExplainedSentenceIDs(documentID: String, contentRevision: Int) async throws -> Set<String>
    func delete(id: String) async throws
    func pruneStale(documentID: String, currentContentRevision: Int) async throws
}
```

**新增 Core 类型：`ReadingExplanationCacheEntry`**（`LangoTraceCore`，Codable + Sendable）

### 3.2 AI 服务层（LangoTraceAI / LangoTraceUI）

`ReadingSelectionExplanationService.explain(input:)` 不改变现有接口。缓存命中判断在调用方（`ReadingDocumentStore`）完成，服务层保持无状态。

### 3.3 Store 层（LangoTraceUI）

`ReadingDocumentStore` 新增：

```swift
// 内存索引，文档打开时从 DB 加载
private(set) var explainedSentenceIDs: Set<String> = []
private var explanationCache: [String: ReadingExplanationCacheEntry] = [:]

// 新增操作
func restoreExplanationIfCached(for context: ReadingSelectionContext) -> ReadingExplanationCacheEntry?
func regenerateExplanation(for context: ReadingSelectionContext) async
```

`explainSelection(context:)` 流程变更：

1. 查 `explanationCache[context.sourceAnchorID]`。
2. 命中 → 直接发布结果，状态设为 `.loaded(result, source: .cache)`。
3. 未命中 → 触发 AI 请求，成功后：
   a. 调用 `cacheRepository.insert(entry)` 写入 DB。
   b. 更新 `explanationCache` 和 `explainedSentenceIDs`。
4. 文档打开时调用 `pruneStale` 并加载 `explainedSentenceIDs`、初始化内存缓存。

`ReadingAsyncState` 扩展（或新增关联值）：

```swift
// 当前状态的来源标记
enum ExplanationSource: Equatable {
    case fresh     // 本次 AI 请求返回
    case cache     // 从 DB / 内存缓存恢复
}
```

`ReadingDocumentStore` 需要将 `source` 传递给 UI，以便展示"重新生成"按钮。

### 3.4 UI 层（LangoTraceUI）

**`ReadingSelectableTextView`（iOS）**

新增参数：`explainedSentenceRanges: [NSRange]`

渲染时在 `NSAttributedString` 中对已解析句子范围叠加：
- `NSUnderlineStyleAttributeName: NSUnderlineStyle.patternDot.rawValue`
- `NSUnderlineColorAttributeName: LangoTraceDesign.ColorToken.accent.withAlphaComponent(0.5)`（传入 UIColor）

注意：该 attribute 不干扰选区高亮（NSTextView 选区 highlight 是系统层覆盖，不受自定义 underline 影响）。更新时机：`explainedSentenceIDs` 变化时重新计算并调用 `textView.setNeedsDisplay()` 或直接更新 attributed string。

需要接收 `precomputedSentences: [ReadingSentence]` 以计算每个 sentenceID 对应的 `NSRange`（已有，只需在 coordinator 中增加 attribute 写回）。

**`ReadingInspectorPane` / `ReadingCompactLearningPanel`**

1. 当 `explanationSource == .cache` 时，在面板头部 scope 标签旁展示"已缓存"（`bookmark.fill`，`textSecondary` 色，`caption2`）。
2. 操作区新增"重新生成"按钮（文字："重新生成"，系统图标：`arrow.clockwise`，`bordered` 样式，放在"解释"按钮之后）。仅在 `explanationSource == .cache` 时可见。
3. 片段选区重叠提示：当 `selectionScope == .textFragment` 且 `containingSentenceID ∈ explainedSentenceIDs` 且当前 `sourceAnchorID` 未命中缓存时，面板底部展示一个提示行（`info.circle`，`textSecondary`，`caption`）："该选区包含已解析句子 · 查看"。点击后切换面板内容到对应句子的缓存结果，同时内存中加载该 `ReadingExplanationCacheEntry`（按 `sentenceID` 查询 DB）。

**新增本地化 key：**

- `reading.explanation.source.cached`：en="Cached" / zh-Hans="已缓存"
- `reading.explanation.regenerate`：en="Regenerate" / zh-Hans="重新生成"
- `reading.explanation.contains.explained.sentence`：en="Contains an explained sentence · View" / zh-Hans="该选区包含已解析句子 · 查看"

## 4. TDD 落点

### 4.1 先失败的行为用例

**`ReadingExplanationCacheRepositoryTests`（LangoTraceData）**

- 插入一条缓存条目后，按 `sourceAnchorID` 精确查询可命中。
- 按不同 `sourceAnchorID` 查询返回 nil。
- `pruneStale` 删除旧 `contentRevision` 的条目，保留当前版本。
- `loadExplainedSentenceIDs` 返回当前版本所有 `sentenceID` 去重集合。
- 按 `sentenceID` 查询：存在返回最新条目，不存在返回 nil。
- ON DELETE CASCADE：关联 `reading_document` 删除后条目自动清理（需要测试框架支持外键）。

**`ReadingDocumentStoreExplanationCacheTests`（LangoTraceUI）**

- 解析完成后，重新选中同一选区 → store 立即发布 `.loaded(result, source: .cache)`，不触发 AI 请求。
- 内容版本变化后，旧缓存失效（pruneStale 被调用）→ 重新选中触发新 AI 请求。
- `regenerateExplanation` 调用后，对应 DB 条目被删除，再次触发 AI 请求。
- `explainedSentenceIDs` 在首次解析完成后包含对应 `sentenceID`。
- 片段选区 F 的 `containingSentenceID` 在 `explainedSentenceIDs` 中 → `overlappingExplainedSentence` 计算属性非 nil。

### 4.2 跳过自动化的原因

- `ReadingSelectableTextView` 的 underline attribute 渲染是 UITextView 视觉效果，无法用单元测试验证；通过模拟器手动验证。
- "已缓存"标签和片段重叠提示行的布局通过模拟器手动验证。

### 4.3 聚焦验证命令

```bash
swift test --package-path Packages/LangoTraceData --filter ReadingExplanationCacheRepositoryTests
swift test --package-path Packages/LangoTraceUI --filter ReadingDocumentStoreExplanationCacheTests
```

### 4.4 完整验证命令

```bash
scripts/verify.sh
```

## 5. 实现顺序

1. **Core 类型**：`ReadingExplanationCacheEntry`、`ReadingExplanationCacheRepositoryProtocol`（LangoTraceCore）。
2. **DB 迁移**：`v14_create_reading_explanation_cache`（LangoTraceData）。
3. **DB Record + Repository**：`ReadingExplanationCacheRecord`、`GRDBReadingExplanationCacheRepository`（LangoTraceData）；同步写 `ReadingExplanationCacheRepositoryTests`。
4. **Store 层**：`ReadingDocumentStore` 增加缓存查询、写入、`explainedSentenceIDs`、重叠检测和 `regenerateExplanation`；同步写 `ReadingDocumentStoreExplanationCacheTests`。
5. **UI 层**：
   - `ReadingSelectableTextView`：接收 `explainedSentenceRanges`，写入 underline attributes。
   - `ReadingInspectorPane` / `ReadingCompactLearningPanel`：添加"已缓存"标签、"重新生成"按钮、片段重叠提示行。
   - 新增本地化 key。
6. **AppEnvironment 注入**：将 `GRDBReadingExplanationCacheRepository` 接入 `AppEnvironment`，传入 `ReadingDocumentStore`。
7. **spec 012 变更日志更新**。

## 6. 自审核确认

### 6.1 与现有决策的一致性

- ✅ 持久化到 GRDB，符合 ADR 011（SQLite / GRDB 作为长期主存储）。
- ✅ AI 解析结果属于用户显式触发产生的派生内容，不自动发送，符合 spec 012 §6 和 ADR-005。
- ✅ `sourceAnchorID` 绑定 `contentRevision`，符合 spec 012 §5 的锚点失效规则。
- ✅ ON DELETE CASCADE 确保文档删除后解析缓存自动清理，符合 spec 007 的附件/派生数据生命周期。

### 6.2 边界与范围限制

- 本任务不实现"学习记录全局历史"或"解析结果跨文档检索"，只做文档内恢复和视觉标记。
- 本任务不实现文档关闭后主动预加载所有句子的 TTS，TTS 缓存路径不变。
- `result_json` 反序列化失败降级为缓存未命中，不崩溃，不弹错误。
- "重新生成"和普通"解释"共用同一个 `ReadingSelectionExplanationService`，不引入新请求路径。

### 6.3 剩余风险

- `sentence_id` 在 `text_fragment` 选区下来自 `containingSentence`；若句子分割结果在两次文档打开间产生差异（例如 segmenter 更新），`sentenceID` 可能不稳定 → 已有 `contentRevision + structureVersion` 双重约束，风险可控。
- 内存缓存 `[String: ReadingExplanationCacheEntry]` 无上限；对于句子数极多的长文档，可能占用较多内存 → 本阶段不加 LRU，记入架构备忘录供后续处理。

## 7. 文档影响

完成后需更新：

- `docs/spec/012-reading-learning-domain.md` 变更日志（新增缓存和视觉标记事实）。
- 本 plan 移入 `docs/plans/done/`。
