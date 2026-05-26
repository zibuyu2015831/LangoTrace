# 任务方案：优化单句练习页 iPhone 信息架构与交互层级

状态：Draft
类型：refactor
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户基于 iPhone 17 模拟器截图指出单句练习页存在信息重复、不可点击状态块误导、底部说明卡冗余和本地化 key 暴露问题，要求站在 Apple 应用交互设计师角度评估。评估后用户要求立即创建 active plan。

2026-05-26：用户进一步确认倾向删除 `跟读 / 录音 / 已完成` 三段状态，并提出练习页需要 `上一句` / `下一句`，方便在同一篇记录的句子之间切换；当到达最后一句时，需要提醒用户这是最后一句。

本方案创建后仍需用户确认 `User Approved` 后再实施代码修改。

## 2. 需求描述

当前单句练习页已经接入示范播放、录音、录音回放和完成态保存，但 iPhone 页面信息架构仍带有早期实现痕迹：

1. 顶部 `跟读练习` section header 和下方目标句摘要与导航标题、正文卡片重复。
2. 中间 `跟读 / 录音 / 已完成` 三个状态块视觉上类似 segmented control，但不可点击，容易误导用户。
3. 底部 `跟读` step card 与操作按钮重复，并暴露 `practiceStep.shadow.body` 原始本地化 key。
4. 页面中真正重要的任务是“听示范、录音、回放、标记完成”，但当前视觉权重被重复标题和说明卡分散。
5. 单句练习页只能返回句子列表后再选择其他句子，缺少在同一篇记录内直接切换上一句 / 下一句的轻量路径；连续练习多句时会形成不必要的往返导航。
6. 当用户处于最后一句时，页面没有明确提醒，用户可能继续寻找下一句入口或误以为按钮失效原因不明。

目标是把单句练习页收敛为符合 iPhone 触控习惯的任务界面：内容少而清楚，主操作稳定可达，状态表达不伪装成可操作控件，并支持在当前记录的句子范围内低成本切换。

## 3. 现状描述

