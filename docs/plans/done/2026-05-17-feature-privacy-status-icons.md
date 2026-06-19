# 工作记录：隐私状态图标优化

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/plans/done/2026-05-17-feature-platform-navigation-refinement.md`

关联 ADR：

- `docs/decisions/004-use-language-space-as-primary-model.md`

关联提交：

- 未提交

## 1. 背景

当前 iPad 主体页已经把语言空间和设置入口下沉到左侧 Sidebar 底部，但仍存在两个问题：

- 顶部全局条仍显示 `本地优先 · 未配置 AI`。
- Sidebar 底部也显示 `本地优先 · AI 未配置`。

这导致同一状态在 iPad 页面内重复出现，削弱顶部工具栏的简洁感。用户进一步指出：未来这里实际涉及两个独立配置状态：

- AI Provider 配置。
- 云端同步 / 对象存储配置。

因此不应继续用一个笼统的“本地优先”文案表达全部状态，而应拆成更准确、低干扰、可解释的状态图标。

## 2. 目标

本次完成后，应达到以下可验证结果：

- iPad 顶部全局条移除常驻隐私状态文字。
- iPad 顶部只保留当前任务相关入口：Sidebar 切换、搜索、学习面板切换。
- iPad Sidebar 底部保留语言空间、设置入口、AI Provider 与同步状态；三个配置图标处于同一行，减少底部占高。
- Mac Sidebar 底部采用同一信息结构，保持跨 iPad / macOS 的状态表达一致。
- AI Provider 和同步状态互相独立，不再合并成一个笼统状态。
- 未配置、已配置、错误、同步中等状态有明确颜色或样式规则。
- 点击、悬停或长按状态图标时，用户可以看到文字说明。
- AI / 同步图标表达“能力或配置状态”，不表达“会自动发送或自动同步”。
- 本次方案需要消除长期规范中“顶部仍显示本地状态”的旧表述，避免后续 AI 辅助开发时读到冲突规则。
- 当前仍保持 Mock / App Shell 阶段边界，不实现真实 AI Provider、真实同步、真实设置页或持久化。

## 3. 范围

本次会处理：

- iPad：
  - 从 `PadWorkspaceBar` 移除 `本地优先 · 未配置 AI` 文案。
  - 保留顶部 Sidebar 切换、搜索、学习面板切换。
  - 在 Sidebar 底部语言空间区域增加 AI Provider 状态图标。
  - 在 Sidebar 底部语言空间区域增加同步状态图标。
  - 为两个图标设计点击 / 悬停说明。
- macOS：
  - 在 Sidebar 底部语言空间区域采用同样的 AI Provider / 同步状态图标结构。
  - 视觉密度比 iPad 更紧凑。
- 文档：
  - 同步 `docs/spec/002-navigation-and-routing.md`：移除 iPad 顶部全局条中的本地保存状态，改为 Sidebar 底部状态图标组。
  - 同步 `docs/spec/003-ui-design-system.md`：移除“顶部全局条仍可保留本地优先 / 未配置 AI”的旧规则，改为 AI / 同步双状态图标规则。
  - 更新本 worklog 的实施记录和验证结果。

## 4. 不做什么

本次不处理：

- 真实 AI Provider 配置、保存、验证或请求。
- 真实对象存储、iCloud、WebDAV、S3、R2 配置。
- 同步任务、同步冲突、同步进度持久化。
- API Key、密钥、Keychain 或安全存储实现。
- 真实设置页面跳转。
- 顶部新增状态图标。
- iPhone 设置页的信息架构调整。
- 真实 Popover 内容数据源。
- 完整请求预览 UI。
- 同步冲突详情 UI。
- 深链、路由、数据库、StoreKit 或权限流程。

## 5. 分析

### 5.1 顶部是否应保留隐私状态

不建议保留。

iPad 顶部全局条的核心职责是承载当前任务入口：

- 打开或收起时间线。
- 搜索当前记录、词句、相似生活片段。
- 打开或收起学习面板。

`本地优先 · 未配置 AI` 属于低频但重要的状态说明，不是当前任务入口。它在顶部常驻会造成两个问题：

- 与 Sidebar 底部状态重复。
- 让顶部从“操作条”变成“状态条”，降低页面高级感和扫描效率。

因此顶部应彻底移除隐私状态文字，不再用图标替代它。状态统一收敛到 Sidebar 底部。

### 5.2 为什么要拆成 AI 和同步两个状态

AI Provider 与云端同步是两个不同风险边界：

- AI Provider 影响文本、图片摘要、相似记忆等内容是否会在用户触发 AI 功能后发送到外部模型服务。
- 云端同步影响本地数据库、媒体附件、索引元数据或同步 manifest 是否会写入用户配置的云端目标。

如果用一个“本地优先”统一表达，会掩盖关键差异：

- AI 已配置但同步未配置。
- 同步已配置但 AI 未配置。
- 两者都未配置。
- 两者都已配置，但仍需要请求预览和同步范围约束。

所以底部状态应拆成两个图标，分别表达 AI 和同步。

状态图标必须表达“能力是否可用 / 配置是否存在”，不能表达“系统会自动发送或自动同步”。即使 AI Provider 已配置，AI 请求仍必须由用户触发，并在发送前展示请求预览。即使同步已配置，也只代表同步能力可用，真实同步范围仍由用户配置和同步策略控制。

### 5.3 状态模型

本次虽然仍处于 Mock / App Shell 阶段，但组件设计不应把“未配置”写死在视图结构中。应预留可替换的状态输入，便于后续真实配置接入。

推荐最小状态模型：

```text
AIStatus:
- notConfigured
- configured
- unavailable
- error

