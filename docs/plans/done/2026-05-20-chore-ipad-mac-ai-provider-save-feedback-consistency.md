# iPad / Mac AI Provider 保存反馈一致性方案

状态：Done
类型：chore
创建日期：2026-05-20
最后更新日期：2026-05-20

## 1. 背景

iOS 端 AI Provider 配置页已经完成保存反馈、Keychain 回显、同值写入不误触发“配置未保存”等修复，并已提交为 `09c9336 fix: refine ai provider save feedback`。用户要求继续完成 iPad 和 Mac 端对应修改，保持一样的设计。

## 2. 当前代码事实

- `AIProviderSettingsView` 是三端共享表单组件，承载文本模型、语音生成模型、向量模型、API Key 字段、保存按钮、测试按钮和底部保存反馈。
- `SettingsCapabilityDetailView` 在 `capability.kind == .aiProvider` 时渲染 `AIProviderSettingsView()`，并为 iPad / macOS 设置最大内容宽度。
- iPad 工作台通过 `PadMainSections.settingDetail(kind:) -> SettingsCapabilityDetailView` 进入 AI Provider 设置。
- Mac 工作台通过 `MacWorkspaceContentView.settingDetail(kind:) -> SettingsCapabilityDetailView` 进入 AI Provider 设置。
- macOS 原生 Settings scene 通过 `LangoTraceSettingsSceneView.settingsDetail -> SettingsCapabilityDetailView` 进入能力详情。
- `LangoTraceApp` 已在主窗口和 macOS Settings scene 注入同一套 `aiProviderSettingsActions`；当前代码和回归测试确认 Keychain resolver、保存、验证和诊断 action 三端一致。

## 3. 设计结论

1. 不新增 `PadAIProviderSettingsView` 或 `MacAIProviderSettingsView`。
2. iPad / Mac 保持复用 `AIProviderSettingsView`，共享 iOS 已确认的按钮样式、底部状态提示、短暂停留规则、API Key 默认隐藏和已保存密钥回显。
3. 平台差异只保留在承载层：
   - iPad 工作台：主区详情页承载共享表单，最大宽度不超过 iPad 阅读栏。
   - Mac 工作台：嵌入现有工作台滚动容器，避免嵌套滚动。
   - macOS Settings scene：系统设置窗口中仍走共享详情组件，不创建第二套字段模型。
4. 本任务主要补齐防回归测试和文档收口，避免后续误以为 iPad / Mac 需要复制一套表单或回退到旧只读能力说明。

## 4. 实施步骤

1. 新增或扩展 UI 测试，锁定：
   - iPad 设置详情通过 `SettingsCapabilityDetailView` 进入共享 AI Provider 表单。
   - Mac 工作台设置详情通过 `SettingsCapabilityDetailView` 进入共享 AI Provider 表单，并使用 embedded presentation。
   - macOS Settings scene 使用 `SettingsCapabilityDetailView`，不直接创建 `AIProviderSettingsView` 分叉。
   - `LangoTraceApp` 在主窗口和 macOS Settings scene 都注入 `aiProviderSettingsActions`。
2. 若测试发现 iPad / Mac 有分叉、缺 action 注入或使用旧只读说明，修复对应容器。
3. 更新任务方案实施记录；如代码事实不改变长期规则，不新增 ADR。
4. 运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderPlatformConsistencyTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
scripts/verify.sh
```

## 5. 不做什么

- 不复制 iPad / Mac 专用 Provider 表单。
- 不改变 Provider 数据模型、Keychain 存储策略或真实网络请求边界。
- 不新增真实 Provider 合成探测。
- 不改变 iPhone 已确认的保存反馈文案和状态规则。

## 6. 验收标准

- iPad、Mac 工作台和 macOS Settings scene 都只能通过共享 `AIProviderSettingsView` 获得 Provider 配置能力。
- 三端都使用同一套 `aiProviderSettingsActions`，确保 Keychain 回显、保存、验证和诊断行为一致。
- 相关回归测试通过，`scripts/verify.sh` 通过。

## 7. 实施记录

- 2026-05-20：新增 `AIProviderPlatformConsistencyTests`，覆盖 iPad 工作台、Mac 工作台、macOS Settings scene 和 `LangoTraceApp` 环境注入。测试确认当前运行时代码已经通过共享 `SettingsCapabilityDetailView -> AIProviderSettingsView` 获得同一套保存反馈、已保存密钥回显和 Keychain action，不需要新增平台专用表单。
- 2026-05-20：执行 `swift test --package-path Packages/LangoTraceUI --filter AIProviderPlatformConsistencyTests`，3 个测试通过。
- 2026-05-20：执行 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`，28 个 AI Provider 相关测试通过。
- 2026-05-20：执行 `scripts/verify.sh`，通过。输出中仍有既有 SwiftLint warning，但命令退出码为 0；本轮新增测试附近的行宽 warning 已修复，并重新执行 `swift test --package-path Packages/LangoTraceUI --filter AIProviderPlatformConsistencyTests`、`git diff --check` 和 `swiftformat --lint . --cache ignore`，均通过。

## 8. 架构置信度

结论置信度：高，0.92。

置信度依据：

- 三端入口已经由源码确认：iPad 工作台、Mac 工作台和 macOS Settings scene 都经由 `SettingsCapabilityDetailView` 进入 AI Provider 设置。
- 共享表单唯一归属已经由源码确认：`AIProviderSettingsView()` 只在 `SettingsCapabilityDetailView` 中实例化，未发现 `PadAIProviderSettingsView` 或 `MacAIProviderSettingsView`。
- action 注入已经由源码确认：`LangoTraceApp` 在主窗口和 macOS Settings scene 都注入 `environment.aiProviderSettingsActions`。
- 防回归测试已经覆盖上述边界，并在本轮验证中通过。
- `scripts/verify.sh` 已完成三端构建和 package 测试，验证共享组件在 iPhone、iPad Simulator 和 macOS 构建链路中都可编译。

剩余风险：

- 本轮新增的是源码结构防回归测试，不是 iPad / macOS 的交互截图测试；由于三端实际复用同一 SwiftUI 表单，当前风险主要来自未来容器布局改动，而不是保存反馈逻辑分叉。
- `scripts/verify.sh` 仍输出既有 SwiftLint warning；这些 warning 不属于本任务引入，且当前验证脚本退出码为 0。

后续触发复查条件：

- `PadMainSections`、`MacWorkspaceContentView`、`LangoTraceSettingsSceneView` 或 `SettingsCapabilityDetailView` 的 AI Provider 路由发生调整。
- `AIProviderSettingsView` 从共享详情容器中拆分为平台专用表单。
- `AIProviderSettingsActions` 注入位置、Keychain resolver、保存或本地验证 action 发生变化。
