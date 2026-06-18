# 任务方案：本地 FTS 全文搜索（mac Command Palette 与 iPad 搜索接入）（E9）

状态：Implemented（待 CI 收尾时补 run id）
自审核状态：Reviewed（2026-06-18 批量 run 实现前隔离自审核，用当前代码核验漂移）
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-18（批量 run 实现前隔离自审核：migration v25+、部署目标 iOS18/macOS15→FTS5+trigram 可用、复用既有 ⌘F search command、memory 组因 E7 未落地仅零态降级）

## 批量 run 实现前隔离自审核（2026-06-18）

```text
审核方式：隔离子代理只读，用当前 HEAD（aa480e4 系附近）核验方案 §2/§12 现状
核心决策/ADR 反转检查：无。FTS 索引为本地可重建派生数据（spec 007 §FTS/索引 + 核心决策 12），方案 §5/§7 已按不同步、不导出必需、可重建处理；tokenizer 选型写 spec 007（非 ADR），权威分流正确。
确认漂移与修订（实现时按此为准）：
  [P0-1] migration 漂移：最新已是 v24（v24_create_ai_request_logs，AppDatabase.swift:114），FTS 虚表 migration 须从 v25 起，用 inline db.execute(sql:"CREATE VIRTUAL TABLE … USING fts5(...)")（db.create(table:) 无法表达虚表），无 Migrations/ 目录。
  [P0-2] 部署目标实为 iOS 18.0 / macOS 15.0（project.yml），系统 SQLite ≥3.43 含 FTS5+trigram；GRDB 7.10 已定义 SQLITE_ENABLE_FTS5（Package.resolved + checkout Package.swift）。FTS5 可用，Phase 0 spike 从“平台风险闸”降级为“确认测试”；短查询(<3 char)走 LIKE 降级仍为合理产品选择（trigram 需 ≥3 char）。
  [P0-3] E7 未落地：无 memory_items 表（E7 仍在 active/ Draft；现有 MemoryItem 是候选投影 mock）。memory 搜索组仅做零态降级，写入索引的 writer hook 不纳入本切片，gate 到 E7 后（写入 §20 剩余风险，不写入 §12 实施步骤）。
  [P1-1] 搜索命令已存在且为 ⌘F：LangoTraceApp.swift:199-203 CommandMenu("Workspace") Button("Search").keyboardShortcut("f")；MacMainView 已 onReceive(.search)→route=.unavailable("search")，toolbar magnifyingglass 同样指向 .unavailable("search")。E9 应【复用既有 LangoTraceAppCommand.search】，把 MacMainView 接收端 + toolbar 从 .unavailable("search") 改指真实 palette，不新增 ⌘K（否则双入口）。§8 的“⌘K command”改为“复用 search command + AppEnvironment 装配 LocalSearchRepository”。
  真实可索引列（FTS 必须引用真实列）：entries(title, body)（AppDatabase.swift:370-382，排除 deleted_at 软删）、learning_materials.learning_text（仅 is_current=1，:395/:422-424）、reading_documents(title, body)（body 对 body_storage_kind=managedFile 为 NULL，回填须经 reading repo body resolver，AppDatabaseReadingMigration.swift:50-83）；reading 逐块锚点用 reading_structure_blocks/reading_sentences（:141-173）。reading 已有 reading_document_search_index + rebuildSearchIndex（LIKE，:692-695）可借鉴。
有序 seam（修订）：v25 fts5 虚表 + meta → SearchIndexWriter(Data，entry/learning_material/reading 写路径，不含 memory) → LocalSearchRepository(Core 协议)+GRDBLocalSearchRepository(Data) → SearchModels(Core，UTF-safe 高亮 range) → SearchPaletteStore(UI) → MacSearchPaletteView（repoint 既有 search 接收端）+ PadSearchOverlayView（替换 PadSheet.unavailableSearch）+ AppEnvironment 装配。
是否允许进入实现：是（批量 run §1 预授权 + 本轮漂移已修订）。
```

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（[2026-06-11-chore-code-review-and-dev-plan-series.md](2026-06-11-chore-code-review-and-dev-plan-series.md)）。该授权仅覆盖"方案文档创建"；本方案进入实现前仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

