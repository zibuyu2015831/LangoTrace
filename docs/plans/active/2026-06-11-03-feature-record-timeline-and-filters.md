# 任务方案：记录 Tab 生活时间线与三端共享筛选投影（系列 E1）

状态：User Approved
自审核状态：Reviewed
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-17

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）。该授权仅覆盖"系列方案文档的制定"，不覆盖本方案的实现。

**2026-06-17 用户确认（进入 User Approved 状态）：**

- Q1 文案统一：三端统一采用「**已沉淀**」，iPad 原型的「已记忆」不再使用。String Catalog key 从 `pad.filter.memorized` 重命名为 `filter.settled`，避免 `memorized` 语义污染后续 E7 能力。
- Q2 零态过渡：采用 **Option B**——`EntryTimelineFilter.settled` 完整实现（判定函数、计数、单元测试），但 chip UI 渲染处 guard 过滤，E7 落地时移除该 guard 即可暴露。不展示长期空态 chip。
- Q3 pill 更新范围：`PhoneMainSupportingViews.swift`（phone EntryCard）**纳入** E1 Phase 3；`MacInspectorContent.swift` **排除**（检视器的 practiceStatus 字段语义是练习历史，与材料状态不同，待 entry(from:) JOIN practice_sessions 后自然修正）；Phase 2 按架构简化——pill 三态改为 UI 层纯函数，Data 层只查 `hasCompletedRecording`。

## 1. 需求或 bug 描述

新版三端原型把记录 Tab 从扁平"最近记录列表"演进为按日分组的生活时间线，并加入轻量筛选：

- `prototypes/iphone/record.html`：保留 Hero 双入口（写一句 / 用照片开始），列表按"今天 / 昨天 / 具体日期"分组；筛选 chips 为 `全部 / 照片 / 待练习 / 已沉淀`；卡片状态 pill 为 `学习材料 · n 句`、`未生成`、`基于旧记录` 三种语义；照片卡片带 44×44 缩略图位。
- `prototypes/ipad/workspace.html`：同一组筛选 chips（原型此处写作 `已记忆`，与 iPhone 的 `已沉淀` 不一致，需统一），时间线侧栏按日分组。
- `prototypes/mac/workspace.html`：sidebar 含 `今日`、`全部记录` 两个带计数的入口，计数必须来自与 iPhone / iPad 同一套投影。

当前实现是扁平列表 + iPad 端的 mock 推导筛选，需要演进为三端共享的真实数据投影。

## 2. 现状描述

按 HEAD `0f0da44`（E0b 全部完成后）核验：

1. iPhone 记录列表：`PhoneRecordWorkspaceView`（`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift:5-44`）以 `LazyVStack` 平铺 `contentStore.entries`，无日期分组、无筛选。
2. iPad 筛选：`PadFilter`（`PadMainModels.swift:4-35`）已有 `all / photoWriting / needsPractice / memorized` 四 case 与 String Catalog key；但 `needsPractice` / `memorized` 的判定是 `memoryItems.contains { $0.entryID == entry.id }` 的反 / 正命中——memory item 当前来自 seed / mock 主路径，`docs/platform-page-inventory.md` 将该筛选标记为 Local Mock，`docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md` §2.1 明确要求"待练习 / 已沉淀"的判定需要真实数据投影、不得复用 mock 推导。
3. 数据层：`LearningContentRepository`（`Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift:4-22`）提供 `entries(for:)`（按 `created_at DESC`，`GRDBLearningContentRepository.swift:70`）、`practiceItems(for:)`、`memoryItems(for:)` 等；无日期分组查询、无筛选投影、无计数查询。`LearningEntry`（`LearningContentModels.swift:4-37`）有 `createdAt`、`source`（含 `photoWriting` case）。learning material、practice session（`completed_recording_id` 列，`AppDatabase.swift:680`）与 practice recording 元数据均已在 GRDB 中，足以推导"有学习材料但无完成录音"的待练习语义，无需新表。
4. 卡片状态 pill：当前渲染 `entry.practiceStatus.displayLabel`（E0b Phase 4 已将 `practiceSummary: String` 替换为结构化 `EntryPracticeStatus` enum，`LearningContentModels.swift:4-7`）。但 `GRDBLearningContentRepository.entry(from:)` 未 JOIN `practice_sessions`，因此所有 GRDB 加载的真实 entry 的 `practiceStatus` 永远是默认值 `.notStarted`——三端卡片实际上全部显示「待练习」占位文案，与真实状态无关。材料状态（生成 / 未生成 / 过期）存储在 `LearningRendering` 的 `sourceEntryBodyHash` 字段（E0b 完成，现已可靠可用）。
5. Mac sidebar：`MacMainView` 已展示 `今日 / 全部记录 / 记忆` 计数（`docs/platform-page-inventory.md` Mac sidebar 条目），但计数推导未与 iPhone / iPad 共享投影函数。
6. 照片：照片附件主数据尚不存在（E2 范围）；当前唯一"照片"信号是 `entry.source == .photoWriting`。

