# Reading Document CRUD Foundation

状态：Verified
自审核状态：Reviewed
类型：feature
创建日期：2026-06-03
最后更新日期：2026-06-03

## 用户确认记录

- 2026-06-03：用户要求先创建 active plan。
- 2026-06-03：在阅读文档治理任务中，用户进一步要求对“用户导入的阅读材料，无论是粘贴还是导入，都需要有基础增删改查功能”形成后续实现方案。
- 2026-06-03：针对“编辑模式应采用正文原位切换还是独立承载”的剩余疑问，用户要求从系统架构师角度直接选择最优方案并修订方案文档。
- 2026-06-03：本方案据此固定为：iPhone 阅读页右上角提供 `编辑` 图标按钮，进入受控编辑 sheet / editor；不采用正文页内联双模式切换；阅读态删除当前正文上方重复 metadata 信息块，保持首屏简洁。

## 需求描述

当前 Reading vertical slice 已完成导入、列表、搜索、打开、collection / tag 赋值、软删除 / 恢复、显式 AI explanation 和 TTS，但 `ReadingDocument` 仍缺少基础更新路径，尚未形成完整 CRUD。根据 `docs/spec/007-data-storage-migration-export-and-attachments.md` 与 `docs/spec/012-reading-learning-domain.md` 的最新治理规则，`ReadingDocument` 已明确属于用户主数据，因此必须从功能和 UI 上补齐最小可维护生命周期，而不是继续停留在“能导入、能阅读”的半闭环。

本任务需要在不改变 Reading domain 隐私边界、AI 请求边界和导入格式范围的前提下，补齐 ReadingDocument 的基础 CRUD 实现，重点是标题 / 正文编辑路径、现有删除 / 恢复语义的产品化承接，以及三端阅读页面的受控入口与状态反馈。

## 当前现状

- `GRDBReadingLibraryRepository` 已支持粘贴导入、`.txt` / `.md` 文件导入、列表、搜索、collection / tag 赋值、打开、软删除 / 恢复和 AI explanation operation summary，但没有 document update API。
- `ReadingLibraryStore` 和 `ReadingDocumentStore` 目前主要围绕导入、打开、解释和 TTS 设计，缺少“读取草稿 -> 编辑 -> 保存 -> 刷新 presentation”的 document update 状态机。
- `ReadingDocumentStore` 当前并未真正接入 `ReadingDocumentDetailView` 或大屏阅读工作台；`ReadingViews.swift` 仍在 view 层本地维护 `selectedText`、`explanationState`、`audioState` 和 selection generation。若本轮继续叠加编辑能力而不先收口 source of truth，stale selection / explanation / TTS 与编辑草稿会分散在多个状态持有者之间。
- `ReadingDocumentStore` 当前是 `@unchecked Sendable` 的普通引用类型，内部通过 `Task` 回写可变状态，并没有 `@MainActor` 或 actor 隔离；如果直接把编辑草稿、保存状态、解释和 TTS 一起塞进去，会把 stale invalidation 问题升级为结构性并发缺陷。
- `ReadingLibraryStore` 当前只用单一 `generation` 同时保护 `reload()` 与 `openDocument()`；一旦保存路径同时要求“刷新列表标题”和“重载当前 document presentation”，两类请求会互相失效，无法保证保存后的 reader 和 library 一致更新。
- iPhone 已重构为“资料库首页 + 独立阅读详情”，iPad / macOS 已重整为多栏阅读工作台，但三端都没有阅读材料编辑入口。
- `ReadingDocument` 当前是用户主数据，但实现上仍接近 read-mostly 模型。
- Reading schema 已存在结构表与 source anchor 依赖，正文更新不仅影响搜索索引，还会影响 block/source range/source anchor 的可解析性；原方案尚未把这层 repository 级 contract 写清楚。
- `docs/review/rounds/2026-06-03-reading-lifecycle-governance/README.md` 已记录：
  - `READ-LIFE-2`：`ReadingDocument` 缺少导入后默认基础 CRUD 规则落地。
  - `READ-LIFE-4`：页面 / 对象入口需要显式检查生命周期完整性。

## 目标

