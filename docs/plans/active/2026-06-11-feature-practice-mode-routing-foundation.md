# 任务方案：练习方式路由基础（mode 路由、句子列表分段控制与续练入口）

状态：Draft
自审核状态：Reviewed
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-11

系列编号：E3（系列母方案：`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`，实施顺序位于 R1 之后、E4 听写与 E5 回译之前）。规模：S。

## 用户确认记录

本方案在 2026-06-11 系列母方案（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）的用户授权下创建。该授权仅覆盖"制定方案文档"本身；本方案进入生产代码实现前，仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

## 1. 需求或 bug 描述

按 `prototypes/iphone/practice-sentences.html` 的目标设计，听写与回译是「记录 → 句子列表」层级上的练习方式切换（分段控制：跟读 / 听写 / 回译），练习 Tab 首层维持记录卡片列表不变。原型同时给出"从第 n 句继续"CTA（定位到第一个未练句、整行可点、触控高度 ≥ 44pt）和行尾"对勾 + 已练"状态（由该句存在 ready 状态练习录音派生）。

本方案为 E4（听写）和 E5（回译）铺设共享路由与列表基础：

1. practice mode 贯通 `PracticeSessionRouteSeed` 与三端路由（spec 013 §6 要求的 practice mode 字段）。
2. 句子列表的练习方式分段控制，未实现方式按页面清单红线处理（不出现假交互、不出现排期文案）。
3. "从第 n 句继续"CTA 与逐句"已练"状态展示。
4. 三端共享 seed 的回归保障。

## 2. 现状描述

以下事实已对照 2026-06-11 HEAD 核验：

- `PracticeSessionRouteSeed` 定义在 `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift:6-75`，**已经包含 `exerciseType: PracticeExerciseType` 字段**，但所有构造路径（`:32`、`:45`、`:156`）硬编码 `.shadowing`。spec 013 §6 与 `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md` §2.3 写的"需要增加 practice mode 字段"相对当前代码已部分过期：字段已存在，缺的是枚举扩展、构造贯通与入口表达。本方案落地后应同步修正这两处文档表述。
- `PracticeExerciseType` 定义在 `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift:3-5`，当前只有 `case shadowing`。
- `practice_sessions` 表已有 `exercise_type TEXT` 列（v9 migration，`AppDatabase.swift:663-751`）；`GRDBPracticeRepository.swift` 的 session 查找已按 `exercise_type` 作为键之一（`:165-191` 的 `session(materialID:sentenceID:sentenceIndex:exerciseType:)`），即同一句子在不同练习方式下是不同 session。**不需要新的 migration**。
- 行解析回退：`PracticeExerciseType(rawValue:) ?? .shadowing`（`GRDBPracticeRepository.swift:194` 附近）。新增枚举 case 后旧库行不受影响。
- `PracticeSentenceListView`（`Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift:5-55`）：单一固定视图，无分段控制、无"已练"状态、无续练 CTA；它不自行查询完成状态，列表数据由 `LearningRendering.sentences` 提供。
- `GRDBPracticeRepository` 没有"按 material + exercise type 列出已练句子"的查询；"已练"语义已有定义：最近一次 ready recording 派生（spec 013 §2）。
- `PracticeActions`（`Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeActions.swift:14-90`）暴露 `createOrRestoreShadowingSession` 等方法，命名绑定 shadowing。
- 句子列表与单句页在三端的承载：`PhoneMainView.swift`、`PadMainSections.swift`、`MacWorkspaceContentView.swift` 都直接构造 `PracticeSentenceListView`，seed 构造共享同一 init。
- 既有测试：`Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`、`PracticeSessionViewModelTests.swift`；Data 侧 `GRDBPracticeRepositoryTests.swift`。
- 页面清单红线（`docs/platform-page-inventory.md` §8）：练习 Tab 首层不得混排未实现任务类型；不得出现`规划中`等排期文案；不得退回 Entry 级 practice route。原型设计说明同时要求"落地前分段控制不出现"。