## 3. 目标

1. iPhone 记录 Tab 列表演进为按日分组时间线：`今天` / `昨天` / 本地化日期 section header，使用系统日期格式化（spec 006 §4 禁止手写固定格式）。
2. 三端共享同一个筛选枚举与判定函数：`全部 / 照片 / 待练习 / 已沉淀`，iPhone chips、iPad chips、Mac sidebar 计数全部消费同一投影。
3. 筛选判定来自真实数据投影：
   - 照片：`entry.source == .photoWriting`（E2 落地真实附件后升级为"存在照片附件"，本方案预留判定函数的输入扩展位）。
   - 待练习：存在学习材料且无已完成练习录音（material-without-ready-recording），由 GRDB 现有表推导。
   - 已沉淀：在真实记忆沉淀能力（系列 E7）落地前，`EntryTimelineFilter.settled` 完整实现（判定、计数、测试），但 chip 不向用户渲染（E7 落地时移除 guard）。
4. 卡片状态 pill 呈现 `学习材料 · n 句` / `未生成` / `基于旧记录` 三种语义（从 `(entry.body, rendering: LearningRendering?)` 在 UI 层纯函数推导，文案走 String Catalog）。
5. Mac sidebar `今日` / `全部记录` 计数来自同一投影函数。
6. `PadFilter` 的 mock 推导被共享真实投影替换。

## 4. 范围

- UI：`PhoneMainSections.swift`（PhoneRecordWorkspaceView 时间线化）、`PadMainSections.swift` / `PadMainModels.swift`（筛选替换）、`MacMainView.swift` / `MacMainModels.swift`（计数接线）、`LearningContentComponents.swift`（状态 pill）、新增共享投影与筛选类型文件。
- Data：`LearningContent.swift` / `GRDBLearningContentRepository.swift` 新增只读投影查询（`learningPracticeReadiness`：per-entry 是否有已完成录音），不新增表、不新增 migration。材料句数与新鲜度从 `LearningRendering` 在 UI 层推导，不经 Data 层查询。
- 本地化：String Catalog 新增筛选标签、section header、零态与 pill 文案 key。
- 文档：`docs/platform-page-inventory.md`、`docs/spec/learning-content/impl.md`、architecture note §2.1 的采纳记录。

前序依赖：E0a（错误分类与 Data 尾项收口，避免在旧契约上加投影）、E0b（PhoneMainView per-tab 导航重构与 `practiceStatus` 结构化先落地——本方案的时间线挂在重构后的记录 Tab 栈内，状态 pill 建立在结构化字段上）。规模：M。

## 5. 不做什么

