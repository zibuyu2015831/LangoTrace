# AI Provider 向量化配置测试方案

状态：In Progress
类型：feature
创建日期：2026-05-27
最后更新日期：2026-05-27

## 1. 用户确认记录

- 2026-05-27：用户指出 AI Provider 中目前仅剩向量化测试未完成，要求深入思考并给出方案。
- 2026-05-27：经讨论确认本轮不是继续保持占位状态，而是要完成真实网络测试请求，为后续向量化基础设施提供能力前提。
- 2026-05-27：用户确认第一阶段真实向量化配置测试只支持 OpenAI、OpenAI-compatible 和 OpenRouter；其他 Provider 暂不实现。
- 2026-05-27：用户要求立即创建 active plan，之后由用户审核该 plan，通过后才能实施。本方案因此仅创建实施方案，不实施代码；后续实现前必须由用户把状态确认到 `User Approved`。
- 2026-05-27：按系统架构师视角完成严格代码审查，确认原方案方向正确但实施前必须补齐 endpoint-scoped validation、provider allowlist、独立 capability 聚合、通用 endpoint fingerprint、opt-in live smoke 和未来向量基础设施备忘录边界。
- 2026-05-27：再次复查方案与当前代码状态，确认方案已进入实施中：阶段 1 / 阶段 2 已完成并分别提交，阶段 3 存在未提交实现文件；本次修订只同步方案上下文、已完成证据、接口命名和剩余实施边界，不扩大实现范围。

## 2. 需求描述

AI Provider 设置页已经支持文本模型、语音生成模型和向量模型三类 endpoint 配置。当前文本回复、JSON 输出、语言支持、图片理解和语音生成配置测试已陆续进入真实或受控 probe 阶段，但向量化仍只作为结果面板中的占位能力显示，不能验证用户配置的 embedding endpoint、模型、Base URL 和凭证是否真正可用。

本任务要为 AI Provider 配置测试补齐真实 `向量化` probe：当用户显式启用并配置向量模型时，测试按钮应对 embedding endpoint 发送固定低敏合成文本，验证 Provider 是否返回合法 embedding vector。该能力只用于配置连通性和响应格式验证，不创建向量索引，不读取或发送用户生活记录，也不写入长期记忆数据。

## 3. 现状描述

代码事实：

- `AIProviderEndpointPurpose` 已包含 `.embedding`。
- `AIProviderProbeCapability` 已包含 `.embedding`。
- `AIProviderDraftConfiguration` 已包含 `embedding: AIOptionalModelDraftConfiguration`，并可把启用后的 embedding endpoint 写入 profile save input。
- `AIProviderConfigurationProbeService` 当前固定把 `.embedding` 返回为 `.notEnabled`，不发真实网络请求。
- `AIProviderConfigurationService` 当前合并文本 probe 和 TTS probe；尚无 embedding probe service，也没有从 saved profile 中解析 embedding endpoint 凭证并执行测试的路径。
- `AIProviderSettingsComponents` 已有 `aiProviderSettings.probeCapability.embedding` 和 `invalidEmbeddingResponse` 文案。
- `AIProviderAdapterKind.capabilityPolicy.canProbeEmbedding` 已在阶段 2 调整：OpenAI Responses 和 OpenAI-compatible Chat 的 adapter policy 可表达第一阶段 embedding probe 能力；最终放行仍必须叠加 provider preset allowlist、provider capability policy、endpoint purpose、用户启用状态和配置完整性。
- `GRDBAIProviderConfigurationRepository.recordValidationOutcome(_:)` 当前会插入 validation event 后无条件更新 `ai_provider_profiles.last_validation_status`；不能直接用于 embedding endpoint scoped outcome，否则会把 embedding 结果污染为 profile 全局验证摘要。
- `ai_provider_validation_events.endpoint_id` 已能记录 endpoint 归属；阶段 1 已为 `ai_provider_endpoints` 增加 endpoint-level 最近验证摘要字段，并为 endpoint input / configuration 增加通用 `configurationFingerprint`。
- UI provider preset 中 OpenAI、OpenRouter 和 Custom OpenAI-compatible 的 embedding policy 可表达为 supported / model-dependent；但多个其他 Provider 也使用 OpenAI-compatible adapter，因此第一阶段不能只按 adapterKind 放行，必须同时按 provider preset allowlist、provider capability policy、adapter capability policy 和用户启用状态判定。
- `AppEnvironment.makeAIProviderConfigurationService(...)` 当前仍只装配 text probe service 和 TTS probe service；阶段 4 必须新增 embedding probe service 注入。

当前实施快照：

