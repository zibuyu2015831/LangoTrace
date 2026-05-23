# 任务方案：语音模型配置与测试

状态：Done
审核状态：Approved With Notes
类型：feature
创建日期：2026-05-23
最后更新：2026-05-23

## 1. 用户确认记录

- 2026-05-23：用户要求先完成逐句播放方案的前提条件，即语音模型的配置和测试功能。
- 2026-05-23：用户要求网上搜索目前系统内置 Provider 的语音模型配置方式，深入思考后创建尽量详细的方案文档。
- 2026-05-23：本方案仅创建实施方案，不实施代码。后续实现前仍需用户确认方案状态从 `Draft` 进入 `User Approved`。
- 2026-05-23：系统架构复审结论为 `Needs Changes`。交互方向和 Provider 调研方向成立，但当前方案尚不具备直接实施条件：需要收紧第一批实现范围、明确 TTS network / audio / playback 的模块归属、重构 multi-endpoint probe result、修正多语言 voice 配置模型、隔离可选 TTS 测试失败对 profile 全局验证状态的影响，并补充现有 action seam / repository / Data 事务的落地步骤。
- 2026-05-23：用户确认前期需要实现 OpenAI 和 OpenRouter 两个 Provider 的语音模型配置与测试。其余架构问题由系统架构复审直接给出推荐方案：采用 language code 级 voice profile、profile-level probe result、TTS 验证状态隔离、AI/Speech 职责拆分和单一测试入口。审核状态从 `Needs Changes` 调整为 `Approved With Notes`，但任务状态仍为 `Draft`，实现前仍需用户确认进入 `User Approved`。
- 2026-05-23：用户采纳先创建长期规范文档的建议，并确认对暂不实施但会影响后续架构边界的任务项补充备忘录文档。
- 2026-05-23：针对“是否具备实施条件”的复审结论为 `Needs Changes`。本次修订补齐与 `011` 规范的差异：双 fingerprint、第一阶段范围收紧、错误枚举落点、profile-level probe 前置、真实代码路径和测试边界。该修订不代表用户已经批准进入代码实施，任务状态仍保持 `Draft`。
- 2026-05-23：用户补充确认语音模型测试应内置多个语言版本的固定测试文本，点击测试时根据当前语言空间的目标语言自动选择对应文本进行配音，再检查音频返回；该测试结果应绑定当前 language code，用于发现当前模型、voice 或路由不支持该目标语言的情况。
- 2026-05-23：系统架构师复审后，用户要求立即修订本方案。本次修订明确：TTS adapter kind 的事实源为 TTS settings，不把真实 TTS adapter 强塞进现有 text/chat `AIProviderAdapterKind`；TTS validation 必须新增 endpoint / voice-profile scoped repository API，不得复用会更新 profile 全局摘要的 `recordValidationOutcome(_:)`；`008` 请求预览规则已经完成修订，后续实施只需保持一致；第一阶段必须新增 `unsupportedLanguage` 错误分类。
- 2026-05-23：系统架构师再次复审后，用户要求立即修订本方案。本次修订明确：`LangoTraceAI` 不得直接依赖 `LangoTraceSpeech`；TTS 音频校验应通过 Core 协议 / AppEnvironment 注入 Speech 实现；Custom OpenAI-compatible 不属于第一阶段真实 TTS probe；`005` 规范已完成修订，实施阶段只需一致性检查。后续基础设施原则复审已废弃“仅 AI 侧轻量响应校验可作为第一版音频验收”的可选路径。
- 2026-05-23：用户补充早期开发与基础设施原则：当前项目可推翻落后设计，不为早期临时代码背历史包袱；基础设施首次实现应采用长期可扩展方案；`docs/` 是 AI 辅助开发控制面，规范可随更优设计演进；暂不实现但影响后续架构的能力必须写入开发备忘录。基于该原则，本方案再次修订：TTS 音频验收不再允许以 AI 侧轻量响应校验替代，必须建立 Core 音频校验协议、Speech 实现和 Speech package 测试 target；设置页样例试听只能经 Speech seam 处理短生命周期 preview audio；真实逐句播放前必须另行完成本地媒体派生资产基础设施 active plan。
- 2026-05-23：用户明确要求“按照该方案的内容立即进行实施，直至方案内容完整落地”。任务状态从 `Draft` 调整为 `User Approved`，进入 TDD 实施阶段。

## 2. 需求描述

在 AI Provider 设置页中补齐 TTS Provider 的真实配置、测试和可用性状态，使后续“记录详情 / 逐句分析 / 点击播放直接生成或播放音频”具备可靠前提。

当前页面已经有“语音生成模型”分组，但它只保存 `Provider + Base URL + model + API Key 引用方式`，不足以表达真实 TTS Provider 的差异。语音合成至少涉及：

- 音色或 voice id。
- 输出格式和采样率。
- 语速、音量、音高、语调、风格或自然语言 instructions。
- Provider 专属请求路径、鉴权方式、请求体字段和响应体形态。
- 可用性测试结果、配置变更后的重测状态，以及后续播放缓存失效依据。

本方案要把 TTS 配置做成可测试、可扩展、可诊断、可被播放服务消费的能力，而不是在 SwiftUI 表单里添加几个散落字段。

## 3. 网上调研摘要

调研时间：2026-05-23。

调研原则：

- 优先使用官方文档和官方 API reference。
- 对于未找到官方 TTS 端点的 Provider，不反向推断可用；标记为“当前内置预设不提供一手 TTS 支持”或“需用户通过兼容层 / 自定义 Provider 接入”。
- Provider 能力变化很快，实施前必须再次核对官方文档和可用模型列表。

### 3.1 OpenAI

官方 Text to Speech 文档显示，OpenAI Audio Speech endpoint 的核心输入是 `model`、`input` 和 `voice`，示例使用 `gpt-4o-mini-tts`、`voice: coral`，并支持通过 `instructions` 控制语气、语速、语调等表达。官方还列出多种内置 voices，并说明默认输出 MP3，支持 `mp3`、`opus`、`aac`、`flac`、`wav`、`pcm` 等输出格式。

来源：https://developers.openai.com/api/docs/guides/text-to-speech

对 LangoTrace 的含义：

- 现有 `openAI.defaultSpeechModel = "gpt-4o-mini-tts"` 方向正确。
- 当前缺少 `voice`、`instructions`、`response_format` 和可解码音频 probe。
- OpenAI 应作为第一批真实 TTS Provider。

### 3.2 Google Gemini

Gemini API 官方 Speech generation 文档显示，Gemini 可通过 `generateContent` 进行 TTS，要求使用带 TTS 能力的 Gemini 模型变体，设置 response modality 为 `AUDIO`，并通过 `SpeechConfig` / `VoiceConfig` / `PrebuiltVoiceConfig` 选择 voice。官方说明 Gemini TTS 可用自然语言控制 style、accent、pace 和 tone，且当前能力处于 Preview。

来源：https://ai.google.dev/gemini-api/docs/speech-generation

对 LangoTrace 的含义：

- 当前代码把 Gemini `speechSynthesis` 标为 `.unsupported` 已经落后于官方能力。
- Gemini 不是 OpenAI `/audio/speech` 兼容路径，不能复用当前 `openAICompatibleChat` adapter。
- Gemini TTS 后续可列入 `modelDependent`，并在 UI 文案中标记 Preview 风险；不要在当前代码尚未定义的情况下直接写入 `supportedButPreview` 状态。

### 3.3 Groq

Groq 官方 Text to Speech 文档显示 `POST https://api.groq.com/openai/v1/audio/speech` 可生成音频，核心输入为 `model`、`input`、`voice` 和 `response_format`，当前文档列出的模型包括 `canopylabs/orpheus-v1-english` 和 `canopylabs/orpheus-arabic-saudi`，示例 voice 包括 `troy`、`hannah`、`austin` 等。Groq 文档将 vocal direction 写入输入文本，例如用方括号表达情绪方向；当前文档没有把 `sample_rate` 或 `speed` 列为该 endpoint 的核心参数。

来源：https://console.groq.com/docs/text-to-speech

对 LangoTrace 的含义：

- 当前 `groq` 预设属于 OpenAI-compatible text，但 TTS 也使用 OpenAI 风格的 Audio Speech endpoint。
- 不能继续把 Groq 的 TTS 能力固定为 false。
- 第一版应按 Groq 当前文档只支持 `model`、`input`、`voice`、`response_format`；不要在 Groq adapter 中写入未确认的 `sample_rate` 或 `speed`。
- Groq 的 vocal direction 属于输入文本风格控制，设置页不应默认把用户配置的风格标签拼进所有学习句子；如需支持，应作为后续高级功能单独审查。

### 3.4 Mistral

Mistral 官方 Text to Speech / Speech Generation 文档显示 Voxtral TTS 支持通过 `audio.speech.complete` 或 `/v1/audio/speech` 生成语音，字段包括 `model`、`input`、`voice_id` 或一次性 `ref_audio`、`response_format`，支持 basic 和 streaming，返回 `audio_data` base64 或 stream events。官方建议输入文本避免 Markdown、emoji 和特殊字符，短提示更稳定。

来源：https://docs.mistral.ai/studio-api/audio/text_to_speech/speech

对 LangoTrace 的含义：

- 当前 `mistral` 预设被当作 OpenAI-compatible text，TTS 能力实际需要 Mistral 专属 `voice_id/ref_audio` 语义。
- 第一版应只支持 saved voice id，不支持上传 reference audio 和克隆流程。
- Mistral 可列入第一批或第二批，取决于是否愿意同时处理 base64 响应体。

### 3.5 xAI

xAI 官方 Text to Speech 文档显示 `POST https://api.x.ai/v1/tts` 使用 `text`、`voice_id`、`language` 生成语音，响应体为 raw audio bytes。文档还提供 voices 列表接口，并说明支持 inline speech tags、输出格式选择、缓存建议、错误码和 WebSocket streaming。

来源：https://docs.x.ai/developers/model-capabilities/audio/text-to-speech

对 LangoTrace 的含义：

- 当前 `xAI` 预设作为 OpenAI-compatible text 处理，不足以表达 `/v1/tts`。
- xAI 字段不是 `input` / `voice`，而是 `text` / `voice_id` / `language`。
- 第一版应只做 unary request，不做 WebSocket streaming。

### 3.6 OpenRouter

OpenRouter 官方 TTS 文档显示其支持专用 `/api/v1/audio/speech` endpoint，并兼容 OpenAI Audio Speech API。模型可以通过 Models API 使用 `output_modalities=speech` 发现；请求字段包括 `model`、`input`、`voice` 和 `responseFormat` / `response_format`，响应是 raw audio byte stream。

来源：https://openrouter.ai/docs/features/multimodal/tts

对 LangoTrace 的含义：

- 当前代码把 OpenRouter `speechSynthesis` 设为 `.modelDependent` 是合理的，但需要真实 TTS adapter 和模型发现 / 手动模型能力声明。
- OpenRouter 不应硬编码某个 voice 列表，应该允许用户输入或从模型能力读取可用项。
- OpenRouter 是聚合 Provider，测试成功只代表当前模型、voice 和路由可用，不代表 OpenRouter 全局 TTS 可用。

### 3.7 DashScope / Qwen / 阿里云百炼

阿里云百炼官方 CosyVoice 文档显示 TTS 支持模型和音色绑定，`model` 与 `voice` 不能混用；参数包括 `format`、`sample_rate`、`volume`、`rate`、`pitch`、`enable_ssml`、`word_timestamp_enabled` 等。文档列出 CosyVoice / Sambert / MiniMax 等模型路线，也说明支持中英等多语种、声音复刻、声音设计、流式输入输出和多种音频格式。

