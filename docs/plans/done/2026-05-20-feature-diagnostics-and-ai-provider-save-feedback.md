# 任务方案：AI Provider 保存反馈与本地诊断日志基础设施

状态：Done
类型：feature
创建日期：2026-05-20
最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户确认需要创建方案。确认背景：iOS 端输入 API Key 后点击“保存配置”没有明确提示；用户希望增加 `saving / saved / failed` 明确状态，并深入评估开发期详细日志、环境变量控制、产品上线后的操作日志和用户主动发送日志排查问题的能力。
- 本方案创建后仍需用户确认实施范围。状态为 `Draft` 时不开始实现。
- 2026-05-20：根据系统架构师和 Apple 应用交互设计复查，用户要求立即更新完善方案。采纳方向：第一阶段诊断持久化主要服务开发期和未来诊断能力打底，不声称解决产品期默认追溯；保存链路增加 `operationID`；诊断日志必须 best-effort，不得影响保存业务结果；快速保存反馈优先使用立即反馈和持久成功状态，不人为阻塞业务完成。
- 2026-05-20：用户确认修改无误后立即进入实施，并要求每个阶段都进行检查和测试，提交对应 commit。

## 1. 需求或 bug 描述

当前 AI Provider 设置页已经把非敏感配置写入 SQLite / GRDB，并把 API Key 写入 Keychain，但 iOS 端点击“保存配置”后的用户反馈不够明确。用户无法清楚判断按钮是否触发、保存是否仍在进行、是否保存成功、失败原因是什么。

同时，当前保存链路没有面向开发排查的非敏感日志。开发者在 iOS 模拟器或真机测试时，无法从系统日志或应用内诊断记录中稳定看到保存动作的关键阶段、耗时、错误分类和失败位置。产品上线后，如果用户反馈问题，也缺少一套本地优先、用户主动导出的诊断日志路径。

## 2. 实施前现状描述

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 的“保存配置”按钮直接调用 `saveConfiguration()`。
- `saveConfiguration()` 成功后调用 `draft.applySavedProfile(profile)`，失败时只设置 `draft.saveState = .saveFailed`。
- `statusTitleKey` 只对缺少必填项、成功和 idle 做可见标题分支；`.saveFailed` 没有独立可见分支。
- `AIProviderSaveState.saveFailed.titleKey` 当前复用 `aiProviderSettings.saveState.missingRequiredFields`，失败语义不准确。
- 当前保存成功文案是“配置已准备加密保存”，真实保存已经落地后，该文案不够准确。
- `AIProviderConfigurationService.saveDefaultProfile(_:)` 区分 Keychain 写入、数据库保存和补偿删除，但 UI 层只收到泛化错误状态。
- `validateDefaultProfileCredentials()` 会写入 `ai_provider_validation_events`，但“保存配置”动作本身不会记录诊断事件。
- 当前代码没有 `Logger`、`OSLog`、`os_log` 或应用内诊断日志基础设施。

## 3. 目标

1. AI Provider 设置页保存按钮具备明确的 `saving / saved / failed` 状态，用户在快速保存路径下也能感知操作已发生。
2. 保存成功后显示准确文案，明确配置已保存到本机安全存储，并且 API Key 明文草稿已清空。
3. 保存失败后显示非敏感、可理解的错误状态，不再复用“缺少必填项”。
4. 建立轻量本地诊断日志基础设施，支持记录隐私安全的结构化操作事件。
5. 开发期支持通过环境变量开启更详细的系统日志输出，便于 Xcode、Console.app、simulator log 和自动化测试排查。
6. 产品上线后保留本地优先的用户诊断路径：默认不上传，用户主动开启、查看摘要、导出或发送诊断包。本轮实现最小本地诊断事件 ring buffer 和 repository 能力，主要服务开发期验证和后续诊断设置页；在产品期诊断设置页落地前，不声称能够追溯用户此前未开启诊断时发生的问题。

## 4. 范围

本任务计划修改或新增：

- AI Provider 设置页保存按钮状态机和状态展示。
- AI Provider draft save state 枚举、文案 key 和 UI 渲染。
- AI Provider 保存链路的非敏感错误分类传递。
- Core 层诊断事件模型、类型安全属性白名单与日志接口。
- Data 层最小 `diagnostic_events` GRDB 持久化表、repository 和滚动保留策略。
- App 层环境装配，把诊断 logger 注入 UI action 或服务层。
- 开发期环境变量开关，例如 `LANGOTRACE_DIAGNOSTICS=1` 和 `LANGOTRACE_LOG_LEVEL=debug`。
- `scripts/verify.sh` 补充 `Packages/LangoTraceAI` 测试，避免 AI package 变更游离在统一验证入口之外。
- 测试覆盖：UI 源码/模型测试、诊断模型测试、Data ring buffer 测试、AI Provider 保存失败 phase / 分类测试。
- 长期规范更新：诊断日志、AI Provider 保存反馈、按钮 / 按键交互规范和用户导出诊断边界。

## 5. 不做什么

- 不记录 API Key、完整 Keychain account、请求头值、cookie、对象存储密钥、同步 token、完整日记、完整 OCR 文本、完整音频转写、完整 AI 请求体或响应体。
- 不默认上传日志，不接入远程分析、云端埋点、崩溃平台或后台遥测。
- 不在本轮实现完整“发送诊断包”UI、Share Sheet 导出、邮件发送或压缩包格式。
- 不在本轮实现真实 Provider 网络测试请求。
- 不改变 AI Provider 凭证存储策略：API Key 仍只进入 Keychain，默认不同步。
- 不把诊断日志作为恢复 API Key、恢复请求头或恢复用户内容的来源。

## 6. 证据与决策依据

