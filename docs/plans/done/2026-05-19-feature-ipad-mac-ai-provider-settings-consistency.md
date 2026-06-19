# iPad 与 macOS AI Provider 设置页一致性方案

Status: Verified

Type: feature

Created: 2026-05-19

Last Updated: 2026-05-19

## 用户确认记录

- 2026-05-19：用户确认 iOS 版 AI Provider 设置页当前方向无误，要求先确认 iPad 端和 Mac 端类似界面，并制定一致性开发方案文档。

## 背景

iOS AI Provider 设置页已经完成一轮真实级 UI 收敛：

- Provider 行内展示。
- API Key 有明确字段名。
- API Key 默认隐藏，并可通过眼睛按钮临时显示。
- 文案从“凭证”改为 `API Key`。
- 文本模型、语音生成模型和向量模型按能力分组。
- 当前仍为 Local Mock：不写 Keychain、不发网络、不保存真实 Provider 配置。

下一步需要确认 iPad 和 macOS 中同类页面是否存在同样问题，并在不破坏平台差异的前提下完成一致性开发。

## 代码阅读结论

### 1. 三端已经复用同一个设置详情组件

`SettingsCapabilityDetailView` 在 `capability.kind == .aiProvider` 时直接渲染：

```swift
AIProviderSettingsView()
```

涉及路径：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`

这意味着 iPhone、iPad 和 macOS 当前看到的 AI Provider 表单主体是同一套 SwiftUI 组件。iOS 已确认的字段结构、API Key 可见性按钮和主路径文案，会自然进入 iPad / macOS。

### 2. iPad 入口使用工作台路由中的设置详情

iPad 在 `PadWorkspaceContentView.settingDetail(kind:)` 中进入：

```swift
SettingsCapabilityDetailView(...)
```

涉及路径：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`

iPad 设置页处于工作台中间主区，而不是 iPhone 的窄屏 Push 页面。当前 `SettingsCapabilityDetailView` 自身没有为 AI Provider 表单设置最大宽度，AI Provider 表单可能在 iPad regular width 中横向拉得过宽。

### 3. macOS 入口同样复用设置详情

macOS 在 `MacWorkspaceContentView.settingDetail(kind:)` 中进入：

```swift
SettingsCapabilityDetailView(...)
```

涉及路径：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`

macOS 同样复用 `SettingsCapabilityDetailView`。在 Mac 可自由调整窗口宽度的情况下，AI Provider 表单如果没有平台级最大内容宽度，会产生过长输入框和过松散的卡片节奏，不符合桌面设置表单的阅读密度。

### 4. macOS 另有原生 Settings scene，但不是本轮详情表单入口

`LangoTraceApp` 中已经声明 macOS 原生 `Settings` scene：

```swift
Settings {
    LangoTraceSettingsSceneView(capabilities: settingsCapabilities)
}
```

`LangoTraceSettingsSceneView` 当前只展示只读能力列表，`CapabilityStatusRow` 的 `action` 为 `nil`，不会进入 `SettingsCapabilityDetailView`，也不会展示 `AIProviderSettingsView`。

涉及路径：

- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`

因此本方案覆盖的是 iPad / macOS **工作台内设置详情路由**，不是 macOS 原生 Settings scene 的完整 Provider 配置体验。macOS Settings scene 后续如果要承载真实 Provider 配置，需要单独设计它与主工作台 Provider 配置的共享模块和数据写入边界。

### 5. 当前问题不在字段组件，而在平台容器

`AIProviderSettingsView` 和 `AIProviderSettingsComponents.swift` 已承载 iOS 最新确认的字段结构。iPad / macOS 不需要另做一套 Provider、Base URL、模型和 API Key 组件。

真正需要补的是：

- iPad / macOS 的内容宽度约束。
- 设置详情页在大屏中保持合理行长。
- iPad 触控舒适度和 Mac 桌面密度之间的差异。
- macOS 工作台设置详情和原生 Settings scene 的职责分离。
- 回归测试锁定三端都经过同一个 AI Provider 设置组件，避免后续有人为 iPad / Mac 加回旧说明页或旧字段结构。

