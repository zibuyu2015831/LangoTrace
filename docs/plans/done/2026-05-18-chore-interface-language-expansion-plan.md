# 工作记录：界面语言扩展方案与首批实现

类型：chore

状态：Implemented

日期：2026-05-18

关联文档：

- `docs/README.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/interface-localization/2026-05-18-interface-language-expansion-design.md`

关联 ADR：

- 无

关联提交：

- 未提交

## 1. 背景

当前 LangoTrace 界面国际化只支持英文和简体中文。用户提出，鉴于产品愿景是适配任意语言学习，界面语言应覆盖日语、法语、德语、韩语、俄语等主流语种，并把西班牙语也纳入语言清单；小语种可以暂不考虑。

## 2. 目标

- 创建主流界面语言扩展方案草案并按审核结论完成首批代码落地。
- 明确扩展语言清单、必要性、可行性、分阶段落地方式和质量门槛。
- 同步更新既有国际化规范，避免方案文档和开发规范冲突。
- 明确该方案只讨论 App 界面语言，不承诺目标学习语言、TTS、OCR、Speech 或 AI Provider 能力已完整支持。
- 将 App 自有 SwiftUI chrome 的第一批候选界面语言扩展为 `en / zh-Hans / es / ja / fr / de / ko / ru`。

## 3. 范围

- 新增界面语言扩展规格草案。
- 更新 `docs/spec/006-interface-localization-and-language-boundaries.md` 的第一批语言范围和设置入口建议。
- 扩展 Core 模型、String Catalog、App target 本地化声明和自动化测试。
- 更新测试文档中的主流界面语言验证矩阵。

## 4. 不做什么

- 不在本次调整 App Store 元数据、权限 purpose strings 或发布材料。
- 不承诺小语种界面支持。
- 不把界面语言扩展等同于完整学习能力扩展。
- 不宣称新增语言已经达到发布级人工审校质量；发布前仍需人工审校和截图 QA。

## 5. 分析

从产品定位看，LangoTrace 面向所有语种学习者，不局限于中文用户或英语学习。界面只支持英文和简体中文，会让产品的全球化表达弱于“适配任意语言学习”的愿景。

从工程现状看，项目已经具备最小国际化基础：`InterfaceLanguagePreference`、`Localizable.xcstrings`、UI 层本地化封装、String Catalog 验证清单和界面语言边界规范。扩展主流界面语言技术上可行，但会显著增加翻译、布局、截图、辅助功能和发布材料维护成本。

关键边界是继续区分三条轴线：

- 界面语言：App chrome。
- 用户母语：解释、讲解和 AI 辅助理解默认语言。
- 目标学习语言：语言空间中的学习对象。

如果混淆这三者，界面语言扩展会错误扩大为“所有学习能力已支持所有语言”，造成产品承诺风险。

## 6. 方案

采用分阶段扩展方案：

1. 先把 `en / zh-Hans / es / ja / fr / de / ko / ru` 定义为第一批正式候选界面语言。
2. 保持英文为 source language 和 fallback。
3. 先完成模型、资源结构、设置入口和测试矩阵扩展，再开放正式用户可选项。
4. 翻译质量达到人工审校标准前，不在发布材料中宣称该语言正式支持。
5. 小语种暂不进入第一批，仅保留架构扩展能力。

替代方案：

- 一次性加入大量语言：覆盖面大，但会严重拉高 QA 和翻译一致性成本，不适合当前早期阶段。
- 继续只支持英文和中文：工程成本低，但不符合长期愿景，也会削弱全球化产品定位。
- 只加入用户列出的五种，不加入西班牙语：范围更小，但西班牙语属于主流国际市场语言，长期排除不合理。

推荐采用第一种分阶段主流语言方案。

## 7. 风险与边界

- 翻译质量风险：机器翻译不能作为正式发布质量；需要人工审校或至少人工抽检。
- 布局风险：德语、俄语可能显著拉长文案；日语、韩语需要关注字体、行高和断行。
- 平台边界风险：App 内语言设置不覆盖系统弹窗、StoreKit、文件选择器和第三方 UI。
- 发布风险：App Store 元数据、权限说明、隐私文案和截图未同步前，不能对外宣称完整支持对应语言。
- 测试矩阵风险：语言数量增加后，不能要求每次改动都跑完整 8 语言截图；需要定义核心 smoke 语言和发布前完整矩阵。

## 8. 测试与验证

实现阶段完成前运行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

专项覆盖检查：

```bash
ruby -rjson -e '<检查 Localizable.xcstrings 的 en / zh-Hans / es / ja / fr / de / ko / ru 覆盖>'
xcodegen generate
```

## 9. 文档影响检查

- 影响 `docs/spec/006-interface-localization-and-language-boundaries.md`：需要把第一批语言范围从英文和简体中文扩展为主流语言候选清单。
- 影响 `docs/testing/README.md`：本次补充主流界面语言扩展验证清单；截图 QA 仍按常规回归、字体断行 smoke 和发布前完整矩阵分层执行。
- 影响 release 文档：发布阶段需要同步 App Store 元数据、截图、权限文案和隐私文案。
- 本次不改变核心 ADR；仍遵守界面语言、用户母语和目标学习语言三轴分离。
- 本次扩展 Core 模型、UI package String Catalog 和 App target 本地化声明；未改变数据库、AI Provider、权限、同步、StoreKit 或核心 ADR，因此不触发专项架构审查轮次。

