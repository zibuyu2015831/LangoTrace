# iPad 右侧面板外侧留白复修方案

Status: Verified

Type: bug

Created: 2026-05-19

Last Updated: 2026-05-19

## 用户确认记录

- 2026-05-19：用户在最新 iPad 模拟器截图中指出右侧边栏内部内容块仍然和屏幕右边紧贴，没有间距。

## 复查结论

上一轮修复已生效：顶部设置齿轮被移除，右侧面板按钮已移动到顶部最右侧。截图说明当前不是旧构建问题。

但上一轮只在 `PadLearningPanelView` 的 `ScrollView` 内容内增加 trailing padding。iPad 工作台的三栏 `HStack` 仍把整个右侧面板放到窗口最右边，导致在设备圆角和安全边界附近，卡片右侧仍表现为贴边或被截断。

根因：留白放错层级。需要在 `PadMainView` 的右侧面板容器外侧增加 trailing gutter，而不是只调整右侧面板内部内容 padding。

## 设计结论

- 保留 `PadLearningPanelView` 内部不对称 padding，用于内容和面板滚动区域之间的基础间距。
- 在 `PadMainView` 中对 `learningPanel` 增加外侧 trailing padding，让整个右栏离窗口右边界保持稳定距离。
- 同步调整右侧面板手势区域的宽度计算，避免因为外侧 gutter 造成右栏显示状态下的滑动判定偏差。
- 不改变 `padInspectorWidth`，不重新分配三栏架构，不缩小卡片内部文字。

## 涉及代码文件

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

## 验证方案

1. `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests/padLearningPanelKeepsContentAwayFromTrailingEdge`
2. `swift test --package-path Packages/LangoTraceUI`
3. `swiftlint --no-cache`
4. `swiftformat --lint . --cache ignore`
5. `git diff --check`
6. `scripts/verify.sh`

## 实施记录

- 2026-05-19：`PageClosureStateTests.padLearningPanelKeepsContentAwayFromTrailingEdge` 增加 `PadMainView` 外侧 gutter 断言，先失败确认当前问题。
- 2026-05-19：`PadMainView` 为 `learningPanel` 增加 `24pt` trailing 外侧留白。
- 2026-05-19：`PadMainView` 增加 `learningPanelGestureStartX(workspaceWidth:)`，右侧面板显示时的滑动手势起点同步扣除外侧 gutter。

## 验证记录

- 2026-05-19：`swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests/padLearningPanelKeepsContentAwayFromTrailingEdge` 先失败后通过。
- 2026-05-19：`swift test --package-path Packages/LangoTraceUI` 通过，88 tests / 15 suites。
- 2026-05-19：`swiftlint --no-cache` 通过，0 violations。
- 2026-05-19：`swiftformat --lint . --cache ignore` 通过，0/102 files require formatting，161 files skipped。
- 2026-05-19：`git diff --check` 通过。
- 2026-05-19：文档占位符扫描无命中。
- 2026-05-19：`scripts/verify.sh` 通过，包含 XcodeGen、Core/Data/UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位符扫描。
