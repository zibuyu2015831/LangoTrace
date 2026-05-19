# iOS 设置页当前空间重复说明精简方案

状态：Verified

类型：bug

创建日期：2026-05-20

最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户指出 iOS 设置页已经有专门的“语言空间”选项，截图中圈住的“当前空间”说明块显得多余，要求考虑去除。
- 2026-05-20：已确认采用“删除红框说明块，保留顶部语言空间胶囊和语言空间卡片”的方案；用户要求立即创建任务方案，确认无误后开始实施。

## 需求或 bug 描述

iOS 设置页顶部已通过语言空间胶囊展示当前语言空间上下文，设置列表第一项也提供“语言空间”详情入口。当前额外显示的“当前空间”说明块不承担导航或操作功能，并重复解释语言空间相关信息，导致设置页首屏层级偏重。

## 复现方式

1. 启动 iPhone 版本。
2. 进入主界面后点击设置入口。
3. 观察设置标题下方、设置卡片列表上方的“当前空间”说明块。

## 预期行为

iOS 设置页应直接展示可操作设置项。当前语言空间上下文由顶部语言空间胶囊表达，语言空间详情由“语言空间”卡片进入，不再额外显示不可点击的“当前空间”说明块。

## 实际行为

设置页在顶部语言空间胶囊和“语言空间”设置卡片之外，额外显示“当前空间 / 查看 AI、同步、本地数据和隐私偏好。”说明块，造成重复。

## 根因分析

`SettingsView` 在设置列表内容前固定插入 `SectionHeader(titleKey: "phone.settings.currentSpace.title", subtitleKey: "phone.settings.currentSpace.subtitle")`。该说明块早期用于解释设置页上下文，但在语言空间胶囊和独立“语言空间”入口完成后已经失去独立价值。

置信度：92%

置信度依据：

- `SettingsView` 只有这一处直接引用 `phone.settings.currentSpace.*`。
- `PhonePage` 已统一渲染 `PhoneContextHeader`，可展示当前语言空间。
- `SettingsCapability.Kind.languageSpace` 已作为设置列表第一项提供详情入口。

备选原因：

- 如果后续设计希望设置页有分组标题，应新增更通用的设置分组标题，而不是保留“当前空间”说明块。

## 目标

- 删除 iOS 设置页不可点击的“当前空间”说明块。
- 保留顶部语言空间胶囊。
- 保留“语言空间”设置卡片和详情页。
- 增加回归测试，防止该重复说明块回到设置页。

## 范围

本次只修改 iOS 设置列表的冗余说明块和相关测试。

## 不做什么

- 不修改 iPad / macOS 设置入口。
- 不改变语言空间模型、设置能力列表、详情页或导航结构。
- 不调整设置页整体视觉系统。
- 不删除 String Catalog 中可能仍未引用的旧 key，避免为了小 UI 修正扩大本地化资源 churn。

## 证据与决策依据

- `docs/platform-page-inventory.md` 记录 iPhone 设置列表通过顶部 gear 进入，设置项包含语言空间、AI、同步、隐私、导出、界面语言等能力边界。
- `docs/spec/006-interface-localization-and-language-boundaries.md` 规定设置入口需区分界面语言与语言空间，且设置不应占用主操作位置。
- 截图中红框内容与顶部语言空间胶囊及“语言空间”卡片重复。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneContextHeader.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSummaryView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

## 涉及的文档路径

- `docs/plans/done/2026-05-20-bug-ios-settings-current-space-duplicate-summary.md`
- `docs/platform-page-inventory.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`

## 实施方案

1. 在 `PageClosureStateTests.swift` 增加源码级回归测试：`SettingsView` 不再引用 `phone.settings.currentSpace.title` 和 `phone.settings.currentSpace.subtitle`，同时仍引用 `PhonePage`、`settings.languageSpace.title` 相关能力入口。
2. 运行 `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests`，确认测试先失败。
3. 从 `SettingsView` 删除 `SectionHeader(titleKey: "phone.settings.currentSpace.title", subtitleKey: "phone.settings.currentSpace.subtitle")`。
4. 再次运行同一测试，确认通过。
5. 运行 `swift test --package-path Packages/LangoTraceUI` 和 `git diff --check`。
6. 更新本方案实施记录和验证结果。

## 回归测试方案

通过 `PageClosureStateTests` 对 `PhoneMainSections.swift` 做源码约束，防止设置页再次渲染 `phone.settings.currentSpace.*` 的不可点击说明块。该测试聚焦当前 bug，不覆盖全截图渲染。

## 复查方法

- 代码复查：确认 `SettingsView` 内容区直接从设置能力列表开始。
- 测试复查：确认新增测试先失败后通过。
- 文档复查：确认没有改变长期产品决策或设置入口规则。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
git status --short
```

## 文档影响检查

本次是小范围 iOS UI 去重，不改变语言空间、设置入口、界面语言、导航或长期架构规范。无需更新 `docs/spec/` 或 ADR。本方案作为任务记录保留。

## 实施记录

- 2026-05-20：创建方案。
- 2026-05-20：新增 `phoneSettingsListOmitsDuplicateCurrentSpaceExplainer` 回归测试，首次运行 `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests` 失败，失败点为 `PhoneMainSections.swift` 仍引用 `phone.settings.currentSpace.title` 和 `phone.settings.currentSpace.subtitle`。
- 2026-05-20：删除 `SettingsView` 中的 `SectionHeader(titleKey: "phone.settings.currentSpace.title", subtitleKey: "phone.settings.currentSpace.subtitle")`，设置页内容区直接进入 `ForEach(capabilities)`。
- 2026-05-20：再次运行 `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests`，15 个测试通过。
- 2026-05-20：运行 `swift test --package-path Packages/LangoTraceUI`，103 个测试通过。
- 2026-05-20：运行 `git diff --check`，无输出。
- 2026-05-20：运行 `scripts/verify.sh`，完成 XcodeGen、Core/Data/UI package 测试、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位扫描，命令退出码为 0。

## 完成标准

- iOS 设置页不再渲染“当前空间”说明块。
- 顶部语言空间胶囊仍存在。
- “语言空间”设置卡片仍作为详情入口存在。
- 新增回归测试覆盖该去重约束。
- 目标验证命令通过，或明确记录无法运行的原因和风险。

## 剩余风险

- 本次不做截图级 UI 自动化验证；最终视觉仍以模拟器人工检查或后续截图验证为准。
