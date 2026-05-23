# 任务方案：记录详情双文本卡片与原文编辑

状态：Done
类型：feature
创建日期：2026-05-23
最后更新日期：2026-05-23

审核状态：Verified

## 用户确认记录

- 2026-05-23：用户在 iPhone `记录详情` 人工测试中发现目标语言学习文本右上角编辑按钮挤压正文阅读宽度，长文本展示不美观。
- 2026-05-23：讨论确认目标语言学习文本卡片应改为类似 `逐句练习` 卡片的顶部工具区：左侧展示动态语义标题，右侧展示编辑 / 重新分析按钮，正文全宽展示。
- 2026-05-23：用户强调左侧标题必须随当前语言空间动态变化，不能硬编码为 `英文表达`。
- 2026-05-23：用户提出母语文本也采用一致卡片设计，并开放母语文本编辑功能。
- 2026-05-23：当前结论为创建本方案文档，用户审核通过前不开始代码实施。
- 2026-05-23：用户明确要求提交当前文档改动后立即按本方案完整实施；本方案进入实施。

## 1. 需求描述

当前 `记录详情` 页面中，目标语言学习文本使用只读卡片 + 右上角悬浮编辑按钮。实现上通过给正文增加右侧 padding 避免按钮遮挡，但在 iPhone 窄屏和长文本场景中会让可读文本列变窄，视觉上像表单字段被操作按钮挤压，不符合学习文本应优先服务阅读和练习的定位。

本任务将 `记录详情` 中的母语原文和目标语言学习文本统一改为“文本卡片 + 顶部工具区”的组件模式：

- 卡片顶部左侧展示动态语义标题，例如 `中文记录`、`英文表达`、`日文表达`。
- 卡片顶部右侧展示该文本对象的操作按钮，例如编辑、重新分析、重新生成。
- 卡片正文全宽展示，不再为右上角悬浮按钮预留文本 padding。
- 母语原文可以编辑；目标语言学习文本继续可以编辑。
- 母语原文保存后不自动调用 AI Provider，而是让已有学习材料进入需要重新生成的状态，由用户显式触发重新生成。

## 2. 现状描述