- 不实现照片附件主数据、缩略图与真实照片筛选判定（E2；本方案照片筛选仅按 `source == .photoWriting`，并在判定函数中留好输入扩展位）。
- 不实现记忆沉淀的真实判定与"已沉淀"非零结果（系列 E7 记忆方案；本方案实现 `settled` 完整类型系统和计数逻辑，但 UI chip 渲染处 guard 过滤，E7 落地时移除 guard）。
- 不做周分组、自定义分组粒度切换（architecture note §2.1 留作后续决策，本方案固定按日分组）。
- 不做跨语言空间时间线（时间线限定当前语言空间）。
- 不建 FTS、不做搜索（系列后续方案；architecture note §3 明确禁止提前建 FTS 表）。
- 不为筛选预埋未经评审的 Entry 字段或派生表（architecture note §3）；全部投影为现有表上的只读查询。
- 不改 Hero 双入口与 entry editor 行为。
- 不更新 `MacInspectorContent.swift` 的 `practiceStatus.displayLabel`——检视器字段语义是练习历史，与材料状态不同；修复依赖未来 `entry(from:)` JOIN `practice_sessions` 的任务，不在本方案范围。

## 6. 证据与决策依据

- 原型证据：`prototypes/iphone/record.html`（chips :120-125、分组 :127-161、pill :132,141,151-166、缩略图位 :155-158、设计注记 :201-203 要求筛选语义与 iPad 共享）；`prototypes/ipad/workspace.html`（chips :154-159）；`prototypes/mac/workspace.html`（sidebar 计数 :114-142）。原型是设计基准，不构成实现授权（architecture note §1）。
- 架构备忘录：`docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md` §2.1——筛选语义与 `PadFilter` 共享、不做平台各自枚举；"待练习 / 已沉淀"判定需真实投影、不得复用 mock 推导；分组粒度与跨空间行为需在本方案重新决策（本方案决策：按日分组、限当前空间）。§3——不提前建表、不预埋字段。本方案采纳 §2.1 全部要求；"已沉淀"真实判定暂不采纳（零态过渡），留给 E7。
- 代码证据：第 2 节逐条路径与行号。
- 页面事实：`docs/platform-page-inventory.md` 将 iPad 筛选标记为 Local Mock 并要求"真实数据模型就绪时更新筛选语义"。
- 高风险动作手册：本方案命中 `docs/workflows/add-platform-screen.md`（平台页面结构变化）——采纳其读 spec 002/004/010、三端共享 seam、页面清单同步要求；不命中 `add-storage-migration.md`（无 schema 变化，仅只读查询）。

```text
证据能证明什么：原型与备忘录确定了筛选语义、分组形态和共享要求；现有 GRDB 表足以推导待练习语义。
"基于旧记录"过期判定已确认可推导：AppDatabase.swift:57 的 v5_add_learning_material_source_entry_body_hash 
migration 确认 source_entry_body_hash 列已存在；LearningRendering 已携带 sourceEntryBodyHash 字段（E0b 完成）；
pill 三态在 UI 层从 (entry.body, rendering?) 推导，无需 Data 层额外查询，降级路径保留作 schema 未来变化备用。
迁移前提：无外部参考迁移。
照搬风险：原型中 iPad 的"已记忆"与 iPhone 的"已沉淀"文案不一致——已用户确认统一用"已沉淀"，
String Catalog key 重命名为 filter.settled，不再保留 pad.filter.memorized。
```

## 7. 约束映射与验证路径

### 约束 1：实现前 active plan + 用户确认

- 约束 ID：DOC-CONST-001 / DOC-CONST-003
- 来源：docs/README.md §4.16、docs/plans/README.md §4
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查状态字段
- 验证提示：状态须为 `User Approved`。
- 说明：无。

### 约束 2：TDD 优先

- 约束 ID：DOC-CONST-005
- 来源：docs/README.md §1.4
- 适用范围：投影函数、筛选判定、计数
- 严重度：blocker
- 执行或验证方式：`swift test --package-path Packages/LangoTraceUI` / `Packages/LangoTraceData`
- 验证提示：spec 004 §4.8 要求筛选与 route 推导优先表达为纯函数以便包内单测。
- 说明：无。

