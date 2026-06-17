# 任务方案：阅读体验收口（进度、收藏、结构统一与解释语言模式收尾）

状态：User Approved
自审核状态：Reviewed
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-17

系列编号：R1（系列母方案：`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`，实施顺序位于 E2 照片写作（`docs/plans/active/2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md`）之后、E3 练习模式路由（`docs/plans/active/2026-06-11-06-feature-practice-mode-routing-foundation.md`）之前）。无硬代码依赖：本方案不依赖 E1 / E2 的交付物，可在用户确认后独立实现。

## 用户确认记录

本方案在 2026-06-11 系列母方案（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）的用户授权下创建。该授权仅覆盖"制定方案文档"本身；本方案进入生产代码实现前，仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

需要用户确认的关键点（见第 13 节"仍需用户确认的问题"）：

1. 是否同意在本方案中解除归档方案 D3 决策的"面板内语言模式切换控件 Deferred"状态（架构已就绪，无需迁移）。
2. 阅读进度的"已读完"判定口径（见第 12 节 Phase 2 决策 R1-D2）。

**用户确认（2026-06-17）：以上两项均已获用户确认。D3 Deferred 解除，面板内解释语言模式切换控件纳入本方案 Phase 4；R1-D2 口径（最后一个 block 完整滚入可视区域时记 `read_completed_at`）已接受。本方案整体范围与实现授权同步确认，状态推进至 `User Approved`。**

## 1. 需求或 bug 描述

2026-06-11 用户决定将 4 份旧 active 方案整体归档至 `docs/archive/plans/`，其中与阅读相关的两份是：

- `2026-06-06-bug-reading-ui-selection-and-display-issues.md`（8 项阅读 UI 缺陷，归档时为 Draft）。
- `2026-06-06-feature-explanation-language-mode-by-level.md`（CEFR 等级驱动的解释语言模式，归档时实施进行中）。

本方案重新评估两份归档方案中仍然成立的内容并吸收为当前工作项，同时补齐 2026-06-11 新版原型（`prototypes/iphone/reading.html`、`prototypes/iphone/reading-document.html`、`prototypes/ipad/reading.html`、`prototypes/mac/reading.html`）与当前实现之间的差距，覆盖五个方向：

1. 逐项复核 8 项归档 UI 缺陷在当前代码（2026-06-11 修复波次之后）中的真实状态，只保留仍然真实存在的项。
2. 阅读进度元信息（读到 n% / 已读完 / 未开始）与收藏（收藏 chip 筛选），对应原型资料库行的 `字数 · 导入日期 · 进度` 三段结构。
3. iPad 学习面板（inspector）折叠时降级为画布底部 compact 面板（原型设计说明 + `docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md` §5 的遗留项）。
4. 解释语言模式（ExplanationLanguageMode）工作的收尾决策：评估代码中已落地部分，明确剩余项的处理方式。
5. 今日代码审查发现 DATA-08：`importInlineDocument` 不构建 `reading_structure_blocks` / `reading_sentences`，而 `updateDocument` 会重建；且 `rebuildStructure` 写入的是整 block 占位"句子"（`character_offset` 恒为 0）并丢弃 `contentRevision`。统一导入 / 更新的结构构建路径——它是阅读进度锚点和未来逐句 TTS 句源的底座。

## 2. 现状描述

以下事实均已对照当前 `HEAD`（含 2026-06-11 修复波次 commit `c1b7947`、`274b7db`）逐项核验。

### 2.1 归档 8 项 UI 缺陷的当前状态（逐项复核结论）

