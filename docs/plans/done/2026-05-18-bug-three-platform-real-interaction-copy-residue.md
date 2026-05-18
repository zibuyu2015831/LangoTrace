# 三端真实交互展示残留清理方案

状态：Verified

类型：bug

创建日期：2026-05-18

最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户指出前面对 iPad、Mac、iOS 三端检查并去除开发标记和提示语后，语言空间页仍残留 `当前边界`、`后续接入条件`、`不会发生` 等说明块，要求再次检查和清除，保证所有页面呈现真实交互效果。
- 2026-05-18：用户确认执行方案，要求实现。

## 需求或 Bug 描述

部分设置详情、语言空间详情和 unavailable 页面仍保留开发阶段说明结构。虽然这些文案不再直接写 `mock` 或 `SQLite`，但 `当前边界`、`后续接入条件`、`不会发生`、`本机预览` 这类展示仍让页面像工程状态说明，而不是真实产品交互。

## 复现方式

1. 启动 iPhone 17 模拟器。
2. 打开语言空间详情页。
3. 页面可见三段工程说明式面板：`当前边界`、`后续接入条件`、`不会发生`。
4. iPad 和 macOS 的设置详情、能力详情和 unavailable 页面也可能出现同类通用说明标题。

## 预期行为

- 三端主展示路径和二级详情页不出现开发说明式标题。
- 普通信息页使用产品语义，例如空间信息、保存与恢复、隐私说明、偏好状态。
- 高风险外发、权限、导入导出页面可以说明不会发生的副作用，但不能以通用工程面板标题占据主视觉。
- 内部 `mockOnly`、`isMock` 等架构状态可以保留，但用户可见文案必须产品化。

## 实际行为

- `LanguageSpaceSummaryView` 默认渲染三段说明面板。
- `SettingsCapabilityDetailView` 对所有设置能力默认渲染三段说明面板。
- `UnavailableCapabilityView` 默认渲染 `Required Before Connecting` / `What Will Not Happen` 这类工程说明标题。
- String Catalog 仍包含 `当前边界`、`后续接入条件`、`不会发生`、`本机预览`。

## 根因分析

置信度：90%

前一轮文案清理主要禁止了 `mock`、`SQLite`、`未接入` 等显式工程词，但没有把“工程说明结构”纳入测试约束。通用设置详情组件复用了三段式边界说明，导致页面即使没有工程名词，仍呈现开发说明感。

## 目标、范围和不做什么

目标：

- 清理 iPhone、iPad、macOS 可见页面中的开发说明式标题和状态 badge。
- 将语言空间、设置详情和 unavailable 页面改成产品语义结构。
- 扩展回归测试，防止同类文案再次进入可见 UI。

范围：

- `Packages/LangoTraceUI/Sources/LangoTraceUI`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests`
- 本任务方案文档。

不做：

- 不接入真实 SQLite / GRDB。
- 不接入真实 AI Provider、TTS、录音、OCR、同步、导入导出或 StoreKit。
- 不删除内部 mock / in-memory 架构状态。
- 不把未完成能力伪装成已完成。

## 证据与决策依据

- `docs/spec/003-ui-design-system.md` 要求 UI 安静、清晰、长期可读，状态表达可信但不打扰主流程。
- `docs/spec/006-interface-localization-and-language-boundaries.md` 要求 UI 文案作为 App chrome 本地化，不能把工程状态直接作为用户语言。
- 已归档 `docs/plans/done/2026-05-18-bug-three-platform-demo-copy-cleanup.md` 已处理显式开发词，本轮处理残留的工程说明结构。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSummaryView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/UnavailableCapabilityView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/ThreePlatformPresentationCopyTests.swift`

## 实施方案

