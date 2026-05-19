# 任务方案：Mac Welcome 样式与语迹卡片内容优化

状态：Verified
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

2026-05-19：本轮按已确认方案实施。副标题不含“录音”；Welcome 卡片不再以“词汇 / 表达 / 练习”为主轴，改为表达语迹核心闭环：用户随笔或照片线索 -> 目标语言改写 -> 配音 -> 跟读。

## 1. 需求描述

把 Mac Welcome 从右侧偏小的预览卡升级为更有产品解释力的桌面欢迎页，同时重做 Welcome 示例卡内容，使默认首屏准确表达“用生活记录学习语言”的核心路径。

## 2. 现状描述

- `WelcomeView.swift` 已有 macOS wide 分支，但右侧卡片尺寸仍偏克制。
- `WelcomeTracePreviewCarousel.swift` 仍使用 `vocabularyKey / expressionKey / practiceKey` 字段，卡片主轴偏向词汇和练习列表。
- `Localizable.xcstrings` 已覆盖 `en / zh-Hans / es / ja / fr / de / ko / ru`，但 Welcome 示例 key 仍沿用 vocabulary / expression / practice 命名。

## 3. 目标

- Mac 宽窗口右侧卡片成为和左侧标题同等级的主视觉。
- iPad 横屏保持现有宽屏结构和 `460...560pt` 卡片宽度，不被 Mac 尺寸策略污染。
- Welcome 示例卡改为四段闭环：我的随笔、改写、配音、跟读。
- 三张示例按学习难度排序，iPhone、iPad 和 macOS 共用同一顺序：咖啡店入门、通勤进阶、工作会议高阶。
- 全部新增或替换文案覆盖 8 种界面语言，且不承诺音频输入、录音、语音转文本或真实播放能力。

## 4. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`

## 5. 不做什么

- 不实现真实 AI、TTS、录音、语音转文本、评分、权限请求、持久化或同步。
- 不改变首次启动路由。
- 不新增 Mac 专用副标题 key。
- 不修改已进入主界面后的 macOS 工作台。
- 不新增 ADR。

## 6. 证据与决策依据

- `docs/README.md` 将语迹定位为“把真实生活变成外语学习材料”的本地优先语言学习 App。
- Welcome 首屏需要帮助用户快速理解生活记录如何变成学习材料，而不是提前强调词汇列表。
- 当前仍是早期 SwiftUI 产品骨架，卡片可作为静态产品解释，不代表真实 AI/TTS/录音已接入。

## 7. 实施方案

1. 先更新 `WelcomeHomeOptimizationTests`，覆盖字段命名、section key、示例内容、8 语言覆盖和 Mac/iPad 尺寸边界。
2. 将 `WelcomeTraceExample` 字段改为 `sourceNoteKey / rewrittenTextKey / audioCueKey / shadowingCueKey`。
3. 将卡片 section key 改为 `sourceNoteTitle / rewrittenTextTitle / audioCueTitle / shadowingCueTitle`，中文分别为 `我的随笔 / 改写 / 配音 / 跟读`。
4. 将示例顺序调整为 cafe、commute、meeting，使 iPhone、iPad 和 macOS 都按入门到高阶展示。
5. 调整 Mac wide helper：`macContentMaxWidth` 约 `1180...1280pt`，`macPreviewCardWidth` 约 `580...660pt`，`macPreviewCardMinHeight` 约 `460...520pt`。
6. 补齐 `Localizable.xcstrings` 新 key 的 8 语言文案，并移除旧卡片主模型 key 的代码引用。

## 8. 复查方法

- 检查 Swift 源码不再引用 `vocabularyKey / expressionKey / practiceKey`。
- 检查 String Catalog 中新 key 覆盖 8 种界面语言。
- 检查中文 section 标题为 `我的随笔 / 改写 / 配音 / 跟读`。
- 检查 Welcome 副标题和卡片文案不含录音、音频输入、语音转文本承诺。
- 检查 Mac 和 iPad 尺寸 helper 分离。

