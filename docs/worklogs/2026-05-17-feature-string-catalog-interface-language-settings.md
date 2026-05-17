# 工作记录：String Catalog 与界面语言设置闭环

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/guidelines/006-interface-localization-and-language-boundaries.md`
- `docs/superpowers/specs/2026-05-17-string-catalog-interface-language-settings-design.md`
- `docs/superpowers/plans/2026-05-17-string-catalog-interface-language-settings.md`
- `docs/testing/README.md`

关联 ADR：

- 无

关联提交：

- 未提交

## 1. 背景

项目已经完成界面国际化基础规范和最小 `InterfaceLanguagePreference` 模型，设置能力列表也已经出现“界面语言”入口。但当前 SwiftUI 可见文案仍大量直接写在代码中，用户无法在 App 内主动选择界面语言，英文 fallback 也还没有通过 String Catalog 和三端截图验证形成可持续闭环。

本阶段承接“界面国际化与语言边界规范”，目标是把国际化从规范和模型推进到可运行的页面文案资源、设置入口和验证流程。

## 2. 目标

- 建立 `LangoTraceUI` 的 String Catalog 资源结构，支持英文和简体中文。
- 将首批 App chrome 文案迁移到可本地化资源，覆盖 Welcome、Onboarding、Settings、iPhone Tab、iPad workspace、macOS workspace 中的主要导航、按钮、空状态、状态说明和设置项。
- 实现 App 内界面语言偏好设置入口，支持跟随系统、English、简体中文。
- 将界面语言偏好持久化为设备级 App 设置，不写入语言空间、学习记录或同步数据。
- 明确系统级 per-app language、App 内偏好、权限弹窗和 StoreKit sheet 的边界。
- 建立英文和简体中文的三端截图验证清单，确保页面没有明显截断、重叠和导航失效。

## 3. 范围

本次计划处理：

- `LangoTraceUI` 本地化资源结构。
- SwiftUI 主要页面的首批用户可见 App chrome 文案。
- App shell 的界面语言偏好注入。
- 设置页中的界面语言选择呈现。
- Core / UI / Data 相关测试。
- 文档和测试清单更新。

## 4. 不做什么

- 不翻译用户输入内容、Mock 学习正文、AI 生成文本、目标语言句子或母语讲解。
- 不接入真实 AI Provider、TTS、OCR、Speech、SQLite、同步或 StoreKit。
- 不承诺英文和简体中文以外的正式界面语言。
- 不实现系统权限弹窗、StoreKit sheet 或第三方 SDK UI 的 App 内即时覆盖。
- 不把界面语言偏好写入语言空间模型、同步 manifest 或学习记录。
- 不把这次工作扩大为完整视觉重设计。

## 5. 分析

当前最主要的架构风险是把“内容语言”和“界面语言”混在一起。语迹的核心内容来自用户生活记录、目标语言学习材料和母语解释，这些内容不能因为界面切换成英文或中文而被自动翻译。

因此本阶段只迁移 App chrome 文案。Seed/mock 学习内容仍被视为内容样本，允许保留自身语言。对于当前位于 Data 层的设置能力说明，本阶段应优先梳理它们的 UI 呈现边界：长期方向是 Data 提供稳定 kind、状态和能力语义，UI 层负责本地化标题与说明。

另一个风险是 App 内语言 Picker 与 Apple 系统 per-app language 产生冲突。第一阶段推荐采用明确的优先级：用户选择 `System` 时跟随系统和 per-app language；用户选择 English 或 简体中文时，语迹自有 SwiftUI 文案通过 App 内 locale 覆盖；系统弹窗、权限弹窗、StoreKit sheet 和文件选择器仍可能遵循系统或 Apple 平台规则。

## 6. 方案

推荐方案：先做“App chrome String Catalog + App 内 locale 注入 + 设置入口”，不做内容重写。

实施顺序：

1. 建立 `LangoTraceUI` 的 `Localizable.xcstrings` 和资源打包配置。
2. 增加界面语言偏好持久化 store，默认 `system`。
3. 在 App shell 注入 resolved locale，供 SwiftUI 自有文案使用。
4. 将首批页面文案迁移到 String Catalog，优先覆盖导航、按钮、设置和状态说明。
5. 在设置详情页为 `interfaceLanguage` 提供可交互 Picker。
6. 增加单元测试，验证偏好持久化、resolved locale、设置入口和语言空间不变性。
7. 用英文和简体中文分别进行 iPhone、iPad、macOS 构建和截图烟测。

## 7. 风险与边界

- Swift Package 中的 String Catalog 需要配置 package resources，并验证 XcodeGen 生成工程后能正确打包。
- 因 String Catalog 位于 `LangoTraceUI` package，UI package 内的 `Text`、`Label`、`Button` label、`navigationTitle`、`accessibilityLabel` 等本地化查找必须显式使用 `Bundle.module` 或统一封装；不能依赖 main bundle 默认查找。
- App 内 locale 注入主要影响 SwiftUI 自有文案，不应被描述为覆盖全部系统 UI。
- `System` 选项应跟随系统语言或系统为语迹设置的 per-app language；用户显式选择 English / 简体中文时，只覆盖语迹自有 SwiftUI chrome，不修改系统 per-app language。
- 旧代码中部分字符串来自 Core / Data 模型，不能盲目改为展示文案，否则会污染数据层。
- `SettingsCapability.Kind.title` 和 `CapabilityStatus.title` 当前在 Data package 中，长期应由 UI 根据稳定 kind/status 映射本地化文案；Data 中的 seed/mock 学习内容仍按内容处理。
- 当前页面仍处于 mock 阶段，本地化迁移应避免为临时内容制造过度抽象。
- 若发现某些文案迁移会牵连大量模型重构，应先记录为后续任务，不阻断首批 chrome 闭环。

## 8. 测试与验证

实现阶段至少执行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
```

