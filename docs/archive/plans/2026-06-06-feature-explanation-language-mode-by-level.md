> 归档说明（2026-06-11）：本方案已按用户决定从 docs/plans/active/ 整体归档，仅作历史证据保留；适用部分由 2026-06-11 系列方案与 Mac 验证清单吸收。详见 docs/archive/plans/README.md。

---
title: 基于学习等级的解释语言模式自适应
type: feature
status: draft
created: 2026-06-06
updated: 2026-06-06
related_specs:
  - docs/spec/012-reading-learning-domain.md
  - docs/spec/005-ai-provider-prompt-and-privacy.md
related_adrs:
  - docs/decisions/005-local-first-and-user-owned-providers.md
related_plans:
  - docs/plans/active/2026-06-06-feature-reading-explanation-cache-and-sentence-indicators.md
---

# 基于学习等级的解释语言模式自适应

状态：Active（D1–D6 已由用户确认；实施进行中，Phase 0 spike 待手动执行）
自审核状态：Architecture-Reviewed（2026-06-06，见第 5、5.7 节；用户确认前不进入实现）
类型：feature
创建日期：2026-06-06
最后更新日期：2026-06-06

## 用户确认记录

| 日期 | 确认人 | 确认内容 | 授权范围 |
|-----|-------|---------|---------|
| — | — | 待确认第 5 节推荐决策（D1–D6）后填入 | — |

## 推荐决策摘要（待用户确认）

第 5 节已对原 Q1–Q6 给出基于代码事实的推荐方案，并在第 5.7 节补充架构审核发现。摘要如下：

| 编号 | 决策点 | 推荐方案 |
|-----|-------|---------|
| D1 | Level → Mode 映射 | **三档自动派生**（方案 A）作为默认值；`ExplanationLanguageMode` 作为一等可覆盖输入，而非纯派生量 |
| D2 | `bilingualBridge` 字段策略 + 例句译文 | 采用三档字段表；新增 **nullable `example_sentence_translation`** 字段（趁 v3 破坏性升级一次性落地） |
| D3 | 面板内临时切换逃生口 | **架构就绪、UI 本阶段 Deferred**：store 持有可覆盖的 `currentMode`，但不在本阶段实现面板控件；改为在 Level 设置页加说明 |
| D4 | 缓存键协调 | **不合并计划**；将 `explanation_language_mode` 列与唯一索引并入缓存计划 v14 schema（两计划均未实现，无需 v15 迁移）；失效采用**静默保留**（不主动清理） |
| D5 | C1/C2 母语释义 | **始终返回且保持 required**（immersion 模式指示模型输出极简母语 gloss）；UI 可折叠弱化，**不改 schema 为 nullable** |
| D6 | Phase 0 spike | 保留为强制门禁；FAIL 时 **bridge 默认降级为 `sourceLanguage`（保守），而非降级为 immersion 或从枚举移除** |

## 1. 背景与动机

### 1.1 问题描述

当前阅读选区解释面板展示以下字段：

| 字段 | 当前实际语言 | 问题 |
|-----|------------|------|
| `shortExplanation`（解释） | 目标语言（英文） | 初级用户难以用英文读懂英文解释，形成语言壁垒 |
| `meaningInNativeLanguage`（释义） | 源语言（中文） | 正确，无问题 |
| `usageNote`（用法） | 目标语言（英文） | 初级用户读英文用法说明认知负担极高 |
| `exampleSentence`（例句） | 目标语言（英文） | 例句内容正确，但初级用户需要源语言译文托底 |
| `grammaticalNote`（语法） | 目标语言（英文） | 语法术语的英文解释对初级用户不友好 |

`ReadingSelectionExplanationInput` 已携带 `proficiencyLevelCode`（对应 `LanguageLevel.rawValue`，取值 A1–C2），也已传入 Prompt，但 Prompt 没有给出任何字段级语言指令，等于将语言决策权完全交给模型，模型默认以目标语言输出大多数字段。

### 1.2 用户场景

- **场景 A（A1/A2）**：用户学英语，水平极低，解释和用法全为英文，完全无法理解。预期：解释和用法应使用母语。
- **场景 B（B1/B2）**：用户有一定基础，英文解释可以作为阅读理解练习；但语法注释用中文更清晰。预期：解释可用英文，语法和用法说明混合或用中文。
- **场景 C（C1/C2）**：用户追求沉浸式学习，全程目标语言可强化语感。预期：除"释义"外全部使用目标语言。

## 2. 目标、范围和不做什么

### 2.1 目标

1. 通过 `LanguageLevel` 自动派生解释语言模式，让解释内容适配用户当前水平。
2. 将语言模式的控制权收归 Prompt 参数，不在 UI 层对 AI 返回内容进行二次翻译。
3. 在缓存键中纳入语言模式，避免 Level 升级后旧缓存语言污染新内容。

### 2.2 范围