- 阶段 1 已提交：`3dca90c Add endpoint validation fingerprint contract`。
- 阶段 2 已提交：`69aba31 Add embedding probe UI capability resolution`。
- 阶段 3 正在实施中，当前未提交文件为 `Packages/LangoTraceAI/Sources/LangoTraceAI/EmbeddingConfigurationProbeService.swift` 和 `Packages/LangoTraceAI/Tests/LangoTraceAITests/EmbeddingConfigurationProbeServiceTests.swift`；阶段 3 必须先通过聚焦测试再提交。

文档事实：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 当前仍写明“向量化当前阶段不得发真实网络测试请求，应显示未启用、未配置或暂不支持测试”。本任务会改变该长期规则，必须同步修订该 spec。
- `docs/product-main-reference.md` 和 `docs/technical-framework-roadmap.md` 已将 Embedding / 向量化列为长期记忆底层能力，并要求外部 embedding API 必须由用户明确配置并知情。
- `docs/plans/done/2026-05-19-feature-ai-provider-multi-model-configuration.md` 已确立文本模型、语音生成模型和向量模型是三个独立 endpoint，可以共享凭证但不共享 Base URL、adapter 或模型名。
- `docs/testing/README.md` 已有 OpenAI-compatible text probe 工具说明；本轮需要扩展为 opt-in embedding live smoke，不能让默认验证依赖真实网络和真实密钥。

## 4. 目标

本任务完成后必须达到：

- AI Provider 配置测试结果面板中的 `向量化` 行可显示真实测试结果。
- 第一阶段只对 provider preset 为 `openai`、`openrouter` 或 `custom-openai-compatible` 的 embedding endpoint 执行真实 probe。
- 其他 Provider 的 embedding probe 返回稳定的 `unsupported` 或 `notConfigured`，不得伪装成认证失败、网络失败或模型失败。
- Draft 测试只使用当前页面短生命周期明文草稿，不写 Keychain、SQLite 或 validation event。
- Saved profile 测试通过 Keychain 引用解析 embedding endpoint 凭证，并把结果作为 embedding endpoint scoped 的非敏感 `synthetic_test` 记录。
- Saved profile 的 text、TTS 和 embedding probe 必须按 endpoint 独立 preflight、credential resolve、probe 和持久化；text endpoint 失败或缺少 credential 时，不得短路已配置完整的 embedding endpoint 测试。
- 测试请求只发送固定低敏合成文本，不发送 Entry、LearningMaterial、Prompt Preset、历史记忆、照片、音频、OCR、附件摘要、用户自定义长文本或向量索引内容。
- 响应验收只检查 embedding shape：`data[0].embedding` 必须是非空数字数组；不保存 vector 数组，不进入日志、validation event、诊断属性或 UI 测试输出。
- `向量化` 结果必须携带 embedding endpoint metadata，包括 endpoint id、purpose、provider preset、model 和 configuration fingerprint，避免误用文本 endpoint 的 metadata。
- 文本模型 profile 全局验证摘要不得被 embedding 结果污染；embedding 的持久化结果必须写入 embedding endpoint 自己的 validation event，并更新 embedding endpoint-level validation summary 或使用只插入 event、不更新 profile summary 的专用 API。
- 本轮必须建立通用 endpoint configuration fingerprint 规则，至少覆盖 endpoint purpose、provider preset、adapter kind、Base URL、model name、credential id / credential mode、request timeout 和 output-affecting capability flags；embedding metadata 应携带该 fingerprint。
- 增加 opt-in 真实网络 smoke 验证入口，用于开发者在提供环境变量时验证 OpenAI / OpenRouter / Custom OpenAI-compatible embeddings；该 live smoke 不进入默认 `scripts/verify.sh`，也不得打印 API Key、请求体、响应体或 embedding vector。
- 更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`，把旧的“不得发真实网络测试请求”改为本轮第一阶段真实低敏 probe 边界。
- 新增未来向量基础设施备忘录，沉淀本轮不实现但会影响后续 embedding job queue、向量索引、重建、删除、同步和隐私提示的边界。

## 5. 范围

本任务覆盖：

- Core 层为 embedding probe 结果表达补齐 endpoint metadata、endpoint configuration fingerprint 和错误分类测试。
- AI 层新增 embedding probe service、请求体构造、响应解析和错误映射。
- AI service 层新增 capability-level orchestration，把 text、TTS、embedding 按 endpoint 独立执行后合并进 `AIProviderConfigurationProbeResult`。
- UI draft 层在向量模型启用且配置完整且 provider preset 进入第一阶段 allowlist 时把 `.embedding` 加入 requested capabilities；启用但配置不完整或 provider 不支持时显示稳定 row 状态。
- Data / Repository 层新增 endpoint-scoped validation 写入契约：embedding outcome 不得调用会更新 profile 全局摘要的 `recordValidationOutcome(_:)`；如新增 endpoint-level validation summary，则同步 migration、repository、fixture 和测试。
- 结果面板继续复用现有 capability list，不新增独立按钮。
- Tooling 层补充 opt-in live embedding smoke 和单元测试；默认完整验证只跑 mock / unit，不依赖真实网络或真实密钥。
- 同步更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/testing/README.md` 和必要的 prompt / 页面事实文档。
- 新增 `docs/architecture/notes/` 中的 embedding / 向量基础设施备忘录，记录本轮不实现但会影响后续向量索引和 job queue 的维度、fingerprint、重建、删除、同步和隐私边界。
- 单元测试覆盖 request、response、错误、draft/saved 持久化、独立 capability 聚合、endpoint fingerprint、UI requested capability 和三端共享 action seam。