| 归档缺陷 | 当前状态 | 当前代码证据 |
|---------|---------|------------|
| P0-1 系统编辑菜单与学习面板冲突 | 已修复 | `ReadingSelectableTextView.swift` 中 `ReadingNonMenuTextView` 覆写 `canPerformAction` 返回 `false`（commit `c1b7947`） |
| P0-2 iOS 选择句柄残留 | 已修复 | `ReadingSelectableTextView.swift:102-111`：提交高亮后清空 `selectedRange`，配合 `isApplyingCommittedHighlight` 防重入 guard |
| P1 底部文本被面板遮挡 | 已修复 | `ReadingViews.swift:380-414`：`ScrollViewReader` + `onChange(of: selectedSelection?.blockID)` 触发 `scrollTo(blockID, anchor: .bottom)` |
| P1b `sourceFormat.rawValue` 泄漏 | 已修复 | `ReadingSourceFormatDisplay.swift` displayName extension + `ReadingViewComponents.swift:84` 改用 `displayName`，并有 `ReadingSourceFormatDisplayTests.swift` 覆盖 |
| P2 面板解释区块无标签 | 已修复 | `ReadingViewComponents.swift:735-745`：`reading.panel.explanation.title` 条件性区块标题 |
| P2 卡片与背景无区分度 | 已修复 | `ReadingViewComponents.swift:117-122`：非选中卡片 shadow |
| P2 粘贴 / 导入按钮层级 | 已修复 | `ReadingViews.swift:617-637`：两按钮均为 `.bordered` |
| P3 面板无下滑关闭手势 | 已修复 | `ReadingViewComponents.swift:652-659`：handle 区域 `DragGesture` |

结论：8 项缺陷已全部在 2026-06-11 修复波次中关闭，本方案不再保留任何一项为工作项。归档方案的"不做什么"与剩余风险中尚未关闭的事项（macOS NSTextView 右键菜单整合、学习面板复制按钮、VoiceOver 人工回归）见本方案第 5 节与第 20 节的处置。

### 2.2 阅读进度与收藏

- `reading_documents` 当前 28 列（`AppDatabaseReadingMigration.swift:45-92`），没有任何阅读进度、阅读位置或收藏列。
- 资料库行 UI（`ReadingViewComponents.swift` 的 `ReadingLibraryDocumentRow`）不展示进度与收藏；筛选只有平台内已有形态，无 `全部 / 收藏` chips。
- Data package 当前 migration 注册顺序为 v1 至 v17，最新为 `v17_add_photo_artifact_types`（`AppDatabase.swift:93` 注册）。v16（`v16_add_reading_fk_and_check_constraints`）重建了 `reading_explanation_cache` FK 与 `reading_import_operations` CHECK 约束，未触及 `reading_documents`；v17（E2）增加照片资产类型。本方案新 migration 预计为 **v18**。

### 2.3 iPad inspector 折叠

- `ReadingLayoutModel`（`ReadingPresentationModels.swift:27`）对 pad / mac 固定 `showsPersistentInspector: true`，`ReadingViews.swift:120-145` 据此恒常渲染右侧 inspector，没有任何折叠开关或折叠状态。
- `docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md` §5 记录：折叠降级路径在当时未实现，`ReadingDocumentCanvas` 未暴露 `isInspectorExpanded` 状态，留作后续任务。
- iPad 原型 `prototypes/ipad/reading.html` 设计说明明确："inspector 折叠时的降级：学习面板收起后，解释降级为画布底部的 compact 面板，保持「选中 → 解释」路径可用"。

### 2.4 解释语言模式（归档方案 16.1 节对照当前代码）

归档方案 D1–D6 已由用户在 2026-06-06 确认，且大部分实现已经落地并保留在当前代码中：

- `ExplanationLanguageMode` 枚举与 `derive(from:)`：`Packages/LangoTraceCore/Sources/LangoTraceCore/ExplanationLanguageMode.swift`（三档：`sourceLanguage` / `bilingualBridge` / `targetImmersion`），含 `ExplanationLanguageModeTests.swift`。
- `ReadingDocumentStore.currentExplanationMode`（`ReadingDocumentStore.swift:33`）：构造期由 Level 快照派生，作为可覆盖输入进入解释请求（`:96`）与缓存键（`:69`）。
- 缓存表 `reading_explanation_cache` 已带 `explanation_language_mode TEXT NOT NULL` 列与 `(document_id, source_anchor_id, explanation_language_mode)` 三元唯一索引（`AppDatabaseReadingMigration.swift:335,351`；v14 / v15 migration 已落地，对应缓存方案已在 `docs/plans/done/`）。
- Prompt 已升级 v3（`ReadingSelectionExplanationService.swift`，`docs/prompts/reading/selection-explanation.md`）。
- Level 设置页 footnote 说明已落地（`LanguageSpaceEditorView.swift` + 本地化 key）。

仍未完成的两项：

