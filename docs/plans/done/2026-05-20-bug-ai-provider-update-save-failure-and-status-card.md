# 任务方案：AI Provider 更新保存失败与状态卡视觉修正

状态：Done
类型：bug
创建日期：2026-05-20
最后更新日期：2026-05-20

## 1. 问题描述

iOS 模拟器中，已有 AI Provider 配置后再次输入 API Key 并点击“保存配置”，UI 显示“配置保存失败”。同时失败状态卡中图标与标题视觉重心偏上，单行状态不够精致；成功和失败状态也不应常驻。

## 2. 证据

- 当前 App 容器 SQLite 中已有 `ai_provider_profiles = 1`、`ai_provider_credentials = 1`、`ai_provider_endpoints = 1`。
- 用户触发保存失败时，系统日志出现 `SecItemAdd_ios` 后紧跟 `SecItemDelete_ios`。
- 这说明 Keychain 写入已进入成功后补偿删除路径，更符合数据库写入失败，而不是 Keychain 写入失败。
- `AIProviderDraftConfiguration.makeProfileSaveInput()` 当前未带已有 `profileID`，导致已有默认 profile 场景再次保存时生成新的默认 profile。
- `ai_provider_profiles` 有 active default 唯一索引，第二个默认 profile 会违反唯一约束。

## 3. 根因

加载已有默认配置后，UI draft 没有记住原始 `profile.id` 和 endpoint id。再次保存时，service 生成新的 profile id，并尝试插入另一个 `is_default = 1` 的 active profile，触发数据库写入失败；随后服务层补偿删除刚写入的 Keychain secret，UI 显示保存失败。

置信度：94%

## 4. 修复方案

1. `AIProviderDraftConfiguration` 增加 `profileID`，加载和保存后保留已有 profile identity。
2. `AIProviderEndpointDraftConfiguration` 增加 `id`，加载已有 endpoint 后保留 endpoint identity，保存时回传。
3. 保存成功后用返回 profile 更新 draft identity，避免后续重复保存再次退回新建路径。
4. 状态卡改为单行居中：图标和标题垂直居中，不再使用顶部对齐和多余 VStack。
5. 成功 / 失败状态增加自动消失机制；保存成功或失败后延迟清除状态。`配置未保存` 不自动消失。

## 5. 不做什么

- 不改变 Keychain 存储策略。
- 不接入真实 Provider 网络请求。
- 不在日志或 UI 中显示 API Key。
- 不把“正在保存”重新显示出来。

## 6. 验证方法

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceData --filter AIProviderConfigurationRepositoryTests
scripts/verify.sh
```

## 7. 实施记录

- 2026-05-20：完成日志与数据库初步排查，确认失败更符合数据库唯一约束导致的补偿删除路径。
- 2026-05-20：新增 UI draft 回归测试，覆盖加载已有 profile 后再次保存必须保留 `profileID` 与 endpoint id。
- 2026-05-20：修复 `AIProviderDraftConfiguration` 身份保留逻辑；保存成功后使用 service 返回的 profile 更新 draft identity。
- 2026-05-20：重设状态卡为单行垂直居中；成功 / 失败状态增加 2.2 秒自动清除，输入变更会取消旧清除任务。
- 2026-05-20：`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests` 通过。
- 2026-05-20：`swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationServiceTests` 通过。
- 2026-05-20：`swift test --package-path Packages/LangoTraceData --filter AIProviderConfigurationRepositoryTests` 通过。
- 2026-05-20：`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsSaveStatusRepairTests` 通过。
- 2026-05-20：`scripts/verify.sh` 通过；SwiftLint 仍有既有 warning，但无 serious violation。
- 2026-05-20：已重启 `iPhone 17` 模拟器，安装并启动新的 `com.zibuyu.LangoTrace` 构建。
