# 任务方案：记录详情场景标签编辑（场景切片 2）

状态：Verified
自审核状态：Reviewed
类型：feature
创建日期：2026-07-22
最后更新日期：2026-07-22

## 用户确认记录

- 本任务在 `FABLE-MISSION.md` 授权的自主运行中执行（§2 第 3 条 + §4 自批授权）。它是场景标签批（`docs/plans/done/2026-07-22-feature-entry-scene-tags-and-timeline-filter.md`）「后续方向」与演进备忘录 `2026-07-22-entry-scene-taxonomy-extension-notes.md` §2.1 登记的第一个后续切片的兑现，无新决策。

## 需求描述

场景标签 v1 只支持创建时打标；已建记录（含批量存量未标注记录、E10 导入记录）无法事后打标或改标，标签体验环不闭合。本切片在三端共享的记录详情页提供场景编辑。

## 现状描述（HEAD `d0ea188`，主会话读码核实）

- Repository 更新方法仅 `updateEntryBody(entryID:spaceID:body:)`（协议 `LearningContent.swift`；GRDB 实现 `GRDBLearningContentRepository.swift:86-111`：trim → 空拒绝 → `fetchActiveEntry` 不存在抛 `entryNotFound` → 跨空间抛 `spaceMismatch` → `UPDATE ... SET body, updated_at ... AND deleted_at IS NULL` → 读回返回）。scene 无更新方法。
- 桥接内部协议 `GRDBLearningContentRepositoryProtocol`（`GRDBLearningContentRepositoryBridge.swift:6-16`）声明 `updateEntryBody`，bridge 转发并刷新 `selectedEntryIDs`。
- 三端详情共享 `EntryDetailView`（`PhoneMainSupportingViews.swift:118-`，可选闭包 seam 模式：`onUpdateEntryBody: ((String) throws -> Void)?` 传入 `SourceEntryTextView.onSave`）；装配层 `EntryDetailStoreView`（`:408-`）把 store 方法接入各闭包；store 有 `updateEntryBody(entryID:body:)` + `reload()`。
- 场景展示/选择基建已备（批次③）：`EntryScenePreset`、`EntrySceneDisplay.label(for:)/label(forStoredScene:)`、`SceneChipButton`、本地化键 `entryScene.*` 与 `entryEditor.scene.section`。
- 自由文本 scene（E10 导入）与空串（未标注）两态必须保留语义；`updated_at` 随改动刷新（与 body 编辑一致，材料 stale 判定只看 body hash，不受 scene 影响——`materialStatus` 用 `sourceEntryBodyHash`，读码确认）。

## 目标、范围和不做什么

目标：三端记录详情可将任意记录的场景改为任一预设或清除为未标注；时间线筛选/计数随 store reload 即时反映。

范围内：