- `ExplanationLanguageMode` 枚举与 `LanguageLevel` → mode 派生逻辑（Core 层），含空/未知 Level 回退（F4）。
- `ReadingSelectionExplanationInput` 增加 `explanationLanguageMode` 字段。
- `ReadingSelectionExplanationResult` 增加 `explanationLanguageMode`（记录请求的模式，见 F3）与 nullable `exampleSentenceTranslation`（D2）字段。
- Prompt 升级至 v3：增加字段级语言指令、新增 `example_sentence_translation`，schema 版本同步升级。
- `docs/prompts/reading/selection-explanation.md` 同步更新至 v3。
- `ReadingDocumentStore` 持有可覆盖的 `currentExplanationMode`（默认由 Level 派生，D3 架构就绪）。
- 缓存键纳入 `explanation_language_mode`（与缓存计划协调，D4）。
- Level 设置页增加"解释语言随等级自动调整"说明（D3 替代措施）。
- **不做**：面板内临时语言模式切换控件（D3，Deferred 到后续计划；架构已为其就绪，落地无需迁移）。

### 2.3 不做什么（本阶段）

- 不实现 Prompt Preset 系统或用户自定义 Prompt 模板。
- 不修改 TTS 播放路径或 TTS 语音选择逻辑。
- 不引入服务端翻译 API 或二次翻译步骤。
- 不修改 Entry、LearningMaterial 等其他模块的 AI 解释路径。
- 不在本阶段完成 Anthropic / Gemini Provider 的支持扩展（现有 unsupportedProvider 限制不变）。
- 不实现"解释语言偏好"作为独立语言空间持久设置项（D1 已将其诉求吸收为 store 可覆盖的 mode；持久化设置项若需要，后续单独做）。

## 3. 现状分析

### 3.1 已存在的基础设施

- `LanguageLevel`（`Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageLevel.swift`）：标准 CEFR 六档枚举 A1 / A2 / B1 / B2 / C1 / C2。
- `LanguageSpace.level`：语言空间已在 GRDB 中持久化 `LanguageLevel`。
- `ReadingSelectionExplanationInput.proficiencyLevelCode`（`ReadingAIExplanation.swift:14`）：字段已存在，已在 `ReadingDocumentStore` 中填入并传入 Prompt 渲染，但 Prompt 未利用该字段控制各字段语言方向。
- Prompt 当前版本：`builtin.reading.selection_explanation.v2`，schema 版本 `reading_selection_explanation.v2`，代码在 `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`。
- 已有 Prompt 文档：`docs/prompts/reading/selection-explanation.md`。

### 3.2 当前 Prompt 的缺失

`ReadingSelectionExplanationPromptRegistry.prompt(input:)` 的 user message 仅将 `proficiency_level_code` 作为上下文传出，没有对各字段语言给出任何显式指令。当 context_text 和 containing_sentence 为目标语言时，模型倾向于以目标语言输出大多数字段，导致初级用户可读性极差。

### 3.3 与缓存计划的交叉影响

`docs/plans/active/2026-06-06-feature-reading-explanation-cache-and-sentence-indicators.md` 以 `sourceAnchorID` 为缓存主键。本功能引入新的缓存维度：用户升级 Level 后，`sourceAnchorID` 不变但期望的解释语言已改变，旧缓存内容语言出错。两计划在缓存键设计上存在硬依赖，必须协调落地顺序。

## 4. 证据与决策依据

| 证据 | 来源 | 影响 |
|-----|-----|-----|
| `proficiencyLevelCode` 已存在于 `ReadingSelectionExplanationInput` | `ReadingAIExplanation.swift:14` | 核心 Input 结构已有扩展点，无需破坏性改动 |
| Prompt user message 已包含 `proficiency_level_code: \(input.proficiencyLevelCode)` 但无字段级指令 | `ReadingSelectionExplanationService.swift:37` | Prompt 只需增量升级，不需要架构重设计 |
| `LanguageLevel` 为 CEFR 标准六档 | `LanguageLevel.swift:1-8` | 可做结构化三档映射，映射逻辑简单且可单元测试 |
| 解释结果已包含 `meaningInNativeLanguage`（固定源语言字段）证明多语言结果是已有设计意图 | `ReadingAIExplanation.swift:51` | `bilingualBridge` 混合字段策略在现有数据模型中有先例 |
| 缓存计划当前 key 为纯 `sourceAnchorID` | `2026-06-06-feature-reading-explanation-cache-and-sentence-indicators.md §2.1` | key 必须扩展，否则 Level 升级后缓存语言污染 |
| Prompt 工程可行性（混合语言字段指令稳定性）尚未验证 | 无代码证据，待 Phase 0 spike | FAIL 时 bridge 默认映射保守降级为 `sourceLanguage`（D6），枚举与字段策略保留 |
| `proficiencyLevelCode` 为 store 构造期快照，多个构造器默认 `""` | `ReadingViews.swift:37,357`、`ReadingDocumentStore.swift:57` | 映射需空值回退（F4）；Level 中途变更需重开文档（F1） |

## 5. 推荐决策（原 Open Questions，待用户确认）

下列 D1–D6 对应原 Q1–Q6，已结合代码事实给出推荐方案与理由。决策仍需用户确认后方可进入实现；用户可对任一条选择不同方案，但应注意条目间的依赖（D1 是前置，D2/D6 依赖 D1，D4 依赖缓存计划落地顺序）。

