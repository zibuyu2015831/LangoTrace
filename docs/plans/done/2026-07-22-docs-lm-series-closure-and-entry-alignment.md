# 任务方案：LM 系列导航收口与入口文档对齐

状态：Verified
自审核状态：Reviewed
类型：docs
创建日期：2026-07-22
最后更新日期：2026-07-22

## 用户确认记录

- 本任务在 `FABLE-MISSION.md` 授权的自主运行中执行。该简报 §4 明确授权：每项实质任务仍写 active plan 并按 `docs/plans/plan-review-protocol.md` 严格自审核，但由本次运行自批，无需停下等用户确认。§2.5 将「文档控制面与代码零未记录偏差」列为本次运行的一等交付。
- 本任务不删除任何历史记录、不改写核心决策、不改变文档权威关系（符合 `docs/README.md` §1.3 保守文档自进化原则），因此适用上述自批授权。

## 需求描述

学习者模型系列（LM01 + LM02 全切片 + LM03 语伴全切片）已于 2026-06-25 ~ 2026-06-27 全部实现、CI 绿并移入 `docs/plans/done/`，但收口遗留两类文档滞后：

1. `docs/plans/active/` 仍留有 4 份状态为 In Progress 的导航/拆解文档，其对应实施工作已全部完成。其中 3 份（进度仪表盘、LM02 拆解、LM03 拆解）自身维护约定写明「随系列收尾移入 `done/`」；第 4 份（S4 拆解边界）无归档约定，但其子片 S4a/S4b 均已 Done，依 `docs/plans/README.md` §5 生命周期规则一并归档。
2. 入口文档 `docs/README.md` 与部分架构文档未随系列落地更新，存在把已实现能力列为未完成的事实漂移。

## 现状描述（2026-07-22，HEAD `c6b0b9e`，经独立探索子代理只读核查 + 隔离自审核复核）

- `docs/README.md:108` 包清单只列 Core/UI/Data/AI/Speech/Sync 六包；实际存在第 7 个包 `Packages/LangoTraceLearnerModel/`（19 个源文件，`project.yml` 与两个 App target、`LangoTraceUI/Package.swift` 均已依赖）。
- `docs/README.md:92-94` 叙述段与 `:131-142`「尚未完成」清单把已实现能力列为未完成：听写（`PracticeDictationSessionView` + v23 `practice_text_attempts`）、回译（`PracticeBacktranslationSessionView`，Slice 1 Implemented）、AI 请求预览（`AIRequestPreviewProjection` + `RequestPreviewCard` 三端接线）、请求日志（`ai_request_logs` + `AIRequestLogListView`）、FTS 全文搜索（`AppDatabaseSearchMigration` trigram FTS5 + `SearchIndexWriter` + `SearchPaletteView`）、照片附件主数据（`EntryPhotoAttachment` + `PhotoImportPipeline` + `GRDBEntryPhotoAttachmentRepository`）、同步引擎纯逻辑切片（`SyncEngine` + `SyncAdapter` 协议 + LWW 冲突解决，真实通道诚实 defer）、导入导出 Slice 1（明文主数据导出引擎，其余 defer）、Anthropic Messages 文本适配器。「已完成」清单也完全未提及学习画像总览页、语伴（Language Companion）、Memory 层、band 重估、查词账本、多轮+流式 Provider 等一级能力。Gemini 文本学习内容适配确未实现（`geminiGenerateContent` 仍 `unsupportedProvider`），保留在「尚未完成」正确。
- `docs/architecture/002-system-map.md:4-5` 头部「最后核对：2026-05-26 / 代码快照：94919d3b」严重滞后于正文（正文已更新至 2026-06-27 的 §4.9-4.16、v33 迁移），元数据失去对齐依据作用。
- `docs/architecture/001-initial-module-boundaries.md:229-268` §5「当前代码快照」仍是初始化阶段描述（称 Entry/练习/记忆仍 Mock、内存 repository），与同文件 §2.8/§3 已更新到 LM02 的内容自相矛盾。
- `docs/plans/active/` 4 份导航文档：`2026-06-11-00-docs-series-progress.md`（仪表盘）、`2026-06-25-docs-lm02-remaining-slices-decomposition.md`（拆解）、`2026-06-25-docs-lm03-companion-decomposition.md`（拆解）、`2026-06-25-feature-lm02-s4-band-reestimation.md`（拆解边界）。仪表盘 `:30` 登记了**五个孤儿**：语伴逐句 TTS 朗读接线（S1 偏差）、S3 deposit 子增量、改写/写作修改消费者、onboarding 自评措辞软化、AI 校准 v2；另有「下一候选 = 待用户指定（语伴远期：语音对话 / 场景模式 / 向量检索）」等前向内容。
- 入站链接现状（隔离审核 P1-2 核实）：`docs/idea/03-conversation-partner.md:12/:14` 与 `docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md:9` 为**当前面向文档**，链接指向 `plans/active/` 下将被移动的 LM03 拆解文档；同一行还存在**既有断链**（指向早已移入 done/ 的 `active/2026-06-25-feature-lm03-s1-companion-mvp.md`、`active/2026-06-25-feature-ai-provider-multi-turn-and-streaming.md`）。另有约 8 份 `docs/plans/done/` 历史方案内含 `active/` 路径引用。`scripts/check-docs.sh` **不做链接解析**（仅 symlink、文件名模式、必需文件/章节、placeholder 扫描），既有断链未被任何检查捕获。
- `project.yml` 的 `LangoTraceAppTests` target 无 `LangoTraceLearnerModel` 依赖；经核查 `LangoTraceAppTests/` 源码无 `import LangoTraceLearnerModel`，属有意省略（App 层测试经宿主链接，LearnerModel 单测都在其 package Tests 内），不改 `project.yml`。
- 其余核对为一致：各 `Package.swift` 依赖 vs 001 §3 / 002 §5 依赖图、`project.yml` packages、页面清单 vs 实际页面、各 impl.md 声明文件、迁移版本 v27-v33 —— 偏差集中在入口文档与上述元数据。

