# 任务方案：全面页面审核与设计提升

状态：Verified
类型：feature
创建日期：2026-05-18
最后更新日期：2026-05-18

## 用户确认记录

状态为 `Draft` 时不能开始实现。用户确认后记录确认时间、确认内容和范围边界。

2026-05-18：用户确认本方案已经通过审核，要求完整阅读方案、修改方案状态、制定详细计划，并对照方案完成全面 UI / 设计 / 规范 / 代码契合度审核任务。

本轮先进入审核与审查产物阶段；是否进入 SwiftUI 实现修改、长期规范更新或新 active plan 拆分，必须以本轮审核结论为依据。

## 1. 需求或 bug 描述

当前项目已经搭建出多端页面骨架，但本轮审核不能默认当前所有页面实现已经大致完成，也不能把现有页面结构视为必须保留的前提。需要站在专业 Apple 应用交互设计师和产品架构审查者的角度，对 iPhone、iPad、macOS 所有现有实现做深入评估，确认它们是否真正服务 LangoTrace 的核心学习闭环，并形成可执行的优化计划。

本任务不是简单美化，也不是继续增加页面，而是先从产品信息架构、Apple 平台交互、页面设计、整体配色、状态真实性、设计系统、规范文档完整性和工程边界八个维度完成审查。必要时可以建议推翻既有页面结构、合并或删除入口、调整 Tab / Sidebar / Toolbar / Settings 等导航模型，或进行页面大改，再按审查结论推进第一轮 UI 收敛和相关规范文档更新。

## 2. 现状描述

当前已经具备：

- Welcome / Onboarding / Main 启动路由。
- 内存语言空间 preview。
- iPhone `今日 / 记录 / 练习 / 记忆 / 设置` 五个 Tab。
- iPad 三栏工作台、时间线、学习面板和左右面板收起 / 展开。
- macOS Sidebar / 主区 / Inspector 工作台骨架。
- Mock Entry 创建、详情、PracticeSession、Memory 和设置能力说明。
- `LangoTraceDesign` 基础 token。
- 多轮页面闭合和 premium UI 相关已完成任务方案。

当前仍存在的结构性风险：

- 页面是否围绕 `Space -> Entry -> Rendering -> Practice -> Memory` 严格组织，需要复核。
- Local Mock、未配置 AI Provider、同步未启用和 unavailable 能力是否表达一致，需要复核。
- iPhone、iPad、macOS 是否都符合各自平台习惯，需要复核。
- iPhone 当前 `今日 / 记录 / 练习 / 记忆 / 设置` 五个 Tab 是否是合理的信息架构，`今日` 和 `记录` 是否存在主路径重复，`设置` 是否应从顶层 Tab 简化为 toolbar 图标或其他系统惯用入口，需要重点复核。
- 语言空间从交互逻辑上是否应该允许用户删除；如果允许删除，需要明确无语言空间回退、最后一个语言空间、关联记录、练习和记忆数据、确认流程、撤销或导出提示、同步和未来真实存储边界。
- macOS 左侧栏底部三个图标按钮当前都进入设置界面，是否符合预期，是否存在入口语义重复或设置能力过度集中，需要重点复核。
- iOS 首次创建语言空间页面的信息密度是否过高，是否把隐私、本地保存、AI、同步、词典和 Prompt 等后续设置过早暴露，是否削弱“先创建空间再记录生活”的主路径，需要重点复核。
- 页面设计、整体配色、视觉层级和交互反馈是否达到付费 Apple 应用的完成度，需要复核。
- docs 下现有设计、导航、SwiftUI 架构和本地化规范是否足够全面，是否与代码实现一致，需要复核。
- 当前 UI 是否过度依赖 `InMemoryLearningContentRepository`、`contentRevision` 和 View 内 transient state，需要复核。
- 设计 token、组件、状态、无障碍、本地化和截图验证是否已经足够支撑后续真实功能，需要复核。

## 3. 目标

本任务完成后必须达到：

