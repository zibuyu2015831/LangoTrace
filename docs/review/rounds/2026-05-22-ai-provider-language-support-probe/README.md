# 文档审查：AI Provider 语言支持合成测试

审查类型：专项审查
日期：2026-05-22
代码快照：b007c8a424091bf17b727ae26a4f1baff9fdd55d
状态：Verified
当前事实源：`docs/README.md`、`docs/architecture/001-initial-module-boundaries.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/platform-page-inventory.md`、`docs/prompts/ai-provider/provider-configuration-probe.md`
后续覆盖记录：none
可作为依据：Yes

## 1. 触发原因

最近一次文档审查索引停在 `2026-05-20-diagnostics-provider-save-feedback`。此后 `fb9f720` 到 `b007c8a` 落地了 AI Provider 语言支持合成测试、iOS 人工审核后的 iPad / macOS 设置入口接入、语言支持 smoke test 放宽、取消态修复，以及 Prompt Registry / AI Provider 隐私规范 / 页面清单同步。

该变更命中专项审查触发条件：AI Provider、Provider 请求、隐私边界、诊断日志、三端设置入口和验证脚本相关事实均发生变化。

## 2. 审查范围

- `docs/README.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/platform-page-inventory.md`
- `docs/prompts/README.md`
- `docs/prompts/ai-provider/provider-configuration-probe.md`
- `docs/plans/active/2026-05-22-feature-ai-provider-language-support-probe.md`

## 3. 相关源码、脚本和配置

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderLanguageSupportValidator.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `scripts/verify.sh`

## 4. 结论摘要

AI Provider 语言支持合成测试的长期规范主体已经基本落地：`spec/005`、`spec/006`、Prompt Registry 和页面清单均记录了 `语言支持` probe 的目标语言 code allowlist、Prompt 契约、JSON / 长度 / NaturalLanguage / 脚本规则校验、非认证性质、`sample` 原文不落日志和 Provider profile 全局验证摘要隔离。

本轮审查发现并修复 4 类文档事实漂移：

- `docs/README.md` 的已完成能力缺少 `语言支持` probe。
- `docs/architecture/001-initial-module-boundaries.md` 仍把 AI 层描述为“不发送真实外部 Provider 请求”，未区分用户主动触发的固定配置 probe 与真实学习内容请求。
- `docs/architecture/001-initial-module-boundaries.md` 的 UI 测试边界仍写着“无网络测试请求”，未表达当前真实边界是 SwiftUI 不直接触网、通过 action seam 进入 AI package。
- Prompt Registry 与语言边界规范的变更记录仍有 iOS-only 表述；当前 iPad / macOS 已经通过共享设置详情入口接入。

## 5. 问题清单

| 编号 | 严重度 | 类型 | 证据 | 处理 |
| --- | --- | --- | --- | --- |
| R1 | P1 | 当前事实源过期 | `docs/README.md` 已完成列表只写文本回复、JSON 输出和图片理解；代码 `AIProviderProbeCapability.languageSupport` 和 `AIProviderConfigurationProbeService.languageSupportProbeResult(...)` 已存在 | 已补充 `语言支持` probe |
| R2 | P0 | 架构事实过期 | `docs/architecture/001-initial-module-boundaries.md` 写“仍不发送真实外部 Provider 请求”；Prompt Registry 已明确配置探测会发送到用户配置的外部或本地 Provider | 已改为区分固定合成配置 probe 和真实学习内容 AI 请求 |
| R3 | P1 | 执行边界表述过期 | UI 测试边界写“无网络测试请求”，但当前正确边界是 SwiftUI View 不直接触网，测试按钮经 action seam 进入 AI package | 已改为 action seam 与 SwiftUI source-boundary 表述 |
| R4 | P2 | 变更记录容易误读 | `docs/prompts/README.md`、`docs/spec/006...` 和页面清单仍带 iOS-only 口径 | 已移除或补充三端入口事实 |

## 6. 文档修改记录

- 更新 `docs/README.md`：已完成能力中补充当前语言空间上下文下的语言支持 probe。
- 更新 `docs/architecture/001-initial-module-boundaries.md`：修正 AI / UI / App Shell / Data-AI 快照，区分配置合成测试和真实学习内容 AI 请求。
- 更新 `docs/platform-page-inventory.md`：追加 iPad / macOS 语言支持入口变更记录。
- 更新 `docs/prompts/README.md`：移除语言支持 Prompt 记录中的 iOS-only 表述。
- 更新 `docs/spec/006-interface-localization-and-language-boundaries.md`：追加三端共享入口事实。
- 更新 `docs/review/INDEX.md`：登记本轮专项审查。

## 7. 用户澄清

无待澄清问题。

## 8. 延后项和原因

- `docs/plans/active/2026-05-22-feature-ai-provider-language-support-probe.md` 仍处于 `Implementation Complete, Awaiting Final Verification`，未在本轮移动到 `docs/plans/done/`。原因：该 feature plan 的收口要求包含最终完整验证和计划生命周期收口；本轮任务是文档审查，不替代功能方案收口。

## 9. 验证命令与结果

- `find docs -maxdepth 3 -type f | sort`：通过。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：通过，无匹配。
- `git diff --check`：通过。
- `git status --short`：通过，显示本轮文档变更。

本轮未运行 `scripts/verify.sh`。原因：本轮只修改文档事实源和审查索引，未修改 Swift 源码、XcodeGen、测试脚本或资源文件。剩余风险是未重新执行完整 Swift 工程构建；语言支持功能自身仍由 active feature plan 的最终验证负责收口。

## 10. 剩余风险

- Apple `NLLanguageRecognizer` 对部分目标语言仍可能误判；该风险已在 feature plan 中保留，不属于文档一致性阻断。
- 当前诊断日志只记录 capability scoped 状态和错误分类，不记录 `sample` 原文。后续若新增 target language code diagnostic attribute，需要同时更新 `DiagnosticAttribute` allowlist、GRDB 序列化和 `spec/008`。
- 真实学习内容 AI 请求、请求预览、请求日志和 Prompt Preset 执行仍未接入；后续接入时必须另开任务方案并再次触发 AI / 隐私专项审查。