1. 为 `ReadingDocument` 提供最小但正式的更新路径，至少覆盖标题和正文编辑。
2. 保持现有删除 / 软删除 / 恢复语义，但把其作为正式 CRUD 生命周期的一部分进行一致化设计。
3. 让 iPhone、iPad、macOS 都能在现有阅读页面结构下进入同一套编辑流程，而不新增第二套数据写入路径。
4. 编辑后的文档必须正确更新 `body`、`body_hash`、`content_revision`、`structure_version`、搜索索引和阅读 presentation，且不得污染已有 AI / TTS 边界。
5. 编辑后必须有清晰的 stale / invalidation 处理：旧 selection、旧 explanation、旧 TTS request、旧 source anchor 不得静默绑定到新正文。
6. 阅读详情与工作台中的交互状态必须收敛到一个明确的 source of truth；本轮不得继续让 View 本地状态和 `ReadingDocumentStore` 并存地管理同一 document 的 selection / explanation / audio / editing 生命周期。
7. 进入 CRUD 实现前，必须先收口 `ReadingDocumentStore` 的并发模型，并明确 list/document 两类异步刷新不会互相取消。
8. iPhone 阅读态默认保持“单一阅读心智”：顶部只保留导航标题与右上角编辑按钮，不在正文页内做阅读 / 编辑双模式切换，也不在正文开头重复显示 source format / language metadata 信息块。

## 范围

- Reading repository 的 document update contract。
- `ReadingDocument` 标题 / 正文编辑输入模型与校验。
- `ReadingLibraryStore` / `ReadingDocumentStore` 的编辑状态和保存动作。
- 阅读详情交互状态从 `ReadingViews.swift` 的局部 `@State` 收口到 `ReadingDocumentStore` 或等价的单一 store。
- iPhone 阅读详情、iPad / macOS 阅读工作台中的编辑入口与编辑承载。
- 编辑后对搜索索引、Markdown / plain text presentation、selection stale 和 UI 刷新的处理。
- `ReadingLibraryActions` 与 AppEnvironment 装配中的 update action 注入。
- 阅读结构表、source anchor stale 历史与 lifecycle audit event 的更新策略。
- 对应 Core / Data / UI 测试与页面事实源更新。

## 不做什么

- 不新增 EPUB / PDF / HTML 导入能力。
- 不做批量编辑、多选删除、封面墙、全文统计或阅读位置持久化。
- 不做协同编辑、版本历史、撤销栈或冲突合并。
- 不改变 AI explanation 只发送 selection / limited context 的隐私边界。
- 不在本轮引入词典管理、Memory CRUD 或 PromptPreset CRUD。
- 不采用正文页内联双模式切换，不在阅读态把正文直接改成 `TextEditor`。

## 证据与决策依据

- `docs/spec/007-data-storage-migration-export-and-attachments.md`：用户主数据默认必须具备完整生命周期；如果当前阶段暂不实现某个生命周期环节，必须在 active plan 中显式记录。
- `docs/spec/012-reading-learning-domain.md`：`ReadingDocument` 已明确属于用户主数据，不能继续作为 import-only / read-only 内容处理。
- `docs/spec/004-swiftui-architecture.md`：View 不直接访问数据库；编辑流程必须通过 Store / AppEnvironment / Repository 边界落地。
- `docs/spec/003-ui-design-system.md`：编辑入口应服务阅读对象本身，不能把阅读详情重新做回表单页；错误、保存和空状态不能裸文本堆叠。
- iPhone 交互约束：阅读与编辑是两种不同心智，正文页内联切换会让 selection、解释、TTS、编辑草稿和返回路径纠缠；对当前 Reading 架构来说，受控编辑 sheet / editor 是更低风险且更符合 HIG 的承载。
- `docs/workflows/add-platform-screen.md`：用户主数据页面必须检查生命周期完整性。
- 实际代码事实：`ReadingViews.swift` 当前直接维护 selection / explanation / audio 局部状态，而 `ReadingDocumentStore.swift` 仅是未接入的行为状态容器；任何 CRUD 方案若不先收口这层状态边界，编辑后的 stale invalidation 将无法形成单一真源。
- 来源于 review round 的 finding 映射：
  - `2026-06-03-reading-lifecycle-governance/READ-LIFE-2 -> work item A：ReadingDocument update contract 与 UI 编辑闭环`
  - `2026-06-03-reading-lifecycle-governance/READ-LIFE-4 -> work item B：三端阅读页面入口与生命周期一致性`