1. Phase 0 spike（Prompt 混合语言指令稳定性验证）：脚本 `docs/reference/research/spikes/2026-06-06-bilingual-bridge-prompt-stability.py` 已就绪但从未手动执行（需要真实 Provider 凭证与可联网环境）。
2. D3 决策中 Deferred 的"面板内临时语言模式切换控件"（归档方案 Phase 5）：架构已就绪（mode 为 store 可覆盖输入、已入缓存键），落地无需迁移。

### 2.5 DATA-08 结构构建不一致（已核验）

- `GRDBReadingLibraryRepository.importInlineDocument`（`GRDBReadingLibraryRepository.swift:49-95`）：插入 `reading_documents` 后只调用 `rebuildSearchIndex`，不调用 `rebuildStructure`，导入后 `reading_structure_blocks` / `reading_sentences` 为空。
- `updateDocument`（同文件 `:159-213`）会调用 `rebuildStructure` 重建结构。
- `rebuildStructure`（同文件 `:590-658`）：每个 block 只写一条"句子"，`character_offset` 硬编码 0、`character_length` 为整 block 修剪后长度，且函数末尾 `_ = contentRevision` 显式丢弃修订号。
- Core 已有真实分句能力 `ReadingTextSegmentation.segmentSentences`（`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift:239`），但 `rebuildStructure` 未使用。
- 后果：导入与更新后的结构事实不一致；占位"句子"无法作为阅读进度锚点或逐句 TTS 句源；结构行无法和 `content_revision` 对账，无法检测过期结构。

## 3. 目标

1. 归档 8 项 UI 缺陷的复核结论写入本方案并收口，不留悬空缺陷叙事。
2. `reading_documents` 拥有阅读进度（百分比 + 位置锚点 + 已读完时间）与收藏列，资料库行展示 `字数 · 导入日期 · 进度` 三段元信息，并提供 `全部 / 收藏` 筛选。
3. 阅读位置以 block 索引 + Swift Character 偏移量持久化，遵守 per-block NSRange 多字节安全转换约定，且结构重建后能检测锚点过期。
4. iPad inspector 可折叠；折叠后解释降级为画布底部 compact 面板，「选中 → 解释」路径保持可用。
5. 解释语言模式收尾：面板内 mode 切换控件落地（解除 D3 Deferred，须用户确认）；Phase 0 spike 作为人工验证项留有明确执行入口与证据落点。
6. 导入与更新共用同一结构构建路径：导入后即有真实句子级 `reading_sentences` 行（基于 `ReadingTextSegmentation.segmentSentences`，character 级 offset / length），结构行记录其构建所基于的 `content_revision`。

## 4. 范围

- Data package：reading migration（新进度 / 收藏列 + 结构表 content_revision 记录）、`GRDBReadingLibraryRepository`（importInlineDocument 结构构建、rebuildStructure 真实分句、进度 / 收藏读写接口）、对应测试。
- Core package：`ReadingLibrary.swift` 文档 summary 模型扩展（进度、收藏字段）、阅读位置锚点 value object、必要的 contract。
- UI package：`ReadingViewComponents.swift`（资料库行三段元信息、收藏标记）、`ReadingViews.swift`（筛选 chips、iPad inspector 折叠、进度采集挂点）、`ReadingLibraryStore.swift` / `ReadingDocumentStore.swift`（进度写回、收藏切换、mode 切换控件状态）、`ReadingPresentationModels.swift`（进度文案映射、折叠布局）、本地化 key。
- 文档：`docs/platform-page-inventory.md`、`docs/spec/012-reading-learning-domain.md`、`docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md` §5 状态更新。

## 5. 不做什么

- 不实现标签（通勤 / 科技等用户自建标签 chips）：原型展示了标签筛选，但标签是跨记录 / 阅读的横向能力，应与记录时间线筛选（E1）统一设计，本方案只做 `全部 / 收藏`。
- 不实现 macOS 右键菜单注入「用语迹解释」（`prototypes/mac/reading.html` 设计）：macOS NSTextView 菜单整合是归档缺陷方案明确排除的独立项，交互模型不同，留待独立方案。
- 学习面板复制按钮：归档方案剩余风险 1 已闭环——2026-06-06 已落地 icon-only 复制按钮（`ReadingViewComponents.swift` 的 `ReadingCopyButton`，使用点为 compact 学习面板 header；见 spec 012 Change Log 2026-06-06 (4)），本方案不需要任何动作。
- 不做阅读 FTS、跨文档搜索、EPUB / PDF 导入（导入格式扩展见 `ReadingImportRegistry` 既有边界）。
- 不把阅读进度、收藏或解释缓存纳入同步、导出或备份；它们保持本地数据。
- 不实现全文朗读或批量 TTS 预生成（`docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` 明确禁止复用单句低摩擦边界）。
- 不改变解释请求的隐私边界、Prompt v3 内容或缓存 schema（v14 / v15 已落地，本方案只消费）。
- 不为 `reading_sentences` 占位数据设计数据迁移兼容：按 CLAUDE.md §1.1 早期重构原则，结构表数据可重建，直接以新逻辑重建。

