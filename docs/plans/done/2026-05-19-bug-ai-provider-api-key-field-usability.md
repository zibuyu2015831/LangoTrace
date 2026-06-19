# AI Provider API Key 表单可用性修正方案

Status: Verified

Type: bug

Created: 2026-05-19

Last Updated: 2026-05-19

## 用户确认记录

- 2026-05-19：用户确认采纳 UI 设计方案，要求立即更新文档并实施。

## 问题描述

AI Provider 设置页已经按文本模型、语音生成模型和向量模型拆分，但当前表单仍存在三处影响可用性和高级感的问题：

1. Provider 标签和选项上下排列，占用纵向空间，视觉上不像 iOS 设置项。
2. API Key 输入框没有字段名称，用户只能看到密码点，不清楚该区域输入什么。
3. 语音模型和向量模型中的“凭证”文案偏工程化，中文普通用户理解成本高。

## 目标

- Provider 行改为同一行展示：左侧 `Provider`，右侧当前 Provider 名称和菜单指示。
- API Key 区域明确展示 `API Key` 标签。
- API Key 输入框提供显示/隐藏按钮，默认隐藏，用户可临时确认输入是否正确。
- 主路径中文案把“凭证”替换为更容易理解的 `API Key`。
- 保持当前 mock 边界：不发网络、不写 Keychain、不改变 Provider 数据模型。

## 范围

### 代码范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`

### 文档范围

- `docs/plans/done/2026-05-19-feature-ai-provider-multi-model-configuration.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`

## 不做什么

- 不实现真实 Keychain 存储。
- 不实现真实 Provider 测试请求。
- 不新增高级配置页。
- 不调整三类模型 endpoint 和 credential reference 的底层结构。

## 设计决策

### Provider 行

使用一行设置项表达 Provider：

```text
Provider                  OpenAI ˅
```

原因：Provider 是选择项，不是长文本输入。行内展示更符合 iOS 设置页扫描习惯，也减少文本模型卡片首屏高度。

### API Key 输入

API Key 使用明确标签和可见性切换：

```text
API Key
••••••••••••••••        [eye]
```

默认使用隐藏输入。点击眼睛按钮时只切换当前字段，不影响其他模型的 API Key 可见性。图标按钮使用 `Button`，保持 44pt 触控区域。

### 中文文案

主路径不再使用“凭证”。用户可见文案改为：

- `API Key`
- `使用文本模型 API Key`
- `使用独立 API Key`

文档和代码内部仍可保留 credential reference 命名，因为那是架构语义，不直接面向普通用户。

## 实施方案

1. 在 `AIProviderSettingsTests.swift` 增加源码回归测试：
   - 存在 `AIProviderRowPicker` 或等价行内 Provider 组件。
   - 存在 `AIProviderAPIKeyField` 或等价 API Key 组件。
   - API Key 字段包含 `eye` / `eye.slash` 显示切换。
   - 主路径不再使用 `aiProviderSettings.credential.*` 本地化 key。
   - 主路径使用 `aiProviderSettings.apiKey.useText` 和 `aiProviderSettings.apiKey.useIndependent`。
2. 重构 `AIProviderEndpointFields`：
   - Provider 改为行内 picker。
   - Base URL 和模型字段保持原输入样式。
3. 新增复用的 `AIProviderAPIKeyField`：
   - 内部维护 `@State private var isVisible = false`。
   - 根据状态在 `SecureField` 和 `TextField` 之间切换。
   - 右侧使用眼睛按钮切换。
4. 替换文本模型和独立 API Key 输入位置。
5. 更新本地化 key 与文档说明。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceUI
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
scripts/verify.sh
```

## 完成标准

- Provider 和当前 Provider 名称同一行展示。
- API Key 字段有清晰名称。
- API Key 字段可显示/隐藏。
- 语音模型和向量模型中的共享选择使用 `API Key` 文案，不再用“凭证”。
- 回归测试覆盖上述 UI 结构和文案约束。
- `scripts/verify.sh` 通过。

## 实施记录

- 2026-05-19：新增回归测试，先确认缺少 `AIProviderRowPicker`、`AIProviderAPIKeyField`、显示/隐藏按钮和 API Key 文案时测试失败。
- 2026-05-19：新增行内 Provider 选择组件和 API Key 输入组件；API Key 默认隐藏，右侧按钮可切换 `eye` / `eye.slash`。
- 2026-05-19：文本模型、语音生成模型和向量模型的独立 API Key 输入统一复用 `AIProviderAPIKeyField`。
- 2026-05-19：主路径本地化从“凭证”改为 `API Key`，并同步更新 AI Provider 规范和页面清单。
- 2026-05-19：验证通过：`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`、`swift test --package-path Packages/LangoTraceUI`、`swiftlint --no-cache`、`swiftformat --lint . --cache ignore`、String Catalog JSON 解析。
