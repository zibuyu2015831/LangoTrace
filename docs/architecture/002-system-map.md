# LangoTrace 系统地图

状态：Accepted
最后核对：2026-05-26
代码快照：94919d3bc7823f127979e6c455dbc2f8165fd5f9

本文档是当前工程结构的快速地图，吸收 VMark `dev-docs/architecture.md` 的短路径系统视图，但不替代 ADR、spec、任务方案或代码。本文档只描述当前代码和已明确标记的未来能力；如果代码继续演进，必须更新 `最后核对` 和 `代码快照`。

## 1. 系统形态

LangoTrace 当前是 SwiftUI Multiplatform App，使用 XcodeGen 生成 Xcode 工程，面向 iPhone、iPad 和 macOS 三端。

当前工程由一个 App target 和多个本地 Swift Package 组成：

- `LangoTraceApp/`：App 入口、环境装配、启动状态和跨 package action 组装。
- `Packages/LangoTraceCore/`：领域模型、协议、状态枚举、故障分类和与平台无关的业务契约。
- `Packages/LangoTraceData/`：SQLite / GRDB、Repository、migration、本地媒体派生资产和设置能力数据。
- `Packages/LangoTraceAI/`：AI Provider 配置服务、Keychain credential store、Provider probe、学习材料生成和 TTS 生成适配。
- `Packages/LangoTraceSpeech/`：TTS 音频校验、preview playback、系统播放边界和前台练习录音 service。
- `Packages/LangoTraceSync/`：同步包边界和 disabled sync service；真实同步仍未实现。
- `Packages/LangoTraceUI/`：共享 SwiftUI 页面、三端布局、状态 store、设置页、AI Provider UI 和 TTS 播放 action seam。
- `LangoTraceAppTests/`、`Packages/*/Tests/`、`Tests/Tooling/`：App 装配、package 单元测试和宿主机工具测试。

当前真实能力边界：

- 已实现：首次启动路由、语言空间 SQLite / GRDB 持久化、AI Provider 本地配置和 Keychain secret 分离、AI Provider 合成 probe、learning content GRDB 主路径、TTS 配置和逐句播放 coordinator、local media artifact / TTS audio cache、单句跟读 practice session / recording metadata 和前台麦克风录音保存。
- 未完成：完整生活记录时间线、照片 / 音频附件主数据、FTS、导出、真实同步、Photos / Camera / Speech Recognition / OCR 权限接入、StoreKit、发布材料、发音评分、听写、回译和完整 Prompt Preset 执行链路。

## 2. App 和 Package 入口点

| 边界 | 当前入口 | 作用 |
| --- | --- | --- |
| Xcode 工程 | `project.yml` | 定义 iOS、macOS、App tests、package 依赖、本地化清单和 schemes。 |
| App 入口 | `LangoTraceApp/LangoTraceApp.swift` | 启动 SwiftUI App，注入 `AppEnvironment` 和 session state。 |
| 环境装配 | `LangoTraceApp/AppEnvironment.swift` | 装配 database、repositories、AI credential store、Provider actions、learning material actions、TTS playback coordinator、practice recording actions、Speech / Sync disabled service。 |
| TTS 装配 | `LangoTraceApp/SentenceAudioPlaybackAssembly.swift` | 组装 TTS 配置、生成、artifact cache、playback source resolver 和 player。 |
| 练习录音装配 | `LangoTraceApp/PracticeActionsAssembly.swift` | 组装 practice repository、recording service、App practice recording engine 和 local media artifact store，向 UI 暴露 `PracticeActions`。 |
| Core | `Packages/LangoTraceCore/Sources/LangoTraceCore/` | 定义跨包共享模型、协议和失败分类。 |
| Data | `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift` | 统一 SQLite / GRDB 打开、migration 注册和测试数据库初始化。 |
| AI | `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift` | 保存 Provider profile、endpoint、Keychain reference、probe 和 TTS 设置。 |
| Speech | `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/` | TTS audio validation、preview playback 和系统音频播放实现边界。 |
| Sync | `Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift` | 当前只表达同步服务边界和 disabled 状态。 |
| UI | `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift` | Welcome / Onboarding / Main 路由和三端主界面入口。 |
| 验证 | `scripts/verify.sh` | 当前完整工程验证入口。 |

## 3. 关键运行时对象

- `AppEnvironment`：App 层依赖装配中心；负责把 Data、AI、Speech、Sync 的实现组合为 UI 可调用 action，不把 SQLite、Keychain 或网络细节直接暴露给 SwiftUI 页面。
- `AppSessionState`：启动和语言空间 session 状态；负责恢复当前语言空间、新增、切换、重命名、删除 fallback，并维护 `welcome` / `onboarding` / `main` 路由。
- `LaunchRoute`：无语言空间时回到 onboarding，有语言空间时进入 main。
- `AppDatabase`：SQLite / GRDB 数据库边界；统一 migration 和 repository 访问。
- `GRDBLanguageSpaceRepository`、`GRDBLearningContentRepository`、`GRDBAIProviderConfigurationRepository`、`GRDBMediaArtifactRepository`、`GRDBTTSProviderSettingsRepository`：当前主要本地持久化 repository。
- `AIProviderConfigurationService`：Provider 配置保存、credential reference、probe 和 TTS 设置服务。
- `KeychainAIProviderCredentialStore`：API Key 等敏感配置存储边界；数据库只保存 Keychain reference 和非敏感元数据。
- `LearningMaterialGenerationService`：用户显式触发的学习材料生成 / 重新分析服务；仍不是后台自动 AI 请求。
- `SentenceAudioPlaybackCoordinator`：逐句 TTS 生成、artifact cache、播放和取消的协调器。
- `LearningContentStore`：UI 层学习内容状态和生成 / 重新分析 / 逐句音频 action 编排。
- `GRDBPracticeRepository`：单句跟读 session、句子快照、录音 attempt、完成态和问题标记的本地 repository。
- `PracticeRecordingService`：练习录音生命周期 actor，负责 start / stop、权限错误映射、录音时长和文件大小边界，不负责业务完成态。
- `AppPracticeRecordingEngine`：App target 内的 AVFoundation 录音实现，处理 iOS / macOS 麦克风权限、audio session / capture authorization、staging 文件和录音结果。
- `PracticeActions` / `PracticeSessionViewModel`：UI 与 App 组装层之间的练习 action seam；SwiftUI 不直接持有 recorder、GRDB queue、绝对文件路径或 AVFoundation concrete。

## 4. 关键数据流

### 4.1 App 启动和语言空间恢复

1. SwiftUI App 启动并创建 `AppEnvironment`。
2. `AppEnvironment.bootstrap()` 打开默认数据库位置并创建 repository factory。
3. `AppSessionState.restoreLanguageSpace()` 读取当前语言空间和 active list。
4. `LaunchRoute.route(hasLanguageSpace:)` 决定进入 onboarding 或 main。
5. 如果 repository 或读取失败，`recoveryState` 记录失败，当前语言空间置空，路由回到 onboarding。

关键文件：

- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LaunchRoute.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`

测试入口：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LaunchFlowTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`
- `LangoTraceAppTests/AppEnvironmentBootstrapTests.swift`

