# 任务方案：LM03-S2a 语伴聊天反哺学习（入站 / 本地，低外发增量）

状态：Done（2026-06-26 用户授权实现；五 Phase TDD 全落地，轻量单包测试全绿 + 全量 CI Build & Test 全绿 run 28186684074）
自审核状态：Reviewed
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-26

## 用户确认记录

- 2026-06-25：用户「按照推荐的顺序，继续推进开发」。推荐顺序 = LM03-S2（语伴第 2 片）。
- 2026-06-25：用户确认 **S2 按风险拆 S2a/S2b**（仿 S4a/S4b 先例）：本片 = **S2a 聊天反哺（入站/本地，低外发增量）**；S2b = 外发注入（Memory 注入 + 方案B找话题 + 两层隐私控制 + PII scrubbing），独立 active plan + 独立授权。
- 2026-06-25：用户确认 **Memory 注入 v1 排序 = 时近性 + 种类配额**（落在 S2b，本片不实现 Memory 注入）。
- **实现授权**：尚未授权。本方案须先完成双轮自审 → `Reviewed`，再由用户授权实现。

## 需求描述

语伴（LM03）落地 S1（MVP 单线程文本对话引擎，已 Done）后，对话「聊完即逝」，学习沉淀为零。idea-03 §3.8 / §4.3 要求把对话闭合回「记录 → 对话 → 记忆」闭环：
1. 把语伴对话中出现的词汇 / 表达自动提取为记忆候选（复用既有候选产出 + 入库管线，§3.8）。
2. 把用户的目标语发言作为 Ability 层产出维度证据回流（接 LM02-S4 分析账本，§3.8 / §3.9）——语伴是 Ability 产出信号的主要来源（02 §13.4，双向协同）。

本片是 S2 拆分后的**低外发增量半片**：只做「入站 / 本地」反哺，不做「外发注入」（Memory 画像注入 prompt + 方案B主动找话题属 S2b，受决策 #10 系统自动注入边界约束）。

## 现状描述（实地核对，证据见下）

- **memory_candidates 表**（`AppDatabase.swift:464-482`）：`entry_id` / `material_id` 均 `NOT NULL REFERENCES ... ON DELETE CASCADE`，`status CHECK (status IN ('candidate'))`，`kind CHECK IN ('word','phrase','sentencePattern','grammarPoint','errorPattern')`。**物理上无法容纳「无 entry / 无 material」的聊天来源候选**。
- **候选产出形状**：`LearningMaterialAnalysis.memoryCandidates: [LearningMemoryCandidate]`（Core `LearningMaterialGenerationModels.swift:354`，`Kind = word|phrase|sentencePattern|grammarPoint|errorPattern`），由学习材料分析 AI 一次性产出，`GRDBLearningContentRepository` 在保存分析结果时批量 `INSERT INTO memory_candidates`（`GRDBLearningContentRepository.swift:638-665`）。候选目前**只产出 + 展示**；真正的 deposit / 复习队列（plan 10/11）尚未实现。
- **语伴消息已捕获用户发言**：S1 的 `companion_messages`（v30）已存 `role`、`content`、`detected_language`、`target_language_code`、`sequence`、`input_modality`。用户目标语发言 = `role='user' AND detected_language` 命中目标语的消息，**已在库内，无需新表**。
- **分析账本（LM02-S4a/S4b）**：`analysis_ledger`（v29，高水位 cursor，键 `(source_type, source_id, analyzer, analyzer_version)`）+ `GRDBAnalysisLedgerRepository.advanceCursor/cursorPosition`。band 消费侧 `GRDBLearnerBandProvider.band(...)` **当前只读 `dictionary_lookup_events`（struggling 信号：查词数 + dictation 错误数 → 越阈降一档）**，并有红线测试守「只读 userAuthored、不读 AI 难度 / learning_text、不覆盖用户可见 level」。**band 当前不建模「产出 / 流利度」正向信号**。
- **请求预览接缝**：`AIRequestPreviewProjection`（Core，非敏感投影，只携带描述符类目不携带内容）+ `RequestPreviewCardModel`（UI）+ `AIRequestPreviewEndpointCache`（App）已就绪，可复用。
- **S1 引擎接缝**：`CompanionConversationEngine`（AI）+ `CompanionReplyTransport` + `AIChatStreamingService`；App 装配在 `AppEnvironment+Companion.swift`。

