# 任务方案：AI Provider 多轮对话 + 文本流式扩容（独立基础设施，LM03 消费）

状态：Draft
自审核状态：Reviewed（2026-06-25 隔离子代理双轮审查，3 项 P1 已修订写回，见第 13 节）
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

本方案是语伴（LM03）落地的两份前置之一（另一份为 [ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md)）。2026-06-25 会话中，用户就语伴三处前置定夺拍板，与本方案相关的一处为：

- **Provider 扩容范围 = 多轮 + 文本流式（OpenAI 兼容族），Anthropic 后置**。即本方案做多轮 messages 形态 + 文本流式 `AsyncThrowingStream`，给足真人感；Anthropic Messages 适配作为后续独立 `add-ai-provider` workflow run，不阻塞语伴 v1。

**定位修正（2026-06-25 用户决策）**：本方案**改标为独立基础设施**，不再框为「仅语伴前置」。理由：① 多轮 + 流式能力可被**任何**多轮 / 流式 AI 能力复用（§1 已述），非语伴专属；② 其 **Phase 0 spike 风险**（全仓首个 `AsyncThrowingStream`、`bytes(for:)` OS 差异、mimo SSE 未验，§2/§12）不应压在语伴关键路径上。故**允许在第 1/2 批先行落地退险**（早于 LM03 批次），LM03 仅**消费**已退险的传输 seam。实施顺序与门控见进度仪表盘（enabler 从「第 3 批语伴前置」上移为可独立先行的 infra）。本方案范围 / 边界 / 自审核结论不变，仅排序定位调整。

状态仍为 `Draft`：**范围已锁定，但进入生产代码实现前仍需 (1) 按 `docs/plans/plan-review-protocol.md` 完成严格自审核并将状态推进到 `Reviewed`，(2) 用户对实现授权确认。** 本方案只扩 Provider 能力 seam，不建语伴 UI / 会话 store（属 LM03）。

## 1. 需求或 bug 描述

语伴需要「像真人一样多轮聊天 + 逐字流式输出」的 AI 请求能力。当前 AI Provider 文本请求 seam 是**单发、无状态、非流式**的 `system + user` 形态，无法承载会话历史，也无法逐 token 呈现。本方案为语伴（及未来任何多轮 / 流式 AI 能力）补齐这层 Provider 能力，作为 LM03 的显式前置基础设施。

## 2. 现状描述

以下对照当前代码（2026-06-25 HEAD）核实：

- `AIProviderTextRequestAdapter`（`Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderTextRequestAdapter.swift`）是**单发、无状态**协议：body 构造方法只有 `structuredCompletionBody(system:user:)` / `plainPromptBody` / `imagePromptBody` / `structuredImagePromptBody`，**最多携带一条 system + 一条 user**，无有序 messages 历史数组。
- `AIProviderTextRequestAdapterFactory` 当前实现 3 个 kind：`openAICompatibleChat`、`openAIResponses`、`mimoCompatibleChat`；`anthropicMessages` / `geminiGenerateContent` 是**保留扩展点**，命中即 `throw .unsupportedProvider`。
- 文本响应是「请求 → 完整 body → 解析 JSON」一次性返回。`AIProviderHTTPClient`（`URLSessionAIProviderHTTPClient`）虽用 `session.bytes(for:)`，但仅用于**响应体积上限拦截**（超 `maximumResponseBytes` 即中断抛 `responseTooLarge`），**不是逐 token 流式**，不向调用方暴露增量。
- 全仓**无对话级文本流式**，且**全仓 `AsyncThrowingStream` 0 命中**（已核实）：唯一既有异步流原语是**非 throwing 的 `AsyncStream`**，位于 `Packages/LangoTraceCore/.../SentenceAudioPlaybackCoordinator.swift`（播放状态观察者）与其 UI 消费方 `SentenceAudioPlaybackActions.swift`；`SentenceTTSGenerationService` 是 `async throws -> Result` 一次性返回，**非流式**。本方案将**首次引入 `AsyncThrowingStream`**（throwing 变体以承载失败 / 超时 / 配额），这是新模式而非既有用法扩展，spike gate 风险据此加权。E0a「AI-11 流式」是上述体积拦截，非聊天流式（易误读，已核实）。
- 既有单发服务（`LearningMaterialGenerationService` / `ReadingSelectionExplanationService` / `PhotoWritingAssistService` / 各 probe）依赖现有单发 seam，**本方案不得破坏其契约**。
- E6（plan 09）已落地请求预览 / 日志：`AIRequestProjections`（`previewProjection()` / `makeLogEntry()`）、`ai_request_logs`（v24）；多轮请求必须能被投影 / 记日志，否则语伴会绕过隐私边界。
- `AIProviderAdapterKind` 定义在 `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`（5 case）。

