# AI Provider 共享凭证保存可用性修复

状态：Verified
类型：bug
创建日期：2026-05-24
最后更新：2026-05-24
修复基线：`403bff45e057b8f42d21b837e23cd9c6e3697bde`

## 1. 用户确认记录

- 2026-05-24：用户在 iPad Pro 13-inch (M5) 模拟器反馈，OpenRouter 语音模型测试显示“未启用”；填写语音模型后“保存配置”不可用，点击“测试请求”后语音生成先显示测试中，完成后又显示“未配置”。
- 2026-05-24：用户在 macOS 端复测后反馈，同样出现配置无法保存的问题，要求全面检查并让 Mac / iPad 逻辑对齐。
- 2026-05-24：用户确认修复后要求补充方案文档，便于后续回溯。

## 2. Bug 描述

AI Provider 设置页在已有文本模型配置的情况下，新启用语音模型或修改语音模型配置时，保存按钮可能保持不可用，导致用户无法保存 TTS 配置。该问题在 iPad 和 macOS 都可出现，因为两端共享 `AIProviderSettingsView`、`AIProviderDraftConfiguration` 和 AI Provider 保存服务。

## 3. 复现方式

### 路径 A：iPad / OpenRouter TTS

1. 打开 iPad 端设置页，进入 AI Provider 配置。
2. 文本模型使用 OpenRouter，已有可用 API Key。
3. 启用语音生成模型。
4. 填写或使用 OpenRouter TTS 模型、voice、输出格式等字段。
5. 保存或测试语音模型。

### 路径 B：macOS / 已有文本模型后新增 TTS

1. 打开 macOS 设置页，进入 AI Provider 配置。
2. 当前数据库中已有文本模型 endpoint 和文本模型 credential，但尚未保存 TTS endpoint。
3. 启用语音生成模型，并选择“使用文本模型 API Key”。
4. 填写语音模型和 voice。

## 4. 预期行为

- 启用语音模型后，若选择“使用文本模型 API Key”，应复用已保存的文本模型 credential。
- 文本模型 API Key 明文未回填时，只要已有文本 endpoint 的 `credentialID`，仍应允许保存非敏感配置变更。
- 保存成功后，应从返回的 profile 中重新合并 endpoint id、credential id、TTS voice profile，并在 Keychain 可解析时回填 API Key 字段。
- 测试结果面板中，已保存 profile 的 TTS 测试成功结果不应被本地草稿完整性判断降级为“未配置”。

## 5. 实际行为

- iPad 端：语音生成测试开始后可显示“测试中”，完成后又显示“未配置”；保存后再修改配置，保存按钮不可用。
- macOS 端：已有文本模型配置后启用语音模型，若文本 API Key 明文未在表单中出现，保存按钮仍不可用。
- 数据库检查显示 macOS 端只保存了文本 endpoint 和 present 状态的文本 credential，没有 TTS endpoint。此时新启用 TTS 时，旧逻辑没有把文本 endpoint 的 `credentialID` 视为共享凭证可用。

## 6. 根因分析

根因分三层：

1. 保存成功后草稿状态合并不完整。
   `AIProviderDraftConfiguration.applySavedProfile(_:)` 旧实现只写回 endpoint identity，并清空明文 API Key，没有完整调用 loaded profile 路径恢复 credential id、provider、model、credential reference 和 TTS voice profile。首次保存后，草稿可能变成“已保存但缺少可用 credential id”的状态。

2. 已保存凭证复用判断只看当前 optional endpoint。
   `AIOptionalModelDraftConfiguration.isComplete(...)` 在 `.textModelCredential` 分支只接受文本 API Key 明文，或误看 optional endpoint 自己的 `credentialID`。对于“已有文本模型 credential，新启用 TTS endpoint”的路径，TTS endpoint 尚未保存，自然没有自己的 `credentialID`，导致保存 readiness 被判为缺字段。

3. 本地 TTS probe 展示覆盖范围过宽。
   本地“未配置”覆盖原本用于草稿测试，但旧逻辑会影响保存 profile 的 probe 展示，导致服务端 / repository 已成功记录的 TTS 测试结果在 UI 中被降级为“未配置”。

