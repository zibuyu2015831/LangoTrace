# 任务方案：记忆复习队列（统计、本地固定间隔调度与已掌握状态机）（E8）

状态：User Approved
自审核状态：Reviewed（2026-06-18 批量 run 实现前隔离自审核，用当前代码核验漂移）
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-18（批量 run 实现前隔离自审核：E7 已落地，幻列 deposited_at→created_at、无 updated_at、Core 协议在 MemoryDeposit.swift、新增 review-update 方法 + 纯 scheduler、无新 migration）

## 批量 run 实现前隔离自审核（2026-06-18）

```text
审核方式：隔离子代理只读，用当前 HEAD（875a6c0，E7 已落地 dev）核验方案现状
核心决策/ADR 反转检查：无。纯本地复习本地记忆数据，不发外部请求、不建向量表（守核心决策 12 + embedding 备忘录红线），符合 spec 007 §3.1.1 MemoryItem 主数据 Update 路径。无 ADR 变更。
确认漂移与修订（实现时按此为准）：
  [P0-1] 幻列：方案「本周沉淀」用 deposited_at，E7 实际列为 **created_at**（AppDatabaseMemoryMigration.swift:31，无 deposited_at）。全部 deposited_at→created_at。
  [近P0] 幻列：方案乐观并发检查提到 updated_at，memory_items **无 updated_at** 列（只有 created_at/soft_deleted_at）。改用 review_count / last_reviewed_at 做并发检查。
  [P1] 现状 stale：E7 已落地，三端记忆页已渲染真实 DepositedMemoryItem 只读列表（iPhone PhoneMainSections、iPad PadMainSections、mac MacWorkspaceContentView），MemoryDepositActions seam 已在 AppEnvironment 接线。E8 统计条 + 复习入口挂真实沉淀数据，不混候选 mock。
  [P1] 落点漂移：Core 模型/协议在 **MemoryDeposit.swift**（非方案写的 MemoryItem.swift / Data 层 MemoryItemRepository.swift）。MemoryReviewState 枚举(new/scheduled/mastered)已存在、DepositedMemoryItem 已带全 review 字段——E8 不需补状态模型，只新增 scheduler + outcome。
  6 个 review 列名逐字匹配 E7（review_state CHECK('new','scheduled','mastered')、review_rung、review_due_at、last_reviewed_at、review_count、mastered_at，均 NOT NULL DEFAULT 或 nullable 如 E7）。
  无新 migration（v26 已含列）；若将来加复习历史事件表才是 v27。
有序 seam：Core 纯 MemoryReviewScheduler（注入 clock，固定阶梯如 [1,3,7,14,30] 天，状态机 new→scheduled→mastered）+ MemoryReviewOutcome 枚举 → MemoryItemRepository(Core 协议) 新增 dueItems/recordReviewOutcome/markMastered/resumeReview/memoryStatistics + GRDB 实现（复用既有 clock 注入构造器）→ UI 复习会话 + 统计条（挂真实沉淀数据，复用 PracticeSession 式会话先例）→ AppEnvironment 装配 → 文档。「本周」用 Swift Calendar/TimeZone 从 epoch 派生，不在 SQL 算周。
是否允许进入实现：是（批量 run §1 预授权 + 本轮漂移已修订）。
```

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（[2026-06-11-chore-code-review-and-dev-plan-series.md](2026-06-11-chore-code-review-and-dev-plan-series.md)）。该授权仅覆盖"方案文档创建"；本方案进入实现前仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

## 1. 需求或 bug 描述

按三端记忆原型（`prototypes/iphone/memory.html`、`prototypes/ipad/memory.html`、`prototypes/mac/memory.html`），记忆页顶部有三项统计（本周沉淀 / 待复习 / 已掌握）和低压力复习入口（"5 个词句等你回看 · 大约 3 分钟"，"不想复习也没关系，它们会安静地留在队列里"）。本任务在 E7 沉淀主数据之上实现：