来源：

- https://help.aliyun.com/zh/model-studio/cosyvoice-ios-sdk
- https://help.aliyun.com/zh/model-studio/speech-synthesis/
- https://help.aliyun.com/zh/model-studio/cosyvoice-voice-list

对 LangoTrace 的含义：

- 当前 `dashScopeQwen` 预设使用 OpenAI-compatible text endpoint，仅适合文本模型；TTS 需要 DashScope / CosyVoice 专属 adapter。
- 需要强制校验 `model + voice` 配对。
- 需要支持 `rate`、`pitch`、`volume`、`format`、`sample_rate`。
- 第一版不做声音复刻 / 声音设计，只支持系统音色或用户已创建的 voice id。

### 3.8 Zhipu GLM

智谱官方 GLM-TTS 文档显示 `POST https://open.bigmodel.cn/api/paas/v4/audio/speech` 使用 `model: glm-tts`、`input`、`voice`、`response_format`，支持系统音色和复刻音色，并提供 `watermark_enabled`、`stream`、`speed`、`volume` 等参数。智谱也有 GLM-4-Voice / GLM-Realtime 等端到端语音模型，但它们不是本方案第一版的单句 TTS 主路径。

来源：https://docs.bigmodel.cn/api-reference/%E6%A8%A1%E5%9E%8B-api/%E6%96%87%E6%9C%AC%E8%BD%AC%E8%AF%AD%E9%9F%B3

对 LangoTrace 的含义：

- 当前 `zhipuGLM` 预设被当作 OpenAI-compatible text 处理，TTS 需要 `glm-tts` 专属 endpoint。
- 第一版应只支持 `glm-tts` 文本转语音，不接入 GLM-4-Voice 对话式音频输出。
- 智谱的水印参数涉及合规披露，应默认遵循 Provider 默认策略，不在第一版提供关闭入口。

### 3.9 SiliconFlow

SiliconFlow 官方 Create Speech 文档显示 `POST /v1/audio/speech` 可生成二进制音频，字段包含 `model`、`input`、`voice`、`response_format`、`stream`、`sample_rate`、`speed`、`gain`。文档列出 `fnlp/MOSS-TTSD-v0.5` 等模型和一组 voice 枚举，响应 `application/audio`。

来源：https://docs.siliconflow.cn/en/api-reference/audio/create-speech

对 LangoTrace 的含义：

- 当前 `siliconFlow` 预设仅按 OpenAI-compatible text 看待，需要补 TTS adapter。
- 需要支持 `speed`、`gain`、`sample_rate`，并处理 streamed / non-streamed 两种响应。
- 第一版建议固定 non-streamed request，播放体验后续再考虑流式。

### 3.10 Kimi / Moonshot

Kimi 官方帮助中心明确说明 Kimi API 当前不支持 TTS 或 ASR，语音相关能力建议结合第三方语音服务。

来源：https://www.kimi.com/help/kimi-api/api-model-capabilities

对 LangoTrace 的含义：

- 当前 `moonshotKimi` 预设应保持 `speechSynthesis: .unsupported`。
- 不应因为 Kimi web 或研究项目出现音频能力就把 API 预设标为 TTS 可用。

### 3.11 Anthropic

Anthropic 官方 API 文档当前主要是 Messages API，输入消息支持 text / image 等 content block，响应是 JSON Message object。官方 API overview 说明请求和响应体均为 JSON；未找到一手 Text-to-Speech endpoint。

来源：

- https://docs.anthropic.com/en/api/overview
- https://docs.anthropic.com/en/api/messages

对 LangoTrace 的含义：

- `anthropic` 预设应保持 `speechSynthesis: .unsupported`。
- 若用户想用 Claude 生成朗读稿，再用第三方 TTS 播放，应通过另一个 TTS Provider 配置完成，不混在 Anthropic endpoint 里。

### 3.12 DeepSeek

DeepSeek 官方 API 文档当前展示的是 OpenAI / Anthropic 兼容的文本 Chat API、模型与价格、JSON Output、Tool Calls、FIM 等文本能力；未找到官方 TTS endpoint 或音频输出模型。

来源：

- https://api-docs.deepseek.com/
- https://api-docs.deepseek.com/quick_start/pricing/

对 LangoTrace 的含义：

- `deepSeek` 预设应保持 `speechSynthesis: .unsupported`。
- DeepSeek 可以作为学习内容生成 Provider，但不作为语音生成 Provider。

### 3.13 Ollama Local

Ollama 官方 API 文档主要提供本地模型 generate / chat / embeddings 等文本接口，默认 base URL 为 `http://localhost:11434/api`；未找到官方一手 TTS endpoint。

来源：https://docs.ollama.com/api

对 LangoTrace 的含义：

- `ollamaLocal` 预设应保持 `speechSynthesis: .unsupported`。
- 未来若接本地 Piper / Kokoro / Coqui / Apple system voice，应作为独立 Local TTS Provider，不伪装成 Ollama endpoint。

## 4. 当前代码现状

### 4.1 已有能力

- `AIProviderPreset` 已包含内置 Provider：OpenAI、Anthropic、Gemini、DeepSeek、Mistral、Groq、xAI、Moonshot / Kimi、OpenRouter、DashScope / Qwen、Zhipu GLM、SiliconFlow、Ollama / Local、Custom OpenAI-compatible。
- `AIProviderEndpointPurpose` 已包含 `.tts`。
- AI Provider 设置页已展示可选 `speechModel` 分组。
- `AIOptionalModelDraftConfiguration` 可保存 speech endpoint 的 Provider、Base URL、model 和凭证引用。
- `AIProviderDraftConfiguration.makeProfileSaveInput()` 已能在 speech enabled 时保存 `.tts` endpoint。
- `AIProviderProbeCapability` 已有 `.speechSynthesis`，结果面板也能展示语音生成占位状态。
- `AIProviderConfigurationService` 在缺少配置或占位能力结果中能返回 speech synthesis 的 `notEnabled` / placeholder 状态。

### 4.2 明确缺口