## 系统架构师复审结论

复审结论：方案方向成立，但实施表达需要两处收紧。

1. **不能把 iPhone / iPad 当作编译期平台分支。** Swift Package 中 `#if os(iOS)` 同时覆盖 iPhone 和 iPad。即使后续可以通过 UIKit 判断 idiom，也不应为了一个表单宽度引入设备判断。正确做法是使用自适应最大宽度：给 AI Provider 表单设置 `maxWidth`，在窄屏和 Split View 中它自然吃满可用宽度，在 iPad / Mac 宽屏中不超过上限。
2. **不能把 macOS Settings scene 混入本轮交付。** 当前 Mac 有主工作台 Settings section，也有原生 Settings scene。前者可进入 `SettingsCapabilityDetailView`，后者只是只读能力列表。本轮只处理工作台内 AI Provider 详情页；原生 Settings scene 的 Provider 配置能力后续单独设计，避免提前制造两套写入入口。
3. **字段语义和平台容器必须分层。** `AIProviderSettingsView` 继续表达 Provider 配置表单；`SettingsCapabilityDetailView` 或其局部 wrapper 只负责页面承载宽度。Provider、API Key、endpoint、mock readiness 和后续 Keychain 边界不应进入平台路由文件。
4. **最大宽度是视觉承载约束，不是数据或路由约束。** 它不得进入 `SettingsCapability`、`AIProviderDraftConfiguration`、Repository、同步 manifest 或任何持久化模型。
5. **测试应锁定架构边界而不是截图像素。** 本轮适合用源码级测试确认共享组件、无平台分叉、无真实网络请求、存在最大宽度 wrapper；视觉截图验证可以作为手动复查，不作为唯一自动证据。

## 目标

1. iPad 和 macOS 的 AI Provider 设置页与 iOS 保持同一信息架构：
   - 文本模型。
   - 语音生成模型。
   - 向量模型。
   - Provider 行内展示。
   - API Key 明确命名并可显示 / 隐藏。
   - 主路径使用 `API Key` 文案，不使用“凭证”。
2. iPad / macOS 不做放大版 iPhone 表单，而是在各自工作台中保持合适宽度和阅读节奏。
3. 不引入平台分叉的数据模型或重复表单组件。
4. 保持 Local Mock 边界，不接入真实 Keychain、网络请求或 Provider 测试请求。

## 非目标

- 不实现真实 Provider 存储。
- 不实现真实 Keychain item 引用。
- 不实现真实测试请求。
- 不新增或改造 macOS 原生 Settings scene 中的独立 Provider 设置页；该 scene 当前仍保持只读能力列表。
- 不改 iPad / macOS 顶层导航结构。
- 不重做 `SettingsCapabilityDetailView` 中所有设置项的视觉体系，本任务只处理 AI Provider 详情页一致性和承载边界。

## 设计原则

### iPad

iPad 是工作台，不是放大的 iPhone：

- 保持当前 Sidebar / Workspace / Learning Panel 的工作台结构。
- AI Provider 设置详情应在中间主区显示。
- 表单主体应限制到适合阅读和输入的最大宽度，例如 720-820pt。
- 窄分屏或 Slide Over 下，表单自然退回单列滚动，不隐藏关键字段。
- 触控目标保持 44pt 以上。

### macOS

macOS 是桌面工作台：

- 保持 Sidebar + 主工作区结构。
- AI Provider 设置详情应在主工作区内呈现为桌面设置表单，而不是铺满全窗口。
- 表单主体应限制最大宽度，例如 760-860pt，并靠左或在内容区域内形成稳定阅读栏。
- 输入框可以比 iPad 更紧凑，但不能牺牲可读性和 VoiceOver / keyboard focus。
- 后续真实 Provider 高级配置可以进入 Mac 更高密度的高级区域，但本轮不新增。

## 推荐方案

