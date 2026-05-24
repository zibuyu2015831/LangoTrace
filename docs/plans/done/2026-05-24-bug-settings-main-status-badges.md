# 设置主页面状态角标优化

状态：Verified
类型：bug
创建日期：2026-05-24
最后更新日期：2026-05-24

## 用户确认记录

用户在 2026-05-24 基于 iPhone 设置主页面截图指出，当前列表标题旁的 `可用`、`本地优先`、`待配置` 等角标来自 UI 设计阶段的临时开发标注，主要用于标记功能开发完整度，不是面向用户的信息。用户要求先更新规范文档，再创建设置主页面优化方案文档，最后修改代码。

## Bug 描述

设置主列表把开发阶段 completion marker 作为用户可见角标显示在每个 row 标题旁，导致页面像开发状态看板，而不是 Apple 风格的安静设置列表。

## 复现方式

1. 在 iPhone 打开设置主页面。
2. 查看 `语言空间`、`界面语言`、`外观`、`AI Provider`、`同步`、`本地数据`、`隐私边界` 等 row。
3. 观察标题旁出现 `可用`、`本地优先` 或 `待配置` 胶囊角标。

## 预期行为

设置主列表默认不显示开发阶段状态角标。每个 row 保留图标、标题、摘要和进入详情 chevron；正常能力状态、产品原则和开发完成度不进入用户主列表。真实异常、未配置、需重测、部分可用等后续用户可行动状态需要通过独立设置状态投影设计，不复用当前 completion marker。

## 实际行为

`SettingsView`、iPad 设置列表、macOS 工作台设置列表和 macOS Settings scene 都无条件使用 `CapabilityStatusRow`，而 `CapabilityStatusRow` 又无条件在标题旁渲染 `CapabilityStatusBadge(status:)`。

## 根因分析

根因是早期通用能力行组件把 `CapabilityStatus` 绑定为固定标题旁 badge，没有区分“能力详情 / 结果面板状态”和“设置主列表入口”。`CapabilityStatus` 本身也仍带有开发阶段标注语义，不能直接作为用户设置主列表信息。

置信度：95%

置信度依据：

- `CapabilityStatusRow.rowContent` 在标题 `HStack` 内无条件渲染 `CapabilityStatusBadge(status:)`。
- `SettingsView`、`PadMainSections.settingsList`、`MacWorkspaceContentView.settingsContent` 和 `LangoTraceSettingsSceneView.capabilityRows` 均使用该组件展示设置入口。
- `docs/spec/003-ui-design-system.md` 此前只有通用状态矩阵，没有设置主列表状态标记规则。

备选原因：

- 单个本地化文案不准确：不是主因，即使改文案，所有 row 仍会出现不必要角标。
- 颜色或 padding 问题：不是主因，信息层级和状态语义本身错误。

## 目标

- 更新 UI 设计系统规范，明确设置主列表不是开发状态看板。
- 创建架构开发备忘录，记录未来设置状态投影需要拆分开发完成度、详情状态和列表当前值。
- 修改设置主列表，让 iPhone、iPad、macOS 工作台和 macOS Settings scene 不再显示当前通用状态 badge。
- 保留 `CapabilityStatusBadge` 在记录详情、学习面板、能力详情、unavailable 说明和结果面板等上下文中的既有用途。
- 用 UI package 回归测试锁定设置主列表必须显式隐藏通用 badge，避免后续复发。

## 不做什么