## 1. 需求或 bug 描述

按 `prototypes/mac/search.html`，macOS 提供 ⌘K 唤起的 Command Palette 全局搜索：结果按 记录 / 阅读 / 记忆 三组分组、命中关键词高亮、↑↓ 选择、↵ 打开并定位命中位置、esc 关闭，范围限定当前语言空间，全程不发出网络请求。iPad 顶部搜索复用同一结果模型与分组语义，只更换呈现容器。本任务建立本地 FTS5 派生索引与三端搜索能力：

1. FTS5 派生全文索引（记录原文、学习材料、阅读文档、记忆词句），本地可重建、永不同步。
2. 索引维护策略与 CJK 分词方案的架构决策。
3. mac Command Palette UI、iPad 顶部搜索浮层复用、iPhone 入口决策。
4. 命中 → 导航，包含阅读文档的 per-block 定位。

## 2. 现状描述

以下事实已对照当前代码（2026-06-11 HEAD）核实：

- 数据层目前没有任何 FTS 实现（`rg -i fts Packages/LangoTraceData` 无命中）。
- 阅读域已有 `reading_document_search_index` 表（`AppDatabaseReadingMigration.swift`，v12 落地）：plain 表（`indexed_title` / `indexed_body_excerpt` / `rebuild_required`），由 `GRDBReadingLibraryRepository` 以 `INSERT OR REPLACE` 维护，用于资料库列表内 LIKE 式搜索；它不是 FTS5，也不覆盖记录与记忆。
- iPad 搜索当前为不可用占位：`PadSheet.unavailableSearch`（`Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`），`PadMainView.swift` 的 `onSearch` 弹出 `UnavailableCapabilityView(content: .search)`。
- macOS 搜索同样不可用：`MacMainView.swift` 将搜索路由到 `route = .unavailable("search")`；仓库中没有 command palette 实现。
- 可索引内容的事实源：`entries`（title / body）、`learning_materials`（learning_text）、`reading_documents`（title / inline body）、E7 的 `memory_items`（target_text / native_text）。E7 尚未实施，记忆分组需要降级路径。
- 当前 migration 头部为 v15；本任务 migration 编号按实施时 `AppDatabase.swift` 顺延（若按系列顺序在 E7 之后实施，预计为 v17）。

## 3. 目标

1. FTS5 索引表落地：覆盖 entries（title+body）、learning materials（learning_text）、reading documents（title+body）、memory items（target_text+native_text），按 `space_id` 过滤，作为本地可重建派生数据。
2. 索引维护采用应用层集中写入策略（决策与理由见第 12.1 节），并提供全量重建路径。
3. CJK 分词采用 trigram tokenizer（决策、理由与 Mac 验证回退见第 12.2 节）。
4. `LocalSearchRepository`：分组查询（记录 / 阅读 / 记忆）、命中片段与高亮区间、相关度排序、当前语言空间过滤。
5. mac Command Palette：⌘K 唤起、分组结果、高亮、↑↓ / ↵ / esc 键盘路径、底部"范围：当前语言空间"披露。
6. iPad：`PadSheet.unavailableSearch` 替换为真实搜索浮层，复用同一结果模型与 store。
7. 命中导航：记录 → Entry 详情；阅读 → 阅读文档并按 per-block 锚点定位；记忆 → 记忆项（E7 已实施时）。
8. E7 未实施时记忆分组以零态降级，不阻塞本任务。

## 4. 范围

- `Packages/LangoTraceData`：FTS migration、`SearchIndexWriter`、`LocalSearchRepository` 协议 + GRDB 实现、各写入 repository 的索引维护接线、重建入口。
- `Packages/LangoTraceCore`：`SearchHit`、`SearchResultGroup`、高亮区间模型。
- `Packages/LangoTraceUI`：`SearchPaletteStore`（查询防抖、分组状态、键盘选择状态机）、mac palette 视图、iPad 搜索浮层、命中导航接线。
- `LangoTraceApp`：⌘K 快捷键注册（macOS commands）、装配。