实施前代码证据：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`：`saveConfiguration()` 失败时只设置 `.saveFailed`；状态展示未覆盖 `.saveFailed`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`：`AIProviderSaveState.saveFailed.titleKey` 复用缺少必填项文案。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`：保存成功文案仍是“配置已准备加密保存”。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`：保存链路包含 Keychain 写入、数据库写入和补偿清理阶段，适合记录非敏感阶段事件。
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`：当前 validation event 只覆盖本地凭证验证，不覆盖保存动作。

文档依据：

- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：诊断日志默认不得包含完整用户内容、API Key、请求头、对象存储密钥；发送诊断包必须先展示内容摘要并允许用户取消。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：Provider 日志可记录 provider、模型、耗时、状态和错误码；不得记录 API Key、完整请求头、完整日记原文、完整 AI 请求体和对象存储密钥；服务层应保留可诊断错误类型。
- `docs/spec/004-swiftui-architecture.md`：View 不直接访问 SQLite、Keychain、网络或具体 Provider；UI 状态应能表达 loading、succeeded、failed 和可诊断错误码。
- `docs/spec/003-ui-design-system.md`：已有触控尺寸、主次操作层级、图标按钮可访问性、状态组件、loading / error 等基础规则，但缺少集中、可复用的按钮 / 按键交互规范。
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`：包含 `Primary / Secondary / Tertiary / Destructive` action hierarchy，但该文档状态为 Draft，不适合作为长期唯一权威源。
- `docs/README.md`：AI、隐私、数据和测试相关任务实现前必须先创建 active plan，并在形成长期判断时更新对应文档。

设计决策：

- 保存反馈采用“状态面板 + 按钮内进度”的组合，不使用短暂 toast 作为唯一反馈。
- `saving` 状态用于表达保存已触发；快速保存路径不人为延迟底层业务完成，也不继续锁住输入。最终可感知性由持久 `saved` / `failed` 状态面板保证。
- 开发期系统日志和产品期本地诊断事件分层。系统日志通过环境变量控制；本地诊断事件通过应用内设置或注入配置控制。
- 操作日志不是“记录任何操作原文”，而是记录隐私安全的结构化事件。
- 第一阶段必须实现最小 `diagnostic_events` 本地 ring buffer，但默认产品运行不写入。原因：本轮需要先固定事件模型、repository、保留策略和隐私边界，避免未来诊断设置页落地时重新设计数据来源；最小 ring buffer 不等于完整诊断包导出 UI，也不等于产品期默认追踪用户操作。
- 诊断事件属性必须采用类型安全 allowlist，不能提供任意 `key/value` 写入入口。
- 保存链路诊断事件必须具备同一次操作可关联能力，使用非敏感 `operationID` 串联 UI 总事件和服务层阶段事件。`operationID` 不能复用 profile ID、credential ID、Keychain account 或任何可反推出用户配置身份的值。
- 诊断日志必须是 best-effort。Console 或 repository 诊断写入失败不能改变 AI Provider 配置保存的业务结果，也不能把诊断故障展示成保存失败。
- 保存失败的 `phase` 必须由服务层错误上下文提供，UI 层不得靠 thrown error 文案或调用位置猜测。
- 环境变量读取只允许在 App 装配层完成；Core、AI、Data、UI package 不直接读取 `ProcessInfo.processInfo.environment`。
- 快速保存反馈不通过人为拖慢业务完成来制造可感知性。保存执行中由按钮内进度表达正在处理；业务保存一旦完成，应及时恢复输入可用性，并通过持久 saved / failed 状态面板表达结果。
- 按钮 / 按键交互规范应沉淀到 `docs/spec/003-ui-design-system.md`，不另建同级规范文件。原因：按钮层级、触控尺寸、反馈状态、危险操作和图标按钮属于 UI 设计系统的一部分；单独拆文件会增加规范入口数量，且当前 `003` 已承载组件风格和状态设计。

## 7. 涉及的代码文件路径

预计修改：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/Diagnostics.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/DiagnosticsTests.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationServiceTests.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBDiagnosticEventRepository.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/DiagnosticEventRepositoryTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `scripts/verify.sh`

可能新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticLogger.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfigurationSaveFailure.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticAttribute.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/InMemoryDiagnosticEventRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/DiagnosticRetentionPolicy.swift`

第一阶段必须新增 GRDB `diagnostic_events` 表，但只实现最小 ring buffer，不实现用户导出 UI。默认产品运行不上传、不远程发送；本地持久化是否写入由 App 层诊断配置控制。

## 8. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`
- `scripts/verify.sh`
- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`

## 9. 涉及的文档路径

预计修改：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/004-swiftui-architecture.md`

预计参考：

- `docs/README.md`
- `docs/plans/README.md`
- `docs/plans/done/2026-05-20-feature-ai-provider-configuration-storage.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`

## 10. bug 分析

本任务含一个可观察 bug 子问题。以下为实施前分析。

```text
复现方式：
1. iOS 端进入 AI Provider 设置页。
2. 输入 Base URL、模型名和 API Key。
3. 点击“保存配置”。

预期行为：
按钮和状态区域立即显示正在保存；保存成功后明确显示已保存；保存失败后显示失败状态和非敏感错误分类。

实际行为：
页面没有明确的保存中反馈；成功文案不准确；失败状态没有独立可见文案。

根因分析：
AIProviderSaveState 缺少 saving 状态；saveFailed 文案复用 missingRequiredFields；AIProviderSettingsView.statusTitleKey 未渲染 saveFailed；保存按钮没有进度和最短可见反馈。

置信度：90%

置信度依据：
代码路径已经确认：saveConfiguration() 成功和失败只改变 draft 状态；statusPanel 是唯一可见反馈；状态分支遗漏 saveFailed。

备选原因：
如果用户操作时页面底部状态面板不在可视范围内，即使状态有变化也可能被用户误认为没有反馈。这需要通过按钮内进度和状态面板共同解决。

回归测试方案：
新增或更新 UI 模型测试，验证 saving、saved、failed 三类状态拥有独立文案 key；源码测试确认保存按钮渲染 ProgressView 和 disabled 状态；手动在 iOS 模拟器验证快速保存也能看到保存中状态。
```

