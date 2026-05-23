# 任务方案：逐句 TTS 生成、播放与跨句协调基础设施

状态：Draft
类型：feature
创建日期：2026-05-24
最后更新日期：2026-05-24

审核状态：Reviewed - Ready for User Approval

## 用户确认记录

- 2026-05-23：逐句分析直接播放 TTS 音频方案确认交互方向：用户点击逐句分析中的听一句按钮时，不再弹出旧 `听一句` sheet，后续应直接播放本地音频或生成后自动播放。
- 2026-05-23：TTS Provider 配置与测试方案已完成，设置页已经承担 TTS 配置、真实 probe、目标语言固定测试文本、voice profile、配置 fingerprint、短生命周期 preview audio 和可播放配置读取接口。
- 2026-05-23：本地媒体派生资产与 TTS 音频缓存基础设施方案已完成，Core / Data / Speech 已具备 TTS audio artifact key、GRDB metadata、文件 staging / 原子移动、持久文件校验、命中、失效、清理和 policy 边界。
- 2026-05-24：用户询问剩余 generation / playback / coordinator 是否应创建新的独立方案文档。结论：应独立创建，因为该任务是跨 AI / Speech / Data / AppEnvironment / UI action contract 的服务层基础设施，不应继续膨胀 direct playback UI 方案。
- 2026-05-24：用户要求立即创建本独立方案文档。本方案仅创建实施方案，不实施代码；进入实现前仍需用户确认状态从 `Draft` 进入 `User Approved`。
- 2026-05-24：严格方案复查确认：当前方案方向正确，但必须按早期基础设施长期正确原则修订 AI / Data staging 边界、生产 HTTP client、secret resolver、coordinator 测试落点、ready artifact resolver、diagnostic allowlist 和后续扩展备忘录引用后，才具备实施条件。

## 1. 需求描述

`docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md` 的真实播放实现还缺少三个硬性前置：

1. 真实 TTS generation service：读取已测试可用的 TTS Provider 配置，使用用户显式点击的单句目标语言文本发起 TTS 请求，拿到音频 bytes 后交给本地媒体派生资产基础设施保存。
2. 正式 audio playback service：播放 App 管理目录中的持久 TTS 音频文件，支持播放、暂停、恢复、停止、生命周期释放和播放失败分类。
3. 跨句 playback coordinator / action contract：保证同一时间只处理一个 active sentence，处理重复点击、切换句子、生成完成后的 active key 校验、取消、缓存命中、配置不可用和 UI presentation state 广播。

这三项不应直接写进 `SentencePairView`。如果 UI 直接调用 Provider、Keychain、GRDB、文件路径或 AVFoundation，会破坏当前 SwiftUI 架构和模块边界。本方案要先建立可测试、可注入、可被三端 UI 复用的服务层基础设施，使后续 direct playback UI 方案只负责把听一句按钮接入 action contract。

本任务是基础设施任务，不以“最小改动接上按钮”为目标。若现有 probe 命名、App-only coordinator、文件 resolver 或包边界不适合长期复用，本任务应重构为长期正确的通用边界，不为早期临时代码背兼容包袱。

## 2. 现状描述

当前已具备：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSProviderConfiguration.swift` 已定义 `TTSVoiceProfile`、`TTSProviderSettings`、`TTSAudioFormat`、TTS configuration fingerprint 和 `PlayableTTSConfiguration`。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift` 已能根据 language code 读取播放可用性，区分 `available`、`notConfigured`、`notTested`、`requiresRetest`、`failedLastTest`、`credentialMissing` 和 `unsupportedProvider`。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSProviderAdapter.swift` 已有 OpenAI / OpenRouter Audio Speech request builder。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderProbeHTTPClient.swift` 已提供设置页 probe 使用的 HTTP client，但命名、错误模型和一次性 body 读取语义仍是 probe-oriented，不应原样作为逐句 TTS 生产请求基础设施。
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift` 已能查询和提交 TTS audio artifact，提交时会持久文件校验、移动 staged file、mark ready，并在 metadata / 文件不一致时按 artifact 精确失效。
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactFileStore.swift` 已能在 App 管理 root 下写 staging file、移动文件、校验相对路径并提供 internal absolute URL；该 concrete 位于 Data package，AI / Speech package 不得直接 import Data concrete。
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioFileValidator.swift` 已提供持久 TTS 文件校验 seam。
- `LangoTraceApp/AppEnvironment.swift` 已为设置页 TTS probe / preview 装配 `DefaultTTSAudioValidationService`、`InMemoryTTSAudioPreviewStore` 和 `DefaultTTSAudioPreviewPlaybackService`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift` 中 `SentencePairView` 已删除旧 sheet，只保留 `isLocalPlaybackActive.toggle()` 的临时原位反馈。

