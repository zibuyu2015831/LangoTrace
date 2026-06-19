# 任务方案：设置真实状态投影（行值、AI / 同步状态与本地数据占用）（E12）

状态：Implemented（2026-06-18 批量 run；CI run `27752466241` Build & Test 全绿，已移入 done/）
自审核状态：Reviewed（2026-06-18 批量 run 实现前隔离子代理用当前 HEAD 复核漂移，结论见下）
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-18（批量 run 实现前漂移复核：AIProviderProfileStatus 6 例 / secret_presence 快照 / UIV-08 行号 / Core PrivacyStatus 枚举 / UI 不依赖 Sync / CapabilityStatusRow 无值槽 / 渲染禁用词）

## 批量 run 实现前漂移复核（2026-06-18）

```text
复核方式：隔离子代理只读核验当前 HEAD（E6/E7/E8/E9/LM01 已收口，E10 S1/E11 引擎切片在 active）。
核心决策/ADR 反转检查：无。决策 9（凭证只入 Keychain、不外发）+ 备忘录 §4（渲染零 Keychain/零网络）是硬边界，本方案遵守不反转。
确认漂移与修订（实现按此为准，覆盖正文旧假设）：
  [P0] sync 行真实值 = `syncService.isEnabled`（现恒 false → 「未启用」），如实投影非硬编码；SyncStatusProjection 已随 E11 真实通道一并 defer，E12 不依赖它（方案 §3「E11 后接 SyncStatusProjection」改为：E11 引擎切片下仍为 isEnabled 降级，真实通道落地后再接）。
  [P0] **LangoTraceUI 不依赖 LangoTraceSync** → footer/列表不能直读 SyncService，须 App 层把 isEnabled 桥接为 Core `SyncProviderStatus` 注入。
  [P0] 渲染禁用词：`ThreePlatformPresentationCopyTests` 禁可见英文 `unavailable`/`not connected` 等 + 扫 `settings.`/`capabilityStatus.` key 前缀与 UI 源码；`PremiumUIBehaviorTests` 禁 UI 源码任何汉字。→ 行值必须 en+zh-Hans 本地化 key，UI .swift 零中文，措辞避开禁用词（如「未启用」EN 用 "Off"/"Not set up" 而非 "unavailable/not connected"）。
  [P1] `AIProviderProfileStatus` 实为 6 例（含 `.draft`）；凭证存在性快照在 `ai_provider_credentials.secret_presence`（`AIProviderSecretPresence`：present/missing/inaccessible/unknown），写点 `markCredentialState`/`insert(_:credential)`（纯 Data 侧，非 Data/AI 接缝）；`GRDBAIProviderConfigurationRepository` 不 import Keychain，`loadDefaultProfile()`/`credential(from:)` 零 Keychain 可读 → 投影直接复用，结构性保证零 Keychain。
  [P1] migration 实为 v26，无新列需求（复用现列，**无 migration**）。
  [P1] Core `AIProviderStatus` 仅 4 例（notConfigured/configured/unavailable/error，在 `PrivacyStatus.swift` 非 footer 文件）→ 投影 `AIProviderListStatus`（notConfigured/configured/missingKey/partiallyAvailable）映射进 footer 4 例（missingKey→error 或 notConfigured，partiallyAvailable→configured，映射在 App/Core，记入测试）。
  [P1] UIV-08 行号漂移：PadMainSections 90–91、MacMainView 246–247、PadLearningPanelView 89–101；**MacWorkspaceContentView 无 AI/sync 行**（其 .unavailable 是真实能力事实，不改）。
  [P2] `CapabilityStatusRow`（LearningContentComponents.swift）无 trailing 值槽 → 加可选 value param；`settingsCapabilities` 是 `GRDBLearningContentRepositoryBridge` 静态数组（忽略 spaceID）。
  [P2] `LocalDataUsageService` 不存在；DB 路径 `LanguageSpaceDatabaseLocation`（+ -wal/-shm），MediaArtifacts root 在 App 层 `SentenceAudioPlaybackAssembly.defaultMediaArtifactsRoot()` → 须注入两路径。界面语言/外观偏好已由 `UserDefaultsInterfaceLanguageStore`/`UserDefaultsAppearancePreferenceStore` 持久化。
  设置渲染入口：iPhone `PhoneMainSections`，iPad/mac 共享 `LangoTraceSettingsSceneView`。
切片（均可完成、无 defer）：
  Slice A（Core + Data）：SettingsProjectionModels（AIProviderListStatus/SyncListStatus + 映射 + localizedValueKey）+ SettingsCapabilityProjection（AI 状态由 secret_presence + profile/endpoint 快照派生，零 Keychain）+ LocalDataUsageService（注入路径，后台 + 缓存）+ 测试。
  Slice B（UI + App）：CapabilityStatusRow 值槽 + 设置行值渲染 + UIV-08 接线移除硬编码 + footer 注入 + App 装配（含 sync isEnabled 桥接）+ 本地化 key（en+zh-Hans）+ UI 测试（含 ThreePlatformPresentationCopy / PremiumUIBehavior 本地跑）。
是否允许进入实现：是（批量 run §1 预授权；全部可实现到可验证边界，无 defer）。
```

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（[2026-06-11-chore-code-review-and-dev-plan-series.md](2026-06-11-chore-code-review-and-dev-plan-series.md)）。该授权仅覆盖"方案文档创建"；本方案进入实现前仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