### 方案 A：在 `SettingsCapabilityDetailView` 中引入设置详情内容宽度容器

对 `SettingsCapabilityDetailView` 增加一个小型平台适配容器，例如：

```swift
VStack(alignment: .leading, spacing: 18) {
    header
    AIProviderSettingsView()
}
.frame(maxWidth: settingsDetailMaxWidth, alignment: .leading)
```

其中需要注意：

- 不能依赖编译期区分 iPhone / iPad。
- iPhone 和 iPad 都属于 iOS，建议统一使用一个 iOS 最大宽度，例如 820pt；iPhone 可用宽度小于上限时会自然吃满。
- macOS 可使用稍大的最大宽度，例如 860pt，保持桌面表单阅读栏。

优点：

- 最小改动。
- 三端继续复用同一 AI Provider 表单。
- 对其他设置详情也可能有正向影响，但需谨慎确认不会破坏当前布局。

风险：

- 如果直接作用于所有设置详情，可能改变其他设置说明页宽度。
- 需要通过测试锁定 AI Provider 页，而不是无意重排所有页面。

### 方案 B：只为 AI Provider 设置页包一层平台宽度容器

保留其他设置详情不动，只在 `capability.kind == .aiProvider` 分支中应用：

```swift
AIProviderSettingsView()
    .frame(maxWidth: aiProviderSettingsMaxWidth, alignment: .leading)
```

优点：

- 范围最窄。
- 不影响其他设置页。
- 符合本任务只处理 AI Provider 页的边界。

风险：

- 如果后续其他复杂设置页也需要同样模式，可能出现重复。

### 推荐选择

推荐采用 **方案 B**。

原因：当前用户明确要求的是 iPad / Mac 的“类似界面”，也就是 AI Provider 设置页一致性，不是整体设置系统重构。只给 AI Provider 表单加平台宽度容器，风险最小，也能避免把其他说明型设置页提前带入新的布局规则。

## 具体实施方案

### 1. 增加平台宽度包装

在 `SettingsCapabilityDetailView` 中为 AI Provider 分支添加包装：

- iOS：`maxWidth: 820`。iPhone 和窄分屏可用宽度小于 820 时自然单列铺满；iPad regular width 不超过 820。
- macOS：`maxWidth: 860`。

不要通过 `UIDevice.current.userInterfaceIdiom` 或新增平台枚举来区分 iPhone / iPad。此处只需要宽度上限，不需要设备身份。

命名建议：

- `aiProviderSettingsContentMaxWidth`
- `aiProviderSettingsContainer`

建议放在 `SettingsCapabilityDetailView` 的私有 extension 中，使用 `#if os(macOS)` 只区分 macOS 与 iOS：

```swift
private var aiProviderSettingsContentMaxWidth: CGFloat {
    #if os(macOS)
        860
    #else
        820
    #endif
}
```

如果后续更多真实设置表单需要相同模式，再抽象 `SettingsFormContainer`。本轮不提前抽象，避免扩大影响面。

### 2. 保持字段组件共享

不新增 `PadAIProviderSettingsView` 或 `MacAIProviderSettingsView`。

继续复用：

- `AIProviderSettingsView.swift`
- `AIProviderSettingsComponents.swift`

原因：

- 三端字段语义完全一致。
- 避免 iPad / Mac 因复制组件重新出现“凭证”“高级模型”或无标签 API Key 等旧问题。

### 3. 补测试

在 `AIProviderSettingsTests.swift` 或新增平台布局测试中补充：

- `SettingsCapabilityDetailView.swift` 中 AI Provider 分支仍使用 `AIProviderSettingsView()`。
- AI Provider 设置页有平台最大宽度约束。
- 不存在 `PadAIProviderSettingsView` / `MacAIProviderSettingsView` 这类分叉组件。
- `LangoTraceSettingsSceneView` 仍保持只读能力列表，不在本轮引入第二套 AI Provider 配置表单。
- `AIProviderSettingsComponents.swift` 继续包含：
  - `AIProviderRowPicker`
  - `AIProviderAPIKeyField`
  - `eye` / `eye.slash`
  - `aiProviderSettings.apiKey.useText`
  - `aiProviderSettings.apiKey.useIndependent`

