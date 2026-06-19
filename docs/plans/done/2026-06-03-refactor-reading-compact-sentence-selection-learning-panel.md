# Reading compact sentence selection and learning panel

状态：Verified
自审核状态：Reviewed
类型：refactor
创建日期：2026-06-03
最后更新日期：2026-06-03

## 用户确认记录

- 2026-06-03：用户在阅读详情测试中指出，点击段落后弹出的 sheet 会挡住 `解释` / `听` 操作，同时希望从产品和长期扩展角度重新设计该交互：默认支持句子级学习，而不是段落级操作；后续需要容纳翻译、语法分析、朗读等能力；用户随后明确采纳“句子级选择 + 非模态学习面板 + 局部文本选择 + 动态上下文请求”的推荐方案，并要求立即创建 active plan，随后进行方案自审，且自审必须使用子代理做独立审核以避免上下文干扰。

## 1. 任务描述

对 iPhone / compact 阅读详情的学习交互进行结构性重设计，替换当前“点击 block -> 段落选中 -> 结果进入 sheet”的模型，改为：

- 默认以句子为主的学习操作对象；
- 支持句内局部文本选择；
- 使用非模态底部学习面板承接解释 / 翻译 / 语法 / 朗读等结果；
- 对 AI 请求引入按全文长度动态裁剪的上下文策略。

## 2. 当前问题

- 当前 `ReadingDocumentCanvas` 以 `ReadingBlockPresentation` 为点击单位，导致默认操作对象是段落而不是句子。
- 当前结果承载依赖 iPhone bottom sheet，会挡住正文和当前操作条，形成“弹出结果层后按钮不可继续点击”的交互冲突。
- 当前 explanation request 只稳定携带 `selectedText`、`containingSentence` 和 `contextText`，其中 `contextText` 目前基本等于句子本身，不足以覆盖“局部片段解释需要上下文”的长期边界。
- 未来能力已明确会扩展到 `翻译 / 语法分析 / 朗读 / 词汇` 等，若继续沿用“正文里插按钮 + 每个动作走 modal sheet”，阅读页会快速退化为操作面板。

## 3. 目标

1. 把阅读页默认学习操作对象从段落收敛到句子。
2. 允许用户在句子内部做局部文本选择，并将片段解释挂靠到所属句子。
3. 用非模态底部学习面板替代当前结果 sheet，避免抢焦点和阻断连续学习。
4. 建立可扩展的统一 action/result 框架，服务后续 `解释 / 翻译 / 语法 / 词汇 / 朗读`。
5. 为 explanation request 引入动态上下文策略：短文可带全文，长文带必要上下段落或相邻句。

## 4. 范围

首轮用户体验优化聚焦 iPhone / compact 阅读详情，但共享 selection / request / source identity 契约必须先在三端共享层收口，避免与 iPad / macOS 长期方向冲突。

代码范围预计包括：

- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingMarkdown.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSourceAnchor.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingMarkdownBlockRenderer.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/*`

文档范围预计包括：

- `docs/platform-page-inventory.md`
- `docs/spec/012-reading-learning-domain.md`
- 当前 active plan

## 5. 非目标

- 本轮不接入真正的系统级自由文本选择引擎或 TextKit 深度定制；若第一阶段无法安全落地，允许先以句子级选择为主，局部文本选择通过受限模型落地。
- 本轮不一次性实现 `翻译 / 语法分析 / 词汇 / 加入记忆 / 进入练习` 的全部后端能力，但 UI 和状态模型必须为其预留统一承载。
- 本轮不重构 iPad / macOS 阅读工作台的信息架构，只允许做与新模型一致的边界调整。
- 本轮不改变当前阅读导入、编辑、删除恢复和 TTS artifact 数据链路。
- 本轮不新增 GRDB `reading_sentences` / `reading_source_anchors` schema 迁移；若第一阶段采用运行时句子 identity，应在 plan 和测试中明确该 identity 的稳定规则，而不是隐式依赖仓库当前“一 block 一句”的早期结构。

## 6. 推荐方案

### 6.0 分阶段落地

- `Phase A`：先把共享 `sentence selection / explanation request / source identity` 契约落到三端共享层。
  - 句子级 selection、请求上下文策略、source anchor identity、renderer / store 状态机和 stale invalidation 都必须是共享事实。
  - iPad / macOS 在本阶段继续使用 side inspector 承载结果，但必须复用同一 selection / request seam。
- `Phase B`：仅对 iPhone / compact 把结果承载从系统 sheet 改为页面内 `非模态底部学习面板`。
  - 该阶段不允许为了 iPhone 单独分叉 selection 语义。
- `Phase C`：若局部文本选择在首轮无法稳定落地，则显式 deferred；不交付语义模糊的半成品。

### 6.1 交互模型

- `段落` 继续是阅读排版单位，不再是默认学习操作单位。
- `句子` 成为默认学习操作对象。用户轻点句子后，该句进入选中态。
- `局部文本片段` 成为高级学习操作对象。用户长按句子后进入片段选择；若首轮不接入完整自由选择，则只交付句子级选择，并把片段选择显式标记为 deferred。

### 6.2 动作入口

- 无选中时，阅读页保持纯阅读，不显示学习动作条。
- 句子选中后，出现轻量操作条。第一层只放：
  - `解释`
  - `听`
  - `更多`
- `更多` 是未来扩展入口，后续容纳 `翻译 / 语法 / 词汇 / 加入记忆 / 进入练习`。

### 6.3 结果承载

- 不再使用系统 sheet 承载阅读解释结果。
- iPhone / compact 改为页面内的 `非模态底部学习面板`：
  - 可收起 / 展开；
  - 不抢走正文主焦点；
  - 收起后保留当前句子或片段选中态；
  - 同一面板承载多种结果类型，而不是每个动作一个 modal。

### 6.3.1 Compact 学习面板状态机

- compact 学习面板必须显式区分：
  - `hidden`：无选中对象；
  - `collapsed`：有选中对象，但面板收起，仅保留轻量标题或最近动作；
  - `loading`：当前动作进行中；
  - `content`：结果可见；
  - `failed`：失败文案与原位重试可见。
- compact 面板的视图承载默认使用页面内 `safeAreaInset(edge: .bottom)` 或等价非模态容器，而不是系统 modal sheet。
- 切换句子或片段时，旧 explanation 结果必须立即失效；若面板已展开，则保留容器并切换到 `loading` 或 `collapsed`，不得把旧结果错误挂到新 selection。
- `听` 属于即时动作；`解释` 和后续 `翻译 / 语法 / 词汇` 属于分析动作并写入学习面板。

### 6.4 AI 请求上下文策略

Explanation request 需要区分：

- `selected_text`
- `selection_scope`：`sentence` / `text_fragment`
- `source_anchor_id`
- `containing_sentence`
- `previous_sentence?`
- `next_sentence?`
- `containing_paragraph`
- `context_mode`
- `context_text`

建议的长度策略：

- 全文长度 `<= 1200` 字符：携带全文；
- 全文更长但局部窗口可控：携带 `前一段 + 当前段 + 后一段`；
- 更长：至少携带 `当前段 + 所属句 + 相邻句`。

解释请求 contract 必须端到端闭合到：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingActions.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`
- `LangoTraceApp/AppEnvironment.swift`

本轮要同时明确：

- `context_mode` 的可枚举值与何时允许 `full_document`；
- 用户可见的 sending scope 提示至少能区分“整句解释 / 片段解释 / 携带全文 / 携带局部上下文”；
- 若当前阶段仍未实现真实片段选择 UI，解释服务和 prompt contract 也不能留下与 UI 语义不一致的占位字段。

### 6.5 Selection Identity Contract

- 本轮不再把 `ReadingBlockPresentation.id` 直接当作句子 identity。
- 句子 identity 必须显式绑定到当前文档版本，可采用运行时 deterministic id，但必须至少编码：
  - `documentID`
  - `contentRevision`
  - `structureVersion`
  - `blockID`
  - `sentenceIndex`
- 片段级 identity 复用 `ReadingSelection` / `ReadingSourceAnchor` 契约，最小字段必须包含：
  - `documentID`
  - `contentRevision`
  - `structureVersion`
  - `blockID`
  - `sentenceID`
  - `selectedTextHash`
  - `characterOffset`
  - `characterLength`
- 编辑保存、文档切换、语言空间切换、重复选择或 renderer 结构变化后，旧 anchor 必须 stale，旧 explanation / audio completion 不得写回当前 selection。
- `听` 继续只针对完整句子；TTS request 使用句子 identity，不使用片段 identity。

## 7. TDD 落点

首轮红绿路径按以下顺序执行：

1. `ReadingPresentationTests`
   - 首个红测：`phoneCompactUsesInlineLearningPanelInsteadOfBottomSheet`
     - 失败原因：当前 `ReadingLayoutModel.platform(.phone)` 和 iPhone detail 仍把结果建模为 bottom sheet。
   - 红测：`sentenceSelectionBecomesPrimaryLearningTargetInsteadOfBlockSelection`
     - 失败原因：当前 `ReadingDocumentCanvas` 仍以 `ReadingBlockPresentation` 为点击和 action 单位。
2. `ReadingDocumentStoreAIAndTTSTests`
   - 红测：`sentenceSelectionInvalidatesStaleExplanationAndAudio`
   - 红测：`fragmentSelectionInvalidatesStaleExplanation`
   - 红测：`explanationRequestChoosesFullDocumentForShortText`
   - 红测：`explanationRequestChoosesAdjacentParagraphsForLongText`
3. `LangoTraceCore` Reading tests
   - 红测：`ReadingSourceAnchorTests.fragmentAnchorBecomesStaleAfterRevisionChange`
   - 红测：`ReadingSourceAnchorTests.fragmentAnchorBecomesStaleAfterStructureChange`
   - 红测：句子分段、相邻句窗口与上下文窗口生成契约。
4. `ReadingSelectionExplanationServiceTests`
   - 红测：prompt / request contract 会透传 `selection_scope`、`context_mode` 和扩展上下文。
5. 若需要 UI seam 边界验证，再补 `ReadingLibraryStoreTests` 或新增 compact-specific presentation tests。

## 8. 关键设计与实现边界

### 8.1 Source of truth

- 选中对象、学习面板展开状态、当前动作类型、解释结果和局部选择上下文必须由 `ReadingDocumentStore` 或等价单一 store 承担。
- `ReadingViews.swift` 不再继续把“正文选中态”和“结果展示态”拆散在 view-local state 与 sheet state 中。

### 8.2 数据与模型

- 现有 `ReadingBlockPresentation` 需要扩展出句子级 presentation 或句子索引映射。
- 需要明确 `句子 id` 与 `局部片段 range` 的组合身份，避免 explanation / TTS / future grammar action 共享时出现 stale write。
- 当前仓库已有 `ReadingSourceAnchor`、`ReadingSelection` 和早期 `reading_sentences` / `reading_source_anchors` 结构；本轮必须显式决定复用哪些契约，不能隐式延续“一个 block 就是一句”的早期实现假设。
- `听` 继续以完整句子为单位，不以局部片段为单位。

### 8.3 平台边界

- iPhone / compact 首先落地新模型。
- iPad / macOS 后续沿用相同 selection / request contract，但结果承载可以继续走 side inspector，而不是 compact bottom panel。
- 本轮方案必须避免把 compact 的结果面板写死成只能在 iPhone 使用的业务模型。

## 9. 涉及文件路径

- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingMarkdown.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSourceAnchor.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingMarkdownBlockRenderer.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSourceAnchorTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingMarkdownRenderingTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingLibraryModelTests.swift`

## 10. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter Reading
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
swift test --package-path Packages/LangoTraceUI --filter ReadingDocumentStoreAIAndTTSTests
scripts/check-docs.sh
git diff --check
```

完整验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

## 11. 文档影响检查

- `platform-page-inventory.md` 需要更新 iPhone 阅读详情的交互事实：从“点击正文块 + bottom sheet”更新为“句子级选择 + 非模态学习面板 + future more actions”。
- `spec/012-reading-learning-domain.md` 需要更新 selection / context request / result presentation 的长期契约。
- 需要检查 `spec/002-navigation-and-routing.md` 是否需要记录 compact 学习面板不再走系统 sheet。
- 需要检查 `Localizable.xcstrings` 是否新增 compact 学习面板、sending scope 和错误态文案 key。
- 需要把 iPhone / compact 的 Dynamic Type、VoiceOver 和长文滚动面板遮挡手验点写入验证记录。
- 如最终确定局部文本选择属于明确的长期架构边界，可能需要补 `architecture/notes/`，但本轮先在 active plan 中记录即可。

## 12. 严格方案自审核记录

审核日期：2026-06-03
审核方式：主会话自审核 + 独立子代理审查
审核轮次：单轮，覆盖第一轮架构审查与第二轮中与当前任务直接相关的 TDD / 落地性检查
未使用隔离审查的原因：无；用户已明确要求使用子代理独立审核。
发现摘要：

- `P0`：AI explanation request contract 未闭合到 UI / Core / AI / AppEnvironment 全链路，原方案不能直接进入实现。
- `P1`：selection identity 过轻，原方案未接上 `ReadingSelection` / `ReadingSourceAnchor` 契约，也未明确处理当前早期 `reading_sentences` 结构与真实句子级选择的不一致。
- `P1`：原方案把“先做 iPhone / compact”写成实现范围，但当前 `ReadingDocumentCanvas` 与 renderer 是三端共享，必须先拆出共享 contract phase，再做 iPhone 承载调整。
- `P2`：compact 学习面板状态机、TDD 具体测试名、文档影响检查和本地化 / 无障碍验证点原先不够具体。
写回修改：

- 补入 `ReadingActions.swift`、`ReadingAIExplanation.swift`、`ReadingSelectionExplanationService.swift`、`AppEnvironment.swift`、`ReadingTextSegmentation.swift`、`ReadingSourceAnchor.swift` 和 `ReadingMarkdownBlockRenderer.swift` 到范围与涉及文件路径。
- 新增 `Phase A / Phase B / Phase C` 分阶段落地，先收口共享 selection / request seam，再改 iPhone compact 承载。
- 新增 `Compact 学习面板状态机`，明确 `hidden / collapsed / loading / content / failed` 与非模态承载方式。
- 新增 `Selection Identity Contract`，明确句子与片段的唯一身份字段、stale invalidation 规则和 TTS 边界。
- 把 TDD 改成具体红测名，并补 `ReadingSelectionExplanationServiceTests`、`ReadingSourceAnchorTests` 级别的 contract 验证。
- 补充 `spec/002`、`Localizable.xcstrings`、Dynamic Type / VoiceOver / 长文滚动遮挡的文档影响检查。
仍需用户确认的问题：无。用户已明确采纳推荐方向并授权创建 active plan 与自审。
是否允许进入实现：有条件允许。当前 active plan 已完成自审核并写回关键修订，但建议后续实现严格按 Phase A -> Phase B 顺序推进；若首轮无法稳定交付片段级选择，应显式降级为“只交付句子级选择 + 片段选择 deferred”。

## 13. 完成标准

- iPhone / compact 阅读详情默认以句子为学习操作对象。
- 解释结果不再用阻断式系统 sheet 承载。
- explanation request 具备动态上下文策略，能区分整句与局部片段选择。
- `听`、`解释` 与未来 `更多` 动作有统一扩展承载，不再把正文页堆成按钮面板。
- 测试、页面事实源和 Reading spec 同步更新。

## 14. 剩余风险

- 若本轮无法稳定接入真正的自由文本局部选择，必须在实现和文档中明确第一阶段只交付句子级选择，局部选择保持 deferred，而不是交出语义模糊的半成品。
- 句子分段与 Markdown block 的映射一旦处理不稳，可能影响 selection stale invalidation、TTS source identity 和 future grammar actions，需要用更严格的测试护栏。
- 当前早期 `reading_sentences` 结构仍接近“一 block 一句”；本轮若不调整持久层 schema，就必须用共享 deterministic sentence identity + `ReadingSourceAnchor` 测试来避免把该早期实现误当长期事实。
- 因为 `ReadingDocumentCanvas` 和 renderer 是共享组件，即使结果承载只先调整 iPhone / compact，也必须做一次 iPad / macOS 共享交互回归，确认 side inspector 仍与新的 sentence selection seam 对齐。

## 15. 实施结果

- 已把 compact 阅读详情的默认学习对象从段落切换为句子，并移除阻断式系统 sheet，改为页面内非模态底部学习面板。
- compact learning panel 当前显式区分 `hidden / collapsed / loading / content / failed` 五态；新句子选中先回到 `collapsed`，不会直接复用旧 explanation 结果。
- 已建立共享 `selection_scope / context_mode / source_anchor_id` explanation request contract，并把动态上下文策略贯通到 UI / Core / AI / AppEnvironment。
- 当前阶段显式交付 `句子级选择`；局部文本片段 contract 已落到共享层，但真实自由片段选择 UI deferred，避免交付半成品。
- 页面事实源、Reading spec 和 testing 验证入口已同步更新；`spec/002-navigation-and-routing.md` 本轮无需改动，因为 compact learning panel 是 detail 页面内的非模态内容承载，不引入新的导航 route 或关闭语义。

验证记录：

- `swift test --package-path Packages/LangoTraceCore`
- `swift test --package-path Packages/LangoTraceUI`
- `swift test --package-path Packages/LangoTraceAI`
- `xcodebuild -list -project LangoTrace.xcodeproj`
- `scripts/check-docs.sh`
- `git diff --check`

说明：

- `scripts/verify.sh` 仍会在仓库当前 `swiftlint --strict` 基线处失败；本轮已清掉与本次改动直接相关的 serious lint 问题，剩余失败属于仓库既有 strict lint 基线，并非这次阅读重构新引入的阻塞。
