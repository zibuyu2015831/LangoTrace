# 任务方案：练习跟读单句页改为「句子舞台 + 底部控制台」布局

状态：User Approved
自审核状态：Reviewed
类型：refactor
创建日期：2026-06-18
最后更新日期：2026-06-18

## 用户确认记录

- 2026-06-18：用户提供 iPhone 17 模拟器截图，指出练习单句页「句子展示区右侧 / 下方留下大量空白」，要求调用设计 skill 分析并优化。设计评审给出三方向（A 垂直再平衡 / B 句子舞台+底部控制台 / C 信息密度型），推荐方向 B。
- 2026-06-18：用户指示「先起草 active plan 文档并按照开发要求完成自审（可以使用子代理）」。本方案据此按推荐的方向 B 起草并已完成隔离双轮自审核。
- 2026-06-18：用户就自审核 §12 两个待确认点 + 实现授权作出决定：① **macOS 也一起改**（三端统一舞台 + 控制台，不再 `#if os(iOS)` 保留 macOS 现状）；② 短句无释义时**句子垂直居中 Hero**；③ **授权进入实现**。状态推进到 `User Approved`。
- 2026-06-18：用户补充约束：**重量级验证（iPhone 模拟器 clean build、全量 / 跨包测试）走 GitHub Actions，本机只做轻量自查**（对齐 CLAUDE.md §1.8.8）。

## 1. 需求或 bug 描述

练习「跟读」单句页（`PracticeShadowingSessionView`）在 iPhone 上内容只占据屏幕上半部分（约 55%），下半屏整片空白；句子卡左对齐、短行右侧拖尾，叠加成「右侧 + 下方大片空白」的失衡观感。需要在不破坏既有跟读闭环、隐私边界和已沉淀的「不显示重复 header / 不预留大块空白」决策前提下，让页面主动占有画布、突出朗读主体。

这是 UI 结构优化，不是功能缺陷；当前功能可用，问题是布局没有分配画布。

## 2. 现状描述

事实源：`Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`。

- `PracticeSessionView`（line 191）按 exercise type 分发：`dictation` → `PracticeDictationSessionView`、`backtranslation` → `PracticeBacktranslationSessionView`、`shadowing` → `PracticeShadowingSessionView`。三端唯一入口已核验：`PhoneMainView.swift:239`、`PadMainSections.swift:165`、`MacWorkspaceContentView.swift:58`，**跟读会话体三端共享**。
- `PracticeShadowingSessionView.body`（line 283）：`ScrollView { VStack(alignment:.leading, spacing:18){ PracticePromptCard; PracticeControlBar; PracticeSentenceNavigationBar; failure/noContent }.padding(20) }`。
- 留白根因：`ScrollView` 内三张紧凑卡片按固有高度排版并顶到顶部，无垂直分配，852pt 高画布剩下半屏空置。
- `PracticePromptCard(` / `PracticeControlBar(` 经 grep 确认**生产代码唯一调用点**均在 `PracticeSessionViews.swift`（:286 / :298），听写 / 回译会话各有内容卡，不复用本卡片。
- `PracticeControlBar.swift:51` 自身已 `.langoPanel(padding:14)`，主按钮 `.tint(LangoTraceDesign.ColorToken.primaryActionFill)`（:48）。
- `PracticePromptCard.body`：`VStack(alignment:.leading, spacing:14)`，句子 `.font(.title3.weight(.semibold))` 左对齐 + disclosure（`ViewThatFits` → `HStack(alignment:.center, spacing:16)`）。
- **源码字符串断言（会被本重构触及的测试，已逐一核验）**：
  - `PhoneIOSConvergenceTests`：`practiceSessionKeepsInlineNavigationTitle...` 要求 `PracticeSessionViews.swift` 含 `PracticeSessionView`、`.navigationTitle(localizedText("practice.title"))`、`.langoPracticeInlineNavigationTitle()`、`navigationBarTitleDisplayMode(.inline)`、`#if os(iOS)`；`practicePromptDisclosuresReset...` 要求 disclosure state、`resetPromptDisclosures()`、`.onChange(of: routeSeed.practiceRouteIdentity)`、`PracticePromptCard(`，以及 `PracticePromptCard.swift` 含 `displayedTranslationText` / `disclosureControls` / `ViewThatFits(in: .horizontal)` / `HStack(alignment: .center, spacing: 16)` / `explanationParagraphs` / `VStack(alignment: .leading, spacing: 8)` / 两个 toggle hint，且不得含 `PracticePromptCardLayout.collapsedMinHeight` / `PracticeSnapshotPanel(`。
  - `ThreePlatformPresentationCopyTests.swift:54-55`：对 `PracticePromptCard.swift`、`PracticeSessionViews.swift` 跑 `forbiddenHardCodedTerms` 硬编码文案扫描。
  - `AppearanceSettingsTests.swift:134/142`：要求 `PracticeControlBar.swift` 含 `LangoTraceDesign.ColorToken.primaryActionFill`。
  - `PracticeRouteSeedTests.swift:238-310`：直接构造并断言 `PracticePromptCardPresentation` 行为（含 :278 两个 toggle 都 false 的 blank 句 case）。
