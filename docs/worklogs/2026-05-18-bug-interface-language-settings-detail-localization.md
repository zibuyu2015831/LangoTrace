# 工作记录：界面语言设置详情本地化与 iPhone 标题重叠修复

类型：bug

状态：Verified

日期：2026-05-18

关联文档：

- `docs/README.md`
- `docs/guidelines/006-interface-localization-and-language-boundaries.md`
- `docs/testing/README.md`
- `docs/superpowers/plans/2026-05-17-string-catalog-interface-language-settings.md`

关联 ADR：

- 无

关联提交：

- `45f9cf6 fix: localize settings capability chrome`

## 1. 背景

用户在 iPad Pro 13-inch (M5) 和 iPhone 17 Simulator 中验证界面语言设置后发现：

- 将界面语言切换为 English 后，设置详情页仍有部分 App chrome 文案显示中文。
- iPhone 设置详情页出现大标题与内容标题重叠。

## 2. 目标

- 修复设置详情页中属于 App chrome 的设置能力摘要、边界、后续条件和副作用说明未随界面语言切换的问题。
- 修复 iPhone 设置详情页标题重叠问题。
- 保持“用户内容 / Mock 学习内容不因界面语言切换而重写”的既有国际化边界。
- 补充单元测试锁定本地化 key 映射，完成 Swift package 和工程验证。

## 3. 范围

- `SettingsCapabilityDetailView` 的设置详情文本渲染。
- iPhone / iPad / macOS 设置列表中 `SettingsCapability` 行摘要的渲染。
- `CapabilityStatusRow` 的本地化摘要渲染能力。
- `Localizable.xcstrings` 中设置详情相关英文和简体中文资源。
- UI package 中与设置详情本地化 key 相关的测试。
- 测试文档与本工作记录。

## 4. 不做什么

- 不把用户记录、目标语言学习内容、Provider 输出或 mock seed 内容自动翻译成界面语言。
- 不接入真实语言空间持久化、数据库、AI Provider、同步或 StoreKit。
- 不重新设计完整视觉系统。
- 不扩大到所有尚未迁移的 App chrome 文案；本次只修复设置能力列表和详情中由 `SettingsCapability` 驱动的混合语言问题。

## 5. 分析

复现步骤：

1. 在 iPad 或 iPhone 中进入主界面。
2. 打开设置中的 Interface Language。
3. 将界面语言切换为 English。

期望行为：

- 设置详情页标题、能力摘要、说明段落和面板标题均显示英文。
- 用户记录、目标语言内容和已有 mock 学习材料不被界面语言设置重写。
- iPhone 详情页标题不重叠。

实际行为：

- `SettingsCapabilityDetailView` 中 `navigationTitle` 和 `capability.kind.localizedTitleKey` 已走 String Catalog。
- `capability.summary`、`capability.detail`、`capability.nextRequirement` 仍来自 Data 层中文字段。
- `TextPanel(title: "当前边界"...)` 等面板标题是 UI 层硬编码中文。
- iPhone 详情页默认导航标题显示模式未明确指定，在截图中出现 large title 与内容 header 重叠。

初步根因判断：

- 国际化实现把设置行标题和状态 badge 迁到了 UI 层资源，但没有为设置详情正文建立 UI 层本地化 key。
- Data 层 `SettingsCapability` 同时承载产品状态和中文展示文案，UI 层直接渲染造成界面语言切换不完整。
- `SettingsCapabilityDetailView` 作为二级页应使用 inline title，但当前依赖系统默认。

## 6. 方案

1. 在 UI 层新增设置能力详情本地化 key 映射，覆盖 summary、detail、nextRequirement。
2. 为 `CapabilityStatusRow` 增加 localized summary 支持，避免设置列表和详情继续显示 Data 层中文摘要。
3. 增加本地化 TextPanel 变体，用 String Catalog 渲染固定 UI 面板标题和正文。
4. 将 `SettingsCapabilityDetailView` 的导航标题显示模式固定为 `.inline`。
5. 补充 UI 测试，确认每个 `SettingsCapability.Kind` 都有稳定的 summary/detail/nextRequirement key。
6. 更新测试文档，记录本轮修复和验证结果。

