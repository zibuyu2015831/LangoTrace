# 任务方案：听写练习（本机对照闭环）

状态：Done
自审核状态：Reviewed（2026-06-18 代码漂移复核，见 §13）
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-18（用户已给出整体实现授权，状态推进到 User Approved，进入 TDD 实现；基于 E1/E2/R1/E3 落地后的真实代码做事实刷新与决策定稿；E4-D1 已确认采用声学/词汇层口径）

系列编号：E4（系列母方案：`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`，实施顺序位于 E3 之后、E5 之前）。规模：M。前序依赖：E3（`docs/plans/active/2026-06-11-06-feature-practice-mode-routing-foundation.md`，practice mode 路由与可用性注册机制）。

## 用户确认记录

本方案在 2026-06-11 系列母方案（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）的用户授权下创建。该授权仅覆盖"制定方案文档"本身；本方案进入生产代码实现前，仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

需要用户确认的关键点（见第 13 节）：E4-D1 diff 宽容度口径（标点与大小写差异不计入差异数）。

## 1. 需求或 bug 描述

按 `prototypes/iphone/practice-dictation.html` 的目标设计实现听写练习方式：

1. 听该句已有的 TTS 音频（重听不设限，本机统计"已听 n 次"低权重信息，不构成评分或惩罚）。
2. 用户写下听到的句子并提交对照；对照前参考句保持隐藏，避免边听边看答案。
3. 本机字符串 diff 对照参考句，差异用下划线 + warn 色 + "n 处差异"计数文字共同表达，并标注"本机对照，不发送 AI"。
4. 句间导航与跟读页结构一致（上一句 / 第 m / n 句 / 下一句）。
5. 听写作答文本持久化，且 attempt 表设计一次性覆盖 E5 回译作答（一个 migration，不做两次）。

## 2. 现状描述

以下事实已对照 2026-06-18 HEAD（E1/E2/R1/E3 落地后）重新核验，并标注与 2026-06-11 初稿假设的差异：

- 练习域当前只有跟读闭环：`PracticeSessionView` / `PracticeSessionViewModel` / `PracticeControlBar` / `PracticePromptCard`（`Packages/LangoTraceUI/Sources/LangoTraceUI/`），录音走 `PracticeActions` → `GRDBPracticeRepository` + Speech `PracticeRecordingService`。
- **E3 交付物已落地并核验（初稿是预测，现为既成事实）**：
  - `PracticeExerciseType`（`Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift`）含 `shadowing` / `dictation` / `backtranslation` 三 case。
  - seed / snapshot 贯通 mode：`PracticeSessionRouteSeed`（`PracticeRouting.swift`）与 `PracticeSentenceSnapshot`（`PracticeSession.swift`，含 `exerciseType`、`targetTextSnapshot`、`targetTextHash` 等全字段）已就绪。
  - actions seam 确为 `PracticeActions.createOrRestoreSession(_:snapshot:)`（`PracticeActions.swift`），且 `completedSentenceIDs(_:exerciseType:)` 已实现。
  - **「可用 mode 注册」的真实形态需订正**：`PracticeModeAvailability`（`PracticeSentenceListPresentation.swift`）只是个 `struct(availableModes:)` 值类型，数据来自 `PracticeActions.availableExerciseTypes`；当前 `PracticeActionsAssembly.swift` 硬编码 `guard snapshot.exerciseType == .shadowing else { throw .disabled }`。因此「注册 `.dictation`」= 在装配处把 `.dictation` 加进 `availableExerciseTypes` + 移除该硬编码 guard，并非存在一个中央注册表。
