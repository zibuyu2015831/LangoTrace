# AI Provider 测试结果成功态重试按钮层级优化

状态：Verified  
类型：bug  
创建日期：2026-05-24  
最后更新日期：2026-05-24  

## 用户确认记录

用户在 2026-05-24 复测后指出：完成态底部新增 `重新测试` 大按钮，但 sheet 高度没有变化，导致顶部标题和 sheet 边框间距不足。随后要求站在专业设计师和 Apple 应用交互角度评估，并确认采用“成功态降低重试操作权重，失败 / 部分可用态保留恢复操作”的方向后，要求立即更新文档并优化。

## Bug 描述

AI Provider 测试成功后，结果 sheet 底部显示一个大号 filled `重新测试` 按钮。该按钮在成功态不是主路径，却占据底部 thumb zone 和额外高度，使 compact iPhone `.medium` sheet 内部内容变得拥挤，顶部标题贴近边框。

## 复现方式

1. 在 iPhone compact 宽度打开 AI Provider 设置页。
2. 使用可成功的 Provider 配置触发测试。
3. 等待能力列表全部完成。
4. 观察底部出现大号 `重新测试` 按钮，sheet 顶部标题与边框间距不足。

## 预期行为

- 成功态不把 `重新测试` 作为底部主 CTA；用户主路径应是查看结果后关闭或继续使用配置。
- 失败、部分可用、取消或不支持状态可以保留明显的恢复操作，因为此时“重试”是合理的下一步。
- 测试中仍不显示不可点击的重试按钮。
- 不改变 Provider 请求、结果判定、TTS 试听和持久化逻辑。

## 实际行为

`AIProviderProbeResultPanelContent` 对所有非测试中状态都显示同一个 `.borderedProminent` `retryButton`。成功态因此额外增加高度和主操作权重，破坏状态反馈 sheet 的信息层级。

## 根因分析

根因是完成态操作权重没有按结果状态区分。上次修复将顶部标题改成中性 `测试请求`，但保留了 `if !isTesting { retryButton }`，导致成功态和失败态共享同一个底部 prominent 恢复操作。

置信度：92%

置信度依据：

- 复测截图显示顶部文案已是 `测试请求`，说明上一轮标题修复生效。
- 截图中的新增拥挤高度来自底部 `重新测试` 按钮。
- 代码中非测试态无条件显示 `retryButton`。
- 从 Apple 交互层级看，成功态的主路径不是重试，prominent button 语义过重。

备选原因：

- 纯 detent 高度问题：统一切 `.large` 可缓解拥挤，但会为成功态引入不必要的自动展开。
- 纯 padding 问题：增加顶部 padding 不能解决底部主按钮权重过高和内容高度过量。

## 目标

- 成功态隐藏底部 prominent `重新测试` 按钮。
- 失败、部分可用、取消、不支持或未知完成态保留 `重新测试` 恢复操作。
- 更新 UI 规范，明确成功反馈 sheet 不应默认给重试主按钮。
- 用 UI package source-boundary 测试固定边界。

## 不做什么

- 不新增 detent 自动切换，除非后续失败态人工测试仍证明需要。
- 不改变 capability rows、TTS 试听按钮、请求服务或诊断日志。
- 不改本地化文案。
- 不提交上次未推送提交之外的无关文件。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`

## 涉及的文档路径

- `docs/plans/active/2026-05-24-bug-ai-provider-probe-result-success-retry-prominence.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/platform-page-inventory.md`

## 实施方案

1. 更新 `AIProviderSettingsProbeTests`，断言结果面板不再使用 `if !isTesting` 无条件显示重试按钮，并新增 `showsRetryButton` 之类状态判断。
2. 红灯运行聚焦测试，确认当前旧实现失败。
3. 在 `AIProviderProbeResultPanelContent` 中新增 `showsRetryButton`，仅在非测试且 `result?.overallStatus != .succeeded` 时显示重试按钮。
4. 更新 UI 规范和页面清单，记录成功态不显示 prominent 重试按钮；失败 / 部分态保留恢复路径。
5. 运行聚焦测试、UI package 测试、文档检查和统一验证。
6. 验证通过后将方案移入 `docs/plans/done/` 并提交 commit。

## 回归测试方案

- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`
- `swift test --package-path Packages/LangoTraceUI`
- `git diff --check`
- 文档 placeholder 扫描
- `scripts/verify.sh`

## 文档影响检查

本任务调整状态反馈 sheet 的长期 UI 规则，需要同步 `docs/spec` 和 `docs/platform-page-inventory.md`。不涉及 ADR、Provider 请求边界、隐私边界、数据 schema、Keychain、同步或 StoreKit。

## 实施记录

- 2026-05-24：新增 UI package source-boundary 回归测试，确认结果面板使用 `showsRetryButton` 判断恢复操作，不再通过 `if !isTesting` 对所有完成态显示重试按钮。
- 2026-05-24：红灯验证 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests` 失败，失败点为旧实现仍包含 `if !isTesting`，且缺少 `showsRetryButton` 和 `result?.overallStatus != .succeeded`。
- 2026-05-24：修改 `AIProviderProbeResultPanelContent`，新增 `showsRetryButton`，仅在非测试且结果不是 `.succeeded` 时显示底部 prominent `重新测试`；成功态只保留结果列表、TTS 试听和关闭路径。
- 2026-05-24：同步 `docs/spec/003-ui-design-system.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`、`docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 和 `docs/platform-page-inventory.md`，沉淀成功态不突出重试、非成功态保留恢复操作的规则。

## 验证记录

- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`：红灯失败一次，随后通过，15 tests。
- `swift test --package-path Packages/LangoTraceUI`：通过，213 tests。
- `git diff --check`：通过。
- `scripts/verify.sh`：首次失败于文档 placeholder 扫描，原因是本方案实施记录未收口；此前步骤中的 Core / Data / UI package 测试、iPhone / iPad / macOS build、SwiftLint 和 SwiftFormat lint 已完成，SwiftLint 仍有既有 warning，0 serious。
- `scripts/verify.sh`：收口方案并移入 done 后重新运行通过；SwiftLint 仍有既有 warning，0 serious；SwiftFormat lint 显示 0/208 files require formatting。

## 完成标准

- 成功态不再显示底部 prominent `重新测试` 按钮。
- 非成功完成态仍保留恢复操作。
- 聚焦测试、UI package 测试、文档检查和统一验证通过。
- 生成一个包含本次相关文件的 commit。

## 剩余风险

- 当前自动测试仍以 source-boundary 为主，不替代模拟器截图验收；本次修复依赖用户截图与代码路径对应关系。