1. 三项统计的真实投影：本周沉淀、待复习、已掌握。
2. 本地间隔复习调度：第一版刻意采用简单的固定间隔阶梯，纯本机计算。
3. 复习完成态与 `已掌握` 状态机。
4. 三端共享的 `开始复习` 入口与小批量复习会话。

## 2. 现状描述

- E7（[2026-06-11-10-feature-memory-deposit-foundation.md](2026-06-11-10-feature-memory-deposit-foundation.md)）尚未实施；其 migration 按 dependency contract 已包含本任务全部 schema 字段：`review_state`（CHECK `'new'`/`'scheduled'`/`'mastered'`）、`review_rung`、`review_due_at`、`last_reviewed_at`、`review_count`、`mastered_at`。本任务不新增 migration。
- 当前代码（2026-06-11 HEAD）没有任何复习调度、统计或复习会话代码；三端记忆页为 Local Mock（E7 现状描述已核实）。
- 原型中的统计数字（12 / 5 / 86）与复习文案均为 mock；iPad 原型明确"低压力"基调：不做打卡、欠债计数或红色角标。
- [2026-05-27-embedding-infrastructure-notes.md](../../architecture/notes/2026-05-27-embedding-infrastructure-notes.md) 与核心决策 12 为约束性边界：复习队列不得引入向量表，不得为用户内容生成 embedding。
- [2026-06-11-prototype-target-design-extension-notes.md](../../architecture/notes/2026-06-11-prototype-target-design-extension-notes.md) §3 曾提醒"不提前建复习队列调度"；本任务即是该能力的"对应独立方案"，提醒因此解除。

## 3. 目标

1. `MemoryReviewScheduler` 纯逻辑调度器落地（LangoTraceCore），固定间隔阶梯，可注入 clock，全部行为单元测试覆盖。
2. repository 扩展：到期项查询、复习结果写入、统计查询（本周沉淀 / 待复习 / 已掌握），全部基于 E7 的 `memory_items` 字段。
3. `已掌握` 状态机：`new → scheduled →（完成阶梯）→ mastered`，支持手动标记已掌握与恢复复习。
4. 三端 `开始复习` 入口 + 复习会话页：小批量（默认每次最多 10 项）、目标文本先行、展开释义与来源语境、`记得` / `还要再看` 两档反馈。
5. 统计与复习状态全程不暴露任何向量 / embedding / 算法工程概念，文案保持低压力基调。

## 4. 范围

- `Packages/LangoTraceCore`：`MemoryReviewScheduler`、`MemoryReviewOutcome`、`MemoryReviewState` 模型与状态机。
- `Packages/LangoTraceData`：`MemoryItemRepository` 扩展（`dueItems`、`recordReviewOutcome`、`markMastered`、`resumeReview`、`memoryStatistics`），事务内状态写入。
- `Packages/LangoTraceUI`：三端统计条、复习入口卡、复习会话视图与 view model、`MemoryReviewActions` seam、mac 表格 `已掌握` 筛选 chip 与 Inspector `开始复习` 按钮接线。
- `LangoTraceApp/AppEnvironment.swift`：actions 装配。

## 5. 不做什么

- 不引入向量表、embedding、语义相似召回或"智能"排序（核心决策 12、embedding 备忘录红线）。
- 不实现 SM-2 / FSRS 等完整 SRS 算法；第一版固定阶梯是刻意选择（见第 6 节）。
- 不新增 migration（schema 由 E7 contract 提供）。
- 不实现复习提醒推送、通知或角标；不做打卡 / streak / 欠债计数（原型低压力基调）。
- 不实现复习历史事件表与撤销（记入剩余风险与后续方向）。
- 不修改 E7 的沉淀流程与列表结构。

## 6. 证据与决策依据