- `AIProviderEndpointConfiguration` 只有通用 endpoint 字段，没有 voice、output format、sample rate、speed、pitch、volume、style、instructions 或 Provider 专属参数。
- `AIProviderAdapterKind` 只有 text/chat 类 adapter：`openAIResponses`、`openAICompatibleChat`、`anthropicMessages`、`geminiGenerateContent`，没有 TTS adapter。
- `AIProviderAdapterCapabilityPolicy.canProbeSpeechSynthesis` 当前全部是 false。
- `AIProviderConfigurationProbeService` 当前只运行 text / JSON / language / image probe，不发送真实 TTS 请求。
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/SpeechBoundary.swift` 当前只有空 `SpeechService` 和 `DisabledSpeechService`。
- `AppDatabase.createAIProviderEndpoints` 的 `ai_provider_endpoints` 表无法保存 TTS 运行参数。
- 现有 capability policy 与官方最新 TTS 能力不一致：Gemini、Mistral、Groq、xAI、OpenRouter、DashScope、Zhipu、SiliconFlow 已有官方或官方平台 TTS 能力，但代码多数仍标为不支持或只做文本兼容。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 中旧的“若使用外部 TTS Provider，必须进入 Provider 请求预览”规则已经在 2026-05-23 修订为引用 `011` 的低摩擦单句 TTS 边界；后续代码实施不得重新引入逐次请求预览，也不得把该低摩擦边界扩展到照片、音频、OCR、历史记忆、多条 Entry 上下文或批量预生成。

## 5. 目标

1. 在设置页建立可用于真实播放前置的 TTS 配置模型。
2. 为内置 Provider 建立准确的 TTS 能力矩阵和 adapter 映射。
3. 提供真实 TTS 配置测试，验证 endpoint、凭证、模型、voice、请求参数、响应 Content-Type、音频字节可解码性和错误分类。
4. 将测试结果写入非敏感 validation event，并能区分未配置、未测试、测试通过、测试失败、配置变更需重测。
5. 形成 `LangoTraceSpeech` 后续生成 / 缓存 / 播放服务可消费的稳定配置 contract。
6. 更新隐私规范：设置页完成披露和测试后，学习页中用户显式点击单句播放可以直接发起 TTS 请求，不需要逐次请求预览；页面展示、滚动、进入详情、批量预生成仍不得自动发送文本。

## 6. 范围

本任务包含：

- TTS Provider 能力矩阵。
- TTS 配置数据模型。
- TTS 配置 UI 字段与动态显示策略。
- TTS adapter contract。
- TTS 配置测试服务。
- TTS 测试结果 UI 和结果面板更新。
- 非敏感 validation event / diagnostic event 规则。
- 数据库存储变更方案。
- 文档规范更新。
- 单元测试与验证路径。

本任务不包含：

- 记录详情中的逐句播放按钮改造。
- 音频缓存表、缓存文件管理和播放协调器。
- 录音、跟读评分、听写、ASR、Speech Recognition。
- 声音克隆、上传参考音频、声音设计或自定义 voice 创建。
- WebSocket streaming TTS 播放。
- 批量预生成整篇记录音频。
- 本地 Apple `AVSpeechSynthesizer` 兜底朗读。
- 付费额度、用量统计和成本预算 UI。

## 7. Provider 支持矩阵

| Provider preset | 当前代码 TTS 判断 | 官方调研结论 | 第一版策略 |
| --- | --- | --- | --- |
| OpenAI | supported | 官方 Audio Speech 支持 `model/input/voice/instructions/format` | 第一批支持 |
| Anthropic | unsupported | 未找到官方 TTS endpoint | 保持不支持 |
| Gemini | unsupported | 官方 Gemini TTS Preview，`generateContent + AUDIO + SpeechConfig` | 后续支持，先不开放第一批真实测试 |
| DeepSeek | unsupported | 官方文档仅文本 Chat / 兼容 API | 保持不支持 |
| Mistral | unsupported | 官方 Voxtral TTS，`voice_id/ref_audio/response_format` | 第二批支持，第一版只 saved voice |
| Groq | unsupported | 官方 OpenAI 风格 `/audio/speech`，Orpheus TTS | OpenAI 路径稳定后的同构扩展 |
| xAI | unsupported | 官方 `/v1/tts`，`text/voice_id/language` | 第二批支持 |
| Moonshot / Kimi | unsupported | 官方 FAQ 明确不支持 TTS / ASR | 保持不支持 |
| OpenRouter | modelDependent | 官方 `/api/v1/audio/speech`，模型按 `output_modalities=speech` 发现 | 第一阶段支持，model-dependent |
| DashScope / Qwen | unsupported | 官方 CosyVoice / Sambert TTS，模型与音色绑定 | 第二批支持 |
| Zhipu GLM | unsupported | 官方 GLM-TTS `/audio/speech` | 第二批支持 |
| SiliconFlow | unsupported | 官方 `/v1/audio/speech`，MOSS-TTSD / CosyVoice | 第二批支持 |
| Ollama / Local | unsupported | 官方 API 未提供 TTS endpoint | 保持不支持 |
| Custom OpenAI-compatible | modelDependent | 取决于是否实现 OpenAI Audio Speech 兼容 endpoint | 后续同构扩展；第一阶段不开放真实 TTS probe |

第一阶段建议分成两个实施切片：

1. 最小可用切片：OpenAI。原因是当前代码已有 `defaultSpeechModel = "gpt-4o-mini-tts"`，官方字段稳定，最适合先打通配置、测试、结果面板、状态持久化和后续逐句播放前置接口。
2. 第一阶段第二切片：OpenRouter。原因是用户明确要求前期支持 OpenRouter，且 OpenRouter 的 TTS endpoint 兼容 OpenAI Audio Speech 形态，但它是聚合 Provider，必须保持 model-dependent 能力语义，要求用户选择或输入支持 speech output modality 的模型和 voice，并以真实测试结果作为唯一可用依据。

同构扩展门槛：Groq、Custom OpenAI-compatible。它们接近 OpenAI Audio Speech 请求形态，但仍有不同模型、voice、格式和兼容风险；只有 OpenAI + OpenRouter 的服务边界、Data 事务和结果模型稳定后才进入后续子阶段。第一阶段不得把 Custom OpenAI-compatible 暴露为可真实测试的 TTS Provider，避免高级 path override、任意兼容服务和 Provider 参数 allowlist 在最小闭环前扩大风险面。

第二批建议：Gemini、Mistral、xAI、DashScope、Zhipu、SiliconFlow。原因是它们需要专属请求体、响应体或更复杂的 voice / format / streaming 语义。

## 8. 架构决策

### 8.1 不把所有 TTS 参数塞进 `AIProviderEndpointConfiguration`

`AIProviderEndpointConfiguration` 当前是通用 endpoint 元数据，适合保存 Provider、Base URL、模型、凭证和 purpose。TTS 参数既多又强 Provider 相关，直接把 `voice_id`、`pitch`、`sample_rate`、`instructions` 全部加到 endpoint 主表，会让 embedding、text generation 和未来 OCR / ASR endpoint 被污染。

决策：

- 保留 `ai_provider_endpoints` 作为 endpoint 主表。
- 新增 TTS 专属配置表或等价 repository 模型，例如 `ai_provider_tts_settings`。
- 通过 `endpoint_id` 一对一关联 `.tts` endpoint。
- 第一阶段不把真实 TTS adapter case 强塞进当前 `AIProviderAdapterKind`。现有 `AIProviderAdapterKind` 是 text/chat request adapter，继续作为 endpoint 连接层历史字段；`.tts` endpoint 的真实请求 adapter 以 `ai_provider_tts_settings.tts_adapter_kind` / `TTSProviderAdapterKind` 为事实源。
- 如果实现时选择直接扩展 `AIProviderAdapterKind` 加入 TTS cases，必须同步迁移 UI 本地同名 enum、Core raw value、Data 迁移、adapter capability policy 和所有保存 / 加载测试；不得让 endpoint 的 `adapter_kind` 与 TTS settings 的 `tts_adapter_kind` 同时表达不同事实。

### 8.2 标准字段 + Provider 专属 allowlist

TTS 配置模型分两层：

标准字段：

- `endpointID`
- `providerPresetID`
- `adapterKind`
- `modelName`
- `voiceID`
- `voiceDisplayName`
- `outputFormat`
- `sampleRate`
- `speed`
- `volume`
- `pitch`
- `stylePrompt`
- `instructions`
- `streamingMode`
- `configurationFingerprint`
- `lastTestedAt`
- `lastTestStatus`

Provider 专属字段：

- 只能保存 adapter 定义的 allowlist key。
- 不允许任意 UI 字符串直接写入请求体。
- 不允许保存 secret、完整 header、完整请求体、完整响应体或用户测试文本。

建议第一版 Provider 专属 key：

| Adapter | allowlist key |
| --- | --- |
| OpenAI Audio Speech | `instructions`, `response_format` |
| Groq Audio Speech | `response_format` |
| OpenRouter Audio Speech | `response_format`, `provider_options` |
| Custom OpenAI-compatible Audio Speech | `response_format`, `path_override` |
| Gemini TTS | `voice_name`, `style_prompt` |
| Mistral Audio Speech | `voice_id`, `response_format` |
| xAI TTS | `voice_id`, `language`, `output_format` |
| DashScope CosyVoice | `format`, `sample_rate`, `rate`, `pitch`, `volume`, `enable_ssml` |
| Zhipu GLM-TTS | `voice`, `response_format`, `speed`, `volume`, `stream` |
| SiliconFlow Audio Speech | `response_format`, `sample_rate`, `speed`, `gain`, `stream` |

第一阶段必须实现的 adapter allowlist：

- OpenAI Audio Speech：`instructions`、`response_format`。
- OpenRouter Audio Speech：`response_format`、`provider_options`。`provider_options` 必须是强类型或 allowlisted JSON value，不允许用户直接输入任意请求体片段。

OpenRouter 特别约束：

- OpenRouter 的 `model` 必须由用户手动填写或由后续模型发现能力选择；当前第一阶段不要求接入 Models API。
- UI 必须明确提示 OpenRouter 是聚合 Provider，测试通过只代表当前 model + voice + route 可用。
- OpenRouter 的 voice 不使用 OpenAI 内置 voice 列表硬编码，第一阶段允许用户输入 voice id / voice name，并以测试结果作为可用性依据。

### 8.3 Voice 是必填能力，不是高级项

几乎所有外部 TTS Provider 都需要 voice / voice id / voice name。即使 OpenAI 有默认 voice，用户也需要知道自己选择了什么音色；后续音频缓存 key 也必须包含 voice。

决策：

- TTS 启用后，`voiceID` 是配置完整性的必填字段。
- Provider 有内置 voice 列表时，UI 使用 Picker。
- Provider 没有稳定列表或通过 API 动态发现时，第一版允许用户输入 voice id，并在测试失败时给出错误分类。
- 不做 voice preview 列表批量加载；只做当前配置的“测试语音”。
- 对多语言空间，voice 不应只作为 `.tts` endpoint 的单个全局字段。一个 Provider profile 可能服务英语、日语、韩语等多个目标语言空间；voice、style、speed 和测试状态应支持按目标语言 code 形成覆盖配置，否则切换语言空间时会互相覆盖。

### 8.4 测试成功是播放前置，不是保存成功

保存配置只说明字段进入本机配置库和 Keychain。真实播放必须依赖 TTS probe 成功状态。

决策：

- `.tts` endpoint 保存后默认 `notRun` 或 `requiresRetest`。
- 用户点击“测试语音”成功后，状态变为 `succeeded`。
- 任一影响请求或音频输出的字段变化后，状态变为 `requiresRetest`。
- 后续逐句播放只接受 `succeeded` 且配置 fingerprint 未变化的 TTS 配置。
- TTS 是可选能力。TTS 测试失败不得把文本模型 profile 全局 `last_validation_status` 覆盖为 failed；它只能更新 TTS endpoint / voice profile 的测试摘要和对应 validation event。

### 8.5 配置测试不使用用户生活记录

TTS 配置测试只验证 Provider 能力，不验证真实学习内容。

决策：

- 使用固定低敏测试句。
- 测试句按目标语言 code 选择，例如英语空间用 `Today I wrote one short sentence for practice.`，中文界面仍不发送用户生活内容。
- 测试句不写入 validation event、diagnostic event 或日志。
- 测试结果面板只展示非敏感元数据：Provider、model、voice、format、duration、status、error category。

### 8.6 Provider 能力状态必须能表达 Preview 和后续支持

现有 `AIProviderCapabilitySupport` 只有 `supported`、`unsupported`、`modelDependent`、`adapterUnsupported`。方案中提到的 `supportedButPreview` 或“后续支持状态”在当前代码不存在，不能直接写进测试或 UI。

决策：

- 第一版不新增 `supportedButPreview`，避免把能力矩阵和 UI 状态一次性扩得过大。
- Gemini、Mistral、xAI、DashScope、Zhipu 和 SiliconFlow 在本任务第一阶段只记录为 `modelDependent` 或 `unsupported` 加说明，不开放真实测试入口。
- 如果后续需要 Preview 语义，应新增明确 enum case、文案、测试和结果面板状态，而不是只在文档里写“Preview”。

### 8.7 Probe result 需要从单 endpoint 结果演进为分 endpoint 结果

当前 `AIProviderConfigurationProbeResult` 只有一个 `providerPresetID` 和 `modelName`。这适合只测试 text endpoint，但不适合同时展示文本、图片、语言支持、语音生成和向量化，因为这些能力可能来自不同 endpoint、不同 Provider、不同模型和不同凭证。

决策：

- 不把 TTS 真实结果硬塞进现有单 model result。
- 在 Core 中为 capability result 增加可选 endpoint metadata，至少包含 `endpointID`、`endpointPurpose`、`providerPresetID`、`modelName` 和 `configurationFingerprint`。
- 或者新增 profile-level probe result，例如 `AIProviderProfileProbeResult`，内部由多个 `AIProviderEndpointProbeResult` 组成。
- 结果面板继续是单一入口，但每个 capability row 必须知道自己的 endpoint / model / Provider，不能复用 text endpoint 的 model 名。

### 8.8 模块归属：AI 负责 Provider 请求，Speech 负责音频语义

当前 `LangoTraceAI` 已负责 Provider 配置、Keychain secret 解析后的请求测试、HTTP client 和 validation event；`LangoTraceSpeech` 当前只有空 `SpeechService`。TTS 横跨两类职责：外部 Provider 网络请求属于 AI / Provider 层，音频解码、试听、后续播放、播放状态和音频 session 属于 Speech 层。

决策：

- TTS 配置保存、Provider adapter request building、HTTP 请求和 validation event 由 `LangoTraceAI` 承担，复用现有 `AIProviderConfigurationService` / `AIProviderSettingsActions` seam。
- `LangoTraceAI` 不得直接 import 或依赖 `LangoTraceSpeech`。现有模块边界是 `AI -> Core`、`Speech -> Core`，App Shell 负责装配 Data / AI / Speech；TTS probe 不能为了调用音频解码而让 AI package 反向依赖 Speech package。
- 必须在 Core 中定义 `TTSAudioValidationService`、`TTSAudioValidationResult` 或等价协议 / value type，由 `LangoTraceSpeech` 提供 AVFoundation / 平台音频实现，再通过 `AppEnvironment` 注入 `AIProviderConfigurationService` 或 `TTSConfigurationProbeService`。这样 AI 层只知道 Core 协议和音频元数据，不知道 Speech concrete 实现。
- AI adapter 可以先做 HTTP status、Content-Type、byte count、格式声明和大小上限等响应前置检查，但这些检查不能替代音频验收。TTS probe 成功必须经过 Speech 音频校验 seam；不能把“收到非空音频 bytes”当作可试听或可播放前置。
- 音频 bytes 的可解码性校验、设置页样例试听、试听临时资源、后续播放服务 contract 由 `LangoTraceSpeech` 承担；具体实现通过 Core 协议和 AppEnvironment 注入给 TTS probe 或后续播放服务。
- `LangoTraceSpeech/Package.swift` 当前没有 test target；本任务必须新增 `LangoTraceSpeechTests`，并覆盖音频校验、错误归一化和 preview audio 不落持久缓存目录的边界。

### 8.9 设置页保持单一主测试入口

现有 AI Provider 设置页的交互资产是一个 `测试请求` 主按钮和一个分能力结果面板。用户此前也要求不要把每个能力拆成多个主按钮。

决策：

- 主路径仍保留一个 `测试请求` 或等价主按钮。
- 当 speech endpoint 启用且 TTS 配置完整时，该测试请求在结果面板中包含 `语音生成` 的真实 probe row。
- `测试语音` 可以作为语音分组内的次级试听动作，但不能替代全局测试请求，也不能创建另一套独立结果状态。
- 结果面板中的 `语音生成` 成功 row 可以提供试听样例音频入口；试听播放状态属于 transient UI / Speech service，不写入 profile 验证摘要。

### 8.10 多语言 voice profile 是播放前置的一部分

LangoTrace 的核心产品模型是一个语言空间对应一门目标语言。用户可能同时有英语、日语和韩语空间，TTS voice 通常与目标语言强相关。

决策：

- `.tts` endpoint 保存 Provider、Base URL、模型、凭证和 adapter。
- 新增 `tts_voice_profiles` 或等价模型，使用 `endpoint_id + language_code` 做唯一键，保存 voice、format、speed、style、fingerprint 和测试状态。
- 若第一版只支持当前语言空间，也必须把唯一键设计成可扩展的 `endpoint_id + language_code`，不能用 `endpoint_id` 单行长期绑定 voice。
- 后续逐句播放调用 `loadDefaultPlayableTTSConfiguration(languageCode:)` 时，必须命中对应 language code 的已测试 voice profile；没有命中时返回 `.notConfigured` 或 `.notTested`。

## 9. 推荐数据模型

### 9.1 Core 类型

建议在 `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift` 或独立 `TTSProviderConfiguration.swift` 中新增：

```swift
public enum TTSProviderAdapterKind: String, Codable, CaseIterable, Sendable {
    case openAIAudioSpeech = "openai_audio_speech"
    case groqAudioSpeech = "groq_audio_speech"
    case openRouterAudioSpeech = "openrouter_audio_speech"
    case customOpenAICompatibleAudioSpeech = "custom_openai_compatible_audio_speech"
    case geminiGenerateContentTTS = "gemini_generate_content_tts"
    case mistralAudioSpeech = "mistral_audio_speech"
    case xAITTS = "xai_tts"
    case dashScopeCosyVoice = "dashscope_cosyvoice"
    case zhipuGLMTTS = "zhipu_glm_tts"
    case siliconFlowAudioSpeech = "siliconflow_audio_speech"
}