### 约束 3：筛选为 transient UI state

- 来源：docs/spec/004-swiftui-architecture.md §4.8
- 适用范围：筛选选中态、分组展开态
- 严重度：blocker
- 执行或验证方式：人工审查 + 单测
- 验证提示：筛选选中态不得进入 `LanguageSpacePreview`、数据库、同步 manifest 或启动恢复。
- 说明：无。

### 约束 4：本地化与日期格式

- 来源：docs/spec/006-interface-localization-and-language-boundaries.md §4
- 适用范围：section header、chips、pill、零态文案
- 严重度：blocker
- 执行或验证方式：本地化 key 单测 + 切换界面语言人工验证
- 验证提示：`今天 / 昨天` 必须经系统相对日期能力或本地化资源，不得硬编码中文；`学习材料 · n 句` 的计数文案为 E0b 记录的复数规则强制场景，使用 String Catalog 复数能力而非手拼。
- 说明：无。

### 约束 5：不提前建表 / 预埋字段

- 来源：docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md §3、docs/spec/007-data-storage-migration-export-and-attachments.md
- 适用范围：Data 投影查询
- 严重度：blocker
- 执行或验证方式：`git diff` 审查无 migration 文件变化
- 验证提示：`rg "registerMigration" Packages/LangoTraceData` 输出与实现前一致。
- 说明：本方案的硬边界——只读投影，零 schema 变化。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`（PhoneRecordWorkspaceView 时间线化 + 筛选 chips）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`（EntryCard pill 从 practiceStatus.displayLabel → EntryMaterialStatusPill，**Phase 3 新增**）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`（PadFilter 迁移 / 删除）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`、`MacMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`（EntryTimelineRow pill 更新，**Phase 4 iPad 接线**）
- 新增 `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryTimeline.swift`（`EntryTimelineFilter` 枚举、`EntryMaterialStatusPill` 纯函数、日分组函数、计数函数）
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`、`GRDBLearningContentRepository.swift`（新增 `learningPracticeReadiness(for:)` 查询，仅返回 `[String: Bool]` hasCompletedRecording）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`（投影装配）
- String Catalog 资源文件（LangoTraceUI 包内 xcstrings）：新增筛选、section header、零态、pill key；`pad.filter.memorized` → `filter.settled`
- 测试：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Timeline/`（新建子目录）、`Packages/LangoTraceData/Tests/LangoTraceDataTests/`
- **不涉及**：`MacInspectorContent.swift`（检视器 practiceStatus 字段排除，见 §5）

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（practice_sessions.completed_recording_id、learning material 表结构，投影 SQL 依据）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`（E0b 重构后的记录 Tab 挂载点）
- `prototypes/iphone/record.html`、`prototypes/ipad/workspace.html`、`prototypes/mac/workspace.html`（设计基准，只读）

## 10. 涉及的文档路径