- 权威约束（已核验）：
  - `docs/spec/013-practice-learning-domain.md:68`：「练习列表与单句页在 macOS 使用 dedicated main scrolling，不被工作台外层 `ScrollView` 再包裹」。
  - `docs/spec/003-ui-design-system.md:134`：`PracticeSentenceNavigationBar` 应放在**操作卡之后**；:136：句间导航**不得**用 filled primary CTA、三等分状态块或 `.langoPanel()` 再包一层卡片；:280/302：filled primary CTA 必须用 `primaryActionFill` token。
  - `docs/platform-page-inventory.md` L54：跟读单句页「不显示重复 header / 常驻指导文案 / 不可点击阶段 pill / 底部 step card」「隐藏释义或讲解时不预留大块空白」。

## 3. 目标

1. iPhone / iPad（iOS）跟读单句页内容**占满会话视口高度**，消除下半屏死区。
2. 句子升为 Hero 主体（更大字号、居中对齐）；展开释义 / 讲解时随主滚动自然滚动，短内容时居中、不在底部留死区。
3. `听 / 回放录音 / 开始录音` 与句间导航**停靠为底部控制台**，但句间导航保持无卡片样式、位于操作卡之后（遵守 spec 003）。
4. 完整保留：跟读闭环、disclosure 逻辑与路由级重置、录音本地优先 / 不外发 / 不默认导出边界、inline navigation title、`primaryActionFill` 主按钮 token。
5. 不引入装饰性填充（不加 eyebrow 标题、不加静态波形）。
6. **三端统一**应用舞台 + 控制台：iPhone / iPad / macOS 共享同一 `PracticeShadowingSessionView` 重构；通过**单一 `ScrollView` + `.safeAreaInset(.bottom)`** 实现，保持「单句页单一主滚动体、不被外层 ScrollView 包裹」，满足 spec 013:68（不引入嵌套主滚动体，macOS 现状即直接渲染 `PracticeSessionView`、无外层包裹）。
7. iPhone 17 模拟器截图验证（CI，含短句无释义、失败态）；iPad / macOS 大屏停靠 deck 观感延后人工验收。

## 4. 范围

代码：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`（`PracticeShadowingSessionView.body` 三端统一重构为单一 ScrollView + safeAreaInset 停靠 deck）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift`（**仅** View 新增 `isCentered: Bool = false`；**不改** `PracticePromptCardPresentation` 的 init / 语义）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`（如复用进 deck，仅容器包裹；保留 `.langoPanel` 与 `primaryActionFill`）
- 新增 `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeShadowingLayout.swift`（带 `resolve(...)` 决策函数的 layout-intent 模型）

测试：

- 新增 `Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeShadowingLayoutTests.swift`
- 按需更新 `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- 回归确认（不应破坏）：`ThreePlatformPresentationCopyTests`、`AppearanceSettingsTests`、`PracticeRouteSeedTests`