## 3. 目标

1. 新增**多轮对话请求形态**：一个携带有序 `[ConversationMessage]`（role + content）+ system 受控片段的请求模型，覆盖 `openAICompatibleChat` / `mimoCompatibleChat` / `openAIResponses` 三个 kind；`anthropicMessages` / `geminiGenerateContent` 显式 `unsupportedProvider`。
2. 新增**文本流式 seam**：以 `AsyncThrowingStream`（增量文本 delta + 终止）暴露逐 token 输出，经 Provider 层；能表达失败 / 取消 / 超时 / 配额（对齐 spec 005 强制规则「Provider 请求必须能表达失败、取消、超时和配额限制」）。
3. **复用并扩展体积上限拦截**：流式累积仍受 `maximumResponseBytes` 约束，超限中断；与逐 token 暴露不冲突。
4. **投影就绪（projection-readiness），不在本方案写日志**：多轮请求携带 E6 投影所需的结构化元数据（capability / content descriptor / length bucket），使 LM03 能用既有 `AIRequestProjections` 同源构造 `previewProjection()` 与无正文 `makeLogEntry(outcome:)`，而**无需回填改造传输层**。本方案**不写 `ai_request_logs`**——既有 E6 架构中 log 的 outcome（success / cancelled / failed）由 App-Shell `AIRequestLogRecorder` 在请求*终止后*写入（`AIRequestProjections.swift:13-15`、`AIRequestLogRecorder.swift:9` 明确「AI service 保持纯执行器、recorder 由 AppEnvironment 驱动」）；流式 outcome 只有流终止时才知，而本方案不接 App-Shell / store（属 LM03）。故「日志写入接线」是 LM03 落点，本方案只保证传输层投影就绪。
5. 全程不破坏既有单发服务契约；不建语伴 UI / 会话 store / Memory·Style 注入（属 LM02 / LM03）。

## 4. 范围

- `Packages/LangoTraceCore`：新增 `ConversationMessage`（`role: ConversationRole`（system / user / assistant）+ `content: String`）与多轮请求值类型（纯值类型，供 AI 包构造、未来 LM03 UI / store 复用）。
- `Packages/LangoTraceAI`：
  - `AIProviderTextRequestAdapter`（或新增 `AIProviderChatStreamingAdapter` 协议）新增多轮 `chatCompletionBody(messages:stream:)` 构造（chat/completions：`messages` 数组 + `stream: true`；responses：`input` 数组 + 流式）。
  - 新增 SSE / chunked 行解析器（`data:` 行 → delta，`[DONE]` 终止，跨 chunk 半行缓冲），与体积拦截累积分离但共用 `bytes(for:)` 增量读。
  - 新增 `AIChatStreamingService`（经 Provider 层暴露 `AsyncThrowingStream<...>`，映射失败 / 取消 / 超时 / 配额到既有错误分类）。
  - `AIRequestProjections` 扩展：多轮请求的 preview / log 投影。
- `project.yml` / 工程：无新增 package（在既有 AI / Core 包内）。
- 文档：`spec/005` §5→§2/§3（多轮 + 流式从「可演进」升为「当前结论 / 强制规则」覆盖范围）、新增 / 更新 architecture note（流式 Provider seam）、`architecture/002-system-map.md`（AI 数据流补流式路径）、ADR-008 交叉引用回写。

