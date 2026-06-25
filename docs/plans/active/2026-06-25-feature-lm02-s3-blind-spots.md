# 任务方案：盲点（常犯错误清单，源自练习机械 diff）（LM02 Slice 3）

状态：Draft
自审核状态：**Reviewed（双轮过；2026-06-25 收口第二轮 2 P1）**——[P1-1] 红线守卫测试机制已定稿 = **行为断言（sentinel）+ §14 既有源级 grep 守卫**（弃不可实现的 SQL 文本断言）；[P1-2] compute-on-read 规模上限已定稿 = **`ORDER BY created_at DESC LIMIT 200`**（约束 5 升 blocker + 先失败测试）。P2-1/P2-2/P3-1/P3-2 同次并入。详见第 13 节第三个自审块。**仍待用户实现授权**。
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

本方案是 [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 学习者模型系列 LM02 的第三份切片（S3），接 LM01（Ability 覆盖，已落地）、LM02-S1（Memory + 总览页，Draft/Reviewed）、LM02-S2（Style，Draft/Reviewed）。2026-06-25 会话用户拍板「将所有实施拆分成 active plan，再分批实现」「本地优先第一批先做」。据 [LM02 切片拆解文档](2026-06-25-docs-lm02-remaining-slices-decomposition.md) S3 边界：从**用户目标语产出 + 机械 diff** 聚合「常犯错误 / 学习盲点」清单，呈现于总览页盲点分区（S1 已预留）+ 可链行动闭环（加入记忆库 / 复习）。**compute-on-read、零外发、不碰 derive()**。

状态 `Draft`：本轮仅拆 plan，**实现授权尚未给出**（用户「先只拆 plan、暂不授权任何实现」）。进入实现前仍需完成 plan-review-protocol 双轮自审并经用户授权。

## 1. 需求或 bug 描述

ADR-006 影响节把「盲点 / 常犯错误」归 Ability 层（按语言）；idea-02 §7.1 / §14.2 把盲点列为**总览页 v1 高价值行动项**——展示用户**自己的**重复错误并可一键去练，是「行动价值」而非「水平判决」。LM01 / S1 都已**预留盲点分区但未填充**（S1 §6 reconcile：盲点依赖用户目标语产出信号，当时判定未就绪而推迟）。

**关键新发现（降低净新增成本）**：仓库**已存在**红线合规的盲点信号源——`practice_text_attempts`（听写 / 回译练习的用户产出 + 机械 diff）。S3 v1 从既有听写 diff 抽取结构化错误模式，**无须**新练习评分、**无须**AI 判定，即可填充盲点分区 + 行动闭环。

## 2. 现状描述

以下对照当前代码（2026-06-25 HEAD）逐条核实：

- **`practice_text_attempts` 表**（v23，`AppDatabase.swift:796`）：`attempt_text`（用户产出）、`reference_text_snapshot`（目标参考）、`diff_difference_count INTEGER`、`diff_summary_json TEXT`、`exercise_type CHECK IN ('dictation','backtranslation')`、`language_space_id`、`soft_deleted_at`、`created_at`。**关键约束**：`diff_difference_count` / `diff_summary_json` **仅听写（dictation）写值，回译（backtranslation）留 nil**（`PracticeTextAttempt.swift:11-13` 注释「回译参考不判对错」核实）。→ **S3 v1 机械 diff 信号只来自 dictation attempts**。
- **`PracticeTextAttempt` Core 模型**（`PracticeTextAttempt.swift:14`）：明确「用户练习证据 = 本地主数据、非可重建缓存、默认不同步 / 不导出 / 不外发」（注释 §5/§7 constraint 3）——盲点读它是读**用户产出**，红线合规。
- **AI 生成物边界（§4 红线，S3 禁读）**：`PracticeBacktranslationReviewResult.observations`（`PracticeBacktranslationReview.swift:50`）是**回译 AI 点评**（现象 + 解释），AI 判定 → ADR-006 §4 禁用作信号证据，**S3 不读**；`memory_candidates.difficulty`、`learning_materials.learning_text` 同禁。
- **`diff_summary_json` 形态**：由 `PracticeDictationDiff.swift`（Core）产出的机械 diff 摘要（逐 token / 段差异）。其结构化解析形态是 S3 待决（§12.2）。
- **记忆库复习队列就绪（行动闭环可接）**：`memory_items`（plan-10/11）含完整 SRS 复习列 + `GRDBMemoryItemRepository.memoryStatistics`；S1 已接复习统计。S3 行动闭环「盲点 → 加入记忆库 / 去练」可接既有 deposit + 复习队列。
- **LM01 compute-on-read 先例**（`GRDBLearnerContextProvider.swift`）：`reader.read{}` 读源表 JOIN `language_spaces` 解析 `target_language_code`，无 writer / 无 migration，源删除经 active 过滤天然级联，严守 §4 红线只读用户产出。**S3 镜像此模式**。
- **总览页盲点分区**（S1 `LearnerProfilePresentation` 已预留占位，S1 §20）：S3 填充该分区 + 行动闭环 UI。
- **Ability 按 language code**（ADR-006 §3）：盲点是「语言级事实」（§3 内部二分：常犯错误 / 语法盲点 = 按语言），故按 `target_language_code` 聚合，跨同语言多空间共享。

## 3. 目标

1. **盲点域模型**（`LangoTraceLearnerModel` 包）：`BlindSpot`（错误模式：kind + 代表样例 + 出现频次 + 证据集 + 语言码）、`BlindSpotKind` = **直接映射 `PracticeDictationDiff.SegmentKind` 的 `{missing, changed, extra}`**（P1-1：代码已有确定机械分型，不另造命名、不做语言学分类）；provenance 用 `[LearnerEvidenceRef]` 表达**证据集分布**（每条支撑 attempt 一个 ref，weight 沿用 reserved；ADR-006 §9：Ability/Style 证据是分布非单 FK，不退化为单 FK）；`LearnerSourceType` 加 `.practiceTextAttempt`（**P3-2：`LearnerEvidenceRef` 纯内存、不落库，加 case 无 raw-value 持久化兼容负担**）。
2. **`LearnerBlindSpotProvider` 读 seam**（新协议）：`func blindSpots(languageCode:) throws -> [BlindSpot]`（按语言、compute-on-read、纯本地读）。与 Ability/Memory/Style provider **并列分方法暴露**，不做 union（idea-01 §12.2）。
3. **`GRDBLearnerBlindSpotProvider`**（compute-on-read，镜像 LM01）：`reader.read{}` 读 `practice_text_attempts` JOIN `language_spaces`，`WHERE exercise_type = 'dictation' AND diff_summary_json IS NOT NULL AND soft_deleted_at IS NULL AND ls.deleted_at IS NULL AND ls.target_language_code = ?`，**读 `attempt_text` + `reference_text_snapshot` 在读路径重跑 `PracticeDictationDiff.compare()` 取词文本**（P0-2：持久 `diff_summary_json` 只存 kind + offset、无词文本，须重算才能做频次聚合 + 代表样例；`diff_summary_json` 仅作存在性过滤 / 校验）。**只读用户产出 + 机械 diff，SQL 仅 SELECT `practice_text_attempts` 白名单列 + JOIN `language_spaces`，绝不 JOIN `memory_candidates` / 不读 `learning_text`（§4 红线）。无 writer、无 migration、无外发。**
4. **总览页盲点分区填充（v1 = 纯展示 + 跳既有复习入口）**：S1 落地后填充其盲点分区，呈现「重复练习错误模式（来自听写练习）」（用户自己的错误、诚实标注练习来源，**非水平判决**）。**「加入记忆库」deposit 砍出 v1**（P0-1：`memory_items` 当前 `CHECK source_kind IN ('candidate')` + `difficulty NOT NULL` + 幂等键建在 `source_candidate_id`，盲点 deposit 需独立 migration + Core 模型扩展，超出本切片零迁移边界）→ 留 §12.2② 后续子增量。v1 仅链到既有复习页（若有现成入口）。
5. 全程**纯本地、零外发、零 AI 判定、零迁移、零 writer、不碰 derive() / LanguageLevel**。

## 4. 范围

- **`Packages/LangoTraceLearnerModel`**：新增 `BlindSpot.swift`（域模型）、`LearnerBlindSpotProvider.swift`（协议）、`GRDBLearnerBlindSpotProvider.swift`（compute-on-read + diff 解析聚合）；扩展 `LearnerSourceType`（加 `.practiceTextAttempt`）。
- **`Packages/LangoTraceCore`**：若 `diff_summary_json` 解析需共享值类型，复用既有 `PracticeDictationDiff` 结构；不新增 Core 类型除非必要。
- **`Packages/LangoTraceUI`**：填充 S1 `LearnerProfilePresentation` / `LearnerProfileView` 盲点分区（**由 S1 创建，S3 立项时尚不存在于磁盘**，P1-3：S3 Phase 2 硬阻塞于 S1 落地）+ v1 纯展示 + 跳既有复习入口（**不含 deposit**，P0-1）。
- **`LangoTraceApp/AppEnvironment.swift`**：装配 `GRDBLearnerBlindSpotProvider(reader:)`。
- **`project.yml`**：无新增 package。
- 文档：ADR-006 实施回写、architecture/001（包获得盲点 read）、architecture/002-system-map（盲点子系统 compute-on-read 数据流）、platform-page-inventory（总览页盲点分区填充 + 行动闭环）、idea-02 §7.1 盲点页落地回指、决策拆解文档标注「→ 已拆 active plan」。

## 5. 不做什么

- **不做「盲点 → 加入记忆库」deposit（P0-1，砍出 v1）**：`memory_items` 当前 schema `CHECK source_kind IN ('candidate')` + 幂等键建在 `source_candidate_id` + `difficulty NOT NULL`，盲点 deposit 需独立 migration（扩 `source_kind` CHECK + `MemoryItemSourceKind` 新 case + `MemoryDepositInput` 允许非 candidate 来源 + 幂等键重设计 + difficulty 缺省策略）+ Core 模型扩展，**超出本切片零迁移边界** → 留后续子增量（命中 add-storage-migration，须用户单独确认）。v1 盲点仅展示 + 跳既有复习入口。
- **不做新练习评分 / 新打分管线**：S3 v1 只消费**既有** `practice_text_attempts` dictation diff；不新增任何评分。
- **不读 AI 判定**：`PracticeBacktranslationReviewResult.observations`（回译 AI 点评）、`memory_candidates.difficulty`、`learning_materials.learning_text` 一律不读（§4 红线）。
- **不做自由产出语种检测 / Entry 目标语写作错误抽取**：自由产出（用户在 Entry 用目标语写作的错误）须目标语产出语种检测（净新增、信号稀疏，idea-02 §13.4）→ 作 S3 **后续子增量**，v1 只用练习 dictation diff（见 §12.3）。
- **不做回译 diff 作错误信号**：回译 `diff_*` 字段为 nil（不判对错），S3 v1 信号源仅 dictation。
- **不做 band 重估 / 水平判决 / 降级**（属 S4，ADR-006 §10）：盲点展示用户**自己的错误**（行动价值），不展示「你水平低 / 降级」。
- **不做持久化盲点表 / migration**：v1 盲点是可重算真派生（从 attempts 机械重算，类比 Ability），compute-on-read、**无新表、无 writer**。
- **不做外发 / AI 校准盲点**（零外发，不新增 `AIRequestCapability`）。

## 6. 证据与决策依据

- ADR 证据：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §2（Ability：常犯错误属能力层、用户产出证据）、§3（常犯错误 / 语法盲点按 language code）、§4（证据红线：用户产出 / 行为，AI 判定禁用——dictation diff 是机械 diff 非 AI 判定，合规；observations 是 AI 判定，禁用）、§8（Ability 真派生不持久）、§9（provenance 证据集）、§10（不展示降级——盲点展示自己的错误，非降级判决）。
- idea 证据：`docs/idea/02-dynamic-proficiency-assessment.md` §4（有效证据 = 用户产出 / 行为）、§7.1（盲点页）、§13.1（闭环红线）、§14.2（盲点是总览页 v1 高价值项）；`docs/plans/active/2026-06-25-docs-lm02-remaining-slices-decomposition.md`（S3 边界 / 既有信号发现 / 待决 / 风险）；S1 §6（盲点张力 reconcile：依赖未就绪而预留分区——S3 现兑现）。
- 代码证据：见第 2 节逐条核实（practice_text_attempts 字段、dictation-only diff、observations 禁读、LM01 compute-on-read 镜像、复习队列就绪）。
- workflow 引用：**v1 不命中** add-storage-migration（已砍 deposit、无新表 / 无 migration / 无 writer，P0-1）；不命中 AI Provider / TTS / Prompt（零外发）；**轻度命中** [`add-platform-screen`](../../workflows/add-platform-screen.md)（填充 S1 总览页盲点分区纯展示，非新页面）。**注**：deposit 子增量（后续）将命中 add-storage-migration。

```text
证据能证明什么：practice_text_attempts 提供用户产出（attempt_text）+ 机械 diff（diff_summary_json，仅 dictation），是 ADR-006 §4 合规盲点信号（用户产出 + 机械 diff，非 AI 判定）；idea-02 §14.2 把盲点列为总览页 v1 高价值；LM01 已证 compute-on-read 读源表派生 Learner 信号合规。故 S3 技术路径合法。
证据不能证明什么：dictation diff 反映的是「转写差异」（可能含听错 / 拼写滑误，不全是语法 / 用法盲点）——故 v1 盲点须诚实标注为「重复练习错误模式」，不可过度宣称为完整语法诊断（§7 约束 4 / §20 效度风险）。idea-02 未强制 v1 即接「→ 立即练」行动闭环——故行动闭环 v1 形态（接练 vs 仅展示 + 加入记忆库）是 §12.2 待决。
迁移前提：v1 无新表 / 无迁移；practice_text_attempts 读路径只读不改。
照搬风险：把回译 diff 当信号（其 diff 字段为 nil）、或把 observations（AI 判定）当信号——已在 §2 / §5 明确排除。
```

```text
是否需要 spike / probe / fixture / evidence：否——纯本地 GRDB 只读聚合，无外发 / 无新表 / 无流式。fixture 为合成 dictation attempts + diff JSON，无真实用户敏感内容。
需要时的落点：不适用。
是否包含真实用户敏感内容：否——合成 fixture。
如何验证和清理：合成 fixture，无需清理。
```

## 7. 约束映射与验证路径

### 约束 1：盲点 compute-on-read、按语言、零持久化（v1）

- 来源：ADR-006 §3/§8，LM01 compute-on-read 先例
- 适用范围：`GRDBLearnerBlindSpotProvider` 读路径
- 严重度：blocker
- 执行或验证方式：单元测试 + 代码审查
- 验证提示：`blindSpots(languageCode:)` 按 `target_language_code` 聚合（同语言多空间共享一份）；`reader.read{}` 只读 / 写零行 / 无新表 / `git diff` 无 migration；删空间 / 软删 attempt 后从剩余 attempts 重算（源删除经 active 过滤天然级联）。

### 约束 2：证据红线——用户产出 + 机械 diff，禁 AI 判定

- 来源：ADR-006 §4、idea-02 §13.1
- 适用范围：信号取源
- 严重度：blocker
- 执行或验证方式：单元测试（行为断言）+ 代码审查
- 验证提示：只读 `practice_text_attempts`（`attempt_text` / `diff_summary_json`，dictation）；**行为断言**（镜像 LM01）：fixture seed dictation attempt + 一条 `PracticeBacktranslationReviewResult.observations` / `memory_candidates` 含唯一 AI-only token，断言该 token 不进盲点；红线 grep 含 `observations|memory_candidates|learning_text`。

### 约束 3：仅 dictation 信号（回译 diff 为 nil）

- 来源：`PracticeTextAttempt.swift:11-13`、`AppDatabase.swift:804-805`
- 适用范围：SQL 过滤
- 严重度：blocker
- 执行或验证方式：单元测试
- 验证提示：SQL `WHERE exercise_type = 'dictation' AND diff_summary_json IS NOT NULL`；fixture 含 backtranslation attempt（diff 为 nil）断言其不进盲点聚合。

### 约束 4：盲点诚实标注（练习来源限定）、不下水平判决 / 降级

- 来源：ADR-006 §10、idea-02 §4.2/§7.1/§8.6/§14.2
- 适用范围：总览页盲点分区呈现
- 严重度：blocker
- 执行或验证方式：presentation 测试 + 人工审查
- 验证提示：dictation diff 含听力辨音误差 + 拼写滑误，**非纯语法 / 用法盲点**（idea-02 §4.1 把听写归「产出 / 理解」练习信号，与「写作盲点」并列但不等同）→ v1 分区文案定性为「**重复练习错误模式（来自听写练习）**」，**不**用无限定的「盲点 / blind spot」裸标签冒充完整语法诊断；**绝不**呈现「你水平 X / 从 B1 降 A2」。presentation 测试断言：① 无 level/downgrade 文案键；② 分区标题键含练习来源限定。真正语法盲点须自由产出信号（§12.2③ 子增量），dictation 是其代理 / 占位信号。

### 约束 5（性能）：compute-on-read 读路径全量重算的规模边界（v1 已定上限）

- 来源：P0-2 重算形态、`PracticeDictationDiff.compare()`（O(n²) LCS、`maxInputLength=2000`）
- 适用范围：`GRDBLearnerBlindSpotProvider` 读路径
- 严重度：**blocker**（第二轮 P1-2 收口：由 warn 升 blocker——这是本切片唯一新增工程风险，不可只文档化不测）
- 执行或验证方式：单元测试（先失败规模断言）+ 代码审查
- 验证提示：**v1 上限定稿 = `ORDER BY created_at DESC LIMIT 200`**（按 `target_language_code`、读路径内 SQL 截断、**无缓存 / 无新表 / 无迁移**，与白名单 SQL 兼容）。仅对最近 200 条 dictation attempts 重跑 `compare()`。选 LIMIT 而非缓存：缓存需生命周期 / 失效或持久化（近迁移），破坏本切片零迁移边界；LIMIT 是无状态、可 TDD 的硬上限。N=200 依据：dictation 文本通常 ≤300 字符，200×300² ≈ 18M ops（进页可接受）；极端 maxInputLength=2000 仅作硬天花板、罕触。先失败测试见 §15 `recomputeBoundedToRecentNAttempts`。若未来 profiling 显示进页延迟超标，再引入「缓存最近一次（键 = max(created_at)+count）」作后续优化（§20）。

### 约束 6：模块依赖方向清晰

- 来源：ADR-006 影响节、`docs/architecture/001-initial-module-boundaries.md`
- 适用范围：盲点 read 在包间位置
- 严重度：warn
- 执行或验证方式：编译依赖检查
- 验证提示：盲点域模型 / provider 在 `LangoTraceLearnerModel`（deps 仅 Core + Data + GRDB）；不 import 网络 / `LangoTraceAI`；UI 经 provider 协议取用；不新增 schema。

### 约束 7：S1 先落地（盲点分区归宿）

- 来源：决策拆解「共同前置」、ADR-006 §1
- 适用范围：S3 排序前置
- 严重度：blocker
- 执行或验证方式：排序门控
- 验证提示：S3 填充 S1 预留的盲点分区 + 同页治理；S3 provider seam 本身不依赖 S1 代码，但产品上盲点呈现归宿是 S1 总览页。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/BlindSpot.swift`（新增：`BlindSpot` / `BlindSpotKind`）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/LearnerBlindSpotProvider.swift`（新增：协议）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/GRDBLearnerBlindSpotProvider.swift`（新增：compute-on-read + diff 解析聚合）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/LearnerContextProvider.swift`（扩展 `LearnerSourceType` 加 `.practiceTextAttempt`）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfilePresentation.swift`（填充盲点分区 presentation + 行动闭环映射）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfileView.swift`（盲点分区 UI + 加入记忆库 / 跳复习）
- `LangoTraceApp/AppEnvironment.swift`（装配 `GRDBLearnerBlindSpotProvider(reader:)`）
- 对应 `Tests` 目录新增测试（见第 15 节）

## 9. 参考的代码文件路径

- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/GRDBLearnerContextProvider.swift`（compute-on-read 镜像模板）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeTextAttempt.swift` / `PracticeDictationDiff.swift`（attempt 模型 + diff 结构）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`（practice_text_attempts 读约定参照）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMemoryItemRepository.swift`（行动闭环 deposit + 复习队列参照）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfileView.swift` / `LearnerProfilePresentation.swift`（**由 S1 创建，S3 立项时尚不存在于磁盘**——S3 Phase 2 硬阻塞于 S1 落地，P1-3）

## 10. 涉及的文档路径

- 本方案。
- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md)（实施后回写盲点 v1 已落地）。
- `docs/architecture/001-initial-module-boundaries.md`（包获得盲点 read）。
- `docs/architecture/002-system-map.md`（盲点子系统 compute-on-read 数据流）。
- `docs/platform-page-inventory.md`（总览页盲点分区填充 + 行动闭环）。
- `docs/idea/02-dynamic-proficiency-assessment.md` §7.1（盲点页落地回指）。
- `docs/plans/active/2026-06-25-docs-lm02-remaining-slices-decomposition.md`（S3 标注「→ 已拆 active plan」）。
- `docs/plans/active/2026-06-11-00-docs-series-progress.md`（状态总表登记 S3）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

> 单包为主（LearnerModel）+ UI 填充。分两 Phase + 待决收口。

### 12.1 Phase 1：盲点域模型 + compute-on-read provider（镜像 LM01）

1. LearnerModel 域模型：`BlindSpot`（languageCode + kind + 代表样例文本 + occurrenceCount + 证据集 `[LearnerEvidenceRef]`，证据集采样上限同 S2）；`BlindSpotKind`（v1 来自 diff 的结构化类别，见 §12.2）；`LearnerSourceType` 加 `.practiceTextAttempt`。先写值类型测试红绿。
2. `LearnerBlindSpotProvider` 协议：`func blindSpots(languageCode:) throws -> [BlindSpot]`。
3. `GRDBLearnerBlindSpotProvider(reader:)`（镜像 `GRDBLearnerContextProvider`）：`reader.read{}` 读 `practice_text_attempts` JOIN `language_spaces`，`WHERE exercise_type='dictation' AND diff_summary_json IS NOT NULL AND soft_deleted_at IS NULL AND ls.deleted_at IS NULL AND ls.target_language_code = ? ORDER BY created_at DESC LIMIT 200`（**P1-2 收口：SQL 内截断最近 200 条，约束 5**）；**对每行 `attempt_text` + `reference_text_snapshot` 重跑 `PracticeDictationDiff.compare()`**（P0-2：持久 summary 无词文本，须重算取 `Segment.attemptText` / `referenceText`），按 `SegmentKind` + 词文本做频次聚合（见 §12.2）。**只读用户产出 + 机械 diff，SQL 仅 SELECT `practice_text_attempts` 白名单列 + JOIN `language_spaces`（不 JOIN `memory_candidates`、不读 `learning_text`，§4 红线）。** 先失败测试 → 实现。注意 `compare()` O(n²) LCS + `maxInputLength=2000`，LIMIT 200 即规模硬上限（约束 5）。

### 12.2 错误模式抽取形态 + 行动闭环（待决收口）

- **① diff → 结构化盲点的形态**：`BlindSpotKind` v1 **定稿 = `{missing, changed, extra}`，直接映射 `PracticeDictationDiff.SegmentKind`**（P1-1，不另造命名、不做语言学分类——语言学分类近 AI 判定）；聚合用**轻量频次聚合**（重跑 compare 后按「kind + 词文本」重复计数 + 代表样例）。聚合策略（按词 vs 按参考片段）仍可自审微调，但 kind 枚举不再待决。
- **①' 规模上限（第二轮 P1-2 收口，定稿）**：重算输入集 = `ORDER BY created_at DESC LIMIT 200` 截断的最近 200 条 dictation attempts（约束 5）。选 LIMIT 而非缓存 / session 去重：无状态、零迁移、可先失败测试。先失败测试 `recomputeBoundedToRecentNAttempts`（§15）。
- **② 行动闭环 v1 形态（已据 P0-1 收口）**：**v1 = 纯展示 + 跳既有复习入口；「加入记忆库」deposit 砍出 v1**（`memory_items` schema 仅接 candidate 来源 + difficulty NOT NULL，盲点 deposit 需独立 migration + Core 扩展，§5）→ 留后续子增量，届时单拆方案、命中 add-storage-migration、用户确认。「针对性练习生成」依赖 AI = 外发，更后置。
- **③ 自由产出语种检测是否进 v1（待决）**：**取舍 = 否**，留子增量（idea-02 §13.4 信号稀疏 + 净新增语种检测）。v1 仅 dictation diff——这是 v1 盲点覆盖面受限的根因（§20）。

### 12.3 Phase 2（硬阻塞于 S1 落地）：总览页盲点分区填充（纯展示）

1. **前置**：S1 的 `LearnerProfilePresentation` / `LearnerProfileView` 须先 merge（S3 立项时尚不存在于磁盘，P1-3）。
2. 填充 S1 盲点分区（`BlindSpot[]` → 「重复练习错误模式（来自听写练习）」列表 + 频次 + 代表样例；**诚实标注练习来源、不下水平判决 / 降级**，约束 4）。
3. `LearnerProfileView` 盲点分区 UI：v1 纯展示 + 「去复习」链到既有复习入口（**v1 无 deposit**，P0-1）；空态（无 dictation 练习时「做几次听写练习以解锁错误模式分析」引导）。
4. App 装配 + presentation 测试 + 三端状态覆盖。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-25
审核方式：隔离子代理第一轮架构审查 + 主会话用当前 HEAD 代码逐条核验写回
审核轮次：第一轮（架构，已覆盖大量测试 / 红线 / schema / 落地性问题）；第二轮（测试 / 安全 / 落地补充）留本地优先第一批实现授权前执行
本轮范围说明：用户 2026-06-25 仅授权「拆 plan、暂不实现」，故 plan 先到「第一轮 Reviewed」；与 S4/LM03 一致——各切片实现批次前补完整双轮自审。
发现摘要（子代理原始分级，主会话已用代码逐条核验成立）：
  P0（阻塞，均核验成立）：
  - [P0-1] 行动闭环 deposit 与「零迁移」自相矛盾、且 schema 物理拒绝：memory_items CHECK source_kind IN('candidate')（AppDatabaseMemoryMigration.swift:33）+ 幂等键建在 source_candidate_id + difficulty NOT NULL。修订——§3目标4/§4/§5/§6/§12.2②/§19/§20：deposit 砍出 v1（留需 migration 的子增量），v1 = 纯展示 + 跳既有复习。
  - [P0-2] diff_summary_json 无词文本，频次聚合输入不存在：持久 PracticeDictationDiffSummary.Segment 仅 {kind,lowerBound,upperBound}（PracticeDictationDiff.swift:340-348，注释「no derived text slices — recomputed at render」）。修订——§3目标3/§12.1.3/§12.2①：provider 读 attempt_text+reference_text_snapshot 重跑 compare() 取词文本；§7 新增约束5 性能（O(n²) LCS + maxInputLength=2000 规模上限）；§15 fixture 含真实文本。
  P1（核验成立）：
  - [P1-1] BlindSpotKind 臆造命名：实际 SegmentKind = {missing,extra,changed}（PracticeDictationDiff.swift:28-35），非方案写的 missingWord/wrongForm/extraWord。修订——§3目标1/§12.2①定稿映射 SegmentKind。
  - [P1-2] 信号效度：dictation diff 含听错 / 拼写滑误，非纯语法盲点（idea-02 §4.1 归练习信号）。修订——§7约束4/§12.3/§20/§15：v1 标注「重复练习错误模式（来自听写练习）」、不用裸「盲点」标签；presentation 断言标题含练习来源限定。
  - [P1-3] S1 的 LearnerProfileView/Presentation 尚不存在于磁盘（S1 仅 Draft）：方案 §9 误列为可参考代码。修订——§4/§9/§12.3/§19：标注 S1 创建、S3 Phase 2 硬阻塞于 S1 落地。
  P2 / 红线断言：
  - [P2-1] 盲点 provenance 是分布证据非单 FK（ADR-006 §9）——§3目标1/§20 注明 [LearnerEvidenceRef] 表证据集、weight reserved。
  - [红线断言纠正] observations「Short-lived UI state — not persisted」（PracticeBacktranslationReview.swift:46），无法 seed → 红线断言改为「SQL 仅 FROM/JOIN practice_text_attempts + language_spaces 白名单列」（§12/§14/§15）。
写回修改：P0-1→§3/§4/§5/§6/§12.2②/§19/§20；P0-2→§3/§7约束5/§12.1/§12.2①/§15；P1-1→§3/§12.2①/§15；P1-2→§7约束4/§12.3/§20/§15；P1-3→§4/§9/§12.3/§19/§20；P2-1→§3/§20；红线断言→§12/§14/§15。
预置确认点（实现授权前）：① §12.2① 聚合策略（按词 vs 按片段）；② §12.2③ 自由产出语种检测是否进 v1（默认否）；③ deposit 子增量是否在 v1 之后紧接（需 migration）；④ 盲点效度文案口径。
是否允许进入实现：否——本轮仅拆 plan，未授权实现；第一轮 2 P0 + 3 P1 已修订写回，第二轮（测试 / 安全细化）留实现批次前执行。状态保持 Draft / 自审核 = 第一轮 Reviewed。
```

```text
审核日期：2026-06-25（补执行）
审核方式：隔离子代理第二轮（测试 / 安全 / 落地）+ 主会话用当前 HEAD 代码逐条核验
审核轮次：第二轮（建立在第一轮修订后的方案上，不重复架构结论）
发现摘要（子代理分级，主会话已用代码核验成立）：
  P1（阻塞清线，须修订后才可标 Reviewed）：
  - [P1-1] §4 红线守卫测试不可实现：`sqlReadsOnlyPracticeAttemptAllowlist` 拟「断言 SQL 只读白名单列」，但 SQL 是 `reader.read{}` 内私有字符串字面值，单测无 seam 读取；LM01 实际红线测试（GRDBLearnerContextProviderTests.swift:150-190 `undepositedCandidateExcluded`）是**行为断言**非 SQL 文本断言；`observations` 不落库（PracticeBacktranslationReview.swift:50，仅 Core）故无法 seed。修订方向（实现批次前定）——§15 改为二选一并写死机制：(a) 行为断言（首选，镜像 LM01）= seed 一条带唯一 token 的 `errorPattern` `memory_candidates` 候选，断言无 BlindSpot 含该 token；或 (b) `Database.trace`（已见用于 LocalDataUsageServiceTests）捕获 SQL 断言只触 practice_text_attempts / language_spaces。§12 红线守卫 + §14 同步。
  - [P1-2] 规模上限（约束 5）未决且无先失败测试：§7 约束5 列三选项（限近 N / session 去重 / 缓存）未择一、无 N 值、无行为；§15 无规模测试。这是本切片唯一新增工程风险（全历史 dictation × 每次进页全量重跑 O(n²) compare，PracticeDictationDiff.swift:302-317）。修订方向——§12.2 决定 v1 cap 具体值（建议 `ORDER BY created_at DESC LIMIT N`，N≈200，须与白名单 SQL 兼容）；§15 加先失败测试 `recomputeBoundedToRecentNAttempts`（seed N+k 条，断言仅最近 N 参与聚合）；约束 5 由 warn 升 blocker 或在 §20 论证「文档化但 v1 暂不测」的剩余风险。
  P2 / P3（非阻塞，同次修订一并并入）：
  - [P2-1] §15 缺语言空间软删测试：当前仅 `softDeletedAttemptDropsFromBlindSpots`（attempt 软删），无 `ls.deleted_at IS NULL` 空间软删测试（SQL 已含该过滤、§7 约束1 已声明、LM01 有对应 `softDeletedSpaceExcluded`）。加 `softDeletedLanguageSpaceContributesNoBlindSpots`。
  - [P2-2] §17 idea-02 §7.1 回写措辞：§7.1 原述盲点源 = `memory_candidates kind=errorPattern`（已核实 errorPattern 是 AI 候选 kind，AppDatabase.swift:493，ADR-006 §4 红线）；S3 纠正为 dictation diff 用户产出。§17 须改为「§7.1 源替换 + 加注」，非单纯「落地回指」。
  - [P3-1] §17 architecture/002 回写前置于 S1 的 LM01/Memory 子系统基线（002 当前零 Learner 条目，grep 证实）；002 盲点数据流回写须接在 S1 基线之后。
  - [P3-2] `.practiceTextAttempt` 是纯内存 source type（`LearnerEvidenceRef` 不落库），加 case 无 raw-value 持久化兼容负担——可在 §3/§5 一句注明。
确认仍坚实（建立在第一轮之上）：TDD 红绿次序、fixture 构造（AppDatabase + DatabaseQueue + raw SQL seed，FK 链 practice_text_attempts.session_id → practice_sessions）、deposit scope-down、provenance 证据集语义、聚焦验证命令均成立。
是否允许进入实现：否。第二轮发现 2 P1 阻塞清线项（红线测试机制 + 规模上限值/测试）须修订写回后，自审核状态方可由「第一轮 Reviewed」推进为「Reviewed」。本轮仍仅授权拆 plan，未授权实现。
```

```text
收口日期：2026-06-25（第二轮 2 P1 + P2/P3 收口，状态推进为 Reviewed）
收口方式：主会话据第二轮发现逐项定稿决策并写回，无需新增用户决策（按「先收口再实施」授权由 AI 给定合理默认）
P1-1（红线守卫测试机制）已定稿：
  弃「SQL 文本断言」（reader.read{} 内私有字面值无 seam，不可实现）。
  机制 = 源级 grep 守卫（§14：rg 对 provider 源无命中，直接证明源不引用 memory_candidates/learning_materials/learning_text）+ 行为断言 redLineExcludesAICandidateAndLearningText（§15：seed errorPattern 候选 + learning_text 各带唯一 sentinel，断言盲点输出不含 sentinel）。两者并用——grep 守源、行为断言守运行期非泄漏。observations 不落库故只由行为断言间接覆盖。
  写回：§14（双守描述）、§15（测试改名 + 机制写死）、§4/约束2 不变（仍 blocker）。
P1-2（规模上限）已定稿：
  v1 上限 = ORDER BY created_at DESC LIMIT 200（按语言、读路径内 SQL 截断、无缓存 / 无新表 / 无迁移）。选 LIMIT 而非缓存：无状态、零迁移、可 TDD。N=200 依据：dictation 文本通常 ≤300 字符，200×300²≈18M ops 进页可接受；maxInputLength=2000 仅硬天花板。
  约束 5 由 warn 升 blocker；§12.1.3 SQL 加 LIMIT；§12.2①' 记决策；§15 加先失败测试 recomputeBoundedToRecentNAttempts；§20 记剩余风险 + 缓存后置。
P2/P3（同次并入）：
  [P2-1] §15 加 softDeletedLanguageSpaceContributesNoBlindSpots（空间软删，镜像 LM01 softDeletedSpaceExcluded）。
  [P2-2] §17 idea-02 §7.1 改「源替换 + 加注」（errorPattern AI 候选 → dictation diff 用户产出 + 加注 AI errorPattern 不作信号源），非单纯落地回指。
  [P3-1] §17 architecture/002 回写须接在 S1 LM01/Memory 基线之后（002 当前零 Learner 条目）。
  [P3-2] §3 目标1 注明 .practiceTextAttempt 纯内存 source type、无 raw-value 持久化兼容负担。
是否允许进入实现：否——状态已推进为 Reviewed（双轮过），但仍待用户逐批实现授权。预置确认点（§13 第一块「预置确认点」）①②③④ 中：①聚合策略（按词 vs 按片段）= 实现期微调、不阻塞；②自由产出语种检测默认否（已定）；③deposit 子增量另立方案；④效度文案口径已定（约束 4「重复练习错误模式（来自听写练习）」）。
```

## 14. 复查方法

- 代码：LearnerModel 值类型 / provider 测试全绿；**红线守卫 = 源级 grep + 行为断言双守**（第二轮 P1-1 定稿）：① 源级 grep `rg "memory_candidates|learning_materials|learning_text|urlsession|LangoTraceAI" Packages/LangoTraceLearnerModel/Sources` 无命中（直接证明 provider 源不引用禁表）；② 行为断言 `redLineExcludesAICandidateAndLearningText`（sentinel 不泄漏，§15）；observations 不落库故不在 grep 内、改由行为断言间接覆盖；依赖断言不 import LangoTraceAI；`git diff` 无 migration / 无新表。
- 数据：盲点按语言聚合（跨同语言多空间共享）；仅 dictation 信号；源删除天然级联；空练习返回空盲点不崩溃；attempts 多时读路径重算规模受上限约束（约束 5）。
- UI：盲点分区不下判决 / 不降级、诚实标注练习来源；v1 仅展示 + 跳复习（无 deposit）；空态引导；三端可达。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/BlindSpot/BlindSpotModelTests.swift（值类型 / kind / 证据集采样上限）
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/BlindSpot/GRDBLearnerBlindSpotProviderTests.swift（compute-on-read / 按语言聚合 / 仅 dictation / 重跑 compare 取词文本频次聚合 / SQL 列白名单 / 源删除天然级联 / 空练习空盲点）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/LearnerProfile/BlindSpotPresentationTests.swift（不下判决 / 不降级 / 练习来源限定标题 / 空态）
fixture 构造：复用 LM01 路径（DatabaseQueue + AppDatabase + raw SQL seed practice_sessions/practice_text_attempts/language_spaces）；dictation attempt 须含真实 attempt_text + reference_text_snapshot（供重跑 compare）。
先失败用例（红绿次序：LearnerModel 值类型 → provider → UI）：
  BlindSpotModelTests.kindMapsToSegmentKind —— 断言 BlindSpotKind = {missing,changed,extra} 映射 PracticeDictationDiff.SegmentKind；预期失败：类型尚不存在。
  GRDBLearnerBlindSpotProviderTests.aggregatesByLanguageReRunningCompare —— 断言重跑 compare 后按词文本频次聚合；预期失败：provider 尚不存在。
  GRDBLearnerBlindSpotProviderTests.backtranslationAttemptsExcluded —— 约束 3：回译 diff_summary_json 为 nil 应被 WHERE 排除。
  GRDBLearnerBlindSpotProviderTests.redLineExcludesAICandidateAndLearningText —— 红线机制定稿（第二轮 P1-1，弃不可实现的 SQL 文本断言）= **行为断言 sentinel**：seed 一条 dictation attempt（产出已知盲点 token）+ 一条 memory_candidates(kind='errorPattern') 含唯一 sentinel-A + 一条 learning_materials.learning_text 含唯一 sentinel-B，断言 blindSpots 输出含 attempt token 但**不含 sentinel-A / sentinel-B**（证运行期不跨 AI 判定表）。**配合 §14 源级 grep 守卫**（`rg memory_candidates|learning_materials|learning_text` 对 provider 源无命中）= 静态直接证明源不引用禁表。两者并用：grep 守源、行为断言守运行期非泄漏。observations 不落库（PracticeBacktranslationReview.swift:50）故不 seed。
  GRDBLearnerBlindSpotProviderTests.recomputeBoundedToRecentNAttempts —— 规模上限定稿（第二轮 P1-2，约束 5 blocker）：seed 200+k 条同语言 dictation attempts（created_at 递增），断言仅最近 200 条参与聚合（ORDER BY created_at DESC LIMIT 200）；预期失败：截断尚未实现。
  GRDBLearnerBlindSpotProviderTests.softDeletedAttemptDropsFromBlindSpots —— 源 attempt 软删后该模式重算消失（天然级联，约束 1）。
  GRDBLearnerBlindSpotProviderTests.softDeletedLanguageSpaceContributesNoBlindSpots —— 第二轮 P2-1 补：空间软删（ls.deleted_at NOT NULL）后其 attempts 不进盲点（约束 1，镜像 LM01 softDeletedSpaceExcluded）。
  BlindSpotPresentationTests.neverShowsLevelDowngradeAndLabelsPracticeSource —— 无 level/downgrade 键 + 标题含练习来源限定；预期失败：presentation 尚不存在（约束 4）。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceLearnerModel
  swift test --package-path Packages/LangoTraceUI
不新增单元测试的原因（如适用）：不适用，全程 TDD。
```

## 16. 验证命令

```bash
swift test --package-path Packages/LangoTraceLearnerModel
swift test --package-path Packages/LangoTraceUI
scripts/check-docs.sh
```

本方案**无 migration**；含三端 UI，收口前三端构建按 CLAUDE.md 1.4 放 GitHub Actions。

## 17. 文档影响检查

- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md)：回写「LM02 盲点 v1（dictation diff 派生、compute-on-read、零外发）已落地；自由产出 / AI 校准盲点留后续」（实施后）。
- `docs/architecture/001-initial-module-boundaries.md`：包获得盲点 read（命中包边界变化触发）。
- `docs/architecture/002-system-map.md`：盲点子系统 compute-on-read 数据流（读 practice_text_attempts dictation diff → 聚合 → BlindSpot）。**P3-1：002 当前零 Learner 条目，盲点数据流回写须接在 S1 的 LM01/Memory 子系统基线之后**（不可先于 S1 基线落条目）。
- `docs/platform-page-inventory.md`：总览页盲点分区填充 + 行动闭环（命中平台页面变化触发）。
- `docs/idea/02-dynamic-proficiency-assessment.md` §7.1：**P2-2：非单纯「落地回指」——§7.1 原述盲点源 = `memory_candidates kind=errorPattern`（已核实 errorPattern 是 AI 候选 kind，AppDatabase.swift:493，ADR-006 §4 红线禁读），S3 须将其改为「dictation diff 用户产出」并加注「AI errorPattern 候选不作盲点信号源」**（源替换 + 加注，非仅回指）。
- review：新子系统 read + 页面分区命中专项审查触发。
- 是否需要新 ADR：否——ADR-006 盲点归 Ability 层的实施，沿用其决策；§12.2 待决作方案内决策 + 用户确认。

## 18. 实施记录

待实现。

## 19. 完成标准

1. 第 3 节目标 1–5 均有代码 / 测试 / 文档证据。
2. **S1 已 merge**（Phase 2 前置，P1-3）；LearnerModel / UI 聚焦测试全绿；无 migration / 无新表；红线 grep 无命中。
3. ADR-006 实施回写、architecture/001 + 002、platform-page-inventory、idea-02 §7.1 收口已同步。
4. plan-vs-shipped 对账：BlindSpot 模型（kind 映射 SegmentKind）、provider seam、compute-on-read 重跑 compare、仅 dictation、SQL 白名单红线、不下判决 / 练习来源限定标注——逐项核对；deposit / 自由产出语种检测 / AI 校准 / 持久化作为有意 scope-down 记录。

## 20. 剩余风险

- **盲点效度（信号性质，最重要，P1-2）**：dictation diff 反映「转写差异」，含听错 / 拼写滑误，**不全是语法 / 用法盲点**（idea-02 §4.1 把听写归练习信号、非「写作盲点」强信号）——v1 须诚实标注「重复练习错误模式（来自听写练习）」、不用裸「盲点」标签冒充完整语法诊断。覆盖有限（仅做过听写者有）；真正语法盲点须自由产出语种检测信号（§12.2③ 子增量、idea-02 §13.4 母语记录稀疏致产出信号稀疏，是 v1 覆盖受限根因）。
- **deposit 砍出 v1（§12.2②，P0-1）**：`memory_items` schema 仅接 candidate 来源 + difficulty NOT NULL，盲点 deposit 需独立 migration + Core 扩展（命中 add-storage-migration）→ 后续子增量、用户单独确认；v1 仅展示 + 跳复习。
- **读路径重算规模（P0-2 / 约束 5，第二轮 P1-2 已收口为 blocker + 上限定值）**：盲点须重跑 `PracticeDictationDiff.compare()`（O(n²) LCS、maxInputLength=2000）。**v1 上限定稿 = `ORDER BY created_at DESC LIMIT 200`**（无状态、零迁移、可先失败测试 `recomputeBoundedToRecentNAttempts`）。剩余风险：N=200 在极端长文本（接近 maxInputLength）下进页延迟仍可能偏高（罕见）；若未来 profiling 超标，再引入「缓存最近一次（键 = max(created_at)+count）」作后续优化，不进 v1（缓存需生命周期 / 失效，破坏零迁移边界）。
- **错误模式抽取形态（§12.2 ①）**：kind 已定稿 {missing,changed,extra} 映射 SegmentKind；聚合策略（按词 vs 按片段）仍可自审微调，避免引入语言学分类（近 AI 判定）。
- **provenance 分布证据（P2-1）**：盲点 provenance 是「证据集分布」（多 attempts 支撑一模式），用 `[LearnerEvidenceRef]` 表达、weight 沿用 reserved；未来加权重须保持证据集语义、不退化为单 FK（ADR-006 §9）。
- **依赖 S1 盲点分区（P1-3）**：S1 的 `LearnerProfileView`/`Presentation` **尚不存在于磁盘**（S1 仅 Draft/Reviewed）；S3 Phase 2 硬阻塞于 S1 落地。
- **与 S4 band 的接缝**：盲点是 S4 band 重估的**独立信号之一**（idea-02 §13.1：band 须建在不被 level 污染的独立信号上）；S3 产出的独立错误信号是 S4 的前置，故 S3 先于 S4（拆解排序一致）。
- **本环境（若 Linux）**无 Swift 工具链；测试须 macOS / GitHub Actions。
```
