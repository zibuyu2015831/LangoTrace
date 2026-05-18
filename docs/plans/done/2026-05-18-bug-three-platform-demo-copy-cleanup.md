# 三端展示界面开发态文案清理方案

状态：Verified

类型：bug

创建日期：2026-05-18

最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户要求全面检查 Mac、iPad、iOS 三端，去除所有类似 `mock`、`SQLite 未接入` 的展示信息，让界面达到真实级评估效果。
- 2026-05-18：用户确认边界文案策略为“保留但产品化”：主展示界面彻底去开发痕迹；设置、搜索、导入导出、请求预览等边界页保留真实能力说明，但删除 mock、SQLite、未接入等工程词。

## 需求或 Bug 描述

前一轮已移除 iPhone 主界面的本地 mock / SQLite 状态行和最近记录区 mock 说明，但其他页面、iPad 和 macOS 仍有可见开发态文案。此类文案会让 UI 评估停留在工程样机感，而不是产品真实界面。

## 复现方式

1. 启动 iPhone / iPad / macOS App。
2. 进入记录、练习、记忆、设置、搜索、导入导出、详情、Inspector 等页面。
3. 查看页面标题、subtitle、状态行、空状态、卡片说明和 request preview。
4. 可见 `mock`、`Local Mock`、`SQLite`、`尚未接入`、`未接入能力`、`真实数据库`、`验证页面闭环` 等开发态表达。

## 预期行为

- 三端主展示路径不出现开发态文案。
- 能力边界页仍诚实表达当前能力边界，但使用产品级用户语言。
- 源码内部仍可保留 mock / in-memory 模型命名，不影响架构边界。

## 实际行为

- String Catalog 和部分 SwiftUI 视图仍直接把开发阶段词汇展示给用户。
- iPad 学习面板、macOS Sidebar / Inspector / Workspace、设置和 unavailable 页面仍有工程实现说明。

## 根因分析

置信度：90%

根因是早期页面闭环阶段为防止误导用户，在 UI 可见层直接使用了工程边界词；后续产品级 UI 收敛时只清理了 iPhone 首页，没有把三端展示路径和 String Catalog 做成统一回归约束。

置信度依据：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings` 仍包含多处 `mock`、`Local Mock`、`SQLite`、`尚未接入` 等用户可见值。
- `PadMainSections.swift`、`MacWorkspaceContentView.swift`、`LearningContentComponents.swift` 等视图仍引用会显示开发态状态的 key 或数据字段。
- `LangoTraceData` 生成的练习摘要、记忆 note 和 rendering note 会进入 UI。

备选原因：

- 某些边界文案属于隐私透明要求，不能完全删除；本任务采用产品化改写而非隐藏。
- 某些 `mock` 字符串只存在测试、内部模型或文档中，不属于可见 UI，不纳入清理。

## 目标、范围和不做什么

目标：

- 清理 iPhone、iPad、macOS 可见展示界面中的开发态文案。
- 用回归测试防止 String Catalog 和主要 UI 源文件再次暴露工程词。
- 保持真实能力边界诚实，但文案产品化。

范围：

- `Packages/LangoTraceUI/Sources/LangoTraceUI`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests`
- `Packages/LangoTraceData/Sources/LangoTraceData` 中会进入 UI 的 seed / preview 内容。
- 本任务方案文档。

不做：

- 不接入真实 SQLite / GRDB。
- 不接入真实 AI Provider、TTS、录音、OCR、同步或 StoreKit。
- 不删除内部 `mockOnly`、`isMock`、`InMemory` 等架构状态。
- 不把未完成能力伪装成已完成。

## 证据与决策依据