## 5. 不做什么

- **不做 Anthropic / Gemini 适配**：`anthropicMessages` / `geminiGenerateContent` 仍 `unsupportedProvider`；Anthropic Messages（x-api-key + Messages body + SSE 事件解析）作为后续独立 `add-ai-provider` workflow run（用户 2026-06-25 定：后置）。
- **不建语伴会话 store / `CompanionMessage` 等 schema / migration**（属 LM03）。
- **不建语伴 UI / 聊天界面 / 输入栏 / 长按操作**（属 LM03）。
- **不做 Memory / Style 注入、`LearnerContextProvider` 接线、难度自适应 prompt 片段**（属 LM02 / LM03）。
- **不在 AI 包写 `ai_request_logs`**：沿用 E6 的 App-Shell `AIRequestLogRecorder` 依赖方向（AI service 纯执行器、recorder 由 AppEnvironment 在请求终止后驱动）；流式 outcome 的日志写入接线属 LM03。
- **不引入语伴 `AIRequestCapability` case / `AIRequestContentDescriptor` / `AIRequestLogFailureBucket` 域**（`AIRequestPreviewProjection.swift` 注释明示该枚举是 closed set，新增 case 是 deliberate change）：这些与语伴的内容类别（如 `currentConversationTurn` / `recentDialogueWindow`）和日志接线强耦合，连同 preview / log 一起留 LM03。本方案只保证多轮请求**携带**可投影的结构化元数据，不动 Core 这三个封闭枚举，避免在传输层扩面到 Core 契约 + 现有 projection 回归。
- **不改既有单发服务**（learning-material / reading-selection / photo-writing / probe）的请求契约——新增并行 seam，不重写单发路径。
- **不改 `ExplanationLanguageMode.derive()` / `LanguageLevel`**。
- **不做 Prompt Registry 的语伴 persona 条目**（属 LM03；本方案只提供能携带任意 system + messages 的传输能力）。

## 6. 证据与决策依据

- ADR 证据：[ADR-005](../../decisions/005-local-first-and-user-owned-providers.md)（Provider 抽象、本地优先——本方案是其内的能力扩展，不改隐私 / 商业边界，故**无需新 ADR**）；[ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md) §6（语伴请求必须经 Provider + 预览 / 日志）、影响节（Provider 扩容列为前置）。
- spec 证据：`spec/005` §3 强制规则「UI 不直接调用具体 AI 服务」「所有 AI 请求必须经过 Provider 层」「Provider 请求必须能表达失败、取消、超时和配额限制」「结构化输出必须经过解析和校验」；§5 可演进部分（多轮 / 流式属可演进，本方案据此升格并登记）。
- 备忘录证据：`2026-05-25-language-companion-extension-notes.md` §「AI Provider 和请求生命周期」（语伴请求必须经 Provider，表达取消 / 超时 / 不支持 / 配额 / 网络失败；翻译 / 语法分析第一阶段分离请求）。
- 代码证据：见第 2 节逐条核实。
- workflow 引用：本方案是对**既有 kind** 的能力扩展（多轮 + 流式），**不新增 provider kind**，故不完整命中 [`add-ai-provider`](../../workflows/add-ai-provider.md) 的建 kind 流程；但其「经 Provider 层、表达失败 / 取消 / 超时、请求预览 / 日志」检查项适用并已纳入目标 2 / 4。Anthropic 新增 kind 时届时整体走该 workflow。

```text
证据能证明什么：现有 seam 是单发非流式（adapter 仅 system+user，HTTP 客户端只做体积拦截）；OpenAI 兼容 chat/completions 与 responses 原生支持 messages 数组与 SSE 流式；ADR-008 与备忘录都要求语伴请求经 Provider 并能表达失败/取消/超时。
证据不能证明什么：不能证明必须现在做 Anthropic（OpenAI 兼容族已足够跑通语伴 v1，用户已定后置）；不能证明流式必须改写既有单发服务（新增并行 seam 即可）。
迁移前提：无 schema 变更、无 migration；扩展点在 AI / Core 包内。
照搬风险：把流式塞进既有单发 adapter 会污染 learning-material / probe 的稳定单发契约——故新增并行 seam，不改单发方法签名。
```

