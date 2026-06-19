# 任务方案：照片写作记录详情不展示图片

状态：Implemented
自审核状态：Reviewed
类型：bug
创建日期：2026-06-17
最后更新日期：2026-06-17

## 用户确认记录

2026-06-17：用户指出照片写作创建后的记录详情页没有展示具体图片，要求先补充 active plan 并完成方案自审；解决完此问题后再继续推进主任务开发。

2026-06-17：用户确认“立即根据自审、修订后的方案开始实施”。实施范围接受“导入失败不得创建可见 photoWriting 记录”为标准，并允许在 UI package 新增 `PhotoWritingSaveCoordinator` / `EntryDetailPhotoState` 等小型 presentation 类型。

## 1. 需求或 bug 描述

用户通过 iPhone 照片写作入口创建“图片记录测试”后进入记录详情，页面只展示原文、目标语言待生成状态和“生成学习材料”入口，没有展示刚选择的照片。

按 E2 照片附件主数据与照片引导写作任务的完成标准，照片写作记录保存后应形成“文本 Entry + 照片附件 + 详情页照片展示”的闭环。详情页没有照片会让照片记录退化为普通文本记录，并削弱用户对照片是否已本地保存、是否会进入 AI 请求的理解。

## 2. 现状描述

- `docs/plans/done/2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md` §18 / §19 已将“保存后详情可见原图”列为 E2 实施记录和手动验收项。
- `docs/platform-page-inventory.md` 的“记录详情”条目写明：`photoWriting` 类型记录在原文卡片上方异步展示全宽 4:3 比例照片，照片不发送 AI Provider。
- `docs/spec/learning-content/impl.md` 写明：`EntryDetailView` 在原文卡片上方展示全宽 4:3 照片，两处展示通过 `PhotoDisplayActions` 异步加载。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift` 中 `EntryDetailView` 已存在 `photoImage` 展示逻辑；`.task(id: entry.id)` 只在 `entry.source == .photoWriting` 时调用 `photoDisplayActions.loadPhotoData(entry.id)`，如果返回 `nil` 则静默不展示任何照片区域。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift` 的照片写作保存路径先调用 `contentStore.createEntry(... source: .photoWriting)`，再用 `try? photoWritingActions.importPhoto(...)` 导入照片。照片导入失败会被吞掉，entry 仍创建、sheet 仍关闭、导航仍进入详情。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingActions.swift` 当前注释明确写着 import throwing “non-fatal”，这与 E2 之后的产品闭环不一致。
- `LangoTraceApp/AppEnvironment.swift` 中 `PhotoWritingActions` 调用 `PhotoImportPipeline.importPhoto(...)`；`PhotoDisplayActions` 通过 `GRDBEntryPhotoAttachmentRepository.photoRelativePath(forEntryID:)` 找附件路径并读文件，任一环节失败返回 `nil`。
- 当前 UI 测试 `PhotoWritingSaveFlowTests` 只覆盖草稿芯片和保存按钮 enablement，没有覆盖“导入失败不得创建无图 photoWriting 记录”或“详情照片缺失时必须有可见降级态”。

## 3. 目标

1. 照片写作保存闭环不得静默创建无附件的 `photoWriting` entry：照片导入失败时保留在照片写作页并显示用户可理解的错误，不跳转到详情。
2. 成功保存后，详情页应能展示本地保存的照片；加载中、加载失败和历史无附件 `photoWriting` 记录都应有明确可见状态，不再静默消失。
3. `PhotoWritingActions` 的契约从“导入失败非致命”修正为“保存闭环必要步骤”；实现仍保持照片字节本地处理，不发送 AI Provider。
4. 增加单元测试覆盖保存失败、详情照片 presentation 状态和导入契约，避免后续回归。
5. 相关事实源文档更新，避免 E2 done plan 与当前实现风险脱节。

## 4. 范围

- UI package：
  - 调整 `PhotoWritingActions` 契约文档和必要 API。
  - 在 `PhotoWritingView` 或保存 orchestration 中加入保存中 / 失败状态。
  - 调整 iPhone 照片写作保存路径，避免 `try?` 吞掉导入失败。
  - 为 `EntryDetailView` 增加照片加载 presentation 状态和失败 / 缺失降级 UI。
  - 新增或更新本地化 key。
- App target：
  - 保持 `AppEnvironment` 的 `PhotoImportPipeline` 装配，并按新契约传递错误。
- Tests：
  - 扩展 `PhotoWritingSaveFlowTests`。
  - 新增 `EntryDetailPhotoPresentationTests` 或同等 UI presentation 测试。
  - 必要时增加 source-string 守卫，临时防止照片导入路径继续使用 `try?`；若能用行为 seam 覆盖，则不新增源码断言。
- Docs：
  - 更新 `docs/spec/learning-content/impl.md`、`docs/platform-page-inventory.md` 或 E2 done plan 变更记录中关于降级态 / 保存原子性的事实。

## 5. 不做什么

- 不实现 OCR、照片 AI 分析、图片理解请求、相机拍照、多张照片、照片编辑、照片删除或重新绑定照片。
- 不改变“照片字节不发送 AI Provider”的隐私边界。
- 不新增数据库 migration；现有 `entry_photo_attachments` 与 `media_artifacts` schema 足以承载本修复。
- 不做跨端大屏视觉重设计；iPad / macOS 仅继承共享 `EntryDetailView` 的可见降级态。
- 不处理已进入 git 历史的密钥清理或 probe workflow 变更；这些属于当前工作区已有未提交文档变更，和本 bug 修复分开提交。

## 6. 证据与决策依据

- 用户证据：iPhone 模拟器截图显示照片写作记录详情无照片区域。
- 产品证据：`docs/product-main-reference.md` §9.7 将照片引导写作定位为写作启动器；照片故事属于用户生活记录和长期记忆对象。
- 页面事实源：`docs/platform-page-inventory.md` “照片写作”“记录详情”“最近记录列表”条目均记录照片附件、缩略图和详情展示为 Implemented。
- 实现证据：
  - `PhoneMainView.swift` 使用 `try? photoWritingActions.importPhoto(...)`，导入失败后仍导航到详情。
  - `EntryDetailView` 在 `loadPhotoData` 返回 `nil` 时没有可见占位或错误态。
  - `PhotoWritingActions.swift` 注释把 import 失败定义为非致命，与当前产品闭环冲突。
  - `AppEnvironment.swift` 的 `PhotoDisplayActions` 任一失败都返回 `nil`，调用方无法区分无附件、文件缺失和解码失败。
- 工作流：本任务是平台页面行为修复，需按 `docs/workflows/add-platform-screen.md` 的页面事实源和三端共享 seam 思路执行；不涉及 `add-storage-migration.md`。

```text
证据能证明什么：当前产品 / 文档 / 实现目标都要求照片详情可见；现有代码存在静默无图记录路径。
证据不能证明什么：截图本身不能证明失败发生在导入、读取、解码、附件查询还是 UI 生命周期；实施前仍需用测试复现最小断点。
迁移前提：无需 schema 迁移；修复应在 UI orchestration、action contract 和 presentation 状态完成。
照搬风险：不能把“历史 mock photoWriting 记录可能无附件”的兼容需求误当成新建记录也可无附件；新建照片写作必须要求附件保存成功。
```

是否需要 spike / probe / fixture / evidence：不需要单独 spike；用单元测试和模拟 action failure 即可复现保存失败路径。不得使用真实用户照片作为 fixture；测试使用小型内存 Data 或 fake action。

## 7. 约束映射与验证路径

### 约束 1：实现前 active plan + 自审核 + 用户确认

- 约束 ID：DOC-CONST-001 / DOC-CONST-002 / DOC-CONST-003
- 来源：`docs/README.md` §1、§4.16；`docs/plans/README.md` §4 / §5；`docs/plans/plan-review-protocol.md`
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查状态字段
- 验证提示：`状态：Draft` 时不得改生产代码；用户确认后推进 `User Approved`
- 说明：本任务是 bug 修复和平台页面行为变化，必须先建 active plan 并自审核。

### 约束 2：照片本地优先与 AI 请求边界

- 来源：`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/platform-page-inventory.md`
- 适用范围：照片附件、AI Provider、隐私
- 严重度：blocker
- 执行或验证方式：代码审查 + UI 文案审查 + 现有 AI 生成路径测试
- 验证提示：修复不能把照片 Data、路径、OCR 或摘要传入 `LearningMaterialGenerationActions`
- 说明：展示照片是本地 UI 行为，不等于图片理解或照片上送。

### 约束 3：照片写作保存语义

- 来源：`docs/plans/done/2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md` §12 / §18 / §19、`docs/spec/learning-content/impl.md`
- 适用范围：照片写作入口、记录详情
- 严重度：blocker
- 执行或验证方式：UI package 单元测试 + 人工模拟器复核
- 验证提示：新建照片写作必须同时有非空文本和成功附件；详情显示照片或明确缺失态
- 说明：done plan 不是新约束来源，但记录了 E2 用户确认和 shipped 事实，本 bug 修复需要恢复该闭环。

### 约束 4：测试靠近模块且轻量验证

- 来源：`docs/README.md` §1.4、`docs/spec/009-testing-and-verification.md`
- 适用范围：测试
- 严重度：blocker
- 执行或验证方式：`swift test --package-path Packages/LangoTraceUI --filter ...`
- 验证提示：优先 UI package presentation / action seam 测试，不运行本机全量 `scripts/verify.sh`
- 说明：本机只跑轻量单包测试；全量验证留给 CI 或用户明确要求。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoDisplayActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/PhotoWritingSaveFlowTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/EntryDetailPhotoPresentationTests.swift`（新建）

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/PhotoImportPipeline.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBEntryPhotoAttachmentRepository.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/PhotoImportPipelineTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/PhotoAttachmentRepositoryTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/EntryCreationFailureSurfaceTests.swift`

## 10. 涉及的文档路径

- 本方案。
- `docs/spec/learning-content/impl.md`：补充照片详情降级态和保存原子性事实。
- `docs/platform-page-inventory.md`：记录照片详情加载失败时的可见状态。
- `docs/plans/active/2026-06-11-00-docs-series-progress.md`：可选，在完成本 bug 后登记“E2 follow-up fixed”并恢复 E3 指针。
- `docs/plans/done/2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md`：历史 done plan 默认不改；如需要只追加变更记录，不重写历史实施记录。

## 11. bug 分析

```text
复现方式：
1. iPhone 模拟器进入记录 Tab。
2. 点击“用照片开始”，选择一张照片，输入非空中文记录。
3. 点击保存，进入记录详情。
4. 观察详情顶部原文卡片上方是否显示所选照片。