## 目标、范围与不做什么

### 目标

把语伴对话沉淀为可复习的学习候选，并把用户目标语产出暴露为 Ability 证据接缝，落实「记录 → 对话 → 记忆」闭环的**入站半环**，且**不引入任何新的系统自动外发**。

### 范围（两个交付物）

**交付物 A — 聊天词汇 / 表达提取 → 语伴候选库**
- 新 Core 域类型 `CompanionMemoryCandidate`（复用 `LearningMemoryCandidate.Kind`：word/phrase/sentencePattern/grammarPoint/errorPattern）。
- 新 GRDB 迁移 **v31 `companion_memory_candidates`** 独立表（不改 `memory_candidates`，隔离风险——见 §决策 D1）：`id / space_id FK CASCADE / thread_id FK companion_threads CASCADE / message_id TEXT NULL FK companion_messages SET NULL / kind / text / explanation_native / example_target / example_native / status='candidate' / created_at / updated_at`，复用候选 kind / status 约束；按可复算派生数据处理（local-only，不加同步/导出策略列，与现 `memory_candidates` 一致）。
- 新 AI 提取引擎 `CompanionExtractionEngine`：输入一段对话窗口 → 经注入式 transport（结构化输出）产出 `[CompanionMemoryCandidate]`；新 Prompt Registry 条目 `CompanionExtractionPromptRegistry`（结构化输出契约 + 隐私边界声明）。
- 新 Data repository 方法 `appendCompanionCandidates(threadID:candidates:)` + 读取 `companionCandidates(spaceID:)`。
- **触发 = 用户显式动作**（「从这段对话提取词汇 / 表达」），**非静默每轮**（见 §决策 D2，成本 + 隐私分类双重理由）。三端入口：语伴聊天页底部 / 工具栏一个显式动作。
- 请求预览：提取调用复用 `AIRequestPreviewProjection`，新增 capability + 描述符（已分享的对话内容 → 同 Provider 同类目，**无新外发类目**）；失败态诚实（不丢对话、不伪装）。

**交付物 B — 用户目标语发言 → Ability 产出证据（最薄前向读接缝，不改 derive()）**
- 新 Data 读接缝 `productionUtterances(spaceID:after:)`：窗口化返回 `role='user'` 且 `detected_language` 命中该 space 目标语的 `companion_messages`（oldest-first，供未来 band 产出消费者读取）。**只读既有 v30 列，无新表、无迁移。**
- 架构备忘录（`docs/architecture/notes/`）：记录该读接缝位置 + 产出证据是**正向 / 流利度信号**（现 band 只建模 struggling 负向）；band 消费前须满足三层论证（信号独立 / 逻辑正确 / 数学形态）。
- **不**新增 `LearnerSourceType.companionProduction` 枚举、**不**写 `analysis_ledger` 常量、**不**改 band（round-1 P1-1 收窄，避免无消费者死代码）。

### 不做什么（非目标）

- **不做 Memory 注入**（系统级生活事实注入 prompt）→ S2b。
- **不做方案 B 主动找话题**（FTS 预筛 + 范围授权外发）→ S2b。
- **不做两层隐私控制 / PII scrubbing** → S2b（本片无新系统自动外发，不触发该门）。
- **不改 `GRDBLearnerBandProvider.band()` / derive()**，不让产出信号影响 band；**不新增 `LearnerSourceType` 项 / `analysis_ledger` 常量**（红线 + 最高风险 + 无消费者，后续 band 演进片）。
- **不做静默每轮自动提取**（成本 + 隐私分类，见 D2）；per-turn-auto 留后续。
- **不做对话小结 UX**（§3.12 手动 / 会话结束批量入口）→ S3。
- **不实现候选 deposit / 复习队列**（plan 10/11 未落地）；本片候选仅产出 + 展示计数，对齐现 `memory_candidates` 现状。
- 不改 `memory_candidates` 既有表结构（隔离风险，D1）。

## 证据与决策依据

### 关键设计决策

