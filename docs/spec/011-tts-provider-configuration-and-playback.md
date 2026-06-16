# 011：TTS Provider 配置、测试与播放前置规范

状态：Accepted

适用阶段：TTS Provider 配置、语音生成测试、逐句播放、音频试听、本地媒体派生资产与播放服务接入。

## 1. 适用范围

本文档规定 LangoTrace 中 TTS Provider 的配置模型、测试入口、隐私边界、数据状态、模块归属和后续逐句播放前置条件。

本规范覆盖：

- AI Provider 设置页中的语音生成模型配置。
- OpenAI 和 OpenRouter 的第一阶段 TTS 配置与测试。
- 后续 Groq、Custom OpenAI-compatible、Gemini、Mistral、xAI、DashScope、Zhipu、SiliconFlow 等 Provider 扩展时必须遵守的边界。
- 记录详情逐句播放功能依赖的 TTS 可用性状态。

本规范不覆盖：

- 录音、跟读评分、听写和 ASR。
- 声音克隆、上传参考音频或自定义 voice 创建。
- 批量预生成整篇记录音频。
- WebSocket / streaming TTS 播放。
- StoreKit 用量计费或成本预算 UI。

## 2. 当前结论

TTS 是“用生活记录学习语言”闭环中的辅助能力，目的是让用户听到目标语言句子、辅助跟读和听写。TTS 不应把产品变成语音合成工具，也不应让 Provider 细节侵入学习页面。

第一阶段 TTS Provider 配置支持：

- OpenAI：官方 Audio Speech 形态，作为最小可用路径。
- OpenRouter：兼容 OpenAI Audio Speech 形态，但必须保持 model-dependent，不声明 OpenRouter 全局 TTS 可用。

学习页面后续单句播放只能依赖“已测试通过”的 TTS 配置。保存 Provider 配置不等于可播放。

## 3. 强制规则

- UI 不直接创建 TTS `URLRequest`、拼接 Authorization header、读取 Keychain、解析 Provider 原始错误或管理音频播放生命周期。
- TTS Provider 网络请求和 validation event 归 AI / Provider 服务层。
- 音频解码、设置页样例试听、播放状态和后续 AudioSession 语义归 Speech 模块；AI Provider 层只能通过 Core 音频校验协议使用 Speech 注入的能力，不得直接依赖 Speech concrete package。
- `.tts` endpoint 只保存 Provider、Base URL、model、credential、adapter 等 endpoint 级信息。
- voice、format、speed、style、instructions 和测试状态按 `endpoint_id + language_code` 保存为 voice profile，不得绑定为 endpoint 全局单行 voice。
- voice profile 必须同时保存当前配置 fingerprint 和最近一次成功测试的 fingerprint。只保存一个 fingerprint 无法区分“当前配置值”与“上次通过测试的配置值”，不得作为逐句播放可用性依据。
- TTS 配置测试必须使用固定低敏测试句，不得发送用户生活记录、Entry 正文、learning text、历史记忆、OCR 文本、照片内容或音频转写。
- TTS saved probe 失败不得覆盖文本模型 profile 的全局最近验证状态。
- 设置页保持单一主测试入口；语音生成作为同一 capability result panel 中的一行结果，不新增一套独立主测试流程。
- 学习页只有用户显式点击某句播放时，才能发送该句目标语言文本给已配置 TTS Provider。
- 阅读页只有用户显式点击阅读正文块或句子的 `听` 动作时，才能发送该句或该块目标语言文本给已配置 TTS Provider；reading TTS 必须使用独立 `readingDocumentSentence` source，不得复用 Entry 或 LearningMaterial sentence source。
- 页面展示、滚动、进入详情、保存记录、生成学习材料完成、切换句子和批量预生成不得自动触发 TTS 请求。
- 阅读资料导入、打开、滚动、选中、搜索、删除 / 恢复和 AI 解释完成不得自动触发 TTS 请求。
- 逐句播放生成的 TTS 音频必须通过本地媒体派生资产基础设施管理，不得写入 SwiftUI 私有状态、临时目录、不可索引文件名或 UI 层 ad hoc 缓存。
- TTS 音频 metadata 必须绑定 derivation key、文本 hash、目标语言、provider profile、endpoint、adapter kind / version、model、voice、format、参数 hash、configuration fingerprint、文件相对路径、byte size、duration、created / last accessed、失效和清理策略。
- 第一阶段 TTS 音频默认 `localOnly`、excluded from system backup、excluded by default from export；未来同步、导出、备份或附件化必须单独设计 manifest、加密、删除传播和恢复策略。
- TTS 请求日志、diagnostic event 和 validation event 不得记录测试文本、用户句子、完整请求体、完整响应体、audio bytes、API Key、Authorization header、完整 Keychain account 或自定义敏感 header。