## 6. 不做什么

本任务不实现：

- 不创建、写入或查询真实向量索引。
- 不实现 FTS、语义搜索、相似记录召回、长期记忆检索或 embedding job queue。
- 不为 Entry、SentencePair、Practice、Memory candidate 或图片摘要生成 embedding。
- 不保存 embedding vector、vector 维度统计、完整响应体或 provider 返回的 usage 细节。
- 不实现模型列表发现、OpenRouter embeddings models API、动态能力发现或模型推荐。
- 不实现 Anthropic、Gemini、DeepSeek、Mistral、Groq、xAI、DashScope、Zhipu、SiliconFlow、Ollama 等 Provider 的 provider-specific embedding adapter。
- 不改变首次启动 onboarding，不让 AI Provider 成为创建语言空间的硬门槛。
- 不引入向量数据库、pgvector、sqlite-vss、sqlite-vec 或本地 ANN 索引。

## 7. 证据与决策依据

### 7.1 项目内依据

- `docs/workflows/add-ai-provider.md`：新增 Embedding、Provider adapter 或 Provider probe 属于 AI Provider 高风险 workflow，必须先创建 active plan，写明请求内容、凭证边界、日志边界、失败路径和验证。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：所有 AI 请求必须经过 Provider 层；API Key 不进入 SQLite、日志或同步目录；Provider 配置测试只能发送固定合成内容，不得发送用户生活内容。
- `docs/product-main-reference.md`：外部 embedding API 必须由用户明确配置并知情；AI、Embedding、TTS 和同步应视为不同能力，分别配置、分别授权。
- `docs/technical-framework-roadmap.md`：向量索引是本地可重建派生数据；embedding provider 是长期记忆基础设施，但不等于本轮要实现向量索引。
- `docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md`：结果面板中的多能力测试应优先让 capability row 携带 endpoint metadata，该扩展点适用于 embedding。
- live code 审查确认 `recordValidationOutcome(_:)` 会更新 profile global summary，因此 embedding endpoint outcome 必须使用 endpoint-scoped API 或 endpoint-level summary。

### 7.2 外部 API 依据

调研时间：2026-05-27。

- OpenAI Embeddings API 官方文档说明 `POST /v1/embeddings` 创建 embedding vector，请求体包含 `input` 和 `model`，可指定 `encoding_format: "float"`；响应返回 `data[].embedding` 数组。来源：https://platform.openai.com/docs/api-reference/embeddings/create
- OpenRouter Embeddings 官方文档说明 `POST https://openrouter.ai/api/v1/embeddings` 可生成 embeddings，请求体包含 `model` 和 `input`；响应同样返回 `data[].embedding`。来源：https://openrouter.ai/docs/api/reference/embeddings

### 7.3 关键决策