## 目标、范围和不做什么

目标：`docs/` 控制面与代码恢复零未记录偏差；`docs/plans/active/` 中 LM 系列导航文档全部收口；归档不丢失任何前向信息、不新增断链。

范围内：

1. 修订 `docs/README.md`：§2 叙述段（92-94）、已完成清单（96-129）、尚未完成清单（131-142）、包清单（:108 增列 LearnerModel）。
   - 「已完成」新增 bullet 基线（钉死，防临场漂移）：LearnerModel 包与 ADR-006 学习者模型子系统（Ability 知识覆盖 compute-on-read、Memory 层 v27、Style 表层印记 seam、盲点 dictation diff、band 动态重估 + derive 迟滞、查词捕获 + 分析账本 v28/v29）；学习画像总览页（三端）；语伴 Language Companion（文本对话引擎 + 聊天反哺 + Memory/Style 受控注入 + 两层隐私与 PII scrubbing + 找话题 + 流式 + 滚动摘要 v33 + 对话小结批量 deposit + v30/v31/v32 迁移）；AI Provider 多轮 + 文本流式；Anthropic Messages 文本适配器（**结构化严格模式与图片理解后置**）；AI 请求预览投影与请求日志（`ai_request_logs`，**语伴会话级日志 defer**）；听写练习（diff 对照）；回译练习 Slice 1（AI critique，**刻意不判对错**）;FTS5 trigram 全文搜索（本地可重建派生数据）；照片附件主数据与照片写作路径；双语沉浸阅读页；导入导出 Slice 1（**明文主数据导出引擎，文件面板/附件打包/加密备份 defer**）；同步引擎纯逻辑切片（`SyncEngine` + Adapter 协议 + LWW，**真实通道/变更跟踪 schema defer**）。defer 边界措辞必须保留，不得把 deferred 包装成已完成。
   - 新「尚未完成」保留：完整时间线的场景标签筛选与搜索联动、Entry 音频附件、附件导出打包与可恢复备份、Gemini 文本学习内容适配、Prompt Preset 执行链路、跟读发音评分、Embedding 真实向量索引、Speech Recognition / OCR / 相机权限、真实同步通道（CloudKit adapter + 变更跟踪 schema）、对象存储配置、StoreKit、发布材料。