### D1：Level → Mode 映射策略（前置）

**推荐：方案 A（三档自动派生）作为默认值，并将 `ExplanationLanguageMode` 设计为一等可覆盖输入，而非纯派生量。**

映射：

| Level | 默认 Mode |
|------|----------|
| A1 / A2 | `sourceLanguage` |
| B1 / B2 | `bilingualBridge` |
| C1 / C2 | `targetImmersion` |
| 空 / 未知（构造器默认 `""`） | `bilingualBridge`（中性默认；若 D6 spike FAIL 则降级为 `sourceLanguage`） |

理由：

1. 三档在教学上正确，对应第 1.2 节场景 A/B/C；二档（原方案 B）把 B1/B2 过渡用户强行二选一，体验损失明确。
2. CEFR 自评水平是弱信号，用户常自评不准。若设计成"纯派生、不可覆盖"，B1 用户觉得 bridge 难懂时只能去改整个语言空间的 Level（牵动其它行为），缺乏退路。因此把 mode 提升为 store 持有的可覆盖输入（默认值由 Level 派生），是兼顾"自动正确"与"用户可纠偏"的最佳架构。这一设计同时让原方案 C（用户手动）与逃生口（D3）成为同一根 mode 状态上的不同入口，避免引入第二套并行控制路径。
3. 实现成本低：派生函数纯函数、可完整单测；`ExplanationLanguageMode` 在 Core 层定义为 `String`-backed、`CaseIterable`、`Codable`、`Sendable` 枚举，rawValue 为 `sourceLanguage` / `bilingualBridge` / `targetImmersion`，该字符串同时作为缓存键的一部分（见 D4），属稳定契约。

未采纳方案 B：二档牺牲 B1/B2 体验，且一旦后续要补 bridge 又需再次升 schema；不符合第 1.2 节"基础设施首次落地采用长期可扩展方案"。
未采纳"纯方案 C"：把全部决策交给用户、首屏即要求配置，违背第 3 节"自动用生活/水平适配"的产品取向；但方案 C 的"可手动覆盖"诉求已被本推荐吸收为 mode 的可覆盖性。

### D2：`bilingualBridge` 字段级策略 + 例句译文

**推荐：采用下表字段策略；新增 nullable `example_sentence_translation` 字段，趁 v3 破坏性升级一次性落地。**

| 字段 | sourceLanguage | bilingualBridge | targetImmersion |
|-----|---------------|-----------------|----------------|
| `shortExplanation`（解释） | 源语言 | 目标语言 | 目标语言 |
| `meaningInNativeLanguage`（释义） | 源语言 | 源语言 | 源语言（极简 gloss，见 D5） |
| `grammaticalNote`（语法） | 源语言 | 源语言 | 目标语言 |
| `usageNote`（用法） | 源语言 | 目标语言 | 目标语言 |
| `exampleSentence`（例句） | 目标语言 | 目标语言 | 目标语言 |
| `exampleSentenceTranslation`（例句译文，新增 nullable） | 源语言（非空） | 源语言（可空） | `null` |

`bilingualBridge` 核心原则：用源语言理解概念和语法，用目标语言感受真实用法。

关于例句译文的取舍（原 Q2 附加问题 / 原风险 4）：

- 不在 `exampleSentence` 同字段内混排译文——混排会让 parser、TTS（`听` 只读目标语言例句）和 UI 渲染都变脆。
- 不用"点击听感受发音"替代文字译文——音频解决发音，不解决初级用户对例句**含义**的理解；二者不可互换。
- 因此新增独立 `example_sentence_translation`（`["string","null"]`）。v3 本就是破坏性升级，此时一次性加字段成本最低；事后再补需要再升一次 schema，违背第 1.2 节扩展性原则。
- 该字段加入 `responseSchema()` 的 `required` 列表（strict schema 要求列出全部属性），但类型允许 `null`；parser 读取为 `String?`。

### D3：面板内临时语言模式切换逃生口

**推荐：架构就绪，UI 控件本阶段 Deferred。**

- `ReadingDocumentStore` 持有 `currentExplanationMode`（默认 = Level 派生值），所有解释请求读此值；这一步本阶段就做，使 mode 成为可覆盖输入（见 D1）。
- 本阶段**不实现**面板内切换控件。理由：第 9 节产品优先级要求克制，本计划已含 spike 门禁与跨计划依赖，UI 逃生口属"锦上添花"而非闭环必需；过早加入会扩大 UI 面、session 状态与测试面。
- 替代措施（本阶段必做）：在语言空间 Level 编辑确认页加一行说明"解释语言会随学习等级自动调整"，让用户能主动感知（同时覆盖原风险 3 的用户感知问题）。
- 关键：因为 mode 已是 store 可覆盖输入且已纳入缓存键（D4），后续补面板切换控件**无需任何迁移**——届时控件改 `currentExplanationMode`、重发请求、结果按 mode 落入独立缓存条目即可。逃生口的语义在此固化：切换必然触发重新请求（不做 UI 层二次翻译，符合第 2.1 节目标 2）；override 的 mode 是 session/文档级（关闭文档或切换空间清空，回落到 Level 派生默认）；但生成的结果按 mode 持久化缓存，再次切回即命中。