## 涉及代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingLibraryRepository.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingLibraryModelTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingLibraryRepositoryTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingLibraryStoreTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`

## 参考的代码与文档路径

- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/012-reading-learning-domain.md`
- `docs/platform-page-inventory.md`
- `docs/plans/done/2026-06-01-feature-reading-ai-tts-vertical-slice.md`
- `docs/plans/done/2026-06-03-refactor-reading-library-ui-redesign.md`
- `docs/plans/done/2026-06-03-refactor-reading-workbench-ipad-mac.md`
- `docs/review/rounds/2026-06-03-reading-lifecycle-governance/README.md`

## 涉及的文档路径

- `docs/platform-page-inventory.md`
- `docs/spec/012-reading-learning-domain.md`
- `docs/plans/done/2026-06-03-feature-reading-document-crud-foundation.md`

## 实施方案

1. 先做并发与状态模型收口，再进入 CRUD：
   - 将 `ReadingDocumentStore` 改为 `@MainActor ObservableObject` 或 actor + MainActor projection，取消当前 `@unchecked Sendable` + 内部 `Task` 直接回写状态的结构。
   - 明确阅读 document 级 source of truth：selection、explanation、audio、editing draft、saving state 由同一 store 承担，`ReadingViews.swift` 不再并行持有同一组局部状态。
   - 将 `ReadingLibraryStore` 的 list reload token 与 current document reload token 拆分，或设计一个原子化 `saveAndRefreshSelection` 路径，避免保存后 library/document 两类刷新互相失效。
2. 再补 Core / Data contract：
   - 为 `ReadingDocument` 增加 update input，明确 title、body、body hash、content revision、structure version 和 source format 保持规则。
   - 第一版应锁定 source format 不随编辑改变；Markdown 仍按 markdown source 编辑，plain text 仍按 plain text source 编辑，避免在 update API 中引入隐式格式转换。
   - Repository 保存时同步重建 search index，并保留 collection / tag / delete state、original import metadata 和 space ownership 不被正文编辑覆盖。
3. 再补 Data repository 行为与迁移兼容：
   - 在 `GRDBReadingLibraryRepository` 增加 update API。
   - 验证编辑不会跨 `space_id` 污染错误文档，也不会重置软删除 / 恢复语义。
   - 明确对 soft-deleted document 的编辑策略；第一版建议禁止编辑已删除文档，要求先恢复再编辑，并在 repository 和 UI 都做一致约束。
   - 更新正文时必须同步处理结构表与 stale 语义：重建 reading structure / sentence / source anchor 相关表或等价结构，并明确旧 anchor 是保留为 stale 历史还是清理；不得只更新主表和搜索索引。
   - 增加 lifecycle `updated` event，形成 CRUD 中 update 的审计证据。
4. 再补 UI store：
   - `ReadingDocumentStore` 管正文编辑草稿、保存状态、保存成功后刷新 presentation。
   - 编辑后失效旧 selection / explanation / TTS request，避免 stale completion 绑定旧内容；必要时 document revision 变化应直接清空当前 selection。
   - `ReadingLibraryStore` 负责资料库层的标题同步与列表刷新；若编辑后当前 document title 变化，列表页和详情页必须保持同一 source of truth，而不是各自局部覆盖。
   - 明确“删除当前文档”的统一行为：phone 关闭 detail 返回 library，pad/mac 清空 reader 选择与 inspector 状态；restore 后是否自动重新选中在本轮固定为不自动重新选中，除非用户再次打开。
5. 最后补三端 UI：
   - iPhone：在 `ReadingDocumentDetailView` 右上角提供 `编辑` 图标按钮；点击后进入受控编辑 sheet / editor，不做正文页内联双模式切换。阅读态删除正文上方重复 metadata 信息块，仅保留导航标题和正文内容。
   - iPad / macOS：在阅读画布标题区提供同一编辑入口；大屏可以使用 sheet / inspector-adjacent editor / 独立 editor panel，但必须复用同一 store / action seam，并保持“阅读态正文优先、编辑态受控承载”的原则。
   - Phone 路由、Pad / Mac 入口和 `LangoTraceRootView` / `AppEnvironment` 装配必须同步接入 update action，不能只在某个平台本地拼接临时保存闭环。
6. 收口文档：
   - 更新 `platform-page-inventory.md`，把 Reading CRUD 从“导入 / 阅读 / 删除恢复”升级为“基础 CRUD 已具备或边界已明确”。
   - 若实现中调整了 Reading spec 的字段或 stale 规则，同任务同步回写 `spec/012`。

## TDD 落点

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingLibraryModelTests.swift`
  - 首个失败测试：`readingDocumentUpdateInputRejectsEmptyBodyAndPreservesSourceFormat`
  - 预期失败原因：`ReadingDocumentUpdateInput` 未定义，或未实现空正文 / source format 约束。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingLibraryRepositoryTests.swift`
  - 先失败测试覆盖：
    - 更新标题与正文后可重新读取。
    - 更新后 search index 同步刷新。
    - 不允许跨 space 更新错误文档。
    - 更新不会丢失 collection / tag / delete state 与 original import metadata。
    - soft-deleted document 无法直接编辑，需先恢复。
    - lifecycle event 新增 `updated`。
    - 结构表 / source anchor stale 处理契约得到执行。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingLibraryStoreTests.swift`
  - 首个失败测试：`saveRefreshesLibraryTitleWithoutDroppingCurrentDocumentSelection`
  - 预期失败原因：library/document 共享 token 导致保存后列表刷新与当前 document 重载互相失效。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`
  - 编辑保存后旧 explanation / TTS / selection completion 被失效或忽略。
  - 首个失败测试还应覆盖：编辑开始后旧 selection state 被受控冻结或清空；保存成功后 revision 变化导致旧 request token 失效。
  - 增补首个失败测试：`savingEditedDocumentInvalidatesInFlightExplanationAndTTS`
  - 预期失败原因：store 仍允许旧 completion 写回新 revision。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
  - 三端编辑入口和承载 intent 的 presentation 语义测试。
  - 增补：删除当前文档后的 route / selection fallback 语义测试。
  - 增补：iPhone 阅读态不再展示重复 metadata block，编辑入口位于右上角 toolbar / navigation action。

首个 red test 建议顺序：

1. `ReadingDocumentStoreAIAndTTSTests/savingEditedDocumentInvalidatesInFlightExplanationAndTTS`
2. `ReadingLibraryModelTests/readingDocumentUpdateInputRejectsEmptyBodyAndPreservesSourceFormat`
3. `GRDBReadingLibraryRepositoryTests/updateEditedDocumentRebuildsSearchIndexAndPreservesMetadata`
4. `ReadingLibraryStoreTests/saveRefreshesLibraryTitleWithoutDroppingCurrentDocumentSelection`

## 复查方法

- 代码复查：确认没有新增第二套 reading document 写入路径，所有编辑都经同一 repository / store seam。
- 结构复查：确认 iPhone、iPad、macOS 都能进入编辑，但不破坏当前阅读 IA。
- UI 复查：确认 iPhone 阅读态正文首屏不再显示重复 metadata block，右上角编辑按钮满足 44pt 触控目标。
- 数据复查：确认编辑后 search index、presentation、content revision 和 stale state 统一更新。
- 隐私复查：确认正文编辑不自动触发 AI explanation 或 TTS 请求。

## 验证命令

聚焦：

```bash
swift test --package-path Packages/LangoTraceUI --filter savingEditedDocumentInvalidatesInFlightExplanationAndTTS
swift test --package-path Packages/LangoTraceCore --filter readingDocumentUpdateInputRejectsEmptyBodyAndPreservesSourceFormat
swift test --package-path Packages/LangoTraceData --filter updateEditedDocumentRebuildsSearchIndexAndPreservesMetadata
swift test --package-path Packages/LangoTraceUI --filter saveRefreshesLibraryTitleWithoutDroppingCurrentDocumentSelection
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
```

完整：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
swift test --package-path Packages/LangoTraceData
scripts/verify.sh
```