- 形成现有三端页面和关键二级页的审核清单。
- 形成页面级、组件级、设计系统级和工程边界级问题清单。
- 明确哪些页面保留、哪些合并、哪些删除入口、哪些重构、哪些降级为占位、哪些需要补充状态。
- 对 iPhone 顶层 Tab、iPad 多栏结构、macOS Sidebar / Toolbar / Inspector 的信息架构给出明确结论，不能仅描述现状。
- 对整体配色、视觉层级、控件密度、交互反馈、可访问性和平台惯用入口给出可执行优化方向。
- 审查 docs 下相关设计规范是否全面完整、是否需要更新，并检查代码实现是否与规范契合。
- 所有页面判断必须紧扣项目定位和愿景：语迹是“用生活记录学习语言”的本地优先个人语言记忆系统，不是 AI 聊天、课程驱动、背单词或云端平台产品。页面层次必须优先服务生活记录、语言转化、练习和记忆沉淀，而不是展示功能清单。
- 明确第一轮 UI 收敛的实施顺序。
- 保持真实能力边界：本轮不接入真实数据库、真实 AI、TTS、OCR、Speech、同步、StoreKit 或真实权限流程。
- 将审核结果写回本任务方案，作为后续实施依据。

## 4. 范围

本任务会检查：

- `LangoTraceApp/`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/`
- `Packages/LangoTraceData/Sources/LangoTraceData/`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md`
- `docs/testing/README.md`

页面覆盖清单：

- 启动与引导：Welcome、Onboarding、缺少语言空间时的路由保护。
- iPhone：顶层信息架构、`今日 / 记录 / 练习 / 记忆 / 设置` 五个 Tab 的必要性和重复性、设置入口是否应保留为 Tab、Entry 创建 sheet、Entry 详情、PracticeSession、Settings detail、unavailable sheet、首次创建语言空间页信息密度。
- iPad：顶部工作台工具条、左侧时间线、筛选、主内容区、右侧学习面板、左右面板收起 / 展开、Entry 创建 sheet、设置详情和 unavailable 状态。
- macOS：Sidebar、Toolbar、主工作区、Inspector、Sidebar / Inspector 收起、新建记录 sheet、设置能力详情、左侧栏底部三个图标入口和 unavailable 状态。
- 共享组件：语言空间 footer、能力状态 badge、Entry timeline row、Entry detail header、Sentence pair、Practice controls、Request preview、Memory item、Unavailable state。
- 视觉与交互覆盖：整体配色、背景层次、卡片和分组策略、按钮层级、toolbar / tab / sidebar / inspector 入口、控件触达、滚动反馈、空状态、错误状态、长文案和本地化文案。
- 状态覆盖：无语言空间、无记录、Local Mock、AI Provider 未配置、同步未启用、请求预览、不可用能力、保存失败预留、权限未接入预留。

本任务预计在审核结论确认后修改：

- 三端 UI 相关 SwiftUI 文件。
- 共享 UI 组件。
- 设计 token。
- 相关 UI 测试。
- 本任务方案的实施记录和验证结果。

## 5. 不做什么

本轮不处理：

- 不引入 SQLite / GRDB schema、迁移、FTS、附件存储或导出。
- 不实现真实 AI Provider 请求、真实 API Key 保存或 Keychain 流程。
- 不实现真实 TTS、录音、Speech、OCR、照片权限或相机权限。
- 不实现同步引擎、CloudKit、WebDAV、S3、R2 或冲突处理。
- 不实现 StoreKit、购买、恢复购买、授权状态或 App Store 发布材料。
- 不重写核心产品决策，不改变“一个语言空间对应一门目标语言”。
- 不在本轮直接实现语言空间删除、数据级联删除、恢复、导出或同步冲突处理；本轮只审查是否需要该能力及其产品、交互、数据和安全边界。
- 不把 Local Mock 写成真实能力。

## 6. 证据与决策依据

文档依据：

- `docs/README.md`：当前优先级是首次启动引导与语言空间最小闭环、本地记录和英语示例学习闭环，再进入真实 AI、TTS、SQLite、同步和 StoreKit。
- `docs/product-main-reference.md`：产品核心是“用生活记录学习语言”，不是 AI 聊天、背单词、课程或云端平台绑定。
- `docs/technical-framework-roadmap.md`：iPhone + iPad MVP 优先，Mac 后续增强为深度工作台；SQLite / GRDB 是长期主存储候选；Provider 和 Sync Adapter 保留边界。
- `docs/spec/003-ui-design-system.md`：UI 应安静、清晰、长期可读，状态表达必须可信，不能用装饰替代产品结构。
- `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md`：付费级 UI 来自信息层级、平台差异、状态可信和工程完成度。
- `docs/development/mvp-development-roadmap.md`：当前阶段应从继续搭页面转入全面审核、设计收敛和领域边界校准。

代码依据：

