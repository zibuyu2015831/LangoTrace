# 任务方案：AI Provider 文本模型配置测试请求

状态：Draft
类型：feature
创建日期：2026-05-21
最后更新日期：2026-05-21

## 用户确认记录

- 2026-05-21：用户要求检查相关备忘录，开发 AI Provider 测试功能，使用户填写相关配置信息后可以测试配置。
- 2026-05-21：经讨论确认第一阶段只完成文本模型配置测试，不一次性接入 TTS、Embedding、图片理解或真实 Prompt Preset 执行；用户要求先创建方案文档。
- 2026-05-21：经系统架构复查后确认：未保存 draft 测试不写入 `AIProviderValidationEvent`，只记录非敏感 diagnostic event；已保存 profile 测试才写入 `synthetic_test` validation event；明文 secret 不进入 Core `Equatable` 类型；第一阶段只真实支持 OpenAI Responses 和 OpenAI-compatible Chat adapter，Anthropic / Gemini 暂返回明确 unsupported 状态。

## 0. 实施者快速上下文

本任务把 AI Provider 设置页底部的“测试请求”从“本地配置完整性和 Keychain 可读性检查”推进到“文本模型合成网络探测”。它不是完整 AI 生成能力，不发送生活记录，不执行 Prompt Preset，也不测试 TTS、Embedding 或图片理解。

实施前必须保留以下硬边界：

- SwiftUI View 不直接使用 `URLSession`、Provider SDK、API Key、Authorization header 或 Keychain。
- 真实网络探测必须走 AI package 服务层，并通过 Core 中的输入 / 输出 / 错误类型暴露给 UI。
- 测试请求只发送合成检测内容，例如要求模型只返回 `OK` 的极短文本。
- API Key 只能来自当前页面短生命周期 draft 或已保存 Keychain 引用，不进入 SQLite、诊断日志、请求预览、测试输出或 UI 明文结果。
- 诊断只记录 provider、model、endpoint purpose、duration、status、error category、operation id 等非敏感字段。
- 第一阶段只支持文本模型 endpoint。语音生成、向量模型和图片理解即使在 UI 中已有配置，也不发真实测试请求。

推荐阅读顺序：

1. `docs/spec/005-ai-provider-prompt-and-privacy.md` 第 4.6、4.7 节。
2. `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 第 4.1、5、6 节。
3. `docs/platform-page-inventory.md` 中 `AIProviderSettingsView` 和三端设置详情条目。
4. `docs/plans/done/2026-05-20-feature-ai-provider-configuration-storage.md`。
5. `docs/plans/done/2026-05-20-feature-diagnostics-and-ai-provider-save-feedback.md`。
6. 本方案第 6、10、11、12 节。

## 1. 需求描述

用户在 AI Provider 设置页填写 Provider、Base URL、文本模型和 API Key 后，需要一个明确的配置测试入口，用来确认当前文本模型配置能否成功访问外部 Provider。当前“测试请求”只验证本地配置完整性和 Keychain 可读性，不发网络请求，不能证明 Base URL、模型名、API Key、Provider adapter 和外部服务响应是否可用。

本任务实现第一阶段真实测试请求：仅针对文本生成 endpoint 发起合成探测，返回成功或失败状态。已保存 profile 的测试记录非敏感 validation event 和 diagnostic event；未保存 draft 的测试只记录非敏感 diagnostic event。

## 2. 现状描述

当前代码事实：

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIBoundary.swift` 只有空 `AIProvider` 协议和 `DisabledAIProvider`，没有真实请求协议或 adapter。
- `LangoTraceApp/AppEnvironment.swift` 注入 `DisabledAIProvider()`，AI Provider 设置页通过 `AIProviderSettingsActions` 加载、保存、解析 Keychain secret 和验证本地凭证。
- `AIProviderConfigurationService.validateDefaultProfileCredentials()` 只读取已保存 profile，检查启用 endpoint 的 Keychain secret 是否可读，并写入 `AIProviderValidationEvent`；它不发网络。
- `AIProviderValidationEventType` 已包含 `syntheticTest` 和 `realRequestProbe`，`AIProviderValidationErrorCategory` 已包含网络、认证、Provider 拒绝、模型不支持、响应无效等分类，适合承载本任务结果。
- `AIProviderPreset` 已表达 Provider preset、默认 Base URL、默认文本模型、adapter kind、认证 header 种类和能力矩阵。
- `AIProviderDraftConfiguration.makeProfileSaveInput()` 可以把当前页面草稿转成保存输入，但测试未保存 draft 时不能直接依赖数据库中旧 profile。
- `AIProviderSettingsView.validateConfiguration()` 当前调用 `actions.validateDefaultProfileCredentials()`，并把 UI 状态设置为 mock succeeded / failed。
- `AIProviderSettingsTests.settingsSourceHasTestButtonWithoutNetworkOrBearerCalls` 当前明确锁定 View 不包含 `URLSession`、`dataTask`、`uploadTask`、`Authorization`、`Bearer`。

