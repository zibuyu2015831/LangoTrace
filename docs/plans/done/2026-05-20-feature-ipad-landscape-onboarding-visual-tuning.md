# iPad 横屏 Onboarding 视觉微调方案

状态：Verified

类型：feature

创建日期：2026-05-20

最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户指出 iPad 横屏版需要将元素下移，取消中间分割线，提升设计感。
- 2026-05-20：用户对比当前实现截图后指出右侧整体偏小，左侧也未充分下移，要求继续贴近设计稿。
- 2026-05-20：用户在截图中标出左侧价值摘要区域，要求左侧元素整体向右、向下偏移。
- 2026-05-20：用户在截图中标出标题区域，要求标题部分也移动，使其与下面元素呈现左右居中对齐的效果。

## 需求描述

当前 iPad 横屏 onboarding 已采用左右分栏，但视觉上仍有两个问题：

- 左右栏内容起始位置偏高，页面上方留白不足，整体重心不够稳。
- 中间竖向分割线形成硬切割，削弱语言学习产品应有的轻盈和高级感。
- 第二轮截图复查显示，删除分割线和初步下移后，右侧表单与按钮组合的视觉权重仍偏小，左侧说明区仍需要进一步下沉。
- 第三轮截图复查显示，左侧三项价值摘要仍与标题区过度同轴，需要作为独立内容组向右、向下偏移。
- 第四轮截图复查显示，标题区没有跟随价值摘要右移，左侧上下两个内容组没有形成统一视觉轴线。

## 现状描述

- `OnboardingView.swift` 中 `padLandscapeOnboardingContent(size:)` 使用 `HStack(spacing: 0)`。
- 左右栏之间插入 `padLandscapeDivider`。
- 横屏顶部 padding 由 `padLandscapeTopPadding(in:)` 控制，目前高屏为 `104pt`，较矮横屏为 `72pt`。

## 目标

- 仅优化 iPad 横屏 onboarding 视觉。
- 横屏左右分栏内容整体下移，形成更舒展的首屏节奏。
- 删除中间竖向分割线，改用栏间留白和左右栏宽度关系形成视觉分区。
- 提升右侧表单和按钮的视觉尺寸，使创建动作与表单成为更明确的主操作区。
- 将左侧三项价值摘要整体右移、下移，落入更稳定的左侧内容区域。
- 将左侧标题区同步右移，使标题区和价值摘要在横向视觉上更居中、更统一。
- 保持母语、目标语言、当前水平、语言方向摘要、创建按钮和本地保存 footnote 的功能不变。

## 范围

- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift` 的 iPad 横屏布局。
- 更新 `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift` 中相关结构性测试。
- 更新 `docs/spec/003-ui-design-system.md` 的 iPad 横屏设计要求。

## 不做什么

- 不修改 iPhone onboarding。
- 不修改 iPad 竖屏 onboarding。
- 不修改 macOS onboarding。
- 不新增本地化文案、数据模型、路由、AI、同步、权限或持久化行为。
- 不引入装饰性背景、额外卡片或新的视觉系统 token。

## 证据与决策依据

- iPad 横屏属于 regular-width 大画布，不应依赖后台式硬分割线表达结构。
- 当前页面信息量不大，左右内容可以通过留白、宽度比例和对齐形成清晰关系。
- 将内容下移能缓解顶部拥挤，让标题区、表单区和底部按钮形成更稳定的垂直节奏。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingValueSummary.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingCompactLevelSelector.swift`

## 涉及的文档路径

- `docs/spec/003-ui-design-system.md`
- `docs/plans/active/2026-05-20-feature-ipad-landscape-onboarding-visual-tuning.md`

## 实施方案

1. 删除 `padLandscapeDivider` 及其调用。
2. 将横屏 `HStack` 从零间距改为自适应栏间距。
3. 调整横屏左右栏宽度比例，避免删除分割线后两栏贴得过近。
4. 提高 `padLandscapeTopPadding(in:)` 返回值，使横屏内容整体下移。
5. 将右栏横向 padding 按宽度自适应，保证最小横屏阈值下表单仍有足够宽度。
6. 第二轮调整将左栏宽度从 `40%` 降到 `36%`，右栏宽度从 `54%` 提升到 `58%`，并将右侧表单最大宽度提升到 `760pt`、横屏按钮最大宽度提升到 `640pt`。
7. 第二轮将横屏顶部 padding 从 `132/96pt` 继续提升到 `156/118pt`，让左右两栏更明显下移。
8. 第三轮仅为 iPad 横屏左侧价值摘要增加 leading/top 偏移，不移动标题和副标题。
9. 第四轮为 iPad 横屏左侧 header 增加与价值摘要一致的 leading 偏移，使标题区和价值摘要保持同一视觉轴线。
10. 更新测试，断言横屏不再包含 `padLandscapeDivider`，并保留横屏分支、4 行当前水平列表、共享价值摘要、左侧标题区和价值摘要偏移规则的保护。
11. 更新设计系统规范，记录横屏分栏应优先使用留白而非竖线分隔。

