# 任务方案：AI Provider 配置存储与安全凭证架构设计

状态：Draft
类型：feature
创建日期：2026-05-20
最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户确认当前只需要完成 AI Provider 功能的架构设计、存储字段设计和设计方案；等并行的语言空间数据基础设施开发完成后，本方案才进入实施。
- 2026-05-20：用户强调相关信息比较敏感，方案必须考虑加密和解密问题。
- 2026-05-20：用户确认 API Key 等密钥在配置页输入后必须加密保存；后续 AI 能力应能实时读取并调用，不应要求用户每次重复输入或确认密钥。
- 状态为 `Draft` 时不能开始实现。用户确认本方案后，需补充确认记录再进入编码。

## 0. 实施者快速上下文

如果另一个 AI 只拿到本文件，应先理解以下边界：

- 本方案不是 UI 视觉任务，而是 AI Provider 配置、非敏感数据库字段、敏感凭证安全存储、Keychain 解密读取和 Data/AI/Core 模块边界设计。
- 当前 AI Provider 设置页已经是“真实级 mock 表单”：UI 有 Provider、Base URL、模型名、API Key、文本/语音/向量模型和测试请求按钮，但保存与测试仍是页面级 mock。
- 语言空间数据基础设施已经完成，但它的当前实现把数据库打开、migration 和 repository 写在 `GRDBLanguageSpaceRepository` 内；这对 AI Provider 后续落库不是最佳长期结构。
- 本方案要求 AI Provider 实施前先新增独立 `AppDatabase`，把数据库生命周期、migration、文件保护和测试数据库初始化从语言空间 repository 中抽出来。
- 敏感值不进入 SQLite。SQLite 只保存 Provider profile、endpoint、credential metadata、Keychain item 引用和测试结果摘要；API Key、Bearer token、自定义敏感 header、对象存储密钥和加密密钥必须进入 Keychain 或等价安全存储。
- 设置页加载已保存配置时不得解密、不得回填 API Key 明文。用户保存密钥后，后续测试请求或真实 AI 请求由服务层自动从 Keychain 读取，不再要求用户重复输入或确认密钥。
- 第一版 Provider profile 是 App 级默认配置，不绑定 `language_space_id`。语言空间只影响目标语言、Prompt 和请求内容。

推荐阅读顺序：

1. 先读本文件第 2、6、11.1、11.6.1、11.6.2、11.8、11.9 节，理解当前代码事实和架构前置。
2. 再读第 11.3 和 11.4 节，理解表字段和 Keychain 规则。
3. 实施前复读 `docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md` 和 `docs/architecture/001-initial-module-boundaries.md`。
4. 如果进入编码，第一步必须处理 `AppDatabase`，不是直接创建 AI Provider 表或 Keychain store。

## 1. 需求描述

当前 AI Provider 设置页已经具备真实级表单形态，能表达文本模型、语音生成模型、向量模型、Provider、Base URL、模型名、API Key、图片理解能力开关、保存配置和测试请求。但这些信息仍停留在 SwiftUI 页面级草稿中，不写入数据库，不写入 Keychain，也不形成后续真实 Provider 请求可复用的配置源。

本任务只形成设计方案，目标是明确 AI Provider 配置如何拆分为非敏感配置、敏感凭证、Keychain 加密存储、解密读取、endpoint 与凭证引用关系、数据库字段、Repository 边界、错误状态和实施顺序。语言空间数据基础设施已完成；AI Provider 实施前还必须先把当前语言空间 repository 内聚的数据库生命周期抽象为独立 `AppDatabase`。

## 2. 现状描述

代码现状：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 通过 `@State private var draft = AIProviderDraftConfiguration(provider: .openAI)` 保存页面草稿。
- `AIProviderDraftConfiguration` 已经区分文本模型、语音生成模型、向量模型、能力启用状态和凭证引用模式，但这些类型仍是 UI package 内部草稿模型。
- `AIProviderPreset` 已经包含多个 Provider preset、默认 Base URL、默认模型、adapter kind、能力矩阵和是否需要 API Key。
- `LangoTraceAI/Sources/LangoTraceAI/AIBoundary.swift` 当前只有空协议 `AIProvider` 和 `DisabledAIProvider`，不具备配置读取、请求构造或凭证解析能力。
- `LangoTraceApp/AppEnvironment.swift` 当前注入 `DisabledAIProvider()`，没有 AI 配置 repository、Keychain store 或 Provider resolver。
- 当前测试已经锁定 AI Provider 设置页的 UI 结构、多模型 endpoint、API Key 文案和三端复用边界，但未覆盖真实保存、Keychain、解密、删除或迁移。
- 语言空间数据基础设施已经落地为 `GRDBLanguageSpaceRepository`，使用 `LanguageSpaceDatabaseLocation.defaultDatabaseURL()` 指向 `Application Support/LangoTrace/LangoTrace.sqlite`，并在 repository 初始化时创建自己的 `DatabaseQueue` 和注册 `v1_create_language_space_infrastructure` migration。
- 当前代码尚未抽出共享 `AppDatabase`、统一 `DatabaseMigrator` 或可由多个 repository 共享的 `DatabaseQueue` 装配入口；AI Provider 存储实施前必须先处理这个边界，否则容易出现多个 repository 各自打开同一 SQLite 文件、迁移注册分散和事务边界不可组合的问题。
- 当前 `Packages/LangoTraceAI/Package.swift` 只有 Core 依赖且没有 test target；若 Keychain store、credential resolver 或 Provider configuration service 放入 AI package，实施时需要补齐 `LangoTraceAITests` test target。
- 复读代码后确认，当前语言空间实现本身可以工作，但它把“数据库生命周期 / migration 注册 / 语言空间 repository”三种职责放在同一类型里。这在只落地语言空间时可接受；在 AI Provider、Entry、FTS、附件、导出和同步陆续进入真实存储后，会成为扩展瓶颈。由于项目仍在早期开发阶段，后续实施应直接推翻这部分临时耦合，而不是围绕它做兼容。

文档现状：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 已规定 API Key 必须进入 Keychain，非敏感配置和敏感凭证必须分层，真实测试请求必须经过 Provider 层。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已规定 API Key、外部服务 token、请求头、对象存储密钥等不得进入普通数据库、日志、导出包或同步目录。
- `docs/decisions/005-local-first-and-user-owned-providers.md` 已决定第一版坚持本地优先和用户自带 Provider，API Key、对象存储密钥和加密密钥默认不同步。
- `docs/plans/done/2026-05-20-feature-language-space-data-infrastructure.md` 已完成 SQLite / GRDB 语言空间数据基础设施；本方案后续实施应复用既有数据库文件位置和 Data 层 repository 装配方向，但还需要在实施前把当前语言空间 repository 内聚的 migration / `DatabaseQueue` 抽象为独立 `AppDatabase`。

## 3. 目标

本方案被实现后必须达到：

- AI Provider 设置页保存后有真实持久化结果，而不是页面级 mock 状态。
- 非敏感 Provider 配置进入本地数据库；敏感凭证只进入 Keychain 或等价系统安全存储。
- 数据库中不保存 API Key、Bearer token、自定义请求头密钥、对象存储密钥、加密密钥或可还原密钥材料。
- 文本生成、图片理解、语音生成和向量模型 endpoint 可以引用同一个凭证，也可以引用各自独立凭证。
- UI 加载已保存配置时不解密、不回填明文 API Key，只展示密钥存在、缺失或不可访问状态。
- App 启动时可以预加载非敏感配置、能力状态和 Keychain item 存在性，但不得在启动时解密 API Key。
- Provider 测试或真实 AI 请求由用户明确触发后，服务层必须自动读取已保存的 Keychain 密钥并调用 Provider，不再要求用户重复输入或确认 API Key。
- 请求预览确认的是即将外发的用户内容和能力边界，不是再次确认或展示密钥。
- 频繁 AI 交互场景允许在受控服务层使用短生命周期内存凭证缓存，避免每次请求都同步访问 Keychain，但缓存不得进入 UI 状态、数据库、日志或可持久化对象。
- Keychain item 默认不跨设备同步，不进入导出包；数据库恢复到新设备但 Keychain 缺失时，UI 明确提示重新输入密钥。
- 方案明确依赖语言空间数据基础设施，并要求先形成独立 `AppDatabase`、统一迁移入口和共享 repository 装配方式。

## 4. 范围

本任务覆盖设计：

