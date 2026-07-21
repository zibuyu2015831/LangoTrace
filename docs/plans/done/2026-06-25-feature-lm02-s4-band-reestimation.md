# 任务方案（拆解边界）：band 动态重估拆为 S4a（信号捕获+账本）/ S4b（band 服务+derive 迟滞）（LM02 Slice 4）

状态：Done（拆解边界 / 导航文档，非单一实现方案。**2026-07-22 收口归档**：S4a/S4b 两子片均已 Done 移 `done/`，双轮发现的 4 P0 + 4 P1 已在两子片实现中逐项处置；本文件作为拆解边界与双轮证据档归档。收口任务见 `docs/plans/done/2026-07-22-docs-lm-series-closure-and-entry-alignment.md`）
自审核状态：N/A（拆解边界）。**2026-06-25 完整双轮自审结论 + 用户决策**：S4 拆 **S4a**（信号捕获+账本，低风险）/ **S4b**（band 服务+derive 迟滞，最高风险），本文件转拆解边界；双轮发现的 **4 P0 + 4 P1** 作为 S4a/S4b 的实现前必决项。**S4a/S4b 已于 2026-06-25「先收口再实施」拆出 + 各自双轮 + 拆分后隔离再审三关过**（见 §12.0 末），两片 Draft/Reviewed、待实现授权。
类型：docs（拆解边界；S4a/S4b 各自 feature active plan 待第 2 批开工前拆）
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