- `PhoneMainView.swift`：iPhone 已有五 Tab、Entry 创建 sheet、详情、练习和设置路由。
- `PadMainView.swift`：iPad 已有三栏工作台、面板切换、筛选、Entry 选择和学习面板。
- `MacMainView.swift`：macOS 已有 Sidebar、Toolbar、Inspector 和 mock Entry 创建。
- `LangoTraceDesign.swift`：已有基础 token，但仍需复核 token 是否覆盖页面状态和长期设计系统需求。
- `navigation/impl.md`：已记录 macOS Settings scene、commands、快捷键、语言空间启动恢复等已知偏差。

## 7. 涉及的代码文件路径

预计审核并可能修改：

- `LangoTraceApp/LangoTraceApp.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadWorkspaceBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadSidebarControls.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ContentUtilityComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/UnavailableCapabilityView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/`

## 8. 参考的代码文件路径

只读参考：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/`
- `Packages/LangoTraceData/Sources/LangoTraceData/`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PadPanelGestureTests.swift`

## 9. 涉及的文档路径

已新增：

- `docs/development/mvp-development-roadmap.md`

本任务方案：

- `docs/plans/active/2026-05-18-feature-comprehensive-ui-review-and-design-uplift.md`

预计审核或同步检查：

- `docs/development/README.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md`
- `docs/testing/README.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.1 审核准备

1. 读取入口和相关规范：
   - `AGENTS.md`
   - `docs/development/mvp-development-roadmap.md`
   - `docs/product-main-reference.md`
   - `docs/spec/002-navigation-and-routing.md`
   - `docs/spec/003-ui-design-system.md`
   - `docs/spec/004-swiftui-architecture.md`
   - `docs/spec/006-interface-localization-and-language-boundaries.md`
   - `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
   - `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md`
2. 读取三端主页面和共享组件：
   - iPhone：`PhoneMainView.swift`、`PhoneMainSections.swift`、`PhoneMainSupportingViews.swift`
   - iPad：`PadMainView.swift`、`PadMainSections.swift`、`PadWorkspaceBar.swift`、`PadSidebarControls.swift`
   - macOS：`MacMainView.swift`、`MacWorkspaceContentView.swift`、`MacInspectorContent.swift`
   - 共享：`LearningContentComponents.swift`、`ContentUtilityComponents.swift`、`LangoTraceDesign.swift`
3. 盘点页面入口、路由、sheet、unavailable 能力、Local Mock 数据和设置能力。

### 11.2 专业 skill 调用要求

本轮审核必须显式调用并按结论引用以下专业 skill，不能只凭主观审美判断：

- `ui-ux-pro-max`：用于整体 UI/UX、信息层级、视觉质量、配色、控件密度、导航、状态反馈和产品级设计判断。
- `ios-design-guidelines`：用于 iPhone 顶层 Tab、NavigationStack、sheet、toolbar、单手触达、44pt 触控目标、Dynamic Type、系统手势和 iOS 平台习惯审查。
- `ipados-design-guidelines`：用于 iPad 多栏布局、Split View、Stage Manager、pointer / keyboard、toolbar、sidebar 和大画布信息密度审查。
- `macos-design-guidelines`：用于 macOS Sidebar、Toolbar、Inspector、Settings scene、菜单栏、commands、窗口尺寸和键盘快捷键审查。
- `swiftui-pro` 或 `swiftui-expert-skill`：用于 SwiftUI 结构、NavigationStack / NavigationSplitView、状态流、View 组合、现代 API、性能和可维护性审查。
- `iOS SwiftUI Accessibility`：用于 VoiceOver、Dynamic Type、触控目标、颜色对比、accessibility label / value / hint、Reduce Motion 和可访问状态审查。

按问题触发调用：

- `verification-before-completion`：在声称审核完成、实现完成、测试通过或准备提交前必须使用，并记录新鲜验证证据。
- `requesting-code-review`：如果第一轮 UI 收敛进入较大范围 SwiftUI 修改，完成后应使用该 skill 做提交前复审。
- `systematic-debugging`：如果审核或验证中发现具体 UI bug、测试失败、构建失败或状态异常，先用该 skill 定位原因再修复。

审核输出中必须记录实际使用了哪些 skill，以及每个 skill 对应支撑了哪些结论。若某个必须 skill 无法使用，必须记录原因、替代依据和剩余风险。

### 11.3 子代理执行方式

为避免一次性上下文过大导致判断互相污染，本轮审核推荐使用子代理，但必须保持“分域审查、主代理整合”的边界：