## 11. 实施方案

### 11.1 保存状态机与 UI 反馈

1. 扩展 `AIProviderSaveState`：
   - `idle`
   - `missingRequiredFields`
   - `saving`
   - `saved`
   - `failed(AIProviderSaveFailureDisplay)` 或等价可测试结构
2. 为保存失败定义可展示、非敏感分类：
   - `missingRequiredField`
   - `invalidEndpoint`
   - `keychainWriteFailed`
   - `databaseWriteFailed`
   - `credentialCleanupFailed`
   - `unknown`
3. 为保存失败定义服务层 phase，UI 只能使用服务层提供的 phase，不自行猜测：
   - `inputValidation`
   - `keychainWrite`
   - `databaseWrite`
   - `credentialCleanup`
   - `unknown`
4. `saveConfiguration()` 点击后立即：
   - 生成本次保存操作的非敏感 `operationID`
   - 记录 `ai_provider_settings.save_tapped`，携带 `operationID`
   - 先构造 save input。输入无效时设置 `saveState = .missingRequiredFields`，记录 `ai_provider_settings.save_input_invalid` 并返回，不把它归类为真实保存失败
   - 输入有效后设置 `saveState = .saving`
   - 禁用保存按钮和测试按钮
   - 记录 `ai_provider_settings.save_started`，携带 `operationID`
5. 保存成功后：
   - 调用 `applySavedProfile(profile)`
   - 清空明文 API Key 草稿
   - 设置 `saveState = .saved`
   - 记录 `ai_provider_settings.save_succeeded`，携带 `operationID`
6. 保存失败后：
   - 将服务层错误上下文映射为非敏感错误分类和 phase
   - 设置 `saveState = .failed(mappedFailure)`
   - 记录 `ai_provider_settings.save_failed`，携带 `operationID`
7. 快速保存反馈：
   - 保存动作完成过快时，不人为延迟底层保存结果，不为了展示 spinner 继续阻塞用户编辑
   - 按钮在真实保存执行中显示 `ProgressView`，保存完成后由状态面板持久展示 saved / failed 结果，避免依赖一闪而过的按钮文案
   - 如后续用户测试证明 spinner 不可感知，可单独评估视觉层最短 affordance，但不得改变业务完成时机或保存事务边界
8. UI 表现：
   - 保存按钮在 `.saving` 时显示 `ProgressView` 和“正在保存...”
   - `.saving` 时按钮 disabled
   - `.saved` 状态使用 checkmark 图标和 accent / success tone
   - `.failed` 状态使用 warning / danger tone，并显示失败标题和简短恢复建议
9. 状态优先级与清除规则：
   - 状态面板优先级为 `saving > failed > saved > invalid > idle`
   - `missingRequiredFields` 不能覆盖刚发生的 `failed`，否则会把保存失败误显示为输入缺失
   - 用户修改会影响保存输入的字段时，清除上一轮 `saved` / `failed` 结果并重新计算 invalid
   - 测试请求状态只能作为次级信息展示，不得覆盖保存状态主标题
   - 如果用户重复点击保存，必须创建新的 `operationID`，上一轮未完成任务应被忽略、取消或通过最后一次操作优先生效规则处理；具体采用哪一种需要在实现中保持可测试

### 11.2 保存错误上下文

新增 Core 层保存失败上下文，避免 UI 层猜测失败阶段：

```swift
public struct AIProviderConfigurationSaveFailure: Error, Equatable, Sendable {
    public var operationID: DiagnosticOperationID?
    public var phase: AIProviderConfigurationSavePhase
    public var category: AIProviderConfigurationSaveFailureCategory
    public var cleanupFailure: AIProviderConfigurationSaveFailureCategory?
}

public enum AIProviderConfigurationSavePhase: String, Codable, Sendable {
    case inputValidation = "input_validation"
    case keychainWrite = "keychain_write"
    case databaseWrite = "database_write"
    case credentialCleanup = "credential_cleanup"
    case unknown
}

public enum AIProviderConfigurationSaveFailureCategory: String, Codable, Sendable {
    case missingRequiredEndpointField = "missing_required_endpoint_field"
    case missingRequiredAPIKey = "missing_required_api_key"
    case invalidBaseURL = "invalid_base_url"
    case keychainWriteFailed = "keychain_write_failed"
    case databaseWriteFailed = "database_write_failed"
    case credentialCleanupFailed = "credential_cleanup_failed"
    case unknown
}
```

实施约束：

- `AIProviderConfigurationService.saveDefaultProfile(_:)` 在 Keychain、DB、cleanup 失败时抛出带 phase 的 `AIProviderConfigurationSaveFailure` 或等价类型。
- `AIProviderConfigurationService.saveDefaultProfile(_:)` 应接收或构造一个非敏感 operation context，使 UI 总事件和服务层阶段事件能被同一 `operationID` 串联；如果 UI 已生成 `operationID`，服务层必须沿用。
- 如果数据库失败后 cleanup 也失败，错误必须保留原始 `databaseWrite` phase，并在 `cleanupFailure` 中记录 cleanup 分类；不得让 cleanup 错误完全覆盖原始失败原因。
- UI 展示只使用 category 的本地化文案；日志可记录 phase 和 category；都不得包含 secret。

### 11.3 诊断事件模型

新增 Core 层诊断模型，保持与 UI、AI、Data 解耦。属性必须使用类型安全 allowlist：

