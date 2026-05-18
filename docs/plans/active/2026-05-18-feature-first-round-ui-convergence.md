# 任务方案：第一轮 UI 收敛与规范同步

状态：In Progress
类型：feature
创建日期：2026-05-18
最后更新日期：2026-05-18

## 0. 新会话实施入口

新会话实施本方案时，先按以下顺序恢复上下文：

1. 读取 `AGENTS.md`，确认项目北极星、早期重构原则、active plan 规则和完成前检查。
2. 读取本文档全文，特别是 `11.2 任务分解`、`15. 审查报告修复项覆盖矩阵`、`17. 完成标准`。
3. 读取审核事实源：
   - `docs/review/rounds/2026-05-18-comprehensive-ui-review/README.md`
   - `docs/review/rounds/2026-05-18-comprehensive-ui-review/findings.md`
   - `docs/review/rounds/2026-05-18-comprehensive-ui-review/spec-gap-review.md`
   - `docs/review/rounds/2026-05-18-comprehensive-ui-review/page-map.md`
   - `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/`
4. 读取并核对相关 active plan：
   - `docs/plans/active/2026-05-18-feature-comprehensive-ui-review-and-design-uplift.md`
   - `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md`
5. 运行 `git rev-parse HEAD` 和 `git status --short`。审核事实源的代码快照是 `a800317a023fcc6d0dbdd93d110879876813a328`，本方案创建时当前 HEAD 为 `6de14e5`，中间主要新增的是审核文档和本方案。若实施时 Swift 代码已经发生变化，必须先重新核对相关代码证据，再开始修改。
6. 本方案仍为 `Draft`；必须由用户在新会话中明确确认进入实现后，才能把状态改为 `User Approved` 或 `In Progress` 并开始代码修改。

实施时的最低要求：

- 不要只修 P1 主线。`15. 审查报告修复项覆盖矩阵` 中每一项都必须在实施记录中标记为已修复、已拆分、已有依赖计划或有证据延期。
- 若使用子代理，必须按平台 / 任务边界拆分，并由主会话统一集成和复查；子代理不得独立改写本方案或长期规范。
- 若实现过程中发现本方案与当前代码事实不一致，先更新本文档的实施记录和判断依据，再继续实现。

## 用户确认记录

状态为 `Draft` 时不能开始实现。用户确认后记录确认时间、确认内容和范围边界。

2026-05-18：根据 `docs/review/rounds/2026-05-18-comprehensive-ui-review/` 的审核结果，创建第一轮 UI 收敛优化方案。本方案先作为实现前确认文档，不修改 SwiftUI 代码、不更新长期规范、不移动上一轮审核方案状态。

2026-05-18：用户要求完整阅读本文档和相关上下文文档，制定计划并开始实施，将方案完整落地；每一阶段都需要测试和 commit。本次实施范围按 `11.2 任务分解` 分阶段推进。

## 1. 需求或 bug 描述

全面 UI 审核已经确认，当前三端 SwiftUI 骨架方向没有偏离“用生活记录学习语言”的产品北极星，但存在一组必须在继续真实数据、真实 AI、TTS、同步和 StoreKit 之前收敛的 P1 / P2 问题：

- iPhone `今日 / 记录` 顶层信息架构重复，`设置` 作为底部 Tab 层级过重。
- 保存 Entry 会立刻生成 mock Rendering、PracticeItem 和 MemoryItem，容易把未来真实 AI 心智误导成“保存即生成”。
- macOS 缺少 Settings scene、commands 和常用快捷键，Sidebar 与 footer 设置入口语义重复。
- iPad 仍是固定 HStack 原型，缺少足够的宽度断点、键盘、pointer、focus 和 context menu 支撑。
- 设计 token、能力状态矩阵、empty / unavailable 模式、卡片使用边界和长文案策略不足。
- 显式 App 内界面语言偏好没有实际驱动多数自有 chrome。
- iPhone / iPad / macOS View 直接依赖并 mutate `InMemoryLearningContentRepository`，`contentRevision` 作为刷新信号横跨三端。
- `SentencePairView` 的 Listen 按钮是可见空 action。
- Welcome 自动跳转、unavailable sheet、Entry editor 和部分横向 row 存在可访问性与 Dynamic Type 风险。

本方案将这些审核结论转化为一轮可执行的 UI / 架构边界 / 规范同步任务。方案必须完整覆盖审查报告中提到的所有修复项；若某项不应在本轮直接实现，必须在本文中明确写入拆分方案、依赖任务、延期原因和复查方式，不能只从实施列表中省略。

## 2. 现状描述

当前代码事实：

- `PhoneMainView.swift` 使用一个 `NavigationStack` 包裹五个 Tab：`today`、`entries`、`practice`、`memory`、`settings`。
- `PhoneMainSections.swift` 中 `TodayView` 和 `EntriesView` 都提供 Entry 创建和记录发现路径。
- `LearningContent.swift` 的 `createEntry` 在保存 Entry 后立即写入 mock Rendering、PracticeItem 和 MemoryItem。
- `MacMainView.swift` 的 footer AI / Sync / Settings 三个按钮都通过 `MacFooterAction` 进入 settings 域，`LangoTraceApp.swift` 只有 `WindowGroup`，没有 macOS `Settings` scene 或 `.commands`。
- `PadMainView.swift` 以 `HStack` 组织三栏，只通过 `horizontalSizeClass` 在 compact 时隐藏右侧学习面板。
- `LangoTraceDesign.swift` 主要是固定浅色 RGB token，状态色和 surface token 尚未覆盖 light / dark / high contrast / reduce transparency。
- `LocalizedChrome.swift` 读取 `Locale.preferredLanguages`，没有接收 `InterfaceLanguagePreference` 或 SwiftUI `locale` 环境。
- 三端 UI 直接持有 `InMemoryLearningContentRepository`，并用本地 `contentRevision` 强制刷新。
- `LearningContentComponents.swift` 的 `SentencePairView` 中 Listen 按钮 `Button {}` 没有动作。
- `UnavailableCapabilityView` 是普通说明内容，缺少作为 sheet / modal 使用时的标题、关闭、滚动和焦点返回约束。

当前文档事实：

- `docs/review/rounds/2026-05-18-comprehensive-ui-review/README.md` 状态为 `Verified`，可作为本轮依据。
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/findings.md` 已列出 P1-001 到 P1-009 和 P2 代表性问题。
- `docs/spec/002-navigation-and-routing.md` 仍写 iPhone 五 Tab，但同时要求设置低干扰、不抢主流程；需要以本轮审核结论同步修正。
- `docs/spec/003-ui-design-system.md` 已有原则，但 token、状态矩阵和模式契约仍不够具体。
- `docs/spec/004-swiftui-architecture.md` 已承认 `contentRevision` 是临时状态，但缺少明确退出条件。
- `docs/spec/006-interface-localization-and-language-boundaries.md` 要求显式语言偏好覆盖自有 chrome，但代码尚未实现。

## 3. 目标

本任务完成后应达到：

- iPhone 顶层入口收敛为互不重复的主目的地，记录生活的主动作更清晰，设置不再作为与记录、练习、记忆并列的底部 Tab。
- Entry 保存与 Rendering / Practice / Memory 生成边界显性化；用户创建 Entry 后先看到原始记录和本地示例状态，而不是被动获得一整套学习材料。
- Listen 等明显可点入口都有可见反馈，不再存在空 action。
- Welcome、Onboarding、unavailable sheet、Entry editor、sentence row 和 footer compact controls 符合基础可访问性、Dynamic Type 和 44pt 触控目标要求。
- macOS 提供 Settings scene、commands 和关键快捷键；Sidebar、footer 状态入口、gear 设置入口语义分离。
- iPad 有明确三栏 / 两栏 / 单栏断点，生产力输入至少覆盖新建、搜索、面板切换、hover / focus / context menu 的第一轮能力。
- 设计系统补齐第一轮 semantic token、状态矩阵、action hierarchy、empty / unavailable / loading / error 模式，减少无差别 `langoPanel` 堆叠。
- 显式 interface-language preference 能驱动 LangoTrace 自有 SwiftUI chrome，或者在产品文案中不承诺当前做不到的即时覆盖能力；本方案推荐实现驱动能力。
- UI 不再直接依赖 concrete `InMemoryLearningContentRepository`，而是通过 `LearningContentRepository` 协议或 MainActor feature store 访问内容。
- `docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 与代码实现保持一致。