```text
是否需要 spike / probe / fixture / evidence：是——SSE 增量解析 + URLSession bytes(for:) 流式行为需 macOS / CI 验证（Linux 无 swift 工具链，且 bytes(for:) 实现随 OS 版本有差异，同 E0a AI-11）。
需要时的落点：Packages/LangoTraceAI/Tests（SSE 解析器纯函数测试可本机/CI 跑；真实 URLSession 流式行为标注须 macOS/CI）。
是否包含真实用户敏感内容：否——本方案只做传输能力与解析，fixture 为合成 SSE 流，无真实日记 / 照片。
如何验证和清理：合成 fixture，无需清理；不落任何用户数据。
```

## 7. 约束映射与验证路径

### 约束 1：所有 AI 请求必须经 Provider 层，UI 不直接调用模型

- 来源：`docs/spec/005-ai-provider-prompt-and-privacy.md` §3
- 适用范围：AI 模块
- 严重度：blocker
- 执行或验证方式：代码审查 + 依赖方向检查
- 验证提示：流式能力以 `AIChatStreamingService` 暴露在 AI 包，不在 UI / App 直接发请求；LM03 UI 经服务取流。

### 约束 2：Provider 请求必须能表达失败、取消、超时、配额

- 来源：`docs/spec/005-ai-provider-prompt-and-privacy.md` §3、`2026-05-25-language-companion-extension-notes.md` §「AI Provider 和请求生命周期」
- 适用范围：流式 seam
- 严重度：blocker
- 执行或验证方式：单元测试
- 验证提示：流式 `AsyncThrowingStream` 在网络失败 / 取消 / 超时 / HTTP 4xx 配额时抛对应既有错误分类（复用 `AIProviderHTTPStatusErrorMapper`）；取消 token 中途取消时流终止且不泄漏。

### 约束 3：多轮请求投影就绪，不泄漏正文（preview / log 写入由 LM03 接线）

- 来源：`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.3 / §4.4、[ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md) §6、E6 落地
- 适用范围：多轮请求的投影元数据
- 严重度：blocker
- 执行或验证方式：单元测试
- 验证提示：多轮请求携带 capability / content descriptor / length bucket 等结构化元数据，使 LM03 能用 `AIRequestProjections` 同源产出 preview + 无正文 log；本方案断言这些元数据**不含 messages 正文 / API Key**。**实际 preview UI 与 log 写入是 LM03 的义务**（ADR-008 §6 强制语伴请求经预览 / 日志）；本方案只保证传输层投影就绪、不自带写入。

### 约束 4：体积上限在流式下仍生效

- 来源：现有 `URLSessionAIProviderHTTPClient`（E0a AI-11）
- 适用范围：流式累积
- 严重度：warn
- 执行或验证方式：单元测试（macOS / CI）
- 验证提示：流式累积超 `maximumResponseBytes` 仍中断抛 `responseTooLarge`，与逐 token 暴露并存。

### 约束 5：不破坏既有单发服务契约

- 来源：第 2 / 5 节
- 适用范围：既有单发 adapter / 服务
- 严重度：blocker
- 执行或验证方式：回归测试
- 验证提示：`swift test --package-path Packages/LangoTraceAI` 既有用例全绿；单发方法签名不变。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/`（新增 `ConversationMessage` / `ConversationRole` 等值类型；文件名待实现时定）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderTextRequestAdapter.swift`（新增多轮 / 流式 body 构造；或拆出 `AIProviderChatStreamingAdapter.swift`）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/`（新增 SSE 行解析器、`AIChatStreamingService`）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPClient.swift`（增量流式读 seam，复用 `bytes(for:)`）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIRequestProjections.swift`（多轮投影）
- 对应 `Tests` 目录新增测试（见第 15 节）

