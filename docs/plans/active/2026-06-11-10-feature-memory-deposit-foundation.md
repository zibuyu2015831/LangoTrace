# 任务方案：记忆沉淀基础（memory_items 主数据与三端只读沉淀列表）（E7）

状态：Draft
自审核状态：Reviewed
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-17

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（[2026-06-11-chore-code-review-and-dev-plan-series.md](2026-06-11-chore-code-review-and-dev-plan-series.md)）。该授权仅覆盖"方案文档创建"；本方案进入实现前仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

## 1. 需求或 bug 描述

按新版三端原型（`prototypes/iphone/memory.html`、`prototypes/ipad/memory.html`、`prototypes/mac/memory.html`），记忆 Tab 的目标体验是"从生活沉淀的词句 / 整句"列表：每条记忆有目标语言文本、母语释义、类型（词句 / 整句）、来源记录回链和沉淀日期。本任务建立记忆沉淀的第一阶段闭环：

1. `memory_items` 用户主数据表与 GRDB migration。
2. 用户显式触发的 `加入记忆` 动作 seam，三端共享（记录详情 inspector、阅读 inspector、面板组件）。
3. 三端只读沉淀列表：iPhone 列表、iPad 网格、macOS 四列表格 + 词句详情 Inspector。
4. 沉淀项到来源记录的回链导航。
5. 为 E1 时间线的 `已沉淀` 筛选提供真实数据投影。

核心语义约束：candidate（AI 分析产出的 memory candidate）不等于 deposited（用户显式确认沉淀）。沉淀必须是用户动作的结果，确认语义要清晰可见。

## 2. 现状描述

以下事实已对照当前代码（2026-06-11 HEAD，含当日修复波次）核实：

- 三端记忆页面均为 Local Mock 投影，不是用户主数据：
  - iPhone：`MemoryView`（`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`）渲染 `contentStore` 提供的 `[MemoryItem]`，但该 `MemoryItem` 是 `GRDBLearningContentRepository.memoryItems(for:)` 从 `memory_candidates` 派生的投影（candidate，不是 deposited 主数据）。
  - iPad / macOS：`MemoryLayerSummaryView`（`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`）只渲染计数摘要行，状态硬编码 `.mockOnly` / `.unavailable`；由 `PadMainSections.swift` 与 `MacWorkspaceContentView.swift` 使用。
- `memory_candidates` 已在 GRDB learning content 主路径中持久化（`v4_create_learning_content_infrastructure` migration，`Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`），`status` CHECK 当前只允许 `'candidate'`；写入发生在 `GRDBLearningContentRepository.replaceAnalysisRows()`。
- `MemoryItem`（`Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`，字段 `id` / `spaceID` / `entryID` / `text` / `note`）目前是 candidate 投影类型，不携带 kind、来源材料、沉淀时间或复习状态。
- 全仓库不存在 `memory_items` 表、`加入记忆` 动作或 deposit 语义代码。
- **E1 完成后状态（2026-06-17）**：`PadFilter` enum 已在 E1（`docs/plans/done/2026-06-11-03-feature-record-timeline-and-filters.md`）中删除。三端筛选现为 `EntryTimelineFilter`（`Packages/LangoTraceUI/Sources/LangoTraceUI/EntryTimeline.swift`）。`EntryTimelineFilter.settled.includes(_:hasMaterialWithoutRecording:)` 当前始终返回 `false`，`FilterChipRow` 和 `PadSidebarView.visibleFilters` 通过 `.filter { $0 != .settled }` guard 隐藏 `已沉淀` chip，等待本任务填充真实判定逻辑。
- 当前 migration 头部为 `v15_reset_reading_explanation_cache_for_unix_epoch`；本任务新增 migration 使用下一可用编号（按当前 HEAD 为 v16；若实施时已有其他 migration 落地则顺延，编号以实施时 `AppDatabase.swift` 为准）。

## 3. 目标