- AI Provider 配置的模块归属和依赖方向。
- Provider profile、endpoint、credential、custom header、validation state 的存储模型。
- SQLite / GRDB 表字段和约束建议。
- Keychain item 命名、加密保存、解密读取、删除和轮换规则。
- UI 草稿模型到持久化模型的映射。
- Repository、KeychainStore、CredentialResolver 和 ProviderConfigurationService 的职责。
- 与语言空间、同步、导出、请求日志、Prompt Preset、TTS 和向量化的边界。
- 后续实施顺序、复查方法和验证命令。

## 5. 不做什么

本方案不实现：

- 不写代码，不修改 Swift 文件，不修改数据库迁移。
- 不发真实 OpenAI、Anthropic、Gemini、DeepSeek、Ollama 或其他 Provider 请求。
- 不实现 Prompt Preset 渲染、结构化输出解析、AI 生成内容保存或请求日志。
- 不实现真实 TTS、OCR、Speech、Embedding 或图片理解请求。
- 不把“测试请求”扩展为完整 AI 生成、TTS 播放、向量索引构建或 Prompt Preset 执行；真实测试请求若并入本方案，只允许发送合成检测内容并记录非敏感结果摘要。
- 不实现对象存储同步配置；对象存储密钥只作为同类敏感配置边界参考。
- 不做 Provider 配置跨设备同步。
- 不做自定义数据库加密、SQLCipher、用户自设主密码或导出包加密。
- 不把 AI Provider 配置做成语言空间私有配置。第一版使用 App 级默认 Provider profile；语言空间只影响目标语言、Prompt 和请求内容。
- 不在 macOS 原生 Settings scene 新增第二套可写 AI Provider 表单；真实写入入口复用现有工作台内设置详情。

## 6. 证据与决策依据

- `docs/spec/005-ai-provider-prompt-and-privacy.md`：UI 不直接调用具体 AI 服务；API Key 必须保存到 Keychain；Provider、Base URL、模型名属于普通表单配置；敏感凭证必须和 endpoint 分离。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：API Key、外部服务 token、请求头、对象存储密钥不得进入数据库、日志、导出包或同步目录。
- `docs/decisions/005-local-first-and-user-owned-providers.md`：本地优先、用户自带 Provider、API Key 默认 Keychain、密钥默认不同步。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：真实主数据和配置元数据应沿用 SQLite / GRDB 主存储路线；API Key、对象存储密钥和外部 Provider token 不得进入普通数据库导出包；`current_language_space_id` 属于本地 app state。
- `docs/architecture/001-initial-module-boundaries.md`：UI 不直接知道 API Key、base URL 或同步密钥；AI package 承担 Provider 协议、OpenAI-compatible 配置模型和请求元数据。
- `docs/plans/done/2026-05-19-feature-ai-provider-multi-model-configuration.md`：已确认模型 endpoint 与敏感凭证分离，多个 endpoint 可引用同一凭证。
- `docs/plans/done/2026-05-19-feature-ipad-mac-ai-provider-settings-consistency.md`：iPhone、iPad、macOS 复用同一 AI Provider 表单，平台差异只体现在承载宽度。
- Apple Keychain Services：Generic Password item 适合保存 API Key / token；系统负责加密静态存储和访问控制。
- `docs/plans/done/2026-05-20-feature-language-space-data-infrastructure.md` 已引入 SQLite / GRDB、`DatabaseQueue`、`Application Support/LangoTrace/LangoTrace.sqlite` 和语言空间 repository；AI Provider 存储应复用同一数据库文件和统一迁移入口，不单独创建第二套本地数据库。

代码事实依据：

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift` 当前持有 `DatabaseQueue`，并在初始化时调用私有 `migrate(_:)` 注册 `v1_create_language_space_infrastructure`。
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceDatabaseLocation.swift` 当前确定数据库位置为 `Application Support/LangoTrace/LangoTrace.sqlite`。
- `LangoTraceApp/AppEnvironment.swift` 当前通过 `makeLanguageSpaceRepository` factory 创建 `GRDBLanguageSpaceRepository.persistent(...)`，并注入 `DisabledAIProvider()`。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIBoundary.swift` 当前只有 `AIProvider` 空协议和 `DisabledAIProvider`。
- `Packages/LangoTraceAI/Package.swift` 当前没有 `testTarget`，实施 AI service / Keychain store 时需要补测试 target。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift` 当前用 `AIProviderDraftConfiguration` 管理页面草稿和 mock save/test 状态。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift` 当前锁定 UI 不直接发网络请求、不直接出现 Bearer 请求逻辑，并确认 Provider 设置页存在测试按钮和多 endpoint 表单结构。

关键决策依据：

| 决策 | 结论 | 依据 | 防误读 |
| --- | --- | --- | --- |
| 数据库存储 | 非敏感配置进入 SQLite / GRDB | 本地优先、SQLite / GRDB 主存储路线、语言空间基础设施已落地 | 不是把密钥也放进 SQLite。 |
| 密钥存储 | API Key / token / secret header 进入 Keychain | 隐私规范和 ADR-005 要求敏感凭证默认 Keychain 且不同步 | 不自制可解密密文 blob。 |
| 数据库入口 | 先引入 `AppDatabase` | 当前 repository 私有 migration 不适合多 repository schema 演进 | 不是为了 AI Provider 单表过度抽象，而是为 Entry/附件/FTS/导出/同步打底。 |
| 协议归属 | 配置模型和 repository 协议归 Core | Data 和 AI 都只能依赖 Core | 不把 repository 协议放 AI package，避免 `Data -> AI`。 |
| Provider profile 作用域 | 第一版 App 级默认 profile | API Key 是用户账号级配置，语言空间只影响学习上下文 | 不增加 `language_space_id`。 |
| 启动加载 | 启动可加载非敏感 projection 和密钥存在性 | AI 是核心能力，需要快速判断配置状态 | 不在启动时解密 API Key。 |
| 测试请求 | 本方案定义状态机和存储；真实探测可选 | 测试按钮已存在，但真实网络会引入 Provider adapter 复杂度 | 最低实现必须有配置完整性和 Keychain 可读性测试。 |
| 密钥替换 | 默认使用新 `credential_id` 两阶段切换 | SQLite 与 Keychain 无共享事务，覆盖旧 item 会造成半提交风险 | 只有纯密钥原地轮换且无配置变更时才允许覆盖同一 item。 |
| Base URL 安全 | 云端 Provider 默认 HTTPS，本地 Provider 才允许 HTTP 回环地址 | AI 请求会发送用户内容，endpoint 是隐私边界的一部分 | 不把 `http` 泛化给任意公网或局域网服务。 |

架构决策：

- 使用“数据库保存配置元数据 + Keychain 保存秘密值”的双层模型。
- 先补齐独立 `AppDatabase`，再添加 AI Provider 表迁移。当前代码没有独立 `AppDatabase`；后续实施不应让 `GRDBLanguageSpaceRepository` 和 AI Provider repository 分别注册互不感知的 migrator，也不应各自长期持有同一数据库文件的独立 `DatabaseQueue`。
- 独立 `AppDatabase` 是本阶段更优设计，不是过度抽象。原因：项目已确认 SQLite / GRDB 是长期主存储候选，AI Provider 之后还会接入 Entry、附件、FTS、导出和同步；数据库生命周期、migration、文件保护、备份策略和测试初始化应由 Data 基础设施统一负责，Repository 只负责领域读写。
- 数据库只保存 Keychain item 引用，不保存可解密密文 blob。原因：Keychain 已提供系统级加密、访问控制和平台集成；自定义加密会引入密钥管理问题，而密钥最终仍需要安全存储。
- Keychain item 使用稳定 `credential_id` 作为 account 的一部分，不使用 Provider 名称或模型名。原因：Provider、Base URL 和模型可以变化，凭证 ID 才是引用稳定点。
- endpoint 直接引用 `credential_id`。如果语音生成或向量模型选择“使用文本模型凭证”，保存时解析为同一个 `credential_id`，不在数据库中保存 UI 文案式引用。
- 第一版使用 App 级默认 Provider profile，不做 language-space scoped override。原因：API Key 是用户账号级敏感配置，不应随着语言空间复制；语言空间只决定请求上下文和 Prompt。
- Keychain item 默认 `synchronizable = false`，并优先使用 `WhenUnlockedThisDeviceOnly` 访问级别。原因：项目当前决策是密钥默认不同步；数据库或设备备份恢复后缺失密钥是可接受且可解释的安全取舍。
- 解密只发生在用户明确触发 Provider 测试或真实 AI 请求的服务层，不发生在页面渲染、列表展示、设置页加载或日志记录中。
- 启动阶段只读取非敏感配置和 Keychain 可用性状态，不读取明文密钥。原因：AI 交互是核心能力，但不是每次打开 App 都一定使用外部 Provider；启动解密会扩大敏感明文驻留时间，也会让 Keychain 锁定、迁移缺失或用户授权状态影响普通本地记录体验。
- 运行期可以为已确认可用的凭证建立短生命周期内存缓存。原因：连续生成、逐句解释、听写回译或批量向量化可能短时间内多次请求同一 Provider；每次都访问 Keychain 会增加延迟和复杂错误点。缓存必须有明确作用域、过期时间和清除时机。
- SQLite 和 Keychain 之间没有统一事务。所有保存、替换、删除和轮换都必须按“先创建新安全存储 item -> 数据库提交切换引用 -> 清理旧 item”的补偿式流程设计，不能假设 Keychain 写入和数据库写入会一起回滚。
- Provider endpoint URL 是用户内容外发边界。第一版对云端 Provider 只接受 `https`；`http` 只允许本机回环地址，或在后续高级本地网络 Provider 方案中单独审查局域网风险、用户确认和请求预览文案。

## 7. 涉及的代码文件路径

本方案阶段不修改代码。预计后续实施会涉及：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfigurationRepository.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderCredentialStore.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/KeychainAIProviderCredentialStore.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderCredentialResolver.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`，作为当前 `GRDBLanguageSpaceRepository` 内部 `DatabaseQueue` / migration 的抽取目标。
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceDatabaseLocation.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AIProviderConfigurationStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/AIProviderConfigurationStoreTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIBoundary.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceDatabaseLocation.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/SyncSettingsTests.swift`

## 9. 涉及的文档路径

本方案新增：

- `docs/plans/active/2026-05-20-feature-ai-provider-configuration-storage.md`

后续实施时预计检查或更新：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/technical-framework-roadmap.md`
- `docs/platform-page-inventory.md`
- `docs/testing/README.md`
- `docs/review/INDEX.md`
- `docs/review/rounds/2026-05-20-ai-provider-configuration-storage.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 设计方案

### 11.1 总体架构

推荐分层：

```text
SwiftUI AIProviderSettingsView
  -> AIProviderConfigurationService
      -> AIProviderConfigurationRepository
          -> SQLite / GRDB 非敏感配置表
      -> AIProviderCredentialStore
          -> Keychain Generic Password items
      -> AIProviderCredentialResolver
          -> 用户触发请求时临时解密读取