预期行为：
新建照片写作保存成功后，记录详情在原文卡片上方展示所选照片；若照片加载失败，展示明确的照片缺失 / 加载失败状态，不静默消失。

实际行为：
截图中详情页没有照片区域，只显示文本记录和学习材料生成入口。

根因分析：
高置信根因是保存路径和展示路径均允许静默失败。`PhoneMainView.swift` 先创建 `photoWriting` entry，再用 `try? photoWritingActions.importPhoto(...)` 导入照片；导入失败不会阻止导航。`EntryDetailView` 的 `loadPhotoData` 返回 `nil` 时没有任何可见降级态。两者组合会产生“无图 photoWriting 详情”。

置信度：85%

置信度依据：
代码中存在明确的 `try?` 吞错路径，且 `PhotoWritingActions` 注释当前也声明 import failure non-fatal；详情页对 `nil` 没有 UI 分支。文档和 E2 DoD 均要求详情展示照片。尚未通过运行时日志确认用户截图中具体失败点，所以不是 100%。

备选原因：
1. `PhotoImportPipeline` 成功写入附件，但 `PhotoDisplayActions` 查到相对路径后文件读取失败。
2. 附件写入成功，但图片 Data 解码为 `UIImage` / `NSImage` 失败。
3. entry source 不是 `.photoWriting`，导致详情加载 guard 直接返回。
4. `photoDisplayActions` environment 没有注入到当前 root 或预览 / 测试环境使用 `.disabled`。