## 4. 第一阶段 Provider 边界

### 4.1 OpenAI

OpenAI 是第一阶段最小可用 TTS Provider。

推荐配置：

- Provider：OpenAI。
- Base URL：`https://api.openai.com/v1`。
- Model：`gpt-4o-mini-tts` 或用户选择的 OpenAI TTS 模型。
- Voice：使用 OpenAI 官方 voice id。
- Output format：默认 `mp3`，允许用户在高级设置中选择受支持格式。
- Instructions：高级设置字段，用于控制语气、风格和朗读方式。

OpenAI adapter 必须验证：

- 请求路径为 Audio Speech endpoint。
- 请求体只包含 adapter allowlist 字段。
- 响应体是可解码音频。
- 错误被映射为稳定分类。

### 4.2 OpenRouter

OpenRouter 是第一阶段第二个 TTS Provider，但必须保持 model-dependent。

规则：

- 不把 OpenRouter 全局标记为 TTS supported。
- 用户必须手动填写或选择支持 speech output modality 的 model。
- 第一阶段不要求接入 OpenRouter Models API。
- voice 不使用 OpenAI 内置 voice 列表硬编码；允许用户输入 voice id / voice name。
- 测试成功只表示当前 model + voice + route 可用，不表示 OpenRouter 所有模型或未来路由都可用。
- 失败时必须展示稳定错误分类，不能展示 Provider 原始响应正文。

OpenRouter adapter 可以复用 OpenAI Audio Speech 的请求形态，但必须在 capability policy 和结果面板中保留 model-dependent 语义。

## 5. 配置模型

### 5.1 Endpoint

`.tts` endpoint 保存 endpoint 级信息：

- endpoint id。
- profile id。
- purpose：`tts`。
- provider preset id。
- TTS adapter kind。
- base URL。
- model name。
- credential id。
- request timeout。

这些字段属于 Provider 连接信息，不表达具体语言空间的 voice 偏好。

### 5.2 Voice Profile

voice profile 按 `endpoint_id + language_code` 唯一。

voice profile 保存：

- voice id。
- voice display name。
- language code。
- output format。
- sample rate。
- speed。
- volume。
- pitch。
- style prompt。
- instructions。
- provider parameters。
- configuration fingerprint。
- last successful configuration fingerprint。
- last test status。
- last test error category。
- last tested at。

原因：

- LangoTrace 的核心模型是一个语言空间对应一门目标语言。
- 英语、日语、韩语等语言空间可能需要不同 voice、speed、style 和测试状态。
- endpoint 全局 voice 会在多语言空间间互相覆盖，后续逐句播放会产生错误音频。

设置页加载已保存配置时，必须在加载 `.tts` endpoint 后继续按当前 `language_code` 读取 voice profile，并回填 voice、format、speed、instructions 等语音字段。只加载 endpoint、model 和 credential secret 会让 UI 回到 provider 默认 voice，后续保存可能覆盖用户对当前语言空间的 voice profile。

### 5.3 Provider Parameters

Provider 专属参数必须使用 adapter allowlist。

第一阶段 allowlist：

- OpenAI：`instructions`、`response_format`。
- OpenRouter：`response_format`、`provider_options`。

`provider_options` 必须是强类型或 allowlisted JSON value，不允许用户直接输入任意请求体片段。

## 6. 测试与结果模型

### 6.1 单一测试入口

AI Provider 设置页保持一个主测试入口。该入口按当前 draft / saved profile 运行分能力 probe，并在结果面板中展示：

- 文本回复。
- JSON 输出。
- 语言支持。
- 图片理解。
- 语音生成。
- 向量化。

TTS 启用且配置完整时，`语音生成` row 运行真实 TTS probe。TTS 未启用或配置不完整时，显示未启用、未配置或需重测。

单一测试入口不等于单 endpoint 测试。实现必须把当前 profile 的 enabled endpoint 拆成独立 capability probe：

- text / JSON / language / image 使用 text generation endpoint。
- speech synthesis 使用 `.tts` endpoint 和当前 language code 对应 voice profile。
- embedding 后续使用 `.embedding` endpoint。

