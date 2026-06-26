# 任务方案：LM03-S4b —— Anthropic Messages 多轮 + 流式适配

状态：Reviewed（双轮隔离自审完成；待用户实现授权）
自审核状态：Reviewed（见 §11）
类型：feature
创建日期：2026-06-27
最后更新日期：2026-06-27
所属系列：语伴（LM03）切片拆解 → S4（v2）按风险拆 S4a（Style 注入）/ **S4b（本片：Anthropic 适配）**
上游决策文档：[`active/2026-06-25-docs-lm03-companion-decomposition.md`](2026-06-25-docs-lm03-companion-decomposition.md) §LM03-S4
Workflow：[`workflows/add-ai-provider.md`](../../workflows/add-ai-provider.md)

## 1. 背景与定位

LM03-S4 是语伴系列 v2，自然分裂为 **S4a（Style 注入）+ S4b（Anthropic 适配）**，与 S2a/S2b、S3a/S3b 同构。2026-06-27 用户决策：**先做 S4b（Anthropic 适配，独立于 §9 Style 时机待决）**；§9 收口为 **A（未来 S4a 注入 v1 surface Style）**，不影响本片。

本片只做 **Provider 传输层**：让语伴（及其它文本 AI 能力）可运行在用户自配的 **Anthropic Messages** Provider 上，补齐 2026-06-25 多轮+流式 enabler 明确后置的 Anthropic 适配。

**当前事实**（调查 2026-06-27）：
- `AIProviderAdapterKind.anthropicMessages`（Core）**已存在**；UI `AIProviderPreset.anthropic` 已可选（`defaultBaseURL https://api.anthropic.com/v1`、`defaultChatModel claude-sonnet-4-5`、`authHeaderKind x-api-key`、`capabilities.chat=true`）。
- 但 `AIProviderTextRequestAdapterFactory` 对 `.anthropicMessages` **抛 `.unsupportedProvider`** → 现在保存/探针/语伴跑 Anthropic 都失败。
- 多轮+流式传输层（`AIChatStreamingService` / `ServerSentEventParser` / `AIProviderStreamingHTTPClient` / adapter `streamingChatBody`+`streamContentDelta`）已就绪，仅 OpenAI 兼容族实现；reserved kinds 默认 `nil`/throw。

## 2. 目标与非目标

**目标（本片交付一个可用、诚实的 Anthropic Provider）**：
1. `AnthropicMessagesTextAdapter`：多轮 + 流式（语伴实际所需）+ 单提示（探针保存/校验所需）。
2. Anthropic 鉴权（`x-api-key` + `anthropic-version`，非 Bearer）经**可动态派发的协议接缝**注入。
3. Anthropic 响应/流式解析（`content[].text` / SSE `content_block_delta`）。
4. 工厂放行 `.anthropicMessages`；设置页对 Anthropic 放行文本探针。
5. 顺带修复 mimo 鉴权**潜伏死代码 bug**（见 §5）。

**非目标（明确后置，本片不做）**：
- **严格 schema 结构化输出（tool_use）**：本片 `structuredCompletionBody` 产出形状正确的 Anthropic body，`outputText` 读 `content[].text`（对“被 prompt 要求输出 JSON 的文本”尽力解析）；学习材料/阅读解析等结构化能力在 Anthropic 上为**尽力而为文本-JSON**，严格 tool_use + 双模 `outputText` 留作后续加性增强（§2.1）。
- **图片理解**：Anthropic `supportsInlineImage=false` 维持；`imagePromptBody` 仅产出形状正确 body，探针跳过，服务门控不调用。
- **Gemini 适配**：`.geminiGenerateContent` 仍 reserved/throw。
- **S4a Style 注入**：另起切片（§9=A 已收口为未来方向）。

### 2.1 为什么结构化严格模式后置而非另拆 S4b-2
探针（textReply / structuredJSON / languageSupport）实测均调 `plainPromptBody`（非 `structuredCompletionBody`），imageUnderstanding 探针对 Anthropic 跳过。故“Anthropic 可保存+校验+跑语伴”只需 plain + streaming，结构化严格模式与本片解耦、可后续单独硬化，不构成本片阻塞，**保持单片 S4b 不再下拆**（自审未发现需拆的风险，§11）。

## 3. 隐私边界（决策 #10 / ADR-005 / spec 005）