- `docs/platform-page-inventory.md`：iPhone 记录 Tab、iPad 筛选（Local Mock → Implemented）、Mac sidebar 计数条目更新。
- `docs/spec/learning-content/impl.md`：新增投影查询的实现地图。
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`：§2.1 采纳情况回写（按本备忘录 §4 读取规则）。
- `docs/spec/002` / `docs/spec/006`：规则不变，核对一致性。
- 本方案。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### Phase 1：共享筛选与投影类型（UI 包纯函数层）

1. 新增 `EntryTimelineFilter`（cases：`all / photo / needsPractice / settled`），替代 `PadFilter`；`photo` 沿用 `entrySource.photoWriting` key 或新增独立 key。
2. 文案：三端统一「已沉淀」（用户已确认）。String Catalog 新增 `filter.settled`（中文：已沉淀，英文：Settled），**不保留** `pad.filter.memorized`。
3. 新增判定函数 `EntryTimelineFilter.includes(entry:hasMaterialWithoutRecording:)`，输入为 entry + `hasMaterialWithoutRecording: Bool`（调用方计算：`practiceReadiness[entry.id] == false`，即在字典中且值为 false——有材料但无已完成录音），不再接收 memoryItems。`settled` case 始终返回 false（等待 E7）。此设计将"无材料（不在字典）"与"有材料无录音（值为 false）"的区分责任留在调用方，保持判定函数为纯 Bool 输入。
4. 新增日分组纯函数 `groupEntriesByDay(_:calendar:)` 与计数函数 `timelineCounts(entries:practiceReadiness:)`（today / total / 各筛选计数）。
5. **`settled` chip guard**：chips 渲染处排除 `settled` case（`filter.allCases.filter { $0 != .settled }`），保留类型系统完整，但不向用户暴露空态 chip。E7 落地时删除此过滤。
6. DoD：筛选纯函数测试全绿；`PadFilter` 类型从源码移除。

### Phase 2：Data 只读投影查询（简化版）

**架构调整（2026-06-17 确认）：** pill 三态（学习材料 · n 句 / 未生成 / 基于旧记录）从 `(entry.body, rendering?)` 在 UI 层纯函数推导，`LearningRendering.sourceEntryBodyHash` 已可靠可用（E0b 完成）。Data 层只需提供"待练习"筛选所需的真实 practice 状态。

1. `LearningContentRepository` 新增 `learningPracticeReadiness(for spaceID: String) -> [String: Bool]`（entryID → hasCompletedRecording），SQL：JOIN `learning_materials` 存在性 + `practice_sessions.completed_recording_id IS NOT NULL`，批量一次查询避免 N+1。
2. mock / seed repository 同步实现该查询，返回空字典或对应 seed entry 的 mock 值，保持 UI 预览可用。
3. `LearningContentStore` 装配：加载 `practiceReadiness: [String: Bool]` 并暴露给 View。
4. DoD：Data 包 `learningPracticeReadiness` 测试（含无 session、有 session 无录音、有完成录音三个 GRDB fixture 场景）全绿；无 migration 变化（`rg "registerMigration"` 数量与实现前一致）。

### Phase 3：iPhone 时间线

1. `PhoneRecordWorkspaceView` 列表区改为分组 section：header 用系统相对日期（今天 / 昨天）+ 本地化日期格式；保持 `LazyVStack` + section 结构，Hero 双入口不动。
2. 加入筛选 chips（水平排列，选中态为 transient `@State`），消费 Phase 1 共享类型；`settled` chip 被 Phase 1 guard 过滤，不渲染。
3. **`PhoneMainSupportingViews.swift`（EntryCard pill）**：新增 `EntryMaterialStatusPill`（在 `EntryTimeline.swift` 中定义的纯函数），从 `(entry: LearningEntry, rendering: LearningRendering?)` 推导三态：`rendering == nil` → 「未生成」；`rendering.sourceEntryBodyHash != LearningMaterialTextHash.sha256(for: entry.body)` → 「基于旧记录」；否则 → 「学习材料 · n 句」（`rendering.sentences.count`，走 String Catalog 复数）。替换原 `entry.practiceStatus.displayLabel` 用法。
4. DoD：`EntryMaterialStatusPill` 纯函数单元测试全绿（三态全覆盖，无需模拟器）；`PhoneMainSupportingViews.swift` 中无 `practiceStatus.displayLabel` 残留（rg 验证）；模拟器人工验证分组滚动与两种空态（无 entry / 筛选无命中）。

### Phase 4：iPad 与 Mac 接线

1. iPad：`PadSidebarView` 的筛选改为共享 `EntryTimelineFilter` 类型与 `practiceReadiness` 真实投影；时间线侧栏按日分组（与 iPhone 共享 `groupEntriesByDay` 函数）。**`LearningContentComponents.swift`（EntryTimelineRow pill）** 同步替换为 `EntryMaterialStatusPill`，与 Phone 共用同一纯函数，替换原 `entry.practiceStatus.displayLabel`。
2. Mac：sidebar `今日` / `全部记录` 计数改由 `timelineCounts` 提供；展示结构不变。
3. DoD：三端消费同一投影函数（`rg "EntryTimelineFilter" Packages/LangoTraceUI/Sources` 命中 Phone / Pad / Mac 三处）；`rg "PadFilter" Packages` 无命中；`LearningContentComponents.swift` 中无 `practiceStatus.displayLabel` 残留。

### Phase 5：文档与收口

页面清单、learning-content impl、architecture note 采纳记录更新；本地化 key 清单核对；macOS 全包聚焦测试。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：方案制定阶段已用只读核验代理对原型、备忘录与代码事实分别取证；本方案无隐私 / 外部请求面。
发现摘要：
- [P0][第一轮] 初稿曾沿用 PadFilter 的 memoryItems 命中作为"待练习"判定，直接违反 architecture note §2.1 的"不得复用 mock 推导"。已修订为 material-without-ready-recording 真实投影，"已沉淀"降为零态等待 E7。
- [P1][第一轮] "基于旧记录"过期判定依赖材料源文本哈希可比对，这一点未在制定环境完全核实（哈希存在于生成路径，但持久化列形态需实现期确认）。已在第 6/12 节写明降级路径与"不加 migration"硬边界，避免实现期擅自加列。
- [P1][第一轮] iPhone「已沉淀」与 iPad「已记忆」文案冲突若不统一会固化成两套 String Catalog key。已升级为需用户确认的统一决策（Phase 1 步骤 2）。
- [P2][第一轮] 批量投影查询避免 N+1：明确 repository 返回字典而非逐 entry 查询；mock repository 同步实现避免预览路径断裂。
- [P2][第一轮] 照片筛选在 E2 之前只有 source 信号；判定函数预留 projection 输入扩展位而非临时布尔参数，E2 落地时无需改函数签名。
- [P1][第二轮] 「学习材料 · n 句」为复数敏感文案，而 LocalizedChrome 当前无复数规则（E0b 记录的已知缺陷）。已在约束 4 写明本方案该文案必须走 String Catalog 系统复数能力，不得经 LocalizedChrome 手拼；这同时构成对 E0b Phase 5 迁移方向的首个真实用例。
- [P2][第二轮] 筛选 + 分组的性能边界：当前数据量小，纯内存分组可接受；在剩余风险记录"千级 entry 时分组与投影需要再评估增量化"，不提前优化。
- [P3][第二轮] 时间线零态（无任何 entry）与筛选零态（有 entry 但筛选无命中）是两个不同空态，Phase 3 文案需区分；已并入 Phase 3 步骤 3。
写回修改：第 3/6/12 节按上述修订；约束 4 补复数规则要求；第 5 节补"不预埋字段"排除；用户确认记录标记文案决策。
仍需用户确认的问题：
1. 三端统一文案采用「已沉淀」的建议是否认可。
2. "已沉淀"零态过渡（筛选可见但结果为空态说明）是否符合预期，或在 E7 前隐藏该筛选项。
是否允许进入实现：待用户确认后允许。

---

**补充轮审核（2026-06-17）**
审核方式：主会话代码核验（E0b 完成后，HEAD 0f0da44）
发现摘要：
- [P1] entry.practiceStatus 在 GRDB 中永远是 .notStarted（GRDBLearningContentRepository.entry(from:) L658-669 未 JOIN practice_sessions），三端卡片 practiceStatus.displayLabel 实际全部显示「待练习」占位；原方案未识别此问题，Phase 2 的 EntryLearningProjection 设计对 pill 部分是多余的——pill 三态可从已有 (entry, rendering?) 参数在 UI 层推导，无需 Data 层返回 sentenceCount / sourceTextHash。已简化 Phase 2 为 learningPracticeReadiness 单一查询，pill 逻辑移入 UI 层纯函数 EntryMaterialStatusPill。
- [P1] source_entry_body_hash 列已确认存在（AppDatabase.swift:57 v5 migration，LearningRendering.sourceEntryBodyHash 字段 E0b 完成后可靠可用）；原方案 §6/§20 的降级风险描述过度保守。已更新为"已确认可推导，降级路径保留作 schema 未来变化备用"。
- [P2] LearningContentComponents.swift 是 iPad EntryTimelineRow（非 Phone EntryCard），Phone EntryCard 在 PhoneMainSupportingViews.swift（原方案 §8 缺失）。已将 PhoneMainSupportingViews.swift 纳入 Phase 3 范围；LearningContentComponents.swift 归属 Phase 4 iPad 接线。
- [P3] 代码引用 HEAD 已从 274b7db 更新为 0f0da44；§2 E0b 相关描述从未来时改为已完成事实。
- [用户确认已获得] Q1（已沉淀）、Q2（Option B 隐藏 chip）、Q3（Phone 纳入，Mac 检视器排除，Phase 2 简化）均已用户确认。
写回修改：§2、§5、§6、§8、§12 Phase 1-4、§15、§18、§20 按上述修订；用户确认记录补充三条决策。
是否允许进入实现：是（User Approved）。
```