文本 probe 失败不得天然阻断 TTS probe。只有 shared credential 缺失、用户取消、全局网络不可用或调用方明确取消整个 operation 时，才允许多个 capability 同时提前结束。否则结果面板必须能表达 text failed、TTS succeeded 或 text succeeded、TTS failed 的 partial 状态。

TTS probe 必须按当前语言空间的目标语言选择固定测试文本。系统应内置多个语言版本的低敏测试文本，例如英语、简体中文、日语、韩语等；用户点击测试时，服务层根据当前 language code 选择对应文本发送给 TTS Provider。测试结果只证明当前 `model + voice + languageCode + route + configurationFingerprint` 可以生成可解码音频，不证明其他语言空间可用，也不证明发音自然度或教学质量。

如果 Provider 明确返回模型、voice 或路由不支持当前语言，必须映射为稳定错误分类。推荐新增 `unsupportedLanguage` 或 `voiceLanguageUnsupported`；如果当前阶段不新增枚举，也必须在实现方案中明确映射到 `unsupportedModel`、`invalidVoice` 或 `providerRejected` 的规则，并让 UI 能提示用户更换支持当前目标语言的模型或音色。

### 6.2 Result Model

推荐新增 `AIProviderProfileProbeResult`。

最低要求：

- 每个 capability result 必须能携带 endpoint metadata。
- endpoint metadata 至少包含 endpoint id、endpoint purpose、provider preset id、model name、configuration fingerprint。
- 结果面板不得把 text endpoint 的 model name 当作 TTS row 的 model name。

如果选择扩展 `AIProviderConfigurationProbeResult`，也必须满足上述 endpoint metadata 要求。

当前代码采用兼容扩展路径：`AIProviderDraftProbeSnapshot` 可携带 text endpoint、tts endpoint、TTS settings、当前 language code 的 voice profile 和 transient secret；`AIProviderConfigurationProbeResult` 的 capability result 可携带 endpoint metadata。后续若新增独立 `AIProviderProfileProbeResult`，必须保持同等语义，不得把 TTS row 的 Provider、model、duration、error category 或 validation event 复用 text endpoint 的字段。

### 6.3 Draft Probe

未保存 draft 可以测试当前屏幕配置，但：

- 不写 Keychain。
- 不写 SQLite 配置。
- 不写 validation event。
- 只允许写非敏感 diagnostic event。
- 明文 API Key 只存在于短生命周期 UI draft 和 transient probe input。
- draft snapshot 必须能携带 text endpoint、tts endpoint、当前 language code、voice profile draft 和对应 transient secret。只携带 text endpoint 的 snapshot 不能用于真实 TTS probe。

### 6.4 Saved Probe

已保存配置测试时：

- 服务层读取默认 profile。
- 解析 `.tts` endpoint。
- 读取当前 language code 对应 voice profile。
- 通过 Keychain 引用解析 secret。
- 发起 TTS probe。
- 写非敏感 `synthetic_test` validation event。
- 更新 voice profile 的 last test status / last tested at / last successful configuration fingerprint。

TTS saved probe 不得调用会覆盖 profile 全局最近验证摘要的路径，除非该路径已经具备 endpoint purpose 隔离语义。

如果一次主测试同时包含 text endpoint 和 TTS endpoint：

- text endpoint 的 synthetic result 可以继续更新文本 profile 的现有最近验证摘要。
- TTS endpoint 的 synthetic result 只能更新 TTS voice profile 和 endpoint-scoped validation event。
- profile-level overall status 只用于结果面板展示，不得直接写入 `ai_provider_profiles.last_validation_status`，除非该字段已经被重构为 endpoint / capability aware。

## 7. 播放前置状态

TTS Provider 配置可用性读取接口只能返回以下状态：

- `available(configuration)`。
- `notConfigured`。
- `notTested`。
- `requiresRetest`。
- `failedLastTest(errorCategory)`。
- `credentialMissing`。
- `unsupportedProvider`。

`available` 在 Provider 配置层必须满足：

- 存在启用的 `.tts` endpoint。
- 存在 endpoint 级 TTS settings。
- 存在当前 language code 对应 voice profile。
- Keychain secret 可解析，或 Provider 不需要 secret。
- 上次 TTS 测试成功。
- 当前配置 fingerprint 与测试成功时一致。
- 当前 App 版本仍支持该 TTS adapter。

