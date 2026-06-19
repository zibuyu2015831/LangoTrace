# iPad / macOS 语言空间管理补全

状态：Verified

类型：feature

创建日期：2026-05-20

最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户提供上一位 agent 形成的实施方案，并要求在 fresh context 中按方案实现、验证和收口。

## 需求描述

参考 iPhone 已落地的语言空间管理能力，把 iPad 和 macOS 从只读摘要入口升级为完整管理入口。iPad 和 macOS 应支持查看所有语言空间、切换当前空间、新增、编辑和删除，并继续保持“鼓励一门学习语言一个空间，但架构允许同目标语言多空间”的策略。

## 现状描述

- `LanguageSpaceManagementView` 已承载 iPhone 设置页语言空间管理，接收空间列表、当前空间 ID 和 lifecycle action closures。
- `PlatformMainView` 只把 `languageSpaces` 和 lifecycle actions 传给 `PhoneMainView`，iPad / macOS 主界面只接收当前 `LanguageSpacePreview`。
- `PadWorkspaceRoute.languageSpaceSummary` 和 `MacWorkspaceRoute.languageSpaceSummary` 只展示 `LanguageSpaceSummaryView`。
- macOS 原生 `Settings` scene 只接收 capabilities 和当前语言空间 preview，不能管理语言空间列表。

## 目标

- iPad Sidebar footer 和设置列表中的语言空间入口进入完整管理页。
- macOS Sidebar footer、Settings section 和原生 Settings scene 中的语言空间入口进入完整管理页。
- 共享 `LanguageSpaceManagementView` 与 `LanguageSpaceEditorView`，不复制业务逻辑。
- macOS 管理列表除 swipe actions 外，提供右键菜单和 toolbar 新增入口。
- App Shell 将语言空间列表和 add / select / update / delete closures 注入三端主界面和 macOS Settings scene。

## 范围

- 修改 SwiftUI UI 层、App Shell 注入和 UI package 源码级回归测试。
- 更新三端页面清单和导航规范。
- 不新增数据库 schema，不改变 repository 删除 fallback 语义，不做恢复入口。

## 不做什么

- 不把同目标语言多空间变成阻断校验。
- 不引入新的数据迁移、同步、StoreKit 或 Keychain 行为。
- 不改变 iPhone 顶部语言空间摘要 sheet 行为。

## 证据与决策依据

- `docs/README.md` 规定新功能实现前需要任务方案，语言空间和三端导航属于核心上下文。
- `docs/spec/002-navigation-and-routing.md` 已规定语言空间是全局学习上下文，不应成为高频主导航。
- `docs/spec/004-swiftui-architecture.md` 已规定当前语言空间会话状态由 App 层收口，SwiftUI 管理页只接收列表和 action closures。
- 现有 iPhone 管理页已验证共享管理组件可复用，iPad / macOS 只需要平台外壳和入口接线。

## 涉及的代码文件路径

- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PremiumUILayoutRules.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceManagementTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceEditorView.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`

## 涉及的文档路径

- `docs/plans/active/2026-05-20-feature-ipad-mac-language-space-management.md`
- `docs/platform-page-inventory.md`
- `docs/spec/002-navigation-and-routing.md`

## 实施方案

1. 为 iPad / macOS 语言空间管理入口补源码级回归测试，先确认当前实现失败。
2. 将 `languageSpaces` 和 lifecycle action closures 从 `PlatformMainView` 注入 `PadMainView`、`MacMainView` 和 macOS `Settings` scene。
3. 将 iPad / macOS 语言空间 route 从 summary 语义改为 management 语义，并在主区渲染 `LanguageSpaceManagementView`。
4. 在 iPad / macOS 设置列表中把 `.languageSpace` capability route 到完整管理页。
5. 为共享管理列表补 macOS 可发现的右键删除入口，同时保留 iOS swipe actions。
6. 更新页面清单和导航规范。
7. 运行 UI package 测试和完整验证脚本。

## 复查方法

- 检查 iPad / macOS source 中不再把语言空间 route 指向 summary-only 页面。
- 检查 macOS Settings scene 是否接收语言空间列表和 lifecycle actions。
- 检查共享管理页是否仍不直接引用 GRDB、SQL 或数据库生命周期。
- 检查文档是否把 iPad / macOS 当前事实从摘要页更新为完整管理页。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
git status --short
```

## 文档影响检查

本任务改变 iPad / macOS 页面入口事实和导航 route 语义，需要更新 `docs/platform-page-inventory.md` 和 `docs/spec/002-navigation-and-routing.md`。未改变语言空间核心模型、SQLite schema、Provider、同步或 StoreKit 边界，不需要 ADR。

## 实施记录

- 2026-05-20：新增 iPad / macOS 语言空间管理源码级测试，初次 `swift test --package-path Packages/LangoTraceUI` 按预期失败，失败点为 iPad / macOS 仍使用 summary route，macOS Settings scene 未注入 lifecycle actions。
- 2026-05-20：实现 App Shell 注入、iPad / macOS management route、macOS Settings scene 管理入口和共享管理页右键删除。
- 2026-05-20：重新运行 `swift test --package-path Packages/LangoTraceUI`，132 个 UI package 测试通过。
- 2026-05-20：运行 `scripts/verify.sh`，通过 XcodeGen、`xcodebuild -list`、Core / Data / UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和 docs placeholder scan。

## 完成标准

- iPad 和 macOS 语言空间入口均进入完整管理页。
- macOS Settings scene 可进入语言空间管理页并复用当前 action closures。
- UI package 回归测试覆盖新增入口和注入边界。
- 相关长期文档同步更新。
- 完整验证命令通过或明确记录无法运行的原因和风险。

## 剩余风险

- 本任务未做人工 iPad / macOS 截图验收；当前收口依据为源码级回归测试和三端构建验证。若后续要求发布级 UI 验收，应在模拟器和 macOS app 中补手动路径检查。
