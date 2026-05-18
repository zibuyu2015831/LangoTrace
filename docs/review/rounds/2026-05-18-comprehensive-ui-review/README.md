# 全面 UI 审查：页面、设计系统与规范契合

审查类型：专项审查
日期：2026-05-18
代码快照：`a800317a023fcc6d0dbdd93d110879876813a328`
状态：Verified
当前事实源：`docs/review/rounds/2026-05-18-comprehensive-ui-review/`
后续覆盖记录：`docs/plans/active/2026-05-18-feature-comprehensive-ui-review-and-design-uplift.md`
可作为依据：Yes

## 1. 触发原因

用户确认 `docs/plans/active/2026-05-18-feature-comprehensive-ui-review-and-design-uplift.md` 已通过审核，要求对照方案完成全面 UI / 设计 / 规范 / 代码契合度审核。审查不能默认当前页面实现已经大致完成，必须从 LangoTrace 的产品定位和 Apple 三端交互质量出发，允许推翻或大改现有页面结构。

## 2. 审查范围

审查覆盖 iPhone、iPad、macOS 主界面、关键二级页、共享组件、设计 token、Local Mock / unavailable 状态、导航规范、UI 规范、SwiftUI 架构规范、界面国际化规范、数据删除边界规范和测试覆盖。

本轮只做审查和后续任务拆分建议，不接入真实 SQLite / GRDB、AI Provider、TTS、OCR、Speech、同步、StoreKit 或权限流程。

## 3. 关键结论

- 产品方向仍正确：当前骨架没有偏向 AI 聊天、课程、背单词或云账号中心，核心对象仍围绕 `Space -> Entry -> Rendering -> Practice -> Memory`。
- iPhone 顶层 IA 需要调整：`今日` 与 `记录` 在 Entry 创建和列表发现上重复，`设置` 作为底部 Tab 层级过重。主审结论建议合并 `今日 / 记录`，并将 `设置` 降级为 toolbar / 语言空间菜单 / 系统设置入口。
- 语言空间应长期允许删除，但删除能力必须拆新 active plan。它涉及最后一个空间回退、Entry / Rendering / Practice / Memory / 附件级联、导出、撤销窗口、未来同步 tombstone，不能作为本轮 UI 小改。
- iOS 首次创建语言空间页结构不算过密，三项必填加底部创建按钮合理；但 Welcome 和 Onboarding 中过早出现 AI / 同步 / Prompt / 词典等概念，会削弱“先创建空间，再记录生活”的主路径。
- macOS 底部 AI / Sync / Settings 三个图标不应表现为三个等价设置入口。AI 和 Sync 应是状态 / 配置详情入口，gear 才是通用设置；同时 macOS 缺少 `Settings` scene、`Cmd+,`、菜单命令和快捷键，是 P1 级 Mac 原生性缺口。
- iPad 三栏方向可保留，但当前是固定宽度 HStack 原型，不是自适应 iPad 工作台。左栏同时承担 timeline、filter、Memory、Import/Export、Settings 和 footer，职责过重；右栏应从功能清单变成状态驱动的学习 Inspector。
- 设计系统问题不是单页美化问题，而是 token、状态矩阵、卡片使用边界、平台材质差异、长文案响应式策略不足。
- SwiftUI 架构存在 P1 偏差：UI 直接依赖并 mutate `InMemoryLearningContentRepository`，`contentRevision` 横跨三端；显式界面语言偏好不实际驱动大部分自有 chrome；`SentencePairView` 的 Listen 按钮为空 action。

## 4. P0-P3 摘要

P0：未发现当前 UI 会真实外发 AI、同步、写数据库、触发权限或 StoreKit 的路径，也未发现会直接破坏启动路由的实现。

P1：

- iPhone `今日 / 记录 / 设置` 信息架构需要收敛。
- 语言空间删除应允许但必须拆独立生命周期方案。
- Rendering 需要显性化，不能让保存 Entry 等同于未来真实 AI 生成。
- macOS Sidebar / footer 设置入口重复，且缺少 Settings scene、commands、快捷键。
- iPad Split View / Stage Manager 响应式不足，键盘 / pointer / context menu 基本缺失。
- 设计 token 固定浅色、状态视觉区分弱、卡片堆叠明显。
- 自有界面语言偏好未真正驱动大部分 chrome。
- UI 直接依赖 concrete in-memory repository。
- `SentencePairView` Listen 是可见空 action。

