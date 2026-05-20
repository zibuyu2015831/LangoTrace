# 任务方案：语言空间数据基础设施与 iOS 管理页

状态：Draft
类型：feature
创建日期：2026-05-20
最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户明确否定旧方案中的单语言空间 UserDefaults 过渡实现，要求基础设施在起步阶段完整建设，避免后续多空间、删除、切换、同步和迁移返工。
- 2026-05-20：用户确认直接引入 SQLite / GRDB 作为真实持久化实现。
- 2026-05-20：用户确认允许同一目标语言创建多个语言空间；允许同名空间，但 UI 创建或重命名时应提示“已有同名空间”。
- 2026-05-20：用户要求第一版即实现删除功能，并先完成 iOS 端设置页中的“语言空间”管理页面设计与实现。
- 状态为 `Draft` 时不能开始实现。用户确认本方案后，需补充确认记录再进入编码。

## 1. 需求描述

当前语迹已经有 onboarding 创建语言空间、Welcome / Onboarding / Main 路由和三端主界面骨架，但语言空间仍只是内存中的 `LanguageSpacePreview`。用户完成首次引导后可以进入 Main，但 App 重启无法恢复语言空间；设置里的“语言空间”也只是能力说明，不具备真实管理能力。

本任务要把语言空间从 UI preview / mock 状态升级为真实本地主数据基础设施，并在 iOS 端设置页先落地完整语言空间管理入口。第一版必须支持：

- 使用 SQLite / GRDB 持久化语言空间。
- 多语言空间模型。
- 同一目标语言可以有多个空间。
- 同名空间允许存在，但创建或重命名时提示用户已有同名空间。
- 当前语言空间的显式选择和冷启动恢复。
- 新增、切换、重命名、删除语言空间。
- iOS 设置页中新增真实“语言空间”管理页面。
- 删除当前空间后有明确 fallback，不自动创建隐式默认空间。
- 数据库文件位置、系统备份、文件保护、WAL/导出一致性和迁移失败处理符合 Apple 平台应用数据存储惯例。

## 2. 现状描述

代码现状：

- `LangoTraceApp/AppEnvironment.swift` 已声明 `languageSpaceRepository: any LanguageSpaceRepository`，但当前注入 `EmptyLanguageSpaceRepository()`。
- `Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift` 中 `LanguageSpaceRepository` 仍为空协议。
- `AppSessionState` 当前只在内存中持有 `currentLanguageSpace: LanguageSpacePreview?`。
- `AppSessionState.createLanguageSpace()` 当前只调用 `onboardingDraft.makeLanguageSpacePreview()`，不写入本地存储。
- `LangoTraceRootView` 的 Main 分支仍存在 `languageSpace ?? onboardingDraft.makeLanguageSpacePreview()` fallback，会掩盖缺少真实语言空间的状态错误。
- `PhoneMainView` 中设置入口通过 `.settingsList` 和 `.settings(SettingsCapability.Kind)` 导航，语言空间入口当前仍会打开 summary sheet 或能力说明。
- `SettingsCapability.Kind.languageSpace` 已存在，但 `SettingsCapabilityDetailView` 对它只展示状态说明，不提供管理 UI。
- `LanguageSpaceSummaryView` 只展示当前空间摘要，不支持列表、切换、新增、重命名或删除。
- `LangoTraceData` 已有内存 `LearningContentRepository`，但 Entry / Rendering / Practice / Memory 仍不是长期持久化数据。

文档现状：

- `docs/spec/007-data-storage-migration-export-and-attachments.md` 已补充基础设施完整建设原则：真实持久化不能只实现单空间临时版本。
- `docs/architecture/001-initial-module-boundaries.md` 已补充 Data 基础设施边界：语言空间持久化、启动恢复、Repository、SQLite / GRDB schema、迁移、导出、删除和恢复应按多语言空间模型设计。
- 旧 active 方案 `2026-05-17-feature-language-space-persistence-startup-restore.md` 基于单空间 UserDefaults 过渡，不再作为新任务入口，本方案创建时删除旧方案。

## 3. 目标

本任务完成后必须达到：

- `LangoTraceData` 引入 SQLite / GRDB 真实本地数据库基础设施。
- 首版 schema 至少包含语言空间表、当前空间状态和迁移入口。
- `LanguageSpaceRepository` 成为真实协议，支持多空间创建、列表、读取、当前空间选择、重命名和删除。
- 同一目标语言可创建多个语言空间；数据库不对 `target_language_code` 做唯一约束。
- 同名空间可存在；创建或重命名时 UI 给出非阻断提示。
- onboarding 创建第一个空间时写入数据库并设为当前空间；写入失败不得进入 Main。
- App 启动时从数据库恢复当前空间；无有效空间时进入 onboarding。
- iOS 设置页中的“语言空间”进入真实管理页，支持新增、切换、重命名、删除。
- 删除当前空间后选择最近使用的其他有效空间；如果没有其他有效空间，回到 onboarding 或无空间恢复路径。
- `LanguageSpacePreview` 保持 UI 展示投影，不作为数据库 schema。

## 4. 范围

本任务会处理：