## 1. 需求或 bug 描述

按新版设置原型（`prototypes/iphone/settings.html`、`prototypes/ipad/settings.html`、`prototypes/mac/settings.html`），设置主列表行尾以低干扰 muted 文字显示真实当前值：界面语言 / 外观显示 `跟随系统`（或具体值）、AI Provider 显示 `已配置`、同步显示 `未启用`、mac 本地数据行显示占用体积（原型示例 `1.2 GB`）。原型设计说明明确"主列表不带状态 badge……通过 / 失败等能力状态只出现在对应二级页里"。

同时按 [2026-05-24-settings-status-projection-notes.md](../../architecture/notes/2026-05-24-settings-status-projection-notes.md) 的约束：面向用户的状态必须来自用户可感知配置，不得来自开发完成度标记；设置主列表渲染路径不得读取 Keychain 明文或执行网络探测。

本任务还吸收今日代码审查发现 UIV-08：`PadMainSections` / `MacMainView` / `PadLearningPanelView` 把 `LanguageSpaceFooter` 的 `aiStatus: .notConfigured` / `syncStatus: .off` 与 `CapabilityStatusRow` 的 `.ready` 等状态硬编码在视图中，需要接真实投影（E0b 重构方案显式把该项延期到本任务）。

## 2. 现状描述

以下事实已对照当前代码（2026-06-11 HEAD）核实：

- `SettingsCapability`（`Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`）：`CapabilityStatus` 仅 `ready` / `mockOnly` / `unavailable` 三档，语义是开发阶段标注而不是用户配置状态；`Kind` 有 languageSpace / interfaceLanguage / appearance / aiProvider / sync / localData / privacy / importExport 八类；status 在构造时传入，UI 调用点硬编码。
- UIV-08 硬编码点（逐一核实）：
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`（约 79–88 行）：`LanguageSpaceFooter(languageSpace:, aiStatus: .notConfigured, syncStatus: .off, ...)`。
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`（约 201–202 行）：同样硬编码 `.notConfigured` / `.off`。
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift`（约 87–99 行）：`CapabilityStatusRow(status: .ready)`（aiProvider）与 `(status: .unavailable)`（sync）硬编码。
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`：多处 `CapabilityStatusRow` 硬编码（search / import / practice）。
  - `LanguageSpaceFooter.swift` 使用独立的 `AIProviderStatus` / `SyncProviderStatus` 枚举（非 `CapabilityStatus`）。
- AI 配置状态的非敏感事实源已存在：`ai_provider_profiles` / `ai_provider_endpoints`（v11 已加 endpoint validation summary 列）持久化于 SQLite；`AIProviderProfileStatus`（`Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`）已含 `configured` / `incomplete` / `credentialMissing` / `credentialInaccessible` / `validationFailed` 等档位。Keychain 凭证经 `KeychainAIProviderCredentialStore`（LangoTraceAI）访问。
- 本地数据体积统计目前不存在：仓库内仅 `ReadingLibraryStore.swift` 在导入 preflight 用 `URLResourceValues.fileSize` 校验单文件，没有数据库 / `MediaArtifacts` 目录聚合统计。
- 同步状态：E11 之前同步真实事实是"未启用、数据仅本机"，可直接如实投影；E11 落地后由其 `SyncStatusProjection` 提供。
- 渲染路径反例已被备忘录 §4 明确禁止：渲染时读 Keychain、发探测、把开发完成度写进用户文案。

