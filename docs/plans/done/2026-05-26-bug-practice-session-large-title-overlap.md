# 任务方案：修复单句练习页播放后 large title 覆盖内容

状态：Done
类型：bugfix
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户反馈

2026-05-26：用户在 iPhone 17 模拟器截图中反馈，初次点击 `听` 播放后，页面左上出现大号 `练习`，覆盖句子内容卡。

## 2. 根因

`PracticeSessionView` 只设置了 `.navigationTitle(localizedText("practice.title"))`，没有在 iOS 上固定 `.inline` 标题模式。播放触发状态刷新后，SwiftUI NavigationStack 可能把该 detail 页恢复为 large title，导致大号标题进入内容区域并压住正文卡。

## 3. 修复

- 在 `PracticeSessionView` 上增加 `langoPracticeInlineNavigationTitle()`。
- 该 helper 仅在 iOS 调用 `navigationBarTitleDisplayMode(.inline)`，macOS / 其他平台返回 `self`，避免 shared SwiftUI 文件在 macOS 编译失败。
- 增加 `PhoneIOSConvergenceTests.practiceSessionKeepsInlineNavigationTitleDuringPlaybackUpdates`，用源代码级回归测试锁定练习页必须显式使用 inline title helper。

## 4. 验证

- 红灯：新增测试后，缺少 inline title helper 时失败。
- 绿灯：添加 iOS-only helper 后，`swift test --package-path Packages/LangoTraceUI --filter 'PhoneIOSConvergenceTests/practiceSessionKeepsInlineNavigationTitleDuringPlaybackUpdates'` 通过。