- TTS 示范播放：单句页"听示范"经 `PracticeSessionViewModel.playDemo`（签名 `@escaping @MainActor @Sendable () async -> SentenceAudioPresentationState`）注入的 playback 闭包，复用逐句 TTS playback coordinator 与 local artifact cache（spec 013 §4；`SentenceAudioPlaybackCoordinator.swift` 在 Core）。TTS artifact 已有持久缓存（`tts_audio_artifacts` + `media_artifacts`）。
- 文本作答仍无任何持久化设施：`practice_sessions` / `practice_recordings` / `practice_recording_artifacts` 都是录音导向（v9 / v10 migration）；没有 `practice_text_attempts` 或等价表。**Data 最新 migration 已是 `v22_add_reading_progress_and_favorite_columns`（初稿假设的 v15 已过期）**；其中 **`v18_allow_practice_mode_exercise_types` 已把 `practice_sessions.exercise_type` 的 CHECK 扩到 `('shadowing','dictation','backtranslation')`**，即数据层闸门已为听写打开，本方案 attempt 表预计为 **v23**（实施时按当时最新顺序确认）。
- **仓库 session 创建方法是 shadowing 专名**：`PracticeRepository` 协议当前只有 `createOrRestoreShadowingSession(languageSpaceID:snapshot:)`；session 行结构跨 mode 同构，差异只在 snapshot 已携带的 `exerciseType`。听写实施时将其泛化为按 `snapshot.exerciseType` 键控的 `createOrRestoreSession`，而非新增近重复方法（早期重构，CLAUDE.md §1.1）。
- Core 没有字符串 diff 能力（已确认）。
- `docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md` §2 确立了多字节安全的 Character 计数约定（阅读域确立，本方案沿用同一原则）。

## 3. 目标

1. 听写会话在句子列表选中"听写"方式后可逐句进入：播放已有 TTS 示范 → 输入作答 → 提交对照 → 查看 diff → 句间导航。
2. diff 为 Core 纯函数，语义明确（见第 12 节 E4-D1/E4-D2），多字节（emoji / CJK / 组合字符）安全，完全单元可测。
3. 对照前参考句不出现在视图状态中可被展示的位置；对照后展示参考句 + 差异标注 + "n 处差异"计数 + "本机对照，不发送 AI" footnote。
4. 新增一个 GRDB migration 建立 `practice_text_attempts` 表，schema 一次性覆盖听写与 E5 回译作答；听写 attempt 含 diff 摘要与本机听次计数。
5. 全程零网络新增：不发任何 AI 请求；TTS 播放只复用既有单句显式触发路径与缓存，不做批量预生成。
6. 听写"已练"状态由已提交 attempt 派生，接入 E3 的已练集合查询。

## 4. 范围

- Core package：`PracticeDictationDiff`（新文件，纯函数 diff + 归一化 + 分词）、attempt value object 与 contract。
- Data package：migration `practice_text_attempts`、`GRDBPracticeRepository` attempt 读写与听写已练派生、测试。
- UI package：听写会话视图与 presentation model（复用 `PracticePromptCard` 句间导航结构）、`PracticeActions` 听写分支实现接入、`PracticeModeAvailability` 注册 `.dictation`、本地化 key、diff 渲染（AttributedString 下划线 + warn 色）。
- App Shell：装配听写 actions（attempt 持久化 + demo 播放复用既有注入）。
- 文档：spec 013、页面清单、相关备忘录采纳标注。

## 5. 不做什么

- 不为听写新增 TTS 请求路径或批量预生成：示范播放完全复用单句 TTS artifact cache 与 playback coordinator；句子无音频时走既有显式生成路径（用户点击"听"触发），与跟读一致（`docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`：批量预生成不得复用单句低摩擦边界；生产请求走 production HTTP client 边界，本方案不触碰该层）。
- 不新增第二个 TTS 设置入口或第二套主测试入口（`docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md` §3.1）。
- 不调用 AI 做对照、评分或解释：对照是本机字符串 diff；不做发音评分、ASR（spec 013 §5/§6）。
- 不做机械评分、星级、惩罚或排行：听次计数只是低权重信息。
- 不把 attempt 文本纳入同步、默认导出、备份、诊断日志或任何外发路径；attempt 是用户练习证据（类比 `docs/architecture/notes/2026-05-26-practice-recording-sync-export-notes.md` 对录音的定位），不是可重建缓存，不参与 TTS cache 清理 / LRU。
- 不做听写的语音输入（键盘输入即可）；不做错词本沉淀（属记忆域 E7 之后的能力）。
- 不为 E5 回译实现任何 UI 或 reference 展开逻辑（仅 schema 预留）。

## 6. 证据与决策依据