## 3. 目标

1. 新增 `SettingsCapabilityProjection`：把"列表行当前值"（用户配置状态）与 `SettingsCapability.status`（开发阶段标注）解耦；主列表行尾值由 projection 驱动，开发完成度不再出现在用户可见字符串或可访问性标签。
2. AI Provider 行值：`已配置` / `缺密钥` / `未配置`（以及 `部分可用` 当多 endpoint 状态不一）——全部由 SQLite 中的 profile / endpoint 非敏感快照派生，渲染路径零 Keychain 读取、零网络探测；凭证存在性快照在保存 / 验证 / 删除凭证时落库更新。
3. 同步行值：E11 前固定真实值 `未启用`；E11 后接 `SyncStatusProjection`（`未启用` / `iCloud 已启用` / `冲突需处理` 等），实现按"先落地者如实降级"原则两个方向都成立。
4. 本地数据行值：`LocalDataUsageService` 异步统计数据库文件 + `MediaArtifacts` 目录体积，结果缓存并在进入设置时后台刷新，渲染永不同步阻塞；mac 设置显示如 `1.2 GB` 的格式化值，iPhone / iPad 进入本地数据二级页显示同一数据。
5. 界面语言 / 外观行值：从既有偏好真实读出（`跟随系统` 或具体值）。
6. 修复 UIV-08：`LanguageSpaceFooter` 与学习面板的 AI / 同步状态改由共享投影注入，移除全部硬编码状态实参。

## 4. 范围

- `Packages/LangoTraceData`：`SettingsCapabilityProjection` 模型与查询、AI 非敏感状态快照查询、`LocalDataUsageService`、凭证存在性快照落库点（保存 / 验证 / 删除路径）。
- `Packages/LangoTraceUI`：设置主列表行值渲染、`LanguageSpaceFooter` / `PadLearningPanelView` / `MacWorkspaceContentView` / `PadMainSections` / `MacMainView` 投影注入、本地数据页占用展示。
- `Packages/LangoTraceCore`：投影值对象（如 `AIProviderListStatus`）。
- `LangoTraceApp/AppEnvironment.swift`：装配。

## 5. 不做什么

- 不为隐藏角标扩展数据库 schema（备忘录 §4）；凭证存在性快照若需落库，复用既有 `ai_provider_profiles` / endpoint validation summary 列，确属必要的新列须回到本方案修订并经用户确认。
- 不在主列表渲染路径读取 Keychain、发起任何网络探测或 probe（备忘录 §4 硬边界）。
- 不实现"需重测 / 最近失败"的主动提醒推送；二级页内的验证结果展示沿用既有 `CapabilityStatusBadge` 体系不在本任务重做。
- 不把 `本地优先` 做成某行的状态字段（备忘录 §4：它属于产品与隐私边界叙事）。
- 不实现 E11 的同步引擎本身；同步行值只消费投影。
- 不重构 `SettingsCapability` 的二级页路由结构（E0b 范围）。

## 6. 证据与决策依据

- 原型证据：`prototypes/iphone/settings.html`（row-value：`跟随系统` / `已配置` / `未启用`；设计说明"主列表不带状态 badge"）、`prototypes/mac/settings.html`（set-value 同语义 + 本地数据 `1.2 GB` 行；"状态语义靠文案而非颜色"）、`prototypes/ipad/settings.html`（本地数据入口）。
- 审计发现与 work item 对照：

```text
来源：2026-06-11 主方案阶段 1 代码审查（docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md 实施记录）
发现 ID 或 trigger ID：UIV-08
严重度：P2（用户可见状态失真：AI 已配置时页脚仍显示未配置）
对应 work item：第 3 节目标 6（移除硬编码、接真实投影）
验证证据：PadMainSections.swift / MacMainView.swift / PadLearningPanelView.swift / MacWorkspaceContentView.swift 硬编码行已在第 2 节逐文件核实
```

