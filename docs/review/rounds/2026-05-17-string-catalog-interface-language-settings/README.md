# 文档审查：String Catalog 与界面语言设置闭环

日期：2026-05-17

状态：Verified

关联工作记录：

- `docs/worklogs/2026-05-17-feature-string-catalog-interface-language-settings.md`

关联规格和计划：

- `docs/superpowers/specs/2026-05-17-string-catalog-interface-language-settings-design.md`
- `docs/superpowers/plans/2026-05-17-string-catalog-interface-language-settings.md`

## 审查范围

本轮审查覆盖 String Catalog 资源位置、App 内界面语言设置、系统 per-app language 边界、SwiftUI locale 注入、Data/UI 文案边界和三端验证清单。

涉及代码与配置：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Package.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreferenceStore.swift`
- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`

## 当前结论

- `Localizable.xcstrings` 位于 `LangoTraceUI` package 内，符合当前 UI chrome 所在模块边界。
- `LangoTraceUI` target 已配置 package resources，SwiftPM 和 Xcode app build 能编译资源 bundle。
- App shell 读取设备级 `UserDefaults` 偏好，解析 `system / en / zh-Hans` 后通过 SwiftUI `locale` 环境注入根视图。
- 设置详情页提供 `System / English / 简体中文` Picker，并明确系统 UI 与内容语言不在覆盖范围内。
- Data 层仍保留 mock 说明内容；UI 已为 settings capability kind 和 status 建立本地化 key 映射，避免长期依赖 Data 展示标题。

## 架构与交互复查补充

- String Catalog 放在 `LangoTraceUI` package 是合理的第一阶段选择，因为当前三端 SwiftUI chrome 的所有权在 UI package；但它不自动完成主 App bundle 的系统级本地化声明。
- 如果产品承诺系统 per-app language 可选择简体中文，必须补充 App target 级本地化声明，例如 `CFBundleLocalizations`、App target 资源或等效配置，并在 iOS / iPadOS / macOS 系统设置中验证。
- App 内显式语言选择只应覆盖语迹自有 SwiftUI chrome，不修改系统 per-app language，也不承诺覆盖权限弹窗、StoreKit、文件选择器、分享面板、系统键盘、第三方 SDK UI 或 Apple 服务 UI。
- `System` 模式的准确语义是跟随平台传给 App 的语言偏好列表；是否能在系统设置中单独选择某个语言，取决于 App bundle 是否声明对应本地化。
- `.environment(\.locale, ...)` 对 `Text(LocalizedStringKey, bundle: .module)` 这类 SwiftUI View 路径是合适的；`String(localized:bundle:)` 是立即求值路径，若不显式传入当前 resolved locale，可能无法随 App 内设置即时刷新。
- iPhone 交互上不应把界面语言并入首次启动必填问题；iPad 应保持 workspace 和侧栏上下文；macOS 当前可先在 settings workspace 闭环，但进入正式 Mac 体验时还需评估 `Settings` scene 和 `Cmd+,`。

## 需要修订或验证的边界

- 当前 App target 的 `knownRegions` 仍显示 `Base, en`，因此不能把 Xcode project regions 当作系统 per-app language 覆盖证据。已改为在 `project.yml` 和两个 App target InfoPlist 中声明 `CFBundleLocalizations = [en, zh-Hans]`。
- 当前代码已移除 `Packages/LangoTraceUI`、`LangoTraceApp`、Core 和 Data 中的 `String(localized:)` 路径。
- macOS Settings 复查发现 settings capability row 的 accessibility label 会暴露 `settings.interfaceLanguage.title` 这类 key；已改为使用本地化 `Text` 组合标题和状态。
- 剩余中文 accessibility hint / mock chrome 字符串需要继续按“必须随界面语言切换的 chrome”和“可保留为内容样本的 mock”分类迁移。

## 已验证

- `swift test --package-path Packages/LangoTraceCore`
- `swift test --package-path Packages/LangoTraceData`
- `swift test --package-path Packages/LangoTraceUI`
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
- `rg -n "String\\(localized:" Packages/LangoTraceUI/Sources/LangoTraceUI LangoTraceApp Packages/LangoTraceCore Packages/LangoTraceData`
- `plutil -p LangoTraceApp/Supporting/Info-iOS.plist`
- `plutil -p LangoTraceApp/Supporting/Info-macOS.plist`
- `scripts/verify.sh`
- `swift test --package-path Packages/LangoTraceUI`
- `swiftformat --lint Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift --cache ignore`
- iPhone 17 English / 简体中文截图：`/private/tmp/langotrace-ui-review/iphone17-en.png`、`/private/tmp/langotrace-ui-review/iphone17-zh-Hans.png`
- iPad Pro 13-inch (M5) English / 简体中文截图：`/private/tmp/langotrace-ui-review/ipad-pro-13-m5-en.png`、`/private/tmp/langotrace-ui-review/ipad-pro-13-m5-zh-Hans.png`
- macOS English / 简体中文窗口：通过 Computer Use accessibility tree 读取 Welcome / Onboarding、主窗口和 Settings；`screencapture -x /private/tmp/langotrace-ui-review/macos-en.png` 在当前环境返回 `could not create image from display`。

## 剩余风险

- iPhone / iPad Settings 页未保留独立截图，因为 Simulator tab bar 子元素在 Computer Use accessibility tree 中没有稳定暴露；相关可达性由 UI route 测试和 settings localization key 测试覆盖。
- macOS 没有文件截图，改用 Computer Use 的窗口截图和 accessibility tree 作为可复查视觉记录。
- 仍有部分 mock 内容和辅助说明保持中文，这是本阶段明确保留的内容语言或后续迁移项，不属于 App chrome 完整本地化完成声明。