| 决策 | 结论 | 理由 | 防误读 |
| --- | --- | --- | --- |
| 第一阶段 Provider 范围 | OpenAI、Custom OpenAI-compatible、OpenRouter | 三者都可按 `/embeddings` 形态实现，能快速建立基础设施边界 | 不代表其他 Provider 不支持 embedding，只是本轮不接入。 |
| 第一阶段放行条件 | provider preset allowlist 为 `openai`、`openrouter`、`custom-openai-compatible`，并同时满足 provider policy、adapter policy、endpoint purpose 和用户启用 | 避免 DeepSeek、Groq、Mistral 等 OpenAI-compatible adapter provider 被误开 embedding probe | “OpenAI-compatible”在本轮指 Custom OpenAI-compatible，不等同所有兼容层预设。 |
| 请求内容 | 固定低敏合成文本 `LangoTrace embedding configuration test.` | 验证配置可用性即可，不需要用户内容 | 不评估真实语义质量。 |
| 响应验收 | `data[0].embedding` 为非空数字数组 | 足以验证 endpoint、模型、鉴权和基础返回格式 | 不保存 vector，不比较相似度。 |
| Service 形态 | 新增独立 embedding probe service，再由 `AIProviderConfigurationService` 合并结果 | 避免继续膨胀 text probe service，也避免 endpoint ownership 混乱 | 不新增独立 UI 按钮。 |
| Capability 聚合 | text、TTS、embedding 各自 preflight、credential resolve、probe 和持久化，最后合并 result | 三类 endpoint 是独立能力边界，不能让 text 失败短路 embedding | 整体状态可 failed / partial，但每行状态必须真实反映自己的 endpoint。 |
| 持久化 | Saved profile 写 embedding endpoint scoped validation event；draft 不持久化；embedding outcome 不更新 profile 全局摘要 | 与凭证和 endpoint 边界一致 | 不能直接复用当前会更新 profile summary 的 `recordValidationOutcome(_:)`。 |
| Endpoint fingerprint | 新增通用 endpoint configuration fingerprint，并写入 metadata | 后续向量索引、缓存、失效和重建都依赖稳定配置指纹 | 不保存 API Key、完整请求头或 embedding vector。 |
| Live smoke | 提供 opt-in 命令验证真实 OpenAI / OpenRouter / Custom endpoint | 用户明确要求本轮形成真实网络测试能力 | 不进入默认 CI / `scripts/verify.sh`，无环境变量时跳过。 |
| 文档更新 | 修改 `spec/005` 旧禁止规则，并新增未来向量基础设施备忘录 | 本轮需求明确改变了当前阶段边界，也会影响后续向量索引设计 | 必须保留低敏、显式启用和不发送用户内容的限制。 |

## 8. 涉及的代码文件路径

预计修改：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderProbeHTTPClient.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/EmbeddingConfigurationProbeService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `scripts/probe_openai_compatible_api.py`
- `Tests/Tooling/test_probe_openai_compatible_api.py`

预计新增：

- `Packages/LangoTraceAI/Tests/LangoTraceAITests/EmbeddingConfigurationProbeServiceTests.swift`
- `docs/architecture/notes/2026-05-27-embedding-infrastructure-notes.md`

预计修改测试：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/AIProviderConfigurationProbeTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/AIProviderConfigurationTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/AIProviderConfigurationRepositoryTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`

## 9. 参考的代码文件路径

- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSProviderAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/SentenceTTSGenerationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPClient.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/SentenceAudioPlaybackAssembly.swift`

## 10. 涉及的文档路径