- 备忘录采纳说明（[2026-05-24-settings-status-projection-notes.md](../../architecture/notes/2026-05-24-settings-status-projection-notes.md)，本方案即其"后续任务"）：
  - §3"是否新增 SettingsCapabilityProjection"：采纳，新增投影类型，三层拆开（列表当前值 / 详情状态 / 开发完成度）。
  - §3"AI Provider 列表状态读取非敏感 profile projection"：采纳（缺密钥 / 部分可用来自落库快照）。
  - §3"同步列表状态表达"：采纳词表，E11 前仅 `未启用` 真实成立。
  - §3"导入导出、本地数据、隐私是否需要真实可操作状态"：本地数据采纳真实占用值；导入导出与隐私保持说明型入口（行尾不显示状态值），与原型一致。
  - §3"macOS 是否需要更高密度 trailing value"：采纳，mac 行值含本地数据体积，iPhone 主列表不显示体积（原型一致）。
  - §4 全部禁止项采纳为硬边界。
- 前序依赖：AI 行值部分在 E6（`docs/plans/active/2026-06-11-09-feature-ai-request-preview-and-log-foundation.md`）之后实施更佳（E6 完善请求与验证元数据），但仅依赖既有落库快照时也可先行；同步部分在 E11 之后接真实投影，之前如实显示 `未启用`。E0b（[2026-06-11-02-refactor-ui-architecture-debt.md](2026-06-11-02-refactor-ui-architecture-debt.md)）显式把 UIV-08 接线延期至本任务，本方案为其收口点。
- workflow 引用：不涉及 migration / Provider / Prompt 新增；页面行为变化参照 [add-platform-screen.md](../../workflows/add-platform-screen.md) 的共享 seam 检查。无偏离。

```text
证据能证明什么：原型固定了行值词表与低干扰呈现；代码证明硬编码点与非敏感事实源均存在。
证据不能证明什么：原型 mock 值（已配置 / 1.2 GB）不代表真实状态可得性已验证；缺密钥快照的更新时机需要实现中以测试固定。
迁移前提：无 schema 迁移预期；若凭证存在性快照确需新列则回方案修订。
照搬风险：照搬 CapabilityStatus 三档去渲染主列表会把开发完成度泄漏给用户——这正是备忘录禁止的模式。
```

## 7. 约束映射与验证路径

### 约束 1：状态来自用户可感知配置，不来自开发完成度

- 来源：`docs/architecture/notes/2026-05-24-settings-status-projection-notes.md` §1、§4
- 适用范围：全部行值与页脚状态
- 严重度：blocker
- 执行或验证方式：单元测试（投影输入只含配置快照，不含 CapabilityStatus）+ 人工审查
- 验证提示：`SettingsCapabilityProjection` 构造不接受 `CapabilityStatus` 参数。

### 约束 2：渲染路径零 Keychain 读取、零网络探测

- 来源：同备忘录 §4
- 适用范围：主列表、页脚、学习面板渲染
- 严重度：blocker
- 执行或验证方式：单元测试（投影查询以纯 SQLite 读实现；测试替身断言 credential store 与 HTTP client 零调用）
- 验证提示：第 15 节先失败用例即覆盖此约束。

### 约束 3：敏感配置与非敏感快照分离

- 来源：`docs/README.md` 核心决策 9、`docs/spec/005-ai-provider-prompt-and-privacy.md`
- 适用范围：凭证存在性快照
- 严重度：blocker
- 执行或验证方式：单元测试（快照只含布尔 / 枚举级事实，不含密钥片段、account 名等可还原信息）

### 约束 4：界面文案语言边界

- 来源：`docs/spec/006-interface-localization-and-language-boundaries.md`
- 适用范围：行值字符串
- 严重度：warn
- 执行或验证方式：本地化 key 单元测试

### 约束 5：主线程渲染不被 IO 阻塞

- 来源：`docs/spec/004-swiftui-architecture.md`
- 适用范围：`LocalDataUsageService`
- 严重度：warn
- 执行或验证方式：单元测试（统计在后台执行、渲染读缓存值；无缓存时显示计算中占位）

## 8. 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/SettingsProjectionModels.swift`（新增）
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapabilityProjection.swift`（新增：投影查询）
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalDataUsageService.swift`（新增）
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`（status 用途收敛说明性调整）
- AI 配置保存 / 验证 / 删除路径（凭证存在性快照更新点，LangoTraceData / LangoTraceAI 接缝处）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceFooter.swift`、`PadMainSections.swift`、`MacMainView.swift`、`PadLearningPanelView.swift`、`MacWorkspaceContentView.swift`（投影注入、硬编码移除）
- iPhone 设置主列表与 mac 设置 scene 对应视图（行值渲染）
- `LangoTraceApp/AppEnvironment.swift`（装配）