当前缺口：

- `LangoTraceAI` 没有正式单句 TTS generation service；现有 adapter 只构造请求，probe service 只服务设置页测试。
- `LangoTraceAI` 当前 `loadDefaultPlayableTTSConfiguration(languageCode:)` 只验证 Keychain secret 可解析并返回 configuration status，不返回短生命周期 plaintext secret；逐句 generation 必须新增明确的 secret resolver / generation input 边界。
- `LangoTraceAI` 当前 HTTP client 只有 `AIProviderProbeHTTPClient`，真实逐句 TTS 请求需要通用生产 client contract，不能继续以 probe-only 类型承载生产能力。
- `LangoTraceSpeech` 没有正式播放 App 管理目录中持久音频文件的 service；`DefaultTTSAudioPreviewPlaybackService` 只适用于设置页短生命周期 preview。
- `LangoTraceCore` 尚未定义逐句播放请求、presentation state、coordinator 协议和稳定错误分类。
- `LangoTraceCore` 尚未定义 AI generation 与 Data staging 之间的抽象协议；若 AI service 直接使用 `LocalMediaArtifactFileStore` 会反向依赖 Data concrete。
- `LangoTraceApp` 尚未装配 generation service、media artifact store、playback service 和 coordinator；当前也没有稳定 App test target，不能把全部状态机只留在 App target 中测试。
- UI action contract 尚未存在，后续 direct playback UI 无法在不越界的情况下调用真实生成 / 播放。

## 3. 目标

本任务完成后，应达到以下目标：

1. 提供 `SentenceAudioPlaybackCoordinator` 或等价服务，作为逐句 TTS 播放的唯一编排入口。
2. 提供 `SentenceAudioPlaybackActions` 或等价 UI action contract，UI 只能通过该 contract 查询状态和发送点击意图。
3. 提供真实 TTS generation service，复用已测试可用的 `PlayableTTSConfiguration`、短生命周期 secret resolver、OpenAI / OpenRouter adapter 和生产级安全 HTTP client。
4. 提供 Core-level staging writer / playback source resolver 协议，Data package 实现 App 管理目录下的 staging 和 ready artifact URL 解析；AI / Speech 不直接依赖 Data concrete。
5. generation service 成功返回音频后，必须先通过 staging writer 和 `LocalMediaArtifactStore` 写入持久 TTS audio artifact，再交给正式 playback service 播放。
6. playback service 只播放通过 ready artifact resolver 解析出的 App 管理目录文件，不播放 UI 或任意调用方传入的绝对路径。
7. 同一时间只允许一个 active sentence 处于 generating / playing / paused 主状态；切换句子必须取消或降级上一句。
8. 重复点击同一句不得重复发起 Provider 请求；缓存命中时不得调用 Provider。
9. TTS 配置未配置、未测试、已变更需重测、上次测试失败、凭证缺失或 Provider 不支持时，coordinator 返回可渲染的 `requiresConfiguration` / `requiresRetest` / `failed` 状态，不发起外部请求。
10. 生成完成时必须再次校验 active key；如果用户已切换到另一句，旧结果只能保存 artifact，不得自动抢占播放。
11. 日志和诊断必须使用 Core typed event / allowlisted attribute，不得记录完整用户句子、完整请求体、完整响应体、audio bytes、API Key、Authorization header、完整 Keychain account、完整文件路径或完整 voice id。

## 4. 范围

本任务范围：

- Core 逐句音频 request、presentation state、错误分类、action contract、coordinator 协议、generation input / output、staging writer 协议和 ready artifact playback source resolver 协议。
- AI 单句 TTS generation service，复用现有 TTS adapter、短生命周期 secret resolver、生产 HTTP client 和 response validator。
- 将 `AIProviderProbeHTTPClient` 的可复用部分提升为生产级 `AIProviderHTTPClient` 或等价通用 contract，并让设置页 probe 继续复用该通用 client。
- Speech 正式持久文件 playback service，独立于设置页 preview playback。
- 可测试 coordinator 状态机核心，优先放在 Swift package 中；App / 服务层只负责串联 TTS 可用性、缓存查询、生成、artifact commit、播放和状态广播的 production assembly。
- AppEnvironment 生产装配 seam。
- Core / AI / Speech / Data / UI action contract 的聚焦单元测试。
- 更新 `docs/spec/011-tts-provider-configuration-and-playback.md` 中“当前已落地边界”和后续 UI direct playback 前置状态。

