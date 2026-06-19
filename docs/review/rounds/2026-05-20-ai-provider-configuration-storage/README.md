# 文档审查：AI Provider 配置存储

审查类型：专项审查
日期：2026-05-20
代码快照：5283f747866242d80f874f529e8f1778b193a543
状态：Verified
当前事实源：`docs/plans/done/2026-05-20-feature-ai-provider-configuration-storage.md`
后续覆盖记录：none
可作为依据：Yes

## 1. 触发原因

AI Provider 配置存储实现新增数据库 schema、GRDB repository、Keychain credential store、AI service、App Shell 装配和三端设置页保存 / 验证路径，命中文档审查机制中的数据库 schema、AI Provider、Keychain、隐私边界和 App 启动结构专项审查触发条件。

## 2. 审查范围

- `docs/plans/done/2026-05-20-feature-ai-provider-configuration-storage.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/platform-page-inventory.md`
- `docs/review/INDEX.md`

## 3. 相关源码、脚本和配置

- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderCredentialStore.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/KeychainAIProviderCredentialStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift`
- `scripts/verify.sh`

## 4. 结论摘要

本次实现已经把 AI Provider 设置页从页面级 mock 推进到真实本地配置保存：非敏感配置进入 SQLite / GRDB，API Key 进入 Keychain，设置页加载不解密、不回填明文，测试按钮执行本地配置完整性和 Keychain 可读性检查，不发起网络请求。

长期文档需要同步为“本地配置保存已实现，真实 Provider 合成探测未实现”。不能继续把 AI Provider 设置页描述为纯 Local Mock，也不能把真实外部 Provider 请求、请求预览、请求日志或 Prompt Preset 执行描述为已完成。

## 5. 问题清单

| 编号 | 严重度 | 问题 | 处理 |
| --- | --- | --- | --- |
| AP-001 | P0 | 任务方案仍为 `Draft`，且写着“不写代码”，会误导后续会话认为实现不能开始或尚未落地。 | 已更新为 `Verified`，补充阶段 commit、验证记录和后续延期项。 |
| AP-002 | P0 | 页面清单仍把 AI Provider 设置页标为 Local Mock，且写着不写 Keychain。 | 已更新为 `Implemented / Local Validation`，记录 SQLite / Keychain 保存和本地验证边界。 |
| AP-003 | P1 | AI 隐私和权限规范未覆盖已落地的 Keychain item 引用、ThisDeviceOnly、数据库恢复缺密钥和 validation event 摘要。 | 已更新 `005` 和 `008`。 |
| AP-004 | P1 | 模块边界文档仍写 AI package 只有 disabled provider，Data 只有语言空间真实存储。 | 已更新 App Shell、Core、Data、AI、UI 当前代码快照。 |

## 6. 文档修改记录

- 更新任务方案状态、需求描述、实现后代码事实、阶段落地状态、文档影响检查、实施记录、完成标准和剩余风险。
- 更新 `005`：Provider 配置页当前阶段、Keychain 引用、加载不解密、本地验证不发网络和 validation event 记录边界。
- 更新 `008`：Keychain 与敏感配置边界、ThisDeviceOnly、默认不同步、数据库恢复缺密钥和 SQLite / Keychain 非原子补偿。
- 更新 `001`：App Shell 装配、Core AI Provider 模型、Data `AppDatabase` / AI Provider repository、AI service / Keychain store、UI action closure 边界。
- 更新页面清单：AI Provider 设置页改为 `Implemented / Local Validation`。
- 更新 review index：新增本轮索引和重审触发日志。

## 7. 用户澄清

无待澄清问题。真实 Provider 合成探测、请求预览、请求日志、Prompt Preset 执行、运行期凭证缓存、凭证轮换 UI 和 cleanup retry 均明确延期，不属于本轮完成范围。

## 8. 延后项和原因

- 真实 Provider 合成探测：需要稳定最小 Provider client、请求预览、日志和错误分类边界。
- 凭证轮换 / 删除 profile / cleanup retry UI：当前 schema 和错误分类已留边界，但还没有用户路径和维护任务。
- iOS / iPadOS Keychain 平台行为：当前已覆盖 macOS 本机 Keychain 单元测试，后续真实请求任务需要补模拟器或真机验证。

## 9. 验证命令与结果

- `swift test --package-path Packages/LangoTraceCore`：通过，34 tests。
- `swift test --package-path Packages/LangoTraceAI`：通过，10 tests。
- `swift test --package-path Packages/LangoTraceData`：通过，24 tests。
- `swift test --package-path Packages/LangoTraceUI`：通过，135 tests。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`：通过。
- `swiftformat LangoTraceApp Packages/LangoTraceAI Packages/LangoTraceCore Packages/LangoTraceUI --lint --cache ignore`：通过，0 files require formatting。
- `git diff --check`：通过。
- `scripts/verify.sh`：首次运行在 SwiftLint 阶段发现 `AppDatabase.migrate` 函数体过长；拆分 migration helper 后需要重跑。
- `scripts/verify.sh`：重跑通过，退出码 0；SwiftLint 仍报告 6 个非阻断 warning，未阻止验证通过。

## 10. 剩余风险

- Keychain `ThisDeviceOnly` 符合默认不同步原则，但设备迁移后需要清晰 UI 引导用户重新输入密钥。
- 真实 Provider 合成探测不能复用本地 validation 的“测试成功”状态直接声称外部服务可用。
- cleanup retry 未落地前，旧 Keychain item 清理失败仍可能留下本机残留；后续任务必须使用非敏感状态记录和重试，不得把完整 Keychain account 暴露给 UI 或日志。
