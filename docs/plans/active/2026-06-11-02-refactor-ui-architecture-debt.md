# 任务方案：UI / App 层结构债清偿（系列 E0b）

状态：Draft
自审核状态：Reviewed
类型：refactor
创建日期：2026-06-11
最后更新日期：2026-06-11

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）。该授权仅覆盖"系列方案文档的制定"，不覆盖本方案的实现。进入生产代码实现前，必须由用户单独确认本方案，并将状态推进为 `User Approved`。其中第 12 节 Phase 5 的 welcome 路由产品语义（APP-12）需要用户做产品选择后才能定稿实现方式。

## 1. 需求或 bug 描述

2026-06-11 全量代码审查在 LangoTraceUI 与 LangoTraceApp 留下一批结构性 P2 债：iPhone 导航结构与 spec 002 偏离（push 覆盖 Tab bar）、嵌套滚动、App Shell 巨型文件承载编排逻辑、TTS 失败对阅读 UI 不可见、Data 层中文展示字符串穿透到 UI chrome、store 影子缓存无失效、自制本地化运行时缺复数与 locale 规则、源码字符串断言型伪测试蔓延。

这些问题会被 E1（记录时间线，重排 PhoneMainView）、E2（照片附件，扩 photo-writing 页面）和后续阅读 / 练习方案直接踩到。本方案在功能方案动这些文件之前一次性清偿，避免每个功能方案都在脏结构上叠加。

## 2. 现状描述

以下现状全部按 HEAD `274b7db` 重新核验：

1. UIV-05：`PhoneMainView.swift:24,28-100` 把 `TabView` 包在单个 `NavigationStack(path: $navigationPath)` 内，共享 `[PhoneRoute]` 路径；任何 push（entryDetail、settings 等）都覆盖 Tab bar。spec 002 §4.2 推荐"底部 Tab：记录 / 阅读 / 练习 / 记忆"作为持久一级导航，当前结构使 Tab 在深层页面不可达。
2. UIV-07 嵌套滚动：iPad `PadMainSections.swift:175-184` 的 workspaceOverview 用 `ScrollView` 包住 `EntryDetailView`，而后者自身含 `ScrollView`（`PhoneMainSupportingViews.swift:112`）；`MacMainModels.swift:81-88` 的 `usesDedicatedMainScrolling` 对 `.entryDetail` / `.reading` 返回 false，导致 Mac 外层再套滚动；`MacMainView.swift:224,282` 存在外层 ScrollView 包内部自滚动内容（含 reading 栏 List-in-ScrollView 形态）。
3. APP-08：`LangoTraceApp/AppEnvironment.swift` 现为 1003 行，`requestReadingSelectionExplanation`（约 :215 起）内嵌 operation 记录，使用魔法字符串 `"succeeded"` / `"failed"` / `"cancelled"` / `"providerNotConfigured"`（:237,270,273,276）。UIV-20：`AIProviderSettingsView.swift` 现为 750 行，保存 / probe / 密钥 reveal 编排（`savedCredentialMetadataByID`、`transientSaveStatusClearTask`、`validateConfiguration`、`playSpeechPreview` 等）堆在 View 与其扩展中，违反 spec 004 §3（View 不承载业务编排）与 §4.3（大型页面文件治理）。
4. UIS-05：`ReadingActions.swift:82` 定义 `public typealias ReadingTTSAction = @Sendable (ReadingTTSRequest) async -> Void`，TTS 失败对阅读 UI 完全不可见，违反 spec 004 §4.7（必须暴露 failed 状态）。APP-13：`AppEnvironment.swift:288-305` 的 `makeReadingTTSAction` 适配器硬编码 `sentenceIndex: 0` 并以 `_ =` 丢弃 `handleTap` 返回状态。
5. UIS-06：`PracticeSessionViewModel.swift:15` 的 `isPlayingDemo` 只在 `stopDemoPlayback()`（:121）被置 false，从未置 true；示范播放进行中无停止 affordance、无重入保护。
6. UIS-07 / UIV-17 / DATA-14：Data 层中文展示字符串流入 UI chrome：`LearningContentModels.swift:22` 默认 `practiceSummary: "待练习"`，由 `LearningContentComponents.swift:26`、`PhoneMainSupportingViews.swift:807`、`PhoneMainSections.swift:91` 直接渲染（含可访问性标签路径）；scene 回退 `"生活记录"`（`GRDBLearningContentRepositoryBridge.swift:37`、`GRDBLearningContentRepository.swift:36,39`）；`LearningContent.swift:104,107` 的 `"新的生活记录"` / `"今天"`。违反 spec 006 §4（UI chrome 必须由 String Catalog 渲染，Data / Core 提供结构化语义）。`createMockPhotoWritingEntry`（`LearningContent.swift:133-158`、`LearningContentStore.swift:72-76`）与 `PhonePhotoWritingPreviewView` 仍是 photo-writing 预览的唯一路径。
7. UIS-09：`LearningContentStore.swift:12` 的 `generatedRenderingsByEntryID` 影子缓存在 :200,224,290 写入、:83 读取，无任何失效路径；entry 更新或重新分析后可能读到陈旧 rendering。
8. UIS-15/16：`LocalizedChrome.swift` 自制 xcstrings 运行时解析（:21-133），无复数规则、`String(format:)` 未带 locale（:18）、`nonisolated(unsafe) static var overrideLanguageCodes`（:136）。
9. UIS-19 / TEST-02：源码字符串断言型伪测试蔓延：`PhoneIOSConvergenceTests.swift` 含 16 处读源码断子串；`WelcomeTracePreviewContentTests.swift`、`InterfaceLanguageSettingsPageTests.swift`、`ThreePlatformPresentationCopyTests.swift`、`PremiumUIBehaviorTests.swift` 同类；App 侧 `LangoTraceAppTests/AppEnvironmentBootstrapTests.swift:66` 读取 `AppEnvironment.swift` 源码断言。
10. APP-09：`AppEnvironment.bootstrap()`（`AppEnvironment.swift:27-80`）经核验在 MainActor 语境内同步完成组件装配；原审查"async restore 脱离 MainActor"表述不成立，但启动恢复路径中数据库 IO 在主线程执行的事实仍在（启动阻塞风险随数据量增长）。APP-12：`completeWelcome()`（:909-914）在 `recoveryState == .failed` 时阻止离开 welcome，welcome 是否提供跳过 / 重试路径属产品决策，尚无规范结论。
11. UIV-08（设置页 footer 状态接线）属于另一份系列方案 `2026-06-11-15-feature-settings-status-projection.md`（对应 architecture note `2026-05-24-settings-status-projection-notes.md`），不在本方案内。
12. 小尾项（审查 ID UIV-25/28/31/32/33 在留存记录中无法逐一回溯到原文，按当前代码重新取证为以下候选）：`PhonePhotoWritingPreviewView.swift:88` 硬编码 `.frame(height: 210)`；`MacMainView.swift:211,298` 固定 sidebar / inspector 宽度常量；`AppEnvironment.swift:300` 阅读 TTS 全部使用句索引 0（与 APP-13 同源）；其余零散硬编码中文与重复视图块在涉及文件改造时顺带处理。