当前文档事实：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 明确：真实测试请求必须经过 Provider 层，不允许 SwiftUI View 直接创建具体服务请求；真实测试请求只能发送合成检测内容，不得发送生活记录、照片、音频、历史记忆、目标语言正文或 Prompt Preset 内容。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 明确：API Key、请求头、请求体、响应体、用户内容都不得进入诊断日志；Provider 配置页和真实请求读取 Keychain 必须由服务层完成。
- `docs/platform-page-inventory.md` 当前仍记录测试按钮只做本地配置完整性和 Keychain 可读性检查，需要在本任务完成后更新为“文本模型合成探测已接入；其他能力未接入真实测试”。

## 3. 目标

本任务完成后必须达到：

- 用户填写文本模型配置和 API Key 后，可以点击“测试请求”发起文本模型合成探测。
- 用户已保存配置后再次打开页面，即使没有新输入，也可以测试已保存的本机配置。
- 当前页面存在未保存修改时，测试当前 draft，而不是静默测试数据库中的旧配置。
- 测试请求只测试文本生成 endpoint。
- 测试请求只发送合成内容，不发送生活记录、照片、音频、历史记忆、目标语言正文或 Prompt Preset 内容。
- 测试成功显示简洁成功状态，例如 `测试成功`。
- 测试失败显示简洁失败状态，并按非敏感错误分类映射为可理解标题或短文案。
- 当前页面测试未保存 draft 时，只记录非敏感 diagnostic event，不写入数据库 validation event，避免用临时配置污染持久化事实。
- 已保存 profile 测试成功或失败时，写入 `synthetic_test` validation event，作为本机保存配置的最近可诊断事实。
- Provider adapter、URL 构造、Header 构造、响应解析和错误分类都在 AI package 中实现。
- UI package 不直接依赖 `URLSession`、Provider SDK、Authorization header 或 Keychain 细节。
- Data repository 继续只保存非敏感 validation event，不保存请求体、响应体、API Key 或完整请求头。
- iPhone、iPad、macOS 共享同一表单和同一测试 action；平台差异只体现在承载宽度和导航。

## 4. 范围

本任务覆盖：

- Core 层新增文本模型合成测试输入、输出、错误分类映射所需类型。
- AI 层新增文本模型合成测试服务和最小 adapter。
- AI 层支持当前第一批 Provider adapter 的保守实现策略。
- AppEnvironment 装配真实文本模型测试 action。
- UI draft 支持从当前页面草稿构造测试输入，且可以 fallback 到已保存配置。
- UI 状态机从 mock test 语义调整为 synthetic test 语义。
- UI 文案更新为真实测试请求状态。
- Data 层复用现有 validation event 表，只记录已保存 profile 的 `synthetic_test` 类型结果；未保存 draft 的临时测试不落 validation event。
- 单元测试覆盖请求构造、敏感字段不入日志、错误分类、UI action 边界和三端共享。
- 文档更新页面清单和 AI Provider / 隐私规范中的当前阶段事实。

## 5. 不做什么

本任务不实现：

- 不执行 Prompt Preset。
- 不发送生活记录、照片、音频、OCR 文本、历史记忆、目标语言正文或用户自定义长文本。
- 不测试 TTS endpoint。
- 不测试 Embedding endpoint。
- 不测试图片理解能力。
- 不实现请求预览 UI。本任务的合成探测内容固定且不包含用户内容；后续真实学习内容请求仍必须单独实现请求预览。
- 不实现完整请求日志、响应查看器、Prompt 调试器或开发者控制台。
- 不在 SwiftUI View 中拼接 HTTP 请求。
- 不在诊断日志、validation event 或测试输出中保存 API Key、完整请求头、请求体、响应体。
- 不引入官方托管 AI，不改变用户自带 Provider 决策。
- 不新增语言空间级 Provider 配置。

## 6. 备忘录检查

已检查：

- `docs/architecture/notes/README.md`
- `docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md`

结论：

- 当前唯一架构备忘录是语言空间同步扩展备忘录，适用范围为 Sync Engine、Adapter、Entry、附件、导出恢复和语言空间删除策略。
- 本任务属于 AI Provider 文本模型合成测试请求，不改变语言空间对象、同步对象、tombstone、device state 或 Sync Adapter。
- 该备忘录无直接采纳项。
- 本任务不需要新增 AI Provider 架构备忘录，因为真实测试请求边界已经进入 `docs/spec/005-ai-provider-prompt-and-privacy.md` 和本 active 方案；如果实施中发现后续多 Provider adapter、请求审计或离线队列的跨任务扩展风险，应再新增 `docs/architecture/notes/YYYY-MM-DD-ai-provider-request-adapter-notes.md`。