1. **Data 协议与实现**：`LearningContentRepository` 增 `@discardableResult updateEntryScene(entryID:spaceID:scene:) throws -> LearningEntry`；GRDB 实现镜像 `updateEntryBody`（trim；**空串合法 = 清除标注，不拒绝**；`entryNotFound` / `spaceMismatch` 语义一致；`SET scene, updated_at`）；内部协议 `GRDBLearningContentRepositoryProtocol` 扩方法 + bridge 转发（含 `selectedEntryIDs` 刷新，与 body 更新一致）；**测试 fake `FailingReadLearningContentRepository`（`GRDBLearningContentRepositoryBridgeDiagnosticsTests.swift:140`）同步补 throw 实现——内部协议扩方法的第四个 conformance 破坏点（隔离审核 P1-1）**；InMemory 镜像（**按 InMemory 既有语义断言：跨空间 → `entryNotFound`**，其 `updateEntryBody` 无 `spaceMismatch` 路径，本切片不升级其语义——隔离审核 P2-4）；Unavailable 抛错。
2. **Store**：`updateEntryScene(entryID:scene:)` + `reload()`。
3. **UI 共享组件（隔离审核 P1-2/P2-2/P2-5 定案）**：新 `EntrySceneEditRow`（`EntrySceneControls.swift` 内）：**接收整个 `LearningEntry`**（row 内部读 `entry.scene`——`PhoneMainSupportingViews.swift` 不出现 `entry.scene)` 子串，`PhoneIOSConvergenceTests:432` 负向守卫保持不变）。行标签复用 `entryEditor.scene.section`；当前值显示三态：预设 slug → 本地化 label、自由文本 → 原样（用户内容不进 key 查找）、**空串 → `entryScene.none`（编辑语境的「未标注」，不用 `displayScene` 的默认场景回退——避免与「无场景」选项自相矛盾）**；Menu 选项 = 「无场景」首位 + 六预设枚举序，**不设「保留当前自由文本」no-op 项**（Menu 不选即保持，冗余项徒增用户内容入菜单与分支）；选择即调 `onUpdateScene(slug)`；失败行内显示复用 `entryEditor.saveFailed`。**当前值一律从 entry prop 派生，仅 error key 用 @State**（避开 `SourceEntryTextView` 的 `State(initialValue:)` stale 陷阱模板）。选项构造抽纯函数 `EntrySceneEditOptions`（静态闭集 none + 六预设 + 当前值三态显示纯函数）。
4. **接线**：`EntryDetailView` 增可选闭包 `onUpdateEntryScene: ((String) throws -> Void)?`（沿既有 seam 形态，nil 时不渲染行；row 不进 `EntryDetailHeader`，与 `PhoneIOSConvergenceTests:66` header 守卫不冲突）；`EntryDetailStoreView` 接 `store.updateEntryScene`；三端共享详情自动生效，无平台文件改动。
5. **本地化**：新键 `entryScene.none`（en "No scene" / zh-Hans "无场景"），登记进既有 `EntrySceneLocalizationTests.newKeys`。
6. **文档同批（隔离审核 P1-3 扩范围）**：页面清单**四处** + 变更记录——iPhone 记录详情 `:50`（**其现有「不展示来源 / 语言 / 场景 metadata」反述必须改写**：场景编辑行是编辑控件而非被移除的只读 metadata badge，措辞钉清与 header 守卫的关系）、iPad 记录详情 `:84`、macOS Entry Detail `:111`、共享组件 `EntryDetailView` 行 `:138`；演进备忘录 §2.1 标记本切片完成（指向本 plan）。备忘录 §2.1「评估合并为 `updateEntry(fields:)`」的处理（§5.4 义务，隔离审核 P2-1）：**暂不采纳**——当前仅两个更新维度且语义不同（body 关联材料 stale 判定，scene 是纯标签），窄方法与 `updateEntryBody` 对称更清晰；第三个可更新字段出现时再重估，结论回写备忘录。

不做什么：

- 不做自由文本输入 / 自定义场景（备忘录 §2.4 承接）；Menu 只提供「无场景」+ 六预设（自由文本当前值仅在行值原样展示，改动即覆盖为所选项）。
- 不动 macOS Inspector 的 scene 只读展示（`MacInspectorContent` 保持展示态；编辑经共享详情主区已可达）。
- 不改时间线筛选逻辑（reload 后 facet 纯函数自适应，含 stale 选中回退——批次③已测）。
- 无 migration、无 AI 请求路径触碰、无新外发。

## 证据与决策依据

- 场景批 done plan「后续方向」第 1 条 + 演进备忘录 §2.1（登记的切片边界与 update 方法方向）。
- `updateEntryBody` 全链先例（GRDB 语义 / bridge 转发 / store / 详情 seam / 错误面 source-boundary 守卫 `EntryCreationFailureSurfaceTests`）。
- spec/006：预设 label 本地化、自由文本用户内容原样不进 key 查找（批次③已立的双通道纪律，`SceneChipButton` 注释为载体）。

## 约束映射与验证路径

- §1.4 TDD：见测试落点；红相位逻辑成立 + CI 实证（批次②③④先例）；调用点勘查用多行感知扫描（批次③教训）；新增声明前注释一律 doc comments（批次②教训）。
- 决策 10：scene 不进任何 AI 请求，无隐私面变化。