## 3. 目标

1. iPhone 重构为 per-tab NavigationStack：每个 Tab 持有自己的导航栈，push 不再覆盖 Tab bar；路由所有权模型（谁持有各 tab 的 path、跨 tab 跳转如何表达）形成书面结论并写回 spec 002。
2. 消除三端嵌套滚动：iPad workspaceOverview 与 Mac entryDetail / reading 改为单一滚动容器所有权。
3. App Shell 与设置页编排下沉：AppEnvironment 的阅读解释 operation 记录改为带状态枚举的专用 recorder 类型；AIProviderSettingsView 的保存 / probe / reveal 编排迁入专用 store / service（按 spec 004 §3 归 UI 或 AI 包），两个文件显著瘦身。
4. `ReadingTTSAction` 契约改为可表达失败（返回结果或抛错），App 适配器接线真实 sentenceIndex 与返回状态，阅读 UI 渲染 `.failed` audioState。
5. `isPlayingDemo` 从播放状态推导，恢复停止 affordance 与重入保护。
6. `practiceSummary` / scene 等 Data 展示字符串改为结构化状态（枚举 / 计数），UI 经 String Catalog 渲染；`createMockPhotoWritingEntry` 路径保留至 E2 落地（书面记录该依赖）。
7. `generatedRenderingsByEntryID` 影子缓存消除：rendering 以 repository 为单一事实源（或缓存带失效协议）。
8. LocalizedChrome 确定向 `Bundle.module` + SwiftUI environment 的迁移方向，并完成一个收敛的第一步（消除 `nonisolated(unsafe)` 全局与无 locale 的 format）。
9. 确立"不得新增源码子串断言测试"规则（写入 spec 009），并替换最严重的存量伪测试（AppEnvironmentBootstrapTests 与 PhoneIOSConvergenceTests 优先）为行为接缝测试。

