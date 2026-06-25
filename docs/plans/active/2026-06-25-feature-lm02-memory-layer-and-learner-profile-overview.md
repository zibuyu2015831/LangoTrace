# 任务方案：学习者模型 Memory 层地基 + 学习画像总览页（LM02 Slice 1）

状态：Draft
自审核状态：Reviewed（2026-06-25 隔离子代理双轮审查，4 项 P0/P1 阻塞已修订写回，2 个待决点已收口，见第 13 节）
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

本方案是 [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 学习者模型系列的第二份（LM02），接 LM01（已落地 Ability 知识覆盖）。2026-06-25 会话中，用户在「LM02 如何切片」上拍板：**第一份 LM02 plan = 总览页 + Memory 层地基**。据此本方案范围 = 净新增系统级 Memory 层（生活事实 / 目标「显式记住」+ 跨空间存储 + 统一治理删除入口）+ 三端「学习画像」总览页（呈现已有 Ability 覆盖 + 记忆复习统计 + 基础趋势 + Memory 事实）。盲点产出管线、Style 层、band 重估、分技能、AI 校准均为**后续 LM02 切片**，另拆 plan。

状态仍为 `Draft`：**范围已锁定，但进入生产代码实现前仍需 (1) 按 `docs/plans/plan-review-protocol.md` 完成严格自审核并推进到 `Reviewed`，(2) 用户实现授权。**

## 1. 需求或 bug 描述

ADR-006 §2 把 Learner Model 分 Ability / Memory / Style 三层，其中 **Memory 层 v1 = 「显式记住先行」**（生活事实 / 学习目标，系统级跨空间）。当前仅 Ability 层（知识覆盖）已落地（LM01），Memory / Style 尚不存在。同时 ADR-008 / `product-main-reference.md` §27 承诺「学习画像可见」，但**无任何面向用户的画像页**——评估对用户是黑箱。

本方案落地两件耦合的事：

1. **Memory 层数据地基**：系统级（横切语言空间）的「生活事实 / 目标」存储，用户**显式**保存（v1 无 AI 自动抽取），可查看、可删除，纳入导出 / 备份（ADR-006 §8）。
2. **学习画像总览页**：三端把「App 对你的了解」可视化——Ability 知识覆盖（LM01 已算）+ 记忆复习统计（plan-11 已有）+ Memory 生活事实 / 目标 + 基础趋势 + 统一治理（查看 / 删除 / 系统级重置）。

## 2. 现状描述

以下对照当前代码（2026-06-25 HEAD）核实：

- **LM01 包 `LangoTraceLearnerModel`** 只含 Ability 覆盖：`LearnerContextProvider` 协议唯一方法 `abilityCoverage(languageCode:) throws -> AbilityCoverage`；类型 `AbilityCoverage` / `AbilityCoverageEntry` / `AbilityCoverageKind`（wordPhrase/sentence）/ `LearnerEvidenceRef` / `LearnerSourceType`（仅 `.memoryItem`）。**无 Memory / Style 任何代码**。
- **`AppDatabase`** 有 `public var reader: DatabaseReader { databaseQueue }`（LM01 加），**无 writer seam**；LM01 §20 已预告「LM02 引入写入时补写 seam」。GRDB migration 头部当前为 **`v26_create_memory_item_infrastructure`**，下一条为 **v27**。
- **`memory_items`**（plan-10/11，词 / 句知识点 SRS 沉淀）含完整复习列（`review_state` / `review_rung` / `review_due_at` / `mastered_at`），`GRDBMemoryItemRepository.memoryStatistics(spaceID:now:)` 返回 `MemoryStatistics`（depositedThisWeek / dueCount / masteredCount）。**注意：`memory_items` 是「要学什么」的知识点库，不是 Memory 层的「生活事实」**——二者不同（ADR-006 §6 边界 / idea-01 §6），本方案 Memory 层是净新增。
- **`media_artifacts`** 用 `sync_policy` / `backup_policy` / `export_policy` 三个 TEXT 策略列。**真实枚举取值（已核实 `MediaArtifact.swift:114-129`）**：`MediaArtifactBackupPolicy = {excludedFromSystemBackup, includedInSystemBackup}`、`MediaArtifactSyncPolicy = {localOnly, syncCandidate, syncManaged}`、`MediaArtifactExportPolicy = {excludedByDefault, includedInUserExport, includedInRecoverableBackup}`——**不存在 `included` 字面值**；Memory 是准原始（ADR-006 §8），取值与 media TTS 派生资产的 `excludedByDefault` **相反**，不可机械照搬默认值（见 §12.1）。
- **`SettingsCapability` 在 `LangoTraceData`（非 UI）**：`SettingsCapability.swift:11-46` 定义 `Kind` 枚举（穷尽 `systemImage` switch）+ `CapabilityStatus`（ready/mockOnly/unavailable）+ status/summary/detail/nextRequirement/isReadOnly。capability **列表由 Data 三处 `settingsCapabilities(for:)` 构建**（`LearningContent.swift:216`、`:396`、`GRDBLearningContentRepositoryBridge.swift:207`）经 store 注入 UI。它建模「**带状态的配置能力**」——学习画像页不是配置能力，**不应**走该体系（见 §12.5）。三端设置入口：iPhone `PhoneMainSections.swift`、iPad `PadMainSections.swift`、macOS `MacWorkspaceContentView.swift` + 原生 Settings scene；iPad/macOS 侧栏有分区可加 peer 项。
- **`memoryStatistics(spaceID:now:)`**（`GRDBMemoryItemRepository.swift:204`）是 **per-space、`async throws`**、在 Data；而 LM01 `LearnerContextProvider.abilityCoverage` 是 **同步 `throws`**、按 language code。snapshot 聚合跨两种并发模型 + 三种分区键，契约见 §12.4。
- **`ExplanationLanguageMode.derive(from:)`** 仅 `ReadingDocumentStore` 消费；本方案**不碰** derive() 与 band 重估（属后续切片，ADR-006 §10 / idea-02 §14.2）。
- **文档基线缺口（已核实）**：`architecture/002-system-map.md` 与 `spec/007` **当前无任何 LM01 Ability / Learner 子系统条目**（LM01 done plan §17 声称回写但未落实，仅 `architecture/001` 登记了包边界）。本方案回写须**一并补 LM01 Ability 基线**，见 §17。
- E10（导入导出）Slice 1 已落地非敏感导出、Slice 2 deferred；Memory 表登记导出 / 备份策略，实际导出打包接线随 E10 后续切片。

## 3. 目标

1. **Memory 层 Core / 域模型**（在 `LangoTraceLearnerModel` 包）：`MemoryFact`（生活事实 / 目标）、`MemoryFactKind`（lifeFact / preference / goal / relationship）、`MemoryFactVisibility`（见 §12.2 决策）、provenance 复用 `LearnerEvidenceRef`，扩展 `LearnerSourceType` 容纳手动来源。
2. **系统级 GRDB 表 `learner_memory_facts`**（v27 migration，在 Data `AppDatabase`）：横切空间（**仓库首张系统级表，刻意无 space FK**，ADR-006 §3；可选 `source_entry_id` 弱引用 ON DELETE SET NULL，沿用 `memory_items.entry_id` 先例）、策略列**复用 Core 枚举、取真实字面值**：`sync_policy=localOnly` / `backup_policy=includedInSystemBackup` / `export_policy=includedInRecoverableBackup`（对齐 ADR-006 §8「Memory 准原始、纳入导出 + 可恢复备份」）、删除语义见 §12.3。
3. **Data 写 seam**：`AppDatabase` 新增 `public var writer: DatabaseWriter`（LM01 §20 预告的一次性小增量）。
4. **`GRDBLearnerMemoryRepository`**（新包内）：显式保存 / 列出 / 删除生活事实；系统级（不按空间）。
5. **扩展 `LearnerContextProvider`**：新增 `memoryFacts(...)` 读方法（系统级；现在有总览页 + 未来语伴两个真实消费者，解除 idea-01 §12.2 的 YAGNI 顾虑）。
6. **`LearnerProfileSnapshot` 聚合**（compute-on-read）：Ability 覆盖 + 记忆复习统计 + Memory 事实 + 基础趋势，供总览页渲染。
7. **三端学习画像总览页**：作为**独立设置内导航项**（**不走 `SettingsCapability` 配置能力体系**——画像非「带状态的配置能力」，避免触碰 mockOnly/ready 语义与 Data 三处 list builder）+ iPad/macOS 侧栏 peer；呈现温和总体水平（不展示降级）、Ability 覆盖、复习统计、Memory 事实列表、基础趋势。
8. **统一治理**：查看 + 删除单条 Memory 事实 + 系统级「重置 App 对我的了解」入口（v1 清 Memory 事实；Ability 是派生不独立清，见 §12.5）。
9. 全程纯本地、零外发、零 AI 校准、不碰 derive() / LanguageLevel、不做盲点 / Style / band / 分技能。

## 4. 范围

- **`Packages/LangoTraceLearnerModel`**：新增 `MemoryFact.swift`（域模型）、`GRDBLearnerMemoryRepository.swift`（系统级读写）、`LearnerProfileSnapshot.swift`（聚合投影）；扩展 `LearnerContextProvider.swift`（加 `memoryFacts`）、`LearnerSourceType`（加手动来源 case）。
- **`Packages/LangoTraceData`**：`AppDatabase` 新增 v27 migration `learner_memory_facts` + `public var writer: DatabaseWriter`。**不改 `SettingsCapability`**（画像页不走该体系，故不动 Data 三处 `settingsCapabilities` list builder 与 `Kind` 穷尽 switch）。
- **`Packages/LangoTraceCore`**：策略列复用既有 `MediaArtifactBackupPolicy/SyncPolicy/ExportPolicy`（取 §3 目标 2 的字面值子集）；如总览页呈现需共享值类型，按需新增，优先放 LearnerModel 包。
- **`Packages/LangoTraceUI`**：三端学习画像总览页（独立导航项 + iPad/macOS 侧栏 peer）+ Memory 事实增删 UI + 系统级重置确认流 + presentation model。
- **`LangoTraceApp/AppEnvironment.swift`**：装配 `GRDBLearnerMemoryRepository` + 扩展后的 provider（注入 reader + writer）。
- **`project.yml`**：无新增 package（沿用 LangoTraceLearnerModel）。
- 文档：ADR-006 实施回写、architecture/001（包获得 Memory 层）、architecture/002-system-map（Memory 子系统 + 治理流）、platform-page-inventory（三端新增学习画像页）、spec/007（`learner_memory_facts` schema + 策略列）、workflows/add-storage-migration 引用。

## 5. 不做什么

- **不做 Memory 自动抽取（AI 从记录蒸馏事实）**：v1 仅「显式记住」；自动抽取 = 外发，属 v2，须先过 ADR-006 §6 隐私前置闸门（已升格 ADR-006 §5，但本方案不实现外发管线）。**不建分析账本（intake ledger）**——账本服务自动抽取的状态追踪，v1 无抽取无需账本（ADR-006 §9）。
- **不做盲点产出管线 / 目标语产出语种检测 / 用户错误抽取**（净新增、信号稀疏、依赖练习评分；属后续 LM02 切片，idea-02 §13.4 / §14.2）。
- **不做 Style 层**（表面写作风格本地启发式属后续切片；认知风格 AI 校准属 v2 opt-in）。
- **不做 band 重估 / CEFR 评估 / 分技能估计 / 不碰 `ExplanationLanguageMode.derive()` 与 `LanguageLevel`**（ADR-006 §10 / idea-02 §14.2 推迟 v2，避免「体验在脚下漂移」）。
- **不做 onboarding 自评措辞软化**（决策 #6 细化的 UI 实现，独立关注点，留单独小切片）。
- **不做对话情景 per-space 记忆（`CompanionMemorySummary`）**（属语伴 LM03；本方案只做系统级生活事实 / 目标）。
- **不做 Memory 注入 prompt / 任何外发**：注入是语伴 LM03 的事，受 ADR-008 §6 / 决策 #10 约束；本方案纯本地，不发请求。
- **不做行动闭环「盲点→立即练」**（依赖盲点 + 练习评分；总览页 v1 只呈现，复习统计可链到既有复习队列）。
- **不做 Style v2 的 AI 请求 capability**（`AIRequestCapability` 不新增 case；零外发）。
- **不做实际导出 / 备份打包接线**（Memory 表登记策略列即可；打包随 E10 后续切片，本方案不碰 E10 引擎）。**硬接缝**：E10 实现可恢复备份时**必须**纳入 `learner_memory_facts`，否则删库 = 永久失忆（ADR-006 §8）——已写入 architecture note，见 §17。
- **不走 `SettingsCapability` 配置能力体系**（画像非配置能力；走独立导航项，见 §12.5）。
- **不做 Memory 字段级加密 / SQLCipher**（idea-01 §12.2 未决项）：v1 复用现有整库 `FileProtection`；字段级加密评估留架构备忘录，见 §7 约束 7。

## 6. 证据与决策依据

- ADR 证据：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §1（系统级横切 + 统一治理入口）、§2（Memory v1 = 显式记住先行）、§3（生活事实 / 目标系统级全局共享、无 space key）、§5/§6（隐私重定义 + 前置闸门：纯本地先行、自动抽取属 v2）、§7（删除三件套）、§8（Memory 准原始 → 纳入导出 + 备份、删除即永久 + tombstone）、§9（provenance 一等公民；Memory 行级、但 v1 无自动抽取故无账本）、影响节（LM02 = 总览页 + 水平信号演进 + 分技能占位）。
- idea 证据：`docs/idea/01-learner-model.md` §13.1（三层定义）、§13.2（分区键：Memory 生活事实系统级）、§13.3（删除三件套）、§12.2（YAGNI：union 接口待真实消费者——本方案总览页 + 语伴构成两个真实消费者，故扩展 provider 合法）、§12.5（visibility 默认 companionOnly vs 显式保存升 global——见 §12.2 决策）；`docs/idea/02-dynamic-proficiency-assessment.md` §7.1（总览页内容）、§14.2（总览页 v1 模块 = 温和总体水平 + 覆盖 + 趋势、不展示降级、不做第四 Tab、行动闭环后置）。
- **盲点张力 reconcile（idea-02 §14.2）**：idea-02 §14.2 把「常犯错误 / 盲点（来自用户产出）」列为「总览页 v1 即可交付的高价值部分」。本方案**不做盲点**，理由：盲点须来自用户目标语产出信号（idea-02 红线），而当前**无目标语产出语种检测、无练习评分、无用户错误抽取**（净新增且信号稀疏，idea-02 §13.4），LM01 也已推迟盲点。故盲点随后续 LM02 切片交付，本切片总览页**预留盲点分区**（presentation 占位），不违 idea-02 定稿、只是依赖未就绪。
- 代码证据：见第 2 节逐条核实。
- workflow 引用：本方案命中 [`add-storage-migration`](../../workflows/add-storage-migration.md)（v27 新表 + 策略列 + 写 seam + 软删 / tombstone + 导出策略登记），实现时按其检查清单；命中 [`add-platform-screen`](../../workflows/add-platform-screen.md)（三端新增总览页 + 设置 / 侧栏入口 + 三端共享 store）。不命中 AI Provider / TTS / Prompt（零外发、无 prompt）。

```text
证据能证明什么：ADR-006 §2 把 Memory v1 定为「显式记住先行」、§3 定为系统级、§8 定为纳入导出 / 备份；idea-02 §14.2 把总览页 v1 限为温和总体水平 + 覆盖 + 趋势。故本方案范围合法。
证据不能证明什么：ADR-006 未强制 v1 即做 tombstone（§7 的 tombstone 主防自动抽取重抽，v1 无抽取）——故 v1 删除语义可简化（见 §12.3 决策）；ADR-006 未定 visibility 默认（idea-01 §12.5 是 idea 层建议）——故 §12.2 把它作为自审 / 用户确认点。
迁移前提：v27 新表，无既有数据迁移（早期阶段、Memory 层首次落地）；Ability 覆盖读路径不受影响。
照搬风险：把 memory_items（知识点 SRS）当 Memory 生活事实会混淆两个不同子系统——已在第 2 节 / 第 5 节明确区分；本方案 Memory 事实是净新增表。
```

```text
是否需要 spike / probe / fixture / evidence：否——纯本地 GRDB 表 + UI，无外发、无新并发原语、无流式。fixture 为合成 Memory 事实，无真实用户敏感内容。
需要时的落点：不适用。
是否包含真实用户敏感内容：否——测试用合成事实。
如何验证和清理：合成 fixture，无需清理。
```

## 7. 约束映射与验证路径

### 约束 1：Memory 系统级、横切空间，不按 space 分区

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §3、`docs/idea/01-learner-model.md` §13.2
- 适用范围：`learner_memory_facts` schema 与查询
- 严重度：blocker
- 执行或验证方式：单元测试
- 验证提示：表无 `space_id` 主外键；事实在任意语言空间下可见；切换空间不改变事实集合；删某语言空间不级联删 Memory 事实（ADR-006 §7.1）。`source_entry_id` 为弱引用 ON DELETE SET NULL（事实可比来源记录长寿）。

### 约束 2：v1 仅显式记住，零外发，不触发决策 #10

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §5/§6、核心决策 #10、ADR-005
- 适用范围：整个 Memory 层 v1
- 严重度：blocker
- 执行或验证方式：代码审查 + 依赖方向检查
- 验证提示：`LangoTraceLearnerModel` 不 import 网络 / AI Provider，不依赖 `LangoTraceAI`；`rg -i "urlsession|urlrequest|provider|http" Packages/LangoTraceLearnerModel/Sources` 无网络命中；Memory 事实仅由用户显式动作写入，无任何自动抽取 / 外发路径。

### 约束 3：Memory 是准原始——纳入导出 / 备份、默认不同步

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §8、核心决策 #12
- 适用范围：`learner_memory_facts` 持久化策略
- 严重度：blocker
- 执行或验证方式：单元测试 + 代码审查
- 验证提示：表含 `sync_policy=localOnly` / `backup_policy=includedInSystemBackup` / `export_policy=includedInRecoverableBackup`（**真实枚举字面值**，复用 Core `MediaArtifact*Policy`）；与 Ability（compute-on-read 不持久不备份）按层分叉，不混为一谈。实际导出打包随 E10，本方案只登记策略 + architecture note 标 E10 硬接缝。

### 约束 4：统一治理入口——查看 / 删除 / 系统级重置

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §1/§7、`product-main-reference.md` §27
- 适用范围：总览页治理区
- 严重度：blocker
- 执行或验证方式：单元测试 + 人工验证
- 验证提示：总览页提供查看全部 Memory 事实、删除单条、系统级「重置 App 对我的了解」（v1 清空全部 Memory 事实）；重置有确认流，不误删用户的知识点库 memory_items（见 §12.5）。

### 约束 5：不展示降级、不打击信心

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §10、`docs/idea/02-dynamic-proficiency-assessment.md` §8.6/§14.2
- 适用范围：总览页水平 / 趋势呈现
- 严重度：warn
- 执行或验证方式：人工审查 + presentation model 测试
- 验证提示：总览页呈现温和总体水平（来自 onboarding level，措辞「约 X，持续校准」）+ 覆盖 / 成长 / 趋势；**绝不**展示「你从 B1 掉到 A2」式降级判决；v1 不重估 band，水平仅来自静态 level 的温和呈现。

### 约束 6：模块依赖方向清晰

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 影响节、`docs/architecture/001-initial-module-boundaries.md`
- 适用范围：Memory 层在包间位置
- 严重度：warn
- 执行或验证方式：编译依赖检查
- 验证提示：Memory 域模型 / repository 在 `LangoTraceLearnerModel`（deps 仅 Core + Data + GRDB）；Data / Core 不反向依赖本包；UI 经 provider / repository 协议取用；schema 仍由 Data `AppDatabase` 集中注册（LM01 §12.1 约定）。

### 约束 7：系统级 PII 静态安全表态（不实现字段级加密，但须声明）

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §5.2（系统级 = 最浓缩全人 PII、保留整库 FileProtection / 字段隔离）、`docs/idea/01-learner-model.md` §12.2（字段级加密 / SQLCipher 未决）
- 适用范围：`learner_memory_facts` 静态安全
- 严重度：warn
- 执行或验证方式：代码审查 + 剩余风险记录
- 验证提示：v1 复用现有整库 `FileProtection.completeUntilFirstUserAuthentication`（`AppDatabase.swift:1291`，iOS）；本方案**不**新增字段级加密 / SQLCipher，但须在 §20 + architecture note 显式表态该未决项，不可静默当作普通派生缓存。「纯本地零外发」覆盖外发边界，本约束补静态安全边界。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/MemoryFact.swift`（新增：`MemoryFact` / `MemoryFactKind` / `MemoryFactVisibility`）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/GRDBLearnerMemoryRepository.swift`（新增：系统级读写）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/LearnerProfileSnapshot.swift`（新增：聚合投影）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/LearnerContextProvider.swift`（扩展：`memoryFacts`；`LearnerSourceType` 加 case）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（v27 migration + `public var writer: DatabaseWriter { databaseQueue }`）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfileView.swift`（新增：三端共享学习画像页根视图）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfilePresentation.swift`（新增：presentation model + snapshot → 视图状态映射 + 不展示降级逻辑）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/`（三端入口接线：iPhone 设置内独立导航项、iPad/macOS 侧栏 peer；Memory 增删 / 系统级重置确认 UI。**不改 `SettingsCapability`**）
- `LangoTraceApp/AppEnvironment.swift`（装配 `GRDBLearnerMemoryRepository(writer:)` + 扩展后的 provider）
- 对应 `Tests` 目录新增测试（见第 15 节）

## 9. 参考的代码文件路径

- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/GRDBLearnerContextProvider.swift`（LM01 compute-on-read 模式参照）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMemoryItemRepository.swift`（repository 约定 + `memoryStatistics` 复用）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`（sync/backup/export 策略列模式参照）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift` / `PadMainSections.swift` / `MacWorkspaceContentView.swift` / `SettingsCapabilityDetailView.swift`（设置 / 侧栏入口模式参照）

## 10. 涉及的文档路径

- 本方案。
- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md)（实施后回写 LM02 Memory 层进展）。
- `docs/architecture/001-initial-module-boundaries.md`（LangoTraceLearnerModel 获得 Memory 层）。
- `docs/architecture/002-system-map.md`（Memory 子系统、数据流、统一治理流）。
- `docs/platform-page-inventory.md`（三端新增学习画像总览页）。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（`learner_memory_facts` schema + 按层持久化策略 + 导出 / 备份登记）。
- `docs/workflows/add-storage-migration.md` / `docs/workflows/add-platform-screen.md`（执行手册）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

> 多阶段、跨 Core/Data/LearnerModel/UI 包、含新 migration。分三 Phase。

### 12.1 Phase 1：Memory 层数据地基（净新增 v27 表 + 写 seam + repository）

1. LearnerModel 包域模型：`MemoryFact`（id / kind / text / salience / source / visibility / createdAt / sourceEntryID? / evidence）、`MemoryFactKind`（lifeFact / preference / goal / relationship）、`MemoryFactVisibility`（见 12.2，默认 global）；`LearnerSourceType` 加 `.manualMemory`（用户手动来源）。先写值类型测试红绿。
2. Data：先加 **`public var writer: DatabaseWriter { databaseQueue }`**（`DatabaseQueue` 同时满足 reader + writer，是 LM01 §20 预告的一次性增量）；再加 v27 migration `learner_memory_facts`（系统级，**无 space PK / 无 space FK——仓库首张系统级表，migration SQL 加注释说明刻意破例**；`source_entry_id TEXT REFERENCES entries(id) ON DELETE SET NULL`；`sync_policy` / `backup_policy` / `export_policy` TEXT 列 + CHECK 约束限真实枚举字面值；`soft_deleted_at REAL`，删除语义见 12.3）。**红绿次序：先 Data writer + v27 migration，再 LearnerModel repository**（否则 fixture 无表 / 无 writer，测试无法编译）。
3. LearnerModel 包 `GRDBLearnerMemoryRepository(writer:)`（`DatabaseWriter` 注入，读写同源）：`save` / `list(includeDeleted:)` / `softDelete(id:)`（单条可撤销）/ `resetAll()`（系统级重置 = 物理 DELETE，见 12.3）。先失败测试 → 实现。LearnerModel 测试用 `try AppDatabase(databaseQueue: DatabaseQueue())` 后取 `.writer` 注入。

### 12.2 visibility 默认（已收口：global）

idea-01 §12.5 建议 Memory 默认 `companionOnly`、按证据升全局，但那针对**自动抽取**的事实。本方案是**用户显式保存**——用户主动告知 App，前提不同。

- **已定（2026-06-25 自审收口）**：v1 显式保存默认 `visibility = global`（总览页可见、未来语伴可用，符合冷启动红利 ADR-006 §3）；保留 `companionOnly` 取值供 v2 自动抽取使用（届时按 idea-01 §12.5 默认 companionOnly）。
- 治理入口（查看 / 删除 / 重置）**不受 visibility 限制**——总览页治理区列出全部事实。
- 用户可在最终授权时推翻为 `companionOnly`；当前以 global 进入实现，已在 §20 / §13 记录。

### 12.3 删除语义（已收口：二段式 软删 + 重置硬删）

ADR-006 §7 称 Memory「删除即永久 + tombstone」，§8 证据说明 tombstone 主防 v2 自动抽取重抽（v1 无抽取）；ADR-006 §7.2「系统级重置 = 唯一全清入口」要求「全清」名实相符；ADR-006 §5.2 警示系统级集中 PII 静态安全。

- **已定（2026-06-25 自审收口）二段式**：
  - **单条删除** = `soft_deleted_at` 置位（可「查看已删除 / 撤销」，符合全库软删约定）。
  - **系统级「重置 App 对我的了解」** = **物理 DELETE**（`resetAll()` 真删，使「重置」名实相符，并消除「最浓缩 PII 软删后仍明文留库」的静态安全顾虑）。
- **tombstone（防重抽）随 v2 自动抽取落地**，v1 无抽取不建 tombstone 表。
- 验证（§15）：单条删除可见于 `list(includeDeleted: true)`；系统级重置后 `SELECT COUNT(*) FROM learner_memory_facts = 0`。

### 12.4 Phase 2：Provider 扩展 + 聚合投影（契约收口）

1. 扩展 `LearnerContextProvider`：加 `func memoryFacts(visibility:) throws -> [MemoryFact]`（系统级；默认返回全部供治理）。两个真实消费者（总览页 + 未来语伴）解除 idea-01 §12.2 YAGNI 顾虑——仍**不**做「难度 ∪ 事实」union 接口，分方法暴露。
2. **`LearnerProfileSnapshot` 聚合契约（解 P1-1 跨分区键 + P1-6 归属）**：
   - **签名**：`func learnerProfileSnapshot(spaceID: String, languageCode: String) async throws -> LearnerProfileSnapshot`——**显式接收当前 `spaceID` + `languageCode`**（调用方 UI store 从当前空间提供），snapshot 不自行猜分区键。
   - **并发**：`async`（因复习统计是 async）；Ability（sync）与 memoryFacts（sync）在 async 上下文内调用。
   - **归属**：放 `LangoTraceLearnerModel`；为读复习统计，本包依赖既有 `MemoryItemRepository` 协议（Data 所有）注入，**借用展示、不拥有**。
   - **来源标注**：snapshot 模型字段显式区分 **Learner-owned**（`abilityCoverage`、`memoryFacts`）vs **借用展示**（`reviewStatistics` 来自记忆库 per-space）。趋势 v1 简单（本周新增 / 覆盖计数）。纯只读无副作用。
   - **重置不影响复习统计**：系统级重置只删 `learner_memory_facts`，snapshot 的 `reviewStatistics`（来自 `memory_items`）不变（§15 加断言）。

### 12.5 Phase 3：三端学习画像总览页 + 统一治理

1. **入口（独立导航项，不走 SettingsCapability）**：iPhone 在设置内加一个**独立导航项**「学习画像」（NavigationLink 到 `LearnerProfileView`，**不**新增 `SettingsCapability.Kind` case——画像非「带状态的配置能力」，避免触碰 Data 三处 list builder + `CapabilityStatus` mockOnly/ready 语义）；iPad/macOS 侧栏新增 peer 项「学习画像」。遵循 idea-02 §14.2「设置内 / 个人画像区、不做第四 Tab」。本地化 key 按既有约定新增。
2. 页面内容（v1 克制）：温和总体水平（来自 onboarding level，措辞「约 X，持续校准」，**不展示降级**，约束 5）+ Ability 知识覆盖列表 + 复习统计（dueCount / masteredCount / 本周新增，可链到既有复习队列）+ Memory 生活事实 / 目标列表 + 基础趋势。
3. 治理：添加 Memory 事实（显式记住，枚举 kind + 文本，防注入）、删除单条、系统级「重置 App 对我的了解」（确认流，v1 清全部 Memory 事实）。
4. **重置范围澄清**：v1 Learner Model 系统级可清内容 = Memory 事实。**Ability 覆盖是 compute-on-read 派生自 `memory_items`（属记忆功能数据，非 Learner Model 所有），重置 App 了解不删 `memory_items`**；总览页文案明确「重置只清除 App 记住的关于你的生活事实，不影响你的学习记录与记忆库」。
5. App 装配 + presentation model 测试 + 三端状态覆盖。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-25
审核方式：隔离审查（general-purpose 子代理只读双轮审查 + 主会话用代码逐条核验写回）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地）
未使用隔离审查的原因：不适用，已使用隔离子代理。
发现摘要（子代理原始分级，主会话已用代码逐条核验）：
  P0 阻塞（4 项，均核验成立）：
  - [P0-1] 策略列字面值错误：方案写 backup/export=`included`，但真实枚举（MediaArtifact.swift:114-129）无此值——backup={excludedFromSystemBackup,includedInSystemBackup}、export={excludedByDefault,includedInUserExport,includedInRecoverableBackup}、sync={localOnly,...}。且 Memory 准原始与 media 派生资产默认相反，不可机械照搬。修订——§2/§3 目标2/§7 约束3/§12.1 改真实字面值 sync=localOnly/backup=includedInSystemBackup/export=includedInRecoverableBackup，复用 Core 枚举。
  - [P0-2] SettingsCapability 归属与范围错误：它在 LangoTraceData（非 UI），含 CapabilityStatus(ready/mockOnly/unavailable) + 穷尽 systemImage switch，list 由 Data 三处 settingsCapabilities 构建；画像页非「配置能力」，走该体系是范畴错误且严重低估改动面。修订——画像页改**独立设置内导航项 + iPad/macOS 侧栏 peer，不走 SettingsCapability**；§2/§3 目标7/§4/§8/§12.5 重写；不触动 Data list builder 与 SettingsCapabilityProjectionTests。
  - [P0-3] writer seam / 红绿次序空洞：AppDatabase 只有 reader 无 writer，LearnerModel repository 需写入。修订——§12.1 写死先 Data 加 writer+v27 再 LearnerModel repository；§15 红绿次序与测试构造（DatabaseQueue 注 .writer）明确。
  - [P1-1 实质 P0] snapshot 跨分区键聚合契约未闭环：memoryStatistics 是 per-space async、Ability 是语言级 sync、Memory 系统级。修订——§12.4 收口契约：snapshot(spaceID:languageCode:) async、归 LearnerModel、借用 MemoryItemRepository 读复习统计、字段标注 owned vs 借用。
  P1（核验成立）：
  - [P1-2] 002/spec-007 无 LM01 Ability 基线（LM01 回写欠账，grep 0 命中）。修订——§2/§17 记欠账，回写一并补 LM01 基线。
  - [P1-4] 删除语义与 ADR-006 §7「删除即永久」张力。收口——§12.3 二段式：单条软删可撤销 + 系统级重置硬删 COUNT=0；tombstone 随 v2。
  - [P1-5] 系统级 PII 静态安全缺表态。修订——§7 新增约束7：v1 复用整库 FileProtection、字段级加密入 architecture note + §20。
  - [P1-6] snapshot 借用复习统计的归属。修订——§12.4 字段区分 owned/借用 + §15 加「重置不改复习统计」断言。
  P2/P3：
  - [P2-1] 与 idea-02 §14.2「盲点是 v1 高价值项」张力。修订——§6 正面 reconcile：盲点依赖未就绪（无产出语种检测/练习评分），随后续切片，预留分区。
  - [P2-2] SettingsCapability 投影测试——随 P0-2 改独立导航项后不再触动，消解。
  - [P2-3] E10 必须纳入 Memory 可恢复备份。修订——升级写入 architecture note（§17）+ §20。
  - [P3-1] visibility 默认。收口——§12.2 = global（显式保存前提不同于自动抽取）。
  - [P3-2] UI 视图文件未预命名。修订——§8 预命名 LearnerProfileView/LearnerProfilePresentation。
写回修改：P0-1→§2/§3/§7/§12.1；P0-2→§2/§3/§4/§8/§12.5；P0-3→§12.1/§15；P1-1→§12.4；P1-2→§2/§17；P1-4→§12.3；P1-5→§7 约束7/§20；P1-6→§12.4/§15；P2-1→§6；P2-3→§17/§20；P3-1→§12.2；P3-2→§8。
新增 architecture note：2026-06-25-learner-memory-persistence-and-security-notes（E10 备份硬接缝 + 字段级加密未决）。
两个待决点收口：visibility=global（§12.2）；删除=二段式软删+重置硬删（§12.3）——均可用户最终授权时推翻，返工小。
仍需用户确认的问题：
  1. 接受 visibility=global 与二段式删除的收口取舍（或指定 companionOnly / 全软删）。
  2. 实现授权（Reviewed ≠ 批准实现；状态保持 Draft 待 go）。
是否允许进入实现：方案门禁已过（4 项 P0 + P1 已修订写回、2 待决点收口、自审核状态 Reviewed）；但状态仍为 Draft，须待用户实现授权方可进入 TDD 实现。
```

## 14. 复查方法

- 代码：LearnerModel 值类型 / repository / 投影测试全绿；`rg "memory_candidates|urlsession|provider" Packages/LangoTraceLearnerModel/Sources` 无命中（红线 + 零外发）；`git diff` 仅 v27 一条新 migration。
- 数据：Memory 事实系统级（跨空间可见、不随空间级联删）；`source_entry_id` 弱引用删源记录后置空、事实保留；策略列正确（localOnly / included / included）。
- 治理：删除单条与系统级重置语义正确；重置不误删 `memory_items`。
- 故障路径：空 Memory 返回空列表不崩溃；migration 失败回滚；并发写入串行化（DatabaseQueue）。
- UI：总览页空态（无事实 / 无覆盖时「继续记录以解锁画像」引导）、不展示降级、三端入口可达。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/MemoryFactModelTests.swift（值类型 / kind / visibility 默认 global）
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/GRDBLearnerMemoryRepositoryTests.swift（系统级读写 / 跨空间可见 / 单条软删可撤销 / 系统级重置 COUNT=0 / source_entry_id SET NULL / 策略列真实字面值）
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/LearnerProfileSnapshotTests.swift（聚合：覆盖 + 借用复习统计 + 事实 + 趋势；重置 Memory 后复习统计不变）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/（v27 migration 建表 + writer seam 暴露）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/LearnerProfile/（presentation model / 不展示降级 / 空态引导）
先失败用例（红绿次序：先 Data writer+v27 → 再 LearnerModel repository → UI）：
  （LearnerModel 值类型，可独立先行）MemoryFactModelTests.defaultVisibilityIsGlobal —— 预期失败：类型尚不存在，编译失败。
  （Data 先行）DataTests.appDatabaseExposesWriterAndV27MemoryFactsTable —— 预期失败：writer seam 与 v27 表尚不存在。
  （LearnerModel，依赖 Data writer+v27）GRDBLearnerMemoryRepositoryTests.factsAreSystemLevelVisibleAcrossSpaces —— 预期失败：repository 尚不存在 + 依赖 writer seam → 编译失败。
  （LearnerModel）GRDBLearnerMemoryRepositoryTests.deletingSpaceDoesNotCascadeMemoryFacts —— 预期失败：ADR-006 §7.1 删除语义未实现。
  （LearnerModel）GRDBLearnerMemoryRepositoryTests.systemResetHardDeletesAllFacts —— 预期失败：resetAll() 尚不存在（§12.3）。
  （LearnerModel）LearnerProfileSnapshotTests.systemResetDoesNotChangeReviewStatistics —— 预期失败：snapshot 聚合尚不存在（§12.4 借用展示边界）。
  （UI）LearnerProfilePresentationTests.neverShowsLevelDowngrade —— 预期失败：presentation model 尚不存在（约束 5）。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceLearnerModel
  swift test --package-path Packages/LangoTraceData
  swift test --package-path Packages/LangoTraceUI
注：画像页**不走 SettingsCapability**，故不触动 Data 的 SettingsCapabilityProjectionTests（无需改既有投影测试）。
不新增单元测试的原因（如适用）：不适用，全程 TDD。
```

## 16. 验证命令

```bash
# 工程生成（如 project.yml 改动）
xcodegen generate

# 聚焦（本机 / CI 轻量单包）
swift test --package-path Packages/LangoTraceLearnerModel
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
```

本方案含 **v27 新 migration + 三端 UI**，收口前的三端构建 / 全量验证按 CLAUDE.md 1.4 节放 GitHub Actions（仓库临时 public），不在本机跑 `scripts/verify.sh`。

## 17. 文档影响检查

- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md)：回写「LM02 Slice 1 已落地 Memory 层显式记住 + 学习画像总览页（band 重估 / 盲点 / Style 留后续切片）」（实施后）。
- `docs/architecture/001-initial-module-boundaries.md`：LangoTraceLearnerModel 获得 Memory 层 + 写 seam（命中包边界变化审查触发）。
- `docs/architecture/002-system-map.md`：**当前无任何 LM01 Learner / Ability 条目（LM01 回写欠账，已核实）**——本方案回写须**一并补 LM01 Ability 子系统基线 + 新增 Memory 子系统**、统一治理数据流（命中数据流变化触发）。
- `docs/platform-page-inventory.md`：三端新增「学习画像」总览页（独立导航项 + 侧栏 peer，非 SettingsCapability；命中平台页面变化触发）。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：**当前无 LM01 条目**——一并登记 LM01 Ability compute-on-read 不持久 + 新增 `learner_memory_facts` schema（系统级首张横切表、按层持久化策略真实字面值、导出 / 备份纳入）。
- **新增 architecture note** `docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`：记两条跨任务硬接缝——① **E10 实现可恢复备份时必须纳入 `learner_memory_facts`**（否则删库 = 永久失忆，ADR-006 §8）；② **系统级 PII 字段级加密 / SQLCipher**（idea-01 §12.2 未决，超出本切片）。
- review：新 migration + 新子系统 + 新页面 + LM01 文档欠账命中专项审查触发，实施后按 `docs/review/README.md` 创建 round 或记录跳过原因。
- 是否需要新 ADR：否——本方案是 ADR-006 的实施，沿用其全部决策；§12.2（visibility=global）/ §12.3（二段式删除）在 idea 层未定，作为方案内决策 + 用户最终确认，不构成 ADR 级反转。

## 18. 实施记录

待实现。

## 19. 完成标准

1. 第 3 节目标 1–9 均有代码 / 测试 / 文档证据。
2. LearnerModel / Data / UI 聚焦测试全绿；含 v27 migration 的三端构建经 CI Build & Test 绿。
3. ADR-006 实施回写、architecture/001 + 002、platform-page-inventory、spec/007 已同步。
4. plan-vs-shipped 对账：Memory 系统级表 + 写 seam + repository、provider memoryFacts、profile snapshot 聚合、三端总览页、治理（删除 / 重置）、不展示降级、零外发——逐项核对；盲点 / Style / band / 分技能 / onboarding 措辞 / 自动抽取作为有意 scope-down 记录。

## 20. 剩余风险

- **visibility / 删除语义已收口**（§12.2 visibility=global、§12.3 二段式软删 + 重置硬删）：作为方案内决策进入实现；用户最终授权时可推翻为 companionOnly / 全软删，返工小（单列默认值 + 删除路径）。
- **静态安全（系统级 PII）**：v1 复用整库 `FileProtection.completeUntilFirstUserAuthentication`（iOS）；字段级加密 / SQLCipher（idea-01 §12.2 未决）**不在本切片**，已记入 architecture note。系统级重置用硬删降低软删明文残留风险（§12.3）。
- **Memory 信号 v1 稀疏**：仅显式记住，事实量取决于用户主动性；总览页须优雅空态（「继续记录以解锁画像」）。自动抽取补全属 v2（隐私闸后）。
- **导出 / 备份接线未完成（E10 硬接缝）**：Memory 表登记策略列（`includedInRecoverableBackup`），但实际导出打包依赖 E10 后续切片（E10 Slice 2 deferred）；删库 = 永久失忆是最痛 PII——**E10 必须纳入 `learner_memory_facts`**，已升级写入 architecture note 防跨任务丢失。
- **LM01 文档欠账**：002 / spec-007 无 LM01 Ability 基线（LM01 §17 回写未落实）；本方案回写一并补齐（§17）。
- **总览页与未来切片的接缝**：盲点 / 分技能 / band / Style 后续接入同一页；本方案 presentation model 预留分区（含盲点占位），降低返工。
- **语伴 LM03 对齐**：本方案 Memory 系统级生活事实与 `2026-05-25` 语伴备忘录的 per-space 记忆假设的对齐留 LM03（对话情景 per-space、生活事实系统级，ADR-006 §7.1 已定方向）。
- **本环境（若 Linux）**无 Swift 工具链，全部测试须 macOS / GitHub Actions；新 migration + 三端 UI 尤需 CI 三端构建确认。
```