必须修改：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/testing/README.md`
- `docs/architecture/notes/2026-05-27-embedding-infrastructure-notes.md`

需要检查并按事实同步：

- `docs/platform-page-inventory.md`
- `docs/prompts/ai-provider/provider-configuration-probe.md`
- `docs/technical-framework-roadmap.md`
- `docs/product-main-reference.md`
- `docs/spec/009-testing-and-verification.md`

暂不新增 ADR。理由：本任务不改变本地优先、用户自带 Provider、Keychain 存储、可重建向量索引默认不同步等核心决策；只是把已存在的 embedding endpoint 配置从占位测试推进到第一阶段真实低敏配置 probe。

## 11. 实施方案

### 11.1 阶段 1：Core、Data 和 endpoint validation 契约

1. 在 Core 测试中锁定 `.embedding` capability 的顺序、endpoint metadata 表达和 `invalidEmbeddingResponse` 错误分类。
2. 在 Core 新增通用 endpoint configuration fingerprint 生成规则，禁止把 API Key、完整 Keychain account、完整请求头、请求体、响应体或 vector 内容纳入 fingerprint。
3. 在 Data 层新增 endpoint-scoped validation 写入契约，优先方案为：
   - `recordEndpointValidationOutcome(_:)`：插入 endpoint-scoped `ai_provider_validation_events`，不更新 `ai_provider_profiles.last_validation_status`。
   - 在 `ai_provider_endpoints` 上增加 `last_validated_at`、`last_validation_status`、`last_validation_error_category`、`last_successful_configuration_fingerprint`，repository 只更新对应 endpoint。
4. 为当前 `recordValidationOutcome(_:)` 添加回归测试：它仍只用于 profile/global text synthetic outcome；embedding 持久化不得调用它。

### 11.2 阶段 2：UI capability resolver 和 draft snapshot

1. 新增 embedding capability decision helper，放行条件必须同时满足：
   - `endpoint.purpose == .embedding`
   - `embedding.isEnabled == true`
   - provider preset id 是 `openai`、`openrouter` 或 `custom-openai-compatible`
   - provider capability policy 的 embedding 为 `.supported` 或 `.modelDependent`
   - adapter capability policy 的 `canProbeEmbedding == true`
   - endpoint base URL、model 和 credential 来源满足当前 draft / saved probe 要求
2. 修改 `AIProviderDraftConfiguration.configurationProbeRequestedCapabilities(...)`：启用且完整且可 probe 时加入 `.embedding`；启用但不完整时由本地 result override 显示 `.notConfigured`；启用但 provider 不在 allowlist 时显示 `.unsupported`。
3. 扩展 `AIProviderDraftProbeSnapshot` 和 `AIProviderConfigurationProbeDraftInput`，携带 `embeddingEndpoint`、`embeddingPlaintextSecret` 和 embedding requested capability。
4. 复用现有 shared credential 规则：embedding 可共享 text credential，也可独立 credential；draft 测试只读取当前 UI draft 明文，不写 Keychain。

### 11.3 阶段 3：Embedding probe service

1. 新增 `EmbeddingConfigurationProbeService`，输入为 embedding endpoint、plaintext secret、operation id、固定测试文本和可选 clock。
2. 支持 provider preset `openai`、`openrouter`、`custom-openai-compatible` 的 `/embeddings` 请求；其他 provider 直接返回 `.unsupported` 且不得调用 HTTP client。
3. 请求体包含：

```json
{
  "model": "<embedding model>",
  "input": "LangoTrace embedding configuration test.",
  "encoding_format": "float"
}
```

4. 响应解析只读取 `data[0].embedding`，并验证它是非空数字数组。
5. 返回 `AIProviderProbeCapabilityResult(capability: .embedding, ...)`，成功或失败均携带 embedding endpoint metadata。
6. `URLRequest.timeoutInterval` 使用 endpoint 的 `requestTimeoutSeconds`，没有配置时沿用当前 probe 默认行为。
7. 错误映射：
   - 401 / 403：`.authenticationFailed`
   - 404：`.unsupportedModel`
   - 429：优先 `.rateLimited`；若响应体可稳定识别 quota，再映射 `.quotaExceeded`
   - 非 2xx 其他状态：`.providerRejected`
   - 网络不可用：`.networkUnavailable`
   - 超时：`.timeout`
   - 取消：`.cancelled`
   - JSON 不合法、缺 `data`、缺 `embedding`、空数组或非数字数组：`.invalidEmbeddingResponse`

### 11.4 阶段 4：Draft / saved profile 独立 capability 聚合

1. `AIProviderConfigurationService` 注入 `EmbeddingConfigurationProbeService?`，并在 `AppEnvironment.makeAIProviderConfigurationService(...)` 中装配真实 service。
2. `testDraftConfiguration(...)` 按 text、TTS、embedding 三类 capability 独立执行。text 失败时 embedding 仍可在 draft endpoint 完整且 provider 支持时运行；draft 不写 Keychain、SQLite 或 validation event。
3. `testDefaultConfiguration(...)` 从 saved profile 分别查找 enabled text / TTS / embedding endpoint。缺少 text endpoint 时不应阻止 enabled embedding endpoint 的 preflight 和 probe；没有任何可测 endpoint 时才返回 missing required endpoint。
4. Saved embedding endpoint 使用自己的 credentialID 解析 Keychain；共享 text credential 时通过 credential metadata 解析同一 Keychain item，但 result metadata 仍属于 embedding endpoint。
5. Saved embedding probe 的持久化必须调用 endpoint-scoped API，不得更新文本 endpoint 的 profile 全局摘要，也不得把 embedding 失败写成 language support 或 TTS 失败。
6. 如果 embedding endpoint 启用但缺少配置或缺少 credential，返回 `.notConfigured` 或 `.failed(.missingCredential)`，并保持错误归属在 embedding row。
7. 聚合 overall status 规则：
   - 任一实际运行 capability 取消时 overall 为 `.cancelled`，且不写失败 validation event。
   - required text probe 失败时 overall 可为 `.failed`，但 embedding row 保留自己的 succeeded / failed / unsupported 状态。
   - embedding 未启用、未配置或 unsupported 不应让已通过的 text profile global synthetic outcome 变为 failed。
8. 当前 `AIProviderConfigurationService.testDefaultConfiguration(...)` 仍以 enabled text endpoint 为必需前置，且 saved probe preflight failure 会直接返回；阶段 4 必须重构为 capability-level collection 后再执行各自 preflight，避免继续保留该短路路径。
9. 当前 `AIProviderConfigurationProbeDraftInput` 的 embedding 字段已由 UI draft snapshot 准备好，但 AI package 的 draft probe input 构造和 App 注入仍需在阶段 4 对齐；不能只让 UI 侧 requested capability 显示 `.embedding` 而服务层忽略。

### 11.5 阶段 5：结果面板、live smoke、文案和文档

1. 确认结果面板无需新增独立按钮，只展示 caller supplied capability rows。
2. 如现有文案不足，补充 embedding `notConfigured` / `unsupported` / `invalidEmbeddingResponse` 的中英文文案。
3. 扩展 `scripts/probe_openai_compatible_api.py` 或新增等价脚本，支持 opt-in embedding live smoke：
   - 环境变量输入 API Key、Base URL、model。
   - 发送同一固定低敏文本。
   - 只输出 status、category、provider/model、duration 和 vector length；不输出 API Key、请求体、响应体或 vector。
   - 无环境变量时不运行真实网络请求。
4. 更新 `docs/testing/README.md`，写明 live smoke 的运行命令、跳过条件、失败含义和脱敏边界。
5. 更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`，删除旧的“向量化当前阶段不得发真实网络测试请求”，替换为本轮第一阶段低敏测试边界。
6. 新增 `docs/architecture/notes/2026-05-27-embedding-infrastructure-notes.md`，记录本轮不实现但后续必须决策的向量索引 schema、维度、模型 fingerprint、重建策略、删除策略、同步 / 导出边界、job queue 和隐私提示。
7. 检查 `docs/platform-page-inventory.md` 和 Prompt Registry 是否需要同步当前事实。