```swift
public struct DiagnosticOperationID: RawRepresentable, Equatable, Hashable, Codable, Sendable {
    public var rawValue: String
}

public struct DiagnosticEvent: Equatable, Sendable {
    public var id: String
    public var name: DiagnosticEventName
    public var domain: DiagnosticDomain
    public var level: DiagnosticLevel
    public var outcome: DiagnosticOutcome?
    public var attributes: [DiagnosticAttribute]
    public var createdAt: Date
}

public enum DiagnosticEventName: String, Codable, Sendable {
    case aiProviderSettingsSaveTapped = "ai_provider_settings.save_tapped"
    case aiProviderSettingsSaveInputInvalid = "ai_provider_settings.save_input_invalid"
    case aiProviderSettingsSaveStarted = "ai_provider_settings.save_started"
    case aiProviderSettingsSaveSucceeded = "ai_provider_settings.save_succeeded"
    case aiProviderSettingsSaveFailed = "ai_provider_settings.save_failed"
    case aiProviderConfigurationKeychainWriteStarted = "ai_provider_configuration.keychain_write_started"
    case aiProviderConfigurationKeychainWriteSucceeded = "ai_provider_configuration.keychain_write_succeeded"
    case aiProviderConfigurationKeychainWriteFailed = "ai_provider_configuration.keychain_write_failed"
    case aiProviderConfigurationDatabaseWriteStarted = "ai_provider_configuration.database_write_started"
    case aiProviderConfigurationDatabaseWriteSucceeded = "ai_provider_configuration.database_write_succeeded"
    case aiProviderConfigurationDatabaseWriteFailed = "ai_provider_configuration.database_write_failed"
    case aiProviderConfigurationCleanupStarted = "ai_provider_configuration.cleanup_started"
    case aiProviderConfigurationCleanupSucceeded = "ai_provider_configuration.cleanup_succeeded"
    case aiProviderConfigurationCleanupFailed = "ai_provider_configuration.cleanup_failed"
}

public enum DiagnosticDomain: String, Codable, Sendable {
    case aiProviderSettings = "ai_provider_settings"
    case permissions
    case dataStorage = "data_storage"
    case appLifecycle = "app_lifecycle"
}

public enum DiagnosticLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
}

public enum DiagnosticOutcome: String, Codable, Sendable {
    case started
    case succeeded
    case failed
    case cancelled
}

public enum DiagnosticAttribute: Equatable, Sendable {
    case operationID(DiagnosticOperationID)
    case providerPresetID(String)
    case endpointPurpose(AIProviderEndpointPurpose)
    case endpointCount(Int)
    case enabledEndpointCount(Int)
    case modelName(String)
    case durationMilliseconds(Int)
    case errorCategory(String)
    case failurePhase(String)
    case platform(String)
    case appVersion(String)
    case diagnosticsMode(String)
}
```

约束：

- `DiagnosticEvent.name` 必须使用 `DiagnosticEventName` 或等价的类型安全事件名，不允许调用点自由拼接事件名字符串。
- `DiagnosticAttribute` 只能通过 enum case 构造，不提供公开的任意 `key/value` initializer。
- Data 层序列化时把 enum case 映射成稳定 `attribute_key` / `attribute_value`，但调用方不能自由指定 key。
- `operationID` 只用于同一次操作内部关联，必须由 UUID 或等价随机 ID 生成；不得使用 profile ID、endpoint ID、credential ID、Keychain account、Base URL、modelName 或用户输入派生值。
- `modelName` 虽然通常不是 secret，但需要限制长度并禁止记录疑似包含 token 的 query / header 片段；如果实现阶段无法可靠判断，第一阶段可以暂不记录 modelName，只记录 provider 和 endpoint purpose。
- 不提供自由记录 API Key、请求头、正文、完整 Base URL、完整文件路径的便利 API。
- 如果后续需要记录文件路径，只能记录 file kind、extension、security scoped access 状态或路径脱敏摘要。

### 11.4 诊断 logger、repository 与模块边界

新增协议：

```swift
public protocol DiagnosticLogging: Sendable {
    func record(_ event: DiagnosticEvent) async
}
```

新增本地 repository 协议：

```swift
public protocol DiagnosticEventRepository: Sendable {
    func record(_ event: DiagnosticEvent) async throws
    func recentEvents(limit: Int) async throws -> [DiagnosticEvent]
    func prune(keepingMostRecent count: Int, newerThan cutoff: Date) async throws
}
```

实现建议：

- `DisabledDiagnosticLogger`：默认空实现。
- `ConsoleDiagnosticLogger`：开发期开启后写入 `Logger(subsystem: "com.zibuyu.LangoTrace", category: ...)`。
- `RepositoryDiagnosticLogger`：写入 `DiagnosticEventRepository`。
- `CompositeDiagnosticLogger`：同时写入系统日志和本地 ring buffer。
- `InMemoryDiagnosticLogger` / `InMemoryDiagnosticEventRepository`：测试使用。
- `GRDBDiagnosticEventRepository`：Data 层实现，写入 `diagnostic_events` 表。

强制约束：

- `DiagnosticLogging.record(_:)` 必须保持 non-throwing，诊断失败不能向业务调用方冒泡。
- `RepositoryDiagnosticLogger` 调用 repository 失败时只能静默丢弃、写入开发期 Console warning 或更新测试可观察计数；不得导致 AI Provider 保存、验证、加载或 UI 状态更新失败。
- `CompositeDiagnosticLogger` 中任一 logger 失败或耗时过长，都不得阻塞其他 logger 或业务结果；第一阶段可以串行 best-effort，实现复杂度上升时再考虑后台队列。
- 日志对象不得持有或缓存 API Key 明文、请求头值、完整 Base URL、用户内容或 Keychain account。

模块归属必须固定：

- Core：`DiagnosticEvent`、`DiagnosticAttribute`、`DiagnosticLogging`、`DiagnosticEventRepository`、AI Provider save failure context。
- Data：`GRDBDiagnosticEventRepository`、`InMemoryDiagnosticEventRepository`、`DiagnosticRetentionPolicy`、`diagnostic_events` migration。
- AI：只依赖 Core 的 logger 和错误上下文，不依赖 Data。
- UI：通过 injected action / logger 记录 UI 操作事件，不直接访问 Data。
- App：读取环境变量，创建 Disabled / Console / Repository / Composite logger，并注入 UI actions 和服务层。