- Core 语言空间主模型、创建输入、更新输入、删除/归档状态、展示投影映射和校验。
- Data 层 SQLite / GRDB 依赖、数据库队列、迁移、schema 和 repository 实现。
- Data 层数据库文件 URL 解析、Application Support 目录创建、iOS 文件保护属性和测试用临时数据库注入。
- App 层 `AppEnvironment.bootstrap()` 和 `AppSessionState` 启动恢复、创建、选择、删除 fallback。
- App 层存储恢复中、恢复失败和重试状态。
- iOS 设置页“语言空间”管理页面设计与实现。
- iOS 端新增/重命名/删除确认交互。
- 单元测试和必要 UI 行为测试。
- 相关 spec、architecture、testing、review 文档影响检查。

## 5. 不做什么

本任务不处理：

- 不实现 Entry、Rendering、Practice、Memory 的 SQLite 表和长期持久化。
- 不实现附件存储、照片、音频、OCR 文件和导出包。
- 不实现同步引擎、CloudKit、WebDAV、S3、R2 或 iCloud Drive。
- 不实现 StoreKit、账号系统或多用户系统。
- 不实现真实 AI Provider 请求、TTS、Speech、OCR 或权限申请。
- 不实现 iPad 和 macOS 的完整语言空间管理页；本轮先完成 iOS 端页面。iPad / macOS 可以继续展示当前 summary 或能力边界，但不得破坏 shared repository。
- 不实现已删除空间的用户可见恢复站；但 Data 层删除策略必须为未来恢复窗口或同步 tombstone 留出边界。
- 不实现自定义数据库加密、SQLCipher 或用户自设数据库密码。首版依赖 App Sandbox、系统备份机制、文件保护和 Keychain 分离敏感凭证；更强本地加密应在真实日记、照片、音频和导出恢复方案明确后单独评估。
- 不实现用户可见的数据库文件管理、导入备份或导出备份 UI；但本轮必须避免把 WAL 下的单文件复制误当成未来备份方案。

## 6. 证据与决策依据

- `docs/README.md`：一个语言空间对应一门目标语言；工作、生活、旅行、会议、情绪不是空间，而是标签、场景或 Prompt 模式。
- `docs/decisions/004-use-language-space-as-primary-model.md`：语言空间是核心信息模型。
- `docs/decisions/005-local-first-and-user-owned-providers.md`：坚持本地优先和用户自带 Provider。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：真实数据写入必须有主数据、迁移、导出、删除和恢复边界。
- `docs/architecture/001-initial-module-boundaries.md`：Data 层负责 Repository、SQLite / GRDB、迁移、FTS 和附件元数据。
- Apple File System Programming Guide：App-created support files 应放在 `Library/Application Support`；可重建缓存应放在 `Library/Caches`；`Documents` 与 `Application Support` 默认参与系统备份，缓存和临时文件不应作为主数据存储位置。
- Apple Foundation file protection 文档：`completeUntilFirstUserAuthentication` 表示设备启动后需用户首次解锁才能访问文件，之后即使设备再次锁定也可继续访问，适合作为首版本地数据库的默认文件保护级别。
- GRDB 文档：GRDB 通过 `DatabaseQueue` / `DatabasePool` 管理 SQLite；`DatabasePool` 会涉及 WAL 行为，备份和导出不能简单等同于复制单个数据库主文件。
- 当前代码中 `LanguageSpaceRepository` 为空协议，说明 repository 边界已有入口但未落地。
- 当前 `AppSessionState` 只持有内存空间，说明启动恢复必须从 App 状态机层接入。
- 当前 iOS 设置入口已经有 `SettingsCapability.Kind.languageSpace`，适合作为语言空间管理页入口。

架构决策：

- 直接引入 SQLite / GRDB，不使用 UserDefaults 作为持久化过渡。
- 允许同一目标语言多个空间。原因：语迹的空间是学习上下文，不是语言 code 配置；用户可能需要“英语 - 日常”“英语 - 工作”“英语 - 旅行”等多个上下文。
- 允许同名空间。原因：同名不应成为数据层约束；UI 负责提示，用户保留最终决定权。
- 使用稳定唯一 ID 作为空间主键，`target_language_code` 和 `display_name` 都只是属性。
- 第一版删除采用软删除语义：用户点击“删除”后，该空间从 active 列表和当前空间候选中移除，数据库记录保留 `deleted_at`。原因：后续 Entry、附件、导出、同步 tombstone 和恢复窗口都需要删除状态边界；当前没有真实 Entry 表，不应先形成不可逆硬删除习惯。
- 主数据库放入 Application Support。原因：语言空间是 App 私有主数据，不应暴露为用户文档，也不能放入可能被系统清理的缓存目录。
- 首版主数据库不排除系统备份。原因：语言空间是用户学习上下文，属于应随设备备份恢复的主数据；未来可重建派生索引和临时文件必须单独排除备份。
- 首版优先使用 `DatabaseQueue`。原因：语言空间管理写入频率低，单连接队列更容易验证事务、迁移和错误恢复；后续 Entry 列表、FTS 或后台处理需要并发读时再升级到 `DatabasePool`。
- 同名检测使用独立规范化字段或等价 repository 规范化函数，不依赖 UI 字符串临场比较。原因：同名允许存在但提示必须稳定、可测试。
- UI 第一版先完成 iOS。原因：iPhone 是个人记录和设置管理的核心入口；iPad / macOS 可在后续按平台设计展开。