- 原型证据：iPhone / iPad / mac 记忆页统计条（本周沉淀 / 待复习 / 已掌握）、复习卡文案、mac `已掌握` chip 与 Inspector `开始复习` 命令位；mac 原型设计说明明确"复习节奏与待复习队列的具体行为需要独立任务方案定义"——本方案即该方案。
- 备忘录采纳说明：
  - [2026-06-11-prototype-target-design-extension-notes.md](../../architecture/notes/2026-06-11-prototype-target-design-extension-notes.md) §2.2：采纳"低压力复习队列入口"与"不暴露工程概念"；其中"复习队列依赖 Embedding / 检索方案"的表述本方案不采纳——经评估，固定间隔阶梯调度只依赖时间字段，不依赖任何检索基础设施，这使复习能力可以在 embedding 基础设施之前安全落地，且不违反任何 ADR。
  - [2026-05-27-embedding-infrastructure-notes.md](../../architecture/notes/2026-05-27-embedding-infrastructure-notes.md)：采纳为硬边界（不建向量表、不发送用户内容）。
- 调度设计决策：第一版固定间隔阶梯为 `[1, 3, 7, 14, 30]` 天。`记得` 进入下一档；`还要再看` 保持当前档并把 `review_due_at` 重置为明天；完成第 5 档后的下一次 `记得` 进入 `mastered`。理由：行为完全可预测、可测试、可向用户解释（"隔几天回看一次"），且未来替换为更智能调度时只需要换 scheduler 实现，schema 字段不变。
- workflow 引用：不涉及新 migration 与新 Provider；UI 入口变化属于平台页面调整，参照 [add-platform-screen.md](../../workflows/add-platform-screen.md) 的三端共享 seam 检查清单。无偏离。

```text
证据能证明什么：原型固定了统计口径的名称、复习入口形态与低压力文案基调。
证据不能证明什么：原型不能证明具体间隔参数、批量大小或两档反馈是用户最终偏好；这些是本方案的架构师决策，可在实现后按真实使用调整。
迁移前提：E7 已实施且 review 字段按 contract 落库。
照搬风险：把传统 SRS 应用的打卡 / 欠债模型照搬进来会违反产品低压力定位；已显式排除。
```

## 7. 约束映射与验证路径

### 约束 1：复习调度不引入向量 / embedding

- 来源：`docs/README.md` 核心决策 12、`docs/architecture/notes/2026-05-27-embedding-infrastructure-notes.md`
- 适用范围：调度器、repository、UI
- 严重度：blocker
- 执行或验证方式：人工审查 + `rg -i "embedding|vector" `新增代码无命中
- 验证提示：调度器只读写 E7 时间 / 计数字段。

### 约束 2：不新增 migration（E7 contract）

- 来源：本系列方案约定（E7 第 12.1 节 dependency contract）、`docs/workflows/add-storage-migration.md` 反例"为临时 UI 状态新增长期 schema"
- 适用范围：Data 层
- 严重度：blocker
- 执行或验证方式：人工审查 diff 中 `AppDatabase.swift` 无新 migration
- 验证提示：若实现中发现字段不足，必须回到方案修订并与用户确认，不得静默加列。

### 约束 3：状态机与派生统计的 source of truth

- 来源：`docs/spec/004-swiftui-architecture.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md` §3.1.2
- 适用范围：统计投影
- 严重度：warn
- 执行或验证方式：单元测试
- 验证提示：统计由查询即时派生，不落独立统计表；复习状态唯一事实源是 `memory_items` 行。

### 约束 4：界面文案语言边界与低压力基调

- 来源：`docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/spec/003-ui-design-system.md`
- 适用范围：复习会话与统计 UI
- 严重度：warn
- 执行或验证方式：本地化 key 单元测试 + 人工审查