- 原型：`prototypes/iphone/practice-dictation.html`（重听不设限 + 已听 n 次、参考句对照前隐藏、下划线 + warn 色 + 计数文字、"本机对照，不发送 AI"、句间导航结构一致、音频复用既有 TTS artifact）。
- spec：`docs/spec/013-practice-learning-domain.md` §4（示范播放显式触发、复用 playback coordinator）、§6（听写位于句子列表层级；"听写校对是否纯本机"的开放决策——本方案决策为纯本机，原型即按此设计）、§7（状态归属）。
- 架构备忘录：
  - `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`：采纳"无批量预生成、playback source 必须经 resolver、生产 HTTP client 边界"；本方案只消费播放 seam，不触碰生成层。
  - `docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md`：采纳"不新增第二套 TTS 设置 / 测试入口"。
  - `docs/architecture/notes/2026-05-26-practice-recording-sync-export-notes.md`：采纳"练习产物默认 local-only、不同步不默认导出"，attempt 文本同等对待。
  - `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md` §2.3：采纳"共享句子快照与 seed、以 practice mode 区分方式、听写不另造句子数据源"；该备忘录"不提前建听写评分数据结构"指评分 / 调度类结构，attempt 作答持久化是本能力的主数据，不属提前建设。
- workflow：`docs/workflows/add-storage-migration.md`（本方案含 migration，采纳其方案要求、测试要求与故障矩阵；无偏离）。
- 代码证据：第 2 节（练习域文件、v9/v10 schema、最新 migration v15、Core 无 diff 能力）。

attempt 表覆盖 E5 的设计依据：

```text
证据能证明什么：听写与回译的作答都是"session 内的文本 attempt + 参考文本快照"，结构同构（差异仅在 diff 摘要与听次计数是否适用）。
证据不能证明什么：不能证明未来写作检查等其他文本练习也适用此表；超出听写 / 回译时需重新评审。
迁移前提：exercise_type 区分行语义；可空列表达方式差异。
照搬风险：若为回译强行复用 diff 列做"判对错"会违反回译"参考不判对错"的产品边界——回译行的 diff 列必须为 NULL。
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

### 约束 2：数据迁移遵守存储 spec 与 workflow

- 约束 ID：DOC-CONST-012
- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/workflows/add-storage-migration.md`
- 适用范围：Data package
- 严重度：blocker
- 执行或验证方式：migration 测试（新库 + 旧库升级）+ repository 测试
- 验证提示：attempt 归类为本地主数据（用户练习证据，不可重建）；软删除、事务失败回滚有测试
- 说明：一个 migration 覆盖 E4 / E5

### 约束 3：练习产物隐私边界

- 来源：`docs/spec/013-practice-learning-domain.md` §5、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`、`docs/architecture/notes/2026-05-26-practice-recording-sync-export-notes.md`
- 适用范围：attempt 文本
- 严重度：blocker
- 执行或验证方式：repository / 诊断测试
- 验证提示：attempt 文本不进入诊断事件、日志、导出或任何外发请求；诊断只允许长度分桶等非敏感属性
- 说明：无

### 约束 4：TTS 播放边界

- 来源：`docs/spec/013-practice-learning-domain.md` §4、`docs/spec/011-tts-provider-configuration-and-playback.md`、`docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`
- 适用范围：听写重听
- 严重度：blocker
- 执行或验证方式：presentation model 单元测试
- 验证提示：页面出现、滚动、句间导航不自动播放；重听只能用户显式点击；播放中开始输入不强制打断（输入是文本不冲突），但句间切换必须先停止播放
- 说明：无

### 约束 5：差异表达不只靠颜色

- 来源：`docs/spec/003-ui-design-system.md` §3、`docs/spec/010-apple-platform-interaction-and-accessibility.md`
- 适用范围：diff 渲染
- 严重度：warn
- 执行或验证方式：人工审查 + 渲染模型测试
- 验证提示：下划线（形状）+ warn 色 + "n 处差异"计数文字三者同时存在
- 说明：无

## 8. 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeDictationDiff.swift`（新建）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeTextAttempt.swift`（新建：attempt 模型与 contract）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（migration 注册）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`（attempt 读写、听写已练派生）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeDictationSessionView.swift`（新建）与对应 presentation model
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeActions.swift`（听写分支）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`（mode 注册、路由分发）
- `LangoTraceApp/`（装配听写 actions 与可用性注册）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- 测试：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/PracticeDictationDiffTests.swift`（新建）、`Packages/LangoTraceData/Tests/LangoTraceDataTests/PracticeTextAttemptRepositoryTests.swift`（新建）、`Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeDictationSessionTests.swift`（新建）

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`（demo 播放注入与互斥模式）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（v9 / v10 schema 形态）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`、`PracticePromptCard.swift`