文档：`docs/platform-page-inventory.md`、`docs/spec/learning-content/impl.md`、本方案。

## 5. 不做什么

- 不改听写 / 回译会话布局（不复用本卡片）。
- 不引入嵌套主滚动体（保持单一 ScrollView，遵守 spec 013:68）；不优化 iPad / macOS 大屏专属交互（仅共享同一重构）。
- 不新增波形对比 / 历次尝试列表 / 发音评分 / ASR / 原声波形（方向 C，另起方案）。
- 不恢复被历史决策移除的元素（重复 header / 常驻指导文案 / 阶段 pill / step card）。
- 不新增本地化文案 key；不改 `PracticePromptCardPresentation` init 签名。
- 不改 `PracticeSessionRouteSeed` / `PracticeActions` / `PracticeSessionViewModel` / GRDB practice 数据 / 媒体资产 / 录音外发与导出边界。

## 6. 证据与决策依据

- 设计评审：根因为「小内容塞进大容器」的垂直失衡；推荐方向 B（舞台 + 底部控制台），已吸收方向 A 的「分页停靠底部」。
- **自审核更优设计采纳**：放弃原 `GeometryReader{ VStack{ ScrollView; deck } }`（违反 spec 013:68 且 deck 高度需手算、脆裂），改为**单一 `ScrollView` 作主滚动体 + `.safeAreaInset(edge:.bottom)` 停靠 deck**——系统自动测量并扣除 deck 高度，保持「单句页单一主滚动」语义，不引入嵌套主滚动体。
- anti-slop：去掉评审 mockup 的 eyebrow（违反「不显示重复 header / 常驻指导文案」）与装饰波形（无真实数据的 data-slop）；位置信息保留在底部句间导航。
- 复用确认（grep）：`PracticePromptCard` / `PracticeControlBar` 仅跟读会话使用，emphasis 改动不波及听写 / 回译。
- 无对应高风险 workflow（非 AI/TTS/migration/新页面/Prompt），属既有平台页面布局调整。

来源对照：用户运行期模拟器观察（非 review round / health ledger），trigger = 用户 2026-06-18 截图反馈，无 finding id。

## 7. 约束映射与验证路径

| 约束来源 | 规则 | 本方案处理 / 验证 |
|---|---|---|
| `docs/plans/plan-review-protocol.md` | 行为变化先写失败测试；实现前完成自审核 | `PracticeShadowingLayoutTests` 先红后绿；已完成隔离双轮自审（§12） |
| `docs/spec/013-practice-learning-domain.md:68` | 单句页 macOS dedicated main scrolling，不被外层 ScrollView 再包裹 | 三端统一用**单一 ScrollView + safeAreaInset**，不引入嵌套主滚动体；已核验 `MacWorkspaceContentView.swift:37/58` 直接渲染 `PracticeSessionView` 无外层包裹 |
| `docs/spec/003-ui-design-system.md:134` | 句间导航放在操作卡之后 | deck 内顺序：`PracticeControlBar` 在前、`PracticeSentenceNavigationBar` 在后 |
| `docs/spec/003-ui-design-system.md:136` | 句间导航不得用 filled CTA / 三等分块 / `.langoPanel()` 再包卡片 | nav bar 保持现有 plain 样式；deck 外壳只用背景 + 顶部 hairline，不对 nav bar 套 langoPanel |
| `docs/spec/003-ui-design-system.md:280/302` | filled primary CTA 用 `primaryActionFill` | `PracticeControlBar` 保留 `.tint(...primaryActionFill)`（亦满足 `AppearanceSettingsTests:142`） |
| `docs/spec/010-...accessibility.md` | 最小触达 44pt；VoiceOver 顺序 | 沿用既有 `minHeight:44/48`；deck 内 control→nav 顺序保持线性阅读合理（§18 人工验收） |
| `docs/spec/002-navigation-and-routing.md` | inline navigation title；route-local UI state | 保留 `navigationBarTitleDisplayMode(.inline)`；disclosure 仍 route-local |
| `docs/platform-page-inventory.md` L54 | 不显示重复 header / 不预留大块空白 | 不加 eyebrow / 波形；失败态顶部对齐避免居中漂移；改后更新该行事实 |
| `docs/README.md` §1.8.6/7 | 轻量验证，不主动跑 verify.sh | 见 §15 |

