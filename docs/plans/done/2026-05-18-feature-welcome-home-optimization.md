# 任务方案：首页欢迎页体验优化

状态：Verified
类型：feature
创建日期：2026-05-18
最后更新日期：2026-05-18

## 用户确认记录

2026-05-18：用户回复“开始实施”，确认按本方案范围进入实现。

## 1. 需求或 bug 描述

根据 `docs/reference/lango_trace_首页优化方案.md`，优化首次打开 App 时的 Welcome / 首页体验，让用户在 5 秒内理解语迹是“把生活记录变成语言学习素材”的本地优先语言学习 App，并明确下一步会进入母语、目标语言和水平自评设置。

本任务不是新增真实 AI、真实记录、数据库或同步能力，而是改进欢迎页的信息架构、三端布局、示例预览、CTA 文案和能力状态表达。

## 2. 现状描述

当前 `WelcomeView` 是一个通用单列页面：

- 顶部品牌区显示 `LANGOTRACE` 和 `ProductIdentity.displayName`。
- 主 slogan 来自 `ProductIdentity.chineseSlogan` 与 `ProductIdentity.englishSlogan`。
- 状态标签显示 `本地优先 / 未配置 AI`。
- 下方 `entryBlock` 使用卡片承载 “今天记录一点生活”、首次使用说明、`继续` 按钮和本地说明。
- 页面 `frame(maxWidth: 640)` 适合 iPhone / 窄窗口，但 iPad 横屏会像放大的 iPhone 欢迎页。
- `Localizable.xcstrings` 已覆盖 `en / zh-Hans / es / ja / fr / de / ko / ru`，因此新增文案必须同步多语言 key，不能在 SwiftUI 源码中硬编码中文。

## 3. 目标

- 将首页叙事从“品牌展示”调整为“价值主张 + 轻量结果预览 + 开始设置”。
- 将 `未配置 AI` 改成用户价值语义 `AI 可选`，避免把工程状态作为欢迎页主标签。
- 将 CTA 从 `继续` 改为 `开始设置`，并说明 `首次设置约 30 秒 · 默认本地保存`。
- 新增轻量“今日语迹”示例卡，展示生活场景、词汇、表达和练习结果。
- iPhone 保持单列、底部 CTA、44pt 以上触控目标和安全区内布局。
- iPad regular width 使用左右分栏，左侧承载品牌/价值/CTA，右侧承载更完整的语言素材预览。
- macOS 窗口沿用宽屏分栏逻辑，但保持 Mac 可调整窗口、合适最小宽度、鼠标/键盘可访问和无移动端 Tab 化。
- 保持本地优先、AI 可选、不会自动发送数据的隐私边界。

## 4. 范围

- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`。
- 必要时新增 Welcome 相关私有子组件，例如 `WelcomeValueBlock`、`WelcomeTracePreviewCard`、`WelcomeCTASection`。
- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings` 中 Welcome 相关 key。
- 必要时微调 `LangoTraceDesign` 的颜色/半径/密度 token，但只允许服务 Welcome 页面，不做全局视觉重构。
- 更新或新增 `Packages/LangoTraceUI/Tests/LangoTraceUITests/` 下的 Welcome 文案、结构和 hard-coded Han 回归测试。
- 运行 UI package 测试和相关构建验证。

## 5. 不做什么

- 不实现真实 AI Provider、TTS、OCR、录音、照片访问或同步。
- 不改变首次启动核心流程：仍然先进入 onboarding，询问母语、目标语言和水平自评。
- 不创建真实语言空间持久化，不写入数据库。
- 不把首页做成营销 landing page，不展示复杂功能清单或流程图。
- 不改变 iPhone 主 Tab、iPad 工作台、macOS Sidebar / Inspector 的主导航架构。
- 不引入大面积渐变、粒子、装饰光球或非 Apple 原生感动画。

## 6. 证据与决策依据

- `docs/reference/lango_trace_首页优化方案.md`：提出主标题、标签、CTA、示例卡、iPhone 单列和 iPad 分栏方向。
- `docs/spec/003-ui-design-system.md`：要求 App 首屏是可用体验，不做营销式首页；强调安静、清晰、本地优先和隐私边界。
- `docs/spec/002-navigation-and-routing.md`：要求首次启动先询问母语、目标语言和水平自评；iPad 不应复用放大的 iPhone Tab 或单列布局。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：要求新增页面考虑多语言长度差异，UI chrome 进入 String Catalog。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`：当前欢迎页仍为单列 `VStack` 和 `maxWidth: 640`。
- Apple iOS 设计技能依据：iPhone 触控目标至少 44pt，主操作放在拇指区，支持小屏宽度和 Dynamic Type。
- Apple iPadOS 设计技能依据：iPad regular width 不应放大 iPhone UI，应使用多栏和自适应布局，支持 Split View / Stage Manager。
- Apple macOS 设计技能依据：Mac UI 应支持可调整窗口、键盘/菜单可达、合适密度和指针交互。

## 7. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`
- 可能新增：`Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeViewCopyTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ProductIdentity.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`