回归测试方案：
1. 行为测试覆盖保存失败不得关闭 sheet / 导航 / 创建无图详情路径。
2. presentation 测试覆盖 `photoWriting` 详情的 loading / loaded / missing / failed 状态。
3. 源码或行为 seam 测试确认照片导入错误不再被 `try?` 静默吞掉。
```

## 12. 实施方案

1. Phase 1：TDD 复现保存闭环缺口。
   - 在 `PhotoWritingSaveFlowTests` 增加保存 orchestration 的纯函数 / coordinator 测试：当 `importPhoto` 抛错时，结果应为 failure，且不得发出 entry detail navigation。
   - 若当前保存逻辑嵌在 `PhoneMainView` closure 中难以测试，先抽出 `PhotoWritingSaveCoordinator` 或 `PhotoWritingSaveOutcome` 到 UI package，专门承载“创建 entry → 导入照片 → 成功后导航”的同步流程。
   - 先失败用例应证明当前 `try?` 路径会把导入失败当成功。
2. Phase 2：修正保存契约和 UI 错误态。
   - 更新 `PhotoWritingActions` 注释：导入照片是照片写作保存闭环的必要步骤，throw 必须向 UI 暴露。
   - `PhotoWritingView` 增加 `isSaving` 和 `saveError` presentation 状态；保存中禁用按钮，失败时保留 sheet 和用户草稿，显示短错误文案。
   - `PhoneMainView` 不再使用 `try?`；只有 `contentStore.createEntry` 与 `photoWritingActions.importPhoto` 都成功后才关闭 sheet 并导航。
   - 如果创建 entry 成功但导入失败，第一版不做数据库回滚时，必须避免留下用户可见的 `photoWriting` 无图记录；更长期正确方案是新增单一 app-level action 在同一业务边界内完成创建 + 导入。实现时优先选择不产生孤儿 entry 的路径；若受现有 repository 限制无法原子回滚，需在实施记录中写明降级策略并补测试。
3. Phase 3：详情照片 presentation 状态。
   - 引入 `EntryDetailPhotoState` 或等价类型：`notApplicable / loading / loaded(Image) / unavailable / failed`。
   - 对 `photoWriting` entry 初始显示 loading 或固定占位区域，加载失败显示可见错误态，例如“照片未能加载”；历史无附件记录显示“这条旧照片记录没有可用图片”。
   - loaded 状态继续使用全宽 4:3 照片；失败态不得暗示照片会发送 AI Provider。
4. Phase 4：文档和验证收口。
   - 更新 `docs/spec/learning-content/impl.md` 和 `docs/platform-page-inventory.md`。
   - 运行 UI package 聚焦测试和轻量整包测试。
   - 做一次 iPhone 模拟器人工复核：保存成功后详情显示照片；模拟导入失败时不跳转或显示错误。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-17
审核方式：主会话自审核
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：当前任务由主会话直接补 active plan，未启用独立审查会话；已按 plan-review-protocol 双轮维度用代码和权威文档核验证据。
发现摘要：
  第一轮：
  - [P0] 初始判断只说“详情页应显示照片”，但未区分新建记录保存失败与历史 photoWriting 无附件兼容。已修订目标：新建照片写作不得静默创建无附件记录；历史无附件记录显示明确降级态。
  - [P1] 若只修 `try?`，仍可能出现文件读取 / 解码失败后详情静默无图。已新增 EntryDetail photo presentation 状态和失败 / 缺失 UI。
  - [P1] “创建 entry 后导入照片”不是严格原子，导入失败可能留下孤儿 photoWriting entry。已在实施方案中要求优先抽出 app-level save coordinator，并记录无法回滚时的降级策略和测试。
  - [P2] 原方案容易把照片展示修复和图片 AI 分析混在一起。已在不做什么和隐私约束中明确排除 OCR / 图片理解 / 照片上送。
  第二轮：
  - [P1] TDD 落点最初不够具体，难以先失败。已补 `PhotoWritingSaveFlowTests` 的导入失败用例和 `EntryDetailPhotoPresentationTests` 的状态用例。
  - [P2] 验证命令不能跑本机全量 `scripts/verify.sh`。已按仓库规则限定为 UI 包聚焦测试、UI 包轻量测试、文档检查和 `git diff --check`。
  - [P2] 文档影响不能重写 done plan 历史事实。已改为更新当前事实源，done plan 只在必要时追加变更记录。
写回修改：已写回第 3、5、7、11、12、15、16、17、19、20 节。
仍需用户确认的问题：是否接受将“导入失败不得创建可见 photoWriting 记录”作为本 bug 的实现标准；是否允许在 UI package 新增 `PhotoWritingSaveCoordinator` / `EntryDetailPhotoState` 等小型 presentation 类型。
是否允许进入实现：是。用户已确认进入实施，状态推进到 User Approved。
```