## 9. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`（`AIProviderProfileStatus` 档位）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/KeychainAIProviderCredentialStore.swift`（只读参照，渲染路径必须避开）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift` 与 E11 的 `SyncStatusProjection`（同步行值消费点）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/CapabilityStatusBadge.swift`（二级页继续使用，主列表退场）

## 10. 涉及的文档路径

- 本方案。
- `docs/platform-page-inventory.md`（设置主列表与页脚状态事实更新）
- `docs/architecture/notes/2026-05-24-settings-status-projection-notes.md`（只读；采纳处理记录在本方案第 6 节）
- 前序依赖方案：`docs/plans/active/2026-06-11-09-feature-ai-request-preview-and-log-foundation.md`（E6，AI 部分推荐其后）、[2026-06-11-14-feature-sync-engine-icloud-foundation.md](2026-06-11-14-feature-sync-engine-icloud-foundation.md)（E11，同步部分其后）、[2026-06-11-02-refactor-ui-architecture-debt.md](2026-06-11-02-refactor-ui-architecture-debt.md)（E0b，UIV-08 延期来源）

## 11. bug 分析

非 bug 任务，不适用（UIV-08 为状态失真型审查发现，根因与修复路径已在第 2、3 节覆盖，无独立复现链路需要记录）。

## 12. 实施方案

1. Core / Data 投影（先失败测试）：定义 `AIProviderListStatus`（`notConfigured` / `configured` / `missingKey` / `partiallyAvailable`）、`SyncListStatus`、`AppearanceValue` 等值对象；`SettingsCapabilityProjection` 查询从 SQLite 非敏感快照派生（profile 存在且凭证快照在 → `configured`；profile 在而凭证快照缺 → `missingKey`；多 endpoint 状态不一 → `partiallyAvailable`）。测试以替身断言零 Keychain / 零网络调用。
2. 凭证存在性快照：在保存凭证、验证成功 / 失败、删除凭证的既有写路径同步落库更新（优先复用 `ai_provider_profiles` 状态列与 v11 endpoint validation summary，不加新列）；补齐"Keychain 内容被系统级删除导致快照失真"的修正点——二级页打开时校正快照（二级页允许受控 Keychain presence 检查，主列表不允许）。
3. `LocalDataUsageService`：后台枚举 Application Support 数据库文件（含 WAL / SHM 同名族）与 `MediaArtifacts` 目录 `totalFileAllocatedSize`，结果缓存（内存 + 时间戳），进入设置触发刷新；格式化用 `ByteCountFormatter` 风格 API。
4. UI 接线：
   - 设置主列表行尾值改投影驱动（`跟随系统` / `已配置` / `缺密钥` / `未启用` / 体积值），移除主列表 badge 语义。
   - `LanguageSpaceFooter` 的 `AIProviderStatus` / `SyncProviderStatus` 由投影映射注入，删除 `PadMainSections` / `MacMainView` 的硬编码实参。
   - `PadLearningPanelView` / `MacWorkspaceContentView` 的 `CapabilityStatusRow` 硬编码：AI / 同步行改投影；search / import 等真实未实现项保留 `unavailable`（这是真实能力事实，非开发进度泄漏，文案按用户语义复核）。