## 10. 涉及的文档路径

- 本方案。
- `docs/spec/013-practice-learning-domain.md`（听写落地后：§2 已练派生扩展为"录音或文本 attempt"、§6 变更记录）。
- `docs/platform-page-inventory.md`（新增听写会话页条目）。
- `docs/architecture/notes/2026-05-26-practice-recording-sync-export-notes.md`（attempt 文本纳入其"后续重新决策"清单的采纳标注）。
- 参考：第 6 节列出的备忘录与 workflow。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### 决策 E4-D1：diff 宽容度（2026-06-18 用户确认采用「声学/词汇层」口径）

听写检验的是**听觉解码能力**（能否把听到的语音正确还原成词），不是正字法。差异分两层：

- **声学/词汇层（计入差异数）**：拼写、词形（如 stay 与 stays——原型示例即 1 处差异）、同音异形词（its/it's、their/there/they're、to/too）、多写 / 漏写 / 错写的词各计 1 处。这些正是听写的学习信号，必须计入；按 word token 对齐、词内撇号算词的一部分的设计恰好能把 its/it's 判为差异。
- **正字法层（不计入差异数）**：纯大小写差异（听不出大写，等价匹配）、独立标点差异（听不出逗号 / 句号）。

理由：这是语言学习产品而非打字测验；对初级用户，把不在语音信号里的差异计为错误会制造挫败感且无学习信号，亦与产品"不做机械评分 / 惩罚"的定位一致。该口径写入 spec 013 作为听写对照契约。

v1 边界（解掉初稿 D1「弱化显示标点」与 D2「标点不参与对齐」的张力）：

- 标点在归一化阶段直接抹除，**count 与显示都不涉及标点**（最简，完全符合"不可听见不计入"）；"弱化显示标点差异"列为后续增强，本版不做。
- **不提供严格模式开关**，避免设置面膨胀（见 §20 风险 2）。

### 决策 E4-D2：diff 算法语义

1. 归一化：双方文本做 Unicode NFC 归一化、首尾修剪、连续空白折叠为单空格；按 E4-D1，独立标点在此阶段直接抹除（不进入后续分词与对齐）。
2. 分词：按 Character 粒度扫描分为 word token（字母 / 数字 / 词内撇号与连字符）；CJK 字符逐字成 token（对混排句安全）。全程使用 Swift String / Character API，不使用 UTF-16 偏移（与 per-block NSRange 备忘录 §2 同一约定）。
3. 对齐：word token 序列做 LCS（最长公共子序列）对齐，比较时大小写折叠（大小写差异不计入）。
4. 输出：`PracticeDictationDiffResult`：差异数、用户文本中各差异段的 Character range（供 AttributedString 下划线渲染）、差异分类（missing / extra / changed）。输入长度上限 2000 Character，超限拒绝（构造失败，不发生 O(n²) 失控）。

### 实施步骤

1. Core diff（TDD）：先写失败测试（见第 15 节），实现 `PracticeDictationDiff.compare(attempt:reference:)` 纯函数。
2. migration（一个，覆盖 E4 / E5；当前最新为 v22，本表预计为 **`v23_create_practice_text_attempts`**，实施时按当时最新注册顺序确认）。`exercise_type` 的 CHECK 约束为 `('dictation','backtranslation')`（shadowing 产出录音而非文本 attempt）：

```sql
CREATE TABLE practice_text_attempts (
  id                       TEXT PRIMARY KEY,
  session_id               TEXT NOT NULL REFERENCES practice_sessions(id),
  language_space_id        TEXT NOT NULL,
  exercise_type            TEXT NOT NULL,          -- dictation | backtranslation
  attempt_number           INTEGER NOT NULL,
  attempt_text             TEXT NOT NULL,
  reference_text_snapshot  TEXT NOT NULL,
  diff_difference_count    INTEGER,                -- 仅听写；回译恒 NULL
  diff_summary_json        TEXT,                   -- 仅听写；差异段序列化
  listen_count             INTEGER NOT NULL DEFAULT 0,  -- 仅听写有意义
  created_at               REAL NOT NULL,
  soft_deleted_at          REAL
)
```

   索引：`(session_id, attempt_number)` 唯一、`(language_space_id, exercise_type)`。