- 主代理负责读取本方案、产品主参考、核心规范、汇总所有结论、消除跨平台冲突，并最终写入本方案和审查产物。
- 子代理不继承主会话历史；每个子代理只接收本方案、必要文档路径、明确文件范围、必须调用的 skill 和输出模板。
- 子代理默认只读审查，不直接修改代码或规范文档；除非用户确认进入实现阶段。
- 子代理之间不得各自改写同一份结论源。所有结论先写入各自报告，再由主代理合并。
- 主代理必须复核子代理结论，不能直接采纳；若子代理结论冲突，以产品定位、核心决策、代码证据和平台规范重新裁决。

建议拆分为以下审查子代理：

- 产品与信息架构审查：聚焦产品定位、语言空间生命周期、`Space -> Entry -> Rendering -> Practice -> Memory`、iPhone Tab 是否重复、设置入口层级。
- iPhone / iOS 交互审查：聚焦 Welcome、Onboarding、首次创建语言空间、五 Tab、sheet、NavigationStack、信息密度、单手触达、Dynamic Type。
- iPadOS 交互审查：聚焦三栏工作台、时间线、学习面板、面板收起、Split View、Stage Manager、pointer / keyboard。
- macOS 交互审查：聚焦 Sidebar、Toolbar、Inspector、左侧栏底部三个图标入口、Settings scene、menu / commands、窗口行为。
- 设计系统与视觉审查：聚焦 `LangoTraceDesign`、配色、材质、层级、组件一致性、空状态、错误状态、长文案和深浅色模式。
- SwiftUI 架构与规范契合审查：聚焦 View 结构、状态流、repository / provider 边界、导航实现、测试覆盖、docs 规范与代码偏差。
- 可访问性与本地化审查：聚焦 VoiceOver、Dynamic Type、触控目标、颜色对比、accessibility label / value / hint、界面语言边界和长文案。

如果当前会话不使用子代理，也必须按以上分域顺序逐项审查，并在过程日志中说明未使用子代理的原因和剩余风险。

### 11.4 审查产物与拆分规则

如果审核内容较少，可以直接追加到本方案的实施记录中；如果内容超过单文件可读范围，必须拆分为审查子文档，并在本方案中只保留索引、关键结论和完成状态。

推荐产物目录：

```text
docs/review/rounds/2026-05-18-comprehensive-ui-review/
  README.md
  process-log.md
  page-map.md
  findings.md
  skill-evidence.md
  spec-gap-review.md
  subagent-reports/
    product-information-architecture.md
    ios-interaction.md
    ipados-interaction.md
    macos-interaction.md
    visual-design-system.md
    swiftui-architecture.md
    accessibility-localization.md
```

产物职责：

- `README.md`：最终审查摘要、审查范围、代码快照、关键结论、P0-P3 问题索引、第一轮 UI 收敛建议、剩余风险。
- `process-log.md`：记录审查过程、读取的文档和代码、使用的 skill、子代理分工、关键分歧、复查动作和验证命令。
- `page-map.md`：记录每个平台的页面 / 入口 / 状态 / 产品对象 / 主动作 / 风险 / 保留或重构结论。
- `findings.md`：按 P0-P3 记录完整问题清单，每条问题包含证据、影响、优化方向和复查方法。
- `skill-evidence.md`：记录每个专业 skill 支撑了哪些结论，避免结论只来自主观审美。
- `spec-gap-review.md`：记录 docs 规范完整性、代码与规范偏差、需要更新的规范文档。
- `subagent-reports/`：保存每个分域子代理的原始审查报告，便于二轮复查追溯。

本方案实施记录必须同步写入上述产物路径、当前状态和最终结论摘要，不能只把结果留在子文档中。

### 11.5 二轮复查机制

第一轮审查完成后，必须进行第二轮复查，复查目标不是重新写一遍报告，而是验证第一轮结论是否完整、证据是否充分、是否存在跨平台冲突。

二轮复查必须检查：

- 是否所有页面、入口、状态和共享组件都进入 `page-map.md`。
- 是否每个 P0 / P1 问题都有代码路径、文档依据、skill 依据、优化方向和复查方法。
- 是否遗漏用户特别提出的问题：iPhone Tab 重复、设置入口层级、语言空间删除、macOS 底部三个图标、iOS 首次创建页信息密度。
- 是否每个结论都回扣产品定位和愿景，而不是只从视觉偏好出发。
- 是否有子代理结论互相冲突，主代理是否给出裁决依据。
- 是否有应更新的 spec、architecture、testing 或 review 文档未记录。
- 是否第一轮 UI 收敛建议过大，需要拆分新的 active plan。

二轮复查结果写入 `README.md` 的 `Second Review` 小节，并在 `process-log.md` 记录复查时间、复查人或代理、复查输入和结论。