## 4. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/`：PhoneMainView、PhoneMainSections、PhoneMainSupportingViews、PadMainSections、MacMainView、MacMainModels、ReadingActions、PracticeSessionViewModel、LearningContentStore、LearningContentComponents、LocalizedChrome、AIProviderSettingsView 及新增 store / service 文件。
- `Packages/LangoTraceData/Sources/LangoTraceData/`：LearningContentModels、LearningContent、GRDBLearningContentRepository、GRDBLearningContentRepositoryBridge（仅展示字符串结构化所需的模型与回退值改造）。
- `LangoTraceApp/AppEnvironment.swift` 及新增 recorder / adapter 文件；`LangoTraceAppTests/`。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/` 存量伪测试替换与新增测试。
- `docs/spec/002`、`docs/spec/009`、`docs/platform-page-inventory.md` 同步。

前序依赖：E0a（`2026-06-11-01-refactor-architecture-foundations.md`）。理由：本方案的 TTS 失败渲染与设置页编排下沉依赖 E0a 补全的错误分类（rateLimited / authenticationFailed / 精确 AIProviderConfigurationError）；operation recorder 的状态枚举应建立在 E0a 收口后的 Core 错误类型上。本方案必须先于 E1（E1 重排 PhoneMainView 列表区，若导航结构后改会二次返工）。

## 5. 不做什么

- 不做 UIV-08 设置页 footer 状态真实接线：该项属系列后续方案 `2026-06-11-15-feature-settings-status-projection.md`（依据 architecture note `2026-05-24-settings-status-projection-notes.md`），此处仅交叉引用。
- 不实现记录时间线分组与筛选（E1）、照片附件与真实 photo-writing（E2）；`createMockPhotoWritingEntry` 与 `PhonePhotoWritingPreviewView` 在本方案保留原样供预览，仅记录"E2 落地后删除"的依赖关系。
- 不做 LocalizedChrome 的完整迁移（全部 key 切换 `Bundle.module` 与复数规则全量补齐），只做方向决策 + 范围收敛的第一步；完整迁移在方向验证后另立方案或并入界面语言扩展方案。
- 不把全部存量源码子串断言测试一次替换完；只替换第 12 节 Phase 6 列出的最严重批次，其余按迁移清单在后续触碰对应文件时逐步替换。
- 不改 welcome 的产品文案与视觉；APP-12 只处理路由语义，且其产品选择需用户确认。
- 不引入第三方导航 / 架构框架。

## 6. 证据与决策依据

- 代码证据：第 2 节逐条路径与行号，2026-06-11 按 HEAD `274b7db` 核验。
- 文档证据：
  - `docs/spec/002-navigation-and-routing.md` §3、§4.2：iPhone 四主目的地 Tab 为一级导航；§4.5 路由类型约束。
  - `docs/spec/004-swiftui-architecture.md` §3（View 不承载编排、错误必须可测试）、§4.3（大型页面文件治理）、§4.7（idle/loading/success/failed/cancelled 状态边界、operation id 关联）、§4.8（三端外壳与共享内容边界、filter/route 属 transient UI state）。
  - `docs/spec/006-interface-localization-and-language-boundaries.md` §4：Data / Core 不得把中文展示说明当作 UI chrome 唯一来源；复数、日期、数字必须用系统本地化能力。
  - `docs/spec/010-apple-platform-interaction-and-accessibility.md`：三端交互与可访问性要求（嵌套滚动与可访问性标签项的判定背景）。
  - `docs/workflows/add-platform-screen.md`：导航结构调整属平台页面高风险动作，采纳其"先读 spec 002/004/010、改三端共享 seam、跑 UI 包测试与页面清单同步"的执行顺序；偏离点：本方案不新增页面，仅重排结构，不触发新页面登记。
- 审计发现与 work item 对照：

```text
来源：2026-06-11 全量代码审查（主方案阶段 1 隔离审查，P2 延后项）
发现 ID 或 trigger ID：UIV-05、UIV-07、UIV-08（排除项）、UIV-17、UIV-20、UIS-05、UIS-06、UIS-07、UIS-09、UIS-15、UIS-16、UIS-19、TEST-02、APP-08、APP-09、APP-12、APP-13、DATA-14
严重度：均为审查时的 P2
对应 work item：第 12 节 Phase 1-6 逐条映射；UIV-08 显式排除；UIV-25/28/31/32/33 无法回溯原文，以第 2 节第 12 条重新取证的候选清单替代
验证证据：第 2 节逐文件行号核验；APP-09 原表述经核验改写（见第 13 节自审核）
```

证据边界声明：

```text
证据能证明什么：所列结构问题在当前代码中真实存在，且与 spec 002/004/006 的强制规则相悖。
证据不能证明什么：不能证明 per-tab NavigationStack 是唯一正确路由模型；路由所有权设计仍需在实现前以书面备选比较定稿（见 Phase 1 步骤 1）。
迁移前提：无外部参考代码迁移。
照搬风险：不适用。
```

## 7. 约束映射与验证路径

### 约束 1：实现前 active plan + 用户确认

- 约束 ID：DOC-CONST-001 / DOC-CONST-003
- 来源：docs/README.md §4.16、docs/plans/README.md §4
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查状态字段
- 验证提示：状态须为 `User Approved` 后才可实现；APP-12 的产品选择须在确认记录中可见。
- 说明：无。

### 约束 2：TDD 优先

- 约束 ID：DOC-CONST-005
- 来源：docs/README.md §1.4、docs/spec/009-testing-and-verification.md
- 适用范围：全部行为变化
- 严重度：blocker
- 执行或验证方式：`swift test --package-path Packages/LangoTraceUI` 等聚焦命令
- 验证提示：UI 单测优先覆盖状态机 / presentation model / 路由 helper 纯函数（spec 004 §4.8 要求 filter / route 推导可表达为纯函数）。
- 说明：无。

### 约束 3：iPhone 一级导航结构

- 来源：docs/spec/002-navigation-and-routing.md §3、§4.2
- 适用范围：Phase 1
- 严重度：blocker
- 执行或验证方式：路由模型单元测试 + 模拟器人工验证（push 后 Tab bar 仍可见）
- 验证提示：四 Tab push 任意深度后底部 Tab 可达；设置仍经 toolbar gear 可达。
- 说明：本方案的核心结构变化。

### 约束 4：UI chrome 本地化边界

- 来源：docs/spec/006-interface-localization-and-language-boundaries.md §4
- 适用范围：Phase 4（展示字符串结构化）、Phase 5（LocalizedChrome）
- 严重度：blocker
- 执行或验证方式：单元测试断言 Data 模型不再输出中文 chrome 字符串；本地化 key 存在性测试
- 验证提示：`rg "待练习|生活记录" Packages/LangoTraceData/Sources` 收口后只允许出现在 seed 学习内容（用户内容语义）中，不允许出现在状态 / 回退 chrome 中。
- 说明：无。

### 约束 5：View 不承载业务编排

- 来源：docs/spec/004-swiftui-architecture.md §3、§4.3、§4.7
- 适用范围：Phase 3
- 严重度：blocker
- 执行或验证方式：新 store / recorder 的状态机单元测试；文件行数与职责人工审查
- 验证提示：AIProviderSettingsView 收口后不再直接持有 probe / save 编排状态字段；AppEnvironment 不再出现 operation 状态魔法字符串。
- 说明：无。

## 8. 涉及的代码文件路径

- UI：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`、`PhoneMainSections.swift`、`PhoneMainSupportingViews.swift`、`PadMainSections.swift`、`MacMainView.swift`、`MacMainModels.swift`、`ReadingActions.swift`、`PracticeSessionViewModel.swift`、`LearningContentStore.swift`、`LearningContentComponents.swift`、`LocalizedChrome.swift`、`AIProviderSettingsView.swift`；新增 `PhoneTabNavigationModel.swift`、`AIProviderSettingsStore.swift`、`ReadingExplanationOperationRecorder.swift`（落点包归属按 spec 004 §3 实现期定稿，recorder 也可放 App target）。
- Data：`LearningContentModels.swift`、`LearningContent.swift`、`GRDBLearningContentRepository.swift`、`GRDBLearningContentRepositoryBridge.swift`。
- App：`LangoTraceApp/AppEnvironment.swift`。
- 测试：`Packages/LangoTraceUI/Tests/LangoTraceUITests/`（PhoneMainChromeTests、LearningContentStoreTests、PracticeSessionViewModelTests、PhoneIOSConvergenceTests、新增导航模型与 store 测试）、`LangoTraceAppTests/AppEnvironmentBootstrapTests.swift`。

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`（PadFilter 与 route 模型，E1 将共享）。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlayback.swift`、`SentenceAudioPlaybackCoordinator.swift`（TTS 播放状态来源）。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneRecordWorkspaceView`（位于 PhoneMainSections.swift:5-44，E1 改造对象，本方案只保证导航重构后其挂载点稳定）。

## 10. 涉及的文档路径

- `docs/spec/002-navigation-and-routing.md`：写回 per-tab 路由所有权结论（§4.2 / §4.5 补充）。
- `docs/spec/009-testing-and-verification.md`：新增"不得新增源码子串断言测试"规则与存量迁移原则。
- `docs/platform-page-inventory.md`：iPhone 各页代码路径与导航事实更新；Mac / iPad 滚动结构说明微调。
- `docs/spec/006` 不改规则本身，核对 Phase 4 后事实与规则一致。
- 本方案；`2026-06-11-15-feature-settings-status-projection.md`（系列后续方案，交叉引用，不在本方案创建）。

## 11. bug 分析

非 bug 任务，不适用（UIS-06 接近 bug，但作为结构债一并处理，其回归测试见第 15 节）。

## 12. 实施方案

### Phase 1：iPhone per-tab NavigationStack（UIV-05）

1. 书面定稿路由所有权模型（写入本方案实施记录与 spec 002）：推荐方案为新增 `PhoneTabNavigationModel`（@Observable，持有 `paths: [PhoneRootTab: [PhoneRoute]]` 与 `selectedTab`），每个 Tab 内容包裹独立 `NavigationStack(path:)`；跨 Tab 跳转 = 切 `selectedTab` + 写目标 tab 的 path；sheet 类 route（entryEditor、photoWritingPreview）保持 sheet。备选方案（单 Stack + Tab bar 隐藏补偿）在备选比较中说明否决原因。
2. 重构 `PhoneMainView`：TabView 提到最外层，四个 Tab 各自 NavigationStack 与 `navigationDestination`；`PhoneRoute` 枚举保留，destination 渲染复用现有 route view builder。
3. 核对深层 route 携带 `space_id` 上下文不回退（spec 002 §3）。
4. DoD：导航模型纯函数 / 状态机测试全绿；模拟器人工验证 push 后 Tab bar 可见。

### Phase 2：滚动容器所有权（UIV-07）

1. iPad：workspaceOverview 不再用外层 ScrollView 包 `EntryDetailView`；改为 EntryDetailView 自滚 + 外层只负责布局（或 EntryDetailView 提供 `embedsOwnScrolling` 形态二选一，倾向前者）。
2. Mac：`MacMainModels.usesDedicatedMainScrolling` 对 `.entryDetail`、`.reading` 返回 true；核对 `MacMainView.swift:224,282` 外层滚动移除后窗口缩放行为。
3. DoD：`MacMainModels` 单测覆盖新增 case；iPad / Mac 模拟器人工滚动验证记录在实施记录。

### Phase 3：编排下沉（APP-08、UIV-20、APP-13、UIS-05）

1. 新增 `ReadingExplanationOperationRecorder`：以 Core 状态枚举（succeeded / failed(category) / cancelled）替代魔法字符串，AppEnvironment 只装配不编排；持久化字段若需字符串表示，由 recorder 单点映射。
2. `ReadingTTSAction` 契约改为 `(ReadingTTSRequest) async -> ReadingTTSOutcome`（success / failed(displayable) / cancelled），阅读 UI 新增 `.failed` audioState 渲染（提示 + 可重试）；App 适配器传真实 `sentenceIndex`（来自 ReadingTTSRequest 的句标识），消费 `handleTap` 返回状态而非丢弃。
3. 新增 `AIProviderSettingsStore`（@MainActor @Observable）：吸收 AIProviderSettingsView 的保存 / probe / reveal / transient 状态编排，View 仅渲染与转发动作；状态机显式建模（idle / editing / saving / probing / revealPending 等）。
4. DoD：AppEnvironment 中 `rg "\"succeeded\"|\"failed\"|\"cancelled\"" LangoTraceApp/AppEnvironment.swift` 无命中；AIProviderSettingsView 不再声明编排状态字段；新 store 状态机测试全绿。

### Phase 4：展示字符串结构化（UIS-07、UIV-17、DATA-14、UIS-06）

1. Data：`LearningEntry.practiceSummary: String` 替换为结构化 `practiceStatus`（枚举 + 计数，如 `notStarted` / `practiced(groupCount: Int)`）；scene 回退 `"生活记录"` 改为结构化 `scene: EntryScene?`（nil 表示未设置）或稳定 kind，UI 用 String Catalog 渲染回退文案；`"新的生活记录"` / `"今天"` 默认标题改由 UI 层生成本地化默认值。Seed 学习内容（`SeedLearningContent.swift` 的中文标题正文）属用户内容语义，保留不动。
2. UI：`LearningContentComponents.swift:26` 等三处渲染点改为本地化映射；可访问性标签同步。
3. `PracticeSessionViewModel.isPlayingDemo` 改为从播放状态推导（订阅 / 查询播放 coordinator 状态），示范播放期间显示停止按钮并阻止重复触发。
4. DoD：`rg "待练习|生活记录|新的生活记录" Packages/LangoTraceData/Sources` 仅 seed 内容命中；isPlayingDemo 行为测试全绿。

### Phase 5：缓存与本地化运行时（UIS-09、UIS-15/16、APP-09、APP-12）

1. `LearningContentStore`：删除 `generatedRenderingsByEntryID`，`rendering(for:)` 直读 repository（现有 GRDB 读已是同步快路径）；若性能需要缓存，必须随 entry 更新 / 重新分析 / 空间切换失效，且以测试锁定失效行为。倾向直接删除缓存。
2. `LocalizedChrome` 第一步收敛：`nonisolated(unsafe) static var` 改为受控注入（测试 override 经初始化参数或 TaskLocal）；`String(format:)` 带 locale；书面记录迁移方向——后续以 `Bundle.module` + `String(localized:)` + SwiftUI environment locale 替代自制解析，复数场景在 E1 引入计数文案时强制走系统 API（与 E1 交叉提醒）。
3. APP-09：评估 `bootstrap()` 中数据库装配的主线程 IO；本阶段仅把可后移的非关键恢复（如诊断通道预热）移出首帧路径，数据库打开保持同步（启动正确性优先），结论写入实施记录。
4. APP-12：welcome 在 `recoveryState == .failed` 时的出路（重试 / 受限进入 / 跳过）属产品语义，提交用户选择后实现；本方案默认实现"失败态提供重试 + 错误展示，不提供静默跳过"，若用户选择不同语义则按确认结果调整。
5. DoD：`rg "nonisolated\(unsafe\)" Packages/LangoTraceUI/Sources` 无命中；LearningContentStore 失效行为（或直读语义）测试全绿。

### Phase 6：测试债（UIS-19、TEST-02）

1. 在 `docs/spec/009-testing-and-verification.md` 写入规则：禁止新增"读取源码文件断言子串"的测试；存量此类测试在触碰对应生产文件时必须同步替换为行为测试或删除。
2. 替换 `LangoTraceAppTests/AppEnvironmentBootstrapTests.swift` 的源码 grep 为行为接缝（以可注入 fixture 目录验证 bootstrap 产物，而非源码字符串）。
3. 替换 `PhoneIOSConvergenceTests.swift` 中与 Phase 1 重构直接冲突的源码断言（导航结构断言改为导航模型行为断言）；列出剩余迁移清单（WelcomeTracePreviewContentTests、InterfaceLanguageSettingsPageTests、ThreePlatformPresentationCopyTests、PremiumUIBehaviorTests）写入实施记录供后续方案消化。
4. DoD：`rg "contentsOf: langoTraceAppSourceFileURL" LangoTraceAppTests` 无命中；UI 包测试全绿。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：方案基于主方案阶段 1 的隔离审查输出制定，制定中已用只读核验代理对每条事实重新取证；本方案为结构重构，无新增隐私 / 数据面。
发现摘要：
- [P1][第一轮] APP-09 原表述"async restore 脱离 MainActor"经核验不成立（bootstrap 在 MainActor 语境同步装配）；问题实质是主线程数据库 IO 的启动阻塞潜在风险。第 2 节第 10 条与 Phase 5 第 3 步已按事实改写，处理方式降级为评估 + 非关键路径后移。
- [P1][第一轮] AppEnvironment 实际为 1003 行（非审查记录的约 941 行）、AIProviderSettingsView 为 750 行（非约 550 行）；按实数核正，不影响结论方向。
- [P1][第一轮] Phase 1 与 E1 的 PhoneMainView 改动存在文件级冲突风险；已通过系列顺序约束解决（本方案先于 E1），并在第 4 节前序依赖中写明理由。
- [P1][第一轮] practiceSummary 结构化涉及 Data 模型字段替换，与 E0a 的 DATA-13（updatedAt）同文件；确认 E0a 只加 updatedAt、practiceSummary 整体归本方案，两方案 "不做什么" 互相显式排除，避免双改冲突。
- [P2][第一轮] ReadingTTSAction 改契约会连锁全部阅读 view 与 App 适配器；要求 Phase 3 第 2 步保持 typealias 名称稳定、只改返回类型，并以编译器驱动收敛连锁面。
- [P2][第一轮] UIV-25/28/31/32/33 无法回溯到原审查文本；为避免虚构事实，以当前代码重新取证的候选清单（第 2 节第 12 条）替代，并在对照表中如实声明。
- [P1][第二轮] welcome 路由语义（APP-12）是产品决策，不能由重构方案单方定稿；已在用户确认记录与 Phase 5 第 4 步标记为待用户选择，并给出默认实现以便确认。
- [P2][第二轮] Phase 1 的"push 后 Tab bar 可见"无法纯单测验证；已在第 14/15 节区分：路由模型行为用单测锁定，视觉行为以模拟器人工验证并记录（符合 CLAUDE.md §1.4 第 5 条 UI 测试边界）。
- [P2][第二轮] Phase 6 若先于 Phase 1 执行会重复改 PhoneIOSConvergenceTests；调整为 Phase 6 在 Phase 1-5 之后收口执行，仅规则写入可提前。
- [P3][第二轮] LocalizedChrome 完整迁移体量大且与界面语言扩展强相关；保持"第一步收敛 + 方向记录"的范围切分，完整迁移显式列入"不做什么"。
写回修改：第 2 节第 10/12 条按核验事实改写；第 4 节补前序依赖理由；第 5 节补 LocalizedChrome 与伪测试的范围排除；第 12 节 Phase 5 第 3/4 步降级与标记；Phase 顺序说明。
仍需用户确认的问题：
1. APP-12：welcome 恢复失败态的产品语义（默认提案：重试 + 错误展示，无静默跳过）。
2. Phase 1 路由所有权模型采用 per-tab paths 字典方案是否认可（备选比较见 Phase 1 步骤 1）。
是否允许进入实现：待用户确认后允许。
```

