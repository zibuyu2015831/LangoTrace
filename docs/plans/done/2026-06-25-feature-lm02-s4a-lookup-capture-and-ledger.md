# 任务方案：查词/索取解释行为捕获 + 分析账本地基（LM02 Slice 4a）

状态：Done（2026-06-25 三 Phase 落地；轻量本机 Core 242 + Data 251 + UI 582 全绿 + GitHub Actions Build & Test 全绿（run 28163829316）；§17 文档已回写；已移入 done/）
自审核状态：**Reviewed（双轮 + 拆分后隔离再审三关过；2026-06-25）**——从 S4 双轮归属 S4a 的发现 + **拆分后隔离再审新发现 P0-A（source_content_origin 不可捕获，降为前向接缝）/ P1-B（practice 伪先例，改新类别显式声明）/ P2-C（埋点落点改 AI 解释 seam）** 均已核验成立并收口（见第 13 节两个审核块）。**仍待用户实现授权**（第 2 批开工前，硬前置 S1 + S3）。
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

本方案由 [S4 拆解边界](2026-06-25-feature-lm02-s4-band-reestimation.md)（2026-06-25 用户决策拆 S4a/S4b）spawn，是 [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 学习者模型系列 LM02 第四片的**低风险地基子片**。S4a 范围：把阅读视图的**查词 / 索取解释行为**落库为行为事件 + 首次落地 ADR-006 §9 规划的**分析账本 + 高水位 cursor**，作为 S4b band 重估的信号与增量重算地基。**S4a 不动 `derive()`、不产 band、不做总览呈现**（那些是 S4b）。

状态 `Draft`：本切片须完整双轮自审（已补）+ 用户实现授权方可进入实现。当前**无实现授权**。**硬前置 S1**（建在 S1 的 v27 `learner_memory_facts` schema + `writer: DatabaseWriter` seam 之上）。

## 1. 需求或 bug 描述

S4b 的 band 重估需要**独立于 level 闭环的用户行为信号**（idea-02 §4 主力信号 = 查词 / 索取解释频率；§13.1 闭环红线 = band 须建在不被 level 污染的独立信号上）。当前（2026-06-25 HEAD）：

- 查词 / 索取解释行为**无持久化**：`ReadingDictionaryLookup`（Core 类型）存在于阅读路径，但**未落库为行为事件**——band 主力信号净新增捕获。
- ADR-006 §9 规划的**分析账本 / cursor 不存在**（全仓无 `intake_ledger` / `IntakeLedger`，migration 头 = `v26`）。账本「建了不读」推迟到 S4 band 重估时**首次建对**。

S4a 把这两块地基建对、可回归，使 S4b 只需消费既有信号 + 接 derive()，把最高风险集中在 S4b。

## 2. 现状描述（对照 2026-06-25 HEAD 核实）

- **migration 头 = v26**（`AppDatabase.swift`，`v26_create_memory_item_infrastructure`）。**S1 将建 v27 `learner_memory_facts`（仓库首张系统级 Learner 表）+ writer seam**；S4a 的查词事件表 + 账本表为 **v28+**，建在 S1 v27 schema 与 `writer: DatabaseWriter` 之上（P1-1 修正：S4 表**非** Learner Model 首张持久表，S1 v27 才是；S4a 是首张 **Ability 派生 / 账本** 持久表）。**硬前置 S1**。
- **「查词 / 索取解释」真实路径 = AI 解释 seam（再核实，修正）**：`ReadingDictionaryLookup` / `ReadingDictionaryLookupIndex`（Core 值类型）**当前是未接线预留**（全仓仅测试引用，无 UI/App 运行路径）。阅读视图真实的「查词 / 索取解释」交互是 **AI 解释路径**（`ReadingAIExplanation` / `ReadingDocumentStore.completeExplanation` / `ReadingExplanationCache`）——用户选中文本→请求解释。故「查词」与「索取解释」在现实现里**同一条 AI 解释路径**，S4a 埋点宿主是该 explanation seam，**非** `ReadingDictionaryLookupIndex`（隔离再审 P2-C 修正）。
- **`practice_text_attempts`（v23）不是「排除导出」先例（隔离再审 P1-B 修正）**：核实 `practice_text_attempts` **无任何 backup/sync/export 策略列**，其「未导出」是「尚无导出 wiring」的隐含状态、非声明式先例；归档导入导出方案（`docs/archive/plans/2026-06-11-13-feature-import-export-backup.md:16`）反而把它列入**「主数据（导出）」**。spec/007:112 的 local-only/排除导出讲的是 **TTS / 媒体派生资产**（可重建敏感派生），与 practice 无关。→ **查词事件无现成先例可挂靠**：是「不可重算的用户行为信号」新类别，须**显式声明持久化策略列** + spec/007 **新增登记**，不照搬伪先例（P1-2 重新论证，见 §7 约束 2）。
- **阅读文档来源 = 当前恒为用户导入（隔离再审 P0-A 修正）**：`reading_documents`（`AppDatabaseReadingMigration.swift`）唯一写入路径 `importInlineDocument` 的 `source_kind` 只取 `pastedText` / `fileImport`，**均为用户导入**；**全仓无任何路径**把 AI 生成 `learning_materials.learning_text` 转成 `reading_documents`（学习材料详情页与阅读视图是独立 surface）。→ **v1 查词恒发生在用户原创/导入内容上**，「AI 生成材料上的查词」在 S4a 范围内**无数据来源**。故 P0-4 二阶闭环（查词建在 AI 生成材料上）**在 v1 不成立**；`source_content_origin` 判别列降为**前向 schema 接缝**（v1 恒 `userAuthored`），见 §3 目标 1。
- **账本不存在**：ADR-006 §9 键 `(source_type, source_id, analyzer, analyzer_version)` + 高水位 cursor 增量重算，S4a 首次建对。

## 3. 目标

1. **查词 / 索取解释行为事件捕获**（净新增持久化，v28）：阅读视图 **AI 解释 seam**（用户选中文本→请求解释，§2 修正）落库为**行为事件**（用户行为信号，非 AI 判定——记的是「用户在何时对哪段文本索取解释」，非 AI 返回的解释内容）。事件含 `source_content_origin` 列作**前向 schema 接缝**（P0-A 修正：v1 阅读文档恒用户导入，该列 v1 恒 `userAuthored`；`aiGenerated` 分支留待未来「学习材料可作阅读源」基础设施落地后填充——不为不存在的路径预造捕获逻辑，仅留 schema 位）。
2. **分析账本 + cursor**（ADR-006 §9 首次落地，v28+）：`(source_type, source_id, analyzer, analyzer_version)` 键 + 高水位 cursor 增量重算（窗口聚合，非 per-item 旗标）；升版重跑靠 `analyzer_version`。查词事件表**就是**账本引用的 source 之一（`source_type = 'dictionaryLookup'`，ADR-006 §9「不在源表加列、以 (source_type, source_id) 引用源行」，P3-3）。
3. **repository + 持久化分层**：查词事件 = **不可重算用户行为信号**（无现成先例，§2 P1-B），**显式声明持久化策略 = local-only / 排除备份 / 排除导出**（默认理由：单条查词低价值、band 可从剩余信号优雅降级；非照搬 practice 先例）+ spec/007 **新增登记** + FileProtection 接缝（架构备忘录）；账本 / cursor = 派生状态（可从事件重算）。**注**：「查词事件是否应可导出」是温和产品问题，v1 默认 local-only 并在 §20 标为开放项。
4. **不动 `derive()`、不产 band、不做总览呈现**（均属 S4b）；全程纯本地、零外发、零 AI 判定。

## 4. 范围

- **`Packages/LangoTraceData`**：查词行为事件表 + 分析账本 / cursor 表（v28+ migration，建在 S1 v27 之上）；对应 repository（写入查词事件、读账本 cursor、增量窗口查询）。
- **`Packages/LangoTraceCore`**：查词行为事件值类型（若需跨包共享）；`source_content_origin` 枚举（`userAuthored` / `aiGenerated`）。
- **`Packages/LangoTraceUI`**：阅读视图查词 / 索取解释埋点（写入行为事件，**不外发、不写诊断敏感内容**）。
- **`LangoTraceApp/AppEnvironment.swift`**：装配查词事件 repository + 账本。
- 文档：spec/007（查词事件 + 账本 / cursor 持久化分层登记）、architecture/002（账本子系统 + 查词信号数据流，接在 S1 LM01/Memory 基线之后）、ADR-006 §9 实施回写（账本首次建对）、`docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`（登记查词事件 FileProtection 接缝，P1-4）、decomposition + dashboard 标注。

## 5. 不做什么

- **不动 `derive()` / 不产 band / 不做总览呈现 / 不接 derive 迟滞**（全属 S4b）。
- **不决定查词信号如何加权 / 是否排除 AI 来源**（S4a 只捕获 `source_content_origin` 判别位，加权策略属 S4b band 服务）。
- **不做 AI 校准 / 外发**（纯本地行为捕获，不新增 `AIRequestCapability`）。
- **不把查词事件进备份 / 导出**（P1-2：local-only，对照 practice 证据先例；band 在 S4b 可从剩余信号优雅降级重估）。
- **不改用户可见 `LanguageLevel` 标签**（S4a 不碰水平呈现）。

## 6. 证据与决策依据

- ADR-006 §4（证据红线：用户行为 / 产出，AI 判定禁用——查词是用户行为，合规）、§8（Ability 派生 local-only 不备份；账本 / cursor 派生可重算）、§9（分析账本 + cursor + provenance 证据集）。
- idea-02 §4（有效信号 = 用户行为 / 产出，查词 / 索取解释频率是主力）、§13.1（闭环红线：band 建在独立信号）。
- 架构备忘录：`docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`（P1-4：创建持久化方案前必查；查词事件加高频行为 PII，须登记 FileProtection / 加密接缝）。
- 代码证据：见第 2 节（migration 头 v26；查词无持久；账本不存在；practice_text_attempts 持久化先例；阅读材料双来源）。
- workflow 引用：**命中** [`add-storage-migration`](../../workflows/add-storage-migration.md)（查词事件表 + 账本 / cursor + 持久化策略 + 回滚验证）；**轻度命中** [`add-platform-screen`](../../workflows/add-platform-screen.md)（阅读视图埋点，非新页面）；不命中 AI Provider / TTS / Prompt（零外发）。

```text
证据能证明什么：查词 / 索取解释是 ADR-006 §4 合规的用户行为信号；ADR-006 §9 已规划账本键 + cursor；practice_text_attempts 给出「不可重算用户行为」持久化先例。故 S4a 地基路径合法。
证据不能证明什么：查词信号若全部建在 AI 生成材料上，会形成「level→生成文本→哪些词难→查词频率→band」二阶闭环（P0-4）——故 S4a 须捕获 source_content_origin 判别位，把「是否排除 AI 来源查词」留给 S4b 决策（S4a 不预先丢弃信号、也不预先全信）。
迁移前提：净新增查词事件表 + 账本 / cursor 表（v28+，建在 S1 v27 之上）；migration 须可回滚 + 结构化验证。
照搬风险：把账本做成 per-item 旗标（应为高水位 cursor 窗口聚合）；把查词事件进备份（应 local-only）。
```

```text
是否需要 spike / probe / fixture / evidence：否——纯本地 GRDB 写入 + 账本读。fixture 为合成查词事件 + 阅读会话，无真实用户敏感内容。
需要时的落点：不适用。
是否包含真实用户敏感内容：否——合成 fixture。
如何验证和清理：合成 fixture，无需清理。
```

## 7. 约束映射与验证路径

### 约束 1：查词事件 = 用户行为信号、非 AI 判定 — blocker
- 来源：ADR-006 §4、idea-02 §4
- 验证：事件只记用户行为（查了哪个词 / 何时 / 在哪条内容上），**不记** AI 判定难度 / AI 点评；单元测试断言写入字段不含任何 AI 生成内容。

### 约束 2：查词事件持久化分层 = 显式声明 local-only / 排除备份 / 排除导出（新类别，非伪先例）— blocker
- 来源：ADR-006 §8、spec/007（**新增登记**）、架构备忘录（P1-2/P1-4）；**隔离再审 P1-B：practice_text_attempts 非排除导出先例（无策略列、归档导出方案列其为主数据）、spec/007:112 是 TTS/媒体派生资产**——故查词事件无现成先例
- 验证：查词事件表**显式声明**持久化策略列（local-only / excluded-from-backup / excluded-from-export），不照搬 practice；spec/007 **新增**「不可重算用户行为信号」分层条目；FileProtection 接缝登记进架构备忘录；测试 / 审查确认不进导出快照、不进同步集。**剩余风险**：① local-only 意味着设备迁移后查词历史不可恢复——S4b band 须能从剩余信号优雅降级重估（在 S4b 约束）；② 「查词事件是否应可导出（像 practice 主数据）」是开放产品问题，v1 默认 local-only（§20）。

### 约束 3：账本高水位 cursor 增量重算（非 per-item 旗标）— blocker
- 来源：ADR-006 §9
- 验证：账本键 `(source_type, source_id, analyzer, analyzer_version)`；cursor 走窗口聚合增量；升 `analyzer_version` 触发重跑；测试 `cursorIncrementalRecomputeSkipsAlreadyAnalyzed` + `analyzerVersionBumpForcesRecompute`。

### 约束 4：source_content_origin 前向 schema 接缝（v1 恒 userAuthored）— warn（由 blocker 降级，隔离再审 P0-A）
- 来源：S4 双轮 P0-4（二阶闭环）+ 隔离再审 P0-A（v1 无 AI 生成阅读源，二阶闭环不成立）
- 验证：查词事件记 `source_content_origin` 列，**v1 恒 `userAuthored`**（阅读文档恒用户导入，§2）；`aiGenerated` 分支 v1 无生产路径。测试降为**结构验证** `lookupEventHasSourceOriginColumnDefaultingUserAuthored`（列存在 + 默认值正确），**不**写「AI 材料标 aiGenerated」（无数据可红）。**理由**：保留列为前向接缝（低成本 TEXT+CHECK），待未来「学习材料可作阅读源」基础设施落地再填 `aiGenerated` 分支 + 升约束为 blocker；S4b 的 aiGenerated 过滤同步降为前向接缝（v1 trivially 全 userAuthored）。

### 约束 5：cursor 增量重算的并发 / 重入 / 取消 — warn
- 来源：S4 双轮 P2-2
- 验证：账本重算只在 document-open 边界触发、不 mid-session 改；明确 MainActor hop；并发 / 重入下 cursor 不双进；测试 cursor 单调推进。

### 约束 6：migration 可回滚 + 结构化验证 — warn
- 来源：S4 双轮 P2-3、add-storage-migration
- 验证：v28+ migration 有结构化建表验证（列 / 索引 / 约束命名测试）；与 S1 v27 顺序正确（v28 在 v27 之后）。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（v28+ migration：查词事件表 + 账本 / cursor 表）
- `Packages/LangoTraceData/Sources/LangoTraceData/`（新增 `GRDBDictionaryLookupEventRepository.swift` + `GRDBAnalysisLedgerRepository.swift`）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/`（查词行为事件值类型 + `SourceContentOrigin` 枚举，若需共享）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/`（阅读视图查词 / 索取解释埋点写入）
- `LangoTraceApp/AppEnvironment.swift`（装配查词事件 repository + 账本）
- 对应 `Tests` 目录新增测试（见第 15 节）

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`（持久化策略列 / 排除备份导出先例）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`（practice_text_attempts 不可重算行为先例）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/GRDBLearnerContextProvider.swift`（Ability 读 / compute-on-read 参照）
- S1 的 `learner_memory_facts` v27 migration + writer seam（**S4a 硬前置，S4a 立项时尚不存在于磁盘**）

## 10. 涉及的文档路径

- 本方案。
- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §9（账本首次建对，实施后回写）。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（查词事件 + 账本 / cursor 持久化分层 + backup_policy 登记）。
- `docs/architecture/002-system-map.md`（账本子系统 + 查词信号数据流，**接在 S1 LM01/Memory 基线之后**）。
- `docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`（P1-4：查词事件 FileProtection 接缝登记 + 检查触发点）。
- `docs/idea/02-dynamic-proficiency-assessment.md` §4（查词信号落地回指）。
- `docs/plans/active/2026-06-25-feature-lm02-s4-band-reestimation.md`（拆解边界母文件，S4a 回指）。
- `docs/plans/active/2026-06-25-docs-lm02-remaining-slices-decomposition.md` / `2026-06-11-00-docs-series-progress.md`（登记 S4a）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

> migration 编号：S4a 两张表建在 S1 v27 之上，**确切编号实现时按当时 head 确认**；下文以 v28（查词事件）/ v29（账本）示意，若同一 migration 建则同号。

### 12.1 Phase 1：查词行为事件表 + repository（v28，硬前置 S1 v27）
1. v28 migration 建查词事件表：`id` / `language_space_id`（FK）/ `looked_up_term` / `source_content_id` / `source_content_origin TEXT CHECK IN ('userAuthored','aiGenerated') DEFAULT 'userAuthored'`（前向接缝，v1 恒 userAuthored，约束 4）/ `occurred_at` / `soft_deleted_at`；**显式持久化策略列** local-only / 排除备份导出（约束 2，新类别非伪先例）。先写迁移结构化验证测试（约束 6）。
2. `GRDBDictionaryLookupEventRepository`：写入事件 + 按语言 / 时间窗读。先失败测试 → 实现。

### 12.2 Phase 2：分析账本 + cursor（v29，ADR-006 §9 首次建对）
1. v29 migration 建账本表：键 `(source_type, source_id, analyzer, analyzer_version)`（查词事件表作 source 之一，`source_type='dictionaryLookup'`，P3-3）+ 高水位 cursor 列；结构化验证测试。
2. `GRDBAnalysisLedgerRepository`：高水位 cursor 增量推进 + 窗口聚合读 + `analyzer_version` 升版重跑（约束 3、5）。cursor 单调推进 / 重入安全测试。

### 12.3 Phase 3：AI 解释 seam 埋点（写入，不外发）
1. **阅读视图 AI 解释路径**（`ReadingDocumentStore` explanation seam，§2 P2-C 修正——非 `ReadingDictionaryLookupIndex`）写入行为事件，`source_content_origin` v1 恒 `userAuthored`（阅读文档恒用户导入，约束 4）。
2. 埋点不引入外发、不写诊断敏感内容（约束 1，§12.1⑥ 母文件隐私边界）；App 装配。

### 12.4 关键决策（已收口，见第 13 节）
- 查词事件持久化 = **显式声明** local-only / 排除备份导出（新类别，非 practice 伪先例，P1-B）；导出与否标开放项（§20）。
- `source_content_origin` = **前向 schema 接缝**，v1 恒 userAuthored（P0-A：v1 无 AI 生成阅读源，二阶闭环不成立）；过滤留 S4b（届时亦 trivially 全 userAuthored）。
- 埋点宿主 = AI 解释 seam（P2-C），非未接线的 `ReadingDictionaryLookupIndex`。
- provenance 采样上限（P2-1）= 镜像 S2/S3 钉采样上限 + 分布摘要、勿无界 ref。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-25
审核方式：隔离子代理双轮（第一轮架构 + 第二轮测试/安全/落地）+ 主会话用 HEAD 代码逐条核验；建立在 S4 拆解边界双轮发现之上（S4a 归属项）
审核轮次：完整双轮
从 S4 双轮归属 S4a 的发现 + 本片收口：
  [P1-1] 「首张持久表」事实错误已纠正：S4a 表 v28+ 建在 S1 v27 + writer seam 之上，硬前置 S1；S4a 是首张 Ability 派生/账本持久表（非首张 Learner 表）。写回 §2/§4/§9。
  [P1-2] 查词事件 backup_policy 已收口 = local-only / 排除备份 / 排除导出（对照 practice_text_attempts，spec/007:113）。剩余风险：设备迁移后查词历史不可恢复 → S4b band 须能从剩余信号优雅降级（在 S4b 约束）。写回 §3目标3/§5/§7约束2。
  [P1-4] 已引用学习者模型持久化/安全架构备忘录：加入 §6 证据 + §10 文档路径，查词事件 FileProtection 接缝登记进备忘录。
  [P0-4] 闭环传递污染（二阶闭环）已收口为「捕获判别位、过滤留 S4b」：S4a 捕获 source_content_origin（userAuthored/aiGenerated），不预先丢弃、不预先全信；S4b 决定加权/排除。写回 §3目标1/§7约束4/§12.1.1。这决定 S4a 捕获什么，故须在 S4a 实现前定（已定）。
  [P2-1] provenance 采样上限：镜像 S2/S3 钉上限 + 分布摘要，勿无界 ref（§12.4）。
  [P2-2] cursor 并发/重入/取消：只在 document-open 边界触发、不 mid-session 改、明确 MainActor hop、cursor 单调推进（§7约束5）。
  [P2-3] migration 回滚 + 结构化验证命名测试（§7约束6/§15）。
  [P3-1] ReadingDictionaryLookup 是 Core 类型非「阅读视图」（§2 已纠正）。
  [P3-2] 测试落点已按 S4a 分区（§15）。
红线机制（镜像 S3 收口）：查词事件捕获不读 AI 判定字段——源级 grep（repository/埋点源不引用 memory_candidates.difficulty / learning_text 作信号）+ 行为断言（写入字段仅用户行为，不含 AI 生成内容）。
确认仍坚实：TDD 红绿次序、fixture（DatabaseQueue + AppDatabase + raw SQL seed，FK 链查词事件→language_spaces）、账本键 + cursor 语义、聚焦验证命令均成立。
是否允许进入实现：否——本轮仅拆 plan，未授权实现。
```

```text
隔离再审日期：2026-06-25（拆分后对 S4a 新 plan 单独 spawn 隔离子代理对照 HEAD 代码再审，防拆分引入新错误）
结论：再审发现 2 项拆分引入的实质错误（P0-A / P1-B）+ 1 落点错误（P2-C）+ 3 P3，均已核验成立并收口；骨架、ADR §9 账本一致性、migration head、红线机制继承、CI-TDD 路径经再审确认坚实。
  [P0-A] source_content_origin 不可捕获（已收口降级）：reading_documents 唯一写入路径仅 pastedText/fileImport（用户导入），全仓无 learning_materials→reading_document 路径 → v1 查词恒 userAuthored、二阶闭环不成立。修订：§2/§3目标1/§7约束4(blocker→warn)/§12.1/§12.3/§12.4/§15/§20——降为前向 schema 接缝（列存在+默认），不为不存在路径预造捕获逻辑。
  [P1-B] practice_text_attempts 伪先例 + spec 引用错位（已收口）：practice_text_attempts 无策略列、归档导出方案列其为「主数据(导出)」、spec/007:112 实为 TTS/媒体派生资产。修订：§2/§3目标3/§7约束2/§12.4/§20——查词事件改「不可重算用户行为信号」新类别、显式声明策略列 + spec/007 新增登记、不照搬伪先例；导出与否标开放产品问题（v1 默认 local-only）。
  [P2-C] 埋点落点错（已收口）：ReadingDictionaryLookupIndex 仅测试引用、未接线；真实查词=AI 解释路径（ReadingDocumentStore explanation seam）。修订：§2/§8/§12.3 改落点；澄清「查词」与「索取解释」同一条 AI 解释路径。
  [P3-1] 「Ability 派生持久表」措辞与 ADR-006 §8（Ability compute-on-read 不持久）张力 → 改「首张分析账本持久表」（§19/§20 用词）。
  [P3-2] migration 编号 v28/v28+ 混用 → §12 顶部注明 v28(查词)/v29(账本)、确切号实现时按 head 定。
  [P3-3] 账本 source_type 取值未点明 → §3目标2/§12.2 补 source_type='dictionaryLookup'。
红线机制可实现性：再审确认 S4a 继承 S3 修正后机制（源 grep + 写入字段行为断言），写入路径天然可断言、未重蹈 SQL-text 断言覆辙；唯一隐患（行为断言可能 trivially-true）与 P0-A 同源、已随之澄清。
状态：经上述收口后双轮 + 再审三关均过，标 Reviewed；仍待用户逐批实现授权（第 2 批，硬前置 S1 + S3 信号成熟）。
```

## 14. 复查方法

- 数据：查词事件按语言 / 时间窗读正确；local-only / 不进备份导出；source_content_origin 正确标注；账本 cursor 单调增量、升版重跑；migration 可回滚 + 结构化验证。
- 红线：源级 grep（repository/埋点不引用 memory_candidates.difficulty / learning_text 作信号）无命中；行为断言写入字段仅用户行为；埋点不外发、不写诊断敏感内容。
- 依赖：Data / Core 不 import LangoTraceAI；硬前置 S1 v27（migration 顺序 v28 在 v27 之后）。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceData/Tests/.../DictionaryLookupEvent/GRDBDictionaryLookupEventRepositoryTests.swift（写入 / 按语言时间窗读 / source_content_origin / local-only 不进导出 / 软删 / 迁移结构化验证）
  Packages/LangoTraceData/Tests/.../AnalysisLedger/GRDBAnalysisLedgerRepositoryTests.swift（cursor 增量 / 升版重跑 / 并发单调 / 窗口聚合）
  Packages/LangoTraceCore/Tests/.../SourceContentOriginTests.swift（枚举值类型，若落 Core）
  Packages/LangoTraceUI/Tests/.../Reading/DictionaryLookupCaptureTests.swift（埋点写入正确来源 / 不外发）
先失败用例：
  migrationCreatesLookupEventAndLedgerTables —— v28/v29 建表结构化验证（列/索引/约束命名）；预期失败：migration 尚不存在。
  lookupEventHasSourceOriginColumnDefaultingUserAuthored —— 约束 4（隔离再审 P0-A 修正）：列存在 + 默认 userAuthored；**不**测「AI 材料标 aiGenerated」（v1 无该数据路径）。
  lookupEventsExcludedFromBackupAndExport —— 约束 2：显式策略列 local-only 不进导出快照。
  cursorIncrementalRecomputeSkipsAlreadyAnalyzed —— 约束 3：高水位 cursor 跳过已分析。
  analyzerVersionBumpForcesRecompute —— 约束 3：升版重跑。
  cursorMonotonicUnderReentry —— 约束 5：并发/重入 cursor 单调不双进。
  lookupCaptureNeverReadsAIDifficulty —— 红线行为断言：写入字段不含 AI 生成内容。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceData
  swift test --package-path Packages/LangoTraceCore
  swift test --package-path Packages/LangoTraceUI
不新增单元测试的原因：不适用，全程 TDD。
```

## 16. 验证命令

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/check-docs.sh
```

含 v28+ migration，收口前三端构建 / 迁移验证按 CLAUDE.md 1.4 放 GitHub Actions。

## 17. 文档影响检查

- ADR-006 §9：账本 + cursor 首次建对，实施后回写。
- spec/007：查词事件 + 账本 / cursor 持久化分层 + backup_policy 登记（命中存储变化触发）。
- architecture/002：账本子系统 + 查词信号数据流（**接在 S1 LM01/Memory 基线之后**）。
- 架构备忘录 `2026-06-25-learner-memory-persistence-and-security-notes.md`：查词事件 FileProtection 接缝登记（P1-4）。
- idea-02 §4：查词信号落地回指。
- review：migration + 新子系统命中专项审查触发。
- 是否需要新 ADR：否——ADR-006 §9 账本规划的实施；查词捕获沿用 §4 用户行为信号决策。

## 18. 实施记录

2026-06-25 落地（dev 分支，三 Phase）：

- **Phase 1（查词事件，v28）**：Core `SourceContentOrigin`（前向接缝）+ `DictionaryLookupEvent`；migration `v28_create_dictionary_lookup_events`（显式 local-only/排除备份导出策略列、source_content_origin CHECK 默认 userAuthored、索引 (space,soft_deleted,occurred)）；`GRDBDictionaryLookupEventRepository`（record/窗口读 after cursor/软删，写策略字面值）。
- **Phase 2（账本，v29）**：migration `v29_create_analysis_ledger`（UNIQUE 键 + cursor_position）；`GRDBAnalysisLedgerRepository` + `AnalysisLedgerKey`（cursorPosition/advanceCursor 单调 upsert，升版=新行 cursor 0）。
- **Phase 3（埋点 + 装配）**：`ReadingLookupCaptureInput/Action` seam + EnvironmentValues entry；`ReadingDocumentStore.explainSelection` 触发捕获 + `reconnectLookupCapture`（环境注入，避免穿透所有 reading view 调用点）；`AppEnvironment.readingLookupCaptureAction`（`makeReadingLookupCaptureAction` 装配 `GRDBDictionaryLookupEventRepository`）+ 两处环境注入。
- **红线**：repository/埋点写入字段仅用户行为（term+时间+内容引用），不记 AI 内容；源级 grep + 行为断言。
- **TDD**：AnalysisSignalsTests(2) + AnalysisLedgerMigrationAndRepositoryTests(7，含迁移结构/local-only/source_origin/cursor 增量/升版/单调) + ReadingLookupCaptureTests(2) 先失败后实现。
- **验证**：轻量本机 Core 242 + Data 251 + UI 582 全绿（含 Han guard），lint 0 error，AppEnvironment 1298<1300；含 v28/v29 migration 的全量 Build & Test 经 GitHub Actions CI 绿。
- **scope-out 全兑现**：不动 derive()/不产 band/不做总览呈现/不决定信号加权/不启用 aiGenerated 过滤（均属 S4b）；source_content_origin v1 恒 userAuthored 前向接缝（P0-A）；查词事件显式 local-only 新类别（P1-B）；埋点宿主 = AI 解释 seam（P2-C）。
- **§17 文档影响已回写**：ADR-006 §9 实施进展（账本首次建对）、spec/007（查词+账本持久化分层登记）、architecture/002-system-map §4.10（查词捕获+账本数据流 + 测试入口）、persistence-security note（查词事件 FileProtection 接缝 §3）。

## 19. 完成标准

1. 第 3 节目标 1–4 均有代码 / 测试 / 文档证据。
2. **S1 已 merge**（硬前置，v28 建在 v27 之上）；Data / Core / UI 聚焦测试全绿；migration 可回滚 + 结构化验证；红线 grep + 行为断言无命中。
3. spec/007 + architecture/002 + ADR-006 §9 + 架构备忘录同步。
4. plan-vs-shipped 对账：查词事件表 + source_content_origin、账本 cursor 增量、local-only 持久化、埋点不外发——逐项核对；band / derive / 总览呈现作为有意 scope-out（属 S4b）记录。

## 20. 剩余风险

- **查词事件 local-only 不可恢复 + 导出策略开放（P1-B / 隔离再审）**：查词事件是「不可重算用户行为信号」新类别（无 practice 伪先例），v1 显式声明 local-only / 排除导出；设备迁移后查词历史丢失——S4b band 须能从剩余信号（S3 产出错误 + 练习 + 现存查词）优雅降级重估，不依赖完整查词历史。**开放产品问题**：查词事件是否应像 practice 主数据那样可导出，v1 默认否、留后续定。
- **传递污染在 v1 不成立（P0-A 修正）**：v1 阅读文档恒用户导入、无 AI 生成阅读源，故二阶闭环（level→生成文本→查词→band）v1 不存在；`source_content_origin` 是**前向 schema 接缝**（v1 恒 userAuthored）。**风险点**：未来若「学习材料可作阅读源」基础设施落地，须同步填 `aiGenerated` 分支 + 升约束 4 为 blocker + S4b 启用过滤——届时二阶闭环才需真防护。
- **账本首次落地复杂度（P2-2）**：cursor 增量重算的并发 / 重入 / 取消须在 document-open 边界收敛；做错会致信号重复计入或漏算。
- **硬前置 S1**：S4a 首张**分析账本**持久表（P3-1：Ability 本身 compute-on-read 不持久，ADR-006 §8）建在 S1 v27 + writer seam 之上；S1 未 merge 前 S4a 不可实现。
- **本环境（若 Linux）**无 Swift 工具链；migration 须 macOS / CI 验证。