```

模块职责：

- UI：只管理表单草稿、保存动作、测试动作和可见状态；不直接访问 SQLite、Keychain 或网络。
- Core：定义 Provider profile、endpoint、credential reference、capability purpose、保存输入、验证错误、展示投影和 `AIProviderConfigurationRepository` 协议等平台无关模型。这样 Data 和 AI 都只依赖 Core，符合当前 `Data -> Core`、`AI -> Core` 的包依赖方向。
- AI：定义 Provider 配置服务、凭证解析、Provider adapter 输入、Keychain credential store 和未来请求构造边界；AI service 消费 Core repository 协议，但不直接依赖 GRDB 或 Data package。
- Data：通过共享数据库保存非敏感配置并实现 Core 中的 repository 协议；不依赖 AI package，不接触明文密钥。
- App Shell：装配 repository、Keychain store、configuration service 和 disabled / mock Provider。

当前代码对本分层的影响：

- `GRDBLanguageSpaceRepository` 目前同时拥有 repository、`DatabaseQueue` 创建和 migration 注册职责。AI Provider 实施前应新增 `AppDatabase`，由它统一持有 `DatabaseQueue`、注册语言空间和 AI Provider migration，并把 queue 注入 `GRDBLanguageSpaceRepository` 与 AI Provider repository。
- `LanguageSpaceDatabaseLocation.defaultDatabaseURL()` 已经确定主数据库位置；AI Provider 配置表应进入同一个 `LangoTrace.sqlite`，但 Keychain item 仍只进入系统 Keychain。
- 当前 iOS 数据库文件保护为 `.completeUntilFirstUserAuthentication`。这可以继续用于非敏感配置和语言空间主数据；API Key 等秘密值通过 Keychain 的 `WhenUnlockedThisDeviceOnly` 提供更强访问边界。

### 11.1.1 启动加载与运行期缓存策略

App 启动时应该读取 AI Provider 配置信息，但读取范围必须分层：

- 可以读取：默认 profile、endpoint、Provider preset、Base URL、模型名、能力启用状态、最近验证摘要、Keychain item 是否存在。
- 不读取：API Key 明文、Bearer token、自定义请求头密钥、对象存储密钥或任何可还原密钥材料。

启动预加载的目的：

- 设置页、Sidebar 状态和请求预览能快速判断“未配置 / 已配置但缺密钥 / 已配置且密钥存在 / 最近测试失败”。
- AI 入口可以在用户点击前知道是否需要引导配置 Provider。
- App 不必为了显示状态临时访问 Keychain 明文。

启动预加载不得阻塞首屏：

- 推荐在 AppSessionState 完成基础启动恢复后异步加载 Provider configuration projection。
- 读取数据库失败时，AI 状态进入可恢复错误，不影响本地记录、语言空间浏览和非 AI 功能。
- Keychain 存在性检查如果平台上可能较慢，可以延后到设置页打开或 AI 请求预览前刷新；默认状态可先标记为 `unknown`，但不能假定密钥可用。

真实 AI 交互时的读取策略：

- 第一次真实 Provider 测试或 AI 请求需要通过 `AIProviderCredentialResolver` 从 Keychain 解密读取。
- 只要 Keychain item 可访问，Provider 调用链路必须自动使用已保存密钥，不应弹出“再次输入 API Key”或“确认使用此 API Key”的流程。
- 用户只在新增、替换、删除或修复缺失密钥时回到配置页输入密钥。
- 请求预览可以要求用户确认“发送哪些内容给哪个 Provider”，但不得要求用户重新确认密钥本身，也不得展示密钥明文。
- Resolver 读取后可以把明文凭证放入 service 层内存缓存，但必须满足：
  - 缓存只存在于 AI package 或 App Shell 装配的服务对象内，UI 不持有。
  - 缓存 key 使用 `credential_id`，不使用 Provider 名称、模型名或明文派生值。
  - 默认过期时间建议为 5 到 15 分钟，或一次批处理任务结束即清除。
  - App 进入后台、用户锁屏相关通知、用户修改或删除凭证、Provider 测试失败为认证错误时必须清除。
  - 缓存不参与 Codable、日志、诊断包、同步、导出或 SwiftUI `@State` / `@Published`。

性能判断：

- 数据库读取非敏感配置很轻量，适合启动后异步预加载。
- Keychain 明文读取通常不是主要瓶颈，但它可能触发系统安全状态、锁定状态或平台差异；因此不应在渲染路径和列表刷新中频繁读取。
- 真实 AI 请求的网络延迟通常远高于一次 Keychain 读取，但连续短请求、批量生成和向量化会放大重复 Keychain 访问成本；短生命周期缓存是合理折中。
- 不应为了性能把 API Key 复制进 SQLite、UserDefaults、内存全局单例或请求日志。

### 11.2 配置作用域

第一版配置作用域为 App 级：

- App 有一个默认 AI Provider profile。
- 一个 profile 可以包含多个 endpoint：文本生成、图片理解、语音生成、向量模型。
- 图片理解不需要独立 endpoint；它是文本模型 endpoint 的能力开关，仍引用文本模型 endpoint 和凭证。
- 语言空间不保存 API Key，也不复制 Provider profile。
- 未来如果需要某个语言空间使用不同 Prompt 或不同模型，先通过 Prompt Preset / request option 表达；只有出现真实用户需求后再设计 language-space override。

### 11.3 数据库字段设计

#### 11.3.1 `ai_provider_profiles`

保存一组 Provider 配置 profile 的非敏感元数据。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | TEXT | primary key | UUID 字符串，稳定 profile ID。 |
| `display_name` | TEXT | not null | 用户可见名称，例如 `Default AI Provider`。 |
| `is_default` | INTEGER | not null, 0/1 | 是否为 App 默认 profile。数据库应保证最多一个 active default。 |
| `status` | TEXT | not null | `draft`, `configured`, `incomplete`, `credential_missing`, `credential_inaccessible`, `validation_failed`。 |
| `created_at` | REAL | not null | Unix timestamp。 |
| `updated_at` | REAL | not null | Unix timestamp。 |
| `last_validated_at` | REAL | nullable | 最近一次合成测试或真实测试时间。 |
| `last_validation_status` | TEXT | nullable | `not_run`, `succeeded`, `failed`, `cancelled`。 |
| `deleted_at` | REAL | nullable | 软删除时间。 |

约束：

- 普通查询只返回 `deleted_at is null`。
- `is_default = 1` 的 active profile 最多一个。迁移层应使用 partial unique index 表达，例如 active profile 中 `is_default = 1` 唯一。
- `status` 不能来自 UI 文案，必须由 repository / service 根据 endpoint 完整性和最近一次 Keychain 存在性检查结果计算或更新。
- `status` 是最近观测状态，不是 Keychain 当前可读性的事实源。UI 展示前、请求预览前和真实请求前都应重新刷新 credential presence；不得因为数据库里是 `configured` 就跳过 Keychain 检查。

#### 11.3.2 `ai_provider_endpoints`

保存每种能力 endpoint 的非敏感请求配置。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | TEXT | primary key | UUID 字符串。 |
| `profile_id` | TEXT | not null | 引用 `ai_provider_profiles.id`。 |
| `purpose` | TEXT | not null | `text_generation`, `tts`, `embedding`。图片理解作为文本 endpoint 能力开关，不作为首版独立 endpoint。 |
| `is_enabled` | INTEGER | not null, 0/1 | 能力是否启用。文本生成默认启用，TTS / embedding 默认关闭。 |
| `provider_preset_id` | TEXT | not null | 例如 `openai`, `anthropic`, `ollama-local`, `custom-openai-compatible`。 |
| `adapter_kind` | TEXT | not null | `openai_responses`, `openai_compatible_chat`, `anthropic_messages`, `gemini_generate_content`。 |
| `base_url` | TEXT | not null | 非敏感 endpoint URL。保存前 trim；云端 Provider 必须是 https，本机回环 Provider 可使用 http。 |
| `model_name` | TEXT | not null | 模型名。 |
| `credential_id` | TEXT | nullable | 引用 `ai_provider_credentials.id`。本地无密钥 Provider 可为空。 |
| `supports_image_input` | INTEGER | not null, 0/1 | 该 endpoint 是否支持图片输入。 |
| `image_input_enabled` | INTEGER | not null, 0/1 | 用户是否启用图片理解。仅 `purpose = text_generation` 时有效。 |
| `request_timeout_seconds` | REAL | nullable | 未来请求超时配置；首版可使用默认值。 |
| `created_at` | REAL | not null | Unix timestamp。 |
| `updated_at` | REAL | not null | Unix timestamp。 |

约束：

- 同一个 profile 下，同一个 `purpose` 只能有一个 active endpoint。
- `image_understanding` 首版不作为独立 endpoint 落库；如果未来为了查询方便新增独立 purpose，也必须映射到 text endpoint，不允许拥有独立凭证。
- `credential_id` 可以被多个 endpoint 引用。共享文本模型凭证时，TTS / embedding 的 `credential_id` 与文本 endpoint 相同。
- `provider_preset_id = ollama-local` 这类本地 Provider 可以没有 `credential_id`，但云端 Provider 默认必须有可访问凭证。
- 云端 Provider、聚合服务和自定义 OpenAI-compatible Provider 默认只允许 `https`。`http` 仅允许 `localhost`、`127.0.0.1`、`::1` 等本机回环地址；局域网明文 HTTP、自签证书、代理网关或公司内网 endpoint 需要后续高级 Provider 方案单独设计用户确认、风险提示和请求预览展示。
- 保存和请求预览时应记录/展示脱敏后的 host 与 provider 类别；不得把 API Key、token 或其他 secret 放进 URL query、fragment、username/password 或日志字段。

#### 11.3.3 `ai_provider_credentials`

保存 Keychain item 的引用和非敏感元数据，不保存明文或可还原密文。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | TEXT | primary key | UUID 字符串，endpoint 引用它。 |
| `profile_id` | TEXT | not null | 所属 profile。 |
| `provider_preset_id` | TEXT | not null | 用于 UI 展示和校验跨 Provider 误用。 |
| `kind` | TEXT | not null | `api_key`, `bearer_token`, `custom_header_secret`。首版主路径使用 `api_key`。 |
| `label` | TEXT | not null | 非敏感标签，例如 `OpenAI API Key`。 |
| `keychain_service` | TEXT | not null | 推荐 `com.langotrace.ai-provider`。 |
| `keychain_account` | TEXT | not null | 推荐 `ai-provider-credential:<credential_id>:<kind>`。 |
| `keychain_access_group` | TEXT | nullable | 默认为空；需要 App Group 或扩展时单独设计。 |
| `keychain_synchronizable` | INTEGER | not null, 0 | 必须为 0，默认不同步。 |
| `keychain_accessibility` | TEXT | not null | 推荐 `when_unlocked_this_device_only`；只有明确后台 AI 队列时才评估 `after_first_unlock_this_device_only`。 |
| `secret_presence` | TEXT | not null | `present`, `missing`, `inaccessible`, `unknown`。不代表已解密。 |
| `cleanup_state` | TEXT | not null | `active`, `pending_keychain_delete`, `cleanup_failed`。用于非原子补偿清理，不包含 secret。 |
| `created_at` | REAL | not null | Unix timestamp。 |
| `updated_at` | REAL | not null | Unix timestamp。 |
| `last_resolved_at` | REAL | nullable | 最近一次成功解析时间，只记录时间，不记录 secret。 |
| `deleted_at` | REAL | nullable | 软删除时间。 |

禁止字段：

- 不保存 `api_key_plaintext`。
- 不保存 `api_key_ciphertext`。
- 不保存 `secret_hash`、`secret_last_four` 或任何可用于识别真实密钥的派生值。
- 不保存完整请求头值。

约束：

- `keychain_service + keychain_account` 必须唯一，避免两个 metadata 行指向同一个 Keychain item 却拥有不同生命周期。
- `secret_presence` 是最近一次存在性检查的缓存状态，不是密钥当前可读性的事实源。启动后异步刷新、进入设置页刷新、保存后刷新、请求预览前刷新和真实请求前强制解析必须分层处理。
- credential 允许被多个 endpoint 或 custom header 引用。删除或软删除 credential 前必须先计算引用计数；仍被 active endpoint / active header 引用的 credential 不得删除 Keychain item。
- `cleanup_state != active` 的 credential 不得被新 endpoint 或 header 引用；设置页可展示非敏感维护错误并允许重试清理，但不得展示 Keychain account 全量字符串。

#### 11.3.4 `ai_provider_custom_headers`

首版 UI 可不开放，但存储设计应支持未来高级配置。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | TEXT | primary key | UUID 字符串。 |
| `endpoint_id` | TEXT | not null | 引用 endpoint。 |
| `header_name` | TEXT | not null | Header 名称，例如 `HTTP-Referer`。 |
| `value_kind` | TEXT | not null | `plain_text`, `secret_credential`。 |
| `plain_value` | TEXT | nullable | 仅允许保存非敏感值。 |
| `credential_id` | TEXT | nullable | Header 值为敏感密钥时引用 credential。 |
| `created_at` | REAL | not null | Unix timestamp。 |
| `updated_at` | REAL | not null | Unix timestamp。 |

约束：

- `value_kind = plain_text` 时 `plain_value` 可用，`credential_id` 为空。
- `value_kind = secret_credential` 时 `credential_id` 必须存在，`plain_value` 必须为空。
- UI 必须把 `Authorization`、`x-api-key`、`x-goog-api-key` 等默认识别为 secret，不允许落入 `plain_value`。
- Header 名称本身可能暴露服务结构。日志和 validation event 默认只记录 header 数量、是否包含 secret header 和错误分类，不记录完整 header 列表；高级配置页展示 header 名称前需要单独审查本地化和隐私文案。

#### 11.3.5 `ai_provider_validation_events`

保存测试请求的非敏感结果摘要。

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | TEXT | primary key | UUID 字符串。 |
| `profile_id` | TEXT | not null | 引用 profile。 |
| `endpoint_id` | TEXT | nullable | 被测试的 endpoint。 |
| `event_type` | TEXT | not null | `credential_validation`, `synthetic_test`, `real_request_probe`。配置完整性测试使用 `credential_validation`；真实合成探测才使用 `real_request_probe`。 |
| `status` | TEXT | not null | `succeeded`, `failed`, `cancelled`。 |
| `error_category` | TEXT | nullable | `missing_credential`, `credential_inaccessible`, `network_unavailable`, `timeout`, `provider_rejected`, `authentication_failed`, `unsupported_model`, `unsupported_endpoint_purpose`, `invalid_response`, `invalid_audio_response`, `invalid_embedding_response`。 |
| `provider_preset_id` | TEXT | not null | Provider preset。 |
| `model_name` | TEXT | nullable | 模型名。 |
| `duration_ms` | INTEGER | nullable | 耗时。 |
| `created_at` | REAL | not null | Unix timestamp。 |

禁止记录：

- 不记录 API Key、请求头完整值、完整请求体、完整响应体、用户生活记录、照片内容、音频转写或历史记忆。
- 合成测试内容可以写死在代码中，但不应保存完整 prompt。

#### 11.3.5.1 迁移级约束与删除规则

后续 GRDB migration 不应只建表，还必须把以下关系落实为数据库约束或 repository 级强校验：

- `ai_provider_profiles`：active default profile 最多一个，推荐 partial unique index：`is_default = 1 AND deleted_at IS NULL`。
- `ai_provider_endpoints`：`profile_id` 外键引用 profile；同一 active profile 下同一 `purpose` 唯一；`credential_id` 外键引用 credential，允许为空但云端 Provider 保存前必须由 service 校验存在。
- `ai_provider_credentials`：`profile_id` 外键引用 profile；`keychain_service + keychain_account` 唯一；soft delete 后普通查询不返回。
- `ai_provider_custom_headers`：`endpoint_id` 外键引用 endpoint；`credential_id` 外键引用 credential；同一 endpoint 下 `header_name` 大小写归一后不得重复。
- `ai_provider_validation_events`：`profile_id` 外键引用 profile；`endpoint_id` nullable，但如果存在必须引用 endpoint；删除 profile 时 validation event 可作为本地诊断摘要保留或级联软删除，实施前必须二选一并写入测试。
- profile soft delete 时，endpoint 和 custom header 应一并退出 active 查询；credential 只有在没有其他 active endpoint / header 引用时才删除 Keychain item 并 soft delete metadata。
- 第一版仍可不实现 profile 多实例 UI，但 schema 和 repository 不能假定永远只有一个 row；App 级默认 profile 通过 `is_default` 表达，而不是写死固定 ID。

### 11.3.6 测试请求是否并入本方案

结论：测试请求的“状态机、字段设计、结果存储、错误分类和安全边界”必须纳入本方案；真实网络测试是否在本方案实施时一并落地，应作为独立子任务开关处理。

建议拆分为两层：

1. **配置完整性测试**：本方案必须实现。只校验 endpoint 字段、凭证引用、Keychain 可读性、Provider preset 能力矩阵和本地状态转换，不发网络。
2. **真实 Provider 合成探测**：可以作为本方案实施的最后一个可选子任务，但必须满足 Provider client 最小化、只发送合成内容、UI 不直接发请求、日志不记录请求体/响应体。若实现时 Provider adapter 还没有稳定边界，则应延期到后续“Provider 合成测试请求”任务。

这样处理的原因：

- “测试请求”按钮已经存在于设置页，如果真实保存 Keychain 后仍只能 mock，会让用户误以为配置可用但无法验证外部服务。
- 但真实测试请求会引入网络、Provider adapter、请求格式差异、错误分类和隐私审计，复杂度已经超出纯配置存储。
- 因此本方案负责把测试请求的存储和安全模型定清楚；实现阶段可以先完成本地配置完整性测试，再按 Provider adapter 成熟度决定是否一并完成真实合成探测。

### 11.3.7 各类 endpoint 的合成测试策略

文本模型测试：

- 适合最先真实测试，成本低，响应易校验。
- 发送固定合成输入，不使用用户记录、目标语言正文、Prompt Preset、照片、音频或历史记忆。
- 建议请求语义：要求模型返回一个固定短 JSON，例如 `{"ok":true}` 或固定短文本。
- 验收只检查请求成功、认证通过、模型可用、响应可解析；不评价模型质量。
- 结果记录到 `ai_provider_validation_events`，只保存 provider、model、endpoint purpose、耗时、状态和错误分类。

语音生成模型测试：

- 不应在第一版测试中自动播放声音，也不应保存音频文件。
- 发送固定短文本，例如 `LangoTrace provider test.`，请求最短可行音频。
- 验收只检查认证通过、模型支持 TTS、返回音频 MIME type 或二进制长度在合理范围内。
- 测试结果不保存音频内容；如实现层需要临时接收音频，应只在内存中验证后立即释放。
- 如果 Provider 的 TTS 接口需要 voice、format 或额外参数，本方案只允许使用 Provider preset 的安全默认值；高级 voice 选择另开任务。

向量模型测试：

- 发送固定短文本，例如 `LangoTrace vector test.`。
- 验收只检查认证通过、模型支持 embedding、返回向量维度大于 0、元素为有限数值。
- 可以记录向量维度作为非敏感能力元数据，但不得保存向量值本身。
- 向量模型测试不触发向量索引创建，不写入长期记忆，不读取任何用户内容。

图片理解测试：

- 图片理解是文本 endpoint 的能力开关，不建议在本方案中做真实图片测试。
- 如果未来需要测试，只能使用内置非用户图片或极小 synthetic image，并单独审查图片上传边界。
- 当前配置存储阶段只校验 Provider preset 是否声明支持图片输入、用户是否启用、文本 endpoint 是否具备可用凭证。

测试按钮的 UI 行为建议：

- 保存配置后，“测试请求”可以显示为一个总按钮，但执行时应按已启用 endpoint 逐项测试。
- 文本模型必测；语音生成和向量模型仅在用户启用后测试。
- 测试结果按 endpoint 展示：文本模型、语音生成、向量模型分别显示成功、失败、未启用或未测试。
- 任一 endpoint 认证失败时，应清除对应 credential 的运行期缓存，并把 profile 标记为需要用户处理。
- 不要求用户再次输入或确认 API Key；测试只确认会发送合成检测内容。

### 11.4 Keychain 加密和解密设计

#### 11.4.1 保存加密

保存流程：

1. UI 提交 `AIProviderConfigurationDraftSaveInput`，其中包含明文 API Key 草稿。
2. `AIProviderConfigurationService` 校验非敏感字段和凭证完整性。
3. Service 为每个新凭证生成稳定随机 `credential_id`。
4. `AIProviderCredentialStore.upsertSecret(credentialID:kind:secret:)` 写入 Keychain Generic Password item。
5. Keychain 写入成功后，repository 在同一业务操作中保存 profile、endpoint 和 credential metadata。
6. 如果数据库写入失败，service 必须删除刚创建的 Keychain item 或标记为未引用并在下次清理。
7. 如果 Keychain 写入失败，数据库不得保存指向不存在密钥的 active credential。

跨存储提交规则：

- Keychain 与 SQLite 没有共同事务。保存操作必须按补偿式流程实现，并在测试中覆盖 Keychain 成功 / 数据库失败、Keychain 失败 / 数据库未写、清理失败三类路径。
- 新增凭证：先写 Keychain 新 item，再写数据库 metadata 和 endpoint 引用；数据库失败时立即删除新 item，删除失败则记录 `orphanedCredentialCleanupFailed`，但不得让 active endpoint 指向它。
- 替换凭证：默认创建新 `credential_id` 和新 Keychain item，数据库事务成功后把 endpoint / header 引用切换到新 credential，再删除旧 item 并 soft delete 旧 metadata。这样可以避免覆盖旧 item 后数据库提交失败导致旧配置使用新密钥。
- 原地轮换只允许用于“同一 credential、同一 endpoint 配置、只替换 secret 值”的显式操作；如果同时修改 Provider、Base URL、模型、共享关系或 header 结构，必须走新 credential 两阶段切换。
- 清理旧 item 失败不应回滚已经成功的新配置，但必须把旧 credential metadata 标记为待清理状态或记录非敏感清理错误，后续设置页或维护任务可重试。

Keychain item 建议属性：

```text
kSecClass: kSecClassGenericPassword
kSecAttrService: com.langotrace.ai-provider
kSecAttrAccount: ai-provider-credential:<credential_id>:<kind>
kSecAttrSynchronizable: false
kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