### D4：与缓存计划的键设计协调

**推荐：不合并两个计划；将 `explanation_language_mode` 列与唯一索引并入缓存计划的 v14 schema；失效采用静默保留。**

- 两个计划关注点不同（缓存/视觉标记 vs 语言自适应），合并会降低可读性与可回滚性，保持独立但建立显式契约。
- 因为两计划**目前都未实现**，无"先落地一方再迁移"的历史数据问题。最省的做法是直接把 mode 写进缓存计划尚未落地的 v14：
  - 表新增列 `explanation_language_mode TEXT NOT NULL`。
  - 唯一索引由 `(document_id, source_anchor_id)` 改为 `(document_id, source_anchor_id, explanation_language_mode)`。
  - 这样本计划只需"填值"，无需追加 v15 迁移去拓宽唯一键（SQLite 改唯一索引需重建，徒增复杂度）。
- 列归属：缓存计划拥有该表与列；本计划拥有枚举、派生函数与取值来源。两份 plan 互相 cross-reference（已在第 13 节登记）。
- 失效策略：**静默保留**。Level 升级后旧 mode 条目自然不再命中，由缓存计划既有的 `pruneStale(contentRevision)` 在内容版本变化时清理；不在 Level 变更时主动清库。理由：存储量极小，旧条目无害，且用户若回退 Level 还能命中；主动失效是额外复杂度、零收益，且与缓存计划"不删除、按需 prune"哲学一致。

落地顺序：缓存计划先落地（携带 mode-aware schema），本计划随后落地派生逻辑使该列产生有意义的值；在缓存计划落地前，store 对该列一律写入 Level 派生的默认 mode。

### D5：C1/C2 下 `meaningInNativeLanguage` 的处理

**推荐：始终返回且保持 required（非 nullable）；immersion 模式指示模型输出极简母语 gloss；UI 可折叠弱化。不改 schema。**

理由：

- `meaningInNativeLanguage`（释义）是唯一恒为源语言、恒正确的字段；对 C1/C2 沉浸用户，一个一瞥即得的极简母语 gloss 是"确认我没理解错"的高价值、低成本安全网，删除它是体验净损。
- 改为 nullable 会牵动 schema、parser 与测试（多一条 null 分支），且与"始终给安全网"取向相悖；属第 1.2 节应避免的为单一场景引入特殊路径。
- 因此：schema 保持 `meaning_in_native_language` required 非空；Prompt 在 immersion 模式要求"仅给最简母语对应词/短语"；是否折叠交由 UI 视觉处理（C1/C2 下次级/可折叠呈现），不进入数据契约。

### D6：Phase 0 spike——Prompt 混合语言指令稳定性验证

**推荐：保留为强制前置门禁；明确 FAIL 时的"保守降级"而非"删除能力"。**

- 验证内容、PASS 条件（5 次中 ≥4 次字段语言完全符合指令）维持原设计。
- **FAIL 处理修订**：bridge 的**默认映射**降级为 `sourceLanguage`（B1/B2 默认走全源语言，最保守、对初级最安全），而**不是**降级为 immersion（把有基础但未沉浸的用户丢进全目标语言是最差结果），也**不从枚举移除** bridge。保留枚举使得：(a) 数据契约稳定、无需返工；(b) 待 D3 逃生口落地后，持有强模型（如 GPT‑4 级）的用户仍可手动选用 bridge。
- 架构前提（spike 无法覆盖、必须写入设计）：本产品本地优先、用户自带 Provider，bridge 可靠性会**因用户模型而异**，单次在开发者 Provider 上的 spike 不能代表所有用户。因此：
  1. Prompt 必须用显式逐字段语言标注，对弱模型尽量稳健；
  2. 运行期**不得**因语言漂移而硬失败——语言正确性是软质量问题，不是 parse 错误，绝不阻塞主流程；
  3. `Result.explanationLanguageMode` 记录的是**请求的**模式，并非对输出语言的保证（见第 5.7 节发现 F3）。

### 5.7 架构审核补充发现（代码事实）

以下为基于现有代码的额外边界发现，须在实现方案中显式处理：