## 5. 不做什么

- 不做跨语言空间搜索（扩展备忘录 §2.4 显式排除；palette 常驻当前空间披露）。
- 不做向量 / 语义搜索；FTS 与向量索引是两套独立派生数据（embedding 备忘录边界），本任务只做词面全文检索。
- 不把 FTS 索引纳入同步或导出（spec 007 §4：FTS 可重建派生数据默认不同步、导出默认非必需）。
- iPhone 不在本任务提供全局搜索入口：新版 iPhone 原型 19 页中没有搜索页面，记录 / 阅读列表已有各自的浏览路径；iPhone 入口在原型先行的前提下另行立案（这是第 1 节要求的"iPhone entry decision"的结论）。
- 不索引练习录音转写、操作日志或诊断数据。
- 不移除阅读域既有 `reading_document_search_index`（资料库列表内过滤继续使用它；关系见第 12.3 节）。

## 6. 证据与决策依据

- 原型证据：`prototypes/mac/search.html`（palette 结构、三分组、highlight 样式、键盘 hint、"范围：当前语言空间"、设计说明明确"依赖本地 FTS 索引……全程不发出网络请求"、"iPad 顶部搜索复用同一结果模型与分组语义"）。
- 代码证据：见第 2 节逐条核实。
- 备忘录采纳说明：
  - [2026-06-11-prototype-target-design-extension-notes.md](../../architecture/notes/2026-06-11-prototype-target-design-extension-notes.md) §2.4：采纳"结果类型至少覆盖记录、阅读文档和沉淀词句"与"范围限定当前语言空间"；"FTS 索引作为可重建派生数据的失效 / 重建策略"由本方案第 12.1 节给出；跨空间搜索按备忘录保持排除。
  - [2026-05-27-embedding-infrastructure-notes.md](../../architecture/notes/2026-05-27-embedding-infrastructure-notes.md)：采纳"FTS 与向量索引边界分离"；本任务不为向量基础设施铺路。
  - [2026-05-20-language-space-sync-extension-notes.md](../../architecture/notes/2026-05-20-language-space-sync-extension-notes.md) §4：采纳"FTS、向量索引……可重建派生数据默认不同步"为硬约束。
- workflow 引用：属于数据迁移 + 平台页面动作，遵循 [add-storage-migration.md](../../workflows/add-storage-migration.md)（派生数据可失效、可重建测试要求）与 [add-platform-screen.md](../../workflows/add-platform-screen.md)。无偏离。
- 前序依赖：R1（[2026-06-11-05-feature-reading-experience-completion.md](2026-06-11-05-feature-reading-experience-completion.md)）确定阅读结构与 per-block 锚点一致性，是阅读命中定位的前提；E7 为软依赖（记忆分组可降级零态）。

```text
证据能证明什么：原型固定了分组、键盘路径、高亮与空间范围披露；代码证明当前没有可复用的 FTS 基础设施，阅读域索引只是 LIKE 辅助表。
证据不能证明什么：原型不能证明 tokenizer 选型与索引维护策略；这些是本方案的架构决策，需在实施中用 spike 验证。
迁移前提：trigram tokenizer 在最低部署目标的系统 SQLite 中可用（见第 12.2 节 Phase 0）。
照搬风险：照搬"外接 content 表 + SQL trigger"的常见 FTS 模式会与本仓库 repository 集中写入、表重建式 migration（v10 先例）的习惯冲突，故选择应用层维护。
```

## 7. 约束映射与验证路径

### 约束 1：FTS 是本地可重建派生数据，默认不同步、不导出为必需数据

- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md` §3、§4；`docs/README.md` 核心决策 12（同类派生数据边界）；`docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md` §4
- 适用范围：FTS 表、重建逻辑、未来同步 / 导出消费方
- 严重度：blocker
- 执行或验证方式：单元测试（重建后查询等价）+ E10 / E11 方案交叉检查
- 验证提示：索引损坏或缺失时可从主数据全量重建；E10 导出清单与 E11 同步范围不包含 FTS 表。

### 约束 2：搜索不发出网络请求

- 来源：`docs/decisions/005-local-first-and-user-owned-providers.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md`
- 适用范围：搜索全链路
- 严重度：blocker
- 执行或验证方式：人工审查（搜索路径不接触任何 Provider / HTTP 类型）
- 验证提示：`LocalSearchRepository` 只依赖 GRDB。

### 约束 3：migration 可重复验证

- 来源：`docs/spec/007` §4、`docs/workflows/add-storage-migration.md`
- 适用范围：FTS migration
- 严重度：blocker
- 执行或验证方式：migration 单元测试（空库、自上一版本、重复 migrator）

### 约束 4：导航与路由一致性

- 来源：`docs/spec/002-navigation-and-routing.md`
- 适用范围：命中导航
- 严重度：warn
- 执行或验证方式：UI 单元测试 + 人工审查
- 验证提示：命中打开复用既有 route 类型（如 `PadWorkspaceRoute.entryDetail`），不新建并行导航机制。

### 约束 5：macOS 键盘与可访问性

- 来源：`docs/spec/010-apple-platform-interaction-and-accessibility.md`
- 适用范围：palette 键盘路径与焦点管理
- 严重度：warn
- 执行或验证方式：store 状态机单元测试 + macOS 人工验证

## 8. 涉及的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（新增 FTS migration）
- `Packages/LangoTraceData/Sources/LangoTraceData/SearchIndexWriter.swift`（新增）
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalSearchRepository.swift`、`GRDBLocalSearchRepository.swift`（新增）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`、`GRDBReadingLibraryRepository.swift`、`GRDBMemoryItemRepository.swift`（写路径接入索引维护）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SearchModels.swift`（新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SearchPaletteStore.swift`、`MacSearchPaletteView.swift`、`PadSearchOverlayView.swift`（新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`、`PadMainView.swift`、`MacMainView.swift`（入口替换）
- `LangoTraceApp/`（macOS ⌘K command、装配）

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabaseReadingMigration.swift`（既有索引表与重建标记模式）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryStore.swift`（查询驱动列表的 store 模式）
- 阅读 per-block 定位相关实现与 [2026-06-06-reading-uitextview-per-block-patterns.md](../../architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md)

## 10. 涉及的文档路径

- 本方案。
- `docs/spec/007`（实施后补充 FTS 派生数据落地事实与重建策略）
- `docs/platform-page-inventory.md`（mac 搜索、iPad 搜索条目状态更新）
- 前序依赖方案：[2026-06-11-05-feature-reading-experience-completion.md](2026-06-11-05-feature-reading-experience-completion.md)（R1）、[2026-06-11-10-feature-memory-deposit-foundation.md](2026-06-11-10-feature-memory-deposit-foundation.md)（E7，软依赖）

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### 12.1 架构决策一：索引维护策略 = 应用层集中写入 + 版本化全量重建

备选是 SQL trigger（外接 content 的 FTS5 表 + INSERT/UPDATE/DELETE triggers）。决策为应用层维护，理由：

1. 本仓库所有写入都经过 GRDB repository（无外部写入方），应用层维护不存在旁路写入漏更新的风险面。
2. trigger 把分词前的归一化（大小写、全半角、空白折叠）逻辑锁死在 SQL 里，不可单元测试；应用层归一化在 Swift 中可测试、可演进。
3. 仓库已有表重建式 migration 先例（v10 重建 `media_artifacts`），trigger 在表重建时必须同步迁移，维护成本高。
4. 风险补偿：提供 `rebuildSearchIndex(spaceID:)` 全量重建 + `search_index_meta` 单行表记录 `index_schema_version`；启动或 migration 时版本不匹配标记重建。索引写入失败不阻塞主数据事务收口策略：索引写入与主数据同事务（保证一致性），若 FTS 写入异常则整组回滚并返回可诊断错误——派生表与主数据同库同事务，成本可接受。

具体落点：`SearchIndexWriter`（upsert / remove，按 object kind + id），由各 repository 在创建、正文更新、软删除、恢复、reanalysis 替换时调用。

