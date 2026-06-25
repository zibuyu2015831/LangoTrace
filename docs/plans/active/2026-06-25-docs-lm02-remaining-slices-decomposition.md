# 任务方案：LM02 后续切片拆解与排序（盲点 / Style / band 重估）

状态：In Progress（拆解 / 排序导航文档，非实现方案；不含生产代码变更）
自审核状态：N/A（决策 / 排序导航文档；各切片进入实现前各自按 plan-review-protocol 自审核）
类型：docs
创建日期：2026-06-25
最后更新日期：2026-06-25

## 这份文档是什么

[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 把学习者模型分 LM01 / LM02 / LM03。LM02 原是一个大桶，已切出 **Slice 1 = Memory 层地基 + 学习画像总览页**（`2026-06-25-feature-lm02-memory-layer-and-learner-profile-overview.md`，Draft/Reviewed）。本文件把 LM02 **剩余**工作（盲点 / Style / band 重估 + 跨切 AI 校准）拆成有界的后续切片，记清每片的**范围、硬前置、依赖、关键待决、风险、设计来源**与**排序**。

它**只做拆解与排序导航**，不是实现方案：

- 不替代各切片未来的 active plan；每片**进入实现前**仍须各自创建 active plan、按 [plan-review-protocol](../plan-review-protocol.md) 严格自审核、走用户确认链路。
- 不替代 ADR-006（权威决策）、idea-01 / idea-02（设计来源）、spec/007 或 LM02 Slice 1 方案。
- 不预先为未就绪能力创建 active plan（避免 active/ 堆积未就绪方案、违反 CLAUDE.md §9 克制）。

冲突时以 ADR-006 与各权威文档为准。

## 共同前置（所有后续切片）

1. **LM02 Slice 1 先落地**：总览页是盲点 / Style / band 呈现的归宿；Memory 层 + `LearnerProfileSnapshot` + `LearnerContextProvider` 扩展是它们的接入点。Slice 1 的 presentation model 已预留盲点分区。
2. **证据红线（ADR-006 §4）**：估水平 / 盲点只用**用户产出 / 行为**，AI 生成物（candidate difficulty、AI 学习文本、AI 点评 observations）一律禁用。
3. **纯本地优先**：本地启发式（零外发）不触发决策 #10，可先行；任何外发（AI 校准）= v2、opt-in、默认关闭、走 plan 09 预览 + 最小发送（ADR-006 §6 隐私前置闸门已升格权威，故 v2 已解锁但须 opt-in）。
4. **每片独立 active plan + 自审核**：本文件不授权直接实现。

## 切片拆解

### LM02-S2：Style 表层（写作风格本地启发式）

> **→ 已拆 active plan**：[`2026-06-25-feature-lm02-s2-style-surface-imprint.md`](2026-06-25-feature-lm02-s2-style-surface-imprint.md)（Draft / 自审 Reviewed，双轮）。**用户决策（2026-06-25）：do-now / seam-only，纳入本地优先第一批**（覆盖自审「推迟」推荐——自审曾指出 seam-only 当前无就绪消费者构成投机地基，风险已被用户接受）；展示默认**不展示**（§13.4 / 本节③）。关键代码核实纠偏：`entries.source` **不是**语言区分键（`targetLanguageWriting` 无写入器）、`LearningMaterialInputKind` 是 AI 生成物（§4 禁用）→ 语言判定改以 `NLLanguageRecognizer`-on-body 为唯一权威（须注入 detector seam 才可测）。持久化：v1 表层判可重算真派生、compute-on-read 不持久（对 ADR-006 §8「Style 准原始」的分层细化，须回写）。详见该 plan §12–§13 / §20。

- **范围**：Style 层 v1 = **表面写作风格**（句长 / 词汇丰富度 / 正式度等），本地启发式 / `NaturalLanguage`，系统级跨空间（ADR-006 §2/§3）。存入 LearnerModel Style 层；`LearnerContextProvider` 扩展 Style 受控片段读口（供总览页 + 语伴 v2）。
- **硬前置**：LM02-S1（Memory 层地基 + 包内 Style 容纳边界）。
- **依赖**：`NaturalLanguage`（仓库已可用，目前仅 `AIProviderLanguageSupportValidator` 用）；**源语言产出取信号**（ADR-006 §4 / idea-01 §13.4：目标语表达受能力限制，把「能力受限」误读成「风格选择」是同型闭环 → 目标语侧打低置信度）。
- **关键待决**：① Style 正式命名（Style / Voice / 表达印记，idea-01 §13.9）；② Style ↔ Ability 下投影档位映射（idea-01 §13.5：应用到目标语改写按 Ability i+1 下投影——但**下投影的消费者是语伴 / 改写，S2 只产出源语言印记**，下投影留 LM03 / 改写切片）；③ 是否在总览页**展示** Style（idea-01 §13.4：隐式用、不下侧写判决 → 倾向**不展示判决**，仅内部供给）。
- **风险**：低（零外发、本地启发式、无 derive() 触碰）。主要风险是「把风格判决展示给用户」越过「不下侧写」红线 → S2 默认不在画像页展示 Style 判决。
- **设计来源**：ADR-006 §2/§4，idea-01 §13.4 / §13.5 / §13.9。
- **触碰**：LearnerModel 包（Style 模型 + 本地分析 + provider 扩展）；可能 Core（NL 复杂度工具）。**不碰** derive()、不外发。
- **认知风格（观察角度 / 思维方式）= AI 校准 = v2**，见跨切 AI 校准，不在 S2。

### LM02-S3：盲点（常犯错误清单）

> **→ 已拆 active plan**：[`2026-06-25-feature-lm02-s3-blind-spots.md`](2026-06-25-feature-lm02-s3-blind-spots.md)（Draft / 第一轮自审 Reviewed）。**用户决策：纳入本地优先第一批**（与 S2 同期）。关键代码核实纠偏：① 行动闭环「加入记忆库」deposit **砍出 v1**（`memory_items` schema 仅接 candidate 来源 + difficulty NOT NULL，需独立 migration）→ v1 纯展示 + 跳复习；② 持久 `diff_summary_json` **无词文本**（仅 kind+offset）→ provider 须重跑 `PracticeDictationDiff.compare()` 取文本；③ `BlindSpotKind` 定稿 = `{missing,changed,extra}` 映射 SegmentKind；④ 效度诚实标注「重复练习错误模式（来自听写）」、信号仅 dictation。详见该 plan §12–§13 / §20。

- **范围**：从**用户目标语产出**聚合「常犯错误 / 学习盲点」清单，呈现于总览页盲点分区（S1 已预留）+ 可链「加入记忆库 / 生成针对性练习」（行动闭环，接 memory_items 复习队列）。
- **硬前置**：LM02-S1（盲点分区 + provider）。
- **依赖（关键新发现，降低净新增成本）**：**`PracticeTextAttempt` 已存在用户产出 + 机械 diff**（`attemptText` / `referenceTextSnapshot` / `diffDifferenceCount` / `diffSummaryJSON`，听写 + 回译的重现错误）——这是**红线合规**的盲点信号源（用户产出 + 机械 diff，**非** AI 判定）。故 S3 v1 可从既有 `PracticeTextAttempt` diff 抽取结构化错误模式，**无须**新练习评分。
  - **禁用**：`PracticeBacktranslationReviewResult.observations`（AI 生成点评）= AI 判定，ADR-006 §4 禁用，S3 **不读**。
  - **自由产出错误**（用户在 Entry 用目标语写作的错误）须**目标语产出语种检测**（净新增，idea-02 §13.4 信号稀疏）→ 作为 S3 的**后续子增量**，v1 先只用练习 diff。
- **关键待决**：① 从 `diffSummaryJSON` 抽结构化错误模式的形态（按类型聚类 vs 频次）；② 行动闭环 v1 是否即接「→ 立即练」（依赖 memory_items 复习队列已就绪，可接）还是先只展示；③ 自由产出语种检测是否进 S3 v1（建议否，留子增量）。
- **风险**：中。信号源（练习 diff）真实但覆盖有限（仅做过听写 / 回译者有）；自由产出稀疏；须避免把「不展示降级」误伤为「不展示错误」——盲点是**行动价值**项（idea-02 §7.1），展示用户**自己的**错误（非判决水平）合规。
- **设计来源**：idea-02 §4（有效证据）/ §7.1（盲点页）/ §13.1（闭环红线）/ §14.2（盲点是 v1 高价值项）。
- **触碰**：LearnerModel（盲点聚合 read，读 `practice_text_attempts`，跨域只读同 LM01 读 memory_items）；UI 盲点分区 + 行动闭环。**不碰** derive()、不外发。

### LM02-S4：band 重估（CEFR 动态评估，v2 高风险）

> **→ 已转拆解边界 + S4a/S4b 已拆出并双轮自审（2026-06-25「先收口再实施」完成）**：[`2026-06-25-feature-lm02-s4-band-reestimation.md`](2026-06-25-feature-lm02-s4-band-reestimation.md) 已转**拆解边界**（类型 docs、自审 N/A）。双轮纠偏：① blast radius 原「derive() 仅 2 处 → 风险小」不成立（proficiency 真值 = 5+ 消费者跨外发边界）；② 「S4 首张持久表」错误（S1 `learner_memory_facts`=v27 才是首张，S4=v28+ 建在 S1 writer seam 上）；③ ADR 已决 = ADR-006 §10 修订（非新 ADR），作 S4b 门控。
> **拆出的两份 active plan（各自双轮 + 拆分后隔离再审三关过）**：
> - **S4a** [`...s4a-lookup-capture-and-ledger`](2026-06-25-feature-lm02-s4a-lookup-capture-and-ledger.md)（查词捕获+账本，低风险）。再审收口：source_content_origin **不可捕获**（reading_documents 恒用户导入、无 AI 生成阅读源）→ 降**前向 schema 接缝**（v1 恒 userAuthored，二阶闭环 v1 不成立）；practice_text_attempts **非排除导出伪先例**（无策略列、归档导出方案列其为主数据）→ 查词事件改「不可重算行为信号」新类别、**显式声明** local-only + spec/007 新增登记；埋点宿主改 **AI 解释 seam**（ReadingDictionaryLookupIndex 未接线）。
> - **S4b** [`...s4b-band-service-and-derive-hysteresis`](2026-06-25-feature-lm02-s4b-band-service-and-derive-hysteresis.md)（band 服务+derive 迟滞+总览，最高风险）。再审收口：「band 不跨外发」被 `:96`（请求携 `explanationLanguageMode`=derive 输出）**证伪** → 改诚实措辞「band 不增新外发字段、外发的是三档枚举」；迟滞 dwell 单位「内容条目」与 S4a 高水位 cursor 错配 → 改 **document-open 评估次数**（稳定阈值=连续 3 次越阈、停留=≥5 次）；迟滞计数器状态 = per-language / local-only / 重启清零可接受。门控：S4a+S3 信号回归 + ADR-006 §10 修订 artifact 存在。
> 两片现 Draft/Reviewed、**待实现授权**。详见各 plan §12/§13。

- **范围**：把目标语水平从静态自评升为**持续重估的内部 band 信号**；驱动材料生成难度 / 解释模式 / 练习选材 / 复习排序 / 语伴基线。
- **硬前置**：LM02-S1；**S3 的独立产出信号 + 查词行为信号成熟**（band 须建在不被 level 污染的独立信号上，否则闭环自证焊死水平，idea-02 §13.1）。
- **依赖**：查词 / 索取解释频率信号（idea-02 §4 主力，**净新增**捕获）+ S3 目标语产出错误；**分析账本 / cursor 增量重算**（ADR-006 §9，此时才首次引入账本）。
- **关键待决（高）**：① `ExplanationLanguageMode.derive()` 改吃演进 band 的**迟滞策略**（idea-02 §13.3 / §14.2：稳定阈值 + 最小停留窗口 + 仅新内容，防「体验在脚下漂移」；blast radius 小——derive() 仅 2 处 `ReadingDocumentStore` 调用）；② **评估覆盖内部难度信号、永不覆盖用户可见标签**（ADR-006 §10）；③ **永不展示降级**（ADR-006 §10 红线）；④ 分技能（理解 vs 产出）是否同期（idea-02 §14.2：v1 只理解 + 覆盖，产出低置信占位）。
- **风险**：最高。闭环自证（信号独立性）、derive() 漂移、母语记录稀疏致产出测不准、不打击信心红线。**故排最后**，且须独立信号充分 + 回归充分后才动 derive()。
- **设计来源**：idea-02 §3 / §5 / §13.1–13.4 / §14.2，ADR-006 §4 / §9 / §10。
- **触碰**：LearnerModel（band 重估服务 + 分析账本 + cursor）；Data（账本 migration）；Core/UI（derive() 迟滞接线，**唯一**碰 derive() 的切片）。纯本地 v1；AI 校准 band = 跨切 v2。

### 跨切 v2：AI 校准（Style 认知风格 + band AI 估计，opt-in）

> **拆分状态（2026-06-25）**：**刻意不在本轮拆成独立 active plan**。理由：AI 校准是叠加在 S2（认知风格）/ S4（band AI 估计）上的**外发增量**，是 opt-in / 隐私闸门后的 v2 能力——为尚未就绪能力预先建 active plan 会违反本文件「共同前置 §17」与 CLAUDE.md §9 克制（active/ 不堆积未就绪方案）。故它**保留为本文件登记的有界未来切片**，待 S2/S4 本地档落地 + ADR-006 §6 隐私闸确认后，再各自叠加为 S2-v2 / S4-v2 的外发增量 active plan。用户 2026-06-25 已认可此「本地优先先行、外发增量后置」分批门控。

- **范围**：不是独立切片，而是叠加在 S2（认知风格：观察角度 / 思维方式）与 S4（band AI 估计）上的**外发增量**。
- **硬前置**：对应本地切片（S2 / S4）先落地；**ADR-006 §6 隐私前置闸门**（已升格权威）。
- **形态**：opt-in + 默认关闭 + 开启动作即决策 #10 明示触发 + 只发增量 delta + 排除私密标签 / 照片原图 + plan 09 预览 / 日志 + 最小发送（ADR-006 §6 / idea-01 §14.4 / idea-02 §5 方案 B）。
- **触碰**：AI 包（新增 `AIRequestCapability` case + content descriptor + 投影，见 LM02-S1 自审 P0-2 关联约定——capability 新 case 留到真正外发切片）；自动后台外发须先过隐私闸（已开）。
- **风险**：外发隐私 + 成本；故全系列最后，且每项独立 opt-in。

### 未来切片登记（2026-06-25 完整性审查补登孤儿能力，避免静默丢失）

完整性审查发现两处 idea / ADR 已批准、但当前无任何 active plan 或拆解行承接的能力。**用户 2026-06-25 决策：两处都登记为未来切片**（仅占位、不立即拆 active plan；进入实现前各自创建 active plan + 双轮自审）。

- **改写 / 写作修改切片（Style→Ability i+1 下投影的落地消费者）**：idea-01 §13.5「Style 应用到目标语改写按 Ability i+1 下投影」的**第二个落地消费者**。S2「seam-only」当前唯一就绪未来消费者只剩 **LM03-S4**（语伴 Style 注入）；**改写 / 写作修改消费者无任何 plan**，使 S2 立项前提（自审已标投机地基）更弱。登记为未来切片：目标语改写 / 写作修改读 S2 Style 印记 + 按 Ability i+1 下投影。硬前置：S2 + LM01 Ability。设计来源 idea-01 §13.5、idea-03 §10.2（会话式 affordance 已被「拆完整引擎」决策替代，改写作为独立写作修改工具消费者保留）。**风险**：低；价值是兑现 S2 的第二消费者、降低投机地基。
- **onboarding 自评措辞软化微切片**：idea-02 §7.2 / ADR-006 §10 已批准的「轻量阶段化措辞（初学 / 能日常交流 / 较流利）」。S1 §5 明确不做、留「单独小切片」，但无 plan/拆解行承接。登记为未来切片：onboarding 水平自评文案从 CEFR 裸标签软化为阶段化措辞，**不改内部 `LanguageLevel` 枚举值**（仅展示层）。可独立做，或并入 S4b（用户可见标签 vs 内部 band 关系已在 S4b 范围）。设计来源 idea-02 §7.2、ADR-006 §10。**风险**：极低（纯展示文案）。

## 推荐排序与门控

```text
LM02-S1（Memory + 总览页）  ← 已 Draft/Reviewed，待实现授权
   ↓
LM02-S2（Style 表层，零外发低风险，喂语伴「像你」）   ← 推荐先做
   ↓ （S2 与 LM03 companion 可并行：companion v1 不依赖 Style，v2 依赖 S2）
LM02-S3（盲点，复用既有 PracticeTextAttempt diff）     ← 高价值，前置成本被既有信号降低
   ↓
LM02-S4（band 重估，v2 高风险，唯一碰 derive()）       ← 最后，需独立信号 + 回归充分
   ↓
跨切 AI 校准（S2 认知风格 / S4 band，opt-in）          ← 叠加增量，非独立片
```

排序理由：

- **S2 与 S3 同属本地优先第一批（用户 2026-06-25 决策）**：S2 立项自审曾建议推迟（seam-only 当前无消费者 = 投机地基），但**用户拍板 S2 do-now / seam-only**，与 S3 同期纳入本地优先第一批。S3（盲点，有既有 PracticeTextAttempt 信号 + 行动价值）独立高价值、可与 S2 并行；二者均零外发、不碰 derive()。band(S4) + 语伴(LM03) + AI 校准为后续批次。
- **S3 提前可行**：原以为盲点需净新增练习评分，核实**既有 `PracticeTextAttempt` diff 即合规信号源**，前置成本大降；高价值（idea-02 §7.1 行动闭环）。
- **S4 最后**：闭环效度 + derive() 漂移是头号风险，须建在 S3 独立信号之上。
- **AI 校准全系列最后**：外发增量，逐项 opt-in。

门控（每片实现前必须满足）：

1. LM02-S1 已落地（总览页 + Memory + provider）。
2. 该片**独立 active plan** 已创建并 **Reviewed**（plan-review-protocol 双轮）。
3. 用户实现授权。
4. S4 / AI 校准额外门：独立信号成熟（S3）+（AI 校准）隐私闸已开（已满足 ADR-006 §6）。

## 与 LM03 语伴的关系

- 语伴（LM03）排在学习者模型系列最后（ADR-006），但其**前置已就绪**（ADR-008 + Provider 多轮 / 流式方案）。
- 语伴 v1 不依赖本文任何后续切片（退回静态 level + 仅 per-space 情景）；语伴 **v2** 依赖 **LM02-S2（Style）** 与 **LM02-S1（Memory）**。
- 故 S2 与 LM03 可并行推进；若优先语伴体验，S2 应紧随 S1。

## 维护约定

- 某切片被拉起为 active plan 时，在 `2026-06-11-00-docs-series-progress.md` 状态总表登记，并在本文件对应切片标注「→ 已拆 active plan: <路径>」。
- 全部后续切片拆完并各自落地后，本文件随 LM02 收口移入 `done/`。
- 设计细节、TDD 落点、验证不写在本文件，写回各切片 active plan 与权威文档。
