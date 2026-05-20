# 文档审查：诊断日志与 AI Provider 保存反馈

审查类型：专项审查
日期：2026-05-20
代码快照：e3c976f77e721cd5a3e10c62e5d4986f6b1cf580
状态：Verified
当前事实源：`docs/plans/active/2026-05-20-feature-diagnostics-and-ai-provider-save-feedback.md`
后续覆盖记录：none
可作为依据：Yes

## 1. 触发原因

本轮实现新增本地 `diagnostic_events` schema、诊断 logger、AI Provider 保存阶段日志、App Shell 环境装配、Provider 保存 UI 状态和统一验证脚本变更，命中文档审查机制中的数据库 schema、AI Provider、隐私、诊断日志、验证脚本、包边界和 App 启动结构专项审查触发条件。

## 2. 审查范围

- `docs/plans/active/2026-05-20-feature-diagnostics-and-ai-provider-save-feedback.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/review/INDEX.md`

## 3. 相关源码、脚本和配置

- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticLogger.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfigurationSaveFailure.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBDiagnosticEventRepository.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `scripts/verify.sh`

## 4. 结论摘要

本轮实现已经把 AI Provider 保存反馈从“保存后状态不清晰”推进到可见的 saving / saved / failed / input invalid 状态，并建立了默认关闭、开发期可开启、非敏感、best-effort 的诊断日志基础设施。

长期文档需要同步为“诊断事件模型和本地 ring buffer 已落地，但产品期用户可见诊断开关、诊断包导出和发送仍未实现”。不能把 `diagnostic_events` 描述成普通用户数据、同步对象、请求日志或远程遥测。

## 5. 问题清单

| 编号 | 严重度 | 问题 | 处理 |
| --- | --- | --- | --- |
| DP-001 | P0 | `scripts/verify.sh` 没有覆盖 `Packages/LangoTraceAI`，而保存诊断实现核心改动在 AI package。 | 已加入 AI package test，并更新 `009`。 |
| DP-002 | P0 | 长期隐私规范没有描述 typed diagnostic events、ring buffer、默认关闭和导出 / 同步排除，后续可能误用为遥测或请求日志。 | 已更新 `008`。 |
| DP-003 | P1 | AI Provider 规范未固定保存阶段、operation id、cleanup failure 和非敏感日志字段边界。 | 已更新 `005`。 |
| DP-004 | P1 | SwiftUI 与 UI 规范没有沉淀保存类异步操作的 input invalid、saving、saved、failed 和 best-effort logging 边界。 | 已更新 `003` 和 `004`。 |
| DP-005 | P1 | 模块边界快照缺少 Diagnostic model、repository、App Shell logger 装配和 AI service 保存失败分类事实。 | 已更新 `001`。 |

## 6. 文档修改记录

- 更新 `003`：新增关键操作反馈规则，明确保存中、成功、失败、输入无效、禁用重复点击和可访问性。
- 更新 `004`：新增保存类异步操作边界，明确 View 不直接访问底层服务、input invalid 不算真实保存失败、operation id 和 best-effort logging。
- 更新 `005`：新增 AI Provider 保存阶段诊断、operation id、失败 phase、cleanup failure 和 App Shell 环境开关边界。
- 更新 `008`：新增 typed diagnostic events、`diagnostic_events` ring buffer、默认关闭、非敏感字段白名单、导出 / 同步排除和失败降级规则。
- 更新 `009` 和 `scripts/verify.sh`：统一验证覆盖 AI package。
- 更新 `001`：同步 App Shell、Core、Data、AI、UI 当前实现快照。
- 更新 review index：新增本轮索引和重审触发日志。

## 7. 用户澄清

无待澄清问题。产品期“隐私与诊断”设置页、诊断包导出 / 发送、真实 Provider 合成探测、真实 AI 请求日志和诊断数据清除 UI 均明确延期，不属于本轮完成范围。

## 8. 延后项和原因

- 用户可见诊断设置页：需要单独的信息架构、隐私说明、清除和导出流程。
- 诊断包导出 / 发送：必须先完成摘要预览、敏感字段扫描、用户确认和 Share Sheet / 发送路径设计。
- 真实 Provider 合成探测：需要请求预览、Provider client、日志和错误分类完整边界。
- 真实 AI、OCR、Speech、Sync 诊断事件：需要分别设计 phase、字段白名单和用户触发边界。

## 9. 验证记录

已在各阶段运行并通过：

- `swift test --package-path Packages/LangoTraceCore`：阶段 1、4 后通过。
- `swift test --package-path Packages/LangoTraceData`：阶段 2 后通过。
- `swift test --package-path Packages/LangoTraceAI`：阶段 3、4 后通过。
- `swift test --package-path Packages/LangoTraceUI`：阶段 4 与 input invalid 补丁后通过，最新 137 tests。
- `xcodegen generate`：阶段 4 后通过。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`：阶段 4 修复 AppEnvironment 签名后通过。
- `git diff --check`：文档更新后通过。
- 文档占位扫描：文档更新后无命中。

完整收尾仍需在任务方案移入 done 前运行 `scripts/verify.sh`、敏感字段扫描和最终 `git status --short`。

## 10. 剩余风险

- `diagnostic_events` 已落地但产品期默认不写入，未开启诊断前的问题不能事后追溯；这是隐私优先的有意取舍。
- 当前 UI 通过持久 saved / failed 状态面板保证快速保存可感知性，没有人为延迟保存完成；若后续真实设备测试发现 spinner 不可见，应只调整视觉 affordance，不改变业务事务完成时机。
- 诊断字段白名单需要随着真实 AI、OCR、Speech、同步和导出接入持续复查。