1. `memory_items` 作为用户主数据表落地，含 migration、record type、`MemoryItemRepository` 协议与 GRDB 实现、迁移测试。
2. schema 一次性包含 E8 复习字段（dependency contract，见第 12 节），避免 E8 二次 migration。
3. 三端共享 `MemoryDepositActions` seam：从 memory candidate 或阅读选区显式沉淀一条记忆；重复沉淀幂等。
4. iPhone 列表 / iPad 网格 / macOS 四列表格 + Inspector 的只读沉淀列表，按 `space_id` 隔离，数据来自真实 repository。
5. 来源回链：沉淀项可导航回来源 Entry 详情或阅读文档；来源被删除时显示降级状态而不是崩溃或空导航。
6. 移除 `FilterChipRow` 和 `PadSidebarView.visibleFilters` 中的 `settled` chip guard，并将 `EntryTimelineFilter.settled.includes(entry:hasMaterialWithoutRecording:)` 替换为基于 `depositedEntryIDs(spaceID:)` 的真实判定，使 `已沉淀` chip 正式对用户可见。
7. UI 全程不出现向量索引、embedding、检索基础设施等工程概念。

## 4. 范围

- `Packages/LangoTraceData`：migration、`MemoryItemRecord`、`MemoryItemRepository` 协议 + GRDB 实现、查询（按空间、按来源、按 kind）、deposit 写入、软删除。
- `Packages/LangoTraceCore`：`MemoryItem` 主数据模型（取代当前 Data 层 candidate 投影命名，见第 12 节命名迁移）、`MemoryItemKind`、`MemoryItemSource`、deposit 输入模型。
- `Packages/LangoTraceUI`：三端记忆页面改造、`加入记忆` 动作入口（记录详情 / 阅读 inspector）、`MemoryDepositActions` seam、来源回链路由、`PadFilter.memorized` 改造。
- `LangoTraceApp/AppEnvironment.swift`：repository 与 actions 装配。
- 文档：`docs/spec/007` 学习内容章节事实更新、`docs/platform-page-inventory.md` 记忆页面状态更新。

## 5. 不做什么

- 不实现复习队列、间隔调度、`已掌握` 状态机和复习统计（E8：[2026-06-11-11-feature-memory-review-queue.md](2026-06-11-11-feature-memory-review-queue.md)）；本任务只在 schema 中预留字段并写入初始值。
- 不实现任何向量表、embedding、语义检索或相似召回（核心决策 12 与 embedding 备忘录红线）。
- 不实现记忆项的全文搜索（E9 负责）。
- 不实现记忆项编辑、批量管理、主题聚合（iPad 原型左栏"常见主题"为后续能力）和词典交叉能力。
- 不把 `memory_candidates` 改造成主数据或迁移其历史行；candidate 仍是派生数据。
- 不实现记忆项的同步与导出（E10 / E11 负责，本任务只保证 schema 可被其消费）。

## 6. 证据与决策依据

- 原型证据：`prototypes/iphone/memory.html`（列表行：目标文本 / 母语释义 / `来自 · 记录标题` / 词句·整句 pill）、`prototypes/ipad/memory.html`（双列网格 + 左栏类型筛选）、`prototypes/mac/memory.html`（四列表格：英文词句 / 中文释义 / 来源记录 / 沉淀日期 + Inspector 详情与来源链接）。三页均标注"目标设计 / 当前实现为 Local Mock"。
- 代码证据：见第 2 节逐条核实结果。
- 备忘录采纳说明（按 `docs/architecture/notes/README.md` 读取规则）：
  - [2026-06-11-prototype-target-design-extension-notes.md](../../architecture/notes/2026-06-11-prototype-target-design-extension-notes.md) §2.2：采纳"第一步做只读沉淀列表"和"不暴露向量 / embedding 概念"；采纳"沉淀项与原始记录的回链导航"为本任务范围；"三层记忆呈现层级"暂不采纳（本任务只呈现沉淀列表，不做层级聚合）。
  - [2026-05-27-embedding-infrastructure-notes.md](../../architecture/notes/2026-05-27-embedding-infrastructure-notes.md)：采纳为红线——本任务不创建向量表、不为用户内容生成 embedding；`memory_items` 删除语义须满足"派生向量必须可删除"的未来前提（保留稳定 id 与软删除时间）。
  - [2026-05-25-dictionary-feature-extension-notes.md](../../architecture/notes/2026-05-25-dictionary-feature-extension-notes.md)：暂不采纳词典交叉能力，记入剩余风险。
- workflow 引用：本任务属于数据迁移 + 平台页面双高风险动作，遵循 [add-storage-migration.md](../../workflows/add-storage-migration.md)（migration id、事务边界、生命周期分层判断、测试矩阵）与 [add-platform-screen.md](../../workflows/add-platform-screen.md)（三端共享 seam、页面清单同步）。无偏离。
- spec 证据：`docs/spec/007` §3.1.1 已把未来 `MemoryItem` 列为用户主数据并要求完整生命周期评估；§5 要求"练习结果和记忆提取应保留来源引用"。