## 7. 证据与决策依据

代码依据：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift` 已有 endpoint、credential、validation event、validation status 和 error category 类型。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift` 已负责配置保存、本地凭证验证、Keychain 解析和 validation event 写入。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderCredentialStore.swift` 提供 `AIProviderCredentialStore` 和 `AIProviderCredentialResolver`，可以在服务层读取 Keychain secret。
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift` 已实现 `recordValidationEvent(_:)`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift` 是 UI 与 App / AI 服务层的 action seam。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 已通过环境注入 action，不直接访问数据库、Keychain 或网络。
- `LangoTraceApp/AppEnvironment.swift` 是合适的服务装配点，可以把 repository、credential store、diagnostic logger 和 URLSession-backed client 组合起来。

文档依据：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`：真实测试请求必须走 Provider 层；只允许发送合成检测内容；不得发送用户生活内容。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：诊断日志只允许非敏感枚举和值；不得保存 API Key、请求头、请求体、响应体或用户内容。
- `docs/decisions/005-local-first-and-user-owned-providers.md`：坚持本地优先和用户自带 Provider，敏感凭证进入 Keychain，默认不同步。
- `docs/platform-page-inventory.md`：AI Provider 设置页三端共享同一表单，真实 Provider 合成探测必须另开任务。

关键决策：

| 决策 | 结论 | 理由 | 防误读 |
| --- | --- | --- | --- |
| 第一阶段测试范围 | 只测文本生成 endpoint | 文本模型是 AI Provider 主路径；TTS / Embedding / 图片理解还缺独立请求契约和用户价值验证 | 不是说其他能力不需要测试，而是后续分任务接入。 |
| 测试内容 | 固定合成短文本 | 满足配置连通性验证，同时不触碰用户内容和请求预览复杂度 | 不允许把当前记录、Prompt Preset 或目标语言正文放入测试请求。 |
| 未保存 draft | 测当前 draft | 用户刚填写后点击测试，预期验证当前屏幕内容 | 不能静默测试旧的已保存配置。 |
| 已保存配置 | 无新输入时测已保存 profile | 用户复查配置时不应重复输入 API Key | 读取 Keychain 必须在服务层，不回传给 UI 日志。 |
| 网络层位置 | AI package | UI 不应拼接请求或持有密钥；Data 不应依赖网络 | AppEnvironment 只装配依赖，不承载请求构造细节。 |
| Adapter 策略 | 第一阶段真实支持 OpenAI Responses 和 OpenAI-compatible Chat；Anthropic / Gemini 明确 unsupported | 降低复杂度，先验证真实网络、密钥和错误分类边界，再分任务接入 Provider 专用协议 | unsupported 不是认证失败或网络失败，UI 必须用专门文案。 |
| 诊断记录 | saved profile 记录 validation event + diagnostic event；draft 只记录 diagnostic event | saved profile 有持久身份，draft 没有可靠 profileID，不能污染配置历史 | 不记录请求体、响应体、API Key、完整 header；不为 draft 生成临时 profile 事件。 |

## 8. 涉及的代码文件路径