- **无新外发类目、无新敏感数据类型**：Anthropic 只是又一个用户自配 Provider 端点；语伴整体 opt-in 与逐项隐私闸（S2b-1/S3b-1）**不变**，PII scrub 不变。
- **凭证**：Anthropic API Key 走既有 Keychain 路径（与其它 Provider 同），明文不进 SQLite / 日志 / 同步 / 请求预览 / 测试输出。`x-api-key` 头在 adapter 内构造，不落日志。
- **请求预览 / 日志**：语伴 `companionConversation` capability 已披露；provider preset id = `anthropic`。本片不新增 `AIRequestCapability`（capability 与 adapterKind 正交）→ **无 exhaustive switch 破坏风险**（区别于 S3b-1）。

## 4. 设计：鉴权协议接缝（本片核心正确性点 = P0 设计）

**问题**：`makeRequest` 仅在协议扩展中（非协议要求），调用点在 `any AIProviderTextRequestAdapter` 存在体上 → **静态派发**到扩展版（Bearer）。mimo 自定义 `makeRequest(baseURL:secret:body:timeoutSeconds:)` 签名不同、无人调用 = 死代码。故“每 adapter 自定义头”必须改为**可动态派发的协议要求**。

**方案**：在协议体新增**要求** `func providerRequestHeaders(secret: String?) -> [String: String]`，默认实现（扩展）返回 OpenAI Bearer：`secret` 非空 → `["Authorization": "Bearer \(secret)"]`。`makeRequest`（扩展）改为遍历该字典 `setValue`。因 `providerRequestHeaders` 是协议要求，扩展内 `self.providerRequestHeaders(...)` 经 witness table **动态派发** → 子类型覆盖生效。
- **Anthropic 覆盖**：`["x-api-key": secret, "anthropic-version": "2023-06-01"]`（secret 非空时）。
- **mimo 覆盖**：`["api-key": secret]`，**删除其死签名 `makeRequest`**（潜伏 bug 修复，§5）。
- **OpenAI 系**：继承默认 Bearer（行为不变）。

> 正确性依据：Swift 协议要求在扩展方法内经 `self` 调用是动态派发；扩展-only 方法是静态派发。本接缝把头策略从“扩展-only（不可覆盖）”升为“协议要求（可覆盖）”，是 §1.2 长期正确基础设施而非最小补丁。

## 5. 顺带修复：mimo 鉴权潜伏 bug

mimo 当前实际走扩展 `makeRequest` → 发 `Authorization: Bearer`（而非 `api-key`）；其自带 `api-key` override 因签名不匹配从不被调用。本片接缝改造**连带修复**：mimo 经 `providerRequestHeaders` 真正发 `api-key`。须加 mimo 回归测试 + 扫描既有 mimo 鉴权断言并校准（§7 P1-2）。

## 6. Anthropic 线格式要点（与 OpenAI 的实质差异）

| 维度 | OpenAI 兼容 | Anthropic Messages |
| --- | --- | --- |
| 鉴权头 | `Authorization: Bearer` | `x-api-key` + `anthropic-version: 2023-06-01` |
| system | messages 数组内 `role:system` | **顶层 `system` 字符串**（不入 messages 数组） |
| max_tokens | 可选 | **必填**（缺则 400） |
| 角色 | system/user/assistant | 仅 user/assistant（首条 user、交替） |
| path | `chat/completions` / `responses` | `messages` |
| 非流式正文 | `choices[].message.content` | `content[].text`（type==text 拼接） |
| 流式 delta | `data: {choices[].delta.content}` + `data:[DONE]` | `data: {type:content_block_delta, delta:{type:text_delta,text}}`；**无 `[DONE]`**，EOF 终止 |

**关键**：`streamingChatBody` **不可**复用 `conversationWireMessages`（它把 system 塞进数组）；须自建 messages（仅 user/assistant）+ 顶层 system + `max_tokens`。SSE `event:` 行被既有 parser 忽略不影响——Anthropic `data:` JSON 自带 `type` 字段足以识别 text_delta，**无需改 SSE parser**。EOF 终止已由 `AIChatStreamingService` line 146 `finish()` 保证（见调查）。
- **max_tokens 取值**：实现时确认 `AIProviderEndpointInput` 是否含上限字段；有则取之，无则常量默认（4096）。

## 7. TDD 落点（先写失败测试，再最小实现）