## 14. 复查方法

- 三端一致性：iPhone / iPad 选择同一筛选，结果集合一致；Mac `今日` 计数与 iPhone 今天 section 条数一致。
- 真实投影：新建 entry → `未生成`；生成材料 → `学习材料 · n 句` 且进入"待练习"；完成一次跟读录音 → 退出"待练习"；编辑正文后 → `基于旧记录`。
- 本地化：界面语言切英文后 section header、chips、pill、零态全部跟随；长文案不截断破版。
- 故障路径：投影查询失败时（模拟 DB 错误）列表降级为无 pill 的基础时间线且有诊断事件（复用 E0a 的读失败上报通道），不崩溃。
- 约束核查：`rg "registerMigration"` 无新增；筛选选中态不出现在任何持久化写路径。

## 15. TDD / 测试落点

```text
测试落点（Phase 1，分组）：Packages/LangoTraceUI/Tests/LangoTraceUITests/Timeline/EntryTimelineProjectionTests.swift（新建子目录与文件）
先失败用例：groupsEntriesByDayWithTodayFirst —— 失败原因：分组函数与 EntryTimelineFilter 尚不存在（编译失败即红）
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter EntryTimelineProjectionTests

测试落点（Phase 1，筛选）：同目录 EntryTimelineFilterTests.swift
先失败用例：needsPracticeRequiresHasMaterialWithoutRecordingTrue —— 失败原因：EntryTimelineFilter.includes(entry:hasMaterialWithoutRecording:) 尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter EntryTimelineFilterTests

测试落点（Phase 2）：Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBPracticeReadinessTests.swift（新建，名称更新）
先失败用例：readinessReturnsTrueWhenEntryHasCompletedRecording —— 失败原因：learningPracticeReadiness(for:) 尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceData --filter GRDBPracticeReadinessTests
fixture 场景：无 session、有 session 无录音、有完成录音（completed_recording_id IS NOT NULL）

测试落点（Phase 3）：Packages/LangoTraceUI/Tests/LangoTraceUITests/Timeline/EntryMaterialStatusPillTests.swift（新建，名称更新）
先失败用例：staleMaterialMapsToBasedOnOldRecordPill —— 失败原因：EntryMaterialStatusPill 纯函数尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter EntryMaterialStatusPillTests
覆盖三态：nil rendering → 未生成；hash 不匹配 → 基于旧记录；hash 匹配 → 学习材料 · n 句

不新增单元测试的原因（如适用）：滚动手感、chips 视觉与空态排版属人工验证项；文档更新依赖第 16 节文档命令。
```

