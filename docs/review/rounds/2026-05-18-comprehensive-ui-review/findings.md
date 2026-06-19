# 问题清单

## P1-001 iPhone 顶层 IA 重复，设置入口层级过重

问题描述：`今日` 和 `记录` 都承担 Entry 创建和记录发现；`设置` 作为 Tab 与记录、练习、记忆并列，削弱主路径。
决策依据：产品主参考要求首页主动作围绕“今天记录一点生活”；导航规范要求设置低干扰但当前又强制五 Tab。
项目定位和愿景影响：削弱“用生活记录学习语言”的第一动作，让配置入口过早进入主导航。
使用的 skill：`ui-ux-pro-max`、`ios-design-guidelines`
涉及代码文件路径：`PhoneMainView.swift`、`PhoneMainSections.swift`、`PhoneRootTab.swift`
涉及文档路径：`docs/product-main-reference.md`、`docs/spec/002-navigation-and-routing.md`
优化方向：合并 `今日 / 记录` 为记录工作台，保留 `练习 / 记忆`，将设置降级为 toolbar / 菜单 / 系统设置入口。
复查方法：检查 iPhone Tab 为互不重复顶层目的地，主屏 5 秒内能明确看到记录生活主动作。
是否进入第一轮 UI 收敛：是
后续任务：第一轮 UI 收敛 active plan

## P1-002 语言空间删除应允许但必须拆生命周期方案

问题描述：语言空间是主数据聚合根，长期应可删除；当前 UI 只有 unavailable / mock，没有删除边界。
决策依据：本地优先和用户掌控数据；数据规范要求主数据可迁移、可导出、可删除。
项目定位和愿景影响：不允许删除会削弱用户掌控；直接删除会破坏个人语言记忆系统完整性。
使用的 skill：`ui-ux-pro-max`、`swiftui-pro`
涉及代码文件路径：`SettingsCapability.swift`、`LearningContent.swift`、`UnavailableCapabilityView.swift`
涉及文档路径：`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/decisions/004-use-language-space-as-primary-model.md`
优化方向：新建语言空间生命周期方案，定义添加、切换、删除、最后空间回退、导出、级联、撤销和同步 tombstone。
复查方法：新方案逐项回答数据规范真实写入前问题。
是否进入第一轮 UI 收敛：不直接进入代码收敛，拆新方案
后续任务：`feature-language-space-lifecycle-and-deletion`

## P1-003 Rendering 边界不显性，保存 Entry 自动生成 mock 闭环

问题描述：`createEntry` 立即创建 mock Rendering、PracticeItem、MemoryItem，容易让未来真实 AI 心智变成保存即外发生成。
决策依据：AI 请求必须用户明确触发，敏感内容不得自动发送。
项目定位和愿景影响：破坏本地优先和请求透明度，削弱用户对生活记录的控制。
使用的 skill：`ui-ux-pro-max`、`swiftui-pro`
涉及代码文件路径：`LearningContent.swift`、`PhoneMainView.swift`、`PhoneMainSupportingViews.swift`、`LearningContentComponents.swift`
涉及文档路径：`docs/product-main-reference.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md`
优化方向：Entry detail 中显性展示 Rendering 状态；Local Mock 改为本地示例；真实 AI 前加入请求预览确认流程。
复查方法：创建 Entry 后先显示原文，再显示 Rendering 状态和明确触发入口。
是否进入第一轮 UI 收敛：是
后续任务：第一轮 UI 收敛 active plan

## P1-004 macOS 设置入口和命令面缺口

问题描述：Sidebar 有 Settings，footer AI / Sync / gear 都切入 settings 域；App 没有 `Settings` scene、`.commands`、`Cmd+,`、`Cmd+N`、`Cmd+F`。
决策依据：macOS HIG 要求菜单、Settings、稳定 command surface 和键盘快捷键。
项目定位和愿景影响：Mac 端像放大的自定义面板，不像资料库和创作工作台。
使用的 skill：`macos-design-guidelines`
涉及代码文件路径：`LangoTraceApp.swift`、`MacMainView.swift`、`MacMainModels.swift`、`LanguageSpaceFooter.swift`
涉及文档路径：`docs/spec/002-navigation-and-routing.md`
优化方向：新增 Settings scene 和 commands；Sidebar 保留内容域，AI / Sync 为状态入口，gear 为通用设置。
复查方法：`rg "\\.commands|CommandMenu|keyboardShortcut|Settings \\{" LangoTraceApp Packages`，并手动验证菜单和快捷键。
是否进入第一轮 UI 收敛：是
后续任务：第一轮 UI 收敛 active plan

## P1-005 iPad 响应式和生产力输入不足

问题描述：iPad 使用固定 HStack，compact 只隐藏右侧面板；缺少 keyboardShortcut、hoverEffect、contextMenu、focusable / FocusState。
决策依据：iPadOS HIG 要求 Split View、Stage Manager、pointer、keyboard 和多栏自适应。
项目定位和愿景影响：iPad 难以成为沉浸式学习工作台。
使用的 skill：`ipados-design-guidelines`
涉及代码文件路径：`PadMainView.swift`、`PadMainSections.swift`、`PadWorkspaceBar.swift`、`LearningContentComponents.swift`
涉及文档路径：`docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`
优化方向：定义三栏 / 两栏 / 单栏断点；补 Cmd+N / Cmd+F / 面板切换快捷键、hover、focus、context menu。
复查方法：iPad 全屏、2/3、1/2、1/3、Slide Over 类窄宽和 Stage Manager 截图验证。
是否进入第一轮 UI 收敛：是
后续任务：第一轮 UI 收敛 active plan

