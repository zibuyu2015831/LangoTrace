# 任务方案：Welcome 舞台位置与桌面间距再平衡

状态：Done
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

2026-05-19：用户指出 iPad 横屏版元素整体偏上，建议上下左右居中；同时指出 Mac 端左右元素间距仍过大，中间空白明显，可以缩短间距并放大各元素，充分利用界面空间。

## 1. 需求描述

继续优化 Welcome 页面在 iPad 横屏和 macOS wide 窗口中的空间分配。iPad 横屏应更像居中的舞台，而不是靠上排列；Mac 端需要进一步缩短左右列距离，并放大标题、CTA 和预览卡，降低中间空白感。

## 2. 现状描述

- iPad 横屏 `wideContent` 外层仍以 `.top` 对齐，且保留 top padding，导致内容偏上。
- macOS wide 已有专属 helper，但在大窗口下左列与右卡之间仍显得疏离。
- macOS 标题、CTA、卡片虽已放大，但截图中仍有明显未利用的中间区域。

## 3. 目标

- iPad 横屏 Welcome stage 在窗口中上下左右居中。
- iPad 横屏不影响 iPad 竖屏单列布局和 iPhone compact 布局。
- Mac wide 左右列间距进一步缩短，内容最大宽度和卡片宽度提高，让桌面窗口更饱满。
- Mac CTA 和左侧标题同步略放大，形成与右侧卡片相当的主视觉。

## 4. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`
- `docs/plans/active/2026-05-19-feature-welcome-stage-balance.md`

## 5. 不做什么

- 不改变 Welcome 卡片内容模型和三张示例顺序。
- 不修改 `Localizable.xcstrings` 文案。
- 不实现真实 AI、TTS、录音、语音转文本、持久化或权限。
- 不改主界面、Onboarding 或首次启动路由。

## 6. 证据与决策依据

- 用户截图显示 iPad 横屏内容处于屏幕偏上区域，底部空白过大；横屏更适合以整体舞台居中。
- Mac 截图显示左右元素之间存在大片空白；当前早期 Welcome 页面应优先把首屏解释内容做清楚，而不是保留过多空白。

## 7. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`

## 9. 涉及的文档路径

- `docs/plans/active/2026-05-19-feature-welcome-stage-balance.md`
- `docs/plans/done/2026-05-19-feature-ipad-welcome-reference-tuning.md`
- `docs/plans/done/2026-05-19-feature-mac-welcome-card-content.md`

## 10. 实施方案

1. 更新 `WelcomeHomeOptimizationTests`，断言 iPad 横屏 outer stage 使用 center alignment，top/bottom padding 收敛为 0，并覆盖 Mac 新间距/尺寸。
2. 调整 iPad 横屏 `wideContent`：去掉垂直偏上 padding，将外层 `frame(minHeight: size.height)` 改为 center alignment。
3. 调整 Mac helper：缩短 `macHorizontalSpacing`，增加 `macContentMaxWidth`、`macPreviewCardWidth`、`macPreviewCardContentHeight` 和 `macCTAMaxWidth`。
4. 运行 UI package 测试、格式检查、`git diff --check` 和完整 `scripts/verify.sh`。

## 11. 复查方法

- iPad 横屏中左列和右卡整体处于屏幕中部，不再明显贴近上方。
- iPad 竖屏仍是单列 expanded card。
- Mac wide 中左列与右卡距离明显缩短，右卡更大，左侧 CTA 更宽。
- iPhone compact 不受影响。

## 12. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
git diff --check
scripts/verify.sh
```

## 13. 文档影响检查

本任务只调整 Welcome 页面视觉布局，不改变产品北极星、AI Provider、权限、数据、同步、StoreKit 或发布策略，因此不新增 ADR 或长期 spec。

## 14. 实施记录

2026-05-19：创建方案，准备按 TDD 添加布局结构回归测试。

2026-05-19：已更新 `WelcomeHomeOptimizationTests`，先覆盖 iPad 横屏 centered stage、Mac 更紧凑更大的桌面舞台尺寸，以及 SwiftFormat 后 helper 签名的稳定断言。

2026-05-19：已调整 `WelcomeView`：iPad 横屏 `wideContent` 改为全屏居中舞台，top/bottom stage padding 收敛为 0；macOS wide 分支缩短左右列间距，扩大内容最大宽度、左列、右侧预览卡、卡片内容高度和 CTA 宽度，并将 Mac 标题提升到 64pt。

2026-05-19：验证通过：

- `swift test --package-path Packages/LangoTraceUI`
- `git diff --check`
- `scripts/verify.sh`

`scripts/verify.sh` 仍报告 3 个非 serious SwiftLint warning：`WelcomeHomeOptimizationTests` type body length、`WelcomeView.swift` file length、`WelcomeView` type body length。它们是当前 Welcome 测试/视图体量问题，本轮未新增阻断级 lint 失败。

## 15. 完成标准

- iPad 横屏 centered stage 的结构测试已通过。
- Mac spacing 和尺寸 helper 的结构测试已通过。
- `scripts/verify.sh` 已通过。

## 16. 剩余风险

- 本任务以源码测试和模拟器人工复查为主，不新增自动截图对比。
