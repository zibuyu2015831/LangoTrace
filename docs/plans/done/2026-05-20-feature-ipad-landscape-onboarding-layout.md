# iPad 横屏 Onboarding 分栏布局优化方案

状态：Done  
类型：feature  
创建日期：2026-05-20  
最后更新日期：2026-05-20  
完成日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户提供 iPad 横屏版设计图，并要求从专业设计师角度评估。
- 2026-05-20：评估结论为横屏左右分栏方向更优；用户确认采纳，并要求在微调设计后创建方案文档。

## 需求描述

iPad 横屏 onboarding 当前仍使用共享 wide 布局，未充分利用横屏宽度。用户设计的新方案采用左右分栏：

- 左侧承载语言空间的说明、短副标题和三项轻量价值摘要。
- 右侧承载母语、目标语言、当前水平表单。
- 表单下方居中显示语言方向摘要、创建语言空间主按钮和本地保存 footnote。

该方向比单列居中更符合 iPad 横屏的阅读与操作节奏：左侧解释“为什么创建”，右侧完成“现在创建”。

## 现状描述

当前 `OnboardingView` 的 iPad 横屏会命中 `usesInlineWideOnboardingLayout(in:)`，进入 `wideOnboardingContent(size:)`：

- 页面主体为单列 `VStack`。
- `onboardingFormContent` 内部包含 `header` 和 `languageForm`。
- `inlineCreateButton` 位于表单下方。
- 最大内容宽度为 `onboardingContentMaxWidth = 680`。
- iPad 竖屏、iPad 横屏和 macOS 宽窗口当前都可能共用 wide 分支。

现有实现的主要问题是横屏宽度被压缩成单列阅读流，左侧大面积空白没有形成可理解的产品语义区域。

## 目标

1. 为 iPad regular-width 横屏 onboarding 增加专属左右分栏布局。
2. 左侧表达语言空间的产品语义和三项轻量价值摘要。
3. 右侧保持创建语言空间所需的表单任务，避免把说明塞进表单。
4. 保持首次启动输入边界不变：母语、目标语言、当前水平、创建语言空间。
5. 保持 iPhone、macOS 和 iPad 竖屏布局不受本方案影响。
6. 与 iPad 竖屏方案保持设计语言一致，但不强行复用同一个布局分支。

## 范围

本次范围内：

- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`。
- 横屏与竖屏方案必须共用同一组能力摘要 String Catalog key；第三项统一为“留下语迹”，不得为横屏新增一套语义重复的独立 key。
- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`，保证新增或复用 key 覆盖 8 个 locale。
- 新增或更新 `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift` 或新建 onboarding layout 测试文件，覆盖横屏分支和非目标平台不受影响。
- 根据最终实现，补充 `docs/spec/003-ui-design-system.md` 中 iPad 横屏 onboarding 承载规则。

## 不做什么

- 不修改 iPhone onboarding 布局。
- 不修改 macOS onboarding 布局。
- 不把本方案并入 iPad 竖屏布局；竖屏仍由独立方案处理。
- 不修改 `LanguageLevel`、`OnboardingDraft`、语言空间数据模型或创建流程。
- 不新增 AI Provider、同步、目录选择、备份、对象存储或权限配置入口。
- 不把左侧说明扩展成营销页、轮播页或多步骤教程。
- 不引入真实持久化、数据库、同步或外部请求。

## 证据与决策依据

- iPadOS 横屏是 productivity 和沉浸学习的主要姿态，不应简单放大 iPhone 单列 UI。
- `docs/spec/003-ui-design-system.md` 要求 iPad 使用更高信息密度和更适合大屏的布局，但 onboarding 不应成为营销 landing page。
- `docs/spec/002-navigation-and-routing.md` 要求首次启动只询问母语、目标语言和当前水平，再创建第一个语言空间。
- 当前水平规则已经明确：A1-C2 代码必须保留，同时展示自然名称和一句话说明，并支持滚动、动态字体和无障碍选中态。
- 本地保存说明已经确定为创建按钮下方低权重 footnote，不应回到表单卡片。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

## 涉及的文档路径

- `docs/plans/active/2026-05-20-feature-ipad-portrait-onboarding-layout.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`

## 设计方案

### 1. 平台与方向判定

新增 iPad 横屏专属判定，原则如下：

- 只在 `os(iOS)` 下启用。
- 只面向 regular-width iPad 横屏或近似横屏大窗口。
- 不依赖设备型号，不写死 iPad Pro 13-inch。
- 推荐判定：
  - `size.width >= 980`
  - `size.height >= 680`
  - `size.width > size.height`

`body` 分支建议按目标优先级排列：

