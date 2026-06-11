# 任务方案：回译练习（本地参考对照 + 可选 AI 点评）

状态：Draft
自审核状态：Reviewed
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-11

系列编号：E5（系列母方案：`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`，实施顺序位于 E4 之后；Slice 2 必须晚于 E6）。规模：M。

前序依赖：

- Slice 1：E4（`docs/plans/active/2026-06-11-feature-practice-dictation.md`，`practice_text_attempts` 表与 mode 会话承载结构）。
- Slice 2：E6（`docs/plans/active/2026-06-11-feature-ai-request-preview-and-log-foundation.md`，请求预览投影与 ai_request_logs 基础）。

## 用户确认记录

本方案在 2026-06-11 系列母方案（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）的用户授权下创建。该授权仅覆盖"制定方案文档"本身；本方案进入生产代码实现前，仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。Slice 2 涉及把用户作答发送给 AI Provider（新增 Prompt 与请求路径），属于隐私敏感能力，用户确认记录中应单独写明对 Slice 2 的授权。

## 1. 需求或 bug 描述

按 `prototypes/iphone/practice-backtranslation.html` 的目标设计实现回译练习方式，分两个切片：

Slice 1（纯本地）：

1. 题面只给母语原意（中文原意），不预先露出目标语言参考。
2. 用户写下自己的目标语言表达。
3. 点"对照参考"展开参考表达：来自已有 LearningMaterial 句子分析的参考句与说明（如 said / says 时态差异说明），鼓励"意思贴近即可"，不判对错、不做机械评分（原型明确的产品文案边界）。
4. 作答持久化复用 E4 的 `practice_text_attempts` 表（exercise_type = backtranslation，diff 列恒 NULL），零网络。

Slice 2（可选 AI 点评）：

5. "请 AI 点评"是显式触发的可选第二步动作，按钮下方 footnote 提前披露发送范围与时机（"点评会把你的作答发送给已配置的 AI Provider，仅在你点击时发送"）；绝不自动触发。
6. 新 Prompt 按 `docs/workflows/add-prompt.md` 登记到 `docs/prompts/`（英文 canonical + 中文审阅版 + 输入变量 + 输出契约 + 隐私边界）。
7. 请求接入 E6 的预览投影与请求日志基础。

## 2. 现状描述

以下事实已对照 2026-06-11 HEAD 核验：

- E3 / E4 落地后（本方案前置事实）：`PracticeExerciseType.backtranslation` case 已存在（E3）、mode 路由与会话承载结构就绪（E3 / E4）、`practice_text_attempts` 表已建且 schema 含 exercise_type 与可空 diff 列（E4）。
- 参考表达数据已存在于 GRDB learning content 主路径：`LearningSentenceAnalysis`（`Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift:325-354`）含 `nativeSentence`、`targetSentence`、`literalTranslation`、`naturalTranslation`、`grammarNotes`、`keyPoints`；`PracticeSentenceSnapshot` 已携带 `translationSnapshot`（母语原意题面）与 `noteSnapshot`。
- 句子分析的读取路径：`GRDBLearningContentRepository`（Data package）已有按 material 读取 analysis 的能力（learning content 主路径，spec/learning-content/impl.md）。
- AI 请求执行现状：学习材料生成走 `LearningMaterialGenerationService`（`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`），阅读解释走 `ReadingSelectionExplanationService`（同目录）；两者都有 Prompt registry + 结构化输出 schema + parser + 失败分类的成熟模式。`docs/prompts/` 已有 learning-material 与 reading 两个登记目录。
- 当前不存在任何回译 UI、回译 Prompt 或"AI 点评"请求路径。
- 隐私基线：`docs/spec/013-practice-learning-domain.md` §6——"回译参考表达如需新 AI 请求，必须遵守 spec 005 的显式触发与请求边界"；`docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md` §2.3——回译参考来源（已有翻译 vs 新 AI 请求）是需要重新决策的点。

## 3. 目标

Slice 1：