- **F1 — Level 是 store 构造期快照，非实时读取**。`proficiencyLevelCode` 在 `ReadingViews.swift:37,357` 由 `store.languageSpace.level.rawValue` 在 `ReadingDocumentStore` 构造时一次性传入，构造后不随设置页改 Level 而变。因此派生出的默认 mode 也是**文档打开时刻**确定的；用户在阅读中途改 Level，不会即时影响当前已打开文档，需重开文档才生效。这是可接受边界，但必须写入文档，并修正第 15 节复查方法第 3 步的措辞（"修改 Level 后需重新打开该文档再触发请求"，而非假设原地生效）。
- **F2 — Result 结构变更需与缓存 `result_json` 向后兼容**。新增 `explanationLanguageMode`、`exampleSentenceTranslation` 字段会改变 `ReadingSelectionExplanationResult` 的 JSON 形态。缓存计划把 Result 以 JSON 存入 `result_json`，并已规定"反序列化失败降级为缓存未命中"。实现时须保证：旧（v2 期）JSON 缺新字段时，要么解码为 `nil`/默认值不抛错，要么命中降级路径；新增字段不得使既有降级契约失效。建议把 mode 也独立存为 `explanation_language_mode` 列（D4），不依赖 `result_json` 内的镜像值做命中判断。
- **F3 — `Result.explanationLanguageMode` 是"请求的模式"，非输出语言保证**。该字段语义须在 spec/Prompt 文档中写明：它记录生成时**请求**的 mode，不保证模型实际输出语言完全符合（尤其弱模型）。第 15 节复查方法据此只能做人工抽检，不能作为自动断言。
- **F4 — 映射函数必须定义空/未知 Level 的回退**。多个构造器 `proficiencyLevelCode` 默认 `""`（如 `ReadingDocumentStore.swift:57`、`ReadingActions.swift:35`）。派生函数输入为非 CEFR 值时须有确定回退（D1 推荐 `bilingualBridge`，FAIL 降级后为 `sourceLanguage`），并有对应单测覆盖空串与非法值。
- **F5 — TTS 与例句译文无冲突**。`听` 按钮只对目标语言 `exampleSentence` 走 TTS；新增的 `exampleSentenceTranslation` 是纯文本、不进入 TTS 路径，符合第 2.3 节"不修改 TTS 路径"。实现方案中应一句话确认此边界。
- **F6 — parser 版本策略**。沿用现状的严格相等校验：v3 parser 只接受 `reading_selection_explanation.v3`，拒绝 v2。早期阶段无生产数据（CLAUDE.md §1.1），无需双版本兼容；旧缓存条目通过 F2 的降级路径自然失效。

## 6. 约束映射与验证路径

| 约束 | 来源 | 验证方式 |
|-----|-----|---------|
| 用户显式触发才发送 AI 请求，不得在导入、打开、滚动、TTS 时触发 | `spec/012 §6`、`prompts/reading/selection-explanation.md §2` | 现有 store 行为测试，不新增触发路径 |
| Prompt 不得包含完整文档、API Key、文件路径、历史记忆或照片 | `spec/005`、`spec/012 §6`、`prompts/reading/selection-explanation.md §2` | 新增字段不扩大隐私边界，`explanationLanguageMode` 不属于用户私密数据 |
| AI Provider 凭证存 Keychain，非敏感配置进 SQLite | ADR-005、`spec/005` | `ExplanationLanguageMode` 派生自 `LanguageSpace.level`，不单独存储凭证 |
| Prompt 版本变更必须登记 Prompt 文档、升级 schema version、更新 parser | `workflows/add-prompt.md §2–4` | spec 更新、Prompt 注册表更新、parser 测试 |
| 缓存键变更影响 `2026-06-06-feature-reading-explanation-cache-and-sentence-indicators.md` 的设计 | 上述计划 §2.1 | 两计划落地前对齐缓存键最终方案 |
| 本地优先，解释结果不上传不同步 | ADR-005 | `ExplanationLanguageMode` 不引入任何同步路径 |

## 7. 涉及的代码文件路径

以下为预期修改文件，括号内标注依赖的 Question：

| 文件 | 修改内容 | 依赖 D |
|-----|---------|-------|
| `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift` | 新增 `ExplanationLanguageMode` 枚举与 `derive(from:)`；`Input` 增 `explanationLanguageMode`；`Result` 增 `explanationLanguageMode` 与 nullable `exampleSentenceTranslation` | D1、D2、D5、F2、F4 |
| `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift` | Prompt registry 升级 v3；逐字段语言指令；`responseSchema()` 加 `example_sentence_translation` 并升 schema version；`parseResult` 支持 v3 | D2、D5、D6、F6 |
| `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift` | 持有 `currentExplanationMode`（Level 派生默认）；填入 `Input`；缓存键纳入 mode | D1、D3、D4、F1 |
| `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`（及 Level 设置页所在文件） | Level 编辑确认页加"解释语言随等级自动调整"说明 | D3 |
| ~~`ReadingViewComponents.swift` 面板内切换控件~~ | **本阶段不改**（D3 Deferred） | D3 |

## 8. 参考的代码文件路径

| 文件 | 参考用途 |
|-----|---------|
| `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageLevel.swift` | Level 枚举定义，映射逻辑的输入类型 |
| `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpace.swift` | `LanguageSpace.level` 字段，映射逻辑的数据来源 |
| `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift` | 现有 AI 解释测试，新测试需保持兼容 |
| `Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift` | 现有 service 测试，Prompt v3 后需更新 |
| `docs/plans/active/2026-06-06-feature-reading-explanation-cache-and-sentence-indicators.md` | 缓存键设计，与本计划协调 |

## 9. 涉及的文档路径