本任务不做：

- 不把 `SentencePairView` 听一句按钮接入真实播放；这属于 `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md` 后续 UI 实施。
- 不改变 TTS Provider 设置页、voice profile 表单或 probe 结果 UI。
- 不新增 Provider 支持范围；第一阶段只复用已落地的 OpenAI / OpenRouter Audio Speech adapter。
- 不实现后台播放、锁屏控制、远程控制中心、音频 session 完整策略或系统中断完整恢复。
- 不实现批量预生成、全文朗读、单句循环、慢速播放、跟读录音、听写录音、ASR 或评分。
- 不改变 Entry、LearningMaterial、sentence rendering 或 Prompt 输出结构。
- 不实现音频同步、导出默认包含、可恢复备份或附件 manifest。
- 不实现 TTS 成本预算 UI、额度阈值、Provider 用量统计或批量队列；但本任务必须保留非敏感 usage bucket / failure category 诊断扩展点。

## 5. 证据与决策依据

产品依据：

- 语迹的听说闭环需要逐句播放高频、低摩擦，但用户生活句子仍是敏感内容；只有用户显式点击单句播放时才可调用外部 TTS Provider。
- TTS Provider 可能收费，同一句同配置重复播放必须优先命中本地 artifact，避免重复扣费。
- 播放按钮的行为应是即时听音频，旧解释型 sheet 已被删除，不能通过重新引入弹窗回避服务层缺口。

架构依据：

- `docs/spec/004-swiftui-architecture.md` 要求 AI、TTS、OCR、Speech、Sync 通过协议或服务层进入 UI，View 不直接访问网络、Keychain、SQLite、文件系统或 AVFoundation 具体实现。
- `docs/spec/011-tts-provider-configuration-and-playback.md` 已定义逐句播放期推荐边界：UI -> action contract -> coordinator -> TTS availability / AI generation / Data artifact store / Speech playback。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已接受低摩擦单句 TTS 边界，但明确禁止页面展示、滚动、保存记录、进入详情、批量预生成、照片、音频、OCR、历史记忆或多条 Entry 上下文复用该边界。

数据一致性依据：

- TTS audio artifact key 已包含 sentence source、文本 hash、目标语言、provider profile、endpoint、voice profile、adapter kind / version、model、voice hash、format、参数 hash 和 configuration fingerprint；coordinator 必须使用该 key 查询和提交 artifact。
- 本地媒体派生资产基础设施已经区分 pending / ready，coordinator 不能在文件 ready 前暴露播放。
- metadata 命中但文件缺失或 hash 不匹配时，`LocalMediaArtifactStore` 会返回 invalidated；coordinator 必须把 invalidated 当作 miss 处理并重新生成或失败。

## 6. 涉及的代码文件路径

预计新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlayback.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceTTSGeneration.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/MediaArtifactPlaybackSource.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/SentenceTTSGenerationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPClient.swift`，或将现有 `AIProviderProbeHTTPClient.swift` 重构为通用 production-safe contract 后保留兼容 typealias。
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentenceAudioPlaybackCoordinatorModel.swift` 或 `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`，用于放置不依赖 SwiftUI concrete / App target 的可测试状态机核心。
- `LangoTraceApp/SentenceAudioPlaybackAssembly.swift`，用于 AppEnvironment production 装配。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceTTSGenerationContractTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/SentenceTTSGenerationServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderHTTPClientTests.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/TTSAudioPlaybackServiceTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactPlaybackSourceResolverTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/SentenceAudioPlaybackCoordinatorModelTests.swift`，若 coordinator 状态机核心放在 UI package；若放在 Core package，则对应测试放入 `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/`。
- `LangoTraceAppTests/SentenceAudioPlaybackAssemblyTests.swift`，仅当本任务同步新增可运行 App test target；否则不得把关键状态机覆盖依赖 App target 测试。

预计修改：

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderProbeHTTPClient.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactFileStore.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/MediaArtifact.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`，仅用于暴露 UI action contract 所需的 store seam，不接真实按钮。
- `LangoTraceApp/AppEnvironment.swift`
- `project.yml`，仅当新增 App test target 或需要把 coordinator 文件纳入 target。
- `scripts/verify.sh`，仅当新增可运行测试 target 后需要加入完整验证入口。

