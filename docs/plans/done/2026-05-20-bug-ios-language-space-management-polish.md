# iOS 语言空间管理界面修复

状态：Verified

类型：bug

创建日期：2026-05-20

最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户通过截图指出新增空间表单暴露未本地化 key、语言空间重命名入口不直观、删除功能缺乏显性发现性。
- 2026-05-20：经确认，采用“保留左滑快捷操作，去除当前状态右侧勾选图标，改为当前行样式状态”的修复方向，用户回复“好，立即完成相关修改”。
- 2026-05-20：用户继续确认：删除按钮应使用更符合破坏性操作的颜色，底部说明可删除，顶部“当前语言空间”区域可由列表内当前样式替代。
- 2026-05-20：用户继续指出编辑 sheet 不只重命名，还可调整语言和等级，应改为“编辑”；设置首页是 App 级设置，不应显示单独空间胶囊。
- 2026-05-20：用户继续指出编辑 sheet 内容较少，当前全高弹窗留白过多，应适当降低弹窗高度。
- 2026-05-20：用户继续通过截图指出编辑 sheet 虽已降低高度，但默认 `Form` 灰底和大块留白仍显临时，要求重新设计为更有高级感且契合项目主题的弹窗界面。

## Bug 描述

iOS 语言空间管理页存在三类体验问题：

1. 新增空间表单中的母语和目标语言字段显示 `onboarding.nativeLanguage.title` / `onboarding.targetLanguage.title` 原始 key。
2. 当前语言空间右侧 `checkmark.circle.fill` 看起来像可点击状态按钮，实际只是状态标记。
3. 重命名和删除仅依赖左滑或上下文菜单发现，当前可保留左滑快捷操作，但当前状态图标不应与操作区竞争。
4. 顶部“当前语言空间”和“所有语言空间”中的当前行重复表达同一状态，底部说明卡片降低管理页信息密度。
5. 编辑 sheet 支持空间名称、母语、目标语言和当前水平调整，左滑动作和 sheet 标题仍叫“重命名”，语义不准确。
6. 设置首页复用通用页面头部，顶部显示当前语言空间胶囊，容易把 App 级设置误导为空间级设置。
7. 编辑 / 新增空间 sheet 内容较少，但默认以接近全屏高度展示，造成明显空白。
8. 编辑 / 新增空间 sheet 改为中等高度后，内部仍使用系统 `Form`，灰底分组和空白与语迹暖纸色、teal 主题和轻量设置面板不一致。

## 复现方式

1. 在 iPhone 17 模拟器进入设置。
2. 打开语言空间管理页。
3. 点击右上角新增空间按钮。
4. 返回语言空间列表并观察当前语言空间行、所有语言空间行和左滑状态。

## 预期行为

- 表单字段显示已本地化文案，例如“母语”“目标语言”。
- 当前语言空间在列表中以行样式体现状态，不显示像按钮的勾选图标。
- 页面只保留一个语言空间列表，当前空间排在列表顶部并用行样式标记。
- 左滑保留“删除 / 编辑”快捷操作。
- 编辑 sheet 标题使用“编辑空间”，新增 sheet 标题保持“新增空间”。
- 删除使用 iOS 破坏性操作语义，说明文字只在删除确认中出现。
- iPhone 设置首页不显示当前空间胶囊，只展示 App 级设置分类卡片。
- 编辑 / 新增空间 sheet 在 iOS 上默认使用中等高度，并可上拉展开到大高度。
- 编辑 / 新增空间 sheet 使用语迹主题化紧凑编辑卡片，不再显示默认 `Form` 灰底。
- 当前状态对 VoiceOver 有明确语义。

## 实际行为

- 表单字段暴露原始本地化 key。
- 当前状态使用右侧勾选图标，视觉上像独立按钮。
- 左滑展开时勾选图标与操作区产生视觉竞争。
- “重命名”文案低估了编辑页实际能力。
- 设置首页顶部空间胶囊和“语言空间”设置卡片形成信息架构重复。
- 编辑 sheet 大量空白削弱了轻量管理操作的感觉。

## 根因分析

- `LanguageSpaceManagementView` 误用了不存在的 `onboarding.nativeLanguage.title` 和 `onboarding.targetLanguage.title` key。
- `LanguageSpaceManagementRow` 将当前状态编码为右侧 `Image(systemName: "checkmark.circle.fill")`，没有把当前状态作为整行样式处理。

置信度：95%

## 置信度依据

- 代码路径直接匹配截图暴露的 key。
- `Localizable.xcstrings` 中存在 `onboarding.nativeLanguage` / `onboarding.targetLanguage`，不存在 `.title` 变体。
- 当前状态图标由 `LanguageSpaceManagementRow` 的 `isCurrent` 分支直接渲染。
- `LanguageSpaceManagementView` 同时渲染 `currentSection`、`allSpacesSection` 和 `guidanceSection`，导致当前状态和说明文案重复占用首屏。
- `LanguageSpaceManagementView` 将 edit 模式标题和行操作复用 `settings.languageSpace.management.rename`。
- `SettingsView` 直接复用带 `PhoneContextHeader` 的 `PhonePage`，没有区分 App 级设置页和学习上下文页。
- `LanguageSpaceManagementView` 的 editor sheet 未指定 iOS presentation detents，系统按默认较大高度展示。

