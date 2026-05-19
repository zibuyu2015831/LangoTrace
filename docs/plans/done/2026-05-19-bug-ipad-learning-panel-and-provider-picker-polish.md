# iPad 学习面板上下文与 Provider 选择器显示修复方案

Status: Verified

Type: bug

Created: 2026-05-19

Last Updated: 2026-05-19

## 用户确认记录

- 2026-05-19：用户在 iPad AI Provider 设置页测试时指出右侧学习面板显示不美观。
- 2026-05-19：用户在 iPhone AI Provider 设置页测试时指出 Provider 名称没有充分利用页面空间。
- 2026-05-19：用户要求创建一个方案，一并修复发现的两个问题。

## 需求描述

本轮合并修复两个 UI 问题：

1. iPad 进入 AI Provider 设置详情时，右侧仍显示围绕当前生活记录生成的学习面板和请求预览，和当前设置任务上下文不一致，视觉上也挤压主表单。
2. iPhone AI Provider 设置页中，长 Provider 名称例如 `Custom OpenAI-compatible` 在右侧 Picker 中换成多行，没有充分利用 Provider 行的横向空间，影响专业感和可读性。

## 现状描述

### iPad 右侧学习面板

`PadMainView.learningPanel` 当前只向 `PadLearningPanelView` 传入：

- `selectedEntry`
- `selectedRendering`
- `memoryItems`
- `contentStore`
- `onRoute`

没有传入当前 `route`。

`PadLearningPanelView` 只根据 `selectedEntry` 决定内容：

- 有选中记录：显示当前句子讲解、词句提取、进入练习、空间设置和 `RequestPreviewCard`。
- 无选中记录：显示学习面板空状态。

因此，当主区 route 是 `.settings(.aiProvider)`、`.settingsList`、`.memory`、`.importExport` 或 `.languageSpaceSummary` 时，只要仍有选中记录，右侧就继续显示 entry 学习上下文。

### iPhone Provider 名称换行

`AIProviderRowPicker` 当前结构是：

```swift
HStack {
    localizedText("aiProviderSettings.provider.title")
    Spacer(minLength: 12)
    Picker(selection: $provider) { ... }
        .pickerStyle(.menu)
        .labelsHidden()
}
```

SwiftUI 的 menu picker 不会自动把选中值按“占满剩余宽度的右侧文本”排版。长名称会在 Picker 自身紧凑宽度内换行，截图中 `Custom OpenAI-compatible` 被拆成三行。

## 复现方式

### iPad

1. 启动 iPad 模拟器。
2. 进入主工作台。
3. 保持右侧学习面板展开。
4. 从左侧底部 AI 图标或设置列表进入 AI Provider 设置详情。
5. 观察右侧仍显示“学习面板”、当前句子讲解、词句提取、练习入口和请求预览。

### iPhone

1. 启动 iPhone 模拟器。
2. 进入 AI Provider 设置页。
3. 展开或启用向量模型。
4. 将 Provider 选择为 `Custom OpenAI-compatible`。
5. 观察右侧 Picker 选中值多行换行，没有充分利用行宽。

## 预期行为

### iPad

- 当 route 是 `.workspace`、`.entryDetail` 或 `.practice` 时，右侧学习面板继续围绕当前 entry 展示学习上下文。
- 当 route 是 `.settingsList`、`.settings(_)`、`.memory`、`.importExport` 或 `.languageSpaceSummary` 时，右侧不显示 entry 学习内容和请求预览。
- 设置 route 的右侧内容应变为低干扰的设置上下文，或至少不与当前设置任务冲突。
- 不自动修改用户的右侧面板展开状态；用户仍可手动收起 / 展开。

### iPhone Provider 行

- Provider label 和选中值保持同一行。
- 右侧选中值充分利用剩余宽度，优先单行显示。
- 超长名称不得竖向换成多行；极限情况下可以缩小或尾部省略。
- 不牺牲 Picker 的可点击区域和 VoiceOver 可读性。

## 实际行为

- iPad 设置页右侧显示 entry 学习上下文，信息层级混乱，`RequestPreviewCard` 在设置任务中显得突兀。
- iPhone Provider 选中值在紧凑 menu picker 内多行换行，破坏表单节奏。

## 根因分析