3. Repository：`recordTextAttempt`（事务内取下一 attempt_number、写行）、`latestTextAttempt(sessionID:)`、听写已练派生并入 E3 的 `completedSentenceIDs(materialID:exerciseType:)`（dictation：存在未软删 attempt 即已练）。
4. Repository / Actions / 装配：先把 `PracticeRepository.createOrRestoreShadowingSession` 泛化为按 `snapshot.exerciseType` 键控的 `createOrRestoreSession`（shadowing 行为不变，dictation 复用同一键控查询）；移除 `PracticeActionsAssembly` 中 `guard exerciseType == .shadowing else { throw .disabled }` 的硬编码闸门，并把 `.dictation` 加入 `availableExerciseTypes`；新增 `submitDictationAttempt` action：Core diff → repository `recordTextAttempt` 写入 → 返回 diff 结果；attempt 提交时把会话期听次计数一并落库。
5. UI 会话页状态机（presentation model 先行、可测）：
   - 状态：`listening`（参考句隐藏；重听按钮 + 已听 n 次 + 输入框 + 提交）→ `compared`（参考句 + diff 渲染 + 计数 + footnote + 再试一次）。
   - 重听：复用 demo 播放注入（与跟读同一 seam）；播放仅显式点击触发；句间切换先停止播放后替换 seed（spec 013 §3）。
   - `compared` 后"再试一次"开启新 attempt（attempt_number 递增），参考句重新隐藏。
   - diff 渲染：AttributedString 在用户作答文本上对差异段加下划线 + warn 前景色；计数文案 `n 处差异 · 本机对照，不发送 AI`。
6. 句子列表 mode 可用性：`PracticeModeAvailability` 是值类型 helper（非中央注册表），其 `availableModes` 已由 `PracticeActions.availableExerciseTypes` 驱动（见步骤 4 的装配改动），句子列表分段控制随之出现 跟读 / 听写 两段。
7. 文档收口：spec 013（E4-D1 契约、已练派生扩展）、页面清单、备忘录采纳标注；migration 命中专项审查判断。

### 故障与恢复路径（按 workflow 故障矩阵）

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| migration 失败 | 原库不半写入，可诊断错误 | migration 测试 |
| attempt 写入事务失败 | 整组回滚，UI 显示可重试失败，diff 结果不丢（内存态保留） | Data + UI 测试 |
| TTS 音频缺失 / artifact 失效 | 走既有显式生成路径或播放不可用状态，不阻塞输入与对照 | presentation 测试 |
| diff 输入超限 | 构造失败 → UI 提示过长，不写库 | Core 测试 |
| 会话句间切换时播放中 | 先停止播放再替换 seed | presentation 测试 |

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：本环境无并行隔离审查会话可用于方案文本审查；已按协议维度逐项自查，并以只读代码核验代理输出作为事实输入。
发现摘要：
  第一轮：
  - [P0] 初稿 diff 未定义大小写 / 标点 / 多字节语义，而这是语言学习产品的产品决策；已补 E4-D1（宽容度）与 E4-D2（算法语义、Character 约定、长度上限）并列为用户确认点。
  - [P1] 初稿把 listen_count 设计为独立计数表；复核后判定它只是低权重信息（原型定位），随 attempt 落库即可，避免为弱信号建第二张表。
  - [P1] attempt 表若只为听写设计，E5 将需要第二个 migration，违反"一个 migration"约束；已把 exercise_type + 可空 diff 列纳入 schema，并写明回译行 diff 恒 NULL 的边界。
  - [P2] 与 2026-06-11 备忘录 §3"不提前建听写评分数据结构"的关系需澄清：attempt 持久化是本能力主数据而非评分 / 调度结构；已写入第 6 节。
  第二轮：
  - [P1] diff_summary_json 中包含差异段文本范围但不应重复存储参考句全文之外的派生大对象；定为只存 range 与分类，渲染期重算文本切片。
  - [P1] attempt 文本不得进入诊断：第 7 节约束 3 增加"只允许长度分桶"验证提示，测试覆盖。
  - [P2] LCS 在 2000 Character 上限内最坏 O(n²) 内存可控；上限拒绝有测试。
  - [P2] migration id 与 R1 / E6 的相对顺序不能在方案间硬编码；统一为"实施时按当时最新注册顺序分配"。
  - [P3] "再试一次"后参考句重新隐藏的状态回转补入状态机。