## 备选原因

- 如果运行时 bundle 语言选择异常，也可能导致局部 key fallback；但当前同页其他文案正常，且字符串表确实缺失 `.title` key，故不是主要原因。

## 目标

- 修复新增/编辑空间表单的本地化 key 泄漏。
- 将当前状态改成行级视觉状态：浅色背景、左侧强调色条、文本胶囊“当前”。
- 保留左滑删除和编辑快捷操作。
- 删除顶部当前空间分区和底部持久说明卡片，把删除风险说明保留在确认弹窗。
- 单一列表内将当前空间优先排在第一行。
- 将编辑动作和编辑 sheet 标题从“重命名”改为“编辑 / 编辑空间”。
- 移除 iPhone 设置首页顶部当前空间胶囊，其他主学习页面继续保留上下文 header。
- iOS editor sheet 使用 `.medium` 和 `.large` detents，默认紧凑展示，同时保留上拉展开能力。
- 补充源码级回归测试，防止旧 key 和旧图标回归。

## 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceEditorView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceManagementTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- 本任务方案文档

## 不做什么

- 不开发 iPad / macOS 完整语言空间管理 UI。
- 不改变语言空间 Repository、数据库 schema 或删除语义。
- 不新增恢复入口。
- 不把左滑快捷操作移除。

## 证据与决策依据