P2：

- unavailable / empty 状态偏说明页，缺少下一步动作。
- iPhone unavailable sheet 缺少标题、关闭、滚动和焦点返回。
- 触控目标和 Dynamic Type 在部分横向 row 中风险较高。
- iPad 左栏隐藏会同时隐藏全局配置入口。
- macOS 搜索、窗口尺寸、Inspector 行为仍偏原型。
- spec 与代码在 iPhone Tab、首次 AI 配置步骤、语言空间入口、界面语言、repository seam 上存在偏差。

P3：

- Memory 三层模型尚未在 UI 中体现。
- 部分 heading 未标记为无障碍 heading。
- 少量原型文案和工程术语削弱付费应用完成度。

完整清单见 [findings.md](findings.md)。

## 5. 第一轮 UI 收敛建议

建议拆出新的 active plan 执行第一轮 UI 收敛，优先级如下：

1. 修正真实交互风险：Listen 空 action、unavailable sheet 可访问性、Welcome 自动跳转、Onboarding 说明前置。
2. iPhone IA 收敛：合并 `今日 / 记录`，降级 `设置`，同时处理每 Tab 导航栈策略。
3. Entry detail 收敛：让 Rendering 成为显性状态区，Local Mock 明确是本地示例，Practice / Memory 从 Rendering 出发。
4. 设计系统底座：扩展 token、状态矩阵、action hierarchy、empty/unavailable pattern，减少全卡片化。
5. iPad 工作台：定义宽度断点、稳定 Settings/Search/New Entry 入口、右侧学习面板改为状态驱动 Inspector。
6. macOS 工作台：添加 Settings scene / commands / 快捷键，分离内容域与配置域。
7. 文档同步：更新 `docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/006-interface-localization-and-language-boundaries.md`。
8. 拆语言空间生命周期方案：添加、切换、删除、导出前置、最后空间回退和未来同步边界。

## 6. Second Review

二轮复查于 2026-05-18 完成，输入为本轮 6 个子代理报告、主线程可访问性 / 本地化补审、核心规范和代码证据。

复查结果：

- 页面地图覆盖 Welcome、Onboarding、iPhone 五 Tab、Entry 创建、Entry detail、Practice、Memory、Settings、iPad 三栏、macOS Sidebar / Toolbar / Inspector、共享组件和主要状态。
- 用户特别提出的问题均已覆盖：iPhone Tab 重复、设置入口层级、语言空间删除、macOS 底部三个图标、iOS 首次创建页信息密度。
- 子代理冲突已裁决：iOS 报告建议短期保留五 Tab；产品 IA 报告建议合并 `今日 / 记录` 并降级 `设置`。主审裁决采用产品 IA 结论，因为本轮方案明确要求不默认现状成立，且 `docs/spec/002-navigation-and-routing.md` 已与“设置不抢主流程”形成张力。
- P0 / P1 均有代码路径、文档依据、skill 依据、优化方向和复查方法。
- 发现的长期规则变化不直接改 spec，先进入第一轮 UI 收敛 active plan；本轮 review 作为依据。
- 审查内容较多，已拆分为子文档；本 README 只保留关键结论和索引。
- 完成审计见 [completion-audit.md](completion-audit.md)。

## 7. 验证命令与结果

见 [process-log.md](process-log.md)。本轮为文档审查，无 SwiftUI 实现修改，未运行完整 `scripts/verify.sh`。已运行文档阶段检查、package 级测试和 diff 检查：`git diff --check` 通过，文档占位扫描无匹配，Core / Data / UI package tests 均通过。

## 8. 剩余风险

- 未进行模拟器截图、VoiceOver 实机、Dynamic Type 自动截图和 macOS 菜单实机验证。
- 第一轮 UI 收敛需要新 active plan 承接，当前代码尚未修复 P1/P2 问题。
- 语言空间删除能力尚未设计数据级实现边界，只形成“应允许但拆方案”的审查结论。
- `docs/spec/002-navigation-and-routing.md` 仍保留 iPhone 五 Tab 强制规则，后续实现前必须同步更新。