## 7. 涉及的代码文件路径

预计修改：

- `Packages/LangoTraceData/Package.swift`：引入 GRDB 依赖。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpacePreview.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/OnboardingDraft.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LaunchRoute.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceDatabaseLocation.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceRecord.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceStore.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSummaryView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

预计新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpace.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpaceInput.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpaceError.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/InMemoryLanguageSpaceRepository.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceEditorView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceDeleteConfirmationView.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LanguageSpaceTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceManagementTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/SyncSettingsTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LaunchFlowTests.swift`

## 9. 涉及的文档路径

预计参考或更新：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/testing/README.md`
- `docs/review/README.md`
- `docs/review/INDEX.md`
- `docs/review/rounds/2026-05-20-language-space-data-infrastructure.md`

外部参考：

- Apple File System Programming Guide: `https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html`
- Apple `completeUntilFirstUserAuthentication`: `https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication`
- GRDB sharing a database / WAL: `https://www.mintlify.com/groue/GRDB.swift/guides/sharing-a-database`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.0 架构复评补充

2026-05-20 复评结论：方案主方向成立，直接使用 SQLite / GRDB、多语言空间、稳定 ID、软删除和 iOS 管理页符合语迹的本地优先定位。但实现前必须把以下边界写入实施约束，否则容易在数据库落地、备份、导出、启动恢复和未来同步阶段返工：

- 数据库文件必须放在 App 私有容器的 Application Support 目录下，例如 `Application Support/LangoTrace/LangoTrace.sqlite`；不得放在 `Documents`、`Caches` 或 `tmp` 作为主数据库位置。
- 主数据库属于用户主数据，默认允许随系统设备备份或 iCloud 设备备份进入备份集合；可重建的 FTS、向量索引、缩略图和临时导出包不得进入主备份集合，应放入 `Caches` 或显式设置 `isExcludedFromBackup`。
- iOS 数据库目录和数据库文件应设置文件保护级别。首版推荐 `completeUntilFirstUserAuthentication`，兼顾隐私和常规启动可用性；后续照片、音频、日记正文等更敏感附件可以在附件任务中评估是否使用更强保护级别。
- 如果使用 `DatabasePool` 或其他 WAL 模式，任何备份、导出或调试复制都不能只复制单个 `.sqlite` 文件。用户可读导出必须通过 repository 快照生成；可恢复备份应使用 SQLite/GRDB 支持的一致性备份方式，或在受控 checkpoint 后处理 `.sqlite`、`.sqlite-wal`、`.sqlite-shm` 的一致性。
- `createLanguageSpace + selectCurrentLanguageSpace`、`selectCurrentLanguageSpace + lastOpenedAt`、`deleteLanguageSpace + fallback current` 必须在同一数据库事务中完成，避免 App 被杀或写入失败后出现“空间已创建但当前空间未更新”等半状态。
- App 启动恢复不应在 SwiftUI 主线程同步阻塞。推荐 `AppSessionState` 增加恢复中的状态，启动后以 `Task` 调用 repository，恢复成功后再进入 welcome / onboarding / main 的现有路由；数据库失败时进入可恢复错误状态，而不是静默创建默认空间。
- `app_state.current_language_space_id` 可以不做强外键，但 repository 必须在读取时把 missing、deleted 和损坏引用统一归一为可解释 fallback，并把修复后的 current 写回 `app_state`。
- 同名提示需要按规范化后的 display name 判断，例如 trim 后比较；是否大小写折叠需要结合当前语言显示规则，首版推荐对 Latin 名称做 case-insensitive 检测，对 CJK 名称按原文检测。
- 软删除只是第一版 UI 语义；Data 层必须把 deleted 空间排除出 active 查询、当前空间候选、同名提示候选和普通设置列表，同时保留未来恢复、导出和同步 tombstone 的扩展点。

### 11.1 数据模型

新增 Core 主模型：

```text
LanguageSpace
  id: String
  nativeLanguageCode: String
  targetLanguageCode: String
  level: LanguageLevel
  displayName: String
  displayNameNormalized: String
  createdAt: Date
  updatedAt: Date
  lastOpenedAt: Date?
  deletedAt: Date?
```

规则：

- `id` 使用稳定唯一 ID，推荐 UUID 字符串。
- `targetLanguageCode` 不唯一。
- `displayName` 不唯一。
- `displayNameNormalized` 只用于检索、排序和同名提示，不作为唯一约束，也不直接展示。
- `deletedAt == nil` 表示 active 空间。
- `LanguageSpacePreview` 由 `LanguageSpace` 映射得到，只服务 UI。
- `OnboardingDraft` 只产生创建输入，不直接产生最终持久化对象。

新增 Core 输入模型：

```text
CreateLanguageSpaceInput
  nativeLanguageCode: String
  targetLanguageCode: String
  level: LanguageLevel
  displayName: String

UpdateLanguageSpaceInput
  nativeLanguageCode: String
  targetLanguageCode: String
  level: LanguageLevel
  displayName: String
```

输入规范化：

