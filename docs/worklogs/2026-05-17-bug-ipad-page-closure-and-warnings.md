# 工作记录：iPad 页面闭环缺口与 SwiftLint warning 修复

类型：bug

状态：Completed

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/worklogs/2026-05-17-feature-three-platform-page-closure.md`
- `docs/superpowers/plans/2026-05-17-three-platform-page-closure.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/testing/README.md`

关联提交：

- 未提交

## 1. 背景

用户在 iPad 端测试后反馈仍缺少相关页面，并要求同时解决此前发现的 warning。

## 2. 根因

代码复查确认问题真实存在：

- iPad 端当前只补齐了记录详情、练习会话、单个设置详情、新建记录和筛选。
- iPad 缺少完整设置列表页、记忆页、导入导出 unavailable 页。
- iPad `LanguageSpaceFooter` 中语言空间、AI、同步和设置入口没有路由动作，导致底部关键入口仍不可达。
- 后续三端复查发现 macOS `LanguageSpaceFooter` 的语言空间标题和设置齿轮仍为空动作；AI Provider 和同步图标只显示 popover，未能进入对应设置详情页。
- `swiftlint --no-cache` 报告 file length / type body length 问题，集中在 `PhoneMainView.swift`、`PadMainView.swift`、`MacMainView.swift`。

## 3. 修复目标

- iPad 增加可达页面：设置列表、设置详情、记忆页、导入导出 unavailable、语言空间 unavailable。
- iPad 底部语言空间、AI、同步和设置入口必须有可见结果。
- macOS 底部语言空间、AI、同步和设置入口必须有可见结果，且与 macOS Sidebar / Inspector 页面状态一致。
- 保持 Local Mock / unavailable 边界，不接入真实数据库、AI、语音、权限、同步或导出。
- 拆分 SwiftUI 文件和视图职责，使 `swiftlint --no-cache` 不再报告 warning。
- 更新相关 worklog / plan 验证记录。

## 4. 不做什么

- 不接入语言空间持久化与启动恢复。
- 不实现真实导入导出、AI Provider、Keychain、同步、TTS、OCR、Speech 或权限流程。
- 不做最终视觉升级。

## 5. 验证计划

```bash
swift test --package-path Packages/LangoTraceUI
swiftlint --no-cache
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
scripts/verify.sh
git status --short
```

## 6. 用户确认记录

2026-05-17：用户反馈 iPad 端仍缺少相关页面，要求检查后继续补充，并一并解决 warning。

## 7. 实施记录

- 新增 `PadWorkspaceRoute` 页面闭环状态和 `PadFooterAction` 路由映射测试，先确认 footer 入口和 iPad-only 页面缺失为可复现问题。
- `PadMainView` 保留页面状态、面板显示状态和手势处理；侧栏、工作台内容、学习面板拆到 `PadMainSections.swift`，侧栏控件拆到 `PadSidebarControls.swift`。
- iPad 侧栏新增“页面”区，提供记忆、导入导出、设置入口。
- iPad footer 的语言空间、AI、同步、设置入口改为可注入动作：iPad 路由到可见页面，其他平台仍可保留原 popover 行为。
- iPad 新增设置列表、记忆页、导入导出 unavailable 页、语言空间 unavailable 页；所有真实数据库、AI、同步、文件和权限能力仍保持未接入说明。
- `MacMainView` 拆出 `MacWorkspaceContentView`、`MacInspectorContent`、`MacMainModels`，消除 Mac 主视图过长 warning。
- macOS footer 新增 `MacFooterAction` 映射：语言空间进入 unavailable 页，AI Provider / 同步进入设置详情，设置齿轮进入设置总览。
- `PhoneMainView` 拆出 `PhoneMainSections.swift`，消除 iPhone 主视图过长 warning。
- `project.yml` 为 iOS / macOS App target 显式链接系统 `AppIntents.framework`，满足 Xcode 26.5 metadata extractor 的依赖检查；当前没有实现任何 AppIntent，也不新增用户可见入口。

## 8. 验证结果

- `swift test --package-path Packages/LangoTraceUI`：通过，6 个 Swift Testing 测试通过。
- `swift test --package-path Packages/LangoTraceUI`：补充 macOS footer 路由回归测试后通过，7 个 Swift Testing 测试通过。
- `scripts/verify.sh`：三端复查后重新通过；Core 17 个测试通过，UI 7 个测试通过，iPhone 17 / iPad Pro 13-inch / macOS 构建通过，SwiftLint 0 violations / 0 serious，SwiftFormat 0/58 files require formatting。
- `git diff --check`：通过。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'`：通过，无命中。
- 静态空动作扫描：空按钮、空动作、崩溃占位和永久禁用控件均无命中。
- macOS 运行态 smoke：通过真实 App 界面创建内存语言空间，逐项点击 Sidebar 的练习、词句记忆、导入导出、设置，以及 footer 的语言空间、AI Provider、同步和设置入口；均进入对应页面、设置详情或 unavailable 说明。
- iPhone / iPad 模拟器启动 smoke：在 iPhone 17 和 iPad Pro 13-inch (M5) 上安装并启动 Debug app，截图确认启动 UI 非空且进入可操作的语言空间创建页；页面跳转闭环由 `PageClosureStateTests` 和三端构建共同覆盖。
- `swiftlint --no-cache`：通过，0 violations / 0 serious。
- `find docs -maxdepth 3 -type f | sort`：通过，文档结构可枚举。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'`：通过，无命中。
- `git diff --check`：通过。
- `scripts/verify.sh`：首次通过，但发现 Xcode AppIntents metadata extractor 仍打印无 AppIntents 依赖 warning；已补充工程配置。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`：补充 AppIntents 系统框架依赖后通过，原 AppIntents metadata extractor warning 消失。
- `scripts/verify.sh`：补充工程配置后重新通过；Core 测试 17 个通过，UI 测试 6 个通过，iPhone / iPad / macOS 构建通过，SwiftLint 0 violations / 0 serious，SwiftFormat 0/58 files require formatting。