**D1：聊天候选用独立新表 `companion_memory_candidates`，不改 `memory_candidates`。**
- 证据：`memory_candidates.entry_id/material_id NOT NULL FK CASCADE`（`AppDatabase.swift:467-468`）物理排斥聊天来源行；改为可空需 SQLite 12 步整表重建，触碰学习内容主路径。
- 取舍：§3.8「复用现有 memory_candidates 路径」在 **管线层面**兑现（同 Kind 枚举、同 analysis→insert 形状、同 status 生命周期），不强行物理同表。S2a 作为低风险片，优先隔离风险。
- 后续：plan 10/11 deposit 管线落地时，统一候选评审面（读两表或届时再合并），记为未来切片，不在本片。

**D2：提取触发 = 用户显式动作，非静默每轮。**
- 成本：每次提取 = 一次独立 AI 请求；静默每轮使每轮 = 回复 + 提取双请求，与 §10.6「成本克制」冲突。
- 隐私分类（关键，已对齐既有先例）：决策 #10 / ADR-006 §6 / ADR-008 §6 把「系统自动注入」定义为 **Memory / Style 画像摘要被系统自动塞进 system prompt**（用户本次未直接键入、从画像拉取的内容），这是受门控、需授权 UX（首次预览 + per-conversation 开关）的行为。本片的提取**不属此类**：它发送的是**用户本人在对话中键入的消息**（已在回复时逐轮发往同一 Provider），由**用户显式点击「提取」触发**——形状与既有「生成学习材料 / 重新分析」**完全同构**（那两个动作同样把已存储的用户内容在显式触发下重发给 Provider，仅受全局 Provider 配置 + 请求预览约束，**不需每次单独授权 UX**）。因此提取沿用既有显式触发先例，**不进 S2b 的系统自动注入门**，无需新授权流程。
- **披露要求（落实 P0-1 修订）**：提取的请求预览必须**显式披露**「将本段对话内容发送给所配置 AI Provider 以提取词汇 / 表达」，不得仅以「同类目」一笔带过；失败诚实、不丢对话。
- 反向边界：**静默每轮自动提取**会从「用户显式触发」漂移为「后台自动外发」（ADR-006 §6 当前不允许），故明确排除（非目标）。
- 发送内容：提取对话窗口 → 同 Provider、同内容类目、**无新外发类目**。

**D3（已按 round-1 P1 收窄）：交付物 B = 最薄前向读接缝 + 架构备忘录，不改 band derive()，不预登记无消费者的 ledger 常量。**
- 证据：`GRDBLearnerBandProvider.band()` 只聚合 `dictionary_lookup_events`（struggling），无产出维度；红线测试守不读 AI 难度、不覆盖用户 level。`LearnerSourceType` 现仅 `memoryItem/manualMemory/practiceTextAttempt/entryBody`，无 companion 项。
- 取舍：产出 = 正向 / 流利度信号，喂入现 struggling 聚合在语义上错误（多说话 ≠ 更挣扎）。在语伴片内重开 band 数学违反「不在消费片重开最高风险地基」原则，且 S4b 刚落地需回归保护。
- **收窄（round-1 P1-1）**：为避免「无消费者的死常量 / 死枚举」，S2a **只交付**：① `productionUtterances(spaceID:after:)` 读接缝（即时有查询价值、可测）；② 架构备忘录记录前向接缝位置 + band 消费前需满足的三层论证（信号独立 / 逻辑正确：流利度≠努力度 / 数学形态）。**不在本片新增 `LearnerSourceType.companionProduction` 枚举项、不写 `analysis_ledger` 常量、不改 band**——这些随未来 band 产出消费片一并引入。仿 S4a「先建捕获再由 S4b 消费」，但 S2a 比 S4a 更薄（连 ledger cursor 都后置）。