## 6. 证据与决策依据

- 用户 2026-06-11 归档决定与系列母方案授权（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md` 用户确认记录）。
- 归档方案：`docs/archive/plans/2026-06-06-bug-reading-ui-selection-and-display-issues.md`（8 缺陷定义与"不做什么"）、`docs/archive/plans/2026-06-06-feature-explanation-language-mode-by-level.md`（D1–D6 用户确认、16.1 已完成实施表、Phase 5 Deferred 记录）。
- 代码证据：第 2 节逐条列出的当前文件与行号（均为 2026-06-11 HEAD 核验结果）。
- 原型证据：`prototypes/iphone/reading.html`（`字数 · 导入日期 · 进度` 行结构、收藏 chip、删除可恢复）、`prototypes/iphone/reading-document.html`（持久高亮、不自动 TTS）、`prototypes/ipad/reading.html`（inspector 折叠降级 compact 面板）、`prototypes/mac/reading.html`（右键菜单为后续项）。
- 架构备忘录：`docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md` §2（NSRange 多字节安全约定——进度锚点必须使用 Swift Character 偏移）、§5（iPad 折叠降级遗留项，本方案采纳）；`docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md` §3（不提前建 FTS——本方案遵守）。
- workflow：`docs/workflows/add-storage-migration.md`（本方案含 migration，采纳其任务方案要求、测试要求与故障矩阵；无偏离）。

归档方案吸收的证据边界：

```text
证据能证明什么：归档方案中 8 项缺陷的根因定位曾经成立；D1–D6 决策已获用户确认且大部分已实现。
证据不能证明什么：归档方案的"现状描述"不能当作当前事实——8 项缺陷已全部被今日修复波次关闭，必须以当前代码为准。
迁移前提：只吸收"仍未落地"的部分（spike 执行、D3 控件、§5 折叠降级），并重新对照当前代码确认落点。
照搬风险：若照搬归档方案行号与实施步骤会指向已变更的代码；本方案全部行号已重新核验。
```

高风险补充：

```text
是否需要 spike / probe / fixture / evidence：是（解释语言模式 Phase 0 spike 尚未执行）。
需要时的落点：docs/reference/research/spikes/2026-06-06-bilingual-bridge-prompt-stability.py（已存在），证据写回同目录。
是否包含真实用户敏感内容：否（spike 使用固定样例文本与开发者自备 Provider）。
如何验证和清理：执行结果记录 PASS / FAIL 与降级决策；脚本与证据按 spikes 目录规则保留，不进入生产代码。
```

## 7. 约束映射与验证路径

### 约束 1：实现前必须创建 active plan 并经用户确认

- 约束 ID：DOC-CONST-001 / DOC-CONST-003
- 来源：`docs/README.md` §4.16、`docs/plans/README.md` §4
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查本方案状态字段
- 验证提示：状态推进到 `User Approved` 前不得改生产代码
- 说明：无

### 约束 2：数据迁移必须遵守存储 spec 与 migration workflow

- 约束 ID：DOC-CONST-012
- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/workflows/add-storage-migration.md`
- 适用范围：Data package
- 严重度：blocker
- 执行或验证方式：migration 单元测试（新库 schema 正确 + 旧库升级正确）
- 验证提示：`swift test --package-path Packages/LangoTraceData` 中 reading migration 测试通过；进度 / 收藏列归类为本地主数据（用户行为产物，不可重建），结构表为可重建派生数据
- 说明：本方案新增 1 个 migration（进度 / 收藏列 + 结构表 content_revision 记录）

### 约束 3：NSRange 多字节安全转换约定