## 10. 用户确认记录

2026-05-18：用户要求立即创建方案文档，并确认把西班牙语也纳入语言清单。

2026-05-18：用户确认方案文档已通过审核，要求立即开始实施直到完整落地。

2026-05-18：用户在模拟器复测时反馈语言设置页面仍只看到 `System / English / 简体中文`，要求全面检查并重启模拟器确认实现完整。

2026-05-18：用户在西班牙语界面复测时发现 Picker 中只有中文显示为 `简体中文`，其余新增语言仍显示英文名，要求统一选项命名体验。

## 11. 实施记录

- 创建 `docs/spec/interface-localization/2026-05-18-interface-language-expansion-design.md`。
- 更新 `docs/spec/006-interface-localization-and-language-boundaries.md` 中第一批语言范围和设置入口建议。
- 架构与三端交互复查后，补充 String Catalog 放置边界、App 内显式语言设置与系统 per-app language 的关系、`System` 模式的 bundle localization 解析原则、iPhone / iPadOS / macOS 设置入口交互边界和 App target 本地化声明要求。
- 对照 Apple Developer Localization、package localization 和 App Store localization 文档，确认 App 内 SwiftUI chrome、本地化 bundle、系统 per-app language 和 App Store metadata 是不同层级。
- 采用 TDD 扩展 `InterfaceLanguagePreference`：新增 `es / ja / fr / de / ko / ru` 存储值、集中支持语言清单、系统语言 BCP 47 前缀解析和 `zh-Hant` 英文 fallback 边界。
- 将 App `System` 模式的解析输入从 `Locale.preferredLanguages` 调整为 `Bundle.main.preferredLocalizations`，使其优先遵循当前 App bundle localization / per-app language 结果。
- 扩展设置详情语言 Picker，保持同一入口但通过 `InterfaceLanguagePreference.allCases` 呈现 9 个选项：`System` 加 8 个候选界面语言。
- 为 `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings` 补齐 8 种语言覆盖，并新增 `Spanish / Japanese / French / German / Korean / Russian` 设置选项 key。
- 更新 `project.yml` 中 iOS 和 macOS target 的 `CFBundleLocalizations`，确保 XcodeGen 重新生成后 App target 仍声明 `en / zh-Hans / es / ja / fr / de / ko / ru`。
- 更新 `docs/testing/README.md`，补充主流界面语言扩展自动化检查和手动验证矩阵。

## 12. 验证结果

- TDD 红灯：`swift test --package-path Packages/LangoTraceCore --filter InterfaceLanguagePreferenceTests` 先因 `.spanish / .japanese / .french / .german / .korean / .russian` 和 `supportedLanguageCodes` 缺失失败。
- TDD 红灯：`swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests` 先因 UI title key 对应 enum case 缺失失败。
- `ruby -rjson -e '<检查 Localizable.xcstrings 8 语言覆盖>'`：通过，`source=en`、`keys=79`、`missing=0`。
- `swift test --package-path Packages/LangoTraceCore --filter InterfaceLanguagePreference`：通过，Swift Testing 9 tests passed。
- `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests`：通过，Swift Testing 8 tests passed。
- `xcodegen generate`：通过，iOS 和 macOS Info plist 均生成 `CFBundleLocalizations = en, zh-Hans, es, ja, fr, de, ko, ru`。
- `scripts/verify.sh`：通过；覆盖 XcodeGen、`xcodebuild -list`、Core/Data/UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat lint 和文档占位扫描。
- `swiftlint --no-cache`：通过，0 violations。
- `swiftformat --lint . --cache ignore`：通过，0/66 files require formatting。
- 语义自检：方案文档和规范均明确 `es / ja / fr / de / ko / ru` 是第一批主流界面语言候选，不代表这些语言的学习能力、TTS、OCR、Speech、AI Provider 输出、App Store 元数据或发布材料已经完成；新增翻译发布前仍需人工审校。
- 2026-05-18 模拟器复查：重新构建 `LangoTrace-iOS`，重启 iPhone 17 模拟器，卸载旧 `com.zibuyu.LangoTrace`，安装 DerivedData 中最新 `LangoTrace.app` 并启动。安装后 App bundle 的 `Info.plist` 含 `CFBundleLocalizations = en, zh-Hans, es, ja, fr, de, ko, ru`，`LangoTraceUI_LangoTraceUI.bundle/en.lproj/Localizable.strings` 含 `settings.interfaceLanguage.spanish / japanese / french / german / korean / russian` 对应文案，App 二进制字符串也含 `Spanish / Japanese / Russian`。因此本次复查确认模拟器运行包已经是 8 语言构建；此前只显示 3 项的最可能原因是模拟器中仍安装旧构建。
- 2026-05-18 选项命名修正：新增 `PageClosureStateTests.interfaceLanguageOptionResourcesUseNativeLanguageNames`，先复现 String Catalog 中新增语言选项在非中文界面下仍显示英文名的问题；随后将 `English / 简体中文 / Español / 日本語 / Français / Deutsch / 한국어 / Русский` 作为所有界面 locale 下的固定自名显示，`System` 选项继续按当前界面语言本地化。