- iOS 设置类页面应让状态作为行属性呈现，而不是伪装成独立按钮。
- 左滑是合适的高级快捷操作，但不应由当前状态图标承担操作暗示。
- 破坏性操作应使用系统 destructive 语义，避免和语迹的绿色确认/当前状态混淆。
- 管理页中重复的当前分区和持久说明卡片会降低首屏扫描效率；删除风险应在用户触发删除时再确认。
- 操作文案应反映真实编辑范围；当页面可改语言和等级时，“编辑”比“重命名”更准确。
- 设置首页是全 App 能力入口，不应在首屏顶部突出某一个语言空间；空间上下文应留在语言空间卡片和管理页中表达。
- 编辑表单只有少量字段，默认中等高度更符合轻量管理任务；保留 `.large` detent 能覆盖键盘、动态字体和长内容兜底。
- 对于少量字段的 iOS sheet，使用自定义紧凑 panel 比系统 `Form` 更能保持信息密度和品牌主题；交互控件仍保留原生 `TextField` / `Picker(.menu)`，避免牺牲键盘、菜单和可访问性行为。
- 当前数据层已支持删除、重命名、切换，本轮只修正 iOS UI 表达。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceEditorView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceManagementTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`

## 涉及的文档路径

- `docs/plans/done/2026-05-20-bug-ios-language-space-management-polish.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`

## 实施方案

1. 将表单 Picker 的 key 改为现有 `onboarding.nativeLanguage` / `onboarding.targetLanguage`。
2. 删除 `checkmark.circle.fill` 当前状态图标。
3. 在当前行左侧增加强调色条，行背景使用 `surfaceSelected`，右侧使用文本胶囊“当前”。
4. 为当前行补充明确可访问性 value。
5. 删除独立 `currentSection` 和 `guidanceSection`，只保留 `allSpacesSection`。
6. 通过 `displayedSpaces` 将当前空间移动到单一列表顶部。
7. 删除左滑按钮保持 `role: .destructive`，让系统使用破坏性操作颜色。
8. 新增 `settings.languageSpace.management.edit` 和 `settings.languageSpace.management.editTitle`，移除 `rename` 入口使用。
9. 为 `PhonePage` 增加 `showsContextHeader` 开关，设置首页关闭上下文 header，其他页面保持默认显示。
10. 为语言空间 editor sheet 增加 iOS-only `langoEditorSheetPresentation`，使用 `.medium` / `.large` detents 和可见 drag indicator。
11. 将 editor sheet 内部从系统 `Form` 改为语迹主题化自定义编辑卡片：暖纸色背景、raised panel、teal 侧轨、56pt 字段行、菜单式 Picker 和轻量 warning chip。
12. 将 editor sheet 实现拆分到 `LanguageSpaceEditorView.swift`，避免语言空间管理页文件过长并保持列表管理和编辑表单职责分离。
13. 更新 UI 源码测试，覆盖本地化 key、当前状态样式、单列表信息架构、左滑操作、编辑文案、设置首页无空间胶囊、紧凑 sheet 和自定义编辑卡片。

## 回归测试方案

- UI 源码测试断言：
  - 不再包含 `onboarding.nativeLanguage.title` 和 `onboarding.targetLanguage.title`。
  - 保留 `swipeActions`、`edit`、`delete`。
  - 删除动作使用 `Button(role: .destructive)`。
  - 不再包含 `checkmark.circle.fill`。
  - 当前状态使用 `currentPill` 和行级背景/强调样式。
  - 不再包含 `currentSection` 和 `guidanceSection`。
  - 不再使用 `settings.languageSpace.management.rename`。
  - `SettingsView` 传入 `showsContextHeader: false`。
  - editor sheet 使用 `langoEditorSheetPresentation`、`presentationDetents([.medium, .large])` 和可见 drag indicator。
  - editor sheet 不再使用 `Form`，改用 `LanguageSpaceEditorCard`、`LanguageSpaceEditorFieldRow`、语迹纸色背景和菜单式 Picker。

## 复查方法

- 代码审查 `LanguageSpaceManagementView` 中 Picker key、当前行布局和左滑动作。
- 运行 `swift test --package-path Packages/LangoTraceUI`。
- 运行 `scripts/verify.sh`。
- 如时间允许，iPhone 17 模拟器人工确认新增空间表单、当前行样式和左滑操作。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 文档影响检查

本任务不改变长期产品决策、数据模型、Repository 边界或删除语义；无需更新 ADR 或数据规范。由于本轮形成了可复用 UI / SwiftUI 组织经验，已同步更新 UI 设计系统规范和 SwiftUI 架构规范。

## 实施记录

- 2026-05-20：创建任务方案。
- 2026-05-20：修复新增/编辑空间表单本地化 key，改用已存在的 `onboarding.nativeLanguage` 和 `onboarding.targetLanguage`。
- 2026-05-20：去除当前状态右侧 `checkmark.circle.fill`，改为当前行浅色背景、左侧强调色条和文本胶囊。
- 2026-05-20：保留左滑删除和编辑快捷操作。
- 2026-05-20：删除顶部“当前语言空间”分区和底部说明卡片，改为单一语言空间列表。
- 2026-05-20：单一列表中将当前语言空间排序到首位，删除说明只保留在确认弹窗。
- 2026-05-20：将语言空间操作文案从“重命名”改为“编辑”，编辑 sheet 标题改为“编辑空间”。
- 2026-05-20：设置首页关闭 `PhoneContextHeader`，移除顶部当前空间胶囊。
- 2026-05-20：为 iOS 编辑 / 新增空间 sheet 设置中等高度默认展示，并保留大高度展开。
- 2026-05-20：补充 UI 源码回归测试，覆盖本地化 key、当前行状态样式和左滑操作。
- 2026-05-20：补充 UI 源码回归测试，覆盖单列表结构、无持久说明卡片和 destructive 删除语义。
- 2026-05-20：补充 UI 源码回归测试，覆盖编辑文案和设置首页无上下文 header。
- 2026-05-20：补充 UI 源码回归测试，覆盖 iOS editor sheet 中等高度和可展开设置。
- 2026-05-20：重新设计编辑 / 新增空间 sheet 内部样式，去除系统 `Form` 灰底，改为语迹主题化紧凑编辑卡片。
- 2026-05-20：补充 UI 源码回归测试，覆盖自定义编辑卡片、语迹纸色背景、菜单式 Picker 和不再使用默认 `Form`。
- 2026-05-20：将编辑器实现拆分到 `LanguageSpaceEditorView.swift`，消除 `LanguageSpaceManagementView.swift` 文件长度 warning。
- 2026-05-20：将共性经验沉淀到 `docs/spec/003-ui-design-system.md` 和 `docs/spec/004-swiftui-architecture.md`：iPhone 管理类 sheet 应使用主题化轻量编辑面板；管理页和多字段 editor 应按职责拆分。
- 2026-05-20：`swift test --package-path Packages/LangoTraceUI` 通过。
- 2026-05-20：`scripts/verify.sh` 通过，覆盖 XcodeGen、Core/Data/UI tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位扫描。

## 完成标准

- 新增空间表单不再显示原始本地化 key。
- 当前空间不再显示右侧勾选图标。
- 当前状态以行级样式和文本胶囊表达。
- 页面不再重复显示顶部当前空间分区和底部说明卡片。
- 删除动作在左滑操作中使用破坏性语义。
- 左滑删除和编辑继续可用。
- 编辑页不再显示“重命名”，改为“编辑空间”。
- 设置首页不再显示顶部当前空间胶囊。
- 编辑 / 新增空间 sheet 默认不再全高展示，可上拉展开。
- 编辑 / 新增空间 sheet 内部视觉不再是默认 `Form`，而是与语迹主题一致的紧凑编辑面板。
- 相关测试和验证通过，或失败项有明确环境原因和剩余风险。

## 剩余风险

- 本轮只修复 iOS 已有管理页；iPad / macOS 完整管理体验仍按前一阶段策略后续展开。
- 本轮未使用自动截图做像素级验收；最终视觉仍建议由 iPhone 17 模拟器人工确认一次。