平台说明：

- iOS / iPadOS 的 AI Provider API Key 优先使用 `WhenUnlockedThisDeviceOnly`，因为真实 AI 请求默认由用户在前台显式触发，不需要设备锁定后后台读取密钥。
- 只有后续明确引入后台 AI 队列、后台向量化或后台同步前置的 Provider 检测，并且经过单独隐私审查后，才允许把特定低风险凭证降级为 `AfterFirstUnlockThisDeviceOnly`。
- macOS 使用 Keychain 等价保护能力；若系统 API 对 accessibility 的语义不同，必须在实现注释和测试中记录差异。
- 不启用 iCloud Keychain 同步；不把 Keychain item 放入 App 导出包。

#### 11.4.2 读取解密

读取原则：

- 设置页加载 profile 时只读数据库和 Keychain item 是否存在，不读取明文。
- 密钥显示控件只允许输入新值或替换值，不回填旧值。
- 用户完成配置页保存后，后续测试请求或真实 AI 动作必须自动使用已保存密钥；只有用户点击“测试请求”或未来真实 AI 动作通过请求预览确认后，`AIProviderCredentialResolver` 才调用 Keychain 读取明文。
- Resolver 返回的 secret 只在请求构造作用域内短暂存在，不写入 `@State`、日志、数据库、请求日志或错误对象。
- Swift `String` 无法保证内存清零，因此实现时应避免延长生命周期；如请求库允许，优先用 `Data` 在最小范围内转换。