## 7. 风险与边界

- 风险：Data 层测试仍断言中文字段，容易让后续开发误以为这些字段会参与界面语言切换。
  - 处理：本次保留 Data 层字段作为 mock 状态描述，同时 UI 层明确使用本地化 key；后续更大范围国际化时再评估 Data 模型拆分。
- 风险：用户可能把 mock 学习内容的中文误认为界面未切换。
  - 处理：遵守现有规范，用户内容和 Provider 输出不随界面语言变化；文档和最终说明中明确边界。
- 风险：只修复设置详情，其他页面仍可能存在未迁移 App chrome。
  - 处理：本次聚焦截图暴露缺陷；后续继续按国际化规范扩大 String Catalog 覆盖。

## 8. 测试与验证

- `swift test --package-path Packages/LangoTraceUI`
- `scripts/verify.sh`
- 必要时使用 iPhone 17 / iPad Pro 13-inch (M5) Simulator 复查设置详情页 English 状态截图。

## 9. 文档影响检查

- 更新本工作记录。
- 更新 `docs/testing/README.md` 的界面语言验证记录。
- 本次不改变核心产品决策和 ADR。
- 本次命中文档影响检查，但不需要新增专项审查轮次；原因是修复范围限于既有国际化方案的缺陷闭环，不改变 String Catalog 放置、App 内语言设置与系统 per-app language 的关系。

## 10. 用户确认记录

2026-05-18：用户提供 iPad / iPhone 截图并要求修复界面语言切换不完整与 iPhone 文字重叠问题；按既有已确认的国际化落地方案执行缺陷修复。

## 11. 实施记录

- 新增 `SettingsCapabilityDetailLocalizationKeys` 和 `settingsCapabilityDetailLocalizationKeys(for:)`，统一设置能力 `summary/detail/nextRequirement` 的 UI 本地化 key。
- 新增 `LocalizedTextPanel`，用于固定 UI 面板标题和正文的 String Catalog 渲染。
- `SettingsCapabilityDetailView` 不再直接渲染 `capability.summary/detail/nextRequirement`，改为渲染 UI 层本地化资源；iOS 上通过 `langoInlineNavigationTitle()` 固定二级页 inline title，避免 iPhone large title 与内容 header 重叠。
- iPhone、iPad、macOS 设置列表中的 `SettingsCapability` 行摘要也改用本地化 summary key。
- `CapabilityStatusRow` 增加 `localizedSummaryKey` initializer，并让可访问性 hint 同步使用本地化 `Text`。
- `Localizable.xcstrings` 增加 7 个设置能力的 summary/detail/nextRequirement，以及设置详情面板标题和“不会发生”正文的英文 / 简体中文资源。
- `PageClosureStateTests` 增加设置能力详情 key 稳定性测试。

## 12. 验证结果

- `swift test --package-path Packages/LangoTraceUI`：通过，10 个 UI package 测试全部通过。
- `ruby -rjson -e 'JSON.parse(File.read(ARGV[0])); puts "valid json"' Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`：通过。
- `swiftlint --no-cache`：通过，0 violations，0 serious；本轮修复中出现的 identifier length 和 file length warning 已清零。
- `swiftformat --lint . --cache ignore`：通过，0/66 files require formatting。
- `scripts/verify.sh`：通过，覆盖 XcodeGen、Core/Data/UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位词扫描。
- iPhone 17 / iPad Pro 13-inch (M5) Simulator：已安装并启动修复后构建。由于当前 App 尚无语言空间持久化，重启后回到 onboarding；Computer Use accessibility tree 对 iPhone tab bar 子项仍未稳定暴露，未能自动导航到 Settings detail 重新截图。修复结论以代码级根因检查、String Catalog 编译、UI key 单元测试和完整构建验证为准。
