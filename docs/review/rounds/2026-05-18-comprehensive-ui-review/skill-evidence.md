# Skill 使用证据

## `ui-ux-pro-max`

支撑结论：

- iPhone 顶层 IA 应减少重复入口，主路径优先服务“记录生活”。
- 设计系统应先解决 token、状态矩阵、卡片使用边界和 action hierarchy，而不是逐页装饰。
- Onboarding 和 unavailable 状态应使用渐进披露，避免说明堆叠。
- Empty / unavailable 状态需要下一步动作。

## `ios-design-guidelines`

支撑结论：

- iPhone Tab 应是 3-5 个互不重复顶层目的地；当前 `今日 / 记录` 重复，`设置` 层级过重。
- Shared `NavigationStack` 不利于 per-tab state preservation。
- 主操作应更靠近单手触达区域，不可用 secondary chips 不应抢首屏。
- 触控目标需要 44pt，Onboarding language menu 和 Practice step 有风险。

## `ipados-design-guidelines`

支撑结论：

- iPad 三栏方向正确，但必须支持 Split View、Slide Over、Stage Manager 和宽度断点。
- 固定 HStack + 只隐藏右栏不足以保护主内容。
- iPad 生产力体验需要 keyboard shortcuts、pointer hover、focus routing 和 context menus。
- 左栏不应同时承担 timeline、filters、全局 Settings 和 ImportExport。

## `macos-design-guidelines`

支撑结论：

- macOS 必须有 Settings scene、menu commands、keyboard shortcuts 和稳定 command surface。
- Sidebar 应接近 source list，Settings / ImportExport 不应与内容域同级。
- AI / Sync / gear 三个 footer 图标必须表达不同语义，不能都像 Settings。
- Window sizing、toolbar、Inspector 和 search 需要 Mac 原生复查。

## `swiftui-pro`

支撑结论：

- UI 直接依赖 `InMemoryLearningContentRepository` 是架构 seam 风险。
- `contentRevision` 可作为短期桥接，不应继续扩散。
- 显式 App 语言偏好不驱动 custom localization，是 spec alignment P1。
- `SentencePairView` Listen 空 action 是真实交互 bug。
- shared `NavigationStack`、manual bindings、ChineseUI display model、large multipurpose View files 需要后续收敛。

## `iOS SwiftUI Accessibility`

支撑结论：

- Welcome 自动跳转违反 timing/accessibility 预期。
- Sheet 需要标题、关闭、滚动和 focus return。
- `TextEditor` 需要明确 accessible label。
- Section heading 应添加 heading traits。
- icon-only / compact controls 需要 label / value / hint 和足够 hit target。

## `verification-before-completion`

支撑结论：

- 完成声明前执行新鲜验证命令。
- 本轮为审查产物，无 SwiftUI 代码修改；验证以文档 diff、package tests、占位扫描和 git status 为主。