读取失败分类：

- `missingCredential`：数据库有 credential metadata，但 Keychain item 不存在。
- `credentialInaccessible`：Keychain item 存在但当前设备锁定、权限或 Keychain 状态导致不可读。
- `credentialCorrupted`：读取结果不是可用 UTF-8 或不满足 Provider 认证格式。
- `userInteractionRequired`：平台要求用户授权或解锁。

UI 表达：

- `missingCredential` 显示为“需要重新输入 API Key”。
- `credentialInaccessible` 显示为“当前无法访问本机安全存储，可解锁设备或稍后重试”。
- 正常已配置状态不显示密钥确认步骤；AI 能力入口直接进入内容级请求预览或执行流程。
- 不向用户展示底层 Keychain 错误码，诊断日志只记录错误分类。

UI 明文草稿生命周期：

- 当前 SwiftUI 表单在用户输入期间不可避免会持有 API Key 草稿；该草稿只能停留在页面本地编辑状态和一次保存输入中，不得进入 `AIProviderConfigurationProjection`、持久化模型、日志、诊断包、preview 数据或测试 fixture。
- 保存成功后，UI 必须立即清空 API Key 明文输入，关闭显示 / 隐藏开关，并改用“已保存 API Key / 替换 API Key / 删除 API Key”这类状态展示，不回显旧值。
- 用户离开设置页、切换 profile、取消编辑或从独立凭证切回共享凭证时，必须丢弃未保存的 API Key 草稿。
- 保存失败时，如果失败发生在本地字段校验之前，可以保留输入帮助用户修正；如果 Keychain 写入已经成功但数据库提交失败，service 必须先执行补偿清理，UI 只展示错误分类，不展示或记录明文。
- 已保存密钥的显示按钮只能作用于当前新输入草稿，不得触发 Keychain 解密后显示旧密钥。