## 3. 目标

1. `PracticeExerciseType` 扩展为 `shadowing / dictation / backtranslation` 三 case；rawValue 即 `practice_sessions.exercise_type` 存储值，是稳定契约。
2. `PracticeSessionRouteSeed` 构造路径可传入 exercise type（默认 `.shadowing`），seed 与 snapshot 中的 mode 一致贯通到 session 创建。
3. 句子列表拥有练习方式分段控制基础设施：由 `PracticeModeAvailability`（已落地方式集合）驱动渲染——只有一个可用方式时不渲染分段控制（与原型"落地前分段控制不出现"一致）；E4 / E5 落地后只需注册可用性，无 UI 改造。
4. 句子列表行展示"已练"状态（对勾 + 已练 文字，按当前选中方式派生），并提供"从第 n 句继续"CTA，定位到当前方式下第一个未练句。
5. Data 层提供按 `learning_material_id + exercise_type` 返回已完成句子标识集合的查询。
6. 三端共享 seed / 列表行为有回归测试，确保平台不分叉。

## 4. 范围

- Core package：`PracticeSession.swift`（枚举扩展）、必要的可用性类型。
- Data package：`GRDBPracticeRepository.swift` 新增已练句子查询 + 测试。
- UI package：`PracticeRouting.swift`（seed 构造贯通 mode）、`PracticeSessionViews.swift`（分段控制、已练状态、续练 CTA）、`PracticeActions.swift`（seam 泛化为按 exercise type 创建 / 恢复 session，行为当前仍只接 shadowing 实现）、三端承载文件的传参点、`Localizable.xcstrings` 新 key。
- 测试：UI `PracticeRouteSeedTests` 扩展 + 新列表 presentation 测试；Data `GRDBPracticeRepositoryTests` 扩展。

## 5. 不做什么

- 不实现听写会话（E4）与回译会话（E5）的任何页面、diff、attempt 持久化或 AI 点评。
- 不新增 GRDB migration：`exercise_type` 列已存在。
- 不改练习 Tab 首层（记录卡片列表维持现状，页面清单红线）。
- 不在分段控制中渲染任何未注册可用性的方式：不出现禁用假按钮、`规划中` 文案或大段 unavailable 说明（页面清单 §8 红线）。
- 不做"已练"状态的手动标记完成（spec 013 §2：完成态由 ready recording 派生，不设手动标记）。
- 不把分段控制选中方式持久化到数据库；它是列表 route 内 UI 状态。
- 不改 TTS 播放、录音或单句跟读会话行为。

## 6. 证据与决策依据

- 原型：`prototypes/iphone/practice-sentences.html`（分段控制、已练状态派生、从第 n 句继续、≥44pt 触控、文字与形状共同表达）。
- spec：`docs/spec/013-practice-learning-domain.md` §3（route seed 契约、sentence identity 红线）、§6（练习方式扩展边界：练习方式切换位于句子列表层级、复用同一句子快照与 TTS 示范路径）、§2（已练状态派生语义）。
- 架构备忘录：`docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md` §2.3——采纳"`PracticeSessionRouteSeed` 携带 practice mode、`practice_sessions` 已有 exercise type 字段可承接"；本方案核验后修正其中"需要增加字段"的表述（字段已存在，需要的是贯通）。
- 代码证据：第 2 节逐条（`PracticeRouting.swift:6-75`、`PracticeSession.swift:3-5`、`GRDBPracticeRepository.swift:165-191`、`PracticeSessionViews.swift:5-55`、三端承载文件）。
- 页面清单：`docs/platform-page-inventory.md` §8 红线与 §9 维护规则。
- workflow：本方案属于平台页面变化，已读取 `docs/workflows/add-platform-screen.md`；无数据迁移，不命中 `add-storage-migration.md`。

