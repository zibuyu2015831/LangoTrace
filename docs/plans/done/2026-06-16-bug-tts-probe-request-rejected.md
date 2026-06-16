# 任务方案：修复 AI Provider 测试请求中的 TTS“请求被拒”

状态：Done
自审核状态：Reviewed
类型：bug
创建日期：2026-06-16
最后更新日期：2026-06-16

## 用户确认记录

本方案由 2026-06-16 用户请求“ai provider 功能存在问题，我在模拟器中点击【测试请求】按钮，语音生成模块显示‘请求被拒’，该功能是系统的 tts 功能基础，进行排查和修复”触发创建。

2026-06-16：用户已明确要求“立即按照这份方案进行修复，清空前面的日志，重新进行测试请求”。据此进入实现，状态推进为 `In Progress`。

## 1. 需求或 bug 描述

模拟器中点击 AI Provider 设置页的 `测试请求` 后，结果面板中的 `语音生成` capability 显示“请求被拒”。该 probe 是逐句播放和后续 TTS 能力的基础健康检查，当前失败会直接削弱用户对 TTS 配置链路的判断能力。

## 2. 现状描述

已核对当前代码与测试，得到以下事实：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/TTSProviderSettingsTests.swift` 已明确记录：`coral` 不支持 `tts-1`，若默认组合为 `tts-1 + coral` 会导致 `providerRejected` probe failure。
- 当前 UI 默认值已经改为 OpenAI `gpt-4o-mini-tts + coral`：
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift` 在加载已保存 `.tts` endpoint 时会回填持久化的 `model`，再单独回填当前语言 voice profile；当前未见对“历史无效模型 + 当前默认 voice”组合的归一化。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSConfigurationProbeService.swift` 会真实发起 TTS probe，并将 4xx/5xx 或音频校验失败映射为稳定错误分类；文件中还残留临时 `print` 调试语句，表明此链路此前已在排查 `providerRejected`。
- Data / AI / UI 多处旧测试和 fixture 仍在使用 `tts-1 + coral`，说明仓库已知存在“默认值已修正，但历史持久化 / 旧配置路径仍可落入旧组合”的风险。

## 3. 目标

1. 找出并修复 TTS probe 进入 `providerRejected` 的根因。
2. 优先保证 OpenAI / OpenRouter 默认 TTS 路径不会因历史配置或归一化缺失落入已知无效组合。
3. 通过 TDD 增加回归测试，覆盖保存配置、加载配置和 probe 请求前的关键归一化路径。
4. 清理排查期间遗留的临时调试输出，避免把 provider 原始响应打印到控制台。

## 4. 范围

- `Packages/LangoTraceUI`：AI Provider TTS draft / loaded profile 归一化与相关测试。
- `Packages/LangoTraceAI`：必要时调整 probe 前置校验或错误分类映射，并补测试。
- 如需最小范围修正文档，仅更新本方案；默认不扩散到 spec / ADR，除非实现中发现当前规范缺口。

## 5. 不做什么

- 不新增新的 Provider 类型或新的 TTS probe 入口。
- 不改变“测试请求”为单一主测试入口的产品设计。
- 不扩展到逐句播放、录音、ASR、请求日志或 Prompt 体系。
- 不运行全量 `scripts/verify.sh`，除非实现范围扩散到跨模块重构或用户明确要求。

## 6. 证据与决策依据

- `docs/plans/README.md`：AI / TTS bug 必须先建 active plan 并经用户确认。
- `docs/plans/plan-review-protocol.md`：实现前需完成严格自审核。
- `docs/workflows/add-tts-provider.md`：要求检查 endpoint / voice profile 分离、固定低敏测试文本、配置 fingerprint、错误分类与聚焦测试。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：
  - TTS probe 必须使用固定低敏文本。
  - voice profile 以 `endpoint_id + language_code` 保存。
  - 失败必须映射为稳定错误分类。
  - 逐句播放只能依赖“已测试通过”的 TTS 配置。

## 7. 复现方式

1. 在模拟器打开 AI Provider 设置页。
2. 配置启用 TTS 的 Provider。
3. 点击 `测试请求`。
4. 观察结果面板中 `语音生成` 一行显示“请求被拒”。

## 8. 预期行为

- 对于 OpenAI / OpenRouter 第一阶段默认推荐配置，点击 `测试请求` 时 `语音生成` 应返回成功，或在确有配置错误时给出与真实根因一致的稳定错误，而不是因历史无效默认组合误报 `providerRejected`。

## 9. 实际行为

- `语音生成` probe 返回“请求被拒”。

## 10. 根因分析

当前高置信度根因：

- 历史保存配置或加载后的 draft 仍可能携带已淘汰的 TTS model。
- OpenAI 路径中，旧模型 `tts-1` 与当前默认 voice `coral` 组合不兼容，会触发 provider 侧拒绝。
- OpenRouter 路径中，模拟器当前保存的 TTS model 仍为 `openai/gpt-4o-mini-audio-preview`，而当前仓库默认与测试基线已经切换到 `openai/gpt-audio-mini`；该历史 model 在 `openrouter_multimodal_audio` 路径下返回 400，并落库为 `provider_rejected`。

需要在实现中最终确认的细节：

- 问题发生在“加载已保存配置后直接测试”的路径，还是“当前草稿保存 / 更新后测试”的路径；两条路径都要以测试覆盖确认。

置信度：85%

置信度依据：

- 仓库已有直接测试注释指明 `tts-1 + coral` 会导致 `providerRejected`。
- OpenRouter 当前默认与测试基线均指向 `openai/gpt-audio-mini`，而模拟器数据库中保存的 voice profile 仍是 `openai/gpt-4o-mini-audio-preview`。
- `ai_provider_validation_events` 最近记录表明：`provider_preset_id=openrouter`、`model_name=openai/gpt-4o-mini-audio-preview`、`status=failed`、`error_category=provider_rejected`。

备选原因：

- OpenAI / OpenRouter adapter 请求体字段与某些模型组合不匹配。
- 已保存 voice profile 与 endpoint model 脱节，导致 probe 请求时发送了不再受支持的 voice / format。
- 错误分类过宽，把更具体的配置问题都收敛成了 `providerRejected`。

## 11. 约束映射与验证路径

- `docs/spec/011-tts-provider-configuration-and-playback.md`
  - OpenAI / OpenRouter 第一阶段推荐模型应为受支持的 TTS model。
  - 失败必须映射为稳定错误分类，但不应掩盖本地可预防的已知无效默认组合。
- `docs/workflows/add-tts-provider.md`
  - 至少验证 voice profile 使用当前语言空间 language code。
  - 配置变化后旧配置不能被误认为当前可用配置。

验证路径：

- 先写失败测试覆盖“加载旧 OpenAI / OpenRouter TTS 配置后 probe/保存前的归一化或兼容修复”。
- 再做最小生产代码变更。
- 最后运行 UI / AI 相关聚焦测试。

## 12. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/TTSProviderSettingsTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/TTSConfigurationProbeServiceTests.swift`