#### 11.4.3 更新、删除和轮换

更新规则：

- 用户不修改 API Key 时，保存配置不得读取旧明文，也不得重写 Keychain。
- 用户输入新 API Key 且同时修改 endpoint 配置、Provider、共享关系或 header 结构时，默认创建新的 `credential_id` 和 Keychain item，数据库提交后再切换 endpoint 引用并清理旧 item。
- 用户仅执行密钥轮换且 endpoint / header 配置不变时，可以更新同一个 `credential_id` 对应的 Keychain item，保持 endpoint 引用不变；此路径必须单独测试 Keychain 写入失败、认证失败后缓存清除和 validation state 重置。
- 用户把 endpoint 从独立凭证改为共享文本凭证时，endpoint 改引用文本 `credential_id`；原独立 credential 若无 endpoint 引用，应删除 Keychain item 并软删除 metadata。
- 删除 profile 时，先计算所有 credential 引用；无其他 profile 或 endpoint 引用的 credential 必须删除 Keychain item，再软删除 metadata。
- 密钥轮换只更新时间、Keychain item 和 validation state，不改变 endpoint 的非敏感配置；成功后必须清除运行期凭证缓存并把相关 endpoint 的最近验证状态重置为 `not_run` 或待重新验证。

恢复场景：

- 如果数据库从设备备份恢复，但 Keychain 因 ThisDeviceOnly 规则未恢复，profile 状态变为 `credential_missing`。
- UI 保留 Provider、Base URL 和模型名，提示用户重新输入 API Key。
- 不应静默降级为 mock Provider，也不应自动清空非敏感配置。

### 11.5 UI 草稿到持久化模型映射

当前 UI 草稿可以映射为：

```text
AIProviderDraftConfiguration
  text.endpoint -> ai_provider_endpoints[purpose=text_generation]
  text.imageUnderstandingEnabled -> text endpoint image_input_enabled
  text.endpoint.independentCredential -> ai_provider_credentials[kind=api_key]
  speech.isEnabled -> ai_provider_endpoints[purpose=tts].is_enabled
  speech.endpoint.credentialReference == textModelCredential -> tts endpoint credential_id = text credential_id
  speech.endpoint.credentialReference == independent -> tts endpoint credential_id = independent credential_id
  embedding.isEnabled -> ai_provider_endpoints[purpose=embedding].is_enabled
  embedding.endpoint.credentialReference == textModelCredential -> embedding endpoint credential_id = text credential_id
  embedding.endpoint.credentialReference == independent -> embedding endpoint credential_id = independent credential_id
```

保存后 UI 展示状态来自 `AIProviderConfigurationProjection`：

- `profileDisplayName`
- `textEndpoint`
- `speechEndpoint`
- `embeddingEndpoint`
- `credentialStatesByEndpoint`
- `canRunSyntheticTest`
- `saveState`
- `lastValidationSummary`

UI 不接收：

- 明文 API Key。
- Keychain raw account。
- 完整请求头。
- 可用于还原或识别密钥的派生值。

### 11.6 Repository 与服务接口建议

建议协议：

```swift
public protocol AIProviderConfigurationRepository: Sendable {
    func loadDefaultProfile() async throws -> AIProviderConfigurationProfile?
    func saveProfile(_ profile: AIProviderConfigurationProfile) async throws
    func markCredentialState(_ state: AIProviderCredentialState, credentialID: AIProviderCredentialID) async throws
    func recordValidationEvent(_ event: AIProviderValidationEvent) async throws
}

public protocol AIProviderCredentialStore: Sendable {
    func upsertSecret(_ secret: AIProviderSecretInput, for reference: AIProviderCredentialKeychainReference) async throws
    func hasSecret(for reference: AIProviderCredentialKeychainReference) async -> AIProviderSecretPresence
    func resolveSecret(for reference: AIProviderCredentialKeychainReference) async throws -> AIProviderResolvedSecret
    func deleteSecret(for reference: AIProviderCredentialKeychainReference) async throws
}
```

实现注意：

- `AIProviderConfigurationRepository` 协议应放在 Core，而不是 AI package。原因是 Data 需要实现该协议，若协议放在 AI package，会迫使 `LangoTraceData` 依赖 `LangoTraceAI`，违反当前模块依赖方向。
- `AIProviderCredentialStore` 可以放在 AI package 或独立平台服务中，由 App Shell 装配；Data 不实现也不持有 Keychain store。
- `saveProfile` 不接收明文 secret。
- `upsertSecret` 不接收数据库 transaction 对象；业务层负责补偿删除，避免 Data 层和 KeychainStore 双向耦合。
- `resolveSecret` 只能由 Provider 测试或 Provider 请求服务调用，UI 不直接调用。
- 后续真实 Provider adapter 接收的是已经解析好的认证 header 构造输入，不自行读取 Keychain。

### 11.6.1 `AppDatabase` 与迁移入口补充设计

语言空间基础设施完成后，当前代码事实是：

- `GRDBLanguageSpaceRepository.persistent(at:)` 自己创建目录、打开 `DatabaseQueue(path:)`、执行 `Self.migrate(databaseQueue)`，然后设置数据库文件保护。
- `migrate(_:)` 是 `GRDBLanguageSpaceRepository` 的私有扩展方法，只注册 `v1_create_language_space_infrastructure`。
- `AppEnvironment.bootstrap()` 只暴露 `makeLanguageSpaceRepository` factory，没有共享数据库对象。

AI Provider 实施前应先做一个小型 Data 基础设施调整：

1. 新增 `AppDatabase` 作为共享数据库入口。
2. 由 `AppDatabase` 统一创建目录、打开 `DatabaseQueue`、设置文件保护和注册所有 migration。
3. 把语言空间 migration 从 `GRDBLanguageSpaceRepository` 私有方法迁移到共享 migrator，保持 migration identifier 不变。
4. 让 `GRDBLanguageSpaceRepository` 接收外部注入的 `DatabaseQueue` 或共享数据库 handle，不再自己决定整库迁移集合。
5. AI Provider repository 复用同一个 queue / handle，并把自己的 migration 注册到同一 migrator。
6. 测试继续支持 in-memory database，但由 `AppDatabase` 创建，避免每个 repository 各自维护一套测试数据库初始化逻辑。