public enum TTSAudioFormat: String, Codable, CaseIterable, Sendable {
    case mp3
    case wav
    case pcm
    case opus
    case flac
    case aac
    case mulaw
}

public enum TTSConfigurationStatus: String, Codable, CaseIterable, Sendable {
    case notConfigured = "not_configured"
    case notTested = "not_tested"
    case testing
    case succeeded
    case failed
    case requiresRetest = "requires_retest"
    case unsupported
}

public struct TTSProviderSettings: Equatable, Sendable {
    public var endpointID: AIProviderEndpointID
    public var adapterKind: TTSProviderAdapterKind
}

public struct TTSVoiceProfile: Equatable, Sendable {
    public var id: String
    public var endpointID: AIProviderEndpointID
    public var languageCode: String
    public var voiceID: String
    public var voiceDisplayName: String?
    public var outputFormat: TTSAudioFormat
    public var sampleRate: Int?
    public var speed: Double?
    public var volume: Double?
    public var pitch: Double?
    public var stylePrompt: String?
    public var instructions: String?
    public var streamingMode: Bool
    public var providerParameters: [String: String]
    public var configurationFingerprint: String
    public var lastSuccessfulConfigurationFingerprint: String?
    public var lastTestStatus: TTSConfigurationStatus
    public var lastTestedAt: Date?
}
```

说明：

- `TTSProviderSettings` 只保存 endpoint 级 adapter 选择，不保存语言相关 voice。
- `TTSProviderSettings.adapterKind` 是真实 TTS request adapter 的事实源。第一阶段 `.tts` endpoint 上的 `AIProviderEndpointConfiguration.adapterKind` 只能作为连接层兼容字段存在，不能被 TTS request builder 当作真实语音 adapter 使用，除非本任务同步完成 `AIProviderAdapterKind` 的 TTS case 扩展和迁移。
- `TTSVoiceProfile` 保存目标语言相关的 voice、format、style 和测试状态。
- `providerParameters` 只能包含 adapter allowlist key，不能作为无限扩展口。
- `providerParameters` 的生产代码不应是 `[String: String]`。方案中的代码片段只是结构示意；实际实现应使用 typed JSON value 或强类型枚举，确保数值、布尔和字符串不会被统一降级成字符串后再临时解析。
- `configurationFingerprint` 由非敏感、影响输出的字段稳定计算，表达当前配置值。
- `lastSuccessfulConfigurationFingerprint` 保存最近一次 TTS probe 成功时的 fingerprint。判断 `available` 时必须比较当前 fingerprint 与最近成功 fingerprint；只保存一个 fingerprint 会把当前配置和已验证配置混在一起，不能作为播放前置依据。
- `languageCode` 来自当前语言空间，不把界面语言误当学习语言。

### 9.2 Data 表

建议新增 endpoint 级设置表：

```sql
CREATE TABLE ai_provider_tts_settings (
    endpoint_id TEXT PRIMARY KEY REFERENCES ai_provider_endpoints(id) ON DELETE CASCADE,
    tts_adapter_kind TEXT NOT NULL,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);
```

建议新增 voice profile 表：

```sql
CREATE TABLE ai_provider_tts_voice_profiles (
    id TEXT PRIMARY KEY,
    endpoint_id TEXT NOT NULL REFERENCES ai_provider_endpoints(id) ON DELETE CASCADE,
    language_code TEXT NOT NULL,
    voice_id TEXT NOT NULL,
    voice_display_name TEXT,
    output_format TEXT NOT NULL,
    sample_rate INTEGER,
    speed REAL,
    volume REAL,
    pitch REAL,
    style_prompt TEXT,
    instructions TEXT,
    streaming_mode BOOLEAN NOT NULL,
    provider_parameters_json TEXT NOT NULL,
    configuration_fingerprint TEXT NOT NULL,
    last_successful_configuration_fingerprint TEXT,
    last_test_status TEXT NOT NULL,
    last_tested_at REAL,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL,
    UNIQUE(endpoint_id, language_code)
);
```

约束：

- `voice_id`、`instructions`、`style_prompt` 属于非 secret，但可能包含用户偏好，不进入诊断日志和同步目录。
- `provider_parameters_json` 必须由 repository 层进行 allowlist 校验。
- `last_test_status` 不替代 `ai_provider_validation_events`，它只是设置页快速读取状态。
- `configuration_fingerprint` 保存当前配置 fingerprint；任一影响输出的字段变更后必须同步更新。
- `last_successful_configuration_fingerprint` 只在 TTS probe 成功后更新；失败、取消或仅保存配置不得更新。`last_test_status = succeeded` 且两个 fingerprint 相等，才允许后续逐句播放判定为 available。
- `ai_provider_endpoints` 删除 / 替换时必须在同一 GRDB write transaction 中重建 TTS settings 和 voice profiles；不能先删除 endpoint 后异步补写 voice profile。

### 9.3 Validation event

`AIProviderValidationEvent` 当前只有 `providerPresetID`、`modelName`、status、error、duration。第一版可以复用 validation event 表记录 TTS synthetic event，但不能复用 `recordValidationOutcome(_:)` 对 profile 全局最近验证摘要的写法。

如果要持久记录更细信息，建议新增非敏感字段前先评估迁移成本；第一版可以只记录：

- event type：`synthetic_test`
- endpoint purpose：`tts`
- capability：`speechSynthesis`
- provider preset
- model name
- status
- error category
- duration

写入规则：

- TTS saved probe 成功或失败可以写 `ai_provider_validation_events`。
- TTS saved probe 只能更新 `ai_provider_tts_voice_profiles.last_test_status`、`last_tested_at` 和 `last_successful_configuration_fingerprint`。
- TTS saved probe 不得调用会覆盖 `ai_provider_profiles.last_validation_status` 的 `recordValidationOutcome(_:)`。
- Repository 必须新增明确的 endpoint / voice-profile scoped API，例如 `recordTTSVoiceProfileProbeOutcome(...)` 或 `recordEndpointValidationEventOnly(...)`。该 API 至少要在同一个 GRDB write transaction 中写入非敏感 `ai_provider_validation_events`，并更新当前 `endpoint_id + language_code` voice profile 的 `last_test_status`、`last_tested_at` 和成功 fingerprint；它不得更新 `ai_provider_profiles.last_validation_status`。
- 只有未来把 `ai_provider_profiles.last_validation_status` 重构为 endpoint / capability aware 摘要后，才允许通过同名或替代 API 写 profile-level summary；第一阶段不得借用现有全局字段表达 TTS 状态。
- 文本模型、语言支持和图片理解的现有验证摘要规则不得被 TTS 失败破坏。

不记录：

- 测试文本。
- 真实句子文本。
- response body。
- audio bytes。
- API Key。
- Authorization header。
- Keychain account。

## 10. Adapter 设计

### 10.1 服务边界

TTS probe 协议归属应保持 UI 无网络、AI 不依赖 Speech concrete package。推荐把输入 / 输出 contract 放在 Core 或 AI 暴露 API 中，把音频校验能力作为 Core 协议注入：

```swift
public protocol TTSConfigurationProbeService: Sendable {
    func probeDraftTTSConfiguration(_ input: TTSDraftProbeInput) async -> TTSProbeResult
    func probeSavedTTSConfiguration(_ input: TTSSavedProbeInput) async -> TTSProbeResult
}
```

输入应包含：

- endpoint input / saved endpoint。
- TTS settings。
- plaintext secret 或 Keychain 解析后的 secret。
- language context。
- operation id。

输出应包含：

- status。
- error category。
- duration。
- audio metadata：format、byte count、duration seconds、sample rate。`duration seconds` / `sample rate` 必须来自 Speech audio validator 的实际解码结果；AI adapter 的 HTTP / Content-Type / byte count 前置检查不能替代音频 metadata 验收。
- 可选 preview audio 临时文件或短生命周期 bytes 引用；该能力必须由 Speech seam 或 AppEnvironment 装配，不由 SwiftUI View 或 AI package 管理长期播放生命周期。设置页 TTS probe 产生的 preview audio 只用于结果面板样例试听，不写入持久媒体资产表，不进入缓存目录，不形成逐句播放可复用音频。

实施约束：

- UI 不直接持有 `TTSConfigurationProbeService`，而是通过 `AIProviderSettingsActions` 进入 App Shell seam。
- `AIProviderSettingsActions.testProviderConfiguration` 当前只接收一个文本 draft snapshot；实施前必须扩展为 profile-level draft snapshot，或新增明确的 TTS draft snapshot 参数。
- 如果结果面板继续使用 `AIProviderConfigurationProbeResult`，必须先扩展 result model 以支持分 endpoint metadata。
- `LangoTraceAI` 可以生成 TTS HTTP request，但不能拥有后续播放状态，也不能直接依赖 `LangoTraceSpeech`。`LangoTraceSpeech` 负责 preview playback / decode helper 或提供可测试的 audio validation seam；AI 侧通过 Core 协议 / AppEnvironment 注入使用该能力。

### 10.2 Adapter 分类

第一阶段 adapter：

1. `OpenAIAudioSpeechAdapter`
   - URL：`{baseURL}/audio/speech`
   - body：`model`、`input`、`voice`、`instructions`、`response_format`
   - response：raw audio bytes

2. `OpenRouterAudioSpeechAdapter`
   - URL：`{baseURL}/audio/speech`
   - body：`model`、`input`、`voice`、`response_format`
   - response：raw audio bytes
   - 能力语义：model-dependent。adapter 只证明 endpoint request / response 形态可执行，不把 OpenRouter 全局标记为 TTS supported。

后续同构扩展 adapter：

1. `GroqAudioSpeechAdapter`
   - URL：`{baseURL}/audio/speech`
   - body：`model`、`input`、`voice`、`response_format`
   - response：raw audio bytes

2. `CustomOpenAICompatibleAudioSpeechAdapter`
   - default path：`/audio/speech`
   - 支持高级 path override，但只在高级设置显示。
   - 不假设 voice 列表，必须测试通过才可用于播放。

第二批 adapter：

1. `GeminiGenerateContentTTSAdapter`
   - URL：Generative Language generateContent endpoint。
   - body：`response_modalities: ["AUDIO"]`、`speech_config.voice_config.prebuilt_voice_config.voice_name`。
   - response：从 Gemini response 中提取音频 bytes。

2. `MistralAudioSpeechAdapter`
   - URL：`{baseURL}/audio/speech`
   - body：`model`、`input`、`voice_id`、`response_format`、`stream: false`
   - response：base64 audio_data 或 raw audio，根据 endpoint 版本固定解析。

3. `XAITTSAdapter`
   - URL：`https://api.x.ai/v1/tts` 或 base URL 拼接 `/tts`
   - body：`text`、`voice_id`、`language`
   - response：raw audio bytes