- 不重做所有设置页视觉结构。
- 不新增数据库 schema 或真实设置状态投影。
- 不改变 AI Provider、同步、导入导出、权限或 Keychain 行为。
- 不删除 `CapabilityStatus` 和 `CapabilityStatusBadge`，因为其他页面仍需要它们表达状态。
- 不把 `未配置`、`未启用` 等未来真实状态立即接入设置主列表。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/SettingsMainStatusBadgeTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/CapabilityStatusBadge.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`

## 涉及的文档路径

- `docs/spec/003-ui-design-system.md`
- `docs/architecture/notes/2026-05-24-settings-status-projection-notes.md`
- `docs/plans/done/2026-05-24-bug-settings-main-status-badges.md`
- `docs/platform-page-inventory.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`

## 实施方案

1. 在 `docs/spec/003-ui-design-system.md` 新增设置主列表状态标记规则，明确正常状态和开发标注不显示。
2. 新增 `docs/architecture/notes/2026-05-24-settings-status-projection-notes.md`，记录后续真实设置状态投影的拆分方向。
3. 新增 `SettingsMainStatusBadgeTests` source-boundary 测试，断言设置主列表调用 `CapabilityStatusRow` 时显式隐藏状态 badge，同时确认共享 row 仍支持默认显示 badge，避免破坏其他页面。
4. 先运行聚焦测试，确认旧实现失败。
5. 给 `CapabilityStatusRow` 增加 `showsStatusBadge` 参数，默认 `true`；标题行只有在该参数为 `true` 时渲染 `CapabilityStatusBadge`，accessibility label 同步避免隐藏状态后仍读出开发 marker。
6. 在 iPhone / iPad / macOS 设置主列表和 macOS Settings scene 中传入 `showsStatusBadge: false`。
7. 更新页面清单和 MVP UI flow 规范，记录设置主列表不显示开发阶段角标。
8. 运行聚焦测试、UI package 测试、文档检查和必要的完整验证。

## 复查方法

- 检查设置主列表的所有入口都显式隐藏状态 badge。
- 检查 `CapabilityStatusRow` 默认仍显示 badge，以保留其他能力状态组件行为。
- 检查 hidden 状态不会进入设置主列表的 accessibility label。
- 检查 docs/spec 与架构备忘录表达一致。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter SettingsMainStatusBadgeTests
swift test --package-path Packages/LangoTraceUI
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
scripts/verify.sh
```

## 文档影响检查

本任务改变设置主列表 UI 信息层级和状态组件使用规则，需要同步 `docs/spec/003-ui-design-system.md`、`docs/platform-page-inventory.md` 和 `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`。未来真实设置状态投影不在本次实现范围，已沉淀为架构开发备忘录。

## 实施记录

- 2026-05-24：创建方案前已确认无 active plan 处理同一设置主列表角标问题。
- 2026-05-24：已更新 UI 设计系统规范，明确设置主列表不是开发进度看板。
- 2026-05-24：已新增设置状态投影架构开发备忘录。
- 2026-05-24：新增 `SettingsMainStatusBadgeTests`，红灯确认旧实现缺少 `showsStatusBadge` opt-out，且设置主列表没有显式隐藏通用 badge。
- 2026-05-24：在 `CapabilityStatusRow` 增加默认显示的 `showsStatusBadge` 参数，并在 iPhone、iPad、macOS 工作台和 macOS Settings scene 设置列表中传入 `false`。
- 2026-05-24：更新页面清单和 MVP UI flow 规范，记录设置主列表隐藏开发阶段角标，未来真实状态走独立 projection。
- 2026-05-24：修复新增测试的 SwiftLint 行长 warning，确认本任务未引入新的 lint warning。

## 验证记录

- `swift test --package-path Packages/LangoTraceUI --filter SettingsMainStatusBadgeTests`：先红灯失败，随后通过，2 tests。
- `swift test --package-path Packages/LangoTraceUI`：通过，216 tests。
- `find docs -maxdepth 3 -type f | sort`：通过，当前 175 个文档文件。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：通过，无输出。
- `git diff --check`：通过，无输出。
- `swiftlint --no-cache --quiet Packages/LangoTraceUI/Tests/LangoTraceUITests/SettingsMainStatusBadgeTests.swift`：通过，无输出。
- `swiftformat --lint Packages/LangoTraceUI/Tests/LangoTraceUITests/SettingsMainStatusBadgeTests.swift --cache ignore`：通过，0/1 files require formatting。
- `scripts/verify.sh`：通过；SwiftLint 仍有既有 warnings，0 serious；SwiftFormat 0/209 files require formatting。

## 完成标准

- iPhone、iPad、macOS 工作台和 macOS Settings scene 的设置主列表不再显示 `可用`、`本地优先`、`待配置` 这类通用状态 badge。
- 其他页面仍可默认使用 `CapabilityStatusRow` 显示状态 badge。
- 回归测试覆盖设置主列表隐藏 badge 和共享 row 默认显示 badge。
- 相关规范、页面清单和方案文档已更新。
- 聚焦测试、UI package 测试、文档检查和完整验证通过。
- 方案已移入 `docs/plans/done/`。

## 剩余风险

- 本次不实现未来真实设置状态投影，因此 AI Provider 是否显示 Provider 名称、同步是否显示真实启用状态仍需后续单独方案。