## 9. 涉及的文档路径

- `docs/reference/lango_trace_首页优化方案.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/plans/active/2026-05-18-feature-welcome-home-optimization.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.1 信息架构

Welcome 页面调整为四个稳定区域：

1. `Brand Mark`：小圆点 + `LANGOTRACE`，品牌轻量化。
2. `Value Proposition`：主标题改为“把生活，变成你的语言素材。”；英文基础文案为 `Learn from the life you already live.`。
3. `Trust Badges`：`本地优先` + `AI 可选`，图标使用 `lock.shield` 或 `lock`、`sparkles`。
4. `Trace Preview + CTA`：示例卡展示“今日语迹”，主按钮为“开始设置”，说明为“首次设置约 30 秒 · 默认本地保存”。

`ProductIdentity` 中长期 slogan 仍保留，不在本任务中修改产品主 slogan；Welcome 页面使用独立本地化 key 承载更适合首屏的价值主张。

### 11.2 iPhone 布局

- 使用单列纵向布局，内容宽度随屏幕自适应，不硬编码固定宽度。
- 顶部品牌和主标题在安全区内，主标题成为视觉重心。
- 示例卡放在中部偏下，高度控制在约 140-180pt，不能挤压底部 CTA。
- 主 CTA 固定在下方内容流末端或通过 `safeAreaInset(edge: .bottom)` 保证拇指区可达。
- 所有按钮和可点击 badge 触控区域不低于 44pt。
- 小屏和 Dynamic Type 下优先允许文案换行，不压缩到不可读。

### 11.3 iPad 布局

- regular width 使用左右分栏，左侧约 40%-45%，右侧约 55%-60%。
- 左侧：品牌、主标题、副说明、标签、CTA 和隐私/耗时说明。
- 右侧：更完整的“今日语迹”预览卡，包含生活记录原文、词汇、表达和练习摘要。
- compact width、Slide Over、窄 Stage Manager 窗口回退为 iPhone 风格单列，不隐藏 CTA。
- 分栏切换不能重置用户已进入的 onboarding 状态。

### 11.4 macOS 布局

- Welcome 页面在宽窗口可复用分栏，但设置合理最大内容宽度，避免横向拉满。
- 窗口变窄时回退单列；不假设全屏。
- 主按钮支持键盘聚焦，示例卡不伪装成可点击真实内容。
- 保持 macOS `Settings` scene 和菜单命令不受本任务影响。

### 11.5 示例卡内容

iPhone 版本：

```text
今日语迹
咖啡店点单
receipt · oat milk · to go
Can I get this to go?
跟读 1 遍 · 收藏 3 个表达
```

iPad / macOS 宽屏版本：

```text
今日语迹
Morning coffee
今天在咖啡店点了一杯燕麦拿铁。

Vocabulary
latte · oat milk · receipt · to go

Expression
Can I get this to go?

Practice
Shadowing · 收藏 · 复习
```

示例卡必须通过视觉或辅助文案表达为 preview / sample，不得暗示已经创建真实记录、已经调用 AI 或已经保存词句。

### 11.6 本地化策略

- 新增 `welcome.valueTitle`、`welcome.valueSubtitle`、`welcome.cta.startSetup`、`welcome.setupTimeLocalNote`、`welcome.tracePreview.*`、`app.badge.aiOptional` 等 key。
- `common.continue` 保留给其他流程，不直接改成 `开始设置`，避免影响非 Welcome 场景。
- 所有 8 种当前 String Catalog 语言都补齐值；非主要验证语言允许先采用英文等价翻译，但必须标记为 translated，避免运行期缺失。
- Swift 源码继续满足 “不含硬编码 Han 字符” 测试。

### 11.7 动效边界

- 第一轮实现不做复杂动画。
- 可接受的轻量动效：页面出现时整体 opacity / small offset 过渡，并尊重 Reduce Motion。
- 如果动效导致测试或平台一致性复杂化，推迟到后续 P3 精修任务。

## 12. 复查方法

- 对照 `docs/reference/lango_trace_首页优化方案.md` 检查 P0 / P1 / P2 是否落地。
- 检查 `WelcomeView.swift` 是否仍能在 iPhone / iPad compact / iPad regular / macOS 窄窗口中保持可读。
- 检查 `Localizable.xcstrings` 是否新增所有 Welcome key，且 Swift 源码无硬编码中文。
- 检查 CTA 语义是否仍进入 onboarding，而不是误导用户开始真实记录。
- 检查 “AI 可选” 是否只表达能力可控，不暗示已经接入真实 AI。
- 通过 SwiftUI preview 或模拟器人工查看 iPhone 与 iPad 横屏截图。

## 13. 验证命令

最低验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
git diff --check
```