- 来源：`docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md` §2
- 适用范围：阅读位置锚点的 offset 语义
- 严重度：blocker
- 执行或验证方式：单元测试（含 emoji / CJK 文本的 offset 往返）
- 验证提示：持久化偏移量一律为 Swift Character 计数，UITextView NSRange 必须经 `characterRange(from:in:)` 等价转换；测试用例必须包含多字节字符
- 说明：进度锚点与句子 offset 都依赖该约定

### 约束 4：选区解释与 TTS 不得被新交互自动触发

- 来源：`docs/spec/012-reading-learning-domain.md` §6、`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.3
- 适用范围：进度采集、折叠降级、mode 切换
- 严重度：blocker
- 执行或验证方式：UI store 单元测试
- 验证提示：滚动采集进度、折叠 / 展开 inspector 不得发起解释请求或 TTS；mode 切换只在已有选区且用户显式点击时重发请求
- 说明：无

### 约束 5：UI 状态与语言边界

- 来源：`docs/spec/003-ui-design-system.md` §3、§4.x 阅读条目；`docs/spec/006-interface-localization-and-language-boundaries.md`
- 适用范围：资料库行、筛选 chips、折叠控件文案
- 严重度：warn
- 执行或验证方式：本地化 key 单元测试 + 人工审查
- 验证提示：进度文案（读到 n% / 已读完 / 未开始）为界面语言；文档标题保留目标语言原文；状态不只靠颜色表达
- 说明：无

### 约束 6：平台页面变化需同步页面清单

- 约束 ID：DOC-CONST-006
- 来源：`docs/platform-page-inventory.md` §9、`docs/review/README.md`
- 适用范围：iPad 阅读折叠、资料库行变化
- 严重度：warn
- 执行或验证方式：完成后人工更新页面清单并判断专项审查
- 验证提示：iPad 阅读页能力边界（折叠降级）写回清单
- 说明：无

## 8. 涉及的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabaseReadingMigration.swift`（新增 migration 注册）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（migration 注册顺序）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingLibraryRepository.swift`（importInlineDocument、rebuildStructure、进度 / 收藏读写）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift`（summary 模型扩展、阅读位置锚点类型）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`（只消费，必要时小幅扩展返回 offset 信息）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`（mode 切换、进度写回 seam）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- 测试：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/`、`Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/`

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSelectableTextView.swift`（NSRange 转换 helper、复核证据）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore+Selection.swift`、`ReadingDocumentStore+Cache.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingExplanationCacheRepository.swift`（mode 维度缓存命中事实）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ExplanationLanguageMode.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift`（iPad 面板现状）

## 10. 涉及的文档路径

- 本方案。
- `docs/platform-page-inventory.md`（iPhone / iPad / macOS 阅读页能力边界更新）。
- `docs/spec/012-reading-learning-domain.md`（进度 / 收藏 / 折叠降级 / mode 切换控件落地后的变更记录）。
- `docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md`（§5 遗留项完成后标注采纳去向）。
- 参考：`docs/archive/plans/` 两份归档方案、`docs/plans/done/2026-06-06-feature-reading-explanation-cache-and-sentence-indicators.md`。

## 11. bug 分析

非 bug 任务，不适用。DATA-08 属于审查发现的实现不一致，按 feature 工作项处理：

```text
来源：2026-06-11 系列母方案阶段 1 代码审查
发现 ID 或 trigger ID：DATA-08
严重度：P1（阻碍进度锚点与逐句 TTS 句源，但当前无用户可见崩溃）
对应 work item：第 12 节 Phase 1
验证证据：GRDBReadingLibraryRepository.swift:49-95（import 无结构构建）、:590-658（占位句子 + `_ = contentRevision`）
```

## 12. 实施方案

### Phase 1：DATA-08 结构构建统一（先做，进度锚点的底座）

1. 先写失败测试（见第 15 节）：导入后 `reading_sentences` 应存在句子级行且 `character_offset` 反映真实位置。
2. `rebuildStructure` 改用 `ReadingTextSegmentation.segmentSentences` 对每个 block 真实分句；每句写入一行 `reading_sentences`，`sentence_index` 全文递增，`character_offset` / `character_length` 为该句在 block plain text 内的 Swift Character 偏移与长度，`text_hash` 为句文本 SHA-256。
3. migration 为 `reading_structure_blocks` 与 `reading_sentences` 增加 `content_revision INTEGER NOT NULL DEFAULT 1` 列；`rebuildStructure` 写入实际 `contentRevision`，删除 `_ = contentRevision` 丢弃语句。
4. `importInlineDocument` 在同一事务内调用 `rebuildStructure`（与 `updateDocument` 同路径），保证导入即有结构。
5. 既有占位结构数据按早期重构原则不做兼容：migration 后由下一次 `rebuildStructure` 或一次性重建覆盖（实现时在 migration 内对所有 active 文档触发重建，保证一致性）。