手动或截图验证至少覆盖：

- iPhone 17，English。
- iPhone 17，简体中文。
- iPad Pro 13-inch (M5)，English。
- iPad Pro 13-inch (M5)，简体中文。
- macOS arm64，English。
- macOS arm64，简体中文。

每个场景检查：

- Welcome 和 Onboarding 文案没有截断。
- iPhone Tab 标签可读，主要按钮触控区域未被压缩。
- iPad sidebar、workspace bar、右侧学习面板没有文本重叠。
- macOS sidebar、toolbar、inspector 没有明显溢出。
- 设置中的界面语言选择不会改变当前语言空间。

## 9. 文档影响检查

本阶段会影响：

- `docs/guidelines/006-interface-localization-and-language-boundaries.md`：如果实现策略与草案有偏差，需要更新。
- `docs/guidelines/003-ui-design-system.md`：如果形成新的长文案、截断或设置布局规则，需要更新。
- `docs/testing/README.md`：需要补充三端双语言截图验证结果。
- `docs/review/INDEX.md` 与 `docs/review/rounds/`：若更新验证脚本、启动结构或国际化边界，需要触发专项审查。

## 10. 用户确认记录

2026-05-17：用户要求“立即进行下一阶段，先创建对应的文档”，确认先创建草案文档，不进入代码实现。

2026-05-17：用户要求“根据文档，立即进行开发、落地”，确认按已复查的规格和实施计划进入实现。

## 11. 实施记录

已开始实现。前置草案和复查结果作为本阶段执行依据。

2026-05-17 架构与三端交互复查：

- 确认 `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings` 是当前阶段合适位置，因为主要 SwiftUI chrome 均在 `LangoTraceUI` package。
- 补充 package 资源查找约束：所有 UI package 本地化 key 必须通过 `Bundle.module` 或封装查找，便捷 API 需要改为 label builder 或 `Text(..., bundle: .module)`。
- 补充主 App bundle 边界：UI package catalog 不自动证明系统 per-app language 会展示简体中文；若产品承诺系统设置可选语言，需要在 App target 级声明 `en / zh-Hans` 并实际验证。
- 补充 SwiftUI locale 边界：依赖即时切换的文案应优先保持为 `Text` / label builder；`String(localized:bundle:)` 若不显式传入当前 resolved locale，可能不会跟随 App 内 locale 环境即时刷新。
- 明确 App 内语言设置与系统 per-app language 的关系：`System` 跟随平台语言偏好；显式 App 内选择只覆盖语迹自有 SwiftUI chrome；系统弹窗、StoreKit、文件选择器和第三方 UI 不纳入即时覆盖承诺。
- 补充 iPhone / iPad / macOS 交互边界：不进入首次启动必填路径；iPad 保持 workspace 上下文；macOS 先在 settings workspace 闭环，后续再评估 `Settings` scene 和 `Cmd+,`。
- 补充 Data/UI 边界：Data 保留稳定 kind/status 和 mock 内容，UI 负责本地化 settings capability 标题、状态和 App chrome 说明。

2026-05-17 实现进展：

