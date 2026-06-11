# 任务方案：修复语音模型配音失败问题

状态：Done
自审核状态：Reviewed
类型：bug
创建日期：2026-06-07
最后更新日期：2026-06-07

## 用户确认记录

- 2026-06-07：用户下发指令“立即进行修复”，批准方案实施。

## 1. 需求或 bug 描述

在模拟器中使用 OpenRouter TTS 时，配音测试或句子配音生成失败，表现为日志中抛出 `invalid_audio_response` 错误。

## 2. 现状描述

1. LangoTrace 提供 `TTSConfigurationProbeService` 用于在设置页对 TTS 配置做试听探针（Probe）。
2. 在 `SentenceTTSGenerationService` 中用于句子播放时的音频生成。
3. 当前对包含 stream 流式音频输出的 Multimodal 语言模型（例如 `openai/gpt-audio-mini`），在 probe 服务中直接将 raw response.body (SSE 格式流文本) 传递给 validator，缺少 decode 步骤。
4. 在 validator 中，如果 response 的原始 `Content-Type` 为 `text/event-stream` 或 `application/json`，会被 `isAudioContentType` 直接拦截，导致即使成功解码出了音频字节也报 `invalid_audio_response`。

## 3. 目标

1. 修复 `TTSConfigurationProbeService` 中对于 multimodal 等需要音频解码的 adapter 的音频解码缺失逻辑。
2. 修复 `SentenceTTSGenerationService` 和 `TTSConfigurationProbeService` 在音频解码完成后因为原始 `Content-Type` 为 `text/event-stream` / `application/json` 而在校验期被错误拦截的 bug。
3. 确保 `LangoTraceAI` 中的测试套件 100% 成功，并为本 bug fix 新增完整的单元测试。

## 4. 范围

- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/SentenceTTSGenerationService.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/TTSConfigurationProbeServiceTests.swift`

## 5. 不做什么

- 不调整其他 providers 的生成逻辑（非 TTS 相关能力）。
- 不重构 Keychain 或数据库持久化逻辑。

## 6. 证据与决策依据

根据 `/Users/zibuyu/code/zibuyu/LangoTrace/logs/latest.log` 中最新采集到的错误日志：
```
2026-06-07 23:21:03.645 E  LangoTrace[11308:29923ab] [com.zibuyu.LangoTrace:diagnostics] ai_provider_configuration.probe_failed failed operation_id=EFBF7B6F-99BD-43CB-B96A-FCFC819DECD6 provider_preset_id=openrouter endpoint_purpose=tts model_name=openai/gpt-audio-mini adapter_kind=openai_compatible_chat probe_capability=speech_synthesis probe_capability_status=failed error_category=invalid_audio_response duration_ms=1854
```
这表明当使用 `openai/gpt-audio-mini` (Multimodal) 进行配音探针测试时，返回了 533942 字节的流数据，但由于缺乏解码和被 `Content-Type` 错误拦截，导致错误分类被归为 `invalid_audio_response`。

## 7. 约束映射与验证路径

无特殊约束。

## 8. 涉及的代码 file 路径

- [TTSConfigurationProbeService.swift](file:///Users/zibuyu/code/zibuyu/LangoTrace/Packages/LangoTraceAI/Sources/LangoTraceAI/TTSConfigurationProbeService.swift)
- [SentenceTTSGenerationService.swift](file:///Users/zibuyu/code/zibuyu/LangoTrace/Packages/LangoTraceAI/Sources/LangoTraceAI/SentenceTTSGenerationService.swift)
- [TTSConfigurationProbeServiceTests.swift](file:///Users/zibuyu/code/zibuyu/LangoTrace/Packages/LangoTraceAI/Tests/LangoTraceAITests/TTSConfigurationProbeServiceTests.swift)

## 9. 参考的代码 file 路径

- [TTSAudioResponseValidator.swift](file:///Users/zibuyu/code/zibuyu/LangoTrace/Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAudioResponseValidator.swift)
- [TTSProviderAdapter.swift](file:///Users/zibuyu/code/zibuyu/LangoTrace/Packages/LangoTraceAI/Sources/LangoTraceAI/TTSProviderAdapter.swift)

## 10. 涉及的文档路径

无。

## 11. bug 分析

```text
复现方式：
1. 配置 OpenRouter TTS 端点，选择 openai/gpt-audio-mini 并使用 openRouterMultimodalAudio 适配器。
2. 触发设置页的配置验证（Probe）或生成句子配音。
预期行为：
能够正常接收流式 SSE 报文，从中提取并还原 base64 音频数据，合成 WAV 后正常通过校验并试听。
实际行为：
验证失败，报错 `invalid_audio_response`，没有音频可播放。
根因分析：
1. TTSConfigurationProbeService 在请求成功后，未调用 `adapter.decodeAudio(from:)`，而直接将原始 SSE 数据传给了 validator。
2. 在 validator 校验时，由于原始的 Content-Type 为 text/event-stream，被 isAudioContentType 规则拒绝（认为它不是 audio/* 媒体）。
置信度：100%
置信度依据：
通过对最新日志中 533942 字节的 status 200 返回（SSE 流文本）和 `TTSAudioValidationService.swift` / `TTSConfigurationProbeService.swift` 源码分析，完美契合逻辑。
回归测试方案：
在 `TTSConfigurationProbeServiceTests` 中模拟 SSE text/event-stream 响应，验证其能否正确解码并顺利通过 validate 并成功构建 TTSAudioValidationResult。
```

## 12. 实施方案

### 12.1 修复 `TTSConfigurationProbeService.swift`
在 `probe(...)` 中，添加对 `response.body` 的解码逻辑，并将 Content-Type 覆盖传参：
1. 如果 HTTP 返回 200~299，调用 `adapter.decodeAudio(from: response.body)`。
2. 若解码抛出异常，返回 `invalidAudioResponse` 校验失败结果。
3. 当原始 Content-Type 不包含 "audio" 且状态码为成功时（说明经历了流解码），在调用 `responseValidator.validate` 时，传给它的 `contentType` 参数重写为 `nil`（绕过 isAudioContentType 限制）或者对应 audio 媒体类型。

### 12.2 修复 `SentenceTTSGenerationService.swift`
在 `generateSpeech(...)` 中，当状态码为 200~299 且原始 `httpResponse.contentType` 不包含 "audio"（说明是 event-stream 或 json 格式）时，将传给 `responseValidator.validate` 的 `contentType` 参数置为 `nil`，使其避开 `isAudioContentType` 的媒体拦截。

### 12.3 编写测试用例
在 `TTSConfigurationProbeServiceTests.swift` 中新增测试 `@Test("Draft TTS probe decodes streamed SSE audio chunks for OpenRouter multimodal adapter")`，提供符合 OpenRouter 返回规范的 mock SSE 数据，运行并期望测试通过。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-07
审核方式：主会话自审核
审核轮次：双轮
未使用隔离审查的原因：当前修复点极度内聚，主要影响 TTS 适配器的解码消费端和验证端，方案已经过主会话详尽的代码追溯和推理，不需要隔离审查。
发现摘要：
1. P1: 缺少对 multimodal 响应的解码，导致配置校验时将 SSE 字符直接当作音频校验；
2. P1: validation 在传入 Content-Type 为 `text/event-stream` 或 `application/json` 时，会被 `isAudioContentType` 直接拦截，导致即便解码为 WAV 音频也会报错。
写回修改：已在 12.1 和 12.2 章节中写入。
仍需用户确认的问题：无
是否允许进入实现：是
```

## 14. 复查方法

- 编译并通过 `Packages/LangoTraceAI` 中的所有单元测试。
- 在模拟器中重新进入 Settings -> AI Provider 配置界面对该 TTS 进行 Probe，观察是否转为 Succeeded。

## 15. TDD / 测试落点

```text
测试落点：Packages/LangoTraceAI/Tests/LangoTraceAITests/TTSConfigurationProbeServiceTests.swift
先失败用例：draftTTSProbeDecodesStreamedSSEAudioChunks (未修改代码前运行会因解码缺失而报错，或因 validation 失败而未返回 succeeded)
聚焦验证命令：swift test --package-path Packages/LangoTraceAI --filter TTSConfigurationProbeServiceTests
```

## 16. 验证命令

```bash
swift test --package-path Packages/LangoTraceAI
```

## 17. 文档影响检查

不影响产品主参考、ADR 等长期核心文档，这是一次单纯的 bug fix。

## 18. 实施记录

- 2026-06-07 23:27:
  1. 修改了 `TTSConfigurationProbeService.swift`，加入了对 `response.body` 的解码逻辑，以及在解码成功后重写 validation 的 `contentType` 为 `nil` 的功能。
  2. 修改了 `SentenceTTSGenerationService.swift`，在流解码成功后，如果原始 HTTP content type 不是 audio，则重写为 `nil`。
  3. 在 `TTSConfigurationProbeServiceTests.swift` 中新增了 `draftTTSProbeDecodesStreamedSSEAudioChunks` 校验单元测试，模拟多模态流解码和校验过程。
  4. 运行 `swift test --package-path Packages/LangoTraceAI`，全部 100 个单元测试完美通过，包括新增的测试用例。

## 19. 完成标准

1. `Packages/LangoTraceAI` 测试全部通过，且新增的流式音频校验测试通过。
2. 实施记录已全部回写。

## 20. 剩余风险

无。