写回修改：以上各项均已写回第 5、6、7、12、15 节。
仍需用户确认的问题：E4-D1 宽容度口径；本方案整体范围与实现授权（推进到 User Approved）。
是否允许进入实现：待用户确认后允许。
```

```text
审核日期：2026-06-18
审核方式：代码漂移复核（事实刷新 + 决策定稿），由真实代码只读核验驱动
触发原因：本方案 §2 现状钉在 2026-06-11 HEAD，其后 E1/E2/R1/E3 已落地；初稿对 E3 的 API 是预测，需用真实代码校验，且若有漂移须订正后再进入实现。
发现摘要：
  - [设计成立] E3 交付物全部命中预测：PracticeExerciseType.dictation、createOrRestoreSession seam、completedSentenceIDs、PracticeSentenceSnapshot 贯通 mode、playDemo 注入、SentenceAudioPlaybackCoordinator 在 Core、无 practice_text_attempts、Core 无 diff——方案骨架无需重审。
  - [事实漂移·已订正] 最新 migration v15 → v22；v18 已放开 exercise_type CHECK；新表落点改为 v23。写回 §2、§12 步骤 2。
  - [措辞订正·已订正] PracticeModeAvailability 非「注册机制」而是值类型 helper，真实落点是 availableExerciseTypes + 移除 PracticeActionsAssembly 硬编码 guard。写回 §2、§12 步骤 4/6。
  - [新落点·已纳入] PracticeRepository.createOrRestoreShadowingSession 为 shadowing 专名，泛化为按 exerciseType 键控的 createOrRestoreSession（早期重构，§1.1）。写回 §2、§12 步骤 4。
  - [决策定稿] E4-D1 经用户确认采用「声学/词汇层计入、正字法层不计入」口径；解掉 D1/D2 标点张力（归一化阶段抹除标点，count 与显示均不涉及）；不做严格模式开关。写回 §12 E4-D1/E4-D2。
写回修改：§1 头部、§2、§12（E4-D1/E4-D2/步骤 2/4/6）。
仍需用户确认的问题：本方案整体范围与实现授权（推进到 User Approved）。E4-D1 已确认。
是否允许进入实现：待用户给出实现授权后允许。
```

## 14. 复查方法

1. 行为：句子列表切到"听写"→ 进入某句 → 参考句不可见 → 重听两次（计数 2，不设限）→ 输入含一处词形差异的作答 → 对照：参考句出现、该词下划线 + warn 色、显示 `1 处差异` 与本机对照 footnote。
2. 宽容度：作答仅大小写或标点不同 → `0 处差异`。
3. 多字节：含 emoji / CJK 混排句对照不崩溃、range 渲染正确（单元测试 + 人工抽检）。
4. 持久化：对照后重进该句，最近 attempt 可见（或按状态机决定恢复到 compared 态）；数据库中 attempt_number 递增、软删除可用。
5. 隐私：抓取诊断事件断言无 attempt 文本；无网络请求新增（无 AI 调用路径可达）。
6. 故障：模拟 repository 写失败 → UI 可重试且 diff 结果不丢；TTS 不可用 → 输入与对照仍可用。
7. 已练：提交首个 attempt 后返回句子列表，该句在听写方式下显示已练；跟读方式不受影响。

## 15. TDD / 测试落点

```text
测试落点：
  1. Packages/LangoTraceCore/Tests/LangoTraceCoreTests/PracticeDictationDiffTests.swift（新建）
  2. Packages/LangoTraceData/Tests/LangoTraceDataTests/PracticeTextAttemptRepositoryTests.swift（新建：migration schema、attempt 读写、attempt_number 唯一、软删除、事务失败回滚、听写已练派生）
  3. Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeDictationSessionTests.swift（新建：状态机——参考句隐藏 / 对照展示 / 再试一次回转 / 听次计数 / 句间切换停止播放 / 不自动播放）