## 8. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- 新增 `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeShadowingLayout.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeShadowingLayoutTests.swift`（新增）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailPhotoPresentation.swift` + `Tests/.../PhotoWriting/EntryDetailPhotoLayoutTests.swift`（layout-intent 模型与测试范式）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`（`langoPanel`、`Spacing`、`Radius.panel=18`、`Density.minimumTouchTarget=44`、ColorToken）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeDictationSessionView.swift` / `PracticeBacktranslationSessionView.swift`（不复用本卡片的对照）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`（`PracticePromptCardPresentation` 行为基线，重构须保持绿）
- 设计 mockup（仓库外，可删）：`~/huashu-demos/langotrace-practice/practice-layout-directions.html`

## 10. 涉及的文档路径

- `docs/platform-page-inventory.md`
- `docs/spec/learning-content/impl.md`
- `docs/spec/013-practice-learning-domain.md`（约束来源，复核是否需同步措辞）
- `docs/spec/003-ui-design-system.md`（约束来源）
- 本文件

## 11. 实施方案

1. **TDD 红**：新增 `PracticeShadowingLayoutTests`，断言带真实输入→输出的 `resolve(...)`（见 §14）。类型不存在 → 编译失败（红）。
2. **实现 layout 模型**（有意义的决策函数，非 tautology）：
   ```swift
   enum PracticeShadowingStageAlignment: Equatable { case center, top }
   struct PracticeShadowingLayout: Equatable {
       var rendersControlDeck: Bool
       var stageAlignment: PracticeShadowingStageAlignment
       static func resolve(hasSession: Bool, hasVisibleFailure: Bool) -> PracticeShadowingLayout {
           guard hasSession else {
               return .init(rendersControlDeck: false, stageAlignment: .center) // noContent：居中状态行，不渲染 deck
           }
           return .init(rendersControlDeck: true,
                        stageAlignment: hasVisibleFailure ? .top : .center)      // 失败态顶部对齐保证可见
       }
   }
   ```
