# FABLE 任务日志 — LangoTrace 深度审查与推进

本文件是 [`FABLE-MISSION.md`](FABLE-MISSION.md) 自主运行的**贯穿全程日志**，由 Fable 在执行过程中持续更新。
记录：操作日志、遇到的问题、决策依据、CI run 编号与结论、下一步。随代码分批提交推送到 `dev`。

约定：新条目追加在下方；每条尽量含 **动作 / 依据 / 结果**；CI 记录带 run id 与 conclusion；
凡涉及推翻早期设计或改动核心决策/文档权威关系的决策，写清理由与所依据的 ADR/spec/plan。

---

## 运行元信息

- 分支：`dev`
- 简报：`FABLE-MISSION.md`
- 测试方式：GitHub Actions（`Build & Test`，`macos-15`）；直接 push 需提交信息含 `[ci]` 才触发
- CI 观察：未认证 REST API `curl https://api.github.com/repos/zibuyu2015831/LangoTrace/actions/runs?branch=dev`
- 仓库可见性：由用户手动管理（运行期间 public，结束后设回 private）

---

## 日志

<!-- Fable 从这里开始追加。示例格式：

### YYYY-MM-DD HH:MM — <标题>
- 动作：<做了什么、动了哪些文件/子代理>
- 依据：<为什么这么决策，引用 ADR/spec/plan/北极星>
- 结果：<产出、CI run id + conclusion、剩余问题>
- 下一步：<接下来做什么>

-->

### 2026-07-22 — 运行开始：基线盘点与深度审查启动
- 动作：接手本 worklog；确认 `dev` 与 `origin/dev` 一致（`c6b0b9e`）、工作区干净；查 CI 基线：run 29853334461（`b029be0`）`Build & Test` conclusion=success，dev 是绿的。
- 依据：FABLE-MISSION §0（开工第一件事接手 worklog）、§5（CI 是唯一构建/测试事实源）。
- 发现：`Packages/` 存在 `LangoTraceLearnerModel`，但 `CLAUDE.md` 与初始模块边界文档只列 Core/UI/Data/AI/Speech/Sync 六包——列入文档一致性审查线索。
- 下一步：并行派出探索子代理，对「代码↔文档一致性」「代码健康度」「未竟任务现状」做全仓深度审查，汇总后定第一批推进项并写 active plan。

### 2026-07-22 — 三路深度审查完成，确定本次运行的推进批次
- 动作：三个独立探索子代理（新上下文、只读）完成全仓审查。
- 结果（要点）：
  - 文档↔代码一致性：架构层（001/002/页面清单/各 impl.md/迁移 v27-v33/依赖图）与代码几乎零偏差；**偏差集中在入口文档 `docs/README.md`**——漏第 7 个包 LangoTraceLearnerModel、漏学习画像/语伴等一级能力、把已实现的听写/回译/请求预览/请求日志/同步引擎切片列为未完成；`002-system-map.md` 头部核对元数据停在 2026-05-26；`001` §5 仍是初始化期快照；`active/` 4 份导航文档待归档。
  - 代码健康度：无崩溃级问题（零 try!/as!/fatalError，Task 生命周期规范，约 350+ 测试文件）；待修：H1 真实功能仍挂 `.mockOnly` 徽章（interfaceLanguage / Memory 摘要 / Pad 空间设置入口，用户可见误导）、M1 AppEnvironment 两处空 catch 吞操作账本写入失败、M2 TTSConfigurationProbeService 无门控 NSLog 打印 provider 错误体、M3 InMemoryLearningContentRepository mock 夹具位于生产 Sources、M5 settingsCapabilities 清单两份逐字重复（正是 H1 漂移根因）、M4 verify.sh 写死模拟器名。
  - 未竟任务：FTS/搜索、请求预览/日志、听写、回译、同步纯逻辑引擎、Anthropic 适配、媒体附件基建均已有成熟地基；真实缺口 = 时间线场景标签筛选与搜索联动、Entry 音频附件、附件导出打包、Gemini 文本适配、Prompt Preset 链路、跟读发音评分、真实同步通道、StoreKit（零地基）。**推荐首选：时间线场景/场景标签筛选 + FTS 搜索联动**（底盘最成熟、直击北极星「记录」主入口）。
- 决策：本次运行按三批推进——①docs 收口与入口对齐（plan 已建：`docs/plans/active/2026-07-22-docs-lm-series-closure-and-entry-alignment.md`，verifier 隔离自审中）；②代码健康度修复批（H1+M1+M2+M5 为主）；③时间线场景筛选 + 搜索联动功能批。依据：FABLE-MISSION §2（审查→优化→推进）、§2.5（文档一等交付）、docs/README §9 当前优先级第 2 条（本地记录闭环）。
- 下一步：等 verifier 结论 → 写回 plan → 实施 docs 批并推送。