预计新增：

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderTextProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderTextProbeHTTPClient.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderTextProbeServiceTests.swift`

预计修改：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIBoundary.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `docs/platform-page-inventory.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`

可能修改：

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`：仅当现有 validation event 写入无法表达 `synthetic_test` 的结果摘要时修改。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/AIProviderConfigurationRepositoryTests.swift`：仅当 Data 层写入行为需要补回归测试时修改。

## 9. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/Diagnostics.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfigurationSaveFailure.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderCredentialStore.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/KeychainAIProviderCredentialStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBDiagnosticEventRepository.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `docs/plans/done/2026-05-20-feature-ai-provider-configuration-storage.md`
- `docs/plans/done/2026-05-20-feature-diagnostics-and-ai-provider-save-feedback.md`
- `docs/plans/done/2026-05-20-bug-ai-provider-save-status-copy.md`
- `docs/plans/done/2026-05-20-chore-ipad-mac-ai-provider-save-feedback-consistency.md`

## 10. 涉及的文档路径

本方案创建：

- `docs/plans/active/2026-05-21-feature-ai-provider-text-model-test-request.md`

实施完成后预计更新：

- `docs/platform-page-inventory.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`

实施完成后预计不需要更新：

- `docs/decisions/005-local-first-and-user-owned-providers.md`：本任务沿用本地优先、用户自带 Provider 和 Keychain 存储决策，不改变 ADR。
- `docs/technical-framework-roadmap.md`：如果只落地文本模型合成探测且不改变 Provider 架构路线，可以不更新；若实现中新增通用 Provider adapter 架构，再做文档影响复查。
- `docs/architecture/notes/`：如果没有新增跨任务扩展风险，可以不新增备忘录。

## 11. 交互设计

### 11.1 测试入口

- 保留当前底部次按钮 `测试请求`。
- 保存按钮和测试按钮仍保持明确层级：保存是主操作，测试是次操作。
- 文本模型必填项完整后，测试按钮可触发。
- 如果用户还没有填写必填项，点击测试不显示成功样式，显示缺少必填项状态。
- 如果已有本机保存配置且当前没有新输入，点击测试使用已保存配置。
- 如果已有本机保存配置但当前页面存在新修改，点击测试使用当前 draft。

### 11.2 状态展示

测试状态建议：

- `idle`：不显示测试结果状态。
- `missingRequiredFields`：显示 `请补全配置`。
- `testing`：显示 `正在测试`，按钮禁用，避免重复请求。
- `succeeded`：显示 `测试成功`，绿色 check 样式，停留约 2 秒后自动消失。
- `failed(category)`：显示 `测试失败` 或错误分类对应短标题，红色 warning 样式，停留约 3 秒后自动消失。

与保存状态的关系：

- 测试状态和保存状态使用同一个底部状态卡片承载，但优先级为：测试进行中 / 测试结果高于保存成功提示；保存失败高于测试 idle。
- 用户修改输入时，清除已有测试成功 / 失败状态。
- 用户保存成功时，清除旧测试结果。
- 用户测试成功不等于自动保存配置；如果测试的是未保存 draft，仍应保留 `配置未保存` 提示或等价未保存状态。

### 11.3 文案原则

- 成功标题：`测试成功`。
- 失败标题：优先 `测试失败`，必要时映射为 `API Key 无效`、`网络不可用`、`模型不可用`、`响应异常`。
- 不展示“请求已发送以下内容”之类请求预览文案，因为本任务的合成测试内容固定且不含用户内容。
- 不展示 API Key、Base URL query、请求头或响应正文。
- 不使用开发术语如 `synthetic probe`、`validation event`、`adapter` 作为用户主路径文案。

## 12. 架构设计

### 12.1 Core 类型

在 Core 层只补足非敏感服务边界类型。明文 secret 不进入 Core 的 `Equatable` 类型，避免测试失败输出、debug dump 或 fixture diff 把 API Key 带出。建议命名可按实现微调，但语义保持：

```swift
public enum AIProviderTextProbeSource: String, Codable, Sendable {
    case draft
    case savedProfile = "saved_profile"
}

public struct AIProviderTextProbeDescriptor: Equatable, Sendable {
    public var endpoint: AIProviderEndpointConfiguration
    public var credential: AIProviderCredentialMetadata?
    public var source: AIProviderTextProbeSource
    public var operationID: DiagnosticOperationID
}

public struct AIProviderTextProbeResult: Equatable, Sendable {
    public var source: AIProviderTextProbeSource
    public var status: AIProviderValidationStatus
    public var errorCategory: AIProviderValidationErrorCategory?
    public var durationMilliseconds: Int?
    public var providerPresetID: String
    public var modelName: String
    public var persistedValidationEventID: AIProviderValidationEventID?
}
```

约束：

- Core descriptor 只能表达 endpoint、credential metadata、来源和 operation id，不包含 `plaintextSecret`、请求体、响应体或 Authorization header。
- AI package 内部可以定义非公开、非 `Equatable` 的临时 secret envelope，例如 `ResolvedTextProbeSecret`，只在构造请求前后短生命周期存在。
- 固定合成 prompt 由 AI service 内部常量提供，不来自 UI 文案、不来自用户输入、不进入 Core descriptor、诊断属性或 validation event。
- `persistedValidationEventID` 只在测试已保存 profile 且成功写入 validation event 时有值；draft 测试必须为 `nil`。

### 12.2 AI 服务层

新增 `AIProviderTextProbeService`，职责：

- 接收当前 draft 构造出的非持久化 text probe 输入，或加载已保存 profile 并从 Keychain 解析 secret。
- 选择文本 endpoint，忽略 TTS 和 Embedding endpoint。
- 规范化 Base URL，构造最小 HTTP 请求。
- 根据 adapter kind 调用对应最小文本探测 adapter。
- 将 HTTP / Provider / 解析错误映射到 `AIProviderValidationErrorCategory`。
- 对已保存 profile 写入 `AIProviderValidationEvent(eventType: .syntheticTest, ...)`。
- 对未保存 draft 不写 validation event，只记录非敏感 diagnostic event。
- 本地 provider 例如 `ollama-local` 允许没有 credential metadata 和 Authorization header；需要 API Key 的 provider 如果缺少 secret，返回 `.missingCredential`，不发网络。
- 处理 cancellation 和 timeout：用户取消或 Task 取消应返回 / 映射为 `.cancelled`，不写失败 validation event；请求超时映射为 `.timeout`，并记录 duration 和错误分类。

### 12.3 HTTP client seam

新增可测试 seam，避免单元测试真实访问网络：

```swift
public protocol AIProviderTextProbeHTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> AIProviderTextProbeHTTPResponse
}