| 文档 | 修改内容 |
|-----|---------|
| `docs/prompts/reading/selection-explanation.md` | 升级至 v3，更新 Prompt canonical、中文审阅版、输入变量和输出契约 |
| `docs/spec/012-reading-learning-domain.md` | §6 AI Explanation 补充语言模式字段说明 |
| `docs/spec/005-ai-provider-prompt-and-privacy.md` | 若新字段扩大隐私边界则更新（当前判断不需要） |
| `docs/workflows/add-prompt.md` | 本任务须遵循该 workflow，完成后无需修改 workflow 本身 |

## 10. 实施方案

状态：**基于第 5 节推荐决策（D1–D6）拟定；用户确认后即可执行。** Phase 0 为强制前置门禁。

### Phase 0：Spike — Prompt 混合语言指令稳定性验证（强制前置）

- **假设**：当前配置的 Provider 模型能稳定遵守字段级双语指令（`bilingualBridge` 下 `shortExplanation` 输出目标语言、`grammaticalNote` 输出源语言、`usageNote` 输出目标语言）。
- **probe 位置**：`docs/reference/research/spikes/` 临时 spike 脚本或 `Tests/Tooling/` 测试脚本，不进入生产代码。
- **PASS 条件**：5 次请求中 ≥ 4 次字段语言完全符合指令。
- **FAIL 处理（按 D6）**：bridge 默认映射降级为 `sourceLanguage`，枚举保留；Prompt v3 仍按三档设计字段指令（bridge 字段策略保留，供后续强模型/逃生口使用），仅 Level→mode 的默认映射改变。
- 记录证据到 `docs/reference/research/spikes/`。PASS 或确定降级口径后方可进入 Phase 1。

### Phase 1：Core 模型扩展（TDD）

1. 先写失败测试：`ExplanationLanguageMode` 派生映射覆盖 A1–C2 全六档 + 空串/非法值回退（F4）。
2. 新增 `ExplanationLanguageMode`（`String` rawValue：`sourceLanguage`/`bilingualBridge`/`targetImmersion`，`CaseIterable`/`Codable`/`Sendable`）。
3. 新增 `ExplanationLanguageMode.derive(from levelCode: String)` 纯函数（含回退）。
4. `ReadingSelectionExplanationInput` 增 `explanationLanguageMode`；`ReadingSelectionExplanationResult` 增 `explanationLanguageMode` 与 `exampleSentenceTranslation: String?`（保持 v2 JSON 可解码，F2）。
5. 跑 `swift test --package-path Packages/LangoTraceCore`。

### Phase 2：Prompt v3 + AI Service 升级（TDD）

1. 先写失败测试：给定各 mode，user message 含对应逐字段语言指令；v3 schema 含 `example_sentence_translation`；parser 拒绝非 v3 schema_version（F6），并回填 `explanationLanguageMode` 与 `exampleSentenceTranslation`。
2. `ReadingSelectionExplanationPromptRegistry` 升级：`promptID`→`...v3`、`schemaVersion`→`reading_selection_explanation.v3`；user 模板按 mode 注入逐字段语言指令（immersion 下释义为极简母语 gloss，D5）。
3. `responseSchema()`：`required` 增 `example_sentence_translation`（类型 `["string","null"]`），`schema_version` enum 改 v3。
4. `parseResult` 读取新字段；语言漂移不视为错误（F3）。
5. 同步更新 `docs/prompts/reading/selection-explanation.md` 至 v3（canonical / 中文审阅 / 输入变量 / 输出契约 / 版本记录）。
6. 跑 `swift test --package-path Packages/LangoTraceAI`。

### Phase 3：ReadingDocumentStore 映射 + 缓存键（与缓存计划协调，TDD）

1. store 持有 `currentExplanationMode`（默认 `ExplanationLanguageMode.derive(from: proficiencyLevelCode)`），构造期由 Level 快照派生（F1）；填入 `Input.explanationLanguageMode`。
2. 缓存键纳入 `explanation_language_mode`：依 D4 与缓存计划 v14 schema 对齐（缓存计划先落地携带该列与三元唯一索引）；命中判断以独立列为准，不依赖 `result_json` 内镜像（F2）。
3. 先写失败测试：相同 `sourceAnchorID` + 不同 mode 不命中缓存。
4. 跑 `swift test --package-path Packages/LangoTraceUI`。

### Phase 4：Level 设置页说明 + 文档收口

1. Level 编辑确认页加"解释语言随学习等级自动调整"说明（D3 替代措施，覆盖原风险 3）。
2. 更新 `docs/spec/012 §6`；确认 `docs/spec/005`、ADR-005、`architecture/002-system-map.md` 不受影响。
3. `scripts/verify.sh` 全量验证。

### Phase 5（Deferred，不在本计划）：面板内临时语言模式切换逃生口

按 D3，本阶段不实现。架构已就绪（`currentExplanationMode` 可覆盖、mode 已入缓存键），后续单独立计划落地时无需迁移。

## 11. TDD 落点

以下为预期测试落点（具体测试函数名待实施方案确认后填入）：