## 14. 复查方法

1. 代码复查：`PhoneMainView.swift` 不再包含 `try? photoWritingActions.importPhoto`；照片写作保存成功路径必须等待导入成功后才导航。
2. 契约复查：`PhotoWritingActions.swift` 注释不再把 import failure 定义为 non-fatal。
3. 详情复查：`EntryDetailView` 对 `photoWriting` entry 至少有 loaded 和 unavailable / failed 可见分支。
4. 数据复查：不新增 migration；`entry_photo_attachments` 和 `media_artifacts` 仍是照片附件事实源。
5. 隐私复查：`LearningMaterialGenerationActions` 请求路径仍只发送文本，不发送照片 Data 或路径。
6. 人工复查：iPhone 模拟器保存照片记录后，详情首屏能看到照片；注入失败 action 时，sheet 不关闭或显示保存失败提示。

## 15. TDD / 测试落点

```text
测试落点：
  1. Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/PhotoWritingSaveFlowTests.swift
  2. Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/EntryDetailPhotoPresentationTests.swift（新建）
  3. Packages/LangoTraceUI/Tests/LangoTraceUITests/EntryCreationFailureSurfaceTests.swift（必要时扩展，确保不再有 try? importPhoto）

先失败用例：
  photoWritingSaveDoesNotSucceedWhenPhotoImportFails
  —— fake createEntry 返回 entry，fake importPhoto 抛错，断言保存 outcome 为 failure 且不产生 navigation target。当前保存逻辑会吞掉 import 错误并继续导航，测试应先失败。

  photoWritingDetailShowsUnavailableStateWhenPhotoDataIsMissing
  —— photoWriting entry 的 photo loader 返回 nil，断言 presentation 输出 missing / unavailable 状态，而不是 nil view。当前 EntryDetailView 只有 photoImage 可选态，测试应先失败或无法表达该状态。

聚焦验证命令：
  swift test --package-path Packages/LangoTraceUI --filter PhotoWritingSaveFlowTests
  swift test --package-path Packages/LangoTraceUI --filter EntryDetailPhotoPresentationTests

不新增单元测试的原因（如适用）：不适用。本任务是行为修复，必须新增 / 更新单元测试。
```