### 11.6 独立交接上下文要求

AI 单独拿到本方案时，必须能在不依赖聊天记录的情况下执行任务。因此实施前必须确认本方案或其引用文档已经提供以下上下文：

- 产品北极星：语迹 / LangoTrace 是“用生活记录学习语言”的本地优先个人语言记忆系统。
- 核心否定边界：不是 AI 聊天、不是背单词、不是课程驱动、不是云端账号优先产品。
- 核心产品对象：Language Space、Entry、Rendering、Practice、Memory、Settings。
- 当前阶段边界：只处于真实数据库、真实 AI、真实语音、真实同步和 StoreKit 之前的早期阶段。
- 不可突破决策：一个语言空间对应一门目标语言；真实能力不能用 Local Mock 伪装；敏感内容只有用户明确触发 AI 能力才发送给 Provider。
- 重点审查问题：iPhone 五 Tab、语言空间删除、iOS 首次创建页信息密度、macOS 底部图标入口、docs 规范完整性、代码与规范契合。
- 必须调用的 skill、审查产物路径、输出模板、完成标准和验证命令。

如果执行者发现上述上下文仍不足，必须先补充方案或审查产物结构，再开始正式审核。

### 11.7 审核矩阵

按以下矩阵记录问题：

| 维度 | 审核问题 | 结论类型 | 必须给出的证据 |
| --- | --- | --- | --- |
| 产品定位和愿景 | 页面层次是否始终服务“用生活记录学习语言”和本地优先个人语言记忆系统，是否偏向 AI 聊天、课程、背单词或功能展示 | 保留 / 调整 / 重构 / 删除入口 | `docs/product-main-reference.md`、页面路径、主动作、信息层级 |
| 产品闭环 | 页面是否服务 `Space -> Entry -> Rendering -> Practice -> Memory` | 保留 / 合并 / 删除入口 / 调整 / 重构 | 页面路径、对应模型、缺口 |
| 语言空间生命周期 | 是否应该允许用户删除语言空间；如果允许，最后一个语言空间、关联 Entry / Practice / Memory、导出、撤销、确认和未来同步冲突边界是否清晰 | 保留不可删 / 允许删除但需强确认 / 拆新方案 | 产品依据、数据规范、路由回退、未来存储和同步风险 |
| iPhone 信息架构 | `今日 / 记录 / 练习 / 记忆 / 设置` 是否都是顶层目的地，是否存在 `今日` 和 `记录` 功能重复，设置是否应降为图标或系统入口 | 保留 / 合并 / 删除入口 / 改为 toolbar 或 sheet | Tab、sheet、NavigationStack 路径、Apple 平台依据 |
| iPhone 交互 | 是否聚焦快速记录、短练习和清晰返回路径；首次创建语言空间页是否信息过密，是否应延后隐私、AI、同步、词典和 Prompt 设置说明 | 通过 / 需优化 / 大改 | Tab、sheet、NavigationStack 路径、截图、单手触达和返回路径 |
| iPad | 三栏是否服务时间线、主内容和学习面板，是否适配 Split View、Stage Manager 和 pointer / keyboard 使用 | 通过 / 需优化 / 大改 | 选择状态、面板状态、窄窗口策略、toolbar 和 sidebar 责任 |
| macOS | Sidebar、Toolbar、Inspector、菜单栏和 Settings scene 是否承担不同职责；左侧栏底部三个图标按钮是否都进入设置，是否语义重复 | 通过 / 需优化 / 大改 | Sidebar section、底部图标入口、toolbar command、Inspector 内容、menu / commands 缺口 |
| 页面设计 | 页面布局、信息层级、控件密度、滚动结构和空状态是否达到 Apple 应用完成度 | 通过 / 需优化 / 大改 | 截图、视图路径、组件路径、平台 HIG 依据 |
| 整体配色 | 色彩、材质、强调色、状态色和深浅色模式是否服务产品气质且可持续 | 通过 / 需优化 / 重建 token | `LangoTraceDesign`、页面截图、可访问性依据 |
| 状态真实性 | Mock、未配置、不可用和外部请求边界是否可信 | 通过 / 需优化 | 文案、状态 badge、不可用页、请求预览 |
| 设计系统 | token、组件、状态、无障碍和本地化是否稳定 | 通过 / 需优化 / 补规范 | `LangoTraceDesign`、共享组件、测试或截图 |
| 规范文档 | docs 下导航、UI、SwiftUI 架构、AI 隐私和本地化规范是否全面完整，是否覆盖当前页面决策 | 通过 / 需更新 / 需拆新规范 | 文档路径、缺口、与代码差异 |
| skill 依据 | 结论是否引用了应调用的专业 skill，而不是只给主观审美意见 | 通过 / 补审 / 重审 | skill 名称、适用结论、引用到的审查维度 |
| 代码规范契合 | 当前 SwiftUI 实现是否符合 docs 规范和 Apple 平台交互原则 | 通过 / 需优化 / 需重构 | 代码路径、规范条款、偏差 |
| 工程边界 | View 是否保持可替换 repository / provider 边界 | 通过 / 需优化 | 依赖注入、repository 调用、transient state |

