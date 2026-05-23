# TTS Provider 后续扩展备忘录

状态：Accepted
创建日期：2026-05-23

## 1. 适用范围

本文档记录 TTS Provider 配置与测试方案中暂不实施、但会影响后续架构边界的扩展提醒。

适用范围：

- TTS Provider 第二批和后续 Provider 接入。
- OpenRouter 模型发现和 voice 发现。
- 音频缓存、离线播放、流式播放和长文本语音生成。
- 本地 TTS Provider、Apple system voice 和第三方本地语音引擎。
- TTS 成本估算、用量提示、音频导出和未来同步边界。

本文档不是最终事实源。后续任务采纳任一条提醒时，必须把对应结论写入任务方案、正式 spec、architecture 文档或 ADR。

## 2. 目的

第一阶段 TTS 配置与测试只实现 OpenAI 和 OpenRouter。该范围足以打通设置页配置、真实 probe、结果面板、voice profile、validation event 和后续逐句播放前置状态。

但当前方案已经明确一些扩展方向会影响 Data schema、Provider adapter、Speech 播放边界、隐私披露和缓存失效规则。如果这些内容只留在单个 active plan 中，后续新增 Provider 或播放能力时容易遗漏，因此需要单独沉淀为架构备忘录。

## 3. 已有设计留下的扩展点

### 3.1 Provider adapter

第一阶段应形成稳定的 TTS adapter contract：

- request path、request body 和 response parsing 由 adapter 定义。
- adapter 只接受 allowlisted provider parameters。
- model-dependent Provider 不能被标记为全局 supported。
- 真实可用性以当前配置的 probe result 为准。

后续 Provider 接入必须复用这套 contract，不新增第二套设置页或第二套主测试入口。

### 3.2 Endpoint 与 voice profile

`.tts` endpoint 保存 Provider、Base URL、model、credential 和 adapter kind。voice、format、speed、style、instructions、测试状态和 successful fingerprint 保存到 `endpoint_id + language_code` 级 voice profile。

该设计为后续多语言空间、缓存 key、配置变更失效和逐句播放可用性读取留下扩展点。后续功能不得把 voice 回退为 endpoint 全局字段。

### 3.3 Result model

语音生成、文本生成、图片理解、语言支持和向量化可能使用不同 endpoint、不同 Provider 和不同 model。后续结果面板应优先采用 profile-level probe result，或至少让每个 capability row 携带 endpoint metadata。

该扩展点也适用于后续 embedding、OCR、ASR 和自定义兼容 Provider。

### 3.4 AI 与 Speech 职责拆分

AI / Provider 层负责外部 TTS 请求、Keychain secret 解析后的请求构造、错误分类和 validation event。Speech 层负责音频解码、试听、播放生命周期、AudioSession 语义和未来缓存播放。

后续如果为了 probe 简化在 AI package 中做轻量 response validation，也不能让 AI package 持有 AVAudioPlayer 生命周期、长期播放状态或平台音频会话策略。

## 4. 后续任务必须重新决策的问题

### 4.1 第二批 Provider 顺序

Groq、Custom OpenAI-compatible、Gemini、Mistral、xAI、DashScope、Zhipu 和 SiliconFlow 不应一次性全部接入。

推荐顺序：

1. Groq 和 Custom OpenAI-compatible：接近 OpenAI Audio Speech 形态，但仍需单独 voice、model、path 和格式测试。
2. Gemini、Mistral、xAI：请求体和响应体差异更明显，需专属 adapter 和更严格错误映射。
3. DashScope、Zhipu、SiliconFlow：需要额外处理地域、账号体系、模型与音色绑定、合规参数和更多音频格式。

每个 Provider 接入前必须重新核对官方文档和当前可用模型，不得使用过期 voice 或模型名。

### 4.2 OpenRouter 模型发现

第一阶段 OpenRouter 采用手动 model / voice 配置。后续如接入 OpenRouter Models API，需要明确：

- speech-capable model 的过滤条件。
- model 输出能力变化后的缓存与刷新策略。
- voice 列表是否来自模型能力、Provider 路由还是用户手动输入。
- 模型发现失败时是否保留手动输入路径。
- 诊断日志中如何记录发现状态而不记录用户输入文本或完整请求体。

OpenRouter 测试成功仍只表示当前 model + voice + route 可用，不得升级为 OpenRouter 全局可用事实。

### 4.3 Voice 列表与试听

Provider voice 列表拉取和批量试听不属于第一阶段。

后续实现前需要决策：