当前代码事实：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift` 中 `EntryDetailView` 通过 `ReadOnlyEntryTextPanel(text: entry.body, emphasis: .secondary)` 展示母语原文，母语原文没有详情页编辑入口。
- 同一文件中的 `LearningMaterialEditorView` 用 `ZStack(alignment: .topTrailing)` 将 `readOnlyLearningText` 和 `actionOverlay` 叠放，并通过 `textTrailingPadding` 为编辑 / 重新分析按钮预留右侧空间。
- `LearningMaterialEditorSheet` 已提供目标语言学习文本编辑 sheet，保存后调用 `onUpdateLearningText(rendering.id, learningText)`。
- `LearningContentStore` 当前有 `createEntry`、`generateLearningMaterial`、`updateLearningText` 和 `analyzeCurrentLearningText`，没有更新 `LearningEntry.body` 的 store 方法。
- `LearningContentRepository` 当前有 `createEntry`，没有更新原始 Entry title/body/scene 的协议方法。
- `GRDBLearningContentRepository` 当前有 `createEntry`、`saveGeneratedMaterial`、`updateLearningText`、`replaceAnalysis` 等方法，没有更新 `entries.body` 的公开方法。
- `learning_materials` 当前只有 `analysis_source_hash`，该 hash 表达“逐句分析是否基于当前 learning text”，不表达“learning material 是否基于当前 Entry body”。
- `LanguageSpacePreview` 当前包含 `nativeLanguage`、`targetLanguage` 和 `targetLanguageCode`；`LanguageSpace.preview` 会把语言 code 解析为中文显示名，因此详情页标题可以基于 `nativeLanguage` / `targetLanguage` 动态生成，但 AI 请求仍必须继续使用稳定 code 边界。

当前文档事实：

- `docs/spec/003-ui-design-system.md` 已要求 iPhone 记录详情中的母语原文和目标语言学习文本优先服务阅读和练习，不应表现成带字段标题的表单。
- 同一规范当前仍描述“目标语言学习文本区默认状态只显示正文和右上角悬浮编辑按钮”，该点已被人工测试证明会挤压长文本，应在本任务中更新为顶部工具区设计。
- `docs/platform-page-inventory.md` 将 `记录详情` 描述为可阅读原始记录、生成学习材料、编辑 learning text、重新分析和进入练习候选；本任务完成后需要补充“编辑原始记录”和“原文变更后的重新生成状态”。

## 3. 目标

本任务完成后应达到以下目标：

1. 母语原文和目标语言学习文本在 `记录详情` 中使用一致的文本卡片布局。
2. 两类文本卡片的标题均动态来自当前语言空间，不硬编码 `中文`、`英文` 或任何单一语种。
3. 目标语言学习文本正文全宽展示，编辑 / 重新分析按钮不再挤压正文阅读宽度。
4. 母语原文支持通过 sheet 编辑，编辑体验与目标语言学习文本一致。
5. 母语原文保存后更新本地 Entry，不自动发送 AI Provider 请求。
6. 如果母语原文保存时该 Entry 已存在当前学习材料，该学习材料在 UI 中明确显示“基于旧记录”或等价状态，并提供用户显式触发的重新生成入口。
7. 目标语言学习文本编辑后继续沿用现有“分析过期 -> 重新分析”语义。
8. VoiceOver 能区分母语记录卡和目标语言表达卡，并能朗读编辑、重新分析、重新生成等按钮的实际意图。

## 4. 范围

本任务范围：

- iPhone `记录详情` 页面中的母语原文卡片、目标语言学习文本卡片和相关编辑 sheet。
- iPad / macOS 复用 `EntryDetailView` 时的同源布局影响复查。
- `LearningContentRepository`、`GRDBLearningContentRepositoryBridge`、`GRDBLearningContentRepository` 和 `InMemoryLearningContentRepository` 的 Entry body 更新能力。
- `LearningContentStore` 的原文编辑状态更新与重新生成状态协调。
- 与本任务直接相关的 UI 单元测试、Data 单元测试、源码约束测试和文档更新。

## 5. 不做什么

本任务不做以下内容：

- 不自动调用 AI Provider 重新生成学习材料。
- 不在母语原文编辑保存时静默删除旧学习材料。
- 不改变 Entry 的创建流程、照片写作流程或 Prompt 输出 schema。
- 不实现 Entry 标题、场景、标签或附件编辑。
- 不实现历史版本对比、撤销栈、冲突合并或同步冲突处理。
- 不新增新的 AI 请求确认 sheet。
- 不改变逐句练习卡片的听 / 练按钮职责。

## 6. 证据与决策依据

交互依据：

- iPhone 窄屏中，正文阅读宽度比操作按钮常驻悬浮位置更重要。
- 顶部工具区能复用 `逐句练习` 卡片的视觉节奏：左侧给出语义锚点，右侧放 44pt 操作按钮，正文独立占据全宽。
- 左侧标题必须承载真实信息，而不是为了填空添加装饰。母语卡使用 `{母语显示名}记录`，目标卡使用 `{目标语言显示名}表达`，可以让用户明确两个文本对象的职责。

产品和数据依据：

- 母语原文是用户生活记录的 source，目标语言学习文本是从 source 派生的学习材料。二者都可以编辑，但编辑后的后果不同。
- 目标语言学习文本编辑只影响派生文本和逐句分析，因此应继续使用“待重新分析”状态。
- 母语原文编辑会改变学习材料的来源，如果已有学习材料继续显示，需要披露它可能基于旧原文；重新生成必须由用户显式触发，以符合本地优先和用户自带 Provider 的隐私边界。

隐私依据：

- 保存母语原文是本地数据库写入，不应触发外部 Provider 请求。
- 重新生成学习材料会发送当前 Entry 文本给用户配置的 AI Provider，必须保持显式用户动作。

## 7. 涉及的代码文件路径

预计修改：

- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/InMemoryLearningContentRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBLearningContentRepositoryTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`

可能修改：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LearningMaterialGenerationTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningMaterialGenerationActions.swift`
- `LangoTraceApp/AppEnvironment.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentencePairActionControls.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBLearningContentRepositoryTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`

## 9. 涉及的文档路径

本方案创建：

- `docs/plans/active/2026-05-23-feature-entry-detail-text-card-editing.md`

实施时预计更新：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/learning-content/impl.md`
- `docs/platform-page-inventory.md`

如果实现过程中改变 AI 请求边界或 Provider 调用条件，还必须复查：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`

## 10. 设计方案

### 10.1 文本卡片布局

新增或重构一个仅负责详情页文本展示的组件，例如 `EntryDetailTextCard`。该组件负责：

- 顶部工具区：左侧标题，右侧按钮组。
- 正文展示：全宽、多行、保留 line spacing。
- 可选状态提示：位于标题或正文之间，避免占用正文右侧宽度。
- 可访问性：卡片标题、正文和操作按钮可被 VoiceOver 清晰识别。

推荐视觉结构：

```text
[中文记录]                         [编辑]
今天我写了一句很短的话。