## 文档影响检查

- 需要更新 `docs/platform-page-inventory.md` 的 iPhone / iPad / macOS 阅读事实源。
- 若正文编辑改变了 ReadingDocument 的长期字段或 stale 规则，需要同步更新 `docs/spec/012-reading-learning-domain.md`。
- 若实现中明确“已删除文档禁止编辑、需先恢复”的产品语义，应同步回写 `docs/spec/007-data-storage-migration-export-and-attachments.md` 或在 `spec/012` 记录 Reading domain 特化规则。
- 若 iPhone 阅读态删除 metadata block 并新增顶部编辑按钮，需要同步更新页面事实源中的阅读详情结构描述。
- 若本轮引入新的保存 / 校验 guardrail，可在任务方案实施记录中记录 enforcement level；目前预计无需改 ADR 或 release 文档。
- 本任务涉及用户主数据生命周期补齐与三端阅读页面入口，完成后应至少做一次日常文档影响检查；若实现显著改变删除 / 恢复或 search index 语义，再判断是否需要新的专项 review round。

## 严格方案自审核记录

审核日期：2026-06-03
审核方式：主会话自审核
审核轮次：双轮
未使用隔离审查的原因：当前只创建 active plan，不进入代码实现；主会话已在同一上下文中完成 Reading CRUD 架构评估、spec 治理和代码路径核对。
发现摘要：