2. 更新 `docs/architecture/002-system-map.md` 头部「最后核对 / 代码快照」为本次核对日期与 HEAD。
3. 在 `docs/architecture/001-initial-module-boundaries.md` §5 顶部加降权标注（历史初始化快照，当前事实以 002-system-map / platform-page-inventory 为准），不删除原文（§1.3 降权优先于删除）。
4. 将 4 份导航文档状态推进为 Done（附一行收口说明）并 `git mv` 至 `docs/plans/done/`。归档前对 4 份文档做**前向内容 sweep**：逐项确认「待用户决策」「下一候选」等前向条目已收口、已有当前事实源或由本次承接，结论写入实施记录。
5. 在 `docs/idea/README.md` 增加「未来切片登记」节，承接**全部五个孤儿**：① 语伴逐句 TTS 朗读接线（LM03-S1 §18 偏差，加性后续）；② 语伴 S3 deposit 子增量；③ 改写/写作修改消费者（idea-01 §13.5，Style→Ability i+1 下投影第二消费者）；④ onboarding 自评措辞软化（idea-02 §7.2 / ADR-006 §10，纯展示层）；⑤ AI 校准 v2（外发增量，硬前置 = ADR-006 §6 隐私闸，逐项 opt-in）。节头部照抄原登记边界句：登记 ≠ 实施授权；进入实现前各自拆 active plan + 双轮自审；本节不改变 idea 目录非事实源地位。每项注明来源与硬前置。语伴远期候选（语音对话 / 场景模式 / 向量检索）一并登记为远期方向占位。
6. 修正入站链接：`docs/idea/03-conversation-partner.md`、`docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md` 两份当前面向文档中指向被移动文件的链接改为 `done/` 路径，**并顺手修复同处既有断链**；`docs/plans/done/` 历史方案中的 `active/` 路径引用做纯路径修正（路径修正不改写历史内容与结论，属链接维护而非历史改写；全部修正，不留双轨）。
7. 在 `docs/review/INDEX.md`「重审触发日志」追加一行：LM 系列收口触发的入口文档对齐检查，承载记录写本 plan 的 **done/ 最终路径**（沿用 2026-05-23 无独立 round 的先例）。

不做什么：

- 不动任何 ADR、spec 正文、产品主参考的决策内容（本任务只对齐事实陈述，不改决策）。
- 不删除、不改写任何 done plan / review round / 架构备忘录的历史内容（路径链接修正除外）。
- 不归档 `docs/idea/01/02/03` 三份 idea 文件（AI 校准 v2 与未来切片仍以其为设计源，留在孵化区）。
- 不改 `project.yml`（AppTests 依赖省略确认为有意）。
- 不改任何生产代码。
- 不给 `check-docs.sh` 新增链接解析能力（属独立脚本增强任务，本次以一次性 rg 扫描兜底；如后续复发断链问题再立项）。

## 证据与决策依据

- 独立探索子代理（新上下文、只读）2026-07-22 全仓核查报告：偏差 A1/A2/A3、待判断 B1-B4、一致性确认清单（见上「现状描述」）。
- 隔离自审核子代理（2026-07-22）双轮审查：P1-1（五孤儿）、P1-2（链接完整性与验证声明失实）、P2-1~P2-5、P3-1~P3-3，均已写回本方案。
- `FABLE-MISSION.md` §2.5（文档控制面一等交付）、§4（active plan 自批授权）。
- `docs/README.md` §1.3（保守文档自进化：降权/归档优先、历史证据保留）、§6（文档更新落点）。
- 3 份导航文档的归档维护约定原文 + `docs/plans/README.md` §5 生命周期规则（S4 拆解边界）。

## 约束映射与验证路径

- `docs/plans/README.md` §5：文档治理任务创建前已搜索 `active/`、`done/`、`review/INDEX.md`，无同题 active plan。
- `docs/README.md` §10 完成前检查：`scripts/check-docs.sh`（结构检查，**不含链接解析**）、全量 placeholder rg 检查、`git diff --check`、`git status --short`。
- 断链兜底：对 4 个被移动文件名逐一 `rg "plans/active/<name>"` 全仓扫描确认清零（详见验证命令）。
- `docs/review/README.md`：本次属「阶段性完成后的文档影响检查」，以 plan 实施记录承载并在 INDEX 触发日志留痕。

## 涉及的代码文件路径

无（纯文档治理任务，不改任何生产代码、测试或脚本）。

## 参考的代码文件路径

- `Packages/LangoTraceLearnerModel/Sources/`（包存在性与规模核验）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeDictationSessionView.swift`、`PracticeBacktranslationSessionView.swift`、`AIRequestLogListView.swift`、`SearchPaletteView.swift`（「已实现」论断的代码证据）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AnthropicMessagesTextAdapter.swift`、`Packages/LangoTraceSync/Sources/LangoTraceSync/SyncEngine.swift`
- `scripts/check-docs.sh`（验证能力边界核验）

## 涉及的文档路径