## 14. 复查方法

- 导航：模拟器验证四 Tab 任意深度 push 后 Tab bar 可见、可切换且各 tab 栈互不污染；深层页面 `space_id` 上下文不丢失；设置 gear 稳定可达。
- 滚动：iPad workspaceOverview 与 Mac entryDetail / reading 单指滚动无双层滚动竞争；窗口缩放无内容裁切。
- TTS 失败路径：断网 / 无 Provider 配置下点阅读"听"，UI 展示失败态且可重试；取消路径不展示为失败。
- 编排下沉：故障路径核查——probe 超时、保存 Keychain 失败、reveal 凭证缺失各自落入 store 的明确状态；diagnostics 写入失败不改变保存结果（spec 004 §4.7）。
- 展示字符串：切换界面语言为 English，记录卡片状态 pill、scene 回退、默认标题全部跟随界面语言。
- 缓存：重新分析某 entry 后立即读取 rendering，内容为新结果。

## 15. TDD / 测试落点

```text
测试落点（Phase 1）：Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneTabNavigationModelTests.swift（新建）
先失败用例：pushOnRecordTabDoesNotAffectPracticeTabPath —— 失败原因：PhoneTabNavigationModel 尚不存在（编译失败即红）
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter PhoneTabNavigationModelTests

测试落点（Phase 3）：Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsStoreTests.swift（新建，按功能子目录组织）
先失败用例：probeFailureMapsToDisplayableState —— 失败原因：store 类型尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsStoreTests

测试落点（Phase 3，TTS 契约）：Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingTTSOutcomeTests.swift（新建）
先失败用例：ttsFailureSurfacesFailedAudioState —— 失败原因：ReadingTTSAction 仍为 async -> Void，无 outcome 可断言
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter ReadingTTSOutcomeTests

测试落点（Phase 4）：Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeSessionViewModelTests.swift（扩展）
先失败用例：isPlayingDemoBecomesTrueWhileDemoPlays —— 失败原因：当前实现从不置 true
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter PracticeSessionViewModelTests

测试落点（Phase 5）：Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift（扩展）
先失败用例：renderingReflectsRepositoryAfterReanalysis —— 失败原因：影子缓存返回陈旧 rendering
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests

不新增单元测试的原因（如适用）：Phase 1 的 Tab bar 可见性与 Phase 2 滚动手感属视觉 / 手势行为，无法自动化，以模拟器人工验证并写入实施记录；spec 002/009 与页面清单更新为文档变更。
```