## 9. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
git diff --check
scripts/verify.sh
```

## 10. 文档影响检查

本任务只调整 Welcome 静态说明卡和 macOS Welcome 视觉比例，不改变产品北极星、AI Provider、TTS、权限、同步、StoreKit、数据库或发布策略，因此不新增 ADR 或长期 spec。任务完成后在本方案记录验证结果，并移入 `docs/plans/done/`。

## 11. 实施记录

2026-05-19：创建方案，记录本轮确认边界和 TDD 验证范围。

2026-05-19：按 TDD 先更新 `WelcomeHomeOptimizationTests`，首次运行 `swift test --package-path Packages/LangoTraceUI` 按预期失败，失败点集中在旧字段 `vocabularyKey / expressionKey / practiceKey`、旧 section key、旧示例顺序和 Mac 卡片尺寸。

2026-05-19：完成实现：

- `WelcomeTracePreviewCarousel.swift` 将卡片模型改为 `sourceNoteKey / rewrittenTextKey / audioCueKey / shadowingCueKey`。
- 默认示例顺序调整为工作会议、咖啡店、通勤；该顺序已在后续反馈中被难度排序取代。
- compact 卡片展示我的随笔、改写主句和跟读提示；expanded 卡片展示我的随笔、改写、配音、跟读四段。
- `Localizable.xcstrings` 补齐新 section key 和三张示例卡新内容的 `en / zh-Hans / es / ja / fr / de / ko / ru` 覆盖。
- `WelcomeView.swift` 将 macOS wide 右侧卡片宽度提升到约 `580...660pt`，最小高度提升到约 `460...500pt`，并保持 iPad 卡片宽度 `460...560pt` 不变。

验证记录：

- `swift test --package-path Packages/LangoTraceUI`：通过，58 个 Swift Testing 测试通过。
- `git diff --check`：通过，无空白错误。
- `swiftlint --no-cache Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`：退出码 0；剩余 1 个非严重 warning，为 `WelcomeHomeOptimizationTests` 结构体体量超过 250 行。
- `swiftformat --lint Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift --cache ignore`：通过，0 个文件需要格式化。
- `scripts/verify.sh`：通过，覆盖 XcodeGen、Core / Data / UI package 测试、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位符扫描。SwiftLint 同样报告上述非严重体量 warning，但脚本退出码为 0。

2026-05-19：根据截图反馈继续优化示例卡内容：

- 移除 expanded 卡片顶部重复展示的随笔正文，随笔只保留在“我的随笔”section。
- 为三张示例增加难度标签：咖啡店为“入门 · 点单短句”，通勤为“进阶 · 通勤说明”，工作会议为“高阶 · 会议表达”。
- 三端共用的 Welcome carousel 顺序调整为咖啡店、通勤、工作会议，确保 iPhone compact、iPad wide 和 macOS wide 都按难度等级展示。
- 将“配音 / 跟读”从泛化状态说明改为可执行练习提示，例如重读关键词、按意群跟读、替换关键词复述。
- 保持 Welcome 示例仍为静态解释卡，不实现真实 TTS、播放、录音、评分或语音转文本。

补充验证记录：

- `swift test --package-path Packages/LangoTraceUI`：通过，60 个 Swift Testing 测试通过。
- `swiftlint --no-cache Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeTracePreviewContentTests.swift Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`：通过，0 violations。
- `scripts/verify.sh`：通过，覆盖 XcodeGen、Core / Data / UI package 测试、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位符扫描。

2026-05-19：根据后续反馈确认三张卡必须按难度等级排序，并同步到 iOS 与 iPad：

- `WelcomeTracePreviewCarousel.swift` 的共享示例数组改为 `cafe -> commute -> meeting`。
- `WelcomeHomeOptimizationTests` 断言示例顺序必须从入门到高阶，并确认没有新增 iPhone/iPad 平台专用 carousel 分叉。

补充验证记录：

- `swift test --package-path Packages/LangoTraceUI`：通过，60 个 Swift Testing 测试通过。
- `git diff --check`：通过。
- `scripts/verify.sh`：通过，覆盖 iPhone 17 build、iPad Pro 13-inch (M5) build 和 macOS arm64 build。

2026-05-19：根据 Mac 截图反馈继续调整桌面欢迎页空间利用：

- macOS wide 左列改为 `macValueBlock`，标题和副标题字号相对 iPad wide 放大。
- macOS wide 内容舞台上限从 `1280pt` 提高到 `1520pt`，降低左右列间距，减少大窗口中的空白感。
- macOS wide 右侧卡片宽度范围提高到约 `680...820pt`，卡片内容高度可由 Mac 单独传入。
- `WelcomeTracePreviewCarousel` 增加可选 `expandedCardHeight`，iPad 仍使用默认 `388pt` expanded card height，避免 Mac 视觉优化污染 iPad。

补充验证记录：

- `swift test --package-path Packages/LangoTraceUI`：通过，60 个 Swift Testing 测试通过。
- `git diff --check`：通过。
- `scripts/verify.sh`：通过，覆盖 XcodeGen、Core / Data / UI package 测试、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位符扫描。

2026-05-19：根据后续反馈继续缩小 Mac 端左右间距：

- macOS wide 左右列间距从 `48 / 40pt` 收紧到 `32 / 28pt`。
- macOS wide 舞台水平 padding 从 `48 / 36pt` 收紧到 `40 / 32pt`。
- iPhone 和 iPad 布局 helper 未改变。

补充验证记录：

- `swift test --package-path Packages/LangoTraceUI`：通过，60 个 Swift Testing 测试通过。
- `swiftformat Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift --cache ignore`：通过，0 个文件格式化。
- `git diff --check`：通过。
- `scripts/verify.sh`：通过，覆盖 XcodeGen、Core / Data / UI package 测试、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位符扫描。

2026-05-19：根据 iPhone / iPad 截图复查 Welcome 副标题：

- 确认截图中的“录音”和旧卡片内容来自旧构建；当前 `Localizable.xcstrings` 中 `welcome.valueSubtitle` 的中文值已是“拍照、随笔，语迹会帮你整理成表达和练习”。
- 将 `WelcomeView` 中三处副标题直接调用收敛为单一 `welcomeSubtitleText` helper，iPhone compact、iPad wide 和 macOS wide 都复用同一个 `welcome.valueSubtitle` key。
- 增加回归测试，断言 Welcome 副标题只有一个 localization key 引用，且不存在 iPhone / iPad / Mac 专用副标题 key。

补充验证记录：

- `swift test --package-path Packages/LangoTraceUI`：通过，61 个 Swift Testing 测试通过。

## 12. 完成标准

- Welcome 示例卡采用四段闭环字段和标题。
- 默认首屏为入门级咖啡店示例，后续依次为进阶通勤和高阶工作会议。
- Mac 宽窗口右侧卡片尺寸提升，page indicator 贴近卡片底部。
- iPad 宽屏卡片尺寸仍保持 `460...560pt`。
- `swift test --package-path Packages/LangoTraceUI`、`git diff --check` 和 `scripts/verify.sh` 完成或明确说明未运行原因。

## 13. 剩余风险

- 本轮不做自动截图验收，Mac 视觉比例仍需后续人工截图复查。