- 语言 code 复用 `OnboardingDraft.normalized()` 当前规则，保存前必须归一到支持的 `LearningLanguage` code。
- `displayName` 保存前 trim 首尾空白；trim 后为空时，使用目标语言默认空间名。
- `displayNameNormalized` 首版规则：
  - trim 首尾空白。
  - 合并连续空白为单个空格。
  - Latin 字符使用 locale-insensitive lowercase。
  - CJK、Kana、Hangul 和其他字符保持原文。
- 同名提示基于 `displayNameNormalized`；保存时不阻断同名。

### 11.2 SQLite / GRDB schema

首版 migration 建议命名为 `v1_create_language_space_infrastructure`。

表：`language_spaces`

```text
id TEXT PRIMARY KEY
native_language_code TEXT NOT NULL
target_language_code TEXT NOT NULL
level TEXT NOT NULL
display_name TEXT NOT NULL
display_name_normalized TEXT NOT NULL
created_at REAL NOT NULL
updated_at REAL NOT NULL
last_opened_at REAL
deleted_at REAL
```

索引：

```text
idx_language_spaces_active_updated_at(deleted_at, updated_at)
idx_language_spaces_target_language(target_language_code)
idx_language_spaces_display_name_normalized(display_name_normalized)
```

表：`app_state`

```text
key TEXT PRIMARY KEY
value TEXT
updated_at REAL NOT NULL
```

当前空间记录：

```text
key = "current_language_space_id"
value = language_spaces.id
```

说明：

- `app_state` 不使用外键强约束，避免当前空间指向已删除或损坏记录时数据库直接失败；repository 启动恢复时处理 fallback。
- 后续 Entry 表必须通过 `space_id` 归属 `language_spaces.id`。
- 后续同步 tombstone 可复用 `deleted_at` 或扩展独立 sync metadata。
- 不对 `target_language_code`、`display_name` 或 `display_name_normalized` 建唯一索引。
- 迁移执行时启用 SQLite foreign key 支持；首版只有 `app_state` 不使用外键，后续 Entry 等主数据表必须通过外键或 repository 级完整性检查绑定 `language_spaces.id`。

迁移和回滚策略：

- 使用 GRDB `DatabaseMigrator` 注册 `v1_create_language_space_infrastructure`。
- schema 版本前进只通过新增 migration，不通过改写既有 migration。
- 正式用户数据不支持自动降级回滚；迁移失败时不删除数据库、不创建新数据库覆盖旧库，App 进入存储错误状态并提供重试。
- 测试数据库使用临时目录，每个测试独立创建和销毁。
- 早期开发阶段如果 schema 在发布前需要重写，可以按 AGENTS 早期重构原则在任务方案中记录并清理本地开发容器；一旦存在真实用户数据或发布版本，不再使用清空容器作为正常升级路径。

数据库位置与 Apple 平台约束：

- `LanguageSpaceDatabase` 负责解析平台数据库 URL，并创建缺失目录。
- iOS 和沙盒 macOS 均使用 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` 下的 App 专属子目录。
- 主数据库文件名固定为 `LangoTrace.sqlite`，同目录下允许 SQLite / WAL 生成配套文件。
- 主数据库目录不设置 `isExcludedFromBackup`；未来 FTS、向量索引、缩略图、下载缓存和临时导出包必须与主数据库分离，并排除备份或放入 Caches。
- iOS 上创建数据库后应设置文件保护属性，首版推荐 `completeUntilFirstUserAuthentication`。
- 不把 API Key、Provider token、对象存储密钥、加密密钥写入该数据库；这些仍归 Keychain 或等价安全存储。
- 测试和 preview 可以向 `LanguageSpaceDatabase` 注入临时数据库 URL，禁止测试写入真实 Application Support。

GRDB 连接建议：

- 首版可以使用 `DatabaseQueue` 降低并发复杂度；如果实现阶段需要读写并发，再使用 `DatabasePool`。
- 如果使用 `DatabasePool`，需要在方案实现记录中注明 WAL 行为，并把一致性备份/导出测试纳入后续导出任务。
- 所有写入型 repository 方法必须通过事务包住相关 SQL。
- repository 对外不暴露 `DatabaseQueue`、`DatabasePool`、SQL 字符串或 record 类型；SwiftUI 和 App Shell 只接触 Core 模型与 repository 协议。

### 11.3 Repository 协议

`LanguageSpaceRepository` 首版能力：

```text
listActiveLanguageSpaces() throws -> [LanguageSpace]
languageSpace(id:) throws -> LanguageSpace?
currentLanguageSpace() throws -> LanguageSpace?
createLanguageSpace(input:) throws -> LanguageSpace
updateLanguageSpace(id:input:) throws -> LanguageSpace
selectCurrentLanguageSpace(id:) throws -> LanguageSpace
deleteLanguageSpace(id:) throws -> LanguageSpaceDeletionResult
duplicateNameExists(displayName:excludingID:) throws -> Bool
```

协议边界：

- 协议保持 `Sendable`，实现必须能安全地从 App 层异步任务调用。
- 方法首版可以保持 synchronous throwing；App 层不得在主线程直接执行可能触发 I/O 的 repository 调用，应通过 `Task` 或专门恢复流程包装。
- `languageSpace(id:)` 默认返回 active 或 deleted 空间都可以；用于用户可见列表时必须通过 `listActiveLanguageSpaces()`。
- `currentLanguageSpace()` 只返回 active 空间；如果 current 指向 missing / deleted，repository 内部执行 fallback 修复后返回 fallback，或在无 active 空间时返回 nil。
- `updateLanguageSpace(id:input:)` 不允许更新 deleted 空间；若 id 不存在或已删除，返回明确错误。
- `selectCurrentLanguageSpace(id:)` 不允许选择 missing 或 deleted 空间。
- `deleteLanguageSpace(id:)` 对 missing 空间返回明确错误；对已 deleted 空间保持幂等还是返回错误需固定为：返回错误，避免 UI 误以为刚刚完成删除。

删除结果：

```text
LanguageSpaceDeletionResult
  deletedSpaceID
  fallbackCurrentSpace: LanguageSpace?
  remainingActiveCount