1. iPad 横屏专属布局。
2. iPad 竖屏专属布局。
3. 现有 wide 布局。
4. 现有 compact 底部 CTA 布局。

这样可以避免横屏误入竖屏分支，也避免 macOS 宽窗口进入 iPad 专属设计。若横屏方案先于竖屏方案单独实施，仍应按这个顺序预留竖屏分支位置，竖屏条件可以暂不命中或继续走现有 wide 兜底；后续实施竖屏时不得重新打乱横屏优先级。

### 2. 横屏页面结构

新增 `padLandscapeOnboardingContent(size:)`，结构如下：

```text
HStack(spacing: 0)
  leftPane
    header
    vertical value list
  subtle divider
  rightPane
    languageForm
    create summary
    primary CTA
    local storage footnote
```

布局规则：

- 左右两栏总宽度使用可用宽度，但内容各自设置最大阅读宽度。
- 左栏建议宽度占比约 `40%`，右栏约 `60%`。
- 左栏内容不贴边，保持约 `80-96pt` leading padding。
- 右栏表单最大宽度建议为 `660-720pt`，避免横向拉满。
- 分割线必须极弱，或在实现中只用留白形成分区；若使用 divider，颜色应接近 hairline，不能产生后台管理系统的硬切割感。
- 主 CTA 不进入表单卡片，保留在表单下方，形成独立主操作。

### 3. 左侧说明区微调

左侧标题沿用当前 onboarding 主标题和副标题：

- `创建语言空间`
- `创建一个语言空间，把生活变成学习材料。`

三项价值摘要采用竖向列表，每项为图标、标题和短说明：

```text
记录生活
照片、声音与文字

练习表达
在真实语境中学习

留下语迹
看见自己的语言成长
```

微调结论：

- 第三项标题采用“留下语迹”，比“长期积累”更有品牌记忆点。
- 第三项说明采用“看见自己的语言成长”，避免重复“语迹”并保持语义清楚。
- 三项之间可使用弱分割线或足够垂直间距；不要使用独立强卡片。
- 图标建议：
  - 记录生活：`camera`
  - 练习表达：`text.bubble` 或 `book`
  - 留下语迹：`leaf`
- 图标背景可使用淡 teal，但视觉重量必须低于主 CTA。

### 4. 右侧表单区

右侧表单继续使用现有 `languageForm` 的输入语义：

- 母语。
- 目标语言。
- 当前水平。

但横屏右侧承载中不再包含 `header`，避免标题在左右两侧重复。实现建议将现有 `onboardingFormContent` 拆成可组合结构：

- `header`
- `languageForm(levelVisibleRows:)`
- `createButtonContent`

横屏右侧只使用 `languageForm(levelVisibleRows: 4)` 和 `createButtonContent`。

### 5. 当前水平列表高度

iPad 横屏高度有限但表单区宽度充足，建议显示约 4 个等级选项：

- A1、A2、B1、B2 可见。
- C1、C2 通过内部滚动访问。
- Dynamic Type 变大时，优先保证可读、可点和可滚动，不压缩字号。

该规则与 iPad 竖屏方案的 4 行可见保持一致，但横屏布局仍独立。

### 6. 本地化与文案边界

能力摘要文案必须进入 `Localizable.xcstrings`，不能在 SwiftUI 中硬编码中文。

推荐 key：

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

所有新增 key 必须覆盖现有 8 个 locale：`en`、`zh-Hans`、`es`、`ja`、`fr`、`de`、`ko`、`ru`。

该 key 组必须与 iPad 竖屏方案共用。两套 iPad 方向都使用“留下语迹”，避免设备旋转后同一价值项出现不同命名。

### 7. 无障碍与响应式

- 左侧三项价值摘要是静态说明，图标 `accessibilityHidden(true)`，每项标题和说明合并为一条可读文本。
- 右侧表单的交互控件触控区域不小于 44pt。
- 横屏布局在 Split View、Stage Manager 窄窗口或高度不足时，不强行使用两栏，应回退到竖屏专属、现有 wide 或 compact 布局。
- 不能依赖 hover 才能理解任何内容。
- 动态字体较大时，左侧价值摘要允许换行；若左右两栏不足以容纳内容，应让页面整体垂直滚动，而不是遮挡 CTA。

## 实施步骤