逐句播放层不得只凭 Provider 配置 `available` 直接播放。本地媒体派生资产基础设施已经可用，能通过 Core TTS artifact key、`GRDBMediaArtifactRepository`、`LocalMediaArtifactFileStore`、`LocalMediaArtifactStore` facade 和 Speech `TTSAudioFileValidator` 查询、写入、解码验证、失效和清理 TTS audio artifact。换言之，Provider 配置 `available` 加本地媒体派生资产基础设施只是逐句播放的基础条件；完整播放 ready 状态还必须经过 direct playback coordinator、真实 TTS generation service、正式 playback service 和 UI action contract。

`requiresRetest` 必须在以下情况出现：

- endpoint Provider、Base URL、model、credential、adapter kind 或 timeout 变化。
- voice profile 的 voice、format、sample rate、speed、volume、pitch、style、instructions 或 provider parameters 变化。
- language code 变化且找不到该 language code 的成功 voice profile。
- App 升级后 TTS adapter schema version 或 request builder 版本变化。

## 8. 隐私与披露

设置页必须清楚说明：

- 测试语音会把固定测试句发送给所选 TTS Provider。
- 学习页面中用户点击某句播放时，会把该句目标语言文本发送给所选 TTS Provider。
- App 不会在页面展示、滚动、进入记录详情、保存记录或切换句子时自动发送文本。
- API Key 保存在本机 Keychain 或等价安全存储中，默认不同步。
- 生成的语音是 AI 生成语音，不是真人录音。

设置页完成配置、测试和披露后，用户在学习页面显式点击单句播放不需要逐次请求预览。该低摩擦边界只适用于单句目标语言 TTS，不扩展到照片、音频、OCR、历史记忆、多条 Entry 上下文或批量预生成。

该披露不需要设计成单独的长期 consent flag。可播放前置由“启用 `.tts` endpoint + voice profile 成功测试 + fingerprint 未变化 + 设置页持续展示披露文案”共同成立。Provider、credential、model、voice 或影响输出的参数变化后，必须重新测试；重新测试前学习页不得直接发送句子。

## 9. 日志与诊断

允许记录：

- operation id。
- endpoint purpose。
- capability。
- provider preset id。
- model name。
- output format。
- duration。
- byte size bucket。
- status。
- error category。

不得记录：

- 测试文本。
- 用户句子文本。
- 完整请求体。
- 完整响应体。
- audio bytes。
- API Key。
- Authorization header。
- 完整 Keychain account。
- 自定义敏感 header。

voice id 是否明文记录必须按 Provider 风险评估；默认优先记录 hash 或仅记录是否存在。

TTS probe 和后续单句生成还必须设置资源边界：

- request timeout 必须来自 endpoint 配置或安全默认值。
- response body 必须有最大字节数限制；超过限制按 `invalidAudioResponse` 或等价稳定错误分类处理。
- 设置页 TTS probe 的 preview audio 只允许短生命周期持有，并且只能经 Speech seam 试听；真实逐句播放音频必须写入已定义的本地媒体派生资产基础设施后再复用。
- 同一 `endpoint_id + language_code` 同一时刻只能有一个 active TTS probe 或 preview 生成；重复点击应取消前一个 operation 或复用当前 in-flight 状态。
- 用户取消、页面关闭或 profile 切换必须取消未完成 probe，并且 cancelled 结果不得写入 validation event 或可播放状态。

## 10. 模块归属

推荐边界：

```text
UI -> AIProviderSettingsActions -> AppEnvironment
AppEnvironment -> AIProviderConfigurationService
AIProviderConfigurationService -> TTSProviderAdapter for network
AIProviderConfigurationService -> GRDB repository for validation metadata
Core TTSAudioValidationService protocol -> injected Speech implementation
SpeechService / TTSAudioValidator -> audio metadata, decode validation, preview semantics
```

逐句播放期推荐边界：

```text
UI -> SentenceAudioPlaybackActions
SentenceAudioPlaybackActions -> SentenceAudioPlaybackCoordinator
SentenceAudioPlaybackCoordinator -> TTS availability service
SentenceAudioPlaybackCoordinator -> AI TTS generation service
SentenceAudioPlaybackCoordinator -> Data LocalMediaArtifactStore
SentenceAudioPlaybackCoordinator -> Speech playback service
Data LocalMediaArtifactStore -> GRDB media artifact metadata repository
Data LocalMediaArtifactStore -> Application Support media artifact file store
Speech playback service -> audio decode / playback lifecycle
```

