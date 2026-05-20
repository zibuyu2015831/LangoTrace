# iPad 竖屏 Onboarding 布局优化方案

状态：In Progress  
类型：feature  
创建日期：2026-05-20  
最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户确认采纳 iPad 竖屏新版方向，并明确本次优化仅设计 iPad 端竖屏版；不得改动 iOS 或 Mac，不得影响 iPad 横屏版，iPad 横屏版之后单独设计。

## 需求描述

当前 iPad 竖屏 onboarding 没有充分利用页面空间，视觉上更接近把共享表单放大后居中。用户提供的新设计希望在 iPad 竖屏下形成更完整的页面节奏：

- 顶部保留 onboarding 标题与简短副标题。
- 标题下方增加轻量能力摘要：记录生活、练习表达、留下语迹。
- 表单主体保持母语、目标语言、当前水平三项。
- 当前水平继续使用 A1-C2 代码、自然名称和一句话说明。
- 创建按钮、语言方向摘要和本地保存 footnote 保持低干扰但清晰。

## 现状描述

当前 `OnboardingView` 使用尺寸分支决定布局：

- `usesInlineWideOnboardingLayout(in:)` 在 iOS 上以 `size.width >= 760 && size.height >= 720` 进入 wide 布局。
- iPad 竖屏和 iPad 横屏都会进入 `wideOnboardingContent(size:)`。
- `wideOnboardingContent(size:)` 只把 `onboardingFormContent` 与 `inlineCreateButton` 纵向排列，最大宽度为 `onboardingContentMaxWidth = 680`。
- `header`、`languageForm`、`compactLevelSelector`、`createButtonContent` 为 iPhone、iPad、macOS 共享内容。
- 当前水平列表默认约 3 行可见，内部滚动。

现状的主要问题不是信息缺失，而是 iPad 竖屏大画布下缺少专属的信息组织。直接改 `wideOnboardingContent` 会同时影响 iPad 横屏和 macOS，因此本任务需要新增 iPad 竖屏专属分支。

## 目标

1. 仅优化 iPad regular-width 竖屏 onboarding 的版式。
2. 让 iPad 竖屏充分利用中等宽度画布，形成标题、能力摘要、表单、摘要、CTA 和 footnote 的完整节奏。
3. 保持首次创建语言空间的输入边界不变：母语、目标语言、当前水平、创建语言空间。
4. 保持当前水平的 A1-C2 数据模型和可见代码不变。
5. 保持 iPhone、macOS 和 iPad 横屏现有布局不变。
6. 若 iPad 横屏方案同时实施，竖屏方案必须与横屏方案共享同一组价值摘要文案和私有 helper，避免旋转设备后语义漂移或重复组件。

## 范围

本次范围内：

- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`。
- 如需新增能力摘要文案，修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`。
- 新增或更新 `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift` 或新建专门测试文件，覆盖 iPad 竖屏专属分支和非目标平台不受影响。
- 根据最终实现，补充 `docs/spec/003-ui-design-system.md` 中 onboarding iPad 竖屏承载规则。

## 不做什么

- 不修改 iPhone onboarding 布局。
- 不修改 macOS onboarding 布局。
- 不修改 iPad 横屏 onboarding 布局。
- 不调整 `LanguageLevel`、`OnboardingDraft`、语言空间模型或创建流程。
- 不新增 AI Provider、同步、目录选择、备份、对象存储或权限配置入口。
- 不把顶部能力摘要做成营销页、教程页或多步骤 wizard。
- 不引入真实持久化、数据库、同步或外部请求。

## 证据与决策依据

- `docs/spec/003-ui-design-system.md` 要求 iPad 使用更高信息密度和更适合大屏的布局，但 onboarding 不应变成营销页。
- `docs/spec/002-navigation-and-routing.md` 要求首次启动必须先询问母语、目标语言和当前水平，再创建第一个语言空间。
- `docs/spec/003-ui-design-system.md` 已规定当前水平使用 A1-C2 代码、自然名称和一句话说明，控件支持滚动、动态字体和无障碍选中态。
- `docs/spec/003-ui-design-system.md` 已规定本地保存提示应在创建按钮下方以低权重 footnote 展示。
- iPadOS 设计边界要求不要简单放大 iPhone UI；regular width 下应使用更适合画布的承载方式，同时必须支持方向变化和多任务窗口尺寸变化。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

## 涉及的文档路径

- `docs/spec/003-ui-design-system.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`

## 设计方案

### 1. 平台与方向判定

在 `OnboardingView` 中新增 iPad 竖屏专属判定，原则如下：

- 只在 `os(iOS)` 下启用。
- 只在 regular-width iPad 竖屏全屏或近似竖屏尺寸下启用。
- 判定应优先使用几何尺寸，不依赖设备名称。
- 推荐判定：
  - `size.width >= 760`
  - `size.height >= 900`
  - `size.height > size.width`

