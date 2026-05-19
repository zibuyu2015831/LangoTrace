# iPad 右侧面板留白与顶部工具栏去重修复方案

Status: Verified

Type: bug

Created: 2026-05-19

Last Updated: 2026-05-19

## 用户确认记录

- 2026-05-19：用户在 iPad 工作台截图中指出右侧栏内容块边框距离屏幕边缘过近，视觉不美观。
- 2026-05-19：用户指出顶部齿轮“设置”图标与已有设置入口重复，应删除；控制右侧边栏的图标可以移动到最右边。

## 问题描述

本轮修复两个 iPad 工作台视觉和信息架构问题：

1. 右侧学习面板宽度较窄，内部 `ScrollView` 只有统一 `22pt` padding，内容卡片右边框接近屏幕 / 面板边界，显得拥挤。
2. 顶部工具栏同时包含右侧面板切换按钮和齿轮设置按钮；设置入口已经在左侧语言空间底部区稳定存在，顶部齿轮属于重复低频入口，削弱当前任务工具栏的简洁性。

## 现状代码

- `PadWorkspaceBar.swift` 当前顺序为：左侧栏切换、搜索、右侧栏切换、设置、 新建记录。
- `PadMainView.swift` 中 `PadWorkspaceBar` 仍接收 `onSettings` 并把 route 切到 `.settingsList`。
- `PadLearningPanelView.swift` 右栏根容器：
  - `VStack` 使用 `.padding(22)`。
  - 整体 `.frame(minWidth: 300, idealWidth: padInspectorWidth, maxWidth: 360)`。
  - 没有针对 trailing 边缘设置额外内边距。

## 设计结论

### 右侧面板

采用 iPad inspector 的处理方式：保持右侧面板本身存在，但把内容区域改为不对称留白。

- 顶部 / 左侧 / 底部维持接近当前视觉密度。
- 右侧增加额外 trailing padding，让卡片边框不贴近设备边缘和滚动条区域。
- 不改变 `padInspectorWidth`，避免牵动三栏自适应阈值。
- 不把卡片内容缩小成更窄的固定宽度，避免中文和英文句子更早换行。

### 顶部工具栏

顶部工具栏只保留当前任务高频动作：

- 左侧栏切换。
- 搜索。
- 右侧学习面板切换。
- 新建记录。

删除顶部齿轮设置按钮。设置入口继续由左侧语言空间底部区承担。右侧学习面板切换按钮移动到搜索之后、新建记录之前的最右功能组位置，视觉上成为“右侧面板的控制器”，避免夹在设置和搜索之间产生误读。

## 范围

本轮做：

- 调整 `PadLearningPanelView` 的横向 padding。
- 删除 `PadWorkspaceBar` 顶部设置按钮和 `onSettings` 参数。
- 更新 `PadMainView` 调用。
- 更新源码级测试，锁定顶部工具栏不再包含设置入口，且右侧面板有 trailing inset。
- 更新页面清单和导航 / UI 规范。

本轮不做：

- 不重做 iPad 三栏布局。
- 不删除左侧底部设置入口。
- 不改变右侧栏显示 / 隐藏状态逻辑。
- 不改 iPhone 或 macOS 设置入口。

## 涉及代码文件

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadWorkspaceBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

## 涉及文档

- `docs/platform-page-inventory.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`

## 验证方案

1. `swift test --package-path Packages/LangoTraceUI --filter PremiumUIBehaviorTests/iPadWorkspaceBarKeepsUtilityActionsAndKeyboardShortcutsReachable`
2. `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests/padLearningPanelKeepsContentAwayFromTrailingEdge`
3. `swift test --package-path Packages/LangoTraceUI`
4. `swiftlint --no-cache`
5. `swiftformat --lint . --cache ignore`
6. `git diff --check`
7. `scripts/verify.sh`

## 实施记录

- 2026-05-19：`PadWorkspaceBar` 删除顶部设置齿轮和 `Cmd+,` 快捷键，右侧学习面板切换按钮移动到工具栏最右侧。
- 2026-05-19：`PadMainView` 删除 `PadWorkspaceBar` 的 `onSettings` 传参；设置入口继续由左侧页面入口和语言空间底部工具区承载。
- 2026-05-19：`PadLearningPanelView` 增加不对称 `contentPadding`，trailing 留白调整为 `32pt`。
- 2026-05-19：补充 `PremiumUIBehaviorTests` 与 `PageClosureStateTests` 源码级回归测试，覆盖顶部设置去重和右侧面板 trailing inset。
- 2026-05-19：更新 `docs/platform-page-inventory.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`。

## 验证记录

- 2026-05-19：新增两条定向测试先失败，确认覆盖当前问题。
- 2026-05-19：`swift test --package-path Packages/LangoTraceUI --filter PremiumUIBehaviorTests/iPadWorkspaceBarKeepsUtilityActionsAndKeyboardShortcutsReachable` 通过。
- 2026-05-19：`swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests/padLearningPanelKeepsContentAwayFromTrailingEdge` 通过。
- 2026-05-19：`swift test --package-path Packages/LangoTraceUI` 通过，88 tests / 15 suites。
- 2026-05-19：`swiftlint --no-cache` 通过，0 violations。
- 2026-05-19：`swiftformat --lint . --cache ignore` 通过，0/102 files require formatting。
- 2026-05-19：`git diff --check` 通过。
- 2026-05-19：文档占位符扫描无命中。

## 后续复查

- 2026-05-19：用户复查最新 iPad 模拟器后确认右侧内容块仍贴近屏幕右边。原因是本方案只调整了 `PadLearningPanelView` 内部 padding，没有在 `PadMainView` 的右侧面板容器外层预留 gutter。复修见 `docs/plans/done/2026-05-19-bug-ipad-right-panel-outer-gutter-followup.md`。