可能修改：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticLogger.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBDiagnosticEventRepository.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`，仅当 action state 需要新增非按钮 UI 文案 key；本任务默认不接 `SentencePairView`，因此应尽量不改 UI 文案。

## 7. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioFileValidation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSProviderConfiguration.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSProviderAdapter.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSAudioResponseValidator.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactFileStore.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioValidationService.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioFileValidator.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `LangoTraceApp/AppEnvironment.swift`

## 8. 涉及的文档路径

本方案创建：

- `docs/plans/active/2026-05-24-feature-sentence-tts-generation-playback-coordinator.md`
- `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`

本方案依赖：

- `docs/plans/done/2026-05-23-feature-tts-provider-configuration-test.md`
- `docs/plans/done/2026-05-23-feature-local-media-artifact-store-and-tts-audio-cache.md`
- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`

本任务实施前必须读取并记录采纳情况：

- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md`
- `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`

本任务实施完成后按影响更新：

- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md`
- `docs/platform-page-inventory.md`，仅当可见页面能力边界发生变化。
- `docs/testing/README.md`，仅当新增正式手动播放验证入口。
- `docs/review/INDEX.md` 或专项审查记录，若 Provider、隐私、包边界、验证脚本或 AppEnvironment 装配发生高风险变更。

## 9. 设计方案

### 9.1 模块边界

目标依赖方向：

```text
Core -> no concrete dependency
AI -> Core
Data -> Core
Speech -> Core
App Shell -> AI / Data / Speech / UI
UI -> Core protocols and injected actions
```

严格禁止新增以下依赖：

- `LangoTraceAI -> LangoTraceData`
- `LangoTraceSpeech -> LangoTraceData`
- `LangoTraceUI -> LangoTraceAI / LangoTraceData / LangoTraceSpeech concrete`
- `LangoTraceCore -> SwiftUI / AVFoundation / URLSession / GRDB / Keychain`

逐句播放链路：

```text
SentencePairView, later task
-> SentenceAudioPlaybackActions
-> SentenceAudioPlaybackCoordinator
-> AIProviderConfigurationService.loadDefaultPlayableTTSConfiguration(languageCode:)
-> AIProviderCredentialResolver or equivalent short-lived secret resolver
-> LocalMediaArtifactStore.ttsAudioArtifact(for:)
-> SentenceTTSGenerationService.generateSpeech(...)
-> TTSAudioStagingWriting.stageTTSAudio(...)
-> LocalMediaArtifactStore.commitTTSAudioArtifact(...)
-> MediaArtifactPlaybackSourceResolving.resolveReadyPlaybackSource(...)
-> TTSAudioPlaybackService.play(source:)
```

禁止：

- UI 直接调用 `TTSProviderAdapter`、Keychain、GRDB、`LocalMediaArtifactFileStore` 或 AVFoundation。
- AI package 持有播放状态、AVAudioPlayer 生命周期或 media artifact metadata repository。
- Speech package 读取 Provider secret、构造 Provider HTTP request 或写 GRDB。
- Data package 发起 Provider 请求或播放音频。
- coordinator 记录完整句子、完整请求体、完整响应体、audio bytes、API Key、Authorization header、完整 Keychain account、完整文件路径或完整 voice id。

### 9.2 Core 契约

新增 Core 类型建议：

```swift
public struct SentenceAudioKey: Equatable, Hashable, Sendable {
    public var sentenceSource: TTSSentenceSource
    public var sentenceTextHash: String
    public var targetLanguageCode: String
    public var configurationFingerprint: String
}

public struct SentenceAudioRequest: Equatable, Sendable {
    public var languageSpaceID: String
    public var owner: MediaArtifactOwner
    public var sentenceSource: TTSSentenceSource
    public var sentenceIndex: Int
    public var targetText: String
    public var targetLanguageCode: String
}

public enum SentenceAudioPresentationState: Equatable, Sendable {
    case idle
    case generating
    case playing
    case paused
    case requiresConfiguration(SentenceAudioConfigurationIssue)
    case failed(SentenceAudioPlaybackFailure)
}
```

Core 还必须定义以下协议或等价边界：

```swift
public protocol TTSAudioStagingWriting: Sendable {
    func stageTTSAudio(
        _ bytes: Data,
        operationID: DiagnosticOperationID
    ) async throws -> MediaArtifactStagedFileReference
}

public struct MediaArtifactPlaybackSource: Equatable, Sendable {
    public var artifactID: String
    public var fileURL: URL
    public var mimeType: String
    public var byteSize: Int64
}

public protocol MediaArtifactPlaybackSourceResolving: Sendable {
    func resolveReadyPlaybackSource(for artifact: MediaArtifact) async throws -> MediaArtifactPlaybackSource
}

public protocol SentenceTTSGenerating: Sendable {
    func generateSpeech(_ request: SentenceTTSGenerationRequest) async throws -> SentenceTTSGenerationResult
}

public protocol TTSAudioPlaying: Sendable {
    func play(_ source: MediaArtifactPlaybackSource, operationID: DiagnosticOperationID) async throws
    func pause() async
    func resume() async throws
    func stop() async
}
```