## 4. 范围

本轮处理：

- 第一轮 iPhone IA 收敛。
- Entry / Rendering / Local Mock 状态边界。
- obvious empty action 和 unavailable / sheet 可访问性。
- interface-language resolver 和语言展示边界。
- UI 到 learning content 数据源的最小 seam。
- iPad 工作台第一轮响应式和生产力输入。
- macOS Settings scene、commands、快捷键和设置入口语义。
- 设计 token、状态矩阵和共享组件模式的第一轮落地。
- 与以上实现直接相关的 UI / Data / Core package tests。
- 与以上实现直接相关的 spec 文档同步。
- 审查报告中所有 P1 / P2 / P3 项的处理记录，包括直接修复、纳入现有 active plan、拆出新 active plan 或明确延期。

## 5. 不做什么

本轮不处理：

- 不实现真实 SQLite / GRDB schema、迁移、FTS、附件存储、导入导出或启动恢复。
- 不实现真实 AI Provider 请求、API Key 保存、Keychain、Prompt 执行链路或请求日志。
- 不实现真实 TTS、录音、Speech、OCR、Photos、相机、权限弹窗或音频播放。
- 不实现同步引擎、CloudKit、WebDAV、S3、R2、冲突处理或 sync tombstone。
- 不实现 StoreKit、购买、恢复购买或 App Store 发布材料。
- 不实现语言空间删除。本轮只把语言空间入口从 unavailable 死路调整为 Space summary / lifecycle placeholder；删除、添加、切换、最后空间回退、导出前置、级联删除、撤销窗口和未来同步边界必须拆成单独 active plan。
- 不把 mock 内容全量本地化；用户内容、seed 内容和示例学习材料可以保持当前语言，只收敛自有 UI chrome。
- 不追求最终品牌视觉系统、完整深色模式或全平台截图矩阵；本轮只建立后续可扩展的 token 和验证底座。

## 6. 证据与决策依据

核心审核依据：

- `docs/review/rounds/2026-05-18-comprehensive-ui-review/README.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/findings.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/page-map.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/spec-gap-review.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/product-information-architecture.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/ios-interaction.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/ipados-interaction.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/macos-interaction.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/visual-design-system.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/swiftui-architecture.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/subagent-reports/accessibility-localization.md`

产品与规范依据：

- `docs/product-main-reference.md`：语迹是“用生活记录学习语言”的本地优先个人语言记忆系统，不是 AI 聊天、课程驱动、背单词或云端账号中心。
- `docs/decisions/004-use-language-space-as-primary-model.md`：一个语言空间对应一门目标语言，语言空间是聚合边界但不应成为重型 Project 管理。
- `docs/decisions/005-local-first-and-user-owned-providers.md`：AI、同步和外部 Provider 必须由用户控制。
- `docs/spec/002-navigation-and-routing.md`：设置应稳定可达但低干扰，不应抢占记录和学习主流程。
- `docs/spec/003-ui-design-system.md`：状态表达必须可信，所有明显入口必须有可见反馈。
- `docs/spec/004-swiftui-architecture.md`：Mock repository 必须可被真实实现替换，View 不应承担数据层职责。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：敏感内容只有在用户明确触发相关能力时才发送给 Provider。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：显式 App 内语言偏好只覆盖自有 SwiftUI chrome，不改变语言空间和学习内容。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：主数据必须可迁移、可导出、可删除；删除边界需单独定义。

## 7. 涉及的代码文件路径

预计修改：

- `LangoTraceApp/LangoTraceApp.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningLanguage.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/OnboardingDraft.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SeedLearningContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadWorkspaceBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadSidebarControls.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceFooter.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ContentUtilityComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/UnavailableCapabilityView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PremiumUILayoutRules.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PadPanelGestureTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/InMemoryLearningContentRepositoryTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/`

如果实施时发现文件拆分能显著降低冲突和复杂度，可新增以下文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/InterfaceLocalization.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneRecordWorkspaceView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacCommandsModel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AdaptiveWorkspaceLayout.swift`

## 8. 参考的代码文件路径

只读参考：

- `Packages/LangoTraceAI/Sources/LangoTraceAI/`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/`
- `Packages/LangoTraceSync/Sources/LangoTraceSync/`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LaunchRoute.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PrivacyStatusModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedTextPanel.swift`
- `project.yml`
- `scripts/verify.sh`

## 9. 涉及的文档路径

本任务方案：

- `docs/plans/active/2026-05-18-feature-first-round-ui-convergence.md`

需要同步更新：

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/review/INDEX.md`

需要引用但默认不改：

- `docs/review/rounds/2026-05-18-comprehensive-ui-review/README.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/findings.md`
- `docs/review/rounds/2026-05-18-comprehensive-ui-review/spec-gap-review.md`
- `docs/product-main-reference.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`

## 10. bug 分析

非单一 bug 任务，不适用。

## 11. 实施方案

### 11.1 实施原则

- 本轮先收敛产品正确性和能力边界，再处理视觉修饰。
- 每个明显可点入口必须有可见反馈；如果能力未接入，反馈应是清楚的 unavailable / local mock 状态，而不是空按钮。
- 不把配置入口做成主流程；主流程优先服务 Entry、Rendering、Practice 和 Memory。
- 不为了保留早期 mock 代码而牺牲长期边界；项目仍处于早期阶段，可以重写临时 UI 结构。
- 所有设计判断必须回到“用生活记录学习语言”和 local-first / user-owned provider 边界。
- 实现时必须使用 `swiftui-pro`、`ios-design-guidelines`、`ipados-design-guidelines`、`macos-design-guidelines`、`iOS SwiftUI Accessibility` 和 `verification-before-completion`；范围较大时推荐使用子代理分工，但主代理必须统一裁决和集成。

### 11.2 任务分解

#### 任务 1：建立 learning content seam，移出 UI 对 concrete repository 的直接依赖

目的：先处理 P1-008，避免后续 iPhone / iPad / macOS UI 收敛继续绑定 `InMemoryLearningContentRepository`。

实施要点：

- 在 Data 层定义最小 `LearningContentRepository` 协议，覆盖当前 UI 真正使用的能力：entries、selectedEntry、selectEntry、createEntry、rendering、practiceItems、memoryItems、settingsCapabilities、practiceSession、ensureSeeded。
- 让 `InMemoryLearningContentRepository` conform 到该协议。
- 在 UI 层引入 MainActor store 或 observable adapter，集中处理 mutation 和刷新信号，三端 View 只依赖 store。
- `contentRevision` 不再散落在 `PhoneMainView`、`PadMainView`、`MacMainView`。
- 更新 UI tests 和 Data tests，确保 seed、select、create 和 rendering 状态仍可验证。