置信度：95%。

## 7. 置信度依据

- macOS 数据库检查显示只有文本 endpoint 和文本 credential，符合“已有文本模型后新增 TTS”的触发条件。
- 新增回归测试 `Loaded text credential can be shared by newly enabled speech without plaintext` 在修复前稳定失败，错误为 `.missingRequiredEndpointField`；修复后通过。
- 新增回归测试覆盖保存成功后写回 credential id、保存后 API Key 可回填、已保存 TTS probe 结果不被本地草稿完整性覆盖。
- 用户在 Mac / iPad 复测后确认问题已修复。

## 8. 备选原因

- Keychain 读取失败：可能导致 API Key 不回填，但不应阻止已有 `credentialID` 的非敏感配置保存。本次修复保留 Keychain 可解析时回填；不可解析时仍可用 existing credential id 保存。
- Repository 无法保存 TTS settings 或 voice profile：已通过 Data 层回归测试证明同 endpoint 的 TTS settings / voice profile 可重存。
- OpenRouter TTS 模型不可用：会影响真实测试结果，但不是保存按钮不可用的根因。

## 9. 目标

- 让 iPad 和 macOS 在同一套共享设置状态机下保存 TTS 配置。
- 支持已有文本模型 credential 被新启用的 TTS endpoint 共享。
- 保存成功后 UI 草稿与 repository 返回状态保持一致。
- 保持敏感凭证边界：API Key 仍在 Keychain；SQLite 只保存 credential metadata 和非敏感配置。

## 10. 范围

本任务包含：

- 修复 AI Provider 设置草稿的保存 readiness 判断。
- 修复保存成功后草稿合并 profile / credential / TTS voice profile 的状态。
- 修复已保存 profile 的 TTS probe 展示降级问题。
- 为 OpenRouter TTS 提供可保存、可测试的默认模型和 voice。
- 补充 UI / AI / Data 层回归测试。
- 重新构建并重启 iPad 和 macOS 本地验证 App。

本任务不包含：

- 新增更多 TTS Provider adapter。
- 实现模型发现或 OpenRouter Models API 自动选择。
- 修改 Keychain 存储策略或同步策略。
- 改动设置页整体视觉设计。

## 11. 涉及代码文件

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`

## 12. 测试文件

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/TTSProviderSettingsTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationServiceTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/AIProviderConfigurationRepositoryTests.swift`

## 13. 参考文档

- `docs/plans/done/2026-05-23-feature-tts-provider-configuration-test.md`
- `docs/plans/done/2026-05-24-feature-sentence-tts-generation-playback-coordinator.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`

## 14. 实施方案

1. 让 `AIProviderEndpointDraftConfiguration` 提供 `hasUsableCredential`，统一表示“当前有明文 API Key 或已有 credential id”。
2. 让文本模型、独立可选模型和 probe readiness 都使用 `hasUsableCredential`，避免保存后明文清空导致状态误判。
3. 修改 `AIOptionalModelDraftConfiguration.isComplete(...)`：当 credential reference 为 `.textModelCredential` 时，使用文本模型 credential 明文或文本 endpoint 的 `credentialID`，而不是 optional endpoint 自己的 `credentialID`。
4. 保存成功后在 `AIProviderSettingsView.saveConfiguration()` 中重新解析返回 profile 的 credential secret，并调用 `applySavedProfile(..., resolvedSecretsByCredentialID:)`。
5. `applySavedProfile(...)` 复用 `applyLoadedProfile(...)` 的完整状态合并逻辑，再将保存状态置为 `.saved`。
6. `AIProviderConfigurationService` 在 `.existing(credentialID)` 保存路径中保留已有 credential metadata，避免重存 profile 时丢失 credential 记录。
7. 对 draft TTS probe 增加本地“未配置”覆盖，但只作用于 `result.source == .draft`。
8. OpenRouter TTS 默认模型设置为 `openai/gpt-4o-mini-tts-2025-12-15`，默认 voice 设置为 `nova`。