| 测试 | Package / 文件 | 先失败用例 | 依赖 D |
|-----|--------------|----------|-------|
| `ExplanationLanguageMode.derive` 覆盖 A1–C2 全六档 | `LangoTraceCore/Tests/` 新文件 | A1→`sourceLanguage`；C2→`targetImmersion` | D1 |
| 派生函数空/非法 Level 回退 | 同上 | `""` 与 `"ZZ"` →默认 mode（D6 PASS 为 `bilingualBridge`，FAIL 为 `sourceLanguage`） | D1、F4 |
| `Result` 可从缺新字段的 v2 期 JSON 解码 | `LangoTraceCore/Tests/` 或 AI 测试 | 缺 `example_sentence_translation` 时解码为 `nil` 不抛错 | D2、F2 |
| Prompt v3 渲染：各 mode 含对应逐字段语言指令 | `LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift` | bridge input 的 prompt 含 `short_explanation`=目标语言、`grammatical_note`=源语言指令 | D2、D5 |
| `parseResult` 解析 v3，回填 `explanationLanguageMode` 与 `exampleSentenceTranslation` | 同上 | 缺 schema_version v3 时 throw `invalidStructuredResponse`；immersion 结果 `exampleSentenceTranslation==nil` | D2、F6 |
| 缓存键含 `explanation_language_mode` | 与缓存计划协调，落在 `ReadingDocumentStoreAIAndTTSTests.swift` 或新文件 | 同 `sourceAnchorID`、不同 mode 不命中缓存 | D4 |

**聚焦验证命令（待实施方案确认后更新）：**

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceUI
```

## 12. 验证命令

```bash
# 聚焦验证（Phase 1 完成后）
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceAI

# 含 UI store 测试（Phase 3 完成后）
swift test --package-path Packages/LangoTraceUI

# 完整验证（实施完成后）
scripts/verify.sh

# 文档占位符扫描
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*'
git diff --check
git status --short
```

## 13. 文档影响检查

| 文档 | 影响判断 | 处理方式 |
|-----|---------|---------|
| `docs/spec/012-reading-learning-domain.md` §6 | 受影响：AI Explanation 新增语言模式参数 | 落地后更新 §6 |
| `docs/spec/005-ai-provider-prompt-and-privacy.md` | 不受影响：`explanationLanguageMode` 非私密数据，不扩大隐私边界 | 落地后确认仍成立 |
| `docs/prompts/reading/selection-explanation.md` | 受影响：需升级至 v3，更新 canonical / 中文审阅版 / schema | 与 Phase 2 同步更新 |
| `docs/plans/active/2026-06-06-feature-reading-explanation-cache-and-sentence-indicators.md` | 受影响：缓存键设计需协调 | 按 D4，缓存计划 v14 schema 增 `explanation_language_mode` 列与三元唯一索引；两计划互相 cross-reference |
| `docs/architecture/002-system-map.md` | 不受影响：不改模块边界或数据流 | 落地后确认 |
| ADR-005 | 不受影响：不引入新 Provider 或同步路径 | 落地后确认 |

## 14. 严格方案自审核记录

```
审核日期：2026-06-06
审核方式：架构审核（基于代码事实），未使用隔离子代理
审核轮次：1
未使用隔离审查的原因：本轮为设计期架构审核与推荐方案撰写，直接基于源码与关联计划阅读，未改生产代码，无需隔离环境
发现摘要：
  - 原 Q1–Q6 已转化为推荐决策 D1–D6（第 5 节）。
  - 补充 6 项代码事实边界 F1–F6（第 5.7 节）：Level 为构造期快照、Result/缓存 JSON 向后兼容、mode 字段语义为"请求模式"、空 Level 回退、TTS 与例句译文边界、parser 版本策略。