- `docs/README.md`
- `docs/architecture/002-system-map.md`（仅头部元数据）
- `docs/architecture/001-initial-module-boundaries.md`（仅 §5 顶部标注）
- `docs/plans/active/` 4 份导航文档 → `docs/plans/done/`
- `docs/idea/README.md`
- `docs/idea/03-conversation-partner.md`（入站链接修正）
- `docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md`（入站链接修正）
- `docs/plans/done/` 约 8 份历史方案（纯路径链接修正）
- `docs/review/INDEX.md`

## 实施方案

1. 修订 `docs/README.md`（按范围第 1 项钉死的 bullet 基线执行）。
2. 更新 002-system-map 头部元数据；001 §5 加降权标注。
3. 对 4 份导航文档做前向内容 sweep（结论记入实施记录）→ 状态改 Done + 收口说明 → `git mv` 至 `done/`。
4. `docs/idea/README.md` 增加未来切片登记节（五孤儿 + 远期方向占位 + 边界句）。
5. 修正全部入站链接（当前文档 + done 历史方案路径修正 + 既有断链）。
6. `docs/review/INDEX.md` 触发日志追加一行（写 done/ 最终路径）。
7. 运行验证命令 → 本 plan 补实施记录、状态推进 → 移入 `done/` → 分批提交推送。

## 复查方法

实施完成后，由独立 verifier 子代理（新上下文）执行：① 对照 `docs/architecture/002-system-map.md` 与 `docs/platform-page-inventory.md` 逐条复核 README 新「已完成 / 尚未完成」清单，确认无 deferred 被包装成完成、无已实现被漏列；② 运行下方断链扫描命令确认清零；③ 抽查 idea/README 登记节五项的来源指针可解析。复核结论写入实施记录。后续会话可从本 plan（done/ 路径）+ `FABLE-WORKLOG.md` 恢复全部上下文。

## TDD / 测试落点

不新增单元测试：本任务为纯文档治理，无生产代码与可自动化行为变化（`docs/plans/README.md` §5 允许并要求说明）。可机械验证部分由 `scripts/check-docs.sh`（结构检查，不含链接解析）+ 下方一次性断链 rg 扫描承担。剩余风险：事实陈述正确性依赖人工/子代理核查，已用独立探索子代理完成一轮，实施后按「复查方法」由 verifier 子代理复核。