1. 回译会话三态闭环：题面（母语原意）→ 作答 → 对照参考（展开 targetSentence + 既有分析说明），参考卡在用户点"对照参考"前保持隐藏。
2. 参考展示不判对错：无评分、无差异计数、无对错标记；说明文案来自既有分析（grammarNotes / keyPoints / note），不再生成新内容。
3. 作答写入 `practice_text_attempts`（backtranslation 行 diff 列恒 NULL）；回译"已练"由已提交 attempt 派生，接入 E3 已练集合查询。
4. 全程零网络：对照参考是本地只读动作。

Slice 2：

5. "请 AI 点评"显式触发：发送内容仅限——母语原意、用户作答、参考句、目标语言 code、水平 code；不发送整条 Entry、其他句子、历史记忆、照片或附件。
6. 新 Prompt `builtin.practice.backtranslation_review.v1` 登记于 `docs/prompts/practice/backtranslation-review.md`，AI package 实现 registry + 结构化输出 schema + parser + 失败分类。
7. 请求接入 E6：发送前可查看"将发送内容"预览投影；完成后写入 ai_request_logs 非敏感日志。
8. 点评结果为短生命周期 UI 状态（不持久化点评正文，第一版与阅读解释纵向切片同口径）。

## 4. 范围

- Slice 1：
  - UI package：回译会话视图与 presentation model（复用 E4 会话承载结构与句间导航）、`PracticeModeAvailability` 注册 `.backtranslation`、actions 的回译分支（session 创建 / attempt 提交 / 参考读取）、本地化 key。
  - Data package：参考表达读取 seam（按 materialID + sentenceID 返回该句 `LearningSentenceAnalysis` 投影；如 `GRDBLearningContentRepository` 已有等价查询则复用）、回译 attempt 已练派生。
  - App Shell：装配回译 actions。
- Slice 2：
  - AI package：`PracticeBacktranslationReviewService`（新建，沿用既有 service 模式）、Prompt registry、schema、parser、失败分类。
  - UI package：点评按钮 + footnote 披露 + 请求状态（进行中 / 结果 / 失败 / 取消）+ E6 预览入口接线。
  - 文档：`docs/prompts/practice/backtranslation-review.md`（新建）、`docs/prompts/README.md` 登记。

## 5. 不做什么

- 不做机械评分、对错判定、相似度打分或星级：本地对照与 AI 点评都不输出"判对错"结论性评分（原型产品边界："参考不判对错"）。
- 不为参考表达发起任何新 AI 请求（Slice 1 决策 E5-D1）：参考只来自已有 LearningMaterial 分析；该句无分析时引导回记录详情走既有"生成学习材料"显式路径，不在练习页内嵌生成。
- 不自动触发 AI 点评：不在对照、输入停顿、句间导航或任何非点击时机发送；不做"自动点评开关"。
- 不持久化 AI 点评正文（第一版短生命周期 UI 状态；持久化需独立评审派生学习结果表）。
- 不把作答或点评纳入同步、默认导出、备份或诊断日志正文。
- 不新增 migration：复用 E4 的 `practice_text_attempts`。
- 不做回译的 TTS 朗读、语音作答输入或参考句多版本生成。
- Slice 2 不扩展到 Anthropic / Gemini 专属请求格式：沿用当前 OpenAI-compatible 请求边界（与学习材料生成一致），其他 Provider 返回明确暂不支持。

## 6. 证据与决策依据