验收：

- `rg "InMemoryLearningContentRepository" Packages/LangoTraceUI/Sources LangoTraceApp` 只应出现在 bootstrap、store 初始化、preview 或测试 seam 中。
- 三端 View 不直接调用 concrete repository mutation。

#### 任务 2：修复真实交互风险和可访问性底线

目的：先关闭空 action 和明显可访问性风险，降低误导真实能力的风险。

实施要点：

- `SentencePairView` 接收 `onListen` 或 `listenState`，点击 Listen 后显示 local mock / unavailable 反馈；如果不提供动作，按钮禁用并有明确状态说明。
- `UnavailableCapabilityView` 支持作为 sheet 使用的标题、关闭按钮、滚动容器、可访问 heading 和焦点返回策略。
- `EntryEditorView` 的 `TextEditor` 增加明确 accessible label，并处理空标题 / 空正文提示。
- Welcome 不再 650ms 自动跳转；改为用户可理解的继续动作，或至少提供可访问性下的暂停 / 继续路径。本方案推荐改为显式“继续”。
- Onboarding 精简过早出现的 AI、同步、词典、Prompt 概念，只保留本地保存和可在设置中处理的轻量说明。
- 为 language menu、sentence row、footer compact icons 处理 44pt hit target 和 Dynamic Type reflow。

验收：

- 点击 Listen 有可见反馈。
- iPhone unavailable sheet 有可读标题、关闭路径和滚动内容。
- Welcome 对 VoiceOver 用户不再自动推进。
- UI tests 覆盖 Listen 状态、unavailable content key、Welcome intent 或 route。

#### 任务 3：实现显式界面语言偏好驱动自有 chrome

目的：修复 P1-007，使 App 内显式界面语言偏好与 006 规范一致。

实施要点：

- 让 `localizedText` / `localizedString` 通过当前 resolved interface language 或 SwiftUI locale 解析，而不是固定使用 `Locale.preferredLanguages`。
- 保留 `System` 模式以 `Bundle.main.preferredLocalizations` 与支持语言求交集为准。
- 将 `LearningLanguage` 中 `ChineseUI` display projection 迁出 Core 或改名为明确的 display policy，避免 Core 模型暗含中文界面。
- 设置页文案明确区分 App 内自有 chrome、系统权限弹窗、StoreKit、文件选择器和 Provider 错误。
- 增加测试：系统语言与 App 内选择不同，Tab / Settings / unavailable / toolbar key 能按显式偏好解析。

验收：

- 切换显式 English / 简体中文 / Español 时，自有 SwiftUI chrome 可跟随切换。
- `System` 仍遵循系统 / bundle 语言结果。
- 学习内容、语言空间目标语言和 Provider 输出不因界面语言切换而改变。

#### 任务 4：iPhone 信息架构收敛

目的：修复 P1-001，避免 `今日 / 记录` 重复和设置层级过重。

实施要点：

- 将 iPhone 顶层收敛为 `记录 / 练习 / 记忆` 三个主 Tab，或等价的三主目的地结构。
- 合并 Today 和 Entries 为 `PhoneRecordWorkspaceView`：首屏主动作是记录生活，次级内容是最近记录和当前 Entry 状态。
- 设置从底部 Tab 降级为 toolbar gear、语言空间菜单或 profile-less settings action；设置详情仍稳定可达。
- 为每个主 Tab 保留独立 navigation state，避免一个 shared `NavigationStack` 包全 Tab。
- 删除或迁移 `PhoneRootTab.today` / `.settings` 的旧测试假设。
- 文案避免“首页功能清单”，强调从生活记录开始。

验收：

- `PhoneRootTab.allCases` 不再包含重复目的地。
- iPhone 主屏 5 秒内能看到“记录生活”主动作。
- 设置稳定可达，但不占主导航。
- 路由测试覆盖记录详情、练习、记忆、设置详情。

#### 任务 5：Entry / Rendering / Practice / Memory 状态边界显性化

目的：修复 P1-003，避免保存 Entry 被理解为未来真实 AI 自动生成。

实施要点：

- 新建 Entry 后默认先显示原始 Entry 和 Rendering 状态区。
- 将 Local Mock 明确表达为“本地示例”或“本地预览”，不使用会让用户以为 AI 已生成的措辞。
- 对新 Entry 增加显式生成本地示例动作；真实 AI 接入前，该动作不外发请求，只生成 local mock rendering。
- Practice / Memory 从 Rendering 状态出发；缺少 Rendering 时显示 unavailable / next action。
- Seed 数据可继续带有 mock rendering，用于展示完整闭环；用户新建数据应体现状态边界。
- Request Preview 移到用户触发 Rendering 前或 Rendering 状态区附近。

验收：

- `createEntry` 不再默认创建完整 learning closure，或其行为命名和 UI 状态明确为 local mock preview。
- 新建 Entry 详情页先展示原文、Rendering 状态和显式本地示例入口。
- Practice / Memory 在无 Rendering 时有清楚状态。

#### 任务 6：iPad 工作台响应式和生产力输入

目的：修复 P1-005，把固定三栏原型推进到第一轮 iPad 工作台。

实施要点：

- 定义三栏、两栏、单栏断点，不只依赖 `horizontalSizeClass`。
- 左栏拆分时间线 / filter 与配置入口；隐藏左栏时，Settings / Search / New Entry 仍有稳定入口。
- 右侧学习面板改为状态驱动 Inspector：根据 selected Entry、Rendering、Practice、Memory 和 Settings route 显示内容。
- 增加 keyboard shortcuts：新建记录、搜索、切换左栏、切换右栏、进入设置。
- 为 timeline row、sentence row、filter、toolbar icon 增加 hover / focus / context menu 的第一轮支持。
- 保留现有边缘手势，但与 toolbar / keyboard 入口保持一致。

验收：

- iPad 全屏、2/3、1/2、1/3 和类 Slide Over 宽度下主内容不被配置入口挤压。
- 键盘可触发新建、搜索和面板切换。
- 隐藏左栏后 Settings / Search / New Entry 仍可达。

#### 任务 7：macOS 工作台原生性收敛

目的：修复 P1-004，让 macOS 像资料库和创作工作台，而不是放大版面板。

实施要点：

- 在 `LangoTraceApp.swift` 增加 macOS `Settings` scene，承载通用设置和只读能力边界。
- 增加 `.commands`：New Entry、Search、Toggle Sidebar、Toggle Inspector、Settings、Focus Records 或等价命令。
- 为常用动作增加 `Cmd+N`、`Cmd+F`、`Cmd+,` 和 View 菜单相关快捷键。
- Sidebar 收敛为内容域 source list；Settings / ImportExport 不再与 Today / Entries / Practice / Memory 同级，除非作为 utility section 且视觉层级明确低于内容域。
- Footer AI / Sync / gear 拆分语义：AI / Sync 是状态或配置详情入口，gear 是通用 Settings。
- 搜索从 unavailable button 向标准 search / command surface 过渡；真实搜索未接入时仍显示清楚 unavailable 状态。

验收：

- `rg "\\.commands|CommandMenu|keyboardShortcut|Settings \\{" LangoTraceApp Packages` 能找到对应实现。
- macOS 菜单和快捷键可以触发主要动作。
- footer 三个图标不再都表现为等价设置入口。

