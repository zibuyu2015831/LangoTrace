# 任务方案：band 重估服务 + derive() 迟滞 + 总览呈现（LM02 Slice 4b）

状态：Done（2026-06-25 落地，三门控满足后实现；轻量本机 Core 246 + LearnerModel 46 + UI 587 全绿 + GitHub Actions Build & Test 全绿（run 28167168073）；§17 文档已回写（含 ADR-006 §10.1 实施进展）；已移入 done/）
自审核状态：**Reviewed（双轮 + 拆分后隔离再审三关过；2026-06-25）**——从 S4 双轮归属 S4b 的发现 + **拆分后隔离再审新发现 P0-1（"band 不跨外发"被 `:96` 证伪→改"不引入新增外发字段"）/ P1-1（迟滞 dwell 单位错配→改 document-open 次数）/ P2-1（计数器状态归属）** 均已核验成立并收口（见第 13 节两个审核块）。**仍待用户实现授权**，且**门控于 S4a merge + S3 信号回归充分 + ADR-006 §10 修订 artifact 存在**。
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

本方案由 [S4 拆解边界](2026-06-25-feature-lm02-s4-band-reestimation.md)（2026-06-25 用户决策拆 S4a/S4b）spawn，是 [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 学习者模型系列 LM02 第四片的**最高风险子片**——**全系列唯一触碰 `ExplanationLanguageMode.derive()`**。S4b 范围：消费 S4a 捕获的查词信号 + S3 产出错误 + 练习行为，产出**内部 band 信号**，经**迟滞策略**接 `derive()` 的 `proficiencyLevelCode` 来源，并在总览页**不展示降级**地呈现。

状态 `Draft`：须完整双轮自审（已补）+ 用户实现授权方可实现。**多重硬门控**：① S4a merge（查词信号 + 账本就绪）；② S3 独立产出信号成熟 + 回归充分（band 须建在不被 level 污染的独立信号上，ADR-006 §4 / idea-02 §13.1）；③ **ADR-006 §10 修订 artifact 已存在**（band 重估 + derive 吃演进信号 + 迟滞契约，下文 §17）。当前**无实现授权**。

## 1. 需求或 bug 描述

当前目标语水平只有 onboarding 一次性自评 `LanguageLevel`（CEFR 枚举），主观、静态、易过期，却已驱动真实体验——`ExplanationLanguageMode.derive(from:)`（Core）按 level 把阅读解释分源语言 / 双语桥接 / 目标语沉浸三档，`ReadingDocumentStore` 消费。S4b 把这个静态值升为**持续重估的内部 band**，使「水平」反映真实进步——但必须不触发系列最高的两类风险：闭环自证（§20）与 derive() 漂移（§20）。

## 2. 现状描述（对照 2026-06-25 HEAD 核实）

- **`ExplanationLanguageMode.derive(from levelCode:)`**（`ExplanationLanguageMode.swift:6`，Core）：纯函数，按 level code 返回解释档位。`derive()` 消费者仅 2 处（`ReadingDocumentStore.swift:58` / `:133`）。
- **但 blast radius 不止 derive()（P0-2 已核实）**：`proficiencyLevelCode` 作为「水平真值」流向远更广——送 AI Provider（`ReadingDocumentStore.swift:95` `ReadingExplanationRequest`）、材料生成（`LearningContentStore.swift:194/:286`）、照片写作（`PhotoWritingAssistViewModel.swift:74`）、回译点评（`PracticeBacktranslationReviewService`）；另有用户手动覆盖路径 `switchExplanationMode`（`ReadingDocumentStore.swift:112`）。**S4b 须明确 band 只喂哪些消费者**（§3 目标 4 收口）。
- **S4a 信号地基**（硬前置）：查词行为事件 + `source_content_origin` 判别 + 分析账本 / cursor（S4a 落地，S4b 消费）。
- **S3 盲点信号**（硬前置）：dictation diff 产出独立产出错误信号；band 产出维度依赖 S3 成熟。
- **`LanguageLevel`（用户可见标签）**：onboarding 设定、语言空间编辑可改。ADR-006 §10：评估**永不覆盖用户可见标签**、只演进内部难度信号、永不降级。

## 3. 目标

1. **band 重估服务**（`LangoTraceLearnerModel`）：吃**独立信号**（S4a 查词频率 + S3 产出错误 + 练习行为），产出**内部 band 信号** + 置信度 + 趋势；分技能 v1 仅理解 + 覆盖，产出维度低置信占位（idea-02 §14.2）。**红线：绝不吃** `memory_candidates.difficulty` / AI 生成难度 / AI 点评（§4）。
2. **查词信号传递污染过滤（P0-4 band 侧；隔离再审对齐 S4a P0-A）**：band 服务据 S4a `source_content_origin` 只采信 `userAuthored`、排除 `aiGenerated`——但**因 v1 阅读文档恒用户导入（S4a P0-A），该过滤 v1 trivially 全 userAuthored、是前向接缝**；待未来「学习材料可作阅读源」基础设施落地，二阶闭环（level→生成文本→查词→band）才需此过滤真生效。
3. **derive() 迟滞接线**（唯一碰 derive() 的切片）：`ReadingDocumentStore` 的 `proficiencyLevelCode` 来源从静态 level 改吃演进 band，经**可测迟滞状态机**（§12.1 钉死数值）防漂移。
4. **band 只喂 derive()，不喂其余 4 消费者（P0-2 收口，限 blast radius）— 但须诚实承认 band 经 `:96` 已影响外发档位（隔离再审 P0-1 修正）**：v1 band 仅驱动 `ReadingDocumentStore` 的 derive() 解释档位（2 处）；AI Provider 请求的 `proficiencyLevelCode`（`:95`）、材料生成、照片写作、回译点评**仍用静态 `LanguageLevel`**。**但 AI 解释请求同时携带 `explanationLanguageMode: currentExplanationMode`（`:96`）= derive() 的输出**——故 band 经 derive() **确实影响发往 Provider 的解释档位**。正确论证：band **不引入新增外发字段**，且 `explanationLanguageMode` 早已随请求外发、隐私量级不变（仍是**三档枚举**，非 band 数值 / 置信度 / 趋势）；band 不流入 `:95` proficiencyLevelCode、不流入材料生成 / 照片写作 / 回译点评。
5. **用户手动覆盖 reconcile（P0-2 收口）**：`switchExplanationMode` 用户覆盖**始终优先**——用户对某文档手动选档后，band 建议对该文档**被抑制 / 并存**，不回改用户已选。
6. **不展示降级**（ADR-006 §10 红线）：总览页只展示覆盖 / 已纠正 / 趋势 / 成长，**绝不**展示「你从 B1 降 A2」。
7. **永不覆盖用户可见 `LanguageLevel` 标签**（ADR-006 §10）：band 是内部信号、只建议 / 并存。

## 4. 范围

- **`Packages/LangoTraceLearnerModel`**：band 域模型 + 重估服务（吃独立信号、red-line 无 AI 字段、置信度 / 趋势、source_content_origin 过滤）+ provider band 受控读口（供总览页 + derive()）。
- **`Packages/LangoTraceCore`**：`ExplanationLanguageMode` 迟滞包装（迟滞决策状态机 / 类型）；band 值类型若需共享。
- **`Packages/LangoTraceUI`**：`ReadingDocumentStore` 的 `proficiencyLevelCode` 来源接 band（经迟滞）+ `switchExplanationMode` 覆盖 reconcile；总览页 band 呈现（不展示降级）。
- **`LangoTraceApp/AppEnvironment.swift`**：装配 band 服务（注入 S4a repository + S3 provider）。
- 文档：**ADR-006 §10 修订（门控前置）+ 实施回写**、architecture/002（band 子系统 + derive() 漂移防护 + 信号独立性）、idea-02 §14 band 落地回指、decomposition + dashboard 标注。

## 5. 不做什么

- **不做 AI 校准 band**（外发增量，opt-in，跨切 v2，过 ADR-006 §6 隐私闸；本方案纯本地）。
- **不让 band 喂 derive() 以外的消费者**（P0-2：AI 请求 / 材料生成 / 照片写作 / 回译点评 v1 仍用静态 label）。
- **不覆盖用户可见 `LanguageLevel` 标签 / 不展示降级**（ADR-006 §10 红线）。
- **不吃 AI 生成物作 band 证据**（`memory_candidates.difficulty` / AI 难度 / AI 点评，§4 红线）。
- **不计入 `aiGenerated` 来源查词**（P0-4：v1 排除，断二阶闭环）。
- **不在 S4a + S3 信号未成熟 / 回归未充分 / ADR-006 §10 修订未存在前动 derive()**（多重门控，§20）。
- **不做新表 / migration**（S4b 消费 S4a 的表；band 倾向 local-only 可重算、不新增持久表——若需 band 缓存另议，v1 compute-on-read）。

## 6. 证据与决策依据

- ADR-006 §4（证据红线 / 闭环自证）、§9（账本 provenance 证据集，S4a 提供）、§10（自评=种子 / 评估=演进内部值 / 永不覆盖标签 / 永不降级）、§8（Ability local-only 可重算）、影响节（LM02 分技能占位）。
- idea-02 §3 / §5（评估机制 + 方案 B 外发后置）、§13.1（闭环红线：band 建独立信号）、§13.3（derive() 迟滞：稳定阈值 + 最小停留 + 仅新内容）、§14.2（v1 理解 + 覆盖、产出低置信、不展示降级、不第四 Tab、行动闭环后置）。
- 代码证据：见第 2 节（derive() 2 处消费、proficiency 5+ 消费者 blast radius、switchExplanationMode 覆盖路径、line 95 送 Provider）。
- workflow 引用：**命中** [`add-platform-screen`](../../workflows/add-platform-screen.md)（总览页 band 呈现）；**不命中** add-storage-migration（S4b 不新增表，消费 S4a）；不命中 AI Provider（band 本地、不喂请求）。

```text
证据能证明什么：ADR-006 §10 明定评估只演进内部值 / 不覆盖标签 / 不降级；idea-02 §13.3 给迟滞方向；derive() 仅 2 处消费可迟滞收敛。故 S4b 路径有权威依据。
证据不能证明什么：迟滞具体阈值 / 停留窗口 idea-02 给方向未给数值（§12.1 须钉死可测值）；产出维度信号稀疏致测不准（v1 仅理解+覆盖）。band 是否进备份——倾向 local-only 可从 S4a 账本+信号重算（§5）。
迁移前提：S4b 不新增表（消费 S4a v28+ 表）；band compute-on-read（可重算、不持久）。
照搬风险：band 直灌 derive()（无迟滞）致漂移；吃 memory_candidates.difficulty 致闭环自证；band 喂 AI 请求放大外发——均须严格排除。
```

```text
是否需要 spike / probe / fixture / evidence：否——纯本地 band 计算 + 迟滞状态机。fixture 为合成信号序列（查词 / 盲点 / 练习），无真实用户敏感内容。
需要时的落点：不适用。
是否包含真实用户敏感内容：否——合成 fixture。
如何验证和清理：合成 fixture，无需清理。
```

## 7. 约束映射与验证路径

### 约束 1：证据红线 + 闭环效度（band 建独立信号）— blocker
- 来源：ADR-006 §4、idea-02 §13.1
- 验证：band 只吃用户行为 / 产出（S4a 查词 + S3 产出错误 + 练习）；**绝不**吃 `memory_candidates.difficulty` / AI 难度。**红线机制（镜像 S3 收口）**：源级 grep（band 服务源不引用 memory_candidates / learning_text / observations 作信号）+ 行为断言 `bandComputationNeverReadsAIDifficulty`（seed 一条含唯一 sentinel 的 errorPattern candidate / learning_text，断言 band 输出不受其影响）。**信号独立性回归**：band 不因「level→生成难度→候选→band」闭环自证。

### 约束 2：传递污染过滤（排除 aiGenerated 查词）— warn（前向接缝，隔离再审对齐 S4a P0-A）
- 来源：S4 双轮 P0-4（band 侧）+ S4a P0-A（v1 无 AI 生成阅读源）
- 验证：band 服务只采信 `source_content_origin = userAuthored`；**v1 trivially 全 userAuthored**（阅读文档恒用户导入），故为前向接缝。测试 `bandExcludesAIGeneratedSourceLookups`（seed 等量 userAuthored / aiGenerated 查词，断言仅前者影响 band）**结构上可写**（band 服务过滤逻辑存在即可红绿），但 v1 生产数据不产 aiGenerated 行；待 AI 阅读源基础设施落地升 blocker。

### 约束 3：永不覆盖用户标签 + 永不降级 — blocker
- 来源：ADR-006 §10
- 验证：`LanguageLevel` 标签不被 band 改写（`bandNeverOverwritesUserLanguageLevel`）；任何呈现无降级文案键（presentation 测试 `neverShowsDowngrade`）。

### 约束 4：derive() 迟滞防漂移（可测状态机）— blocker
- 来源：idea-02 §13.3/§14.2、S4 双轮 P0-3
- 验证：derive() 输入经迟滞状态机（§12.1 钉死数值）；测试断言 band 小波动不立即改档、仅持续越阈 + 停留足够才切、且只作用新内容不回改已渲染解释；blast radius 限 `ReadingDocumentStore` 2 处。

### 约束 5：band 仅喂 derive()、不引入新增外发字段（隔离再审 P0-1 修正）— blocker
- 来源：S4 双轮 P0-2 + 隔离再审 P0-1（band 经 `:96` 已影响外发档位）
- 验证：v1 band 仅驱动 derive() 解释档位（`:58`/`:133`）；`proficiencyLevelCode`(`:95`) / 材料生成 / 照片写作 / 回译点评仍读静态 `LanguageLevel`。**测试 `bandOnlyFeedsDeriveNotAIRequests` 须显式覆盖 `:96`**：断言 band 不使 `:95` proficiencyLevelCode 漂移、不流入材料生成 / 照片写作 / 回译点评；**并明确接受 `explanationLanguageMode`(`:96`) 随 band 变化是预期行为**（否则会漏 `:96` 误绿）。隐私论证落到「外发的是三档枚举、非 band 内部信号 / 数值 / 置信度」，**不**宣称「band 零跨外发」（代码证伪）。

### 约束 5b：迟滞计数器状态归属（隔离再审 P2-1）— warn
- 来源：隔离再审 P2-1（derive() 当前无状态纯函数、band compute-on-read，「连续 3 次」计数是新增状态）
- 验证：迟滞计数器键 = **per-language**（与 band 同键）；**local-only、重启清零属可接受退化**（非持久）；document-open 评估喂入点 = `:58`（init/replaceDocument）/ `:133` 两处。测试断言计数器按语言隔离、喂入点正确。

### 约束 6：用户手动覆盖优先 — blocker
- 来源：S4 双轮 P0-2、`switchExplanationMode`（`ReadingDocumentStore.swift:112`）
- 验证：用户对某文档手动选档后，band 建议对该文档被抑制 / 并存，不回改用户已选；测试 `userOverrideSuppressesBandSuggestionForDocument`。

### 约束 7：分技能 v1 仅理解 + 覆盖 — warn
- 来源：idea-02 §14.2、ADR-006 风险（产出信号稀疏）
- 验证：v1 band 仅理解 + 覆盖维度有效；产出维度低置信占位；不因产出测不准误判整体 band。

## 8–11. 代码 / 文档路径 / bug 分析

- 涉及代码：`ExplanationLanguageMode.swift`（迟滞状态机）、`ReadingDocumentStore.swift:58/:133`（derive 来源接 band）+ `:112`（switchExplanationMode reconcile）、LearnerModel band 服务 / provider band 读口、总览页 band 呈现、`AppEnvironment`。
- 参考代码：`GRDBLearnerContextProvider.swift`（Ability compute-on-read）、S4a 查词事件 / 账本 repository、S3 盲点 provider、S1 总览页。
- 涉及文档：ADR-006（§10 修订，门控前置）、architecture/002、idea-02 §14、decomposition、dashboard。
- 非 bug 任务。

## 12. 实施方案

### 12.0 多重硬门控（实现授权前必须全部满足）
1. **S4a merge**：查词信号 + `source_content_origin` + 账本 / cursor 就绪。
2. **S3 信号成熟 + 回归充分**：独立产出错误信号稳定（band 建独立信号，ADR-006 §4）。
3. **ADR-006 §10 修订 artifact 已存在**：band 重估 + derive 吃演进信号 + 迟滞契约写入 §10（§17）——S4b 清线门控于此 artifact 存在。

### 12.1 迟滞状态机（P0-3 收口，钉死可测数值）

> idea-02 §13.3 给方向（稳定阈值 + 最小停留 + 仅新内容）未给数值；S4b 钉死如下可测默认值（实现期可据回归微调，但 v1 须有具体值方能 TDD 红）：

- **稳定阈值** = band 须在**连续 3 次 document-open 评估**中持续越过相邻档边界，方触发档位切换（单次 / 两次波动不切）。
- **最小停留窗口** = 切档后须停留**≥ 5 次 document-open 评估**，方允许下一次切档（防抖动来回切）。**单位修正（隔离再审 P1-1）**：原写「≥5 条新分析内容条目（以 S4a cursor 计）」与 S4a 的高水位窗口聚合 cursor（非 per-item 计数器，S4a §12.2 刻意不做 per-item 旗标）数据形态不兼容；改用 **document-open 评估次数**——与稳定阈值同一时钟、单位统一、最易 TDD，且不要求 S4a 暴露条目计数（不扩大 S4a / 不破坏门控）。
- **「仅新内容」边界** = 迟滞决策只作用于 **document-open 时刻之后新打开 / 新分析的内容**；**已渲染解释永不回改**（缓存键 = document-open 快照 + contentRevision，per-anchor）。
- 测试：`bandFluctuationDoesNotImmediatelyChangeExplanationMode`（< 3 次越阈不切）、`sustainedCrossingChangesModeAfterThreshold`（≥ 3 次越阈 + 停留足够才切）、`onlyNewContentReEvaluatedNeverRerendersExisting`（已渲染不回改）、`dwellWindowPreventsRapidReswitch`（停留窗口 < 5 次 document-open 内不再切）。

### 12.2 band 重估服务（LearnerModel）
1. band 域模型：维度（理解 / 覆盖 v1 有效，产出低置信占位）+ 置信度 + 趋势 + provenance 证据集（采样上限，分布非单 FK，镜像 S2/S3）。
2. 重估服务：吃 S4a 查词（仅 userAuthored，约束 2）+ S3 产出错误 + 练习行为；**红线断言无 AI 字段**（约束 1）；compute-on-read（band 不持久、可从账本 + 信号重算，§5）。先失败测试 → 实现。

### 12.3 derive() 迟滞接线（唯一碰 derive()）
1. `ExplanationLanguageMode` 迟滞包装：band → 迟滞状态机（§12.1）→ derive 档位；blast radius 限 `ReadingDocumentStore` 2 处（约束 4）。
2. `ReadingDocumentStore` 的 `proficiencyLevelCode` 来源接 band（经迟滞）；`switchExplanationMode` 用户覆盖优先 reconcile（约束 6）；**band 不流入 `:95` AI 请求 / 材料生成 / 照片写作 / 回译点评**（约束 5）。

### 12.4 总览页 band 呈现（不展示降级）
1. 总览页 band 分区：覆盖 / 已纠正 / 趋势 / 成长（**绝不**降级文案，约束 3）；用户标签并存、不被改写。
2. presentation 测试无降级键 + 标签不被 band 改写；三端状态覆盖。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-25
审核方式：隔离子代理双轮（第一轮架构 + 第二轮测试/安全/落地）+ 主会话用 HEAD 代码逐条核验；建立在 S4 拆解边界双轮发现之上（S4b 归属项）
审核轮次：完整双轮
从 S4 双轮归属 S4b 的发现 + 本片收口：
  [P0-2] blast radius + 用户覆盖 reconcile 已收口：proficiency 真值 5+ 消费者，但 v1 band 仅喂 derive()（2 处），其余 4 路（AI 请求:95 / 材料生成 / 照片写作 / 回译点评）仍用静态 label——band 不跨 AI 外发边界（约束 5）；switchExplanationMode 用户覆盖始终优先、band 对该文档抑制/并存（约束 6）。写回 §2/§3目标4-5/§5/§7约束5-6/§12.3。
  [P0-3] 迟滞无数值 → 可测状态机已钉死（§12.1）：稳定阈值=连续 3 次 document-open 越阈、最小停留=≥5 条新分析内容、仅新内容=document-open 快照 per-anchor 不回改；4 条先失败测试。写回 §7约束4/§12.1/§15。
  [P0-4 band 侧] 传递污染过滤已收口：band 默认只采信 userAuthored 来源查词、排除 aiGenerated（断二阶闭环），aiGenerated v1 不计入（约束 2）。写回 §3目标2/§5/§7约束2/§12.2。
  [P1-3] ADR 升级已定 = ADR-006 §10 修订（用户决策）：band 重估 + derive 吃演进信号 + 迟滞契约作 §10 扩展修订，作 S4b 清线门控（artifact 须先存在）。写回 §12.0③/§17。
  红线机制（镜像 S3）：源级 grep（band 服务源不引用 memory_candidates/learning_text/observations 作信号）+ 行为断言 bandComputationNeverReadsAIDifficulty（sentinel 不影响 band）。写回 §7约束1/§15。
确认仍坚实：band compute-on-read 不新增表（消费 S4a）；provenance 采样上限镜像 S2/S3；分技能 v1 理解+覆盖；TDD 红绿次序 / fixture（合成信号序列）/ 聚焦验证命令均成立。
是否允许进入实现：否——本轮仅拆 plan，未授权实现。
```

```text
隔离再审日期：2026-06-25（拆分后对 S4b 新 plan 单独 spawn 隔离子代理对照 HEAD 代码再审）
结论：代码事实层（derive 2 消费、proficiency 5+ 消费者 blast radius、switchExplanationMode:112、ADR-006 §10 需修订）经再审**逐一核实准确、无虚标**；但拆分新引入的核心 scoping 论据有 1 P0 被代码证伪 + 1 P1 单位错配，均已收口。
  [P0-1] 「band 不跨 AI 外发边界」被 :96 证伪（已收口）：AI 解释请求 ReadingExplanationRequest 同时传 proficiencyLevelCode(:95) 与 explanationLanguageMode: currentExplanationMode(:96)，而 currentExplanationMode 正是 derive() 输出 → band 经 derive() 已影响发往 Provider 的解释档位。修订：§3目标4/§5/§7约束5/§20——改「band 不引入新增外发字段，且 explanationLanguageMode 早已外发、隐私量级不变（三档枚举非 band 数值）」；测试 bandOnlyFeedsDeriveNotAIRequests 显式覆盖 :96 防误绿。
  [P1-1] 迟滞 dwell 单位与 S4a cursor 形态错配（已收口）：原「≥5 条内容条目（以 S4a cursor 计）」与 S4a 高水位窗口聚合 cursor（非 per-item 计数器）不兼容。修订：§12.1——dwell 改用 document-open 评估次数（与稳定阈值同时钟、单位统一、不扩大 S4a）。
  [P2-1] 迟滞计数器状态归属未定（已收口）：derive() 当前无状态纯函数、band compute-on-read，「连续 3 次」是新增状态。修订：§7 新增约束 5b——计数器 per-language 键、local-only 重启清零可接受、喂入点 :58/:133。
  [P3-1] ADR-006 §10 修订门控判断**准确**（§10 现文确不覆盖「derive 吃演进 band + 迟滞 + 喂哪些消费者」）；提醒 §10 修订须同步 P0-1 措辞、勿把「不跨外发」错误前提写进 ADR。
  [P3-2] 红线机制（grep + 行为 sentinel）再审确认可实现、未重蹈 SQL-text 断言覆辙。
  再审逐一确认无 finding：derive 消费仅 :58/:133；blast radius 5+ 消费者（:95 送 Provider、LearningContentStore:194/:286、PhotoWritingAssistViewModel:74、Backtranslation service）全对上；switchExplanationMode:112 用户覆盖 reconcile 在 v1 代码下天然成立；S4a 地基（source_content_origin / 查词 / 账本）全仓不存在 → 门控真实未满足、设计正当。
状态：经上述收口后双轮 + 再审三关均过，标 Reviewed；仍门控于 ①S4a merge ②S3 信号成熟+回归充分 ③ADR-006 §10 修订 artifact 存在 + 用户逐批实现授权。
```

## 14. 复查方法

- band 计算输入无 AI 生成字段（红线 grep + 行为断言）；band 不改写 `LanguageLevel`；无降级呈现；derive 迟滞防漂移（< 3 次越阈不切、已渲染不回改、停留窗口防抖）；band 仅喂 derive() 不喂其余 4 消费者；用户覆盖优先；aiGenerated 查词不计入。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceLearnerModel/Tests/.../Band/BandReestimationServiceTests.swift（独立信号输入 / 红线无 AI 字段 / aiGenerated 排除 / 置信度趋势 / 不覆盖标签 / provenance 采样上限）
  Packages/LangoTraceCore/Tests/.../ExplanationLanguageModeHysteresisTests.swift（迟滞状态机数值，§12.1）
  Packages/LangoTraceUI/Tests/.../Reading/DeriveBandSourceTests.swift（derive 来源接 band / 用户覆盖优先 / band 不流入其余消费者）
  Packages/LangoTraceUI/Tests/.../LearnerProfile/BandPresentationTests.swift（不展示降级 / 标签不被改写）
先失败用例：
  bandComputationNeverReadsAIDifficulty —— 约束 1 红线行为断言（sentinel 不影响 band）。
  bandExcludesAIGeneratedSourceLookups —— 约束 2：仅 userAuthored 查词影响 band。
  bandNeverOverwritesUserLanguageLevel —— 约束 3：标签不被改写。
  bandFluctuationDoesNotImmediatelyChangeExplanationMode —— 约束 4：< 3 次越阈不切档。
  sustainedCrossingChangesModeAfterThreshold —— 约束 4：≥ 3 次越阈 + 停留足够才切。
  onlyNewContentReEvaluatedNeverRerendersExisting —— 约束 4：已渲染解释不回改。
  dwellWindowPreventsRapidReswitch —— 约束 4：停留窗口（< 5 次 document-open）内不再切。
  bandOnlyFeedsDeriveNotAIRequests —— 约束 5（隔离再审 P0-1 修正）：断言 band 不使 :95 proficiencyLevelCode 漂移、不流入材料生成 / 照片写作 / 回译点评；**显式覆盖 :96**——接受 explanationLanguageMode 随 band 变化为预期（避免漏 :96 误绿）。
  hysteresisCounterIsolatedPerLanguage —— 约束 5b：迟滞计数器 per-language 隔离、喂入点 :58/:133。
  userOverrideSuppressesBandSuggestionForDocument —— 约束 6：手动覆盖优先。
  bandPresentationNeverShowsDowngrade —— 约束 3 presentation。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceLearnerModel
  swift test --package-path Packages/LangoTraceCore
  swift test --package-path Packages/LangoTraceUI
不新增单元测试的原因：不适用，全程 TDD。
```

## 16. 验证命令

```bash
swift test --package-path Packages/LangoTraceLearnerModel
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/check-docs.sh
```

含 derive() 行为变化 + 三端 UI，收口前三端构建 / 全量验证按 CLAUDE.md 1.4 放 GitHub Actions。S4b **不新增 migration**（消费 S4a 表）。

## 17. 文档影响检查

- **ADR-006 §10 修订（门控前置 artifact）**：band 动态重估 + derive() 从静态 level 改吃演进信号 + 迟滞契约，作为 ADR-006 §10 扩展修订（**非新增独立 ADR**；复用「自评=种子 / 评估=演进内部值 / 永不覆盖标签 / 永不降级」决策上下文）。**S4b 清线门控于该修订存在**（§12.0③）。修订须明确：band 喂哪些消费者（v1 仅 derive()）、迟滞契约、用户覆盖优先、不降级。
- ADR-006：回写 band 重估 + derive() 演进落地（实施后）。
- architecture/002：band 子系统 + derive() 漂移防护 + 信号独立性（接在 S1/S4a 基线之后）。
- idea-02 §14：band 落地回指。
- review：derive() 行为变化 + ADR-006 §10 修订 + 新子系统——命中专项审查触发。

## 18–19. 实施记录 / 完成标准

2026-06-25 落地（dev 分支；三门控满足后实现：S4a merge ✅ + S3 信号回归 ✅ + ADR-006 §10.1 artifact 存在 ✅）：

- **Core**：`BandHysteresis` 迟滞状态机（seed + stableThreshold=3 + dwellWindow=5；连续越阈 + 切档后停留方再切；非连续越阈 reset）+ `LearnerBand`/`BandConfidence`/`BandTrend`。
- **LearnerModel**：`LearnerBandProvider` 协议 + `GRDBLearnerBandProvider` compute-on-read（SQL 仅 `dictionary_lookup_events` JOIN `language_spaces`，仅 userAuthored、排除 aiGenerated；blindSpotProvider 取 S3 错误；strugglingScore ≥ threshold 则下沉一档；confidence=.low；不写 level）。
- **UI**：`ReadingDocumentStore` 加 `bandLevelSource`（环境注入 + `reconnectBandSource`）+ `BandHysteresis` 状态 + `userDidOverrideMode`；`evaluateBandForDocumentOpen`（迟滞评估 + 仅新内容改 mode）；`switchExplanationMode` 设 override；replaceDocument 清 override。`LearnerProfilePresentation` 加 bandTrend/confidence（不展示降级，levelDisplay 恒 onboarding level）。reading view `.task` reconnect + evaluate。
- **装配**：`makeReadingBandLevelSource`（`GRDBLearnerBandProvider` → estimatedLevel）+ `AppEnvironment.readingBandLevelSource` + 两处环境注入；snapshot builder 加 `bandProvider`，`loadSnapshot` 加 seedLevel。
- **红线 + 外发诚实**：band SQL 不读 AI 字段（行为断言 `bandComputationNeverReadsAIDifficulty`）；`bandOnlyFeedsDeriveNotAIRequests` 显式覆盖 :95 静态 / :96 随 band（接受为预期，防误绿）。
- **TDD**：BandHysteresisTests(4) + GRDBLearnerBandProviderTests(5) + DeriveBandSourceTests(3) + BandPresentationTests(2) 先失败后实现。
- **验证**：轻量本机 Core 246 + LearnerModel 46 + UI 587 全绿（含 Han guard），format/lint 0 error，AppEnvironment 1300；含 derive() 行为变化 + 三端 UI 的全量 Build & Test 经 GitHub Actions CI 绿。
- **scope-out 全兑现**：无 AI 校准 band、无 migration（compute-on-read）、band 不喂 derive() 以外消费者、不覆盖标签 / 不降级、不吃 AI 难度、aiGenerated 排除。
- **§17 文档影响已回写**：ADR-006 §10.1 实施进展、architecture/002-system-map §4.10 band 数据流 + 测试入口、idea-02 §14 band 落地回指。

完成标准（达成）：①S4a + S3 已 merge 信号回归充分；②ADR-006 §10.1 artifact 存在；band 不覆盖标签 / 不降级 / 红线无 AI 字段 / 排除 aiGenerated / 仅喂 derive()；迟滞防漂移测试全绿；用户覆盖优先；CI 绿；ADR / architecture 同步。
- 完成标准：①S4a + S3 已 merge 且信号回归充分；②ADR-006 §10 修订 artifact 存在；band 不覆盖标签 / 不降级 / 红线无 AI 字段 / 排除 aiGenerated 查词 / 仅喂 derive()；derive 迟滞防漂移测试全绿；用户覆盖优先；三端构建 CI 绿；ADR / architecture 同步。

## 20. 剩余风险（系列最高）

- **闭环自证（头号）**：band 须建在不被 level 污染的独立信号；红线松动则水平焊死。S4b 排最后、门控 S3 信号成熟 + 回归充分 + 排除 aiGenerated 查词（约束 2）。
- **derive() 漂移**：band 直灌 derive() 致体验在用户脚下漂移；§12.1 迟滞状态机（连续 3 次越阈 + ≥5 条停留 + 仅新内容不回改）防之；blast radius 限 2 处（约束 4-5）。
- **band 经 `:96` 已影响外发档位（隔离再审 P0-1，措辞已修正）**：v1 band **不**喂 `:95` proficiencyLevelCode / 材料生成 / 照片写作 / 回译点评（约束 5），但 AI 解释请求携带的 `explanationLanguageMode`(`:96`) = derive() 输出，band 经 derive() 确实改变发往 Provider 的解释档位。诚实论证：band **不引入新增外发字段**，外发的仍是**三档枚举**（早已外发、隐私量级不变），非 band 数值 / 置信度 / 趋势。未来若 band 喂 `:95` 或其余路径须重审外发边界。ADR-006 §10 修订须采用此措辞、勿写「不跨外发」错误前提。
- **产出信号稀疏**：母语记录占多数 → 目标语产出测不准；v1 仅理解 + 覆盖，产出低置信占位。
- **不打击信心**：永不展示降级（约束 3 红线）。
- **band local-only 可重算**：band compute-on-read 不持久，从 S4a 账本 + 信号重算；S4a 查词 local-only 不可恢复 → band 须从剩余信号优雅降级（S4a §20 接缝）。
- **ADR-006 §10 修订门控**：修订 artifact 未存在前 S4b 不可清线（§12.0③ / §17）。
- **本环境（若 Linux）**无 Swift 工具链；derive 行为须 macOS / CI 验证。