## 12. TDD 与测试方案

实施时必须先写失败测试，再写生产代码。

### 12.1 Core tests

命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationProbeTests
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationTests
```

覆盖：

- `.embedding` capability 顺序保持在结果面板末尾。
- embedding result 可携带 `.embedding` endpoint metadata。
- `invalidEmbeddingResponse` raw value 稳定。
- 通用 endpoint configuration fingerprint 不包含敏感字段，且相同 endpoint 输出影响字段相同则 fingerprint 稳定、model / base URL / adapter / purpose 改变则 fingerprint 改变。

### 12.2 AI tests

命令：

```bash
swift test --package-path Packages/LangoTraceAI --filter EmbeddingConfigurationProbeServiceTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationServiceTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationProbeServiceTests
```

覆盖：

- OpenAI embedding probe 请求 URL 为 `/embeddings`，body 含固定测试文本、model 和 `encoding_format: "float"`。
- OpenRouter embedding probe 使用 `/embeddings`，并支持 OpenRouter base URL。
- Custom OpenAI-compatible endpoint 使用 `/embeddings`。
- 成功响应 `data[0].embedding` 非空数字数组时返回 `.succeeded`。
- 空 vector、字符串 vector、缺 data、缺 embedding、非 JSON 响应返回 `.invalidEmbeddingResponse`。
- 401 / 403 / 404 / 429 / timeout / network / cancellation 映射正确。
- endpoint `requestTimeoutSeconds` 会进入 embedding `URLRequest.timeoutInterval`。
- Draft probe 不写 Keychain 或 validation event。
- Saved probe 使用 embedding endpoint credential，不误用 text endpoint model 或 metadata。
- Saved text credential 缺失时，不短路已配置且独立 credential 完整的 embedding probe。
- Saved embedding 缺 credential 时只污染 embedding row，不写 text endpoint 或 profile global failure。
- OpenRouter / OpenAI / Custom OpenAI-compatible 以外的 OpenAI-compatible adapter provider 不发 embedding HTTP。
- `AIProviderConfigurationService` 合并 text、TTS、embedding 结果时保持 capability row 顺序和 endpoint metadata。

### 12.3 Data tests

命令：

```bash
swift test --package-path Packages/LangoTraceData --filter AIProviderConfigurationRepositoryTests
```

覆盖：

- endpoint scoped validation API 确认 embedding endpoint outcome 只更新对应 endpoint 的 validation event 和 endpoint-level summary。
- 当前 `recordValidationOutcome(_:)` 仍更新 profile summary，且 embedding 持久化路径不会调用它。
- 不保存 request body、response body、vector 数组、API Key 或完整 Keychain account。

### 12.4 UI tests

命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
```

覆盖：