#### 任务 8：设计系统和状态模式底座

目的：修复 P1-006 和多个 P2 视觉 / 状态问题。

实施要点：

- 扩展 `LangoTraceDesign` semantic token：surface、text、accent、privacy、state、separator、focus、shadow、material、high contrast fallback。
- 明确 `ready / local mock / unavailable / warning / error / permission denied / sync conflict` 状态矩阵。
- 为 `CapabilityStatusBadge` / `CapabilityStatusRow` 建立视觉和文案约束，颜色不能是唯一状态表达。
- 收敛 `langoPanel` 使用边界，区分页面背景、section、repeated item、modal / sheet、tool surface。
- 建立 empty / unavailable / loading / error / permission denied 的共享模式。
- 更新 `LanguageSpaceFooter` 长名称和 compact hit size 策略。
- Memory UI 补内容记忆、语言记忆、学习记忆三层模型的第一轮表达。

验收：

- `rg "Color\\(red:" Packages/LangoTraceUI/Sources/LangoTraceUI` 的命中集中在 token 定义或少量经说明的状态色中。
- 状态组件能同时用文案、图标、tone 和 layout 表达状态。
- 主页面不再呈现大面积无差别卡片堆叠。

#### 任务 9：规范文档同步

目的：让 Accepted spec 与本轮代码事实保持一致，避免后续 AI 或开发者继续按旧 IA 实现。

实施要点：

- 更新 `docs/spec/002-navigation-and-routing.md`：iPhone 顶层结构、设置入口、iPad / macOS footer 语义、macOS Settings scene / commands。
- 更新 `docs/spec/003-ui-design-system.md`：状态矩阵、token 映射、action hierarchy、empty / unavailable / loading / error 模式、卡片使用边界。
- 更新 `docs/spec/004-swiftui-architecture.md`：`LearningContentRepository` seam、feature store、`contentRevision` 退出条件、View 不依赖 concrete repository。
- 更新 `docs/spec/006-interface-localization-and-language-boundaries.md`：显式 interface-language resolver、language display projection、系统语言与 App 内语言测试。
- 更新 `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`：第一轮 UI 收敛后的页面地图、Rendering 显性状态、Memory 三层模型。
- 更新 `docs/review/INDEX.md`，记录本轮从审核进入实施方案和后续验证状态。

验收：

- 文档不再把 iPhone 五 Tab 写为当前强制规则。
- 文档明确区分本轮已实现、仍为 local mock、仍需单独方案的问题。
- 文档占位扫描无匹配。

#### 任务 10：多宽度、平台输入和可发现性验证

目的：把 iPad / macOS 审查中“原型可用但平台完成度不足”的问题变成可验证的交互矩阵。

实施要点：

- 建立 iPad 宽度矩阵：全屏、2/3、1/2、1/3、类 Slide Over 窄宽度；记录每个宽度下 timeline、workspace、Inspector、Settings、Search、New Entry 的可达性。
- 建立 macOS 窗口矩阵：默认宽度、窄窗口、隐藏 Sidebar、隐藏 Inspector、同时隐藏两侧辅助面板；验证 `.windowResizability(.contentSize)` 和 `minHeight` 是否仍合理。
- 为 iPad panel edge gestures 保留 accelerator 定位，并确保 toolbar、keyboard shortcut、button label 提供可发现入口。
- 为 macOS toolbar panel toggles 增加 accessibility value，并提供 menu mirror。
- 为 Search 入口建立诚实行为：真实搜索未接入时，不用伪搜索框误导；可以用标准 search command 打开 unavailable / local mock 说明。
- 建立截图或手动验证记录路径。如果模拟器或截图工具不可用，记录具体失败命令、失败原因和替代验证。

验收：

- iPad 隐藏左栏后，Settings / Search / New Entry 仍可达。
- macOS 窄窗口下主内容不被 Inspector / Sidebar 过度挤压。
- panel edge gestures 不是唯一入口。
- 搜索入口不会暗示真实搜索已经接入。

#### 任务 11：语言空间 summary、生命周期方案和持久化方案衔接

目的：完整覆盖 P1-002、P2-IA-03 和 SwiftUI 架构报告中的 `LanguageSpaceRepository` 问题，同时避免把删除能力混入本轮 UI 修复。

实施要点：

- 将当前语言空间入口从纯 unavailable route 改为只读 Space summary，至少展示当前空间名称、母语到目标语言、水平、Local-first 数据边界和后续 lifecycle 能力说明。
- 对“添加学习语言 / 切换语言 / 删除语言空间”显示 lifecycle placeholder，明确当前版本不会创建、切换或删除真实空间。
- 新建或引用独立 active plan：`feature-language-space-lifecycle-and-deletion`，内容必须覆盖添加、切换、删除、最后空间回退、导出前置、级联、撤销、同步 tombstone。
- 与现有 `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md` 做边界检查：本轮不重复实现启动恢复和持久化，但不能与其未来 repository 形态冲突。
- 在 `docs/spec/002-navigation-and-routing.md` 中记录语言空间入口的第一轮 UI 语义：当前上下文 summary，不是重型 Project 管理，也不是 unavailable 死路。

验收：

- 用户点击语言空间入口能看到当前空间摘要和明确的后续能力边界。
- 方案文档中能找到语言空间生命周期删除方案的路径或创建记录。
- 本轮代码没有直接实现删除真实语言空间。
- `LanguageSpaceRepository` 的持久化问题要么由已有 active plan 承接，要么在本轮实施记录中说明依赖关系。

#### 任务 12：SwiftUI hygiene、可访问性 pattern 和组件拆分

目的：覆盖 P2/P3 中不属于单一平台 IA 的 SwiftUI 质量项，避免只修主路径而留下可访问性和维护性债务。

实施要点：

- 修复触及文件中的 SwiftUI drift：不合理 `.tabItem` 结构、manual binding、字符串拼接形成的本地化不可控文案、重复 accessibility hint。
- 为 SectionHeader、SectionCaption 或等价标题组件增加 heading trait，并避免每个页面散落手写 traits。
- 为 status row、sheet、popover、icon-only controls 建立统一 label / value / hint pattern。
- 对 `PhoneMainSections.swift`、`PhoneMainSupportingViews.swift`、`PadMainSections.swift`、`MacWorkspaceContentView.swift`、`LearningContentComponents.swift` 中本轮触及的多职责区域做目标拆分，优先按产品对象拆出 Entry、Rendering、Practice、Memory、Settings 相关组件。
- 如果 macOS entry editor sheet 本轮被触及，改为 item-based presentation；如果未触及，在实施记录中标为后续 SwiftUI hygiene。
- 增加回归测试：empty actions、route fallback、repository seam、interface language resolver、unavailable pattern。

验收：

- `Button {}` 空 action 扫描无命中，或命中均为明确测试 / preview。
- 重点 shared components 有一致 accessibility label / value / hint。
- 多职责文件有明确拆分或实施记录解释为何本轮不拆。
- UI tests 能覆盖本轮新增的状态模型。

#### 任务 13：设计系统完整性和用户文案收敛

目的：覆盖视觉报告中除 token 之外的所有修复项，包括平台材质差异、文案工程味、compact pattern 和状态矩阵样板页。

实施要点：