- 原型：`prototypes/iphone/practice-backtranslation.html`（题面只给中文原意、对照参考为本地只读动作、参考不判对错、AI 点评显式触发 + footnote 披露、共享句子快照与 seed）。
- spec：`docs/spec/013-practice-learning-domain.md` §5（单句页只读取已有 LearningMaterial 翻译 / note，不新增 AI 语法分析请求——Slice 1 严格遵守）、§6（回译新 AI 请求必须走 spec 005 显式触发边界——Slice 2 的依据）；`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.3（请求预览与同意级别）、§4.4（日志允许字段）、§4.6（失败分类）。
- 架构备忘录：`docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md` §2.3——"回译参考表达的来源"决策点在此落定：Slice 1 用已有 LearningMaterial 翻译（采纳），新 AI 请求仅作为 Slice 2 可选点评且走显式触发 + 预览边界（采纳）。
- workflow：`docs/workflows/add-prompt.md`（Slice 2 新 Prompt 全量采纳：完整英文 canonical、中文审阅版、变量、输出契约、隐私边界、registry 测试）；`docs/workflows/add-ai-provider.md`（新增 AI 能力入口的测试要求与故障矩阵，采纳）。
- 代码证据：第 2 节（`LearningSentenceAnalysis` 字段、`PracticeSentenceSnapshot` 题面来源、既有 AI service 模式）。

```text
证据能证明什么：回译所需的题面与参考数据在既有 learning content 主路径中已经存在，Slice 1 可零网络成立。
证据不能证明什么：不能证明 AI 点评在用户自带各类模型上的输出质量稳定；点评是软质量能力，不进入判定性结论。
迁移前提：该句存在已生成的 LearningMaterial 分析；无分析句子在回译方式下显示"先生成学习材料"的引导态。
照搬风险：原型参考说明文案是示例语料，不能硬编码；实际说明必须来自该句真实分析字段。
```

## 7. 约束映射与验证路径

### 约束 1：实现前 active plan + 用户确认 + 自审核

- 约束 ID：DOC-CONST-001 / DOC-CONST-002 / DOC-CONST-003
- 来源：`docs/README.md` §4.16、`docs/plans/plan-review-protocol.md` §2、`docs/plans/README.md` §4
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查状态字段
- 验证提示：Slice 2 的实现授权须在用户确认记录中单独可见
- 说明：无

### 约束 2：用户敏感内容只在显式触发时发送 Provider

- 约束 ID：DOC-CONST-014
- 来源：`docs/README.md` §4.10、`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.3、`docs/spec/013-practice-learning-domain.md` §6
- 适用范围：Slice 2
- 严重度：blocker
- 执行或验证方式：service / store 单元测试（无点击不构造请求）+ 人工审查触发链路
- 验证提示：点评请求只能由"请 AI 点评"按钮触发；对照、输入、导航路径不可达请求构造
- 说明：无

### 约束 3：Prompt 登记与结构化输出

- 约束 ID：DOC-CONST-013
- 来源：`docs/workflows/add-prompt.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.7（结构化 JSON、拒绝半成品输出）
- 适用范围：Slice 2 AI package + docs/prompts
- 严重度：blocker
- 执行或验证方式：registry / parser 单元测试 + `docs/prompts/README.md` 登记检查
- 验证提示：parser 拒绝自然语言前后缀、缺字段、非法枚举、额外字段；半成品不进入任何持久层
- 说明：无

### 约束 4：请求元数据与日志脱敏

- 来源：`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.4、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- 适用范围：Slice 2 日志与诊断
- 严重度：blocker
- 执行或验证方式：单元测试断言日志属性集合
- 验证提示：只记录 Prompt id / version、Provider / model、长度分桶、失败分类、耗时；不记录作答、原意、参考句、点评正文
- 说明：写入 E6 的 ai_request_logs 时同样适用

### 约束 5：不判对错的产品文案边界

- 来源：原型 `prototypes/iphone/practice-backtranslation.html` 设计说明 + `docs/spec/003-ui-design-system.md` §3（重要状态明确表达）
- 适用范围：参考卡与点评结果 UI
- 严重度：warn
- 执行或验证方式：本地化 key 审查 + Prompt 输出契约约束
- 验证提示：UI 与 Prompt 输出契约均不出现 正确 / 错误 / 得分 类判定字段；点评输出字段为观察与建议性结构
- 说明：Prompt schema 直接不提供判定字段，从契约层防住

## 8. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeBacktranslationSessionView.swift`（新建）与 presentation model
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeActions.swift`（回译分支：attempt 提交、参考读取、点评触发）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`（mode 分发）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`（如需新增按句分析投影查询）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`（回译已练派生）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/PracticeBacktranslationReviewService.swift`（新建，Slice 2）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/`（点评输入 / 结果 / 失败分类模型，Slice 2）
- `LangoTraceApp/`（装配）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- 测试：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeBacktranslationSessionTests.swift`（新建）、`Packages/LangoTraceData/Tests/LangoTraceDataTests/PracticeTextAttemptRepositoryTests.swift`（扩展回译用例）、`Packages/LangoTraceAI/Tests/LangoTraceAITests/PracticeBacktranslationReviewServiceTests.swift`（新建，Slice 2）

## 9. 参考的代码文件路径

- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`、`ReadingSelectionExplanationService.swift`（service / registry / parser 模式）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift`（`LearningSentenceAnalysis` 字段）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift`（snapshot 题面字段）
- E4 交付的 `PracticeTextAttempt` 模型与 repository