### 4.2 语言空间新增、切换、重命名、删除 fallback

1. Onboarding 或管理页通过 UI action 调用 `AppSessionState`。
2. `AppSessionState` 调用 `LanguageSpaceRepository` 创建、选择、更新或软删除语言空间。
3. 删除当前语言空间后，repository 返回 fallback current space。
4. session 刷新 active list；若没有 fallback，路由回 onboarding。

关键文件：

- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpace.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSwitcherSheet.swift`

测试入口：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LanguageSpaceTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceManagementTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceSwitcherTests.swift`

### 4.3 Entry 写入和 LearningMaterial 生成 / 重新分析

1. 三端 UI 通过共享 entry editor / detail action 写入文本记录。
2. `GRDBLearningContentRepository` 持久化 Entry、LearningMaterial、句子分析、修改说明、practice candidate、memory candidate 和 operation summary。
3. 用户显式点击生成或重新分析后，`LearningContentStore` 调用 `LearningMaterialGenerationActions`。
4. App 层读取已保存 Provider 配置和 Keychain secret，构造固定 Prompt Registry 请求。
5. 成功结果写回 repository；失败或取消写入稳定 operation 状态。

关键文件：

- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialPromptRegistry.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`

测试入口：

- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBLearningContentRepositoryTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/LearningMaterialGenerationServiceTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreCancellationTests.swift`

### 4.4 AI Provider 配置、Keychain secret 和固定 probe

1. 用户在 AI Provider 设置页输入 profile、endpoint、model 和 secret。
2. UI draft 通过 `AIProviderSettingsActions` 调用 App 层 service。
3. 非敏感配置写入 SQLite / GRDB；API Key 写入 Keychain；数据库只保存 credential metadata / reference。
4. 用户显式触发 probe 时，服务发送固定低敏请求，例如文本回复、JSON 输出、语言支持、图片理解和 TTS probe。
5. probe 结果写入 validation event 和 UI 结果状态。

关键文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/KeychainAIProviderCredentialStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`

测试入口：

- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/KeychainAIProviderCredentialStoreTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/AIProviderConfigurationRepositoryTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`

### 4.5 TTS 生成、local artifact cache 和播放 coordinator

1. 用户点击单句 `听`。
2. UI 通过 `SentenceAudioPlaybackActions` 调用 `SentenceAudioPlaybackCoordinator`。
3. coordinator 读取默认可播放 TTS 配置和 Keychain secret。
4. 如命中有效本地 TTS artifact，直接解析 playback source 并播放。
5. 如 cache miss 或 artifact 损坏，调用 TTS 生成服务，校验音频，写入 local media artifact，再播放。
6. 取消会停止当前播放 / 生成链路并更新 UI 状态。

关键文件：

- `LangoTraceApp/SentenceAudioPlaybackAssembly.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/SentenceTTSGenerationService.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentenceAudioPlaybackActions.swift`

测试入口：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackCoordinatorTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/SentenceTTSGenerationServiceTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LocalMediaArtifactStoreTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactPlaybackSourceResolverTests.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/TTSAudioPlaybackServiceTests.swift`
- `LangoTraceAppTests/SentenceAudioPlaybackAssemblyTests.swift`

### 4.6 单句跟读练习录音、示范播放和完成态

1. 用户从练习 Tab 记录卡片或记录详情逐句 `练` 进入句子列表 / 单句练习页。
2. UI 创建 `PracticeSessionRouteSeed`，携带 entry、learning material、sentence identity、sentence index、target text hash、target language code 和句子快照。
3. `PracticeSessionViewModel` 通过 `PracticeActions` 调用 App 层，`GRDBPracticeRepository` 创建或恢复 shadowing session，并保存 `PracticeSentenceSnapshot`。
4. 单句页的听示范按钮复用 `LearningContentStore` 的 `SentenceAudioPlaybackActions` 和 `SentenceAudioPlaybackCoordinator`，以 route seed 构造单句 TTS 请求，不复制 TTS 生成 / artifact cache 路径。
5. 用户显式点击开始录音后，ViewModel 先停止当前示范播放，并在本地 playback flag 活跃时拒绝开始录音；`PracticeRecordingService` 调用 `AppPracticeRecordingEngine` 请求麦克风权限并写入 staging 文件。
6. 停止录音后，App 层经 `LocalMediaArtifactStore` 提交 practice recording artifact，`GRDBMediaArtifactRepository` 写入 `practice_recording_artifacts` typed metadata；ready recording 回写 session attempt。
7. 用户可在单句页回放最近 ready recording；App 层通过 `GRDBPracticeRepository.readyRecordingArtifact` 校验 session / recording / artifact ready 状态，再由 `LocalMediaArtifactPlaybackSourceResolver` 校验文件存在、大小和 hash 后交给前台播放器。
8. 用户点击完成时，repository 在事务中校验 ready recording，并把 `practice_sessions.completed_recording_id` 固定到该次录音，后续重录不会自动漂移完成证据。

关键文件：

- `LangoTraceApp/PracticeActionsAssembly.swift`
- `LangoTraceApp/AppPracticeRecordingEngine.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeRecordingArtifact.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/PracticeRecordingService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentenceAudioPlaybackActions.swift`

测试入口：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/PracticeSessionReducerTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/PracticeAudioCoordinationTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBPracticeRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactRepositoryTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackCoordinatorTests.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/PracticeRecordingServiceTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeSessionViewModelTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreSentenceAudioCoordinatorTests.swift`
- `LangoTraceAppTests/PracticeRecordingConfigurationTests.swift`
- `LangoTraceAppTests/AppEnvironmentPracticeBootstrapTests.swift`

### 4.7 未来同步、导出、权限和 StoreKit

这些能力目前是未完成或 disabled / unavailable 状态：

- Sync：`Packages/LangoTraceSync/` 只有包边界和 disabled service，尚无 Sync Engine、Adapter、冲突处理或对象存储配置。
- 导出：设置入口可以表达边界，但完整导出、可恢复备份和附件导出尚未实现。
- 权限：练习录音已经接入麦克风权限；Speech Recognition、OCR、Photos 和相机权限尚未接入真实授权流程。
- StoreKit：买断制购买、恢复购买、App Store 发布材料和隐私标签尚未实现。

这些能力不得在当前文档、UI 或计划中写成已完成。

### 4.8 照片写作 AI 看图辅助写作（首个照片 → AI 请求边界）

这是当前实现中第一个把**照片内容**纳入 AI 请求边界的数据流，且是该边界的唯一入口：