1. `PadLearningPanelView` 的内容决策只依赖 `selectedEntry`，没有 route awareness。它把“有当前记录”误当成“所有页面都应该展示学习面板内容”。
2. `AIProviderRowPicker` 没有给 Picker 建立明确的剩余宽度、单行和压缩策略；menu picker 以自身 intrinsic width 布局，长值在狭窄区域换行。

置信度：92%

## 置信度依据

- 代码搜索确认 iPad `.settings(.aiProvider)` 通过 `PadWorkspaceContentView.settingDetail(kind:)` 渲染中间设置详情，但右侧 `learningPanel` 不接收 route。
- `PadLearningPanelView.selectedEntryContent` 中无条件渲染 `RequestPreviewCard(entry:rendering:)`。
- `AIProviderRowPicker` 源码中没有 `.lineLimit(1)`、`.minimumScaleFactor`、`.truncationMode` 或右侧 `maxWidth` 约束。
- 用户截图与源码行为一致。

## 备选原因

- 右侧面板不美观也可能部分来自面板宽度、卡片密度或中英文混排，但本轮最直接的问题是 route 语义错误。若修复后仍觉得拥挤，可再做 iPad 学习面板视觉密度专项。
- Provider 名称换行也可能受 iOS menu picker 内部样式影响。若简单 frame/lineLimit 不能完全控制，需要改为自定义 `Menu` 或 `Button` 展示选中值，再弹出菜单。

## 目标

1. iPad 设置、记忆、导入导出和语言空间摘要 route 不再展示当前 entry 学习内容和请求预览。
2. iPad 设置 route 的右侧面板显示与当前任务一致的低干扰上下文。
3. iPhone / iPad / macOS 共享的 Provider 行在长名称下保持单行、右对齐和合理压缩。
4. 通过源码级回归测试锁住边界。

## 范围和不做什么

本轮做：

- 给 iPad 学习面板传入当前 `PadWorkspaceRoute`。
- 为非 entry 学习 route 提供 route-aware 右侧内容。
- 修复 `AIProviderRowPicker` 的布局约束。
- 更新页面清单和必要规范。
- 增加测试。

本轮不做：

- 不重做 iPad 三栏架构。
- 不默认自动收起右侧学习面板。
- 不重做所有 settings 页视觉。
- 不实现真实 Provider 请求、Keychain 或网络测试。
- 不把 Provider picker 改成平台独立控件，除非原生 picker 无法满足单行显示。

## 设计方案

### 方案 A：设置页自动收起右侧学习面板

进入 `.settingsList` 或 `.settings(_)` 时自动把 `isLearningPanelVisible = false`。

优点：主表单空间最大。

缺点：会修改用户面板状态，route 切换时页面跳动明显，也削弱 iPad 工作台三栏一致性。

结论：不采用。

### 方案 B：右侧学习面板 route-aware

给 `PadLearningPanelView` 增加 `route` 参数。

- `.workspace`、`.entryDetail`、`.practice`：继续显示当前 entry 学习内容。
- `.settingsList`、`.settings(_)`：显示设置上下文，包含 AI Provider、同步和隐私边界的简短说明，不能出现 `RequestPreviewCard`。
- `.memory`：显示记忆上下文。
- `.importExport`：显示导入导出上下文。
- `.languageSpaceSummary`：显示语言空间上下文。

优点：不改变面板展开状态，内容语义正确，符合 iPad 工作台“右侧承载上下文”的设计。

缺点：需要增加少量文案和测试。

结论：采用。

### Provider 选择器方案

优先保持 `Picker(.menu)`，但改造 `AIProviderRowPicker`：

- 左侧 label 固定。
- Picker 占用剩余宽度并右对齐。
- 对 Picker 及其 label 设置单行、尾部省略和最小缩放。
- 保持 `minimumTouchTarget`。

如果验证发现原生 `Picker(.menu)` 仍不能控制显示，再升级为自定义 `Menu`，显示层用 `Text(provider.displayName)` 明确控制单行，菜单内列出全部 provider。

## 涉及代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`

## 参考代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ContentUtilityComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`

## 涉及文档路径