1. 写测试，锁定 iPad 横屏分支存在且只在 `width > height` 的大尺寸 iOS 几何条件下启用。
2. 写测试，锁定 iPhone、macOS 和 iPad 竖屏不会命中横屏分栏布局。
3. 写测试，锁定横屏能力摘要 key 覆盖 8 个 locale，且简体中文第三项为“留下语迹 / 看见自己的语言成长”。
4. 写测试，锁定横屏当前水平列表约 4 行可见。
5. 将 `languageForm` 和 `compactLevelSelector` 参数化，支持传入可见行数。
6. 实现 `usesPadLandscapeOnboardingLayout(in:)` 与 `padLandscapeOnboardingContent(size:)`。
7. 实现左侧 `padOnboardingValueList`，优先复用竖屏方案中的 value item 组件；若竖屏尚未实施，则先在横屏方案中建立可复用私有组件，并在竖屏方案后续实施时复用它。
8. 更新 `Localizable.xcstrings` 8 locale 文案。
9. 更新 `docs/spec/003-ui-design-system.md`，补充 iPad 横屏 onboarding 左右分栏规则。
10. 运行验证命令并重启 iPad 横屏模拟器供人工检查。

## 复查方法

人工复查：

- iPad Pro 13-inch 横屏：应呈现左右分栏，左侧为说明和三项价值摘要，右侧为表单、摘要、主按钮和 footnote。
- iPad Pro 13-inch 竖屏：不应出现横屏左右分栏。
- iPhone 17：不应出现横屏左右分栏或左侧价值摘要。
- macOS：不应出现 iPad 横屏专属分栏。
- iPad Split View / Stage Manager 窄窗口：布局应退回到更适合窄宽度的分支，不应横向溢出。
- Dynamic Type 较大时：左侧说明、右侧表单、CTA 和 footnote 不应重叠。

代码复查：

- 横屏判定不能写死设备型号。
- 左侧价值摘要不能参与语言空间数据模型。
- 新增本地化 key 必须覆盖 8 locale。
- 横屏和竖屏价值摘要必须共用 `trace` key 和同一套标题语义。
- 分栏布局不能污染 iPhone、macOS 或 iPad 竖屏路径。
- 若同时存在 iPad 竖屏方案，两个分支的命名、key 和 helper 要保持一致，避免重复实现两套近似组件。

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

启动后需在模拟器中切到横屏检查。实际安装路径应使用本机 DerivedData 中构建出的 `LangoTrace.app`。

## 文档影响检查

本任务会影响长期 UI 规则，因此实施完成后需要检查并按需更新：

- `docs/spec/003-ui-design-system.md`：补充 iPad 横屏 onboarding 左右分栏承载规则。
- `docs/spec/002-navigation-and-routing.md`：若只改变视觉承载，不改变首次启动路径，则无需更新。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：若只新增本地化 key 且不改变语言边界，则无需更新。
- `docs/product-main-reference.md`：若不改变产品定位和首次启动输入项，则无需更新。

## 实施记录

- 2026-05-20：创建方案，等待用户确认后实施。
- 2026-05-20：开始实施。已在 `OnboardingView.swift` 中新增 iPad 横屏专属布局分支，横屏使用左侧说明/价值摘要与右侧表单/CTA 的分栏承载；当前水平列表在 iPad 横屏显示约 4 行并保持内部滚动。价值摘要与竖屏方案共用 `onboarding.value.*` 本地化 key。已新增 source-scan 和 String Catalog 覆盖测试，并通过 `swift test --package-path Packages/LangoTraceUI --filter Onboarding`。
- 2026-05-20：完成实现并提交 `c677754`、`44d76c7`。最终验证通过 `swift test --package-path Packages/LangoTraceUI --filter Onboarding`、`swift test --package-path Packages/LangoTraceUI`、`scripts/verify.sh`、`git diff --check`；iPad Pro 13-inch (M5) 模拟器已重启、安装并启动当前构建。

## 完成标准

- iPad 横屏 onboarding 采用左右分栏布局。
- 左侧价值摘要采用微调后的“记录生活 / 练习表达 / 留下语迹”。
- 右侧表单保持母语、目标语言、当前水平和创建语言空间主动作。
- iPhone、macOS 和 iPad 竖屏 onboarding 没有视觉或代码行为回归。
- 新增或复用文案完成 8 locale 本地化。
- 当前水平列表在 iPad 横屏约 4 行可见，仍支持内部滚动。
- 通过 UI package 测试、全量验证脚本和文档 diff 检查。
- iPad 横屏模拟器重启并完成手动视觉检查。

## 剩余风险

- iPad Mini、Split View 和 Stage Manager 窄窗口可能不适合左右分栏，应按尺寸回退，而不是强行套用横屏设计。
- 8 locale 文案为工程本地化覆盖，不等同于母语级文案审校。
- 如果 iPad 竖屏方案先实施，横屏方案需要复用或调整已有 helper，避免重复组件；如果横屏先实施，则竖屏方案后续应复用相同 value item 组件和 `trace` 文案 key。
- 用户设计图是视觉目标，SwiftUI 实现会按 safe area、Dynamic Type 和实际模拟器尺寸响应式适配，不能承诺像素级一致。
