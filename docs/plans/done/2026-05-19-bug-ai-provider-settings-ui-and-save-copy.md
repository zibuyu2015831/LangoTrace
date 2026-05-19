# 任务方案：AI Provider 设置页字段重复与保存意图 UI 修复

状态：Verified
类型：bug
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

- 2026-05-19：用户截图指出 AI Provider 设置页字段重复、视觉不美观，并补充“用户填写的信息是需要加密后存储的，之后 app 在进行 AI 请求时会直接调用”。
- 2026-05-19：用户确认本轮“只需要完成页面 UI 设计，从 UI 上体现这一点，比如‘保存’按钮等；相关的真实存储逻辑后续再完善”。

## 1. 需求或 bug 描述

iPhone AI Provider 设置页出现 Base URL、API Key、模型输入框重复渲染三次的问题，且页面仍偏开发态：只有测试按钮，没有清晰的“保存配置”主动作，也没有从 UI 层表达“凭证后续会进入本机加密存储、AI 请求会从安全配置读取”的产品意图。

本轮修复必须限定在 UI 和 mock 状态，不接入真实 Keychain、数据库持久化或真实网络请求。

## 2. 根因分析

`Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 中的 `langoProviderTextInput(keyboardHint:)` 使用 `@ViewBuilder`，但 iOS 分支写成三条并列表达式：

```swift
textInputAutocapitalization(.never)
keyboardType(keyboardHint.keyboardType)
autocorrectionDisabled()
```

在 `@ViewBuilder` 中，这三条表达式会被组合为多个 view 输出，而不是对同一个 view 连续应用三个 modifier，导致每个调用该 modifier 的输入控件被重复渲染。

## 3. 目标

- 修复输入框重复渲染，确保每个字段只出现一次。
- 将页面主动作调整为“保存配置”，测试请求作为保存/填写后的辅助动作。
- 从 UI 文案和状态上表达：API Key 属于敏感凭证，正式接入后会进入本机加密存储，后续 AI 请求会从安全配置读取。
- 明确当前版本只展示保存状态和配置草稿，不写入 Keychain、不发起真实网络请求。
- 优化页面视觉密度，减少开发标记感，保持 iPhone 页面简洁、可信、可继续演进。

## 4. 范围

- `AIProviderSettingsView` 的输入 modifier、页面结构、按钮层级和状态卡。
- `AIProviderDraftConfiguration` 的 UI mock 保存状态。
- AI Provider 设置相关本地化字符串。
- 针对重复字段根因、保存按钮、加密保存边界和无网络请求的测试。
- 同步 `docs/platform-page-inventory.md` 和 `docs/spec/005-ai-provider-prompt-and-privacy.md` 中的当前实现事实。

## 5. 不做什么

- 不实现 Keychain repository。
- 不把 API Key 写入数据库、文件、日志、同步目录或 mock repository。
- 不接入真实 Provider 请求、模型列表拉取、健康检查或费用估算。
- 不修改 AI Provider 长期架构决策。
- 不扩展到 iPad/macOS 专门布局重做；共享页面可继续在三端打开。

## 6. 实施方案

1. 先补失败测试：
   - 检查 `langoProviderTextInput` 不再包含会产生多 view 的并列表达式。
   - 检查页面包含保存按钮和加密保存边界文案 key。
   - 检查当前实现仍不包含 `URLSession`、Bearer 请求或真实网络调用。
2. 修复 `langoProviderTextInput`，将 iOS modifier 改成单一链式表达式。
3. 调整 draft 状态：
   - 将凭证状态从 transient wording 改为 UI 层的 secure draft / encrypted storage pending。
   - 增加 mock 保存状态和 `saveMockConfiguration()`。
4. 调整页面结构：
   - 顶部摘要保留语言空间和安全配置状态。
   - Provider 与连接信息保持紧凑。
   - 凭证与模型输入只出现一次。
   - 操作区提供“保存配置”主按钮和“测试请求”次按钮。
   - 状态卡说明“当前只展示保存状态，不写入 Keychain；测试不发网络请求”。
5. 更新本地化和文档事实。
6. 运行 UI package 测试、格式/静态检查、完整验证脚本，并重新安装启动 iOS 模拟器。

## 7. 复查方法

- 代码复查：检查 `langoProviderTextInput` 为单链式 modifier，不产生多 view。
- 测试复查：新增测试在旧实现下失败，在修复后通过。
- UI 复查：iPhone 页面中 Base URL、API Key、模型字段各只出现一次；主按钮为“保存配置”。
- 隐私复查：页面不承诺真实 Keychain 已完成，但清楚表达正式配置会加密保存并供后续 AI 请求读取。
- 网络边界复查：源码中不出现 `URLSession`、`dataTask`、`Authorization` 或 `Bearer` 请求实现。

## 8. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
scripts/verify.sh
```

## 9. 完成标准

- 字段重复问题消失。
- AI Provider 设置页有清晰的“保存配置”主动作。
- 页面通过 UI 明确传达“敏感凭证将加密保存，后续 AI 请求从安全配置读取”的产品设计。
- 当前不接入真实存储和真实请求的边界明确。
- 测试和验证通过。

## 10. 实施记录

- 2026-05-19：补充回归测试，确认旧实现下 `AIProviderSettingsTests` 因缺少保存 UI 和链式 text input modifier 失败。
- 2026-05-19：修复 `langoProviderTextInput`，将 iOS text input modifier 改为单链式表达式，避免 `@ViewBuilder` 输出多个 view。
- 2026-05-19：新增 UI mock 保存状态和 `保存配置` 主按钮；测试请求改为次按钮；页面状态说明改为安全配置草稿和加密保存意图。
- 2026-05-19：更新本地化、页面清单和 AI Provider 隐私规范，明确当前版本不写 Keychain、不发网络。
- 2026-05-19：完成 `swift test --package-path Packages/LangoTraceUI`，结果 79 tests passed。
- 2026-05-19：完成 `swift test --package-path Packages/LangoTraceData`，结果 11 tests passed；完成 `swiftlint --no-cache` 和 `swiftformat --lint . --cache ignore`，结果均通过。
- 2026-05-19：完成边界扫描，未发现开发标记文案、`URLSession` 或 Bearer 请求实现；完成 `git diff --check`。
- 2026-05-19：完成 `scripts/verify.sh`，结果通过；脚本覆盖 XcodeGen、Core/Data/UI tests、iPhone/iPad/macOS builds、SwiftLint、SwiftFormat 和 docs placeholder scan。
- 2026-05-19：完成 iOS 模拟器重装和启动，`xcrun simctl launch booted com.zibuyu.LangoTrace` 返回进程 `94789`。