开关策略：

- 环境变量 `LANGOTRACE_DIAGNOSTICS=1`：启用 Console 结构化日志。
- 环境变量 `LANGOTRACE_DIAGNOSTIC_STORE=1`：开发期启用本地 ring buffer 写入；产品期由未来 App 内设置控制。
- 环境变量 `LANGOTRACE_LOG_LEVEL=debug|info|warning|error`：控制最低输出级别。
- 环境变量只允许在 `LangoTraceApp/AppEnvironment.swift` 或 App 层诊断配置工厂读取；Core、AI、Data、UI package 不直接访问 `ProcessInfo.processInfo.environment`。
- 非 debug/release 通用行为：环境变量只能影响当前运行实例，不写入用户偏好。
- 产品期 App 内“启用本机诊断日志”设置作为后续 UI 任务；在该设置页落地前，release 默认不写入本地诊断 store。因此第一阶段不能承诺用户未开启诊断前的问题可被事后追溯。

### 11.5 本地诊断事件持久化

第一阶段新增 `diagnostic_events` 表，但保持最小字段和滚动保留：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | TEXT primary key | UUID。 |
| `name` | TEXT not null | 稳定事件名。 |
| `domain` | TEXT not null | `ai_provider_settings` 等。 |
| `level` | TEXT not null | `debug`、`info`、`warning`、`error`。 |
| `outcome` | TEXT nullable | `started`、`succeeded`、`failed`、`cancelled`。 |
| `operation_id` | TEXT nullable | 单次操作关联 ID；不得使用 profile / credential / Keychain 标识。 |
| `attributes_json` | TEXT not null | 由类型安全 `DiagnosticAttribute` 序列化，禁止任意 key。 |
| `created_at` | TEXT not null | ISO-8601 或现有 DB 日期格式。 |

索引：

- `idx_diagnostic_events_created_at`
- `idx_diagnostic_events_domain_created_at`
- `idx_diagnostic_events_operation_id_created_at`

保留策略：

- 第一阶段默认保留最近 1000 条或最近 7 天，以更严格者为准。
- 每次写入后可异步触发轻量 prune；测试必须覆盖数量和时间双限制。
- 诊断事件不进入普通用户数据导出包，不进入同步目录。后续“诊断包导出”必须单独走摘要确认和用户主动分享。
- 如果诊断 store 未启用，repository 不应被写入；Console 诊断和 repository 诊断分别由 App 层配置控制。

### 11.6 AI Provider 保存链路事件

保存动作至少记录以下事件：

| 事件名 | 时机 | level | outcome | 允许属性 |
| --- | --- | --- | --- | --- |
| `ai_provider_settings.save_tapped` | 用户点击保存按钮 | info | started | operation_id、provider、enabled_endpoint_count |
| `ai_provider_settings.save_input_invalid` | 表单输入无法生成 save input | warning | failed | operation_id、error_category |
| `ai_provider_settings.save_started` | 调用服务层前 | info | started | operation_id、provider、endpoint_purposes |
| `ai_provider_settings.save_succeeded` | profile 保存成功 | info | succeeded | operation_id、provider、endpoint_count、duration_ms |
| `ai_provider_settings.save_failed` | 保存失败 | error | failed | operation_id、error_category、phase、duration_ms |

服务层必须记录更细阶段，且仍不得记录 secret：

- `ai_provider_configuration.keychain_write_started`
- `ai_provider_configuration.keychain_write_succeeded`
- `ai_provider_configuration.keychain_write_failed`
- `ai_provider_configuration.database_write_started`
- `ai_provider_configuration.database_write_succeeded`
- `ai_provider_configuration.database_write_failed`
- `ai_provider_configuration.cleanup_started`
- `ai_provider_configuration.cleanup_succeeded`
- `ai_provider_configuration.cleanup_failed`

第一阶段不得只在 UI action 层记录总事件。原因：用户反馈“保存失败”时，开发者需要区分输入校验、Keychain、DB 和 cleanup 失败；如果 phase 只由 UI 猜测，日志不可作为排查证据。
所有服务层阶段事件必须携带同一 `operationID`；如果缺少 operation context，服务层可以生成新的 `operationID`，但 UI 总事件和服务层事件将无法关联，因此 UI 保存路径必须传入。

### 11.7 未来诊断包导出边界

推荐分阶段：

第一阶段：

- 实现 Core 诊断模型和 logger 协议。
- 实现 Console logger、Disabled logger、Repository logger、Composite logger 和 InMemory logger。
- 实现 GRDB `diagnostic_events` ring buffer。
- AI Provider 保存链路接入 UI 总事件和服务层阶段事件。
- 文档明确用户诊断包导出边界。
- 明确第一阶段不提供产品期用户可见诊断开关，因此 release 默认不写入诊断 store；这意味着不能追溯用户未开启诊断前发生的问题。

第二阶段：

- 增加“隐私与诊断”设置页入口。
- 支持用户查看摘要、清除日志、导出诊断包。
- 支持导出前摘要，例如时间范围、事件数量、模块列表、敏感字段排除声明。
- 由用户明确开启本机诊断日志后，才在产品期写入本地 ring buffer；设置页必须说明会记录哪些非敏感事件、保留多久、如何清除。

第一阶段不实现完整导出 UI，但必须具备持久化事件基础。这样后续用户主动开启并发送日志时，不需要重新设计事件模型和数据来源；但它不解决“未开启前的历史追溯”。

### 11.8 统一验证脚本更新

`scripts/verify.sh` 当前运行 Core、Data、UI package tests，但不运行 AI package tests。本任务会修改 `Packages/LangoTraceAI`，必须把以下命令加入统一验证脚本：

```bash
swift test --package-path Packages/LangoTraceAI
```

同步检查 `docs/spec/009-testing-and-verification.md` 是否需要补充 AI package test 为默认验证面。

### 11.9 文档更新