问题严重程度：

- `P0`：会误导用户认为真实 AI、同步、权限、数据库或 StoreKit 已可用；或破坏核心路由和学习闭环。
- `P1`：明显影响主路径、顶层信息架构、三端平台体验、可访问性、本地化、状态可信度或后续真实数据接入。
- `P2`：影响付费级完成度、视觉一致性、组件复用或信息层级，但不阻断核心路径。
- `P3`：局部文案、视觉密度、轻微布局或后续增强建议。

### 11.8 审核输出

在本任务方案的实施记录中追加：

- 页面地图。
- 三端覆盖矩阵。
- 产品对象覆盖矩阵。
- 产品定位和愿景对齐结论，必须说明每个顶层入口如何服务生活记录、语言转化、练习或记忆沉淀。
- 语言空间生命周期结论，必须明确是否建议允许删除，以及删除能力是否需要拆分新的 active plan。
- iOS 首次创建语言空间页信息密度结论，必须基于截图、代码和 iOS 平台交互依据判断是否需要精简。
- macOS 左侧栏底部图标入口结论，必须说明三个入口是否应分别代表不同能力、合并、删除或改为菜单 / toolbar / Settings scene。
- 专业 skill 使用记录，列出 `ui-ux-pro-max`、`ios-design-guidelines`、`ipados-design-guidelines`、`macos-design-guidelines`、SwiftUI 审查 skill 和可访问性 skill 分别支撑了哪些判断。
- 顶层导航和信息架构结论，必须包含 iPhone 五 Tab 是否保留、合并或降级入口的判断。
- Apple 平台交互审查结论，分别覆盖 iPhone、iPad 和 macOS。
- 设计规范文档完整性审查结论，明确哪些 docs 需要更新。
- 代码与规范契合度审查结论，明确偏差路径。
- 问题清单，按严重程度排序。
- 每个问题包含：
  - 问题描述。
  - 决策依据。
  - 涉及代码文件路径。
  - 优化方向。
  - 复查方法。
- 不处理项和后续任务拆分建议。
- 第一轮 UI 收敛任务拆分。

审核记录格式：

```text
编号：
严重程度：P0 / P1 / P2 / P3
问题描述：
决策依据：
项目定位和愿景影响：
使用的 skill：
涉及代码文件路径：
涉及文档路径：
优化方向：
复查方法：
是否进入第一轮 UI 收敛：
后续任务：
```

页面地图格式：

```text
平台：
页面 / 入口：
当前状态：真实 / Local Mock / 只读说明 / unavailable
对应产品对象：Space / Entry / Rendering / Practice / Memory / Settings
主要动作：
外部请求或权限风险：
审核结论：保留 / 调整 / 重构 / 降级占位
```

### 11.9 第一轮 UI 收敛原则

第一轮只修影响核心闭环和付费级完成度的问题：

- 页面入口、层级或视觉重点偏离“用生活记录学习语言”的产品主旨。
- 主路径不清。
- 顶层信息架构重复或不符合平台习惯，例如 iPhone Tab 语义重叠或设置入口层级过重。
- 生命周期入口缺少清晰边界，例如语言空间删除能力不可见、误触风险高，或删除后路由 / 数据 / 同步边界不清。
- onboarding 或首次创建页信息过密，过早展示后续设置，阻断“先创建语言空间”的主路径。
- macOS 多个图标入口进入同一设置界面，造成入口语义重复或用户预期落空。
- 状态误导。
- 三端平台习惯冲突。
- 整体配色、视觉层级或控件密度明显削弱付费级质感。
- 文字、按钮、状态标签溢出或遮挡。
- 核心组件状态不一致。
- 设计 token 明显不够支撑已有页面。
- docs 规范缺失、过期或与代码实现冲突。
- View 边界会阻碍后续真实 repository / provider 接入。

第一轮不处理真实基础设施，也不新增大范围页面。

### 11.10 文档收口