```text
证据能证明什么：原型固定了沉淀列表的字段集合（目标文本/释义/类型/来源/日期）与三端形态；代码证明 candidate 数据可作为沉淀输入。
证据不能证明什么：原型不能证明复习调度、主题聚合或搜索已被授权；candidate 投影不能证明沉淀语义已存在。
迁移前提：migration 编号以实施时 AppDatabase.swift 为准（E1 未新增 migration，当前仍为 v16）；`settled` chip guard 移除前提是 `memory_items` 查询已可用。
照搬风险：直接把原型 mock 字段照搬为 schema 会漏掉来源引用完整性、软删除与 E8 复习字段；已在 schema 设计中补足。
```

## 7. 约束映射与验证路径

### 约束 1：用户主数据完整生命周期

- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md` §3.1.1、§4
- 适用范围：`memory_items` schema 与 repository
- 严重度：blocker
- 执行或验证方式：单元测试 + 方案内生命周期表（第 12 节）
- 验证提示：Create（deposit）、Read（列表 / 详情 / 按来源查询）、Update（本阶段仅复习字段预留，正文编辑显式暂缓并记录）、Delete（软删除）各有测试。
- 说明：`MemoryItem` 被 spec 007 明确列为用户主数据。

### 约束 2：派生数据与主数据分离

- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md` §3.1.2
- 适用范围：`memory_candidates` 与 `memory_items` 的关系
- 严重度：blocker
- 执行或验证方式：单元测试
- 验证提示：删除 current material 或 Entry 后，已沉淀 `memory_items` 仍可读（快照语义）；candidate 查询行为不变。
- 说明：candidate 是派生数据，deposit 后的记忆项必须脱离派生生命周期。

### 约束 3：不暴露向量 / embedding 概念

- 来源：`docs/README.md` 核心决策 12、`docs/architecture/notes/2026-05-27-embedding-infrastructure-notes.md`、`docs/spec/003-ui-design-system.md` §4.14
- 适用范围：全部 UI 文案与本地化 key
- 严重度：blocker
- 执行或验证方式：本地化 key 单元测试 + 人工审查
- 验证提示：`rg -i "embedding|vector|向量" Packages/LangoTraceUI/Sources` 无用户可见文案命中。

### 约束 4：migration 可重复验证

- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md` §4、`docs/workflows/add-storage-migration.md` §4
- 适用范围：新 migration
- 严重度：blocker
- 执行或验证方式：migration 单元测试（空库迁移、自 v15 旧库迁移、重复 migrator）
- 验证提示：复用 `AppDatabaseTests` 既有 migration 测试模式。

### 约束 5：三端共享 seam 与平台分别设计

- 来源：`docs/README.md` 核心决策 2、`docs/spec/004-swiftui-architecture.md`、`docs/workflows/add-platform-screen.md`
- 适用范围：`MemoryDepositActions` 与三端页面
- 严重度：warn
- 执行或验证方式：UI 单元测试 + 人工审查
- 验证提示：动作与投影逻辑在共享层，三端仅差呈现容器。

### 约束 6：界面语言边界

- 来源：`docs/spec/006-interface-localization-and-language-boundaries.md`
- 适用范围：目标文本 / 母语释义的显示通道
- 严重度：warn
- 执行或验证方式：presentation model 单元测试
- 验证提示：目标语言文本走 target-language 通道，释义走母语通道，界面框架文案走本地化 key。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/MemoryItem.swift`（新增：主数据模型、kind、source、deposit 输入）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（新增 migration）
- `Packages/LangoTraceData/Sources/LangoTraceData/MemoryItemRepository.swift`（新增协议）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMemoryItemRepository.swift`（新增实现）
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`（candidate 投影类型更名，见第 12 节）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`（candidate 投影查询调整）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`、`PadMainSections.swift`、`MacWorkspaceContentView.swift`、`LearningContentComponents.swift`（三端记忆页面）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryTimeline.swift`（移除 `settled` guard，填充真实判定逻辑）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`、`PadMainSections.swift`（移除 `visibleFilters` 中的 `settled` guard）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MemoryDepositActions.swift`（新增 seam）
- 记录详情 / 阅读 inspector 对应视图文件（`加入记忆` 入口）
- `LangoTraceApp/AppEnvironment.swift`（装配）
- 对应 `Tests` 目录新增测试（见第 15 节）

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/PracticeRepository.swift` 与 `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift`（actions seam 与 route seed 既有模式）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabaseReadingMigration.swift`（扩展表与 CHECK 模式）
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBLearningContentRepositoryTests.swift`（测试 fixture 模式）

