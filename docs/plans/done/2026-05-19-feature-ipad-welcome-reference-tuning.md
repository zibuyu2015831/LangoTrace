# 任务方案：iPad Welcome 参考图视觉校准

状态：Verified
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

2026-05-19：用户提供 iPad Welcome 参考图，并指出当前 iPad 端效果仍显得内容偏小、舞台偏上方零散，需要参考图片样式继续优化 iPad 端。

## 1. 需求描述

集中优化 iPad 端首次打开 Welcome 页面，让横屏 regular width 布局更接近参考图：左右主元素更大、更靠近、整体舞台更早进入视线，减少顶部和底部大面积空白。

## 2. 现状描述

- 当前 iPad wide layout 已使用左右分栏，但 `wideStageTopPadding` 在高屏幕上为 `148pt`，导致内容整体偏低，首屏上方空白过大。
- iPad card 仍使用默认 expanded carousel 高度 `388pt`，视觉解释力弱于参考图。
- 左右列间距和内容上限延续了上一轮保守设计，和参考图相比元素不够饱满。
- 当前 macOS 已有专属 wide 分支；本任务只调整非 macOS wide 分支，不改变 Mac 专属尺寸策略。

## 3. 目标

- iPad 横屏 Welcome stage 更接近参考图：标题、按钮、预览卡在首屏中部形成一组，而不是偏小地散在页面上方。
- 缩小 iPad 左右列间距，提高 card 和左侧价值主张的视觉权重。
- iPad expanded 预览卡略增高，并用 section 分隔提升阅读层级。
- 保持 iPhone compact 结构不变。
- 保持 macOS wide helper 不受本轮 iPad 调整影响。

## 4. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`

## 5. 不做什么

- 不实现真实拍照、AI、TTS、录音、语音转文本、评分、持久化或同步。
- 不改变 Welcome 文案语义和三端共享副标题 key。
- 不调整 macOS 专属 welcome layout。
- 不改首次启动路由。

## 6. 证据与决策依据

- 用户截图显示 iPad 当前效果已经加载到新副标题和新卡片内容，但整体视觉仍偏稀疏，和参考图的“中部舞台 + 较大卡片”不一致。
- `WelcomeView.swift` 中 macOS 与非 macOS wide layout 已经分支，本轮可以只改 iPad regular width 的 helper。
- 参考图的核心不是复原旧“词汇 / 表达 / 练习”内容，而是借鉴其舞台比例、卡片体量和 section 层级。

## 7. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`

## 9. 涉及的文档路径

- `docs/plans/active/2026-05-19-feature-ipad-welcome-reference-tuning.md`
- `docs/plans/done/2026-05-19-feature-ipad-welcome-page-design.md`
- `docs/plans/done/2026-05-19-feature-mac-welcome-card-content.md`

## 10. 实施方案

1. 先更新 `WelcomeHomeOptimizationTests`，断言 iPad wide layout 有专属 card 高度、较小 top padding、较紧列间距和不会复用 Mac card 尺寸。
2. 调整非 macOS `wideContent`，给 iPad expanded carousel 传入 `iPadPreviewCardContentHeight(in:)`。
3. 调整 iPad wide helper：降低 top padding、减少列间距、减少水平 padding、略放大卡片宽度和高度。
4. 在 expanded preview section 之间加入细分隔线，参考图片的卡片阅读层级，但保留“我的随笔 / 改写 / 配音 / 跟读”新内容模型。
5. 运行 UI package 测试、格式检查和必要构建验证。

## 11. 复查方法

- iPad 13 英文和中文横屏下，内容不再显著偏小或偏下。
- 左侧标题、副标题、badge、CTA 与右侧卡片形成同一水平舞台。
- iPhone compact 仍使用 bottom safe area CTA 和 compact card。
- macOS wide helper 的 `macPreviewCardWidth`、`macContentMaxWidth`、`macHorizontalSpacing` 不因本任务改变。