当前已落地边界：

- Core 已定义 `MediaArtifact`、`TTSAudioArtifactKey`、policy、lookup result、commit input、cleanup result、`MediaArtifactRepository`、`LocalMediaArtifactStoring` 和 `TTSAudioFileValidating`。
- Data 已实现 `v7_create_media_artifact_infrastructure`、`media_artifacts` / `tts_audio_artifacts`、`GRDBMediaArtifactRepository`、`LocalMediaArtifactFileStore` 和 `LocalMediaArtifactStore` facade；metadata 使用 pending / ready 文件状态避免文件 move 完成前被 lookup 命中，文件缺失或内容不匹配时按 artifact id 精确失效。
- Speech 已实现持久 TTS 文件校验 `TTSAudioFileValidator`；设置页短生命周期 bytes validation / preview 与逐句播放持久文件 validation 保持分离。
- Core 已定义逐句音频请求、presentation state、配置问题、失败分类、generation input / result、staging writer、playback source resolver、playback service 和 typed diagnostic allowlist contract。
- AI 已实现生产级 `AIProviderHTTPClient`、`SentenceTTSGenerationService` 和 OpenAI / OpenRouter 单句 TTS 生成路径；设置页 probe 继续复用通用 HTTP client。
- Data 已实现 `LocalMediaArtifactFileStore` 的 TTS staging writer 协议和 ready artifact playback source resolver，解析时校验 App 管理目录、relative path、文件存在性、byte size、content hash 和 ready 状态。
- Speech 已实现持久 TTS 音频 playback service，并通过 playback engine seam 隔离 AVFoundation lifecycle。
- AppEnvironment 已装配 `SentenceAudioPlaybackCoordinator` 和 `SentenceAudioPlaybackActions`；iPhone / iPad / macOS 共享记录详情中的逐句 `听` 按钮只通过 UI action contract 触发真实单句播放或生成后播放。
- App 层新增轻量 `LangoTraceAppTests` assembly smoke，`project.yml` 和 `scripts/verify.sh` 已纳入该验证；核心状态机、AI、Data、Speech 和 UI 行为仍由 package tests 覆盖。

禁止：

- SwiftUI View 直接调用 Provider SDK。
- SwiftUI View 直接读取 Keychain。
- SwiftUI View 直接解析音频 bytes。
- SwiftUI View 直接读写 TTS 音频文件路径或 SQLite media artifact metadata。
- AI package 持有长期播放状态或 AVAudioPlayer 生命周期。
- Speech package 直接读取 Provider secret 或拼 Provider HTTP request。
- Data package 直接发起 Provider 请求或持有 AVAudioPlayer 生命周期。

## 11. 后续 Provider 扩展规则

Groq、Custom OpenAI-compatible、Gemini、Mistral、xAI、DashScope、Zhipu 和 SiliconFlow 后续接入时必须遵守：

- 先更新 Provider 能力矩阵。
- 先写 failing tests 锁定 request body、response parsing、错误映射和日志禁区。
- 不得复用 OpenAI voice 列表，除非官方明确兼容。
- 不得把 model-dependent Provider 标为全局 supported。
- 不得在没有真实 TTS probe 的情况下让逐句播放认为配置可用。
- 不得新增第二套设置页或第二套主测试入口。

## 12. 验证要求

自动化测试至少覆盖：

- OpenAI TTS request path、headers、body 和 audio response validation。
- OpenRouter TTS model-dependent 状态、手动 model / voice 配置和 audio response validation。
- TTS probe 根据当前 language code 选择对应固定测试文本，并把结果写回该 language code 的 voice profile。
- 当前语言不被模型、voice 或路由支持时，返回稳定错误分类，不得误标为全局 TTS 可用。
- profile-level probe snapshot / result 能同时表达 text endpoint 和 TTS endpoint，且 capability row 不复用错误 endpoint metadata。
- text probe 与 TTS probe 的 partial 状态互不覆盖。
- language code 级 voice profile 不互相覆盖。
- 配置变更后当前 fingerprint 与 last successful configuration fingerprint 不一致，状态变为 requires retest。
- TTS saved probe 不覆盖 text profile 全局最近验证状态。
- draft probe 不写 Keychain、SQLite 或 validation event。
- 日志和 validation event 不包含测试文本、用户句子、请求体、响应体、audio bytes 和密钥。
- TTS response 超过大小限制、空音频、非音频 bytes、取消和超时都返回稳定错误分类。
- TTS audio artifact hit / miss / invalidated、原子写入、metadata 文件不一致恢复、LRU 或容量清理、policy 默认值、日志禁区和重复点击 in-flight 复用。