代码现状：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
  - `PracticeSessionView.body` 在页面顶部渲染 `SectionHeader(titleKey: "practice.shadowing.title", subtitle: routeSeed.snapshot.targetTextSnapshot)`。
  - 同一页面随后渲染 `PracticeSnapshotPanel`，已经包含译文、目标句和笔记。
  - session 加载后渲染 `PracticeControlBar`、失败状态行和 `PracticeStepPanel`。
  - `PracticeStepPanel.mainText` 在 `.shadowing` 分支读取 `practiceStep.shadow.body`，但 `Localizable.xcstrings` 没有对应 key，导致截图中出现原始 key。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
  - 顶部 `HStack` 渲染三个 `phasePill`：`.shadowing`、`.recording`、`.completion`。
  - `phasePill` 使用 44pt 高度、填充色和 capsule-like 视觉，接近可点击 segmented control，但没有 action，也没有 accessibility value 表达“只读状态”。
  - `PracticeControlBar` 已有真正操作：`听`、`回放录音`、主按钮 `开始录音 / 停止录音 / 已完成`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift`
  - `PracticeSessionRouteSeed` 当前只包含单个句子的 identity、hash 和 `PracticeSentenceSnapshot`。
  - route seed 不知道同一篇 rendering 下还有多少句，也不知道当前句是否有上一句 / 下一句。
  - `PhoneRoute.practiceSentence(PracticeSessionRouteSeed)`、`PadWorkspaceRoute.practiceSentence(PracticeSessionRouteSeed)` 和 `MacWorkspaceRoute.practiceSentence(PracticeSessionRouteSeed)` 都依赖该 seed，因此句间导航应在 seed / route seam 上补轻量上下文，而不是在某个平台 View 内临时查全局状态。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
  - `PracticeSessionView` 当前在 `init` 中用 `@StateObject` 创建 `PracticeSessionViewModel(languageSpaceID:snapshot:actions:...)`。
  - 如果句间导航只是替换 route seed，但 SwiftUI 复用同一个 `PracticeSessionView` 实例，`@StateObject` 不会自动用新 seed 重建，可能导致页面显示新句子但 ViewModel 仍加载旧 session。
  - 实施时必须明确让练习页按 route seed 重建，或让 ViewModel 提供显式 `reset(routeSeed:)` 入口；本任务推荐按 route seed 设置 stable `.id(...)`，保持单句练习页状态边界简单。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
  - 存在 `practiceStep.prepare.body`、`practiceStep.compare.body`、`practiceStep.completed.body`。
  - 不存在 `practiceStep.shadow.body`。
- `docs/spec/003-ui-design-system.md`
  - 要求 iPhone 一次聚焦一个任务，不做卡片套卡片，状态不能临时用裸文本堆在页面上，文本和按钮不能溢出或遮挡。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
  - 要求 iPhone 主路径少而清楚，高频媒体操作在原卡片或控制条内反馈，播放类按钮行为和视觉语义一致，页面结构变化需要自动化覆盖和截图 / 人工验证说明。

## 4. 问题根因

根因不是录音或播放链路错误，而是早期功能逐步叠加后缺少一次页面级信息架构收口：

- `SectionHeader` 继承了列表页的 section 结构，但单句详情页已经有导航标题和正文卡片。
- `phasePill` 把 domain step 映射成了强视觉控件，却没有对应交互能力。
- `PracticeStepPanel` 原本用于解释练习步骤，但真实操作按钮补齐后，其说明价值下降，且本地化 key 漏配暴露了开发状态。
- 操作区和说明区没有明确区分“可执行动作”和“只读状态”。
- 句间导航缺失的根因是 `PracticeSessionRouteSeed` 被设计成单句不可变快照，只适合从列表进入单句；它没有携带 sibling context，因此单句页无法在不回到列表的情况下构造相邻句子的 route seed。
- 句间导航还存在 SwiftUI 生命周期边界：`@StateObject` 与初始化 seed 绑定，route 更新必须触发练习页状态重建，否则会出现 UI seed、ViewModel session、播放 closure 三者不同步。

置信度：92%

置信度依据：

- 截图中的三个红框均对应上述代码路径。
- 本地化 key 暴露可由 `PracticeStepPanel.mainText` 和 `Localizable.xcstrings` 缺 key 直接解释。
- 页面中的录音 / 播放能力已经由刚完成的 `feat: complete practice playback loop` 接入，当前问题集中在 UI 结构和 copy 层。

备选原因：

- 如果后续产品希望把跟读扩展成多步训练向导，保留 step indicator 可能有价值。但当前页面只有单句 shadowing，不支持点击跳步，也没有评分 / 听写 / 回译步骤，因此高权重 step indicator 仍不适合放在主操作区。
- 如果后续要做跨记录连续练习队列，上一句 / 下一句可能不只局限于当前 rendering。但本任务的用户需求来自“同一篇记录的最后一句”，当前应限制为同一篇记录内切换，避免过早引入队列模型。

## 5. 目标

- 删除单句练习页顶部重复的 `跟读练习` section header 和目标句 subtitle。
- 删除 `PracticeControlBar` 中不可点击的 `跟读 / 录音 / 已完成` 三段 phase pill。
- 删除底部 `PracticeStepPanel`，避免重复说明和本地化 key 暴露。
- 保留并强化真实可操作能力：`听`、`回放录音`、`开始录音 / 停止录音 / 标记完成`。
- 用低干扰状态文案表达当前 session 状态，例如 `录音保存在本机`、`正在录音`、`录音已保存，可回放后完成`、`本次练习已完成`。
- 增加同一篇记录内的句间导航：`上一句` / `下一句`。
- 到达最后一句时禁用或隐藏 `下一句` 的同时给出明确提醒，例如 `这是最后一句`。
- 到达第一句时对 `上一句` 做对称边界表达，例如禁用并显示 `第一句` 或通过状态文案表达；避免只出现不可解释的 disabled 按钮。
- 切换句子时替换当前练习 route，而不是在导航栈中连续 push 多个单句页；返回仍应回到句子列表或记录详情，而不是逐句倒退。
- 录音中禁止切换上一句 / 下一句；示范播放或录音回放中切换应先停止播放或禁用切换，避免音频和页面内容错位。
- 切换句子时必须保证 `PracticeSessionViewModel`、`onPlayDemo` closure、`onStopDemo` closure 和当前 `routeSeed` 同步更新；不得出现页面句子已经切换但播放仍使用旧句 seed 的状态。
- 保持 iPhone、iPad、macOS 共享同一个 `PracticeSessionView`、`PracticeSessionViewModel` 和 `PracticeActions` seam，不新增平台专用业务逻辑。
- 修正或移除 `practiceStep.shadow.body` 缺 key 问题，确保界面不暴露本地化 key。

## 6. 不做什么

- 不改变 `PracticeSession` schema、状态机、录音文件写入、播放 resolver、TTS 示范播放或完成态保存逻辑。
- 不新增发音评分、ASR、听写、回译或多步向导。
- 不新增底部固定操作条作为本任务必做项。该方向更适合后续在更多练习类型稳定后统一设计；本任务只清理当前 ScrollView 内的信息层级。
- 不为 iPad / macOS 单独复制一套练习页业务逻辑。
- 不改变语言空间上下文。
- 不做跨记录练习队列、自动播放下一句、自动进入下一句录音或批量完成统计。
- 不要求完成当前句后才能进入下一句；用户可以自由切换句子，但录音中的切换必须被禁止。
- 不在本任务中新增用户离开未完成录音的确认弹窗；ready recording 已持久化，未完成 session 可以通过当前 repository 恢复。录音中则禁止切换，避免丢失正在采集的音频。

## 7. 证据与决策依据

设计依据：

- iOS 交互中，看起来像 segmented control 的组件应可切换或清楚表达只读状态；当前 phase pill 不可点击，用户容易误判。
- iPhone 主任务页面应减少解释型文案，把视觉权重给当前内容和可执行动作。
- 录音页的主要操作应保持 44pt 以上触控目标，并尽量接近拇指操作区；当前 action buttons 已满足基本触控尺寸，删除重复说明不会削弱可操作性。
- 本地化 key 暴露属于用户可见缺陷，不能靠后续文案解释。
- 上一句 / 下一句属于内容导航，不属于练习步骤状态；应使用明确的 Button 行或工具区，而不是复用 `跟读 / 录音 / 已完成` 这类阶段文案。
- 最后一句提醒应解释边界状态，不能只让 `下一句` 灰掉；disabled-only 对 VoiceOver 和普通用户都不够清楚。
- 新增按钮必须沿用项目现有按钮语义：句间导航是 tertiary / navigation action，不使用 filled primary CTA，不和 `开始录音` 争夺主操作视觉层级。
- 句间导航按钮应使用 lucide 不适用时的 SF Symbols `chevron.left` / `chevron.right`，配合文字 label；不能只显示箭头图标，也不能做成类似阶段 pill 的大块状态按钮。

文档依据：

- `docs/spec/003-ui-design-system.md`：iPhone 单列、快速操作、一次聚焦一个任务；不做卡片套卡片；状态必须有清晰表现。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`：iPhone 主路径少而清楚；播放类按钮视觉、辅助标签和实际行为一致；页面结构变化必须说明自动化和截图 / 人工验证范围。
- `docs/workflows/add-platform-screen.md`：平台页面或入口调整需要明确共享状态、action seam、本地化、Dynamic Type、VoiceOver 和页面清单影响。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeSessionViewModelTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/ThreePlatformPresentationCopyTests.swift`

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ContentUtilityComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainModels.swift`