- voice list 是否本地缓存，缓存多久。
- voice display name、language、gender、style 等 metadata 是否进入数据库。
- voice preview 是否发送固定测试句，是否需要独立披露。
- 用户自定义 voice id 如何与官方列表合并。
- Provider 返回的 voice metadata 是否可能包含账号私有信息。

voice list 失败不得阻断手动输入 voice id。

### 4.4 音频缓存与离线播放

逐句播放第一版不得再把生成音频作为临时 UI 缓存或不可索引文件处理。真实逐句播放进入实施前，必须先完成本地媒体派生资产基础设施方案，使 TTS 音频通过统一 metadata、App 管理文件目录、原子写入、解码验证、失效和清理策略落地。设置页 TTS 配置测试可以产生短生命周期 preview audio，但该 preview 不写入 `LocalMediaArtifactStore`，也不能作为逐句播放可复用缓存。

本地媒体派生资产基础设施必须决策：

- cache key 是否包含 Provider、model、voice profile fingerprint、language code、text hash、format 和 App schema version。
- audio bytes 存放位置、文件命名、大小限制和清理策略。
- 缓存是否进入导出包、备份目录或未来同步对象。
- 用户删除 Entry、语言空间、Provider profile 或 voice profile 时如何清理缓存。
- 缓存命中是否需要重新验证 credential 或只验证 configuration fingerprint。
- text hash 是否可能成为敏感内容侧信道。

音频缓存即使可重建，也不能被当作普通无敏感缓存处理。

### 4.5 流式 TTS 与长文本

第一阶段只面向逐句播放，使用 non-streamed request 即可。

后续若支持 streaming TTS、WebSocket 或长文本分段，需要重新评估：

- 播放开始延迟与取消语义。
- 分段文本是否改变隐私披露级别。
- partial audio 的缓存、失败恢复和清理。
- iOS 后台音频策略和 AudioSession category。
- Provider 限流、超时和并发策略。
- 句子级播放与整段朗读是否使用同一缓存和同一授权边界。

长文本或批量预生成不得复用“单句点击播放”的低摩擦边界。

### 4.6 本地 TTS Provider

Apple `AVSpeechSynthesizer` 或第三方本地 TTS 引擎可以作为未来本地 Provider，但不能伪装成 OpenAI-compatible endpoint。

后续需要决策：

- 本地 Provider 是否作为独立 provider preset。
- 本地 voice 与外部 voice profile 是否共用表结构。
- 系统 voice 列表是否按平台差异展示。
- 本地播放是否绕过 TTS Provider 测试，或使用本地 probe 统一返回可用性状态。
- 本地 voice 的质量、语言覆盖和用户预期是否足以作为默认兜底。

### 4.7 成本与用量提示

TTS 配置测试和逐句播放可能产生外部 Provider 费用。第一阶段只做设置披露，不做成本预算 UI。

后续如增加用量提示，需要决策：

- 是否按字符数估算，还是只展示 Provider 计费提示链接。
- 是否为配置测试和真实逐句播放分别记录非敏感 usage bucket。
- 是否需要本地每日提醒、预算阈值或禁用高成本 Provider。
- 是否影响买断制产品定位和 App Store 隐私披露。

用量记录不得包含用户句子原文或完整请求体。

### 4.8 音频导出与同步

未来若支持导出学习材料或多端同步音频，需要单独审查：

- 生成音频是否属于用户数据、派生数据还是可重建缓存。
- 是否默认导出、可选导出或默认排除。
- 多端同步时是否同步 audio bytes、同步 cache metadata，还是在新设备重新生成。
- Provider license 或 voice 使用条款是否限制导出、分发或商业使用。
- 删除 Provider 配置、语言空间或 Entry 后是否需要强制清理派生音频。

在正式决策前，TTS audio bytes 默认不得进入同步目录。

## 5. 不应在当前阶段提前实现的内容

当前 OpenAI + OpenRouter 配置与测试阶段不实现：

- OpenRouter Models API 自动发现。
- Provider voice list 拉取和批量试听。
- Groq、Custom OpenAI-compatible、Gemini、Mistral、xAI、DashScope、Zhipu、SiliconFlow 的真实接入。
- 声音克隆、上传参考音频、声音设计和自定义 voice 创建。
- WebSocket / streaming TTS。
- 长文本朗读、整篇记录批量预生成。
- 持久音频缓存和离线播放。
- 本地 Apple `AVSpeechSynthesizer` 兜底。
- 成本预算 UI。
- 音频导出和同步。

这些能力进入实现前，必须先创建或更新对应 active plan，并检查本备忘录是否需要提升为正式 spec、architecture 文档或 ADR。

## 6. 关联文档

- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/plans/active/2026-05-23-feature-tts-provider-configuration-test.md`
- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