5. 降级路径：E11 未落地时同步投影常量 `未启用`（真实事实）；E6 未落地不阻塞（仅缺更细验证元数据）。
6. 文档同步与验证收口。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：同系列说明——方案撰写会话内无法对未落盘草稿做隔离审查，按协议第 3 节降级为主会话双轮自审核。
发现摘要：
  第一轮（架构）：
  - P1：初稿"缺密钥"判定方案为渲染时查 Keychain presence，直接违反备忘录 §4 → 改为写路径落库快照 + 二级页受控校正（12.2 步）。
  - P1：Keychain 被外部清除（如重装、iCloud Keychain 变化）后快照失真的修正点缺失 → 补充二级页打开校正。
  - P2：LanguageSpaceFooter 枚举与 CapabilityStatus 双体系易混 → 决策保留 footer 专用枚举、由投影映射，不强行统一类型（footer 语义更窄）。
  - P2：数据库体积统计漏 WAL / SHM 文件会显著低估 → 12.3 步显式覆盖同名族。
  第二轮（测试 / 安全 / 落地）：
  - P1：零 Keychain / 零网络约束若无测试就只是口头承诺 → 先失败用例直接以替身断言调用次数为 0。
  - P2：体积统计在大目录上的耗时无界 → 后台执行 + 缓存 + 计算中占位，测试覆盖"无缓存首帧不阻塞"。
  - P2：partiallyAvailable 的判定口径（任一 endpoint 失败即部分可用？）需要固定 → 固定为"存在 succeeded 与 failed/credentialMissing 并存"，写入测试。
写回修改：以上均已写回第 3、5、7、12 节。
仍需用户确认的问题：
  1. 行值词表最终中文文案（已配置 / 缺密钥 / 未配置 / 部分可用 / 未启用）是否符合预期。
  2. 二级页打开时的受控 Keychain presence 校正是否接受（主列表仍零读取）。
是否允许进入实现：待用户确认后允许。
```

## 14. 复查方法

- 代码：投影测试（含零 Keychain / 零网络断言）、usage service 测试、footer 接线测试全绿；`rg "aiStatus: \.notConfigured|syncStatus: \.off" Packages/LangoTraceUI/Sources` 无硬编码残留。
- 行为：配置一个 AI Provider 并保存后，设置主列表与 iPad / mac 页脚立即显示已配置；删除 Keychain 凭证（经 App 内删除路径）后显示缺密钥；本地数据行显示非零体积且进入设置无卡顿；同步行在 E11 前显示未启用。
- 故障路径：数据库不可读时行值显示稳定回退（不崩溃、不显示开发期词汇）；体积统计目录缺失返回 0 而非错误；快照失真经二级页校正闭环。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Settings/SettingsCapabilityProjectionTests.swift（新增）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Settings/LocalDataUsageServiceTests.swift（新增）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Settings/LanguageSpaceFooterProjectionTests.swift（新增：UIV-08 回归）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Settings/SettingsRowValueLocalizationTests.swift（新增）
先失败用例：SettingsCapabilityProjectionTests.aiProjectionReportsMissingKeyWithoutKeychainAccess —— 预期失败原因：SettingsCapabilityProjection 尚不存在，编译失败；该用例同时断言 credential store 替身调用次数为 0。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceData --filter Settings
  swift test --package-path Packages/LangoTraceUI --filter Settings
不新增单元测试的原因（如适用）：不适用。
```

## 16. 验证命令

```bash
# 聚焦
swift test --package-path Packages/LangoTraceData --filter Settings
swift test --package-path Packages/LangoTraceUI --filter Settings

# 受影响 package 完整
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
```

## 17. 文档影响检查

- `docs/platform-page-inventory.md`：设置主列表、iPad / mac 页脚状态从硬编码 mock 更新为真实投影（实施后）。
- `docs/architecture/notes/2026-05-24-settings-status-projection-notes.md`：本方案即其落地方案，采纳记录在第 6 节；备忘录原文保留。
- `docs/spec/005`：若凭证存在性快照口径影响隐私叙事（仅布尔级事实落库）补充一行事实说明（实施后评估）。
- ADR：不需要；无核心决策变化。
- review：设置状态属于用户可见行为变化，实施后做日常文档影响检查即可，不命中专项审查触发条件（无 schema / 权限 / 同步变化；若实施中确需新列则升级处理）。

## 18. 实施记录