```

删除规则：

- 删除采用 soft delete：写入 `deleted_at` 和 `updated_at`。
- 删除非当前空间：当前空间不变。
- 删除当前空间：选择 `last_opened_at` 最新的其他 active 空间；若没有其他 active 空间，则清空 `current_language_space_id`。
- 删除最后一个空间后，App 不创建默认空间，回到 onboarding 或无空间恢复路径。
- 删除、切换和创建后设为当前必须是事务性写入。
- `duplicateNameExists` 只检查 active 空间，不检查 soft-deleted 空间。

事务清单：

- `createLanguageSpace(input:)`：插入 `language_spaces`、写入 `app_state.current_language_space_id`、设置 `last_opened_at` 在同一事务完成。
- `selectCurrentLanguageSpace(id:)`：校验 active、写入 `app_state.current_language_space_id`、更新 `last_opened_at` 在同一事务完成。
- `updateLanguageSpace(id:input:)`：校验 active、更新语言字段、`display_name`、`display_name_normalized`、`level`、`updated_at` 在同一事务完成。
- `deleteLanguageSpace(id:)`：校验 active、写入 `deleted_at`、选择 fallback、写回或清空 `app_state.current_language_space_id` 在同一事务完成。

错误类型建议：

```text
LanguageSpaceError
  storageUnavailable
  migrationFailed
  notFound
  deleted
  invalidInput
  noActiveLanguageSpace
```

错误处理原则：

- Data 层保留底层错误供日志或 debug 使用，但 UI 只展示可本地化、可恢复的错误摘要。
- 输入错误停留在编辑页；存储错误停留在当前页面并提供重试。
- 迁移失败和数据库打不开属于启动恢复错误，不允许继续进入 Main。

### 11.4 App 启动和状态机

启动恢复：

1. App bootstrap 创建 SQLite database queue 和 `GRDBLanguageSpaceRepository`。
2. `AppSessionState` 进入恢复中状态，并通过异步任务读取 `currentLanguageSpace()`。
3. 如果返回 active 空间，设置 `currentLanguageSpace` 并进入 welcome；用户完成 Welcome 后进入 Main。
4. 如果无 active 空间，进入 welcome；用户完成 Welcome 后进入 onboarding。
5. 如果 `current_language_space_id` 指向 missing 或 deleted 空间，repository 选择最近使用的其他 active 空间并修复 `app_state`；如果没有 active 空间，则清空 current。
6. 如果数据库打不开、迁移失败或读取失败，进入可恢复错误状态；第一版可以显示本地存储错误和重试入口，但不得静默创建默认空间，也不得把错误伪装成首次使用。

创建流程：

1. onboarding 收集母语、目标语言、水平。
2. 默认 `displayName` 使用目标语言默认空间名；若同名 active 空间存在，显示提示但允许继续。
3. 用户点击创建后，repository 写入 `language_spaces` 并设为当前空间。
4. 写入成功后更新 `currentLanguageSpace` 并进入 Main。
5. 写入失败时停留 onboarding，显示错误。

切换流程：

1. iOS 语言空间管理页列出 active 空间。
2. 当前空间使用 checkmark、语义色或辅助文本标识。
3. 点击其他空间后调用 `selectCurrentLanguageSpace(id:)`。
4. repository 更新 `current_language_space_id` 和 `last_opened_at`。
5. AppSessionState 更新当前空间，主界面内容跟随空间 ID 切换。

错误状态：

- 存储恢复失败时，UI 应显示本地存储错误，不允许进入会产生真实写入的 Main。
- 创建、重命名、切换、删除失败时，当前 UI 状态保持不变，并显示可重试错误。
- 如果删除最后一个空间成功，`currentLanguageSpace` 置空，路由回 onboarding 或无空间恢复路径。

建议扩展 App 状态：

```text
AppSessionState
  phase: LangoTraceAppPhase
  recoveryState: LanguageSpaceRecoveryState
  currentLanguageSpace: LanguageSpacePreview?

LanguageSpaceRecoveryState
  idle
  restoring
  restored
  failed(messageKey)