- 未启用向量模型时不请求 `.embedding`。
- 启用但配置不完整时结果为 `.notConfigured`。
- 启用且配置完整时 requested capabilities 包含 `.embedding`。
- OpenAI / OpenRouter / Custom OpenAI-compatible 可进行 embedding probe。
- DeepSeek、Groq、Mistral 等使用 OpenAI-compatible adapter 但不在第一阶段 allowlist 的 provider 不请求 `.embedding` 或稳定显示 unsupported。
- 其他 Provider 显示 unsupported 或不允许 probe。
- Draft text probe 不完整时，如果 embedding 独立配置完整，测试按钮 readiness 应允许进入测试，UI snapshot 仍可携带 embedding endpoint；文本行显示自己的 notConfigured / failed 状态，不阻塞 embedding row。
- SwiftUI 仍不包含 `URLSession`、`Authorization` 或 `Bearer` 拼接。

### 12.5 Tooling / live smoke tests

命令：

```bash
python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py
```

覆盖：

- embedding mode 构造 `/embeddings` URL 和固定低敏请求体。
- embedding mode 成功时只输出 vector length，不输出 vector 内容。
- 401 / 404 / 429 / timeout 分类稳定。
- 输出中不包含 API Key、Authorization header、完整请求体或完整响应体。
- 无真实环境变量时 live smoke 不自动运行。

## 13. 复查方法

实施前复查：

```bash
rg -n "embedding|向量化|invalidEmbeddingResponse|canProbeEmbedding" Packages docs/spec docs/prompts
rg -n "URLSession|Authorization|Bearer " Packages/LangoTraceUI/Sources/LangoTraceUI
```

实施后复查：

```bash
rg -n "LangoTrace embedding configuration test|/embeddings|invalidEmbeddingResponse" Packages/LangoTraceAI Packages/LangoTraceUI docs scripts Tests/Tooling
rg -n "向量化当前阶段不得发真实网络测试请求|不得发真实网络测试请求" docs/spec docs/plans/active
rg -n "recordValidationOutcome\\(|recordEndpointValidationOutcome|last_successful_configuration_fingerprint|configurationFingerprint" Packages/LangoTraceAI Packages/LangoTraceData Packages/LangoTraceCore
git diff --check
```

人工复查重点：

- embedding probe 是否只在用户显式启用并配置向量模型后执行。
- 是否有任何用户内容进入 embedding probe。
- embedding response vector 是否只用于 shape validation，没有被持久化或写日志。
- OpenRouter 与 Custom OpenAI-compatible 是否使用 embedding endpoint，而不是 chat completions endpoint。
- 文本、TTS、embedding 三类 endpoint metadata 是否各自归属正确。
- embedding outcome 是否没有调用会更新 profile global summary 的持久化路径。
- OpenAI-compatible allowlist 是否没有误覆盖其他 routed provider。

## 14. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationProbeTests
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationTests
swift test --package-path Packages/LangoTraceAI --filter EmbeddingConfigurationProbeServiceTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationServiceTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationProbeServiceTests
swift test --package-path Packages/LangoTraceData --filter AIProviderConfigurationRepositoryTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py
```

完整验证：

```bash
scripts/verify.sh
```

文档检查：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

Opt-in live smoke 示例：

```bash
OPENAI_API_KEY='...' OPENAI_BASE_URL='https://api.openai.com/v1' OPENAI_EMBEDDING_MODEL='text-embedding-3-small' \
  scripts/probe_openai_compatible_api.py --mode embeddings --json
```

该命令只在开发者主动提供环境变量时运行；默认验证和 CI 不运行真实网络请求。

## 15. 文档影响检查

本任务会改变 AI Provider 配置测试和隐私边界文档，必须执行文档影响检查。

必须更新：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`：修订向量化测试边界。
- `docs/testing/README.md`：登记 opt-in embedding live smoke 命令、跳过条件、失败含义和脱敏输出边界。
- `docs/architecture/notes/2026-05-27-embedding-infrastructure-notes.md`：新增未来向量基础设施备忘录。

需要同步检查：

- `docs/platform-page-inventory.md`：若页面事实描述仍称向量化只是占位，应更新。
- `docs/prompts/ai-provider/provider-configuration-probe.md`：如果固定 embedding probe 文本纳入 Prompt Registry 管理，应登记请求文本、输出契约和隐私边界。
- `docs/technical-framework-roadmap.md`：若其仍表达 embedding 仅为未来能力，需要补充“配置测试已支持第一阶段低敏 probe，但向量索引尚未实现”。
- `docs/product-main-reference.md`：通常不需要修改，除非当前文字与“外部 embedding API 可被用户显式配置并测试”冲突。
- `docs/spec/009-testing-and-verification.md`：若需要登记 embedding live smoke 或新增敏感字段扫描规则，应同步更新。