本方案是 [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 学习者模型系列 LM02 的第四份切片（S4），是**全系列最高风险**的一片（唯一触碰 `ExplanationLanguageMode.derive()`、首次引入分析账本 + 持久化派生 + migration）。2026-06-25 会话用户拍板「全部拆成 active plan、按门控分批实现」。据 [LM02 切片拆解文档](2026-06-25-docs-lm02-remaining-slices-decomposition.md) S4 边界：把目标语水平从**静态自评**升为**持续重估的内部 band 信号**，驱动材料难度 / 解释模式 / 练习选材 / 复习排序 / 语伴基线。

**S4 排在 S1 + S3 之后**，且必须等 **S3 独立产出信号 + 查词行为信号成熟 + 回归充分**才动 `derive()`（ADR-006 §4 闭环红线 / idea-02 §13.1）。状态 `Draft`：本轮仅拆 plan，**实现授权未给出**，且本切片须完整双轮自审 + 用户授权方可进入实现。

## 1. 需求或 bug 描述

当前目标语水平只有 onboarding 一次性自评 `LanguageLevel`（CEFR 枚举），主观、静态、易过期，却已在驱动真实体验——`ExplanationLanguageMode.derive(from:)`（Core）按 level 把阅读解释分源语言 / 双语桥接 / 目标语沉浸三档，`ReadingDocumentStore` 已消费（ADR-006 背景）。S4 把这个静态值升为**持续重估的内部 band**，使「水平」反映真实进步。

**这是系列最难的一片**：① 闭环自证——若证据红线执行不严，`level → 生成难度 → 候选难度 → 反推 level` 会把水平焊死（ADR-006 §4）；② derive() 漂移——band 演进若直接灌入 derive() 会让「体验在用户脚下漂移」（idea-02 §13.3）；③ 母语记录占多数时目标语产出信号天然稀疏，产出维度测不准（ADR-006 风险）；④ 不打击信心红线——永不展示降级（ADR-006 §10）。

## 2. 现状描述（对照 2026-06-25 HEAD 核实）

- **`ExplanationLanguageMode.derive(from levelCode:)`**（`ExplanationLanguageMode.swift:6`，Core）：纯函数，按 level code 返回解释档位。`derive()` **消费者仅 2 处**（`ReadingDocumentStore.swift:58` / `:133`）。**但 blast radius 不止于此（P0-2 已核实）**：`proficiencyLevelCode` 作为「水平真值」流向远更广——送 AI Provider（`ReadingDocumentStore.swift:95` `ReadingExplanationRequest`）、材料生成（`LearningContentStore.swift:194/:286`）、照片写作（`PhotoWritingAssistViewModel.swift:74`）、回译点评（`PracticeBacktranslationReviewService`）；另有用户手动覆盖路径 `switchExplanationMode`（`ReadingDocumentStore.swift:112`）。故「derive()=2 处 → 风险小」的原框定不成立：proficiency-as-source-of-truth = 5+ 消费者且跨 AI 外发边界。`proficiencyLevelCode` 当前是静态来源（onboarding level）。
- **查词 / 索取解释频率信号（idea-02 §4 主力信号）当前无持久化**：核实 `AppDatabase` 无 dictionary lookup / 查词事件表（`ReadingDictionaryLookup` Core 类型存在于阅读视图，但**未落库为行为事件**）→ S4 的主力 band 信号**净新增捕获**（须新增查词行为事件表）。
- **分析账本 / cursor 当前不存在**（核实全仓无 `intake_ledger` / `IntakeLedger`，migration 头 = `v26`）：ADR-006 §9 规划的账本「建了不读」推迟到 S4 band 重估时**首次建对**——S4 引入分析账本 + 高水位 cursor 增量重算（持久化 + migration）。
- **S3 盲点信号（目标语产出错误）**：S3（`2026-06-25-feature-lm02-s3-blind-spots`）从 dictation diff 产出独立产出信号；**S4 的产出维度信号依赖 S3 先成熟**（band 须建在不被 level 污染的独立信号上，idea-02 §13.1）。
- **LM01/S2/S3 均 compute-on-read 无持久；S4 不同**——band 是「真派生但需账本 / cursor 增量重算」。**修正（P1-1）：S4 表并非 Learner Model 首张持久表**——S1 已建 `learner_memory_facts` = **v27**（仓库首张系统级表）+ writer seam；S4 的查词事件 + 账本表为 **v28+**，建在 S1 v27 schema 与 `writer: DatabaseWriter` 之上（**硬前置 S1**）。S4 是 Learner Model 首张 **Ability 派生 / 账本** 持久表。Ability 仍 local-only 不备份（ADR-006 §8），查词事件作「不可重算的用户行为」须单独定 backup_policy（P1-2）。
- **`LanguageLevel`（用户可见标签）**：onboarding 设定、语言空间编辑可改。ADR-006 §10：评估**永不覆盖用户可见标签**，只演进**内部难度信号**。

## 3. 目标

> S4 体量大（净新增查词捕获 + 账本 + band 服务 + derive() 迟滞接线），建议**自身再分两子片**实现（见 §12.0），但作为一份拆解方案统一记录边界。

1. **查词 / 索取解释行为事件捕获**（净新增持久化）：阅读视图查词 / 索取解释行为落库为**行为事件**（用户行为信号，非 AI 判定），作 band 主力信号（idea-02 §4）。
2. **分析账本 + cursor**（ADR-006 §9 首次落地）：`(source_type, source_id, analyzer, analyzer_version)` 键，Ability 走高水位 cursor 增量重算（窗口聚合，非 per-item 旗标）。
3. **band 重估服务**（LearnerModel）：吃**独立信号**（S3 产出错误 + 查词频率 + 练习行为），产出**内部 band 信号** + 置信度 + 趋势；**永不覆盖用户可见 `LanguageLevel` 标签**（ADR-006 §10）；分技能 v1 仅理解 + 覆盖，产出维度低置信占位（idea-02 §14.2）。
4. **derive() 迟滞接线**（唯一碰 derive() 的切片）：`ReadingDocumentStore` 的 `proficiencyLevelCode` 来源从静态 level 改吃演进 band，但经**迟滞策略**（稳定阈值 + 最小停留窗口 + 仅新内容，idea-02 §13.3）防体验漂移；用户可见标签仍可手动编辑、band 只「建议 / 并存」。
5. **不展示降级**（ADR-006 §10 红线）：总览页 / 任何呈现只展示覆盖 / 已纠正 / 趋势 / 成长，**绝不**展示「你从 B1 降 A2」。
6. **证据红线严格执行**（ADR-006 §4）：band 只吃用户行为 / 产出，**绝不**吃 `memory_candidates.difficulty` / AI 生成难度 / AI 点评。

## 4. 范围

- **`Packages/LangoTraceData`**：查词行为事件表 + 分析账本 / cursor 表（migration，**首次为 Learner Model 建持久表**）；对应 repository。
- **`Packages/LangoTraceLearnerModel`**：band 域模型 + 重估服务 + cursor 增量重算 + provider 扩展（band 受控读口，供总览页 + derive() + 语伴 baseline）。
- **`Packages/LangoTraceCore`**：`ExplanationLanguageMode` 迟滞包装（或新增迟滞决策类型）；band 值类型若需共享。
- **`Packages/LangoTraceUI`**：查词行为事件埋点（阅读视图）；`ReadingDocumentStore` 的 proficiencyLevelCode 来源接 band（经迟滞）；总览页 band 呈现（不展示降级）。
- **`LangoTraceApp/AppEnvironment.swift`**：装配查词事件 repository + band 服务 + 账本。
- 文档：**ADR-006 §10 修订（已决）+ 实施回写**（band 重估 + derive() 吃演进信号 + 迟滞契约，作 §10 扩展修订、S4b 门控）、spec/007（账本 + 查词事件 + band 持久化分层）、architecture/002（band 子系统 + 账本数据流 + derive() 漂移防护）、idea-02 §14 band 落地回指。

## 5. 不做什么

- **不做 AI 校准 band**（AI 估计水平 = 外发增量，opt-in，跨切 v2，须过 ADR-006 §6 隐私闸；本方案纯本地）。
- **不覆盖用户可见 `LanguageLevel` 标签**（ADR-006 §10：只演进内部信号、只建议 / 并存）。
- **不展示任何降级**（ADR-006 §10 红线）。
- **不吃 AI 生成物作 band 证据**（`memory_candidates.difficulty` / AI 难度 / AI 点评，§4 红线）。
- **不在产出信号未成熟时硬上产出维度 band**（v1 仅理解 + 覆盖；产出低置信占位，idea-02 §14.2）。
- **不在 S3 独立信号 + 回归未充分前动 derive()**（闭环效度 + 漂移头号风险，§20）。

## 6. 证据与决策依据

- ADR-006 §4（证据红线 / 闭环自证）、§9（分析账本 + cursor + provenance）、§10（自评=种子 / 评估=演进内部值 / 永不覆盖标签 / 永不降级）、§8（Ability local-only 不备份——band 派生但 cursor 增量、账本持久）、影响节（LM02 = 水平信号演进 + 分技能占位）。
- idea-02 §3 / §5（评估机制 + 方案 B 外发后置）、§13.1（闭环红线：band 建在独立信号）、§13.3（derive() 迟滞：稳定阈值 + 最小停留 + 仅新内容）、§14.2（v1 理解 + 覆盖、产出低置信、不展示降级、不第四 Tab、行动闭环后置）。
- 代码证据：见第 2 节（derive() 2 处消费、查词无持久、账本不存在、derive 输入 proficiencyLevelCode）。
- workflow 引用：**命中** [`add-storage-migration`](../../workflows/add-storage-migration.md)（查词事件表 + 账本 / cursor 表 + 持久化策略）；**命中** [`add-platform-screen`](../../workflows/add-platform-screen.md)（总览页 band 呈现 + 查词埋点）；不命中 AI Provider（本地 v1）。

```text
证据能证明什么：derive() 仅 2 处消费（blast radius 小，idea-02 §14.2 成立）；ADR-006 §10 明定评估只演进内部值 / 不覆盖标签 / 不降级；idea-02 §13.3 给出迟滞策略。故 S4 路径有权威依据。
证据不能证明什么：查词信号、账本、cursor 当前都不存在（净新增持久化 + migration），S4 体量远大于 S1/S2/S3——是否一份 plan 实现，还是拆 S4a(信号捕获+账本)/S4b(band 服务+derive 迟滞)，是 §12.0 待决；迟滞具体阈值 / 停留窗口、分技能是否同期是 §12 待决（idea-02 给方向未给数值）。
迁移前提：净新增查词事件表 + 账本表 + 可能 band 持久表（首次为 Learner Model 建持久表）；须与 ADR-006 §8 按层持久化对齐（band 是否进备份？Ability local-only 不备份——band 作为 Ability 内部信号倾向 local-only 不备份、可从账本重算，须正面定）。
照搬风险：把 band 直接灌 derive()（无迟滞）会致体验漂移；把 memory_candidates.difficulty 当 band 证据会触闭环自证——均须严格排除。
```

## 7. 约束映射与验证路径（要点）

### 约束 1：证据红线 + 闭环效度（band 建在独立信号）— blocker
- 来源：ADR-006 §4、idea-02 §13.1
- 验证：band 只吃用户行为 / 产出（查词事件 + S3 产出错误 + 练习）；**绝不**吃 `memory_candidates.difficulty` / AI 难度；单元测试断言 band 计算输入不含任何 AI 生成字段；信号独立性回归（band 不因「level→生成难度→候选」闭环自证）。

### 约束 2：永不覆盖用户标签 + 永不降级 — blocker
- 来源：ADR-006 §10
- 验证：band 是内部信号，`LanguageLevel` 标签不被 band 改写（测试断言 onboarding/编辑标签不受 band 影响）；任何呈现无降级文案键（presentation 测试）。

### 约束 3：derive() 迟滞防漂移 — blocker
- 来源：idea-02 §13.3/§14.2
- 验证：derive() 输入经迟滞（稳定阈值 + 最小停留窗口 + 仅新内容）；测试断言 band 小波动不立即改 derive() 档位、仅持续越阈且停留足够才切、且只作用于新内容不回改已渲染解释；blast radius 限 `ReadingDocumentStore` 2 处。

### 约束 4：账本 / cursor 增量重算 + provenance — blocker
- 来源：ADR-006 §9
- 验证：账本键 `(source_type, source_id, analyzer, analyzer_version)`；Ability 走高水位 cursor 窗口聚合（非 per-item 旗标）；升版重跑靠 `analyzer_version`；band 派生带 `source_refs` 证据集（分布，非单 FK）。

### 约束 5：持久化分层（band / 账本 / 查词事件按层）— blocker
- 来源：ADR-006 §8、spec/007
- 验证：查词事件 = 用户行为主数据（持久、按层定备份）；账本 / cursor = 派生状态；band = Ability 内部信号（倾向 local-only 不备份、可从账本 + 信号重算）——三者持久化等级须显式定、不一刀切。

### 约束 6：分技能 v1 仅理解 + 覆盖 — warn
- 来源：idea-02 §14.2、ADR-006 风险（产出信号稀疏）
- 验证：v1 band 仅理解 + 覆盖维度有效；产出维度低置信占位（母语记录多致目标语产出稀疏）；不因产出测不准而误判整体 band。

## 8–11. 代码 / 文档路径 / bug 分析

- 涉及代码：`ExplanationLanguageMode.swift`（迟滞）、`ReadingDocumentStore.swift:58/:133`（derive 来源接 band）、`AppDatabase.swift`（查词事件 + 账本 migration）、LearnerModel 新增 band 服务 / cursor / provider 扩展、阅读视图查词埋点、总览页 band 呈现、`AppEnvironment`。
- 参考代码：`GRDBLearnerContextProvider.swift`（Ability 读）、`GRDBMediaArtifactRepository.swift`（持久化策略列）、S1/S3 总览页。
- 涉及文档：ADR-006（§10 修订，已决）、spec/007、architecture/002、idea-02 §14、decomposition、progress dashboard。
- 非 bug 任务。

## 12. 实施方案

### 12.0 S4 拆 S4a / S4b（已决，2026-06-25 用户决策）

S4 体量远大于 S1/S2/S3（净新增查词捕获 + 账本 + band 服务 + derive 迟滞 + 总览呈现，含多张 migration + 唯一 derive 触碰），且捆了 4 类风险。**2026-06-25 用户决策：拆两子片**，本文件转拆解边界：
- **S4a = 信号捕获 + 账本地基**：查词 / 索取解释行为事件表（v28+）+ 分析账本 / cursor + repository（持久化 + migration，**不动 derive()、不产 band 呈现**，建在 S1 v27 + writer seam 之上）。低风险、可先回归。S4a 清线前须收口：查词事件 backup_policy（不可重算用户行为，对照 practice_text_attempts 先例 + S1 架构备忘录 FileProtection 接缝，§13 P1-2/P1-4）；闭环红线**传递污染**审查（查词建在 AI 生成阅读材料上的二阶闭环，§13 P0-4）——该项决定 S4a 捕获什么，须在 S4a 实现前定。
- **S4b = band 服务 + derive() 迟滞 + 总览呈现**：band 重估服务 + derive 迟滞接线 + 总览 band 呈现（**唯一动 derive()、最高风险**，须 S4a + S3 信号回归充分后再做）。S4b 清线前须收口：可测迟滞状态机数值（§13 P0-3）；proficiency 真值 5+ 消费者 blast radius + `switchExplanationMode` 用户覆盖 reconcile（§13 P0-2）；ADR-006 §10 修订存在（下条）。
- **本文件不再被推进为单一可实现方案**；**S4a/S4b 已拆出并各自双轮自审 + 拆分后隔离再审三关过（2026-06-25「先收口再实施」完成）**：[`...s4a-lookup-capture-and-ledger`](2026-06-25-feature-lm02-s4a-lookup-capture-and-ledger.md) / [`...s4b-band-service-and-derive-hysteresis`](2026-06-25-feature-lm02-s4b-band-service-and-derive-hysteresis.md)，两片现 Draft/Reviewed、待实现授权。本文件保留为拆解边界 + 双轮证据档。

### 12.1 关键待决（实现授权前须收口）
1. **derive() 迟滞参数**：稳定阈值、最小停留窗口大小、「仅新内容」边界（已渲染解释不回改）——idea-02 §13.3 给方向未给数值，须定具体策略 + 测试。
2. **分技能 v1 范围**：仅理解 + 覆盖（产出低置信占位）vs 理解 + 产出同期——建议仅理解（idea-02 §14.2）。
3. **S4 是否分 S4a/S4b**（§12.0）。
4. **band 持久化分层**：band / 账本 / 查词事件各自是否进备份（约束 5）。
5. **ADR（已决，2026-06-25 用户决策）= ADR-006 §10 修订**：band 重估 + derive() 吃演进 band + 迟滞契约作为 ADR-006 §10 的扩展修订（复用既有「自评=种子 / 评估=演进内部值 / 永不覆盖标签 / 永不降级」决策上下文），**作为 S4b 清线门控**（修订 artifact 须先存在），非新增独立 ADR。
6. **查词信号捕获的隐私 / 埋点边界**：查词事件是本地行为信号（不外发），但须确认埋点不引入外发、不写诊断敏感内容。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-25
审核方式：隔离子代理完整双轮（第一轮架构 + 第二轮测试 / 安全 / 落地）+ 主会话用当前 HEAD 代码逐条核验
审核轮次：完整双轮
核验过的事实（HEAD）：derive(from:) 纯函数、消费仅 ReadingDocumentStore.swift:58/:133；migration 头 = v26（v26_create_memory_item_infrastructure）；无 intake_ledger / 查词事件表；ReadingDictionaryLookup 是 Core 词条类型、未落库为行为事件；LangoTraceLearnerModel 现仅 AbilityCoverage + LearnerContextProvider + GRDBLearnerContextProvider，全 compute-on-read 无持久表。

结论：本文件不应被推进为单一可实现方案标 Reviewed。应先据 §12.1③ 决定「拆 S4a/S4b」，本文件改为拆解边界（类型 docs、自审核 N/A，结构同 LM02 decomposition meta），各子片各自 active plan + 各自完整双轮。

P0（阻塞，均核验成立）：
- [P0-1] 拆解边界 vs 可实现方案错位：§12.0 建议拆 S4a/S4b、§13/§18/§19 又留多项 §12.1 待决，protocol §2「Not Reviewed→Reviewed」预设实现范围已固定——本文件不满足。修订：§12.1③ 现在定「拆」；本文件改拆解边界、自审核 N/A；spawn S4a（信号捕获+账本，低风险）+ S4b（band 服务+derive 迟滞，最高风险），各 Not Reviewed、各双轮。
- [P0-2] blast radius 严重低估（已用 rg 核实）：derive() = 2 处，但 proficiencyLevelCode 作为水平真值流向远更广——送 AI Provider（ReadingDocumentStore.swift:95 ReadingExplanationRequest）、材料生成（LearningContentStore.swift:194/:286）、照片写作（PhotoWritingAssistViewModel.swift:74）、回译点评（PracticeBacktranslationReviewService）；且 currentExplanationMode 另有用户手动覆盖路径 switchExplanationMode（ReadingDocumentStore.swift:112）。修订：§2/§7约束3/§20 重述「derive()=2 处，proficiency-as-source-of-truth=5+ 消费者且跨 AI 外发边界」；S4b 须明确 band 喂哪些消费者、并 reconcile 用户覆盖路径；line 95 送 Provider 是隐私相关面（§12.1⑥ 须扩到 band→request 路径，非仅查词捕获）。
- [P0-3] derive() 迟滞无数值 → 无法 TDD 红：idea-02 §13.3/§14.2 给方向未给数值，§15 的 `bandFluctuationDoesNotImmediatelyChangeExplanationMode` / `onlyNewContentReReevaluated` 无具体阈值无法写成可失败测试。修订：S4b 清线前须在 §12.1① 钉死可测迟滞状态机——停留窗口单位（事件/天/内容条目）、稳定阈值（连续跨档次数/置信下限）、「仅新内容」精确边界（document open time / contentRevision / per-anchor 缓存）。
- [P0-4] 闭环红线测试可实现性未证 + 传递污染未审：§15 `bandComputationNeverReadsCandidateDifficulty` 须像 S3 一样改 SQL-source 白名单行为断言（seed 式对不落库字段无效）；且须审「二阶闭环」——查词频率建在 AI 生成阅读材料上（level→生成文本→哪些词难→查词频率→band），现仅守一阶 memory_candidates.difficulty。修订：§7约束1/§15 改可 seed 的源白名单断言 + 增传递独立性分析（查词信号是否须限非 AI 来源内容）；须在 S4a 捕获查词前定（影响捕获什么）。

P1（高风险，须修订后 round-1 方可清）：
- [P1-1] 「首次为 Learner Model 建持久表」事实错误（已核实）：S1 创建 learner_memory_facts = v27（仓库首张系统级表）+ writer seam；S4 表为 v28+、建在 S1 schema 与 writer 之上。修订 §2/§4/§6/§17：「S4 是 Learner Model 首张 Ability 派生/账本持久表，建在 S1 v27 + writer seam 之上，migration v28+」+ 显式硬前置 S1 writer。
- [P1-2] 查词事件持久化分层可现在定：ADR-006 §8 已定 Ability 派生 local-only 不备份、账本/cursor 派生可重算；真正开放项 = 查词事件作「不可重算的用户行为」。对照 practice_text_attempts（最近似先例）= local-only / 排除备份 / 排除导出（spec/007:113）。但查词事件**不可重算**（阅读会话过后行为即逝），是不同于 Ability（可重算）与练习证据的新类别——须显式定 backup_policy + 触发 S1 架构备忘录的 FileProtection/加密接缝。
- [P1-3] ADR 升级须现在定、非「评估」：derive() 从静态 level 改吃演进 band（影响材料/解释/练习/复习/语伴基线）是核心行为变化，CLAUDE.md §4#17 触发 ADR；ADR-006 §10 覆盖「标签 vs 内部值」但未 bless 「derive() 吃演进 band + 迟滞契约」。修订 §12.1⑤：定为 ADR-006 §10 修订或新 ADR，S4b 清线门控于该 artifact 存在。
- [P1-4] 未引用既有学习者模型持久化/安全架构备忘录：docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md（CLAUDE.md §5.4 要求创建持久化方案前必查）；S4 加高频查词流 + 账本（行为 PII 更集中）却未引。加入 §6 证据 + §10 文档路径，并在该备忘录检查触发点登记查词事件。

P2：[P2-1] band provenance 须像 S3 钉采样上限+分布摘要、勿无界 ref；[P2-2] cursor 增量重算缺并发/重入/取消设计（band 只在 document-open 边界读、不 mid-session 改，明确 MainActor hop 与「仅新内容」映射）；[P2-3] §16 缺 migration 回滚/结构化验证命名测试。
P3：[P3-1] §2 ReadingDictionaryLookup 是 Core 类型非「阅读视图」；[P3-2] 测试落点拆后按 S4a/S4b 分区。

是否允许进入实现：否。本文件保持 Not Reviewed；正确终态是「拆 S4a/S4b + 本文件转拆解边界」，须用户决策（见仪表盘待用户决策）。在拆分与上述 P0/P1 收口前，S4 系不可实现。
```

## 14. 复查方法（要点）

- band 计算输入无 AI 生成字段（红线）；band 不改写 `LanguageLevel` 标签；无降级呈现；derive 迟滞防漂移（小波动不切档、仅新内容）；账本 cursor 增量重算正确；查词事件埋点不外发；migration 可回滚。

## 15. TDD / 测试落点（要点）

```text
Data：查词事件表 + 账本 / cursor migration 建表 + repository（迁移测试 + 增量 cursor 测试）。
LearnerModel：band 重估服务（独立信号输入、红线断言无 AI 字段、置信度 / 趋势、不覆盖标签）、cursor 增量重算、provider band 读口。
Core/UI：derive() 迟滞（稳定阈值 + 停留窗口 + 仅新内容的状态机测试，断言小波动不切档）；总览 band 呈现无降级键；查词埋点。
先失败用例（示例）：
  derive 迟滞：bandFluctuationDoesNotImmediatelyChangeExplanationMode；onlyNewContentReReevaluated。
  红线：bandComputationNeverReadsCandidateDifficulty（行为断言）。
  标签：bandNeverOverwritesUserLanguageLevel。
  账本：cursorIncrementalRecomputeSkipsAlreadyAnalyzed。
聚焦：swift test --package-path Packages/LangoTraceData / LangoTraceLearnerModel / LangoTraceCore / LangoTraceUI
```

## 16. 验证命令

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceLearnerModel
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/check-docs.sh
```

含多张 migration + derive() 行为变化，收口前三端构建 / 全量验证按 CLAUDE.md 1.4 放 GitHub Actions。

## 17. 文档影响检查

- ADR-006：回写 band 重估 + 账本 + cursor + derive() 演进落地。
- **ADR（已决）= ADR-006 §10 修订**：band 动态重估 + derive() 从静态 level 改吃演进信号 + 迟滞契约，作为 ADR-006 §10 扩展修订（非新增独立 ADR；影响材料难度 / 解释模式 / 练习 / 复习 / 语伴 baseline），**S4b 清线门控于该修订存在**；§12.1 第 5 项。
- spec/007：查词事件 + 账本 / cursor + band 持久化分层登记（首次为 Learner Model 建持久表）。
- architecture/002：band 子系统 + 账本数据流 + derive() 漂移防护 + 信号独立性。
- idea-02 §14：band 落地回指。
- review：migration + 新子系统 + derive() 行为变化 + ADR-006 §10 修订——命中专项审查触发。

## 18–19. 实施记录 / 完成标准

- 待实现。
- 完成标准：S1 + S3 已 merge 且信号回归充分；band 不覆盖标签 / 不降级 / 红线无 AI 字段；derive 迟滞防漂移测试全绿；账本 cursor 增量正确；migration 三端构建 CI 绿；ADR / spec/007 / architecture 同步；（若拆）S4a/S4b 各自双轮自审 + 授权。

## 20. 剩余风险（系列最高）

- **闭环自证（头号）**：band 须建在不被 level 污染的独立信号（查词 + S3 产出 + 练习）；若红线松动，水平焊死、无法反映进步。故 S4 排最后、须 S3 信号成熟 + 回归充分。
- **derive() 漂移**：band 演进直灌 derive() 会让体验在用户脚下漂移；必须迟滞（稳定阈值 + 停留窗口 + 仅新内容）；blast radius 限 2 处但行为风险高。
- **产出信号稀疏**：母语记录占多数 → 目标语产出测不准；v1 仅理解 + 覆盖，产出低置信占位。
- **不打击信心**：永不展示降级（红线）。
- **持久化首次落地**：S4 引入 Learner Model 首张持久表 + 账本 + migration；持久化分层须显式定（band local-only 可重算 vs 查词事件主数据）。
- **体量大**：建议拆 S4a/S4b（§12.0）降风险。
- **ADR 已决 = ADR-006 §10 修订**（非新独立 ADR），作 S4b 清线门控（§12.1 第 5 项 / §17）。
- **本环境（若 Linux）**无 Swift 工具链；migration + derive 行为须 macOS / CI 验证。
```
