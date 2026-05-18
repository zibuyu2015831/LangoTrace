# 工作记录：修复 iOS 首屏未占满屏幕

类型：bugfix

状态：Verified

日期：2026-05-17

关联文档：

- `docs/worklogs/2026-05-17-feature-product-shell-navigation.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`

关联提交：

- 待提交

## 1. 问题

iPhone 17 Simulator 中首次引导页没有占满全屏，页面显示为黑色系统背景中嵌入一块缩放后的浅色内容区域，看起来像出现了内部滚动容器。

## 2. 根因

iOS target 的 `Info-iOS.plist` 没有配置 Launch Screen。iOS 在缺少启动屏声明时会按旧式兼容尺寸显示 App，导致 SwiftUI 根视图被系统 letterbox，表现为黑底和内部缩放页面。

这不是 `OnboardingView` 的滚动容器本身导致的布局问题。

进一步确认：项目由 XcodeGen 管理 `Info-iOS.plist`。如果只直接编辑 plist 文件，`xcodegen generate` 会覆盖变更。因此 `UILaunchStoryboardName` 必须写入 `project.yml` 的 iOS target `info.properties`。

## 3. 修复

- 在 `project.yml` 的 iOS target 中增加 `UILaunchStoryboardName = LaunchScreen`，由 XcodeGen 写入 `Info-iOS.plist`。
- 新增 `LangoTraceApp/Resources/LaunchScreen.storyboard`。
- Launch Screen 使用与产品视觉一致的温润纸感背景色，避免启动瞬间出现纯白或黑色闪烁。

## 4. 验证计划

```bash
xcodegen generate
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/zibuyu/Library/Developer/Xcode/DerivedData/LangoTrace-hdfadqhothdwgbahopjjqiwrxhky/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch booted com.zibuyu.LangoTrace
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
```

## 5. 验证结果

已验证通过：

- `xcodegen generate`
- `xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
- 最终构建产物 `Info.plist` 已包含 `UILaunchStoryboardName = LaunchScreen`。
- 已卸载旧 Simulator App 后重新安装，避免 iOS 缓存旧启动屏/兼容尺寸。
- `xcrun simctl launch booted com.zibuyu.LangoTrace` 启动成功。
- `xcrun simctl io booted screenshot /private/tmp/langotrace-ios-fullscreen-fix.png` 截图确认页面已铺满屏幕，不再出现黑色 letterbox。
- `swiftlint --no-cache` 0 violations。
- `swiftformat --lint . --cache ignore` 0 files require formatting。
- `git diff --check` 通过。
