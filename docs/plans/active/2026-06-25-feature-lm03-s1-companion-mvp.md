# 任务方案：语伴 MVP 单线程文本对话引擎（LM03 Slice 1）

状态：In Progress（双轮自审 Reviewed + **用户 2026-06-25 实现授权**；按 §15 TDD 逐 Phase 落地中）
自审核状态：**Reviewed（双轮 + 两路隔离子代理对照 HEAD 再审；2026-06-25）**——两路隔离审查独立收敛 3 个 P0（Ability 基线取值错误 / 开关持久化未指定 / 导出策略列未明确）+ 4 个 P1，均已对照 HEAD 核验成立并收口写回（见 §13）。仍待用户实现授权。
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

本方案由 [LM03 语伴切片拆解](2026-06-25-docs-lm03-companion-decomposition.md) spawn，是 [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 学习者模型系列 **LM03（语伴，依赖链最长、排最后）的第一片 = MVP 单线程文本对话引擎**，严格受 [ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md) 六条硬边界约束。

- **2026-06-25 用户已定**：① 语伴策略 = **直接拆完整聊天引擎**（非会话式 affordance 中间形态）；② 语伴入口英文名 = **Language Companion**（用户在我标注「Companion 可能被读成助手」的张力后仍选定，按此落地）。
- 本片**仅拆 plan，未获实现授权**。`Draft` 状态默认不得进入生产代码实现。LM03-S2/S3/S4 不在本片范围，按门控留到各批开工前再拆。

## 1. 需求或 bug 描述

语迹现有四种练习（跟读、听写、回译、写作修改）**全是「再现 / 转换已有文本」**，唯独缺「自由产出 = 用目标语互动表达」这一练习模态（idea-03 §4.1）。LM03-S1 落地**最小可用语伴**：一个**默认关闭、需手动开启**、按语言空间隔离的**单线程纯文本多轮对话引擎**，始终用目标语回复，扎根用户显式带入的单条记录（方案 A），复用既有逐句 TTS 朗读，并在 Provider 不可用时优雅失败、不丢输入、不伪装。它补齐自由产出模态，同时**不**把产品重心从「用生活记录学习语言」转向聊天（ADR-008 §1）。

## 2. 现状描述（对照 2026-06-25 HEAD 核实）

- **多轮 + 流式传输能力已就绪（enabler 已 Done）**：`AIChatStreamingService.stream(_:) -> AsyncThrowingStream<AIChatStreamEvent, Error>`（`Packages/LangoTraceAI/.../AIChatStreamingService.swift:99-150`），请求 `AIChatStreamingServiceRequest`（`:58-88`，字段 `endpoint / plaintextSecret / system / messages: [ConversationMessage]`，含 `projectionMetadata()` 供 E6 预览 / 日志），事件 `AIChatStreamEvent.delta(String)`（`:5`），错误 `AIChatStreamingError`（`:13`，`.cancelled / .timedOut / .networkUnavailable / .providerRejected(...)`）。`ConversationMessage`（`Packages/LangoTraceCore/.../ConversationMessage.swift:23`）+ `ConversationRole{system,user,assistant}`（`:10`）。**当前仅 OpenAI 兼容族（chat/completions + responses）支持多轮 / 流式；Anthropic / mimo 流式后置**（enabler §17，LM03-S4 / 后续 run）。
- **逐句 TTS 可复用**：`SentenceAudioPlaybackActions`（`Packages/LangoTraceUI/.../SentenceAudioPlaybackActions.swift:4-63`，`handleTap(SentenceAudioRequest) async -> SentenceAudioPresentationState`）+ `SentenceAudioPlaybackAssembly.makeCoordinator()`（`LangoTraceApp/SentenceAudioPlaybackAssembly.swift:8-53`）。
- **本地语种识别 seam 已就绪（LM02-S2 引入）**：`LanguageDetector` 协议 + `NaturalLanguageDetector`（`Packages/LangoTraceLearnerModel/.../LanguageDetector.swift:10-33`，`detect(_:) -> (language, confidence)?`，可注入）。
- **难度基线来源 = `LanguageSpace.level`（onboarding 静态 `LanguageLevel`），不经 LearnerContextProvider（隔离再审 P0-1 纠正）**：`LearnerContextProvider.abilityCoverage(languageCode:)` 返回 `AbilityCoverage`（知识覆盖点列表，compute-on-read，**无 level / band / 难度字段**，`GRDBLearnerContextProvider.swift:21`），**不能**取静态 level。既有取静态 level 的唯一权威路径 = `languageSpace.level.rawValue`（`LearningContentStore.swift:194/:286`、`ReadingViews.swift:49/:456` 均如此）。故 **S1 难度基线直接读当前空间 `LanguageSpace.level.rawValue`，S1 完全不消费 `abilityCoverage()` / `memoryFacts()`**（Ability 覆盖 = LM02 既有、Memory 注入 = S2）。`LearnerContextProvider` 仅作 S2+ 接入点登记，S1 不依赖。
- **Prompt Registry 范式**：`LearningMaterialPromptRegistry`（`Packages/LangoTraceAI/.../LearningMaterialPromptRegistry.swift:18-97`，静态方法返回 `LearningMaterialRenderedPrompt`，prompt ID 形如 `"builtin.learning_material.generate.v1"`）；`docs/prompts/` 有 `learning-material/ photo-writing/ practice/ reading/ ai-provider/` 子目录，**无 `companion/`**。
- **GRDB 迁移头 = v29**：`AppDatabase.migrate()`（`Packages/LangoTraceData/.../AppDatabase.swift:59-148`，末位 `v29_create_analysis_ledger` 于 `:145`）；per-space FK + 级联范式见 `AppDatabaseAnalysisLedgerMigration.swift:23`（`language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE`）。**当前无 `companion_*` 任何表 / 实体 / 引擎 / UI 入口 / 设置开关**（全仓核实：语伴零实现）。
- **三端路由 exhaustive 枚举**：`PhoneRoute`（`PhoneRoute.swift:3`）、`PadWorkspaceRoute`（`PadMainModels.swift:4`）、`MacWorkspaceRoute` + `MacWorkspaceSection`（`MacMainModels.swift:4/71`）、`PadLearningPanelView`（`PadLearningPanelView.swift:35-80` switch）、`MacInspectorContent`（`MacInspectorContent.swift:19-88` switch）、`PremiumUILayoutRules`。练习导航种子 `PracticeSessionRouteSeed`（`PracticeRouting.swift:5-77`）。
- **记录详情 action seam**：`EntryDetailPresentation.LearningMaterialActionAvailability`（`EntryDetailPresentation.swift:43-67`）门控生成 / 重新分析 / 编辑；「围绕这条记录对话」入口附于此。
- **AppEnvironment seam 范式**：`AppEnvironment` 装配服务 + `@Entry` EnvironmentValues 注入 + store `reconnect*`（`LangoTraceApp/AppEnvironment.swift:14-69`、`LangoTraceApp.swift:136-145`、`AIRequestPreviewPresentation.swift:19-21`）。
- **memory_candidates 自动产出管线存在**（S2 复用，非 S1）：`GRDBLearningContentRepository.swift:638-665` 分析时自动入库。

## 3. 目标

1. **设置开关默认关闭**（ADR-008 §2.6）：全局「Language Companion」开关，默认 OFF；关闭时三端导航 / 菜单 / 入口不出现、相关数据与 AI 路径不激活。
2. **入口 = 练习 Tab 二级 + 记录详情**（ADR-008 §3，不做第四 Tab / 顶层导航）：练习 Tab 内「Language Companion」二级入口；记录详情「围绕这条记录对话」入口（方案 A 种子）。三端共享同一 store / Prompt Registry / Provider service。
3. **单线程纯文本多轮**（ADR-008 §4）：每语言空间一个固定语伴身份 + 一段会话；不支持新建 / 多会话；切空间即切语伴，历史互不串扰（thread 带 `language_space_id` FK）。
4. **始终目标语回复**（ADR-008 §2.1）：无论用户用母语或目标语发言，主回复一律用当前空间目标语；S1 **不做**长按翻译 / 解析 / 提示（refined 出 S1，见 §5）。
5. **会话 GRDB schema**（v30，per-space、local-only、不同步、可导出、可按条及后续 / 整段删除）：`conversation_companions`（per-space 人设配置）+ `companion_threads` + `companion_messages`；删除某条 = 删该条**及其后续全部**（ADR-008 §4 线性上下文自洽）；清空 = 删整段会话（S1 无摘要，故不涉摘要重建）。**为远期语音预留** message schema 接缝（§12.2 + 架构备忘录）。
6. **多轮编排 + 上下文窗口管理**：引擎从 thread 历史 + 人设 system prompt + Ability 基线 + 方案 A 种子装配 `[ConversationMessage]`；上下文超预算时**机械截断最旧轮次**（S1 不做摘要，摘要 = S3）；调用 `AIChatStreamingService` 并**缓冲全部 delta 后整段呈现**（S1 非流式 UX；增量流式 = S3）。
7. **人设 = Prompt Registry 固定模板 + 枚举选项（防注入）**：`CompanionPromptRegistry` 固定 system 模板；用户仅可调**枚举**——语气（友好 / 中性 / 幽默）、正式度（随意 / 正式）、纠错倾向（仅按需 / 温和复述 / 不纠错），默认**友好 / 随意 / 仅按需**；**无「陪练强度」**（难度由 Ability 层驱动，§3.9）；**v1 不开放任何自由文本**（含昵称），枚举→受控片段映射，绝不把用户文本拼进指令位（AI-17 加固）。
8. **模糊输入拟真确认**（ADR-008 §2.3 / idea-03 §3.4）：错误过多影响理解时，人设 prompt 指示语伴像真人确认 / 二次询问 / 克制调侃（默认偏友好），**不内联报错**；阈值实现期细化（§12.5）。
9. **语种识别本地 + AI 路由回退**（idea-03 §3.5）：本地 `NaturalLanguageDetector` 判用户输入语种（记于 message）；低置信时回退「system prompt 写明目标 / 源语言由模型自判」；**仅作主回复路由提示，不改「主回复永远目标语」规则**。
10. **难度三层自适应基线 v1 = 静态 `LanguageLevel`**（idea-03 §3.9，ADR-008 §5）：**直接读当前空间 `LanguageSpace.level.rawValue`**（与既有 `LearningContentStore` / `ReadingViews` 同路径）写入受控片段，**不经 `abilityCoverage()`**（隔离再审 P0-1）；v2 接 band；响应层 persona 指令读信号自然调整、不宣布难度；不暴露「陪练强度」选项。
11. **语伴朗读复用逐句 TTS**（idea-03 §3.7，初版必需）：语伴回复可逐句朗读，复用 `SentenceAudioPlaybackActions` / coordinator，不新造播放栈。
12. **话题来源仅方案 A**（ADR-008 §6 / idea-03 §3.6）：记录详情「围绕这条记录对话」**显式带入单条 Entry** 作首轮上下文（用户主动触发 = 决策 #10 明示触发）；**S1 不做方案 B 主动找话题**（= S2）。
13. **冷启动**（idea-03 §3.10）：通用入口（非方案 A）首屏 = **本地模板化问候（零外发）**，待用户首次发消息才发起 Provider 请求；方案 A 入口 = 用户已显式带入该 Entry，首轮即携该单条记录。
14. **失败态**（ADR-008 §7 / idea-03 §6.7）：Provider 不可用 / 限流 / 离线 → 明确「语伴暂时联系不上」+ 可重试 + **不丢用户已输入内容** + **不伪装正常回复**。

## 4. 范围

- **`Packages/LangoTraceCore`**：语伴域值类型——`CompanionPersona`（三枚举）+ 枚举→受控片段映射、`CompanionMessage` / `CompanionThread` 值模型（与持久层解耦的领域类型）、删除语义纯函数 `messagesAfterDeleting(_:in:)`（删该条及其后续）。复用既有 `ConversationMessage` / `ConversationRole`（Core）作 Provider 请求装配类型。
- **`Packages/LangoTraceAI`**：`CompanionConversationEngine`（多轮装配 + 上下文窗口截断 + 语种路由提示 + 缓冲 `AIChatStreamingService` + 失败态映射）；`CompanionPromptRegistry`（固定 system 模板 + 枚举→受控片段，prompt ID `"builtin.companion.system.v1"`）。
- **`Packages/LangoTraceData`**：v30 `companion` 迁移（`conversation_companions` + `companion_threads` + `companion_messages`，per-space FK ON DELETE CASCADE，local-only / 不同步 / 可导出，message schema 预留语音接缝列）；`GRDBCompanionRepository`（建 / 取活动 thread、追加消息、删该条及后续、清空 thread、读 / 写人设）。
- **`Packages/LangoTraceUI`**：`CompanionChatStore` + presentation + 三端聊天视图 + 练习 Tab 二级入口 + 记录详情入口 + 设置开关行 + 三端路由枚举新 case（exhaustive switch 全覆盖）+ 朗读复用 + 失败态呈现 + 本地化 key。
- **`LangoTraceApp`**：装配 `CompanionConversationEngine` + repository + 注入 `@Entry`；设置开关读写；TTS coordinator 复用接线。
- **文档**：架构备忘录（语音输入预留，硬前置 6）、spec/005（语伴 Prompt 进 Registry / 经 Provider / 预览 / 输出语言边界登记）、spec/006（主回复目标语边界）、spec/007（companion 表 + local-only / 导出口径登记）、architecture/002（语伴子系统 + 数据流）、ADR-008 交叉引用回写、page-inventory、idea-03 回指、decomposition + dashboard 标注。

## 5. 不做什么

- **不做长按翻译 / 语法解析 / 「提示」脚手架**（idea-03 §3.5/§3.10）——decomposition 已将其 refine 出 S1；S1 主回复始终目标语即可，长按操作留后续片。
- **不做方案 B 主动找话题 / Memory 生活事实注入 / 聊天反哺 memory_candidates / Ability 产出回流**（全部 = **S2**，依赖 FTS + 隐私两层控制 + PII scrubbing）。S1 **零系统自动注入** → 不触发决策 #10 的「系统自动外发」分支（仅用户打字 / 显式带入单条记录的主动触发）。
- **不做文本流式增量 UX**（= **S3**；S1 缓冲全部 delta 后整段呈现，传输用同一 `AIChatStreamingService`）。
- **不做对话记忆 / 滚动摘要 / 对话小结 / 温和复述默认开 / 常驻建议 chip**（= **S3**）；S1 上下文超预算仅机械截断最旧轮次。
- **不做 Style 受控片段注入 / Anthropic 适配 / 认知风格下投影**（= **S4 v2**）。
- **不做 band 动态难度**（v1 静态 level；band = LM02-S4b，已 Done 但 S1 难度基线刻意退静态 level，避免 S1 引入 band 耦合）。
- **不做语音输入 / 语音对话**（远期；S1 仅预留 schema / 输入栏 / 权限边界接缝，写架构备忘录）。
- **不开放自由文本人设字段**（v1 纯枚举，防注入）。
- **不做 PII scrubbing 基础设施**（绑定 S2 Memory 注入；S1 无系统自动注入，用户自有消息外发等同既有 AI 请求）——但在架构备忘录登记 S2 必须补。
- **不新建独立 Swift Package**（早期克制；S1 复用 Core/AI/Data/UI 既有边界；若 S2-S4 引擎膨胀再评估 `LangoTraceCompanion` 包，登记于架构备忘录）。
- **不把语伴做成第四 Tab / 顶层导航**（ADR-008 §3 红线）。
- **不做会话历史同步**（默认不同步；导出随统一口径，sync 引擎尚未实现）。

## 6. 证据与决策依据

- **ADR-008**（语伴定位）：六条硬边界（§2）、入口 = 练习 Tab 二级 + 记录详情（§3）、数据模型命名 `ConversationCompanion / CompanionThread / CompanionMessage`（§4）、删除语义（§4：删该条及后续 / 清空不清系统 Memory）、关系记忆归 Learner Model（§5）、隐私外发两类（§6：用户主动触发 vs 系统自动注入）、失败态（§7）。
- **ADR-006**：语伴 = LM03 消费者（§17）；Ability 基线 v1 静态 level（§10）；Memory 注入 = S2（本片不碰）。
- **idea-03**（设计来源）：§3.1-3.13 功能点、§3.9 三层难度、§3.10 冷启动、§5.2 真实新增工作、§6 核心决策关系、§7 第 2 步 MVP、§10.6 推荐定稿。
- **2026-05-25 语伴备忘录**：命名对齐、per-space 对话情景 vs 系统级生活事实（S2 处理）。
- **代码证据**：见 §2（enabler 多轮 / 流式服务、TTS、NL detector、LearnerContextProvider、Prompt Registry、v29 迁移头、三端路由枚举、记录详情 seam、AppEnvironment 范式均经 HEAD 核实存在 / 缺失）。
- **workflow 命中**：[`add-platform-screen`](../../workflows/add-platform-screen.md)（三端聊天 UI + 路由枚举）、[`add-storage-migration`](../../workflows/add-storage-migration.md)（v30 companion 表）、[`add-prompt`](../../workflows/add-prompt.md)（companion 人设 Prompt Registry）、[`add-ai-provider`](../../workflows/add-ai-provider.md) 部分（消费多轮服务，不新增 Provider）。

```text
证据能证明什么：enabler 已交付多轮 + 流式传输 + preview 投影；TTS / NL detector / LearnerContextProvider / Prompt Registry 范式 / per-space FK 级联 / 三端路由枚举均存在可复用；ADR-008 六边界 + 入口 + 命名 + 删除语义 + 失败态给出权威约束。故 S1 路径有权威 + 代码依据。
证据不能证明什么：① AI 实际输出语种 = 目标语无法单测断言（仅能验 system prompt 指令 + 请求携带正确目标语 code = 结构化验证）；② 模糊输入「拟真确认」阈值 idea-03 未给数值（§12.5 实现期细化，prompt 行为非确定性）；③ 上下文窗口预算具体 token 数须实现期标定（v1 取保守消息条数上限）。
迁移前提：v30 新增 companion 三表（建在 v29 之上，per-space FK 级联，不改既有表）；message schema 预留语音列（nullable，前向接缝）。
照搬风险：把语伴做成通用聊天（违 ADR-008 六边界）；自由文本人设致注入；系统自动注入 Memory 越 #10（S1 刻意不做）；上下文无限增长撑爆 context（S1 截断、S3 摘要）；流式半成品丢输入（S1 缓冲 + 失败态保输入）。
```

```text
是否需要 spike / probe / fixture / evidence：否——传输能力 enabler 已退险（首个 AsyncThrowingStream 已落地验证）。fixture = 合成对话历史 + 注入式 stub stream（成功 / 失败两路）+ 合成 Entry 种子，无真实用户敏感内容。
需要时的落点：不适用。
是否包含真实用户敏感内容：否——合成 fixture + 注入式 stub。
如何验证和清理：合成 fixture，无需清理。
```

## 7. 约束映射与验证路径

### 约束 1：默认关闭 + 关闭即不激活 — blocker
- 来源：ADR-008 §2.6
- 验证：全局开关默认 OFF；OFF 时三端入口不出现、引擎 / 数据路径不装配。测试 `companionEntryHiddenWhenDisabledOnAllPlatforms`（presentation 断言三端 case 在 disabled 时无语伴入口）+ 设置开关持久化默认 false。

### 约束 2：始终目标语回复 — blocker
- 来源：ADR-008 §2.1
- 验证：**结构化验证**（AI 输出语种不可单测，隔离再审 P1-1）——`CompanionPromptRegistry` 产出带 **typed directive 元数据**，测试断言 `directives.contains(.alwaysReplyTargetLanguage)`（`companionPromptDeclaresAlwaysTargetLanguageDirective`，**不脆弱字符串 contains**）+ 请求 system/messages 携当前空间目标语 code（`companionRequestCarriesSpaceTargetLanguage`）。真实输出语种质量留模拟器人工验证（page-inventory 关注点）。

### 约束 3：人设纯枚举、防注入 — blocker
- 来源：ADR-008 §4 / idea-03 §3.3 / AI-17
- 验证：人设仅三枚举→受控片段；**无自由文本进指令位**。测试 `personaMapsEnumOnlyToControlledFragments`（任意枚举组合产出固定片段、无用户字符串透传）+ 源级断言引擎不把用户消息内容拼进 system 模板指令位（用户消息只进 `.user` role）。

### 约束 4：单线程 per-space 隔离 + 删除语义 — blocker
- 来源：ADR-008 §4
- 验证：每 space 一活动 thread（`oneActiveThreadPerSpace`）；删某条 = 删该条及后续（纯函数 `messagesAfterDeletingDropsSubsequent` + repo `deleteMessageCascadesSubsequent`）；清空删整段（`clearThreadRemovesAllMessages`）；切 / 删 space 级联（`deletingSpaceCascadesCompanionThreadAndMessages`，FK ON DELETE CASCADE）。

### 约束 5：local-only / 不同步 / 可导出 + 语音接缝 — blocker
- 来源：ADR-008 §4 / idea-03 §3.7 / spec/007
- 验证：companion 三表显式 local-only、默认不同步、随主数据导出口径（**非**排除导出，区别于 dictionary_lookup_events）；message schema 含 nullable 语音接缝列（`audio_artifact_id` / `input_modality`，前向接缝，v1 恒文本）。测试 `companionMessageSchemaReservesVoiceSeam` + spec/007 登记。

### 约束 6：上下文窗口截断（不撑爆 / 不丢已存历史）— blocker
- 来源：idea-03 §5.2
- 验证：装配超保守消息上限时机械截断最旧轮次、**保留 system + 最近 N 轮**（`contextWindowTruncatesOldestKeepsRecent`）；截断仅作用于**发往 Provider 的装配**，**不删持久历史**（`truncationDoesNotMutatePersistedThread`）。S1 无摘要（明确标注 S3 接）。

### 约束 7：失败态保输入、不伪装 — blocker
- 来源：ADR-008 §7 / idea-03 §6.7
- 验证：注入失败 stream（各 `AIChatStreamingError` case）→ store 呈现明确错误 + 可重试 + **用户已输入文本保留**（`failureStatePreservesUserInputAndDoesNotFake`）；失败不写入 assistant 消息、不留半截伪回复。

### 约束 8：方案 A only、S1 零系统自动注入 — blocker
- 来源：ADR-008 §6 / 决策 #10 / idea-03 §3.6
- 验证：唯一记录外发路径 = 记录详情显式「围绕这条记录对话」带入**单条** Entry（用户主动触发）；引擎**不读取**其他 Entry / 不注入 Memory facts（`engineNeverInjectsMemoryFactsInS1` + 源级断言不调用 `memoryFacts` / FTS）；通用冷启动问候**本地模板零外发**（`coldStartGreetingIsLocalNoOutbound`）。

### 约束 9：语种识别本地优先 + 主回复不变 — warn
- 来源：idea-03 §3.5
- 验证：注入 `LanguageDetector` 判用户输入语种记于 message；低置信回退 AI 路由提示；**主回复路由提示不改「永远目标语」**（`languageRoutingNeverOverridesTargetLanguageReply`）。warn 因 AI 实际行为非确定。

### 约束 10：所有外发经 Provider 抽象 + E6 预览 / 日志 — blocker
- 来源：ADR-008 §6 / decision #8 / spec/005
- 验证：引擎只经 `AIChatStreamingService`（已带 `projectionMetadata()`）发请求，UI 不直连模型；对话级 log 写入接线（enabler §17 defer 到 LM03）在本片补 App-Shell recorder（`companionRequestGoesThroughProviderWithProjection`）。

## 8–11. 代码 / 文档路径 / bug 分析

- **新增代码**：
  - Core：`CompanionPersona.swift`（枚举 + 受控片段映射）、`CompanionMessage.swift` / `CompanionThread.swift`（领域值类型 + 删除语义纯函数）。
  - AI：`CompanionConversationEngine.swift`、`CompanionPromptRegistry.swift`。
  - Data：`AppDatabaseCompanionMigration.swift`（v30）、`GRDBCompanionRepository.swift`、`CompanionRow.swift`（解码）；`AppDatabase.swift:147` 前注册 v30。
  - UI：`CompanionChatStore.swift` / `CompanionChatPresentation.swift` / `CompanionChatView.swift`（三端）/ `CompanionChatActions.swift`（+ `@Entry`）；练习 Tab 二级入口 + 记录详情入口 + 设置开关行；`PhoneRoute` / `PadWorkspaceRoute` / `MacWorkspaceRoute` + `PadLearningPanelView` / `MacInspectorContent` / `PremiumUILayoutRules` 新 case。
  - App：`AppEnvironment+Companion.swift`（`makeCompanionConversationEngine` / `makeCompanionRepository` / 设置读写）、`LangoTraceApp.swift` 注入。
  - 本地化：`Resources/Localizable.xcstrings` companion key（入口 / 设置 / 失败态 / 冷启动问候 / 人设选项标签）。
- **参考代码**：`AIChatStreamingService`（多轮 / 流式）、`SentenceAudioPlaybackActions`（TTS）、`LanguageDetector`（语种）、`LearnerContextProvider`（Ability 基线）、`LearningMaterialPromptRegistry`（Prompt 范式）、`AppDatabaseAnalysisLedgerMigration`（FK 级联范式）、`AppEnvironment+ReadingLookupCapture.swift`（seam 装配范式）、LM02-S1 总览页（三端入口 + exhaustive switch 范式）。
- **涉及文档**：见 §4 文档列 + §17。
- 非 bug 任务。

## 12. 实施方案

### 12.0 硬前置（实现授权前必须满足）
1. **ADR-008 Accepted**（已满足）；**enabler 多轮 + 流式已 Done**（已满足，§2）。
2. **本 plan 双轮自审 Reviewed**（§13）+ **用户实现授权**（当前无）。
3. **架构备忘录（语音输入预留）已写入**（硬前置 6，本 plan 创建时一并落，§17）。

### 12.1 数据层（v30 companion schema + repository）
- `conversation_companions`：`space_id` PK/FK ON DELETE CASCADE、`tone` / `formality` / `correction` 枚举字符串、`created_at` / `updated_at`、显式 `local_only` / `included_in_export`（true）/ `synced`（false 语义）。
- `companion_threads`：`id` PK、`space_id` FK ON DELETE CASCADE、`source_entry_id` nullable FK ON DELETE SET NULL（方案 A 种子来源 / 弱链）、`created_at`。S1 每 space 至多一活动 thread。
- `companion_messages`：`id` PK、`thread_id` FK ON DELETE CASCADE、`sequence`（线性序，UNIQUE(thread_id, sequence)）、`role`、`content`、`detected_language` nullable、`target_language_code`、`created_at`、**语音接缝**：`input_modality`（默认 `'text'`，CHECK in('text','voice')）、`audio_artifact_id` nullable（前向，v1 恒 null，ON DELETE SET NULL 弱链媒体资产）。
- **导出 / 备份 / 同步策略列（隔离再审 P0-3 收口，显式三列，区别于 `dictionary_lookup_events`）**：companion 三表均带显式 `sync_policy='localOnly'` / `backup_policy='includedInSystemBackup'` / `export_policy='includedByDefault'`。**理由**：对话历史是**可恢复的用户主数据**（ADR-008 §4「可导出」），既非可重建派生（向量索引），亦非不可重算行为信号（`dictionary_lookup_events` 的 `excludedFromSystemBackup`/`excludedByDefault`）；故与 Entry / learning content 主数据同口径**纳入导出 + 系统备份**、**不同步**。须 spec/007 新增登记此第三类归属。
- `GRDBCompanionRepository`：`loadOrCreateThread(spaceID:sourceEntryID:)`、`appendMessage`、`messages(threadID:)`、`deleteMessageAndSubsequent(messageID:)`、`clearThread(threadID:)`、`loadPersona` / `savePersona`。先失败测试 → 实现。

### 12.2 领域类型 + 删除语义（Core）
- `CompanionPersona`（tone / formality / correction 三枚举 + `controlledFragments() -> [String]` 映射，**无自由文本**）。
- `CompanionThread` / `CompanionMessage` 值类型 + 纯函数 `messagesAfterDeleting(_ id:in:) -> [CompanionMessage]`（删该条及后续，与 repo 行为一致、可纯测）。
- **语音前向接缝**：`CompanionMessage` 带 `inputModality` / `audioArtifactID?`，文本设计不阻断远期语音（架构备忘录托管）。

### 12.3 对话引擎（AI）
- `CompanionPromptRegistry.systemPrompt(persona:targetLanguage:abilityBaseline:seedEntry:)` → 固定模板 + 受控片段（始终目标语 + 三层难度响应层指令 + 模糊输入拟真确认指令 + 枚举映射），prompt ID `"builtin.companion.system.v1"`，登记 `docs/prompts/companion/`。
- `CompanionConversationEngine.reply(to userInput:thread:persona:space:)`：
  1. 本地 `LanguageDetector` 判 `userInput` 语种（低置信 → 路由提示交模型）。
  2. 取难度基线（**`LanguageSpace.level.rawValue` → 静态 level 受控片段**；**不调用** `abilityCoverage()`，隔离再审 P0-1）。
  3. 装配 `[ConversationMessage]` = system（人设 + 基线 + 方案 A 种子 entry）+ 最近 N 轮历史（**上下文窗口截断**，保 system + 最近）+ 当前 user。
  4. 经 `AIChatStreamingService.stream(...)` 发送，**缓冲全部 `.delta` 整段返回**（S1 非流式）；`projectionMetadata()` 供 E6 预览 / 日志。
  5. 失败 → 映射 `AIChatStreamingError` 为 honest 失败态（不写 assistant 消息、保输入）。
- **红线**：引擎源**不调用** `memoryFacts` / FTS（约束 8）；用户内容只进 `.user` role（约束 3）。

### 12.4 UI（三端聊天 + 入口 + 开关 + 朗读 + 失败态）
- `CompanionChatStore`：发送 → optimistic 追加 user 消息 + 持久 → 调引擎 → 缓冲回复 → 持久 assistant；失败保输入；删该条及后续 / 清空；冷启动通用入口本地模板问候（零外发）。
- **三端路由新 case 清单（隔离再审 P1-3 收口，exhaustive switch 全覆盖防编译断裂）**：
  - `PhoneRoute.companionChat(CompanionChatRouteSeed?)`（seed 携 `sourceEntryID?`，nil = 冷启动通用问候）。
  - `PadWorkspaceRoute.companionChat(CompanionChatRouteSeed?)` + `PadLearningPanelView` switch 新 case。
  - `MacWorkspaceRoute.companionChat(CompanionChatRouteSeed?)`（或经 `MacWorkspaceSection.practice` 承载二级）+ `MacInspectorContent` switch 新 case。
  - `PremiumUILayoutRules`：核对是否需新增 companion 的 iPad/macOS 尺寸规则（若该枚举对路由 exhaustive 匹配则补 case）。
  - 入口：练习 Tab 二级「Language Companion」push（seed=nil）；记录详情「围绕这条记录对话」button（`EntryDetailPresentation.LearningMaterialActionAvailability` 邻位）→ route with `sourceEntryID`。
- **数据流（方案 A）**：seed 非 nil → 引擎取该 Entry `body` + language code 拼首轮 system context，并记 `companion_threads.source_entry_id`；seed=nil → 不装配 Entry context、仅本地模板问候。
- 设置开关行（默认 OFF）：开启后入口出现；关闭隐藏入口 + 不装配引擎。
- 朗读：每条 assistant 消息可逐句朗读，复用 `SentenceAudioPlaybackActions`；**权限边界同 LM01 逐句播放**（TTS Provider 配置后单句播放不再弹窗，spec/008 §27），用户仅接收回复、不录音、不触发麦克风权限（与 S2 语音输入区分，架构备忘录已登记）。
- **大文件拆分（隔离再审 P2 收口，防 swiftlint file_length 1300 error）**：`CompanionChatView` 按 iPhone / iPad / macOS 分离子视图文件，单文件不堆叠三端布局。
- 本地化 key 全覆盖（含失败态 / 冷启动问候 / 人设标签）。示例 key：`companion.entry.title`(=Language Companion) / `companion.settings.toggle` / `companion.settings.toggle.description` / `companion.greeting.coldStart` / `companion.failure.unavailable` / `companion.failure.retry` / `companion.persona.tone.{friendly,neutral,humorous}` / `companion.persona.formality.{casual,formal}` / `companion.persona.correction.{ifNeeded,warmRecast,none}`。

### 12.5 模糊输入阈值（实现期细化，推荐默认）
- idea-03 §3.4 未给数值；S1 推荐默认：**拟真确认 / 克制调侃由人设 prompt 指令承载**（非客户端阈值），偏友好、初学者安全感优先；不内联报错。客户端不设硬阈值（行为交模型 + persona 受控片段），故无确定性数值需 TDD；prompt 契约测试验「含拟真确认指令片段」即可。

### 12.6 装配（App）
- `AppEnvironment+Companion.swift`：装配 repository + 引擎（注入 `LanguageDetector` / `AIChatStreamingService` / TTS coordinator；难度基线读 `LanguageSpace.level`，**不注入 LearnerContextProvider**——S1 不消费）+ 设置开关读写；`@Entry` 注入 + store `reconnect*`。

### 12.7 设置开关持久化（隔离再审 P0-2 收口）
- **复用既有 UserDefaults 偏好范式**（`Core` 中 `AppearancePreferenceStore` + `UserDefaultsAppearancePreferenceStore` / `InterfaceLanguagePreferenceStore` + `UserDefaultsInterfaceLanguageStore`，各带 Core 单测）：
  - `Packages/LangoTraceCore`：新增 `CompanionFeaturePreferenceStore` 协议 + `UserDefaultsCompanionFeatureStore`（键 `"LanguageCompanionEnabled"`，**默认 false**），与既有两个偏好 store 同层、同测试范式。
  - App：`bootstrap()` 读取注入 environment；设置页 toggle `onChange` 写回 store。
  - **per-device（非 per-space）**：开关是 App 级特性闸，不入 companion per-space 表。
- 测试（Core）：`companionFeatureDefaultsToDisabled`（无存量读出 false）+ `companionFeatureTogglePersists`（写 true 后重读 true）。

### 12.8 始终目标语的结构化验证（隔离再审 P1-1 收口，防脆弱字符串匹配）
- `CompanionPromptRegistry.systemPrompt(...)` 返回带 **typed directive 元数据**的结果（如 `CompanionRenderedPrompt{ text, directives: Set<CompanionPromptDirective> }`，`CompanionPromptDirective` 含 `.alwaysReplyTargetLanguage` / `.ambiguityRealisticConfirm` / `.difficultyResponsiveLayer` / `.correctionPolicy(...)`）。
- 测试断言 `directives.contains(.alwaysReplyTargetLanguage)` 与 `.ambiguityRealisticConfirm`（**结构化、不脆弱字符串 contains**）+ 请求 system/messages 携当前空间目标语 code。模糊输入拟真确认作为 `.ambiguityRealisticConfirm` directive 承载（行为非确定性，prompt 契约验 directive 存在 + 模拟器人工抽样，page-inventory 关注点登记）。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-25
审核方式：隔离子代理双轮——两路独立隔离审查（第一轮系统架构 / 第二轮测试·安全·落地）各自对照 HEAD 代码核验；主会话汇总 + 逐条用 HEAD grep 复核证据后写回。
审核轮次：完整双轮（两路独立 + 主会话核验，三关）
未使用隔离审查的原因：不适用（用了隔离子代理）。
发现摘要（两路独立收敛——三个 P0 被两路同时命中，主会话 grep 核实全部成立）：
  [P0-1] 难度基线取值错误（两路同命中，HEAD 核实成立）：原 §2/§3目标10/§12.3 写「LearnerContextProvider.abilityCoverage → 静态 level」错误——abilityCoverage() 返回 AbilityCoverage（知识覆盖点列表、无 level 字段，GRDBLearnerContextProvider.swift:21）；静态 LanguageLevel 唯一权威路径 = languageSpace.level.rawValue（LearningContentStore:194/:286、ReadingViews:49/:456 核实）。收口：§2/§3目标10/§12.3/§12.6 改直接读 LanguageSpace.level，S1 完全不消费 abilityCoverage()/memoryFacts()。
  [P0-2] 设置开关持久化未指定（两路同命中，HEAD 核实成立）：原 §12.6 仅「设置开关读写」过简。HEAD 有偏好 store 范式（Core 的 AppearancePreferenceStore + UserDefaultsAppearancePreferenceStore / InterfaceLanguagePreferenceStore + UserDefaultsInterfaceLanguageStore，各带 Core 单测）。收口：新增 §12.7——CompanionFeaturePreferenceStore + UserDefaultsCompanionFeatureStore（键 LanguageCompanionEnabled、默认 false、per-device、复用范式 + Core 单测）；§15 加 companionFeatureDefaultsToDisabled/TogglePersists。
  [P0-3] companion 表导出策略与 dictionary_lookup_events 混淆（第二轮命中，spec/007 核实成立）：原 §12.1 仅「随主数据导出」未给策略列。收口：§12.1 显式三列 sync_policy=localOnly / backup_policy=includedInSystemBackup / export_policy=includedByDefault（对话=可恢复用户主数据，区别于行为信号的 excluded 策略），spec/007 新增第三类登记；§15 加 companionTablesIncludedInExportNotExcluded。
  [P1-1] 始终目标语验证脆弱（第二轮）：原 prompt 契约靠字符串 contains 脆弱。收口：§12.8——CompanionPromptRegistry 产出 typed directive 元数据，测试断言 directives.contains(.alwaysReplyTargetLanguage)（结构化）；§7约束2 / §15 同步改名 companionPromptDeclaresAlwaysTargetLanguageDirective。
  [P1-2] 拟真确认非确定性 + page-inventory 缺手工验证点（两路）：收口——拟真确认承载为 .ambiguityRealisticConfirm directive（prompt 契约验 directive 存在）；§17 page-inventory 新增 companion 手工验证关注点（拟真确认 / 目标语强制 / 失败保输入）。
  [P1-3] 三端 exhaustive switch 覆盖清单不清（两路）：收口——§12.4 列明 PhoneRoute/PadWorkspaceRoute/MacWorkspaceRoute companionChat(seed?) + PadLearningPanelView/MacInspectorContent/PremiumUILayoutRules 新 case + 记录详情入口数据流。
  [P1-4] 朗读权限边界模糊（第二轮）：收口——§12.4 注明复用 LM01 逐句播放权限边界（TTS 配置后不弹窗、不录音、不触发麦克风）；spec/008 §17 登记；架构备忘录已记 S2 语音输入须重评估。
  [P2] swiftlint file_length / 本地化 key / 语音备忘录存在性：收口——§12.4 CompanionChatView 按三端拆子视图防 1300 error + 列示例本地化 key；语音架构备忘录已于本 plan 创建时落地（docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md，§17）。
写回修改：§2 / §3目标10 / §12.1 / §12.3 / §12.4 / §12.6 / 新增 §12.7 / §12.8 / §7约束2 / §15 / §17 / §20 均已按上述收口同步更新（非仅审核记录描述）。
确认仍坚实（两路独立确认）：enabler AIChatStreamingService 多轮/流式 API 存在且缓冲消费 AsyncThrowingStream 作非流式 S1 合理；SentenceAudioPlaybackActions / LanguageDetector / Prompt Registry 范式 / v29 迁移头 / 三端路由枚举 / 记录详情 seam / 偏好 store 范式均 HEAD 核实存在；ADR-008 六边界 / ADR-006 无冲突；S1 零系统自动注入（不读 Memory / 不 FTS）使决策 #10 trivially 满足成立；删该条及后续 / per-space 隔离 / 失败保输入 / 上下文截断不丢持久历史设计坚实。
仍需用户确认的问题：① 语伴入口英文名（已答 Language Companion）；② 实现授权（当前无——本片仅拆 plan + 自审，未获实现授权）。
是否允许进入实现：否——双轮自审 Reviewed 仅表方案门禁完成；须用户实现授权方可按 §15 TDD 落地。
```

## 14. 复查方法

- 开关默认 OFF + 关闭不激活；三端入口仅 enabled 出现；始终目标语（prompt 契约 + 请求携带目标语 code）；人设纯枚举无注入面；单线程 per-space + 删该条及后续 + 清空 + space 级联；companion 表 local-only / 可导出 + 语音接缝；上下文截断不丢持久历史；失败保输入不伪装；S1 零系统自动注入（不读 Memory / 不 FTS）；外发经 Provider + E6 投影；朗读复用 TTS。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceCore/Tests/.../Companion/CompanionPersonaTests.swift（枚举→受控片段、无自由文本）
  Packages/LangoTraceCore/Tests/.../Companion/CompanionDeletionSemanticsTests.swift（删该条及后续纯函数）
  Packages/LangoTraceCore/Tests/.../Companion/CompanionFeatureStoreTests.swift（开关默认 false / 持久化，复用偏好 store 范式）
  Packages/LangoTraceData/Tests/.../GRDBCompanionRepositoryTests.swift（v30 schema / per-space FK 级联 / 序 / 删该条及后续 / 清空 / local-only / 语音接缝列）
  Packages/LangoTraceAI/Tests/.../Companion/CompanionConversationEngineTests.swift（多轮装配 / 上下文截断 / 语种路由 / 缓冲 stub stream / 失败映射 / 红线不读 Memory）
  Packages/LangoTraceAI/Tests/.../Companion/CompanionPromptRegistryTests.swift（始终目标语 + 拟真确认 + 难度响应层片段 + prompt ID）
  Packages/LangoTraceUI/Tests/.../Companion/CompanionChatStoreTests.swift（发送→持久→缓冲回复 / 失败保输入 / 删该条及后续 / 清空 / 冷启动本地问候零外发）
  Packages/LangoTraceUI/Tests/.../Companion/CompanionChatPresentationTests.swift（disabled 三端隐藏入口 / 本地化 key / 失败态文案）
先失败用例：
  companionFeatureDefaultsToDisabled / companionFeatureTogglePersists —— 约束 1（开关持久化，隔离再审 P0-2）。
  companionEntryHiddenWhenDisabledOnAllPlatforms —— 约束 1（三端入口门控）。
  companionPromptDeclaresAlwaysTargetLanguageDirective / companionRequestCarriesSpaceTargetLanguage —— 约束 2（结构化 directive，隔离再审 P1-1）。
  personaMapsEnumOnlyToControlledFragments —— 约束 3。
  oneActiveThreadPerSpace / messagesAfterDeletingDropsSubsequent / deleteMessageCascadesSubsequent / clearThreadRemovesAllMessages / deletingSpaceCascadesCompanionThreadAndMessages —— 约束 4。
  companionMessageSchemaReservesVoiceSeam / companionTablesIncludedInExportNotExcluded —— 约束 5（语音接缝 + 导出策略列，隔离再审 P0-3）。
  contextWindowTruncatesOldestKeepsRecent / truncationDoesNotMutatePersistedThread —— 约束 6。
  failureStatePreservesUserInputAndDoesNotFake —— 约束 7。
  engineNeverInjectsMemoryFactsInS1 / coldStartGreetingIsLocalNoOutbound —— 约束 8。
  languageRoutingNeverOverridesTargetLanguageReply —— 约束 9。
  companionRequestGoesThroughProviderWithProjection —— 约束 10。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceCore
  swift test --package-path Packages/LangoTraceData
  swift test --package-path Packages/LangoTraceAI
  swift test --package-path Packages/LangoTraceUI
不新增单元测试的原因：不适用，全程 TDD。AI 输出语种 / 模糊输入分寸为非确定性行为，以 prompt 契约 + 请求携带验证替代（约束 2/9 标注）。
```

## 16. 验证命令

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceUI
scripts/check-docs.sh
```

含 v30 migration + 三端 UI，收口前三端构建 / 全量验证按 CLAUDE.md 1.4 放 GitHub Actions（本机仅轻量单包 + format/lint）。

## 17. 文档影响检查

- **架构备忘录（本 plan 创建时一并写，硬前置 6）**：`docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md`——语伴语音输入 / 语音对话须为 message schema（`input_modality` / `audio_artifact_id`）、输入栏交互、Speech 权限边界预留；并登记「S2 必补 PII scrubbing + Memory 注入两层控制」「companion 引擎若 S2-S4 膨胀则评估独立 `LangoTraceCompanion` 包」两条跨片提醒。
- **spec/005**（AI Provider / Prompt / 隐私）：登记 companion 人设 Prompt 进 Registry、请求经 Provider + E6 预览 / 日志、输出语言边界（始终目标语）。
- **spec/006**（界面国际化与语言边界）：主回复目标语、入口 / 设置 / 失败态界面语边界。
- **spec/007**（数据存储 / 迁移 / 导出 / 附件）：companion 三表登记 + **显式策略列三类归属**（local-only / 不同步 / included-in-export + included-in-system-backup，作「可恢复用户主数据」第三类与 dictionary_lookup_events 的 excluded 信号类并列，隔离再审 P0-3）+ 语音接缝列。
- **spec/008**（权限 / 本地隐私 / 诊断）：companion 朗读复用 LM01 逐句播放权限边界（不弹窗 / 不录音 / 不触发麦克风；S2 语音输入须重评估，隔离再审 P1-4）。
- **architecture/002-system-map**：语伴子系统 + 数据流（练习入口 → 引擎 → Provider → 持久）+ 测试入口。
- **ADR-008**：交叉引用 S1 落地 + product-main-reference §9.13 定位文案收口（idea-03 §10.6「合并为一次修订」，含 §3「产品不是 AI 聊天工具」补「受 ADR-008 约束的有界例外」已存在则核对）。
- **page-inventory**：三端语伴页面 + 入口 + 状态 + 代码路径登记 + **手工验证关注点**（隔离再审 P1-2）：① 始终目标语回复；② 模糊输入拟真确认（非确定性、模拟器抽样）；③ 失败态保输入不伪装。
- **idea-03 / decomposition / dashboard**：S1 落地回指 + 「→ 已拆 active plan」标注 + 待办总表登记。
- **review**：新子系统 + migration + Prompt + 隐私边界——命中专项审查触发（收口时判断）。

## 18–19. 实施记录 / 完成标准

**2026-06-25 落地（dev 分支，用户实现授权后按 §15 TDD 逐 Phase）**：

- **Phase 1（Core）**：`CompanionPersona`（三枚举→受控片段，无自由文本）+ `CompanionMessage`/`CompanionThread`（语音接缝 `inputModality`/`audioArtifactID`）+ `CompanionConversation.messagesAfterDeleting`（删该条及后续纯函数）+ `CompanionFeaturePreferenceStore`/`UserDefaultsCompanionFeatureStore`（默认 false）+ `CompanionReplyFailure`。Core 255 tests 绿。
- **Phase 2（Data）**：v30 `conversation_companions`/`companion_threads`/`companion_messages`（per-space FK CASCADE + `source_entry_id` ON DELETE SET NULL + UNIQUE(thread_id,sequence) + 语音接缝列 + 显式策略列 localOnly/includedInSystemBackup/includedByDefault）+ `GRDBCompanionRepository`。Data 262 tests 绿。
- **Phase 3（AI）**：`CompanionPromptRegistry`（typed directive 元数据 + `builtin.companion.system.v1` + `docs/prompts/companion/system.md`）+ `CompanionConversationEngine`（transport seam + 检测闭包 + 上下文截断保最近不动持久 + 缓冲非流式 + 失败映射 + 红线零 Memory/零 FTS）。AI 206 tests 绿。
- **Phase 4（UI）**：`CompanionChatStore`/`CompanionChatPresentation`/`CompanionChatActions`/`CompanionChatView`（三端聊天 + 冷启动本地问候零外发 + 失败保输入）；`companionChat(seed?)` 路由接入三端全部 exhaustive switch；入口 = 设置开关行（env 驱动，三端）+ 练习 Tab 二级入口（iPhone/macOS）+ 记录详情「围绕这条记录对话」按钮（三端，方案 A 种子）；11 个 companion 本地化 key（en+zh-Hans）。三端 UI 编译 + UI 596 tests 绿（含 Han guard）。
- **Phase 5（App）**：`AppEnvironment+Companion`（repository + 引擎 + `CompanionStreamingTransport` 绑定解析的 Provider endpoint+secret；难度基线读 `LanguageSpace.level`；方案 A 首轮注入单条 Entry；成功才持久 user+assistant）+ `AppEnvironment` 字段 + `LangoTraceApp` 三处注入 + @State 镜像开关。**xcodegen + macOS app 构建 SUCCEEDED**。
- **验证**：轻量本机 Core 255 + Data 262 + AI 206 + UI 596 全绿；macOS app 构建绿；format/lint 0 error（AppEnvironment 抽出 `AIRequestPreviewEndpointCache` 保 <1300）。含 v30 migration + iPhone/iPad 构建的全量 Build & Test 走 GitHub Actions CI。

### 实施期偏差（诚实记录，须用户知悉）

1. **逐句 TTS 朗读暂缓（idea-03 §3.7 初版必需 → 本片未实现）**：既有 `SentenceAudioPlaybackActions` seam 形状是「学习内容渲染句（rendering+sentence+index）」，复用于任意对话回复文本需非平凡适配（合成 rendering 或新 TTS 入口）。为不让 S1 view 膨胀且避免改动既有 TTS seam，本片**仅交付文本聊天**，朗读作为**低风险加性后续增量**（基础设施已就绪，接线即可）。已登记为剩余项（§20）。
2. **Pad 通用冷启动入口经记录详情而非独立练习落地页**：Pad 工作区是 entry-driven（无独立练习 landing tab），通用「练习 Tab 二级」入口在 iPhone/macOS 落地；Pad 通过记录详情「围绕这条记录对话」（方案 A）+ 设置开关触达语伴——符合「界面按设备分别设计」（决策 #2），非功能缺失。

完成标准（达成项）：① §15 全部先失败测试转绿；② 开关默认 OFF / 关闭不激活 / 三端入口 env 门控；③ 始终目标语（typed directive 契约 + 请求携带目标语 code）；④ 人设纯枚举无注入；⑤ 单线程 per-space + 删该条及后续 + 清空 + space 级联；⑥ companion 表 local-only / 可导出 + 语音接缝；⑦ 上下文截断不丢持久历史；⑧ 失败保输入不伪装；⑨ S1 零系统自动注入；⑩ 外发经 Provider；⑪ macOS app 构建绿。**待全量 CI（iPhone/iPad/macOS 构建 + v30 migration）绿后移入 done/。** 偏差项：⑫ 朗读暂缓（§20）。

完成标准：① §15 全部先失败测试转绿，§16 验证含 CI 三端构建 + v30 migration 全绿；② 开关默认 OFF / 关闭不激活 / 三端入口仅 enabled 出现；③ 始终目标语（契约 + 携带验证）；④ 人设纯枚举无注入；⑤ 单线程 per-space + 删该条及后续 + 清空 + space 级联；⑥ companion 表 local-only / 可导出 + 语音接缝；⑦ 上下文截断不丢持久历史；⑧ 失败保输入不伪装；⑨ S1 零系统自动注入；⑩ 外发经 Provider + E6 投影；⑪ 朗读复用 TTS；⑫ §17 文档回写 + 架构备忘录已落；移入 `done/` + dashboard 更新。

## 20. 剩余风险

- **me-too + 价值后置（ADR-008 §风险）**：语伴差异化依赖记录语料 + 关系记忆 + FTS 找话题成熟（= S2+），S1 仅交付「能聊」骨架；空记录场景优雅退化（通用轻量话题 + 引导去记录）。
- **在线依赖 vs 本地优先张力（ADR-008 §风险 / idea-03 §10.4）**：聊天 UI 诱发「秒回」期待；以失败态 + 「练习对象而非助手」文案 / 朗读优先缓解。
- **始终目标语 / 拟真确认非确定性**：AI 实际行为不可单测，仅以 prompt 契约 + 请求携带验证；真实质量留模拟器人工验证（page-inventory 关注点）。
- **上下文无摘要（S1 截断有损）**：长会话截断旧轮致语伴「忘事」；S1 明确退化、S3 接滚动摘要 + 对话记忆。
- **S1 零系统自动注入是隐私简化前提**：一旦 S2 引入 Memory 注入，须补首次预览 + per-conversation toggle + PII scrubbing（架构备忘录登记，S2 门控）。
- **本环境（若 Linux）无 Swift 工具链**：migration / 三端构建 / 引擎行为须 macOS / CI 验证。
- **Anthropic / mimo 流式未适配**：S1 限 OpenAI 兼容族；其他 Provider 多轮 / 流式 = S4 / 后续 run（失败态须对不支持 Provider 给清晰提示）。
- **难度基线退静态 level（隔离再审 P0-1 后）**：S1 刻意读 `LanguageSpace.level` 不接 band/AbilityCoverage；若 onboarding 自评失真，S1 基线即失真——可接受退化（v2 接 LM02-S4b band；onboarding 措辞软化 = 登记孤儿微切片）。
- **始终目标语 / 拟真确认非确定性**：以结构化 directive 契约 + 请求携带验证替代输出语种单测；真实质量留模拟器人工验证（page-inventory 关注点）。
- **逐句 TTS 朗读暂缓（剩余项，§18 偏差 1）**：本片仅文本聊天；朗读复用既有 TTS seam 需适配「任意对话文本→可朗读句」，作低风险加性增量后续接线，不阻断 S1 文本闭环。