### 12.2 架构决策二：tokenizer = FTS5 trigram，附 Mac 验证回退

评估：

- `unicode61`：对空格分词语言（英语等目标语言文本）工作良好，但把连续 CJK 字符串当作单 token，中文母语释义与日语目标文本的子串查询基本不可用。语迹的母语侧默认是中文，记录正文是中外混排，unicode61 单独使用不成立。
- `trigram`（SQLite >= 3.34）：对 CJK 与拉丁文本统一支持子串匹配，无需外部分词器，顺带获得 LIKE 加速；代价是索引体积约为原文 3 倍量级、查询词最短 3 个字符。

推荐：FTS5 `tokenize='trigram'` 作为唯一索引 tokenizer。查询词不足 3 字符（如中文双字词"咖啡"按 UTF-8 字符计为 2 字符）时，降级为对索引源列的 `LIKE '%q%'` 扫描（数据量为个人记录量级，可接受），该降级在 repository 内封装，调用方无感知。

Mac 验证回退（本环境为 Linux，无法验证 Apple 平台系统 SQLite）：实施第一步为 Phase 0 spike——在 macOS 环境对最低部署目标验证 `trigram` tokenizer 可用性。

```text
假设名称：系统 SQLite 在最低部署目标（iOS 17+ / macOS 14+ 量级，以 project.yml 为准）支持 FTS5 trigram
probe / fixture 路径：Packages/LangoTraceData/Tests/LangoTraceDataTests/Search/FTSTokenizerAvailabilityTests.swift（创建 trigram 虚表并断言成功）
PASS 条件：测试在 macOS 本机与 iOS Simulator 构建中通过
FAIL 条件：CREATE VIRTUAL TABLE ... tokenize='trigram' 抛错
FAIL 后处理方式：改用 unicode61 索引拉丁文本 + 全列 LIKE 降级承担 CJK 查询，并把该取舍写回本方案与 spec 007
是否允许进入生产实现：PASS 后允许；FAIL 时按回退路径修订方案后再实现
```

### 12.3 与既有 reading_document_search_index 的关系

阅读资料库列表内过滤继续使用既有表（其职责是列表筛选，含 `rebuild_required` 机制）；全局搜索的阅读分组使用新 FTS 表。两者来源同一主数据、各自可重建，不互为事实源。后续若 R1 之后阅读列表过滤迁移到 FTS，由独立清理任务处理，本任务不合并以控制范围。

### 12.4 实施步骤

1. Phase 0 spike（12.2）。
2. Data：先失败测试 → migration（FTS5 trigram 虚表 `search_index`，列：object_kind / object_id / space_id（UNINDEXED 视需要）/ title / body；`search_index_meta` 版本表）→ `SearchIndexWriter` → 各 repository 写路径接线（含软删除移除、恢复重建、Entry body 更新、reanalysis 替换、阅读导入 / 软删除 / 恢复、memory deposit）→ 全量重建 + 已有存量数据的首次回填（migration 后标记重建，启动异步回填，回填中搜索返回部分结果并在 store 暴露 indexing 状态）。
3. 查询：`GRDBLocalSearchRepository.search(query:spaceID:limit:)` 返回分组 `SearchHit`（标题、摘要片段、高亮区间、导航引用：entry id / reading document id + block 锚点 / memory item id），按 FTS rank 排序，每组截断（如 5 条）。阅读命中的 block 锚点通过 R1 落定的 block / offset 结构换算。
4. UI：`SearchPaletteStore`（防抖 150ms、任务取消防竞态、键盘选择跨组连续移动、esc 关闭、↵ 导航回调）；mac palette 视图 + ⌘K command；iPad 浮层替换 `PadSheet.unavailableSearch`（保留 sheet 容器，内容换为真实搜索）。E7 未落地时记忆分组隐藏并显示零态说明。
5. 导航接线与三端验证、文档同步。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：同系列说明——方案撰写会话内无法对未落盘草稿做隔离审查，按协议第 3 节降级为主会话双轮自审核。
发现摘要：
  第一轮（架构）：
  - P0：初稿未处理与既有 reading_document_search_index 的关系，会形成两套阅读搜索语义的认知冲突 → 新增 12.3 节明确边界。
  - P1：初稿 trigram 决策没有覆盖"查询词 < 3 字符"的中文常见场景 → 补充 LIKE 降级路径。
  - P1：存量数据首次回填缺失会导致升级用户搜索结果为空 → 12.4 第 2 步补充回填与 indexing 状态。
  - P2：索引写入与主数据事务关系未定义（崩溃后索引漂移）→ 12.1 决策为同事务写入 + 版本化重建兜底。
  第二轮（测试 / 安全 / 落地）：
  - P0：tokenizer 可用性在本环境不可验证，直接进入实现有平台性风险 → 升级为 Phase 0 spike gate（12.2）。
  - P1：查询防抖下的任务竞态（旧查询晚返回覆盖新结果）→ store 测试补充取消用例。
  - P2：高亮区间在 UTF-8 / UTF-16 偏移换算上易错 → SearchModels 用 String.Index 安全表示并写测试。
  - P2：搜索查询字符串不得进入诊断日志原文 → 复查方法补充日志脱敏检查。