3. **prompt card 居中能力**：`PracticePromptCard`（View）新增 `isCentered: Bool = false`；`true` 时外层 `VStack` 用 `.center` 对齐、句子 `.multilineTextAlignment(.center)`、字号升为 `.title2.weight(.semibold)`。**不改** `PracticePromptCardPresentation`（保持 `PracticeRouteSeedTests` 绿）。保留 `disclosureControls` / `ViewThatFits` / `HStack(alignment:.center, spacing:16)` / `displayedTranslationText` / `explanationParagraphs` / `VStack(alignment:.leading, spacing:8)` / toggle hints（满足 convergence）。
4. **重构会话体**（按平台分支）：
   ```swift
   var body: some View {
       content                          // 见下，按 #if 分支
           .navigationTitle(localizedText("practice.title"))
           .langoPracticeInlineNavigationTitle()
           .langoPageBackground()
           .task { await viewModel.load() }
           .onChange(of: routeSeed.practiceRouteIdentity) { _, _ in resetPromptDisclosures() }
   }
   ```
   - **三端统一（iPhone / iPad / macOS）**，单一 ScrollView + safeAreaInset：
     ```swift
     let layout = PracticeShadowingLayout.resolve(hasSession: viewModel.session != nil,
                                                  hasVisibleFailure: viewModel.visibleFailure != nil)
     ScrollView {
         stageContent(isCentered: true)                 // PromptCard(isCentered:true) + failure 行
             .frame(maxWidth: 560,                        // 限制可读宽度，缓解 iPad/mac 右侧拖尾
                    alignment: .center)
             .frame(maxWidth: .infinity,
                    minHeight: measuredContainerHeight,   // 经 ScrollView .background(GeometryReader) 测得，已扣除 safeAreaInset deck
                    alignment: layout.stageAlignment == .center ? .center : .top)
             .padding(.horizontal, 24)
     }
     .safeAreaInset(edge: .bottom) {
         if layout.rendersControlDeck { controlDeck }    // 不渲染则无 deck（noContent）
     }
     ```
     - `measuredContainerHeight` 用 `.background(GeometryReader { ... })` 读取主滚动体自身高度（**不**用包裹式 GeometryReader，避免 P0-1 的嵌套形态）；safeAreaInset 已把 deck 高度从该高度扣除，无需手算 deckHeight。三端共用此结构：macOS 仍是该会话自有的单一主滚动体、不被外层包裹，满足 spec 013:68。
     - `controlDeck` = `VStack(spacing:12){ PracticeControlBar(...); PracticeSentenceNavigationBar(...) }`，外壳仅用背景填充 + 顶部 1pt hairline（**不**对 nav bar 套 `langoPanel`），底部留安全区 padding；内容同样限宽 560 居中。control bar 自带 panel 与 `primaryActionFill` 不变。
5. **保留字符串**：确保 `PracticeSessionViews.swift` 仍含 convergence 所需全部字符串（含 `#if os(iOS)`）；`PracticePromptCard.swift` 内部结构不删；不引入 `forbiddenHardCodedTerms` 命中的硬编码英文文案。
6. **convergence / 回归测试**：跑 `PhoneIOSConvergenceTests`、`ThreePlatformPresentationCopyTests`、`AppearanceSettingsTests`、`PracticeRouteSeedTests`；既有断言因字符串移动失败时按真实新结构修正（保留意图）；为 stage/deck 结构在 `PhoneIOSConvergenceTests` **追加**正向断言（源码含 `PracticeShadowingLayout` / `safeAreaInset`），不弱化既有约束。
7. **轻量验证 + 模拟器截图**（§15），含短句无释义态截图确认居中不突兀、失败态顶部对齐。
8. **文档影响**：更新页面清单 L54 与 impl.md 跟读布局事实；复核 spec 013:68 措辞是否需同步（三端仍单一主滚动体、不被外层包裹 → 预期无需改实质规则，仅在 plan 记录已核对）。

## 12. 严格方案自审核记录

审核日期：2026-06-18
审核方式：隔离审查（子代理只读上下文）+ 主会话核验证据并写回
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：不适用（已使用子代理隔离审查）

发现摘要与处理（均已用代码 / spec 行号核验）：