## 10. 涉及的文档路径

- `docs/platform-page-inventory.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/testing/README.md`
- `docs/plans/done/2026-05-26-bug-practice-session-playback-completion-gap.md`

## 11. 推荐实施方案

### 11.1 页面结构

将 `PracticeSessionView` 调整为：

1. `PracticeSnapshotPanel(snapshot:)`
2. `PracticeSentenceNavigationBar(...)`
3. `PracticeControlBar(...)`
4. 仅在失败时显示 `CapabilityStatusRow`

删除：

- 单句页顶部 `SectionHeader(titleKey: "practice.shadowing.title", subtitle: routeSeed.snapshot.targetTextSnapshot)`。
- session 成功加载后的 `PracticeStepPanel(session:)`。
- `PracticeStepPanel` 类型本身，如果没有其他调用点。

保留：

- `PracticeSentenceListView` 中的 `SectionHeader(titleKey: "practice.shadowing.title", subtitle: entry.title)`，因为列表页仍需要 section 语义。
- `PracticeSnapshotPanel` 的译文、目标句和笔记结构。
- `CapabilityStatusRow` 失败态展示。

页面协调要求：

- `PracticeSentenceNavigationBar` 不使用 `.langoPanel()`，避免形成“内容卡 + 导航卡 + 操作卡”的三卡堆叠；它应是内容卡和操作卡之间的轻量 inline control。
- 操作卡仍然是页面主交互 surface；句间导航视觉权重必须低于 `听 / 回放录音 / 开始录音`。
- iPhone 上可用一行 `上一句 | 第 n / m 句 | 下一句`；Dynamic Type 或窄屏下允许换成两行：第一行位置 / 边界提示，第二行左右按钮。
- iPad / macOS 共享同一组件，但允许通过自适应宽度保持居中和较低密度；不得引入平台专属业务逻辑。