```text
证据能证明什么：seed 与存储层已为多 mode 预留（字段 + 键控查询），扩展是低风险贯通而非重设计。
证据不能证明什么：不能证明听写 / 回译会话本身的可行性（属 E4 / E5）。
迁移前提：枚举 rawValue 与 exercise_type 存储值保持一致。
照搬风险：spec 013 §6 与备忘录 §2.3 的"需要增加字段"表述过期，照搬会重复造字段；以当前代码为准。
```

## 7. 约束映射与验证路径

### 约束 1：实现前 active plan + 用户确认 + 自审核

- 约束 ID：DOC-CONST-001 / DOC-CONST-002 / DOC-CONST-003
- 来源：`docs/README.md` §4.16、`docs/plans/plan-review-protocol.md` §2、`docs/plans/README.md` §4
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查状态字段
- 验证提示：`User Approved` 前不改生产代码
- 说明：无

### 约束 2：练习 route 与 sentence identity 红线

- 来源：`docs/spec/013-practice-learning-domain.md` §3、`docs/platform-page-inventory.md` §8
- 适用范围：UI 路由
- 严重度：blocker
- 执行或验证方式：`PracticeRouteSeedTests` 单元测试
- 验证提示：任何 mode 的 session route 都必须携带稳定 sentence identity，不得退回 Entry 级 route
- 说明：分段控制切换方式时不得丢失 sentence 上下文

### 约束 3：不出现假交互与排期文案

- 来源：`docs/platform-page-inventory.md` §8
- 适用范围：分段控制渲染
- 严重度：blocker
- 执行或验证方式：`PracticeModeAvailability` 单元测试 + 人工审查
- 验证提示：只有已注册可用的方式才渲染；单一方式时不渲染分段控制
- 说明：避免 E4 / E5 落地前出现不可用的听写 / 回译入口

### 约束 4：状态表达与可访问性

- 来源：`docs/spec/003-ui-design-system.md` §3 / §4.3、`docs/spec/010-apple-platform-interaction-and-accessibility.md`
- 适用范围：已练标记、续练 CTA
- 严重度：warn
- 执行或验证方式：本地化 key 测试 + 人工审查
- 验证提示：已练状态用形状 + 文字（对勾 + 已练），不只靠颜色；CTA 整行可点且触控高度 ≥ 44pt
- 说明：无

### 约束 5：三端共享 seam

- 来源：`docs/spec/004-swiftui-architecture.md`、`docs/spec/013-practice-learning-domain.md` §1
- 适用范围：三端承载
- 严重度：blocker
- 执行或验证方式：共享组件 + 回归测试
- 验证提示：mode 进入 seed / actions 的路径三端唯一，平台只决定承载
- 说明：无

## 8. 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- 测试：`Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`、`Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeSentenceListPresentationTests.swift`（新建，开始按功能子目录组织）、`Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBPracticeRepositoryTests.swift`

## 9. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeRecordingArtifact.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhonePracticeRows.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（v9 schema 事实）

## 10. 涉及的文档路径