涉及平台布局后应继续运行：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
swiftlint --no-cache
swiftformat --lint . --cache ignore
```

收口前优先运行完整：

```bash
scripts/verify.sh
```

## 14. 文档影响检查

本任务改变 Welcome 页面体验和欢迎页文案，但不改变产品北极星、首次启动流程、语言空间模型、AI Provider 边界、同步边界或导航架构，因此预计不需要新增 ADR。

如果实现过程中决定将 “Learn from the life you already live.” 替换长期英文主 slogan，必须同步更新 `docs/product-main-reference.md` 并评估是否需要 ADR 或产品决策记录。本方案当前不做该变更。

完成后需要在本任务方案实施记录中写明文档影响检查结果。若发现 `docs/spec/003-ui-design-system.md` 或 `docs/spec/002-navigation-and-routing.md` 中的 Welcome 规则需要长期化，再单独更新 spec。

## 15. 实施记录

2026-05-18：创建 Draft 方案。

2026-05-18：用户回复“开始实施”后进入实现。

2026-05-18：按 TDD 先新增 `WelcomeHomeOptimizationTests`，首次运行 `swift test --package-path Packages/LangoTraceUI` 失败，失败点为 Welcome 仍使用旧 `ProductIdentity` slogan、`app.badge.aiNotConfigured`、`common.continue`，且 String Catalog 缺少新 Welcome key。

2026-05-18：改造 `WelcomeView.swift`：

- 使用价值主张文案 key 替代品牌大标题和固定 slogan。
- 将状态标签改为 `本地优先 / AI 可选`，图标调整为 `lock.shield` 和 `sparkles`。
- 新增 `WelcomeTracePreviewCard`，在 compact 布局显示轻量示例，在 regular width 显示扩展示例。
- 使用宽度和 size class 判断 iPad / macOS 宽屏分栏，窄窗口回退单列。
- CTA 改为 `开始设置`，说明改为 `首次设置约 30 秒 · 默认本地保存`。

2026-05-18：补齐 `Localizable.xcstrings` 中 8 种当前界面语言的 Welcome 优化 key，保留旧 `common.continue` 和 `app.badge.aiNotConfigured` 给其他场景使用，但 Welcome 不再引用。

2026-05-18：运行 `swift test --package-path Packages/LangoTraceUI`，45 个测试通过。

2026-05-18：运行 `scripts/verify.sh`，通过。验证覆盖：

- `xcodegen generate`
- `xcodebuild -list -project LangoTrace.xcodeproj`
- `swift test --package-path Packages/LangoTraceCore`
- `swift test --package-path Packages/LangoTraceData`
- `swift test --package-path Packages/LangoTraceUI`
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`
- `swiftlint --no-cache`
- `swiftformat --lint . --cache ignore`
- 文档占位符扫描
- `git status --short`

文档影响检查：本任务未改变产品北极星、首次启动流程、语言空间模型、AI Provider 边界、同步边界或导航架构；不需要新增 ADR。长期主 slogan 未修改，`ProductIdentity` 保持原样。

2026-05-18：根据用户测试反馈“Mac 端已经完成了优化，iOS 和 iPad 似乎还没完成”做复查。确认问题不是 iOS / iPad 未使用新 Welcome 页面，而是移动端和 iPad regular width 的布局节奏未完全落地：

- iPhone compact 布局中 `Spacer(minLength:)` 在 `ScrollView` 内造成首屏下半部过度拉开，示例卡和 CTA 位置偏低。
- iPad regular width 布局使用居中对齐，导致分栏内容整体偏向屏幕中部，首屏上方留白过大。

修复内容：

- compact 布局移除 `Spacer(minLength:)`，改为基于屏幕高度的稳定 spacing 和顶部 padding，让价值主张、示例卡与 CTA 同处首屏。
- regular width 布局改为顶部对齐，并按 iPad / Mac 大高度给出更明确的顶部节奏。
- 新增 Welcome 布局回归测试，防止 compact 布局重新引入 `Spacer(minLength:)`，并检查 iPad 分栏保持顶部对齐。

补充验证：

- `swift test --package-path Packages/LangoTraceUI`：46 个测试通过。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`：通过。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`：通过。
- 已重新安装并启动本地模拟器：
  - iPhone 17：`CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C`
  - iPad Pro 13-inch (M5)：`73045FC7-A9FB-4F41-892E-3CE9755D2ECB`
- 截图复查：
  - `/private/tmp/langotrace-iphone-welcome-after-layout-fix.png`
  - `/private/tmp/langotrace-ipad-welcome-after-layout-fix.png`

## 16. 完成标准

- 已完成。用户确认本方案范围。
- 已完成。Welcome 页面完成文案、示例卡、CTA 和 iPad 分栏优化。
- 已完成。新增测试覆盖关键文案 key、无硬编码中文、按钮 action 仍指向 `onFinished`。
- 已完成。运行第 13 节验证命令，并记录结果。
- 已完成。文档影响检查完成。
- 已完成。任务方案状态更新为 `Verified`。

## 17. 剩余风险

- 示例卡文案涉及多语言混排，后续仍建议截图验证 VoiceOver、Dynamic Type 和长语言换行。
- “AI 可选”需要在后续设置页和 Provider 真实接入时保持一致，避免用户误解为当前已具备真实 AI 配置能力。
- iPad 分栏在 Stage Manager 极窄窗口下可能需要额外断点微调。