## 涉及的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`（协议 + InMemory + Unavailable）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift`（内部协议 + 转发）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntrySceneControls.swift`（EntrySceneEditRow + Options）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`（EntryDetailView seam + EntryDetailStoreView 接线）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- 测试：`GRDBLearningContentRepositoryTests` / `InMemoryLearningContentRepositoryTests` 扩展、`GRDBLearningContentRepositoryBridgeDiagnosticsTests.swift`（fake 补实现）、`Timeline/EntrySceneEditOptionsTests.swift`（新）、`EntrySceneLocalizationTests` 扩键（互异断言经核不受影响）、`PhoneIOSConvergenceTests` source-boundary 断言

## 参考的代码文件路径

- `GRDBLearningContentRepository.swift:86-111`（updateEntryBody 模板）
- `PhoneMainSupportingViews.swift:408-470`（EntryDetailStoreView 接线先例）

## 涉及的文档路径

- `docs/platform-page-inventory.md`（两行 + 变更记录）
- `docs/architecture/notes/2026-07-22-entry-scene-taxonomy-extension-notes.md`（§2.1 完成标记）
- `FABLE-WORKLOG.md`

## 实施方案

1. Data：GRDB `updateEntryScene` + 测试（行为红：round trip / 清除 / trim / notFound / spaceMismatch）→ 协议扩方法（编译红）→ bridge / InMemory / Unavailable 同步 → 多行感知扫描调用点。
2. UI：`EntrySceneEditOptions` 纯函数 + 测试（行为红：none 首位 / 预设枚举序 / 当前值三态显示）→ `EntrySceneEditRow` → `EntryDetailView` seam + 装配接线 → source-boundary 断言 + 本地化键。
3. 文档同批 → 提交带 `[ci]` → CI 绿收口。

## TDD / 测试落点

- **Data（行为红）**：`updateEntrySceneRoundTrip`（"work"→读回；再改 ""→清除；trim）；`updateEntrySceneRejectsMissingEntryAndForeignSpace`（notFound / spaceMismatch，原值不变）；InMemory 镜像用例。协议扩方法对三实现为编译红/回归钉。
- **UI（行为红）**：`EntrySceneEditOptionsTests`——`options()` = none 首位 + 六预设枚举序（静态闭集）；当前值显示纯函数三态（slug → 本地化、自由文本 → 原样不经 key、空 → `entryScene.none` 而非 displayScene 回退）。
- **UI source-boundary（行为红，钉死挂 `PhoneIOSConvergenceTests`——body seam 先例在 `:224-226`，隔离审核 P2-3）**：`PhoneMainSupportingViews.swift` 含 `onUpdateEntryScene` seam 且 `EntryDetailStoreView` 接 `contentStore.updateEntryScene(entryID:`；负向断言不含 `try? contentStore.updateEntryScene`；既有 `:432` `entry.scene)` 负向守卫保持不变（row 接收整个 entry）。
- **本地化（行为红）**：`entryScene.none` 进 `EntrySceneLocalizationTests.newKeys`。
- 红相位逻辑成立 + CI 实证。

## 验证命令

聚焦（CI 内等价步骤）：`swift test --package-path Packages/LangoTraceData`、`swift test --package-path Packages/LangoTraceUI`。
完整：GitHub Actions `Build & Test`（HEAD 带 `[ci]`），conclusion=success 为准。

## 文档影响检查

- 页面清单四处（iPhone :50 反述改写 / iPad :84 / macOS :111 / 共享组件 :138）+ 变更记录、演进备忘录 §2.1 完成标记与 §5.4 结论回写——确定交付。
- 无 schema / AI / 权限 / 同步变化，不触发专项审查；本 plan 承载影响记录。

## 严格方案自审核记录