## 10. 涉及的文档路径

- 本方案。
- `docs/prompts/practice/backtranslation-review.md`（新建，Slice 2）与 `docs/prompts/README.md` 登记。
- `docs/spec/013-practice-learning-domain.md`（回译落地后 §5/§6 变更记录；Slice 2 把"回译新 AI 请求"从边界提醒转为已落地事实）。
- `docs/platform-page-inventory.md`（回译会话页条目）。
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`（§2.3 参考来源决策的采纳标注）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### 决策 E5-D1：参考表达来源

Slice 1 参考卡内容 = 该句 `targetSentence`（参考句）+ `naturalTranslation` / `literalTranslation`（必要时）+ `grammarNotes` / `keyPoints`（说明），全部来自该句已有 `LearningSentenceAnalysis`；snapshot 的 `noteSnapshot` 作为兜底说明。无分析的句子在回译方式下显示引导态（去记录详情生成学习材料），不内嵌生成请求。

### 决策 E5-D2：点评发送范围（Slice 2）

发送字段固定为：`native_sentence`（母语原意）、`user_attempt`（用户作答）、`reference_sentence`（参考句）、`target_language_code`、`proficiency_level_code`。不发送 Entry 其余正文、其他句子分析、历史 attempt、点评历史或任何附件。按 spec 005 §4.3 属"发送当前用户主动输入的短文本 + 单句上下文"，配合 footnote 披露与 E6 预览，采用非阻断确认（与学习材料生成同级别）。

### Slice 1 步骤

1. 先写失败测试（见第 15 节）：回译 presentation model 三态（answering → revealed）与参考卡隐藏边界。
2. presentation model：`answering`（题面 = `translationSnapshot`；输入框；"对照参考"在作答非空后可用）→ `revealed`（参考卡展开 + "请 AI 点评"入口位（Slice 2 前不渲染）+ 再试一次）。参考卡渲染输入来自 E5-D1 投影。
3. Data：按 materialID + sentenceID 的分析投影查询（如已有等价查询则复用并加测试）；attempt 写入复用 E4 repository（exercise_type = backtranslation、diff 列 NULL——repository 层断言听写专用列不被回译路径写入）；回译已练派生并入 `completedSentenceIDs`。
4. actions / 装配：`createOrRestoreSession` 的 `.backtranslation` 分支；`submitBacktranslationAttempt`（写 attempt + 返回参考投影）；注册 `.backtranslation` 到 `PracticeModeAvailability`（分段控制三段齐全）。
5. 本地化：题面标签（中文原意 / 你的表达 / 参考表达）、引导态、"参考表达不止一种，意思贴近即可"等文案 key。

### Slice 2 步骤（E6 落地后）

6. Core 模型：`PracticeBacktranslationReviewInput / Result / FailureCategory`（失败分类对齐 spec 005 §4.6 与 E0a 错误分类整备）。
7. Prompt：`builtin.practice.backtranslation_review.v1`，schema `practice_backtranslation_review.v1`。输出契约（结构化 JSON，无判定字段）：`acknowledgement`（作答中成立之处）、`observations[]`（差异观察：现象 + 解释，上限条数）、`suggestions[]`（更自然表达建议，上限条数）、`register_note`（语体 / 时态等说明，可空）。解释语言遵循语言空间水平派生的解释语言模式（复用 `ExplanationLanguageMode` 派生，作为 Prompt 输入变量）。
8. AI service（TDD）：registry 渲染测试（变量齐全、不含未授权内容）、parser 测试（拒绝缺字段 / 额外字段 / 自然语言前后缀）、取消与失败分类测试；HTTP 走既有生产 client 边界。
9. UI：点评按钮 + footnote（提前披露发送范围与时机）+ E6 预览入口；状态机：idle → previewable → sending → reviewed / failed / cancelled；取消终止任务且不写失败日志事件（与既有取消语义一致）。
10. 接入 E6：发送前预览投影（capability = practice_backtranslation_review）；完成 / 失败 / 取消写 ai_request_logs 非敏感行。
11. 文档：Prompt 文档 + README 登记 + spec 013 变更记录。

### 故障与恢复路径

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| 该句无 LearningMaterial 分析 | 回译方式显示引导态，不崩溃、不发请求 | presentation 测试 |
| attempt 写入失败 | 回滚 + UI 可重试，作答文本保留在输入态 | Data + UI 测试 |
| Provider 未配置 / Key 缺失（Slice 2） | credential missing 可恢复状态，按钮态明确 | service 测试 |
| 点评返回非法 JSON | 拒绝解析，显示可重试失败，不写持久层 | parser 测试 |
| 用户取消点评 | 任务终止，无失败事件，状态回 revealed | store 测试 |
| 模型不支持（非 OpenAI-compatible） | 明确"暂不支持"分类，不伪装网络失败 | service 测试 |

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：本环境无并行隔离审查会话可用于方案文本审查；已按协议维度逐项自查，并以只读代码核验代理输出作为事实输入。
发现摘要：
  第一轮：
  - [P0] 初稿未定义"句子没有 LearningMaterial 分析"时的回译行为；已定为引导态（去生成学习材料），不内嵌生成请求，写入 E5-D1 与故障矩阵。
  - [P1] 初稿点评输出契约含 quality 评级字段，与"参考不判对错"产品边界冲突；已改为无判定字段的观察 / 建议结构，并升级为约束 5（从契约层防住）。
  - [P1] 点评解释语言初稿未定义；复用已落地的 ExplanationLanguageMode 派生作为 Prompt 输入变量，避免第二套语言模式概念。
  - [P2] Slice 1 / Slice 2 的依赖边界初稿含混；明确 Slice 1 仅依赖 E4、Slice 2 依赖 E6，且 Slice 2 授权须单独可见。
  第二轮：
  - [P1] repository 需要防止回译路径误写听写专用列（diff / listen_count）；已加入第 12 节步骤 3 与测试落点。
  - [P1] 取消语义需与既有"取消不写失败事件"一致；已写入步骤 9 与故障矩阵。
  - [P2] Prompt 输出条数需上限（observations / suggestions）防超长响应；已写入输出契约。
  - [P3] 原型示例说明文案不得硬编码；写入证据边界"照搬风险"。
写回修改：以上各项均已写回第 5、6、7、12、15 节。
仍需用户确认的问题：Slice 1 与 Slice 2 分别的实现授权（Slice 2 涉及作答外发）；E5-D2 发送范围口径。
是否允许进入实现：待用户确认后允许。
```

