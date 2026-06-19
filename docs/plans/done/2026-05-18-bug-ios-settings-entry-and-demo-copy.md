# iOS Settings Entry And Demo Copy Repair

状态：Verified

类型：bug

创建日期：2026-05-18

最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户在 iPhone 17 模拟器截图中确认当前主界面看不到设置入口，且点击顶部语言空间胶囊无反应。
- 2026-05-18：用户要求创建方案文档进行修复，并去除主界面中类似“当前仅为本地 mock 记录，SQLite 尚未接入”“选择一条记录查看本地 mock 学习材料”的说明文字，让 UI 即便使用模拟数据也呈现为真实界面，便于整体评估设计。

## 需求或 bug 描述

iOS 主界面的设置入口按代码曾放在 `PhonePage` 的 `toolbar` 中，但在当前模拟器主界面不可见，导致用户无法从主界面稳定进入设置。主界面还直接展示 mock、SQLite 未接入、mock 学习材料等工程状态说明，削弱了真实产品界面的评估价值。

## 复现方式

1. 启动 iPhone 17 模拟器中的 LangoTrace。
2. 完成 Welcome / Onboarding，进入记录 Tab。
3. 观察顶部区域和底部 Tab。
4. 尝试点击语言空间胶囊。
5. 观察“当前仅为本地 mock 记录，SQLite 尚未接入”“选择一条记录查看本地 mock 学习材料”等说明文字。

## 预期行为

- iPhone 主界面应有可见、可点击、触控尺寸合格的设置入口。
- 设置入口不应占用底部 `记录 / 练习 / 记忆` 三个主 Tab。
- 顶部语言空间上下文可以作为当前学习空间展示，但如果看起来可点击，必须有真实动作。
- 主页面应像真实 App 一样展示模拟数据，不把 mock、SQLite 未接入等工程状态文案放在普通用户主路径。
- 能力边界说明应保留在设置、详情页、unavailable sheet 或其他明确的配置/诊断上下文中。

## 实际行为

- `PhonePage` 的 toolbar gear 在当前 iPhone 17 模拟器截图中没有显示。
- 语言空间胶囊只是 `Label`，没有 action，点击无反应。
- 记录页顶部和最近记录区展示工程状态说明文案。

## 根因分析

置信度：90%

`PhonePage` 当前把设置入口放进 `ScrollView` 页面的 `.toolbar`，但 `PhoneMainView` 的 `NavigationStack` 包着 `TabView`，实际 iOS 渲染中 toolbar 没有稳定显示在当前截图主界面。与此同时，`PhoneContextHeader` 只渲染语言空间 `Label` 和 status `Label`，其中 status 文案来自 `phone.entries.status` 等 localized keys，直接把 mock / SQLite 状态暴露给普通用户主界面。

## 置信度依据

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift` 中 `PhonePage` 仍有 `ToolbarItem` gear，但截图没有对应可见控件。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift` 中 `PhoneContextHeader` 的语言空间是 `Label(languageSpace.displayContext, systemImage: "text.badge.star")`，不是 `Button`。
- `PhoneContextHeader` 直接显示 `statusText`，而 `phone.entries.status` 的中文值是“当前仅为本地 mock 记录，SQLite 尚未接入。”。
- `phone.today.recent.subtitle` 的中文值是“选择一条记录查看本地 mock 学习材料。”。

## 备选原因

- toolbar 可能受当前 NavigationStack / TabView 组合和大标题显示策略影响，而不是完全未挂载。
- 模拟器截图可能处于滚动位置或导航栏显示状态导致 toolbar 不明显，但这不改变“设置入口对用户不可发现”的问题。

## 目标

1. 在 iPhone 主界面顶部内容区提供稳定可见的设置齿轮按钮。
2. 语言空间胶囊提供真实的语言空间摘要 sheet 入口，避免看起来可点击但无响应。
3. 从 iPhone 主页面移除工程状态说明文案，包括顶部 status 行和最近记录区 mock 说明。
4. 保留底部三 Tab 信息架构，不新增设置 Tab。
5. 用测试锁定主界面不再依赖 `phone.entries.status` / `phone.today.recent.subtitle` 这类工程说明。

## 范围

- 修改 iPhone SwiftUI 主页面、顶部上下文 header 和必要测试。
- 不实现真实 SQLite、AI、TTS、同步或 StoreKit。
- 不移除设置页、详情页、unavailable 页面中的能力边界说明。
- 不恢复左右滑动切换 Tab。
- 不改变 iPad 和 macOS 的设置入口结构。

## 证据与决策依据

- `docs/spec/002-navigation-and-routing.md` 要求 iPhone 一级入口为 `记录 / 练习 / 记忆`，设置通过 toolbar gear、语言空间摘要或二级配置 route 稳定可达，不作为底部 Tab。
- `docs/spec/003-ui-design-system.md` 要求本地优先和隐私边界可理解但不打扰主流程。
- 用户截图证明当前 gear 不可见，且工程说明文案影响真实 UI 评估。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneContextHeader.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneMainChromeTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSummaryView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