### 11.2 句间导航结构

新增轻量 route sibling context，而不是在 `PracticeSessionView` 内访问全局 store：

1. 在 `PracticeRouting.swift` 中新增 `PracticeSessionNavigationContext` 和 `PracticeSessionNavigationItem`。
2. `PracticeSessionRouteSeed` 初始化时从 `LearningRendering.sentences` 捕获当前 rendering 的轻量句子列表、当前句 index、entry id、material id、target language code、source hash。
3. `PracticeSessionRouteSeed` 暴露：
   - `var hasPreviousSentence: Bool`
   - `var hasNextSentence: Bool`
   - `var positionTextKey / positionSummary` 或可测试 projection，用于 `第 n / m 句`、`这是最后一句`。
   - `func neighboringSeed(direction: PracticeSentenceNavigationDirection, capturedAt: Date) -> PracticeSessionRouteSeed?`
4. `PracticeSessionView` 接收 `onNavigateSentence: (PracticeSessionRouteSeed) -> Void` closure。
5. iPhone route 切换时替换当前 `navigationPath` 最后一项为 `.practiceSentence(newSeed)`；iPad / macOS 调用现有 `onRoute(.practiceSentence(newSeed))`。
6. `PracticeSessionView` 或平台调用点必须使用 route seed identity 触发状态重建。推荐做法是在 `PracticeSessionView` 外层或内部对内容添加 `.id(routeSeed.practiceRouteIdentity)`，identity 至少包含 `entryID`、`learningMaterialID`、`sentenceID`、`sentenceIndex`、`targetTextHash` 和 `targetLanguageCode`。
7. 句间导航按钮在录音中和录音回放中禁用；示范播放中允许切换前调用 `onStopDemo`，但不得在无法停止的播放状态下切换。
8. `PracticeSessionNavigationContext` 只保存生成相邻 route seed 所需的轻量文本快照，不保存完整 `LearningRendering` 或 repository 对象；避免让 route enum 承载大型业务对象。
9. 若当前 seed 没有 navigation context，例如来自旧测试或未来深链入口，则导航条退化为仅显示当前位置或隐藏上一句 / 下一句，不能崩溃。

推荐视觉：

- 一行低权重导航条，放在句子内容卡和操作卡之间。
- 左侧 Button：`上一句`，图标 `chevron.left`；使用 `.buttonStyle(.plain)` 或项目现有低权重 chip 样式，最小触控区域 44pt。
- 中间 Text：`第 2 / 5 句`；如果最后一句，显示 `第 5 / 5 句 · 这是最后一句`。位置文本使用 `.caption` 或 `.footnote`，颜色使用 `textSecondary`。
- 右侧 Button：`下一句`，图标 `chevron.right`；视觉权重与上一句对称。
- 第一 / 最后一句对应按钮 disabled，但中间文案解释边界；不使用弹窗提醒。
- 不使用大面积浅绿背景，不使用 filled primary style，不使用类似 segmented control 的三等分胶囊按钮。