4. `DashScopeCosyVoiceAdapter`
   - URL：DashScope / Model Studio TTS endpoint。
   - body：`model`、`voice`、`format`、`sample_rate`、`volume`、`rate`、`pitch`。
   - response：HTTP / WebSocket 分支。第一版只实现 HTTP 或非实时模式。

5. `ZhipuGLMTTSAdapter`
   - URL：`{baseURL}/audio/speech`
   - body：`model`、`input`、`voice`、`response_format`、`speed`、`volume`、`stream: false`
   - response：raw string / audio bytes 按官方 API reference 实测固定。

6. `SiliconFlowAudioSpeechAdapter`
   - URL：`{baseURL}/audio/speech`
   - body：`model`、`input`、`voice`、`response_format`、`stream: false`、`sample_rate`、`speed`、`gain`
   - response：`application/audio` binary

## 11. 设置页交互设计

### 11.1 主路径字段

在 AI Provider 设置页中，“语音生成模型”启用后展示：

1. Provider。
2. Base URL。
3. 语音模型。
4. API Key 引用方式。
5. 音色。
6. 输出格式。
7. 语速。
8. 全局测试请求入口中的语音生成能力。
9. 最近测试状态。

首屏不展示所有高级参数。iPhone 上必须避免把设置页变成工程表单。

### 11.2 音色字段

Provider 有稳定内置列表时：

- OpenAI：展示内置 voice 列表，例如 alloy、ash、ballad、coral、echo、fable、nova、onyx、sage、shimmer、verse、marin、cedar。
- Groq：展示当前官方 Orpheus voice 或允许输入 voice id。
- Zhipu：展示 tongtong、chuichui、xiaochen 等系统音色。
- SiliconFlow：展示文档列出的 `fnlp/MOSS-TTSD-v0.5:*` voices。

Provider voice 依赖账户或模型时：

- OpenRouter、Mistral、DashScope、xAI：允许用户输入 voice id，并通过测试确认可用。
- 后续可增加“获取音色列表”按钮，但不是第一版。

第一阶段 OpenRouter 不做模型发现和 voice 列表拉取。它只提供手动填写 model / voice 的路径，并用真实测试结果决定是否可播放。这样符合“用户自带 Provider”的产品定位，也避免把聚合平台的动态模型目录变成 LangoTrace 的硬编码事实。

### 11.3 高级设置

高级设置使用折叠区，不进入首屏主路径：

- `instructions` 或 `stylePrompt`。
- sample rate。
- pitch。
- volume。
- provider-specific switches，例如 DashScope `enable_ssml`、SiliconFlow `gain`。
- path override。

高级字段必须根据 adapter capability 动态显示。对当前 Provider 无效的字段不显示。

### 11.4 测试语音结果

全局“测试请求”包含语音生成能力时：

- 按钮进入 loading。
- 请求成功后，结果面板显示“语音生成：已通过”，并提供试听按钮。
- 请求失败后，显示稳定错误分类，而不是直接展示 Provider 原始错误正文。
- 配置变更后状态显示“需要重新测试”。
- 若保留语音分组内“试听当前语音”按钮，它只能作为次级动作调用同一 TTS probe / preview 能力，不能写另一套持久测试状态。

错误分类建议：

- missingCredential
- credentialInaccessible
- authenticationFailed
- networkUnavailable
- timeout
- providerRejected
- unsupportedEndpointPurpose
- unsupportedModel
- invalidVoice
- unsupportedLanguage
- invalidAudioResponse
- unsupportedAudioFormat
- audioDecodeFailed
- rateLimited
- quotaExceeded

第一阶段必须在 `AIProviderValidationErrorCategory` 中新增稳定 case，至少包含：

- `invalidVoice`
- `unsupportedLanguage`
- `unsupportedAudioFormat`
- `audioDecodeFailed`
- `rateLimited`
- `quotaExceeded`

`invalidAudioResponse` 可继续表示空响应、非音频响应或字节超限等通用音频错误；但 Provider 明确返回 voice 不存在、当前语言不支持、429 限流或 quota 不足时，不应全部折叠为 `providerRejected`。`unsupportedLanguage` 表示当前 `model + voice + route` 明确不支持当前语言空间的 target language；`invalidVoice` 表示 voice 不存在、无权使用或不被当前 model 接受。UI 必须能分别提示“更换支持当前语言的模型或音色”和“检查音色 ID / 权限”。

## 12. 测试请求链路

### 12.1 Draft 测试

未保存配置也可测试当前草稿，但不得写入 Keychain、SQLite 或 validation event。

链路：

1. UI 创建短生命周期 draft。
2. `AIProviderDraftConfiguration` 生成 profile-level draft snapshot，至少包含 text endpoint、tts endpoint、TTS settings、当前语言空间 voice profile 和 requested capabilities。
3. 明文 API Key 只在 UI draft 和 probe input 中短生命周期存在。
4. TTS probe service 发起请求。
5. 结果只写 diagnostic event，不写 profile validation event。
6. 结果面板展示试听入口。

### 12.2 Saved profile 测试

已保存且无修改的配置测试：

1. Service 读取默认 profile。
2. 解析 `.tts` endpoint。
3. 从 Keychain 解析 secret。
4. 读取 endpoint 级 `TTSProviderSettings` 和当前语言 code 对应的 `TTSVoiceProfile`。
5. 发起 TTS probe。
6. 成功后写 `synthetic_test` validation event，并更新 `ai_provider_tts_voice_profiles.last_test_status`、`last_tested_at` 和测试成功 fingerprint。
7. 失败后写非敏感失败 event，并更新 voice profile 状态。
8. 不更新文本模型 profile 的全局最近验证摘要，除非 repository 已提供 endpoint purpose 隔离后的摘要字段。

### 12.3 按目标语言选择固定测试文本

测试文本由本机代码根据当前语言空间的目标语言 code 自动选择，不允许用户生活记录参与。用户点击设置页主测试入口时，TTS probe 必须读取当前 language code，并使用对应语言版本的固定低敏文本进行配音：

- `en`: `Today I wrote one short sentence for practice.`
- `zh-Hans`: `今天我写了一句很短的话。`
- `ja`: `今日は短い文を一つ書きました。`
- `ko`: `오늘 짧은 문장을 하나 썼습니다.`
- fallback：使用英文测试句。

测试文本不进入日志、validation event、diagnostic event 或数据库。

测试结果必须绑定当前 language code 和当前 voice profile：

- 同一个 Provider profile 在英语空间测试成功，不代表日语、韩语或中文空间可用。
- 同一个 `.tts` endpoint 下，每个 `endpoint_id + language_code` 的 voice profile 都必须分别保存测试状态、最近测试时间和最近成功 fingerprint。
- 当前语言空间切换后，如果找不到对应 language code 的成功 voice profile，逐句播放必须返回 `notTested` 或 `requiresRetest`，不得复用其他语言的测试成功状态。
- 如果 Provider 明确返回模型、voice 或路由不支持该语言，第一阶段必须映射为 `unsupportedLanguage`。若 Provider 只返回 voice 不存在、voice 无权使用或 voice 与 model 不兼容，映射为 `invalidVoice`；若 Provider 只表达模型不支持 speech/TTS 能力，映射为 `unsupportedModel`。只有无法稳定归因时，才允许回退到 `providerRejected`，并且 UI 仍应提示用户检查当前语言、模型和音色组合。
- 如果 Provider 返回可解码音频，测试只能证明当前 `model + voice + languageCode + route + configurationFingerprint` 可生成音频；它不能证明发音自然度、口音质量、教学质量或未来路由稳定性。UI 文案和结果面板不得过度承诺。

### 12.4 音频验收

成功标准：

- HTTP 状态成功。
- 响应体非空。
- Content-Type 或响应解析路径符合 adapter 预期。
- 音频字节可被 AVFoundation 或轻量 parser 解码。
- 时长在合理范围，例如 0.2s 到 30s。
- 格式与请求格式一致或在 adapter 允许的兼容格式内。
- 当前 language code 对应的 TTS probe 使用了正确语言版本的固定测试文本。
- 测试结果写回当前 language code 的 voice profile，而不是 endpoint 全局状态。

失败时不得保存 preview audio。

## 13. 与后续逐句播放的 contract

本任务完成后，逐句播放方案可以依赖以下接口语义：

```swift
public protocol TTSConfigurationAvailabilityService: Sendable {
    func loadDefaultPlayableTTSConfiguration(
        languageCode: String
    ) async throws -> PlayableTTSConfigurationStatus
}
```

状态：

- `.available(configuration)`
- `.notConfigured`
- `.notTested`
- `.requiresRetest`
- `.failedLastTest(errorCategory)`
- `.credentialMissing`
- `.unsupportedProvider`

`available` 必须保证：

- endpoint purpose 是 `.tts`。
- TTS settings 存在。
- 当前 language code 对应的 voice profile 存在。
- Keychain secret 可解析或 Provider 不需要 secret。
- 上次测试成功。
- 当前配置 fingerprint 与测试成功时一致。
- Provider adapter 仍在当前版本支持列表中。

## 14. 缓存 key 影响

虽然本任务不实现音频缓存，但必须为后续缓存留出稳定字段。

后续单句音频缓存 key 至少包含：

- entry id 或稳定句子来源。
- sentence index。
- sentence text hash。
- target language code。
- provider profile id。
- endpoint id。
- TTS adapter kind。
- model name。
- voice id。
- output format。
- speed。
- pitch。
- volume。
- instructions / style prompt hash。
- provider parameters hash。
- configuration fingerprint。
- adapter version。

因此本任务的配置模型必须让这些字段可读取，不能把关键参数只存在 UI state 中。

## 15. 隐私与合规边界

### 15.1 设置页披露

设置页必须说明：

- 测试语音会把一条固定测试句发送给所选 TTS Provider。
- 学习页面中用户点击单句播放时，会把该句目标语言文本发送给所选 TTS Provider。
- 不会在页面展示、滚动、进入记录详情或保存记录时自动发送文本。
- API Key 保存在本机 Keychain 或等价安全存储中，默认不同步。
- 生成的语音是 AI 生成语音，不是真人录音。

### 15.2 请求预览规则修订

`docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已在 2026-05-23 修订外部 TTS 请求预览规则。后续实施必须保持以下边界：

- 设置页 TTS 配置、测试和披露完成后，用户在学习页面显式点击单句播放属于低摩擦单句 TTS 请求，不需要逐次请求预览。
- 页面展示、滚动、进入详情、生成学习材料完成、切换句子、批量预生成都不得自动发送 TTS 请求。
- 照片、音频、OCR、历史记忆、多条 Entry 上下文或批量生成不复用该低摩擦边界。

### 15.3 日志禁区

不得记录：

- 测试文本。
- 用户句子文本。
- 完整请求体。
- 完整响应体。
- audio bytes。
- API Key。
- Authorization header。
- Keychain account。
- 自定义敏感 header。

允许记录：

- operation id。
- endpoint purpose。
- capability。
- provider preset。
- model name。
- voice id hash 或非敏感 voice id，具体是否记录明文 voice id 需按 Provider 风险评估。
- output format。
- duration。
- byte size bucket。
- status。
- error category。

## 16. 涉及代码文件

预计修改：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderProbeHTTPClient.swift`
- `Packages/LangoTraceSpeech/Package.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/SpeechBoundary.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `LangoTraceApp/AppEnvironment.swift`

预计新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSProviderConfiguration.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioValidation.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSProviderAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/OpenAIAudioSpeechAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/OpenRouterAudioSpeechAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAudioResponseValidator.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBTTSProviderSettingsRepository.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioValidationService.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/TTSAudioValidationTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/TTSProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/TTSProviderSettingsSection.swift`