完成审核和优化后：

- 更新本任务方案的实施记录、验证结果、剩余风险。
- 如果改变长期 UI 规则，更新 `docs/spec/003-ui-design-system.md` 或 `docs/spec/ui-design/` 对应规格。
- 如果改变导航或 SwiftUI 架构边界，更新 `docs/spec/002-navigation-and-routing.md` 或 `docs/spec/004-swiftui-architecture.md`。
- 如果只修页面实现细节，不新增长期规则，在本方案中记录即可。

## 12. 复查方法

文档复查：

- 检查本方案是否包含问题描述、决策依据、涉及代码文件路径、优化方向和复查方法。
- 检查 `docs/development/mvp-development-roadmap.md` 是否只记录跨任务路线，不替代 active plan。
- 检查审核结论是否逐项回扣 `docs/product-main-reference.md` 的产品定位、产品不是、产品是、主 slogan 和本地优先边界。
- 检查本方案实施记录是否列出实际调用的专业 skill，以及每个 skill 支撑的结论。
- 检查相关设计规范文档是否全面覆盖顶层导航、页面布局、配色、状态、Apple 平台入口和代码实现约束。
- 检查代码实现是否与 `docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/006-interface-localization-and-language-boundaries.md` 及 `docs/spec/ui-design/` 规范契合。
- 检查没有把真实 AI、数据库、同步、StoreKit 写成已完成能力。

代码复查：

- 对照三端主页面确认每个主入口都有反馈。
- 对照 iPhone 顶层 Tab 确认每个 Tab 都是互不重复的顶层目的地；若不是，必须记录合并、降级或删除建议。
- 对照截图和代码确认 iOS 首次创建语言空间页的信息密度是否合理，是否需要把本地保存、AI、同步、词典和 Prompt 等说明后移到设置或渐进披露。
- 对照 macOS 代码确认左侧栏底部三个图标按钮的目标、命名、可访问标签和实际跳转是否一致。
- 对照数据和隐私规范确认语言空间删除若进入后续任务，需要哪些不可跨越的确认、导出、回退和同步边界。
- 对照 `LangoTraceDesign` 确认新增视觉规则进入 token 或共享组件。
- 对照 UI 测试确认 route、panel、settings 和状态映射仍被覆盖。

手动复查：

- iPhone：Welcome、Onboarding、五 Tab、Entry 创建、详情、练习、设置。
- iPad：三栏默认状态、左右面板收起、时间线选择、学习面板、设置详情。
- macOS：默认窗口、Sidebar 收起、Inspector 收起、新建记录、设置和 unavailable 状态。

## 13. 验证命令

文档阶段：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

实现阶段：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

如果 `scripts/verify.sh` 因当前环境缺少工具、模拟器或格式化器失败，必须记录失败命令、失败原因和剩余风险。

## 14. 文档影响检查

本任务新增长期开发路线文档：

- `docs/development/mvp-development-roadmap.md`

本任务新增 active plan：

- `docs/plans/active/2026-05-18-feature-comprehensive-ui-review-and-design-uplift.md`

预计不需要新增 ADR，因为本任务不改变以下核心决策：

- SwiftUI Multiplatform。
- 一个语言空间对应一门目标语言。
- 本地优先和用户自带 Provider。
- SQLite / GRDB 作为长期主存储候选。
- Sync Engine + Adapter。
- 第一版买断制、单人使用。

如果审核后建议改变上述任何决策，必须另行新增或更新 ADR，并在用户确认记录中写明确认范围。

## 15. 实施记录

2026-05-18：创建本任务方案，并新增 `docs/development/mvp-development-roadmap.md` 作为跨任务开发路线事实源。

2026-05-18：用户确认本方案已经通过审核，本方案进入执行状态。已按方案完成全面 UI / 设计 / 规范 / 代码契合度审查，审查产物写入：

- `docs/review/rounds/2026-05-18-comprehensive-ui-review/README.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/process-log.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/page-map.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/findings.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/skill-evidence.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/spec-gap-review.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/`

本轮实际调用并使用的专业 skill：

- `ui-ux-pro-max`
- `ios-design-guidelines`
- `ipados-design-guidelines`
- `macos-design-guidelines`
- `swiftui-pro`
- `iOS SwiftUI Accessibility`
- `verification-before-completion`

本轮使用 6 个只读子代理完成分域审查：产品与信息架构、iPhone / iOS、iPadOS、macOS、设计系统与视觉、SwiftUI 架构与规范契合。由于会话子代理数量达到上限，可访问性与本地化审查由主线程补审并写入 `subagent-reports/accessibility-localization.md`。