## 14. 复查方法

1. Slice 1 行为：句子列表切"回译"→ 题面只见中文原意 → 作答 → 对照参考：参考卡展开且内容来自该句真实分析；全程抓包 / 测试断言无网络请求。
2. 无分析句子：回译方式显示引导态，可导航回记录详情。
3. 持久化：attempt 行 exercise_type = backtranslation、diff 列 NULL；回译已练状态独立于跟读 / 听写。
4. Slice 2 行为：点评按钮下 footnote 可见 → 点击后（经 E6 预览路径）发送 → 结果按契约渲染、无判定文案；取消后状态回 revealed 且无失败日志。
5. 隐私：registry 渲染测试断言 Prompt 内容仅含 E5-D2 五字段；日志测试断言无作答正文。
6. 故障矩阵逐项触发验证（第 12 节表格）。

## 15. TDD / 测试落点

```text
测试落点：
  1. Packages/LangoTraceUI/Tests/LangoTraceUITests/Practice/PracticeBacktranslationSessionTests.swift（新建：三态状态机、参考卡隐藏、引导态、Slice 2 触发与取消）
  2. Packages/LangoTraceData/Tests/LangoTraceDataTests/PracticeTextAttemptRepositoryTests.swift（扩展：回译行写入、diff 列恒 NULL、已练派生）
  3. Packages/LangoTraceAI/Tests/LangoTraceAITests/PracticeBacktranslationReviewServiceTests.swift（新建，Slice 2：registry 渲染、schema、parser 拒绝路径、失败分类、取消）
先失败用例：
  testReferenceCardHiddenUntilUserReveals
  —— 构造回译 presentation model（含完整分析投影），断言初始 answering 态下参考投影不可见、reveal 动作后可见；presentation model 尚不存在，按 stub-first 建空模型使断言失败成红。
  Slice 2 先失败用例：testPromptContainsOnlyAllowedFields —— registry 渲染结果断言包含五个允许变量且不包含 entry 正文 / 其他句子文本。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceUI --filter PracticeBacktranslationSessionTests
  swift test --package-path Packages/LangoTraceAI --filter PracticeBacktranslationReviewServiceTests
不新增单元测试的原因（如适用）：点评真实输出质量依赖用户自带模型，无法 CI 自动化；以契约测试 + 人工抽检兜底（与学习材料生成同口径）。
```