SyncStatus:
- off
- configured
- syncing
- paused
- error
```

状态含义：

- `AIStatus.notConfigured`：用户尚未配置 AI Provider，AI 能力不可用，但这不是错误。
- `AIStatus.configured`：AI Provider 已配置，AI 能力可用，但不会自动发送内容。
- `AIStatus.unavailable`：当前平台、网络、权限或配置条件导致 AI 能力暂不可用。
- `AIStatus.error`：AI Provider 配置存在错误或最近一次请求失败。
- `SyncStatus.off`：同步未启用，数据仅保存在本机。
- `SyncStatus.configured`：同步已配置，具备同步能力。
- `SyncStatus.syncing`：正在同步，应使用低干扰动态状态，并尊重 Reduce Motion。
- `SyncStatus.paused`：同步被用户暂停或因条件不足暂停。
- `SyncStatus.error`：同步失败或配置失效。

### 5.4 图标语义

不建议使用感叹号作为默认状态。

原因：

- `AI 未配置` 和 `同步未启用` 不是错误。
- 感叹号会制造警告感，削弱本地优先的正向信任表达。
- 只有真实异常、配置失效、同步失败或请求失败时，才应使用警告语义。

首版固定图标：

- AI Provider：`sparkles`。
- 同步：`arrow.triangle.2.circlepath`。
- 隐私保护基础语义可以通过 `lock` 或 `lock.shield` 出现在说明文案中，不必作为第三个常驻图标。
- 错误状态不更换为感叹号主图标，避免图标语义跳变；错误通过状态色、辅助标签、状态值和说明文案表达。

### 5.5 状态颜色与样式

推荐状态规则：

- 未配置：低饱和灰色或弱墨色，表示“可配置但不需要立即处理”。
- 已配置：深松石绿或品牌强调色，表示“已启用 / 可用”。
- 错误：低饱和琥珀或红色，只在真实错误时使用。
- 同步中：使用轻微进度点、旋转或状态变体；必须尊重 Reduce Motion。
- 禁用：比未配置更弱，需在说明中解释不可用原因。

颜色不能作为唯一信息来源。每个状态图标必须有可访问名称、状态值和文字说明。

### 5.6 Tooltip / Popover 内容

状态图标不是纯装饰，点击、悬停或长按后应展示说明。

AI Provider 未配置时：

```text
AI Provider 未配置
当前不会发送文本、照片摘要或相似记忆。
配置后，只有在你触发 AI 功能并确认请求预览时才会发送。
```

AI Provider 已配置时：

```text
AI Provider 已配置
AI 请求会在发送前显示请求预览。
API Key 保存在本机安全存储中。
```

同步未启用时：

```text
同步未启用
数据仅保存在本机。
你可以稍后配置 iCloud、WebDAV、S3 或 R2。
```

同步已配置时：

```text
同步已配置
仅同步你配置范围内的数据。
密钥和未选择的数据不会进入同步内容。
```

当前 Mock 阶段可以先显示静态说明，不接真实状态源。

平台触发规则：

- iPad：点击显示 Popover；长按可显示说明；支持 pointer hover，但不能依赖 hover 作为唯一发现方式。
- macOS：hover tooltip 可以作为轻量说明，点击 Popover 可展示更完整内容。
- VoiceOver：必须通过 accessibility label、value 和 hint 读出图标类型、当前状态和下一步含义。
- 键盘用户：macOS 图标应可聚焦，后续进入真实设置时需要支持键盘触发。

### 5.7 与请求预览、同步冲突的关系

Sidebar 底部状态图标只解释当前配置状态，不承载完整请求预览或同步冲突处理。

- AI 请求预览仍属于 AI 操作流程，应出现在学习面板、请求预览卡片或 AI 发送确认流程中。
- 同步冲突仍属于临时任务路由，应通过独立的冲突确认界面处理。
- 状态图标可以提示“已配置 / 未配置 / 错误”，但不能承担复杂操作流程。

### 5.8 长期规范同步点

当前长期规范中仍存在与本方案冲突的旧表述，需要在实施时同步更新：

- `docs/spec/002-navigation-and-routing.md` 中 iPad 顶部全局条不应再包含“本地保存状态”。
- `docs/spec/003-ui-design-system.md` 中不应再建议顶部全局条保留“本地优先 / 未配置 AI”。
- iPad / macOS Sidebar 底部应明确为语言空间、设置、AI 状态、同步状态的低频上下文区。

## 6. 方案

推荐采用“顶部去状态、Sidebar 底部双状态图标”的方案。

### 6.1 iPad 方案

iPad 顶部调整为：

```text
[时间线切换] [搜索记录、词句、相似生活片段] [学习面板切换]
```

iPad Sidebar 底部调整为：

```text
英语空间                 [AI] [Sync] [设置]
中文 -> 英语 · B1
```

设计规则：

- AI、同步和设置图标应靠近语言空间，并处于同一行，因为它们都属于当前空间的低频配置上下文。
- 两个状态图标不要做成新的卡片，只作为轻量工具图标组。
- 每个图标触控目标不少于 44pt。
- 图标说明可以用 Popover、Tooltip 或 SwiftUI 平台适配方式实现。
- AI 图标固定使用 `sparkles`，同步图标固定使用 `arrow.triangle.2.circlepath`。
- 首版 Mock 默认状态为 `AIStatus.notConfigured` 和 `SyncStatus.off`。
- Mock 阶段点击图标只显示说明，不跳转真实设置，不写入数据。

### 6.2 Mac 方案

Mac Sidebar 底部采用相同语义，但更紧凑：

```text
英语空间              [AI] [Sync] [设置]
中文 -> 英语 · B1
```

设计规则：

- macOS 可以使用 hover tooltip 作为主要说明方式，点击可作为后续进入设置的入口。
- 当前阶段点击仍保持无副作用。
- 图标应可被键盘聚焦，并提供辅助标签和状态值。
- 后续 `Settings...`、`Cmd+,` 或菜单栏入口实现后，再决定点击图标是否直达对应配置分区。

### 6.3 替代方案

方案 A：顶部继续显示 `本地优先 · 未配置 AI`。

- 优点：状态最明显。
- 缺点：与 Sidebar 底部重复，顶部显得拥挤，不符合当前工具栏职责。

方案 B：顶部只显示一个隐私图标。

- 优点：比文字更简洁。
- 缺点：仍占用顶部，并且无法表达 AI 与同步两个独立状态。

方案 C：Sidebar 底部显示一个综合隐私图标。

- 优点：最简洁。
- 缺点：无法区分 AI Provider 与同步配置，后续状态扩展会变模糊。

方案 D：Sidebar 底部显示 AI / 同步两个状态图标。

- 优点：结构准确，视觉克制，状态可扩展，符合本地优先与用户掌控。
- 缺点：需要设计图标说明和状态样式。

推荐方案 D。

## 7. 风险与边界

- 风险：顶部移除状态后，用户不容易注意到隐私边界。
  - 缓解：Sidebar 底部保留两个状态图标，并通过说明明确“不自动发送”和“本地保存”。
- 风险：两个图标含义不够直观。
  - 缓解：使用可访问标签、Tooltip / Popover 和一致的图标语义。
- 风险：已配置状态被理解为“所有数据会自动发送或同步”。
  - 缓解：说明文案必须强调用户触发、请求预览和同步范围。
- 风险：颜色成为唯一状态表达。
  - 缓解：图标、辅助标签、状态值和说明文案共同表达。
- 风险：未来真实 AI / 同步状态接入后 Mock 语义不匹配。
  - 缓解：组件应预留状态枚举或输入参数，不把“未配置”写死在视图结构中。
- 风险：状态图标被误认为请求预览或同步冲突入口。
  - 缓解：状态图标只展示配置状态说明；复杂流程仍由学习面板、请求预览卡片或临时任务路由承载。
- 风险：Popover / Tooltip 对触控和辅助技术不友好。
  - 缓解：iPad 必须支持点击 Popover；VoiceOver 必须能读出 label、value 和 hint；macOS 不能只依赖 hover。
- 风险：长期规范继续保留旧的顶部状态规则。
  - 缓解：实施时同步更新导航规范和 UI 设计系统规范，并在变更记录中说明原因。

## 8. 测试与验证

完成前至少执行：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
swiftlint --no-cache
swiftformat --lint . --cache ignore
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS' build
git diff --check
```