1. 扩展 `ThreePlatformPresentationCopyTests`，禁止可见 String Catalog value 出现截图中的残留开发说明词。
2. 先运行新增测试，确认失败。
3. 将通用设置详情标题改为产品语义：`当前状态`、`接下来`、`隐私说明` 或具体页面标题。
4. 将 `capabilityStatus.mockOnly` 和 `requestPreview.localMock` 的用户可见值从 `On-device preview` / `本机预览` 改为更自然的本地优先表达。
5. 将 language space 页面从三段式工程说明改为“空间信息 + 保存与恢复 + 隐私说明”的产品说明。
6. 将 unavailable 页面标题从接入条件/不会发生改为“接下来 / 隐私说明”，保留不外发、不录音、不导入导出的安全事实。
7. 运行针对性测试和全量验证。

## 回归测试方案

- `ThreePlatformPresentationCopyTests.visibleCatalogCopyAvoidsEngineeringStageWording` 禁止：
  - `当前边界`
  - `后续接入条件`
  - `不会发生`
  - `本机预览`
  - `Current Boundary`
  - `Next Requirement`
  - `Will Not Happen`
  - `What Will Not Happen`
  - `Required Before Connecting`
  - `On-device preview`

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter ThreePlatformPresentationCopyTests
swift test --package-path Packages/LangoTraceUI
swift test --package-path Packages/LangoTraceData
scripts/verify.sh
git diff --check
git status --short
```

## 文档影响检查

本任务不改变产品北极星、架构决策、数据路线或 Provider / Sync 边界。完成后归档本任务方案即可。

## 实施记录

- 2026-05-18：创建任务方案，准备按 TDD 扩展回归测试。
- 2026-05-18：扩展 `ThreePlatformPresentationCopyTests`，将截图中的残留开发说明词纳入可见文案禁用清单。
- 2026-05-18：先运行 `swift test --package-path Packages/LangoTraceUI --filter ThreePlatformPresentationCopyTests`，测试按预期失败，失败项覆盖 `本机预览`、`当前边界`、`后续接入条件`、`不会发生`、`On-device preview` 等残留。
- 2026-05-18：清理 `Localizable.xcstrings` 中通用状态标题与本机预览 badge 文案，改为 `本地优先`、`本地草稿`、`当前状态`、`接下来`、`隐私说明` 等产品化表达。
- 2026-05-18：将 Data seed 和显式生成内容的 `providerLabel` 从 `On-device Preview` 改为 `LangoTrace Draft`，避免进入 UI 后呈现开发说明感。
- 2026-05-18：同步更新 Data 测试断言。
- 2026-05-18：针对性回归测试、UI package 测试、Data package 测试和 `scripts/verify.sh` 均已运行。
- 2026-05-18：额外扫描 `Localizable.xcstrings` 和 Data 可见内容，未发现本轮禁止的残留开发说明词。

## 验证记录

- `swift test --package-path Packages/LangoTraceUI --filter ThreePlatformPresentationCopyTests`：先失败后通过。失败时捕获 28 个问题，覆盖 `本机预览`、`当前边界`、`后续接入条件`、`不会发生` 和 `On-device preview`。
- `swift test --package-path Packages/LangoTraceUI`：通过，38 个 Swift Testing 测试。
- `swift test --package-path Packages/LangoTraceData`：通过，10 个 Swift Testing 测试。
- `scripts/verify.sh`：退出码 0；包含 XcodeGen、Core/Data/UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat lint、文档占位扫描和工作树状态输出。
- `scripts/verify.sh` 仍报告 3 个既有 SwiftLint warning：`PremiumUIBehaviorTests.swift` line length、`PremiumUIBehaviorTests.swift` type body length、`LearningContentComponents.swift` file length。
- `rg -n "On-device Preview|On-device preview|本机预览|Current Boundary|当前边界|Next Requirement|后续接入条件|Will Not Happen|What Will Not Happen|不会发生|Required Before Connecting" Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings Packages/LangoTraceData/Sources/LangoTraceData --glob '*.swift' --glob '*.xcstrings'`：无匹配。
- `git diff --check`：通过。

## 完成标准

- 三端可见页面不再出现本任务禁止的开发说明式标题。
- 回归测试覆盖残留词。
- `scripts/verify.sh` 通过或记录不能运行的具体原因。

## 剩余风险

- 本轮只处理可见文案和页面结构，不代表真实持久化、AI、TTS、同步、导入导出能力已完成。
