# 工作记录：iPad 与 Mac 可收起侧栏和检查器

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/plans/done/2026-05-17-feature-ipad-ui-quality-pass.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`

关联提交：

- 未提交

## 1. 背景

当前 iPad 主体页已经形成“顶部全局条 + 左侧时间线 + 中间写作学习区 + 右侧学习面板”的学习桌面结构。这个结构适合 iPad 横屏全尺寸使用，但在竖屏、Split View、Stage Manager 或较窄窗口中，固定显示左右两侧面板会挤压中间的双语正文和逐句练习区。

用户提出：iPad 端左右侧边栏是否需要支持展开和收起。进一步讨论后确认，这个需求不只适用于 iPad，也适用于 Mac 端。但二者的产品动机和交互实现不同：

- iPad：主要解决触控设备上的空间适配、专注写作和沉浸练习。
- Mac：主要符合桌面级工具对 Sidebar、Inspector、菜单栏、快捷键和窗口管理的预期。

本次 worklog 用于记录该能力的产品判断、平台边界和后续实施方案。

## 2. 目标

本次完成后，应达到以下可验证结果：

- iPad 左侧时间线面板和右侧学习面板可以分别展开或收起。
- Mac 左侧 Sidebar 和右侧 Inspector 可以分别显示或隐藏。
- 中间写作与学习区始终保持最高优先级，左右面板是可召回的辅助能力。
- iPad 使用触控友好的顶部图标按钮完成切换。
- Mac 优先遵循桌面级工具心智，通过 Toolbar、菜单栏命令和可验证的键盘快捷键完成切换；不能只复制 iPad 的页面内按钮逻辑。
- iPhone 不引入侧栏或检查器收起逻辑，继续保持底部 Tab + 单列内容。
- 当前仍保持 Mock / App Shell 阶段边界，不引入真实路由、持久化设置或复杂多窗口状态。

## 3. 范围

本次会处理：

- 更新 iPad 的 `PadMainView` 结构，使左侧栏和右侧学习面板可按本地 UI 状态显示或隐藏。
- 在 iPad 顶部全局条加入低干扰图标按钮：
  - 显示 / 隐藏左侧时间线。
  - 显示 / 隐藏右侧学习面板。
- 更新 Mac 的 `MacMainView` 结构，使 Sidebar 和 Inspector 可按本地 UI 状态显示或隐藏。
- 在 Mac Toolbar 或等价顶部区域加入低干扰图标按钮：
  - 显示 / 隐藏 Sidebar。
  - 显示 / 隐藏 Inspector。
- 为 Mac 预留菜单栏和快捷键设计边界；如当前工程结构允许，可先实现基础 Commands。
- 使用 SwiftUI 本地临时 UI 状态管理，不写入数据库，不接同步，不进入 Core 领域模型。
- 更新本 worklog 的实施记录和验证结果。

## 4. 不做什么

本次不处理：

- iPhone 侧栏、抽屉导航或横屏三栏模式。
- 真实记录选择路由、深链、NavigationSplitView 完整重构。
- 侧栏宽度拖拽调整。
- 用户级持久化偏好，例如记住每个设备或每个窗口的侧栏状态。
- macOS 多窗口之间的独立布局状态同步。
- 根据窗口宽度自动隐藏面板的完整响应式断点系统。
- Stage Manager、Split View 的完整断点系统。
- 真实 AI、TTS、OCR、同步、数据库、StoreKit 或权限流程。
- 完整菜单栏体系和 Command Palette，除非为本能力提供最小必要入口。

## 5. 分析

### 5.1 必要性

语迹的 iPad 和 Mac 页面都采用大屏工作台结构。工作台结构的优点是信息密度高、上下文清晰，但风险是主内容被左右辅助面板挤压。对于语迹来说，用户真正的核心任务是：

- 写下生活记录。
- 阅读 AI 转换后的目标语言文本。
- 听、跟读、听写和回译。
- 从当前内容沉淀词句与长期记忆。

因此中间写作与学习区必须始终是主角。左右面板应该服务当前记录，而不是永久占据空间。支持收起可以让用户在不同任务之间切换：

- 记录整理时打开左侧时间线。
- 专注写作时收起左右面板。
- 逐句学习时打开右侧学习面板。
- 小窗口或分屏时保留中间内容优先。

### 5.2 iPad 与 Mac 的差异

iPad 侧栏收起的核心是触控设备上的空间和专注：

- 用户可能横屏、竖屏、分屏或使用 Stage Manager。
- 顶部按钮应足够大，符合触控目标要求。
- 不应依赖悬停、菜单栏或键盘快捷键。
- 动画应轻、短、可理解，避免干扰写作和阅读。

Mac 侧栏收起的核心是桌面级窗口管理：

- 用户可能缩放窗口、并排显示多个 App、打开多个文档窗口。
- 显示 / 隐藏 Sidebar 和 Inspector 是 macOS 工具类 App 的常见心智。
- Toolbar 图标、菜单栏命令和快捷键应同时存在或至少预留。
- 后续可以演进到窗口级布局状态和多窗口独立状态。

### 5.3 与产品定位的关系

语迹不是后台管理系统，也不是把所有功能铺满的大屏看板。可收起面板能强化“私人语言资料库与学习桌面”的高级感：

- 默认页面安静，不让功能堆叠压迫用户。
- 需要上下文时召回左侧资料和时间线。
- 需要学习辅助时召回右侧解释、词句、请求预览和记忆线索。
- 通过空间变化表达任务切换，而不是增加更多 Tab 或页面。

### 5.4 对现有实现的影响

当前 iPad 的 `PadMainView` 已经有顶部全局条、左侧栏、中间区和右侧面板，适合在现有自定义三栏上增加 `@State` 控制。

当前 Mac 的 `MacMainView` 仍是较早的骨架版，Sidebar 和 Inspector 固定显示。它也适合先增加基础收起能力，但 Mac 整体 UI 质量尚未完成独立优化，因此本次 Mac 改动应保持克制，不顺手做完整 Mac 视觉重构。

### 5.5 状态层级

侧栏与检查器的展开状态属于 `Transient UI state`：

- 不属于语言空间主数据。
- 不进入 Core 模型。
- 不进入 Repository、SQLite、同步 manifest 或对象存储。
- 不参与 AI 请求、TTS、OCR、练习记录或长期记忆。
- 本次不持久化到用户设置。

后续如果需要记住用户偏好，应作为独立设置能力设计，明确区分“设备级偏好”“窗口级偏好”和“语言空间主数据”。

### 5.6 默认显示策略

本次默认策略：

- iPad 横屏全尺寸：默认显示左侧时间线和右侧学习面板。
- iPad 竖屏、Split View、Stage Manager 窄窗口：本次不做自动断点，但手动收起能力必须可用，且不能阻碍后续引入响应式降级。
- Mac 标准窗口：默认显示 Sidebar 和 Inspector。
- Mac 较窄窗口：本次不做自动隐藏，但主编辑区应保持优先可读，不能因为左右面板固定导致页面不可用。

## 6. 方案

推荐采用“平台化可收起辅助面板”方案。

### 6.1 统一原则

统一原则是：

> 中间写作与学习区永远是主工作区，左右面板是可召回的辅助能力。

具体表现：

- iPad：左侧时间线和右侧学习面板可以分别收起。
- Mac：左侧 Sidebar 和右侧 Inspector 可以分别隐藏。
- iPhone：不参与该模式。

### 6.2 iPad 方案

iPad 顶部全局条增加两个 icon-only 按钮：

- 左侧面板按钮：使用 `sidebar.left` 或系统中更适合的 SF Symbol。
- 右侧面板按钮：使用 `sidebar.right`、`info.circle` 或系统中更适合的 SF Symbol。

交互规则：

- 点击按钮切换对应面板显示状态。
- 收起左侧后，中间区域扩展。
- 收起右侧后，中间区域扩展。
- 左右都收起时，中间区域进入专注写作 / 学习状态。
- 按钮触控目标至少 44pt。
- 按钮必须有动态 `accessibilityLabel`，表达当前动作，例如“隐藏时间线”“显示学习面板”，不能只写静态“侧栏按钮”。
- 收起 / 展开状态不能只靠颜色区分。
- 动画应轻、短，并尊重系统 Reduce Motion 设置。

### 6.3 Mac 方案

Mac 不应简单复制 iPad 的触控按钮逻辑。Mac 的推荐顺序是：

1. 优先使用 macOS / SwiftUI 可稳定接入的标准 Sidebar 或 Toolbar 展示方式。
2. 在 Toolbar 或现有顶部区域提供低干扰 icon-only 按钮。
3. 在工程结构允许且不引入额外复杂度时，补充菜单栏命令。
4. 快捷键必须经过冲突检查后再落地。

Mac 顶部 Toolbar 或现有顶部区域提供两个 icon-only 按钮：

- 显示 / 隐藏 Sidebar。
- 显示 / 隐藏 Inspector。

快捷键边界：

```text
Sidebar     优先使用 SwiftUI / macOS 标准 Sidebar command；如需自定义，必须先确认不与系统、文本编辑和保存语义冲突。
Inspector   可优先评估 Cmd + Option + I，但实现前仍需确认没有冲突。
```

菜单栏后续推荐：

```text
View -> Show/Hide Sidebar
View -> Show/Hide Inspector
```

如果本次工程入口还不适合安全接入完整 macOS Commands，应只实现页面内 Toolbar 切换，并把 Commands 作为后续 Mac UI 质量优化的一部分记录。

### 6.4 实施分期

本 worklog 保持一份，不拆分为多份。但实现时建议按阶段推进：

1. Phase 1：实现 iPad 左侧时间线和右侧学习面板的手动收起 / 展开。
2. Phase 2：实现 Mac Sidebar 和 Inspector 的基础手动显示 / 隐藏。
3. Phase 3：评估并补充 Mac Commands、菜单栏和快捷键；如果工程结构不适合，本阶段延期到 Mac 产品级 UI 质量优化。

### 6.5 替代方案

方案 A：只在 iPad 做，不在 Mac 做。

- 优点：范围小。
- 缺点：Mac 作为资料库与创作工作台，同样需要窗口级空间控制，后续仍会补做。

方案 B：iPad 与 Mac 立即重构为 `NavigationSplitView`。

- 优点：更接近 Apple 原生 split view 心智。
- 缺点：当前仍是 Mock / App Shell 阶段，会提前引入真实选择状态、路由和断点复杂度。

方案 C：保留现有自定义布局，先加入平台化收起状态。

- 优点：成本可控，能快速改善空间适配和高级感。
- 缺点：未来真实路由和多窗口实现时可能需要再迁移到更原生的 split/inspector 架构。

推荐方案 C。

## 7. 风险与边界

- 风险：按钮过多，顶部全局条变复杂。
  - 缓解：使用 icon-only + accessibility label，图标靠近对应边缘，不引入文字按钮。
- 风险：iPad 收起后页面过空。
  - 缓解：中间区域增加最大宽度或合理内边距，保持阅读行长。
- 风险：Mac 当前页面尚未完成视觉优化，新增按钮后仍不够高级。
  - 缓解：本次只解决交互基础，Mac 产品级 UI 质量优化进入独立 worklog。
- 风险：状态不持久化，重启后恢复默认。
  - 缓解：当前 App Shell 阶段接受本地瞬时状态，持久化偏好后续单独设计。
- 风险：快捷键与系统或文本编辑冲突。
  - 缓解：不提前固定 Sidebar 快捷键，不占用 `Cmd + S` 等核心系统语义；实际实现前确认 SwiftUI Commands 和 macOS 默认行为。
- 风险：动画导致布局跳动或影响可读性。
  - 缓解：使用短时 ease 或 spring 过渡，避免复杂转场；尊重 Reduce Motion；如效果不稳定，先关闭动画。
- 风险：面板状态被错误做成业务状态或同步状态。
  - 缓解：明确限定为 `Transient UI state`，本次只保存在对应 View 或轻量 UI 容器中。

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
  - 进入主体页后，点击左侧面板按钮，左侧时间线应收起 / 展开。
  - 点击右侧面板按钮，右侧学习面板应收起 / 展开。
  - 左右都收起时，中间写作和学习区不应出现明显拉伸、重叠或不可读。
  - 按钮触控目标足够清晰，不与语言空间切换、搜索、设置入口混淆。
  - 使用辅助功能检查按钮语义，确认 VoiceOver 可理解当前动作。
- Mac：
  - 启动 macOS App。
  - 点击 Sidebar 按钮，左侧 Sidebar 应隐藏 / 显示。
  - 点击 Inspector 按钮，右侧 Inspector 应隐藏 / 显示。
  - 如实现 Commands，验证对应菜单项和快捷键可用，且不覆盖保存、查找、文本编辑等常用语义。
  - 缩小窗口时主编辑区仍优先可读。

## 9. 用户确认记录

2026-05-17：用户确认在再次检查、确定无误后开始实施。

## 10. 实施记录

2026-05-17：已完成 iPad 与 Mac 的基础手动展开 / 收起能力。

主要改动：

- `PadMainView`：
  - 增加 `isTimelineVisible` 和 `isLearningPanelVisible` 两个 SwiftUI 本地瞬时状态。
  - 左侧时间线和右侧学习面板可分别显示 / 隐藏。
  - 中间写作与学习区保持 `layoutPriority(1)`，在左右面板收起后优先获得空间。
  - 收起 / 展开动画尊重 `accessibilityReduceMotion`。
- `PadWorkspaceBar`：
  - 拆分为独立组件。
  - 顶部全局条加入左侧时间线和右侧学习面板的 icon-only 切换按钮。
- `MacMainView`：
  - 增加 `isSidebarVisible` 和 `isInspectorVisible` 两个 SwiftUI 本地瞬时状态。
  - Sidebar 和 Inspector 可分别显示 / 隐藏。
  - Mac 当前只实现页面内顶部区域切换入口，不提前接入菜单栏 Commands 或快捷键。
  - 根据面板显示状态调整窗口最小宽度，并为主内容区设置最小宽度和更高布局优先级，避免默认三栏状态下主标题和正文被压缩到不可读。
- `LangoPanelToggleButton`：
  - 新增共享图标按钮组件。
  - 触控 / 点击目标为 44pt。
  - 使用动态 `accessibilityLabel` 和 `accessibilityValue` 表达当前动作与状态。
- 跨平台构建修正：
  - `PhoneMainView` 的 `.tabBar` toolbar background 限定在 iOS 编译，避免 macOS target 编译失败。
  - `project.yml` 的 macOS target 排除 iOS 专用 `LaunchScreen.storyboard`，避免 macOS ibtool 处理 iOS storyboard。

本次没有引入数据库、同步、真实路由、AI、TTS、OCR 或持久化设置。

## 11. 验证结果

2026-05-17：已完成命令验证、iPad Simulator 人工点击截图验收和 macOS 图形界面点击验收。

执行命令：

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

- `xcodegen generate` 成功生成工程。
- `swift test --package-path Packages/LangoTraceCore` 通过，4 个测试通过。
- `swiftlint --no-cache` 通过，0 violations。
- `swiftformat --lint . --cache ignore` 通过，0 个文件需要格式化。
- `xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build` 通过。
- `xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS' build` 通过。
- `git diff --check` 通过。