## 12. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
git diff --check
scripts/verify.sh
```

## 13. 文档影响检查

本任务是 Welcome 页面 iPad 视觉校准，不改变产品北极星、AI Provider、权限、数据、同步、StoreKit 或发布策略，因此不新增 ADR 或长期 spec。

## 14. 实施记录

2026-05-19：创建方案，准备按 TDD 更新 iPad wide layout 结构测试。

2026-05-19：按 TDD 先更新 `WelcomeHomeOptimizationTests`，新增 iPad reference stage 和 expanded card divider 结构断言。首次运行 `swift test --package-path Packages/LangoTraceUI` 按预期失败，失败点为 iPad wide layout 仍使用旧 top padding、旧列距、旧 card range，且 expanded card 缺少 section divider。

2026-05-19：完成实现：

- `WelcomeView.swift` 的非 macOS wide layout 给 `WelcomeTracePreviewCarousel` 传入 `iPadPreviewCardContentHeight(in:)`，iPad expanded card 高度提高到 `452 / 420pt`。
- iPad wide top padding 从 `148 / 86pt` 收敛到 `92 / 64pt`，减少首屏上方空白。
- iPad wide 左右列间距从 `88 / 56pt` 收紧到 `56 / 44pt`，水平 padding 从 `64 / 48pt` 收紧到 `40 / 32pt`。
- iPad card width 从 `460...560pt` 调整为 `500...580pt`，CTA 宽屏上限从 `360pt` 提升到 `380pt`，左侧标题字号从 `42pt` 提升到 `46pt`。
- `WelcomeTracePreviewCarousel.swift` 为 expanded card 增加 `PreviewSectionDivider`，保留新的“我的随笔 / 改写 / 配音 / 跟读”内容模型，同时参考图中的分段阅读层级。
- macOS wide helper 未改变，仍使用 `macPreviewCardContentHeight(in:)`、`macPreviewCardWidth(in:)` 和 Mac 专属 spacing。

2026-05-19：根据用户补充的 iPad 竖屏参考图继续优化：

- `WelcomeView.swift` 新增 `usesPadPortraitLayout(in:)` 和 `padPortraitContent(size:)`，iPad regular width 竖屏不再走横屏双列，也不再退回 iPhone compact card。
- iPad 竖屏改为单列展开布局：品牌、标题、副标题、badge、expanded 示例卡、page indicator 和 CTA 按参考图纵向排列。
- iPad 竖屏 preview card 宽度为 `min(size.width - 144, 640)`，expanded card 内容高度为 `430 / 400pt`，CTA 与卡片等宽。
- iPad 横屏 wide 通过 `iPadAllowsWideLayout(in:)` 限定为 `size.width > size.height`，避免竖屏硬塞左右分栏。
- iPhone compact 仍保留 bottom safe area CTA 和 compact card。

验证记录：

- `swift test --package-path Packages/LangoTraceUI`：通过，64 个 Swift Testing 测试通过。
- `swiftformat Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift --cache ignore`：通过，0 个文件格式化。
- `git diff --check`：通过。
- `scripts/verify.sh`：通过，覆盖 XcodeGen、Core / Data / UI package 测试、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位符扫描。SwiftLint 保留 3 个非严重 warning：`WelcomeHomeOptimizationTests` 结构体体量超过 250 行、`WelcomeView.swift` 超过 400 行、`WelcomeView` 结构体体量超过 250 行，脚本退出码为 0。
- iPad Pro 13-inch (M5) 模拟器已重装并启动最终 `Debug-iphonesimulator/LangoTrace.app`，竖屏截图保存到 `/private/tmp/langotrace-ipad-portrait-final.png`。

## 15. 完成标准

- iPad wide layout 的源码测试覆盖新尺寸边界。
- iPad wide 视觉 helper 与 macOS helper 明确分离。
- UI package 测试通过。
- 完成后移动本方案到 `docs/plans/done/` 并记录验证结果。

## 16. 剩余风险

- 本任务以源码结构测试和模拟器人工复查为主，不新增自动截图对比。