1. 用户在照片写作页选好照片后，显式点击「让 AI 看图帮我写」并经发送前确认（核心决策 #10；选取 / 滚动 / 写正文 / 保存 / 进入详情都不触发）。
2. `PhotoWritingAssistViewModel` 先调用 `PhotoWritingActions.sanitizeImage`（App Shell 接 `LangoTraceData` 的 `AIImageSanitizer`）把原始 PhotosPicker 字节降采样到 max edge 1024 + 再次剥离 EXIF/GPS，产出 `SanitizedAIImage`；View 不得把原始字节直接交给请求层（脱敏单一入口）。
3. App Shell `PhotoWritingActionsAssembly` 解析默认 text endpoint + Keychain secret，构造 `PhotoWritingAssistService`（`LangoTraceAI`）请求：经 `structuredImagePromptBody`（图片 + json_schema，仅 OpenAI 兼容 Chat / Responses；门控顺序 `supportsImageInput → imageInputEnabled → AIProviderImageSupport allowlist`）发送，按 `mode` 解析两份严格 schema。
4. 请求经 `ai_request_logs`（capability=`photoWritingAssist`）写非敏感日志；照片、备注、产出正文不入日志、不持久化。
5. 请求预览投影（`AIRequestPreviewProjection.photoWritingAssist`）是唯一在 `includedContent` 含 `photoAttachments` 的能力；`alwaysExcludedContent` 不变，其余所有能力仍排除照片（Core 回归测试锁定）。

安全边界要点：照片默认仅本地（保存路径不上传 / 不同步）；唯一外发是上述显式动作的脱敏图片。`photo_writing_assist_operations` 专用摘要表 v1 延后。

### 4.9 多轮对话 + 文本流式传输 seam（独立基础设施，LM03 消费）

这是对话级 AI 请求的**传输能力**数据流，目前**只到 Provider seam，无 UI / 会话 store**（消费方语伴 LM03 后续接入）：

1. 调用方构造 `AIChatStreamingServiceRequest`（endpoint + secret + 可选 system + 有序 `[ConversationMessage]`）。
2. `AIChatStreamingService`（`LangoTraceAI`）经 adapter 的 `streamingChatBody`（chat/completions `messages` + `stream:true`；responses `input` + `stream`；mimo 流式未验证暂 `unsupportedProvider`；anthropic / gemini 仍 `unsupportedProvider`）构造请求。
3. 经 `AIProviderStreamingHTTPClient.streamBytes` → `AsyncThrowingStream<UInt8, Error>` 增量读；`ServerSentEventParser` 字节级解析（仅按 `0x0A` 切分，跨 chunk 半行 + 多字节安全），`OpenAIStreamDeltaExtractor` 提取 delta。
4. 服务以 `AsyncThrowingStream<AIChatStreamEvent>`（全仓首个 throwing 异步流）逐 token yield；流终止于 `[DONE]` 或映射后的错误。
5. **投影就绪不写日志**：`request.projectionMetadata()` 携带 preset / model / lengthBucket / messageCount（无正文 / persona / 密钥）；对话级 `ai_request_logs` 写入由 LM03 在请求终止后经 App-Shell recorder 接线（E6 依赖方向）。

关键文件：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ConversationMessage.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIChatStreamingService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ServerSentEventParser.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPClient.swift`（`AIProviderStreamingHTTPClient`）

测试入口：

- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIChatStreamingServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/ServerSentEventParserTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/ConversationMessageTests.swift`

架构备忘录：`docs/architecture/notes/2026-06-25-chat-streaming-provider-seam-notes.md`

### 4.10 学习者模型（Ability 覆盖 + Memory 层 + 学习画像总览页）

系统级、横切语言空间的 Learner Model 子系统（ADR-006），独立包 `LangoTraceLearnerModel`：

1. **Ability 知识覆盖（LM01）**：`GRDBLearnerContextProvider` 经 `AppDatabase.reader` 以 compute-on-read 从 active 沉淀 `memory_items`（JOIN `language_spaces.target_language_code`）聚合 `AbilityCoverage`，**不持久不备份、无 migration**，删除经 active-only 读天然级联（ADR-006 §8/§7）；红线：不读 `memory_candidates`、无 band/level/difficulty。
2. **Memory 层（LM02-S1）**：用户**显式记住**的生活事实 / 目标写入**系统级表 `learner_memory_facts`（v27，无 space FK）**经 `AppDatabase.writer` → `GRDBLearnerMemoryRepository`；准原始策略 `localOnly`/`includedInSystemBackup`/`includedInRecoverableBackup`（ADR-006 §8）。单条删=软删可撤销；系统级「重置 App 对我的了解」=物理 DELETE（不触 `memory_items`/学习记录）。
3. **学习画像总览页（LM02-S1）**：`LearnerProfileSnapshotBuilder` compute-on-read 聚合 Ability 覆盖 + Memory 事实（Learner-owned）+ per-space 复习统计（借用 `memory_items`，系统级重置不改它）；三端 `LearnerProfileView`（独立设置导航项 / iPad·macOS 侧栏 peer，非 SettingsCapability）经 `LearnerProfileActions` 取数与治理；温和水平**不展示降级**（ADR-006 §10）。
4. **盲点（LM02-S3）**：`GRDBLearnerBlindSpotProvider` compute-on-read 读 `practice_text_attempts`（dictation diff）JOIN `language_spaces`，按 `target_language_code` 重跑 `PracticeDictationDiff.compare()` 频次聚合为 `BlindSpot`（{missing,changed,extra}），喂入 snapshot 的盲点分区；**红线只读用户产出 + 机械 diff，绝不读 AI 判定 / learning_text**；规模上限 `LIMIT 200`；总览页诚实标注「来自听写练习」、不下判决。无新表 / 无 writer。
5. **Style 表面印记（LM02-S2，seam-only）**：`GRDBLearnerStyleProvider` compute-on-read 读 `entries.body` JOIN `language_spaces`，经注入的 `LanguageDetector`（默认 `NLLanguageRecognizer`）判语种=母语→高置信纳入、=目标语→排除，**按母语分组**机械算句长/TTR/正式度为 `StyleImprint`；**红线只读 `entries.body`，绝不读 `learning_materials`/`input_kind`/`memory_candidates`**；**装配为 seam-only（`AppEnvironment.learnerStyleProvider`，无消费者读，语伴 v2 / 改写下投影届时消费）**；v1 表面印记是真派生不持久（§8 分层细化见 architecture note `2026-06-25-style-surface-imprint-recompute-notes.md`）。无新表 / 无 writer。
6. **查词捕获 + 分析账本（LM02-S4a，S4b 地基）**：阅读视图 AI 解释 seam（`ReadingDocumentStore.explainSelection` 触发 `lookupCaptureAction`）经 `AppEnvironment.readingLookupCaptureAction` → `GRDBDictionaryLookupEventRepository` 落库**查词行为事件**（v28 `dictionary_lookup_events`，**显式 local-only / 排除备份导出**，`source_content_origin` v1 恒 userAuthored 前向接缝）；`GRDBAnalysisLedgerRepository`（v29 `analysis_ledger`）是 ADR-006 §9 首张分析账本——`(source_type,source_id,analyzer,analyzer_version)` 键 + 高水位 cursor 增量窗口聚合、升版重跑、单调推进。**红线只记用户行为，不记 AI 内容**。建在 S1 v27 writer seam 之上。
7. **band 重估 + derive() 迟滞（LM02-S4b，全系列唯一碰 derive()）**：`GRDBLearnerBandProvider`（LearnerModel）compute-on-read 吃**独立行为信号**（S4a userAuthored 查词 + S3 错误）产出内部 band（红线只读 `dictionary_lookup_events`+`language_spaces`，排除 aiGenerated，不读 AI 难度）；经 `AppEnvironment.readingBandLevelSource` 注入 `ReadingDocumentStore`，由 **`BandHysteresis` 迟滞状态机**（Core，连续 3 次 document-open 越阈 + ≥5 次停留）稳定后喂 `derive()`（仅新内容不回改），`switchExplanationMode` 用户覆盖优先；**band 仅喂 derive()、不增新外发字段**（`:95` 静态、band 不流入材料/照片/回译；`:96` 随 band 但外发仍是三档枚举）；总览页 bandTrend/confidence 呈现**永不展示降级**、不覆盖用户 `LanguageLevel`。无新表（compute-on-read）。契约见 ADR-006 §10.1。

