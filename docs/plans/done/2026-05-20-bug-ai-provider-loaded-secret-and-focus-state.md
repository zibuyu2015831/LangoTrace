# 任务方案：AI Provider 已保存密钥回显与焦点误触发修正

状态：Done
类型：bug
创建日期：2026-05-20
最后更新日期：2026-05-20

## 1. 问题描述

用户完成 AI Provider 配置后，再次打开配置页时，API Key 输入框仍为空；同时用户只是把光标移动到输入框、未输入任何内容时，底部已经显示“配置未保存”。

## 2. 影响

- 已完成配置的用户无法确认当前本机 Keychain 中保存的 API Key，体验上像配置丢失。
- 焦点行为被误判为输入变更，会降低“配置未保存”状态的可信度。
- 如果用户只是进入页面检查配置，不应看到未保存提示。

## 3. 根因判断

1. `AIProviderConfigurationService.loadDefaultProfile()` 只返回数据库中的 profile、endpoint 和 credential metadata，不返回 Keychain secret。
2. `AIProviderDraftConfiguration.applyLoadedProfile(_:)` 会清空 plaintext secret，因此 UI 无法回显已保存 API Key。
3. `AIProviderSettingsView` 的 Binding setter 当前先调用 `markDraftInputChanged()` 再赋值；SwiftUI 控件在获得焦点或刷新时可能写回相同值，因此同值写入也会触发 `unsavedChanges`。

置信度：90%

## 4. 推荐修复方案

1. 在 UI action 边界增加“按 credential metadata 解析 secret”的闭包，由 AppEnvironment 使用既有 Keychain store 实现。
2. 加载 profile 后，仅在 UI draft 内按 credential id 回填 plaintext API Key；不改变数据库模型，不把密钥写入诊断日志。
3. draft endpoint 记录 `credentialID`，用于把 resolved secret 准确映射回文本、语音或向量 endpoint 的独立凭证输入框。
4. 所有表单 Binding setter 先比较新旧值；只有值真正变化时才标记 `unsavedChanges`。
5. 保持加载已有配置后状态为 `idle`，保存成功/失败仍沿用上一轮短暂停留规则。

## 5. 不做什么

- 不把 API Key 明文保存到 SQLite。
- 不在日志、诊断事件或测试输出中打印真实 API Key。
- 不改变 Keychain 默认不同步策略。
- 不新增真实 Provider 网络请求。

## 6. 验证方法

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationServiceTests
scripts/verify.sh
```

## 7. 实施记录

- 2026-05-20：新增回归测试并先确认失败，失败点为 `applyLoadedProfile` 不支持 resolved secret，且 `markInputChanged` 不支持同值写入过滤。
- 2026-05-20：在 `AIProviderSettingsActions` 增加 `resolveCredentialSecret`，由 AppEnvironment 使用既有 Keychain store 解析 credential secret；解析结果只进入 UI draft，不进入数据库或诊断日志。
- 2026-05-20：`AIProviderEndpointDraftConfiguration` 增加 `credentialID`，加载 profile 后按 credential id 将 resolved API Key 回填到对应独立凭证输入框。
- 2026-05-20：所有 AI Provider 表单 Binding setter 改为先比较新旧值；同值写回不触发 `unsavedChanges`，也不会清除短暂停留的成功 / 失败提示。
- 2026-05-20：完成文档影响检查并更新长期规范：`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`、`docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 和 `docs/platform-page-inventory.md` 同步已保存 API Key 短生命周期回显边界。
- 2026-05-20：验证通过：`swift test --package-path Packages/LangoTraceUI --filter AIProviderLoadedSecretRepairTests`。
- 2026-05-20：验证通过：`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`。
- 2026-05-20：验证通过：`swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationServiceTests`。
- 2026-05-20：验证通过：`scripts/verify.sh`；SwiftLint 仍有既有 warning，但无 serious violation，SwiftFormat 通过。