## P1-006 设计系统 token 和状态矩阵不足

问题描述：固定浅色 RGB、青绿 / 金色体系、`langoPanel` 过度复用、Local Mock 与 ready 状态视觉接近。
决策依据：UI 规范要求安静但不简陋、状态可信、不能用装饰替代结构。
项目定位和愿景影响：付费级完成度不足，真实 Provider 接入后可能误导能力状态。
使用的 skill：`ui-ux-pro-max`
涉及代码文件路径：`LangoTraceDesign.swift`、`CapabilityStatusBadge.swift`、`LearningContentComponents.swift`、`LanguageSpaceFooter.swift`
涉及文档路径：`docs/spec/003-ui-design-system.md`、`docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
优化方向：扩展 semantic token、light/dark/high contrast 映射、状态矩阵、action hierarchy、empty/unavailable pattern。
复查方法：截图状态矩阵，搜索裸 `Color(red:)`，做 light/dark 和对比度抽查。
是否进入第一轮 UI 收敛：是
后续任务：第一轮 UI 收敛 active plan

## P1-007 自有界面语言偏好未实际驱动多数 chrome

问题描述：App 注入 `.locale`，但 `localizedText()` 使用 `Locale.preferredLanguages`，显式设置不一定改变自有 SwiftUI chrome。
决策依据：006 规范要求显式 App 内语言偏好覆盖 LangoTrace 自有 chrome。
项目定位和愿景影响：多语种产品的界面语言边界不可信。
使用的 skill：`swiftui-pro`、`iOS SwiftUI Accessibility`
涉及代码文件路径：`LangoTraceApp.swift`、`LocalizedChrome.swift`、`SettingsCapabilityDetailView.swift`
涉及文档路径：`docs/spec/006-interface-localization-and-language-boundaries.md`
优化方向：建立环境感知本地化层，或降级设置文案避免承诺即时覆盖。
复查方法：系统语言不同于 App 内选择时，验证 Tab、设置、unavailable、toolbar 文案切换。
是否进入第一轮 UI 收敛：是
后续任务：第一轮 UI 收敛 active plan

## P1-008 UI 直接依赖 concrete in-memory repository

问题描述：iPhone / iPad / macOS View 直接持有 `InMemoryLearningContentRepository`，调用 `ensureSeeded`、`createEntry`、`selectEntry` 并手动 bump `contentRevision`。
决策依据：SwiftUI 架构规范要求 mock repository 可被真实实现替换，View 不承担数据层职责。
项目定位和愿景影响：真实数据接入会变成 UI 重构，拖累本地记录闭环。
使用的 skill：`swiftui-pro`
涉及代码文件路径：`AppEnvironment.swift`、`LangoTraceRootView.swift`、`PhoneMainView.swift`、`PadMainView.swift`、`MacMainView.swift`
涉及文档路径：`docs/spec/004-swiftui-architecture.md`
优化方向：引入 `LearningContentRepository` 协议或 MainActor feature store，把 mutation 和刷新信号移出平台 View。
复查方法：`rg "InMemoryLearningContentRepository" Packages/LangoTraceUI/Sources LangoTraceApp` 只在 bootstrap / preview seam 出现。
是否进入第一轮 UI 收敛：建议进入架构前置任务
后续任务：repository seam active plan 或第一轮 UI 收敛前置

## P1-009 `SentencePairView` Listen 是空 action

问题描述：Listen 按钮可见且可点，但 `Button {}` 无反馈。
决策依据：页面闭环阶段所有明显入口必须有可见结果。
项目定位和愿景影响：误导用户以为 TTS / audio 已接入。
使用的 skill：`swiftui-pro`、`iOS SwiftUI Accessibility`
涉及代码文件路径：`LearningContentComponents.swift`
涉及文档路径：`docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`
优化方向：传入 `onListen` 并打开 unavailable/local mock feedback，或禁用并明确说明。
复查方法：手动点击三端 sentence row 的 Listen，必须有可见反馈。
是否进入第一轮 UI 收敛：是
后续任务：第一轮 UI 收敛 active plan

## P2 代表性问题

- iPhone unavailable sheet 缺标题、关闭、滚动和焦点返回。
- Welcome 650ms 自动跳转对 VoiceOver 和 Timing accessibility 不友好。
- Onboarding / language menu / practice steps 存在 44pt 和 Dynamic Type 风险。
- iPad Sidebar 绑定 Settings / ImportExport / footer，隐藏左栏时隐藏重要入口。
- macOS 搜索是 unavailable button 而非标准 search / command surface。
- `Memory` 未体现内容记忆、语言记忆、学习记忆三层模型。
- `LanguageSpaceFooter` lineLimit 和 compact hit size 会影响长名称与可访问性。
- 组件文件仍然过大，但应随 first-round convergence 按产品对象拆分。