写回修改：第 5/5.7 节（决策与发现）、推荐决策摘要表、§2.2 范围、§7 代码文件、§10 实施方案、§11 TDD、§15 复查方法、§17 完成标准、§18 风险均已同步。
仍需用户确认的问题：D1–D6（第 5 节）——尤以 D1（三档+可覆盖）、D2（新增 example_sentence_translation 字段）、D4（缓存计划 schema 改动归属）为关键确认点。
是否允许进入实现：否。状态仍为 Draft，须用户确认 D1–D6 后方可进入 Active 实现；Phase 0 spike 为强制门禁。
```

*方案为 Draft 状态。本轮已完成架构审核与推荐方案撰写；待用户确认 D1–D6 后，再做实施前严格自审核（含 TDD 落点最终核对）。*

## 15. 复查方法

1. 读取 `ReadingSelectionExplanationResult.explanationLanguageMode`，确认与文档打开时 `LanguageSpace.level` 派生的 mode 一致（注意该字段为"请求的模式"，非输出语言保证，见 F3）。
2. 使用当前已配置 Provider 发送 A1 和 C1 两个 level 的解释请求，人工抽检各字段语言是否符合预期策略（语言一致性只能人工抽检，不能自动断言）。
3. 修改 `LanguageSpace.level`（如从 B1 升为 C1）后**重新打开该阅读文档**（因 Level 是 store 构造期快照，F1），再触发同一选区的解释请求，确认缓存未命中并返回新语言模式的结果。
4. 运行 `scripts/verify.sh` 全量验证。

## 16. 实施记录

| 日期 | 提交哈希 | 内容 | 验证结果 |
|-----|---------|-----|---------|
| 2026-06-06 | zibuyu-UCloud | D1–D6 全部确认；指令"立即按照修订后的方案开始实施" | Phase 0–4 实施授权 |

## 16.1 已完成实施内容

| Phase | 文件 / 动作 | 状态 |
|-------|-----------|------|
| Phase 0 | `docs/reference/research/spikes/2026-06-06-bilingual-bridge-prompt-stability.py` spike 脚本（待手动运行） | 就绪待执行 |
| Phase 1 | `ExplanationLanguageMode.swift` 新建；`ReadingAIExplanation.swift` Input+Result 扩展 | 实现完成 |
| Phase 1 | `ExplanationLanguageModeTests.swift` 新建（含 6 档 + 空/非法值 + rawValue + roundtrip 测试） | 测试完成 |
| Phase 2 | `ReadingSelectionExplanationService.swift` 升级 v3（Prompt、schema、parser） | 实现完成 |
| Phase 2 | `ReadingSelectionExplanationServiceTests.swift` 新增 v3 prompt + parser 测试 | 测试完成 |
| Phase 2 | `docs/prompts/reading/selection-explanation.md` 升级至 v3 | 文档完成 |
| Phase 3 | `ReadingActions.swift`：`ReadingExplanationRequest` 增 `explanationLanguageMode` | 实现完成 |
| Phase 3 | `ReadingDocumentStore.swift`：`currentExplanationMode` 属性；构造期派生；request 携带 mode | 实现完成 |
| Phase 3 | `ReadingDocumentStoreAIAndTTSTests.swift` 新增 mode 派生 + request 携带测试 | 测试完成 |
| Phase 3 | 缓存计划 v14 schema：增 `explanation_language_mode` 列 + 三元唯一索引 + 协议签名更新 | 文档完成 |
| Phase 4 | `LanguageSpaceEditorView.swift`：Level 下方新增 footnote 说明 | 实现完成 |
| Phase 4 | `Localizable.xcstrings`：新增 `settings.languageSpace.management.explanationLanguageAdaptsToLevel` | 本地化完成 |
| Phase 4 | `docs/spec/012` §6 更新 + 变更日志 | 文档完成 |

## 17. 完成标准

1. `ExplanationLanguageMode` 枚举存在，`derive(from:)` 有完整单元测试，6 档 + 空/非法回退均覆盖。
2. Prompt v3 已登记在 `docs/prompts/reading/selection-explanation.md`，包含完整英文 canonical、中文审阅版、输入变量和输出契约。
3. `ReadingSelectionExplanationService` 升级至 v3，现有 service 测试全部通过，逐字段语言指令与 `example_sentence_translation` 验证测试通过。
4. `Result` 可从缺新字段的 v2 期 JSON 解码（F2），有对应测试。
5. 缓存键已纳入 `explanation_language_mode`，缓存计划中的 v14 schema 约束已对齐（D4）。
6. A1 用户选区解释结果中 `shortExplanation` 和 `usageNote` 为源语言，C2 用户为目标语言（人工抽检）。
7. Level 设置页含"解释语言随等级自动调整"说明（D3）。
8. `scripts/verify.sh` 全量通过。
9. `docs/spec/012 §6` 和 `docs/prompts/reading/selection-explanation.md` 已更新。

## 18. 剩余风险

1. **Prompt 语言遵从稳定性 + 自带 Provider 异质性（高风险）**：逐字段语言指令在不同用户模型间稳定性不一，单次 spike 不可推广（F3）。缓解：Phase 0 强制门禁 + FAIL 保守降级（D6，bridge→`sourceLanguage`）+ 运行期不因语言漂移硬失败 + 保留枚举供后续逃生口/强模型使用。
2. **缓存计划依赖（中风险）**：两计划硬依赖缓存键。缓解（D4）：缓存计划 v14 直接携带 `explanation_language_mode` 列与三元唯一索引，缓存计划先落地、本计划随后填值；两 plan 互相 cross-reference，避免一方先落地产生不一致。
3. **Level 升级用户感知（低风险）**：升级 Level 后同一文字解释语言变化可能令用户困惑，且因 F1（store 构造期快照）需重开文档才生效。缓解：D3 在 Level 编辑确认页加说明；完成时验证文案存在。
4. **新增 `exampleSentenceTranslation` 字段改动面（低风险）**：列入 v3 `required`（类型允许 null），增加少量 parser/测试改动。已评估"听发音"不能替代文字译文（D2），接受该改动；因与 v3 一次性落地，无后续二次升 schema 成本。
5. **测试覆盖率（低风险）**：验证 AI 实际返回语言是否符合指令依赖真实 Provider，无法在 CI 自动化。依赖 Phase 0 spike 与第 15 节人工抽检；单元测试只覆盖 Prompt 渲染（指令存在性）与 parser，不覆盖模型实际输出语言。