### 4. 更新文档

更新以下文档：

- `docs/platform-page-inventory.md`
  - 记录 iPad / macOS AI Provider 设置页复用同一组件，但在大屏中有表单最大宽度约束。
  - 继续记录 macOS Settings scene 是只读能力列表，不与工作台设置详情混淆。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
  - 补充三端 Provider 设置页共享字段语义，平台只调整承载宽度和密度，不分叉数据模型。
- 本方案完成后移入 `docs/plans/done/`。

## 验证方法

### 自动验证

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceUI
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
scripts/verify.sh
```

### 手动视觉复查

iPad：

- 从 Sidebar 底部 AI 状态或设置列表进入 AI Provider。
- 页面显示文本模型、语音生成模型、向量模型。
- Provider 行内展示。
- API Key 有标题和眼睛按钮。
- 表单不铺满整个 13-inch iPad 主工作区。
- Split View 窄宽度下仍可滚动填写。

macOS：

- 从 Sidebar 底部 AI 状态或设置列表进入 AI Provider。
- 页面显示同一字段结构。
- 输入框不横跨整个窗口。
- 宽窗口下内容保持稳定阅读栏。
- 窗口缩小时不截断字段标题、API Key 按钮或操作区按钮。
- `Cmd+,` 打开的原生 Settings scene 仍为能力状态列表，不应出现未设计的数据写入入口。

## 完成标准

- iPad / macOS 与 iOS 使用同一 AI Provider 设置字段结构。
- iPad / macOS 的 AI Provider 表单有合理最大宽度，不再像拉伸版 iPhone 表单。
- 不产生平台分叉组件。
- macOS 原生 Settings scene 的只读边界保持清楚，不与工作台 AI Provider 配置详情混淆。
- 回归测试覆盖共享组件和平台容器约束。
- 文档同步完成。
- `scripts/verify.sh` 通过。

## 实施记录

- 2026-05-19：在 `AIProviderSettingsTests` 中新增源码级回归测试，先确认 `SettingsCapabilityDetailView` 缺少 AI Provider 平台最大宽度容器时失败。
- 2026-05-19：在 `SettingsCapabilityDetailView` 中新增 `aiProviderSettingsContainer` 和 `aiProviderSettingsContentMaxWidth`，仅对 AI Provider 分支应用最大内容宽度；iOS 为 820pt，macOS 为 860pt。
- 2026-05-19：确认未新增 `PadAIProviderSettingsView` 或 `MacAIProviderSettingsView`，macOS 原生 `LangoTraceSettingsSceneView` 仍不渲染 `AIProviderSettingsView`，能力列表 row 继续使用 `action: nil`。
- 2026-05-19：同步更新 `docs/platform-page-inventory.md` 和 `docs/spec/005-ai-provider-prompt-and-privacy.md`，记录三端共享表单、大屏承载宽度和 macOS 原生 Settings scene 只读边界。
- 2026-05-19：验证通过：
  - `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`
  - `swift test --package-path Packages/LangoTraceUI`
  - `swiftlint --no-cache`
  - `swiftformat --lint . --cache ignore`
  - `python3 -m json.tool Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
  - `git diff --check`
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'` 无命中
  - `scripts/verify.sh`

## 剩余风险

- 当前方案只约束 AI Provider 设置页，不解决所有设置详情页在大屏下的布局密度问题。如果后续 Sync、Export、Local Data 等设置页也变成真实表单，可能需要抽象通用 `SettingsFormContainer`。
- macOS 未来如果新增原生 Settings scene，AI Provider 配置可能需要在主工作台和 Settings scene 之间复用更明确的 Provider configuration module。本轮不提前设计。
- 真实 Keychain 接入后，API Key 可见性按钮需要结合系统安全存储、编辑状态、已保存密钥占位显示和删除/替换流程重新审查。