手动验证至少覆盖：

- iPhone：OpenAI 配置、测试、试听、改 voice 后需重测。
- iPhone：OpenRouter 手动 model / voice 配置、测试、试听、失败分类。
- iPad / macOS：共享设置页字段语义一致，结果面板可关闭和重试。
- 断网、错误 API Key、错误 voice、Provider 限流。

## 13. iOS AudioSession 管理约束

本节约束仅适用于 `#if os(iOS)` 分支；macOS 不使用 `AVAudioSession`，不受影响。

### 13.1 TTS 播放会话（`.playback` category）

- TTS 播放会话必须显式指定 `options: [.allowBluetoothA2DP]`，不得省略该选项。
- 原因：录音会话可能激活 BT HFP 双向通道（通话质量 8–16kHz）；HFP 退出是 OS 异步操作，TTS 播放若不显式请求 A2DP，可能沿用 HFP 路由，导致播放音质降级。`.playback` + `.spokenAudio` 模式下 A2DP 为默认路由，但显式指定可防止 HFP 路由残留导致的回退。
- `setCategory` 失败不得静默吞掉（`try?`），必须通过 OSLog warning 记录失败原因和当前 category，以便开发者通过 Console.app 排查会话冲突。`player.play()` 失败仍通过现有 engine error mapping 上报。
- `category=\(session.category.rawValue, privacy: .public)` 和 `error.localizedDescription` 可以标记 `.public` 记录；不得记录用户句子、API Key 或音频内容。

### 13.2 录音会话（`.playAndRecord` category）

- 录音会话不得使用 `.allowBluetoothHFP` 选项（蓝牙协议全双工双向通道），否则 BT 耳机切入通话模式后，会污染后续 TTS 播放路由。
- 当前使用 `.allowBluetooth`（iOS 17 deprecated）作为 BT 麦克风输入选项，兼容蓝牙耳机录音；deprecated 迁移路径见架构备忘录 `architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md §1.1`。
- 蓝牙协议限制：`.playAndRecord` + A2DP 互斥（全双工场景 A2DP 与麦克风不能共存），录音侧不使用 `.allowBluetoothA2DP`；该选项仅在 `.playback` 会话中有效。
- 录音结束必须调用 `setActive(false, options: .notifyOthersOnDeactivation)`，通知系统（和其他 App / session）录音会话已退出，降低 HFP 路由残留风险。

### 13.3 新增录音或 TTS 播放基础设施时的检查清单

- [ ] 是否在 TTS 播放会话（`.playback`）中显式设置 `options: [.allowBluetoothA2DP]`？
- [ ] 是否把 TTS 播放会话的 `setCategory` 失败从 `try?` 改为 OSLog warning soft-fail？
- [ ] 录音会话（`.playAndRecord`）是否避免使用 `.allowBluetoothHFP`？
- [ ] 录音结束是否调用 `setActive(false, options: .notifyOthersOnDeactivation)`？
- [ ] 是否在 macOS 路径的 `#if os(iOS)` 条件分支内处理，不影响 macOS 构建？

## 14. 可演进部分

- OpenRouter Models API 自动发现 speech-capable 模型。
- Provider voice 列表拉取和试听预览。
- Groq、Custom OpenAI-compatible、Gemini、Mistral、xAI、DashScope、Zhipu、SiliconFlow 接入。
- 本地 Apple `AVSpeechSynthesizer` 或第三方本地 TTS Provider。
- 流式 TTS 播放。
- TTS 音频跨设备同步、默认导出、可恢复备份和附件化。
- 用量估算和费用提示。

这些扩展如果改变隐私边界、同步边界、存储边界或商业模式，应先更新 spec 或 ADR。

## 14. 变更记录