关键文件：

- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/`（`MemoryFact` / `GRDBLearnerMemoryRepository` / `LearnerProfileSnapshot` / `GRDBLearnerContextProvider` / `LearnerContextProvider`）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabaseLearnerMemoryMigration.swift`（v27）+ `AppDatabase.writer`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfileView.swift` / `LearnerProfilePresentation.swift` / `LearnerProfileStore.swift` / `LearnerProfileActions.swift`

测试入口：`GRDBLearnerMemoryRepositoryTests` / `LearnerProfileSnapshotTests` / `LearnerContextProviderMemoryFactsTests` / `BlindSpotModelTests` / `GRDBLearnerBlindSpotProviderTests` / `StyleImprintModelTests` / `GRDBLearnerStyleProviderTests` / `GRDBLearnerBandProviderTests`（LearnerModel）、`AppDatabaseLearnerMemoryMigrationTests` / `AnalysisLedgerMigrationAndRepositoryTests`（Data）、`AnalysisSignalsTests` / `BandHysteresisTests`（Core）、`LearnerProfilePresentationTests` / `LearnerProfileStoreTests` / `BlindSpotPresentationTests` / `ReadingLookupCaptureTests` / `DeriveBandSourceTests` / `BandPresentationTests`（UI）。

硬接缝：E10 可恢复备份必须纳入 `learner_memory_facts`（否则删库=永久失忆），事实源 `docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`。

### 4.11 语伴 MVP 单线程文本对话（LM03-S1）

- **入口**：设置开关（默认 OFF，`UserDefaultsCompanionFeatureStore`，per-device）→ 启用后三端入口出现：练习 Tab 二级（iPhone/macOS `CompanionEntryCard`）+ 记录详情「围绕这条记录对话」（三端 `CompanionEntryDetailButton`，方案 A 种子）。关闭即门控隐藏 + 不装配。
- **数据流**：`CompanionChatView` → `CompanionChatStore`（@MainActor）→ `CompanionChatActions`（App 注入）→ `GRDBCompanionRepository`（v30 `conversation_companions`/`companion_threads`/`companion_messages`，per-space、local-only、可导出、不同步）+ `CompanionConversationEngine`（`LangoTraceAI`）。引擎装配 system（`CompanionPromptRegistry` 固定模板 + 三枚举受控片段 + 难度基线读 `LanguageSpace.level`）+ 历史（上下文截断保最近、不动持久）+ 方案 A 首轮单条 Entry，经 `CompanionStreamingTransport`→`AIChatStreamingService`（缓冲非流式 S1），成功才持久 user+assistant，失败保输入不伪装。
- **隐私边界**：S1 **零系统自动注入**（不读 Memory 生活事实 / 不 FTS）→ 仅用户打字 + 显式带入单条记录的主动外发（决策 #10 trivially 满足）；外发经 Provider 抽象 + `projectionMetadata()`（E6）；人设纯枚举防注入（AI-17）；始终目标语（typed directive 契约）。
- **故障恢复**：Provider 未配置 / 不可用 / 拒绝 → honest 失败态（`CompanionReplyFailure`）+ 可重试 + 不丢输入。
- **测试入口**：`CompanionPersonaTests`/`CompanionDeletionSemanticsTests`/`CompanionFeatureStoreTests`（Core）、`GRDBCompanionRepositoryTests`（Data）、`CompanionConversationEngineTests`/`CompanionPromptRegistryTests`（AI）、`CompanionChatStoreTests`/`CompanionChatPresentationTests`（UI）。
- **未实现接缝**：逐句 TTS 朗读（暂缓，加性后续）；语音输入（远期，schema `input_modality`/`audio_artifact_id` 已预留，见 `docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md`）；对话记忆 / 滚动摘要 / 对话小结（LM03-S3b，门控未开）；Style 注入 + Anthropic（LM03-S4）。方案B 主动找话题 = LM03-S2b-2（见 §4.14）；Memory 注入 + PII scrubbing = LM03-S2b-1（见 §4.13）；**文本流式 UX + 温和复述 = LM03-S3a 已落地（见 §4.15）**。

### 4.12 语伴聊天反哺（LM03-S2a 入站半环 + S3b-2 deposit 闭环）

- **入口**：语伴聊天页工具栏（secondary action）显式「提取词汇 / 表达」动作（`CompanionChatView`）；非静默每轮——成本 + 隐私分类双理由（plan §D2）。
- **交付物 A 数据流（聊天 → 候选）**：`CompanionChatStore.extractCandidates()` → `CompanionChatActions.extract`（App 注入 `companionExtract`）→ 读 `companion_messages` 窗口 → `CompanionExtractionEngine`（`LangoTraceAI`，复用 S1 `CompanionStreamingTransport`→`AIChatStreamingService`，固定提取 Prompt `CompanionExtractionPromptRegistry`，结构化 JSON）→ `GRDBCompanionRepository.appendCompanionCandidates`（**v31 `companion_memory_candidates` 独立表**，锚定最新用户消息弱引用 `message_id`，删 thread CASCADE / 删消息 SET NULL）→ 读回 `companionCandidates(spaceID:)` 全量列表（含 source-deleted 态）。候选 = 可复算派生（无策略列），仅产出 + 展示计数。
- **交付物 B 接缝（用户目标语发言 → Ability 产出证据）**：`GRDBCompanionRepository.productionUtterances(spaceID:after:)` 最薄前向读接缝（`role='user'` 且行内 `detected_language == target_language_code`，oldest-first，cursor 窗口），供未来 band 产出消费片读取；**不改 band derive()、不登记 ledger 常量**（plan §D3）。红线守卫 `CompanionRefluxBandGuardTests`：band 源无 `companion` 引用 + 插入聊天数据后 band 不变。
- **隐私边界**：提取 = 用户显式触发重发已存对话，与「重新分析」同构，**不进系统自动注入门**（决策 #10）；capability `companionExtraction` 投影仅含 `companionConversation` 类目，**无新外发类目**，请求预览显式披露发送该段对话；失败诚实不丢对话。
- **deposit 闭环（LM03-S3b-2「对话小结」）**：把候选**批量 deposit 进 E7/E8 记忆复习系统**，闭合「记录 → 对话 → 记忆」。入口 = 提取结果区「全部加入记忆库」批量按钮 + 逐条「已加入」徽标（手动触发，§3.8 反手动选词、批量入库）。数据流：`CompanionChatStore.depositAllCandidates()` → `CompanionChatActions.depositAllCandidates`（App 编排）→ 读 `companionCandidates(spaceID)` → 逐条 `MemoryDepositInput(companionCandidate:spaceID:)`（`entryID = nil` 对话来源无归属 entry、`difficulty = .medium` 中性不读 band、kind 复用五类映射）→ `GRDBMemoryItemRepository.deposit`（**复用 E7 幂等**，`source_kind 'candidate'`、`entry_id` 写 NULL；幂等键 `(space_id, source_candidate_id)`，companion 与分析候选共用 `'candidate'`、UUID 无碰撞）→ 进 E8 复习队列（`review_state 'new'`）。「已加入」态 = `depositedCandidateIDs(spaceID)`（store 与 companion 候选 id 取交集，`@Published` 反应式）。**纯本地、无新外发 / 无新 migration**；候选删除/重提取按 E7 snapshot 语义不影响已 deposit 项。`GRDBMemoryItemRepository` 不耦合 companion 表（App 层编排）。band 红线不碰（守卫 `CompanionRollingSummaryBandGuardTests` 已覆盖 companion 数据不影响 band；deposit 只搬运候选文本、difficulty 默认中性）。
- **测试入口**：`CompanionMemoryCandidateTests`（Core）、`CompanionRefluxMigrationAndRepositoryTests`（Data）、`CompanionRefluxBandGuardTests`（LearnerModel 红线）、`CompanionExtractionEngineTests`/`CompanionExtractionPromptRegistryTests`（AI）、`CompanionExtractionStoreTests`/`CompanionCandidatePresentationTests`（UI）；**S3b-2 deposit：`MemoryDepositTests`（Core，companion init + kind 映射 + 既有回归）、`MemoryItemRepositoryTests`（Data，companion deposit entry_id NULL + 幂等 + analysis 回归）、`CompanionDepositStoreTests`（UI，批量标记 / 幂等 / load 预置）**。
- **后续接缝（备忘录）**：band 消费产出正向信号 + 两候选表统一评审面，见 `docs/architecture/notes/2026-06-26-companion-reflux-production-signal-and-candidate-unification-notes.md`。S3b-2 残余：`source_kind 'candidate'` 不区分来源表（UUID 无碰撞，未来扩展来源须纳 source_kind 入幂等键 = migration）。

### 4.13 语伴 Memory 注入 + 两层隐私（LM03-S2b-1，最高隐私门核心）

- **定位**：决策 #10 **首个系统自动注入外发**实例——把用户系统级生活事实（`learner_memory_facts`）经受控选择 + PII 脱敏后注入语伴 system prompt，使语伴「记得」用户生活背景。与 S1「用户打字发送」、S2a「用户点提取重发已存对话」严格不同类。
- **两层隐私控制**：① **全局三态 consent**（`CompanionMemoryConsent` notDecided/enabled/disabled，`UserDefaults`，非敏感）——授权 UX = **首次开启的一次性预览披露 + 全局关**（spec/008 §2 / ADR-008 §6，**非每次弹窗 / 非发送前拦截**，日常零摩擦）；`notDecided` 期间不注入；② **per-conversation 开关**（v32 `companion_threads.uses_learner_profile` DEFAULT 1）。
- **注入门权威判定**：落 App 端 `companionSend` async——`CompanionInjectionGate.shouldInject(consent:threadUsesProfile:)`（纯函数四态可测）；consent 最后一刻读 `UserDefaults`、toggle 读自同一 thread 行；UI store `canInjectMemory` 仅呈现、非外发授权 source of truth。
- **数据流**：consent+toggle 门开 → `GRDBLearnerContextProvider.memoryFacts(.global)` → `CompanionMemorySelection.select`（时近性 + 种类配额 top-5、不读 salience、仅 .global、LearnerModel 纯函数）→ `.text` → `CompanionConversationEngine`（新 `scrub` seam = `PIIScrubber.scrub`）对**注入片段 + 历史回放 + 用户输入**统一 outbound 脱敏 → `CompanionPromptRegistry.systemPrompt(memoryContext:)` delimiter `<<<MEMORY>>>` 包裹（引用非指令，`.memoryGroundedContext` directive 结构可测）。**持久化存原文，仅 outbound 脱敏**。
- **诚实披露**：新 capability `.companionConversation` + 新 included descriptor `.curatedLearnerMemory`；`.longTermMemory` **保持全局 always-excluded 恒真**（原始全量长期记忆库不外发）；一次性预览（`CompanionMemoryPreviewModel`，**不复用绑 entry 的 `RequestPreviewCardModel`**）同时展示「发：curated 子集」与「不发：完整记忆库 / 照片 / 录音」。
- **band 红线隔离**：注入只读 `learner_memory_facts`，**不碰 band derive() / 不读 AI 难度 / learning_text**；守卫 `CompanionMemoryInjectionBandGuardTests`（选择层源无 band 机器 + 注入路径后 band 不变）。
- **PII scrubbing v1**：手机号（`1[3-9]\d{9}`）+ 身份证号（18 位末位 X/数字），确定性正则、中性母语占位、outbound-only、不入日志。剩余风险：国际号 / 邮箱 / 地址 / 误杀练习数字（「宁少杀勿多杀」）。
- **测试入口**：`PIIScrubberTests`/`CompanionMemoryConsentStoreTests`/`CompanionInjectionGateTests`/`CompanionThreadProfileToggleTests`（Core）、`CompanionMemorySelectionTests`/`CompanionMemoryInjectionBandGuardTests`（LearnerModel）、`CompanionPromptRegistryTests`/`CompanionConversationProjectionTests`/`CompanionConversationEngineTests`（AI）、`CompanionMemoryToggleMigrationTests`（Data）、`CompanionMemoryInjectionUITests`/`CompanionMemoryPreviewModelTests`（UI）。
- **范围外（S2b-2 / v2）**：方案B 主动找话题（强依赖本片隐私闸）；salience / FTS 相关性召回；companionOnly 事实注入；对话级注入日志；邮箱 / 地址 PII。

### 4.14 语伴方案B 主动找话题（LM03-S2b-2，系统自动注入记录）

- **定位**：用户无方案A 显式带入记录时，语伴**授权后自动从用户记录里挑一条开启话题**（决策 #10 第二个系统自动注入实例）。**仅 send 回合内**触发——不破 S1「冷启动 load 零外发」铁律（`CompanionChatStore.load()` 从不 send）。
- **两层隐私**：① 全局一次性话题授权 `CompanionTopicSourcingConsent`（三态 `UserDefaults`，mirror S2b-1，首次预览披露、非每次弹窗、`notDecided`/`disabled` 不找话题）；② **复用 v32 `uses_learner_profile`**（语义自本片统一为「使用我的内容＝画像＋记录」，关一处同关 Memory 注入与找话题）。注入门 `CompanionInjectionGate.shouldSourceTopic` 纯函数四态可测。
- **数据流（send 回合内）**：`companionSend` 无方案A种子 + `shouldSourceTopic` 门开（consent 最后一刻读 + 同 thread 行 toggle）→ `GRDBCompanionRepository.recentTopicCandidates(spaceID:limit:1)`（**纯 `entries.body`、排软删、仅当前 space**；**不用 FTS**——FTS 须 rebuild 易陈旧 + body 折叠 AI `learning_text`）→ `CompanionTopicSelection.select`（recency top-1，LearnerModel 纯函数）→ `.body` → `CompanionConversationEngine`（scrub seam）脱敏 → `CompanionPromptRegistry.systemPrompt(broughtInRecords:)` `<<<RECORD>>>` 引用非指令 + `.topicGroundedInBroughtRecord` directive。
- **诚实披露**：新 included descriptor `.broughtInRecords`（**A/B 共用**：方案A 用户显式带入 + 方案B 自动找）；`companionConversation(..., hasBroughtInRecords:)` 注入时披露；一次性预览 `CompanionMemoryPreviewModel` 复用展示「发：你的 1 条记录 / 不发：完整记录库 / 照片 / 录音」。
- **连带修复（S2b-1/方案A 既有漏洞）**：S2b-1 的 engine scrub seam **遗漏 `seedEntryBody`**（方案A 记录正文未脱敏外发）+ 方案A 记录在 preview 零披露。本片把 `seedEntryBody` 纳入 scrub + `.broughtInRecords` A/B 共用披露，一并修复。
- **band 红线**：只读 `entries.body`，**不取 FTS snippet（含 AI 文本）/ 不碰 derive()**；守卫 `CompanionTopicSelectionBandGuardTests`（源 grep + 数据源行为断言）。
- **测试入口**：`CompanionTopicSourcingConsentStoreTests`/`CompanionInjectionGateTopicTests`/`CompanionTopicCandidate`（Core）、`CompanionTopicSelectionTests`/`CompanionTopicSelectionBandGuardTests`（LearnerModel）、`CompanionPromptRegistryTests`/`CompanionConversationProjectionTests`/`CompanionConversationEngineTests`（AI）、`CompanionTopicCandidateRepositoryTests`（Data）、`CompanionTopicSourcingUITests`（UI，含冷启动零外发回归）。
- **v1 残余 / 范围外**：单条记录 PII 集中（仅手机号/身份证脱敏，缓解 = top-1 + 一次性预览 + 可关）；同会话可能重复引用最近记录（不追踪已用种子）；recency ≠ 相关（FTS 精排 / 子范围授权 / 独立 `uses_record_topics` 列留后续 + architecture note）。无新 migration（复用 v32 + 只读 entries + UserDefaults consent）。

### 4.15 语伴文本流式 UX + 温和复述（LM03-S3a，纯显示 + persona 暴露）

- **定位**：把 S1「缓冲整段再显示」非流式 UX 升级为**逐字流式显示**，并暴露既有温和复述纠错档。**流式只改显示，不改外发**——请求体 / 内容类目 / 隐私闸 / PII scrub 与 S1·S2b 完全一致；**无新 migration、无新 AI capability、无新外发类目**；不碰 band 红线。
- **流式数据流**：`CompanionConversationEngine.reply(..., onPartial:)` 在既有 delta 循环内逐 token 回调**累积缓冲全文**（传输层早已逐 delta yield，S1 只是缓冲）→ `CompanionChatActions.send` seam **新增 `onPartial` 第三参**（App `companionSend` 透传 → engine）→ `CompanionChatStore.send()` 内建 `AsyncStream<String>`，`onPartial` 仅 `cont.yield`（`@Sendable` 保序），**单 MainActor consumer 顺序消费**更新 `@Published inFlightReply`（correct-by-construction，零 Task fan-out / 无单调守卫）→ `CompanionChatView` 在 `isSending && inFlightReply` 非空白时渲染**进行中 assistant 气泡**。
- **持久化不变量**：`inFlightReply` 纯 UI 派生态，**从不进持久路径**；仅成功 outcome 的**完整缓冲文本**持久（engine `.reply(text:)` 返回全文，App 持久之）；失败 / 取消任何路径无条件清空 `inFlightReply` + 保 draft 不伪装（ADR-008 §7）。
- **温和复述（persona 暴露）**：v1 暴露既有 `CompanionCorrection.warmRecast` 二元 opt-in（默认 `.ifNeeded` 关），directive `correctionPolicy(.warmRecast)` + 受控片段文本早已映射。`CompanionLoadedThread` 加 `correction`（struct 默认值，不破坏构造）；App `loadThread` 带出 `loadPersona(spaceID).correction`；store `gentleRecastEnabled` 派生 + `setGentleRecast`；toggle 经 App **read-modify-write**——persona 为 per-space（`conversation_companions`），`savePersona` 全字段 upsert，故 `loadPersona`→仅改 correction→save，保 tone/formality。
- **故障恢复**：先 yield 部分 delta 后抛错 → `onPartial` 已回调但最终 `.failure`，store 据此清空 in-flight、不持久部分回复（honest failure）。
- **测试入口**：`CompanionConversationEngineTests`（流式 onPartial 累积 / 空流不回调 / 部分后失败，AI）、`CompanionPromptRegistryTests`（warmRecast fragment 文本，AI）、`CompanionStreamingStoreTests`（partials 累积 + 失败清空 + recast 派生与路由，UI）、`GRDBCompanionRepositoryTests`（read-modify-write 保 tone，Data）。
- **范围外**：对话记忆 / 滚动摘要（LM03-S3b-1，见 §4.16）；对话小结（LM03-S3b-2）；常驻建议 chip / 长按翻译·解析·提示（长按能力未建）；persona tone/formality 编辑器 / `.none` 档；Anthropic 多 Provider 流式适配（LM03-S4）。

### 4.16 语伴对话记忆 / 滚动摘要（LM03-S3b-1，上下文窗口压缩 + 失效重建一致性）

- **定位**：会话超窗时把**老化出 recent-verbatim 窗**的较早轮次压缩为滚动摘要（`<<<CONVERSATION MEMORY>>>` 引用块）注入语伴 system prompt，长对话保持「记得你上次说的」（idea-03 §3.2/§5.2/§3.11）。**只压缩本会话自身消息、不注入外部数据**——区别于 S2b-1 Memory 注入（注入外部系统级事实 = 最高门）。
- **隐私归类（语伴整体 opt-in 内，无新 consent 门）**：摘要系统自动触发，但被摘要内容 = provider 在本会话早轮已收到的对话（同会话同 provider、内容已见过），无新外发类目/无外部数据 → 归语伴整体 opt-in，**不新增 consent 门**；诚实披露经新 capability `.companionSummarization`（preview-only、不写 `ai_request_logs`，includedContent = `[.companionConversation]`，外部数据全 excluded）；被摘要轮 + 现有摘要经 `scrub`（PIIScrubber）outbound 脱敏。
- **触发判定（引擎纯函数，可单测）**：`CompanionConversationEngine.shouldSummarize(messageCount:watermark:threshold≈24:recentVerbatimWindow≈12)`——超阈值且存在老化出窗未折叠轮次 → true。判定不埋 App（自审 P0-3）。
- **数据流（send 回合内，App `companionSend`）**：`shouldSummarize` true → 取老化出窗且 `sequence > 水位` 的待折叠轮 → `engine.summarize(messagesToFold:existingSummary:)`（非流式缓冲、`CompanionSummarizationPromptRegistry` `builtin.companion.summary.v1`、scrub 覆盖被折叠轮 + 现有摘要）→ 成功则 `repository.updateRollingSummary(text:coversThroughSequence:新水位)`（失败 = honest failure，不更新、不阻塞回复）→ `reply` 只发 `sequence > 水位` 的未摘要近端轮 + `conversationMemory: 摘要文本`（无重叠双发）。reply 仍走 S3a `onPartial` 流式（摘要不流式、在 reply 前完成）。
- **持久化（v33）**：`companion_threads` 加 3 列 `rolling_summary`/`summary_covers_through_sequence`/`summary_updated_at`（派生 cache 列，水位模型，无 fingerprint）；`CompanionRollingSummary`（Core 值类型）；local-only 不同步、随 thread 行 backup/export lane（可重建、恢复安全）。
- **失效重建一致性（idea-03 §3.2，本片最高风险）**：`deleteMessageAndSubsequent`/`clearThread` 在**既有同一 `writer.write` 事务内**——删除点 `sequence ≤ 水位`（或 clear）→ 同事务清空摘要 + 水位（SQLite 原子、无中途态）；删除点 > 水位 → 保留；水位 null → no-op。重建惰性：失效后下次 send 再超窗重摘。
- **band 红线隔离**：摘要只读 `companion_messages.content`，**不碰 band derive() / 不读 AI 难度 / learning_text**；守卫 `CompanionRollingSummaryBandGuardTests`（摘要专属源级 grep 无禁词 + 插入对话 + 摘要后 band 不变）。
- **测试入口**：`CompanionRollingSummaryRepositoryTests`（v33 + 一致性六态，Data）、`CompanionConversationEngineTests`（shouldSummarize 四态 / summarize 缓冲·失败·scrub / conversationMemory 注入，AI）、`CompanionSummarizationTests`（prompt directive + 披露，AI）、`CompanionRollingSummaryBandGuardTests`（红线，LearnerModel）。
- **范围外**：对话小结（S3b-2）；成本软提示 UI（§6.8 defer）；摘要经 `LearnerContextProvider` 统一取用（§3.11 v2 generalize，本片 companion-owned + repo 方法封装预留迁移点 + architecture note）；fingerprint 增量免重算（v2）；per-conversation 摘要开关（defer，「关语伴」已是整体 opt-out）。

## 5. 模块依赖方向

当前依赖方向：

```text
App Shell -> UI -> Core
App Shell -> Data / AI / Speech / Sync / LearnerModel
UI -> Core / Data / LearnerModel
Data -> Core
AI -> Core
Speech -> Core
Sync -> Core
LearnerModel -> Core / Data
```

当前 App target 通过 `project.yml` 依赖所有本地 package；package 之间仍应保持 Core 向下无依赖、具体实现由 App 组装。UI 自 LM02-S1 起依赖 LearnerModel（消费学习画像总览页类型；LearnerModel 不反向依赖 UI，无环）。

## 6. 禁止反向依赖

- Core 不依赖 SwiftUI、GRDB、Keychain、URLSession Provider 实现、AVFoundation 或 Sync Adapter。
- UI 不直接访问 SQLite、Keychain、对象存储、真实网络 Provider、文件系统 artifact path 或同步密钥。
- Data 不引入 SwiftUI 页面状态，也不保存 API Key 明文、密文、hash、尾号、请求体或响应体。
- AI 不把真实用户生活记录、照片、音频或 Prompt Preset 内容用于配置 probe。
- Speech 不决定 Provider 配置存储和 Keychain 读取策略。
- Sync 未实现前不得把主数据、派生数据和 cache 的同步边界写成已落地。
- Workflow、review、plan、reference research 不得覆盖 ADR、spec 或 architecture 的权威关系。

## 7. 已知故障与恢复路径索引

本节是异常路径和测试覆盖视图，不替代 bug plan、spec 或 review round。发现真实缺陷时，仍应在 `docs/plans/active/` 创建对应任务。

| 能力 / 边界 | Failure mode | Recovery path | User-visible result | Diagnostics / log | Test status | Test file or verification | Current owner document |
| --- | --- | --- | --- | --- | --- | --- | --- |
| App 启动和语言空间恢复 | 数据库或 repository 读取失败 | `AppSessionState` 清空当前空间，记录 `recoveryState`，路由回 onboarding | 用户重新进入 onboarding 或看到语言空间缺失状态 | App session recovery state；运行期问题可用 `scripts/capture-runtime-log` | Partial | `LaunchFlowTests.swift`、`LanguageSpaceRepositoryTests.swift`、`AppEnvironmentBootstrapTests.swift` | 本文档；`docs/spec/002-navigation-and-routing.md` |
| 语言空间删除 fallback | 删除当前空间后无 fallback | repository 返回空 fallback，session 刷新列表并回 onboarding | 不停留在悬空当前空间 | repository error / session recovery state | Yes | `LanguageSpaceRepositoryTests.swift`、`LanguageSpaceManagementTests.swift` | 本文档；`docs/spec/navigation/impl.md` |
| GRDB migration / repository 写入 | migration 失败、写入失败、唯一约束或软删除冲突 | repository 抛出稳定错误；UI / App 层按当前 action 显示失败或保持旧状态 | 保存失败，不伪装成功 | Data repository error；必要时 runtime log | Partial | `AppDatabaseTests.swift`、`LanguageSpaceRepositoryTests.swift`、`GRDBLearningContentRepositoryTests.swift`、`AIProviderConfigurationRepositoryTests.swift` | `docs/spec/007-data-storage-migration-export-and-attachments.md` |
| AI Provider 配置缺失 | 未配置 profile / endpoint / model / secret | 配置 service 返回 input invalid 或 missing credential；probe / 生成不继续发送真实请求 | 设置页显示未配置或输入无效 | validation event / diagnostic event，不含 secret | Yes | `AIProviderConfigurationServiceTests.swift`、`AIProviderSettingsTests.swift` | `docs/spec/005-ai-provider-prompt-and-privacy.md` |
| Keychain 读取失败 | secret 缺失、拒绝、不可用或 decode 失败 | 映射为稳定 credential error；数据库不回填明文；生成 / probe 失败收口 | 用户看到凭证相关失败，需要重新保存或检查系统 Keychain | diagnostic event 只记录阶段和分类 | Partial | `KeychainAIProviderCredentialStoreTests.swift`、`AIProviderCredentialReferenceTests.swift` | `docs/spec/008-permissions-local-privacy-and-diagnostics.md` |
| Provider probe 失败或取消 | 网络失败、401、模型不存在、超时、用户取消 | probe result 记录 capability status；取消不当作 validation failure | 设置页显示对应失败或取消状态 | validation event；固定低敏请求 | Yes | `AIProviderConfigurationProbeServiceTests.swift`、`AIProviderSettingsProbeTests.swift`、`Tests/Tooling/test_probe_openai_compatible_api.py` | `docs/prompts/ai-provider/provider-configuration-probe.md` |
| 学习材料生成 / 重新分析失败 | Provider 错误、结构化输出非法、secret 缺失、取消 | 写入 operation failure / cancelled summary；取消保持终态，不覆盖为成功 | 记录详情显示失败、取消或可重试状态 | operation summary；diagnostic event 分类 | Partial | `LearningMaterialGenerationServiceTests.swift`、`GRDBLearningContentRepositoryTests.swift`、`LearningContentStoreCancellationTests.swift` | `docs/spec/learning-content/impl.md` |
| TTS 生成失败 | Provider HTTP 失败、空音频、格式无效、配置不支持 | 映射为稳定 TTS failure；不写入 ready artifact | 单句播放显示失败或可重试 | TTS failure category；不记录请求体 / 响应体 | Yes | `SentenceTTSGenerationServiceTests.swift`、`TTSAdapterRequestTests.swift`、`TTSAudioValidationTests.swift` | `docs/spec/011-tts-provider-configuration-and-playback.md` |
| Artifact cache miss / corrupt | 本地文件缺失、格式不符、metadata 与文件不一致 | 重新生成或标记 artifact unavailable；损坏文件不当作命中 | 单句播放重试生成或显示失败 | media artifact state；cleanup result | Yes | `LocalMediaArtifactStoreTests.swift`、`MediaArtifactPlaybackSourceResolverTests.swift`、`TTSAudioFileValidatorTests.swift` | `docs/spec/007-data-storage-migration-export-and-attachments.md` |
| 播放取消和重试 | 用户取消、播放器失败、playback source 不可用 | coordinator 取消当前任务；后续点击可重新开始 | 单句状态回到取消 / 失败 / 可重试 | playback failure category | Yes | `SentenceAudioPlaybackCoordinatorTests.swift`、`TTSAudioPlaybackServiceTests.swift`、`LearningContentStoreSentenceAudioCoordinatorTests.swift` | `docs/spec/011-tts-provider-configuration-and-playback.md` |
| 媒体派生资产 staging / atomic move / cleanup | staging 写入失败、move 失败、cleanup 部分失败 | 不提交 ready metadata；cleanup result 记录失败文件数 | 用户不看到伪成功 artifact | cleanup result；file state | Yes | `LocalMediaArtifactFileStoreTests.swift`、`LocalMediaArtifactStoreTests.swift`、`MediaArtifactRepositoryTests.swift` | `docs/spec/007-data-storage-migration-export-and-attachments.md` |
| 练习 session 创建 / 恢复 | current material 变化、sentence soft reference 丢失或重复进入同一句 | repository 按 language space / material / sentence / exercise type 创建或恢复，并依赖 session snapshot 回读历史内容 | 用户仍能看到练习时的句子快照；悬空 current sentence 不作为 active 入口 | 不记录完整句子或 Entry 正文 | Yes | `GRDBPracticeRepositoryTests.swift`、`PracticeRouteSeedTests.swift` | `docs/plans/done/2026-05-25-feature-practice-shadowing-recording-completion.md` |
| 麦克风权限拒绝或不可用 | 用户拒绝、受限、设备不可用或 sandbox entitlement 缺失 | 录音 service 返回稳定 failure，不创建 ready recording，不标记完成 | 单句页显示可恢复失败；其他学习功能可继续使用 | permission status / failure category，不记录音频 | Partial | `PracticeRecordingServiceTests.swift`、`PracticeRecordingConfigurationTests.swift`；真实设备需人工验收 | `docs/spec/008-permissions-local-privacy-and-diagnostics.md` |
| 练习录音提交失败 | recording stop 失败、文件缺失、文件过大、hash mismatch、metadata ready 标记失败 | 清理 staging 或保持 pending 待 recovery；不把失败 attempt 暴露为 ready；完成操作只接受 ready recording | 用户可重新录音，不显示完成成功 | duration / byte size bucket 和 failure category；无绝对路径 | Partial | `GRDBPracticeRepositoryTests.swift`、`MediaArtifactRepositoryTests.swift`、`PracticeRecordingServiceTests.swift` | `docs/spec/media-artifacts/impl.md` |
| 完成态录音缺失或被清理误选 | completed recording 文件缺失、hash mismatch 或普通 cleanup 候选误包含 | session 保持 completed；playback source 标为 unavailable；completed recording 不进入普通 TTS / capacity cleanup | 用户看到完成记录存在但录音不可播放或需重新录制 | artifact state / failure category；不记录路径 | Partial | `MediaArtifactRepositoryTests.swift`、`GRDBPracticeRepositoryTests.swift`、`PracticeSessionViewModelTests.swift`；真实设备回放需人工验收 | `docs/spec/007-data-storage-migration-export-and-attachments.md` |
| 学习画像总览 / Memory 治理（LM02-S1） | DB 不可用、空 Memory、删除/重置 | snapshot loader 返回 nil → 页面 `unavailable` 态；空 Memory 返回空列表 + 「继续记录以解锁画像」空态；单条删=软删可撤销，系统级重置=物理 DELETE 且不触 `memory_items`；写入经串行 `DatabaseQueue` | 用户看到画像不可用 / 空态 / 重置确认流；不展示水平降级 | 纯本地零外发；不记录事实正文 | Yes | `GRDBLearnerMemoryRepositoryTests`、`LearnerProfileSnapshotTests`、`LearnerProfileStoreTests`、`AppDatabaseLearnerMemoryMigrationTests` | `docs/decisions/006-system-level-three-layer-learner-model.md`；`docs/spec/007-...md` |
| 多轮 / 流式聊天传输（enabler，无 UI） | 流中途网络失败、取消、超时、4xx 配额、非 2xx、响应超体积上限、不支持的 Provider kind | `AIChatStreamingService` 将错误映射到既有分类后令 `AsyncThrowingStream` 安全终止；已 yield 的 delta 已交付（流式本义，非泄漏）；超 `maximumResponseBytes` 以 `responseTooLarge` 终止 | 传输层语义正确；半截回复的 UI 表达属 LM03（当前无 UI） | 不记录消息正文 / persona / 密钥；对话级 log 写入归 LM03 | Yes | `AIChatStreamingServiceTests.swift`、`ServerSentEventParserTests.swift`；真实 URLSession 流式行为经 CI Build & Test | `docs/architecture/notes/2026-06-25-chat-streaming-provider-seam-notes.md`；`docs/spec/005-ai-provider-prompt-and-privacy.md` |
| 未来 Sync | sync engine / adapter / conflict 未实现 | 保持 disabled / unavailable，不承诺同步 | 设置页显示未启用或不可用 | 无真实同步日志 | No | `SyncBoundaryTests.swift` 只覆盖 disabled boundary | `docs/technical-framework-roadmap.md` |
| 未来权限 | Photos / Camera / Speech Recognition / OCR 未接入 | 保持未实现说明，真实权限任务另建 plan | 不弹出真实权限或误导为已授权 | 无真实权限日志 | No | 当前无完整权限测试 | `docs/spec/008-permissions-local-privacy-and-diagnostics.md` |
| 未来导出 | 完整导出和可恢复备份未实现 | 保持 unavailable / future capability | 设置页不能写成已导出 | 无真实导出日志 | No | 当前无完整导出测试 | `docs/spec/007-data-storage-migration-export-and-attachments.md` |
| 未来 StoreKit | 买断制购买 / 恢复购买未实现 | 保持未实现，发布前另建 StoreKit plan | 不显示已购买或可恢复购买 | 无 StoreKit 日志 | No | 当前无 StoreKit 测试 | `docs/release/README.md` |

## 8. 验证入口

文档和工程验证入口：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
scripts/verify.sh
```

聚焦 package 测试入口：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceSync
swift test --package-path Packages/LangoTraceUI
python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py
```
