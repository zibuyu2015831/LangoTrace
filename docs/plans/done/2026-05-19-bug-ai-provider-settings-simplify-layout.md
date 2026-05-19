# AI Provider 设置页信息降噪与对齐修复

Status: Verified

## 背景

iOS AI Provider 设置页当前仍展示过多实现边界说明：顶部说明、Provider 说明、请求格式/认证方式、凭证说明、动作状态和隐私说明在同一页面重复出现，削弱真实设置页的简洁感。

截图复查还发现 Provider 内容框没有与后续表单卡片保持同宽对齐。

## 目标

1. 将 AI Provider 设置页改成更真实的设置表单：Provider、Base URL、API Key、模型、保存配置、测试请求。
2. 删除或收起对普通用户不必要的实现说明，只保留必要的安全语义。
3. 保证所有一级面板在 iPhone 页面中同宽对齐。
4. 保持当前仅 UI 展示的边界：不写 Keychain、不发起真实网络请求。

## 实施范围

- 修改 `AIProviderSettingsView.swift` 的信息层级和布局。
- 调整 `Localizable.xcstrings` 中相关文案。
- 更新 AI Provider 设置页测试，覆盖信息降噪和布局约束。

## 不做

- 不实现真实 Keychain 存储。
- 不实现真实 Provider 请求。
- 不变更 Provider 预设来源和模型列表。

## 验证

- 2026-05-19：先新增回归测试，确认旧实现仍包含 Provider 风险说明、独立隐私说明和只读技术元数据行，测试失败。
- 2026-05-19：删除 AI Provider 设置页主路径中的重复说明和技术元数据，补齐全宽布局约束。
- 2026-05-19：`swift test --package-path Packages/LangoTraceUI` 通过，80 个测试通过。

## 结果

- 顶部重复说明、Provider 风险说明、请求格式/认证方式、凭证解释段和独立隐私卡片已退出主路径。
- Provider 面板和后续表单面板通过根容器全宽约束保持对齐。
- 页面仍保留 Provider、Base URL、API Key、模型、保存配置和测试请求，不接入真实 Keychain 或真实网络请求。