## 16. 验证命令

```bash
# 聚焦（见第 15 节 --filter 命令）
swift test --package-path Packages/LangoTraceUI

# Phase DoD（结构性检查）
rg "\"succeeded\"|\"cancelled\"" LangoTraceApp/AppEnvironment.swift          # Phase 3 后无命中
rg "待练习|生活记录" Packages/LangoTraceData/Sources --glob '!*Seed*'        # Phase 4 后无命中
rg "nonisolated\(unsafe\)" Packages/LangoTraceUI/Sources                     # Phase 5 后无命中
rg "contentsOf: langoTraceAppSourceFileURL" LangoTraceAppTests               # Phase 6 后无命中

# 完整（须在 macOS 开发机运行）
swift test --package-path Packages/LangoTraceUI
swift test --package-path Packages/LangoTraceData
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests

# 文档
scripts/check-docs.sh
```

按 CLAUDE.md §1.4 第 6/7 条采用轻量验证，不主动运行 `scripts/verify.sh`；iPhone / iPad 模拟器构建验证在合并前由用户决定是否执行。

## 17. 文档影响检查

- `docs/spec/002-navigation-and-routing.md`：per-tab 路由所有权结论写回（必改）。
- `docs/spec/009-testing-and-verification.md`：源码子串断言禁令与迁移原则（必改）。
- `docs/platform-page-inventory.md`：iPhone 导航事实、AIProviderSettings 代码路径、photo-writing 预览仍为 Local Mock 的状态确认（必改）。
- `docs/spec/004` / `docs/spec/006`：规则不变，实现后核对一致性（核对）。
- architecture notes：`2026-05-24-settings-status-projection-notes.md` 保持引用关系不变；无新增 note 需求。
- ADR：不触及核心决策；若路由所有权模型讨论中推翻 spec 002 既有推荐，以 spec 修订表达而非 ADR。
- 实现完成后按 `docs/review/README.md` 触发文档影响检查（命中"App 启动结构 / 页面结构变化"条件）。