## 16. 验证命令

```bash
# 聚焦红绿验证
swift test --package-path Packages/LangoTraceUI --filter PhotoWritingSaveFlowTests
swift test --package-path Packages/LangoTraceUI --filter EntryDetailPhotoPresentationTests

# 受影响 package 轻量验证
swift test --package-path Packages/LangoTraceUI

# 文档与 diff
scripts/check-docs.sh
git diff --check
git status --short
```

本任务不主动运行 `scripts/verify.sh`；除非用户明确要求或后续改动扩大到跨 package 重构，否则本机不跑全量验证。

## 17. 文档影响检查

- `docs/spec/learning-content/impl.md`：需要更新，补充保存原子性和详情照片降级态。
- `docs/platform-page-inventory.md`：需要更新，记录照片详情加载失败 / 历史无附件记录的可见状态。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：预计不需要更新；照片仍不发送 AI Provider。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：预计不需要更新；无 schema 或存储策略变化。
- `docs/review/`：本任务是 E2 follow-up bug，不触发数据库 schema 专项审查；完成后做日常文档影响检查即可。
- `docs/plans/active/2026-06-11-00-docs-series-progress.md`：完成后可登记 E2 follow-up 已修复，再恢复 E3 指针。

## 18. 实施记录

2026-06-17：创建 active bug plan，并完成双轮主会话自审核。