建议新增本地化 key：

- `practice.navigation.previous`
  - zh-Hans：`上一句`
  - en：`Previous`
- `practice.navigation.next`
  - zh-Hans：`下一句`
  - en：`Next`
- `practice.navigation.position`
  - zh-Hans：`第 %1$d / %2$d 句`
  - en：`Sentence %1$d of %2$d`
- `practice.navigation.firstSentence`
  - zh-Hans：`这是第一句`
  - en：`First sentence`
- `practice.navigation.lastSentence`
  - zh-Hans：`这是最后一句`
  - en：`Last sentence`
- `practice.navigation.unavailableWhileRecording`
  - zh-Hans：`录音中不能切换句子。`
  - en：`Finish recording before switching sentences.`
- `practice.navigation.unavailableWhilePlayback`
  - zh-Hans：`回放结束后再切换句子。`
  - en：`Wait for playback to finish before switching sentences.`

### 11.3 操作区结构

将 `PracticeControlBar` 调整为更明确的 action panel：

1. 删除 phase pill `HStack` 和相关 `phasePill(_:)` / `title(for:)` helper。
2. 保留 `听` 和 `回放录音` 两个 secondary buttons。
3. 保留 primary button，并把有录音但未完成时的文案从 `已完成` 调整为更像动作的 `标记完成`。
4. 在操作按钮下方增加一行低权重状态文案，表达当前状态而不是模拟步骤切换。

建议新增本地化 key：

- `practice.status.readyToRecord`
  - zh-Hans：`听完示范后开始录音。`
  - en：`Listen to the demo, then record your attempt.`
- `practice.status.recording`
  - zh-Hans：`正在录音，本次录音只保存在本机。`
  - en：`Recording now. This attempt stays on this device.`
- `practice.status.readyToComplete`
  - zh-Hans：`录音已保存，可回放后标记完成。`
  - en：`Recording saved. Review it, then mark this practice complete.`
- `practice.status.completed`
  - zh-Hans：`本次练习已完成，录音仍可在本机回放。`
  - en：`Practice complete. The recording remains playable on this device.`
- `practice.action.markComplete`
  - zh-Hans：`标记完成`
  - en：`Mark Complete`

### 11.4 本地化 key 清理

处理方式：

- 如果删除 `PracticeStepPanel` 后没有调用 `practiceStep.shadow.body`，不新增该 key。
- 保留已有 `practiceStep.*` key 供列表、旧测试或后续多步练习使用，不在本任务中大规模删除本地化历史。
- 补充测试或扫描，证明用户可见练习页不再暴露 `practiceStep.shadow.body`。

### 11.5 可访问性

- `听` 按钮继续使用 Label 和系统图标，保持 44pt 以上高度。
- `回放录音` disabled 时不作为错误，只表示当前没有 ready recording 或音频忙。
- primary button 的 accessibility label 跟随按钮文案，不把完成态按钮显示成不可理解的 `已完成` 动作。
- 新增状态文案不使用颜色作为唯一状态表达。
- `上一句` / `下一句` 必须是 Button，不用裸 `onTapGesture`。
- `上一句` / `下一句` 视觉上必须明显是导航按钮，但低于录音主按钮层级；推荐 plain button + SF Symbol + 44pt frame，或复用 `SecondaryActionChip` 的低权重样式但避免占满整行。
- 位置文案和第一 / 最后一句提示必须可被 VoiceOver 读到；disabled 按钮不能是唯一边界表达。
- 录音中禁用句间导航时，状态文案应解释原因，不能只靠按钮灰色表达。
- 对 VoiceOver，导航条应提供组合后的上下文，例如 `第 3 / 5 句`、`这是最后一句`；上一句 / 下一句按钮应有明确 hint，例如“切换到同一篇记录的上一句”。
- Dynamic Type 下，导航条可以换行，但按钮不得压缩到 44pt 以下，位置文案不得遮挡操作按钮。

## 12. 测试方案

自动化优先覆盖可稳定验证的 presentation / copy 边界：