后续同构扩展新增：

- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/GroqAudioSpeechAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/CustomOpenAICompatibleAudioSpeechAdapter.swift`

后续第二批新增：

- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/GeminiGenerateContentTTSAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/MistralAudioSpeechAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/XAITTSAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/DashScopeCosyVoiceAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/ZhipuGLMTTSAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAdapters/SiliconFlowAudioSpeechAdapter.swift`

## 17. 测试方案

### 17.1 Core 测试

新增或更新：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/TTSProviderConfigurationTests.swift`

覆盖：

- TTS adapter kind raw value 稳定。
- output format 枚举稳定。
- configuration fingerprint 在 voice / model / speed / instructions 变化时变化。
- last successful configuration fingerprint 只在成功 probe 后更新；保存配置、失败 probe 和取消 probe 不更新。
- 不影响输出的字段不改变 fingerprint。
- provider parameters allowlist 拒绝未知 key。
- `AIProviderValidationErrorCategory` 新增的 TTS 错误 case raw value 稳定。

### 17.2 UI 模型测试

新增或更新：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/TTSProviderSettingsTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`

覆盖：

- OpenAI 默认 TTS 设置包含 `gpt-4o-mini-tts`、默认 voice、默认 format。
- OpenRouter TTS 设置允许手动填写 model / voice，并在 UI 文案中明确 model-dependent。
- Gemini / Mistral / xAI / DashScope / Zhipu / SiliconFlow 第一阶段不开放真实 TTS 测试入口；如展示官方能力说明，也不得显示为当前可用。
- Kimi / DeepSeek / Anthropic / Ollama 不显示可启用 TTS 主路径。
- 配置变更后测试状态变为 `requiresRetest`。
- “测试请求”结果面板包含 speech synthesis 真实状态，不再只是 placeholder。
- 设置页仍只有一个主测试入口；不得新增多个能力级主按钮。

### 17.3 AI package 测试

新增：

- `Packages/LangoTraceAI/Tests/LangoTraceAITests/TTSConfigurationProbeServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/TTSAdapterRequestTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/TTSAudioResponseValidatorTests.swift`

覆盖：

- OpenAI adapter 请求路径、headers、body 字段。
- OpenRouter adapter 请求路径、headers、body 字段和 model-dependent 状态。
- OpenRouter adapter 请求路径和 raw audio 响应处理。
- 缺失 credential 返回 missingCredential。
- 401 返回 authenticationFailed。
- 429 返回 rateLimited。
- Provider 明确 voice 不存在或不可用时返回 invalidVoice。
- Provider 明确当前 model / voice / route 不支持当前 language code 时返回 unsupportedLanguage。
- Provider quota 不足时返回 quotaExceeded。
- 非音频 Content-Type 返回 invalidAudioResponse。
- 空 bytes 返回 invalidAudioResponse。
- TTS probe 必须注入 Core `TTSAudioValidationService` 并由 Speech 实现解码；不可解码 bytes 返回 audioDecodeFailed。
- AI package 测试只覆盖 adapter request、Provider 错误映射、非音频 Content-Type、空 bytes、大小上限和格式声明不匹配；不可解码 bytes 必须由 Speech package 测试覆盖，不能在 AI package 中引入 AVFoundation 来满足该用例。
- draft probe 不写 validation event。
- saved probe 成功写 synthetic_test validation event。

后续同构扩展阶段再补充：

- Groq adapter 请求路径和当前官方字段，不能写入未确认的 `sample_rate` 或 `speed`。
- Custom OpenAI-compatible adapter path override 只能走高级 allowlist。

### 17.4 Data 测试

新增：

- `Packages/LangoTraceData/Tests/LangoTraceDataTests/TTSProviderSettingsRepositoryTests.swift`

覆盖：

- `.tts` endpoint 删除时级联删除 settings。
- settings 保存和读取保持字段一致。
- provider parameters JSON 只保存 allowlist key。
- 配置状态更新不影响 text endpoint。
- 数据库迁移后旧 profile 仍可加载，TTS settings 缺失时状态为 `notConfigured`。
- 同一 endpoint 下不同 language code 的 voice profile 互不覆盖。
- 当前 configuration fingerprint 与 last successful configuration fingerprint 不一致时返回 `requiresRetest`。
- 失败和取消的 saved probe 不更新 last successful configuration fingerprint。
- TTS saved probe 不更新 text profile 的全局最近验证摘要。

### 17.5 UI 字符串测试

更新：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LocalizationTests.swift` 或当前等价本地化测试。

覆盖：

- 新增 key 在 `Localizable.xcstrings` 中存在中英双语。
- 主路径使用“语音生成模型”“音色”“语速”“测试语音”等用户可理解词，不把“adapter”“credential”等工程词暴露给普通用户。

### 17.6 Speech package 测试

本任务必须先给 `Packages/LangoTraceSpeech/Package.swift` 添加 test target，再新增：

- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/TTSAudioValidationTests.swift`

覆盖：

- 空 audio bytes 被拒绝。
- 非音频 bytes 被拒绝。
- 支持格式返回稳定 metadata。
- decode failure 不抛底层 AVFoundation 错误字符串给 UI。
- 试听临时资源不进入持久缓存目录。
- 设置页 preview audio 只作为短生命周期资源存在，不写入 `LocalMediaArtifactStore` 或持久音频缓存。

## 18. 实施步骤

### 阶段一：修正能力矩阵与方案基础

1. 先新增 Core / UI / AI 测试锁定 profile-level probe contract：一次主测试可以包含 text endpoint 与 tts endpoint，capability row 必须携带 endpoint metadata，text 与 TTS partial 状态互不覆盖。
2. 新增或扩展 `AIProviderProfileProbeResult` / endpoint metadata result；如果选择兼容扩展 `AIProviderConfigurationProbeResult`，也必须先满足 `docs/spec/011-tts-provider-configuration-and-playback.md` 的 profile-level 语义。
3. 新增 TTS 错误分类 case：`invalidVoice`、`unsupportedLanguage`、`unsupportedAudioFormat`、`audioDecodeFailed`、`rateLimited`、`quotaExceeded`。第一阶段不再允许把明确的语言不支持折叠为 `providerRejected`。
4. 新增测试锁定当前矩阵事实：OpenAI supported，OpenRouter modelDependent 且第一阶段真实 probe，Custom modelDependent 但不开放第一阶段真实 probe，Anthropic / DeepSeek / Kimi / Ollama unsupported，Gemini / Mistral / xAI / DashScope / Zhipu / SiliconFlow 暂不开放第一阶段真实测试入口。
5. 更新 `AIProviderPreset.capabilityPolicy` 和 adapter capability policy，将 OpenAI 和 OpenRouter 纳入第一阶段可真实 probe；OpenRouter 必须保持 model-dependent，不升级为全局 supported。
6. 明确 adapter kind 落点：第一阶段以 `TTSProviderAdapterKind` / `ai_provider_tts_settings.tts_adapter_kind` 作为真实 TTS adapter 事实源；若决定扩展现有 `AIProviderAdapterKind`，必须先完成 raw value、Data migration、UI 本地 enum 映射和 adapter capability policy 测试。
7. 在同一阶段记录 Groq / Custom OpenAI-compatible 的同构扩展意图，但不要求和 OpenAI / OpenRouter 同一次 commit 全部落地；第一阶段 UI 不得显示 Custom OpenAI-compatible 可真实测试 TTS。
8. 保持 Gemini、Mistral、xAI、DashScope、Zhipu、SiliconFlow 的官方能力记录在文档中，但 UI 不出现可用假象；后续支持需新增 adapter 和测试。
9. 更新 UI tests，防止 unsupported Provider 显示可测试 TTS 主路径。
10. 阶段一完成前不得实现 OpenAI / OpenRouter TTS 网络请求；没有 endpoint metadata 的 profile-level result 会导致 TTS row 复用 text endpoint 的 Provider / model，必须先阻断。

### 阶段二：新增 TTS 设置模型和 Data 存储

1. 新增 Core TTS 配置类型。
2. 新增 endpoint 级 TTS settings 和 language code 级 voice profile。
3. 新增 Data 表和 repository。
4. 添加迁移测试。
5. 将 `.tts` endpoint、TTS settings 和当前语言 voice profile 在同一保存事务内处理。
6. 修正 `GRDBAIProviderConfigurationRepository.saveProfile(_:)` 的删除 / 重插入路径，确保 endpoint 替换不会留下孤立 voice profile，也不会因外键顺序导致保存失败。
7. 新增 endpoint / voice-profile scoped validation repository API，例如 `recordTTSVoiceProfileProbeOutcome(...)` 或 `recordEndpointValidationEventOnly(...)`，并用 Data 测试证明该 API 不更新 `ai_provider_profiles.last_validation_status`。

### 阶段三：更新设置 UI

1. 将 `AIOptionalModelDraftConfiguration` 中的 speech 分支替换或扩展为 `TTSProviderDraftConfiguration`。
2. 增加 voice、format、speed 字段。
3. 增加 Provider 动态高级字段。
4. 增加当前语言空间 voice profile 的测试状态展示和“需要重新测试”状态。
5. 将阶段一建立的 profile-level probe snapshot 接入 UI draft，使测试请求能同时携带 text endpoint、tts endpoint、voice profile draft、当前 language code 和对应 transient secret。
6. 保持一个主测试入口和一个结果面板；语音分组内试听只能是次级动作。
7. 保持 iPhone / iPad / macOS 共享同一设置组件。

### 阶段四：实现第一批 TTS probe

1. 新增 `TTSProviderAdapter` 协议。
2. 先实现 OpenAI adapter，打通 request、response、audio metadata、draft / saved profile probe 和结果面板。
3. 新增 Core audio validation 协议、Speech package audio validation / preview seam 和 `LangoTraceSpeechTests`；AVFoundation 解码必须在 Speech 模块实现，并由 AppEnvironment 注入给 TTS probe。AI package 不得直接依赖 Speech package。
4. 复用阶段一建立的 profile-level result，确保 speech synthesis row 使用 TTS endpoint metadata，不复用 text endpoint 的 Provider / model。
5. 在 OpenAI 路径稳定后实现 OpenRouter adapter，并保持 model-dependent 状态和手动 model / voice 配置路径。
6. 接入 draft / saved profile probe。
7. 更新结果面板，语音生成从 placeholder 变成真实结果；成功 row 的试听入口必须通过 Speech seam 播放短生命周期 preview audio，UI 不接触音频 bytes、文件路径、AVFoundation 或 Provider response。
8. OpenAI + OpenRouter 路径验证稳定后，再以独立子阶段接入 Groq、Custom OpenAI-compatible。

### 阶段五：隐私与文档同步