## 15. 回归测试方案

- 保存成功后应写回服务返回的 credential id，后续非敏感编辑仍可保存为 `.existing("credential-1")`。
- 保存成功后若 Keychain 可解析 API Key，应回填文本模型 API Key 字段且不标记未保存。
- 已加载文本模型 credential、新启用 TTS 并选择“使用文本模型 API Key”时，即使文本 API Key 明文为空，也应允许保存。
- 已保存 profile 的 TTS probe 成功结果不应被本地 draft 完整性覆盖为“未配置”。
- Configuration service 使用 `.existing(credentialID)` 重存时应保留已有 credential metadata。
- Data repository 可重存同 endpoint 的 TTS settings 和 voice profile。

## 16. 验证命令与结果

聚焦红灯：

```bash
swift test --package-path Packages/LangoTraceUI --filter loadedTextCredentialCanBeSharedByNewlyEnabledSpeechWithoutPlaintext
```

结果：修复前失败，错误为 `.missingRequiredEndpointField`。

聚焦绿灯：

```bash
swift test --package-path Packages/LangoTraceUI --filter loadedTextCredentialCanBeSharedByNewlyEnabledSpeechWithoutPlaintext
```

结果：通过。

UI package 全量验证：

```bash
swift test --package-path Packages/LangoTraceUI
```

结果：通过，226 tests。

格式检查：

```bash
git diff --check
```

结果：通过。

macOS 构建：

```bash
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData build
```

结果：`BUILD SUCCEEDED`。

iPad 构建：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -derivedDataPath .build/DerivedData build
```

结果：`BUILD SUCCEEDED`。

手动验证：

- iPad 已安装并启动新包，进程 `84370`。
- macOS 已重新打开新构建，进程 `84428`。
- 用户复测确认 Mac / iPad 配置无法保存的问题已修复。

## 17. 文档影响检查

本任务修复的是 AI Provider 设置页状态机和已有 credential 复用行为，未改变产品北极星、隐私边界、Provider 凭证存储边界或 TTS 架构方向。既有 `005` 和 `011` 规范仍成立。

需要沉淀的实现事实已记录在本 done 方案中：

- 已保存文本模型 credential 可被新启用的 TTS endpoint 共享。
- 保存 readiness 不应依赖明文 API Key 回填；已有 `credentialID` 也是可用凭证。
- 本地 draft 完整性覆盖不得降级 saved profile probe 结果。

不新增 ADR，不更新 spec。

## 18. 实施记录

- 2026-05-24：完成 iPad 端 TTS 未启用 / 未配置展示问题排查，修复 draft TTS probe capability 展示和 OpenRouter TTS 默认模型 / voice。
- 2026-05-24：完成保存成功后 profile / credential / TTS voice profile 状态合并修复。
- 2026-05-24：完成 `.existing(credentialID)` 重存时 credential metadata 保留修复。
- 2026-05-24：完成 macOS 已保存文本 credential 新增 TTS 保存 readiness 修复，并新增回归测试。
- 2026-05-24：完成 iPad 和 macOS 构建、安装 / 启动验证。

## 19. 完成标准

- iPad 端启用并配置 TTS 后可以保存。
- macOS 端在已有文本模型 credential 的情况下，新启用 TTS 并选择“使用文本模型 API Key”可以保存。
- 保存后再次修改非敏感配置仍可保存。
- TTS 测试结果不会在 saved profile 路径中被错误降级为“未配置”。
- 回归测试和平台构建通过。

## 20. 剩余风险

- 若用户手动选择“使用独立 API Key”，独立 API Key 输入框为空时保存仍会被禁用，这是预期行为，不是本次 bug。
- OpenRouter TTS 仍依赖当前模型和路由实际可用性；保存可用不等于真实 Provider 一定返回有效音频。
- Keychain 不可访问时 API Key 字段不会回填，但已有 credential id 仍允许非敏感配置保存；后续真实请求是否可用取决于 Keychain 读取结果。
