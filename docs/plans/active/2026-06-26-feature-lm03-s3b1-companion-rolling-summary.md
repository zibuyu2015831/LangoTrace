# 任务方案：LM03-S3b-1 语伴对话记忆 / 滚动摘要（上下文窗口压缩 + 失效重建一致性）

状态：Draft（双轮自审已执行；待用户实现授权）
自审核状态：Reviewed
类型：feature
创建日期：2026-06-26
最后更新日期：2026-06-26

## 用户确认记录

- 2026-06-26：用户确认 **LM03-S3b 按风险拆 S3b-1 / S3b-2，先做 S3b-1**。本片 = **S3b-1**：对话记忆 / 滚动摘要（上下文窗口压缩 + 删除失效重建一致性，高风险地基）。**对话小结（§3.12）= S3b-2**（复用 S2a 提取 + 本片摘要 infra + plan 10/11 deposit，独立后续门控）。
- 2026-06-26：用户确认 **滚动摘要隐私归类 = 语伴整体 opt-in 内，不新增 consent 门**——滚动摘要是既有上下文窗口管理（截断）的演进，**只压缩本会话消息、不注入 Memory/记录等外部数据**；措施 = 新增摘要 capability 披露（请求预览诚实披露「将本会话历史发送以生成对话记忆」）+ 复用 S2b-1 `PIIScrubber` + 摘要 local-only 不同步。区别于 Memory 注入（注入外部系统级事实 = 最高门，S2b-1）。
  - **诚实措辞订正（自审 P1）**：早先表述「只压缩**已逐轮外发**内容」**不精确**——当前 `assembleRequest` 截断到 `suffix(maximumContextMessages)`，老化出窗的较早轮次在最近几轮**已不再外发**；摘要会把它们重新发给摘要服务。准确表述 = 摘要重发的是 provider **在本会话早轮（新鲜在窗内时）已收到**的对话内容，**无新外发类目、无外部数据**，仍在语伴整体 opt-in + 决策 #10 边界内（同一会话、同一 provider、内容 provider 已见过）。该订正不改变「不新增 consent 门」的用户决策，但要求 capability 披露诚实说明此自动外发。
- **实现授权**：尚未授权。本方案完成双轮隔离自审 → `Reviewed` 后提交用户授权，授权前不写生产代码。

## 这份文档是什么

S3b-1 完整实施方案：把语伴当前「机械截断最近 N 轮」的上下文窗口管理（`CompanionConversationEngine.maximumContextMessages` suffix）升级为**滚动摘要 / 对话记忆**——会话超窗时把**已老化出窗**的较早轮次压缩为一段滚动摘要（`<<<MEMORY OF CONVERSATION>>>` 引用块），随 system prompt 注入，使语伴在长对话中「记得你上次说的」（idea-03 §3.2 / §5.2 / §3.11）；并落地 idea-03 §3.2 的硬性一致性规则：**删除某条及其后续 / 清空对话 → 覆盖被删内容的摘要必须一并失效并重建**，否则被删内容残留在摘要里继续影响回复。权威边界以 ADR-008 / spec/005 / idea-03 为准。

## 北极星 / 边界对照（实现前自检）

- **不注入外部数据**：滚动摘要只压缩**本会话消息**（已逐轮外发的对话内容），**绝不**纳入 Memory 生活事实、记录正文、band/AI 难度/`learning_text`、Style、FTS、其他会话、照片、音频、API Key——与 S2b-1 Memory 注入（外部系统级事实）严格不同类。摘要注入块 = 既有 system prompt 的加性受控片段（delimiter 包裹为引用内容、非指令，AI-17）。
- **隐私归类 = 语伴整体 opt-in 内（用户已定）**：摘要触发是系统自动，但被摘要内容 = 本会话已外发内容，无新外发类目、无新 consent 门；摘要请求走请求预览诚实披露 + PII scrub（复用 S2b-1）；摘要持久 local-only / 不同步（沿用 companion 行 `localOnly`）。
- **持久化语义（idea-03 §3.2 / §3.11）**：摘要是**派生可重建**数据（由消息重新摘要可得），随 companion 行 backup/export lane（`includedInSystemBackup`/`includedByDefault`，与历史同 lane）、**不同步**；删对话历史（清空）→ 摘要一并删；**系统级生活事实（S2b-1）不随对话删除而清**（分层语义，§3.11，本片不碰系统级 Memory）。
- **band 红线**：摘要只读 `companion_messages.content`（本会话对话文本），**绝不**碰 band `derive()` / 不读 AI 难度 / `learning_text`；新增源文件须通过 band-guard 源级 grep（无 `derive(`/`bandhysteresis`/`learning_text`/`difficulty` 禁词）。
- **ADR-008 六边界不变**：始终目标语 / 话题扎根记录 / 学习纠错 / 单一对话对象 / 非通用助手 / 默认关闭——摘要只压缩上下文，不改任何边界。