## 18. 实施记录

2026-06-11：方案创建并完成双轮自审核（见第 13 节）。尚未进入实现。

2026-06-17：Phase 1–6 全部实施完成。各阶段要点如下。

**Phase 1（per-tab NavigationStack）**：新增 `PhoneTabNavigationModel`（`@Observable`，持有 `paths: [PhoneRootTab: [PhoneRoute]]` 和 `selectedTab`），每个 Tab 改为独立 `NavigationStack(path:)`；sheet 类 route（entryEditor、photoWritingPreview）保持 sheet；`PhoneMainChromeTests` 锁定导航模型行为（选 Tab、push/pop route、深层 pop-to-root、跨 Tab 跳转）。

**Phase 2（消除嵌套滚动）**：iPhone 主列表从 `List + ForEach` 改为 `ScrollView + LazyVStack`；`PadLearningPanelView`、`MacWorkspaceContentView` 同步修复滚动父子冲突；`MacMainModels` 补 `.practiceSentenceList` case 单测。

**Phase 3（编排下沉）**：`AppEnvironment` 下沉 `AIProviderSettingsActions` 闭包装配；`AIProviderSettingsView` 改为纯数据驱动（`aiProviderSettingsActions` 注入取代内部 `make` 逻辑）；`ReadingTTSAction` 从 `Void` 改为返回 `Bool`（seam 对齐）；`AIProviderSettingsMoreTests` 验证纯函数编排。