- 以 iPhone 记录工作台 + Entry detail、iPad 三栏、macOS 主工作台 + Inspector 作为样板页，验证 token、状态矩阵和 action hierarchy。
- 为 `SentencePairView`、`EntryDetailHeader`、`LanguageSpaceFooter`、主要 hero / empty / unavailable 组件增加 compact pattern。
- 主路径文案从工程术语改为用户语言，例如避免把 Local Mock、Provider、Prompt、Vector Index 放在首屏主叙事；技术边界保留在详情层或状态说明中。
- `INSPECTOR` 等原型 literal 替换为本地化、用户可理解的标题。
- `langoPanel` 从万能容器改为明确 pattern：repeated item、modal / sheet、tool surface；页面 section 不默认包卡片。
- 记录哪些 token / 魔法数因不在本轮触及范围内暂不清理，避免误称“完整设计系统完成”。

验收：

- 样板页中状态视觉不只依赖颜色。
- 主路径文案不以工程术语作为第一层信息。
- 组件 compact pattern 覆盖长语言名称、长 Entry 标题、长目标语言文案。
- 文档明确“深色模式 / 高对比 / 完整品牌系统”仍是后续视觉验证项。

#### 任务 14：二轮复查、截图和验证

目的：完成实现后的代码级复核和验证闭环。

实施要点：

- 对照本文 `15. 审查报告修复项覆盖矩阵` 逐项标记处理结果，不能只检查 P1-001 到 P1-009。
- 对保留、拆出或延期的项目记录理由，尤其是语言空间删除、语言空间持久化、真实 AI / TTS / 同步、深色模式和截图矩阵。
- 使用 `requesting-code-review` 做一次提交前复审，重点查误报修复、文档漂移、状态误导和平台原生性。
- 运行 package tests 和完整 `scripts/verify.sh`。
- 如果环境允许，补 iPhone、iPad、macOS 截图验证；若截图或模拟器不可用，记录具体失败原因、失败命令和替代验证。

验收：

- P1 / P2 / P3 项均有完成、拆分或有证据的延期记录。
- `scripts/verify.sh` 通过，或失败项有环境级原因和替代验证。
- `git diff --check` 通过。
- `git status --short` 只包含本任务相关变更。

### 11.3 建议提交拆分

本任务范围较大，实施时建议分为多个小提交，而不是一个巨大提交：

1. `refactor: add learning content store seam`
2. `fix: close visible interaction and accessibility gaps`
3. `feat: apply explicit interface language chrome`
4. `feat: converge phone record workspace navigation`
5. `feat: clarify entry rendering local mock flow`
6. `feat: refine ipad workspace interactions`
7. `feat: add mac settings commands`
8. `style: expand UI tokens and state patterns`
9. `feat: add language space summary boundary`
10. `refactor: split UI components and accessibility patterns`
11. `test: add adaptive UI validation coverage`
12. `docs: sync UI convergence specs`

如果用户要求一个 commit 收口，可以在完成验证后 squash 或用单次提交；默认推荐阶段性提交以便复审。

## 12. 复查方法

逐项复查：

- P1-001：检查 iPhone 顶层目的地是否互不重复，设置是否降级。
- P1-002：检查语言空间删除没有被直接实现，且 Space summary / lifecycle placeholder 不误导用户。
- P1-003：检查新 Entry 不再被动进入完整 Rendering / Practice / Memory 闭环。
- P1-004：检查 macOS Settings scene、commands 和快捷键。
- P1-005：检查 iPad 多宽度和键盘 / pointer / focus / context menu。
- P1-006：检查 token、状态矩阵和卡片使用边界。
- P1-007：检查显式界面语言偏好驱动自有 chrome。
- P1-008：检查 UI 不依赖 concrete repository。
- P1-009：检查 Listen 有反馈。

人工复查：

- iPhone：Welcome、Onboarding、记录工作台、Entry 创建、Entry detail、练习、记忆、设置入口、unavailable sheet。
- iPad：全屏、2/3、1/2、1/3、窄宽度、面板收起、键盘新建、搜索、设置入口。
- macOS：菜单、快捷键、Settings scene、Sidebar、Toolbar、Inspector、footer AI / Sync / gear。
- 本地化：系统语言与 App 内显式语言不同，检查自有 chrome。
- 可访问性：VoiceOver 顺序、Dynamic Type、44pt hit target、Reduce Motion、状态 label / value / hint。

## 13. 验证命令

实现前基线：

```bash
git status --short
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

实现后必须运行：

```bash
scripts/verify.sh
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

重点扫描：

```bash
rg "InMemoryLearningContentRepository" Packages/LangoTraceUI/Sources LangoTraceApp
rg "\\.commands|CommandMenu|keyboardShortcut|Settings \\{" LangoTraceApp Packages
rg "Button \\{\\}" Packages/LangoTraceUI/Sources/LangoTraceUI
rg "Locale\\.preferredLanguages" Packages/LangoTraceUI/Sources LangoTraceApp
rg "Color\\(red:" Packages/LangoTraceUI/Sources/LangoTraceUI
rg "ChineseUI|INSPECTOR" Packages LangoTraceApp
rg "\\.accessibilityAddTraits\\(\\.isHeader\\)|accessibilityHeading" Packages/LangoTraceUI/Sources/LangoTraceUI
```

如实施中修改 String Catalog，补充：

```bash
ruby -rjson -e 'JSON.parse(File.read("Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings")); puts "json ok"'
```

## 14. 文档影响检查

本任务必然触发文档影响检查，因为会改变导航规范、UI 规范、SwiftUI 架构规范、界面语言边界和 review 索引。