## 9. 参考的代码文件路径

- `Packages/LangoTraceAI/Sources/LangoTraceAI/OpenAICompatibleResponseTextParser.swift`（响应解析参照）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPStatusErrorMapper.swift`（错误映射复用）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`（唯一既有异步流原语 `AsyncStream`（非 throwing）用法参照——本方案首次引入 throwing 变体）
- `LangoTraceApp/AIRequestLogRecorder.swift` + `Packages/LangoTraceAI/Sources/LangoTraceAI/AIRequestProjections.swift`（E6 日志写入依赖方向：recorder 由 App-Shell 驱动、AI service 纯执行器——本方案据此不在 AI 包写日志）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`（单发服务契约，反例：不改）

## 10. 涉及的文档路径

- 本方案。
- [ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md)（前置关系回写）。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`（多轮 + 流式登记）。
- `docs/architecture/002-system-map.md`（AI 流式数据流）。
- 新增 / 更新 architecture note：流式 Provider seam（供 LM03 / 未来 Anthropic 复用）。
- `docs/workflows/add-ai-provider.md`（Anthropic 后置时的入口，回写本方案已铺好多轮 / 流式 seam）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

> 多阶段、跨 Core/AI 包、含流式 spike，设 Phase 0 spike gate。

```text
Phase 0 spike gate：
假设名称：URLSession bytes(for:) 可逐行增量产出 SSE delta，且取消 / 超时 / 体积拦截可在流式下表达。
probe / fixture / baseline 路径：Packages/LangoTraceAI/Tests（合成 SSE 流 fixture + 纯函数解析器先行；真实 URLSession 流式行为标注 macOS/CI）。
PASS 条件：解析器在合成多 chunk SSE 流上正确产出有序 delta + [DONE] 终止 + 半行缓冲；取消令牌中途终止流。
FAIL 条件：解析器无法处理跨 chunk 半行或无法表达取消。
FAIL 后处理方式：退回「非流式多轮」先行（仅目标 1 + 4 + 5），流式降级为后续增量，记入剩余风险。
是否允许进入生产实现：Phase 0 PASS 后方可。
```