```

状态机约束：

- `completeWelcome()` 必须基于恢复后的 `currentLanguageSpace` 判断 route；恢复未完成时不应允许进入 Main。
- `createLanguageSpace()` 需要改为 async 或触发异步任务；写入成功前不更新 phase 为 `.main`。
- 当前 Main 依赖 `LanguageSpacePreview` 的地方继续使用 projection，但 projection 的源必须来自 repository 返回的 `LanguageSpace`。
- `LangoTraceRootView` 的 `languageSpace ?? onboardingDraft.makeLanguageSpacePreview()` fallback 必须删除；缺少空间时 route 应回 onboarding 或错误状态。

### 11.5 iOS 页面设计

入口：

- iPhone `设置` 列表中保留“语言空间”选项。
- 点击“语言空间”进入 `LanguageSpaceManagementView`，不再只显示能力说明。
- 当前首页顶部的语言空间 chip 可继续显示 summary；是否直接进入管理页由实现阶段结合导航一致性决定，但设置页必须可达。

页面结构：

```text
NavigationStack
  List
    Section 当前空间
      当前空间 row：名称、语言方向、等级、当前标记
    Section 所有语言空间
      active space rows
        名称
        母语 -> 目标语言
        等级
        当前空间 checkmark
        swipe action: 删除
    Section 说明
      本地优先、删除影响、同名空间提示
  toolbar
    plus: 新增空间