1. 先遵守 `docs/spec/011-tts-provider-configuration-and-playback.md`，它是 TTS Provider 配置、测试、voice profile、隐私披露和逐句播放前置状态的长期规范。
2. 检查 `docs/spec/005-ai-provider-prompt-and-privacy.md` 已修订的 TTS 配置测试边界和后续单句播放边界是否仍与本实现一致；如实现边界改变再更新，而不是重复记录已不存在的旧规则。
3. 检查 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已修订的外部 TTS Provider 请求预览规则是否仍与本实现一致；如实现边界改变再更新，而不是重复记录已不存在的旧规则。
4. 更新 `docs/platform-page-inventory.md`，记录 AI Provider 设置页的 TTS 配置状态。
5. 更新 `docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 中“没有真实 TTS”的旧事实。
6. 后续 Provider、音频缓存、流式播放、本地 TTS、用量估算和音频同步等暂不实施项，实施前必须检查 `docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md`。

### 阶段六：为逐句播放提供配置可用性前置接口

1. 在 `LangoTraceSpeech` 或 AppEnvironment seam 中暴露 TTS 可用性读取接口。
2. 保证后续记录详情播放按钮能判断 `available / notConfigured / requiresRetest / credentialMissing`。
3. 可用性读取必须按 language code 命中 voice profile。
4. 不在本任务中接入记录详情播放 UI。
5. 不在本任务中实现持久 TTS 音频缓存、`LocalMediaArtifactStore`、播放协调器或媒体资产清理。真实逐句播放进入实施前，必须另行创建或完成本地媒体派生资产基础设施 active plan，至少覆盖 `media_artifacts` metadata、Application Support 文件目录、原子写入、解码验证、失效、清理、backup / sync / export policy 和日志禁区。

## 19. 复查方法

代码复查重点：

- SwiftUI View 是否仍不直接创建 `URLRequest`、读取 Keychain、拼接 Authorization header 或解析音频。
- TTS network adapter 是否只在 AI / Provider service 层，音频解码 / 试听 / 播放是否只在 Speech 层或明确的音频 helper 层。
- TTS settings 是否通过 repository 管理，不散落在 UI state。
- 设置页 preview audio 是否只经 Speech seam 短生命周期播放，不写入持久媒体资产或 SwiftUI 私有文件路径。
- Provider 专属参数是否有 allowlist。
- draft probe 是否不写 Keychain / SQLite / validation event。
- saved probe 是否只写非敏感 validation event。
- 配置变更是否稳定触发 `requiresRetest`。
- Provider 矩阵是否与官方资料一致，并在测试中锁定。
- 语音生成失败是否不会污染文本模型的 profile 全局最近验证状态。
- 多语言空间是否不会互相覆盖 voice / 测试状态。
- 本任务是否没有偷做持久音频缓存；若实现逐句播放或缓存，是否已经先完成本地媒体派生资产基础设施方案。

四维切片：

- 并发 / 性能：测试请求要可取消；重复点击测试按钮不得并发写入状态；同一 endpoint + language code 同时只能有一个 active TTS probe；音频 bytes 只短生命周期持有；不做批量 voice 列表拉取。
- 异常边界：明确 401、429、timeout、invalid voice、invalid audio、decode failure、unsupported model、missing credential；Provider 原始错误正文不得直接展示或落日志。
- 状态同步：保存状态、测试状态、配置 fingerprint、validation event、结果面板必须一致；配置变更后不能继续显示可用；语言空间切换后必须读取对应 language code 的 voice profile。
- 数据一致性：`.tts` endpoint、endpoint TTS settings 和 language voice profile 必须同事务写入；Keychain 和 SQLite 失败仍遵守现有补偿规则；删除 profile 时级联清理 TTS settings；TTS optional probe 不覆盖 text profile 全局验证摘要。

## 20. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
```

完整验证：

```bash
scripts/verify.sh
```

文档检查：

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

手动验证：

- iPhone 17：OpenAI TTS 配置保存、测试语音、试听、改 voice 后显示需重测。
- iPhone 17：OpenRouter TTS 手动填写 model / voice 后可保存、测试、试听；测试结果明确标记为当前 model + voice + route 的可用性，不表示 OpenRouter 全局可用。
- iPhone 17：OpenAI 错误 voice / 错误 API Key / 断网时展示稳定错误分类。
- iPad：共享设置页展示同一 TTS 字段语义。
- macOS：设置详情不会横向拉满，测试结果面板可关闭和重试。
- 断网：返回 networkUnavailable。
- 错误 API Key：返回 authenticationFailed。
- 错误 voice：Provider 明确返回 voice 不存在或不可用时返回 invalidVoice；无法稳定识别为 voice 问题时才允许回退到 providerRejected。

## 21. 文档影响检查

本任务涉及 AI Provider、TTS、隐私、诊断、权限说明、设置页和后续记录详情播放前提，必须更新或检查：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/platform-page-inventory.md`
- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md`

若实际实现改变长期 Provider 抽象或隐私授权边界，需要评估是否更新 ADR-005 或新增 ADR。当前方案沿用“用户自带 Provider、本地优先、敏感凭证 Keychain”的既有 ADR，不要求新增 ADR。

## 22. 与逐句播放方案的依赖关系

`2026-05-23-feature-direct-sentence-tts-playback.md` 必须等待本方案完成以下条件后才能进入实施：

- 至少一个 TTS Provider 可保存并真实测试成功。
- 设置页能清楚披露单句播放会发送目标语言文本给 TTS Provider。
- 后续播放服务能读取 `available / requiresRetest / credentialMissing` 等状态。
- TTS 配置 fingerprint 可用于判断缓存失效。
- 真实逐句播放所需的持久音频存储、缓存复用和清理必须由本地媒体派生资产基础设施方案提供；本方案只提供配置可用性与短生命周期 preview audio，不提供逐句播放缓存。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已精确修订单句外部 TTS 请求预览边界，且本实现没有重新引入逐句播放前的逐次请求预览。

## 23. 完成标准

- 设置页至少能配置并真实测试 OpenAI TTS。
- 设置页至少能配置并真实测试 OpenRouter TTS；OpenRouter 保持 model-dependent，并以当前 model + voice + route 的真实测试结果作为可用依据。
- Groq、Custom OpenAI-compatible 不属于第一阶段完成标准；后续进入同构扩展阶段时，必须复用同一模型、结果面板和测试状态，不新增第二套设置流。
- TTS 配置包含 voice、format、speed 和必要的 Provider 专属字段。
- 保存成功不等于可播放；测试成功才形成可播放前置状态。
- 测试请求发送固定低敏文本，不发送用户生活记录。
- 测试成功可通过 Speech seam 试听短生命周期样例音频；SwiftUI 不接触音频 bytes、真实文件路径、AVFoundation 或 Provider response。
- 配置变更后状态变为需重测。
- 结果面板中语音生成状态从占位变成真实 probe 结果。
- 日志和 validation event 不包含敏感文本、请求体、响应体、audio bytes 或密钥。
- 相关 Core / AI / Data / Speech / UI package 测试通过。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。

## 24. 剩余风险

- Provider TTS 能力变化很快，官方模型名、voice 列表和 API 参数可能在实现时已变更；实现前必须二次核对。
- Gemini TTS 处于 Preview，稳定性、可用地区和模型命名可能变化，不宜作为第一版唯一可用 Provider。
- 国内 Provider 的模型、地域、音色和合规参数复杂，第二批实现前需要进一步确认账号区域和 API Key 类型。
- OpenRouter 是聚合层，测试成功只证明当前路由组合可用，不能证明未来每次请求都稳定。
- 音频解码测试在 macOS 和 iOS Simulator 上可能表现不同，需要人工验证补充。
- 语音合成可能产生费用；本方案只做配置测试，不做成本预算 UI。
- 若第一版只支持 non-streamed TTS，长文本体验会有等待；逐句播放的短句场景可以接受。

## 25. 实施记录

- 2026-05-23：创建方案。已基于当前代码和官方 Provider 文档完成初版能力矩阵、架构决策、数据模型、测试链路和文档影响范围。
- 2026-05-23：系统架构复审后更新方案。修正 Groq 官方 TTS 字段，收紧第一批实现范围，补充多语言 voice profile、profile-level probe result、AI / Speech 模块归属、单一测试入口、TTS validation event 与 profile 全局状态隔离、Data 事务和 Speech package 测试目标要求。
- 2026-05-23：根据用户确认更新第一阶段 Provider 范围为 OpenAI + OpenRouter。系统架构推荐方案落定：language code 级 voice profile、`AIProviderProfileProbeResult` 优先、TTS validation 与 profile 全局状态隔离、Speech 承接音频 validation / preview、设置页保持单一测试入口。
- 2026-05-23：新增长期规范 `docs/spec/011-tts-provider-configuration-and-playback.md`，并新增架构备忘录 `docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md`。同时修订 `005` 和 `008` 中与真实 TTS probe、外部 TTS 单句点击播放边界冲突的旧表述。
- 2026-05-23：根据实施条件复审修订方案。补齐 `lastSuccessfulConfigurationFingerprint` / `last_successful_configuration_fingerprint`，将 profile-level probe contract 调整为阶段一前置，明确 TTS 错误枚举落点，修正不存在的结果面板文件路径，并将 Gemini / Groq / Custom OpenAI-compatible 相关测试移出第一阶段强制验收。
- 2026-05-23：根据用户补充要求修订语言测试边界。TTS probe 必须根据当前语言空间目标语言选择内置固定测试文本，并把结果绑定到当前 language code 的 voice profile；模型、voice 或路由不支持当前语言时应返回稳定错误分类，避免把其他语言的成功测试误当成当前语言可播放。
- 2026-05-23：根据系统架构师复审继续修订实施级歧义。明确 TTS adapter kind 事实源、TTS validation repository scoped API、`008` 已修订事实、`unsupportedLanguage` 第一阶段错误分类，以及没有 profile-level endpoint metadata 不得先接 OpenAI / OpenRouter TTS 网络请求。
- 2026-05-23：根据系统架构师再次复审核准实施边界。补充 AI / Speech 依赖方向约束：`LangoTraceAI` 不直接依赖 `LangoTraceSpeech`，音频 decode / preview 通过 Core 协议与 AppEnvironment 注入 Speech 实现；统一 Custom OpenAI-compatible 为后续同构扩展，不纳入第一阶段真实 TTS probe；修正 `005` 为已修订后的实施一致性检查。
- 2026-05-23：根据早期开发与基础设施优先原则再次完善方案。删除“AI 侧轻量响应校验可作为第一版音频验收”的可选路径，强制建立 Core 音频校验协议、Speech 实现和 Speech package test target；明确设置页 preview audio 只作为短生命周期试听资源，不写入持久媒体资产；真实逐句播放前必须另行完成本地媒体派生资产基础设施 active plan。
- 2026-05-23：用户批准立即实施，方案状态调整为 `User Approved`，实施从阶段一 TDD 开始。
- 2026-05-23：实施进展：已按 TDD 落地阶段一到阶段六的主要代码路径。新增 profile-level capability endpoint metadata、TTS 错误分类、TTS Core 配置模型与 fingerprint、Data TTS settings / language voice profile 表和 scoped repository、`GRDBAIProviderConfigurationRepository` 同事务保存 profile endpoint / TTS settings / voice profile、Core 音频校验与 preview playback 协议、Speech package test target、短生命周期 preview store / validation / playback seam、AI package OpenAI / OpenRouter Audio Speech request adapter、音频响应 validator、设置页 voice / format / speed / instructions 可见字段、draft / saved TTS probe 合流、TTS 结果状态持久化隔离、失败分类持久化，以及 `loadDefaultPlayableTTSConfiguration(languageCode:)` 可用性读取接口。
- 2026-05-23：实施中途完成文档影响同步。更新 `docs/README.md` 当前状态、`docs/platform-page-inventory.md` 页面事实、`docs/spec/009-testing-and-verification.md` TTS 验证门禁、`docs/spec/011-tts-provider-configuration-and-playback.md` 当前 result / availability 语义，以及 `docs/spec/ui-design/mvp-ui-flow-and-design-system.md` AI Provider 设置页 UI 事实。
- 2026-05-23：实施完成审计：完成标准逐项满足。OpenAI / OpenRouter TTS 均通过同一配置测试入口进入真实 Audio Speech adapter；OpenRouter 保持 model-dependent；Groq / Custom OpenAI-compatible 未纳入第一阶段真实 probe；TTS 配置包含 voice、format、speed、instructions 和 provider parameter allowlist；保存与可播放前置通过 fingerprint 和最近成功测试隔离；固定低敏测试文本按 language code 选择；成功结果可经 Speech seam 试听短生命周期 preview audio；TTS 失败不污染文本 profile 全局验证摘要；配置变更后进入 `requiresRetest`；日志与 validation event 不记录请求体、响应体、audio bytes 或密钥。验证命令 `scripts/verify.sh` 已通过，SwiftLint 仅剩既有 warning 且 0 serious，SwiftFormat 0 files require formatting。