## 范围（本片，待实现）

### 1. v33 滚动摘要持久化（companion_threads 加列，非新表）

一空间一会话（`companion_threads` 1:1 per-space，ADR-008 §4），摘要 1:1 绑 thread → **`ALTER TABLE companion_threads` 加列**（非新表，避免 join；watermark 模型）：

- `rolling_summary TEXT`（nullable，null = 无摘要 / 已失效）。
- `summary_covers_through_sequence INTEGER`（nullable，水位：摘要覆盖到 `sequence ≤ 此值` 的消息；用于删除失效判定）。
- `summary_updated_at REAL`（nullable）。
- ~~`summary_fingerprint`~~ **自审定：v1 不纳入**（失效后下次超窗无条件重摘，简单且正确；fingerprint「内容未变免重算」属 v2 优化，届时 v34 再加）。

迁移 v33 = `ALTER TABLE ADD COLUMN` 三列（SQLite 加列对既有 v30 行安全，默认 null）。**migration head v32 → v33**。摘要列是 thread 行上的**派生 cache 列**：随 thread 行既有 backup/export lane（无法列级排除，且摘要 + 水位 + 同被备份的消息一致、可重建，恢复安全无害）、**不同步**（companion 行 `localOnly`）。读写**封装为 repo 方法**（`loadRollingSummary`/`updateRollingSummary`，不裸露字段），为 §3.11「摘要经 `LearnerContextProvider` 统一取用」的 v2 generalize 预留迁移点（自审 P1）。

### 2. 摘要生成（CompanionSummarizationPromptRegistry + capability + 引擎方法）

- **Prompt**：新 `CompanionSummarizationPromptRegistry`（`builtin.companion.summary.v1`，进 `docs/prompts/companion/summary.md`）——固定模板，把「较早对话轮次 + 现有摘要（增量折叠）」压缩为简洁第三人称对话情景摘要；隐私 directive：禁臆造、禁画像、reference-only、始终围绕本会话；输入消息以 delimiter 包裹为引用内容（AI-17）。
- **capability 披露**：新 `AIRequestCapability.companionSummarization`（**preview-only、不写 `ai_request_logs`**，沿用 S2a/S2b capability 风格）+ 复用/新增 included descriptor `.companionConversation`（被摘要内容 = 本会话对话，无新外发类目；`.longTermMemory`/`.broughtInRecords`/照片/录音保持 always-excluded）。请求预览诚实披露「将本会话历史发送以生成对话记忆」。
- **引擎**：`CompanionConversationEngine` 新增非流式 `summarize(...)` 方法（复用既有 `CompanionReplyTransport`→`AIChatStreamingService`，缓冲全文即摘要）；对**被摘要消息 + 现有摘要**统一 outbound `scrub`（复用既有 scrub seam = `PIIScrubber.scrub`，存原文发脱敏）；honest failure（摘要失败 → 不更新摘要、不阻塞本轮回复，degrade 到既有截断，见 §故障恢复）。

### 3. 上下文窗口集成（assembleRequest 注入摘要块 + 最近 N 轮）