- 新增 `UserDefaultsInterfaceLanguageStore`，以设备级 `UserDefaults` 保存 `interfaceLanguagePreference`，无效值恢复为 `system`，并支持 reset。
- 新增 `LangoTraceUI` package resources 和 `Resources/Localizable.xcstrings`，英文为 source language，简体中文为首批 translated language。
- 新增 `LocalizedChrome.swift`，集中维护 UI package 的本地化 key 映射，包括 `PhoneRootTab`、`SettingsCapability.Kind`、`CapabilityStatus` 和界面语言 Picker 选项。
- 在 `LangoTraceApp` 中读取界面语言偏好，解析 `Locale.preferredLanguages` 后通过 `.environment(\.locale, ...)` 注入根视图。
- 将界面语言偏好和更新回调传入 `LangoTraceRootView`、iPhone、iPad 和 macOS 主界面。
- `SettingsCapabilityDetailView` 在 `interfaceLanguage` 设置项中显示 `System / English / 简体中文` Picker 和三条边界说明。
- 首批迁移 Welcome、Onboarding、iPhone Tab、Entry editor、Request preview、settings capability 标题和 capability status 等 App chrome 文案。
- 明确保留用户内容、seed/mock 学习正文、目标语言句子、translation、note 和 Provider 输出为内容，不随界面语言重写。
- 在 `project.yml`、`Info-iOS.plist` 和 `Info-macOS.plist` 中声明 `CFBundleLocalizations = [en, zh-Hans]`，补齐主 App bundle 对系统 per-app language 可见语言的基础声明。
- 移除 `Packages/LangoTraceUI`、`LangoTraceApp`、Core 和 Data 中的 `String(localized:)` 路径，避免依赖 SwiftUI `locale` 环境即时切换的文案在创建时被固定为旧语言。
- macOS Settings 视觉复查发现 settings capability row 的 accessibility label 会暴露本地化 key；已将 `CapabilityStatusRow` 的 accessibility label 改为由本地化 `Text` 组合标题和状态。

## 12. 验证结果

已执行：

```bash
swift test --package-path Packages/LangoTraceCore --filter InterfaceLanguagePreferenceStoreTests
swift test --package-path Packages/LangoTraceUI --filter 'PageClosureStateTests/settingsCapabilityChromeUsesUILocalizationKeys'
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
rg -n "String\\(localized:" Packages/LangoTraceUI/Sources/LangoTraceUI LangoTraceApp Packages/LangoTraceCore Packages/LangoTraceData
plutil -p LangoTraceApp/Supporting/Info-iOS.plist
plutil -p LangoTraceApp/Supporting/Info-macOS.plist
scripts/verify.sh
swift test --package-path Packages/LangoTraceUI
swiftformat --lint Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift --cache ignore
```

当前结果：

- Core store 专项测试通过，4 tests passed。
- UI 本地化 key 专项测试通过。
- Core package 全量测试通过，24 tests passed。
- Data package 全量测试通过，9 tests passed。
- UI package 全量测试通过，9 tests passed。
- iPhone 17 simulator build succeeded，且 Xcode 构建日志显示 `xcstringstool compile` 已处理 `Localizable.xcstrings`，并生成 `LangoTraceUI_LangoTraceUI.bundle`。
- `String(localized:)` 扫描无命中。
- iOS 和 macOS InfoPlist 均包含 `CFBundleLocalizations`，值为 `en` 和 `zh-Hans`。
- `scripts/verify.sh` 通过，覆盖 XcodeGen、Core/Data/UI tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位扫描。
- iPhone 17 English / 简体中文 Onboarding 截图已保存：
  - `/private/tmp/langotrace-ui-review/iphone17-en.png`
  - `/private/tmp/langotrace-ui-review/iphone17-zh-Hans.png`
- iPad Pro 13-inch (M5) English / 简体中文 Onboarding 截图已保存：
  - `/private/tmp/langotrace-ui-review/ipad-pro-13-m5-en.png`
  - `/private/tmp/langotrace-ui-review/ipad-pro-13-m5-zh-Hans.png`
- macOS English / 简体中文通过 Computer Use 读取窗口和 accessibility tree 验证，覆盖 Welcome / Onboarding、主窗口和 Settings 页面。
- `screencapture -x /private/tmp/langotrace-ui-review/macos-en.png` 在当前环境返回 `could not create image from display`，因此 macOS 未生成独立文件截图。

剩余风险：

- iPhone / iPad Settings 页未保留独立截图，因为 Simulator tab bar 子元素在 Computer Use accessibility tree 中没有稳定暴露；Settings 路由、Picker key 和 capability key 由 `LangoTraceUITests` 覆盖。
- 仍有部分 mock 内容和辅助说明保持中文，这是本阶段明确保留的内容语言或后续迁移项，不代表完整 App 全文案本地化已经完成。