更新 `docs/spec/003-ui-design-system.md`：

- 新增“按钮与操作反馈规范”章节，作为长期按钮 / 按键交互权威入口。
- 明确按钮层级：
  - Primary：创建、保存、继续、生成、本地预览等主路径动作；每个主区域同一时间只能有一个主按钮。
  - Secondary：测试、筛选、查看详情、打开设置说明、切换面板等支持动作。
  - Tertiary / icon：播放、收藏、更多、gear、AI / Sync 状态图标；必须有 accessibility label / value / hint，macOS 可补 tooltip。
  - Destructive：删除、清空、重置、断开连接等危险操作；必须有确认、可恢复或导出前置。
  - Inline：句子行、列表行、表单行内的小动作；不能抢占主操作层级。
- 明确平台差异：
  - iPhone：触控优先，关键主操作优先放在易触达区域；触控目标不低于 44pt；高频主按钮可以使用全宽或接近全宽承载，但同一屏不能堆多个同权重主按钮；异步保存、生成、删除等操作必须在按钮本体或紧邻状态区域给出反馈。
  - iPad：触控、指针、硬件键盘和 Stage Manager 并存；regular 宽度可把主操作放在顶部工具条、侧栏底部或内容区上下文位置，但 compact / Slide Over 下必须退化为 iPhone 可触达模式；图标按钮不能只依赖 hover 或颜色表达状态；可收起面板、侧栏、Inspector、AI / Sync 状态等图标按钮必须有动态 label / value；关键命令应能被键盘触发或通过可见按钮替代。
  - macOS：允许更紧凑的 toolbar / sidebar 操作，但不能简单沿用 44pt 移动按钮形态；关键命令必须有 menu bar 或 keyboard shortcut 镜像，toolbar 按钮应提供 tooltip 和可访问名称；窗口变窄时按钮可以进入 overflow / menu，但不能变成空 action； destructive 和不可逆操作必须通过 confirmation dialog、菜单项 role 或等价确认路径表达。
- 明确跨平台共同底线：
  - 所有平台都必须使用真实 `Button` / `Menu` / `Toggle` / `Picker` 等语义控件，不用裸 `onTapGesture` 模拟按钮，除非确有手势语义且另有可访问替代。
  - 图标按钮必须有可访问名称；状态按钮还必须有 value 或 hint，不能只靠图标、颜色或 tooltip。
  - Button label 文案必须可本地化，不能硬编码中文或英文；最长本地化文案不得撑破按钮容器。
  - 主要动作、次要动作、危险动作不能只靠颜色区分，必须通过位置、样式、图标、文案和状态共同表达。
  - 表单提交按钮必须在输入无效、保存中、保存成功、保存失败四类状态下都有明确表现。
  - 如果按钮触发真实副作用，必须明确该副作用属于本地、Keychain、数据库、外部 Provider、同步、导出或删除中的哪一类。
- 明确异步按钮状态：
  - `idle`
  - `loading` / `saving` / `running`
  - `success` / `saved`
  - `failed`
  - `cancelled`，仅当用户可取消时需要。
- 明确保存 / 提交类按钮必须有可感知反馈：保存中、保存成功、保存失败不能只依赖短暂 toast；快速路径也应有按钮内进度或持久状态面板。
- 明确状态持续时间：
  - `loading` / `saving` 如果可能低于用户感知阈值，应通过完成后持久状态保持结果可见；如需最短可见时长，只能作为视觉 affordance，不得改变业务完成时机。
  - `success` 可以是持久状态、状态面板、按钮文案变化或轻量反馈，但不能只在不可见位置闪现。
  - `failed` 必须保留到用户修改输入、重试、关闭页面或显式清除。
- 明确禁用状态要求：禁用按钮必须有可理解原因或临近恢复路径，不能只灰掉；如果原因和当前上下文无关，应优先隐藏或改为 unavailable 说明。
- 明确按钮文案：动词明确，避免用“确定”“好的”承载复杂动作；危险操作文案应说明对象，例如“删除语言空间”而不是“删除”。
- 明确图标按钮：优先使用系统图标；必须有辅助标签；状态不能只靠颜色表达；可收起面板、播放、测试、设置、AI / Sync 状态等图标按钮需要动态 label / value。
- 明确不同按钮类型的默认承载：
  - 创建 / 继续 / 保存：优先 Primary。
  - 测试 / 验证 / 预览：优先 Secondary，除非它是当前页面唯一主任务。
  - 播放 / 收藏 / 设置 / 面板切换：优先 Icon 或 Tertiary，并提供辅助信息。
  - 删除 / 清空 / 重置：必须 Destructive，且不能和普通 Primary 混用同一视觉。
  - 菜单型多选项：使用 Menu / Picker，不把多个互斥选择做成一排同权重按钮。
- 明确禁止模式：
  - 不用禁用按钮代替解释。
  - 不把未接入能力按钮做成可执行主按钮。
  - 不在同一区域放多个同样醒目的 Primary。
  - 不把 macOS 菜单命令只放 toolbar 而没有 menu / shortcut 路径。
  - 不把 iPad regular 布局的宽屏按钮原样挤进 compact / Slide Over。
  - 不用纯图标表达危险操作。
- 明确复查清单：可见、可点、可访问、动态字体不溢出、状态不只靠颜色、异步状态完整、危险操作可恢复或有确认、iPhone / iPad compact / iPad regular / macOS 窗口缩窄下都有合理承载。

更新 `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：

- 明确开发期系统日志和产品期本地诊断事件的分层。
- 明确环境变量只作为开发期开关，不作为 App Store 用户主要开关。
- 明确产品期本地诊断 store 在用户可见开关落地前默认关闭，不承诺追溯未开启前的用户问题。
- 明确用户诊断包必须本地生成、主动导出、先展示摘要、默认不上传。
- 明确最小本地诊断 ring buffer 的默认保留策略、默认不上传和不进入普通导出/同步。

更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`：