2026-06-18（批量 run，两切片）：feature/e12-settings-projection。
  - **Slice A（Core + Data）**：Core `SettingsProjectionModels`——`AIProviderListStatus`（notConfigured/configured/missingKey/partiallyAvailable，纯函数 `make(from: AIProviderConfigurationProfile?)` 从非敏感快照派生 + `footerStatus` 映射进 4 例 footer 枚举 + `localizedValueKey`）、`SyncListStatus`（从 `isEnabled` 派生）、`LocalDataUsage`、`SettingsStatusProjection`。Data `SettingsCapabilityProjectionService`（仅依赖 `AIProviderConfigurationRepository`，**编译期零 Keychain**——不引用 credential store）+ `LocalDataUsageService`（DB + -wal/-shm + MediaArtifacts 体积，缺路径计 0）。测试：Core 派生（含 footer 映射 + 红线结构）、Data 经真实 GRDB repo（configured/missingKey/empty）+ usage service 临时目录。
  - **Slice B（UI + App）**：`LearningContentStore` 新增 `@Published settingsStatus` + 注入 `loadSettingsStatus` 闭包 + `refreshSettingsStatus()`（后台计算，渲染读缓存）。App `AppEnvironment.loadSettingsStatus` 由 config repo + `syncService.isEnabled`（DisabledSyncService→未启用）+ usage service 装配；经 `LangoTraceRootView`→`PlatformMainView`→store，以及 macOS Settings scene 的 `@State` + `.task` 注入。`CapabilityStatusRow` 加 trailing 值槽（builder `.trailingValue(_:)`，零改既有 init）。设置主列表（iPhone `SettingsView`、iPad/mac `LangoTraceSettingsSceneView`）行尾显示真实值（界面语言/外观/AI/同步/本地数据体积）；**UIV-08** 修复——`PadMainSections`/`MacMainView` footer 与 `PadLearningPanelView` AI/sync 行改投影驱动，移除 `.notConfigured`/`.off`/`.ready`/`.unavailable` 硬编码。新增本地化 key（en+zh-Hans，措辞避开禁用词）。测试：UI 行值解析/投影→能力色调映射/UIV-08 源码回归 + Core/Data 切片测试；本地 `ThreePlatformPresentationCopy`/`PremiumUIBehavior` 守卫全绿（UI 515 / Core 233 / Data 236 本地通过）。
  - 漂移修正（对照实现前复核）：`AIProviderProfileStatus` 6 例（含 `.draft`，draft→notConfigured）；凭证存在性来自 `ai_provider_credentials.secret_presence`（非 endpoint summary），渲染零 Keychain 由「投影只依赖 SQLite repo」结构性保证；无 migration（复用现列）；`AIProviderStatus`/`SyncProviderStatus` 在 Core `PrivacyStatus.swift`，投影经 `footerStatus` 映射；UI 不依赖 Sync，sync 值由 App 桥接 `isEnabled`。
  - CI：合并 dev `merge(E12): ... [ci]`（commit `46df14a`），首跑 iOS build 失败（`SentenceAudioPlaybackAssembly.defaultMediaArtifactsRoot()` 抛错未 `try`）；修复（commit `f261f67`：在非逃逸初始化闭包内 `try?` 解析 DB URL + media root，usage service 成 `let` 供 @Sendable 闭包安全捕获）后 **CI run `27752466241` Build & Test 全绿**（三端构建 + macOS app 测试 + lint + docs）。

## 完成状态（批量 run）

第 3 节目标 1–6 全部落地（投影解耦、AI 行值、sync 行值、本地数据体积、界面/外观行值、UIV-08 硬编码清零）并有代码 + 测试 + CI 证据；本地化 key（en+zh-Hans）通过 `ThreePlatformPresentationCopy`/`PremiumUIBehaviorTests` 守卫；CI run `27752466241` 三端构建 + macOS 测试全绿。属**可完成且已完成**，移入 `docs/plans/done/`。sync 行值在 E11 真实通道落地后接 `SyncStatusProjection` 的二次接线为 deferred 入口（当前 `isEnabled` 降级如实成立，已在剩余风险记录）。

## 19. 完成标准

1. 第 3 节目标 1–6 全部有代码与测试证据；UIV-08 有回归测试且硬编码清零。
2. 聚焦与受影响 package 测试全绿。
3. 页面清单文档同步完成。
4. plan-vs-shipped 对账完成；同步行值在 E11 后的二次接线若延后，记录 deferred 入口。

## 20. 剩余风险

- 凭证存在性快照与 Keychain 真实状态存在窗口期失真（外部删除场景），由二级页校正兜底；主列表短暂显示过期值是接受的取舍。
- 本地数据体积为近似值（文件系统分配粒度、统计瞬时性），不承诺与系统储存设置完全一致。
- 同步行值的最终词表依赖 E11 状态机定稿；E11 范围调整时本任务投影词表需复核。
- Linux 环境无法人工验证三端渲染与无卡顿体感，需 macOS 补验。