## 16. 验证命令

```bash
# 聚焦（红绿循环）
swift test --package-path Packages/LangoTraceUI --filter PracticeBacktranslationSessionTests
swift test --package-path Packages/LangoTraceData --filter PracticeTextAttemptRepositoryTests
swift test --package-path Packages/LangoTraceAI --filter PracticeBacktranslationReviewServiceTests

# 受影响 package 轻量验证
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceUI

# 文档（含 Prompt 登记检查）
scripts/check-docs.sh
git diff --check
git status --short
```

## 17. 文档影响检查

- `docs/prompts/practice/backtranslation-review.md` 新建 + `docs/prompts/README.md` 登记（Slice 2）——是。
- `docs/spec/013-practice-learning-domain.md`：§5/§6 变更记录；Slice 2 落地后"回译新 AI 请求"边界转为已落地事实——是。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：新增能力沿用既有边界，预计无需改 spec 正文；若点评引入新的隐私判断（如发送范围调整）则必须更新——落地后确认。
- `docs/platform-page-inventory.md`：回译会话页条目——是。
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`：§2.3 决策采纳标注——是。
- ADR：无核心决策变化（显式触发 + 用户自带 Provider 沿用 ADR-005）。
- `docs/review/`：Slice 2 命中"AI Provider / 请求边界"专项审查判断，实现完成后按 `docs/review/README.md` 处理。

## 18. 实施记录

2026-06-11：方案创建并完成两轮自审核（见第 13 节）。尚未进入实现。

## 19. 完成标准

1. Slice 1：第 15 节测试 1–2 通过；三端回译本地闭环可用且零网络（人工验证记录）；分段控制三段齐全。
2. Slice 2：测试 3 通过；Prompt 文档完整登记（英文 canonical + 中文审阅版 + 变量 + 契约 + 隐私边界）；预览与日志接入 E6 验证通过。
3. 文档影响检查各项完成；Slice 2 专项审查判断有记录。
4. plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：按 Slice 分别核对。
scope-down 是否已记录：若 Slice 2 暂缓，本方案保持 active 并记录 deferred 决策日志，Slice 1 不得包装成全部完成。
deferred / aborted 项是否已从完成叙事中剥离：是。
后续事实源或复审入口：spec 013、docs/prompts/README.md、platform-page-inventory。
```

## 20. 剩余风险

1. 参考说明质量取决于既有学习材料生成质量；分析字段为空或质量差时参考卡信息量低——属上游能力质量问题，回译 UI 以可空渲染兜底。
2. 点评输出语言与质量随用户模型波动（与解释语言模式同源风险）；契约只能约束结构不能约束语言遵从，运行期不因语言漂移硬失败。
3. Slice 2 等待 E6 期间，revealed 态的点评入口位不渲染；若系列顺序调整导致 E5 全量先行，必须回到本方案重审 Slice 2 依赖（不允许绕过预览 / 日志直接发请求）。
4. 同句多次 attempt 的参考卡重复展开体验未深究（每次 reveal 内容相同）；可接受，后续记忆域沉淀能力再优化。