写回修改：以上均已写回第 5、12、14、15 节。
仍需用户确认的问题：
  1. iPhone 本阶段不提供全局搜索入口的决策是否接受（原型无该页面，建议原型先行后另行立案）。
  2. 每组结果截断条数（建议 5）与是否需要"查看全部结果"页（本任务不做）。
是否允许进入实现：待用户确认后允许（且 Phase 0 spike 需 PASS）。
```

## 14. 复查方法

- 代码：migration、writer、repository、store 测试全绿；`rg -i fts Packages/LangoTraceData` 命中新基础设施。
- 行为：mac ⌘K 唤起 palette，输入英文与中文关键词均能命中三组结果并高亮；↑↓/↵/esc 路径正确；iPad 顶部搜索同结果；命中打开后定位正确（阅读命中滚动到对应 block）；切换语言空间后结果隔离。
- 故障与恢复路径：删除 FTS 表后重建恢复等价结果；索引版本不匹配触发重建；查询中断 / 快速连续输入无竞态错乱；空查询与无结果有稳定零态；搜索词不出现在诊断日志原文（仅长度分桶级元数据，如有记录）。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Search/FTSTokenizerAvailabilityTests.swift（Phase 0）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Search/AppDatabaseSearchMigrationTests.swift（新增）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Search/SearchIndexWriterTests.swift（新增：upsert / 软删除移除 / 恢复 / 重建等价）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Search/GRDBLocalSearchRepositoryTests.swift（新增：分组、空间隔离、CJK 命中、短词降级、rank）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Search/SearchPaletteStoreTests.swift（新增：防抖、取消、键盘状态机、零态）
先失败用例：GRDBLocalSearchRepositoryTests.indexedEntryIsFoundByBodyKeyword —— 预期失败原因：search_index 虚表与 LocalSearchRepository 尚不存在。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceData --filter Search
  swift test --package-path Packages/LangoTraceUI --filter SearchPaletteStoreTests
不新增单元测试的原因（如适用）：不适用。
```

## 16. 验证命令

```bash
# Phase 0 DoD（macOS 环境）
swift test --package-path Packages/LangoTraceData --filter FTSTokenizerAvailabilityTests

# 聚焦
swift test --package-path Packages/LangoTraceData --filter Search
swift test --package-path Packages/LangoTraceUI --filter Search

# 受影响 package 完整
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
```

## 17. 文档影响检查

- `docs/spec/007`：补充 FTS 派生数据落地事实、重建策略与同步 / 导出排除（实施后）。
- `docs/platform-page-inventory.md`：mac 搜索从未实现更新为 Command Palette、iPad 搜索从 unavailable 占位更新（实施后）。
- `docs/spec/002`：若命中导航引入新 route 形态需同步（预计复用既有 route，无需改动）。
- ADR：不需要；FTS 沿用派生数据既有边界。tokenizer 选型写入 spec 007 而非 ADR。
- review：数据库 schema 变化命中专项审查触发条件，实施后按 `docs/review/README.md` 处理。

