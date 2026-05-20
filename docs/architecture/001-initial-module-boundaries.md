# 初始模块边界

本文档记录语迹 LangoTrace 原生工程初始化阶段的模块边界。它用于指导第一版 SwiftUI 工程骨架，不代表所有模块都必须在第一天完整实现。

当前代码已经落地这些初始边界，但仍处于早期 Mock / disabled service 阶段。本文档既记录目标边界，也记录当前实现快照，避免后续误把占位协议理解成真实数据、AI、语音或同步能力已经完成。

## 1. 边界原则

第一阶段的重点是让工程结构支持长期演进：

- App 可以在 iPhone、iPad 和 macOS 启动。
- 产品核心概念不被写死在单个视图文件里。
- 后续接入数据库、AI、TTS、OCR、同步和 StoreKit 时有明确放置位置。
- 早期可以使用协议、空实现或内存实现，但不把外部服务请求直接写进 UI。

## 2. 推荐模块

### 2.1 App Shell

职责：

- 应用入口。
- 根导航。
- 平台窗口配置。
- 首次启动状态路由。

不负责：

- 直接执行 AI 请求。
- 直接读写数据库。
- 直接管理同步冲突。

### 2.2 Core

职责：

- 领域模型。
- 用例协议。
- 语言空间、记录、句子、词句记忆、练习记录等核心类型。
- 与平台无关的业务规则。

不负责：

- SwiftUI 视图。
- SQLite 细节。
- 网络请求细节。

### 2.3 UI

职责：

- 共享设计 token。
- 共享 SwiftUI 组件。
- iPhone、iPad、macOS 的根布局适配。
- 原型中的视觉方向转化为原生界面。

不负责：

- 数据持久化。
- AI Provider 调用。
- 同步协议。

### 2.4 Data

职责：

- 本地 Repository 接口和实现。
- SQLite / GRDB 接入。
- 数据迁移。
- FTS 索引。
- 附件元数据。

第一阶段可以从协议和内存实现起步；语言空间持久化和 AI Provider 配置元数据已进入真实 SQLite / GRDB 基础设施，其余 Entry、附件、Speech 和 Sync 仍按各自任务分阶段落地。

基础设施建设边界：

- 语言空间持久化、启动恢复、Repository、SQLite / GRDB schema、迁移、导出、删除和恢复属于 Data 基础设施，不应以单语言空间或单对象临时实现作为长期交付结果。
- UI 可以在 MVP 阶段只开放第一个语言空间，但 Data 层协议、主键、外键、查询、当前空间选择、删除/导出边界和迁移测试必须按多语言空间模型设计。
- 轻量存储只能用于交互 prototype 或测试替身；一旦任务目标是“持久化与启动恢复”，应优先建设真实可演进的数据边界，而不是先落一个后续必然推翻的 UserDefaults 单空间版本。

### 2.5 AI

职责：

- AI Provider 协议。
- Provider configuration service。
- Keychain credential store 和 credential resolver。
- Prompt Preset。
- 请求预览和请求元数据。
- 图片理解、文本转换、写作检测和改写的接口。

当前已落地 AI Provider 配置保存、Keychain 凭证存储和本地 credential validation；仍不发送真实外部 Provider 请求。

### 2.6 Speech

职责：

- TTS 播放接口。
- 录音接口。
- 语音识别接口。
- 跟读、听写和回译流程所需的音频状态。

第一阶段可以使用空实现或占位状态。

### 2.7 Sync

职责：

- 同步状态。
- Sync Adapter 协议。
- 冲突模型。
- manifest 和变更记录的抽象。

第一阶段不实现 WebDAV / S3 / R2 / iCloud 同步。

## 3. 依赖方向

推荐依赖方向：

```text
App Shell -> UI -> Core
App Shell -> Data / AI / Speech / Sync
Data -> Core
AI -> Core
Speech -> Core
Sync -> Core
```

约束：

- Core 不依赖 UI。
- Core 不依赖具体数据库。
- Core 不依赖具体 AI Provider。
- UI 不直接知道 API Key、base URL 或同步密钥。
- Data、AI、Speech、Sync 通过协议向 App Shell 暴露能力。

## 4. 第一阶段最小落地

第一阶段工程初始化已经落地：

- App Shell。
- 根视图。
- 最小 Core 类型，例如产品身份、平台角色、手机根 Tab、学习语言、语言水平、隐私状态、启动路由和占位语言空间状态。
- 可以编译的模块结构。
- Core、Data 和 UI package 的首批测试。
- 统一验证脚本。

仍未落地：

- Entry、Rendering、Practice、Memory、附件和导出的真实数据库表。
- 真实 AI 请求。
- 真实 TTS。
- 真实同步。
- StoreKit。

## 5. 当前代码快照

### 5.1 App Shell

当前文件：

- `LangoTraceApp/LangoTraceApp.swift`
- `LangoTraceApp/AppEnvironment.swift`

当前职责：

- 通过 `AppEnvironment.bootstrap()` 装配共享 `AppDatabase`、真实语言空间 SQLite / GRDB repository、AI Provider 配置 repository、Keychain credential store、AI Provider 设置页 actions，以及 AI / Speech / Sync 的 disabled 实现。
- App Shell 负责装配 Data 和 AI package 的实现，但不直接持有 SQL、Keychain query 或 Provider SDK 调用细节。
- App Shell 负责装配诊断 logger。产品期默认 disabled；开发期可组合 console 和本地 ring buffer。Core、Data、AI、UI package 不直接读取环境变量。
- 通过 `AppSessionState` 管理 `welcome`、`onboarding`、`main` 三段启动状态。
- 使用 `LaunchRoute` 判断缺少语言空间时应回到 onboarding。
- 通过 `AppSessionState` 恢复、创建、切换、重命名和删除当前语言空间；缺少 active 语言空间时回到 onboarding。
- `LanguageSpacePreview` 只作为 UI 展示投影，真实语言空间来自 Core `LanguageSpace` 和 Data repository。

