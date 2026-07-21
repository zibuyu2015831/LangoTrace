# Language Companion Summarization Prompt — Rolling Conversation Memory (LM03-S3b-1)

状态：Active

## 1. 基本信息

- Prompt id：`builtin.companion.summary.v1`（version `1`）。
- 所属功能：语伴对话记忆 / 滚动摘要（LM03-S3b-1）——会话超窗时把老化出窗的较早轮次压缩为滚动摘要，注入语伴 system prompt，使长对话保持「记得你上次说的」。
- 调用模块：`CompanionSummarizationPromptRegistry`、`CompanionConversationEngine.summarize(...)`、`CompanionConversationEngine.shouldSummarize(...)`；注入经 `CompanionPromptRegistry.systemPrompt(conversationMemory:)`（`<<<CONVERSATION MEMORY>>>` 块 + `.conversationMemoryGrounded` directive）。
- 代码位置：`Packages/LangoTraceAI/Sources/LangoTraceAI/CompanionSummarizationPromptRegistry.swift`、`CompanionConversationEngine.swift`；`Packages/LangoTraceCore/.../CompanionRollingSummary.swift`；`Packages/LangoTraceData/.../GRDBCompanionRepository.swift`（v33 摘要列 + 失效）。
- 自动化测试：`CompanionSummarizationTests`（prompt directive + 披露）、`CompanionConversationEngineTests`（shouldSummarize / summarize 缓冲·失败·scrub / conversationMemory 注入）、`CompanionRollingSummaryRepositoryTests`（v33 + 失效一致性）、`CompanionRollingSummaryBandGuardTests`（红线）。

## 2. 触发与隐私边界（语伴整体 opt-in 内，无新 consent 门）

摘要是**系统自动触发**（send 前 `shouldSummarize` 判定：会话超 `threshold≈24` 轮且存在老化出 `recentVerbatimWindow≈12` 窗、未折叠的轮次），但：

- **只压缩本会话自身消息**（`companion_messages.content`），**绝不**纳入 Memory 生活事实、记录正文、band/AI 难度/`learning_text`、Style、FTS、其他会话、照片、音频、API Key——**无新外发类目、无外部数据**。
- 被摘要内容 = provider **在本会话早轮（新鲜在窗内时）已收到**的对话内容，摘要重发的是其已见过的内容（同会话、同 provider）；故归**语伴整体 opt-in 内、不新增 consent 门**（决策 #10 边界成立），区别于 Memory 注入（注入外部系统级事实 = 最高门，S2b-1）。
- **诚实披露**：新 capability `.companionSummarization`（preview-only、不写 `ai_request_logs`），`AIRequestProjections.companionSummarization` includedContent = `[.companionConversation]`，长期记忆/记录/照片/音频/历史/其他空间全 excluded。
- **PII scrubbing**：被摘要轮次 + 现有摘要在外发前经 `CompanionConversationEngine.scrub`（= `PIIScrubber.scrub`，手机号/身份证）统一脱敏；存原文发脱敏、不入日志/DB。
- **持久化**：摘要 = thread 行上的派生 cache（`companion_threads.rolling_summary` + 水位 `summary_covers_through_sequence`），local-only 不同步；删该条及后续 / 清空 → 覆盖被删内容的摘要**同事务失效重建**（idea-03 §3.2）。

## 3. 行为契约（typed directives）

`CompanionSummarizationRenderedPrompt.directives` 结构化集合（结构可测、非脆弱字符串匹配）：

- `groundedInConversationNoFabrication`：只摘要对话中实际出现的内容，禁臆造、禁加事实。
- `thirdPersonRecap`：产出简洁第三人称对话情景回顾（聊过的话题、用户提到的事、聊到哪）。
- `noProfilingNoExternalData`：禁画像、禁纳入任何外部数据，仅本会话自身轮次在范围内。
- `foldPriorSummary`：有现有摘要时折叠进单一更新摘要、不另起重复。

注入块在 system prompt 中以 `<<<CONVERSATION MEMORY … CONVERSATION MEMORY>>>` 分隔包裹为**引用内容、非指令**（AI-17），声明 `.conversationMemoryGrounded` directive。

## 4. 失效重建一致性（idea-03 §3.2，本片最高风险）

- 水位 `summary_covers_through_sequence` = 摘要覆盖到 `sequence ≤ 此值` 的消息。
- `deleteMessageAndSubsequent`：删除点 `sequence ≤ 水位` → 同 write 事务清空摘要 + 水位（失效）；删除点 > 水位 → 保留。
- `clearThread`：同事务清空摘要 + 水位。
- 重建惰性：失效后下次 send 再超窗时 `shouldSummarize` true → 重摘。
- 摘要失败 = honest failure：不更新摘要列、不阻塞本轮回复、不重试本轮（best-effort 上下文压缩）。

## 5. 范围外（后续）

- 对话小结（§3.12）= S3b-2（复用 S2a 提取 + 本片摘要 infra + plan 10/11 deposit）。
- 成本软提示 UI（§6.8）/ 用量透出：defer。
- 摘要经 `LearnerContextProvider` 统一取用（§3.11 v2 generalize）；fingerprint 增量免重算（v2）。
- per-conversation「本次不用对话记忆」快捷开关：defer（既有「关语伴」已是整体 opt-out）。