- **触发判定 = 引擎纯函数（自审 P0-3，关键可测性）**：`CompanionConversationEngine.shouldSummarize(messageCount:watermark:threshold:recentVerbatimWindow:) -> Bool` 静态纯函数——`messageCount > threshold` 且（`watermark == nil` 或 `watermark < messageCount - recentVerbatimWindow`，即存在老化出窗的未摘要轮次）→ true。**判定逻辑下沉到可单测纯函数，不埋在 App `companionSend`**（App 只调用）。v1 参数：`threshold ≈ 24`、`recentVerbatimWindow ≈ 12`（保守值，自审采纳；后续可调）。
- **编排（App `companionSend`）**：取 history 后 `shouldSummarize` → true 则**同步**先 `await engine.summarize(...)` 折叠老化轮次（连同现有摘要增量）→ `repository.updateRollingSummary(threadID, text:, coversThroughSequence: 被折叠最大 sequence)` → 再 `engine.reply(...)`。摘要不流式（缓冲全文）；reply 仍走 S3a `onPartial` 流式（两者不冲突，摘要在 reply 前完成）。
- **`assembleRequest`**：有摘要时，system prompt 加 `<<<CONVERSATION MEMORY ... >>>` 引用块（`.conversationMemoryGrounded` directive 结构可测）+ 只发**最近 recentVerbatim 轮**（替代当前 suffix 全截断）；无摘要时与 S1/S3a 完全一致（零摘要、原截断）。摘要文本经 `systemPrompt(conversationMemory: String? = nil)` **默认参数**注入——`systemPrompt` 是函数（非闭包字面量），默认值**救既有调用**（仅 `assembleRequest` 实际传值，测试 helper 不破），区别于 S3a send 闭包破坏面（自审订正：此处非 P0 merge-blocker，是 P1 机械）。
- **故障恢复（自审 P1/P2，honest failure）**：`engine.summarize` 失败（network/provider/timeout/cancel）→ **不更新摘要列**（保持现值或失效态）→ 本轮 reply 照常（用现有摘要或退回截断）→ **不阻塞、不伪装、不重试本轮**；下次 send 再超窗时重试。摘要请求 **preview-only、不写 `ai_request_logs`**。
- **成本**：超窗 send = 摘要 + 回复两次外发（v1 接受；增量折叠避免每轮全量重摘）；软提示 UI（§6.8「对话已较长」）**defer 到 S3b-2 或后续**（本片聚焦 infra + 一致性，见非目标）。

### 4. 删除 / 清空失效重建一致性（idea-03 §3.2 硬规则，本片核心风险）