## 13. 参考的代码文件路径

- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSProviderAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPStatusErrorMapper.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAudioResponseValidator.swift`

## 14. 涉及的文档路径

- 本方案
- `docs/workflows/add-tts-provider.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`

## 15. 实施方案

1. 在 UI 测试层先新增失败用例，重现“加载旧 OpenAI TTS 配置或旧模型值时，draft/probe 仍保留 `tts-1 + coral` 导致不可测”的路径。
2. 在 `AIProviderDraftConfiguration` 增加最小归一化逻辑，至少覆盖 OpenAI `.tts` endpoint 的已知无效历史组合；优先选择在加载配置或生成 probe snapshot 之前修正为 `gpt-4o-mini-tts`，避免 UI 与 probe 层继续传播已知坏配置。
3. 如 probe 层仍存在把 provider 原始响应打到控制台的临时调试逻辑，移除该逻辑并保持现有稳定错误分类。
4. 补充 AI / UI 回归测试，确认：
   - 新建 OpenAI draft 仍默认 `gpt-4o-mini-tts + coral`
   - 加载旧配置后不会继续以 `tts-1 + coral` 发起 probe
   - 非 OpenAI provider 不受该兼容修复影响

## 16. 严格方案自审核记录

```text
审核日期：2026-06-16
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：本轮任务范围集中，当前会话已能直接核对相关代码、测试与 workflow；未额外启用隔离审查代理。
发现摘要：
  - [P0] 若直接改 probe 错误文案而不修配置归一化，只会掩盖真实故障，不能进入实现。
  - [P1] 若只修“新建默认值”而不覆盖“加载历史保存配置”路径，模拟器中的真实故障仍会复现。
  - [P1] `TTSConfigurationProbeService` 中的临时 print 会把 provider 响应正文输出到控制台，不符合长期边界。
  - [P2] 旧 fixture 大量使用 `tts-1 + coral`，需要仅更新与当前行为契约直接相关的测试，避免无关大面积改动。