## 涉及的文档路径

- `docs/plans/done/2026-05-18-bug-ios-settings-entry-and-demo-copy.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`

## 实施方案

1. 给 `PhoneContextHeader` 增加 `onLanguageSpaceAction` 和 `onSettingsAction`，把语言空间胶囊和设置齿轮作为可点击控件渲染在同一行。
2. 从 `PhonePage` 参数中移除 `statusTextKey` 和 `statusArgument`，删除顶部 status 行与 toolbar gear / language space toolbar 入口。
3. 记录页 `SectionHeader` 只保留“最近的生活记录”标题，不显示 mock 学习材料说明。
4. 练习页和记忆页的主 section 也先去掉未接入/本地 mock subtitle，让列表自身承载内容；不可用状态保留在空状态、详情或能力说明中。
5. 增加源代码级回归测试，确认 iPhone 主页面 header 使用 `Button` 提供语言空间与设置入口，并且主页面不再引用 `phone.entries.status`、`phone.practice.status`、`phone.memory.status` 和 `phone.today.recent.subtitle`。

## 回归测试方案

- `swift test --package-path Packages/LangoTraceUI`
- `scripts/verify.sh`
- iPhone 17 模拟器重启、安装并启动，确认记录页顶部可见齿轮按钮，点击可进入设置；确认截图中标记的工程说明文字不再出现。

## 复查方法

- 代码检查 `PhoneContextHeader` 中设置入口为 `Button`，具备 `accessibilityLabel(localizedText("tab.settings"))`。
- 代码检查 `PhonePage` 不再计算或展示 `statusText`。
- 模拟器检查记录页、练习页、记忆页的主界面不展示 mock / SQLite 工程状态说明。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git status --short
```

## 文档影响检查

本任务符合现有导航和 UI 设计规范，不改变核心产品决策、平台策略、数据/AI/同步/付费边界，不需要新增 ADR。本方案已移入 `docs/plans/done/` 并记录验证结果。

## 实施记录

- 2026-05-18：创建方案并进入实现。
- 2026-05-18：新增 `PhoneMainChromeTests`，先验证旧实现失败：`PhoneContextHeader` 没有设置按钮，`PhoneMainSections` 仍引用 `statusTextKey`、`statusArgument` 和主页面 mock 状态 key。
- 2026-05-18：新增 `PhoneContextHeader.swift`，把 iPhone 顶部上下文改为可点击语言空间胶囊和 44pt 设置齿轮按钮。
- 2026-05-18：更新 `PhoneMainSections.swift`，移除 `PhonePage` 的 status 文案参数、顶部 status 行和记录/练习/记忆主 section 的工程说明 subtitle。
- 2026-05-18：更新 `PhoneMainSupportingViews.swift`，删除 hero 中“照片和语音当前为未接入能力”的主路径提示，并让 `SectionHeader` 在没有 subtitle 时不渲染空文本。
- 2026-05-18：将新增 header 和新增测试拆到独立文件，避免增加 SwiftLint 文件长度或类型长度 warning。
- 2026-05-18：`swift test --package-path Packages/LangoTraceUI` 通过，35 个测试通过。
- 2026-05-18：`scripts/verify.sh` 通过。覆盖 XcodeGen、Core/Data/UI tests、iPhone 17/iPad Pro/macOS build、SwiftLint、SwiftFormat、docs placeholder scan。SwiftLint 仅剩既有 3 个 warning：`PremiumUIBehaviorTests.swift` line length、`PremiumUIBehaviorTests.swift` type body length、`LearningContentComponents.swift` file length。
- 2026-05-18：重启 iPhone 17 模拟器，安装并启动新版 app；完成 Welcome -> Onboarding -> Main 路径；记录页可见设置齿轮，点击进入设置；语言空间胶囊点击打开语言空间摘要 sheet；记录页不再显示用户截图中标记的 mock / SQLite 工程说明。

## 模拟器验证截图

- `/private/tmp/langotrace-ui-review/iphone17-settings-entry-fix-record.png`
- `/private/tmp/langotrace-ui-review/iphone17-settings-entry-fix-settings.png`
- `/private/tmp/langotrace-ui-review/iphone17-settings-entry-fix-language-space.png`

## 完成标准

- iPhone 主界面可见设置齿轮按钮。
- 点击齿轮进入设置列表。
- 点击语言空间胶囊打开语言空间摘要。
- 记录页不再显示“当前仅为本地 mock 记录，SQLite 尚未接入。”。
- 记录页不再显示“选择一条记录查看本地 mock 学习材料。”。
- LangoTraceUI 测试和全量验证脚本通过。
- 模拟器主界面截图完成复查。

## 剩余风险

- 模拟数据内容本身仍可能包含 “mock” 概念的设置或详情说明；本任务只移除普通用户主页面中的工程状态说明，不伪装真实未接入能力。