- [P0-1] 原 `GeometryReader{ ScrollView }` 违反 `spec 013:68` macOS 不嵌套滚动红线。证据：spec 013:68、`MacWorkspaceContentView.swift:37/58` 直接渲染 `PracticeSessionView` 无外层包裹。处理：改为单一 `ScrollView + safeAreaInset` 停靠 deck，保持单一主滚动体即满足 013:68；用户后续确认 macOS 一起改，故三端统一应用该结构（非 `#if` 门控）。已重写 §11.4、§7、§6。**阻塞 → 已解除**。
- [P0-2] 「强居中」在短句 / 无释义 / 失败态制造新空白或漂移。证据：L54、`PracticeRouteSeedTests:278` blank case。处理：引入 `resolve(hasSession:hasVisibleFailure:)`，失败态 `.top`、noContent 不渲染 deck；短句居中作为**有意 flashcard 构图**并用截图验证。已写入 §11.2、§14、§18。**阻塞 → 已解除**。
- [P1-1] deck 把 nav bar 包进 langoPanel 违反 `spec 003:136`，且顺序须在操作卡之后（:134）。处理：deck 外壳仅背景+hairline，nav bar 保持 plain 且置于 control bar 之后。已写入 §7、§11.4。
- [P1-2] 漏盘 `ThreePlatformPresentationCopyTests:54-55`、`AppearanceSettingsTests:142`、`PracticeRouteSeedTests`。证据：对应行号已核验。处理：`isCentered` 加在 View 不改 Presentation；保留 `primaryActionFill`；不加硬编码文案。已写入 §2、§4、§14。
- [P1-3] layout 测试为 tautology。处理：改为断言 `resolve(...)` 的输入→输出映射（真实回归价值）。已写入 §11.2、§14。
- [P2-1] 采纳 `safeAreaInset` 取代手算 deckHeight。已并入 §6、§11.4。
- [P2-2] VoiceOver 顺序随 deck 重排变化。处理：deck 内 control→nav 顺序固定；§18 记入人工验收。
- [P2-3] 失败态对齐与居中互斥。处理：由 `resolve` 决定失败态 `.top`。已并入 §11.2。
- [P3-1] spec 013 / 003 缺席约束表与文档影响。处理：已补入 §7、§10、§16。
- [P3-2] noContent 残留空 deck 高度。处理：`rendersControlDeck=false` 时不挂 safeAreaInset 内容。已并入 §11.4、§18。

写回修改：§2、§3、§4、§5、§6、§7、§10、§11、§14、§16、§18 均按上述发现更新。
仍需用户确认的问题（2026-06-18 已确认，见用户确认记录）：(1) macOS → **用户选择「也一起改」**，方案改为三端统一（单一 ScrollView + safeAreaInset 满足 spec 013:68），不再保留 macOS 现状分支；(2) 短句对齐 → **用户选择「垂直居中 Hero」**，`resolve` 在 active + 无失败时返回 `.center`。
是否允许进入实现：是。自审核门禁通过且用户已授权（状态 = User Approved）。重量级验证（全量 / 跨包测试、iPhone 模拟器 build）按用户要求走 GitHub Actions。

## 13. 复查方法

- 后续会话可从本 plan + `PracticeShadowingLayout.swift` + `PracticeShadowingLayoutTests.swift` 恢复设计意图与决策函数语义，无需聊天记忆。
- 回归判断：跑 `PracticeShadowingLayoutTests`、`PhoneIOSConvergenceTests`、`ThreePlatformPresentationCopyTests`、`AppearanceSettingsTests`、`PracticeRouteSeedTests`；对照页面清单 L54 更新后事实。

## 14. TDD / 测试落点

新增：