必须更新：

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`

必须检查是否需要更新：

- `docs/product-main-reference.md`：若仅收敛实现，不改变产品北极星，则不改；若改变 iPhone 顶层 IA 推荐描述，需要同步。
- `docs/decisions/004-use-language-space-as-primary-model.md`：本轮不改变语言空间核心模型，默认不改。
- `docs/decisions/005-local-first-and-user-owned-providers.md`：本轮不改变 Provider 决策，默认不改。
- `docs/review/INDEX.md`：记录本轮实施与验证状态。

不应在本任务中更新为已完成：

- 真实 AI Provider。
- 真实 TTS / Speech / OCR / Photos 权限。
- 真实同步。
- 真实 StoreKit。
- 语言空间删除。
- 完整深色模式。

## 15. 审查报告修复项覆盖矩阵

本节是本方案的完整性检查入口。实施时不得只按 11.2 的任务标题推进，必须逐条对照本矩阵更新状态。

### P1 修复项

| 审查项 | 处理方式 | 落点 |
| --- | --- | --- |
| P1-001 iPhone `今日 / 记录` 重复，`设置` Tab 层级过重 | 本轮直接修复 | 任务 4、任务 9 |
| P1-002 语言空间应允许删除但必须拆生命周期方案 | 本轮不直接实现删除；创建或引用独立 active plan，当前 UI 改为 Space summary / lifecycle placeholder | 任务 11、任务 9 |
| P1-003 Rendering 边界不显性，保存 Entry 自动生成 mock 闭环 | 本轮直接修复 | 任务 5、任务 8 |
| P1-004 macOS 设置入口和命令面缺口 | 本轮直接修复 | 任务 7、任务 9 |
| P1-005 iPad 响应式和生产力输入不足 | 本轮直接修复 | 任务 6、任务 10 |
| P1-006 设计系统 token 和状态矩阵不足 | 本轮直接修复第一层底座；完整品牌系统和完整深色模式延期 | 任务 8、任务 9、任务 13 |
| P1-007 自有界面语言偏好未实际驱动多数 chrome | 本轮直接修复 | 任务 3、任务 9 |
| P1-008 UI 直接依赖 concrete in-memory repository | 本轮直接修复最小 seam | 任务 1、任务 9 |
| P1-009 `SentencePairView` Listen 是空 action | 本轮直接修复 | 任务 2、任务 12 |
| iOS shared `NavigationStack` 包全 Tab | 本轮直接修复 | 任务 4、任务 12 |
| Today 首屏 photo writing / listen unavailable chips 权重过高 | 本轮直接修复 | 任务 4、任务 8 |
| Welcome / Onboarding 过早暴露 AI、sync、dictionary、Prompt 概念 | 本轮直接修复 | 任务 2、任务 4、任务 9 |
| Welcome 650ms 自动跳转 | 本轮直接修复 | 任务 2、任务 12 |
| macOS Sidebar 与 footer 设置入口语义重叠 | 本轮直接修复 | 任务 7 |
| iPad Sidebar 配置入口过重 | 本轮直接修复 | 任务 6、任务 7 |
| LanguageSpaceRepository 为空且未被 session state 使用 | 已有 active plan `2026-05-17-feature-language-space-persistence-startup-restore.md`；本轮只做依赖衔接和不冲突检查，不重复实现持久化 | 任务 11、任务 14 |

### P2 修复项

| 审查项 | 处理方式 | 落点 |
| --- | --- | --- |
| iPhone unavailable sheet 缺标题、关闭、滚动和焦点返回 | 本轮直接修复 | 任务 2、任务 12 |
| Onboarding menu、practice step、sentence inline controls 触控目标和 Dynamic Type 风险 | 本轮直接修复第一轮 compact / reflow pattern | 任务 2、任务 8、任务 12 |
| Entry editor `TextEditor` 缺少明确 accessible label | 本轮直接修复 | 任务 2 |
| 密集 horizontal rows 缺少 Dynamic Type reflow | 本轮直接修复重点组件 | 任务 2、任务 8 |
| Onboarding language value 使用 ChineseUI display helpers | 本轮直接修复或移入 UI display helper | 任务 3、任务 9 |
| iPad empty / filtered-empty 缺少下一步动作 | 本轮直接修复 | 任务 6、任务 8 |
| iPad 右学习面板像功能 inventory，不是状态驱动 Inspector | 本轮直接修复 | 任务 6、任务 5 |
| iPad custom chrome 缺少 toolbar / command 语义 | 本轮直接修复第一轮 keyboard / command 入口 | 任务 6、任务 7 |
| Onboarding 当前密度合理但产品 / 导航文档仍有“是否现在配置 AI Provider”的分歧 | 本轮同步文档，不把 AI Provider 配置作为首次启动必经步骤 | 任务 2、任务 9 |
| macOS Search 是 unavailable toolbar button，不是标准 search / command surface | 本轮修复为诚实标准入口；真实搜索仍可 unavailable | 任务 7、任务 8 |
| macOS window behavior under-specified，尺寸可能过约束 | 本轮定义窗口尺寸规则并截图或记录验证 | 任务 7、任务 14 |
| macOS Inspector 过于 passive | 本轮增加上下文动作和更紧凑信息层级 | 任务 7、任务 8 |
| macOS toolbar panel toggles 缺少 accessibility state value 和 menu mirror | 本轮直接修复 | 任务 7、任务 12 |
| 设计系统三端视觉过于同源，平台材质差异不足 | 本轮建立 platform surface adapter 第一层 | 任务 8 |
| empty / unavailable 状态偏说明页，缺少下一步动作 | 本轮直接修复共享模式 | 任务 8、任务 12 |
| 主次按钮层级和控件密度缺少统一规则 | 本轮直接补 action hierarchy | 任务 8、任务 9 |
| 设计 token 覆盖不足，魔法数扩散 | 本轮收敛重点 token 和新代码，不承诺清空所有历史魔法数 | 任务 8、任务 13 |
| SwiftUI modern API / swiftui-pro drift，例如 `.tabItem`、manual bindings、text concatenation | 本轮在触及文件中修复，剩余项记录为后续 hygiene | 任务 12、任务 14 |
| View files 过于 multi-purpose | 本轮随重构拆分 Phone / iPad / Mac 重点文件，非相关大文件不做机械拆分 | 任务 4、任务 6、任务 7、任务 12 |
| Core display model 仍有 ChineseUI-specific helpers | 本轮修复或隔离到 UI display projection | 任务 3、任务 9 |

### P3 与验证项

| 审查项 | 处理方式 | 落点 |
| --- | --- | --- |
| Memory 未体现内容记忆、语言记忆、学习记忆三层模型 | 本轮直接补第一轮 UI 表达和文档说明 | 任务 8、任务 9 |
| Section headings 未标记 accessibility heading trait | 本轮修复重点页面和共享 section 组件 | 任务 12 |
| 部分 hints 重复 label 或 visible summary | 本轮修复重点组件，建立状态 row / sheet pattern | 任务 12 |
| iPad panel edge gestures 不可发现 | 本轮保留为 accelerator，并增加 toolbar / keyboard 可发现入口 | 任务 6 |
| macOS `INSPECTOR` literal 和语言空间 footer unavailable route 像原型 | 本轮替换用户可理解文案，语言空间入口改 Space summary | 任务 7、任务 11 |
| macOS entry editor sheet 未来适合 item-based presentation | 本轮如果触及 Mac entry editor，改为 item-based；否则写入后续 hygiene | 任务 7、任务 14 |
| UI 文案偏工程术语 | 本轮替换主路径文案，技术边界下沉到详情层 | 任务 8、任务 9 |
| iPhone SE + Accessibility text size + en / zh-Hans / long language 截图基线 | 本轮建立验证清单；能跑则截图，不能跑记录环境原因 | 任务 14 |
| iPad Split View / Stage Manager 多宽度截图 | 本轮建立验证清单；能跑则截图，不能跑记录环境原因 | 任务 14 |
| macOS narrow window / menu / Settings scene 截图或手动验证 | 本轮建立验证清单；能跑则截图，不能跑记录环境原因 | 任务 14 |

## 16. 实施记录

### 2026-05-18 阶段 1：Learning content seam

处理范围：

- 完成任务 1 / P1-008 的第一轮实现。
- 在 `LangoTraceData` 定义 `LearningContentRepository` 协议，覆盖 UI 当前使用的 entries、selection、create、rendering、practice、memory、settings capabilities 和 practice session 能力。
- 让 `InMemoryLearningContentRepository` conform 到协议，保持当前 mock 数据行为不变。
- 在 `LangoTraceUI` 新增 `LearningContentStore`，由 MainActor store 统一 seed、select、create、刷新和派生内容读取。
- `LangoTraceRootView` / `PhoneMainView` / `PadMainView` / `MacMainView` 以及 iPad / macOS 子视图改为依赖 store；`contentRevision` 从三端主 View 移除。
- App bootstrap 仍在 `AppEnvironment` 创建 `InMemoryLearningContentRepository(seedEntries: [])`，这是本阶段保留的 composition root seam。

验证结果：

- TDD red：`swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests` 初次失败，原因是 `LearningContentStore` 不存在。
- TDD green：`swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests` 通过，2 个 store seam 测试通过。
- `swift test --package-path Packages/LangoTraceData` 通过，10 个测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，25 个测试通过。
- `rg -n "contentRevision|contentRepository|InMemoryLearningContentRepository" Packages/LangoTraceUI/Sources LangoTraceApp` 只剩 `LangoTraceApp/AppEnvironment.swift` 的 bootstrap 创建。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 通过。

剩余边界：

- 本阶段只建立最小替换 seam，不改变 `createEntry` 自动生成 mock closure 的旧行为；P1-003 留到任务 5 单独收敛。
- App composition root 仍使用 in-memory repository，后续真实 repository 由数据持久化计划承接。

### 2026-05-18 阶段 2：Visible interaction and accessibility baseline

处理范围：

- 完成任务 2 / P1-009 的第一轮实现，并覆盖 Welcome 自动跳转、unavailable sheet、Entry editor body accessibility label、Onboarding 首屏说明收敛。
- `SentencePairView` 增加 `onListen` seam；默认点击 Listen 展示 `.listenOne` unavailable sheet，不再存在可见空 action。
- `UnavailableCapabilityView` 改为滚动内容，作为 sheet 使用时显示标题和关闭按钮；iPhone / iPad sheet 调用传入 `onDismiss`。
- `WelcomeView` 删除 650ms 自动推进，改为显式 Continue button；补充不会从欢迎页启动 AI、同步或外部请求的轻量说明。
- `EntryEditorView` 为 `TextEditor` 增加 body accessibility label / hint。
- Onboarding 隐私说明从 AI / 同步 / 词典 / Prompt 列表收敛为“本地创建第一个语言空间，能力边界稍后在设置中查看”。
- String Catalog 补充 `common.close`、`common.continue`、`welcome.localOnlyNote`、`entryEditor.bodyField.accessibilityLabel`、`entryEditor.bodyField.accessibilityHint`。

验证结果：

- TDD red：`swift test --package-path Packages/LangoTraceUI --filter stageFourVisibleInteractionAndAccessibilityGapsStayClosed` 初次失败，覆盖 `Button {}`、Welcome `.task`、Entry editor body label、Unavailable sheet 结构缺口。
- TDD green：同一测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，26 个测试通过。
- `ruby -rjson -e 'JSON.parse(File.read("Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings")); puts "json ok"'` 通过。
- `rg -n "Button \\{\\}|\\.task \\{" Packages/LangoTraceUI/Sources/LangoTraceUI` 无命中。
- `git diff --check` 通过。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 通过。

剩余边界：

- 本阶段只关闭明显可点入口和基础 accessibility 风险；Dynamic Type / 44pt / compact row 的完整模式仍由任务 8、任务 12、任务 13 继续收敛。
- Listen 当前仍是 unavailable / local mock 反馈，不接入真实 TTS 或音频播放。

### 2026-05-18 阶段 3：Explicit interface language chrome

处理范围：

- 完成任务 3 / P1-007 的第一轮实现。
- `LocalizedChrome` 不再直接读取 `Locale.preferredLanguages`；新增 `LocalizedChromeLanguageResolver`，由 `LangoTraceRootView` 根据 `InterfaceLanguagePreference.resolvedLanguageCode(systemLanguageCodes: Bundle.main.preferredLocalizations)` 驱动自有 chrome。
- 增加 `withLocalizedChromeLanguageCode` 测试辅助，验证 English / 简体中文 / Español 可驱动 `localizedString("tab.settings")`。
- 保留 `System` 语义：仍由 `InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes:)` 与支持语言求交集，无法匹配时回退 English。
- 新增 `InterfaceLocalization.swift`，将 onboarding 语言显示投影移到 UI 层的 `LearningLanguageDisplayPolicy`；Core 的 `LearningLanguage` 不再暴露 `ChineseUI` 命名的 display helper。
- 更新 Core 测试，保留模型稳定字段和默认语言空间名称测试。

验证结果：

- TDD red：阶段 3 新增测试初次失败，原因是缺少 chrome language override 和 UI display projection 文件；Core 测试也暴露旧 `ChineseUI` helper 依赖。
- `swift test --package-path Packages/LangoTraceCore` 通过，26 个测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，29 个测试通过。
- `rg -n "Locale\\.preferredLanguages|ChineseUI|pickerMenuTitleForChineseUI|selectedTitleForChineseUI|spaceNameForChineseUI" Packages/LangoTraceUI/Sources Packages/LangoTraceCore/Sources LangoTraceApp` 无命中。
- `git diff --check` 通过。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 通过。

剩余边界：

- 本阶段只覆盖 package-owned SwiftUI chrome；InfoPlist、权限弹窗、StoreKit、文件选择器、系统 per-app language 和 Provider 输出仍按 `spec/006` 的分层边界处理。
- UI 内语言切换不会改变语言空间、学习内容或 Provider 输出。

### 2026-05-18 阶段 4：iPhone IA convergence

处理范围：

- 完成任务 4 / P1-001 的第一轮实现。
- `PhoneRootTab` 从 `今日 / 记录 / 练习 / 记忆 / 设置` 收敛为 `记录 / 练习 / 记忆` 三个主目的地，删除 `.today` 和 `.settings` 的顶层 tab 假设。
- iPhone 默认进入 `记录`，由新的 `PhoneRecordWorkspaceView` 合并记录生活主动作、最近记录和全部记录入口，避免 `今日` 与 `记录` 两个顶层目的地表达同一任务。
- 设置从底部 Tab 降级为 toolbar gear 入口，经 `PhoneRoute.settingsList` 推入设置列表；设置页自身不再重复显示设置入口。
- 更新 `PhoneTabNavigationTests` 和 `LocalizedChrome.PhoneRootTab` 映射，避免旧五 Tab 结构继续作为代码事实。

验证结果：

- TDD red：先将 `PhoneTabNavigationTests` 改为三主目的地预期，`swift test --package-path Packages/LangoTraceCore --filter PhoneTabNavigationTests` 初次失败，原因是旧 `PhoneRootTab.allCases` 仍包含 `.today` / `.settings`。
- TDD green：同一测试通过，随后 `swift test --package-path Packages/LangoTraceCore` 通过，26 个测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，29 个测试通过。
- `rg -n "PhoneRootTab\\.(today|settings)|case (today|settings)|tab\\.today" Packages/LangoTraceCore/Sources Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift` 只剩设置导航 route，不再存在 `PhoneRootTab.today` / `.settings`。
- `git diff --check` 通过。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 通过。

剩余边界：

- 本阶段只收敛 iPhone 顶层 IA；iPad / macOS 的 footer、Settings scene、commands 和窄窗口行为留给任务 6、任务 7、任务 9 继续处理。
- `PhoneRecordWorkspaceView` 仍使用当前 mock content store；Entry 创建后的真实对象边界、Entry detail / rendering / practice / memory 的能力声明由任务 5 收敛。

### 2026-05-18 阶段 5：Entry rendering boundary

处理范围：

- 完成任务 5 / P1-003 的第一轮实现。
- `LearningContentRepository` 增加显式 `generateLocalPreview(for:spaceID:)` seam；`InMemoryLearningContentRepository.createEntry` 只创建并选中新 Entry，不再自动生成 rendering、practice item 或 memory item。
- `LearningContentStore` 暴露 `generateLocalPreview(for:)` 并在生成后 reload，保持三端 UI 从同一 store 读取更新后的 rendering / practice / memory。
- `EntryDetailView` 在缺少 rendering 时显示本地预览生成行，说明只在设备上创建示例学习材料，真实 AI generation 尚未接入。
- Entry detail 的 Practice 区在缺少 practice item 时显示 unavailable 状态，不再留下空 section；seed 数据仍可展示完整 local mock 闭环。
- iPhone / iPad / macOS 所有 `EntryDetailView` call site 均接入同一个显式生成动作。

验证结果：

- TDD red：更新 Data 测试后，`swift test --package-path Packages/LangoTraceData --filter createdEntriesReceiveLocalPreviewOnlyAfterExplicitGeneration` 初次编译失败，原因是 repository 尚无 `generateLocalPreview`。
- TDD red：更新 UI store 测试后，`swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests` 初次编译失败，原因是 store 尚无 `generateLocalPreview(for:)`。
- TDD green：上述两个测试分别通过。
- `swift test --package-path Packages/LangoTraceData` 通过，10 个测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，29 个测试通过。
- `ruby -rjson -e 'JSON.parse(File.read("Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings")); puts "json ok"'` 通过。
- `rg -n "creates mock rendering|Created entries receive mock|renderingsByEntryID\\[entry\\.id\\]|generateLocalPreview|entry\\.rendering\\.localPreview" Packages/LangoTraceData Packages/LangoTraceUI docs/plans/active/2026-05-18-feature-first-round-ui-convergence.md` 确认自动生成旧测试文案已移除，生成入口只剩显式 preview seam 和 UI 文案。

剩余边界：

- 本阶段仍只生成 local mock preview，不接入真实 AI Provider、Prompt Registry 渲染、请求预览确认流或外部请求日志。
- Memory tab 仍展示 store 中已有 memory items；更完整的空态、筛选和向量索引状态由任务 8、任务 12、任务 13 继续收敛。

### 2026-05-18 阶段 6：iPad responsive workspace and input

处理范围：

- 完成任务 6 / P1-005 的第一轮实现。
- 新增 `PadWorkspaceWidthClass`，按实际 workspace width 定义 three-column / two-column / single-column；`PadAdaptivePanelLayout` 不再只依赖 `horizontalSizeClass`。
- `PadMainView` 在 workspace `GeometryReader` 中根据宽度调整 panel 可见性：宽屏保留当前状态，中等宽度隐藏 learning panel，窄宽度同时隐藏 timeline 和 learning panel，保护主写作区。
- `PadWorkspaceBar` 增加稳定 Settings 入口，使隐藏左栏后 Settings / Search / New Entry 仍可达。
- `PadWorkspaceBar` 增加第一轮键盘快捷键：New Entry、Search、Settings、Toggle Timeline、Toggle Learning Panel。
- `EntryTimelineRow` 和 `FilterPill` 增加 focusable、hover state 和 context menu，补齐 iPad pointer / keyboard 第一轮 affordance。

验证结果：

- TDD red：新增 `iPadWorkspaceWidthClassesProtectWritingDesk` 后初次失败，原因是缺少 `PadWorkspaceWidthClass` 和 width-based visibility API。
- TDD green：`swift test --package-path Packages/LangoTraceUI --filter iPadWorkspaceWidthClassesProtectWritingDesk` 通过。
- `swift test --package-path Packages/LangoTraceUI --filter iPadWorkspaceBarKeepsUtilityActionsAndKeyboardShortcutsReachable` 通过，确认 top bar 保留 utility actions 和快捷键。
- `swift test --package-path Packages/LangoTraceUI` 通过，32 个测试通过。

剩余边界：

- 本阶段不做真实 Search，不接入外部键盘 command menu；真实菜单命令和 macOS commands 留给任务 7。
- iPad 多宽度截图验证、Stage Manager / Split View 手动矩阵和截图基线仍由任务 10、任务 14 收口。

### 2026-05-18 阶段 7：macOS Settings scene and commands

处理范围：

- 完成任务 7 / P1-004 的第一轮实现。
- `LangoTraceApp` 拆出 `mainWindowScene` 和 `rootContent`，并在 macOS 下增加独立 `Settings` scene。
- 新增 `LangoTraceSettingsSceneView`，在 Settings window 中展示只读 capability boundary，避免把通用设置只埋在主 workspace sidebar。
- 新增 `LangoTraceAppCommand` 通知 seam；App-level commands 通过 command bus 触发 Mac workspace 内部状态变化。
- `LangoTraceCommands` 增加 New Entry、Settings、Search、Toggle Sidebar、Toggle Inspector，并绑定 `Cmd+N`、`Cmd+,`、`Cmd+F`、`Cmd+Opt+[`、`Cmd+Opt+]`。
- `MacMainView` 监听 command notifications，复用现有 entry editor、search unavailable route、sidebar / inspector toggle 和 settings overview route。

验证结果：

- 首次 `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 失败，原因是 `Settings {}` 放在 chained scene modifier 后导致 SceneBuilder 解析错误。
- 第二次 build 失败，原因是 command post 使用 `.newEntry` shorthand，编译器解析为 `Notification.Name.newEntry`。
- 修复后 `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，32 个测试通过。
- `git diff --check` 通过。
- `rg -n "\\.commands|CommandMenu|keyboardShortcut|Settings \\{|LangoTraceAppCommand|openSettings" LangoTraceApp Packages/LangoTraceUI/Sources/LangoTraceUI` 确认 app scene、commands、Settings scene 和 command bus 均存在。

剩余边界：

- 本阶段只建立 macOS 原生命令面；真实 Search、真实 Settings 配置写入和 Provider / Sync 配置仍保持 unavailable 或 read-only。
- Sidebar 内容域重排和 footer icon 语义的更细视觉收敛仍由任务 8、任务 9 配合规范文档继续处理。

## 17. 完成标准

本任务完成必须同时满足：

- 用户已确认本方案进入实现。
- 本文 `15. 审查报告修复项覆盖矩阵` 中所有 P1 / P2 / P3 和验证项均有完成、拆分、依赖计划或有证据延期记录。
- P1-001、P1-003、P1-004、P1-005、P1-006、P1-007、P1-008、P1-009 均完成或有明确拆分记录。
- P1-002 语言空间删除没有混入本轮实现，并已明确新方案路径或创建单独 active plan。
- P2 和 P3 项不能只以“低优先级”略过；若不直接修复，必须说明不修原因、后续落点和复查方法。
- iPhone、iPad、macOS 主路径均符合本轮审查裁决。
- 所有明显可点入口有反馈。
- 显式界面语言偏好驱动自有 chrome，或文案不再承诺即时覆盖。
- UI 对 concrete in-memory repository 的依赖降到 bootstrap / preview / tests seam。
- 规范文档与代码事实一致。
- `scripts/verify.sh` 通过，或不能运行的项有具体原因和替代验证。
- `git diff --check` 通过。
- 文档占位扫描无匹配。
- 实施记录写明验证命令和结果。

## 18. 剩余风险

- 本轮会触及三端主 UI、Data seam、Core display helper 和多份 spec，改动范围大；推荐分阶段提交和每阶段复查。
- 真实数据层尚未接入，本轮 repository seam 只能保证替换边界，不能证明 SQLite / GRDB 方案已经完成。
- 真实 AI、TTS、权限、同步和 StoreKit 仍未接入；所有相关 UI 只能表达 local mock 或 unavailable。
- 语言空间删除仍是独立高风险任务，本轮只能避免把语言空间入口做成死路。
- 深色模式和高对比模式只能建立 token 基础，完整视觉验证需要后续截图矩阵。
- 如果完整 `scripts/verify.sh` 因模拟器、SwiftLint 或 SwiftFormat 环境失败，需要保留原始失败信息并运行可替代的 package tests / build 命令。