该调整不改变语言空间表字段和行为，但它是 AI Provider 存储进入实现前的前置任务。否则两个 repository 即使指向同一个 `LangoTrace.sqlite`，也会在连接生命周期、migration 可见性、写事务组合和后续备份/导出策略上形成隐性分叉。

### 11.6.2 `AppDatabase` 独立设计评估

系统架构结论：应引入独立 `AppDatabase`，并把它作为 Data package 的数据库基础设施真源。

当前实现的优点：

- `GRDBLanguageSpaceRepository` 直接可用，代码少，测试容易构造。
- `DatabaseQueue` 适合当前语言空间管理低并发读写场景，事务行为清晰。
- `LanguageSpaceDatabaseLocation` 已经把主数据库放入正确的 Application Support 私有位置。

当前实现的架构问题：

- Repository 同时负责打开数据库、设置文件保护、注册 migration 和执行业务读写，职责过宽。
- 后续每增加一个真实 repository，都会面临“谁注册 migration、谁持有 queue、谁负责文件保护、谁处理迁移失败”的重复决策。
- 如果多个 repository 各自调用 `DatabaseQueue(path:)` 打开同一个文件，短期可能可运行，但会让事务组合、连接生命周期、测试初始化、导出快照和后续 `DatabasePool` 升级变得不稳定。
- migration 在单个 repository 私有方法中注册，不适合后续跨模块 schema 演进；例如 AI Provider 表、Entry 表、附件表和 FTS 表必须在同一 migrator 中按顺序前进。

推荐设计：

```text
AppEnvironment.bootstrap()
  -> AppDatabase.persistent(defaultDatabaseURL)
      -> DatabaseQueue
      -> DatabaseMigrator(all migrations)
      -> file protection / database pragmas
  -> GRDBLanguageSpaceRepository(database: appDatabase)
  -> GRDBAIProviderConfigurationRepository(database: appDatabase)
```

`AppDatabase` 负责：

- 解析并创建数据库目录。
- 打开 `DatabaseQueue`；未来如 Entry 列表、FTS 或后台任务出现明确并发需求，可在同一类型内部升级为 `DatabasePool`，不扩散到 UI / App Shell / Core 协议。
- 注册全部 migration，包括现有 `v1_create_language_space_infrastructure` 和后续 AI Provider schema migration。
- 设置数据库文件保护、SQLite pragmas 和迁移失败策略。
- 提供 `read` / `write` 或受控 `DatabaseQueue` 访问给 Data package 内部 repository；不向 UI、Core、AI 或 App Shell 暴露 SQL 细节。
- 提供 `inMemory` 和 `temporary` 工厂，统一测试初始化。

Repository 负责：

- 接收 `AppDatabase` 或 Data 内部 database handle。
- 只实现领域表的读写、查询和数据映射。
- 不注册全局 migration，不决定数据库文件位置，不处理文件保护。

早期开发阶段处理方式：

- 可以直接重写 `GRDBLanguageSpaceRepository` 的初始化边界，不需要保留 `persistent(at:)` / `inMemory()` 的旧公开便利 API；若测试仍需要便利工厂，也应委托 `AppDatabase.inMemory()`。
- 保持现有 migration identifier `v1_create_language_space_infrastructure` 不变即可；若还未发布且需要重写 schema，可以按早期重构原则在新任务方案中明确清理本地开发容器。
- 不需要为了已经存在的开发期数据库做复杂兼容迁移；但正式 migration 机制从 `AppDatabase` 引入后，应按“只追加 migration，不改写已发布 migration”的规则执行。

是否保留 `DatabaseQueue`：

- 第一版继续使用 `DatabaseQueue`。这符合语言空间计划中的低并发判断，也降低 AI Provider 配置写入的事务复杂度。
- `AppDatabase` 的价值不是立刻换成 `DatabasePool`，而是把 queue / pool 选择隐藏在 Data 基础设施内部。未来真的需要并发读时，只改 `AppDatabase` 和 Data 内部适配，不影响 Core 协议和 UI。

### 11.7 错误状态设计

配置保存错误：

- `missingRequiredEndpointField`
- `invalidBaseURL`
- `unsupportedCapabilityForProvider`
- `missingRequiredAPIKey`
- `keychainWriteFailed`
- `databaseWriteFailed`
- `orphanedCredentialCleanupFailed`

凭证读取错误：

- `missingCredential`
- `credentialInaccessible`
- `credentialCorrupted`
- `userInteractionRequired`

测试请求错误：

- `syntheticTestUnavailable`
- `credentialValidationOnly`
- `networkUnavailable`
- `timeout`
- `providerRejected`
- `authenticationFailed`
- `unsupportedModel`
- `unsupportedEndpointPurpose`
- `invalidResponse`
- `invalidAudioResponse`
- `invalidEmbeddingResponse`
- `cancelledByUser`

错误日志规则：

- 记录错误分类、Provider preset、endpoint purpose、模型名、耗时和平台。
- 不记录 API Key、请求头完整值、请求体、响应体、用户内容或 Keychain account 全量字符串。

### 11.8 与语言空间数据基础设施的依赖

实施前必须确认：

- 独立 `AppDatabase` 已经从当前 `GRDBLanguageSpaceRepository` 内部抽出，或本任务实施的第一个子任务就是抽出该入口。
- 迁移注册方式已经统一，语言空间 migration identifier `v1_create_language_space_infrastructure` 保持不变，AI Provider migration 在同一个 migrator 中追加。
- 测试临时数据库和 in-memory 数据库由 `AppDatabase` 创建，再注入语言空间 repository 与 AI Provider repository。
- AppEnvironment 中 repository/service 装配模式已经能共享同一个 `AppDatabase` 实例，而不是每个 repository factory 各自打开数据库文件。
- 数据库文件位置继续使用 `LanguageSpaceDatabaseLocation.defaultDatabaseURL()` 当前确定的 `Application Support/LangoTrace/LangoTrace.sqlite`，除非另开数据基础设施任务统一重命名。
- 数据库文件保护继续只保护非敏感主数据和配置元数据；密钥访问级别以 Keychain item 的 accessibility 为准。

AI Provider 存储实施时不得：

- 新建独立 SQLite 数据库文件。
- 让 AI Provider repository 和语言空间 repository 各自长期维护独立 `DatabaseMigrator` / `DatabaseQueue` 生命周期。
- 让 App Shell 或 SwiftUI 持有 `DatabaseQueue`、SQL record、migration 注册器或 SQLite pragma 细节；这些应留在 Data package 的 `AppDatabase` 内部。
- 把 Provider 配置写入 `app_state`。`app_state` 当前只承载本设备本地状态，例如 `current_language_space_id`，不应混入 Provider profile、endpoint 或凭证引用元数据。
- 把 KeychainStore 放进 Data package 形成 Data -> Security 平台耦合；更合适的是 AI package 或独立 platform service 由 App Shell 装配。
- 把 Provider profile 绑定到 `language_space_id`。

### 11.9 实施阶段拆分建议

后续实施建议拆成六个小任务：

1. Data 基础设施整理：新增 `AppDatabase`，从 `GRDBLanguageSpaceRepository` 中抽出数据库打开、文件保护、统一 `DatabaseQueue` 和 migrator，保持现有语言空间行为和测试通过。
2. Core 配置模型、repository 协议和错误类型；AI package 增加配置服务、credential resolver、Keychain store 协议和测试 target。
3. Keychain credential store 与单元测试，使用测试替身覆盖写入、读取、缺失、删除和轮换。
4. SQLite / GRDB 非敏感配置 repository 与迁移，复用 `AppDatabase`。
5. UI 保存 / 加载 / 状态展示接入；测试请求至少完成配置完整性测试和 Keychain 可读性检查。
6. 可选子任务：Provider 合成探测。仅在最小 Provider client 边界已经稳定时实现文本模型真实探测；语音生成和向量模型按 11.3.7 的合成策略逐项接入。

Prompt Preset 执行、真实 AI 生成内容保存、请求预览、请求日志、TTS 播放和向量索引构建应另开任务。

### 11.10 实施防误读清单

后续 AI 或开发者进入编码前，应逐项确认：