`MediaArtifactPlaybackSource.fileURL` 只能由 Data package 的 resolver 从 App 管理 root + ready artifact relative path 解析得到；UI、AI 和调用方不得自行构造该 URL。

`SentenceAudioPlaybackFailure` 必须能区分：

- TTS 配置不可用。
- 凭证缺失。
- 配置未测试。
- 配置需要重测。
- 上次测试失败。
- Provider 不支持。
- 网络失败。
- 鉴权失败。
- 非音频响应。
- 音频过大。
- media artifact 写入失败。
- 持久文件校验失败。
- 播放失败。
- 用户取消。
- staging 写入失败。
- playback source 解析失败。
- 文件播放期间缺失或不可读。
- AudioSession / AVFoundation 初始化失败。
- 速率限制或额度耗尽。

### 9.3 TTS generation service

`SentenceTTSGenerationService` 负责：

1. 接收 `PlayableTTSConfiguration`、plaintext secret、目标句文本、operation id。
2. 根据 `TTSProviderSettings.adapterKind` 选择 OpenAI 或 OpenRouter Audio Speech adapter。
3. 使用生产级 `AIProviderHTTPClient` 或等价通用 client 发起 request。该 client 必须支持 request timeout、取消传播、最大 body 字节数、HTTP status 分类、content type 读取和非敏感响应摘要。
4. 限制 response body 最大字节数。第一版逐句播放上限与持久文件校验上限保持一致或更严格，默认不超过 25 MB；设置页 probe 仍可使用更小上限。
5. 使用 `TTSAudioResponseValidator` 验证 status code、content type、格式和音频 bytes。
6. 通过注入的 `TTSAudioStagingWriting` 写入 staging area；AI package 不直接 import `LangoTraceData` 或 `LocalMediaArtifactFileStore`。
7. 返回 `MediaArtifactStagedFileReference`、mime type、byte size、duration 和非敏感诊断摘要。

generation service 不负责：

- 查询或写入 media artifact metadata。
- 播放音频。
- 持有 UI 状态。
- 读取 SwiftUI view state。
- 直接读取 Keychain concrete。
- 直接依赖 Data package concrete。

Secret 边界：

- `AIProviderConfigurationService.loadDefaultPlayableTTSConfiguration(languageCode:)` 继续只表达配置可用性，不把 plaintext secret 放入可长期保存的 config model。
- 本任务新增 `PlayableTTSSecretResolving` 或等价短生命周期 resolver，由 App / coordinator 在用户显式点击后解析 Keychain secret，并立即传入 generation request。
- resolver 只返回内存中的 `AIProviderResolvedSecret` 或 plaintext value，不写数据库、日志、diagnostic event、请求预览或 UI state。
- Provider 不需要 secret 的未来本地 Provider 可返回 nil secret，但 OpenAI / OpenRouter 第一阶段必须要求 present secret。

HTTP client 边界：

- `AIProviderProbeHTTPClient` 不能继续作为唯一生产请求抽象。实现时应新增 `AIProviderHTTPClient` / `AIProviderHTTPResponse` / `AIProviderHTTPClientError`，或重构现有文件为通用命名并让 probe type 兼容转发。
- 生产 client 的错误分类至少区分：cancelled、timedOut、networkUnavailable、rateLimited、quotaExceeded、authenticationFailed、providerRejected、invalidHTTPResponse、responseTooLarge。
- response body 超限时必须停止处理并返回稳定错误；不得为了验证音频把超限 bytes 写入 staging。

### 9.4 正式 playback service

`TTSAudioPlaybackService` 负责：

1. 根据 `MediaArtifactPlaybackSource` 打开文件；该 source 只能由 Data package resolver 对 ready artifact 解析得到。
2. 播放、暂停、恢复、停止当前音频。
3. 暴露当前播放状态变化。
4. 在播放完成、失败、取消或 service deinit 时释放资源。
5. 第一版明确只支持前台播放，不承诺后台播放、锁屏控制或远程控制中心。

第一版可以使用 AVFoundation，但 AVFoundation 具体类型不得进入 Core 或 UI 公共契约。

Playback source resolver 负责：