- 本方案。
- `docs/spec/013-practice-learning-domain.md`（§6 字段表述修正 + 分段控制落地后的变更记录）。
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`（§2.3 采纳标注与表述修正）。
- `docs/platform-page-inventory.md`（句子列表能力边界更新）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

1. Core：`PracticeExerciseType` 增加 `dictation`、`backtranslation`（rawValue 同名小写，与 `exercise_type` 列稳定对应）。先写失败测试锁定 rawValue 契约。
2. UI seed 贯通：`PracticeSessionRouteSeed` 的便捷 init 增加 `exerciseType` 参数（默认 `.shadowing`），写入 seed 与 `PracticeSentenceSnapshot.exerciseType`；句间导航 seed（`:156` 路径）继承当前 mode，不回落 shadowing。
3. Actions seam 泛化：`PracticeActions.createOrRestoreShadowingSession` 更名为 `createOrRestoreSession`，签名携带 snapshot（snapshot 内含 exerciseType）；App Shell 装配的实现当前对 `.shadowing` 走既有路径，对其他 mode 返回 `PracticeActionFailure.disabled`（E4 / E5 落地时替换）。这是单一 seam 扩展，不造第二条路由。
4. 可用性：新增 `PracticeModeAvailability`（UI 层 value type）：`availableModes: [PracticeExerciseType]`，由 App Shell 装配注入；本方案落地时只注册 `.shadowing`，因此分段控制不渲染——红线安全。E4 / E5 各自注册即可点亮对应 segment。
5. 列表 presentation：新增纯 presentation 计算（放入可测的 helper / presentation model）：
   - 输入：句子数组 + 已练句子标识集合（按当前 mode）+ 可用方式。
   - 输出：每行 practiced 标记、`continueTarget`（第一个未练句 index 与编号文案 `从第 n 句继续`）、是否渲染分段控制。全句已练时不显示 CTA。
6. Data 查询：`GRDBPracticeRepository` 新增 `completedSentenceIDs(materialID:exerciseType:)`——返回该 material 下、该方式、状态 completed 或存在 ready recording 的 `sentence_id` 集合（与 spec 013 §2"由最近一次 ready recording 派生"一致；completed 但录音缺失的 session 仍计已练）。
7. UI 装配：`PracticeSentenceListView` 接入分段控制（仅多方式时渲染）、行尾已练标记、底部续练 CTA（整行 Button，≥44pt）；CTA 点击即构造对应句子的 seed 进入会话。三端承载文件只传新参数，不复制视图。
8. 本地化：新增 `practice.modes.shadowing / dictation / backtranslation`、`practice.sentenceList.practiced`、`practice.sentenceList.continueFrom`（含占位 n）等 key 的 zh-Hans / en 文案。
9. 文档收口：修正 spec 013 §6 与备忘录 §2.3 的字段表述，更新页面清单。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：本环境无并行隔离审查会话可用于方案文本审查；已按协议维度逐项自查，并以只读代码核验代理输出作为事实输入。
发现摘要：
  第一轮：
  - [P0] 初稿沿用 spec 013 §6"route seed 需要增加 practice mode 字段"的表述，代码核验后发现 exerciseType 字段已存在且 session 查找已按 exercise_type 键控；方案改为"贯通而非新增"，并增加文档表述修正工作项。
  - [P1] 初稿让分段控制渲染三个 segment 并禁用未实现项，与页面清单 §8"不出现假交互 / 排期文案"和原型"落地前分段控制不出现"冲突；改为 PracticeModeAvailability 驱动、单一方式时不渲染。
  - [P2] 初稿未定义"completed 但录音文件缺失"的已练口径；按 spec 013 §2（session 保持 completed）判定仍计已练，已写入第 12 节第 6 步。
  第二轮：
  - [P1] Actions 更名属于行为契约变化，需同步更新 PracticeSessionViewModelTests 与 App Shell 装配；已写入范围与测试落点。
  - [P2] 续练 CTA 在"全部已练"时的行为最初未定义；定为不显示 CTA。
  - [P2] 行解析回退 `?? .shadowing` 会把未来未知 rawValue 静默归为跟读；当前三 case 下可接受，作为剩余风险记录（若后续新增方式应改为显式失败或保留原值）。
  - [P3] 本地化 key 列表补全。
写回修改：以上各项均已写回第 2、3、5、12、15、20 节。
仍需用户确认的问题：本方案整体范围与实现授权（推进到 User Approved）；Actions seam 更名（createOrRestoreShadowingSession → createOrRestoreSession）是否接受。
是否允许进入实现：待用户确认后允许。
```

## 14. 复查方法