写回修改：
  - 将根因聚焦为“历史配置 / 归一化缺失”，而非泛化为网络层问题。
  - 将 TDD 落点明确到 UI draft / probe 路径，并把调试输出清理纳入范围。
仍需用户确认的问题：
  - 是否按本方案进入生产代码实现。
是否允许进入实现：待用户确认。
```

## 17. 复查方法

1. 用旧 OpenAI TTS 配置样例加载设置页，点击 `测试请求`，确认 `语音生成` 不再因 `tts-1 + coral` 被拒。
2. 用当前默认 OpenAI 配置测试，确认成功。
3. 用 OpenRouter 配置测试，确认不被 OpenAI 兼容修复误伤。
4. 检查控制台不再打印 provider 原始错误正文。

## 18. TDD / 测试落点

先失败用例：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/TTSProviderSettingsTests.swift`
  - 新增用例：加载旧 OpenAI `.tts` endpoint 模型 `tts-1` 且 voice 为 `coral` 时，draft 会在 probe / save 关键路径前归一化到受支持模型。

可选补充用例：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
  - 断言 probe snapshot 对 OpenAI 历史旧模型配置不会继续发出已知坏组合。
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/TTSConfigurationProbeServiceTests.swift`
  - 若修改 probe 层逻辑，则补针对调试输出移除或错误映射的测试。

聚焦验证命令：

- `swift test --package-path Packages/LangoTraceUI`
- `swift test --package-path Packages/LangoTraceAI`

完整验证命令：

- 如仅改 UI / AI 包，默认不跑 `scripts/verify.sh`
- 若实现过程中波及 App 装配或跨包接口，再评估是否需要 `BuildProject` 或额外聚焦构建

## 19. 文档影响检查

- 预期不需要更新 spec / ADR。
- 若实现发现“历史 TTS 配置兼容修复”需要成为长期规则，再补充 `docs/spec/011-tts-provider-configuration-and-playback.md` 的实现边界说明。

## 20. 实施记录

- 2026-06-16：用户确认按本方案立即实施。
- 2026-06-16：在 `AIProviderDraftConfiguration` 增加 OpenAI 历史 `tts-1 + coral` 组合的兼容归一化，并把该归一化同时接到 loaded voice profile、保存输入和 draft probe snapshot。
- 2026-06-16：根据模拟器最新 `ai_provider_validation_events` 与 `ai_provider_tts_voice_profiles` 排查确认，OpenRouter 保存态仍使用历史 model `openai/gpt-4o-mini-audio-preview`，并在 `openrouter_multimodal_audio` 路径上稳定落库为 `provider_rejected`。
- 2026-06-16：在 `AIProviderDraftConfiguration` 增加 OpenRouter 历史 `openai/gpt-4o-mini-audio-preview` -> `openai/gpt-audio-mini` 的 UI 侧兼容归一化。
- 2026-06-16：在 `AIProviderConfigurationService` 增加保存态 TTS 配置归一化，覆盖 `testDefaultConfiguration` 的 TTS probe 和 `loadDefaultPlayableTTSConfiguration` 的后续播放可用性路径，避免数据库中遗留旧 model 时仍直接走坏配置。
- 2026-06-16：移除 `TTSConfigurationProbeService` 中输出 provider 原始响应正文的临时 `print`。
- 2026-06-16：新增 UI 回归测试，覆盖加载旧 OpenAI TTS 配置后保存 / probe 仍会自动升级到 `gpt-4o-mini-tts`。
- 2026-06-16：新增 OpenRouter 回归测试，覆盖保存态历史 model 在 probe 前自动升级到 `openai/gpt-audio-mini`。
- 2026-06-16：已清空 `logs/latest.log`。
- 2026-06-16：`mcp__xcode_tools__.BuildProject` 构建通过；本机 `swift test --package-path ...` 受宿主沙箱限制，未能在当前会话完成包级测试执行。
- 2026-06-16（Phase 3）：**根本根因：OpenRouter 完全换用专用 TTS 端点。** 经查询 OpenRouter 官方博客公告，OpenRouter 实际支持 `/api/v1/audio/speech` 专用 TTS 端点，模型为 `openai/gpt-4o-mini-tts-2025-12-15`。代码中错误注释"OpenRouter has no /audio/speech endpoint"导致仓库一直使用对话式音频模型（`openai/gpt-audio-mini` via `chat/completions`）；即使设置 `modalities: ["audio"]` + 强化 system prompt，对话式模型也无法纯朗读——它会把输入当问题回答。真正的 TTS 模型通过 `/audio/speech` 直接返回原始音频字节，无对话行为。
  - 改动 1：`AIProviderSettingsModels.swift` — OpenRouter `defaultSpeechModel` → `openai/gpt-4o-mini-tts-2025-12-15`，`defaultTTSAdapterKind` → `.openRouterAudioSpeech`，修正错误注释。
  - 改动 2：`AIProviderDraftConfiguration.swift` — `normalizedTTSModel` 增加 `openai/gpt-audio-mini` 中间态归一化到新模型。
  - 改动 3：`AIProviderConfigurationService.swift` — 扩展 `normalizeLegacySavedTTSConfiguration` 增加 `settings` 参数；OpenRouter + multimodal adapter → 归一化到 `openRouterAudioSpeech` + 新模型；更新两个调用点（probe 路径和 playback 路径）均使用 normalized settings。
  - 测试更新：`TTSProviderSettingsTests.swift`（adapter kind 期望、默认模型期望、legacy 升级测试）；`AIProviderConfigurationServiceTests.swift`（legacy OpenRouter probe 测试改 HTTP response 为原始音频字节，fixture `savedProfileWithTTS` 改用规范模型 `gpt-4o-mini-tts` 避免归一化后指纹错位）。
  - 所有测试 `swift test --package-path Packages/LangoTraceUI`（374 passed）和 `swift test --package-path Packages/LangoTraceAI`（146 passed）均已通过。
- 2026-06-16（Phase 4）：**再次根因修正：OpenRouter 专用 TTS 模型实际不存在。** Phase 3 改动依据 OpenRouter 博客公告（`openai/gpt-4o-mini-tts-2025-12-15`），但用户测试后仍返回"请求被拒"。诊断日志确认 HTTP 400，错误体为 `{"error":{"message":"Model openai/gpt-4o-mini-tts-2025-12-15 does not exist","code":400}}`。查询 OpenRouter `/api/v1/models` 确认该模型确实不在模型列表；博客公告中的其他 TTS 模型（`google/gemini-3.1-flash-tts-preview`、`mistralai/voxtral-mini-tts-2603`）同样不存在。OpenRouter 目前仅有两个音频能力模型：`openai/gpt-audio` 和 `openai/gpt-audio-mini`，均为对话式多模态模型，只支持 `/chat/completions` 路径。
  - 决策：回退到 `openRouterMultimodalAudio` + `openai/gpt-audio-mini`，保留强 system prompt 抑制对话行为；专用 TTS 端点在 OpenRouter API 稳定可用后再切换。
  - 改动 1：`AIProviderSettingsModels.swift` — OpenRouter `defaultSpeechModel` 回退至 `openai/gpt-audio-mini`，`defaultTTSAdapterKind` 回退至 `.openRouterMultimodalAudio`，更新注释说明当前限制。
  - 改动 2：`AIProviderDraftConfiguration.swift` — `normalizedTTSModel` 改为将 `openai/gpt-4o-mini-audio-preview` 和 `openai/gpt-4o-mini-tts-2025-12-15`（Phase 3 写入的错误值）都归一化到 `openai/gpt-audio-mini`。
  - 改动 3：`AIProviderConfigurationService.swift` — `normalizeLegacySavedTTSConfiguration` 改为将任何 OpenRouter `openRouterAudioSpeech` 配置（Phase 3 遗留）或已知旧 model 都回归至 `openRouterMultimodalAudio` + `openai/gpt-audio-mini`；同步移除 Phase 3 诊断期间添加的所有 `NSLog` 语句。
  - 改动 4：`TTSConfigurationProbeService.swift` — 移除诊断 `NSLog` 语句。
  - 测试更新：`TTSProviderSettingsTests.swift` 和 `AIProviderConfigurationServiceTests.swift` 期望值全部更新到 `openRouterMultimodalAudio` + `openai/gpt-audio-mini`；AI 包 legacy probe 测试 mock response 改为有效 SSE 格式。
  - `swift test --package-path Packages/LangoTraceUI`（374 passed）和 `swift test --package-path Packages/LangoTraceAI`（146 passed）均通过。

## 21. 完成标准

- 模拟器中的 `测试请求` 不再因 OpenAI 历史无效默认组合稳定落入“请求被拒”。
- 新增回归测试先失败后通过。
- 聚焦测试通过。
- 临时调试输出被清理。

## 22. 回归测试方案

- 覆盖新建默认配置、加载旧配置、生成 probe snapshot、非 OpenAI provider 不受影响四类路径。

## 23. 剩余风险

- 如果真实根因还包含 provider 侧接口变化，本轮修复可能只能解决最主要的一条本地可控路径；届时需要在实现中继续收窄并补充更具体的错误分类或请求体适配。