审核主裁决：

- iPhone 顶层 IA 不应继续默认保留 `今日 / 记录 / 练习 / 记忆 / 设置` 五 Tab。`今日` 与 `记录` 存在 Entry 创建和记录发现重复，`设置` 作为底部 Tab 层级过重。第一轮 UI 收敛建议合并 `今日 / 记录`，将 `设置` 降级为 toolbar / 语言空间菜单 / 系统设置入口。
- 语言空间长期应允许删除，但必须拆新的 active plan 定义删除、最后空间回退、关联 Entry / Rendering / Practice / Memory / 附件、导出、撤销和未来同步 tombstone 边界；本轮不直接实现删除。
- iOS 首次创建语言空间页的三项基础表单和底部创建按钮合理，但 Welcome / Onboarding 不应过早暴露 AI、同步、词典和 Prompt 等后续能力说明。
- macOS 底部 AI / Sync / Settings 三个图标不应表现为三个等价设置入口；AI / Sync 应是状态或配置详情入口，gear 才是通用设置。macOS 还缺少 `Settings` scene、commands 和键盘快捷键。
- iPad 三栏方向保留，但当前固定宽度 HStack 和左栏职责过重，需要补宽度断点、keyboard / pointer、稳定配置入口和状态驱动右侧学习 Inspector。
- 设计系统应先扩展 token、状态矩阵、action hierarchy 和 empty / unavailable pattern，再做逐页视觉提升。
- SwiftUI 架构需要修复 interface-language resolver、repository seam、`contentRevision` 扩散和 `SentencePairView` Listen 空 action。

2026-05-18：归档复查确认，本方案可以移入 `done/`。依据：

- 审查任务本身已经完成，审查产物写入 `docs/review/rounds/2026-05-18-comprehensive-ui-review/`，并包含 `completion-audit.md`。
- 第一轮 UI 收敛、规范同步和对应测试已经由 `docs/plans/done/2026-05-18-feature-first-round-ui-convergence.md` 承接并完成，状态为 `Verified`。
- 语言空间添加、切换和删除已拆为独立 active plan：`docs/plans/active/2026-05-18-feature-language-space-lifecycle-and-deletion.md`。
- 本方案不再承担未完成实现任务；后续真实语言空间持久化、生命周期、真实 AI / TTS / 同步 / StoreKit 仍由各自 active plan 承接。

## 16. 完成标准

本任务可以从 `active/` 移入 `done/` 的条件：

- 全面审核已完成，并写入本方案实施记录。
- 已记录实际调用的专业 skill，且核心结论有对应 skill 依据。
- 已完成产品定位和愿景对齐审查，确认页面层次紧扣“用生活记录学习语言”的主旨和本地优先个人语言记忆系统定位。
- 已明确判断当前页面实现是否应保留、合并、删除入口、重构或大改，不能默认现有实现基本成立。
- 已完成 iPhone 顶层 Tab 合理性审查，明确 `今日` / `记录` 是否重复，以及 `设置` 是否应继续作为 Tab。
- 已完成语言空间删除能力的产品和边界审查，明确本轮是否只记录结论或拆分后续 active plan。
- 已完成 iOS 首次创建语言空间页信息密度审查，明确是否需要精简或渐进披露。
- 已完成 macOS 左侧栏底部三个图标入口审查，明确是否重复、是否应合并或重新分配入口职责。
- 已完成 docs 设计规范完整性审查，并记录需要更新的规范文档。
- 已完成代码实现与相关规范契合度检查，并记录偏差。
- 已形成按严重程度排序的问题清单。
- 已完成第一轮 UI 收敛或明确拆分出后续 active plan。
- 相关 SwiftUI 修改通过对应 package 测试。
- `scripts/verify.sh` 通过，或记录无法运行的明确原因和剩余风险。
- 文档占位扫描、`git diff --check` 和 `git status --short` 已执行并记录结果。
- 若长期 UI、导航或架构规则发生变化，相关 spec 已同步更新。

## 17. 剩余风险

- 当前任务范围较大，审核后可能需要拆分为 iPhone、iPad、macOS 或设计系统多个子任务。
- 如果第一轮 UI 收敛触及真实数据、AI、权限或同步边界，必须先创建新的 active plan。
- 由于当前语言空间仍未持久化，截图和手动验证可能受重启后回到 onboarding 的限制影响。
- macOS 菜单栏、Settings scene、commands 和快捷键仍是已知后续能力，不作为本轮完成标准。