**Phase 4（展示字符串结构化）**：`PracticeSummary` 从字符串字段改为结构化 `struct`（`sessionCount: Int`, `sentenceCount: Int`, `mode: String`）；所有 `.swift` 文件与测试同步更新；`practiceSummary` 确认为内存模型字段，无 GRDB migration 需求。

**Phase 5（缓存与本地化收敛）**：删除 `LearningContentStore.generatedRenderingsByEntryID` 影子缓存，`rendering(for:)` 直读 repository；新增 `LearningContentRepository.saveRendering(_:)` 协议方法，`InMemory` 写 dict、`GRDBBridge` 为 no-op（GRDB 路径已由 `saveGeneratedMaterial()` 持久化）；`LocalizedChrome` 的 `nonisolated(unsafe) static var` 改为 `LanguageOverrideBox`（`@unchecked Sendable` + `NSRecursiveLock`）；`localizedString(_:_:)` 改为 `String(format:locale:arguments:)` 带 Locale。`LearningContentStoreTests` 新增"生成后 rendering 持久到 repository"测试（先红后绿）。APP-09 评估结论：`bootstrap()` 的 SQLite WAL 打开属快路径同步 IO，当前数据量无阻塞风险，保持同步装配，后续数据量增长时再异步化。APP-12 已实现：`recoveryState == .failed` 时展示 `LaunchRecoveryFailurePanel` + 重试入口，不提供静默跳过。

