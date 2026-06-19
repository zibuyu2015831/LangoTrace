# 任务方案：Mac Welcome 标题与卡片适配微调

状态：Done
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

2026-05-19：用户基于 Mac Welcome 截图指出主标题拆成三行不美观，示例卡片右侧显示不全，要求调用专业 skill 对 Mac welcome 页进行微调和完善；建议缩减示例卡片宽度。

## 1. 需求描述

在不改变 Welcome 内容模型和 iPad / iPhone 布局的前提下，继续微调 macOS wide Welcome 页面，使左侧主标题更接近两行呈现，右侧示例卡片完整落在窗口可视区域内，并保持两列之间的紧凑关系。

## 2. 现状描述

- macOS wide 上一轮将左列设为约 560pt，中文主标题在截图窗口中被拆成三行。
- macOS preview card 宽度提升到 `760...900pt`，在截图窗口中右侧内容被窗口裁切。
- 两列间距已经收紧，但总舞台宽度与卡片宽度组合仍超过部分 Mac 窗口的舒适可视范围。

## 3. 目标

- Mac 中文主标题在常见宽窗口下避免拆成三行，优先呈现为两行附近的阅读节奏。
- Mac 示例卡片宽度收敛，避免右侧裁切。
- Mac 页面仍比 iPad 横屏更有桌面尺度，不回退到小卡片。
- iPad 横屏、iPad 竖屏和 iPhone compact 布局不受本次调整影响。

## 4. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`
- `docs/plans/done/2026-05-19-feature-mac-welcome-title-card-fit.md`

## 5. 不做什么

- 不修改 Welcome 卡片示例内容、难度顺序或本地化文案。
- 不修改 iPad 或 iPhone 布局 helper。
- 不实现真实 AI、TTS、录音、语音转文本、持久化或权限。
- 不新增截图自动化。

## 6. 证据与决策依据

- 用户截图显示 Mac 主标题被强制拆为三行，左列视觉重心过高且节奏笨重。
- 用户截图显示右侧示例卡片延伸到窗口外，说明上一轮卡片宽度上限对当前窗口过大。
- macOS 欢迎页应充分利用桌面宽度，但不能以裁切内容为代价；欢迎首屏信息必须完整可读。

## 7. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`

## 9. 涉及的文档路径

- `docs/plans/done/2026-05-19-feature-mac-welcome-title-card-fit.md`
- `docs/plans/done/2026-05-19-feature-welcome-stage-balance.md`

## 10. 实施方案

1. 先更新 `WelcomeHomeOptimizationTests`，断言 Mac wide 左列增宽、卡片宽度收敛、总内容宽度不再过度扩张，并确认 iPad card range 仍保持原值。
2. 调整 `WelcomeView` 的 macOS helper：提高 `macLeadingColumnWidth`，下调 `macPreviewCardWidth` 上限和比例，收敛 `macContentMaxWidth`。
3. 运行 `swift test --package-path Packages/LangoTraceUI`，再运行 `git diff --check` 和 `scripts/verify.sh`。
4. 验证通过后将本方案移动到 `docs/plans/done/` 并记录结果。

## 11. 复查方法

- Mac 宽窗口中标题不再明显被拆成三行。
- Mac 示例卡片完整显示在窗口内。
- Mac 左右两列距离仍保持紧凑，没有恢复到大面积中间空白。
- iPad / iPhone 源码 helper 与测试期望未被本次 Mac 微调污染。

## 12. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
git diff --check
scripts/verify.sh
```

## 13. 文档影响检查

本任务只调整 Welcome 页面 macOS wide 视觉布局，不改变产品北极星、AI Provider、权限、数据、同步、StoreKit 或发布策略，因此不新增 ADR 或长期 spec。

## 14. 实施记录

2026-05-19：创建方案，准备按 TDD 先更新 Mac 布局结构测试。

2026-05-19：已先更新 `WelcomeHomeOptimizationTests`，新增 Mac wide 可视窗口适配断言，并确认旧的 `min(max(size.width * 0.48, 760), 900)` 卡片宽度策略会导致测试失败。

2026-05-19：已调整 `WelcomeView` macOS wide helper：窗口内容先对齐到 `size.width` 再居中，宽窗口左列提高到 660pt，中等窗口左列提高到 600pt；右侧示例卡片收敛为 720pt / 600pt / 540pt 三档，避免继续使用 900pt 上限造成裁切。

2026-05-19：验证通过：

- `swift test --package-path Packages/LangoTraceUI`
- `git diff --check`
- `scripts/verify.sh`

`scripts/verify.sh` 报告 4 个非 serious SwiftLint warning：`WelcomeHomeOptimizationTests.swift` file length 与 type body length、`WelcomeView.swift` file length 与 type body length。它们是当前 Welcome 测试/视图体量问题，不阻断本轮验证。

## 15. 完成标准

- Mac wide helper 测试覆盖标题列增宽和卡片宽度收敛。
- `WelcomeView` Mac wide 布局完成调整。
- 指定验证命令通过。
- 方案移动至 `docs/plans/done/`。

## 16. 剩余风险

- 本轮仍以源码测试和人工截图复查为主，不新增自动视觉回归截图。
