# iPad 与 Mac 界面语言设置边界补齐方案

状态：Verified

类型：bugfix

创建日期：2026-05-22

最后更新日期：2026-05-22

## 背景

iPhone 端「界面语言」详情页已经重构为选择优先的轻量页面，并通过测试和模拟器验证。后续检查发现 iPad 与 Mac 端虽然复用 `SettingsCapabilityDetailView`，但平台外层仍存在两个边界风险：

- macOS 独立 Settings scene 只有在存在 `languageSpace` 时才展示选中的 capability 详情；这对 `interfaceLanguage` 不正确，因为界面语言是 App 级偏好，不依赖语言空间。
- Mac workspace 的 inspector 在 `.settings(kind)` 路由中统一展示 `settingsCapabilityDetailLocalizationKeys(...).detail` 和 `nextRequirement`；这会让「界面语言」在 Mac 右侧栏继续出现旧的长说明。

## 决策

1. iPad workspace 继续复用 `SettingsCapabilityDetailView`，不新增平台专属界面语言页。
2. macOS Settings scene 对 `.interfaceLanguage` 使用不依赖语言空间的 placeholder language space，仅满足共享详情组件当前签名；该 placeholder 不得写入数据库，也不得作为语言空间上下文展示。
3. Mac inspector 对 `.interfaceLanguage` 只展示短脚注，不再展示 `detail` 和 `nextRequirement` 长说明。
4. 不修改 `InterfaceLanguagePreference`、语言空间模型、持久化和三端 locale 注入逻辑。

## 修改路径

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`
- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/InterfaceLanguageSettingsPageTests.swift`

## 验证

- `swift test --package-path Packages/LangoTraceUI --filter InterfaceLanguageSettingsPageTests`
- `swift test --package-path Packages/LangoTraceUI`
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`
- `scripts/verify.sh`

## 验证结果

- 2026-05-22：`swift test --package-path Packages/LangoTraceUI --filter InterfaceLanguageSettingsPageTests` 通过，6 个测试。
- 2026-05-22：`swift test --package-path Packages/LangoTraceUI` 通过，176 个测试。
- 2026-05-22：`xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build` 通过。
- 2026-05-22：`xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 通过。
- 2026-05-22：`scripts/verify.sh` 通过。SwiftLint 仍有既存 45 个 warning、0 serious；SwiftFormat lint 通过。
