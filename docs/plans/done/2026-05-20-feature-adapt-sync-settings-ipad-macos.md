# 任务方案：同步设置 UI 适配 iPad 与 macOS

状态：Verified
类型：feature
创建日期：2026-05-20
最后更新日期：2026-05-20

## 1. 背景与目标

iOS 端同步设置页已经通过测试，当前实现以 `SyncSettingsView`、`SyncSettingsModels` 和 `SyncS3DraftView` 为核心，展示 iCloud 推荐路径、S3 兼容对象存储高级草稿、同步范围、附件开关和密钥边界。该实现是 Local Mock UI，不写 Keychain、不写数据库、不发 CloudKit / S3 / R2 / WebDAV 请求，也不上传任何内容。

下一步需要按照 iOS 端已经验证的产品设计，适配 iPad 端和 macOS 端。适配目标不是重新设计同步策略，而是把同一套同步信息架构放进 iPad 工作台与 macOS 桌面工作台 / 原生 Settings scene 中，使其符合各平台的导航、布局、窗口和输入习惯。

本方案只制定 UI 与工程实施计划。真实 Sync Engine、CloudKit Adapter、S3 Adapter、Keychain 写入、数据库 schema、冲突处理和同步副作用不进入本阶段。

## 2. 当前事实

### 2.1 已落地代码

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`
  - 当前是三端可编译的共享 SwiftUI View。
  - 内容为单列 stack：状态卡、同步方式、同步范围、mock 边界、未来选项。
  - iCloud 和 S3 草稿通过 `.sheet` 打开。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsModels.swift`
  - iCloud 为推荐，S3-compatible 为高级。
  - 生活记录、学习材料和进度、Prompt Preset、AI 生成内容固定纳入。
  - 照片附件、音频附件是本地 UI 草稿开关，默认关闭。
  - 向量索引本地重建，凭证和密钥仅本机。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncS3DraftView.swift`
  - 当前是单列表单草稿，包含 Provider、endpoint、region、bucket、path prefix、access key、secret key、HTTPS、path-style access。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
  - `.sync` 已路由到 `SyncSettingsView(languageSpace:)`。
  - iPad 和 macOS 目前主要靠最大宽度限制阅读栏。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
  - iPad 设置详情在工作台中央主区展示。
  - 左侧 timeline / pages 和右侧 learning panel 仍可能同时存在。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
  - macOS 工作台 Settings section 可进入 `.settings(.sync)`。
  - `MacMainView.main` 外层已有 `ScrollView`，而 `SettingsCapabilityDetailView` 内部也有 `ScrollView`，同步设置详情在 Mac 工作台存在嵌套滚动风险。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
  - macOS 原生 Settings scene 当前只是只读能力列表，row 无 action，不打开同步详情。

### 2.2 已落地文档

- `docs/plans/done/2026-05-19-research-ios-sync-strategy-and-settings-ui.md`
  - 已确定 Apple-only 阶段默认推荐 iCloud / CloudKit，S3-compatible 对象存储作为高级选项。
  - 已明确 S3 不作为普通用户第一眼默认路径。
  - 已明确密钥默认不同步，向量索引本地重建，附件默认关闭。
- `docs/platform-page-inventory.md`
  - 已记录 iPhone 同步设置页为 Local Mock。
  - 已记录 iPad / macOS 设置详情复用 `SettingsCapabilityDetailView`。
  - 已记录 macOS 原生 Settings scene 当前为只读列表。

## 3. 设计原则

1. 同步策略和数据边界保持三端一致。
   - 不为 iPad / macOS 增加新的同步范围、默认选项或密钥承诺。
   - iOS 端已验证的“iCloud 推荐、S3 高级、附件默认关闭、密钥仅本机、向量本地重建”保持为唯一产品结论。

2. 共享模型，平台化承载。
   - `SyncSettingsDraft`、`SyncMethodOption`、`SyncScopeItem` 和 S3 draft validation 不分叉。
   - iPad / macOS 只在布局、导航、presentation、窗口尺寸和滚动容器上做平台适配。
   - 跨平台布局判定以“可用内容宽度”为主；iPad 可额外参考 horizontal size class，macOS 不应依赖 size class 存在。

3. iPad 不能是放大的 iPhone。
   - 常规宽度下应利用横向空间组织内容。
   - Split View、Slide Over 和 Stage Manager 窄宽度下回退为 iPhone 同款单列。
   - 设置详情属于低频配置，不应继续被右侧学习面板挤压成窄栏。

4. macOS 不能只是移动页嵌在窗口里。
   - 工作台 Settings section 和系统 `Settings` scene 需要语义一致。
   - Mac 端需要避免嵌套滚动、过窄表单和只有触摸式交互的控件表现。
   - 原生 Settings scene 应承担偏好入口职责；在已有语言空间时可以进入同步详情，在无语言空间时保持只读边界。

5. 本阶段保持无真实同步副作用。
   - UI 可以真实级，但所有按钮仍是预览、草稿或关闭。
   - 任何实现不得引入 `URLSession`、`CKContainer`、`CKDatabase`、`SecItem`、`KeychainAccess`、`AWSSDK`、`S3Signer` 或 WebDAV 客户端调用。

## 4. 方案取舍

### 4.1 方案 A：仅复用当前单列页面

做法：

- 不新增平台布局，只继续在 iPad / Mac 设置详情中展示当前 `SyncSettingsView`。
- 通过现有 `frame(maxWidth:)` 控制阅读宽度。

优点：

- 改动最小。
- 风险低。

问题：

- iPad 大屏空间利用不足，仍像 iPhone 页面放大。
- Mac 工作台嵌套滚动风险不解决。
- macOS 原生 Settings scene 仍然无法进入同步详情。

结论：不采用。它能复用代码，但不满足“适配 iPad 端和 Mac 端”的产品要求。

### 4.2 方案 B：共享同步组件 + 平台自适应布局

做法：

- 保留 `SyncSettingsDraft` 和现有同步语义。
- 为 `SyncSettingsView` 增加平台自适应布局：
  - 窄宽度：沿用 iPhone 单列。
  - 常规宽度：状态区保持顶部，方法卡可并排，范围与边界说明形成两栏。
- 为 S3 草稿页设置大屏合理宽度，iPad / macOS 上保持表单专注，不铺满窗口。
- iPad 同步设置详情进入设置焦点形态，默认收起右侧学习面板，保留用户再次打开面板的能力。
- macOS 工作台修正设置详情嵌套滚动；原生 Settings scene 增加可进入详情的设置列表。

优点：

- 同一套同步产品设计跨三端一致。
- iPad / macOS 有平台原生感。
- 改动集中在 UI 承载层，仍不触碰真实同步能力。
- 后续真实 Sync Engine 接入时不需要重写三套设置语义。

风险：

- 需要小幅重构设置详情容器，避免重复 `ScrollView`。
- 需要补充单元测试和源码边界测试，防止真实同步副作用被提前引入。

结论：采用。它是当前阶段最平衡、最可维护的实现路径。

### 4.3 方案 C：iPad / macOS 分别写专属同步设置页

做法：

- 为 iPad 和 macOS 分别创建独立 `PadSyncSettingsView`、`MacSyncSettingsView`。

优点：

- 平台视觉控制最强。

问题：

- 同步策略、范围、密钥边界、S3 草稿表单会复制三份。
- 后续真实同步接入时容易出现三端文案和行为漂移。
- 当前 Local Mock 阶段没有足够复杂度支撑三套实现。

结论：不采用。

## 5. 推荐设计

### 5.1 共享同步设置内容结构

继续使用 iOS 已验证的信息架构：

1. 顶部状态卡
   - 当前不连接云端。
   - 显示当前语言空间上下文。
   - 明确这是同步设置真实级预览。

2. 同步方式
   - iCloud：推荐，面向 Apple-only 阶段。
   - S3-compatible：高级，面向 R2 / S3 / MinIO / custom endpoint。

3. 同步范围
   - 固定纳入：生活记录、学习材料和进度、Prompt Preset、AI 生成内容。
   - 可切换草稿：照片附件、音频附件。
   - 固定本地：向量索引本地重建，密钥与凭证仅本机。

4. 本阶段边界
   - 不连接 iCloud、S3、R2、WebDAV、数据库或安全凭证存储。
   - 不上传内容。

5. 未来路径
   - CloudKit Adapter、S3 Adapter、WebDAV、导出和冲突处理仍需后续方案。

### 5.2 iPad 端设计

iPad 同步设置入口保持不变：

- 左侧页面区的“设置”列表。
- 左侧底部 LanguageSpaceFooter 的 Sync 状态入口。

iPad 同步设置详情采用以下承载：

- 常规宽度：
  - 中央主区进入设置焦点状态。
  - 右侧 learning panel 默认收起，避免设置表单被挤窄。
  - 左侧 timeline/sidebar 保留，用户仍能回到工作台页面。
  - 同步设置内容使用大屏布局：状态卡置顶，方法卡横向或紧凑分组，范围与边界说明并列展示。
- compact width / Slide Over：
  - 自动回退单列布局，与 iPhone 同构。
  - 不依赖固定宽度，不假设全屏。
- S3 草稿：
  - 以 sheet 或 form sheet 展示，宽度控制在可读范围。
  - Provider、连接信息、密钥和安全说明保持分组。
  - 不在 iPad 主区直接铺开密钥表单，避免用户误认为已经保存。

交互边界：

- 照片和音频附件仍是唯一可切换的开关。
- iCloud 预览和 S3 草稿仍是本地 sheet，不触发系统账号、网络或 Keychain。
- 右侧面板被自动收起只是 UI 状态，不写入业务数据。
- 设置焦点只在进入设置详情 route 时应用一次默认策略：`.settings(.sync)` 和其他设置详情默认收起 learning panel；如果用户在该 route 内手动重新打开 learning panel，后续同一 route 内的宽度变化不能在 regular / three-column 场景下再次强制关闭。compact width / single-column 仍可按响应式规则隐藏面板，保证主内容可读。

### 5.3 macOS 端设计

macOS 需要覆盖两个入口。

第一，工作台 Settings section：

- Sidebar 的 Settings 和底部 Sync 入口继续进入 `MacWorkspaceRoute.settings(.sync)`。
- Settings 详情需要使用非嵌套滚动容器，避免外层 `MacMainView.main` 和内层 `SettingsCapabilityDetailView` 双重滚动。
- 内容宽度更宽，可采用两栏布局，但不无限拉伸。
- S3 草稿 sheet 设置合理最小宽度和高度，支持键盘输入、tab 顺序和 SecureField 显示/隐藏。

第二，原生 Settings scene：

- `LangoTraceSettingsSceneView` 从只读列表升级为可选择详情的设置窗口。
- 在存在当前语言空间时，选择“同步”显示同一套 `SettingsCapabilityDetailView` / `SyncSettingsView`。
- 在没有当前语言空间时，保持只读能力列表和边界说明，不创建默认语言空间，也不能把 `bootstrap` capability 伪装成当前空间的真实配置。
- Settings scene 的职责是偏好与能力配置入口，不承载学习记录、练习或记忆内容。

macOS 不新增菜单命令。现有 `Cmd+,` 打开 Settings scene；工作台 Sidebar / footer 仍提供 app 内部设置路径。

## 6. 工程实施方案

### 6.1 新增或调整的类型

建议新增：

- `SyncSettingsLayoutMode`
  - `stacked`
  - `regularColumns`
  - 通过可用内容宽度决定布局；iPad compact size class 强制 `stacked`，macOS 只按内容宽度判定。
- `SettingsCapabilityDetailPresentation`
  - `standaloneScrollable`
  - `embeddedInExistingScroll`
  - 用于解决 macOS 工作台嵌套滚动。

建议调整：

- `SyncSettingsView`
  - 继续接收 `languageSpace`。
  - 内部根据布局模式组合已有 sections。
  - 保持所有状态为本地 `@State` draft。
- `SyncS3DraftView`
  - 增加大屏 frame 限制。
  - 保持字段、验证和无副作用边界不变。
- `SettingsCapabilityDetailView`
  - 拆出内部 content builder，外层根据 presentation 决定是否包 `ScrollView`。
  - 默认参数保持当前行为，避免影响 iPhone。
- `PadMainView`
  - route 进入 `.settings(.sync)` 或其他设置详情时，默认收起右侧学习面板。
  - 用户手动重新打开 learning panel 后不阻止。
  - 设置焦点策略必须区分“route 切换触发的默认收起”和“用户手动 toggle”；不能在 regular width 下因为普通 resize 反复覆盖用户选择。
- `MacWorkspaceContentView`
  - 在 setting detail 中使用 `embeddedInExistingScroll`。
- `LangoTraceSettingsSceneView`
  - 接收可选 `languageSpace`、`interfaceLanguagePreference` 和变更回调。
  - 增加本地 selected capability state。
  - 选中 `.sync` 时展示共享详情；无语言空间时展示安全边界。
  - 无语言空间时展示全局能力边界，不展示当前空间上下文，不调用会暗示已有空间的详情页。
- `LangoTraceApp.swift`
  - macOS Settings scene 传入 `session.currentLanguageSpace` 和界面语言 preference。

### 6.2 测试策略

新增或扩展 `Packages/LangoTraceUI/Tests/LangoTraceUITests/SyncSettingsTests.swift`：

- 验证常规宽度使用 `regularColumns`，窄宽度使用 `stacked`。
- 验证 macOS 布局模式不依赖 horizontal size class；宽内容区使用 `regularColumns`，窄内容区使用 `stacked`。
- 验证附件仍是唯一可切换同步范围。
- 验证平台适配后仍不出现真实同步副作用 API。
- 验证 `SettingsCapabilityDetailView` 支持 sync route 且可选择非嵌套滚动 presentation。

新增或扩展 iPad / macOS 相关测试：

- iPad route 测试：Sync footer action 或 settings row 能进入 `.settings(.sync)`。
- iPad 设置焦点测试：设置详情 route 的默认 panel visibility 不保留右侧 learning panel 挤压配置页；用户在设置详情内手动重新打开 learning panel 后，regular width resize 不应再次覆盖用户选择。
- macOS Settings scene 源码边界测试：Settings scene 不再只是 `action: nil` 的只读列表，存在详情选择路径。
- macOS Settings scene 无语言空间测试：没有 `languageSpace` 时不渲染 `SettingsCapabilityDetailView`，不显示当前空间上下文，不创建默认空间。
- macOS 工作台测试：setting detail 使用 embedded presentation，避免 `MacMainView.main` 与设置详情双重 `ScrollView`。

继续保留现有无副作用测试：

- 不引入 `URLSession`。
- 不引入 `CKContainer` / `CKDatabase`。
- 不引入 `SecItem` / `KeychainAccess`。
- 不引入 `AWSSDK` / `S3Signer` / `WebDAV`。

### 6.3 文档更新

实施完成后更新：

- `docs/platform-page-inventory.md`
  - iPad 同步设置详情从“共享表单最大宽度”更新为“设置焦点 + 自适应布局”。
  - macOS 原生 Settings scene 从“只读能力列表”更新为“可进入同步详情的 Local Mock 设置窗口”。
- 本方案完成后移入 `docs/plans/done/` 并更新状态为 Verified。

若实施中发现需要改变同步策略、真实数据边界、密钥同步策略或 CloudKit / S3 Adapter 优先级，必须停止实现并新增或更新 ADR。本阶段按现有 ADR 和同步研究方案执行，不触发 ADR 变更。

## 7. 分步执行计划

1. 写失败测试：布局模式
   - 为 `SyncSettingsLayoutMode` 写宽度和 size class 判定测试。
   - 预期当前不存在该类型，测试失败。

2. 实现布局模式
   - 新增小型纯 Swift helper，避免把平台判定散落在 view 内。
   - 让 iPhone / narrow width 走 `stacked`，iPad / macOS 宽内容区走 `regularColumns`。
   - helper 输入应允许 size class 为 `nil`，避免 macOS 被迫依赖 iPad-only 环境值。

3. 写失败测试：设置详情 presentation
   - 验证 `SettingsCapabilityDetailView` 可被源码检测到存在 embedded presentation 参数。
   - 验证 macOS setting detail 调用 embedded presentation。

4. 重构设置详情容器
   - 拆出内部 content。
   - iPhone 和 iPad 默认仍使用 standalone scroll。
   - macOS 工作台使用 embedded presentation。

5. 写失败测试：iPad 设置焦点
   - 抽出或扩展 `PadAdaptivePanelLayout`，让设置详情 route 能默认隐藏 learning panel。
   - 验证 `.settings(.sync)` 不保留右侧学习面板作为默认状态。

6. 实现 iPad 设置焦点
   - 在 route 变化时应用设置焦点 panel policy。
   - 保留用户手动 toggle 面板能力。
   - 不把 panel 可见性写入业务模型。
   - 将 route 默认策略与宽度自适应策略分层：route 切换负责初始焦点，宽度自适应只在 compact / single-column 等空间不足场景下强制隐藏。

7. 写失败测试：macOS Settings scene 可进入详情
   - 验证 `LangoTraceSettingsSceneView` 不再只有 `action: nil` row。
   - 验证它接收 `languageSpace` 并能承载 `SettingsCapabilityDetailView`。

8. 实现 macOS Settings scene 详情
   - 增加 selected capability。
   - 有语言空间时展示详情。
   - 无语言空间时展示只读边界，不创建空间，不使用 `bootstrap` id 生成的能力列表冒充空间设置。

9. 优化 S3 / iCloud sheet 大屏表现
   - 为 sheet content 增加合理 frame。
   - 保持字段和按钮语义不变。
   - 确保 iPad compact 和 Mac 小窗口仍可滚动。

10. 更新页面清单
    - 同步更新 iPad、macOS、共享组件和变更记录。

11. 运行验证
    - `swift test --package-path Packages/LangoTraceUI --filter SyncSettingsTests`
    - `swift test --package-path Packages/LangoTraceUI`
    - `scripts/verify.sh`
    - `git diff --check`
    - 文档 placeholder 扫描。

12. 人工检查
    - iPad Pro 13-inch：进入设置 > 同步，检查右侧学习面板默认收起、内容不贴边、开关可点、sheet 尺寸合理。
    - iPad 窄宽度或 Slide Over：检查单列回退。
    - macOS 工作台：进入 Settings > Sync，检查无嵌套滚动异常。
    - macOS `Cmd+,`：打开 Settings scene，选择 Sync，检查可进入同一套 Local Mock UI。

## 8. 边界与风险

- 本阶段不保存同步配置。S3 表单字段即使填写完整，也只表示本地 UI 草稿。
- 本阶段不实现 CloudKit entitlement、iCloud container、private database、CKSyncEngine 或 push notification。
- 本阶段不实现对象存储签名、对象命名、manifest、tombstone、冲突合并、附件上传或恢复流程。
- 本阶段不改变 Prompt Preset、AI Provider、密钥和向量索引的既有边界。
- macOS 原生 Settings scene 引入详情后，必须避免与工作台 Settings section 语义冲突：两者都只是设置入口，真实学习主流程仍在工作台。
- iPad 设置焦点是 route 级 UI 默认行为，不是用户偏好持久化；不能进入语言空间模型、UserDefaults、数据库或同步 manifest。
- macOS Settings scene 在无语言空间时只能表达全局能力边界；任何需要当前语言空间上下文的详情页必须等待 `session.currentLanguageSpace` 存在。

## 9. 无阻塞疑问

当前没有必须向用户确认后才能继续的阻塞问题。基于项目定位、现有实现和 Apple 三端体验，推荐直接采用方案 B。

默认决策如下：

- iPad：同步设置详情进入设置焦点，大屏自适应两栏，窄宽度回退单列。
- macOS：工作台 Settings 和原生 Settings scene 都能进入同步详情；无语言空间时原生 Settings scene 只展示边界，不创建数据。
- 工程：共享同步模型和同步内容，不分叉三套业务 UI。
- 能力：继续保持 Local Mock，无真实同步、密钥、数据库和网络副作用。

## 10. 参考来源

- `AGENTS.md` / `docs/README.md`：任务前文档入口、同步任务必须先写方案、完成前验证要求。
- `docs/plans/done/2026-05-19-research-ios-sync-strategy-and-settings-ui.md`：iOS 同步策略、数据范围、iCloud / S3 决策和密钥边界。
- `docs/platform-page-inventory.md`：三端页面入口、当前 iPad / macOS 设置承载事实和维护规则。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`：当前共享同步设置 UI。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsModels.swift`：当前同步 draft、范围和 S3 草稿模型。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`：三端设置详情路由。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift` 与 `PadMainSections.swift`：iPad 工作台、panel 和设置详情承载。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`、`MacWorkspaceContentView.swift` 与 `LangoTraceSettingsSceneView.swift`：macOS 工作台、原生 Settings scene 和命令入口。