## 18. 实施记录

（实施时按时间追加；Phase 0 spike 结果必须先记录在此。）

## 19. 完成标准

1. Phase 0 spike 有明确 PASS 记录（或 FAIL 后已按回退路径修订并重新确认）。
2. 第 3 节目标全部有代码与测试证据；记忆分组降级路径有测试。
3. 聚焦与受影响 package 测试全绿；macOS 人工验证键盘路径通过（或记录待补验）。
4. 文档同步完成，plan-vs-shipped 对账完成。

## 20. 剩余风险

- trigram 索引体积约为源文本 3 倍，个人数据量级下可接受，未做上限治理；数据量异常增长时需要容量观测（后续本地数据统计能力 E12 可顺带暴露）。
- 短查询 LIKE 降级在超大数据量下变慢；当前量级低风险。
- 阅读 per-block 锚点依赖 R1 的结构稳定性；若 R1 范围调整，本任务阅读命中定位需同步复核。
- iPhone 无全局搜索入口在用户侧可能形成三端差异疑问；已列为仍需用户确认项。
- Linux 环境无法执行 Phase 0 与人工键盘验证，相关步骤必须在 macOS 环境完成。

## 18. 实施记录

2026-06-18（批量 run 落地）：feature/e9-local-fts-search 分支按 TDD 分阶段落地，本机轻量验证（Core/Data/UI 单包测试 + swiftformat/swiftlint），重测试走 CI。
  - Phase 1-2（commit Core+Data）：Core `SearchModels`（`SearchObjectKind`/`SearchHit`/`SearchResultGroup`/`SearchResults`/UTF-safe `SearchHighlighting`）+ `LocalSearchRepository` 协议；`v25_create_local_search_index`（FTS5 trigram 虚表 + `search_index_meta`）；`SearchIndexWriter`（应用层同事务 upsert/remove）+ `GRDBLocalSearchRepository`（trigram MATCH / <3 字符 LIKE 降级 / space 隔离 / per-group 截断 / 从 entries+当前 learning_text+reading 当前结构 blocks 全量 rebuild）。测试：Core 4、Data 8（**含 FTS5 trigram availability 在本机确认**、CJK 子串、短词降级、space 隔离、rebuild 丢弃软删）。
  - Phase 3（commit UI store）：`LocalSearchActions` env seam + `SearchPaletteStore`（防抖、stale-result 丢弃、跨组键盘环绕、零态/indexing、rebuild-on-open）。测试 6。
  - Phase 4（commit UI+App）：共享 `SearchPaletteView`；复用既有搜索命令（⌘F），repoint macOS 工具栏/命令 + iPad sheet 从 `.unavailable("search")` 到真实浮层；记录命中→记录详情、阅读命中→阅读区；`AppEnvironment` 装配 `GRDBLocalSearchRepository`+`LocalSearchActions`，两处根注入。全 UI 套件 503 绿。
  - 文档：spec 007 变更记录补充 + platform-inventory 搜索行更新。

scope 决策（留痕，§1.1 首版可限定范围、底层为后续预留）：
- **索引维护 = rebuild-on-open（v1）**，非按写路径增量 upsert。理由：所有写入经 repository，rebuild 从主数据全量重建、零旁路漏更新风险，个人数据量级 rebuild 成本可接受，且完全可测试。`SearchIndexWriter` 增量 upsert 已就绪并测试，按写路径接线（entry 创建/更新/软删、reading 导入/软删/恢复、reanalysis）列为后续优化（届时 rebuild 仍为一致性兜底）。
- **reading 命中按文档级**（一文档一行，body=当前结构版本 blocks 拼接），未做 per-block 锚点行；per-block 锚点导航（plan §3.7）列为后续优化，命中先打开文档。
- **命中导航**：记录→记录详情已接；阅读→选中阅读区（未滚动到具体 block，随 per-block 锚点优化一并补）；记忆→零态（E7 未落地、无 `memory_items`，方案 §3.8 既定降级）。
- iPhone 不提供全局搜索入口（方案 §5 既定，原型无该页）。