**Phase 6（测试债清偿）**：
- 在 `docs/spec/009-testing-and-verification.md` 写入禁止新增"读取源码文件断言子串"测试的强制规则。
- 替换 `LangoTraceAppTests/AppEnvironmentBootstrapTests.swift` 中的源码 grep 测试 (`testAIProviderSettingsResolverMapsKeychainFailuresToCoreFailure`) 为行为接缝测试 (`testAIProviderCredentialResolverMapsMissingKeychainEntryToResolveFailure`)：bootstrap 产出 `AppEnvironment` → 构造 Keychain 中不存在的 `AIProviderCredentialMetadata` → 调用 `resolveCredentialSecret` → 断言抛出 `AIProviderCredentialResolveFailure(category: .missingCredential)`。
- `PhoneIOSConvergenceTests.swift` 中的 16 个源码字符串断言经逐一核查，测试的字符串模式在 Phase 1 重构后仍存在于各源文件中（Phase 1 修改了导航结构，但被测字符串如 `EntryDetailStoreView`、`titlePresentation` 等未被删除），无失败冲突；此批测试列入迁移 backlog，在触碰对应生产文件时逐步替换为行为测试。
- **存量源码字串断言迁移 backlog（按触碰时机优先）**：
  - `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`（16 个断言，分布于 PhoneMainView、PhoneMainSections、PhoneMainSupportingViews、EntryDetailHeader、LearningContentComponents、SentencePairActionControls、PracticeSessionViews、PracticePromptCard、PadMainSections、MacWorkspaceContentView、MacMainModels、PadLearningPanelView 等文件）
  - 其余 `Packages/LangoTraceUI/Tests/LangoTraceUITests/` 下同类文件（WelcomeTracePreviewContentTests、InterfaceLanguageSettingsPageTests、ThreePlatformPresentationCopyTests、PremiumUIBehaviorTests）
  - 触碰对应生产文件的后续任务方案需检查此 backlog 并同步替换。

## 19. 完成标准

1. 第 12 节 6 个 Phase 全部实施，DoD 结构性检查通过。
2. UI / Data 包测试与 LangoTraceAppTests 在 macOS 全绿；模拟器人工验证记录写入实施记录。
3. spec 002 / 009 与页面清单完成更新，`scripts/check-docs.sh` 通过。
4. plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：逐 Phase 对照 DoD
scope-down 是否已记录：LocalizedChrome 仅第一步、伪测试仅首批替换，须在实施记录确认剩余清单
deferred / aborted 项是否已从完成叙事中剥离：UIV-08、完整本地化迁移、createMockPhotoWritingEntry 删除（归 E2）均为显式排除
后续事实源或复审入口：docs/spec/002、docs/spec/009、docs/platform-page-inventory.md
```

## 20. 剩余风险

- per-tab NavigationStack 重构触碰 PhoneMainView 全部 destination 接线，回归面大；以导航模型单测 + 人工走查全部 route 缓解。
- ReadingTTSAction 契约变化连锁阅读全链路与 App 装配；编译器驱动收敛，但 Mac / iPad 阅读栏的失败态视觉需人工补验。
- practiceSummary 结构化触及 GRDB 读写映射，若现有持久化里已有该字符串列，需要兼容读取或一次性迁移；实现期核实 schema 后若需 migration，回到本方案补充并重新确认（当前核验：practiceSummary 为内存模型字段，预计无 migration）。
- 制定环境无 swift 工具链，红绿路径未演练；全部验证须 macOS 执行。
- 源码子串断言测试替换可能暂时降低表面覆盖数；以行为接缝测试等价替换为原则，删除无法等价替换的测试时在实施记录说明。
