# 任务方案：Mac 首次打开 Welcome 页面优化

状态：Implemented
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

2026-05-19：用户要求开始进行 Mac 端 Welcome 页面优化，参考用户提供的 Mac 窗口截图，并明确副标题保持前面已经讨论确认的版本：

```text
拍照、随笔、录音，语迹会帮你整理成表达和练习
```

## 1. 需求描述

优化首次打开 App 时 macOS 端的 Welcome 页面。视觉参考为一个居中的 Mac 窗口：左侧是品牌、标题、副标题、状态 badge 和主 CTA，右侧是语迹预览卡。页面需要保持安静、现代、克制的桌面质感。

本任务只优化 Mac 端 Welcome 的布局承载，不改变副标题文案，不实现真实拍照、随笔、录音、AI、TTS、同步、数据库或权限能力。

## 2. 现状描述

- `WelcomeView.swift` 当前使用 `usesWideLayout(in:)` 将 iPad 横屏和 Mac 宽窗口归入同一 wide layout。
- wide layout 已有左右分栏和预览卡，但 CTA 位于左右分栏下方居中，和参考图中“CTA 属于左侧叙事”的结构不一致。
- `welcome.valueSubtitle` 已在上一轮更新为三端共享的新副标题，并覆盖 `en / zh-Hans / es / ja / fr / de / ko / ru`。
- `WelcomeTracePreviewCarousel.swift` 已有三张静态示例卡和分页，不自动轮播。

## 3. 目标

- Mac 宽窗口使用参考图结构：左侧叙事列内包含品牌、标题、副标题、状态 badge 和 CTA；右侧展示完整预览卡。
- 副标题继续使用共享的 `welcome.valueSubtitle`，不新增 Mac 专用副标题 key。
- Mac 布局要比 iPad 横屏更像桌面窗口：整体最大宽度更克制，左右列比例稳定，CTA 不漂到整页中央。
- 窄 Mac 窗口继续走现有 compact / safe area 结构，不破坏 iPhone 和 iPad。
- 预览卡继续是静态示例，不触发真实能力。

## 4. 范围

- 修改 `WelcomeView.swift` 中 wide layout 的 Mac 分支或 Mac 尺寸策略。
- 如有必要，微调 `WelcomeTracePreviewCarousel.swift` 的 expanded 卡片高度或宽度承载，但不改变 carousel 行为。
- 更新 `WelcomeHomeOptimizationTests.swift`，新增 Mac Welcome 布局测试。
- 更新本方案实施记录并完成验证。

## 5. 不做什么

- 不改 `welcome.valueSubtitle` 文案。
- 不新增 `welcome.valueSubtitle.mac` 或其他平台专用副标题 key。
- 不实现真实拍照、随笔、录音、权限弹窗、AI 请求、TTS、同步或持久化。
- 不改变首次启动路由。
- 不调整已创建语言空间后的 Mac 工作台。
- 不新增 ADR。

## 6. 涉及文件

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`
- `docs/plans/active/2026-05-19-feature-mac-welcome-page-optimization.md`

## 7. 设计方案

Mac 宽窗口采用桌面舞台布局：

- 背景继续使用现有纸面色，避免营销式装饰。
- 内容最大宽度控制在约 `1040-1080pt`，在大窗口中居中。
- 左列宽度约 `420pt`，包含品牌、主标题、副标题、badge、CTA。
- 右列宽度约 `500-540pt`，展示 expanded 预览卡。
- CTA 与左列绑定，左对齐或在左列内居中，不再放在整页左右分栏下方。
- 窗口高度不足时保留滚动能力，避免文字和卡片重叠。

## 8. 测试方案

新增或更新 `WelcomeHomeOptimizationTests.swift`：

- 断言 `WelcomeView.swift` 存在 macOS 条件布局分支。
- 断言 Mac wide layout 使用独立方法，例如 `macWideContent(size:)`。
- 断言 Mac CTA 位于左列内部，例如 `macLeftColumn(size:)` 中调用 `bottomActionArea(maxButtonWidth: macCTAMaxWidth(in: size), centersInAvailableWidth: false)`。
- 断言 Mac 继续使用 `WelcomeTracePreviewCarousel(isExpanded: true)`。
- 断言 Mac 不新增平台专用副标题 key。

## 9. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
scripts/verify.sh
```

## 10. 文档影响检查

本任务只优化首次打开 Welcome 页面在 macOS 上的布局承载，不改变产品北极星、首次启动路由、语言空间模型、AI Provider、权限、同步、StoreKit 或发布策略，因此不新增 ADR。

完成后将本方案移入 `docs/plans/done/`，并记录实际验证结果。

## 11. 实施记录

2026-05-19：创建方案，记录 Mac Welcome 页面参考图目标、共享副标题边界、实现范围和验证方式。

2026-05-19：完成 Mac Welcome 布局落地：

- `WelcomeView.swift` 在 wide layout 中增加 `#if os(macOS)` 分支，Mac 宽窗口使用 `macWideContent(size:)`。
- Mac 宽窗口左列新增 `macLeftColumn(size:)`，品牌、主标题、副标题、状态 badge 和 CTA 归属同一叙事列。
- Mac CTA 使用 `bottomActionArea(maxButtonWidth: macCTAMaxWidth(in: size), centersInAvailableWidth: false)`，不再漂到整页底部中央。
- 右侧继续使用 `WelcomeTracePreviewCarousel(isExpanded: true)`，保持静态示例卡和分页。
- 副标题继续使用共享 `welcome.valueSubtitle`，未新增 Mac 专用副标题 key。

测试记录：

- 先新增 `macWelcomeWideLayoutBindsCTAtoLeftNarrativeColumn` 测试并运行 `swift test --package-path Packages/LangoTraceUI`，按预期失败，失败点为缺少 macOS 条件分支、`macWideContent(size:)`、`macLeftColumn(size:)` 和左列 CTA。
- 实现 Mac 分支后再次运行 `swift test --package-path Packages/LangoTraceUI`，55 个测试通过。
- 初次运行 `scripts/verify.sh` 时，SwiftFormat lint 发现 `WelcomeView.swift` 新增 `#if os(macOS)` 区块缩进不符合项目格式；随后运行 SwiftFormat 修正。
- 为消除 SwiftLint 非阻塞 warning，将 Mac 专属布局和尺寸 helper 移入同文件的 `private extension WelcomeView`，并拆分测试中的长行。
- 局部复查 `swiftlint --no-cache Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift` 通过，0 violations。
- 局部复查 `swiftformat --lint Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift --cache ignore` 通过，0 files require formatting。
- 最终运行 `scripts/verify.sh` 通过：XcodeGen、Core / Data / UI 包测试、iPhone / iPad / macOS build、SwiftLint、SwiftFormat 和文档占位符扫描均通过。

## 12. 完成标准

- Mac Welcome 宽窗口 CTA 归属左侧叙事列，不再作为整页居中下方按钮。
- Mac Welcome 右侧保留 expanded 语迹预览卡。
- 副标题保持 `welcome.valueSubtitle` 共享 key，不新增 Mac 专用副标题。
- iPhone / iPad 现有 Welcome 布局测试继续通过。
- `swift test --package-path Packages/LangoTraceUI` 通过。
- 收口前运行 `scripts/verify.sh`，或说明不能运行的原因和剩余风险。
