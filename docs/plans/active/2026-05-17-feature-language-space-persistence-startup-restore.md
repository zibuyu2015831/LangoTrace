# 任务方案：语言空间持久化与启动恢复最小闭环

类型：feature

状态：Draft

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/testing/README.md`
- `docs/review/README.md`
- `docs/review/INDEX.md`
- 旧 `docs/superpowers/plans/2026-05-17-language-space-persistence-startup-restore.md` 已并入本方案；`docs/superpowers/` 已退出当前文档体系。

关联 ADR：

- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 未提交

## 1. 背景

当前项目已经完成 Welcome / Onboarding / Main 启动路由、语言空间 preview、三端主体页面、Mock 学习内容、设置二级说明页和本地 mock 练习会话。但是首次启动创建的语言空间仍只存在于 `AppSessionState.currentLanguageSpace` 内存状态中。

这导致一个关键产品闭环没有成立：用户完成首次引导后进入主界面，但 App 重启后无法恢复已创建语言空间，仍会回到 onboarding 路径。按照 `docs/README.md` 当前优先级，下一步应先完成“首次启动引导与语言空间的最小闭环”，再推进本地记录闭环和 SQLite / GRDB。

## 2. 目标

本次目标是建立最小、可测试、可替换的语言空间本地持久化与启动恢复路径：

- 用户完成 onboarding 创建第一个语言空间时，将明确的持久化快照保存到本地，而不是直接保存 UI preview。
- App 启动时读取已保存语言空间；如果存在有效空间，Welcome 完成后进入 Main。
- 如果没有保存空间或保存数据无法解码，Welcome 完成后仍进入 onboarding。
- 如果保存失败，不进入 Main，继续停留在 onboarding 并暴露本地错误状态，避免用户误以为语言空间已经建立。
- 保持当前本地优先和无外部请求边界，不接入账号、同步、Keychain、SQLite / GRDB 或迁移系统。
- 用 repository protocol 隔离临时持久化实现，为后续 SQLite / GRDB 替换保留边界。

## 3. 范围

本次会处理：

- 增加 `StoredLanguageSpace` 持久化快照模型，包含 schema version、语言 code、水平、创建时间和临时空间 ID。
- 扩展 `LanguageSpaceRepository` 协议，让它能够读取、保存和清除当前语言空间。
- 在 `LangoTraceData` 增加内存 repository 测试替身和 UserDefaults-backed 临时 repository。
- 改造 `AppEnvironment.bootstrap()`，让 App 使用本地 repository。
- 改造 `AppSessionState` 初始化和 `createLanguageSpace()`，接入启动读取、创建保存和保存失败状态。
- 收紧 `LangoTraceRootView` 的 Main 渲染边界，避免在缺少语言空间时用 onboarding draft 生成 fallback preview。
- 增加 Data / Core / App 或可测试 coordinator 单元测试，覆盖保存、恢复、损坏数据回退、版本不兼容、语义无效数据、保存失败和路由保护。
- 更新测试文档、SwiftUI 架构规范和导航规范。
- 因命中“首次启动闭环 / 语言空间闭环 / App 启动结构变化”，执行时建立一次文档专项审查记录。

## 4. 不做什么

本次不处理：

- 不引入 SQLite / GRDB schema、迁移、FTS、附件存储或导出。
- 不实现多个语言空间列表、切换、删除、重命名或排序。
- 不同步语言空间，不接入 CloudKit、WebDAV、S3、R2 或 iCloud Drive。
- 不接入账号系统、StoreKit、真实 AI Provider、TTS、Speech、OCR 或权限申请。
- 不为当前临时 UserDefaults 数据设计正式迁移；后续 SQLite / GRDB 接入时可以按早期开发原则重写。
- 不改变语言空间的产品定义：一个 Space 仍对应一门目标语言。
- 不把 `LanguageSpacePreview` 作为长期存储 schema；它仍是 UI 展示投影。

## 5. 分析

### 5.1 当前代码状态

- `LangoTraceApp/AppEnvironment.swift` 已有 `languageSpaceRepository: any LanguageSpaceRepository`，但 `LanguageSpaceRepository` 目前为空协议，默认实现是 `EmptyLanguageSpaceRepository()`。
- `AppSessionState` 当前在内存中持有 `currentLanguageSpace`，`completeWelcome()` 只根据该内存值决定进入 onboarding 或 main。
- `createLanguageSpace()` 当前只调用 `onboardingDraft.makeLanguageSpacePreview()` 并写入内存，不做本地保存。
- `LaunchRoute.route(hasLanguageSpace:)` 已有路由保护测试，可以继续作为启动恢复后的路由判断基础。
- `LanguageSpacePreview.id` 已使用稳定语言 code，例如 `en`，适合先作为临时持久化主键。
- `LangoTraceRootView` 当前在 `.main` 分支使用 `languageSpace ?? onboardingDraft.makeLanguageSpacePreview()` 作为兜底。虽然 `effectivePhase` 已有路由保护，但这个 fallback 会掩盖 Main 缺少语言空间的错误语义，本次应收紧。

### 5.2 产品影响

完成后，首次启动路径会从“可展示的内存 Demo”提升为“可重启恢复的最小产品闭环”。这不会让本地记录、AI、同步或设置能力变为真实可用，但会让用户的第一个学习空间成为后续记录和学习内容的稳定上下文。

语言空间保存的数据属于用户学习画像，包含母语、目标语言和水平。当前阶段允许保存在 App 本地 UserDefaults 中并随系统备份走设备级备份路径，但不得包含生活记录正文、照片、音频、API Key、AI 请求日志或同步配置。

### 5.3 技术取舍

本阶段推荐使用 UserDefaults-backed repository，而不是直接引入 SQLite / GRDB：

- 优点：实现面小，适合只保存一个当前语言空间；可以快速验证启动路由、状态注入和测试结构。
- 缺点：不是长期主存储，不能承载记录、附件、FTS、导出和同步。
- 边界：所有调用都通过 `LanguageSpaceRepository`，后续 SQLite / GRDB 可以替换 repository 实现，而不是让 App 层依赖 UserDefaults。

但不能直接持久化 `LanguageSpacePreview`。`LanguageSpacePreview` 是 UI preview / projection，字段会随界面、本地化和展示策略变化。持久化层应保存 `StoredLanguageSpace`：

- `schemaVersion`：当前为 `1`，用于识别不兼容数据。
- `id`：当前单空间阶段可等于目标语言 code，例如 `en`；文档明确它不是长期多空间主键。
- `nativeLanguageCode`：例如 `zh-Hans`。
- `targetLanguageCode`：例如 `en`。
- `level`：保存 `LanguageLevel`。
- `createdAt`：用于后续正式空间模型和调试审计。

恢复时必须先校验 schema version 和语义有效性，再映射成 `LanguageSpacePreview`。如果数据可解码但语义无效，例如目标语言不在支持列表、母语等于目标语言、`id` 与目标语言不一致或版本不支持，应返回 nil 并回到 onboarding。

### 5.4 文档审查影响

本次命中 `docs/README.md` 第 4 节第 17 条中的默认触发条件：

- 首次启动闭环。
- 语言空间闭环。
- App 启动结构变化。

因此执行时应新增 `docs/review/rounds/2026-05-17-language-space-startup-restore.md`，并更新 `docs/review/INDEX.md`。如果实现阶段发现只改纯模型而未触发启动结构变化，也应在任务方案中说明审查范围，而不是省略记录。

## 6. 方案

采用四层小步方案：

1. Core 层新增或承载 `StoredLanguageSpace` 与映射规则，继续保持 `LaunchRoute` 纯函数路由判断。
2. Data 层扩展 `LanguageSpaceRepository`，新增 `InMemoryLanguageSpaceRepository` 和 `UserDefaultsLanguageSpaceRepository`，并让保存接口显式抛错。
3. App 层让 `AppSessionState` 从 repository 初始化当前语言空间；创建语言空间时先保存，保存成功后才进入 Main。
4. UI 根视图收紧 Main 缺语言空间时的 fallback，避免自动生成 preview 掩盖状态错误。
5. 文档层更新当前状态、规范和测试清单，并建立一次专项审查记录。

执行顺序应遵守 TDD：先补 package 测试，再实现 Core / Data，最后接入 App 和文档。

## 7. 风险与边界

- 风险：UserDefaults 临时数据可能被误认为长期数据库。
  - 边界：文档和代码命名必须明确这是启动恢复用的轻量 repository，不是记录主存储。
- 风险：保存数据损坏导致启动异常。
  - 缓解：repository 解码失败时返回 nil，路由回 onboarding；不 crash，不创建默认空间。
- 风险：数据可解码但语义无效，例如不支持的语言 code 或同语种空间。
  - 缓解：恢复时执行语义校验；无效数据返回 nil 并回到 onboarding。
- 风险：未来 UI preview 字段变化破坏本地数据。
  - 缓解：持久化 `StoredLanguageSpace`，不持久化 `LanguageSpacePreview`。
- 风险：AppSessionState 接入 repository 后难以测试。
  - 缓解：为 `AppSessionState` 或抽出的 session coordinator 增加测试，覆盖启动恢复、创建保存和保存失败。
- 风险：保存失败后用户误以为已创建空间。
  - 缓解：`saveCurrentLanguageSpace` 使用 `throws`；保存失败时不进入 Main，保留 onboarding，并记录 `sessionErrorMessage`。
- 风险：多端 target 使用同一 App 源码，UserDefaults suite 和 key 设计不当会影响 iOS / macOS 调试。
  - 缓解：repository 默认使用 `.standard` 和明确 key；测试使用 isolated suiteName。
- 风险：语言空间恢复后 seed 内容是否属于当前空间。
  - 缓解：现有主界面已经按 `spaceID` seed；本次只保证恢复后的 `languageSpace.id` 稳定传入。
- 风险：`id = targetLanguageCode` 被误读为长期空间主键。
  - 缓解：文档明确这是单空间 MVP 临时 ID；多空间阶段必须引入真正唯一 ID。

## 8. 测试与验证

开发中：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
```