### AI package（本片主体）
1. **`AnthropicMessagesTextAdapter`**（新文件 `Packages/LangoTraceAI/Sources/LangoTraceAI/AnthropicMessagesTextAdapter.swift`）：`pathSuffix="messages"`；`providerRequestHeaders` 覆盖；`streamingChatBody`（顶层 system + max_tokens + user/assistant + stream:true）；`streamContentDelta`（经新 `AnthropicStreamDeltaExtractor`）；`plainPromptBody` / `structuredCompletionBody` / `imagePromptBody` / `structuredImagePromptBody`（形状正确 Anthropic body）；`outputText`（经新 `AnthropicResponseTextParser`）。
2. **鉴权接缝**（改 `AIProviderTextRequestAdapter.swift`）：新增协议要求 `providerRequestHeaders` + 默认 Bearer；`makeRequest` 改用之；删 mimo 死 override + mimo 覆盖。
3. **`AnthropicResponseTextParser`**（新）：`messagesText(fromResponseObject)` → 拼接 `content[].text`（type==text）。
4. **`AnthropicStreamDeltaExtractor`**（新）：`contentDelta(fromDataPayload)` → 解析 `content_block_delta.delta.text_delta`，对 message_start/ping/content_block_start/message_stop 返回 nil。
5. **工厂**：`.anthropicMessages` → 返回 adapter（移出 throw 组；gemini 仍 throw）。

**AI 测试**（`Packages/LangoTraceAI/Tests/LangoTraceAITests/`）：
- `AnthropicMessagesTextAdapterTests`（新）：鉴权头 = x-api-key + anthropic-version 且**非** Bearer；`streamingChatBody` 形状（system 顶层不入数组、max_tokens 在、角色 user/assistant）；`plainPromptBody` 形状；`outputText` 解析 `content[].text`；`streamContentDelta` 解析 text_delta、对非文本事件返回 nil。
- **既有测试校准（P1-1，S3b-1 式跨测试破坏）**：`AIProviderTextRequestAdapterTests` 工厂用例 + `AIChatStreamingServiceTests` reserved-kinds 用例当前断言 `.anthropicMessages` **throw** → 改为 supported；仅留 `.geminiGenerateContent` reserved/throw。
- **mimo 回归（P1-2）**：断言 mimo 现真发 `api-key`；OpenAI 系仍 Bearer。
- `AIChatStreamingServiceTests`（增）：脚本化 Anthropic SSE（event+data 行）端到端，断言 delta 累积 + **EOF 无 [DONE] 正常终止**；401 → `providerRejected(auth)`。
- `AIProviderConfigurationProbeServiceTests`（增）：Anthropic plain textReply 成功路径（脚本化 `content[].text`）+ 凭证不泄漏 + 取消不写失败事件。

### Core package
- 无 enum 变更（`anthropicMessages` 已存在）；预期零 Core 代码改动。

### UI package
- 设置页 capability 策略：对 `.anthropicMessages` 放行 textReply/structuredJSON/languageSupport 探针（switch **改返回值非加 case** → 无 CI 破坏）；校准任何“Anthropic 无探针”的既有 UI 断言。
- **必跑全量 UI 测试本机**（S3b-1/S3b-2 教训：no-hardcoded-Han 守卫 + exhaustive switch + band 守卫）。新增 UI 源注释**英文**。

### App package
- 预期零改动：语伴 send 经 `AIChatStreamingServiceRequest(endpoint:…)`，`adapterKind` 由保存端点流入；工厂放行后 Anthropic 即可流式。**P1-4：实现时核验 `AppEnvironment+Companion` send 路径 kind-agnostic（无 openAI 硬编码）**。macOS app test 覆盖编译。

### Prompt Registry
- 无新 Prompt（语伴 prompt 不变；Anthropic 仅传输）。

## 8. 故障与恢复矩阵

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| API Key 缺失 | 可恢复 credential-missing（探针） | probe 测试 |
| 无效 key（401） | `providerRejected(.auth)` 经状态映射，不伪装网络失败 | streaming/probe 测试 |
| 模型不支持（400/404） | `providerRejected(...)` 稳定分类 | streaming 测试 |
| 缺 max_tokens（400） | 适配器始终带 max_tokens，杜绝该故障 | adapter 测试断言 body 含 max_tokens |
| 用户取消 | `cancelled`，不写失败事件 | service 测试 |
| 返回格式不合法 | `invalidResponse` / `invalidResponseBody`，不写 Data | parser/service 测试 |
| 流无 [DONE] | EOF `finish()` 正常终止 | streaming EOF 测试 |

## 9. 验证