1. 代码：`PracticeExerciseType` 三 case rawValue 与 `exercise_type` 列值一致；seed 三条构造路径均可携带 mode；句间导航不回落 shadowing。
2. 行为：当前只注册 shadowing 时句子列表与现状一致（无分段控制、无回归）；测试中注册多方式后分段控制出现、切换方式时已练集合按方式重算。
3. 已练状态：对某句完成一次跟读录音后回到列表，该行显示对勾 + 已练；CTA 跳到下一未练句；全部已练时 CTA 消失。
4. 故障路径：repository 查询失败时列表仍可进入跟读（已练状态降级为全未练展示，不阻塞主流程）；对未注册可用性的 mode 调用 actions 返回 `disabled` 失败而非崩溃。
5. 三端：Phone / Pad / Mac 承载点编译期共享同一组件；`ThreePlatformPresentationCopyTests` 风格的共享断言不分叉。

## 15. TDD / 测试落点

```text
测试落点：
  1. Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift（扩展）
  2. Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeSentenceListPresentationTests.swift（新建）
  3. Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBPracticeRepositoryTests.swift（扩展）
  4. Packages/LangoTraceCore/Tests/LangoTraceCoreTests 内 PracticeExerciseType rawValue 契约测试（落入既有 practice 模型测试文件或新建）
先失败用例：
  testRouteSeedCarriesDictationExerciseTypeIntoSnapshot
  —— 用 exerciseType: .dictation 构造 seed，断言 seed.exerciseType 与 snapshot.exerciseType 均为 .dictation；当前 init 无该参数且硬编码 .shadowing，编译先失败，按 stub-first（先加参数透传空实现）使断言失败成红。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceUI --filter PracticeRouteSeedTests
不新增单元测试的原因（如适用）：分段控制的触控尺寸与三端视觉承载属人工模拟器验证；其状态机与渲染条件已由 presentation 测试覆盖。
```

## 16. 验证命令

```bash
# 聚焦（红绿循环）
swift test --package-path Packages/LangoTraceUI --filter PracticeRouteSeedTests
swift test --package-path Packages/LangoTraceData --filter GRDBPracticeRepositoryTests

# 受影响 package 轻量验证
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
git diff --check
git status --short
```

## 17. 文档影响检查

- `docs/spec/013-practice-learning-domain.md`：§6 表述修正（字段已存在）+ 分段控制 / 续练 CTA 落地写入变更记录——是。
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`：§2.3 采纳标注——是。
- `docs/platform-page-inventory.md`：句子练习列表条目能力更新——是。
- ADR：无核心决策变化。
- `docs/review/`：无数据库 schema 变化，不命中专项审查硬触发；平台页面变化按日常文档影响检查处理。

## 18. 实施记录

2026-06-11：方案创建并完成两轮自审核（见第 13 节）。尚未进入实现。

## 19. 完成标准

1. 第 15 节测试全部存在且通过；首个失败用例转绿。
2. 仅注册 shadowing 时三端句子列表无可见回归；已练标记与续练 CTA 按 ready recording 派生正确。
3. E4 / E5 可仅通过注册 `PracticeModeAvailability` 与替换 actions 实现接入对应 segment（以测试中注册 fake mode 验证）。
4. spec 013 / 备忘录 / 页面清单的表述修正完成。
5. 从 `active/` 移入 `done/` 前完成 plan-vs-shipped 对账（无 deferred 项预期；如有则记录决策日志）。

## 20. 剩余风险

1. `PracticeExerciseType(rawValue:) ?? .shadowing` 的静默回退在未来新增方式时可能掩盖数据问题；本方案三 case 范围内无实际影响，记录待后续练习方式扩展时复审。
2. "已练"按方式独立计算意味着同一句跟读已练、听写未练；这是产品预期（每种方式独立闭环），但首次切换方式时用户可能误以为进度丢失；E4 落地时在 UI 文案上复查。
3. Actions seam 更名牵动 App Shell 装配与既有 ViewModel 测试，属一次性机械修改；如遗漏会在编译期暴露。