[英文表达 · 待重新分析]             [重新分析] [编辑]
Today I wrote one very short sentence for practice.
```

### 10.2 动态标题规则

标题不硬编码具体语种。推荐规则：

- 母语原文卡：`{languageSpace.nativeLanguage}记录`
- 目标语言学习文本卡：`{languageSpace.targetLanguage}表达`
- 如果语言显示名为空或不可用，母语卡兜底 `原始记录`，目标卡兜底 `目标语表达`。
- 本地化 key 应支持带参数格式化，而不是在 Swift 代码中拼接固定中文词。

示例本地化 key：

- `entry.detail.sourceText.titleFormat`：`%@记录`
- `entry.detail.sourceText.fallbackTitle`：`原始记录`
- `entry.detail.learningText.titleFormat`：`%@表达`
- `entry.detail.learningText.fallbackTitle`：`目标语表达`

### 10.3 母语原文编辑

母语原文编辑采用 sheet：

- sheet 标题：`修改{母语显示名}记录`，兜底 `修改原始记录`。
- 内容：大面积 `TextEditor`。
- 顶部工具栏：取消 / 保存。
- 保存条件：trim 后正文非空，且和原值不同。
- 保存行为：只更新本地 Entry body 和 updated_at，不自动触发 AI 生成。
- 保存后：详情页立即展示新正文。

如果 Entry 当前没有学习材料，保存原文后不显示重新生成状态。

如果 Entry 当前已有学习材料，保存原文后目标语言学习文本卡进入“基于旧记录”状态，并提供 `重新生成` 操作。该操作复用现有 `generateLearningMaterial` 显式请求路径。

### 10.4 目标语言学习文本编辑

目标语言学习文本继续采用现有 sheet 编辑模式，但卡片展示改为顶部工具区：

- 常态：左侧 `{目标语言}表达`，右侧 `编辑`。
- `analysisIsStale`：左侧 `{目标语言}表达 · 待重新分析`，右侧 `重新分析` 和 `编辑`。
- `analyzing`：左侧 `{目标语言}表达 · 分析中`，右侧编辑按钮禁用或隐藏，正文仍可读。
- `failed`：左侧 `{目标语言}表达 · 分析失败`，右侧保留可恢复动作。

目标语言学习文本保存后继续调用现有 `updateLearningText`，保持当前分析过期与重新分析行为。

### 10.5 原文变更后的学习材料状态

“当前学习材料是否基于旧原文”是 Entry source 与派生 material 之间的数据一致性状态，不能只依赖临时 UI 状态，否则 App 重启、重新进入详情页或跨平台复用同一 repository 时会丢失提示。

优先方案：

- 在 `learning_materials` 持久化当前 material 生成时对应的 `source_entry_body_hash`，hash 使用与 `LearningMaterialTextHash.sha256` 一致的换行归一化规则。
- `saveGeneratedMaterial` 在同一 write transaction 中基于被读取的 active Entry body 写入 `source_entry_body_hash`。该字段不从 AI 返回结果信任输入。
- `updateEntryBody` 只更新 `entries.body` / `entries.updated_at`，不修改当前 learning material，也不把 `analysis_status` 标记为 stale。
- Store / UI 通过比较当前 Entry body hash 与当前 material 的 `source_entry_body_hash` 推导 `sourceEntryIsStale`。
- UI 将该状态展示为 `{目标语言}表达 · 基于旧记录`。
- 重新生成成功会创建新的 current material，并写入新的 `source_entry_body_hash`，因此 `sourceEntryIsStale` 自然清除。

架构取舍：

- 如果现有 `LearningMaterial.analysis_source_hash` 能稳定代表当前 learning text 的分析来源，则不要复用它表达 Entry source body 是否变化，避免混淆“目标文本分析过期”和“原文来源过期”。
- 本任务采用持久化 source hash，而不是 UI-only Set。原因是该状态属于 material 与 source 的一致性事实，用户重启 App 后仍应看到“基于旧记录”；只放 Store 会让页面显示与数据库事实不一致。
- 本任务不持久化完整 source 文本快照，不做版本对比。hash 足以支持 stale 判断，并避免把历史原文版本系统提前引入当前 MVP。
- `learningTextAnalysisIsStale` 与 `sourceEntryIsStale` 必须分别建模：前者表示逐句分析需要重新分析，后者表示学习材料需要重新生成。二者可以同时为 true，UI 应同时给出正确主动作优先级。

### 10.6 平台复用边界

`EntryDetailView` 是 iPhone 详情页、iPad route 详情页和 macOS 部分详情区域的共享组件，本任务应优先保证该组件的布局和行为正确。

当前 `PadMainSections.workspaceOverview` 仍使用独立 `TextPanel` 双栏概览，并不完全经过 `EntryDetailView`。该概览不是本任务的主要编辑入口；实施时必须复查是否需要保持只读概览，或把双栏概览迁移到新的只读 `EntryDetailTextCard` 展示样式。若不迁移，必须在文档影响检查中明确记录“iPad workspace overview 仍为只读概览，不承载本次原文编辑能力”。

## 11. 实施方案

### 11.1 测试先行

Data 层测试：

- 增加 migration 测试：`learning_materials` 包含 `source_entry_body_hash`，从旧 schema 迁移时能按当前 Entry body 回填。
- 增加“保存 generated material 会写入当前 Entry body hash”的测试。
- `GRDBLearningContentRepositoryTests` 增加“更新 Entry body 会持久化正文并刷新 updated_at”的测试。
- 增加“空正文更新会失败且不修改原 Entry”的测试。
- 增加“更新原文不修改当前 LearningMaterial learningText、originalGeneratedText、analysis_status、analysis_source_hash，但会让 current material 可被推导为 source stale”的测试。
- `InMemoryLearningContentRepositoryTests` 增加同等行为测试。

UI Store 测试：

- `LearningContentStoreTests` 增加“更新母语原文后 entries 和 selectedEntry 同步刷新”的测试。
- 增加“已有 learning material 时更新母语原文会让该 entry 的 `sourceEntryIsStale` 为 true”的测试。
- 增加“重新生成成功后通过新的 material source hash 清除 `sourceEntryIsStale`”的测试。
- 增加“更新 learning text 只让 `analysisIsStale` 为 true，不改变 `sourceEntryIsStale`”的测试。

UI 源码约束测试：

- `PhoneIOSConvergenceTests` 或 `PremiumUIBehaviorTests` 固定目标语言文本卡不再使用 `ZStack(alignment: .topTrailing)` + `textTrailingPadding` 方式挤压正文。
- 固定 `EntryDetailView` 同时传入 `languageSpace.nativeLanguage` 和 `languageSpace.targetLanguage` 生成动态卡片标题。
- 固定母语原文编辑入口存在，且目标文本编辑入口仍存在。

### 11.2 数据层实现

在 `LearningContentRepository` 中新增方法：

```swift
@discardableResult
func updateEntryBody(entryID: String, spaceID: String, body: String) throws -> LearningEntry
```

在 `InMemoryLearningContentRepository` 中实现：

- trim body。
- body 为空时抛出已有或新增的 repository error。
- 只允许更新对应 space 中存在的 entry。
- 更新 entriesBySpace 中的 entry.body。

在 `GRDBLearningContentRepository` 中实现公开方法：

```swift
public func updateEntryBody(entryID: String, body: String) throws -> LearningEntry
```

行为：

- trim body。
- body 为空时抛出 `LearningContentRepositoryError.emptyEntryBody`。
- 在单个 database write transaction 中更新 `entries.body` 和 `entries.updated_at`，并只允许更新未删除的 active entry。
- 返回更新后的 active entry。
- 不修改 `learning_materials.learning_text`、`learning_materials.original_generated_text`、`analysis_status`、`analysis_source_hash` 或 analysis JSON。

在 `GRDBLearningContentRepositoryBridge` 中实现协议方法，转发到 GRDB repository，并校验返回 entry 的 spaceID。

Schema / 模型调整：

- 新增 migration `v5_add_learning_material_source_entry_body_hash`。
- `learning_materials` 新增 `source_entry_body_hash TEXT NOT NULL`。旧数据迁移时按当前 `entries.body` 回填；当前阶段尚无正式用户数据，这个回填可接受。
- `LearningMaterial` 新增 `sourceEntryBodyHash` 字段。
- `LearningRendering` 可新增 `sourceEntryBodyHash` 或 Store 可保留 material 级状态；推荐给 `LearningRendering` 增加可选或非可选字段，使 UI Store 能在不突破 repository 边界的前提下推导 source stale。

### 11.3 Store 与 App Shell

在 `LearningContentStore` 中新增：

```swift
@discardableResult
func updateEntryBody(entryID: String, body: String) throws -> LearningEntry
```

行为：

- 调用 repository 更新 body。
- reload entries / selectedEntry / settingsCapabilities。
- 如果该 entry 当前有 rendering，通过当前 Entry body hash 与 rendering / material 的 `sourceEntryBodyHash` 推导 `sourceEntryIsStale`。
- 如果后续重新生成成功，新的 current material source hash 与当前 Entry body 一致，`sourceEntryIsStale` 自然为 false。
- 保存失败时不关闭编辑 sheet，并在 UI 层显示本地保存失败提示；不得吞掉错误后让用户误以为保存成功。

新增 Store 查询：

```swift
func sourceEntryIsStale(for entry: LearningEntry) -> Bool
```

在 `PhoneMainView`、`PadMainSections`、`MacWorkspaceContentView` 调用 `EntryDetailView` 时传入 `onUpdateEntryBody`。

### 11.4 UI 组件实现

在 `PhoneMainSupportingViews.swift` 中重构：

- 将 `ReadOnlyEntryTextPanel` 替换或扩展为 `EntryDetailTextCard`。
- 将 `LearningMaterialEditorView` 的 `ZStack` 悬浮按钮改为顶部工具区。
- 新增 `SourceEntryEditorSheet` 或复用通用文本编辑 sheet。
- 保持按钮最小 44pt 触控目标。
- 保持正文 `.fixedSize(horizontal: false, vertical: true)` 和全宽 frame。
- 编辑按钮使用 `pencil`，重新分析使用 `text.magnifyingglass`，重新生成使用 `sparkles` 或现有生成学习材料图标。

### 11.5 本地化

新增或调整 `Localizable.xcstrings`：

- 母语卡标题格式。
- 目标语卡标题格式。
- 母语编辑 sheet 标题。
- 目标语编辑 sheet 标题沿用或改名。
- `基于旧记录`、`待重新分析`、`分析中`、`分析失败` 状态短语。
- 母语编辑按钮 accessibility label。
- 重新生成按钮 accessibility label。

文案必须避免写死 `英文`。测试中应检查不存在仅适用于英语空间的硬编码标题。

### 11.6 文档更新

实施时同步更新：

- `docs/spec/003-ui-design-system.md`：将“右上角悬浮编辑按钮”改为“顶部工具区右侧操作按钮”，补充母语原文可编辑和动态标题规则。
- `docs/spec/learning-content/impl.md`：补充 Entry body 更新能力、原文编辑不自动外发、已有学习材料基于旧记录的 UI 状态。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：补充 Entry body 更新只修改本地 entries 表，不自动修改派生 learning material。
- `docs/platform-page-inventory.md`：记录 iPhone 详情页支持原文编辑和目标文本顶部工具区。

## 12. 复查方法

人工复查重点：

- iPhone 17 模拟器中，长目标语言文本不再被右上角按钮压缩阅读宽度。
- 母语原文卡和目标语言学习文本卡视觉一致，但标题和状态能明确区分 source 与 derived material。
- 切换到非英语目标语言空间后，目标卡标题不显示 `英文表达`。
- 切换到非中文母语空间后，母语卡标题不显示 `中文记录`。
- 编辑母语原文保存后，不出现自动 AI 请求或自动生成状态。
- 已有学习材料时编辑母语原文，目标语言卡能提示它基于旧记录，并提供显式重新生成路径。
- 目标语言学习文本编辑后仍走重新分析，不误触发重新生成。

代码复查重点：

- UI 组件不直接访问数据库或 AI Provider。
- Data 层更新 Entry body 不修改派生 LearningMaterial。
- Store 层明确区分 `sourceEntryIsStale` 与 `analysisIsStale`，不混用 `source_entry_body_hash` 和 `analysis_source_hash` 语义。
- 所有新按钮保持不小于 44pt 触控目标。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

完整验证：

```bash
scripts/verify.sh
```

文档检查：

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

模拟器人工验证：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/LangoTrace-hdfadqhothdwgbahopjjqiwrxhky/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch booted com.zibuyu.LangoTrace
```