### Phase 2：阅读进度与收藏（migration + repository + UI）

migration（与 Phase 1 合并为一个 migration，id 在实施时按当时最新注册顺序分配，当前最新为 `v17_add_photo_artifact_types`，预计为 **v18**）为 `reading_documents` 新增：

- `is_favorite INTEGER NOT NULL DEFAULT 0`
- `reading_progress_percent INTEGER`（0–100，空表示未开始）
- `last_read_block_index INTEGER`、`last_read_character_offset INTEGER`（Swift Character 计数）
- `last_read_structure_version INTEGER`、`last_read_content_revision INTEGER`（锚点过期检测：与当前文档修订不一致时锚点降级为只按百分比恢复）
- `read_completed_at REAL`

决策 R1-D1（锚点语义）：阅读位置锚点 = `(content_revision, block_index, character_offset)`。恢复时若 `content_revision` 不一致，不做模糊重定位，回退到按 `reading_progress_percent` 滚动到近似位置；该回退是可接受边界，写入 spec 012 变更记录。

决策 R1-D2（已读完口径，需用户确认）：用户将最后一个 block 完整滚入可视区域时记 `read_completed_at`；列表态显示优先级为 已读完 > 读到 n% > 未开始。已读完后继续阅读不清除 `read_completed_at`。

进度采集：iPhone / iPad / macOS 阅读画布通过可视 block 追踪（ScrollView 几何观察）产生 `(blockIndex, offset, percent)` 投影，节流写回（页面离开时必写 + 阅读中按最小间隔写）；写回走 repository 接口 `updateReadingProgress`，不触发任何 AI / TTS。

收藏：repository `setFavorite(documentID:isFavorite:)`；资料库行加收藏标记（形状 + 文字辅助，不只靠颜色）；筛选 chips `全部 / 收藏` 进入 `ReadingLibraryStore` 状态。

行 UI：row-sub 固定三段 `字数 · 导入日期 · 进度`；字数由 body 词数计算（目标语言按空白分词、CJK 按字符数，做成 Core 纯函数可测）。

### Phase 3：iPad inspector 折叠降级

1. `ReadingLayoutModel` 增加折叠维度（pad 可折叠，mac 维持常驻；mac 折叠不在本方案）。
2. `ReadingViews.swift` iPad 布局加折叠按钮（复用 iPad 既有面板折叠交互语言，见 `PadPanelGestureTests` 的判定 helper 风格）；折叠状态为 view 级 `@State`，不持久化。
3. 折叠时解释承载降级为画布底部 compact 面板（复用 `ReadingCompactLearningPanel`），保持「选中 → 解释」可用；展开时回到右栏，compact 面板隐藏。
4. 状态归属不变：解释请求与结果仍以 `ReadingDocumentStore` 为唯一事实源，折叠只改变承载容器。

### Phase 4：解释语言模式收尾

1. （须用户确认解除 D3 Deferred）面板内 mode 切换控件：在解释面板（compact 面板与 iPad / mac inspector 共用组件）加入三档切换；切换更新 `ReadingDocumentStore.currentExplanationMode` 并对当前选区重发请求；结果按 mode 落入既有三元唯一索引缓存，切回即命中（架构已就绪，无迁移）。按归档方案 D3 已获用户确认的语义：mode override 为 session / 文档级状态——关闭文档或切换语言空间后清空，回落到 Level 派生默认值；不作为持久化偏好存储（持久化"解释语言偏好"设置项按归档方案 §2.3 口径留待后续单独立案）；切换必然触发重新请求，不做 UI 层二次翻译。
2. 控件文案遵守 spec 006：三档名称用界面语言表达（如 母语解释 / 双语过渡 / 目标语言沉浸），不暴露枚举名。
3. Phase 0 spike 处置：本方案不把 spike 作为代码门禁（控件只是切换已有请求维度，不新增 Prompt 行为）；spike 作为人工验证项保留——在 macOS 真机环境用自备 Provider 运行 `docs/reference/research/spikes/2026-06-06-bilingual-bridge-prompt-stability.py`，PASS / FAIL 与降级决策（FAIL 时 bridge 默认派生降级为 `sourceLanguage`，枚举保留，按归档方案 D6 口径）记录回 spikes 目录与本方案实施记录。