- 验证 artifact 未 invalidated。
- 验证 artifact type 为 `.ttsSentenceAudio` 且 relative path 安全。
- 使用 App 管理 media artifact root 解析 internal URL。
- 读取文件 info 并再次核对 byte size / content hash。
- 文件缺失、hash 不匹配或 artifact 非 ready 时返回稳定失败，不让 playback service 直接猜测。

### 9.5 Coordinator 状态机

Coordinator 处理点击：

1. 如果点击当前 playing 句子：暂停。
2. 如果点击当前 paused 句子：恢复。
3. 如果点击当前 generating 句子：取消 generation、删除未提交 staging、进入 idle 或 cancelled presentation。
4. 如果点击另一句：停止当前播放，取消当前生成任务，切换 active key。
5. 读取当前 language code 的 playable TTS configuration。
6. 不可用时进入 `requiresConfiguration` 或 `failed`，不发起外部请求。
7. 在用户显式点击后解析短生命周期 secret。
8. 计算完整 `TTSAudioArtifactKey`。
9. 查询 `LocalMediaArtifactStore.ttsAudioArtifact(for:)`。
10. hit：通过 playback source resolver 解析 ready source，播放本地 artifact。
11. miss / invalidated：进入 `generating`，调用 generation service。
12. generation 成功后提交 artifact。
13. 提交成功后确认 active key 仍一致。
14. active key 一致：解析 ready playback source 并播放新 artifact。
15. active key 已变化：只保留 artifact，不自动播放。

Coordinator 必须处理：

- 同一句重复点击导致的 in-flight 复用或取消。
- Provider 返回非音频。
- generation 取消后不得写成功诊断。
- artifact commit 失败后不得留下 ready metadata。
- playback 失败后状态进入 `failed(.playbackFailed)`。
- Entry 切换、语言空间切换、页面销毁和 App 进入后台时停止播放并取消 generation。
- cache hit 后必须调用 repository `markAccessed` 或通过 store facade 更新 last accessed；若当前 facade 没有暴露该能力，本任务应补充。
- cleanup 与正在播放文件的关系：第一版不做后台清理调度，但 resolver / playback service 必须能把播放期间文件缺失映射为稳定 playback source 或 playback failure。

Coordinator 测试落点：

- 状态机核心不得只放在 App target。优先放入 Core package；如果需要 `@MainActor ObservableObject` presentation model，可放入 UI package，但底层 transition reducer 应保持纯 Swift 可测试。
- App Shell 文件只做 production assembly，不承载无法通过 package tests 覆盖的核心逻辑。
- 若本任务决定新增 App test target，则必须同步更新 `project.yml` 和 `scripts/verify.sh`；否则完成标准不得依赖 App target 单元测试。

### 9.6 诊断和隐私

允许记录：

- operation id。
- provider preset id。
- endpoint purpose。
- model name。
- output format。
- text length bucket。
- byte size bucket。
- duration bucket。
- cache hit / miss / invalidated。
- generation lifecycle：started / succeeded / failed / cancelled。
- playback lifecycle：started / paused / resumed / stopped / completed / failed。
- failure category。
- elapsed milliseconds。

不得记录：

- 用户句子文本。
- 完整请求体。
- 完整响应体。
- audio bytes。
- API Key。
- Authorization header。
- 完整 Keychain account。
- 自定义敏感 header。
- 完整 voice id；默认记录 hash 或是否存在。

需要新增或扩展 Core typed diagnostics：

- `DiagnosticEventName.sentenceTTSGenerationStarted`
- `DiagnosticEventName.sentenceTTSGenerationSucceeded`
- `DiagnosticEventName.sentenceTTSGenerationFailed`
- `DiagnosticEventName.sentenceTTSGenerationCancelled`
- `DiagnosticEventName.sentenceAudioPlaybackStarted`
- `DiagnosticEventName.sentenceAudioPlaybackPaused`
- `DiagnosticEventName.sentenceAudioPlaybackResumed`
- `DiagnosticEventName.sentenceAudioPlaybackStopped`
- `DiagnosticEventName.sentenceAudioPlaybackCompleted`
- `DiagnosticEventName.sentenceAudioPlaybackFailed`

需要新增或复用 allowlisted attributes：`endpointPurpose`、`providerPresetID`、`modelName`、`durationMilliseconds`、`errorCategory`、`operationID`、`outputFormat`、`textLengthBucket`、`byteSizeBucket`、`durationBucket`、`cacheResult`、`adapterKind`。不得新增任意 key / value 日志入口。

## 10. 实施方案