人工验收：

### iPad

- 设备：iPad Pro 13-inch (M5) Simulator，iOS 26.5。
- 已安装并启动 `com.zibuyu.LangoTrace`。
- 已从首次语言空间创建页进入主体页。
- 左侧时间线按钮：
  - 初始状态显示 `隐藏时间线`，`accessibilityValue` 为 `当前已显示`。
  - 点击后左侧时间线收起，按钮变为 `显示时间线`，`accessibilityValue` 为 `当前已隐藏`。
  - 再次点击后左侧时间线恢复显示。
- 右侧学习面板按钮：
  - 初始状态显示 `隐藏学习面板`，`accessibilityValue` 为 `当前已显示`。
  - 点击后右侧学习面板收起，按钮变为 `显示学习面板`，`accessibilityValue` 为 `当前已隐藏`。
  - 再次点击后右侧学习面板恢复显示。
- 左右都收起时，中间写作与学习区扩展，没有明显文字重叠、横向溢出或不可读。
- 左右重新展开后，三栏布局恢复正常。

截图证据：

- `/private/tmp/langotrace-ipad-panels-both-visible.png`
- `/private/tmp/langotrace-ipad-panels-left-hidden.png`
- `/private/tmp/langotrace-ipad-panels-both-hidden.png`
- `/private/tmp/langotrace-ipad-panels-restored.png`

### macOS

- 设备：本机 Mac，macOS target。
- 已启动最新构建产物 `LangoTrace.app`。
- 已从首次语言空间创建页进入主体页。
- 复测中发现并修复过一个问题：默认三栏窗口下主区过窄，导致标题出现逐字竖排。
- 修复后默认三栏布局正常，`语言资料库工作台` 标题和主内容横向可读。
- Sidebar 按钮：
  - 初始状态显示 `隐藏侧边栏`，`accessibilityValue` 为 `当前已显示`。
  - 点击后 Sidebar 收起，按钮变为 `显示侧边栏`，`accessibilityValue` 为 `当前已隐藏`。
- Inspector 按钮：
  - 初始状态显示 `隐藏检查器`，`accessibilityValue` 为 `当前已显示`。
  - 点击后 Inspector 收起，按钮变为 `显示检查器`，`accessibilityValue` 为 `当前已隐藏`。
- Sidebar 和 Inspector 都收起时，主工作区正常扩展，没有明显文字重叠、横向溢出或不可读。

说明：

- 本次已完成编译、格式、lint、Core 测试、iPad Simulator 点击截图验收和 macOS 图形界面点击验收。