1. **Core 值类型**：`ConversationMessage` / `ConversationRole`（system / user / assistant）+ 多轮请求值类型（纯值，先写值类型测试红绿）。
2. **SSE 解析器**：纯函数行解析器（`data:` → delta，`[DONE]` 终止，跨 chunk 半行缓冲）；先失败测试 → 实现。
3. **adapter 多轮 body**：chat/completions（`messages` + `stream: true`）/ responses（`input` + 流式）body 构造；`anthropicMessages` / `geminiGenerateContent` 仍 `unsupportedProvider`。
4. **HTTP 流式读 seam（必须先定协议契约，供确定性测试注入）**：`AIProviderHTTPClient` 当前只有 `func send(...) async throws -> AIProviderHTTPResponse`（全量响应，无增量）。新增**可注入的流式方法**，建议签名 `func streamBytes(_ request: URLRequest, maximumResponseBytes: Int) -> AsyncThrowingStream<UInt8, Error>`（或产出 `Data` chunk 的等价 seam），复用 `bytes(for:)` 增量读、体积拦截在流式累计下保留并在超限时以 `responseTooLarge` 终止流。提供可注入 fake（按脚本投喂 chunk / 触发取消），使第 15 节取消测试**确定性**可写，不依赖真实 URLSession 时序。
5. **`AIChatStreamingService`**：经上述 seam 暴露 `AsyncThrowingStream`（首次引入 throwing 变体），映射失败 / 取消 / 超时 / 配额到既有错误分类（复用 `AIProviderHTTPStatusErrorMapper`）。
6. **投影就绪（不写日志）**：多轮请求 struct 携带 capability / descriptor / length 元数据，使 LM03 可同源构造 preview + log；本方案只到「元数据就绪 + preview 投影纯函数可测」，**不写 `ai_request_logs`、不接 App-Shell recorder、不引入语伴 capability case**（见第 5 节）。
7. **回归 + 文档**：既有 AI 单发用例全绿；spec 005 / architecture note / system-map / ADR-008 回写。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-25
审核方式：隔离审查（general-purpose 子代理只读双轮审查 + 主会话逐条核验写回）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地）
未使用隔离审查的原因：不适用，已使用隔离子代理。
发现摘要（子代理原始分级，主会话已用代码逐条核验）：
  第一轮（架构）：
  - P0/P1 级共 3 项 P1 阻塞：
  - [P1-1] 现状事实错误：原 §2 称「AsyncThrowingStream 仅用于 TTS，SentenceTTSGenerationService 等」。核验成立——`rg AsyncThrowingStream Packages/*/Sources` 0 命中；SentenceTTSGenerationService 是 `async throws -> Result` 非流式；唯一既有异步流是非 throwing 的 `AsyncStream`（SentenceAudioPlaybackCoordinator）。本方案实为**首次引入 AsyncThrowingStream**。修订——改写 §2、§9 参考文件，明确首次引入新模式、spike 风险加权。
  - [P1-2] 实施链路断点：原目标 4「多轮请求产出 previewProjection + makeLogEntry」与 E6 架构冲突。核验成立——`AIRequestProjections.swift:13-15` + `AIRequestLogRecorder.swift:9` 明确 log 由 App-Shell recorder 在请求终止后写入、AI service 纯执行器；`makeLogEntry(outcome:)` 的 outcome 由调用方提供。流式 outcome 只有流终止才知，而本方案不接 App-Shell/store。强行在 AI 包写日志会违反既有依赖方向。修订——目标 4 重构为「投影就绪（携带可投影元数据），不写日志」；§5 补「不在 AI 包写 ai_request_logs」；约束 3、§12 步骤 6、§19、§17 同步；日志写入接线归 LM03。
  - [P1-3] TDD 红绿不可立即落地：取消测试依赖尚未设计的可注入流式协议。核验成立——`AIProviderHTTPClient` 协议只有 `send(...) -> AIProviderHTTPResponse`（全量、无增量）。修订——§12 步骤 4 明确流式 seam 协议签名（streamBytes → AsyncThrowingStream<UInt8,Error> + 可注入 fake）；§15 取消测试先失败原因改为「流式协议 seam 不存在 → 编译失败」、取消断言用 fake 确定性驱动。
  第二轮（测试 / 安全 / 落地）：
  - [P2-1] 新增语伴 capability 会牵动 Core 封闭枚举（AIRequestCapability / ContentDescriptor / FailureBucket）。核验成立（AIRequestPreviewProjection 注释明示 closed set）。决策——本方案**不引入**语伴 capability case，连同 preview/log 一起留 LM03（写入 §5）；§16 补 Core 隐私不变量回归（photoAttachments 仍仅对 photoWritingAssist included）。
  - [P2-2] 流式下体积截断语义模糊：「不泄漏部分缓冲」与逐 token 暴露矛盾。核验成立。修订——§14 澄清超限以 responseTooLarge 终止、已 yield delta 是流式本义非泄漏、半截 UI 表达属 LM03。
  - [P3-1] mimo 流式未经真实验证（api-key 头 + 自带 makeRequest）。采纳——§20 补 mimo 流式后置 / 可先非流式。
  - [P3-2] ADR-008 回写措辞 + system-map 故障态。采纳——§17 精确化回写措辞、补流式失败/取消故障态。
  - 隐私复核：无阻塞——多轮 messages 属用户主动发送（核心决策 #10 明示触发），Memory/Style 注入属 LM02/LM03 不在本方案外发；API Key 经既有 makeRequest 注入不入日志。补充上下文预算提醒写入 §20。