public struct AIProviderTextProbeHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var body: Data
}
```

生产实现使用 `URLSession`，测试使用 fake client 捕获 request 并返回固定响应。网络实现只放在 `LangoTraceAI` target；Core / UI / Data 不引入 `URLRequest` 构造、`URLSession` 或 Provider SDK。当前 Swift package 目标为 iOS 18 / macOS 15，生产 client 可直接使用 Apple Foundation 网络类型；如果后续扩展到 Linux 测试，再单独做 `FoundationNetworking` 条件导入，不在本任务扩大平台范围。

### 12.4 Adapter 第一阶段策略

第一阶段真实支持：

- `openAICompatibleChat`
- `openAIResponses`

第一阶段明确不真实支持：

- `anthropicMessages`
- `geminiGenerateContent`

理由：

- 语迹当前仍处于 AI 请求能力的第一阶段，本任务目标是验证真实网络边界、密钥边界、错误分类和 UI 状态机，而不是一次性维护所有 Provider 专有协议。
- Anthropic / Gemini 的请求格式、认证头、版本参数和响应结构需要单独 adapter 审查；本阶段若临时实现，容易把未来真实学习请求的 Provider 层做成难以扩展的分支。
- 用户选择 Anthropic / Gemini 时，测试按钮仍可触发，但返回 `.unsupportedEndpointPurpose`，UI 显示“当前 Provider 暂不支持测试”或等价短文案。这不是网络失败、认证失败或模型失败，不能误导用户更换 API Key。

推荐请求内容：

- OpenAI-compatible Chat：`POST /chat/completions`，message 内容要求模型只回复 `OK`。
- OpenAI Responses：`POST /responses`，input 内容要求模型只回复 `OK`。
- 响应成功判定：HTTP 2xx 且可解析出非空文本；如文本不是 `OK`，仍可视为 Provider 可访问成功，但记录响应格式可解析即可。
- 解析测试必须分别覆盖 Chat `choices[].message.content` 和 Responses 输出文本路径；不能只检查 HTTP 2xx。

### 12.5 Draft 与已保存配置

测试输入来源优先级：

1. 当前页面存在用户修改：从 draft 构造临时文本 endpoint 和 secret。
2. 当前页面无修改且已加载保存配置：使用 profile 中的文本 endpoint 和对应 credential metadata，通过 Keychain 解析 secret。
3. 没有可测试配置：返回 `missingRequiredFields`。

草稿测试不得把未保存 API Key 先写入 Keychain。只有用户点击保存时才写 Keychain 和 SQLite。

为避免 UI action 猜测来源，`AIProviderDraftConfiguration` 需要新增显式来源判定：

- 新增只读状态或 helper，例如 `hasUnsavedChanges` / `canUseSavedProfileForTest` / `textProbeSource`，由 draft 内部根据 `profileID`、`hasPersistedConfiguration`、`saveState` 和输入变更维护。
- 新增专用 `makeTextProbeDraftInput(operationID:)`，只构造文本 endpoint、provider preset、adapter kind、base URL、model 和临时 secret；不得复用 `makeProfileSaveInput()` 后再拆分，因为保存输入会包含 TTS / Embedding endpoint 和 `credentialMode.newSecret`。
- draft 输入完整时优先测试 draft；已加载保存配置且没有未保存修改时测试 saved profile，并由 AI service 通过 Keychain 重新解析 secret，而不是依赖 UI draft 中回填的明文。
- 如果 profile 已保存但用户清空或修改了 API Key 字段，视为 draft 测试；缺少必需 secret 时返回 `missingRequiredFields` 或 `.missingCredential`，不回退到旧 Keychain secret。

### 12.6 诊断与 validation event

每次测试生成独立 operation id。允许记录：

- operation id。
- endpoint purpose：`text_generation`。
- provider preset id。
- adapter kind。
- model name。
- duration。
- status。
- error category。

禁止记录：

- API Key。
- Authorization header。
- 自定义敏感 header。
- 请求体。
- 响应体。
- Base URL query 中的敏感参数。
- 完整 Keychain account。
- 用户生活内容。

新增 Core typed diagnostic event name：

- `aiProviderTextProbeStarted`
- `aiProviderTextProbeSucceeded`
- `aiProviderTextProbeFailed`
- `aiProviderTextProbeUnsupported`
- `aiProviderTextProbeCancelled`

这些事件继续使用 `DiagnosticAttribute` allowlist 中的 `operationID`、`providerPresetID`、`endpointPurpose`、`modelName`、`durationMilliseconds` 和 `errorCategory`。如需要记录 adapter kind，应新增类型安全枚举属性，例如 `adapterKind(String)`，不得引入任意 key / value 日志入口。

validation event 写入规则：

- saved profile 测试：成功、认证失败、网络失败、timeout、unsupported、invalid response 等非取消结果写入 `AIProviderValidationEvent(eventType: .syntheticTest)`。
- draft 测试：不写 `AIProviderValidationEvent`，只写 diagnostic event。原因是 validation event schema 以持久 `profileID` 为事实归属，draft 没有可靠持久身份，不能用临时 profile id 污染配置历史。
- cancelled：只写 cancelled diagnostic event，不写失败 validation event，不更新 credential presence。

## 13. 实施方案

### 阶段 1：Core / AI 层测试优先

1. 在 `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderTextProbeServiceTests.swift` 新增失败测试：
   - OpenAI-compatible Chat 请求构造使用 `POST`。
   - 请求 URL 基于 Base URL 加 `/chat/completions`。
   - Authorization header 使用 API Key，但测试断言该 key 不出现在 validation event 或 diagnostic attributes。
   - 合成 prompt 不包含用户内容。
   - HTTP 401 映射为 `.authenticationFailed`。
   - HTTP 404 或模型错误响应映射为 `.unsupportedModel` 或 `.providerRejected`。
   - 超时 / transport error 映射为 `.networkUnavailable` 或 `.timeout`。
2. 在 `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/AIProviderTextProbeTests.swift` 或现有 Core AI Provider 测试中新增失败测试：
   - `AIProviderTextProbeDescriptor` 不包含 `plaintextSecret`、`requestBody`、`responseBody` 或 header 字段。
   - `AIProviderTextProbeResult.persistedValidationEventID` 可以表达 draft 未落库和 saved profile 已落库两种结果。
   - 新增 diagnostic event name 和 attribute key 后仍保持类型安全 allowlist。
3. 新增 `AIProviderTextProbeHTTPClient` fake，实现 request 捕获。
4. 新增 `AIProviderTextProbeService` 最小实现，让上述测试通过。
5. 为 `openAIResponses` 增加请求构造和成功解析测试。
6. 为 Anthropic / Gemini 增加明确 unsupported 测试，断言不发 HTTP 请求，结果分类为 `.unsupportedEndpointPurpose`，UI 可映射为“当前 Provider 暂不支持测试”。
7. 为 `ollama-local` 或无 API Key provider 增加测试，断言请求不带 Authorization header，缺少 credential 不被当成错误。
8. 增加 cancellation / timeout 测试，断言取消不写失败 validation event，timeout 映射为 `.timeout`。

### 阶段 2：Configuration service 集成

1. 在 `AIProviderConfigurationService` 或独立 service 中增加 `testDefaultTextEndpoint(...)`。
2. 支持从已保存 profile 读取文本 endpoint 和 credential metadata。
3. 通过 `AIProviderCredentialStore.resolveSecret` 读取 Keychain secret。
4. 对当前 draft 测试提供不落库的临时输入入口。
5. saved profile 测试成功 / 失败后调用 `repository.recordValidationEvent`，event type 使用 `.syntheticTest`。
6. draft 测试只调用 diagnostic logger，不调用 `repository.recordValidationEvent`、`repository.saveProfile` 或 Keychain 写入。
7. 增加 AI package 单元测试：
   - 已保存配置测试会解析 Keychain。
   - draft 测试不写 Keychain、不写 profile。
   - draft 测试不写 validation event。
   - saved profile 测试写 `synthetic_test` validation event。
   - 只选择 `.textGeneration` endpoint。
   - TTS / Embedding 启用时不会被测试。
   - 已保存配置测试不使用 UI draft 中回填的明文 secret，而是由服务层通过 Keychain 解析。

### 阶段 3：UI action 与状态机

1. 扩展 `AIProviderSettingsActions`：
   - 增加 `testTextModelConfiguration` action。
   - 输入包含 `AIProviderTextProbeSource` 和当前 draft 可生成的文本测试输入；当 source 是 saved profile 时由 action 内部读取已保存 profile。
   - 输出为 `AIProviderTextProbeResult` 或 UI 可映射的非敏感结果。
2. 扩展 `AIProviderTestState`：
   - 将 `mockTesting` / `mockSucceeded` / `mockFailed` 替换或兼容迁移为 `testing` / `succeeded` / `failed(category)`。
   - 增加 `unsupportedProvider` 或通过 `failed(.unsupportedEndpointPurpose)` 映射到专门文案，避免把 Anthropic / Gemini 暂不支持误显示为网络错误。
   - 保留 `missingRequiredFields`。
3. 扩展 `AIProviderDraftConfiguration`：
   - 新增 `hasUnsavedChanges` 或等价只读状态。
   - 新增 `textProbeSource`，明确当前点击应测试 draft 还是 saved profile。
   - 新增 `makeTextProbeDraftInput(operationID:)`，只生成文本模型测试所需字段和短生命周期 secret。
   - 用户修改输入时清除已有测试结果，保留或更新 `配置未保存` 状态。
4. 修改 `AIProviderSettingsView.validateConfiguration()`：
   - 不再调用 `validateDefaultProfileCredentials()` 作为主路径。
   - 点击后生成 operation id。
   - 当前 draft 完整时测试 draft。
   - 当前 draft 未修改但有已保存配置时测试已保存配置。
   - 测试期间禁用测试按钮，避免重复请求。
   - 成功 / 失败状态自动清除。
   - `statusTitleKey`、`statusIconName` 和 `statusTone` 需要合并 `testState` 和 `saveState`，优先级为：`testing` / 测试结果 > 保存失败 > 未保存修改 > 保存成功 > idle。
   - 测试成功不改变 `saveState`；如果 source 是 draft 且存在未保存修改，测试成功后仍展示或恢复 `配置未保存`。
5. 保持 View 源码不包含 `URLSession`、`Authorization`、`Bearer `、API Key 日志。
6. 更新 `Localizable.xcstrings` 中测试状态文案。

### 阶段 4：App 装配

1. 在 `LangoTraceApp/AppEnvironment.swift` 创建生产 `AIProviderTextProbeService`。
2. 注入 repository、credential store、diagnostic logger、URLSession-backed HTTP client。
3. 保留 `validateDefaultProfileCredentials` 作为本地凭证验证能力，避免破坏既有测试或后续诊断入口。
4. 确认 iPhone、iPad、macOS 共用同一 `AIProviderSettingsActions` 注入路径。

### 阶段 5：文档与验证

1. 更新 `docs/platform-page-inventory.md`：
   - AI Provider 设置页从 `Local Validation` 更新为 `Text Synthetic Probe` 或等价描述。
   - 明确测试按钮只接入文本模型合成探测，TTS / Embedding / 图片理解仍未接入真实测试。
2. 更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`：
   - 记录文本模型合成测试已接入的边界。
   - 保留真实学习内容请求必须请求预览的要求。