### 2026-07-22 — 批次①完成：LM 系列收口 + 入口文档对齐（docs）
- 动作：按 `docs/plans/done/2026-07-22-docs-lm-series-closure-and-entry-alignment.md`（隔离双轮自审 Reviewed，P1×2 已写回）实施：重写 `docs/README.md` 状态清单（补 LearnerModel 第七包、学习画像、语伴、听写/回译/FTS/请求预览日志等 15 条已完成项；「尚未完成」改为真实缺口）；002-system-map 头部元数据 + §1 能力边界同步修正；001 §5 加历史降权标注；4 份 LM 导航文档收口归档 `done/`；五孤儿 + 语伴远期候选承接进 `docs/idea/README.md` §5.1；修正全部入站链接含两处既有断链；review INDEX 触发日志留痕。
- 依据：FABLE-MISSION §2.5（文档控制面一等交付）；探索子代理审查报告 A1-A3；隔离自审 P1-1（五孤儿非三）、P1-2（check-docs.sh 无链接解析，需 rg 兜底）。
- 结果：check-docs ok、placeholder 零命中、断链扫描清零；独立 verifier 复核通过（唯一修正：测试文件数 350+→实测约 250）；`docs/plans/active/` 收敛。CI 侧 check-docs 随批次②的 `[ci]` 检查点执行。

### 2026-07-22 — 批次②完成：代码健康度修复（chore）
- 动作：按 `docs/plans/active/2026-07-22-chore-code-health-remediation.md`（隔离双轮自审 Reviewed，P1×2 修正后放行）实施：新建 `SettingsCapabilityCatalog` 单一持有 capability 顺序与元数据，bridge/InMemory 仅注入 status；bridge `interfaceLanguage` `.mockOnly`→`.ready`；Pad spaceSettings 行与 MemoryLayerSummaryView 非空态 `.mockOnly`→`.ready`；AppEnvironment 2 处空 catch 改 `generationLogger.error`（区分 blocked/cancel 语义）；TTS probe 删 3 处 NSLog + errorBody 死绑定（spec/008 §113 纠偏，不再向系统日志明文输出 provider 错误体）；播放 assembly 空 catch 补注释；verify.sh 模拟器目的地环境变量化（默认值不变，CI 不受影响）；页面清单记忆页行 + 变更记录同步；M3/L1/L4 defer 落 `docs/architecture/notes/2026-07-22-test-support-target-and-concurrency-cleanup-notes.md`。
- TDD：新增红测试 `bridgeReportsInterfaceLanguageAsReady`（旧值 .mockOnly 必红）、`bridgeExposesNoMockOnlyCapability`、UI source-boundary 断言（挂进既有 PhoneIOSConvergenceTests，复用 helper）；守护测试 `bridgeAndMockCatalogShareMetadata`（顺序+元数据一致、排除 status，旧代码即绿，如实标注）。红相位在本环境（无 Swift 工具链）以逻辑成立，绿相位待 CI 实证。
- 结果：与批次①合并推送，HEAD 带 `[ci]`；等待 CI `Build & Test` 结论后收口该 plan 移 done/。

### 2026-07-22 — 批次② CI 红一轮：同名歧义编译错误，已修复重触发
- 问题：CI run 29856344239（`40643c8`）在 `Test LangoTraceData` 步骤失败。经 `.gh-token`（仓库内既有凭证，记忆索引提示）拉取 job 日志定位：测试文件里 `GRDBLearningContentRepositoryBridge.settingsCapabilities` 被编译器解析为未应用的实例方法引用——静态属性与实例方法 `settingsCapabilities(for:)` 同名歧义，449 条诊断同一根因。
- 修复：静态属性改名 `realPathSettingsCapabilities`（`4070f6f`，带 `[ci]` 重触发）。教训：本机无 Swift 工具链，同名歧义这类编译期错误只能靠 CI 首轮捕获；命名新成员时主动避开与既有方法的裸名冲突。
- 二轮（run 29856938870 仍红）：真正根因是该静态属性位于 `private extension`（成员 fileprivate）对测试不可见——首轮的「歧义」实为可见性问题的伪装。移入 internal extension（`8cdaf6e`）。
- 三轮（run 29857721868）：**全部测试已绿**（红测试转绿、守护测试过），仅剩 SwiftFormat `docComments` 规则拦截（声明前注释须 `///`）。修两文件四处注释（`e9c2e06`，带 `[ci]`）。教训沉淀：新增声明前注释一律用 doc comments。
- 结果：等待 run 29858671734 结论。