- 补充 AI Provider 配置保存动作可记录非敏感诊断事件。
- 明确保存日志不得包含 API Key、完整 Keychain account、完整 Base URL query 中可能携带的 secret、请求头值或用户内容。

更新 `docs/spec/004-swiftui-architecture.md`：

- 补充异步保存按钮必须有 loading、success、failure 状态，失败状态应带可诊断错误码。
- 与 `003` 的按钮规范保持一致：SwiftUI 状态模型负责表达底层状态，UI 组件负责按按钮规范呈现触达、反馈、无障碍和平台差异。

## 12. 复查方法

代码复查：

- 检查 `AIProviderSettingsView` 不直接访问 SQLite、Keychain、网络或 Provider SDK。
- 检查保存按钮 `.saving` 时有进度和 disabled 状态，保存完成后有持久 saved / failed 反馈。
- 检查 `.failed` 状态有独立文案和图标，不复用 missing fields 文案。
- 检查 API Key 明文在保存成功后仍被清空。
- 检查保存失败 phase 来自服务层错误上下文，不由 UI 猜测。
- 检查诊断 attribute 采用 enum allowlist，不暴露任意公开 key/value initializer。
- 检查诊断事件名采用类型安全枚举或等价 factory，不由调用点自由拼接字符串。
- 检查 UI 总事件和服务层阶段事件使用同一非敏感 `operationID`，且该 ID 不复用 profile、credential、Keychain 或用户输入派生标识。
- 检查诊断 logger 不暴露记录任意 secret 字符串的便捷入口。
- 检查诊断 logger 和 repository 写入失败不会影响保存配置的业务成功 / 失败结果。
- 检查 Core、AI、Data、UI package 不读取 `ProcessInfo.processInfo.environment`，环境变量只在 App 装配层读取。
- 检查 `diagnostic_events` ring buffer 不进入普通导出、同步或用户内容表。
- 检查 `Logger` 输出使用 privacy-safe 的属性，不插入 API Key 或请求头。

文档复查：

- 对照 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 检查日志字段白名单和黑名单。
- 对照 `docs/spec/005-ai-provider-prompt-and-privacy.md` 检查 AI Provider 保存事件不突破隐私边界。
- 对照 `docs/spec/004-swiftui-architecture.md` 检查 UI 状态机符合异步操作规范。
- 对照 `docs/spec/003-ui-design-system.md` 检查新按钮规范是否覆盖层级、尺寸、异步状态、状态持续时间、危险操作、禁用状态、图标按钮、按钮文案、本地化、平台差异、禁止模式和可访问性。

行为复查：

- iOS 模拟器输入 API Key 后点击保存，按钮立即显示“正在保存...”，保存完成后状态面板显示“已保存到本机安全存储”。
- 快速保存路径下，业务完成后输入控件能及时恢复可用，结果由持久状态面板表达，不为了显示 saving 而阻塞用户继续编辑。
- 保存失败后即使表单字段随后变为 invalid，当前失败状态不会被误显示为“缺少必填项”；用户修改相关字段后再清除上一轮失败。
- 故意制造 Keychain 或 repository 失败，页面显示保存失败文案，日志中只有非敏感错误分类。
- 故意制造诊断 repository 写入失败，AI Provider 保存业务仍按真实结果显示，不把诊断失败误报为保存失败。
- 未设置环境变量时，开发期 console 不输出 debug 级详细事件。
- 设置 `LANGOTRACE_DIAGNOSTICS=1` 后，Console.app 或 simulator log 能看到非敏感结构化事件。
- 设置 `LANGOTRACE_DIAGNOSTIC_STORE=1` 后，`diagnostic_events` 中能看到保存链路事件；不设置时按默认配置不写入产品期本地诊断 store。

## 13. 验证命令

完成前至少运行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git status --short
```

日志安全检查：

```bash
rg -n "apiKey|API Key|Authorization|Bearer|Keychain account|plaintextSecret|request body|response body" Packages LangoTraceApp docs/spec
rg -n "ProcessInfo|processInfo\\.environment|LANGOTRACE_" Packages/LangoTraceCore Packages/LangoTraceAI Packages/LangoTraceData Packages/LangoTraceUI
```

上述安全检查不是要求这些词完全不存在，而是要求逐项确认日志写入路径、诊断事件字段和导出路径没有记录敏感值。
第二条检查要求除测试说明外，非 App package 不直接读取环境变量。

## 14. 文档影响检查

本任务影响长期规则，必须更新：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/009-testing-and-verification.md`

可能影响：

- `docs/architecture/001-initial-module-boundaries.md`：新增诊断 logger、repository 和 App 装配边界后需要补充模块边界。
- `docs/review/INDEX.md` 和 `docs/review/rounds/`：如果实施后触发 AI / 隐私 / 日志专项文档审查，需要新增 review round。

不需要新增 ADR。原因：本方案延续本地优先、用户自带 Provider 和敏感凭证不进入普通日志/导出的既有决策，没有改变核心产品或架构取舍。

## 15. 实施记录