- 2026-05-23：创建第一版 TTS Provider 配置、测试与播放前置规范。原因：语音模型配置与逐句播放前置方案已经跨 AI Provider、Data、Speech、隐私、诊断和设置页交互，必须从 active plan 提升为长期开发规范。影响范围：AI Provider 设置、TTS probe、Speech、Data schema、逐句播放、隐私披露和后续 Provider 扩展。是否需要 ADR：否，沿用 ADR-005 的本地优先和用户自带 Provider；若未来引入官方托管 TTS 或云端同步音频，再评估 ADR。
- 2026-05-23：补充 TTS probe 必须按当前语言空间目标语言选择固定测试文本，并将测试结果绑定到当前 language code 的 voice profile。原因：用户配置的语音模型或音色可能不支持当前语言空间语种，单一全局 TTS 成功状态会误导逐句播放可用性判断。
- 2026-05-23：补充逐句 TTS 音频必须通过本地媒体派生资产基础设施管理。原因：逐句播放方案采纳早期基础设施完整建设原则，TTS 音频不应作为临时 UI 缓存落地，而应作为本地优先、隐私敏感、可重建的派生媒体资产，为后续全文朗读、跟读录音、听写录音、音频同步和导出预留一致边界。
- 2026-05-23：收紧 TTS 音频校验和 preview 边界。原因：早期基础设施原则要求首次落地采用长期可扩展方案；TTS 配置测试不能以 AI 侧轻量响应校验替代音频验收，必须通过 Core 音频校验协议注入 Speech 实现。设置页 preview audio 只作为短生命周期试听资源，真实逐句播放音频复用必须依赖本地媒体派生资产基础设施。
- 2026-05-23：同步 TTS Provider 配置测试实施事实。原因：当前实现选择兼容扩展 `AIProviderConfigurationProbeResult` 和 `AIProviderDraftProbeSnapshot`，已经具备 endpoint metadata 与 TTS draft snapshot；Speech 层提供短生命周期 preview store / playback seam，voice profile 保留最近失败分类供可用性读取；同时明确 Provider 配置 `available` 只是逐句播放必要条件，不等于完整播放 ready 状态。
- 2026-05-23：同步本地媒体派生资产基础设施实施事实。原因：本地媒体派生资产与 TTS 音频缓存方案已落地 Core / Data / Speech 基础设施和测试；逐句播放规范需要把 media artifact 从“待建前置”更新为“已具备基础设施，但仍缺 playback coordinator / generation / UI 接入”。影响范围：Data、Speech、direct playback 方案、缓存命中、失效清理和隐私日志边界。是否需要 ADR：否，沿用 ADR-005；未来若默认同步、备份或导出音频再评估 ADR。
- 2026-05-23：补充设置页加载已保存 voice profile 的状态同步规则。原因：voice profile 是 language code 级状态源，重开设置页必须回填当前语言空间的 voice、format、speed、instructions，避免 UI 默认值覆盖用户配置。
- 2026-05-24：同步逐句 TTS generation / playback / coordinator 和 direct playback UI 接入实施事实。原因：真实单句 TTS 生成、持久音频播放、缓存优先、跨句协调、AppEnvironment 装配和共享 UI action contract 已落地；规范需从“播放前置缺失”更新为“第一阶段真实逐句播放已具备”。影响范围：Core、AI、Data、Speech、UI、AppEnvironment、project.yml、scripts/verify.sh 和页面清单。是否需要 ADR：否，沿用 ADR-005；后台播放、锁屏控制、批量预生成、同步导出和费用预算仍需独立方案。
- 2026-06-01：补充 reading sentence TTS source。原因：Reading vertical slice 已新增 `TTSSentenceSource.readingDocumentSentence(documentID:sentenceID:)`、media artifact owner/source columns 和阅读页显式 `听` action，不能与 Entry 或 LearningMaterial sentence cache key 混用。影响范围：Core TTS artifact key、Data media artifact metadata、Reading UI、AppEnvironment 和 Reading spec。是否需要 ADR：否，沿用本地优先派生媒体资产规则。
- 2026-06-16：新增 §13 iOS AudioSession 管理约束。原因：bug 修复 `docs/plans/done/2026-06-16-bug-tts-audio-session-hfp-routing.md` 揭示录音会话 `.allowBluetoothHFP` 激活 BT HFP 双向通道后，TTS 播放侧未显式请求 `.allowBluetoothA2DP` 会导致播放音质降级；该类问题属于 AudioSession 选项使用规范缺失，需要沉淀为长期约束。影响范围：Speech package TTS 播放会话、录音引擎会话选项、新增录音或 TTS 基础设施时的检查清单。是否需要 ADR：否，沿用本地优先和 Speech package 管理 AudioSession 语义的已有决策。