```

页面状态：

- loading：首次进入管理页时读取 active 空间列表，显示系统 `ProgressView` 或与现有设计一致的加载行。
- loaded with current：显示当前空间 section 和全部 active 空间列表。
- loaded without current but has active spaces：显示列表，并提示“请选择一个语言空间”；这种状态只应出现在恢复修复前后短暂阶段。
- no active spaces：显示空状态和新增按钮；如果从删除最后一个空间进入，应允许用户立即创建新空间，不自动创建默认空间。
- storage error：显示本地存储错误、重试按钮和返回设置列表的导航能力。

新增 / 重命名：

- 使用 sheet 或 navigation destination。
- 字段：
  - 空间名称。
  - 母语。
  - 目标语言。
  - 当前水平。
- 若 `displayName` 与其他 active 空间重复，显示 inline warning：`已有同名空间，仍可继续保存。`
- 保存按钮在必填字段有效时启用。
- 重命名当前空间成功后，当前空间 chip、设置页列表和 Main 内容里的 display context 必须同步更新。
- 新增空间成功后默认设为当前空间。原因：用户在设置中主动新建学习空间，通常预期接下来进入该空间；如果后续希望“新增但不切换”，应单独设计二级选项。
- 触控目标不小于 44pt，支持 Dynamic Type。

删除：

- row swipe action 可以触发删除，但必须进入确认对话。
- 详情页或编辑页也可以提供 destructive 删除按钮。
- 确认文案必须说明：
  - 删除后该空间不会再出现在空间列表。
  - 当前版本没有恢复入口。
  - 如果这是当前空间，App 会切换到最近使用的其他空间；如果没有其他空间，会回到创建语言空间流程。
- 删除按钮使用 `.destructive`。

删除后的 UI 行为：

- 删除非当前空间：关闭确认对话，列表移除该空间，当前空间标记不变。
- 删除当前空间且存在 fallback：关闭确认对话，列表移除该空间，新的当前空间显示 checkmark；Main 相关上下文同步切换。
- 删除最后一个空间：关闭确认对话后进入 no active spaces 状态，并让 App 根路由回 onboarding 或无空间恢复路径。
- 删除失败：关闭 destructive 进程，保留原列表，显示可重试错误；不得先从 UI 乐观移除再无法恢复。

iOS HIG 约束：

- 顶层设置列表使用 `NavigationStack`。
- 主列表使用系统列表或与现有 `LangoTraceDesign` 一致的列表样式。
- 新增按钮放在 navigation bar trailing，使用 plus 图标。
- destructive action 必须二次确认。
- 所有按钮和 row action 保持 44pt 以上触控区域。
- 不使用 hamburger 菜单，不创建额外底部 tab。
- 支持 VoiceOver：当前空间 row 使用 selected 或等价辅助语义；删除按钮 accessibility label 必须包含空间名。
- 支持 Dynamic Type：空间名称、语言方向和等级文本可换行，不允许在小屏或大字号下遮挡删除/当前标记。
- 支持 Dark Mode：warning、destructive 和当前标记使用系统语义色或设计系统 token，不写死仅适合浅色模式的颜色。

iPad / macOS 短期边界：

- 本轮不开发完整 iPad / macOS 管理页，但 shared repository 和 `AppSessionState` 是三端共用能力。
- iPad / macOS 仍可展示 summary 或 unavailable 管理说明，但不能再声称语言空间没有真实持久化。
- 如果 iOS 删除最后一个空间导致 `currentLanguageSpace == nil`，iPad / macOS 同一 App 状态也必须遵守无空间路由保护。

### 11.6 文案与本地化

新增或更新 String Catalog key：

```text
settings.languageSpace.management.title
settings.languageSpace.management.currentSection
settings.languageSpace.management.allSection
settings.languageSpace.management.add
settings.languageSpace.management.rename
settings.languageSpace.management.delete
settings.languageSpace.management.currentBadge
settings.languageSpace.management.duplicateNameWarning
settings.languageSpace.management.deleteTitle
settings.languageSpace.management.deleteMessage
settings.languageSpace.management.deleteCurrentFallbackMessage
settings.languageSpace.management.noSpacesTitle
settings.languageSpace.management.noSpacesBody
settings.languageSpace.management.storageErrorTitle
settings.languageSpace.management.storageErrorBody
settings.languageSpace.management.retry
settings.languageSpace.management.selectSpacePrompt
settings.languageSpace.management.deleteLastSpaceMessage
```

新增 key 必须至少覆盖当前 String Catalog 支持的界面语言集合。若实现时发现 `project.yml` 的 `CFBundleLocalizations` 与 String Catalog 语言集合不一致，应按界面国际化规范同步处理。

### 11.7 测试策略

Core 测试：

- `LanguageSpace` 创建输入规范化。
- 同目标语言多空间允许。
- 同名空间检测不阻断模型。
- deleted 空间不应映射为 active 当前空间。

Data 测试：

- fresh database migration 成功。
- 数据库默认 URL 位于 Application Support 的 App 专属子目录。
- 测试注入临时数据库 URL 时不会写入真实 Application Support。
- iOS 文件保护属性设置路径有单元测试或平台条件源码测试覆盖。
- 创建两个目标语言相同的 active 空间成功。
- 创建两个 displayName 相同的 active 空间成功。
- `duplicateNameExists` 能检测同名并支持 excluding current ID。
- `duplicateNameExists` 基于规范化名称检测，例如首尾空白、连续空白和 Latin 大小写不影响提示。
- soft-deleted 同名空间不触发 duplicate warning。
- 选择当前空间后可恢复。
- 删除非当前空间不改变当前空间。
- 删除当前空间后 fallback 到最近使用的其他空间。
- 删除最后一个空间后 current 清空。
- soft-deleted 空间不出现在 active list。
- 创建、切换、重命名、删除使用事务；通过失败注入确认不会留下半写入状态。
- current 指向 missing 或 deleted 空间时，repository 能 fallback 并修复 `app_state`。
- 迁移失败不会删除或覆盖既有数据库，App 层可收到存储恢复错误。
- 写入失败路径可被测试替身覆盖。

UI 测试或源码级行为测试：

- iOS 设置页包含语言空间管理入口。
- 语言空间管理页包含新增、重命名、删除和当前空间标记。
- 同名输入显示 warning。
- 删除按钮使用 destructive confirmation。
- 删除最后一个空间显示明确文案并进入无 active 空间状态。
- 存储错误状态显示重试入口。
- Dynamic Type 和 VoiceOver 所需的 label / value / hint 在源码级测试中覆盖关键路径。
- 页面文案进入 String Catalog。

App 状态测试：

- 无空间时 Welcome 后进入 onboarding。
- 有当前空间时 Welcome 后进入 Main。
- 当前空间 ID 指向 deleted / missing 空间时 fallback。
- 创建空间保存失败时不进入 Main。
- 恢复未完成时 `completeWelcome()` 不进入 Main。
- 存储恢复失败时不进入 Main，并保留重试路径。
- 删除当前空间后 AppSessionState 同步切换到 fallback。
- 删除最后空间后 AppSessionState 清空当前空间并触发无空间路由保护。

## 12. 复查方法

- 代码复查：
  - 确认 `LanguageSpaceRepository` 不再为空协议。
  - 确认 `AppSessionState` 不再只依赖内存 preview。
  - 确认 `LangoTraceRootView` Main 分支不再用 onboarding draft 生成 fallback 空间。
  - 确认数据库 schema 没有对 `target_language_code` 或 `display_name` 加唯一约束。
  - 确认数据库实际路径来自 Application Support，测试可注入临时路径。
  - 确认主数据库不包含 API Key、Provider token、对象存储密钥或加密密钥。
  - 确认 `display_name_normalized` 或等价规范化逻辑存在，并且没有唯一约束。
  - 确认创建、切换、重命名、删除和 fallback 写入在事务中完成。
  - 确认删除为 soft delete，active list 默认排除 deleted 空间。
  - 确认迁移失败路径不会清空数据库或静默创建新库覆盖旧库。
- 产品复查：
  - 同一目标语言可创建多个空间。
  - 同名空间提示但不阻断。
  - 删除当前空间后 fallback 可解释。
  - 删除最后空间后不创建默认空间。
- iOS 交互复查：
  - 设置页路径清晰。
  - 新增、重命名、切换、删除符合 iOS 导航和确认习惯。
  - Dynamic Type 下关键文本不重叠。
  - destructive action 有二次确认。
  - 删除最后空间、存储错误和无 active 空间都有清晰状态。
  - VoiceOver 能读出当前空间、空间名称和删除目标。

## 13. 验证命令

开发中至少运行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

收尾运行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
scripts/verify.sh
git status --short
```

手动验证：

- iPhone 17 Simulator 首次启动，完成 onboarding 创建空间，进入 Main。
- 终止并重启 App，Welcome 后恢复当前空间。
- 设置 -> 语言空间 -> 新增一个同目标语言空间，切换成功。
- 新增或重命名为同名空间时显示提示，仍可保存。
- 删除非当前空间后当前空间不变。
- 删除当前空间后切换到最近使用的其他空间。
- 删除最后一个空间后回到 onboarding 或无空间恢复路径。
- 在 iOS Simulator 容器中确认主数据库位于 Application Support，而不是 Documents、Caches 或 tmp。
- 在大字号和深色模式下检查管理页、编辑页、删除确认文案不重叠。
- 用 VoiceOver 检查当前空间标记和删除按钮语义。