- P0：`ReadingDocumentStore` 当前不是可安全扩展的并发承载点；在 `@unchecked Sendable` 普通引用类型上继续叠加编辑、解释和 TTS，会把 stale invalidation 变成结构性并发问题。已将“先收口并发模型，再做 CRUD”提升为实施方案第 1 步。
- P1：若只补正文编辑而不更新 stale selection / explanation / TTS 语义，会出现旧 completion 绑定新正文的污染。已写入目标、实施方案和 TDD 落点。
- P1：当前 `ReadingDocumentStore` 并未接入 `ReadingViews.swift`，而视图层自己持有 selection / explanation / audio 状态；若不先收口 source of truth，编辑态和阅读态会出现双重状态持有。已将该问题写入当前现状、目标、范围和实施方案。
- P1：当前 `ReadingLibraryActions` / `AppEnvironment` / `PhoneMainView` / `LangoTraceRootView` 仍没有 update action 注入路径；如果 plan 只改 repository 与 store，会在装配层卡住。已补入涉及文件和实施方案。
- P1：当前 `ReadingLibraryStore` 共享单一 generation token，保存后 library/document 双刷新会互相取消。已要求拆分 token 或设计原子化 refresh 路径。
- P1：repository update contract 原先遗漏结构表 / source anchor stale 处理与 lifecycle `updated` 审计事件。已补入实施方案与测试落点。
- P1：删除当前文档后的 route / selection / inspector / audio fallback 原先未定义。已补入统一行为规则和 presentation 测试要求。
- P1：若只做 iPhone 编辑入口，大屏会再次和 lifecycle 规范脱节。已将三端入口一致性纳入范围。
- P1：如果把 CRUD 扩大到批量管理、版本历史、撤销栈，会导致 scope 失控。已在“不做什么”中剔除。
- P2：source format 是否允许在编辑时变化、soft-deleted document 是否允许直接编辑、original import metadata 是否保留，原方案未明确。已在实施方案和 TDD 落点补充第一版约束。

写回修改：

- 把任务收敛为“ReadingDocument 基础 CRUD”而不是“阅读库全部管理能力”。
- 明确 source-of-truth 在 `ReadingDocument` 和 `GRDBReadingLibraryRepository`，而不是 view-local draft。
- 将 review finding id 显式映射到 work item。

仍需用户确认的问题：

- 无。该疑问已由本轮方案修订固定为“右上角编辑按钮 + 受控编辑 sheet / editor”，不采用正文页内联切换。