1. 更新或新增 UI package 测试，验证 `PracticeActionFailure.localizedSummaryKey` 不受影响。
2. 新增 `PracticeSessionRouteSeed` sibling context 测试：
   - 三句 rendering 的第二句可以生成上一句和下一句 seed。
   - 第一句没有 previous，最后一句没有 next。
   - 最后一句 position projection 返回 `practice.navigation.lastSentence`。
   - neighbor seed 继承 entry id、learning material id、target language code、source hash，并重新生成目标句 hash。
   - route identity 随相邻句变化，能驱动 `PracticeSessionView` / ViewModel 重建。
   - 无 navigation context 时 neighbor seed 返回 nil 或导航 projection 退化为不可导航状态。
3. 新增 `PracticeControlBar` 可测试的 presentation helper，或在现有 ViewModel 测试中覆盖状态文案 key 映射：
   - 无录音、未录音中：`practice.status.readyToRecord`
   - 录音中：`practice.status.recording`
   - 有 latest ready recording 且未完成：`practice.status.readyToComplete`
   - completed：`practice.status.completed`
4. 更新 `ThreePlatformPresentationCopyTests` 或新增本地化 smoke，确保新增 key 在 `en` 和 `zh-Hans` 均存在。
5. 删除或调整任何依赖 `practiceStep.shadow.body` 的测试期望。

手动 / 截图验证：