### Phase 5：文档收口

更新 `docs/platform-page-inventory.md`、`docs/spec/012` 变更记录、备忘录 §5 采纳标注；按 `docs/review/README.md` 判断 migration 是否触发专项审查（数据库 schema 变化：是，需创建 review round 或在本方案说明）。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：本环境无并行隔离审查会话可用于方案文本审查；已按协议维度逐项自查，并以两个只读代码核验代理的输出作为事实输入。
发现摘要：
  第一轮：
  - [P1] 初稿把"面板内 mode 切换控件"直接列为工作项，但归档方案 D3 是用户确认过的 Deferred 决策；解除 Deferred 属于决策变化，必须显式提请用户确认。已在用户确认记录与第 12 节 Phase 4 标注。
  - [P1] 初稿进度锚点只存 block_index + offset，未考虑文档编辑后锚点失效；已加入 content_revision / structure_version 过期检测与按百分比回退的决策 R1-D1。
  - [P2] 初稿把 Phase 0 spike 写成实现门禁；复核后判定控件不改变 Prompt 行为，spike 降为人工验证项并保留 D6 降级口径，避免 Linux 环境阻塞。
  - [P2] migration id 不应硬编码：系列中 R1 / E4 / E6 各含 migration，落地顺序决定编号；改为"实施时按当时最新注册顺序分配"。
  第二轮：
  - [P1] 进度节流写回存在并发写竞争（滚动写与离开页写）；已要求 repository 写接口幂等且以最新值覆盖，测试覆盖乱序写。
  - [P2] 字数计算若放在 UI 层会三端重复；改为 Core 纯函数并补测试落点。
  - [P2] 初稿验证命令缺 Core 包（segmentSentences 消费方式变化、字数函数新增）；已补。
  - [P3] 收藏标记需要形状 + 文字，不只靠颜色（spec 003）；已写入 Phase 2。
写回修改：以上各项均已写回第 3、7、12、15、16 节。
仍需用户确认的问题：
  1. 解除 D3 Deferred（面板内 mode 切换控件纳入本方案）。✅ 已确认（2026-06-17）
  2. R1-D2 已读完口径（最后 block 完整滚入可视区域）。✅ 已确认（2026-06-17）
  3. 本方案整体范围与实现授权（推进到 User Approved）。✅ 已确认（2026-06-17）
是否允许进入实现：用户已确认，可进入实现。
```

## 14. 复查方法

1. 新建空库导入一篇多段落文档：`reading_structure_blocks` / `reading_sentences` 立即存在，句子行的 `character_offset` 单调递增且与正文一致（含 emoji / CJK 样例）。
2. 编辑文档正文后：结构行 `content_revision` 与文档一致；旧进度锚点恢复时回退到百分比定位，不指向错误句子。
3. 资料库行显示 `字数 · 导入日期 · 进度`；未读文档显示 `未开始`，滚动后回到列表显示 `读到 n%`，读完显示 `已读完`；收藏切换后 `收藏` 筛选只显示收藏文档。
4. iPad：折叠 inspector 后选中文本，compact 面板从底部出现并可触发解释；展开后回到右栏；折叠 / 展开过程不发起任何网络请求（可由 store 测试断言）。
5. mode 切换：同一选区切换三档，首次切换发起新请求，切回命中缓存（断言 repository 命中而非再次请求）。
6. 故障路径：migration 失败保持原库不半写入（migration 测试）；进度写回失败不影响阅读主流程（错误进入诊断而非 UI 阻断）；锚点指向已删除 block 时回退百分比定位。
7. mode 切换控件落地后，对同一选区分别以三档（含 A1 与 C1/C2 水平空间）发送解释请求，人工抽检各字段语言是否符合归档方案 D2 字段表；字段语言遵从为软质量，只抽检不自动断言（吸收自归档方案 §15 复查方法第 2 步）。

## 15. TDD / 测试落点

```text
测试落点：
  1. Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingStructureBuildTests.swift（新建，DATA-08）
  2. Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingProgressAndFavoriteTests.swift（新建，migration + repository）
  3. Packages/LangoTraceCore/Tests/LangoTraceCoreTests/ReadingWordCountTests.swift（新建，字数纯函数）
  4. Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingLibraryProgressPresentationTests.swift（新建，进度文案映射 / 筛选 / 收藏状态）
  5. Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingInspectorCollapseTests.swift（新建，折叠降级状态机 + 不触发请求断言）