收尾：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
scripts/verify.sh
git status --short
```

建议手动验证：

- iPhone 17 Simulator 首次启动，完成 onboarding 创建英语空间，进入 Main。
- 终止并重启 App，点击 Welcome 后直接进入 Main，显示同一个语言空间。
- 清空 App 数据后重新启动，点击 Welcome 后进入 onboarding。
- iPad Pro 13-inch Simulator 和 macOS Debug App 至少完成构建验证；如时间允许，抽样验证恢复后的语言空间 footer / 主界面上下文。

## 9. 文档影响检查

预计需要更新：

- `docs/README.md`：将“内存语言空间 preview”与“首个语言空间轻量本地启动恢复”的状态拆清楚；实现完成后保留“正式语言空间数据模型、SQLite / GRDB Repository、迁移和多空间管理未完成”。
- `docs/spec/002-navigation-and-routing.md`：补充启动恢复路由规则。
- `docs/spec/004-swiftui-architecture.md`：补充 AppSessionState 只能通过 repository 恢复和保存语言空间，Main 不得自行从 onboarding draft 生成 fallback 空间。
- `docs/testing/README.md`：补充重启恢复手动验证。
- `docs/review/INDEX.md` 和 `docs/review/rounds/2026-05-17-language-space-startup-restore.md`：记录专项审查。
- 本任务方案：实现后记录实际改动、验证命令和剩余风险。

预计不需要更新：

- ADR：本次不改变语言空间模型、本地优先原则或长期 SQLite / GRDB 候选，只实现已确认方向的最小闭环。
- `docs/release/`：本次不涉及 StoreKit、TestFlight、隐私标签或发布材料。

## 10. 用户确认记录

状态为 `Draft`，不能开始实现。

2026-05-17：用户调整优先级，要求先完成 iPad 和 macOS 页面闭环，再进行设计优化，待整体页面设计完成后再进入功能开发和细节优化。本草案暂时搁置，后续恢复前需要重新复查页面闭环后的代码和文档状态。

2026-05-18：复查 `docs/archive/superpowers/plans/` 后确认，本方案仍对应当前 `docs/README.md` 中“真实语言空间持久化和启动恢复”的优先级，已作为唯一活跃方案保留在 `docs/plans/active/`。归档目录中的旧英文执行计划副本已移除，避免后续误读为另一个可执行入口。开始实现前仍需要用户重新确认。

如后续恢复本方案，需要重新确认后记录：

```text
2026-05-17：用户确认本方案，可以开始实现。
```

## 11. 实施记录

尚未开始实现。

## 12. 验证结果

尚未执行实现验证。草案创建后需要执行文档基础检查，确认新增文档没有占位词、格式问题或未跟踪文件遗漏。
