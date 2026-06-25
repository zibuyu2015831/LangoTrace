# 任务方案：band 动态重估（CEFR 内部信号 + derive() 迟滞）（LM02 Slice 4）

状态：Draft
自审核状态：Not Reviewed（**最高风险切片**；实现批次前必须按 plan-review-protocol 完成完整双轮自审，见第 13 节）
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

本方案是 [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 学习者模型系列 LM02 的第四份切片（S4），是**全系列最高风险**的一片（唯一触碰 `ExplanationLanguageMode.derive()`、首次引入分析账本 + 持久化派生 + migration）。2026-06-25 会话用户拍板「全部拆成 active plan、按门控分批实现」。据 [LM02 切片拆解文档](2026-06-25-docs-lm02-remaining-slices-decomposition.md) S4 边界：把目标语水平从**静态自评**升为**持续重估的内部 band 信号**，驱动材料难度 / 解释模式 / 练习选材 / 复习排序 / 语伴基线。

**S4 排在 S1 + S3 之后**，且必须等 **S3 独立产出信号 + 查词行为信号成熟 + 回归充分**才动 `derive()`（ADR-006 §4 闭环红线 / idea-02 §13.1）。状态 `Draft`：本轮仅拆 plan，**实现授权未给出**，且本切片须完整双轮自审 + 用户授权方可进入实现。

## 1. 需求或 bug 描述

当前目标语水平只有 onboarding 一次性自评 `LanguageLevel`（CEFR 枚举），主观、静态、易过期，却已在驱动真实体验——`ExplanationLanguageMode.derive(from:)`（Core）按 level 把阅读解释分源语言 / 双语桥接 / 目标语沉浸三档，`ReadingDocumentStore` 已消费（ADR-006 背景）。S4 把这个静态值升为**持续重估的内部 band**，使「水平」反映真实进步。

**这是系列最难的一片**：① 闭环自证——若证据红线执行不严，`level → 生成难度 → 候选难度 → 反推 level` 会把水平焊死（ADR-006 §4）；② derive() 漂移——band 演进若直接灌入 derive() 会让「体验在用户脚下漂移」（idea-02 §13.3）；③ 母语记录占多数时目标语产出信号天然稀疏，产出维度测不准（ADR-006 风险）；④ 不打击信心红线——永不展示降级（ADR-006 §10）。

## 2. 现状描述（对照 2026-06-25 HEAD 核实）

- **`ExplanationLanguageMode.derive(from levelCode:)`**（`ExplanationLanguageMode.swift:6`，Core）：纯函数，按 level code 返回解释档位。**消费者仅 2 处**（`ReadingDocumentStore.swift:58` / `:133`，均 `currentExplanationMode = ExplanationLanguageMode.derive(from: proficiencyLevelCode)`）——**blast radius 小**，符合 idea-02 §14.2 判断。`proficiencyLevelCode` 当前是静态来源（onboarding level）。
- **查词 / 索取解释频率信号（idea-02 §4 主力信号）当前无持久化**：核实 `AppDatabase` 无 dictionary lookup / 查词事件表（`ReadingDictionaryLookup` Core 类型存在于阅读视图，但**未落库为行为事件**）→ S4 的主力 band 信号**净新增捕获**（须新增查词行为事件表）。
- **分析账本 / cursor 当前不存在**（核实全仓无 `intake_ledger` / `IntakeLedger`）：ADR-006 §9 规划的账本「建了不读」推迟到 S4 band 重估时**首次建对**——S4 引入分析账本 + 高水位 cursor 增量重算（持久化 + migration）。
- **S3 盲点信号（目标语产出错误）**：S3（`2026-06-25-feature-lm02-s3-blind-spots`）从 dictation diff 产出独立产出信号；**S4 的产出维度信号依赖 S3 先成熟**（band 须建在不被 level 污染的独立信号上，idea-02 §13.1）。
- **LM01/S2/S3 均 compute-on-read 无持久**；**S4 不同**——band 是「真派生但需账本 / cursor 增量重算」，引入仓库内 Learner Model 名下首张持久派生 + 账本表。Ability 仍 local-only 不备份（ADR-006 §8）。
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
- 文档：**新增 / 更新 ADR-006 实施回写 + 可能新 ADR**（band 重估 + derive() 演进是核心行为变化，须评估是否升 ADR）、spec/007（账本 + 查词事件 + band 持久化分层）、architecture/002（band 子系统 + 账本数据流 + derive() 漂移防护）、idea-02 §14 band 落地回指。

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
- 涉及文档：ADR-006、（评估）新 ADR、spec/007、architecture/002、idea-02 §14、decomposition、progress dashboard。
- 非 bug 任务。

## 12. 实施方案

### 12.0 S4 自身分子片（待决，建议）

S4 体量远大于 S1/S2/S3（净新增查词捕获 + 账本 + band 服务 + derive 迟滞 + 总览呈现，含多张 migration + 唯一 derive 触碰）。**建议自身拆两子片**：
- **S4a = 信号捕获 + 账本地基**：查词 / 索取解释行为事件表 + 分析账本 / cursor + repository（持久化 + migration，**不动 derive()、不产 band 呈现**）。低风险、可先回归。
- **S4b = band 服务 + derive() 迟滞 + 总览呈现**：band 重估服务 + derive 迟滞接线 + 总览 band 呈现（**唯一动 derive()、最高风险**，须 S4a + S3 信号回归充分后再做）。
- 用户可选不拆（一份实现），但鉴于风险，**推荐拆**。本方案统一记录边界，实现时各子片各自 active plan + 双轮自审。

### 12.1 关键待决（实现授权前须收口）
1. **derive() 迟滞参数**：稳定阈值、最小停留窗口大小、「仅新内容」边界（已渲染解释不回改）——idea-02 §13.3 给方向未给数值，须定具体策略 + 测试。
2. **分技能 v1 范围**：仅理解 + 覆盖（产出低置信占位）vs 理解 + 产出同期——建议仅理解（idea-02 §14.2）。
3. **S4 是否分 S4a/S4b**（§12.0）。
4. **band 持久化分层**：band / 账本 / 查词事件各自是否进备份（约束 5）。
5. **是否新 ADR**：band 重估 + derive() 演进是核心行为变化，须评估升 ADR（§17）。
6. **查词信号捕获的隐私 / 埋点边界**：查词事件是本地行为信号（不外发），但须确认埋点不引入外发、不写诊断敏感内容。

## 13. 严格方案自审核记录

```text
待执行：本切片为系列最高风险，实现授权前必须完整双轮自审（架构 + 测试 / 安全 / 落地）。本轮用户仅授权拆 plan，故标 Not Reviewed。
实现批次前须核验：derive() 迟滞 blast radius（仅 ReadingDocumentStore 2 处）、闭环效度回归（band 不自证）、账本 / cursor schema、查词事件红线（用户行为非 AI）、band 不覆盖标签 / 不降级、持久化分层、是否升 ADR。
预置确认点见 §12.1（6 项）。
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
- **是否新 ADR（高）**：band 动态重估 + derive() 从静态 level 改吃演进信号，是核心行为变化（影响材料难度 / 解释模式 / 练习 / 复习 / 语伴）——**须评估是否新增 ADR**（不只 ADR-006 实施）；§12.1 待决 5。
- spec/007：查词事件 + 账本 / cursor + band 持久化分层登记（首次为 Learner Model 建持久表）。
- architecture/002：band 子系统 + 账本数据流 + derive() 漂移防护 + 信号独立性。
- idea-02 §14：band 落地回指。
- review：migration + 新子系统 + derive() 行为变化 + 可能新 ADR——命中专项审查触发。

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
- **可能升 ADR**：核心行为变化，须评估（§17）。
- **本环境（若 Linux）**无 Swift 工具链；migration + derive 行为须 macOS / CI 验证。
```