## 14. 文档影响检查

本任务涉及 UI 规范、Data Repository 边界、AI 请求触发边界和页面清单，实施时必须执行文档影响检查。

必须确认：

- `docs/spec/003-ui-design-system.md` 不再要求目标文本右上角悬浮按钮。
- `docs/spec/learning-content/impl.md` 描述原文编辑和派生材料 stale/regenerate 关系。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 不把原文编辑误描述为 learning material 编辑。
- `docs/spec/005-ai-provider-prompt-and-privacy.md` 和 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 没有暗示保存原文会自动外发 AI 请求。
- `docs/platform-page-inventory.md` 的 `记录详情` 能力描述与代码一致。

## 15. 实施记录

- 2026-05-23：创建 Draft 方案，等待用户审核。尚未实施代码。
- 2026-05-23：实施 Data / Store / UI 变更。`learning_materials` 增加 `source_entry_body_hash`，`LearningContentRepository` / `GRDBLearningContentRepository` / `GRDBLearningContentRepositoryBridge` / `InMemoryLearningContentRepository` 增加 Entry body 更新能力；`LearningContentStore` 增加 `updateEntryBody` 和 `sourceEntryIsStale`；`EntryDetailView` 改为 `EntryDetailTextCard` 顶部工具区，母语原文和目标语言学习文本共享动态标题和全宽正文，原文可编辑，目标文本可编辑 / 重新分析 / 在旧记录状态下重新生成。
- 2026-05-23：补充并通过聚焦测试：`swift test --package-path Packages/LangoTraceData`、`swift test --package-path Packages/LangoTraceUI`。
- 2026-05-23：通过完整验证 `scripts/verify.sh`。SwiftLint 输出既有 warning 但 0 serious；SwiftFormat lint 显示 0 files require formatting。方案归档至 `docs/plans/done/`。