手动验证：

- iPad Pro 13-inch Simulator：
  - 顶部不再显示 `本地优先 · 未配置 AI`。
  - 顶部只显示 Sidebar 切换、搜索、学习面板切换。
  - Sidebar 底部显示语言空间、设置入口、AI 状态图标和同步状态图标。
  - 点击或悬停 AI 图标能看到 AI Provider 状态说明。
  - 点击或悬停同步图标能看到同步状态说明。
  - AI 图标使用 `sparkles`，同步图标使用 `arrow.triangle.2.circlepath`。
  - VoiceOver 或辅助树能区分 AI Provider 状态与同步状态。
  - Sidebar 收起后状态图标跟随隐藏，再次展开后恢复。
- Mac：
  - Sidebar 底部显示同样的 AI / 同步状态图标。
  - 主区顶部不显示 AI / 同步状态。
  - 状态图标可被键盘聚焦或至少具备明确辅助标签。
  - Sidebar 收起后状态图标隐藏，主区仍可读。
- 文档：
  - `docs/spec/002-navigation-and-routing.md` 不再要求 iPad 顶部显示本地保存状态。
  - `docs/spec/003-ui-design-system.md` 不再要求顶部保留本地优先 / 未配置 AI 状态。

## 9. 用户确认记录

状态为 `Draft` 时不能开始实现。