- 聚焦：`swift test --package-path Packages/LangoTraceAI`（主体）。
- 全量 UI：`swift test --package-path Packages/LangoTraceUI`（Han/band/exhaustive 守卫；S3b-1 教训）。
- 完整：GitHub Actions `Build & Test`（三端构建 + macOS app test + 全包 + lint）。仓库 public→CI→private（默认先取得用户许可）。
- 本机一次只跑一个包 `swift test`（本会话教训：并发跑撞坏共享 module cache 致 Speech/Sync 编译 fatalError、UI 测试卡死）。

## 10. 文档影响（§17 收口落点，实现后回写）
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：Anthropic Messages 流式/多轮现已支持 + 鉴权头接缝。
- `docs/architecture/002-system-map.md`：Provider adapter 矩阵补 Anthropic；鉴权接缝。
- `docs/architecture/notes/2026-06-25-chat-streaming-provider-seam-notes.md`：Anthropic 落地、SSE event 行无需改 parser、EOF 终止。
- `docs/platform-page-inventory.md`：设置页 Anthropic 探针放行。
- `docs/idea/03-conversation-partner.md` §10.3 / 拆解 doc §LM03-S4 / 仪表盘：S4b Done、S4a 待。
- 审查：AI Provider + Keychain + 请求预览边界触碰 → 按 `docs/review/README.md` 判断专项审查；无新 ADR（anthropicMessages 早为 reserved 决策；本片是其兑现）。

## 11. 双轮隔离自审核记录（plan-review-protocol）

**轮次一（架构/正确性）**：
- **P0（核心设计，correct-by-construction）**：鉴权必须为**协议要求**（动态派发），非扩展-only。已据此设计 `providerRequestHeaders` 协议要求 + 默认 Bearer，`makeRequest` 内 `self.` 调用经 witness table 派发。若误放扩展则 Anthropic 头永不生效（= mimo 现状 bug）。已规避。
- **P1-2**：删 mimo 死 override 改变 mimo 实际线上头（Bearer→api-key），属行为修复；须 mimo 回归测试 + 扫描既有断言。
- **P1-3**：`streamingChatBody` 禁用 `conversationWireMessages`（system 入数组）；须顶层 system + max_tokens。
- **P2**：`anthropic-version` 必带（缺则 400）；折入 `providerRequestHeaders` 返回的头字典（非密钥常量）。

**轮次二（隔离再审，对抗式，假设未见轮一）**：
- **SSE `event:` 行**：既有 parser 弃 `event:` 仅留 `data:` —— Anthropic `data:` JSON 自带 `type` 字段足以判定 text_delta → **无需改 parser**（确认非 P0）。
- **EOF 终止**：`AIChatStreamingService:146` 在字节流 EOF `finish()`；Anthropic 无 `[DONE]` 仍正常终止（确认非 hang）。
- **P1-1（新发现，S3b-1 式跨测试破坏）**：既有 `AIProviderTextRequestAdapterTests` 工厂用例 + `AIChatStreamingServiceTests` reserved-kinds 用例**断言 anthropicMessages throw**；本片放行使其失败 → 必须同步改这两处既有测试（移 anthropicMessages 出 throw 期望，仅留 gemini）。**这是最易被漏的破坏点**。
- **错误映射**：401→`unacceptableStatusCode(401)`→`providerRejected(auth)`，状态映射已覆盖，无需改。
- **P1-4**：核验 App 语伴 send kind-agnostic（无 openAI 硬编码）。
- **P2（结构化）**：Anthropic 结构化 = 尽力而为文本-JSON；严格 tool_use 后置，学习材料在 Anthropic 上失败为稳定 parse error 非静默损坏，记为已知限制。
- **P2（UI）**：capability 策略 switch 仅改返回值非加 case（无 CI 破坏）；校准既有 UI 断言；全量 UI 本机跑。

**自审结论**：单片 S4b 连贯、无需再下拆（鉴权接缝+adapter+parsers+工厂+少量 UI/测试校准互相耦合，半片不可用）。结构化严格模式为可后续加性硬化、非阻塞。最高风险=P1-1 既有测试破坏（已入计划先改）+ P0 鉴权派发（已 correct-by-construction）。升 **Reviewed**，待用户实现授权。

## 12. 剩余风险（授权时知情）
1. Anthropic 线格式细节（max_tokens 字段来源、anthropic-version 值）以官方 Messages API 为准；实现时若 endpoint 无 max_tokens 字段用常量 4096。
2. mimo 行为修复连带触碰非语伴 Provider；回归测试覆盖。
3. 结构化严格模式在 Anthropic 上后置 = 学习材料/阅读/照片能力在 Anthropic 上为尽力而为（语伴/探针不受影响）。