- **`deleteMessageAndSubsequent(messageID:)`（自审 P0：失效必须 in-transaction）**：在**既有同一 `writer.write` 事务内**——读删除点 `sequence` → DELETE 消息 → 同事务内：若 `summary_covers_through_sequence != nil && 删除点 sequence ≤ 水位` → 覆盖了被删内容 → **同事务清空 `rolling_summary` + 水位 + updated_at`**（失效）；删除点 > 水位（只删未摘要近端轮次）或水位为 null → 摘要保留/无操作。失效逻辑**折入 repo 既有方法内**（非 App 层外部驱动），SQLite 事务保证「删消息 + 失效」原子、无中途态。
- **`clearThread(threadID:)`**：同事务清空所有消息 → **一并清空摘要 + 水位**（§3.2 整段删除含摘要）。
- **「编辑刚发消息」（§3.2）**：等价「从该条删除并重发」，复用 `deleteMessageAndSubsequent` 失效路径，无独立处理（本片 UI 不提供编辑；语义覆盖即可）。
- **重建惰性**：删除/清空失效后摘要为 null；**下次 send 再超窗**（`shouldSummarize` true）时重摘（TDD 覆盖：失效 → 新增轮次 → send 触发重摘）。
- **不变量**：摘要水位永远 ≤ 当前最大 message sequence；任何使「水位指向已不存在 / 已变更消息」的结构性变更都必须失效。TDD 锁死（删 ≤ 水位失效 / 删 > 水位保留 / 水位 null 删除 no-op / 清空失效 / 失效后超窗重摘 / 失效与删同事务）。

### 5. UI（最小，本片不做大改）

- 滚动摘要对用户基本不可见（上下文压缩）；本片**不新增独立 UI 面板**。可选最小：长对话「对话记忆生效中」低干扰指示（自审待议是否纳入 v1，倾向 defer）。
- 三端共享 `CompanionChatView` 既有删除 / 清空入口自动经 repo 触发失效（无 UI 改动需求）。

## 关键架构落点与触碰

| 层 | 落点 | 动作 |
|---|---|---|
| Core | `CompanionRollingSummary`（新值类型：`text`/`coversThroughSequence`/`updatedAt`，自审 P1-3）；`AIRequestCapability` + `AIRequestProjections` | 新 `CompanionRollingSummary` struct（repo 返回类型）；新 `.companionSummarization` capability + `AIRequestProjections.companionSummarization(...)`（includedContent=`.companionConversation`，`.longTermMemory`/`.broughtInRecords`/照片/录音 always-excluded；preview-only）。 |
| Data | 新 `AppDatabaseCompanionRollingSummaryMigration.swift` + `AppDatabase.migrate()` 注册 v33 | v33 `ALTER TABLE companion_threads` 加 3 列；`GRDBCompanionRepository` 新增 `loadRollingSummary(threadID:)->CompanionRollingSummary?`/`updateRollingSummary(threadID:text:coversThroughSequence:)`，并在 `deleteMessageAndSubsequent`/`clearThread` **同事务内**接失效。 |
| AI | `CompanionSummarizationPromptRegistry.swift`（新，`builtin.companion.summary.v1`）、`CompanionConversationEngine.summarize(...)`（新非流式方法）、`CompanionConversationEngine.shouldSummarize(...)`（新静态纯函数）、`CompanionPromptRegistry.systemPrompt(conversationMemory: String? = nil)`（**默认参数**加性摘要块 + `.conversationMemoryGrounded` directive） | 摘要 Prompt + 引擎摘要方法 + 触发纯函数 + assembleRequest 注入摘要块；scrub 覆盖被摘要消息 + 现有摘要。 |
| AI | `CompanionConversationEngine.assembleRequest` | 有摘要 → 注入摘要块 + 最近 N 轮；无摘要走原截断路径（与 S1/S3a 一致）。 |
| App | `AppEnvironment+Companion.swift` `companionSend` | send 前 `shouldSummarize` 判定 → 调 `summarize` + `updateRollingSummary`（honest failure 不阻塞回复，不更新摘要）；摘要 capability 预览投影。 |
| 文档 | spec/005 §5、architecture/002（新 §4.16）、prompts/companion/summary.md、page-inventory、拆解 doc + 仪表盘、idea-03 §3.2/§3.11 收口、architecture/notes（generalize 边界） | §17 回写。 |

## 非目标（本片不做）

- **对话小结（§3.12）**：= S3b-2（手动/会话结束、复用 S2a 提取 + 典型错误 + 批量 deposit + 本片摘要 infra）。
- **成本软提示 UI（§6.8）/ 用量透出**：defer（本片聚焦摘要 infra + 一致性）。
- **摘要经 `LearnerContextProvider` 统一取用（§3.11 架构方向）**：v1 摘要 companion-owned（per-space 对话情景 ≠ 系统级，路由跨切面 provider 过度）；本片写 architecture note 记录该方向，generalize 后续（自审重点核验此边界）。
- **Style 注入 / Anthropic 多 Provider 摘要适配**：= S4。
- **向量 / 语义召回增强摘要**：远期。
- **系统级 Memory 生活事实变化**：本片不碰 S2b-1 系统级 Memory（分层语义）。

## TDD 落点（先失败 → 最小实现 → 聚焦验证）

1. **Data 迁移**：`CompanionRollingSummaryMigrationTests` — in-memory DB 迁到 head 后 `companion_threads` 含 `rolling_summary`/`summary_covers_through_sequence`/`summary_updated_at` 且默认 null、可读写；migration head = v33（参照 `CompanionMemoryToggleMigrationTests` 范式）。
2. **Data 一致性（本片最高风险，自审 P0）**：`GRDBCompanionRepository` — ① 水位=5 → 删 sequence=3（≤ 水位）→ 摘要清空 + 水位 null；② 水位=5 → 删 sequence=8（> 水位）→ 摘要保留；③ **水位=null → 删除 → no-op（不报错）**；④ `clearThread` → 摘要清空；⑤ `updateRollingSummary`/`loadRollingSummary` 往返（`CompanionRollingSummary` 值相等）；⑥ **失效与删消息同事务**（删后立即 `loadRollingSummary` 读到失效态，无中途态）。
3. **AI 触发纯函数（自审 P0-3）**：`CompanionConversationEngineTests` — `shouldSummarize(messageCount:30, watermark:5, threshold:24, recentVerbatimWindow:12)` == true；`(30, 25, ...)` == false（水位覆盖近端无出窗）；`(20, nil, ...)` == false（未超窗）；`(30, nil, ...)` == true（超窗无摘要）。
4. **AI 摘要引擎**：`CompanionConversationEngineTests` — summarize stub 缓冲全文 → 返回摘要文本；**摘要失败（stub 抛错）→ honest failure（不抛、返回失败枚举，调用方据此不更新摘要）**；被摘要消息 + 现有摘要经 scrub 脱敏外发（手机号/身份证占位出现、原文消失，复用 S2b-1 断言范式）。
5. **AI 上下文集成**：有摘要 → assembleRequest system 含 `<<<CONVERSATION MEMORY>>>` + `.conversationMemoryGrounded` directive + 只发最近 N 轮；无摘要 → 与 S1 一致（无摘要块、原截断，`systemPrompt` 默认参数不破既有断言）；摘要块**绝不**含 Memory/记录/band 词。
6. **AI 摘要 Prompt**：`CompanionSummarizationPromptRegistryTests` — `builtin.companion.summary.v1` + 隐私 directive（禁臆造/reference-only/围绕本会话）+ 输入 delimiter 包裹。
7. **AI 披露（自审 P1-1）**：`CompanionConversationProjectionTests` — `.companionSummarization` capability includedContent = `.companionConversation`，`.longTermMemory`/`.broughtInRecords`/照片/录音 always-excluded。
8. **LearnerModel 红线**：`CompanionRollingSummaryBandGuardTests` — 摘要源文件源级 grep 无 band 机器禁词（`derive(`/`bandhysteresis`/`learning_text`/`difficulty`）+ 插入对话 + 生成摘要后 band 不变。
9. **App（经 CI macOS app test）**：超窗 send 触发摘要更新 + 摘要失败不阻塞回复 + 删除/清空后重建惰性（失效 → 新增轮 → send 重摘）。

聚焦验证（本机轻量逐包）：`swift test --package-path Packages/{LangoTraceCore,LangoTraceData,LangoTraceAI,LangoTraceLearnerModel,LangoTraceUI}` + swiftformat/swiftlint。完整验证（三端构建 + macOS app test + **v33 migration**）走 GitHub Actions CI。

## 文档影响（§17，实现收口回写）

- **spec/005 §5**：登记语伴滚动摘要 capability（`.companionSummarization` preview-only）+ 上下文窗口管理演进 + 隐私归类（语伴整体 opt-in 内、无新外发类目、PII scrub、local-only）。
- **architecture/002 §4.16（新）**：滚动摘要数据流（超窗 → summarize 折叠 → v33 摘要列 → assembleRequest 注入 + 最近 N 轮）+ 删除/清空失效重建一致性 + 与 S2b-1 系统级 Memory 的分层区别。
- **prompts/companion/summary.md（新）**：摘要 Prompt 英/中、输入变量、输出契约、隐私边界。
- **prompts/companion/system.md**：补 `conversationMemoryGrounded` 摘要块说明。
- **platform-page-inventory**：语伴行补对话记忆（滚动摘要不可见 + 删除/清空失效重建）。
- **idea-03 §3.2/§3.11 收口**：滚动摘要 + 失效重建 + 分层删除语义落地。
- **拆解 doc + 仪表盘**：S3b-1 Done 登记；S3b-2 边界。
- **architecture/notes**：摘要 companion-owned vs `LearnerContextProvider` 统一取用的边界备忘（§3.11 方向 defer 理由）。
- **专项审查触发判断**：本片**含 v33 migration + 新 AI 外发能力（摘要）→ 触发数据 / AI 专项审查或在方案说明**（按 review 机制）；隐私门虽无新 consent，但新自动 AI 外发须 review 确认披露 + scrub + 分层语义。

## 剩余风险 / 待用户定（实现时 / 自审重点）

- **摘要 companion-owned vs `LearnerContextProvider`（§3.11 架构方向）**：v1 companion-owned；是否需即时 generalize 经 provider 取用 = 自审 + architecture note 核验（倾向 defer，per-space 对话情景非系统级）。
- **失效粒度**：v1 = 删点 ≤ 水位即整段失效重建（不做摘要部分回滚）；可接受（重建惰性 + 正确性优先）。
- **触发阈值 / 窗口具体数值**（threshold / recentVerbatim）：v1 取保守值（自审定，倾向 threshold≈24 / recent≈12），后续可调。
- **成本**：超窗 send 双外发（摘要 + 回复）；增量折叠缓解；软提示 UI defer。
- **摘要 fingerprint 是否 v1 纳入**：自审定（不纳入则每次失效后下次超窗无条件重摘，简单且正确；纳入可省重算但增复杂度）。

## 严格方案自审核记录

```
审核日期：2026-06-26
审核方式：隔离子代理 ×2（架构/边界/一致性/隐私 + 测试·落地/破坏面/可测性），并行 distinct-lens → 主会话核验汇总
审核轮次：第一轮（架构）+ 第二轮（测试·落地）
```

两轮**高度收敛**（两轮各自独立命中：①失效重建须 in-transaction、②隐私「已逐轮外发」措辞不精确、③`systemPrompt` 加参数破坏既有调用、④触发判定可测性）。合计经主会验确认 = **2 P0（确认）+ 1 P0→P1 降级 + 多 P1/P2**，全部写回正文：

- **P0（失效重建必须 in-transaction）已采纳**：两轮命中。`deleteMessageAndSubsequent`/`clearThread` 的水位比较 + 摘要清空必须**折入 repo 既有同一 `writer.write` 事务**（非 App 外部驱动），SQLite 事务保证删消息 + 失效原子无中途态。已写回 §4 + TDD 2⑥。
- **P0（触发判定须可单测纯函数）已采纳**：测试轮命中——阈值/窗口判定若埋在 App `companionSend` 则只能经 CI macOS app test 间接验证。改为引擎静态纯函数 `shouldSummarize(...)`，App 仅调用。已写回 §3 + TDD 3。
- **P0→P1 降级（systemPrompt 加参数破坏调用，主会核验订正严重度）**：测试轮报「P0 无法合并主干」。**主会核验**：`systemPrompt` 是**函数**（非 S3a 那种存储闭包字面量），加 `conversationMemory: String? = nil` **默认参数即救既有调用**（仅 `assembleRequest` 实际传值，测试 helper 不破）——故为 **P1 机械**非 P0 merge-blocker。已写回 §3 + 落点表。
- **P1（隐私「已逐轮外发」措辞不精确）已采纳〔重要〕**：架构轮命中——当前 `assembleRequest` 截断 `suffix(maximumContextMessages)`，老化出窗轮次在近几轮已不再外发；摘要会重发。**主会核验属实**（已读 engine 行 90 确认）。订正措辞 = 摘要重发的是 provider **在本会话早轮已收到**的内容、无新类目/无外部数据，仍在语伴整体 opt-in + 决策 #10 内；**不改用户「不新增 consent 门」决策**，但 capability 披露须诚实说明此自动外发。已写回 §用户确认 + §边界对照。
- **P1（fingerprint v1 不纳入）已采纳**：两轮一致。失效后下次超窗无条件重摘，简单且正确；v33 仅 3 列。已写回 §1。
- **P1（新类型/capability 须先定义否则 TDD 无法先失败）已采纳**：定义 `CompanionRollingSummary`（Core）+ `.companionSummarization` capability + `AIRequestProjections.companionSummarization` + repo 三方法签名，作为各 TDD 先失败的前置。已写回落点表 + TDD。
- **P1（schema 派生 cache 列持久语义）已采纳为说明**：架构轮虑摘要=派生数据是否该进 backup/export lane。**主会核验**：摘要是 thread 行上的 cache 列，无法列级排除 backup；但摘要 + 水位 + 同被备份的消息一致、可重建，**恢复安全无害**；export 冗余属 export-projection 关注非 schema。已写回 §1（不阻塞）。
- **P1（摘要 companion-owned vs `LearnerContextProvider` 架构债）已采纳为 defer + 迁移点**：v1 per-space 对话情景非系统级、路由跨切面 provider 过度；读写**封装为 repo 方法**（不裸字段）预留 v2 generalize 迁移点 + architecture note。已写回 §1 + §非目标 + 文档影响。
- **P2 已采纳**：摘要失败 honest failure 精确化（不更新/不重试/不阻塞/preview-only 不写日志）+ TDD（§3 故障恢复 + TDD 4/9）；重建惰性 TDD（失效→新增→重摘，TDD 9）；水位 null 删除 no-op（TDD 2③）；band-guard 源级 grep 守卫（TDD 8）。「对话记忆生效中」UI 指示 = 经 `.conversationMemoryGrounded` directive 可后续低成本接，v1 defer。

**仍需用户确认的问题**：无新增范围性问题——隐私归类（不新增 consent 门）已由用户 2026-06-26 决策，自审仅订正措辞诚实度（不改决策）；其余均实现细节，已按高风险收口。**唯一提示用户的实现期取舍**：摘要 v1 同步前置于 reply（超窗 send 双外发、增量折叠缓解）；是否需 per-conversation「本次不用对话记忆」快捷开关 = 列为剩余风险 defer（既有「关语伴」已是整体 opt-out）。

**是否允许进入实现**：2 P0（in-transaction 失效 / 触发纯函数）+ 全部 P1/P2 已写回正文（默认参数救调用 / 隐私措辞订正 / 新类型 capability 先定义 / fingerprint 去除 / schema 语义 / generalize 迁移点 / honest failure / 重建惰性 TDD）。**自审门禁完成 → `Reviewed`**。待用户实现授权（`Reviewed` ≠ 已批准实现；本片高风险 = v33 migration + 新自动 AI 外发，授权前不写生产代码）。