## 10. 涉及的文档路径

- 本方案。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（实施后补充 memory_items 落地事实）
- `docs/platform-page-inventory.md`（三端记忆页面状态从 Local Mock 更新）
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`（只读，采纳说明见第 6 节）
- 前序依赖方案：`docs/plans/done/2026-06-11-03-feature-record-timeline-and-filters.md`（E1，已完成；`EntryTimelineFilter.settled` guard 等待本任务移除）、`docs/plans/active/2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md`（E2，推荐先行）

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### 12.1 schema 设计（含 E8 dependency contract）

新 migration `v16_create_memory_item_infrastructure`（编号实施时顺延核对）：

```sql
CREATE TABLE memory_items (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES language_spaces(id),
  kind TEXT NOT NULL,                 -- CHECK ('wordPhrase','sentence')，对应 UI 词句 / 整句
  target_text TEXT NOT NULL,          -- 目标语言文本快照
  native_text TEXT NOT NULL,          -- 母语释义快照
  context_sentence TEXT,              -- 可选：来源句子快照（mac Inspector 的 sentence-note）
  source_kind TEXT NOT NULL,          -- CHECK ('entry','reading')
  source_entry_id TEXT,               -- 软引用，不加 FK 级联删除
  source_material_id TEXT,
  source_sentence_id TEXT,
  source_reading_document_id TEXT,
  source_candidate_id TEXT,           -- 幂等去重键之一
  source_title_snapshot TEXT NOT NULL,-- 来源标题快照，来源删除后仍可显示"来自 · X"
  review_state TEXT NOT NULL,         -- E8 contract：CHECK ('new','scheduled','mastered')，本任务一律写 'new'
  review_rung INTEGER NOT NULL,       -- E8 contract：固定间隔阶梯档位，本任务写 0
  review_due_at REAL,                 -- E8 contract：本任务写 NULL
  last_reviewed_at REAL,              -- E8 contract：本任务写 NULL
  review_count INTEGER NOT NULL,      -- E8 contract：本任务写 0
  mastered_at REAL,                   -- E8 contract：本任务写 NULL
  deposited_at REAL NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  deleted_at REAL
);
CREATE INDEX idx_memory_items_space ON memory_items(space_id, deleted_at, deposited_at);
CREATE UNIQUE INDEX idx_memory_items_candidate_dedupe
  ON memory_items(space_id, source_candidate_id) WHERE source_candidate_id IS NOT NULL AND deleted_at IS NULL;