用户确认后记录：

```text
2026-05-17：用户确认本方案，可以开始实现。
```

## 10. 实施记录

2026-05-17：开始实施。先在 Core 层补充 AI Provider 与同步状态模型测试，再接入 iPad / macOS Sidebar 底部状态图标，并同步长期规范文档。

2026-05-17：根据用户反馈，将 AI Provider、同步和设置图标合并到语言空间标题行右侧，避免底部工具区纵向占用过多空间。

## 11. 验证结果

自动验证：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
swiftlint --no-cache
swiftformat --lint . --cache ignore
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS' build
git diff --check
```

结果：

- `swift test --package-path Packages/LangoTraceCore` 通过，11 个测试通过。
- `swiftlint --no-cache` 通过，0 violations。
- `swiftformat --lint . --cache ignore` 通过，0 个文件需要格式化。
- iPad Pro 13-inch (M5) Simulator 构建通过。
- macOS 构建通过。
- `git diff --check` 通过。

人工验证：

- iPad Pro 13-inch (M5) Simulator：
  - 顶部全局条不再显示 `本地优先 · 未配置 AI`。
  - Sidebar 底部语言空间、AI Provider、同步和设置入口同处一行，减少纵向占高。
  - AI Provider 图标使用 `sparkles`，同步图标使用 `arrow.triangle.2.circlepath`。
  - 点击 AI Provider 图标后，状态说明浮层完整显示在 Sidebar 内，未出现左侧裁切。
  - 辅助树能区分 AI Provider 状态与同步状态，并包含 label、value 和 hint。
- macOS：
  - Sidebar 底部语言空间、AI Provider、同步和设置入口同处一行。
  - 点击 AI Provider 图标后，状态说明浮层完整显示在工具区上方，未出现窗口边缘裁切。
  - 辅助树能区分 AI Provider 状态与同步状态，并包含 label、value 和 hint。

验证结论：

- 本次变更满足“顶部去状态、Sidebar 底部双状态图标、AI / 同步独立表达、点击显示说明、保持页面简洁”的目标。