先失败用例：
  testImportInlineDocumentBuildsSentenceLevelStructure
  —— 调用 importInlineDocument 后查询 reading_sentences，断言行数大于 block 数（多句段落）且存在非 0 character_offset；当前实现导入后表为空，必然失败。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceData --filter ReadingStructureBuildTests
不新增单元测试的原因（如适用）：滚动几何采集的真实触发、iPad 折叠手势与 VoiceOver 属人工模拟器验证项（见第 14 节与第 20 节），其状态机部分已由上述单元测试覆盖。
```

## 16. 验证命令

```bash
# 聚焦（红绿循环）
swift test --package-path Packages/LangoTraceData --filter ReadingStructureBuildTests
swift test --package-path Packages/LangoTraceData --filter ReadingProgressAndFavoriteTests

# 受影响 package 轻量验证
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
git diff --check
git status --short
```

按 CLAUDE.md §1.4 约束 7，不主动运行 `scripts/verify.sh`；migration 涉及数据库结构，收口前如用户要求全量验证再运行。

## 17. 文档影响检查

- `docs/platform-page-inventory.md`：iPhone / iPad / macOS 阅读页能力边界（进度、收藏、折叠降级、mode 切换控件）必须更新——是。
- `docs/spec/012-reading-learning-domain.md`：进度锚点语义（R1-D1）、已读完口径（R1-D2）、mode 切换控件落地写入变更记录——是。
- `docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md`：§5 折叠降级采纳后标注去向——是。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：进度 / 收藏列为本地主数据、结构表为可重建派生数据，与既有分类一致，预计无需改 spec；落地后确认。
- ADR：无核心决策反转，不新增 ADR。
- `docs/review/`：数据库 schema 变化命中专项审查触发条件，实现完成后创建 review round 或在本方案实施记录中说明。

## 18. 实施记录

2026-06-11：方案创建并完成两轮自审核（见第 13 节）。尚未进入实现。

## 19. 完成标准

1. 第 15 节全部测试存在且通过；DATA-08 复现测试转绿。
2. 三端资料库行显示三段元信息与收藏筛选；iPad 折叠降级路径可用（模拟器人工验证记录在实施记录）。
3. mode 切换控件落地且缓存命中行为有测试。
4. spike 执行结果（PASS / FAIL + 降级决策）记录到 spikes 目录与实施记录；若环境持续不可用，按 deferred 项记录决策日志。
5. 文档影响检查各项完成；migration 专项审查判断有记录。
6. plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：收口时逐项核对第 12 节五个 Phase。
scope-down 是否已记录：若任何 Phase 缩水，记录在实施记录。
deferred / aborted 项是否已从完成叙事中剥离：spike 若 deferred 单独记录。
后续事实源或复审入口：spec 012、platform-page-inventory、备忘录 §5。
```

## 20. 剩余风险

1. 滚动进度采集的三端几何 API 差异（iOS ScrollView 观察与 macOS 行为不完全一致）可能导致百分比口径轻微不一致；以"可视 block 索引 / 总 block 数加权"为统一口径，差异由人工验证兜底。
2. spike 在当前 Linux 环境无法执行；若长期未执行，bridge 模式在弱模型上的语言遵从风险持续存在（归档方案剩余风险 1 的延续），运行期不因语言漂移硬失败的边界仍然成立。
3. macOS 右键菜单整合、VoiceOver 人工回归未纳入本方案，作为已知未关闭项保留（归档方案剩余风险 2–3 的延续），后续按需要独立立案；阅读选区 VoiceOver 回归已列入 Mac 验证清单第 31 项。学习面板复制按钮已于 2026-06-06 落地，不再是未关闭项。
4. migration 内对存量文档一次性重建结构在大文档库下的耗时未知；早期阶段无真实用户数据，风险可接受，实现时保留单文档重建失败不阻塞整体 migration 的策略。