```

dependency contract（与 E8 协调）：上述 6 个 review 字段由本 migration 一次建好，E8 不再新增 migration，只新增查询、调度逻辑与状态写入。E8 方案的 schema 章节必须引用本节而不是自建表。

关键决策（Entry 删除与记忆项归属语义）：`memory_items` 是用户主数据，文本采用沉淀时快照；Entry / 阅读文档软删除或硬清理不级联删除记忆项。来源引用是软引用：回链导航前先解析来源是否 active，不可达时 UI 显示 `source_title_snapshot` + 来源不可用降级态。理由：沉淀是用户显式保存动作，其价值独立于来源记录的存续；这同时满足 spec 007"记忆提取应保留来源引用"与"删除主数据时必须定义派生与关联对象处理方式"。语言空间删除沿用空间级 soft delete + 子对象隐藏模型（active 查询按 `space_id` 排除）。

生命周期分层判断（workflow 要求）：`memory_items` = 用户主数据。Create = deposit 动作；Read = 三端列表 / 详情 / 来源反查；Update = 本阶段只允许 E8 复习字段更新，正文编辑显式暂缓（原因：原型未定义编辑入口，避免与来源快照语义冲突；后续入口为独立记忆管理方案）；Delete = 软删除（UI 本阶段提供移除入口仅在 mac Inspector 与 iPhone 行滑动中实现，若实施时间受限可整体暂缓并记录，见第 18 节模板）。

### 12.2 实施步骤

1. Core：新增 `MemoryItem` 主数据模型、`MemoryItemKind`、`MemoryItemSourceReference`、`MemoryDepositInput`。将 Data 层现有 candidate 投影类型 `MemoryItem` 更名为 `MemoryCandidatePreview`，消除命名冲突（早期重构原则允许，调用点一并修改）。
2. Data：先写失败的 migration 与 repository 测试，再实现 migration、`MemoryItemRecord`、`MemoryItemRepository`（`deposit`、`listMemoryItems(spaceID:)`、`memoryItem(id:)`、`memoryItems(forEntryID:)`、`softDelete`、`depositedEntryIDs(spaceID:)`）。deposit 在单写事务内校验 candidate / 阅读选区输入并写入快照；按 dedupe 索引幂等（重复 deposit 返回已有项，不报错）。
3. UI seam：`MemoryDepositActions`（deposit、列表加载、来源解析），由 `AppEnvironment` 装配真实实现，测试用内存替身。记录详情 inspector 的 memory candidate 区与阅读 inspector 增加 `加入记忆` 按钮：未沉淀显示动作态，已沉淀显示 `已加入记忆` 完成态（确认语义清晰，二次点击不重复写入）。
4. 三端列表：iPhone `MemoryView` 改为真实沉淀列表（目标文本 / 释义 / 来源 / kind pill）；iPad 记忆区改双列网格 + 左栏 kind 筛选（全部 / 词句 / 整句，`已掌握` 项显示但在 E8 前为空集）；macOS 改四列表格 + Inspector（词句详情、`听` 复用 `SentenceAudioPlaybackActions` 现有 seam 仅当来源句可解析时启用、来源链接）。移除 `MemoryLayerSummaryView` 的 mock 计数摘要用法。
5. 回链导航：iPhone push 到 Entry 详情；iPad / macOS 切换到对应 route 并选中来源；来源不可达走降级态。复用各平台既有 route 类型，不新建并行导航栈。
6. 筛选接线：移除三端 `visibleFilters` 中的 `settled` chip guard；将 `EntryTimelineFilter.settled.includes(entry:hasMaterialWithoutRecording:)` 替换为基于 `depositedEntryIDs(spaceID:)` 的真实判定；`needsPractice` 语义不在本任务修改。
7. 文档同步与验证收口。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：本系列方案由主方案阶段 3 统一授权创建，当前会话为方案撰写会话，无独立子代理审查环境可对未落盘草稿做只读审查；按协议第 3 节改为主会话双轮自审核并记录。
发现摘要：
  第一轮（架构）：
  - P1：初稿把 deposit 来源限定为 memory candidate，遗漏原型与备忘录中阅读 inspector 的沉淀入口 → 已加入 source_kind='reading' 路径与 source_reading_document_id。
  - P1：初稿未定义 Entry 删除后的记忆项归属语义（任务要求的显式决策）→ 已在 12.1 写明快照 + 软引用 + 降级态决策。
  - P1：Data 层既有类型 MemoryItem 与新主数据模型重名会造成双语义混淆 → 已加入更名步骤（MemoryCandidatePreview）。
  - P2：重复沉淀同一 candidate 的幂等性未定义 → 已加入 partial unique index 与幂等返回语义。
  - P2：E8 字段若不进本 migration 会造成二次 migration → 已按系列约定写入 dependency contract。
  第二轮（测试 / 安全 / 落地）：
  - P1：先失败测试初稿只覆盖 repository，未覆盖"candidate 投影与 deposited 主数据分离"的语义回归 → 测试落点补充 `EntryTimelineFilter.settled` 接线 / 投影测试。
  - P2：UI 文案红线（向量/embedding）缺少机械验证方式 → 约束 3 补充 rg 验证提示。
  - P2：来源句 `听` 按钮可能在来源删除后触发空播放 → 12.2 第 4 步限定仅来源句可解析时启用。
写回修改：以上各条均已写回第 6、7、12、15 节。
仍需用户确认的问题：
  1. 软删除（移除记忆）入口是否纳入本任务首版 UI（schema 与 repository 均已含软删除；仅 UI 入口可暂缓）。
  2. Data 层 candidate 投影类型更名涉及多个调用点，确认接受该重构范围。
是否允许进入实现：待用户确认后允许。
```