## 14. 文档影响检查

本任务命中以下文档审查触发条件：

- 数据层。
- 启动闭环。
- 语言空间闭环。
- 验证脚本可能变化。
- 包依赖和模块边界。
- App 启动结构变化。

预计需要更新：

- `docs/README.md`：更新已完成 / 未完成状态。
- `docs/architecture/001-initial-module-boundaries.md`：从空 repository 状态更新为 SQLite / GRDB 语言空间基础设施。
- `docs/spec/002-navigation-and-routing.md`：补充无空间、当前空间恢复、当前空间失效 fallback 和删除最后空间路由。
- `docs/spec/003-ui-design-system.md`：补充 iOS 语言空间管理页、destructive action 和同名提示规则。
- `docs/spec/004-swiftui-architecture.md`：补充 AppSessionState 与 repository 的边界。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：实现后补充首版 schema 事实。
- `docs/spec/009-testing-and-verification.md` 和 `docs/testing/README.md`：补充数据库与启动恢复验证。
- `docs/review/INDEX.md` 和新 review round：记录专项审查。

预计不需要更新 ADR：

- 本任务延续 SwiftUI Multiplatform、本地优先、语言空间核心模型和 SQLite / GRDB 候选决策，不改变核心 ADR。
- 后续同步扩展问题已单独记录在 `docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md`，当前任务不实现 Sync Engine 或 sync metadata。

## 15. 实施记录

尚未开始实现。

旧方案处理：

- 2026-05-20：删除旧 active 方案 `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md`。原因：旧方案基于单语言空间 UserDefaults 过渡，与用户确认的基础设施完整建设要求冲突。
- 2026-05-20：删除旧 active 方案 `docs/plans/active/2026-05-18-feature-language-space-lifecycle-and-deletion.md`。原因：该方案依赖已删除的单空间启动恢复方案，且“先添加和切换、不先实现删除”的实施顺序已被用户新要求取代；其多空间、切换、重命名、删除和 fallback 边界已合并进本方案。

方案完善记录：

- 2026-05-20：按系统架构复评补充 Apple 平台存储约束、Application Support 数据库位置、系统备份语义、iOS 文件保护、WAL/导出一致性、GRDB `DatabaseQueue` 优先策略、迁移失败处理、事务清单、规范化同名检测、启动恢复错误态、iOS 管理页状态和可访问性测试边界。
- 2026-05-20：新增 `docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md` 作为后续同步功能开发备忘录。当前任务只保持稳定 ID、软删除、Repository 边界和 `app_state` 分离，不提前实现完整 sync metadata。

## 16. 完成标准

- SQLite / GRDB 语言空间 schema、migration 和 repository 实现完成。
- 主数据库位于 Application Support，测试可注入临时路径，iOS 文件保护策略有实现记录。
- `LanguageSpaceRepository` 支持多空间、当前空间、重命名、删除和同名检测。
- 同名检测基于规范化名称，且不阻断保存。
- onboarding 创建第一个空间写入数据库并设为当前空间。
- App 冷启动能恢复当前空间。
- 存储恢复中和恢复失败状态可见，不静默降级为首次启动。
- iOS 设置页“语言空间”管理页支持新增、切换、重命名、删除。
- 同目标语言多空间和同名空间均被测试覆盖。
- 删除当前空间和删除最后空间的 fallback 被测试覆盖。
- 创建、切换、重命名、删除和 fallback 写入的事务边界被测试覆盖。
- `LanguageSpacePreview` 不作为数据库 schema。
- 相关文档和 review round 更新。
- `scripts/verify.sh` 通过，或失败项有明确环境原因和替代验证。

## 17. 剩余风险

- Entry、附件、导出、同步尚未落地，删除语言空间的级联影响只能先通过 soft delete 和边界接口预留，不能最终验证真实数据级联。
- iPad 和 macOS 管理页不在本轮完成，三端语言空间管理体验会短期不一致。
- 引入 GRDB 可能需要网络下载依赖或 XcodeGen / SwiftPM 配置调整，执行阶段需确认本地环境是否已有依赖缓存。
- 数据库损坏恢复第一版可能只提供错误边界和回 onboarding，完整备份恢复、导出恢复和修复工具需要后续任务。
- 首版不做自定义数据库加密；若后续把日记正文、照片、音频或 AI 请求日志纳入主数据库，需要重新评估文件保护、导出加密和本地威胁模型。
- 首版优先 `DatabaseQueue` 会牺牲部分并发读能力；Entry、FTS、向量化后台任务落地时需要复评是否升级 `DatabasePool`。
- 软删除在没有恢复 UI 时可能让数据库长期保留已删除空间记录；发布前需要结合导出、隐私删除和同步 tombstone 再定义清理策略。
- 同步扩展空间已通过架构备忘录记录，但当前任务不会验证多设备冲突、远端版本、device state 和 tombstone 传播；这些必须在未来同步任务中重新建模和测试。