### 10.1 实施前检查

实施前运行：

```bash
git status --short
rg -n "SentenceAudio|TTSAudio|TTSProvider|LocalMediaArtifactStore|SpeechService|playback coordinator|直接播放" docs Packages LangoTraceApp
```

必须确认：

- TTS Provider 配置测试方案仍在 `docs/plans/done/`，且当前代码仍有 playable TTS configuration 读取接口。
- 本地媒体派生资产方案仍在 `docs/plans/done/`，且 `LocalMediaArtifactStore` 可查询、提交、失效和清理 TTS audio artifact。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 仍保持单句显式点击低摩擦边界。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`、`docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md` 和 `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` 已被读取；本方案实施记录必须写明采纳了哪些提醒，哪些暂不采纳。
- 当前 `project.yml` 是否已有 App test target；若没有，必须选择“新增 App test target”或“把 coordinator 核心下沉到 package tests”中的一种，不能留下未测试核心逻辑。

### 10.2 TDD 步骤

1. Core 先写 `SentenceAudioPlaybackTests`，覆盖 state enum、configuration issue、failure category、request 不记录敏感字段、staging writer contract、playback source resolver contract 和 typed diagnostic allowlist。
2. Core 或 UI package 先写 coordinator transition tests，覆盖 cache hit、cache miss generation、invalidated 后重生成、重复点击取消、playing pause、paused resume、切换句子、生成完成时 active key 已变化、配置不可用、secret 缺失、commit 失败、playback source 解析失败和 playback 失败。
3. AI 先写 `AIProviderHTTPClientTests`，覆盖 timeout、cancelled、network unavailable、non-HTTP response、response too large、status code 分类和 content type 传递。
4. AI 先写 `SentenceTTSGenerationServiceTests`，覆盖 OpenAI / OpenRouter request 选择、secret 注入、response size limit、非音频响应、rate limit / quota / auth 映射、取消、staging writer 不被超限响应调用和诊断禁区。
5. Data 先写 playback source resolver tests，覆盖 ready artifact source 解析、relative path 防穿越、文件缺失、content hash mismatch、invalidated artifact 和 mark accessed。
6. Speech 先写 `TTSAudioPlaybackServiceTests`，通过 fake audio engine 或 protocol seam 覆盖 play / pause / resume / stop / completion / failure，不依赖真实扬声器。
7. 再实现最小生产代码，使每组聚焦测试通过。
8. 最后装配 `AppEnvironment` production graph，但不接 `SentencePairView`。

### 10.3 分阶段提交建议

每个阶段通过聚焦测试后单独 commit：

1. Core playback / generation / resolver / diagnostic contracts and tests。
2. AI production HTTP client, secret resolver boundary, sentence TTS generation service and tests。
3. Data staging writer / playback source resolver and tests。
4. Speech persistent playback service and tests。
5. Coordinator state machine and tests。
6. AppEnvironment assembly and documentation updates。

## 11. 复查方法

复查时按以下问题逐项检查：

- UI 是否仍不能直接访问 Provider、Keychain、GRDB、文件路径或 AVFoundation。
- generation service 是否只负责请求和 staging，不写 metadata、不播放。
- AI package 是否没有 import Data package concrete；Speech package 是否没有 import Data package concrete。
- production TTS 请求是否使用通用 `AIProviderHTTPClient`，而不是 probe-only client contract。
- plaintext secret 是否只存在于用户点击后的短生命周期 service call 中，不进入 config model、日志、数据库或 UI state。
- playback service 是否只播放 App 管理目录下 ready artifact resolver 产出的 source，不接受任意 UI 路径。
- coordinator 是否是唯一 active sentence 状态源。
- cache hit 是否不发起 Provider 请求。
- miss / invalidated 是否只在用户显式点击后发起请求。
- 生成完成后 active key 已变化时是否不会抢占播放。
- 取消、页面销毁和语言空间切换是否释放播放和生成资源。
- 诊断是否没有完整句子、请求体、响应体、audio bytes 和 secret。
- 未来后台播放、AudioSession、同步导出、批量预生成和成本预算是否仍只记录在 architecture notes 中，没有被当前任务偷偷实现。

## 12. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter SentenceAudioPlaybackTests
swift test --package-path Packages/LangoTraceCore --filter SentenceTTSGenerationContractTests
swift test --package-path Packages/LangoTraceAI --filter SentenceTTSGenerationServiceTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderHTTPClientTests
swift test --package-path Packages/LangoTraceSpeech --filter TTSAudioPlaybackServiceTests
swift test --package-path Packages/LangoTraceData --filter LocalMediaArtifactStoreTests
swift test --package-path Packages/LangoTraceData --filter MediaArtifactPlaybackSourceResolverTests
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
swift test --package-path Packages/LangoTraceUI --filter SentenceAudioPlaybackCoordinatorModelTests
```

