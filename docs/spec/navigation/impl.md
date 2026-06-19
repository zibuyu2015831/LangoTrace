# navigation 实现地图

状态：Current Implementation Map

最后更新：2026-05-20

## 1. 对应规范

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`

## 2. 当前实现

- App 入口：`LangoTraceApp/LangoTraceApp.swift`
- 启动状态和环境：`LangoTraceApp/`
- Core 启动路由：`Packages/LangoTraceCore/Sources/LangoTraceCore/`
- iPhone 主界面：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- iPad 主界面：`Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- macOS 主界面：`Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`

当前已经实现：

- Welcome / Onboarding / Main 三段启动路由。
- 缺少语言空间时回到 onboarding 的路由保护。
- iPhone `记录 / 练习 / 记忆` 三个 Tab。
- iPhone 设置页语言空间管理入口，支持新增、切换、重命名和删除。
- iPad 三栏工作台和左右辅助面板收起 / 展开。
- macOS Sidebar / 主区 / Inspector 工作台骨架。
- macOS `Settings` scene、基础 commands 和键盘快捷键。
- 配置能力的说明页、部分真实配置页和 mock / unavailable 边界。

## 3. 已知偏差

- iPad / macOS 还没有完整语言空间管理页；本轮先以 iOS 为第一验收面。
- 外部入口、多窗口、Command Palette、深链和状态恢复尚未实现。
- iPad / macOS 面板展开状态仍是瞬时 UI state，不持久化。

## 4. 复查方法

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
rg "\\.commands|CommandMenu|keyboardShortcut|Settings \\{" LangoTraceApp Packages
scripts/verify.sh
```

UI 或平台交互任务还应按 `docs/testing/README.md` 执行 iPhone、iPad 和 macOS 页面闭环验证。