3. 更新 `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：
   - 记录合成测试诊断字段 allowlist。
4. 执行第 15 节验证命令。
5. 验证通过后把本方案状态更新为 `Implemented`，待用户测试通过后移动到 `docs/plans/done/` 并改为 `Verified` 或 `Done`。

## 14. 复查方法

代码复查：

- 搜索 `URLSession|dataTask|uploadTask|Authorization|Bearer `，确认只出现在 AI 层网络实现或测试 fixture 中，不出现在 UI View。
- 搜索 `plaintextSecret|apiKeyDraft|resolveSecret`，确认明文 secret 不进入 Data repository、诊断属性、Localizable 文案或 UI 结果。
- 搜索 `AIProviderTextProbeDescriptor` 和 Core probe 类型，确认 Core 类型不包含明文 secret、请求体、响应体或 header。
- 检查 `AIProviderSettingsView.validateConfiguration()`，确认它不直接构造 HTTP 请求。
- 检查 `AIProviderDraftConfiguration`，确认通过显式 `textProbeSource` 或等价状态决定测试 draft / saved profile，而不是在 View 中猜测。
- 检查 `AIProviderTextProbeService`，确认测试 prompt 是固定合成内容。
- 检查 validation event 写入，确认 saved profile 使用 `eventType == .syntheticTest`，draft 测试不写 validation event。
- 检查 fake HTTP client 测试，确认请求构造和错误映射被覆盖。
- 检查 Anthropic / Gemini unsupported 测试，确认不发 HTTP 请求且 UI 不显示为网络失败。
- 检查 `ollama-local` 无 API Key 路径，确认不构造 Authorization header。
- 检查三端设置入口，确认仍复用 `SettingsCapabilityDetailView` 和 `AIProviderSettingsView`。

隐私复查：

- 测试输出和日志中不得出现真实 API Key。
- 诊断 event attributes 不得包含请求体、响应体、Authorization header、Keychain account 或 Base URL query。
- 合成测试请求不得包含任何用户生活记录字段或 Prompt Preset 字段。
- draft 测试不得写入数据库 validation event，也不得生成临时 profile id 落库。
- cancelled 测试不得写入失败 validation event。

交互复查：

- 未填写必填项点击测试，不显示成功。
- 已填写未保存 draft 点击测试，测试当前 draft。
- 已保存配置无新输入点击测试，测试本机保存配置。
- 测试进行中重复点击不会发起并发请求。
- 成功 / 失败状态停留后自动消失。
- 测试成功不自动把未保存 draft 标记为已保存。
- Anthropic / Gemini 第一阶段显示“当前 Provider 暂不支持测试”或等价短文案，不显示“API Key 无效”或“网络不可用”。

## 15. 验证命令

实施完成后至少运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter AIProviderTextProbeTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderTextProbeServiceTests
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceData --filter AIProviderConfigurationRepositoryTests
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
scripts/verify.sh
```