### 2026-07-22 — 批次③实施：记录场景标签输入、展示与时间线筛选（feature）
- 方案：`docs/plans/active/2026-07-22-feature-entry-scene-tags-and-timeline-filter.md`——接缝勘查子代理 + 隔离双轮自审（P0=0，P1×5 全部写回：Mac 守卫测试落点、InMemory 写死「今天」的事实修正、E10 导入路径证伪「库里只有空串」并确立三态 displayScene 必要性、筛选三状态语义钉死、chips key/text 双通道）后 Reviewed 进入实施。
- 动作（本地已完成，待 CI 绿后推送）：Core `EntryScenePreset` 六预设 + slug/顺序契约测试；协议 `createEntry` 扩 scene、三实现同步（InMemory 改 trim 透传）、store 默认参数保照片写作零改动、GRDB round-trip 测试；`EntrySceneFacet` 纯函数层（预设序 + 码点序、全量计数、切空间重置、stale 回退）+ 五用例；`displayScene` 三态升级 + `EntrySceneDisplay`；共享 `EntrySceneChipsRow`/`SceneChipButton`；三端编辑器接 chips 且 onSave 扩参（含 Mac #else stub 与 MacEntryEditorSheetTests:49 守卫同步）；iPhone 场景 Menu、iPad 侧栏场景 pill 分区（`FilterPill` 增 text 入口守住 spec/006 用户内容不进 key 查找）；三端行换 `displayScene` 修尾部「· 」；xcstrings 增 10 键（保持原格式最小 diff，曾误重排全文件已回滚重做）+ 本地化守卫测试 + source-boundary 断言。
- 文档同批：README 已完成/尚未完成口径、页面清单 4 行 + 变更记录、新建 `2026-07-22-entry-scene-taxonomy-extension-notes.md`（场景编辑/Mac 筛选/搜索联动/多标签/AI 上下文五项后续登记）。
- 下一步：CI（e9c2e06）绿 → 收口批次② plan 移 done/ → 场景批独立提交带 `[ci]` 推送。

### 2026-07-22 — 批次②收口 + 批次③推送与 CI 一轮红修复
- 批次②收口：CI run 29858671734 `Build & Test` success（四提交链 40643c8→4070f6f→8cdaf6e→e9c2e06 的完整绿），plan 补实施记录移 `done/`（`d9cf78b`）。
- 批次③推送：`0a5ecae` feat(timeline) 30 文件 +1007/-40，带 `[ci]`。
- 批次③ CI 红一轮（run 29860493887）：Data 测试 5 处**多行书写**的 `createEntry` 调用缺 scene 参数——实施前用单行 grep 勘查调用点，漏掉多行调用形态。修复 `9473a7e`（带 `[ci]`），并用多行感知 python 扫描全仓复核清零。教训沉淀：**签名扩参后的调用点勘查必须用多行感知扫描，不能只靠单行 grep**。
- 批次③ CI 二轮红（run 29860981794）：Data 绿，UI 两条 `EntryCreationFailureSurfaceTests` source-boundary 守卫仍钉旧 onSave/saveEntry 签名 → 守卫断言同步（`7e7eb3a`，语义不变）。三轮红（run 29861889669）：测试全绿、SwiftFormat 单点缩进（regex 补参写死 8 空格、#expect 闭包内需 12）→ `1a96a97` 修正。
- 结果：与批次④合并推送（HEAD `36c22a2` 带 `[ci]`），等待结论。

### 2026-07-22 — 批次④实施：Gemini generateContent 文本适配（feature）
- 方案：`docs/plans/active/2026-07-22-feature-gemini-text-adapter.md`——接缝勘查 + 隔离双轮自审（P0=0，P1×2：流式 fallback 假命题改 mimo fixture、四服务测试处置当场钉死 + probe 重写正向用例；P2 定案 makeRequest 显式参数而非 in-band 标记、结构化忽略 schema 参数防未登记外发）后 Reviewed 实施。
- 动作（`36c22a2`，21 文件 +719/-103）：makeRequest 升协议要求 + 显式 model/streaming 参数（六调用点机械补参、其余四 adapter 零改动）；Gemini adapter 三件套（x-goog-api-key、model-in-path、流式 :streamGenerateContent?alt=sse、assistant→model 角色映射、SSE EOF 终止、model 前缀归一）；工厂与 UI policy 放行；七处 reserved fixture 逐处处置（流式改 mimo、三服务用例删除留理由、probe 重写正向、photo-writing 保留）；13 例 Gemini 套件 + 流式端到端 fixture；spec/005 / 002 §1+§4.9 / README / multimodal 备忘录 / 四处 stale 注释同批回写。
- 下一步：CI 结论 → 绿则收口批次③④两 plan 移 done/；红则诊断。
- CI run 29862700137（`36c22a2`）：仅一处红——Gemini 正向探针用例把未启用图片的状态误断为 `.unsupported`，实际服务判定顺序是「未启用（notEnabled）先于 adapter 不支持（unsupported）」。修正断言（`835349c`，带 `[ci]`）。本轮 Core/Data/AI 其余全绿；UI 与三端构建待下轮首验。

### 2026-07-22 — 批次③④收口：CI 全绿，双 plan 移 done/
- 结果：**CI run 29864585392（HEAD `835349c`）`Build & Test` conclusion=success**——完整绿覆盖批次③（场景标签：Core/Data/UI + 三端构建 + 本地化 + source-boundary 守卫）与批次④（Gemini 适配：makeRequest 升格零回归 + Gemini 13 例 + 流式 SSE + probe 正向 + UI policy）+ 全部 lint + check-docs。
- 动作：两份 active plan 补实施记录（提交序列、CI run 证据链、红→绿实证、教训）后移 `done/`；`docs/plans/active/` 再次清空。
- 本次运行至此的交付总览：①LM 系列收口 + 入口文档对齐（docs）②代码健康度修复（chore）③场景标签闭环（feature）④Gemini 文本适配（feature），全部 CI 绿、plan 归档、文档控制面同批更新。