- Package：`LangoTraceUI`
- 文件：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeShadowingLayoutTests.swift`
- 测试名与断言（输入→输出，非 tautology）：
  - `noContentHidesControlDeckAndCentersStage`：`resolve(hasSession:false, hasVisibleFailure:false)` → `rendersControlDeck == false` 且 `stageAlignment == .center`。
  - `activeSessionCentersStageAndDocksControls`：`resolve(hasSession:true, hasVisibleFailure:false)` → `rendersControlDeck == true` 且 `stageAlignment == .center`。
  - `visibleFailureTopAlignsStage`：`resolve(hasSession:true, hasVisibleFailure:true)` → `stageAlignment == .top`（失败信息优先可见）。
- 先失败原因：`PracticeShadowingLayout` 类型不存在（编译失败）；实现后映射成立转绿。

更新 / 回归（须保持绿，方案据此约束实现）：

- `PhoneIOSConvergenceTests`：保留既有练习断言；追加 stage/deck 正向断言。
- `ThreePlatformPresentationCopyTests`：不引入硬编码英文文案 → 保持绿。
- `AppearanceSettingsTests`：`PracticeControlBar.swift` 保留 `primaryActionFill` → 保持绿。
- `PracticeRouteSeedTests`：不改 `PracticePromptCardPresentation` init/语义 → 保持绿。

不为真实渲染几何 / 居中像素写单元测试的原因：SwiftUI 视觉几何无法在单元层稳定断言；按既有范式用 layout 决策模型锁定意图，配合模拟器截图作视觉证据（含短句态、失败态）。

## 15. 验证命令

验证分层（按用户约束：本机只做轻量自查，重测试走 GitHub Actions）。

本机轻量（仅 lint，不做整包编译以护住 MacBook Air 散热）：

```bash
swiftformat --lint Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift \
  Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift \
  Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift \
  Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeShadowingLayout.swift \
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeShadowingLayoutTests.swift --cache ignore
swiftlint --no-cache --quiet
```

GitHub Actions（重测试 + 视觉证据，对齐 CLAUDE.md §1.8.8 / §3.1）：

```bash
# 单包聚焦（CI runner 上跑，TDD 红绿与回归）
swift test --package-path Packages/LangoTraceUI --filter PracticeShadowingLayoutTests
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
swift test --package-path Packages/LangoTraceUI --filter ThreePlatformPresentationCopyTests
swift test --package-path Packages/LangoTraceUI --filter AppearanceSettingsTests
swift test --package-path Packages/LangoTraceUI --filter PracticeRouteSeedTests
swift test --package-path Packages/LangoTraceUI
# iPhone 17 模拟器 clean build + install + launch + 截图
#   正常多行句 / 短句无释义 / 失败态 → logs/iphone17-practice-shadowing-stage*.png
```

不在本机主动运行 `scripts/verify.sh` 或 iPhone 模拟器 clean build（负载高、散热受限）；这些由 CI `Build & Test` 承载。触发 CI 前先把仓库临时设为 public。

## 16. 文档影响检查

- `docs/README.md`：无需改（未变核心决策 / 包边界 / 启动结构）。
- `docs/platform-page-inventory.md` L54：**需更新**——三端跟读单句页由「ScrollView 顶部堆叠内容卡 + 操作卡 + 底部句间导航」改为「句子舞台（Hero，条件居中，单一主滚动）+ safeAreaInset 底部停靠控制台（操作卡 + 其后句间导航）」；保留「不显示重复 header / 不预留大块空白 / 录音本地优先」。
- `docs/spec/learning-content/impl.md`：若含跟读单句页布局描述，同步更新。
- `docs/spec/013-practice-learning-domain.md:68`：复核——三端仍为该会话自有的单一主滚动体、不被外层包裹，预期**无需改实质规则**；在实施记录登记已核对。
- `docs/spec/003-ui-design-system.md`：本轮 deck 外壳局部用于练习页且遵守 :134/:136；暂不提升为通用 pattern，他处复用再提升。
- ADR：不涉及（仍属 ADR-005 本地优先与既有练习闭环）。
- review：平台页面结构变化，按 `docs/review/README.md` 做文档影响检查（本节已判断），是否触发专项审查在实施记录确认。

## 17. 实施记录

2026-06-18（本机部分，重测试待 CI）：

- 新增 `PracticeShadowingLayout.swift`：`resolve(hasSession:hasVisibleFailure:)` 决策函数 + `stageFrameAlignment`；新增 `PracticeControlDeckHeightKey` PreferenceKey 实测控制台高度。
- 新增 `Practice/PracticeShadowingLayoutTests.swift`：三个输入→输出断言（noContent 不渲染 deck 且居中 / active 居中并渲染 deck / 失败态顶部对齐）。先因类型不存在编译失败（红），实现后转绿（绿由 CI 跑）。
- 重构 `PracticeShadowingSessionView.body`：三端统一改为单一 `ScrollView` + `.safeAreaInset(edge:.bottom)` 停靠 `controlDeck`；舞台 `stageContent` 用 `PracticePromptCard(isCentered:true)` + 失败/noContent 状态行，经背景 `GeometryReader` 测得视口高度并 `minHeight: 视口 - controlDeckHeight` 按 `layout.stageFrameAlignment` 对齐；舞台与控制台限宽 560 居中；控制台内 control bar 在前、nav bar 在后、仅背景 + 顶部 hairline（不套 langoPanel）。保留 `navigationTitle` / `langoPracticeInlineNavigationTitle` / disclosure state / `onChange(routeSeed.practiceRouteIdentity)`。
- `PracticePromptCard` 新增 `isCentered: Bool = false`（仅 View，不改 `PracticePromptCardPresentation`）：居中时 `.center` 对齐 + `.title2.weight(.semibold)` + `multilineTextAlignment(.center)`；disclosure / `ViewThatFits` / 段落结构不变。
- `PhoneIOSConvergenceTests` 追加 `shadowingSessionUsesCenteredStageWithBottomDockedControlDeck`，锁定 `PracticeShadowingLayout.resolve` / `safeAreaInset(edge: .bottom` / `PracticeControlDeckHeightKey` / `controlDeck(session:)` / `isCentered: true` / prompt card `var isCentered` 与 `multilineTextAlignment(multilineAlignment)`；既有练习断言保留。
- 更新 `docs/platform-page-inventory.md` L54 与组件映射行（新增 `PracticeShadowingLayout.swift`、改写跟读单句页结构事实）。`docs/spec/learning-content/impl.md` 经检索未描述跟读单句页布局 → 无需改。`docs/spec/013-practice-learning-domain.md:68` 复核：三端仍单一主滚动体、未被外层包裹 → 无需改实质规则。
- 本机轻量验证：`swiftformat --lint`（4 文件 0 待格式化，2 文件已 format 写回）、`swiftlint`（改动区无新增 error；既有 `type_body_length` / `opening_brace` / `type_name` 为改动区外 pre-existing 警告）、`scripts/check-docs.sh` ok、`git diff --check` 干净。
- 重测试（全量单包 `swift test`、convergence/copy/appearance/routeSeed 回归、iPhone 17 模拟器 clean build + 截图）按用户约束走 GitHub Actions，尚未执行（见验证命令与下方完成标准）。

## 18. 完成标准

- `PracticeShadowingLayoutTests` 三个用例先失败后通过。
- `PhoneIOSConvergenceTests` 全绿（既有断言保留 + 新断言通过）。
- `ThreePlatformPresentationCopyTests` / `AppearanceSettingsTests` / `PracticeRouteSeedTests` 保持绿。
- `swift test --package-path Packages/LangoTraceUI` 全绿。
- iPhone 17 截图显示：句子为视觉主体、控制台停靠底部、下半屏无死区；短句态居中自然；失败态顶部对齐可见。三端统一应用，iPad / macOS 大屏观感人工验收。
- 页面清单 L54 与 impl.md 已更新。

## 19. 剩余风险

- iPad / macOS 共享同一重构，大屏 / Stage Manager / 窄宽 / 桌面窗口下停靠 deck 与 560pt 限宽居中的观感需人工验收；本轮自动验证仅 iPhone 截图（CI），iPad / macOS 截图按需补。
- `safeAreaInset` + 背景 GeometryReader 测高在超长讲解 + 小机型上需确认滚动正常、不裁切；以截图与展开态实测为准。
- 短句居中为有意 flashcard 构图，可能与个别用户对「上下留白」的预期不同；以截图复核，必要时回退为方向 A 的温和顶部分配（保留为备选）。
- VoiceOver 线性顺序因 deck 重排为 stage → control → nav，需人工验收盲用流程。
- layout 决策模型锁定意图，不保证像素级居中；视觉回归依赖截图。
- convergence / copy / appearance 测试为源码字符串断言，结构调整后需人工确保断言反映真实新结构而非被机械放宽。