该分支命名建议为 `usesPadPortraitOnboardingLayout(in:)`。若只实施竖屏方案，`body` 分支顺序应为：

1. iPad 竖屏专属布局。
2. 现有 wide 布局。
3. 现有 compact 底部 CTA 布局。

这样 iPad 横屏仍会进入现有 wide 布局，iPhone 仍会在宽度不足时进入 compact 布局，macOS 不会进入 iOS 专属分支。

若 iPad 竖屏和横屏方案在同一轮实施，`body` 分支顺序必须统一为：

1. iPad 横屏专属布局。
2. iPad 竖屏专属布局。
3. 现有 wide 布局。
4. 现有 compact 底部 CTA 布局。

这样可以确保横屏不会被竖屏或 wide 分支提前截获。

### 2. iPad 竖屏页面结构

新增 `padPortraitOnboardingContent(size:)`，结构如下：

```text
ScrollView
  VStack(spacing: 34)
    header
    padPortraitValueStrip
    languageForm
    inlineCreateButton
```

承载规则：

- 外层 `VStack` 最大宽度建议为 `700pt`。
- 顶部 padding 在 13 英寸竖屏上约 `118pt`，较小 iPad 或 Stage Manager 竖屏窗口下降到约 `72-88pt`。
- 表单仍使用现有 `languageForm`，避免复制母语、目标语言和当前水平输入逻辑。
- `inlineCreateButton` 可继续复用，按钮最大宽度仍以 `onboardingBottomActionMaxWidth` 控制。

### 3. 顶部能力摘要

新增轻量 `padPortraitValueStrip`，用于表达创建语言空间后的三类价值：

```text
记录生活        练习表达        留下语迹
照片、声音与文字  在真实语境中学习  看见自己的语言成长
```

视觉规则：

- 三项横向排列，使用 `HStack` 或三列 `Grid`。
- 每项由淡色圆角图标底、标题、短说明组成。
- 图标建议：
  - 记录生活：`camera`
  - 练习表达：`book`
  - 留下语迹：`leaf`
- 图标、标题和说明必须低于主标题和主 CTA 的视觉重量。
- 不使用独立卡片边框，不做成营销功能卡。
- 文案必须进入 `Localizable.xcstrings`，不能在 SwiftUI 中硬编码中文。

### 4. 当前水平列表高度

iPad 竖屏可比 iPhone 显示更多内容，但仍保持内部滚动，避免 C1/C2 在动态字体或较小 iPad 上把 CTA 挤出可见区域。

推荐规则：

- iPhone / compact：约 3 行可见，沿用现状。
- iPad 竖屏：约 4 行可见，内部滚动。
- iPad 横屏 / macOS：本次不改，沿用现状。

实现建议：

- 将 `compactLevelSelectorMaxHeight` 改为可传入可见行数的 helper，例如 `levelSelectorMaxHeight(visibleRows:)`。
- `languageForm` 默认仍使用 3 行。
- iPad 竖屏专属布局通过环境或参数让 `languageForm` 使用 4 行；若参数化会导致 `languageForm` 变复杂，可新增 `languageForm(levelVisibleRows:)` 并让原 `languageForm` 调用 3 行版本。

### 5. 文案与本地化

新增本地化 key 建议：

- `onboarding.value.record.title`
- `onboarding.value.record.subtitle`
- `onboarding.value.practice.title`
- `onboarding.value.practice.subtitle`
- `onboarding.value.trace.title`
- `onboarding.value.trace.subtitle`

简体中文建议：

- `记录生活`
- `照片、声音与文字`
- `练习表达`
- `在真实语境中学习`
- `留下语迹`
- `看见自己的语言成长`

所有新增 key 必须覆盖现有 String Catalog 支持的 8 个 locale：`en`、`zh-Hans`、`es`、`ja`、`fr`、`de`、`ko`、`ru`。

该 key 组应与 iPad 横屏方案共用。不得在竖屏使用 `growth`、横屏使用 `trace`，也不得让同一价值项在不同方向下显示不同标题。

### 6. 无障碍与动态字体

- 能力摘要每项作为静态文本组合，图标 `accessibilityHidden(true)`。
- 当前水平选项继续保留等级代码、自然名称、说明和 selected trait。
- iPad 竖屏下所有可点击控件触控区域不小于 44pt。
- 动态字体下能力摘要允许单项文字换行，但不得互相重叠；必要时在极大字号下降级为纵向三行摘要。
- 不能通过缩小字体解决溢出问题。

## 实施步骤

