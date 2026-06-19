# AI Provider 设置页语言空间上下文标题移除

状态：Verified  
类型：bug  
创建日期：2026-05-24  
最后更新日期：2026-05-24  

## 用户确认记录

用户在 2026-05-24 基于模拟器截图提出：AI Provider 设置页顶部导航标题已经是 `AI Provider`，内容区又出现一组 `AI Provider` 和 `中文 -> 英语 · B1`。用户进一步确认 AI Provider 设置本质是系统级配置，和当前语言空间没有必然归属关系，因此希望删除内容区语言空间上下文标题，使页面更简洁。

## Bug 描述

AI Provider 设置详情页在导航标题下重复显示能力标题，并把当前语言空间方向和等级作为内容区副标题。该信息会误导用户认为 Provider 配置属于当前语言空间，同时造成首屏纵向空间浪费。

## 复现方式

1. 在 iPhone 打开设置列表。
2. 进入 `AI Provider` 设置详情。
3. 观察导航标题下方的内容区 header。

## 预期行为

- 页面只保留顶部导航标题 `AI Provider` 作为页面归属。
- 内容区直接从文本模型配置开始，不重复显示 `AI Provider` 标题。
- 内容区不显示 `中文 -> 英语 · B1` 这类语言空间方向与等级。
- 当前语言空间 target language code 仍可作为测试请求的低敏上下文，用于 `语言支持` probe 和 TTS voice profile 读取。

## 实际行为

`SettingsCapabilityDetailView` 对除界面语言和外观外的设置能力统一插入 `header`，AI Provider 也进入该路径，所以内容区显示能力标题和 `languageSpace.displayContext`。

## 根因分析

根因是共享设置详情容器把 AI Provider 归入普通语言空间能力页处理。`AIProviderSettingsView` 自身已经没有顶部标题；重复 header 来自 `SettingsCapabilityDetailView.detailContent` 中的通用 `header` 分支。

置信度：95%

置信度依据：

- `AIProviderSettingsView.body` 直接从模型配置 section 开始，没有渲染 `AI Provider` 或语言空间副标题。
- `SettingsCapabilityDetailView.detailContent` 在 `capability.kind != .interfaceLanguage, capability.kind != .appearance` 时插入 `header`。
- `header` 使用 `capability.kind.localizedTitleKey` 和 `languageSpace?.displayContext`，与截图中的 `AI Provider` / `中文 -> 英语 · B1` 完全对应。

备选原因：

- 本地化字符串残留：字符串存在但不是当前截图渲染路径。
- Provider 表单内部 header：源码已排除。

## 目标

- 为 AI Provider 设置详情移除内容区通用 header。
- 保留其他仍需要语言空间上下文的设置详情 header。
- 保持 AI Provider 三端共享表单和当前 target language code 注入，不改变 Provider 保存、Keychain、测试请求或隐私边界。
- 更新设计规范、AI Provider 规范和页面清单，明确 AI Provider 配置是系统级设置，语言空间只作为测试上下文。

## 不做什么

- 不删除导航标题。
- 不移除 `语言支持` probe。
- 不改变 TTS voice profile 当前按 language code 读取和保存的实现。
- 不改变 Provider profile、endpoint、credential、Keychain、GRDB 或同步边界。
- 不重做设置详情整体导航结构。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`

## 涉及的文档路径

- `docs/plans/active/2026-05-24-bug-ai-provider-settings-context-header.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/platform-page-inventory.md`

## 实施方案

1. 新增 UI package source-boundary 回归测试，断言 AI Provider 详情通过 `showsCapabilityHeader` 排除内容区 header，同时仍把 `languageSpace.targetLanguageCode` 注入 `AIProviderSettingsView`。
2. 先运行聚焦测试，确认旧实现失败。
3. 在 `SettingsCapabilityDetailView` 中提取 `showsCapabilityHeader`，将 `.aiProvider` 纳入不显示通用 header 的系统级设置页例外。
4. 更新 UI 设计系统规范和 AI Provider 隐私规范，沉淀“系统级配置不在内容区显示当前语言空间归属”的规则。
5. 更新页面清单，记录 AI Provider 配置页直接进入模型表单，语言空间只用于 probe / voice profile 上下文。
6. 运行聚焦测试、UI package 测试、文档检查和统一验证。

## 回归测试方案

- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`
- `swift test --package-path Packages/LangoTraceUI`
- `git diff --check`
- 文档 placeholder 扫描
- `scripts/verify.sh`

## 文档影响检查

本任务改变设置页信息架构和 AI Provider 页面语义，需要同步 `docs/spec` 与 `docs/platform-page-inventory.md`。不涉及 ADR、数据 schema、Provider 请求体、Keychain、同步、StoreKit 或权限。

## 实施记录

- 2026-05-24：创建方案，确认根因在 `SettingsCapabilityDetailView` 通用 header，而非 `AIProviderSettingsView` 表单内部。
- 2026-05-24：新增 `AIProviderSettingsTests` source-boundary 回归测试，断言 AI Provider 详情使用 `showsCapabilityHeader` 排除内容区 header，同时继续把 `languageSpace.targetLanguageCode` 注入 `AIProviderProbeLanguageContext`。
- 2026-05-24：红灯运行 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`，旧实现失败，失败点为缺少 `showsCapabilityHeader`、`.aiProvider` 例外和 `if showsCapabilityHeader`。
- 2026-05-24：修改 `SettingsCapabilityDetailView`，新增 `showsCapabilityHeader`，让 `.aiProvider`、`.interfaceLanguage` 和 `.appearance` 不显示通用能力 header；其他能力详情保留原有 header。
- 2026-05-24：更新 `InterfaceLanguageSettingsPageTests`，把旧的内联条件断言调整为新的 `showsCapabilityHeader` helper 边界。
- 2026-05-24：同步 `docs/spec/003-ui-design-system.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md` 和 `docs/platform-page-inventory.md`，记录 AI Provider 是系统级设置，当前语言空间只作为 probe / voice profile 上下文。

## 验证记录

- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`：红灯失败一次，随后通过，32 tests。
- `swift test --package-path Packages/LangoTraceUI --filter InterfaceLanguageSettingsPageTests`：通过，6 tests。
- `swift test --package-path Packages/LangoTraceUI`：首次因相邻 source-boundary 测试仍断言旧内联条件失败；同步测试后通过，214 tests。
- `git diff --check`：通过。
- 文档 placeholder 扫描：通过，无输出。
- `scripts/verify.sh`：首次失败于 SwiftFormat lint，原因是新 helper 使用了当前规则判定为冗余的 `return`；移除 `return` 并同步测试断言后重新运行通过。SwiftLint 仍有既有 warning，0 serious；SwiftFormat lint 显示 0/208 files require formatting。

## 完成标准

- AI Provider 设置详情内容区不再显示重复 `AI Provider` 标题和语言空间副标题。
- 当前语言空间 target language code 仍传入 AI Provider 测试上下文。
- 相关规范和页面清单已更新。
- 聚焦测试、UI package 测试、文档检查和统一验证通过。
- 方案已移入 `docs/plans/done/`。

## 剩余风险

- 本轮自动测试以 source-boundary 为主，最终视觉仍依赖模拟器或人工截图确认；不过当前问题由明确的 SwiftUI header 分支造成，代码路径确定。