写回修改：P1-1→§2/§9；P1-2→§3 目标 4/§5/§7 约束 3/§12 步骤 6/§17/§19；P1-3→§12 步骤 4/§15；P2-1→§5/§16；P2-2→§14；P3-1→§20；P3-2→§17。无新增 architecture note 需求（跨任务提醒已被 ADR-008 + 2026-05-25 备忘录覆盖，均归 LM02/LM03）；无新 ADR（ADR-005 抽象内传输扩展，定位例外由 ADR-008 承载）。
仍需用户确认的问题：
  1. 实现授权（Reviewed ≠ 已批准实现；状态保持 Draft 待用户 go）。
  2. 流式若 Phase 0 spike FAIL，是否接受降级为「非流式多轮先行」（§12 Phase 0 已写降级路径）。
是否允许进入实现：方案门禁已过（3 项 P1 + P2 已修订写回，自审核状态 Reviewed）；但状态仍为 Draft，须待用户实现授权方可进入 TDD 实现。
```

## 14. 复查方法

- 代码：AI 包流式 / 多轮测试全绿，既有单发用例回归全绿。
- 契约：多轮请求 preview / log 不含正文 / 密钥；`anthropicMessages` / `geminiGenerateContent` 仍明确 `unsupportedProvider`。
- 故障路径：网络失败 / 取消 / 超时 / 4xx 配额在流式下均抛对应错误且流安全终止。**体积上限语义澄清（流式）**：超 `maximumResponseBytes` 时流以 `responseTooLarge` 终止——由于流式逐 token 暴露，已 yield 的 delta 已交付消费者（这是流式本义，非隐私泄漏，内容本就是用户向 Provider 发起的回复）；「半截回复被中断」的 UI 表达属 LM03，本方案只保证**流终止语义正确**，不承诺「不交付部分缓冲」。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceCore/Tests/LangoTraceCoreTests/（ConversationMessage 值类型 / 角色编码）
  Packages/LangoTraceAI/Tests/LangoTraceAITests/（SSE 解析器、多轮 body 形态、流式服务取消 / 错误映射、多轮投影、体积拦截并存）
先失败用例：
  （Core，可独立先行）ConversationMessageTests.encodesOrderedRolesAndContent —— 预期失败：类型尚不存在，编译失败。
  （AI）SSEStreamParserTests.yieldsOrderedDeltasAndTerminatesOnDone —— 预期失败：解析器尚不存在。
  （AI）AIChatStreamingServiceTests.cancellationTerminatesStream —— 预期失败：**流式协议 seam（`streamBytes` + 可注入 fake）尚不存在 → 服务无法构造 → 编译失败**；取消断言用 fake 注入按脚本投喂 chunk 并触发取消（确定性），不用真实 URLSession 时序。
  （AI）AIRequestProjectionsTests.multiTurnRequestMetadataOmitsMessageBodies —— 预期失败：多轮请求 struct 的可投影元数据尚不存在（断言 preview / log 用元数据不含 messages 正文 / 密钥；不验证写入，写入属 LM03）。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceAI
  swift test --package-path Packages/LangoTraceCore
不新增单元测试的原因（如适用）：不适用，全程 TDD。
```

## 16. 验证命令

```bash
# 聚焦（本机 / CI 轻量单包）
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceAI

# 流式真实 URLSession 行为（须 macOS / CI；Linux 无法运行）
# 经 GitHub Actions Build & Test 覆盖
# 含 Core 隐私不变量回归：photoAttachments 仍仅对 photoWritingAssist included
#   （spec 005 §4.8 / AIRequestPreviewProjection 不变量；本方案不引入语伴 capability，应保持现有 projection 测试全绿）

# 文档
scripts/check-docs.sh
```

本方案无 schema 变化、无新 package；流式 `bytes(for:)` 真实行为与三端构建按 CLAUDE.md 1.4 节放 GitHub Actions（仓库临时 public），不在本机跑全量 `scripts/verify.sh`。

## 17. 文档影响检查