- `docs/platform-page-inventory.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- 本方案：`docs/plans/active/2026-05-19-bug-ipad-learning-panel-and-provider-picker-polish.md`

## 实施方案

1. TDD：新增测试，先确认当前代码失败。
   - iPad route-aware 测试：`PadLearningPanelView` 源码应接收 `route`，非 entry route 不渲染 `RequestPreviewCard` 主路径。
   - Provider picker 测试：`AIProviderRowPicker` 源码应包含单行、压缩、尾部省略和右侧宽度策略。
2. 实现 iPad 学习面板 route-aware。
   - `PadMainView.learningPanel` 传入 `route`。
   - `PadLearningPanelView` 根据 route 切换内容。
   - 设置 route 使用简洁上下文，不展示当前句子和请求预览。
3. 实现 Provider picker 单行宽度策略。
   - 先尝试增强原生 Picker。
   - 若不稳定，改为 `Menu` + 自定义显示 label。
4. 补充本地化文案。
5. 更新页面清单和必要规范。
6. 验证并移动方案到 `docs/plans/done/`。

## 回归测试方案

- `PageClosureStateTests` 增加 iPad 学习面板 route-aware 结构测试。
- `AIProviderSettingsTests` 增加 Provider row 单行布局源码测试。
- 保留已有 AI Provider 设置测试和三端 page closure 测试。

## 复查方法

代码复查：

- 确认 `PadLearningPanelView` 不再只用 `selectedEntry` 决定所有 route 内容。
- 确认 `RequestPreviewCard` 只在 entry 学习上下文中显示。
- 确认 Provider 名称显示有单行和宽度策略。

手动复查：

- iPad AI Provider 设置页右侧不显示“当前句子 / 请求预览”。
- iPad 工作台 entry detail 右侧仍显示学习上下文。
- iPhone 选择 `Custom OpenAI-compatible` 后，Provider 行不再多行换行。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceUI
swiftlint --no-cache
swiftformat --lint . --cache ignore
python3 -m json.tool Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
scripts/verify.sh
```

## 文档影响检查

- 需要更新 `docs/platform-page-inventory.md` 中 iPad 右侧学习面板边界。
- 如实现确认 route-aware 面板成为长期规则，应补充 `docs/spec/002-navigation-and-routing.md` 或 `docs/spec/003-ui-design-system.md`：右侧学习面板是 route context，不是永远跟随 selected entry。
- 不需要 ADR；不改变核心产品决策、Provider 安全存储决策或三端架构。

## 实施记录

- `PadMainView.learningPanel` 现在把当前 `route` 传给 `PadLearningPanelView`。
- 新增 `PadLearningPanelView.swift`，把 iPad 右侧面板从 `PadMainSections.swift` 拆出，避免文件长度越界，也让右侧上下文职责独立。
- `PadLearningPanelView` 根据 `PadWorkspaceRoute` 切换右侧内容：
  - `.workspace`、`.entryDetail`、`.practice` 保留当前 entry 学习内容和 `RequestPreviewCard`。
  - `.settingsList`、`.settings(_)` 改为设置上下文，只展示 AI Provider、同步和隐私边界摘要。
  - `.memory`、`.importExport`、`.languageSpaceSummary` 展示对应 route 的低干扰上下文。
- `AIProviderRowPicker` 改为 `Menu` + 自定义单行 label，长 Provider 名称使用右对齐、单行、最小缩放和尾部省略策略。
- 补充 iPad route-aware 右侧面板文案，并避免在设置上下文里重复暴露过重的技术说明。
- 更新 `docs/platform-page-inventory.md`、`docs/spec/002-navigation-and-routing.md` 和 `docs/spec/003-ui-design-system.md`，固化 iPad 右侧面板是 route context 的规则。

## 验证记录

2026-05-19 已通过：

- `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests/padLearningPanelSwitchesContentByWorkspaceRoute`
- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests/providerRowKeepsLongNamesOnOneLine`
- `swift test --package-path Packages/LangoTraceUI`
- `swiftlint --no-cache`
- `swiftformat --lint . --cache ignore`
- `python3 -m json.tool Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `git diff --check`
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'` 无命中
- `scripts/verify.sh`

## 完成标准

- 两个用户截图中暴露的问题均有代码级修复。
- 回归测试覆盖两个问题。
- iPad 设置 route 不再显示 entry 学习内容和请求预览。
- Provider 长名称不再在行内竖向换成多行。
- 文档同步完成。
- 验证命令通过。

## 剩余风险

- 原生 `Picker(.menu)` 的显示行为可能仍受系统控件限制；若无法稳定控制，需要改为自定义 `Menu`。
- 本轮不全面重做 iPad 右侧面板密度；route-aware 修复后若视觉仍偏重，需要另做 iPad 面板设计专项。