如果 `AIProviderConfigurationRepositoryTests` 未修改且 Data 层行为没有变化，可仍运行该 filter 作为回归确认。

手动验证建议：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
```

真机或模拟器交互验证：

- 使用测试 Provider / 测试 API Key 验证成功路径。
- 使用错误 API Key 验证认证失败路径。
- 使用错误模型名验证 Provider 拒绝或模型不可用路径。
- 选择 Anthropic / Gemini 验证第一阶段 unsupported 文案，不误报为 API Key 或网络问题。
- 选择 Ollama / Local 验证无 API Key 路径不要求填写密钥且不带 Authorization header。
- 关闭网络或使用不可达 Base URL 验证网络失败路径。

## 16. 文档影响检查

本任务影响 AI Provider、隐私、诊断和三端页面事实，实施完成后必须检查：

- `docs/platform-page-inventory.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

预计结论：

- 需要更新页面清单和 `005` / `008`。
- 如果验证命令或发布前检查不变，`009` 可以不更新。
- ADR-005 不需要更新，因为本任务沿用用户自带 Provider、Keychain、本地优先和显式请求边界。

## 17. 实施记录

- 2026-05-21：创建 active 方案文档。已检查架构备忘录，确认当前唯一备忘录与本任务无直接采纳关系；方案采纳 `005` 和 `008` 中关于真实测试请求、Keychain、诊断日志和隐私边界的约束。
- 2026-05-21：按系统架构复查结论完善方案：明确 Core 只放非敏感 probe descriptor、AI 内部短生命周期持有 secret、draft 测试不写 validation event、saved profile 测试才写 `synthetic_test`、新增 typed diagnostic event、显式 draft / saved test source、第一阶段 unsupported provider 策略、Ollama 无密钥路径、timeout / cancellation 和 UI 状态优先级。