## 复查方法

- 代码层确认 iPad 横屏分支仍位于 iPad 竖屏、wide 和 compact 分支之前。
- 代码层确认 `padLandscapeDivider` 已删除。
- 代码层确认 `padLandscapeTopPadding(in:)` 只影响横屏布局。
- 测试层确认 onboarding 相关测试通过。
- 构建层运行 Swift package 测试和 iOS build。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter Onboarding
scripts/verify.sh
```

## 文档影响检查

本任务只改变 onboarding iPad 横屏视觉承载规则，应同步更新 `docs/spec/003-ui-design-system.md`。不涉及 ADR、数据、AI、隐私、同步、StoreKit 或发布文档。

## 实施记录

- 2026-05-20：删除 iPad 横屏 onboarding 中间竖向分割线，改用自适应栏间留白分隔左右内容。
- 2026-05-20：将 iPad 横屏内容顶部 padding 从 `104/72pt` 调整为 `132/96pt`，使页面重心下移。
- 2026-05-20：为右栏横向 padding 和栏间距增加宽度自适应，保护最小横屏阈值下的表单宽度。
- 2026-05-20：更新 onboarding 结构测试，覆盖无分割线、留白分隔和内容下移规则。
- 2026-05-20：更新 `docs/spec/003-ui-design-system.md`，记录 iPad 横屏不使用中间竖向分割线。
- 2026-05-20：`swift test --package-path Packages/LangoTraceUI --filter Onboarding` 通过，11 个测试全部通过。
- 2026-05-20：`scripts/verify.sh` 通过，包含 XcodeGen、package tests、iPhone/iPad/macOS build、SwiftLint 和 SwiftFormat lint。
- 2026-05-20：根据用户第二轮截图反馈，将左栏宽度调为 `36%`，右栏宽度调为 `58%`，右侧表单最大宽度调为 `760pt`，横屏创建按钮最大宽度调为 `640pt`。
- 2026-05-20：根据用户第二轮截图反馈，将横屏顶部 padding 继续调为 `156/118pt`。
- 2026-05-20：更新按钮宽度约束测试，保留默认 `520pt` 约束，同时允许 iPad 横屏使用 `640pt` 专用主按钮。
- 2026-05-20：整理 `OnboardingView.swift` 内部布局 helper，使文件长度回到 SwiftLint 限制内。
- 2026-05-20：第二轮 `swift test --package-path Packages/LangoTraceUI --filter Onboarding` 通过，11 个测试全部通过。
- 2026-05-20：第二轮 `scripts/verify.sh` 通过，包含 XcodeGen、package tests、iPhone/iPad/macOS build、SwiftLint 0 violations 和 SwiftFormat lint。
- 2026-05-20：根据用户第三轮截图标注，为 iPad 横屏左侧价值摘要增加 `44/32pt` leading 偏移和 `28/20pt` top 偏移。
- 2026-05-20：第三轮 `swift test --package-path Packages/LangoTraceUI --filter Onboarding` 通过，11 个测试全部通过。
- 2026-05-20：第三轮 `scripts/verify.sh` 通过，包含 XcodeGen、package tests、iPhone/iPad/macOS build、SwiftLint 0 violations 和 SwiftFormat lint。
- 2026-05-20：根据用户第四轮截图标注，为 iPad 横屏左侧标题区增加与价值摘要一致的 `44/32pt` leading 偏移。
- 2026-05-20：第四轮 `swift test --package-path Packages/LangoTraceUI --filter Onboarding` 通过，11 个测试全部通过。
- 2026-05-20：第四轮 `scripts/verify.sh` 通过，包含 XcodeGen、package tests、iPhone/iPad/macOS build、SwiftLint 0 violations 和 SwiftFormat lint。

## 完成标准

- iPad 横屏 onboarding 不再显示中间竖向分割线。
- 横屏内容整体下移，页面上方留白更稳定。
- iPhone、iPad 竖屏、macOS 分支不受影响。
- 相关测试和验证命令通过。

## 剩余风险

- 本轮主要通过代码结构和模拟器构建验证，最终视觉仍建议在 iPad 横屏模拟器中人工确认。