## 8. 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/MemoryReviewScheduler.swift`（新增）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/MemoryItem.swift`（E7 产物，补充 review 状态模型）
- `Packages/LangoTraceData/Sources/LangoTraceData/MemoryItemRepository.swift`、`GRDBMemoryItemRepository.swift`（扩展）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MemoryReviewActions.swift`（新增 seam）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MemoryReviewSessionView.swift` 与对应 view model（新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`、`PadMainSections.swift`、`MacWorkspaceContentView.swift`（统计条与入口接线）
- `LangoTraceApp/AppEnvironment.swift`（装配）

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift` 与 practice session view model（会话式页面既有模式）
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/`（可注入 clock 的测试模式，语言空间测试已有 UTC epoch + injectable clock 先例）

## 10. 涉及的文档路径

- 本方案。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（实施后补充复习状态生命周期事实）
- `docs/platform-page-inventory.md`（记忆页面能力更新）
- 前序依赖方案：[2026-06-11-10-feature-memory-deposit-foundation.md](2026-06-11-10-feature-memory-deposit-foundation.md)（E7，hard dependency）

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

1. Core 调度器（先失败测试）：`MemoryReviewScheduler` 输入 `(当前状态, 反馈, now)` 输出 `(新状态, 下次到期时间)`；纯函数、注入 clock；状态机覆盖 `new` 首次入队（deposit 后第 1 天到期）、阶梯推进、`还要再看` 重置为次日、阶梯顶端转 `mastered`、手动 `markMastered` / `resumeReview`（恢复到 rung 0、次日到期）。
2. Data 扩展（先失败测试）：
   - `dueItems(spaceID:limit:now:)`：`review_state IN ('new','scheduled') AND (review_due_at IS NULL OR review_due_at <= now)`，按 `review_due_at` 升序，limit 默认 10。`new` 项视为立即可复习，保证 deposit 当天也能进入"等你回看"。
   - `recordReviewOutcome`：单事务读取当前行、调用 scheduler、写回字段并自增 `review_count`；并发重复提交以行内 `updated_at` 乐观检查防止双写。
   - `memoryStatistics(spaceID:now:)`：本周沉淀（`deposited_at` 位于本地周一起始的当周）、待复习（`dueItems` 同条件计数）、已掌握（`review_state='mastered'`）。周起始按用户日历周计算并在测试中固定 fixture 时区。
3. UI seam 与会话：`MemoryReviewActions`（加载批次、提交反馈、标记掌握）；`MemoryReviewSessionViewModel` 状态机（加载 → 出示目标文本 → 展开释义 / 来源语境 → 反馈 → 下一项 → 完成总结），支持中途退出（已提交的反馈保留，未复习项留在队列，符合"安静地留在队列里"文案）。
4. 三端接线：iPhone 统计条 + 复习卡；iPad 统计条 + 复习卡 + 左栏 `已掌握` 筛选实数据；mac 统计条 + `已掌握` chip + Inspector `开始复习`。复习会话 iPhone 为全屏 push，iPad / mac 为居中 sheet；三端共用同一 view model。
5. 空态与零压力路径：无待复习项时复习卡显示完成态文案而不是隐藏；统计为 0 时正常显示 0。
6. 文档同步与验证收口。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：同系列说明——方案撰写会话内无法对未落盘草稿做隔离审查，按协议第 3 节降级为主会话双轮自审核。
发现摘要：
  第一轮（架构）：
  - P0：扩展备忘录 §2.2 写有"复习队列依赖 Embedding / 检索方案"，与本方案"无向量复习"路线表面冲突 → 经核验该依赖只对"语义检索式复习"成立，固定间隔调度不依赖检索；已在第 6 节显式记录"不采纳该表述"的理由，避免后续会话误判为违反备忘录。
  - P1：`new` 状态项若必须等 1 天才进入队列，会造成"刚沉淀却无事可做"的体验断点 → dueItems 把 new 视为立即可复习。
  - P1：统计"本周"的周起始与时区未定义会导致跨端口径漂移 → 固定为用户日历周并写入测试 fixture。
  - P2：复习会话中途退出的状态语义未定义 → 已补充第 12.3 步。
  第二轮（测试 / 安全 / 落地）：
  - P1：recordReviewOutcome 并发双写（快速连点）会导致 review_count 跳档 → 补充乐观检查与对应测试用例。
  - P2：手动 markMastered 后误触的恢复路径缺失 → 补充 resumeReview 与测试。
  - P2：统计查询每次全表扫描的性能边界 → E7 已建 (space_id, deleted_at, deposited_at) 索引，当前数据量级可接受，记入剩余风险。
写回修改：以上均已写回第 5、6、12、15 节。
仍需用户确认的问题：
  1. 固定阶梯参数 [1,3,7,14,30] 天与两档反馈（记得 / 还要再看）是否符合预期。
  2. 批量上限默认 10 是否符合"大约 3 分钟"的产品口径。
是否允许进入实现：待用户确认后允许。
```