```text
审核日期：2026-07-22
审核方式：隔离审查（独立 general-purpose 子代理，新上下文、只读，HEAD d0ea188 核验）
审核轮次：双轮合并
未使用隔离审查的原因：不适用（已使用）
发现摘要：P0=0；P1=3（① 内部协议扩方法击穿测试 fake FailingReadLearningContentRepository——第四个 conformance 破坏点未登记；② PhoneIOSConvergenceTests:432 的 entry.scene) 负向守卫与接线自然写法冲突；③ 页面清单 iPhone :50 现有「不展示场景 metadata」反述与本切片直接矛盾，且 macOS :111 / 共享组件 :138 行遗漏）；P2=5（备忘录 §5.4 消化义务、「保留当前」no-op 项过度设计 + 空态 displayScene 回退自相矛盾、source-boundary 归属钉 PhoneIOSConvergenceTests、InMemory 错误语义差异、@State stale 陷阱提醒）；P3=5（materialStatus 命名失真、搜索/导出边界核验为无漏层、本地化互异断言安全、测试目录归属可接受、accessibilityLabel）。
关键核验：方案全部行号与结构论断证实；三端共享详情自动生效证实（Phone/Pad/Mac 均经 EntryDetailStoreView 装配）；reload → @Published → entry(id:) 重取数据流成立、无 stale；search_index 不含 scene、E10 实时 SELECT——更新无需触碰索引/导出。
写回修改：范围 1（fake 破坏点 + InMemory 语义钉死）、范围 3/4（row 接收整个 entry 保守卫、删 no-op 项、空态 entryScene.none、值从 prop 派生）、范围 6（页面清单四处 + :50 反述改写 + 备忘录 §5.4 暂不采纳结论）、TDD 落点（options 简化、source-boundary 钉 PhoneIOSConvergenceTests）、剩余风险补搜索/导出证据与命名勘误。
仍需用户确认的问题：无（前序切片登记的后续兑现，自批授权范围内）。
是否允许进入实现：是（P1 修订已全部写回本方案）。
```

## 实施记录

2026-07-22 实施完成（自主运行，FABLE-MISSION 授权）：

- 提交：`bbce0c6`（17 文件 +444/-5，单提交完成全部落点：GRDB `updateEntryScene` + 五处 conformance〔含测试 fake〕、store 方法、`EntrySceneEditOptions` + `EntrySceneEditRow`、共享详情 seam 接线、五组测试、页面清单四行 + 变更记录、备忘录 §2.1 完成标记与 §5.4 结论）。
- CI 证据：**run 29867642501 `Build & Test` conclusion=success——首轮即绿**（前序批次教训全部生效：fake conformance 提前登记、守卫冲突提前定案 row 传 entry、多行感知扫描、doc comments 纪律、缩进层级）。
- 红→绿：GRDB round-trip/清除/trim/notFound/spaceMismatch、InMemory 镜像、options 闭集与三态、convergence source-boundary、`entryScene.none` 本地化守卫，全部与实现同批入库并经 run 29867642501 实证。
- deferred：无新增（Mac 筛选 / 搜索联动 / 多标签仍由演进备忘录承载）。

## 完成标准

- 三端详情页可改/清场景，时间线筛选随 reload 反映；全部新测试入库；CI success；文档同批；plan 移 `done/`。

## 剩余风险

- Menu 失败错误面为行内轻提示（复用 saveFailed 键），无重试按钮；缓解：重选即重试，与 body 编辑 sheet 的错误面同级。
- `updated_at` 刷新会改变记录排序吗？——`entries(for:)` 按 `created_at DESC` 排序（读码确认），不受影响。
- 搜索/导出边界（隔离审核 P3-2 核验证据）：`search_index` 只索引 title/body（`SearchIndexWriter.swift:6-28`），scene 不入索引，更新无需触碰索引；E10 导出为实时 SELECT，新值自动进入后续快照；同步引擎尚无真实通道，无边界触碰。
- stale 判定命名勘误（P3-1）：实际方法为 `LearningContentStore.sourceEntryIsStale(for:)`（比对 `sourceEntryBodyHash`），scene 更新不影响其结果。