- 不要直接在 `AIProviderSettingsView` 里调用 SQLite、Keychain、`URLSession` 或具体 Provider SDK。
- 不要把 `AIProviderPreset` 当前 UI 内部 enum 直接当成长期 Core 模型照搬；应先评估哪些字段属于平台无关配置模型，哪些只是 UI 选择辅助。
- 不要为了快速保存，把 API Key 临时放进 `UserDefaults`、SQLite、`app_state`、日志、测试 fixture、preview 数据或 SwiftUI `@State` 的持久投影。
- 不要让 `GRDBLanguageSpaceRepository` 继续私有注册整库 migration 后再新增 AI Provider repository；先抽出 `AppDatabase`。
- 不要把 `app_state` 扩展为 Provider 配置表。`app_state` 当前只代表本机状态，例如 `current_language_space_id`。
- 不要让 Data package 依赖 AI package。Data 实现 Core repository 协议；AI service 消费 Core 协议。
- 不要把 `credential_id` 设计成 Provider 名称、模型名或 Base URL 派生值。它必须是稳定随机 ID。
- 不要在 UI 加载旧配置时回填旧 API Key 明文。用户不修改密钥时保存配置也不得读取旧明文。
- 不要把“测试请求”做成完整用户内容 AI 请求。本方案最低要求是配置完整性和 Keychain 可读性检查；真实 Provider 合成探测只能发送固定 synthetic 内容。
- 不要为当前开发期数据库做复杂兼容包袱。项目仍处于早期阶段，若 `AppDatabase` 抽取需要改写便利 API 或清理本地开发容器，应在实施计划中记录后直接处理。

## 12. 复查方法

设计复查：

- 检查数据库字段中没有 API Key、token、secret、密钥密文、密钥 hash 或密钥尾号。
- 检查 Core / Data / AI 依赖方向仍符合 `Data -> Core`、`AI -> Core`，不存在 `Data -> AI`。
- 检查 AI Provider 表迁移和语言空间表迁移由同一个 `AppDatabase` 注册，语言空间 repository 不再私有决定整库迁移集合。
- 检查 `AppDatabase` 是数据库生命周期、migration、文件保护和测试数据库初始化的唯一入口；repository 不再各自打开同一个 SQLite 文件。
- 检查 endpoint 与 credential 是引用关系，多个 endpoint 能共享同一个 `credential_id`。
- 检查 Keychain 与 SQLite 的非原子保存路径有补偿策略：新增、替换、原地轮换、删除和清理失败都能落到非敏感状态，而不是留下 active endpoint 指向孤儿 credential。
- 检查云端 Provider 的 `base_url` 默认只允许 `https`，`http` 只允许本机回环地址；请求预览展示 host，不允许 secret 出现在 URL 中。
- 检查 UI 加载路径不解密，只有用户触发测试或真实请求时才读取 Keychain。
- 检查 UI 的 API Key 明文草稿在保存成功、离开页面、切换共享方式和取消编辑时被清空；已保存密钥的显示按钮不会触发 Keychain 解密回显。
- 检查 App 启动路径只预加载非敏感配置和凭证存在性，不读取明文 API Key。
- 检查运行期凭证缓存有过期、后台清除、凭证变更清除和认证失败清除规则。
- 检查 Keychain item 默认不同步，恢复到新设备后有 `credential_missing` 状态。
- 检查实施依赖明确指向语言空间数据基础设施，不创建第二套数据库。
- 检查测试请求只发送合成检测内容，并且文本、语音生成、向量模型的验证标准不保存用户内容、音频内容或向量值。

实现后复查：

- 单元测试模拟 Keychain 写入成功、写入失败、读取缺失、读取不可访问、删除共享凭证、删除独立凭证。
- 单元测试模拟 Keychain 写入成功但数据库提交失败、替换凭证后旧 item 清理失败、原地轮换失败和 `cleanup_state` 重试清理。
- 数据库测试确认保存 profile 后只出现非敏感字段。
- 数据库测试确认 active default、`profile_id + purpose`、`keychain_service + keychain_account`、header 名称归一唯一和外键关系被约束。
- 源码扫描确认 UI 不直接调用 `SecItemCopyMatching`、`SecItemAdd`、`URLSession` 或真实 Provider adapter。
- 日志扫描确认错误对象和 validation event 不包含明文 secret。
- 若实现真实 Provider 合成探测，使用测试替身覆盖文本成功、TTS 返回非音频、embedding 维度为空、认证失败和超时。

## 13. 验证命令

本方案阶段需要运行：

```bash
git diff --check
git status --short
```

实施完成后需要运行：

```bash
scripts/verify.sh
```

如果只完成本方案文档且不改代码，可不运行 `scripts/verify.sh`，但必须说明原因。

## 14. 文档影响检查

本方案只新增 active plan，不改变长期规范。实施完成后必须检查：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 是否需要补充 Keychain item 引用、解密读取和 credential missing 状态。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 是否需要补充 Keychain 恢复缺失、ThisDeviceOnly 和日志分类。
- `docs/architecture/001-initial-module-boundaries.md` 是否需要更新 AI / Data / App Shell 边界快照。
- `docs/platform-page-inventory.md` 是否需要把 AI Provider 设置页从 Local Mock 更新为真实配置保存。
- 是否需要新增 `docs/review/rounds/2026-05-20-ai-provider-configuration-storage.md` 做专项文档影响检查。

不需要新增 ADR，因为本方案不改变本地优先、用户自带 Provider、敏感凭证进入 Keychain、密钥默认不同步这些核心决策。

## 15. 实施记录

- 2026-05-20：创建 Draft 设计方案，仅覆盖架构、存储字段、加密/解密边界和实施依赖；未修改代码。
- 2026-05-20：语言空间数据基础设施完成后进行代码现状复审；补充独立 `AppDatabase`、统一 migration、Core/Data/AI 依赖方向和 AI package 测试 target 前置要求；未修改代码。
- 2026-05-20：再次复读语言空间 repository、AppEnvironment、Package 依赖和数据规范后确认，独立 `AppDatabase` 是更优且应前置的 Data 基础设施设计；当前 repository 自建数据库的实现可以在早期阶段直接推翻重构，无需为开发期临时 API 做兼容。
- 2026-05-20：根据系统架构复查补充 Keychain / SQLite 非原子提交补偿策略、迁移级唯一/外键约束、URL 安全边界、`secret_presence` 最近观测语义、UI 明文草稿生命周期和后续验证项；未修改代码。

## 16. 完成标准

本方案可以进入实施前必须满足：

- 用户确认本 Draft 的范围、字段设计、Keychain 访问策略和与语言空间数据基础设施的依赖边界。
- 语言空间数据基础设施任务已经完成；在 AI Provider 实施前，必须把当前 `GRDBLanguageSpaceRepository` 内部的 `DatabaseQueue` / migration 抽象为独立 `AppDatabase`，或把该抽取列为 AI Provider 实施的第一个子任务。
- Core / Data / AI 协议归属已经确认：平台无关配置模型和 repository 协议归 Core，Data 实现 GRDB repository，AI 消费 Core 协议并处理凭证解析和 Provider 边界。
- 方案明确不包含完整真实 AI 生成请求；Provider 合成探测若纳入实施，只能作为可选子任务发送固定合成检测内容。
- 方案明确数据库不保存敏感凭证。
- 方案明确 UI 加载不解密，解密只发生在用户触发的测试或真实请求服务层。
- 方案明确 Keychain 与 SQLite 的非原子保存、替换、删除和补偿清理规则。
- 方案明确云端 Provider endpoint 的 URL 安全边界，以及 UI 明文 API Key 草稿的清理规则。

本任务最终可移入 `docs/plans/done/` 的条件：

- 对应实现完成并通过 `scripts/verify.sh`。
- AI Provider 设置页能保存和加载非敏感配置。
- API Key 能写入、读取、删除 Keychain，并有缺失和不可访问状态。
- 数据库和日志扫描确认没有敏感凭证。
- 文档影响检查完成。

## 17. 剩余风险

- Keychain 在 iOS、iPadOS 和 macOS 上的 accessibility 行为存在平台差异，实施时需要用平台测试替身和真机 / 本机验证补齐。
- ThisDeviceOnly 会导致设备迁移或备份恢复后密钥缺失，这是符合默认不同步原则的安全取舍，但 UI 必须解释清楚。
- Swift 内存中无法完全保证明文 secret 清零，实施时只能通过缩短生命周期、避免日志和避免持久引用降低风险。
- 未来如果用户要求 Provider 配置跨设备同步，需要单独设计端到端加密、用户确认、密钥迁移和恢复策略，不能复用本方案的默认不同步路径直接扩展。
- 未来如果接入自定义请求头，header 名称本身也可能暴露服务结构；高级配置页需要额外审查展示和日志边界。
- Keychain item 清理失败会留下本机安全存储残留。实施时必须支持非敏感 `cleanup_state` 和重试清理，但不得为了清理便利把 Keychain account 全量字符串暴露给 UI 或日志。
- 自定义 OpenAI-compatible Provider 可能指向代理、内网或聚合服务。第一版应保守限制 URL；如后续放开局域网 HTTP 或自签证书，需要单独审查请求预览、风险提示和诊断日志。
