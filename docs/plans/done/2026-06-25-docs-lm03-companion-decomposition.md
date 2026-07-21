# 任务方案：语伴（LM03）切片拆解与决策收口（完整聊天引擎）

状态：Done
自审核状态：N/A（决策 / 排序导航文档；各子片进入实现前各自按 plan-review-protocol 双轮自审核）
类型：docs
创建日期：2026-06-25
最后更新日期：2026-07-22（**收口归档**：LM03 语伴系列 S1→S2a→S2b-1→S2b-2→S3a→S3b-1→S3b-2→S4b→S4a 全部 Done 移 `done/`；「仍须用户定的少数项」已在实现批次逐一收口〔Style v2 时机=§9 方案 A、salience=时近性+种类配额、模糊输入=directive+人工验证、入口英文名=Language Companion〕；远期候选〔语音对话/场景模式/向量检索〕已登记至 `docs/idea/README.md`。收口任务见 `docs/plans/done/2026-07-22-docs-lm-series-closure-and-entry-alignment.md`）

## 这份文档是什么

[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 把学习者模型分 LM01/LM02/LM03，语伴（LM03）是依赖链最长、排最后的消费者。[ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md) 已固化语伴**定位**（扎根记录的语言对话练习模态 + 六条硬边界 + 入口 = 练习 Tab 二级 + 记录详情），[Provider 多轮 + 流式方案](2026-06-25-feature-ai-provider-multi-turn-and-streaming.md) 已拆为前置。本文件把语伴**功能本体**（`docs/idea/03-conversation-partner.md` §3 各节）拆成有界子片，并**收口 idea-03 §9 / §10.6 的全部待决点**。

**2026-06-25 用户决策**：语伴策略采 **直接拆完整聊天引擎**（非 idea-03 §10.2 的「会话式 affordance 中间形态」）。故本文件按完整单线程多轮对话引擎拆解。

它**只做拆解 / 排序 / 决策导航**，不是实现方案：
- 不替代各子片未来的 active plan；每子片**进入实现前**各自创建 active plan、双轮自审、走用户确认链路。
- 不替代 ADR-006 / ADR-008（权威决策）、idea-03（设计来源）、Provider 前置方案、2026-05-25 语伴备忘录。
- 冲突时以 ADR-008 / ADR-006 与各权威文档为准。

## 硬前置（全部子片）

1. **ADR-008 定位**（已 Accepted）：六条硬边界 + 入口 = 练习 Tab 二级 / 记录详情（**不做第四 Tab / 顶层导航**）。
2. **Provider 多轮 + 文本流式**（**已落地 `done/2026-06-25-feature-ai-provider-multi-turn-and-streaming.md`**：OpenAI 兼容族多轮 messages + 文本流式 `AsyncThrowingStream` 已就绪，并由 LM03-S1/S3a 消费）。Anthropic Messages 适配后置（LM03-S4）。
3. **数据依赖已就绪**：plan 09（请求预览 / 日志，E6）已落地；plan 10/11（记忆 deposit / 复习，E7/E8）已落地；plan 12（FTS，E9）已落地——方案 B 找话题 + 聊天反哺记忆 + Memory 注入的数据底子具备。
4. **2026-05-25 语伴备忘录对齐**：复用命名 `ConversationCompanion / CompanionThread / CompanionMessage / CompanionMemorySummary / CompanionAnalysis`；对话情景 per-space、生活事实系统级（ADR-006 §7.1 / idea-03 §10.1）。
5. **LM02 Memory（S1）就绪**：Memory 注入依赖 S1 系统级生活事实 + `LearnerContextProvider`；Style 注入依赖 S2（v2）。
6. **语音输入架构备忘录（idea-03 §3.7）**：拆子片时必须把「语伴语音输入 / 语音对话」写入 `docs/architecture/notes/`，说明文本设计须为后续语音预留 message schema / 输入栏 / Speech 权限边界。

## 子片拆解（完整引擎，按依赖排序）

### LM03-S1：MVP 单线程文本对话引擎
> **→ 已 Done（2026-06-25）**：[`done/2026-06-25-feature-lm03-s1-companion-mvp.md`](../done/2026-06-25-feature-lm03-s1-companion-mvp.md)。五 Phase TDD 全落地 + **全量 CI 绿（run 28178973216：iPhone/iPad/macOS 构建 + v30 migration + macOS app test + 全包测试 + lint）**。入口英文名 = **Language Companion**。自审隔离再审收口 3 P0（难度基线 `abilityCoverage()` 无 level→改读 `LanguageSpace.level`；开关持久化→`UserDefaultsCompanionFeatureStore`；导出策略列→companion 表 included-in-export/backup 可恢复主数据第三类）+ 4 P1（typed directive / page-inventory 手工验证 / exhaustive switch 清单 / 朗读权限）。实施期 CI 修复：App 直接 import GRDB 致 test 链接失败 → 查询移入 Data repo。**偏差**：逐句 TTS 朗读暂缓（加性后续，plan §18）；Pad 通用入口经记录详情。语音预留备忘录 `docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md`。详见该 plan §12–§13 / §18 / §20。

- **范围**：设置开关（默认关闭，ADR-008）+ 练习 Tab 二级入口 + 记录详情「围绕这条记录对话」入口；单一会话（不支持多会话）纯文本多轮；始终目标语言回复；会话 GRDB schema（`CompanionThread/Message`，per-space、local-only、不同步、可按条及后续 / 整段删除）；多轮编排 + 上下文窗口管理；人设 = Prompt Registry 固定模板 + 枚举选项（语气 / 正式度 / 纠错倾向，防注入）；模糊输入拟真确认；语种识别本地 `NaturalLanguage` + AI 路由回退；难度三层自适应基线 v1 = 静态 `LanguageLevel`（§3.9）；语伴朗读复用既有逐句 TTS（ADR-008 / §3.7 初版必需）；话题来源仅方案 A（用户显式带入单条记录）；失败态（Provider 不可用 / 离线，不丢输入，不伪装）。**注（S1 实现细化）**：长按翻译 / 解析 / 提示 refine 出 S1（后续片）；流式 UX 后置 S3（S1 缓冲 enabler 流）；难度基线读 `LanguageSpace.level` 而非 `abilityCoverage()`；S1 零系统自动注入（不注入 Memory / 不 FTS）。
- **硬前置**：ADR-008 + Provider 多轮（流式可后置到 S3）+ 2026-05-25 命名。
- **触碰**：新 Speech/AI 编排 seam、新会话 GRDB schema（migration）、三端聊天 UI（工作量大头）、新 Prompt Registry 人设条目、设置开关、语种识别。
- **风险**：高（三端聊天 UI + 多轮编排 + 上下文预算 + 失败态）；但不依赖 LM02 后续切片（难度退静态 level）。

### LM03-S2：找话题（方案 B）+ Memory 注入 + 聊天反哺记忆
> **2026-06-25 用户决策：按风险拆 S2a / S2b**（仿 S4a/S4b 先例）。Memory 注入 v1 排序 = **时近性 + 种类配额**（salience 列 v1 不参与，留 v2 FTS 相关性召回）。

#### LM03-S2a：聊天反哺学习（入站 / 本地，低外发增量）
> **→ 已 Done（2026-06-26）**：[`done/2026-06-25-feature-lm03-s2a-companion-reflux.md`](../done/2026-06-25-feature-lm03-s2a-companion-reflux.md)。五 Phase TDD 全落地（Core 候选值类型 / v31 迁移 + repo 三方法 + band 红线守卫 / 提取引擎 + Prompt Registry + capability 闭集新 case / 三端 UI 提取动作 + 三态 + 预览披露 + 本地化 / App 装配）；轻量单包测试全绿 + 全量 CI `Build & Test` 全绿（run 28186684074）。双轮隔离自审完成（两 P0 经主会话核验降为 P1；第二轮 5 项契约具体化全采纳）。**新表 `companion_memory_candidates`（v31）独立、不改 memory_candidates；band derive() 零改动；无新系统自动外发**。备忘录：`docs/architecture/notes/2026-06-26-companion-reflux-production-signal-and-candidate-unification-notes.md`。
- **范围**：① 聊天词汇 / 表达提取 → **新表 `companion_memory_candidates`（v31，独立表，不改 memory_candidates）**，**显式触发**（非静默每轮，成本 + 隐私分类双理由——提取同既有「重新分析」显式重发先例，不进系统自动注入门）；② 用户目标语发言 → Ability 产出证据**最薄前向读接缝** `productionUtterances()` + 架构备忘录，**不改 band derive() / 不登记无消费者 ledger 常量**（红线 + 最高风险后置）。
- **硬前置**：LM03-S1（Done）。**不依赖** Memory / FTS / 隐私两层（那些属 S2b）。
- **风险**：中（新迁移 + 新 AI 提取引擎 + 三端动作；但无新系统自动外发，band 零改动）。

#### LM03-S2b：外发注入 —— 2026-06-26 用户决策再拆 S2b-1 / S2b-2

> 整个语伴系列**最高隐私门**（系统自动注入外发，受决策 #10），原单片含三件重活，2026-06-26 用户确认按风险再拆，把基础的 Memory 注入半片与最复杂的方案B 找话题半片分离、逐门控授权。

##### LM03-S2b-1：Memory 注入 + 两层隐私控制 + PII scrubbing
> **→ Done（2026-06-26，全量 CI 绿 run 28214663981）**：[`done/2026-06-26-feature-lm03-s2b1-companion-memory-injection.md`](../done/2026-06-26-feature-lm03-s2b1-companion-memory-injection.md)。双轮自审捕获并写回 4 P0（授权 UX 须一次性预览非发送前拦截 / `.longTermMemory` 改用 `.curatedLearnerMemory` 不破全局红线 / scrub 须含历史回放 / 预览 card 不可复用须新建语伴专用 view）+ 7 P1 + 关键 P2（注入门纯函数 seam 等）→ Reviewed → 用户授权（接受 3 项推荐默认）→ 六 Phase 落地（v32 迁移 + consent/gate/scrubber + selection + prompt 注入 + 三端 UI 一次性预览 + App 装配）→ §17 回写 → 全量 CI 绿。
- **范围**：系统级生活事实经 `LearnerContextProvider.memoryFacts(.global)` 取 **top-5（时近性 + 种类配额）** → PII scrubbing → 注入语伴 system prompt（§3.11）；两层隐私控制（全局首次预览 + 全局关 / per-conversation toggle，v32 `companion_threads.uses_learner_profile`）；PII scrubbing **v1 = 手机号 + 身份证号**（用户 2026-06-26 定）；注入预览**如实披露** `.longTermMemory`（首个 `companionConversation` capability，§6.9）。
- **硬前置**：LM03-S1（Done）+ LM02-S1 Memory / `LearnerContextProvider`（就绪）+ **两层隐私 + PII scrubbing 可验证**（额外门）。
- **风险**：高（最高隐私门核心：系统自动注入外发 + 预览披露语义变化）。

##### LM03-S2b-2：方案B 主动找话题（一次性授权 + recency 智能最小发送）
> **→ Done（2026-06-26，全量 CI 绿 run 28217180799）**：[`done/2026-06-26-feature-lm03-s2b2-companion-active-topic-finding.md`](../done/2026-06-26-feature-lm03-s2b2-companion-active-topic-finding.md)。
- **范围（自审后定）**：一次性全局话题授权（mirror S2b-1 consent）+ 复用 v32 per-conversation 开关 + **recency top-1 最小发送**（FTS 须 rebuild 易陈旧 + body 含 AI 文本，降后续）+ 新 `.broughtInRecords` descriptor（A/B 共用）；**找话题仅 send 回合内**（不破 S1 冷启动零外发）；无新 migration。
- **硬前置**：LM03-S1 + LM03-S2b-1（Done，复用其隐私闸 + PII scrubbing + 一次性预览）。
- **自审重要产出**：两轮独立命中并将修复 **S2b-1/方案A 既有隐私漏洞**——`seedEntryBody` 未脱敏外发 + 方案A 记录零 preview 披露（本片连带修复）。
- **风险**：高（系统自动注入外发 + 单条记录 PII 集中度）。待用户授权 + 2 项确认（单条记录一次性预览闸是否够 / 连带修方案A 披露）。

### LM03-S3：文本流式 + 对话记忆 + 小结 + 温和复述 —— 2026-06-26 用户决策拆 S3a / S3b
> 原单片捆五件事、风险差异大（流式/复述低风险 vs 摘要持久化/一致性高风险），按风险拆。

#### LM03-S3a：文本流式 UX + 温和复述（低风险）
> **→ 已 Done（2026-06-26，全量 CI 绿 run 28226376483）**：[`done/2026-06-26-feature-lm03-s3a-companion-streaming-and-recast.md`](../done/2026-06-26-feature-lm03-s3a-companion-streaming-and-recast.md)。双轮隔离自审收口 1 P0（并发模型：原 cumulative+Task hop+单调守卫不保序 → 改 `AsyncStream` + 单 MainActor consumer 顺序消费，correct-by-construction）+ 多 P1（send 闭包 +onPartial 破坏 8 fixture 机械补 `_` / loadThread 新增 loadPersona 带出 correction / setGentleRecast read-modify-write 保 tone-formality）+ P2（取消失败清空 in-flight 升 TDD / 持久完整文本守卫 / 空白 partial 不渲染 / warmRecast fragment 文本断言）。六落点 TDD 全落地（engine onPartial 累积 + recast fragment / store AsyncStream 流式 + recast 派生 / view in-flight 气泡 + toggle / Data read-modify-write 保 tone / 本地化 key）。**流式只改显示——无新 migration / 无新 AI capability / 无新外发类目，请求体·隐私闸·PII scrub 与 S1·S2b 一致；`inFlightReply` 纯 UI 态不入持久路径；band 红线未碰**。
- **范围**：文本流式逐字显示 UX（复用既有 `CompanionReplyTransport` 流式，仅 surface deltas + in-flight 态，**不改持久化**）；温和复述纠正 opt-in（暴露既有 `CompanionCorrection.warmRecast`，默认 `.ifNeeded` 关，persona save 复用）。建议 chip defer（长按提示本身未建）。
- **硬前置**：LM03-S1（Done）+ Provider 流式（就绪）。**无新 migration / 无新 AI capability / 无新外发类目**。
- **风险**：低（纯 UX + persona 选项暴露；流式并发顺序是主要审查点）。

#### LM03-S3b：对话记忆/滚动摘要 + 对话小结 —— 2026-06-26 用户决策拆 S3b-1 / S3b-2
> 两半风险异质（滚动摘要 = 高风险地基：持久化 + 上下文窗口整合 + 失效重建一致性 + 新自动 AI 外发；对话小结 = 中风险、复用 S2a），按风险拆，先做地基 S3b-1。

##### LM03-S3b-1：对话记忆 / 滚动摘要（上下文窗口压缩 + 失效重建一致性）
> **→ 已 Done（2026-06-26，全量 CI 绿 run 28229050120）**：[`done/2026-06-26-feature-lm03-s3b1-companion-rolling-summary.md`](../done/2026-06-26-feature-lm03-s3b1-companion-rolling-summary.md)。双轮自审收口 2 P0（失效 in-transaction / 触发纯函数 `shouldSummarize`）+ 多 P1/P2（隐私「已逐轮外发」措辞订正为「provider 本会话早轮已收到」不改不新增 consent 门 / `systemPrompt` 默认参数救调用 / fingerprint v1 去除 / 新 `CompanionRollingSummary` + `.companionSummarization` capability 先定义）。逐落点 TDD：v33 + 一致性六态（Data）/ shouldSummarize 四态 + summarize 缓冲·失败·scrub + conversationMemory 注入 + 摘要 Prompt directive + 披露（AI）/ band 红线守卫（LearnerModel）。**首轮 CI 捕获跨包破坏**（新 capability 破坏 `AIRequestLogListView` exhaustive switch）→ 补 case + 本地化 key 后重跑绿（教训：新增闭集 capability 须同步全部 exhaustive 消费点 + 本机验证含 UI build）。**摘要只压缩本会话已外发内容、无新外发类目、无新 consent 门；band 红线未碰**；架构备忘录 `docs/architecture/notes/2026-06-26-companion-rolling-summary-ownership-notes.md`（companion-owned vs LearnerContextProvider generalize 迁移点）。
- **范围**：会话超窗时把老化出窗的较早轮次压缩为滚动摘要（`<<<CONVERSATION MEMORY>>>` 引用块）注入 system prompt（§3.2/§5.2/§3.11）；**删该条及后续 / 清空 → 覆盖被删内容的摘要一并失效重建**（§3.2 硬规则，本片最高风险）。v33 `ALTER TABLE companion_threads` 加摘要列（水位模型，非新表）+ `CompanionSummarizationPromptRegistry`（`builtin.companion.summary.v1`）+ `.companionSummarization` capability + 引擎 `summarize` 方法。
- **隐私归类（2026-06-26 用户定）**：**语伴整体 opt-in 内，不新增 consent 门**——只压缩本会话已逐轮外发内容、不注入外部数据；措施 = 摘要 capability 披露 + 复用 S2b-1 PII scrub + 摘要 local-only 不同步。区别于 S2b-1 Memory 注入（外部系统级事实 = 最高门）。
- **硬前置**：LM03-S1（Done）+ S3a（Done）+ Provider 流式（就绪）。**新增 v33 migration + 新自动 AI 外发（摘要）**。
- **风险**：高（失效重建一致性 + 新自动 AI 外发 + 上下文窗口整合）。

##### LM03-S3b-2：对话小结（§3.12，候选批量 deposit 闭合「对话 → 记忆」）
> **→ 已 Done（2026-06-26，全量 CI 绿 run 28243788513）**：[`done/2026-06-26-feature-lm03-s3b2-companion-session-deposit.md`](../done/2026-06-26-feature-lm03-s3b2-companion-session-deposit.md)。双轮自审两 P0（entryID 放宽 / 新 seam 破坏）经主会核验**均为非破坏** + P1/P2 写回（isDeposited 改 store 承载 / source_kind UUID 残余文档化 / 验证含 UI build）。逐落点 TDD：Core companion deposit init + 映射 + analysis 回归 / Data companion deposit entry_id NULL + 幂等 + analysis 回归 / UI 批量标记·幂等·load 预置。**纯本地 deposit、无新 AI / 外发类目 / migration**（复用 E7 幂等、`source_kind 'candidate'`、`entry_id` 写 NULL）；band 红线未碰（difficulty 默认 medium）。CI 教训复用：本机跑 UI 全量捕获 no-hardcoded-Han 守卫（新增注释 Han→英文）。
- **范围（用户 2026-06-26 定）**：**复用 S2a 提取（含 errorPattern 五类候选）+ 批量 deposit 到 E7/E8 复习系统（`memory_items`）**，把对话闭合回「记录 → 对话 → 记忆」。**不新增摘要 AI**；deposit 粒度 = 批量「全部加入」+ 逐条「已加入」态（§3.8 反手动选词）。调查结论：S2a 提取 + E7 deposit + E8 复习均已落地，但 `companion_memory_candidates` 与 `memory_items` **当前完全孤立**——真增量 = 建立这条 deposit 连接 + 小结 UI。
- **硬前置**：LM03-S2a（Done，候选源）+ E7/E8 记忆 deposit·复习（Done）。
- **边界**：**无新 AI / 无新外发类目 / 无新 migration**（deposit 纯本地、复用 E7 幂等 `deposit`、`source_kind 'candidate'`、`entry_id` 可空写 NULL）；band 红线不碰（difficulty 默认 `.medium` 不读难度）。
- **风险**：中低（纯本地 deposit 连接 + UI；自审两 P0〔entryID 放宽 / 新 seam 破坏〕经核验均为非破坏）。

### LM03-S4（v2）：Style 注入 + Anthropic 适配 + 认知风格下投影
> **2026-06-27 用户决策：S4 按风险拆 S4a（Style 注入）/ S4b（Anthropic 适配），与 S2a/S2b、S3a/S3b 同构；先做 S4b（独立于 §9）。§9 Style 时机收口为 A（未来 S4a 注入 v1 surface Style）。**

#### LM03-S4b：Anthropic Messages 多轮 + 流式适配
> **→ 已 Done（2026-06-27，全量 CI 绿 run 28252751284）**：[`done/2026-06-27-feature-lm03-s4b-anthropic-messages-adapter.md`](../done/2026-06-27-feature-lm03-s4b-anthropic-messages-adapter.md)。双轮自审 → 授权 → TDD：鉴权升为可动态派发协议要求 `providerRequestHeaders`（Anthropic `x-api-key`+`anthropic-version` / mimo `api-key`，**连带修复 mimo 死 override 潜伏鉴权 bug**）+ `AnthropicMessagesTextAdapter`（顶层 system / 必填 max_tokens / `content[].text` / `content_block_delta` 流式 / 无 [DONE] EOF 终止）+ Anthropic 响应/流式 parser + 工厂放行 + UI 探针放行。**无新 migration / 无新 AIRequestCapability / 无新外发类目**；语伴 send 路径 kind-agnostic 零 App 改动。结构化严格模式（tool_use）+ 图片在 Anthropic 上后置。自审 P1-1 跨测试破坏实际范围比方案广（6 处 unsupported fixture 改 gemini），**聚焦 AI 包本机当场捕获**（印证 S3b-1 闭集语义变更须本机跑全包教训）。
- **范围**：Anthropic Messages 多轮 + 流式适配（idea-03 §10.3）。
- **硬前置**：Provider Anthropic 适配（本片实现）；独立于 §9 与 LM02-S2 Style。
- **风险**：中（多 Provider 鉴权 + SSE 形态差异；无新外发类目）。

#### LM03-S4a：Style 受控片段注入 + 认知风格 i+1 下投影
> **→ 已 Done（2026-06-27，全量 CI 绿 run 28256888515）**：[`done/2026-06-27-feature-lm03-s4a-companion-style-injection.md`](../done/2026-06-27-feature-lm03-s4a-companion-style-injection.md)。双轮自审 → 授权 → TDD：Core `CompanionStyleDescriptor` + `.curatedLearnerStyle` / LearnerModel `CompanionStyleProjection`（formality 镜像量化 + elaboration + **ceiling=band.estimatedLevel** 只读封顶 + sampleCount 阈值 + band 红线守卫）/ AI `<<<STYLE>>>` 渲染 + `.styleGroundedPersona` directive + engine 透传 / UI exhaustive switch 上修 + 本地化 / App 同 `uses_learner_profile` 门装配 + 预览披露 Memory+Style。**i+1 v1 mapping 定义**（正式度镜像 + 复杂度按 band 封顶；认知风格 v2 后置）。**Style 块零原始用户内容**（枚举派生类别 + CEFR ceiling）→ 无需 PII scrub；复用 S2b-1 两层 consent，**无新 consent 门 / 无新 migration / 无新 capability / 无新外发类目语义升级**；band 红线只读。Prompt 登记 `docs/prompts/companion/style.md`。
- **范围**：Style 受控片段注入（依赖 LM02-S2 Style，经 Ability i+1 下投影，§3.11 / idea-01 §13.5）；§9 时机已收口 = **A（注入 v1 surface Style）**。
- **硬前置**：LM02-S2（Style，Done seam-only）+ ADR-006 §6 隐私闸（复用 S2b-1 两层 consent）+ Ability band（i+1 下投影，Done，只读）。
- **风险**：中（系统自动注入外发；自审 P0 band 红线 + P1 闭集破坏均守卫钉死 / 计划内上修）。

> **至此 LM03 语伴系列（S1→S2a→S2b-1→S2b-2→S3a→S3b-1→S3b-2→S4b→S4a）全部 Done。** 本拆解 / 决策导航文档随之收尾，可移入 `done/`（待下一次系列收口统一归档）。

### 远期（不在本次拆解的 active plan 范围）
- 语音输入 / 语音对话（依赖 Speech Recognition，先写架构备忘录，§3.7）；场景 / 主题对话模式（决策 #5：Prompt 模式非新空间，§9 远期）；向量检索增强话题相关性。

## idea-03 待决点收口（§9 + §10.5/§10.6）

下列多数 §10.6 已给架构师推荐默认，本文件**采纳为各子片进入实现时的默认取舍**（用户最终授权时可逐项推翻）：

| 待决点 | 收口（默认，§10.6 推荐） | 归属子片 |
| --- | --- | --- |
| 开关默认 | **关闭**（已定，§2） | S1 |
| 入口位置 | **练习 Tab 二级 + 记录详情**，不做第四 Tab（ADR-008） | S1 |
| 数据模型命名 | **复用 2026-05-25 备忘录** Companion* | S1 |
| 人设选项集 | 语气（友好/中性/幽默）正式度（随意/正式）纠错（仅按需/温和复述/不纠错），默认**友好/随意/仅按需**；无「陪练强度」 | S1 |
| 自由文本（昵称） | v1 **不开放**，纯枚举（防注入） | S1 |
| 难度自适应 | **三层隐式**（Ability 基线 v1 静态 level→v2 band / 响应层 persona / 对话控制），不宣布难度 | S1（v2 接 S4 band） |
| 词汇提取 | **自动产出 + 入库**对齐既有 memory_candidates；长按手动补充 | S2 |
| 清空对话语义 | 仅清对话消息 + per-space 情景；系统级生活事实保留；UI 透明提示 | S1（schema）/ S2（Memory） |
| Memory 注入隐私 | 全局首次预览 + 全局关闭 / per-conversation toggle / PII scrubbing；不为每类单独 opt-in | S2 |
| Memory v1 注入上限 | salience **top-5**；v2 接 FTS 召回 | S2 |
| 模糊输入拟真 | 确认 / 调侃，克制偏友好（阈值待细化） | S1 |
| 温和复述纠正 | **默认关闭**，opt-in | S3 |
| 对话小结触发 | **手动 + 可选会话结束**，不每轮 | S3 |
| 历史 export/sync | **默认不同步**；导出随统一口径 | S1（schema）/ E10 |
| 失败态 | 「语伴暂时联系不上」+ 重试 + 不丢输入 + 不伪装 | S1 |
| 秒回期待 | 产品定位「练习对象」非「助手」 | S1（文案） |
| 流式 | 依赖 Provider 前置；可后置到 S3 | S3 |
| Style 集成 | v1 不注入；v2 经 provider 注入 + i+1 下投影 | S4（v2） |
| Style v2 时机 | **仍待决**（与 idea-01 §13.4 认知风格后置节奏对齐） | S4（v2，待用户定） |
| Memory salience 评分机制 | **仍待决**（时近 / 频次 / 主题相关性权重） | S2（待用户定） |
| 混合语言 / 夹码 | 长按按主导 / 选中片段；主对话母语片段当求助填空 | S1（待细化） |
| 场景 / 主题模式 | **远期**，Prompt 模式非新空间 | 远期 |
| 关系记忆可见 / 编辑 / 删除粒度 | 归 Learner Model 统一治理（LM02-S1 总览页） | S2 |

**仍须用户定的少数项**（其余采纳上表默认）：① Style v2 接入时机（S4，留待 S4 拆解）；② Memory salience top-5 评分机制（S2，留待 S2 拆解）；③ 模糊输入拟真 / 夹码体验的具体阈值（S1 实现时细化，已收口为 `.ambiguityRealisticConfirm` directive + 模拟器人工验证）；④ ~~语伴入口英文名~~ → **已定（2026-06-25）：Language Companion**（入口 = 练习 Tab 二级 + 记录详情，ADR-008 §3）。

## 推荐排序与门控

```text
前置：ADR-008（已定）+ Provider 多轮/流式（已落地 done/）+ 2026-05-25 命名对齐
   ↓
LM03-S1（MVP 文本对话引擎）   ← 完整引擎起点；不依赖 LM02 后续切片（难度退静态 level）
   ↓
LM03-S2（方案 B 找话题 + Memory 注入 + 反哺记忆）   ← 依赖 plan 12 FTS（已就绪）+ LM02-S1 Memory + 隐私两层
   ↓
LM03-S3（流式 + 对话记忆 + 小结 + 复述）   ← 依赖 Provider 流式
   ↓
LM03-S4（v2：Style 注入 + Anthropic + i+1 下投影）   ← 依赖 LM02-S2 Style + ADR-006 §6 隐私闸
   ↓
远期：语音对话 / 场景模式 / 向量检索
```

门控（每子片实现前）：① 硬前置就绪；② 该子片独立 active plan 已 Reviewed（双轮）；③ 用户实现授权；④ S2 额外门 = 隐私两层控制 + PII scrubbing 可验证；⑤ S4 额外门 = ADR-006 §6 Style 外发闸 + Anthropic 适配。

## 与既有文档的关系 / 维护约定

- 语伴本体改变产品定位，相关定位修订（连同 idea-01 隐私重定义、idea-02 自适应卖点）按 ADR-008 已部分固化；S1 落地时一并收口 `product-main-reference.md` 定位文案（§10.6「合并为一次修订」）。
- 某子片拉为 active plan 时，在 `2026-06-11-00-docs-series-progress.md` 登记，并在本文件对应子片标注「→ 已拆 active plan: <路径>」。
- 语音输入架构备忘录（硬前置 6）在 LM03-S1 active plan 创建时一并写入 `docs/architecture/notes/`。
- 全部子片落地后，本文件随 LM03 收口移入 `done/`。
- 设计细节 / TDD 落点 / 验证写回各子片 active plan 与权威文档，不在本文件。
```