- iPhone 17：确认顶部重复 header 消失、三段 phase pill 消失、底部 step card 消失、操作按钮仍可见。
- iPhone 17：从第一句进入时 `上一句` 不可用且有第一句提示；中间句可切换上一句和下一句；最后一句 `下一句` 不可用且显示 `这是最后一句`。
- iPhone 17：点击上一句 / 下一句后当前页面被替换为相邻句，系统返回仍回到句子列表，不按每句逐级倒退。
- iPhone 17：录音前、录音中、停止录音后、完成后分别检查状态文案和主按钮文案。
- iPhone 17：录音中上一句 / 下一句不可用，并有可理解状态文案。
- iPhone 17：回放录音中上一句 / 下一句不可用；示范播放中切换会停止旧句示范，不出现旧句音频继续播放。
- iPhone 小屏或 Dynamic Type 较大字体：确认 `听`、`回放录音` 和主按钮不溢出。
- iPhone 小屏或 Dynamic Type 较大字体：确认 `上一句`、位置文案、`下一句` 不互相挤压；必要时换行。
- iPad / macOS：确认共享练习页没有出现空白断层，操作仍可达。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|PracticeRouteSeedTests|ThreePlatformPresentationCopyTests|LearningContentStoreSentenceAudioCoordinatorTests'
```

完整验证：

```bash
scripts/verify.sh
```

文档检查：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

## 14. 文档影响检查

需要更新：

- `docs/platform-page-inventory.md`：单句练习页当前 UI 事实从“listen demo / record / playback / complete + step panel”调整为“内容卡 + action panel + failure status”。
- `docs/platform-page-inventory.md`：补充同一篇记录内上一句 / 下一句切换和最后一句边界提醒。
- `docs/testing/README.md`：手动检查项补充 iPhone 练习页信息架构、状态文案、句间导航和最后一句提示检查。
- `docs/spec/003-ui-design-system.md`：补充或确认练习页句间导航按钮的低权重样式规则，避免后续把内容导航做成 primary CTA 或伪 segmented control。

可能不需要更新：

- `docs/spec/010-apple-platform-interaction-and-accessibility.md`：现有规范已经覆盖播放按钮、主路径和页面验证要求。
- `docs/architecture/002-system-map.md`：本任务不改变播放、录音、数据或 App assembly 链路。

## 15. 实施步骤

1. 创建或更新 UI package 聚焦测试，先覆盖练习操作区状态 key / 主按钮文案 key 的期望。
2. 创建或更新 `PracticeRouteSeedTests`，先覆盖上一句 / 下一句 seed 生成、第一句 / 最后一句边界和 position 文案 projection。
3. 在 `PracticeRouting.swift` 中新增 sibling context、route identity 与 neighbor seed helper。
4. 给 `PracticeSessionView` 增加 `onNavigateSentence` closure，并新增句间导航条。
5. 明确 `PracticeSessionView` 的 seed 更新策略：添加 `.id(routeSeed.practiceRouteIdentity)` 或等价重建机制，防止 `@StateObject` 持有旧句 session。
6. 更新 `PhoneMainView`、`PadMainSections`、`MacWorkspaceContentView` 的 route 替换逻辑。
7. 删除 `PracticeSessionView` 顶部重复 `SectionHeader`。
8. 删除 `PracticeStepPanel` 渲染和未使用类型。
9. 重构 `PracticeControlBar`，删除 phase pill，新增低权重状态文案和 `practice.action.markComplete`。
10. 更新 `Localizable.xcstrings`，新增状态文案和句间导航 key；确认不再需要 `practiceStep.shadow.body`。
11. 更新 `docs/spec/003-ui-design-system.md` 中练习页句间导航按钮的低权重样式约束。
12. 运行 UI 聚焦测试并修复失败。
13. 更新 `docs/platform-page-inventory.md` 和 `docs/testing/README.md`。
14. 运行完整验证。
15. 在实现记录写入验证结果，通过后将方案移动到 `docs/plans/done/`。

## 16. 复查方法

复查时逐项确认：

- 页面首屏没有重复展示目标句标题。
- 没有不可点击但看似可点击的三段 step control。
- 页面不暴露任何本地化 key。
- 上一句 / 下一句能在同一篇记录内切换相邻句，且切换不污染系统返回栈。
- 最后一句有明确 `这是最后一句` 边界提醒。
- route seed 切换后 ViewModel、当前句内容、示范播放 closure 和录音 session 均指向同一句。
- 录音中不能切换句子，录音回放中不能切换句子，示范播放中切换会停止旧句音频。
- 录音前、录音中、录音后、完成后都有稳定、低干扰状态表达。
- `听`、`回放录音` 和主录音 / 完成按钮仍保持 44pt 以上触控目标。
- `上一句` / `下一句` 符合低权重导航按钮规范，44pt 可触达，不使用 primary CTA 或伪 segmented control 视觉。
- iPhone、iPad、macOS 仍共享同一业务 seam，没有平台分叉写入路径。

## 17. 完成标准

- 代码删除重复 header、phase pill 和底部 step card。
- 代码新增同一篇记录内上一句 / 下一句切换，并在最后一句显示明确提醒。
- 用户可见页面不再出现 `practiceStep.shadow.body`。
- 新状态文案和主按钮文案在 `en` / `zh-Hans` 均有本地化。
- 新句间导航文案在 `en` / `zh-Hans` 均有本地化。
- `PracticeSessionView` 在句间切换时不会复用旧 `@StateObject` session。
- `docs/spec/003-ui-design-system.md` 记录练习页句间导航按钮样式约束。
- 聚焦测试和 `scripts/verify.sh` 通过。
- `docs/platform-page-inventory.md` 和 `docs/testing/README.md` 与实现一致。
- iPhone 17 模拟器重新构建后页面结构符合本方案描述。

## 18. 剩余风险

- 真实设备上的麦克风权限弹窗、系统音频路由和中断仍需要后续真机验收；本任务只处理页面结构，不改变音频底层。
- 如果后续引入听写、回译、评分等多步练习，可能需要重新设计真正可交互的 stepper 或 progress indicator；当前删除不可点击 phase pill 不阻碍后续以新方案重建。
- 固定底部操作条可能进一步提升 iPhone 单手操作体验，但本任务不一次性引入，避免扩大布局风险。
- 当前上一句 / 下一句限定在同一篇记录的当前 rendering 内；后续如果做跨记录连续练习，需要新增练习队列模型，而不是继续扩展 route seed。
- `PracticeSessionRouteSeed` 增加 sibling context 后会比当前单句 seed 更大；本任务要求只保存轻量句子导航快照，避免 route enum 携带完整 rendering 或 repository 状态。
- 未完成但已保存的 ready recording 在切换句子后仍保留在对应 session 中；这符合本地优先和可恢复原则，但用户可能需要后续“未完成练习列表”来重新发现它，不在本任务范围内。