2026-06-17：完成实现。新增 `PhotoWritingSaveCoordinator`，照片写作保存改为“创建 Entry → 导入照片 → 成功后导航”；照片导入失败会回滚已创建 Entry、保留 sheet 并显示保存失败文案，不再产生可见无图 `photoWriting` 记录。新增 `EntryDetailPhotoPresentation`，`EntryDetailView` 对照片记录展示加载中 / 缺失 / 解码失败的可见照片区域，成功时继续展示全宽 4:3 图片。`PhotoWritingActions` 契约已改为导入失败对保存闭环是致命错误；`LearningContentRepository` / `LearningContentStore` 暴露 `deleteEntry` 用于保存失败回滚。

2026-06-17：文档已同步 `docs/spec/learning-content/impl.md` 与 `docs/platform-page-inventory.md`。未做模拟器人工复核；本轮用 UI/Data 单元测试覆盖保存失败、回滚、详情照片状态和源码守卫。人工 iPhone 成功保存后详情照片可见仍建议在下次模拟器验收中补一遍。

## 19. 完成标准

1. 照片写作保存路径不再静默吞掉照片导入失败。
2. 新建照片写作记录只有在文本 entry 和照片附件保存都成功后才关闭 sheet 并进入详情。
3. 详情页对照片加载成功展示全宽照片；对历史缺失 / 文件缺失 / 解码失败展示明确可见状态。
4. UI package 聚焦测试和轻量整包测试通过。
5. `docs/spec/learning-content/impl.md` 与 `docs/platform-page-inventory.md` 已同步当前事实。
6. 人工模拟器复核截图或文字记录写入实施记录。

plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：是；代码、测试、当前事实源文档和验证命令均已完成
scope-down 是否已记录：是；未做数据清理、补图、多图、OCR、AI 图片理解和模拟器人工复核
deferred / aborted 项是否已从完成叙事中剥离：是；人工 iPhone 复核作为剩余风险记录，不写入已验证结论
后续事实源或复审入口：本方案实施记录、learning-content impl、platform-page-inventory
```

## 20. 剩余风险

1. 现有数据库里可能已经存在无附件的 `photoWriting` 记录；本任务只要求可见降级态，不做数据清理或补图流程。
2. 当前回滚采用创建 Entry 后导入失败时 soft delete Entry，不是单一数据库事务包住文件导入和元数据提交；对用户可见层面已避免孤儿记录，但文件系统 staging / 清理仍依赖 `PhotoImportPipeline` 既有失败清理。
3. 详情页加载失败原因第一版可能只显示通用错误，不细分“附件元数据缺失 / 文件缺失 / 解码失败”；细分诊断可后续补。
4. iPad / macOS 继承共享详情状态，但本方案的人工验证优先 iPhone；大屏视觉细节仍按 E2 剩余风险后续验收。