完整验证：

```bash
scripts/verify.sh
```

文档轻量验证：

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如果新增 App test target，必须同步更新 `project.yml` 和 `scripts/verify.sh`，并在本方案实施记录中写明新 target 的运行命令和结果。

## 13. 文档影响检查

本任务涉及 AI Provider、TTS、隐私、媒体派生资产、AppEnvironment 和包边界。实施完成后必须检查：

- `docs/spec/011-tts-provider-configuration-and-playback.md` 是否从“尚未装配逐句播放 coordinator”更新为当前事实。
- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md` 是否把本方案标记为已完成前置，并保留 UI 接入剩余范围。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 是否仍准确表达单句显式点击边界。
- `docs/platform-page-inventory.md` 是否需要记录学习页仍未接 UI，或后续接入后记录新能力。
- `docs/review/INDEX.md` 是否需要新增专项审查记录；若 AppEnvironment、包边界或验证脚本发生实际变更，应触发文档影响检查。
- `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` 是否仍准确；若本任务把其中某条提升为正式实现，必须同步写入 `docs/spec/011-tts-provider-configuration-and-playback.md` 或正式 architecture 文档。

## 14. 实施记录

- 2026-05-24：创建方案。当前仅记录 generation / playback / coordinator 基础设施边界，不实施代码。进入实现前需要用户确认方案状态进入 `User Approved`。
- 2026-05-24：根据严格架构复查修订方案。补充早期基础设施长期正确原则下的重构要求：AI / Data staging 通过 Core 协议解耦，probe HTTP client 升级为生产级通用 client，secret 解析采用短生命周期 resolver，coordinator 状态机核心必须放入可测试 package，playback 只接受 ready artifact resolver 产物，逐句 TTS 诊断必须走 typed allowlist，并新增架构备忘录记录暂不实现但会影响后续边界的后台播放、AudioSession、同步导出、批量预生成和成本预算问题。

## 15. 完成标准

本任务完成时必须同时满足：

- Core 已有逐句音频 request、key、presentation state、错误分类和 action / coordinator 协议。
- Core 已有 generation input / output、staging writer、playback source resolver、playback service 和 typed diagnostic allowlist contract。
- AI 已有正式单句 TTS generation service，能复用已测试可用配置、短生命周期 secret、OpenAI / OpenRouter adapter、生产级 HTTP client 和 response validator，且 AI package 不依赖 Data concrete。
- Data 已实现 staging writer 和 ready artifact playback source resolver，能校验 ready artifact、relative path、文件存在性、byte size、content hash 和 last accessed。
- Speech 已有正式持久音频 playback service，能 play / pause / resume / stop，并隔离 AVFoundation 具体实现。
- Coordinator 能处理 cache hit、miss、invalidated、生成、commit、播放、暂停、切句、取消、active key 校验和失败状态。
- Coordinator 状态机核心已通过 package-level 单元测试覆盖，不依赖未建立的 App test target。
- AppEnvironment 已能装配生产 coordinator 所需依赖，但 direct playback UI 方案尚未接入按钮。
- 单元测试覆盖并发、取消、错误、状态同步、缓存一致性和隐私日志禁区。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。
- 文档影响检查完成，`011` 和 direct playback active plan 不再描述本方案能力为缺失。

## 16. 剩余风险

- 第一版只做前台播放，不处理后台播放、锁屏控制、远程控制中心和完整音频中断恢复；后续若进入这些能力，需要独立方案。
- 第一版只做 production-safe non-streamed request；如果后续接入 streaming TTS，需要重新设计 partial audio、播放开始延迟、取消和缓存策略。
- OpenAI / OpenRouter 以外 Provider 不在本任务范围内；后续 Provider 扩展必须先更新能力矩阵和 adapter tests。
- 如果 App test target 仍未建立，AppEnvironment 装配只能通过 package tests + 构建验证间接覆盖；核心 coordinator 状态机不得因此缺少自动化测试。
- TTS 外部请求可能产生费用和速率限制；本任务只保证用户显式点击、缓存优先和重复点击不重复请求，不实现额度预算 UI。
- 真实播放 UI 尚不在本任务范围内；本方案完成后仍需执行 direct playback UI 方案，才能让用户在 `SentencePairView` 中实际触发播放。