1. 写测试，先锁定 iPad 竖屏分支存在且不影响 iPhone、iPad 横屏和 macOS 分支。
2. 写测试，锁定 iPad 竖屏能力摘要 key 存在且覆盖 8 个 locale。
3. 写测试，锁定 iPad 竖屏当前水平列表约 4 行可见，默认共享表单仍约 3 行可见。
4. 实现 `usesPadPortraitOnboardingLayout(in:)` 与 `padPortraitOnboardingContent(size:)`。
5. 抽出可参数化的 `languageForm(levelVisibleRows:)`、`compactLevelSelector(visibleRows:)` 和 `levelSelectorMaxHeight(visibleRows:)`。
6. 实现 `padPortraitValueStrip` 和轻量 value item 组件；如果横屏方案同轮实施，应抽成私有共享 value item，横屏使用纵向列表，竖屏使用横向三列。
7. 更新 `Localizable.xcstrings` 的 8 个 locale 文案。
8. 更新 `docs/spec/003-ui-design-system.md`，只补充 iPad 竖屏 onboarding 承载规则，不改 iPhone、Mac 或 iPad 横屏规范。
9. 运行验证命令并重启 iPad 竖屏模拟器供人工检查。

## 实施记录

- 2026-05-20：开始实施。已在 `OnboardingView.swift` 中新增 iPad 竖屏专属布局分支，竖屏使用标题、三项价值摘要、表单和 CTA 的纵向节奏；当前水平列表在 iPad 竖屏显示约 4 行并保持内部滚动。价值摘要与横屏方案共用 `onboarding.value.*` 本地化 key。已新增 source-scan 和 String Catalog 覆盖测试，并通过 `swift test --package-path Packages/LangoTraceUI --filter Onboarding`。

## 复查方法

人工复查：

- iPad Pro 13-inch 竖屏：页面应接近用户提供的新设计，顶部能力摘要横向排列，表单居中且不显得空。
- iPad Pro 13-inch 横屏：不应出现新能力摘要，布局应与当前横屏 wide onboarding 保持一致。
- iPhone 17：不应出现新能力摘要，仍使用底部固定 CTA 的 compact onboarding。
- macOS：不应出现 iPad 竖屏专属能力摘要，仍使用现有 wide onboarding。
- 动态字体较大时：能力摘要、当前水平列表和 CTA 不应重叠。

代码复查：

- iPad 竖屏判定不能写死设备型号。
- 新增能力摘要不能参与语言空间数据模型。
- 新增本地化 key 不能只写中文或英文。
- 竖屏和横屏若同轮实施，价值摘要必须共用 `trace` key 和同一套标题语义。
- 不得把 iPad 竖屏专属布局扩散到 iPad 主工作台、iPhone 或 macOS。

## 验证命令

实施后至少运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter Onboarding
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
git status --short
```

模拟器人工检查建议：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcrun simctl boot "iPad Pro 13-inch (M5)"
xcrun simctl install "iPad Pro 13-inch (M5)" /path/to/LangoTrace.app
xcrun simctl launch "iPad Pro 13-inch (M5)" com.zibuyu.LangoTrace
```

实际安装路径应使用本机 DerivedData 中构建出的 `LangoTrace.app`。

## 文档影响检查

本任务会影响长期 UI 规则，因此实施完成后需要检查并按需更新：

- `docs/spec/003-ui-design-system.md`：补充 iPad 竖屏 onboarding 专属承载规则。
- `docs/spec/002-navigation-and-routing.md`：若只改变视觉承载，不改变首次启动路径，则无需更新。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：若只新增本地化 key 且不改变语言边界，则无需更新。
- `docs/product-main-reference.md`：若不改变产品定位和首次启动输入项，则无需更新。

## 实施记录

- 2026-05-20：创建方案，等待用户确认后实施。

## 完成标准

- iPad 竖屏 onboarding 采用新版布局。
- iPhone、macOS 和 iPad 横屏 onboarding 没有视觉或代码行为回归。
- 新增文案完成 8 locale 本地化。
- 价值摘要文案与 iPad 横屏方案一致，第三项为“留下语迹 / 看见自己的语言成长”。
- 当前水平列表在 iPad 竖屏约 4 行可见，仍支持内部滚动。
- 通过 UI package 测试、全量验证脚本和文档 diff 检查。
- iPad 竖屏模拟器重启并完成手动视觉检查。

## 剩余风险

- iPad Mini、Split View 和 Stage Manager 窄窗口可能不满足竖屏专属判定，应按尺寸退回 compact 或现有 wide 布局，而不是强行套用 13 英寸竖屏设计。
- 8 locale 文案为工程本地化覆盖，不等同于母语级文案审校。
- 截图中的视觉比例来自用户设计稿，SwiftUI 实现会按动态字体、safe area 和实际 iPad 尺寸做响应式约束，不能承诺像素级一致。