- `docs/spec/003-ui-design-system.md` 要求本地优先和隐私边界可理解，但不打扰主流程。
- `docs/spec/002-navigation-and-routing.md` 要求未完成入口有可见结果，不能留空 action。
- 用户明确要求“所有展示界面真实级”，并确认边界页采用产品化说明。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSummaryView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SeedLearningContent.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/UnavailableCapabilityView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PremiumUILayoutRules.swift`

## 涉及的文档路径

- `docs/plans/active/2026-05-18-bug-three-platform-demo-copy-cleanup.md`
- `docs/plans/done/2026-05-18-bug-three-platform-demo-copy-cleanup.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/002-navigation-and-routing.md`

## 实施方案

1. 新增回归测试，扫描三端展示 key 和关键源文件，禁止可见 UI 出现开发态词。
2. 先运行测试并确认失败。
3. 清理 String Catalog 中 phone / pad / mac / settings / unavailable / requestPreview / entry / practice / memory 等展示 key 的开发态值。
4. 清理 UI 视图中直接展示 mock / unavailable 状态的主路径；必要时保留内部状态但改写显示标题和摘要。
5. 清理 Data seed 中会进入 UI 的练习摘要、记忆 note、rendering note 和 provider label。
6. 运行 package test、全量 verify、文档检查和模拟器/桌面截图验证。
7. 将方案文档移入 done，并写入验证记录。

## 回归测试方案

- 新增 `ThreePlatformPresentationCopyTests`：
  - 扫描主展示 SwiftUI 文件，不允许硬编码开发态展示词。
  - 解析 String Catalog，检查展示前缀 key 的所有 localizations value。
  - 对边界页 key 也禁止工程词，但允许用户级边界表达。

## 复查方法

- 代码扫描：`rg -n "mock|Local Mock|SQLite|GRDB|尚未接入|未接入|真实数据库|验证.*页面闭环" Packages/LangoTraceUI/Sources Packages/LangoTraceData/Sources`
- 手动审查：三端主要页面和边界页截图确认没有工程态视觉噪音。
- 测试审查：确保测试覆盖 phone / pad / mac / settings / unavailable / requestPreview / entry / practice / memory 前缀。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git status --short
```

## 文档影响检查

本任务改变的是 UI 可见文案，不改变核心产品定位、架构决策、数据路线、Provider 边界或同步策略。无需新增 ADR。完成后任务方案归档即可。

## 实施记录

- 2026-05-18：创建方案并进入实现。
- 2026-05-18：新增 `ThreePlatformPresentationCopyTests`，覆盖 String Catalog 展示 key、三端主展示 SwiftUI 文件和 Data seed 会进入 UI 的展示内容。
- 2026-05-18：先运行新增测试确认失败，失败项覆盖 149 处展示文案问题。
- 2026-05-18：清理 `Localizable.xcstrings` 中 phone / pad / mac / settings / unavailable / requestPreview / entry / practice / memory 等展示值，改为本机预览、待配置、请求确认、不会发送等产品级表达。
- 2026-05-18：清理 `LangoTraceData` seed / generated content 中会进入 UI 的 Local Mock、mock rendering、AI Provider 等开发态文本，并更新相关数据测试断言。
- 2026-05-18：补充 `LangoTraceUI` 测试 target 对 `LangoTraceData` 的依赖，用于直接验证 seed 内容不会把工程词带入 UI。
- 2026-05-18：重启 iPhone 17 和 iPad Pro 13-inch (M5) 模拟器，重新安装当前构建并完成主界面验证；重启 macOS App 完成主界面验证。

## 验证记录

- `swift test --package-path Packages/LangoTraceUI --filter ThreePlatformPresentationCopyTests`：通过，3 个测试。
- `swift test --package-path Packages/LangoTraceData`：通过，10 个测试。
- `swift test --package-path Packages/LangoTraceUI`：通过，38 个测试。
- `scripts/verify.sh`：通过；包含 XcodeGen、Core/Data/UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS build、SwiftLint、SwiftFormat 和文档占位扫描。
- SwiftLint 仍报告 3 个既有 warning：`PremiumUIBehaviorTests.swift` line length、`PremiumUIBehaviorTests.swift` type body length、`LearningContentComponents.swift` file length；本任务未扩大该问题。
- 额外扫描 `Localizable.xcstrings` 可见 value 和主要 SwiftUI/Data 展示源文件，未发现本任务禁止的开发态展示词。
- iPhone 截图：
  - `/private/tmp/langotrace-ui-review/iphone17-real-copy-main-final.png`
  - `/private/tmp/langotrace-ui-review/iphone17-real-copy-settings-final.png`
- iPad 截图：
  - `/private/tmp/langotrace-ui-review/ipad-real-copy-main.png`
- macOS 截图：
  - `/private/tmp/langotrace-ui-review/macos-real-copy-main.png`

## 完成标准

- 三端主要展示路径不出现开发态文案。
- 设置、搜索、导入导出、请求预览等边界页保留产品级说明，不暴露工程词。
- 新增回归测试先红后绿。
- `scripts/verify.sh` 通过；如有既有 warning，记录来源。
- 模拟器和 macOS 主要界面完成截图验证。

## 剩余风险

- 未接入真实能力仍只能以产品级边界说明呈现，不能替代真实功能。
- 未来新增 String Catalog key 时仍需遵守回归测试词表；少数新功能可能需要扩展允许词或改写策略。
- 本次没有接入真实 SQLite / AI / 同步；“真实级”仅指展示界面去除工程样机感，并继续诚实表达能力边界。