## 26. 系统架构复审结论

状态：Approved With Notes。文档已根据 2026-05-23 早期开发与基础设施优先原则完成修订；用户已明确批准立即实施，任务状态已进入 `User Approved`。

### 26.1 代码现状准确性

基本准确：

- `AIProviderEndpointPurpose` 已有 `.tts`。
- `AIProviderSettingsView` 已展示 speech model 分组。
- `AIOptionalModelDraftConfiguration` 能保存 speech endpoint 的 Provider、Base URL、model 和凭证引用。
- `AIProviderProbeCapability.speechSynthesis` 已存在，结果面板可展示真实 TTS probe 结果；成功试听按钮通过 `AIProviderSettingsActions.playSpeechPreview` 接入 AppEnvironment 注入的 Speech preview playback seam。
- `AIProviderConfigurationService` 已可在 draft / saved 测试中把 TTS probe 合并到同一个分能力结果，并通过 endpoint metadata 区分 text endpoint 与 `.tts` endpoint。
- `LangoTraceSpeech` 已新增 TTS 音频校验实现、短生命周期 preview store / playback service 和 package test target。
- `GRDBAIProviderConfigurationRepository.saveProfile(_:)` 已同事务保存 profile endpoint、endpoint 级 TTS settings 和 language code 级 voice profile；Data 聚焦测试已覆盖外键级联、删除重插和 TTS 结果持久化语义，完整验证已通过 `scripts/verify.sh` 收口。

已修正或明确后续边界：

- 结果面板试听入口已建立 UI callback、preview resource 传递、AppEnvironment 注入和 Speech playback service。SwiftUI 不接触音频 bytes、真实文件路径、AVFoundation 或 Provider response。
- `loadDefaultPlayableTTSConfiguration(languageCode:)` 已能按 language code 与 fingerprint 读取可用性；`failedLastTest(errorCategory)` 的最近失败分类来自 voice profile 持久化字段，成功测试会清除该分类。
- 严格代码检查补齐设置页加载路径：`AIProviderSettingsActions.loadTTSVoiceProfile` 现在按当前 language code 读取已保存 voice profile，`AIProviderDraftConfiguration.applyLoadedTTSVoiceProfile` 回填 voice、format、speed 和 instructions，避免重开设置页后使用 provider 默认值覆盖用户配置；UI 回归测试已覆盖该状态同步。
- 严格代码检查补齐 TTS probe 响应大小门禁：TTS audio response 超过 2 MiB 时在进入音频校验前返回 `invalidAudioResponse`，避免把超大响应体传入 preview store 或解码层；AI 回归测试已覆盖该边界。
- UI 已显示 voice / format / speed / instructions；OpenRouter provider options 等更高级字段不属于第一阶段完成标准，后续需要另行扩展 allowlist 与 provider-specific UI。
- 配置变更后 repository 已通过 fingerprint 产生 `requiresRetest` 语义；UI 保存后的展示仍以重新加载服务结果和测试结果面板为准，未新增第二个主测试入口。
- UI package 中存在本地 `AIProviderAdapterKind` 与 Core 同名 enum，实施 TTS adapter 扩展时必须明确映射边界，避免 UI enum 与 Core enum 漂移。
- 当前 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已完成外部 TTS 单句点击播放边界修订；方案中不得继续把它描述为当前冲突事实。

### 26.2 可行性判断

方向可行，但不应按原始大范围一次实施。推荐执行顺序：

1. 先建立 TTS 数据模型、voice profile 和 result model 迁移，不接真实网络。
2. 接入 OpenAI TTS，跑通配置、保存、测试、试听和状态持久化。
3. 在同一结果面板中把 `speechSynthesis` 从 placeholder 升级为真实 row。
4. 接入 OpenRouter TTS，保持 model-dependent，使用手动 model / voice 配置和真实测试结果判断可用性。
5. 通过严格测试后，再以独立子阶段接 Groq / Custom OpenAI-compatible；Custom 不属于第一阶段真实 TTS probe。
6. Gemini、Mistral、xAI、DashScope、Zhipu、SiliconFlow 单独后续方案或本方案后续阶段实现。

本次复审已给出推荐方案，剩余实施前门槛为工程执行门槛，不再是产品 / 架构方向待确认：

- 推荐新增 `AIProviderProfileProbeResult`；如选择扩展现有 result，也必须让 capability row 持有 endpoint metadata。
- TTS adapter kind 第一阶段以 `TTSProviderAdapterKind` / `ai_provider_tts_settings.tts_adapter_kind` 为真实请求 adapter 事实源；现有 text/chat `AIProviderAdapterKind` 不直接驱动 TTS request builder。
- TTS audio validation / preview seam 强制进入 `LangoTraceSpeech`，并新增 Speech package test target；AI package 不直接依赖 Speech package，音频校验通过 Core 协议 / AppEnvironment 注入。AI 侧轻量响应检查只能作为 adapter 前置检查，不能替代音频验收。
- voice profile 必须是 language code 级。
- TTS 测试失败必须与 profile 全局验证摘要隔离，并通过新增 repository scoped API 写 validation event 与 voice profile 状态。
- 第一阶段 Provider 范围为 OpenAI + OpenRouter。

### 26.3 决策依据和收益

核心收益：

- 为逐句播放提供真实前提，避免“按钮直接播放”落成无真实音频的 UI 改动。
- 保持 LangoTrace 的本地优先与用户自带 Provider 边界：Keychain 保存 secret，SQLite 只存非敏感配置，测试请求不发送生活记录。
- 通过 language code 级 voice profile 支持多语言空间，避免英语、日语、韩语配置互相覆盖。
- 通过 single test entry + capability result panel 延续现有设置页交互，避免每个能力增加一个主按钮。
- 通过 endpoint metadata result model 解决不同能力使用不同 Provider / model 的长期扩展问题。

架构收益：

- UI 仍只发起意图，不拼网络请求、不读 Keychain、不解析音频。
- AI package 继续拥有 Provider request / validation event 边界。
- Speech package 开始承接 TTS 音频语义，为后续逐句播放、暂停、停止和缓存打基础。
- Data schema 将 endpoint 与 voice profile 拆分，避免把 TTS 专属字段污染通用 endpoint 表。

### 26.4 四维切片

- 并发 / 性能：必须为每个 endpoint + language code 限制一个 active TTS probe；重复点击测试不应产生并发请求或状态倒写。Preview audio bytes 只能短生命周期持有，不进入缓存目录。
- 异常边界：必须新增 invalidVoice、unsupportedLanguage、audioDecodeFailed、rateLimited、quotaExceeded 或等价错误映射；Provider 原始错误正文不得直接展示或落日志。
- 状态同步：保存状态、测试状态、configuration fingerprint、validation event、结果面板和 language voice profile 必须一致；切换语言空间时读取对应 language code 配置。
- 数据一致性：endpoint、tts settings、voice profile 必须同事务写入；Keychain / SQLite 非原子补偿沿用现有规则；TTS optional probe 不覆盖 text profile 全局最近验证摘要。

### 26.5 更优设计建议

比原方案更稳的设计是：

```text
AIProviderProfile
  text endpoint
  tts endpoint
    endpoint-level tts settings
    voice profile for language en
    voice profile for language ja
    voice profile for language ko
```

设置页仍是一套共享组件：

```text
AIProviderSettingsView
  Text endpoint section
  TTS endpoint section
    current language voice profile
  Embedding endpoint section
  One test button
  One capability result panel
```

服务边界：

```text
UI -> AIProviderSettingsActions -> AppEnvironment
AppEnvironment -> AIProviderConfigurationService
AIProviderConfigurationService -> TTSProviderAdapter for network
AIProviderConfigurationService -> GRDB repository for validation summary
AIProviderConfigurationService -> Core TTSAudioValidationService protocol
AppEnvironment -> injects Speech TTSAudioValidationService implementation when decode validation is needed
SpeechService / TTSAudioValidationService -> audio metadata / preview semantics
```

这比“每个能力独立测试按钮 + endpoint 单行 voice 设置 + 单 endpoint result model”更符合当前代码结构和长期扩展方向。

### 26.6 已定推荐方案与实施前门槛

- Result model：推荐新增 `AIProviderProfileProbeResult`；若选择扩展 `AIProviderConfigurationProbeResult`，也必须让 capability result 持有 endpoint metadata。
- Adapter kind：真实 TTS request adapter 使用 `TTSProviderAdapterKind` / `ai_provider_tts_settings.tts_adapter_kind`；除非同步完成 Core/Data/UI 的 adapter enum 扩展和迁移，否则不得把 TTS request builder 绑定到现有 text/chat `AIProviderAdapterKind`。
- Data schema：采用 endpoint settings + language voice profile，不采用 endpoint 单行 voice。
- Data fingerprint：voice profile 必须同时保存当前 `configuration_fingerprint` 和 `last_successful_configuration_fingerprint`；只有最近成功 fingerprint 与当前 fingerprint 一致，才允许逐句播放判定为 available。
- Validation persistence：TTS 结果不复用会覆盖 profile 全局摘要的 `recordValidationOutcome(_:)`；必须新增 endpoint / voice-profile scoped repository API。
- Speech package：新增测试 target，音频 validation / preview seam 归 Speech；AI package 不直接依赖 Speech package，必须通过 Core 协议 / AppEnvironment 注入使用音频校验。
- 第一阶段 Provider：OpenAI + OpenRouter。OpenRouter 维持 model-dependent，以当前 model + voice + route 的真实测试结果作为可用依据；Custom OpenAI-compatible 不进入第一阶段真实 TTS probe。
- 本任务只提供 TTS 配置可用性、真实 probe、Speech seam 样例试听和逐句播放可用性读取；持久 TTS 音频缓存、`LocalMediaArtifactStore`、播放协调器和媒体资产清理必须在真实逐句播放实施前通过单独 active plan 完成。
- `docs/spec/005-ai-provider-prompt-and-privacy.md` 的真实 TTS probe 边界已完成修订；实施阶段只需检查实现是否仍遵守该边界，如边界改变再更新。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 的外部 TTS 请求预览旧规则已完成修订；实施阶段只需检查实现是否仍遵守该边界。

### 26.7 当前实施条件判断

当前方案已完成用户审批，具备开工条件：

- 文档层面：关键架构、第一阶段范围、数据模型、测试路径和边界问题已补齐，可作为实施依据。
- 流程层面：用户已明确要求立即实施，方案状态已改为 `User Approved`，可进入 TDD 实施。
- 工程层面：实施应先写失败测试，再按阶段一到阶段六推进；不得跳过 profile-level probe contract 直接接 OpenAI TTS 网络请求；不得跳过 Core / Speech 音频校验 seam；不得在本任务中偷做持久音频缓存或逐句播放协调器。