是否触发专项文档审查：

- 本任务涉及 AI Provider、隐私边界和高风险 Provider 请求。完成后应按 `docs/review/README.md` 做一次事件触发文档影响检查，至少确认 spec、plan、prompt registry、testing docs、architecture note 和页面事实没有互相冲突。

## 16. 实施记录

- 2026-05-27：创建 active plan。初始状态为 `Draft`，等待用户审核；未实施代码。
- 2026-05-27：根据严格方案审查修订 plan，补齐 endpoint-scoped validation、provider allowlist、独立 capability 聚合、通用 endpoint fingerprint、opt-in live smoke 和未来向量基础设施备忘录要求。
- 2026-05-27：阶段 1 已完成并提交 `3dca90c Add endpoint validation fingerprint contract`。已运行并通过：`swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationTests`、`swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationProbeTests`、`swift test --package-path Packages/LangoTraceData --filter AIProviderConfigurationRepositoryTests`。
- 2026-05-27：阶段 2 已完成并提交 `69aba31 Add embedding probe UI capability resolution`。已运行并通过：`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`、`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`。
- 2026-05-27：再次复查方案完整性。结论：方案总体链路完整，但状态和部分现状描述需与当前实施进度对齐；已更新为 `In Progress`，并明确阶段 3 未提交、阶段 4 必须移除 saved text endpoint 短路、阶段 5 必须完成文档和 live smoke 收口。

## 17. 完成标准

- 用户审核本方案并确认进入 `User Approved` 后才开始实现。
- OpenAI、Custom OpenAI-compatible 和 OpenRouter 的 embedding configuration probe 均有单元测试覆盖。
- 其他 Provider 暂不实现时有稳定 unsupported / not configured 行为和测试。
- Draft probe 不持久化。
- Saved probe 通过 Keychain 引用解析 embedding credential，且只写非敏感 endpoint scoped validation outcome。
- Saved embedding outcome 不调用会更新 profile 全局摘要的持久化路径；endpoint-level validation summary 只更新 embedding endpoint 自己的摘要。
- Text、TTS、embedding 三类 capability 独立 preflight / credential resolve / probe / persist，text endpoint 失败不短路配置完整的 embedding endpoint。
- OpenAI-compatible 第一阶段只包含 Custom OpenAI-compatible，不误放行其他使用 OpenAI-compatible adapter 的 Provider。
- Endpoint metadata 携带通用 configuration fingerprint，且 fingerprint 不含敏感字段。
- Opt-in live embedding smoke 可在提供环境变量时发真实网络请求，并通过单元测试证明默认验证不依赖网络、不泄露密钥和 vector。
- 结果面板展示真实 `向量化` 行结果，并携带 embedding endpoint metadata。
- 不发送、不保存、不记录用户内容或 embedding vector。
- `docs/spec/005-ai-provider-prompt-and-privacy.md` 已同步修订旧边界。
- `docs/architecture/notes/2026-05-27-embedding-infrastructure-notes.md` 已创建，用于承接本轮不实现但影响后续的向量索引和 embedding job queue 边界。
- 聚焦测试和 `scripts/verify.sh` 通过。
- 实施完成后本方案移动到 `docs/plans/done/`，状态更新为 `Verified` 或 `Done`，并记录验证命令和结果。

## 18. 剩余风险

- OpenAI-compatible Provider 的 `/embeddings` 兼容程度不一致，部分服务可能返回 OpenAI-like 但字段略有差异。第一阶段只接受 OpenAI / OpenRouter 标准 shape，避免过度兼容导致误判。
- OpenRouter embedding 模型可用性依赖具体模型和路由状态；测试成功只代表当前模型和路由可用，不代表 OpenRouter 全局 embedding 永久可用。
- 本轮不做模型列表发现，用户可能填写 chat model 到 embedding endpoint，测试会以 `unsupportedModel`、`providerRejected` 或 `invalidEmbeddingResponse` 反馈。
- 本轮不建立向量索引 schema，因此后续真正写入向量索引时仍需单独设计维度、模型 fingerprint、重建策略、隐私提示和删除策略。
- 本轮选择新增 endpoint-level validation summary，会产生 GRDB migration；当前仍处早期开发阶段，不需要兼容真实用户历史数据，但必须保证现有测试 fixture 和 repository 读取路径同步更新。
- Custom OpenAI-compatible 的 `/embeddings` 兼容性只能通过 shape 验证确认基础可用，不代表 provider 支持批量 embedding、维度配置、token 计费或生产吞吐。
