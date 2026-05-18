# 任务方案：全面页面审核与设计提升

状态：Draft
类型：feature
创建日期：2026-05-18
最后更新日期：2026-05-18

## 用户确认记录

状态为 `Draft` 时不能开始实现。用户确认后记录确认时间、确认内容和范围边界。

当前用户要求：

- 将整体开发规划沉淀为 Markdown 文档，放入 docs 文档框架对应目录。
- 创建本任务方案，记录页面审核和优化计划。

本方案当前只完成计划记录，尚未进入页面审核和代码修改。

## 1. 需求或 bug 描述

当前项目大部分页面已经搭建完成，但页面数量增加后，需要进行一轮系统性的审核和设计提升，确认现有 iPhone、iPad、macOS 页面是否真正服务 LangoTrace 的核心学习闭环，并形成可执行的优化计划。

本任务不是简单美化，也不是继续增加页面，而是先从产品、交互、平台、状态真实性、设计系统和工程边界六个维度完成审查，再按审查结论推进第一轮 UI 收敛。

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
- 当前 UI 是否过度依赖 `InMemoryLearningContentRepository`、`contentRevision` 和 View 内 transient state，需要复核。
- 设计 token、组件、状态、无障碍、本地化和截图验证是否已经足够支撑后续真实功能，需要复核。

## 3. 目标

本任务完成后必须达到：

- 形成现有三端页面和关键二级页的审核清单。
- 形成页面级、组件级、设计系统级和工程边界级问题清单。
- 明确哪些页面保留、哪些重构、哪些降级为占位、哪些需要补充状态。
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
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md`
- `docs/testing/README.md`

页面覆盖清单：

- 启动与引导：Welcome、Onboarding、缺少语言空间时的路由保护。
- iPhone：今日、记录、练习、记忆、设置、Entry 创建 sheet、Entry 详情、PracticeSession、Settings detail、unavailable sheet。
- iPad：顶部工作台工具条、左侧时间线、筛选、主内容区、右侧学习面板、左右面板收起 / 展开、Entry 创建 sheet、设置详情和 unavailable 状态。
- macOS：Sidebar、Toolbar、主工作区、Inspector、Sidebar / Inspector 收起、新建记录 sheet、设置能力详情和 unavailable 状态。
- 共享组件：语言空间 footer、能力状态 badge、Entry timeline row、Entry detail header、Sentence pair、Practice controls、Request preview、Memory item、Unavailable state。
- 状态覆盖：无语言空间、无记录、Local Mock、AI Provider 未配置、同步未启用、请求预览、不可用能力、保存失败预留、权限未接入预留、长文案和本地化文案。

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
- `docs/spec/006-interface-localization-and-language-boundaries.md`
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

### 11.2 审核矩阵

按以下矩阵记录问题：

| 维度 | 审核问题 | 结论类型 | 必须给出的证据 |
| --- | --- | --- | --- |
| 产品闭环 | 页面是否服务 `Space -> Entry -> Rendering -> Practice -> Memory` | 保留 / 调整 / 重构 | 页面路径、对应模型、缺口 |
| iPhone | 是否聚焦快速记录、短练习和清晰返回路径 | 通过 / 需优化 | Tab、sheet、NavigationStack 路径 |
| iPad | 三栏是否服务时间线、主内容和学习面板 | 通过 / 需优化 | 选择状态、面板状态、窄窗口策略 |
| macOS | Sidebar、Toolbar、Inspector 是否承担不同职责 | 通过 / 需优化 | Sidebar section、toolbar command、Inspector 内容 |
| 状态真实性 | Mock、未配置、不可用和外部请求边界是否可信 | 通过 / 需优化 | 文案、状态 badge、不可用页、请求预览 |
| 设计系统 | token、组件、状态、无障碍和本地化是否稳定 | 通过 / 需优化 | `LangoTraceDesign`、共享组件、测试或截图 |
| 工程边界 | View 是否保持可替换 repository / provider 边界 | 通过 / 需优化 | 依赖注入、repository 调用、transient state |

问题严重程度：

- `P0`：会误导用户认为真实 AI、同步、权限、数据库或 StoreKit 已可用；或破坏核心路由和学习闭环。
- `P1`：明显影响主路径、三端平台体验、可访问性、本地化、状态可信度或后续真实数据接入。
- `P2`：影响付费级完成度、视觉一致性、组件复用或信息层级，但不阻断核心路径。
- `P3`：局部文案、视觉密度、轻微布局或后续增强建议。

### 11.3 审核输出

在本任务方案的实施记录中追加：

- 页面地图。
- 三端覆盖矩阵。
- 产品对象覆盖矩阵。
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

### 11.4 第一轮 UI 收敛原则

第一轮只修影响核心闭环和付费级完成度的问题：

- 主路径不清。
- 状态误导。
- 三端平台习惯冲突。
- 文字、按钮、状态标签溢出或遮挡。
- 核心组件状态不一致。
- 设计 token 明显不够支撑已有页面。
- View 边界会阻碍后续真实 repository / provider 接入。

第一轮不处理真实基础设施，也不新增大范围页面。

### 11.5 文档收口

完成审核和优化后：

- 更新本任务方案的实施记录、验证结果、剩余风险。
- 如果改变长期 UI 规则，更新 `docs/spec/003-ui-design-system.md` 或 `docs/spec/ui-design/` 对应规格。
- 如果改变导航或 SwiftUI 架构边界，更新 `docs/spec/002-navigation-and-routing.md` 或 `docs/spec/004-swiftui-architecture.md`。
- 如果只修页面实现细节，不新增长期规则，在本方案中记录即可。

## 12. 复查方法

文档复查：

- 检查本方案是否包含问题描述、决策依据、涉及代码文件路径、优化方向和复查方法。
- 检查 `docs/development/mvp-development-roadmap.md` 是否只记录跨任务路线，不替代 active plan。
- 检查没有把真实 AI、数据库、同步、StoreKit 写成已完成能力。

代码复查：

- 对照三端主页面确认每个主入口都有反馈。
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

页面审核尚未开始。

## 16. 完成标准

本任务可以从 `active/` 移入 `done/` 的条件：

- 全面审核已完成，并写入本方案实施记录。
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