- 2026-05-20：创建方案，尚未实现。
- 2026-05-20：根据系统架构审查补强方案。主要调整：第一阶段纳入最小 GRDB 诊断 ring buffer；诊断属性改为类型安全 allowlist；保存失败 phase 改由服务层错误上下文提供；固定 Core / Data / AI / UI / App 模块边界；要求 `scripts/verify.sh` 覆盖 AI package tests。
- 2026-05-20：根据用户要求，将按钮 / 按键交互设计规范沉淀纳入本任务实施范围。实施本方案时必须同步更新 `docs/spec/003-ui-design-system.md`，新增长期按钮与操作反馈规范，避免后续保存、测试、生成、删除、播放、同步、导出等按钮交互继续分散。
- 2026-05-20：根据系统架构师复查继续补强。主要调整：明确第一阶段诊断 store 产品期默认关闭，不承诺追溯未开启前的问题；增加非敏感 `operationID` 串联 UI 与服务层事件；事件名改为类型安全；诊断 logger 明确 best-effort，写入失败不得影响保存业务；快速保存反馈改为立即反馈和持久结果，不人为阻塞业务完成。
- 2026-05-20：阶段 1 已提交 `2e57177`。落地 Core 诊断事件模型、类型安全属性、AI Provider 保存失败上下文、disabled / in-memory / repository / console / composite logger 和 logger 失败不影响业务的测试。
- 2026-05-20：阶段 2 已提交 `59c1396`。落地 `diagnostic_events` GRDB migration、repository、序列化白名单、数量与时间双限制保留策略，以及 Data package repository 测试。
- 2026-05-20：阶段 3 已提交 `f7bb26b`。落地 AI Provider 保存阶段诊断、operation id 透传、Keychain / DB / cleanup phase 分类、cleanup 失败不覆盖原始 DB 失败的行为和 AI package 测试。
- 2026-05-20：阶段 4 已提交 `de541b2`。落地 UI saving / saved / failed 状态、按钮内 `ProgressView`、独立本地化文案、App Shell logger 装配和 iOS build 验证。
- 2026-05-20：阶段 4 复查补丁已提交 `e3c976f`。补齐 `save_input_invalid` 事件边界：输入无效先回到 missing required fields 并记录独立诊断，不污染真实保存失败路径。
- 2026-05-20：阶段 5 更新长期规范和验证脚本。已更新 UI 操作反馈、SwiftUI 异步保存边界、AI Provider 保存诊断、权限与诊断日志隐私边界、测试验证入口、模块边界和 `scripts/verify.sh` 的 AI package 覆盖。
- 2026-05-20：验证修复已提交 `6cc1ab0` 和 `3188d6a`。前者拆分 AI Provider 保存 workflow，消除 SwiftLint serious；后者按 SwiftFormat 规则格式化诊断基础设施文件。
- 2026-05-20：最终收口验证通过并移入 `docs/plans/done/`。完整 `scripts/verify.sh` 退出码 0；SwiftLint 剩余 19 个非阻断 warning，0 serious。
- 2026-05-20：系统架构复查发现 `diagnostic_events` repository 已提供手动 `prune`，但 `record` 写入时未自动应用保留策略，不符合 ring buffer 边界；已补齐写入后同事务按数量和时间裁剪，并新增 `InMemoryDiagnosticEventRepository` 与回归测试。

## 16. 完成标准

本任务可以移入 `docs/plans/done/` 的条件：

- AI Provider 保存按钮具备明确 saving、saved、failed 状态。
- 快速保存路径下，保存执行中有按钮内 `ProgressView`，保存完成后通过持久 saved / failed 状态面板表达结果，不人为拖慢业务完成。
- 保存成功文案准确表达“已保存”，不再表达为“准备保存”。
- 保存失败有独立文案、图标和非敏感错误分类。
- 诊断 logger 基础设施落地，并由环境变量控制开发期系统日志输出。
- 最小 `diagnostic_events` GRDB ring buffer 落地，具备数量和时间双限制保留策略。
- AI Provider 保存链路记录 UI 总事件和服务层阶段事件，失败 phase 来自服务层错误上下文，并通过同一非敏感 `operationID` 关联。
- 诊断事件名采用类型安全枚举或等价 factory，不由调用点自由拼接。
- 诊断属性采用类型安全 allowlist，不提供公开任意 key/value 写入入口。
- 诊断日志写入是 best-effort；Console / repository 失败不改变 AI Provider 保存业务结果。
- 环境变量读取只存在于 App 装配层。
- release 默认不写入本地诊断 store，直到后续“隐私与诊断”设置页提供用户可见开关；文档明确该阶段不能追溯用户未开启诊断前的问题。
- `scripts/verify.sh` 覆盖 `Packages/LangoTraceAI` tests。
- 测试覆盖新增状态机、错误映射、phase 传递、ring buffer 和日志隐私边界。
- `docs/spec/003-ui-design-system.md` 已新增关键操作反馈规范，覆盖异步状态、输入无效、保存成功、保存失败、禁用重复点击、持久结果反馈和可访问性。
- 相关 spec 已更新。
- `scripts/verify.sh` 通过。
- 工作区干净，并完成单独 commit。

## 17. 剩余风险

- 第一阶段虽然新增 `diagnostic_events` 表，但不提供用户导出 UI；用户主动发送诊断包仍需要后续任务实现。
- 第一阶段 release 默认不写入诊断 store，因此不能追溯用户未明确开启诊断前发生的问题；这是隐私优先的有意取舍。
- 即使记录服务层阶段事件，后续真实 Provider 请求、同步和导出链路仍需要分别接入自己的 phase 和错误分类。
- 环境变量开关只适合开发和自动化测试，不能替代产品期 App 内诊断设置。
- 诊断日志字段白名单需要在后续真实 AI 请求、OCR、Speech、同步和导出接入时持续复查。

## 18. 最终验证记录

- `swift test --package-path Packages/LangoTraceCore`：通过，39 tests。
- `swift test --package-path Packages/LangoTraceData`：通过，27 tests。
- `swift test --package-path Packages/LangoTraceAI`：通过，12 tests。
- `swift test --package-path Packages/LangoTraceUI`：通过，137 tests。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`：通过。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`：通过。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`：通过。
- `swiftlint --no-cache`：通过，19 warnings，0 serious。
- `swiftformat --lint . --cache ignore`：通过，0 files require formatting。
- 文档占位扫描：无命中。
- 敏感字段扫描：命中均为规范禁止项、UI 草稿字段、测试用假 secret 或模型定义；未发现诊断 logger / event 写入 API Key、Bearer、完整请求头、完整请求体或 Keychain account。
- 环境变量边界扫描：`ProcessInfo.processInfo.environment` 与 `LANGOTRACE_*` 读取只存在于 `LangoTraceApp/AppEnvironment.swift`。