- `docs/spec/005-ai-provider-prompt-and-privacy.md`：多轮 + 流式从 §5「可演进」升为 §2/§3 覆盖范围（命中 AI 请求路径变化审查触发）。
- 新增 / 更新 architecture note：流式 Provider seam（供 LM03 与未来 Anthropic 复用），含「日志写入接线归 LM03、本方案只到传输 + 投影就绪」的边界说明。
- `docs/architecture/002-system-map.md`：AI 数据流补流式路径**及流中途失败 / 取消故障态**（若含故障恢复矩阵则登记流式失败恢复路径）。
- [ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md)：回写措辞须精确——「Provider 多轮 + 流式**传输能力 + preview 投影就绪**已落地；对话级 log **写入**接线随 LM03」，避免暗示多轮日志已闭环（实施后）。
- `docs/workflows/add-ai-provider.md`：Anthropic 后置入口处回写本方案已铺多轮 / 流式 seam。
- 是否需要新 ADR：否——本方案是 ADR-005 Provider 抽象内的能力扩展，不改隐私 / 商业 / 默认数据边界（spec 005 §5 末「如影响隐私 / 商业模式 / 默认数据边界应更新 ADR」，本方案均不影响）。
- review：AI 请求路径变化命中专项审查触发，实施后按 `docs/review/README.md` 处理。

## 18. 实施记录

待实现。

## 19. 完成标准

1. 第 3 节目标 1–5 均有代码 / 测试 / 文档证据。
2. AI / Core 聚焦测试全绿，既有单发用例回归全绿；流式真实行为经 CI Build & Test 绿。
3. spec 005 / architecture note / system-map / ADR-008 已同步。
4. plan-vs-shipped 对账：多轮 body、SSE 解析、流式服务、取消 / 失败 / 超时 / 配额、体积拦截并存、多轮请求**投影元数据就绪**（preview 纯函数可测、不含正文 / 密钥）、Anthropic 仍 unsupportedProvider——逐项核对；Anthropic 后置、日志写入接线归 LM03、语伴 capability case 归 LM03 均作为有意 scope-down 记录。

## 20. 剩余风险

- **流式 `bytes(for:)` OS 差异**：与 E0a AI-11 同类，须 macOS / CI 验证，Linux 不可运行。
- **Phase 0 FAIL 降级**：若流式 spike 失败，降级为「非流式多轮先行」，真人感打折，流式作后续增量。
- **Anthropic 后置**：语伴 v1 仅限用户配置了 OpenAI 兼容 / mimo Provider 者；用 Anthropic 的用户需等后续 `add-ai-provider` run。已在第 5 节作为有意 scope。
- **mimo 流式未经真实验证**：第 6 节证据只确认 OpenAI 兼容族原生 SSE；`MimoCompatibleChatTextAdapter` 用 `api-key` 头 + 自带 `makeRequest`，其 endpoint 是否支持 SSE 流式未验证。缓解：v1 mimo 多轮可先非流式，mimo 流式待真实 endpoint 确认（Phase 0 spike 若用合成 OpenAI SSE fixture 无法覆盖 mimo）。
- **日志写入接线归 LM03**：本方案只到「传输 + 投影元数据就绪」，不写 `ai_request_logs`、不接 App-Shell recorder、不引入语伴 `AIRequestCapability` case；这些与流式 outcome 写入强耦合，留 LM03。ADR-008 §6 的「语伴请求经预览 / 日志」义务在 LM03 兑现，本方案保证传输层不阻碍该兑现。
- **上下文预算属 LM03**：多轮 `messages` 体积随会话增长，单次请求体可能远大于现有单发；本方案只保证**任意长度 messages 的传输与体积拦截正确**，上下文窗口 / 摘要 / 裁剪策略属 LM03。
- **首次引入 `AsyncThrowingStream`**：全仓此前 0 命中（既有仅非 throwing `AsyncStream`）；这是新并发模式，Phase 0 spike 须验证跨 chunk 半行缓冲、取消、体积拦截在 throwing 流下均正确。
- **LM03 接线未验证**：本方案只到 Provider 能力 seam；语伴会话 store / UI / Memory 注入的真实接线在 LM03 验证，本方案预留 `ConversationMessage` 值类型与投影契约降低返工。
- **本环境（若 Linux）**无 Swift 工具链，全部测试须 macOS / GitHub Actions。