**D4（落实 round-1 P0-2）：聊天候选 = 可复算派生数据，主数据边界在「升级为记忆条目」处。**
- 一致性：现 `memory_candidates` 无同步 / 备份 / 导出策略列，按派生数据处理（删 entry → CASCADE，重算 = 重新分析）。`companion_memory_candidates` 沿用同分类（删 thread → CASCADE，重算 = 显式重新提取），**保持两候选表一致**。
- 主数据边界：候选只是**评审暂存**；用户显式确认后**升级为记忆条目**（plan 10/11 → `learner_memory_facts`，该表已带 `includedInRecoverableBackup`，进可恢复备份 + 导出）。即「候选派生、记忆条目主数据」的分层与现有 Memory 层一致。
- 备份恢复一致性（诚实记录）：可恢复备份恢复后，`companion_messages`（主数据）在、`companion_memory_candidates`（派生）不在，用户可对保留的对话**重新显式提取**——与 `memory_candidates` 删材料后需重新分析的行为一致，属派生数据可接受降级。spec/007 §3 补一行派生候选失效 / 重建生命周期说明。

### 约束映射与验证路径（仅 LangoTrace 权威来源）

| 约束来源 | 规则 | 本片落点 / 验证 |
| --- | --- | --- |
| CLAUDE.md 决策 #10 / ADR-005 | 敏感内容仅用户明示触发才外发 | D2 显式触发；提取走请求预览；无系统自动注入（Memory 注入留 S2b） |
| ADR-008 §4 | 语伴会话 = 可恢复用户数据；删该条及后续 | 候选随 thread CASCADE；message_id SET NULL（删消息不连带删候选历史，仅断弱引用） |
| ADR-006 §4 红线 | level→generation→difficulty→band 闭环禁止；band 不读 AI 难度 / 不覆盖 level | D3 不改 band；产出接缝只读 userAuthored 用户消息，不含 AI 文本 / 难度 |
| ADR-006 §9 | 分析账本 + 高水位 cursor 作演进信号入口 | **S2a 不登记** `companionProduction` source_type 常量 / 不写 ledger / 不写 derive()（D3 round-1 收窄，避免无消费者死代码）；仅留前向读接缝 + 架构备忘录，待未来 band 产出消费片引入 |
| spec/005 AI-17 | Prompt 加固 / 选项化防注入 | 提取 prompt 为固定模板；对话内容经分隔与既有分析一致处理 |
| spec/007 | 派生数据 vs 主数据存储策略分层 | 候选 = 可复算派生（local-only，无策略列，对齐现 memory_candidates） |
| CLAUDE.md 1.2 | 基础设施首落地长期可扩展 | 候选表预留 message_id 弱引用；引擎 transport 注入式可测 |
| 决策 #8 | AI 能力走 Provider 抽象 | 提取经 `CompanionReplyTransport` / `AIChatStreamingService` 同族复用 |

## 涉及的代码文件路径（预计）