## 验证命令

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*' --glob '!**/idea/**'
# 断链兜底：被移动的 4 个文件名在全仓不应再有 active/ 路径引用（[-] 写法排除本命令行自匹配）
rg "plans/active/2026-06-11-00[-]docs-series-progress"
rg "plans/active/2026-06-25-docs-lm02[-]remaining-slices-decomposition"
rg "plans/active/2026-06-25-docs-lm03[-]companion-decomposition"
rg "plans/active/2026-06-25-feature-lm02-s4[-]band-reestimation"
git diff --check
git status --short
```

完整验证：下一个带 `[ci]` 的检查点将连带执行 CI 的 `check-docs` 步骤（docs-only 变更不单独触发全量 macOS CI，节省额度；风险低——不含代码变更；未来合并 `main` 走 PR 时必跑全量 `Build & Test`）。

## 文档影响检查

本任务本身即文档影响检查的执行。不升级为独立 review round / 里程碑轻量全审的理由：LM 系列各切片已逐片完成 §17 文档影响回写（ADR-006/008、spec/005·006·007·008、architecture/001·002、page-inventory、prompts 均已随片更新），本次仅为入口文档与元数据对齐，且独立子代理全仓核查结论为「其余一致」。**本判断不豁免未来数据层 / AI 层里程碑全审**。额外落点：`docs/review/INDEX.md` 触发日志留痕；`FABLE-WORKLOG.md` 记录动作与依据。

## 严格方案自审核记录

```text
审核日期：2026-07-22
审核方式：隔离审查（独立 general-purpose 子代理，新上下文、只读）
审核轮次：双轮合并
未使用隔离审查的原因：不适用（已使用）
发现摘要：P0=0；P1=2（五孤儿只承接三、移动文件破坏当前文档入站链接且 check-docs.sh 无链接解析、验证声明失实）；P2=5（S4 无归档约定的证据措辞、缺必填章节、README 已完成清单无 bullet 基线、idea/README 目录边界、review round 豁免理由未记录）；P3=3（rg pattern 不全、INDEX 路径细节、docs-only CI 风险确认成立）。
写回修改：范围第 4/5/6 项扩展（前向 sweep、五孤儿 + 远期占位 + 边界句、入站链接与既有断链修正）；现状描述补链接现状与 S4 约定事实；README 已完成 bullet 基线钉死（含 defer 边界措辞）；补「复查方法」「涉及/参考代码路径」章节；TDD 节修正 check-docs.sh 能力描述；验证命令补断链扫描与全量 placeholder pattern；文档影响检查补豁免理由；INDEX 行写 done/ 最终路径。
仍需用户确认的问题：无（均在 FABLE-MISSION §4 自批授权范围内；不涉及核心决策、历史删除或权威关系变更）。
是否允许进入实现：是（P1 修订已全部写回本方案）。
```

## 实施记录

2026-07-22 实施完成（自主运行，FABLE-MISSION 授权）：

- `docs/README.md`：叙述段（92-94）、包清单（七包含 LearnerModel）、「已完成」按钉死 bullet 基线增补 15 条（defer 边界措辞保留）、「尚未完成」重写为真实缺口清单。
- `docs/architecture/002-system-map.md`：头部「最后核对 2026-07-22 / 代码快照 c6b0b9e0」；实施后复查发现其 §1「当前真实能力边界」清单与 Packages 列表自身滞后（漏 LearnerModel 包、未完成清单含已实现项），一并修正——否则头部核对声明失实。
- `docs/architecture/001-initial-module-boundaries.md` §5：加降权 blockquote（历史初始化快照，不删原文）。
- 4 份导航文档：前向内容 sweep 结论——五孤儿 + 语伴远期候选承接至 `docs/idea/README.md` §5.1；「待用户决策」各项确认已在实现批次收口（Style v2=§9 方案 A、salience=时近性+种类配额、模糊输入=directive、入口英文名=Language Companion）；E10/E11 硬接缝仍由 `2026-06-25-learner-memory-persistence-and-security-notes.md` 托管。状态改 Done + 收口说明后 `git mv` 至 `done/`。
- `docs/idea/README.md`：新增 §5.1 未来切片登记（五孤儿表 + 远期占位 + 边界句 + 来源/硬前置）。
- 入站链接：`idea/03`、`architecture/notes/2026-06-25-companion-voice-input-...`、`decisions/008` 及 5 份 done plan 的 `plans/active/` 路径全部修正为 `done/`（含两处既有断链：`lm03-s1-companion-mvp`、`ai-provider-multi-turn-and-streaming`）。
- `docs/review/INDEX.md`：重审触发日志追加 2026-07-22 行（由本 plan done/ 路径承载）。
- 验证：`scripts/check-docs.sh` ok；全量 placeholder rg 零命中；4 个被移动文件名的 `plans/active/` 断链扫描清零；`git diff --check` 干净。
- 复查（独立 verifier 子代理，新上下文）：叙述段 / 已完成 / 尚未完成逐条对照代码复核通过，无 deferred 被包装成完成、无漏列；唯一数字错误「350+ 测试文件」已按实测改为「约 250 个测试文件、约 1600 个测试用例」；idea §5.1 五项指针全部可解析；001 §5 降权标注措辞确认得当；verifier 顺带发现的 002-system-map §1 滞后已修正（见上）。
- CI 侧 `check-docs` 步骤随下一个带 `[ci]` 的代码检查点执行（docs-only 不单独触发全量 macOS CI）。
- 提交：`58f9c38`（docs: LM 系列导航收口归档 + 入口文档与代码对齐）；CI 侧 `check-docs` 实际由后续检查点 run 29858671734（success）连带覆盖。（2026-07-22 全面复核时补记，消除纯文档 plan 无 commit hash 的追溯缺口。）

## 完成标准

- 4 份导航文档以 Done 状态位于 `done/`；前向 sweep 结论在案。
- `docs/README.md` 不再把已实现能力列为未完成，包清单含 LearnerModel，defer 边界措辞保留。
- 002-system-map 头部元数据与本次核对一致；001 §5 有降权标注。
- 五孤儿 + 远期方向在 `docs/idea/README.md` 可发现，带来源与边界句。
- 断链扫描清零；`scripts/check-docs.sh` 通过；变更已提交推送 `dev`。

## 剩余风险

- `docs/README.md`「已完成」清单为概括性重写，可能遗漏个别细节能力；缓解：bullet 基线已钉死 + 以 002-system-map 与 platform-page-inventory 为细节事实源 + verifier 复核。
- docs-only 提交不单独触发 CI，`check-docs` 的 CI 侧执行推迟到下一个 `[ci]` 检查点；缓解：本地已运行同一脚本。
- `check-docs.sh` 长期缺链接解析能力，未来移动文档仍可能引入断链；已在「不做什么」登记为候选独立任务。
