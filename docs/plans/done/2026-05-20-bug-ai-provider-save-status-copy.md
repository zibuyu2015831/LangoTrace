# 任务方案：AI Provider 保存状态文案与状态面板修正

状态：Done
类型：bug
创建日期：2026-05-20
最后更新日期：2026-05-20

## 1. 问题描述

iOS AI Provider 设置页在用户没有输入 API Key、或只是加载已有本机配置时，底部状态面板可能显示绿色打勾和“配置已保存到本机安全存储”。这会让用户误以为刚刚执行了保存动作，尤其在 API Key 输入框为空时更容易产生误解。

上一轮已去除按钮内的快速 saving 动画，但底部状态面板仍包含说明 tip 和保存中状态语义，不够克制。

## 2. 用户确认的交互规则

- 尚未输入或配置不完整时，不显示底部状态文本。
- 已有本机配置但当前没有新输入时，不显示底部状态文本。
- 已有本机配置且当前输入发生修改时，显示标题“配置未保存”。
- 用户主动点击保存并保存成功后，显示绿色打勾样式和标题“配置已更新”。
- 保存失败时显示失败标题。
- 去除“正在保存”的可见状态；保存操作一般很快，快速切换会影响视觉稳定性。
- 所有状态面板只显示标题，不显示 tip。

## 3. 推荐实现

1. 在 `AIProviderSaveState` 中增加 `unsavedChanges`，用于表达“已有配置被修改但尚未保存”。
2. 加载已有 profile 后保持 `idle`，不显示成功态。
3. `markInputChanged()` 只在已有配置基础上把状态置为 `unsavedChanges`；新配置输入阶段保持安静。
4. 保存成功后显示 `.saved`，文案改为“配置已更新”。
5. 保留内部 `.saving` 用于防重复提交，但不渲染底部状态面板。
6. `statusPanel` 改为按需显示，仅覆盖 `unsavedChanges / saved / failed`。
7. 删除状态面板内说明文案渲染。

## 4. 不做什么

- 不改变 Keychain / SQLite 保存链路。
- 不恢复按钮内 `ProgressView` 或“正在保存...”文案。
- 不显示 API Key、Keychain account 或任何敏感信息。
- 不接入真实 Provider 网络测试。

## 5. 验证方法

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
scripts/verify.sh
```

## 6. 文档影响

本修正属于 AI Provider 设置页局部交互规则调整，已记录在本任务方案中。若后续沉淀全局按钮/状态面板规范，再提升到 `docs/spec/003-ui-design-system.md`。

## 7. 实施记录

- 2026-05-20：根据用户确认的最终交互规则创建方案并开始实施。
- 2026-05-20：新增 UI 状态回归测试并先确认失败，失败点为 `AIProviderSaveState` 缺少 `unsavedChanges`。
- 2026-05-20：已实现 `unsavedChanges`、加载已有配置保持 `idle`、新配置输入前保持安静、保存成功显示“配置已更新”、状态面板只显示标题且不渲染 tip。
- 2026-05-20：`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests` 通过，20 tests。
- 2026-05-20：`scripts/verify.sh` 通过；SwiftLint 仍有既有 warning，0 serious；SwiftFormat 0/140 files require formatting。