## 18. 完成标准

本任务完成需同时满足：

- 文本模型合成测试请求可以从 AI Provider 设置页触发。
- 未保存 draft 和已保存配置两条路径都可测试。
- 测试请求只发送固定合成内容。
- UI 层没有直接网络请求或密钥拼接。
- 成功、认证失败、网络失败、响应异常至少有单元测试覆盖。
- saved profile 测试的 validation event 记录 `synthetic_test`，且不含敏感内容。
- draft 测试不写 validation event，只写非敏感 diagnostic event。
- Anthropic / Gemini 第一阶段明确 unsupported，不发 HTTP 请求，不误映射为认证或网络失败。
- Ollama / Local 无 API Key 路径可以测试，不要求凭证，不构造 Authorization header。
- iPhone、iPad、macOS 仍复用同一设置表单。
- 相关规范和页面清单完成更新。
- 第 15 节验证命令通过；如有未运行项，实施记录写明原因和剩余风险。

## 19. 剩余风险

- 不同 Provider 的接口兼容度不一致。OpenAI-compatible endpoint 的成功不代表 Anthropic、Gemini 或聚合服务都能用同一种请求格式。
- Anthropic / Gemini 第一阶段会显示暂不支持测试。该限制是有意的 adapter 边界控制，不代表这些 Provider 不能作为未来真实文本模型使用；后续接入前需要单独审查请求格式、认证头、版本参数和响应解析。
- 某些 Provider 即使返回 2xx，也可能返回非标准错误体或安全策略提示，需要保守映射为响应异常或 Provider 拒绝。
- 本任务不实现请求预览，因此只能测试固定合成内容；后续真实学习内容请求仍必须单独设计请求预览和用户确认。
- 本任务不测试 TTS、Embedding 或图片理解；这些能力仍可能配置完整但运行期不可用。
- draft 测试只有 diagnostic event，没有 validation event 历史；这是为了避免临时配置污染持久 profile 事实。用户保存后再次测试，才会形成可持久追踪的 `synthetic_test` 记录。
- 模拟器网络成功不等于真机、公司代理、地区网络或 Provider 账户额度都可用；手动验证应覆盖错误 API Key、错误模型和不可达网络。

## 20. 方案自检

- 需求覆盖：已覆盖用户填写配置后测试文本模型配置的主路径，并明确未保存 draft、已保存配置、失败状态和诊断边界。
- 范围控制：已排除 TTS、Embedding、图片理解、Prompt Preset、请求预览和完整请求日志。
- 隐私边界：已明确 API Key、请求头、请求体、响应体、用户内容不进入日志、数据库和 UI 结果。
- 架构边界：已明确 UI 只调用 action，AI package 承载网络和 adapter，Core 只暴露非敏感 descriptor / result，Data 只保存已保存 profile 的非敏感 validation event。
- 文档边界：已列出实施后需要更新的页面清单和规范文档。