## 16. 完成标准

本任务只有在以下条件全部满足后，才能从 `active` 移入 `done`：

1. 用户审核本方案并明确允许实施。
2. 母语原文和目标语言学习文本均使用动态标题文本卡片。
3. 目标语言学习文本长文本展示不再因按钮预留右侧空白而变窄。
4. 母语原文可编辑并持久化到本地 repository。
5. 母语原文编辑不自动触发 AI Provider 请求。
6. 已有学习材料时，母语原文编辑后的“基于旧记录 / 重新生成”状态清晰可见且可恢复。
7. 目标语言学习文本编辑和重新分析逻辑保持可用。
8. `sourceEntryIsStale` 基于持久化 source hash 推导，App 重启后仍能正确提示。
9. Data、UI 聚焦测试通过。
10. `scripts/verify.sh` 通过，或记录无法运行的明确原因和剩余风险。
11. 相关 spec 和页面清单完成更新。

## 17. 剩余风险

- 本方案选择持久化 `source_entry_body_hash`，但不保存完整 source 文本快照；因此只能判断“是否基于旧记录”，不能展示旧原文或做 diff。若后续需要历史版本对比，应另立 Entry revision / material source snapshot 方案。
- 母语原文编辑会影响未来同步和冲突处理，但当前同步尚未实现。本任务不设计同步冲突，只保证本地 repository 行为清晰。
- 如果未来 Entry 支持标题、场景、标签和附件编辑，母语编辑 sheet 可能需要升级为完整 Entry 编辑器。本任务只做 body 编辑，避免过早扩大范围。
- 非中文界面下 `{语言名}记录`、`{语言名}表达` 的语序和用词可能需要更完整本地化。本任务先按现有中文界面落地，不能在 Swift 代码中硬编码具体语种。

## 18. 严格方案审核记录

- 2026-05-23：基于代码进行系统架构审核。结论：方案方向正确，但原 Draft 中“source stale 可先放 UI Store”的优先方案不足以支撑数据一致性和重启后的用户提示，因此已调整为持久化 `source_entry_body_hash` 并由 Store 推导 `sourceEntryIsStale`。
- 代码事实确认：`EntryDetailView` 当前确实通过 `ReadOnlyEntryTextPanel` 只读展示 Entry body；`LearningMaterialEditorView` 当前确实使用 `ZStack(alignment: .topTrailing)` 和 `textTrailingPadding` 挤压目标文本宽度；`LearningContentRepository` / `GRDBLearningContentRepository` / `LearningContentStore` 当前均没有 Entry body 更新 API。
- 架构判断：`analysis_source_hash` 只属于 learning text -> sentence analysis 的一致性，不得复用为 Entry source -> learning material 的一致性。两个状态必须分别表达，否则会把“重新分析”和“重新生成”两个用户动作混在一起。
- 实施就绪状态：在用户确认本更新版方案后具备实施条件。实施时必须先补 Data / Store / UI 源码约束测试，再改生产代码。