是否允许进入实现：允许。交互承载方向已固定，方案已可进入生产实现。

## 实施记录

- 2026-06-03：创建本 active plan，基于 Reading lifecycle governance 和现有 reading vertical slice / UI 重构事实，定义 ReadingDocument 基础 CRUD 的范围、TDD 落点与文档影响检查。
- 2026-06-03：根据系统架构与 iPhone 交互边界复审，固定编辑承载方案为“右上角编辑按钮 + 受控编辑 sheet / editor”，并同步删除 iPhone 阅读态正文上方重复 metadata block 的设计要求。
- 2026-06-03：在 `LangoTraceCore` 中新增 `ReadingDocumentUpdateInput` 与 `ReadingDocumentUpdateError`，落实空正文校验、标题规范化和 source format 保持规则，并新增 `ReadingDocumentLifecycleEventType.updated`。
- 2026-06-03：在 `GRDBReadingLibraryRepository` 中实现 document update contract，补齐 soft-deleted document 禁止直接编辑、search index 重建、reading structure / sentence / source anchor 重建和 lifecycle `updated` 审计事件；同步更新 `AppDatabaseReadingMigration` 的 lifecycle event 约束。
- 2026-06-03：在 `ReadingLibraryActions`、`AppEnvironment`、`ReadingLibraryStore` 与 `ReadingDocumentStore` 中接入统一 update seam，拆分 library/document 刷新 token，将阅读详情 selection / explanation / TTS / editing 状态收口到 `@MainActor` 的 `ReadingDocumentStore`。
- 2026-06-03：更新 `ReadingViews.swift`、`ReadingPresentationModels.swift` 与相关组件，为 iPhone / iPad / macOS 阅读页面提供统一的受控编辑入口；iPhone 阅读详情新增右上角编辑按钮，阅读态删除正文上方重复 metadata block。
- 2026-06-03：更新 `docs/platform-page-inventory.md` 与 `docs/spec/012-reading-learning-domain.md`，同步页面事实源、Reading CRUD 规则和 revision / stale invalidation 行为。
- 2026-06-03：补充“删除当前已选中文档时清空 reader / inspector 状态，恢复后不自动重新选中”的资料库行为，并通过对应 UI store 测试。
- 2026-06-03：补充并通过 Core / Data / UI 测试，清理 `swiftformat` / `swiftlint` 阻塞项，完成 `scripts/verify.sh`、iPhone / iPad / macOS 构建与 macOS App 测试验证。

## 完成标准

- `ReadingDocument` 具备最小基础 CRUD：导入 / 创建、列表 / 搜索 / 打开、标题 / 正文更新、删除 / 恢复。
- 编辑路径在三端阅读页面中可达，并复用同一 store / repository seam。
- 更新后 search index、presentation、content revision 和 stale state 正确刷新。
- 旧 selection / explanation / TTS completion 不会污染新正文状态。
- 受影响的 Core / Data / UI 测试通过。
- 页面事实源与实现一致。

## 验证结果

- 2026-06-03：`swift test --package-path Packages/LangoTraceCore`
- 2026-06-03：`swift test --package-path Packages/LangoTraceData`
- 2026-06-03：`swift test --package-path Packages/LangoTraceUI`
- 2026-06-03：`swift test --package-path Packages/LangoTraceData --filter GRDBReadingLibraryRepository`
- 2026-06-03：`python3 -m unittest discover -s Tests/Tooling -p 'test_*.py'`
- 2026-06-03：`scripts/verify.sh`
- 2026-06-03：`swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache ignore`
- 2026-06-03：`swiftlint --no-cache`
- 2026-06-03：`git diff --check`
- 2026-06-03：`xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
- 2026-06-03：`xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`
- 2026-06-03：`xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`
- 2026-06-03：`xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests`

## 剩余风险

- 直接编辑 Markdown 正文会涉及 block / source range 重建，第一版可能只能提供纯文本 / markdown source 级编辑，而不是结构化块内所见即所得编辑。
- 批量编辑、版本历史、撤销和跨设备冲突不在本轮范围内，后续若继续增强 Reading lifecycle，需要新的 active plan。