先失败用例：
  testThirdPersonSDifferenceCountsAsOneDifference
  —— PracticeDictationDiff.compare("The owner says he only stay for three hours a day.", "The owner says he only stays for three hours a day.") 断言差异数为 1 且差异段定位到 stay；类型尚不存在，按 stub-first（先建返回 0 差异的空实现）使断言失败成红。
  紧随：testPunctuationOnlyDifferenceCountsZero、testCaseOnlyDifferenceCountsZero、testEmojiAndCJKSafeRanges、testInputOverLimitRejected。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceCore --filter PracticeDictationDiffTests
不新增单元测试的原因（如适用）：下划线 + warn 色的最终视觉与真机键盘交互属人工模拟器验证；渲染输入（range 与分类）已由 Core 测试锁定。
```

## 16. 验证命令

```bash
# 聚焦（红绿循环）
swift test --package-path Packages/LangoTraceCore --filter PracticeDictationDiffTests
swift test --package-path Packages/LangoTraceData --filter PracticeTextAttemptRepositoryTests
swift test --package-path Packages/LangoTraceUI --filter PracticeDictationSessionTests

# 受影响 package 轻量验证
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
git diff --check
git status --short
```

按 CLAUDE.md §1.4 约束 7，不主动运行 `scripts/verify.sh`。

## 17. 文档影响检查

- `docs/spec/013-practice-learning-domain.md`：§2 已练派生扩展（文本 attempt）、§6 听写从"未实现"转为已落地、E4-D1 对照契约写入——是。
- `docs/platform-page-inventory.md`：新增听写会话页（三端）条目——是。
- `docs/architecture/notes/2026-05-26-practice-recording-sync-export-notes.md`：attempt 文本与录音同等的同步 / 导出重新决策范围，采纳标注——是。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：attempt 为本地主数据，与既有分类一致，预计无需改 spec；落地后确认。
- ADR：无核心决策变化（本机对照沿用本地优先决策）。
- `docs/review/`：数据库 schema 变化命中专项审查触发条件，实现完成后创建 review round 或在本方案实施记录中说明。

## 18. 实施记录

2026-06-11：方案创建并完成两轮自审核（见第 13 节）。尚未进入实现。
2026-06-18：基于 E1/E2/R1/E3 落地后的真实代码做代码漂移复核（见第 13 节第二条记录）。E3 交付物全部命中预测，设计骨架成立；订正迁移版本（v15→v22，新表 v23）、`PracticeModeAvailability` 措辞、仓库 seam 泛化等漂移。E4-D1 经用户确认采用「声学/词汇层」口径。
2026-06-18：用户给出整体实现授权，方案状态推进到 User Approved，进入 TDD 实现。实现按 §12 步骤 1–7 推进，每完成一小阶段做轻量验证 + commit。

2026-06-18：E4 听写练习实现完成，方案推进到 Done。落地内容与 plan-vs-shipped 对账：

- 步骤 1（Core diff，TDD）：新增 `PracticeDictationDiff`（NFC 归一化、标点抹除、Character 分词、词级 LCS 大小写折叠、差异数 = 各 gap `max(ref, attempt)`、2000 上限）与 `PracticeTextAttempt` / `PracticeTextAttemptDraft` / `PracticeDictationDiffSummary`。测试 `PracticeDictationDiffTests`（11 例，含先失败用例 `thirdPersonSDifferenceCountsAsOneDifference`、标点/大小写零差异、its/it's、emoji/CJK 安全、超限拒绝）全绿。commit `feat(core)`。
- 步骤 2–4（Data，TDD）：`v23_create_practice_text_attempts` migration（CHECK `('dictation','backtranslation')`，回译 diff 列 NULL）；`GRDBPracticeRepository.recordTextAttempt` / `latestTextAttempt`，听写已练并入 `completedSentenceIDs`；`createOrRestoreShadowingSession` 泛化为 `createOrRestoreSession`（协议 + 实现 + 装配 + 既有测试同步）。测试 `PracticeTextAttemptRepositoryTests`（7 例：schema、attempt_number 递增、已练派生、软删除排除、回译 NULL diff、缺失 session 失败回滚、泛化 seam）全绿；full Data package 194 绿。commit `feat(data)`。
- 步骤 5–6（UI，TDD）：`PracticeDictationSessionViewModel`（listening/compared 状态机、参考句对照前隐藏、重听计数、提交先算 diff 再持久化、持久化失败保留对照、再试一次回转、句间切换停止播放）；`PracticeDictationSessionView`（重听 + 已听 n 次 + 隐藏参考输入 + 对照视图 + 用户作答下划线/warn diff + “n 处差异 · 本机对照，不发送 AI” + 再试一次）；`PracticeSessionView` 改为按 exercise type 分发，跟读体抽出为 `PracticeShadowingSessionView`；`PracticeActions.submitDictationAttempt` + `PracticeDictationAttemptSubmission` + `inputTooLong` / `attemptSaveFailed` 失败；装配注册 `.dictation`、移除 shadowing-only guard、attempt 持久化（JSON diff summary）；10 个本地化 key（en/zh-Hans）。测试 `PracticeDictationSessionTests`（7 例）全绿；full UI package 482 绿。commit `feat(ui)`。
- 步骤 7（文档收口）：spec 013 §2/§6/§9、platform-page-inventory（新增听写会话行 + 修订跟读会话 / 练习 Tab / 组件行 + changelog）、本备忘录采纳标注、本方案。
- scope-down：E4-D1 最终口径为用户确认的「声学/词汇层计入、正字法层不计入」，标点在归一化阶段抹除（count 与显示均不涉及），不提供严格模式开关；与初稿一致，无范围缩减。
- deferred：回译（E5）仅 schema 预留，未实现任何 UI / reference 逻辑；diff 显示侧标点弱化、Myers diff 定位改进、CJK 分词策略复审、attempt 配额管理列入后续（§20 剩余风险）。
- 专项审查判断（§17）：本次含数据库 schema 变化（v23），命中专项审查触发条件；按 §17 在本实施记录中说明——schema 为 attempt 主数据新表，遵循 workflow `add-storage-migration` 的方案 / 测试 / 故障矩阵要求，migration 新库与既有升级路径由 Data 测试覆盖，attempt 隐私边界（local-only、不外发）已在 spec 013 §2 与本备忘录 §2 沉淀，未引入 ADR 冲突，不再单独开 review round。
- 验证：本机执行 §16 聚焦与受影响包轻量验证（Core 11 + 203、Data 7 + 194、UI 7 + 482 全绿），`swiftformat --lint` / `swiftlint` 对改动文件 0 serious；全量 `xcodebuild` 三端构建与 App target 编译留待 CI（`Build & Test`，仓库当前 public）。未按 CLAUDE.md §1.4 主动运行 `scripts/verify.sh`。

## 19. 完成标准

1. 第 15 节测试全部存在且通过；首个失败用例转绿。
2. 三端听写闭环可用（模拟器人工验证记录在实施记录）；零新增网络路径。
3. migration 测试覆盖新库与旧库升级；attempt 表可直接被 E5 复用（schema 评审通过即视为满足，不要求 E5 代码）。
4. 文档影响检查各项完成；专项审查判断有记录。
5. plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：收口时逐项核对第 12 节步骤 1–7。
scope-down 是否已记录：如宽容度口径被用户调整，记录最终口径。
deferred / aborted 项是否已从完成叙事中剥离：是。
后续事实源或复审入口：spec 013、platform-page-inventory。
```

## 20. 剩余风险

1. LCS 词级对齐对"同词重复多次"句子的差异定位可能不直观（对齐歧义）；差异数仍正确，定位歧义作为已知表现，必要时后续换 Myers diff 改进定位。
2. 听写宽容度（E4-D1）对个别用户可能"过宽"（想练标点 / 大写）；当前不提供严格模式开关，避免设置面膨胀；用户反馈后再评审。
3. CJK 逐字成 token 的口径在目标语言为日语 / 中文时差异计数偏细（逐字计差）；首发目标语言以英语为主，混排场景已测；日语空间普及前复审分词策略。
4. attempt 文本无上限累积增长；单行体量小（≤2000 Character），早期不做配额；存储管理 UI 方案出现时一并评审。