## 14. 复查方法

- 代码：migration 测试、repository 测试、UI 投影测试全绿；`rg "memory_items" Packages/LangoTraceData` 命中 migration 与 repository。
- 行为：模拟器中显式点击 `加入记忆` 后记忆 Tab 出现该项；未点击的 candidate 不出现；删除来源 Entry 后记忆项仍在且来源显示降级态；切换语言空间后列表隔离。
- 故障路径：deposit 时数据库写失败返回可诊断错误且无半写入；重复点击幂等；candidate 已被 reanalysis 替换后 deposit 输入失效时给出用户可见错误而不是静默成功；来源不可达导航降级。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Memory/GRDBMemoryItemRepositoryTests.swift（新增，功能子目录 Memory/）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Memory/AppDatabaseMemoryMigrationTests.swift（新增）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Memory/MemoryDepositActionsTests.swift（新增）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Memory/MemoryListProjectionTests.swift（新增，含 `EntryTimelineFilter.settled` 真实投影回归 + settled chip guard 移除验证）
先失败用例：GRDBMemoryItemRepositoryTests.depositFromCandidateCreatesMemoryItemWithSnapshot —— 预期失败原因：memory_items 表与 MemoryItemRepository 尚不存在，编译失败 / 表缺失。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceData --filter GRDBMemoryItemRepositoryTests
  swift test --package-path Packages/LangoTraceData --filter AppDatabaseMemoryMigrationTests
  swift test --package-path Packages/LangoTraceUI --filter Memory
不新增单元测试的原因（如适用）：不适用，本任务全程 TDD。
```

## 16. 验证命令

```bash
# 聚焦
swift test --package-path Packages/LangoTraceData --filter Memory
swift test --package-path Packages/LangoTraceUI --filter Memory

# 受影响 package 完整
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
```

涉及数据库 schema 变化，收口前按 CLAUDE.md 1.4 节第 7 条与用户确认是否补跑 `scripts/verify.sh`（默认不主动运行，记录为待 macOS 环境收口项）。

## 17. 文档影响检查

- `docs/spec/007`：需补充 memory_items 主数据落地事实与生命周期（实施后）。
- `docs/platform-page-inventory.md`：三端记忆页面状态、能力边界与代码路径更新（实施后）。
- ADR：不需要新增；沿用本地优先与 SQLite / GRDB 决策。
- review：数据库 schema 变化命中专项审查触发条件，实施后按 `docs/review/README.md` 创建 round 或在本方案记录跳过原因。
- `docs/spec/learning-content/impl.md`：candidate 投影类型更名后同步实现地图。

## 18. 实施记录

**2026-06-17（E1 完成后状态更新）**：E1 时间线与筛选方案已完成。`PadFilter` enum 已删除；三端筛选统一为 `EntryTimelineFilter`；`settled` chip 通过 `visibleFilters.filter { $0 != .settled }` guard 隐藏，等待本任务（E7）落地后移除。本方案 §2、§3、§4、§6、§8、§10、§12.2 step 6、§15 已同步更新，移除所有对已不存在的 `PadFilter.memorized` 的引用。当前 migration 头部为 v16（E1 未新增 migration）；本任务 `memory_items` migration 编号以实施时 AppDatabase.swift 为准。本方案仍处于 Draft 状态，实施前需用户单独确认。

## 19. 完成标准

1. 第 3 节目标全部有代码、测试或文档证据。
2. 第 16 节聚焦与受影响 package 测试全绿。
3. `docs/spec/007` 与 `docs/platform-page-inventory.md` 已同步。
4. plan-vs-shipped 对账完成（schema、seam、三端列表、回链、筛选接线逐项核对），scope-down 与 deferred 项已记录。

## 20. 剩余风险

- E8 复习字段先建后用，在 E8 落地前是冗余列；风险低（NULL / 默认值），由 dependency contract 管控。
- candidate 被重新分析替换后，已沉淀项的 `source_candidate_id` 会悬挂；快照语义保证显示不受影响，但去重键对"同一文本再次沉淀"不生效，可能出现近似重复项；后续记忆管理方案处理合并。
- 词典能力交叉（2026-05-25 备忘录）未纳入，未来词句沉淀与词典条目的关系需要独立方案。
- 本环境（Linux）无法做模拟器人工验证，三端视觉与导航行为需 macOS 环境补验。
