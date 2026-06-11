# 任务方案：听写练习（本机对照闭环）

状态：Draft
自审核状态：Reviewed
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-11

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

以下事实已对照 2026-06-11 HEAD 核验：

- 练习域当前只有跟读闭环：`PracticeSessionView` / `PracticeSessionViewModel` / `PracticeControlBar` / `PracticePromptCard`（`Packages/LangoTraceUI/Sources/LangoTraceUI/`），录音走 `PracticeActions` → `GRDBPracticeRepository` + Speech `PracticeRecordingService`。
- E3 落地后：`PracticeExerciseType` 含 `dictation` case、seed / snapshot 贯通 mode、`PracticeModeAvailability` 注册机制就绪、actions seam 为 `createOrRestoreSession`（非 shadowing 当前返回 disabled）。本方案以 E3 的交付物为前置事实。
- TTS 示范播放：单句页"听示范"经 `PracticeSessionViewModel.playDemo` 注入的 playback 闭包，复用逐句 TTS playback coordinator 与 local artifact cache（spec 013 §4；`SentenceAudioPlaybackCoordinator.swift`、`SentenceTTSGeneration.swift` 在 Core）。TTS artifact 已有持久缓存（`tts_audio_artifacts` + `media_artifacts`）。
- 文本作答没有任何持久化设施：`practice_sessions` / `practice_recordings` / `practice_recording_artifacts` 都是录音导向（v9 / v10 migration）；没有 `practice_text_attempts` 或等价表。当前 Data 最新 migration 为 `v15_reset_reading_explanation_cache_for_unix_epoch`。
- Core 没有字符串 diff 能力。
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

### 决策 E4-D1：diff 宽容度（需用户确认）

听写检验的是"听"，不可听见的差异不计入差异数：

- 标点 token 差异不计入差异数（听不出逗号 / 句号），渲染时弱化显示。
- 纯大小写差异不计入差异数（听不出大写），等价匹配。
- 拼写 / 词形差异计入（如 stay 与 stays——原型示例即 1 处差异）；多写、漏写、错写的词各计 1 处。

理由：这是语言学习产品而非打字测验；对初级用户，把不可听见的差异计为错误会制造挫败感且无学习信号。该口径写入 spec 013 作为听写对照契约。

### 决策 E4-D2：diff 算法语义

1. 归一化：双方文本做 Unicode NFC 归一化、首尾修剪、连续空白折叠为单空格。
2. 分词：按 Character 粒度扫描分为 word token（字母 / 数字 / 词内撇号与连字符）与 punctuation token；CJK 字符逐字成 token（对混排句安全）。全程使用 Swift String / Character API，不使用 UTF-16 偏移（与 per-block NSRange 备忘录 §2 同一约定）。
3. 对齐：word token 序列做 LCS（最长公共子序列）对齐，比较时大小写折叠；punctuation token 不参与对齐计数。
4. 输出：`PracticeDictationDiffResult`：差异数、用户文本中各差异段的 Character range（供 AttributedString 下划线渲染）、差异分类（missing / extra / changed）。输入长度上限 2000 Character，超限拒绝（构造失败，不发生 O(n²) 失控）。

### 实施步骤

1. Core diff（TDD）：先写失败测试（见第 15 节），实现 `PracticeDictationDiff.compare(attempt:reference:)` 纯函数。
2. migration（一个，覆盖 E4 / E5；id 在实施时按当时最新注册顺序分配，需与 R1 的 migration 协调先后）：

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
4. Actions / 装配：`createOrRestoreSession` 的 `.dictation` 分支创建 / 恢复 `exercise_type = 'dictation'` 的 session（复用 E3 键控查询）；新增 `submitDictationAttempt` action：Core diff → repository 写入 → 返回 diff 结果；attempt 提交时把会话期听次计数一并落库。
5. UI 会话页状态机（presentation model 先行、可测）：
   - 状态：`listening`（参考句隐藏；重听按钮 + 已听 n 次 + 输入框 + 提交）→ `compared`（参考句 + diff 渲染 + 计数 + footnote + 再试一次）。
   - 重听：复用 demo 播放注入（与跟读同一 seam）；播放仅显式点击触发；句间切换先停止播放后替换 seed（spec 013 §3）。
   - `compared` 后"再试一次"开启新 attempt（attempt_number 递增），参考句重新隐藏。
   - diff 渲染：AttributedString 在用户作答文本上对差异段加下划线 + warn 前景色；计数文案 `n 处差异 · 本机对照，不发送 AI`。
6. 注册 `.dictation` 到 `PracticeModeAvailability`：句子列表分段控制出现 跟读 / 听写 两段。
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