## 14. 复查方法

- 代码：scheduler 全分支测试、repository 事务与并发测试、view model 状态机测试全绿。
- 行为：deposit 一条记忆后复习卡立即显示 1 项待复习；完成复习后待复习数下降；连续完成阶梯后项进入已掌握并出现在 `已掌握` 筛选；手动标记 / 恢复闭环可走通。
- 故障路径：复习提交时数据库失败给出用户可见错误且状态不半写；会话中途退出后队列状态正确；clock 回拨（设备时间改动）不会让 mastered 项回退。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceCore/Tests/LangoTraceCoreTests/MemoryReviewSchedulerTests.swift（新增）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Memory/MemoryReviewRepositoryTests.swift（新增）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Memory/MemoryReviewSessionViewModelTests.swift（新增）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Memory/MemoryStatisticsProjectionTests.swift（新增）
先失败用例：MemoryReviewSchedulerTests.rememberedAdvancesRungAndSchedulesNextInterval —— 预期失败原因：MemoryReviewScheduler 类型尚不存在，编译失败。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceCore --filter MemoryReviewSchedulerTests
  swift test --package-path Packages/LangoTraceData --filter MemoryReviewRepositoryTests
  swift test --package-path Packages/LangoTraceUI --filter Memory
不新增单元测试的原因（如适用）：不适用。
```

## 16. 验证命令

```bash
# 聚焦
swift test --package-path Packages/LangoTraceCore --filter MemoryReviewSchedulerTests
swift test --package-path Packages/LangoTraceData --filter Memory
swift test --package-path Packages/LangoTraceUI --filter Memory

# 受影响 package 完整
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
```

## 17. 文档影响检查

- `docs/spec/007`：复习状态作为主数据行内字段的生命周期事实（实施后补充）。
- `docs/platform-page-inventory.md`：记忆页面从只读沉淀更新为含复习闭环（实施后）。
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`：§3"不提前建复习队列调度"的提醒由本方案对应解除，实施后在该备忘录使用方记录中无需改动（备忘录本身保留历史表述）。
- ADR：不需要；未来若引入向量化复习排序，必须新方案并按核心决策 12 评估。

## 18. 实施记录

（实施时按时间追加。）

## 19. 完成标准

1. 第 3 节目标全部有代码、测试或文档证据；无新增 migration。
2. 聚焦与受影响 package 测试全绿。
3. 三端入口在 macOS 环境人工验证通过（或记录为待补验项）。
4. plan-vs-shipped 对账完成，阶梯参数等架构师决策已在实施记录中留痕。

## 20. 剩余风险

- 固定阶梯不考虑遗忘曲线个体差异；属于刻意的第一版取舍，替换路径已通过 scheduler 抽象预留。
- 无复习历史事件表，无法撤销误触反馈、无法做趋势分析；后续若需要，单独方案新增事件表（届时才需要新 migration）。
- 统计查询随数据量增长的性能未做基准测试；当前索引覆盖主路径，量级风险低。
- Linux 环境无法人工验证三端会话交互，需 macOS 补验。