## 16. 验证命令

```bash
# 聚焦
swift test --package-path Packages/LangoTraceUI --filter Timeline
swift test --package-path Packages/LangoTraceData --filter GRDBPracticeReadinessTests

# 完整（macOS 开发机）
swift test --package-path Packages/LangoTraceUI
swift test --package-path Packages/LangoTraceData

# 结构性 DoD
rg "PadFilter" Packages --count-matches            # 收口后无命中
rg "registerMigration" Packages/LangoTraceData/Sources | wc -l   # 与实现前一致（无新 migration）

# 文档
scripts/check-docs.sh
```

按 CLAUDE.md §1.4 采用轻量验证；不主动运行 `scripts/verify.sh`。

## 17. 文档影响检查

- `docs/platform-page-inventory.md`：iPhone 记录 Tab（时间线 + 筛选）、iPad 筛选（Local Mock → Implemented）、Mac sidebar 计数事实更新（必改）。
- `docs/spec/learning-content/impl.md`：投影查询实现地图（必改）。
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`：§2.1 采纳结论回写——分组粒度定为按日、限当前空间、"已沉淀" chip E7 前不渲染（类型系统完整，guard 隐藏，非零态 UI）（必改，按该 note §4 读取规则）。
- `docs/spec/002` / `006`：无规则变化（核对）。
- ADR：无核心决策变化。
- 实现完成后按 `docs/review/README.md` 做文档影响检查（命中"本地记录闭环变化"触发条件）。

## 18. 实施记录

2026-06-11：方案创建并完成双轮自审核（见第 13 节）。尚未进入实现。

2026-06-17：基于 E0b 完成后代码（HEAD `0f0da44`）补充代码核验轮审核，发现并修订三条 P1/P2 问题（见 §13 补充轮）。用户确认三条架构决策（Q1 已沉淀、Q2 Option B 隐藏 chip、Q3 PhoneMainSupportingViews 纳入 / MacInspectorContent 排除 / Phase 2 简化），方案状态推进为 User Approved，可进入实现。

## 19. 完成标准

1. 第 12 节 5 个 Phase 实施完毕，三端筛选与计数消费同一投影。
2. UI / Data 包测试在 macOS 全绿；第 14 节复查路径人工验证记录在案。
3. 第 17 节必改文档更新完毕，`scripts/check-docs.sh` 通过。
4. plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：逐 Phase 对照 DoD
scope-down 是否已记录："已沉淀" chip E7 前不渲染须在实施记录写明；"基于旧记录"三态已确认可实现，无降级风险
deferred / aborted 项是否已从完成叙事中剥离：真实照片判定（E2）、真实沉淀判定（E7）为显式排除
后续事实源或复审入口：docs/platform-page-inventory.md、docs/spec/learning-content/impl.md
```

## 20. 剩余风险

- "基于旧记录"判定：`source_entry_body_hash` 列已确认存在（v5 migration），降级路径保留作 schema 未来变化备用，当前可正常实现三态。
- 时间线分组与 `learningPracticeReadiness` 批量查询在千级 entry 规模未做性能评估；当前数据量小可接受，规模化时需增量化（记录于此，不提前优化）。
- `settled` chip：类型系统完整，chip UI 被 guard 过滤。E7 接入时需移除 Phase 1 步骤 5 的 filter guard，并为 `EntryTimelineFilter.includes settled` 填充真实记忆判定逻辑。
- `MacInspectorContent.swift` 的 `entry.practiceStatus.displayLabel` 因 `entry(from:)` 未 JOIN `practice_sessions` 而永远显示「待练习」占位；本方案显式排除，需在未来填充 GRDB practiceStatus 计算的任务中修复。
- `PhoneMainSections.swift`（PracticeView）的 `projection(for:)` 函数同样使用 `entry.practiceStatus.displayLabel` 作为 statusText；属于 Practice Tab 范围，不在本方案 E1 范围，留后续方案处理。
- 制定与审核环境无 swift 工具链，红绿路径未演练，全部验证须 macOS 执行。