### 5.2 Core

当前已实现类型：

- `ProductIdentity`
- `PlatformRole`
- `PhoneRootTab`
- `LearningLanguage`
- `LanguageLevel`
- `LanguageSpacePreview`
- `LanguageSpace`
- `CreateLanguageSpaceInput`
- `UpdateLanguageSpaceInput`
- `LanguageSpaceDeletionResult`
- `LanguageSpaceError`
- `AIProviderConfigurationProfile`
- `AIProviderEndpointConfiguration`
- `AIProviderCredentialMetadata`
- `AIProviderValidationEvent`
- `AIProviderConfigurationRepository`
- `AIProviderConfigurationSaveFailure`
- `DiagnosticEvent`
- `DiagnosticLogging`
- `DiagnosticEventRepository`
- `PrivacyStatusSeverity`
- `AIProviderStatus`
- `SyncProviderStatus`
- `LaunchRoute`
- `OnboardingDraft`
- `ModuleMarker`

当前测试覆盖：

- 产品身份。
- 启动路由。
- onboarding draft 默认值、语言空间创建输入和异常语言 code 归一化。
- 语言空间 display name 规范化、软删除 preview 边界和持久化身份投影。
- 学习语言展示和目标语言过滤。
- 手机 Tab 顺序。
- 隐私状态标签和图标。
- AI Provider endpoint URL 安全校验、credential metadata、保存输入和 Keychain reference 字段。
- AI Provider 保存失败阶段、类型安全诊断事件、allowlisted diagnostic attributes 和 non-throwing logger 行为。

### 5.3 UI

当前已实现视图和 helper：

- `LangoTraceRootView`
- `WelcomeView`
- `OnboardingView`
- `PhoneMainView`
- `PadMainView`
- `MacMainView`
- `LanguageSpaceFooter`
- `LanguageSpaceManagementView`
- `PadWorkspaceBar`
- `LangoPanelToggleButton`
- `PadPanelGestureAction`
- `LangoTraceDesign`

当前 UI 能展示三端产品骨架，其中 iPhone 设置页已接入语言空间管理页，AI Provider 设置页已接入真实本地配置保存、本地 credential validation 和保存结果反馈；Entry、练习、记忆和真实 AI 请求内容仍是 Mock。UI 不应直接接入 SQLite、Keychain、网络、对象存储或具体 AI Provider，语言空间管理页和 AI Provider 设置页都通过 App 层 action closures 修改状态。

当前测试覆盖：

- iPad 左右辅助面板边缘手势判定。
- iPhone 语言空间管理页源码级行为边界：不依赖 GRDB / SQL、包含新增/切换/重命名/删除 action、同目标语言提示、同名提示和 soft delete 文案约束。
- AI Provider 设置页源码级行为边界：真实保存调用、按钮内 saving 反馈、独立 saved / failed / input invalid 状态、operation id 关联和无网络测试请求。

### 5.4 Data / AI / Speech / Sync

当前状态：

- `LangoTraceData` 已包含 `LanguageSpaceRepository`、`EmptyLanguageSpaceRepository`、`GRDBLanguageSpaceRepository`、`LanguageSpaceDatabaseLocation` 和内存学习内容 repository。
- `LangoTraceData` 已包含 `AppDatabase`，统一负责 SQLite / GRDB 数据库打开、文件保护、migration 注册和测试数据库初始化。
- 语言空间 repository 已使用 SQLite / GRDB 持久化 `language_spaces` 与 `app_state.current_language_space_id`，支持 active list、读取、当前空间、创建、更新、选择、软删除和同名检测。
- AI Provider configuration repository 已使用同一 `AppDatabase` 持久化非敏感 Provider profile、endpoint、credential metadata 和 validation event；数据库不保存 API Key 明文、密文、hash 或尾号。
- Diagnostic event repository 已使用同一 `AppDatabase` 持久化最小 `diagnostic_events` ring buffer；只保存类型安全事件名、domain、level、outcome、operation id 和 allowlisted attributes，不保存用户内容或密钥。
- Entry / Rendering / Practice / Memory 仍使用内存学习内容 repository，不代表本地记录闭环已持久化。
- `LangoTraceAI` 已包含 `AIProviderConfigurationService`、`AIProviderCredentialStore`、`AIProviderCredentialResolver`、`KeychainAIProviderCredentialStore`、`AIProvider` 和 `DisabledAIProvider`；Provider 配置保存失败会返回稳定阶段和错误分类，并通过 best-effort 诊断事件记录 Keychain / Data / cleanup 阶段。
- `LangoTraceSpeech` 只有 `SpeechService` 和 `DisabledSpeechService`。
- `LangoTraceSync` 只有 `SyncService` 和 `DisabledSyncService`。

这些类型中语言空间和 AI Provider 配置已进入真实本地数据库基础设施；AI 仍未发送真实外部请求，Speech 和 Sync 仍表示模块边界和装配位置。后续接入具体能力时，应在对应模块内扩展协议、状态和测试，而不是从 UI 直接调用平台 API 或外部服务。
