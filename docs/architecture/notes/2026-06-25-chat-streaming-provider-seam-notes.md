# Chat Streaming Provider Seam Notes

状态：Accepted
创建日期：2026-06-25

## 适用范围

适用于后续任何「多轮对话 + 文本流式」AI 能力：语伴（LM03）会话引擎、未来任意需要逐 token 呈现或携带会话历史的能力，以及 Anthropic / Gemini 多轮 + 流式适配的后续接入。

## 背景

截至本备忘录创建时，AI Provider 多轮 + 文本流式 enabler 已落地（`docs/plans/done/2026-06-25-feature-ai-provider-multi-turn-and-streaming.md`），补齐了此前缺失的对话级传输能力：

- `Packages/LangoTraceCore/.../ConversationMessage.swift`：`ConversationMessage`（`role: ConversationRole` system/user/assistant + `content`）纯值类型，供 AI 构造请求、未来 LM03 UI / store 复用同一 transcript 模型。
- `Packages/LangoTraceAI/.../ServerSentEventParser.swift`：字节级 SSE 行解析器，仅按 `0x0A` 切分——UTF-8 不会在多字节序列内嵌入 `0x0A`，故完整行总可安全解码，自然跨 chunk 半行与多字节字符；`OpenAIStreamDeltaExtractor` 提供 chat/completions 与 responses 两种 delta 提取。
- `Packages/LangoTraceAI/.../AIProviderHTTPClient.swift`：新增 `AIProviderStreamingHTTPClient` 协议（`streamBytes(_:maximumResponseBytes:) -> AsyncThrowingStream<UInt8, Error>`），与单发 `AIProviderHTTPClient` 分离以不动既有单发 conformer / fake；`URLSessionAIProviderHTTPClient` 同时实现两者，复用 `bytes(for:)` 增量读、保留体积上限拦截、非 2xx → `unacceptableStatusCode(Int)`、取消 / 超时映射。
- `Packages/LangoTraceAI/.../AIChatStreamingService.swift`：暴露 `AsyncThrowingStream<AIChatStreamEvent, Error>`（**全仓首个 throwing 异步流**），把取消 / 超时 / 网络 / 配额 / 体积映射到既有错误分类（复用 `AIProviderHTTPStatusErrorMapper`）；纯执行器，不写 `ai_request_logs`。

## 目的

- 防止后续多轮 / 流式能力各自重写传输层；统一经 `AIChatStreamingService` 流式 seam。
- 记录本 enabler **刻意未做**的接线点，避免后续会话误以为已闭环。
- 固化「流式 outcome 的日志写入归调用方（App-Shell recorder）」的 E6 依赖方向，防止在 AI 包内反向写日志。

## 已有设计留下的扩展点

- `AIProviderAdapterKind` 五枚举 + `streamingChatBody` / `streamContentDelta` 协议方法（默认 `nil`）已是流式支持矩阵的 allowlist 维度：chat/responses 已实现；mimo 流式未验证暂继承 `nil`（= `unsupportedProvider`）；anthropic / gemini 仍由工厂 `unsupportedProvider`。
- `AIChatRequestProjectionMetadata`（preset / model / lengthBucket / messageCount）是「投影就绪、不含正文」的非敏感元数据契约，LM03 据此用既有 `AIRequestProjections` 同源构造 preview + 无正文 log。
- `ServerSentEventParser` 的字节级设计已天然支持 Anthropic SSE 事件流（事件名 + data 行）——后续 Anthropic 接入只需新增 delta 提取分支与 `x-api-key` 鉴权 body，不必重写行解析。

## 后续任务必须重新决策的问题

- **mimo 流式**：mimo 用 `api-key` 头 + 自带 `makeRequest`，其 endpoint 是否支持 SSE 未验证；当前流式服务经协议扩展 `makeRequest`（Bearer）构造请求，mimo 流式刻意 defer。后续验证 mimo SSE 后再决定是否放行其 `streamingChatBody`。
- **对话级日志写入接线**（归 LM03）：流式 outcome 只有流终止才知；本 enabler 不接 App-Shell recorder、不引入语伴 `AIRequestCapability` case。LM03 须用 `projectionMetadata()` + 自己的 capability case 在请求终止后写 `ai_request_logs`，兑现 ADR-008 §6 的「语伴请求经预览 / 日志」。
- **上下文预算 / 裁剪**（归 LM03）：`messages` 体积随会话增长；本 enabler 只保证任意长度的传输 + 体积拦截正确，窗口 / 摘要 / 裁剪策略属 LM03。
- **Memory / Style 注入**（归 LM02 / LM03）：本 enabler 只提供能携带任意 system + messages 的传输能力，不做 `LearnerContextProvider` 接线或难度自适应 prompt 片段。

## 不应在当前阶段提前实现的内容

- 不在 AI 包写 `ai_request_logs`（违反 E6 依赖方向）。
- 不引入语伴专属 `AIRequestCapability` / `AIRequestContentDescriptor` / `AIRequestLogFailureBucket` case（Core 封闭枚举，扩展是 deliberate change，归 LM03）。
- 不建语伴会话 store / UI / `CompanionMessage` schema（归 LM03）。
- 不做 Anthropic / Gemini 适配（后置，走 `docs/workflows/add-ai-provider.md`）。
