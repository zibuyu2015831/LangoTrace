# AI Provider 测试结果完成态标题修复

状态：Verified  
类型：bug  
创建日期：2026-05-24  
最后更新日期：2026-05-24  

## 用户确认记录

用户在 2026-05-24 提供 iPhone 17 模拟器截图并要求排查原因、创建方案文档、立即修复、测试无误后提交 commit。本方案按该指令进入实施。

## Bug 描述

AI Provider 配置测试 bottom sheet 在测试中显示 `正在测试` 时视觉正常；测试完成后顶部标题切换为 `测试成功`，该标题位于 sheet 顶部 chrome 区，与 handle、右上关闭按钮和下方结果卡片的层级关系不美观。

## 复现方式

1. 在 iPhone compact 宽度打开 `AI Provider` 设置页。
2. 配置可通过测试的文本 / 图片 / TTS Provider。
3. 点击测试按钮，观察 bottom sheet 测试中状态。
4. 等待测试完成，观察 sheet 顶部标题从 `正在测试` 切换为 `测试成功`。

## 预期行为

- 测试中可以在顶部 chrome 显示 `正在测试` 和小号 `ProgressView`，明确表达当前操作正在进行。
- 测试完成后，sheet 顶部应回到稳定、中性的面板标题，避免把 `测试成功` / `部分可用` / `测试失败` 当作页面标题。
- 具体能力结果继续由 grouped capability rows 的图标、状态文字和试听按钮表达。

## 实际行为

`AIProviderProbeResultPanelContent.titleKey` 在非测试中直接返回 `result?.probePanelTitleKey`，导致完成态顶部标题变成 `测试成功`、`部分可用` 或 `测试失败`。成功态下该状态标题悬在 sheet 顶部，视觉上像临时提示而不是稳定面板标题。

## 根因分析

根因是结果状态和 sheet chrome 标题职责混用。2026-05-23 的结果面板重设计把顶部改成状态 chrome，但实现保留了“完成态用 overall status 文案作为标题”的逻辑；当结果成功时，`probePanelTitleKey` 返回 `aiProviderSettings.testState.succeeded`，最终渲染为 `测试成功`。

置信度：90%

置信度依据：

- 截图中的异常文案正是 `aiProviderSettings.testState.succeeded` 的中文本地化。
- 代码中 `titleKey` 唯一路径在非测试中返回 `result?.probePanelTitleKey`。
- capability rows 已经独立展示每项 `可用` / `未启用` 状态，完成态标题不承担必要信息。

备选原因：

- 纯间距问题：可以通过增加顶部 padding 缓解拥挤，但不能解决 `测试成功` 被当成 sheet 标题的职责错误。
- 图标尺寸问题：缩小成功图标能降低突兀感，但完成态标题仍然不稳定。

## 目标

- 保持测试中状态显示不变。
- 完成后顶部标题固定为中性 `测试请求`。
- 不改变 Provider probe 请求、结果判断、TTS 试听、持久化或三端共享入口。
- 用 UI package 现有 source-boundary 测试固定该边界。

## 不做什么

- 不新增真实 Provider 请求能力。
- 不改 capability row 状态语义。
- 不改 sheet detent、关闭和重试行为。
- 不引入截图测试基础设施。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

## 涉及的文档路径

- `docs/plans/active/2026-05-24-bug-ai-provider-probe-result-completed-header.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/platform-page-inventory.md`

## 实施方案

1. 先更新 `AIProviderSettingsProbeTests`，断言结果面板测试中使用 `testing` 标题，完成后使用稳定 `probeResult.title`，且不再从 `result?.probePanelTitleKey` 派生顶部标题。
2. 运行聚焦测试，确认新增断言红灯。
3. 修改 `AIProviderProbeResultPanelContent.titleKey`，非测试中返回 `aiProviderSettings.probeResult.title`。
4. 若 `probePanelTitleKey` 不再有使用方，删除该派生属性，避免后续误用。
5. 更新相关 UI spec / 页面清单，记录完成态不使用 overall status 作为 sheet 标题。
6. 运行聚焦测试、UI package 测试、文档检查和统一验证。
7. 验证通过后将方案移入 `docs/plans/done/` 并提交 commit。

## 回归测试方案

- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`
- `swift test --package-path Packages/LangoTraceUI`
- `git diff --check`
- 文档 placeholder 扫描
- `scripts/verify.sh`

## 文档影响检查

本修复改变 AI Provider 测试结果面板的长期 UI 规则，需要同步 `docs/spec` 和 `docs/platform-page-inventory.md`。不涉及 ADR、Provider 请求边界、隐私边界、数据 schema、Keychain、同步或 StoreKit。

## 实施记录

- 2026-05-24：新增 UI package source-boundary 回归测试，确认 `AIProviderProbeResultPanelContent` 测试中使用 `aiProviderSettings.testState.testing`，完成后使用稳定 `aiProviderSettings.probeResult.title`，且不再从 `result?.probePanelTitleKey` 派生顶部标题。
- 2026-05-24：红灯验证 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests` 失败，失败点为旧实现仍包含 `return result?.probePanelTitleKey`。
- 2026-05-24：修改 `AIProviderSettingsComponents.swift`，删除 `probePanelTitleKey`，完成态标题固定为 `aiProviderSettings.probeResult.title`；保留测试中 `正在测试`、完成态能力行状态、TTS 试听、关闭和重试行为。
- 2026-05-24：同步 `docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`、`docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 和 `docs/platform-page-inventory.md`，记录完成态不把 overall status 当作 sheet 顶部标题。

## 验证记录

- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`：红灯失败一次，随后通过，15 tests。
- `swift test --package-path Packages/LangoTraceUI`：通过，213 tests。
- `git diff --check`：通过。
- 文档 placeholder 扫描：初次只命中本方案实施记录占位，收口时已移除。
- `scripts/verify.sh`：通过；包含 XcodeGen、Core / Data / UI package 测试、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint 和 SwiftFormat lint。SwiftLint 仍有既有 warning，0 serious。

## 完成标准

- 测试中标题仍为 `正在测试`。
- 完成态顶部标题不再使用 `测试成功`。
- 分能力结果行继续展示每项可用性。
- 聚焦测试、UI package 测试、文档检查和统一验证通过。
- 生成一个包含本次相关文件的 commit。

## 剩余风险

- 当前自动测试为 source-boundary 测试，不能替代真实模拟器截图验收；本次风险通过代码路径和用户截图对应关系控制。