- `Packages/LangoTraceCore/Sources/LangoTraceCore/CompanionMemoryCandidate.swift`（新）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabaseCompanionRefluxMigration.swift`（新，v31）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（注册 v31）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBCompanionRepository.swift`（扩 `appendCompanionCandidates` / `companionCandidates` / `productionUtterances`）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/CompanionExtractionPromptRegistry.swift`（新）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/CompanionExtractionEngine.swift`（新）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIRequestProjections.swift`（扩 companion 提取投影）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIRequestPreviewProjection.swift`（扩 capability + 描述符）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/CompanionChatPresentation.swift` / `CompanionChatActions.swift` / `CompanionChatStore.swift` / `CompanionChatView.swift`（扩提取动作 + 计数态 + 失败态）
- `LangoTraceApp/AppEnvironment+Companion.swift`（装配提取 actions）
- `Packages/LangoTraceUI/.../Localizable.xcstrings`（新增 companion 提取 / 计数 / 失败本地化 key）

## 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift:638-665`（候选批量 insert 形状）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabaseAnalysisLedgerMigration.swift` / `GRDBAnalysisLedgerRepository.swift`（ledger 接缝）
- `Packages/LangoTraceLearnerModel/.../GRDBLearnerBandProvider.swift`（band 红线，确认不触碰）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/CompanionConversationEngine.swift`（引擎 + transport 形状）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIRequestProjections.swift` / `Packages/LangoTraceUI/.../AIRequestPreviewPresentation.swift`（请求预览复用）
- `docs/plans/done/2026-06-25-feature-lm03-s1-companion-mvp.md`（S1 接缝与命名）

## 涉及的文档路径（§17 文档影响）

- `docs/decisions/008-language-companion-as-grounded-practice-modality.md`（§3.8 反哺落地补注）
- `docs/architecture/002-system-map.md`（§4.11 companion 数据流补提取 + 产出接缝）
- `docs/architecture/notes/`（新备忘录：band 吃产出正向信号 = 后续演进；companion 候选统一面 = deposit 期决策）
- `docs/platform-page-inventory.md`（语伴页新增「提取词汇」动作行）
- `docs/spec/005-ai-provider-prompt-and-privacy.md`（提取 capability + 显式触发非自动外发分类）
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（v31 派生候选表登记；§3 派生数据列表补 `memory_candidates` / `companion_memory_candidates`（升级为 memory item 主数据前的评审暂存），落实 D4，round-2 P2-1）
- `docs/prompts/companion/extraction.md`（新，提取 prompt 结构化输出契约 + 隐私边界 directive 登记；与既有 `system.md` 并列，round-2 P2-2）
- `docs/plans/active/2026-06-25-docs-lm03-companion-decomposition.md`（S2→S2a/S2b 拆分标注）
- `docs/plans/active/2026-06-11-00-docs-series-progress.md`（仪表盘）

## 实施方案（按 Phase，TDD 先失败）

**Phase 1（Core）**：`CompanionMemoryCandidate`（复用 `LearningMemoryCandidate.Kind`）。先失败：构造 + 等值 + kind 映射用例。（产出读接缝直接复用既有 `CompanionMessage`，不新增值类型 / ledger 常量——round-1 P1-1 收窄。）
**Phase 2（Data）**：v31 迁移 `companion_memory_candidates`（迁移头当前 = v30，已核对 `AppDatabase.swift`，v31 为正确下一头）+ repository 三方法。**确定签名（round-2 P1-1/P1-3）**：
- `func appendCompanionCandidates(threadID: String, messageID: String?, candidates: [CompanionMemoryCandidate]) throws`
- `func companionCandidates(spaceID: String) throws -> [CompanionMemoryCandidate]`（created_at DESC）
- `func productionUtterances(spaceID: String, after: Date?) throws -> [CompanionMessage]`（返回 `space_id == ? AND role='user' AND detected_language == target_language_code` 的消息，`created_at` ASC，`after=nil` 全量、否则仅返回其后，**无 limit（窗口由调用方决策）**）。**目标语判定行内自洽**（round-2 复查修正）：`companion_messages` 已逐行存 `target_language_code`（v30，发送时刻快照），故用**行内 `detected_language == target_language_code` 比较**，不 join `language_spaces`——更简单且使用发送时历史目标语（虽决策 #4 一空间一语言使二者等价，行内比较仍更稳健、零耦合）

先失败用例（具名）：`companionMemoryCandidatesTableExistsAfterV31()`、`deletingThreadCascadeDeletesCandidates()`、`deletingMessageSetsCandidateMessageIdNullButRetainsCandidate()`（删消息→候选 message_id 置 NULL、count 不减，round-1 P2-2）、`productionUtterancesExcludeAssistantAndNonTargetMessages()`、`productionUtterancesCursorReturnsOnlyAfter()`、跨空间隔离。
**Phase 3（AI）**：新增 `AIRequestCapability.companionExtraction` 枚举项（Core，闭集新 case，round-2 P0-1）+ `CompanionExtractionPromptRegistry`（结构化输出契约 + 隐私边界 directive）+ `CompanionExtractionEngine.extract(window:targetLanguageCode:...) -> Result<[CompanionMemoryCandidate], CompanionExtractionError>`（注入 transport）。**错误契约（round-2 P0-2，对齐 `LearningMaterialGenerationService` 同族）**：无效 JSON → `.invalidStructuredOutput`；缺必填字段（text/kind）→ `.invalidStructuredOutput`；`candidates: []` → **成功、count=0**（非失败，UI 展示「未找到词汇」）；Provider 不可用 / 取消 → 复用 `CompanionReplyFailure` 同族映射。先失败：capability 投影为 `.companionExtraction` 且披露对话内容描述符（round-1 D2）；结构化解析 + 上述四错误分支；从用户 + AI 双方提取目标语项。
**Phase 4（UI）**：聊天页显式「提取词汇 / 表达」动作 + presentation 计数 / 加载 / 失败态 + 请求预览投影披露标签 + 本地化 key。**store 签名（round-2 P2-3）**：`func extractCompanionCandidates(threadID:) async`（触发→`isExtracting` loading→成功更新 count / 失败更新 error）。本地化 key 示例（final 实现期定）：`companion.extraction.action` / `.loading` / `.successCount` / `.empty` / `.failure`。先失败：store 提取流（触发→loading→计数 / 空 / 失败三态）+ presentation 映射 + 「来源消息已删除」候选态 + 请求预览披露文案断言 + 本地化 key 存在性 + UI 源无中文注释守卫。
**Phase 5（App）**：`AppEnvironment+Companion.swift` 装配提取 actions（resolve endpoint + transport + repository），注入三端。App 不直接 import GRDB（S1 教训：查询走 Data repo）。

每 Phase：先失败测试 → 最小实现 → 轻量单包测试（`swift test --package-path Packages/<pkg>`）+ `swiftformat`/`swiftlint` 自查 → commit。

## 严格方案自审核记录

### 第一轮（系统架构师，隔离子代理）

- 审核日期：2026-06-25
- 审核方式：隔离子代理（只读，按 plan-review-protocol §4.1 + §9 prompt）
- 轮次：第一轮
- 发现摘要：子代理报 2 P0 + 2 P1 + 2 P2 + 2 P3。主会话核验证据（均与代码一致）后**对两 P0 重新定级**：
  - 子代理 P0-1（D2 隐私分类）→ 主会话定 **P1**：提取与既有「生成学习材料 / 重新分析」**同构**（显式触发重发已存储用户内容，受全局 Provider 配置 + 请求预览约束，非每次单独授权），不进系统自动注入门成立；修订点在「论证需引先例 + 请求预览须显式披露提取」，非范围阻塞。
  - 子代理 P0-2（派生候选备份策略）→ 主会话定 **P1**：候选 = 可复算派生（与现 `memory_candidates` 一致），主数据边界在「升级为记忆条目」（`learner_memory_facts`，已进可恢复备份）；需文档化分层，非 schema 变更。
  - P1-1（产出接缝无消费者死代码）→ 采纳收窄：删 ledger 常量 / 枚举，只留读接缝 + 架构备忘录。
  - P1-2（band 红线负向守卫）/ P2-2（message_id SET NULL 孤立 + UI 来源已删态）/ P2-1（请求预览 capability 披露）→ 全部采纳，写入 TDD。
  - P3（长期合并两候选表 / 缺前向接缝备忘录）→ 记入剩余风险 + 文档影响。
- 写回修改：D2 重写（先例论证 + 披露要求 + 反向边界）；新增 D4（派生候选分层 + 备份恢复一致性）；D3 + 交付物 B + 非目标收窄（删 ledger 常量）；删 `CompanionProductionEvidence` 值类型；TDD 增 3 项守卫测试（孤立 / 产出过滤 / band 负向）+ 预览披露断言。
- 仍需用户确认的问题：无新增（拆分 + 排序 + Memory 排序已确认）；实现授权待批。
- 是否允许进入实现：第一轮后 **暂不**，待第二轮。

### 第二轮（测试 / 安全 / 落地性，隔离子代理）

- 审核日期：2026-06-25
- 审核方式：隔离子代理（只读，基于第一轮修订后方案，按 §4.2）
- 轮次：第二轮
- 发现摘要：子代理报 2 P0 + 3 P1 + 3 P2 + 2 P3。**全部为契约具体化缺口，非架构问题**——子代理独立核实迁移头 = v30、v31 为正确下一头，并确认方案尊重 ADR-006 / ADR-008 / spec/005 / spec/007、第一轮修订已整合。
  - P0-1（请求预览 capability 未显式声明）→ 采纳：Phase 3 明确新增 `AIRequestCapability.companionExtraction` 闭集 case + 披露描述符。
  - P0-2（结构化输出错误处理未定）→ 采纳：Phase 3 写定四错误分支（无效 JSON / 缺字段 → `.invalidStructuredOutput`；空 `[]` → 成功 count=0；Provider 不可用 / 取消复用同族），对齐 `LearningMaterialGenerationService`。
  - P1-1（FK 测试不具体）/ P1-3（`productionUtterances` 签名歧义）→ 采纳：Phase 2 写定三方法签名（`after: Date?`、created_at 排序、无 limit）+ 具名 FK / 过滤 / cursor 测试。
  - P1-2（band 负向守卫含糊）→ 采纳：具名 `bandProviderSourceUnchangedNoCompanionJoin`（源级 grep 无 `companion` + 插入候选后 band 结果不变双守）。
  - P2-1（spec/007 派生数据补文）/ P2-2（extraction.md 文件路径）/ P2-3（store 签名）→ 采纳，写入文档影响 + Phase 4。
  - P3-1（候选两表合并架构备忘录）/ P3-2（本地化 key 示例）→ 采纳为 notes + Phase 4 示例 key。
- 写回修改：Phase 2/3/4 全部补具体签名 + 错误契约 + 具名先失败测试；文档影响补 spec/007 派生数据补文 + `extraction.md`；capability 闭集新 case 落点明确。
- 仍需用户确认的问题：无（拆分 / 排序 / Memory 排序已确认）；仅余实现授权。
- 是否允许进入实现：**双轮自审完成，所有 P0/P1 已修订写回，剩余风险已记录** → 方案门禁满足，`自审核状态` 置 `Reviewed`；**实现仍待用户授权**（`状态` 维持 `Draft`，未经授权不进生产代码）。

## 复查方法

- 红线 grep 守卫：测试断言 `companion` 产出接缝 SQL 不含 `learning_text` / `difficulty` / AI 文本列；band provider 源未被本片修改（diff 范围检查）。
- 行为断言：产出读接缝只返回 `role='user'` 且 `detected_language` 命中目标语的消息；AI 助手消息与非目标语用户消息被排除。

## TDD / 测试落点

- `Packages/LangoTraceCoreTests/...`：`CompanionMemoryCandidateTests`。（**无** `CompanionProductionEvidenceTests`——D3 round-1 收窄已删除 `CompanionProductionEvidence` 值类型，产出读接缝直接复用既有 `CompanionMessage`，其窗口过滤测试落在 DataTests。）
- `Packages/LangoTraceDataTests/...`：`CompanionRefluxMigrationAndRepositoryTests`（建表 / FK / 插入读取 / 产出窗口过滤）。先失败用例：`func companionCandidatesTableExistsAfterV31()`（迁移未加前 `tableExists` 假）。另含：`func deletingMessageOrphansItsCandidatesNotDeletes()`（message_id SET NULL，round-1 P2-2）；`func productionUtterancesExcludeAssistantAndNonTargetMessages()`（只返回 user + 目标语）。
- `Packages/LangoTraceLearnerModelTests/...`：`func bandProviderSourceUnchangedNoCompanionJoin()` 负向守卫——band 计算不读 `companion_*` 表 / 不受聊天候选影响（round-1 P1-2，红线回归保护）。
- `Packages/LangoTraceAITests/...`：`CompanionExtractionEngineTests`（注入 stub transport → 结构化候选；失败映射）、`CompanionExtractionPromptRegistryTests`（directive / id / 结构化契约）。
- `Packages/LangoTraceUITests/.../Companion/`：`CompanionExtractionStoreTests`、`CompanionExtractionPresentationTests`（含「来源消息已删除」候选展示态，round-1 P2-2）、请求预览投影披露文案断言（round-1 P2-1 / P0-1 披露要求）、本地化 key 守卫。
- 不新增单元测试的项：无（全部行为可自动化）。

聚焦验证：`swift test --package-path Packages/LangoTraceData`（及对应改动包）。
完整验证：GitHub Actions `Build & Test`（含 v31 迁移 + 三端构建 + macOS app test + 全包 + lint），仓库临时 public、跑完 private。

## 文档影响检查

见上「涉及的文档路径」。v31 迁移 + 新 AI capability + 新 Prompt → 触发 spec/005 / 007 + architecture/002 + page-inventory + ADR-008 补注 + prompts 登记的专项判断。band 未改 → ADR-006 仅补「产出证据前向接缝」备忘录，不改 §10 契约。

## 完成标准

- 五 Phase TDD 落地，轻量单包测试绿 + 全量 CI 绿。
- §17 文档回写完成。
- band derive() / `memory_candidates` 既有表零改动（diff 验证）。
- 无新系统自动外发（提取为显式触发，走请求预览）。
- 移入 `done/`，仪表盘 + 拆解文档更新。

## 剩余风险

- 提取质量依赖 Provider 结构化输出能力（mimo 等弱 JSON 模型）——同既有学习材料分析既有风险，复用同族处理。
- 候选统一评审面延后到 deposit 管线（plan 10/11）；当前两表分离需届时合并，已记为未来切片。
- band 产出正向信号未消费——交付物 B 仅为前向接缝；若长期无消费者，需复审是否保留（已记备忘录）。

## 实施落地记录（2026-06-26）

2026-06-26 用户「方案审核通过，根据修订后的方案，立即进行实施」，授权后五 Phase TDD 落地：

- **Phase 1（Core）**：`CompanionMemoryCandidate`（复用 `LearningMemoryCandidate.Kind`，`messageID` 弱引用支持 SET NULL 存活）。`CompanionMemoryCandidateTests` 4 用例绿。
- **Phase 2（Data）**：`v31_create_companion_reflux_infrastructure` + `appendCompanionCandidates` / `companionCandidates`(created_at DESC) / `productionUtterances`(行内 `detected_language == target_language_code` 自洽、`after` cursor、无 limit)。`CompanionRefluxMigrationAndRepositoryTests` 10 用例 + LearnerModel `CompanionRefluxBandGuardTests` 2 守卫（band 源无 `companion` 引用 + 插入聊天数据后 band 不变）绿。
- **Phase 3（AI）**：`AIRequestCapability.companionExtraction` + `AIRequestContentDescriptor.companionConversation` 闭集新 case；`CompanionExtractionError`（`invalidStructuredOutput` + 复用 reply 失败族，conforms `Error` 供 `Result`）；`CompanionExtractionPromptRegistry`（隐私边界 + 结构化契约 directives）；`CompanionExtractionEngine` 复用 `CompanionReplyTransport`，四错误分支（空 `[]` = 成功 count 0）；`companionExtraction` 投影仅含 `companionConversation` 无新外发类目；UI 两处闭集 switch 补 case + 预览披露文案。AI 12 用例绿。
- **Phase 4（UI）**：`CompanionChatActions.extract` + `CompanionExtractionOutcome`；`CompanionChatStore.extractCandidates()`（触发→`isExtracting`→计数 / 空 / 失败三态，失败保留对话不伪造）；`CompanionCandidatePresentation`（含来源消息已删除态）+ 提取本地化 key + 诚实失败文案；`CompanionChatView` 工具栏提取按钮 + 结果区。UI 20 用例 + Han 源守卫绿。
- **Phase 5（App）**：`companionExtract` 装配（resolve 空间 + endpoint + secret → `CompanionExtractionEngine` 复用 S1 streaming transport → `appendCompanionCandidates` 锚定最新用户消息弱引用 → 读回 `companionCandidates` 全量列表）；App 不直接 import GRDB；本地 macOS `BUILD SUCCEEDED`。

**实现期对方案的两处一致性调整（均不改架构边界）**：① store 方法用参数无关的 `extractCandidates()`（读内部 `threadID`，与既有 `send()` / `clear()` 一致），而非方案 round-2 字面记法 `extractCompanionCandidates(threadID:)`；actions 闭包 `extract(threadID:)` 仍带 threadID。② `CompanionExtractionError` 命名沿用方案 `.invalidStructuredOutput`（新类型，与 `LearningMaterialGenerationService` 的 `.invalidStructuredResponse` 同义不同名，无需统一）。

§17 文档回写完成：architecture/002 §4.12、spec/005 / 007 变更记录、ADR-008 §6、page-inventory 三端、prompts/companion/extraction.md（新）、架构备忘录（新）、拆解文档、仪表盘。**完整验证已绿：GitHub Actions `Build & Test` run 28186684074（v31 迁移 + iPhone/iPad/macOS 构建 + macOS app test + 全包测试 + lint + check-docs），仓库跑前 public、跑完转回 private。**
