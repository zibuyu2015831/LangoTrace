# 任务方案：学习者模型模块边界 + Ability 知识覆盖（LM01，v1 compute-on-read）

状态：Draft
自审核状态：Reviewed
类型：feature
创建日期：2026-06-15
最后更新日期：2026-06-15

## 用户确认记录

本方案在 2026-06-15 会话中由用户授权创建（用户指令："同意你的顺序规划，立即进行" + "创建 plan 后进行自审流程"）。该授权覆盖"方案文档创建 + 严格自审核"；本方案进入生产代码实现前仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

自审核后用户已定稿两项关键决策（2026-06-15，见第 13 节）：① 覆盖语义只做「事实性知识覆盖」，不做盲点 / 水平；② 模块归属采取长期最优——新建独立包 `LangoTraceLearnerModel`、基础设施一步到位、避免返工。

本方案是 [ADR-006 系统级三层学习者模型](../../decisions/006-system-level-three-layer-learner-model.md) 落地系列的第一份（LM01）。系列顺序见 ADR-006「影响」节：① 本方案（边界 + Ability 知识覆盖，接 plan-10）→ ② LM02（学习画像总览页 + 水平信号演进 + 盲点/分技能，接 plan-11）→ ③ LM03（语伴，最后）。编号 `LM01/LM02/LM03` 追加在既有 2026-06-11 的 01–15 系列之后，不重编原系列。

## 1. 需求或 bug 描述

ADR-006 确立语迹需要一个本地优先、系统级（横切语言空间）的学习者模型子系统（Learner Model），分 Ability / Memory / Style 三层。本方案落地该子系统的**模块边界**与 **Ability 层 v1 的知识覆盖能力**：

1. 建立独立包 `LangoTraceLearnerModel`，承载 Learner Model 领域模型与 `LearnerContextProvider` 供给契约（这是子系统对外的**唯一稳定边界**；其余消费者后续接入，不在本方案内自建 store）。
2. 实现 **Ability 知识覆盖（compute-on-read）**：从**用户沉淀行为**（plan-10 用户显式沉淀的 `memory_items`）聚合"用户已接触 / 已沉淀的目标语言知识点覆盖"，按语言（language code）维护，带 provenance 证据引用。
3. 删除级联：覆盖只读 active 源行，故源删除后下次读取自然不计入（Ability 是真派生、可丢弃重算，无需持久化覆盖结果）。

**严格语义边界（本方案的核心纪律）**：

- 「知识覆盖」= **事实性地图**：用户通过显式动作（沉淀）已接触哪些知识点。它是 ADR-006 §2 Ability 层的「知识覆盖」子项，不是水平判决。
- 本方案**不产出**任何 CEFR / band / 水平估计、不产出**盲点清单**（盲点须来自用户目标语产出而非 AI 候选，见 ADR-006 §4、idea-02 §14.2，属 LM02）。
- 本方案**不读取** `memory_candidates.difficulty` 等 AI 生成的难度 / 水平判断（ADR-006 §4 红线）。
- 本方案纯本地、零外发（ADR-006 §6：纯本地启发式不触发决策 #10，可先行）、不改 `derive()`、不建 UI（均属 LM02）。

## 2. 现状描述

以下事实已对照当前代码（2026-06-15 HEAD `9e23152`）核实：

- 仓库现有 6 个 Swift Package（`LangoTraceCore` / `Data` / `AI` / `Speech` / `Sync` / `UI`），**不存在 `LangoTraceLearnerModel` 包，也不存在任何 Learner Model / ProficiencyProfile / AbilityCoverage 模型或 store**（`rg -li "learner|proficiency|abilitycoverage"` 命中均为无关上下文）。
- GRDB migration 头部当前为 `v15_reset_reading_explanation_cache_for_unix_epoch`（`Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`）。plan-10（E7）将新增 `v16_create_memory_item_infrastructure`。**本方案 v1 不新增 migration**（见第 12 节，覆盖 compute-on-read，无持久化）。
- plan-10 的 `memory_items` schema（其方案第 12.1 节）：主键 + `space_id TEXT NOT NULL REFERENCES language_spaces(id)`、`kind TEXT CHECK ('wordPhrase','sentence')`、`target_text` / `native_text` / `source_candidate_id` / `deleted_at` 等。**关键事实**：`memory_items` **无 `language_code` 列**，按语言聚合须 JOIN `language_spaces.target_language_code`；`kind` **仅 2 个取值**。
- `language_spaces` 表含 `target_language_code`（`GRDBLanguageSpaceRepository`）。
- `LangoTrace` 是 CEFR 枚举（`A1…C2`，默认 `B1`），仅 onboarding 设定一次；`ExplanationLanguageMode.derive(from:)`（`Packages/LangoTraceCore`）已按 level 把阅读解释分三档，`ReadingDocumentStore` 已消费。本方案**不触碰** `derive()` 与 level。
- `memory_candidates` 已在 GRDB 持久化（`v4`），其 `difficulty` / `kind`（含 grammarPoint / errorPattern）由 AI 赋值——按 ADR-006 §4 红线，**这些字段不得作为水平证据，本方案不读取该表**。
- `memory_items`（plan-10 产出）是本方案 v1 覆盖的**前置依赖与唯一行为信号源**；plan-10 尚未实施。
- 2026-06-11 Mac 验证门已于 commit `02965f2` 关闭，ADR-006「影响」节"先关验证门再实现"硬门控已满足。

## 3. 目标

1. 新建独立包 `LangoTraceLearnerModel`（见 12.1），承载领域模型——`AbilityCoverage`（按 language code）、`AbilityCoverageEntry`（覆盖条目 + 结构性 kind 分组 + 接触计数）、`LearnerEvidenceRef`（provenance 证据引用，支持单条 FK 与证据集两种粒度）、`LearnerSourceType`（可扩展枚举）、`LearnerContextProvider` 协议（对外供给 Ability 上下文的唯一 seam）。
2. `GRDBLearnerContextProvider.abilityCoverage(languageCode:)`（新包内）——经注入的 `AppDatabase.reader` compute-on-read 聚合，JOIN `language_spaces` 取 `target_language_code` 按语言合并该语言全部空间的 active `memory_items`，按 text 归并、kind 分组、计数、挂 provenance。
3. App：`AppEnvironment` 装配 `GRDBLearnerContextProvider(reader:)`（暂无 UI 消费者，契约就绪供 LM02 接入）。
4. 全程零外发、零向量 / embedding、无 migration、不改 `derive()`、不产出 band / 盲点、不读 `memory_candidates`、不建 UI。

## 4. 范围

- **新建 `Packages/LangoTraceLearnerModel`**（Package.swift，依赖 Core + Data + GRDB；target + 测试 target）：`AbilityCoverage`、`AbilityCoverageEntry`、`AbilityCoverageKind`、`LearnerEvidenceRef`、`LearnerSourceType`、`LearnerContextProvider` 协议、`GRDBLearnerContextProvider`（覆盖聚合 + JOIN language_spaces + provenance；compute-on-read，无新表）。
- `Packages/LangoTraceData`：`AppDatabase` 新增 `public var reader: DatabaseReader` 读 seam（供新包注入消费）。
- `project.yml`：`packages:` 增 `LangoTraceLearnerModel`；`LangoTrace-iOS` / `LangoTrace-macOS` target 依赖新增本包。
- `LangoTraceApp/AppEnvironment.swift`：装配 `GRDBLearnerContextProvider(reader: appDatabase.reader)`。
- 文档：`docs/architecture/001-initial-module-boundaries.md`（登记新包边界与依赖方向）、`docs/architecture/002-system-map.md`（新增 Learner Model 子系统与数据流）、`docs/platform-page-inventory.md`（记录"LM01 为无 UI 数据层"）、`docs/spec/007`（登记 Ability 覆盖为 compute-on-read 无持久化派生）、ADR-006 实施回写。

## 5. 不做什么

- **v1 不建分析账本表（intake ledger）与任何 migration**。理由：ADR-006 §9 规定 Ability 走高水位 **cursor 增量重算**（非行级账本），而 v1 覆盖是 compute-on-read（源即真相、删除级联天然由 active-only 读实现），引入行级账本是"建了不读"的写放大与会被推翻的临时结构。账本按正确的 cursor 形态推迟到 LM02 引入 band 重估 / 增量聚合时一次建对。
- **不建学习画像总览页 UI**（三端呈现页属 LM02）。本方案只到 `LearnerContextProvider` 契约 + 单元测试可验证，不接任何视图。
- **不做水平 band 判决 / CEFR 重估 / 分技能估计 / 盲点清单**（属 LM02，盲点须用户产出证据，本阶段证据稀疏）。
- **不触碰 `ExplanationLanguageMode.derive(from:)` 与 `LanguageLevel`**（迟滞策略属 LM02，避免 ADR-006 §10 警示的"体验在脚下漂移"）。
- **不做任何外发 / AI 校准 / 自动后台分析请求**（ADR-006 §6 隐私前置闸门，属 v2）。
- **不读取 `memory_candidates` 表 / 不消费 AI difficulty**（ADR-006 §4 红线）。
- **不实现 Memory / Style 两层**（仅建立可容纳它们的 Provider 边界，本方案只填 Ability 知识覆盖）。
- **不建向量表 / embedding / 语义检索**（核心决策 #12 + embedding 备忘录红线）。
- **不实现导出 / 备份 / 同步**：Ability 是真派生、local-only 不备份不同步（ADR-006 §8）；覆盖 compute-on-read 无持久化，天然不进导出包。

## 6. 证据与决策依据

- ADR 证据：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §1（系统级横切空间）、§2（Ability 含「知识覆盖」子项）、§3（Ability 按 language code）、§4（证据红线）、§6（隐私前置闸门：纯本地先行）、§8（Ability local-only 真派生）、§9（分析账本 cursor 形态——本方案据此**不在 v1 建行级账本**）、影响节（系列顺序与 Mac 验证门硬门控）。
- idea 证据：`docs/idea/01-learner-model.md` §13.2（分区键）、§13.3（删除三件套）、§14.1–14.2（分析账本三义、Ability=cursor）；`docs/idea/02-dynamic-proficiency-assessment.md` §4（有效证据 = 用户产出 / 行为）、§14.2（"盲点来自用户产出非 AI 候选"——故本方案**不做盲点**，只做事实覆盖）。
- 代码证据：见第 2 节逐条核实。
- 依赖契约：本方案覆盖依赖 plan-10（`docs/plans/active/2026-06-11-10-feature-memory-deposit-foundation.md`）的 `memory_items`；plan-10 须先落地。`LearnerSourceType` 设计为可扩展枚举，未来练习评分等行为信号可加入而无需改动 Provider 契约。
- workflow 引用：本方案 v1 不新增 migration，不命中 add-storage-migration 的建表流程（若 LM02 引入 cursor 账本则届时遵循）；不命中 AI Provider / TTS / 平台页面 / Prompt workflow（零外发、无 UI）。
- 备忘录检查（按 `docs/architecture/notes/README.md`）：
  - [2026-05-27-embedding-infrastructure-notes.md](../../architecture/notes/2026-05-27-embedding-infrastructure-notes.md)：采纳为红线——不建向量表、不为用户内容生成 embedding；覆盖聚合是结构化计数，非向量召回。
  - [2026-05-25-language-companion-extension-notes.md](../../architecture/notes/2026-05-25-language-companion-extension-notes.md)：其 per-space 记忆假设须与 ADR-006 对齐——本方案只做 Ability，不触 Memory，对齐工作留 LM03，记入剩余风险。

```text
证据能证明什么：ADR-006 §2 把「知识覆盖」列为 Ability 子项，故"事实性覆盖"合法；§4 红线只禁"AI 难度 / 水平判断作水平证据"；idea-02 §14.2 要求盲点来自用户产出（故本方案不做盲点）。
证据不能证明什么：idea-01 §11 的"独立包 vs Core/Data"原为待决项，已由用户 2026-06-15 定稿为独立包（见 12.1），ADR 本身未强制该实现选择；ADR 未要求 v1 即建账本（§9 明确 Ability 用 cursor）——故 v1 compute-on-read 不建表是合规简化。
迁移前提：本方案 v1 无 migration；覆盖聚合前提是 plan-10 memory_items 与 language_spaces.target_language_code 可查询。
照搬风险：把 memory_candidates.difficulty 或 candidate kind（grammarPoint/errorPattern）当覆盖证据会触发 ADR-006 §4 红线——已在第 5 节明确不读该表、kind 收敛为 memory_items 真实 2 值。
```

## 7. 约束映射与验证路径

### 约束 1：证据红线——不读 AI 生成物、不做水平推断

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §4、`docs/idea/02-dynamic-proficiency-assessment.md` §4
- 适用范围：覆盖聚合的输入源与输出语义
- 严重度：blocker
- 执行或验证方式：正向单元测试 + 代码审查
- 验证提示：① 聚合 SQL 只 FROM / JOIN `memory_items` 与 `language_spaces`，**不 FROM / JOIN `memory_candidates`**（`rg "memory_candidates" Packages/LangoTraceLearnerModel/Sources` 无命中）；② 正向断言：构造一条"仅存在于 candidate、未被用户沉淀"的 fixture，断言它**不出现**在覆盖结果中；③ 覆盖输出模型不含任何 band / level / difficulty 字段。

### 约束 2：Ability 按 language code keyed，需 JOIN 解析

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §3、`docs/idea/01-learner-model.md` §13.2
- 适用范围：覆盖聚合的分区键与查询
- 严重度：blocker
- 执行或验证方式：单元测试
- 验证提示：聚合查询 `JOIN language_spaces ON memory_items.space_id = language_spaces.id` 取 `target_language_code` 作分区键；构造同一 language code 的两个语言空间各沉淀记忆项，断言覆盖按 language code 合并为一份（而非按 space id 分裂）；空间改名不影响归并（按 code 不按名）。

### 约束 3：纯本地、零外发

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §6、核心决策 #10、ADR-005
- 适用范围：整个 Learner Model 模块
- 严重度：blocker
- 执行或验证方式：代码审查 + 依赖方向检查
- 验证提示：`LangoTraceLearnerModel` 包不 import 网络 / AI Provider 类型、不依赖 `LangoTraceAI`（Package.swift deps 仅 Core + Data + GRDB）；`rg -i "urlsession|urlrequest|provider|http" Packages/LangoTraceLearnerModel/Sources` 无网络命中。

### 约束 4：Ability 真派生——compute-on-read、可丢弃重算、不进备份 / 同步

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §8、核心决策 #12
- 适用范围：覆盖持久化策略
- 严重度：blocker
- 执行或验证方式：单元测试 + 代码审查
- 验证提示：覆盖 compute-on-read，**不新增任何持久化表**（`git diff` 无 migration 变更）；同一 fixture 多次读取结果一致（无副作用、读路径不写库）；删除源行后重算结果相应变化。

### 约束 5：源删除级联——active-only 读自动失效

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §7（删除三件套）、`docs/idea/01-learner-model.md` §13.3
- 适用范围：覆盖聚合
- 严重度：blocker
- 执行或验证方式：单元测试
- 验证提示：软删除一条 `memory_items` 后覆盖重算不再计入该项；同一 language code 双空间，软删其一，覆盖仍含另一空间贡献；删除该语言最后一个空间的全部沉淀（无 active memory_items）→ 该 language code 覆盖归零。

### 约束 6：模块依赖方向清晰

- 来源：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 影响节、`docs/architecture/001-initial-module-boundaries.md`、`docs/spec/004-swiftui-architecture.md`
- 适用范围：Learner Model 在包间的位置
- 严重度：warn
- 执行或验证方式：代码审查 + 编译依赖检查
- 验证提示：模型 / 协议 / GRDB 实现集中在 `LangoTraceLearnerModel` 包（deps 仅 Core + Data + GRDB）；Data / Core 不反向依赖本包（无环）；消费者经 `LearnerContextProvider` 取用，不依赖具体实现。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceLearnerModel/Package.swift`（新增包定义：deps Core + Data + GRDB；target + 测试 target）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/AbilityCoverage.swift`（新增：`AbilityCoverage` / `AbilityCoverageEntry` / `AbilityCoverageKind`）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/LearnerContextProvider.swift`（新增：协议 + `LearnerEvidenceRef` / `LearnerSourceType`）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/GRDBLearnerContextProvider.swift`（新增：覆盖聚合 compute-on-read + JOIN language_spaces + provenance）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（新增 `public var reader: DatabaseReader` 读 seam）
- `project.yml`（`packages:` 与 app target 依赖）
- `LangoTraceApp/AppEnvironment.swift`（装配）
- 对应 `Tests` 目录新增测试（见第 15 节）

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMemoryItemRepository.swift`（plan-10 产出，覆盖聚合的输入源 + repository 约定模式）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift`（`target_language_code` 来源 + JOIN 参照）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`（candidate 派生查询模式参考，反例：本方案不读该表）
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/`（GRDB 测试 fixture 模式）

## 10. 涉及的文档路径

- 本方案。
- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md)（权威依据，实施后回写实施状态）。
- `docs/architecture/002-system-map.md`（新增 Learner Model 子系统、数据流与依赖方向）。
- `docs/platform-page-inventory.md`（记录 LM01 为无 UI 数据层，无新增页面）。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（登记 Ability 覆盖为 compute-on-read 无持久化派生，不进导出 / 同步）。
- 前序依赖：`docs/plans/active/2026-06-11-10-feature-memory-deposit-foundation.md`（plan-10，memory_items）。
- 只读对齐：`docs/architecture/notes/2026-05-25-language-companion-extension-notes.md`（per-space 记忆假设对齐留 LM03）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### 12.1 模块归属决策（2026-06-15 用户定稿：独立包）

idea-01 §11 的待决项"新建独立 `LangoTraceLearnerModel` 包 vs 跨 Core/Data 命名空间"，用户 2026-06-15 定稿："从一开始采取最优方案，基础设施需要从一开始搭建完整，避免后续开发需要返工"。据此确立：

- **新建独立 Swift Package `Packages/LangoTraceLearnerModel`** 作为 Learner Model 子系统的强域边界（对应 ADR-006 §1"系统级横切子系统"）。该包是三层（Ability / Memory / Style）、provenance、未来多消费者的长期归属，从首发即建立编译期物理边界。
  - 依赖：`LangoTraceCore`（共享类型）+ `LangoTraceData`（数据库访问）+ `GRDB`。
  - 内容：Learner 领域模型、`LearnerContextProvider` 协议、`GRDBLearnerContextProvider`，及未来三层的 repository / 服务。
  - 消费者（UI / App / 未来 AI 语伴）依赖本包；本包**不被** Core / Data 反向依赖（无环）。
- **schema 仍集中在 Data 的 `AppDatabase`，不在 LM01 引入跨包 migration 框架**。权衡与理由：① 现有全部表（language_spaces / memory_candidates / practice / reading 等）均由 `AppDatabase` 单一 `DatabaseMigrator` 集中注册，保证 migration **顺序确定性**；引入"域包各自贡献 migration"的扩展点是投机性框架，本身是返工风险；② Ability 覆盖 v1 是 compute-on-read **无新表**，LM02 的 cursor 账本届时按现有方式加一条 migration 到 `AppDatabase` 即可——新包通过下述读 / 写 seam 访问该表，无需重构。Data owns 物理 schema、LearnerModel owns 域逻辑，与 LearnerModel 读 `memory_items`（Data 所有）的跨域读一致。
- **Data 暴露读 seam（LM01 落地）**：`AppDatabase` 新增 `public var reader: DatabaseReader { databaseQueue }`（只读，最小公开面），供 `GRDBLearnerContextProvider` 经注入消费。LM01 只做 compute-on-read，仅需 reader；LM02 引入账本写入时再补写 seam（一次性小增量，非框架返工）。
- **project.yml 与 app target 接线**：`packages:` 增 `LangoTraceLearnerModel`；`LangoTrace-iOS` / `LangoTrace-macOS` target 依赖新增本包（`AppEnvironment` 在 app target 装配 Provider）。
- **包内边界清晰**：模型 / 协议 / 实现按 `Learner*` / `AbilityCoverage*` 命名；Provider 协议与实现分文件，消费者只依赖协议。

### 12.2 Core 模型与契约

- `AbilityCoverage`：`languageCode: String`、`entries: [AbilityCoverageEntry]`、`generatedAt: Date`。**不含** band / level / 任何水平字段。
- `AbilityCoverageEntry`：`text: String`（目标语言知识点快照）、`kind: AbilityCoverageKind`、`occurrenceCount: Int`（用户行为接触次数）、`evidence: [LearnerEvidenceRef]`（provenance）。
- `AbilityCoverageKind`：**v1 收敛为 `wordPhrase` / `sentence`**（与 plan-10 `memory_items.kind` 的 2 个真实取值一一对应）。`grammarPoint` / `errorPattern` 需练习评分 / 查词信号且只存在于被禁用的 candidate，**不进 v1**，留 LM02。kind 是结构性分组，不含难度 / 水平含义。
- `LearnerEvidenceRef`：`sourceType: LearnerSourceType`、`sourceID: String`（单条 FK 粒度）；为 Ability/Style 未来"证据集 + 权重"粒度预留可选 `weight: Double?`（ADR-006 §9 粒度警示——schema 不强制单 FK）。
- `LearnerSourceType`：可扩展枚举，v1 仅 `memoryItem`；未来 `practiceResult` 等加入不破坏契约。
- `LearnerContextProvider` 协议（在 `LangoTraceLearnerModel` 包）：`func abilityCoverage(languageCode: String) -> AbilityCoverage`（同步只读；若实施时既有 repository 为 async 风格则对齐为 async）。

以上模型与协议均位于新包 `LangoTraceLearnerModel`（见 12.1），不再放 Core。

### 12.3 覆盖聚合（compute-on-read）

`GRDBLearnerContextProvider`（`LangoTraceLearnerModel` 包）通过构造注入的 `DatabaseReader`（= `AppDatabase.reader`，见 12.1 读 seam）查询，`abilityCoverage(languageCode:)`：

1. 查询该 language code 下全部空间的 active `memory_items`：
   `SELECT mi.* FROM memory_items mi JOIN language_spaces ls ON mi.space_id = ls.id WHERE ls.target_language_code = ? AND mi.deleted_at IS NULL AND ls.deleted_at IS NULL`（memory_items / language_spaces 软删字段以 plan-10 与现有 language_spaces 实际列名为准；可用原始 SQL 行解码或复用 Data 公开的记录类型，避免耦合 Data 内部布局）。
2. 按 `target_text` 归并相同知识点，`occurrenceCount` = 该文本出现次数，`kind` 由 `memory_items.kind` 直接映射（2 值），`evidence` 收集各来源 `memory_item.id`（`sourceType = .memoryItem`）。
3. 返回 `AbilityCoverage`。**读路径不写任何表**（CQS：无副作用）。

无持久化、无账本：覆盖是真派生，源即真相。删除级联由步骤 1 的 `deleted_at IS NULL` 自动实现（约束 5）。

### 12.4 实施步骤（TDD）

1. 新建 `Packages/LangoTraceLearnerModel`（Package.swift：deps Core + Data + GRDB；target + 测试 target）；`project.yml` 增 `packages:` 条目与 app target 依赖；`xcodegen generate` 后确认工程可解析。
2. LearnerModel 包：新增 `AbilityCoverage` / `AbilityCoverageEntry` / `AbilityCoverageKind` / `LearnerEvidenceRef` / `LearnerSourceType` / `LearnerContextProvider`（纯值类型 + 协议，无 IO）。先写值类型测试（可独立于 plan-10 先行红绿）。
3. Data：`AppDatabase` 增 `public var reader: DatabaseReader { databaseQueue }`（最小读 seam）。
4. LearnerModel 包：先写失败的覆盖聚合测试（含红线正向断言、按 language code JOIN 合并、软删失效、双空间合并），再实现 `GRDBLearnerContextProvider`。**此步红绿前提 = plan-10 的 `memory_items` migration 与 repository 已合入**（否则 fixture 无表可插、无法编译）。测试经注入内存 `DatabaseReader`（GRDB in-memory queue）构造。
5. App：`AppEnvironment` 装配 `GRDBLearnerContextProvider(reader: appDatabase.reader)`。
6. 文档同步（architecture/001 登记新包边界、system-map 新增子系统、page-inventory 记录无 UI、spec/007 登记 compute-on-read、ADR-006 实施回写）与验证收口。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-15
审核方式：隔离子代理审查（general-purpose 子代理只读审查 + 主会话核验写回）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地）
未使用隔离审查的原因：不适用，已使用隔离子代理。
发现摘要（子代理原始分级，主会话已逐条核验）：
  第一轮（架构）：
  - P0-1：初稿把 memory_items 当 Ability「覆盖视图（盲点清单）」证据，混淆了「事实覆盖」与「盲点 / 水平」。核验：ADR-006 §2「知识覆盖」是 Ability 合法子项，故事实覆盖来自用户沉淀行为可成立；但 idea-02 §14.2 盲点须来自用户产出非 AI 候选。结论：部分成立。修订——LM01 只做事实性「知识覆盖」、显式不做盲点 / band，标题与全文从「覆盖视图（盲点清单）」改为「知识覆盖」；语义边界写入第 1 节。
  - P0-2：覆盖「按 language code」但 memory_items 只有 space_id 无 language_code。核验成立（plan-10 schema 确认）。修订——12.3 显式 JOIN language_spaces 取 target_language_code；约束 2 补改名不影响归并测试。
  - P1-1：AbilityCoverageKind 5 值 vs memory_items.kind 仅 2 值（grammarPoint/errorPattern 只在被禁用的 candidate）。核验成立。修订——kind 收敛为 wordPhrase/sentence，grammarPoint/errorPattern 留 LM02。
  - P1-2：行级账本与 ADR-006 §9（Ability=cursor）矛盾，且 compute-on-read 下账本「建了不读」是写放大 + 会被推翻的临时结构。核验成立且重要。修订——v1 去掉账本表与 migration，纯 compute-on-read；账本按 cursor 形态推迟 LM02（写入第 5 节不做什么 + 剩余风险）。
  第二轮（测试 / 安全 / 落地）：
  - P1-3：红线机械验证 rg "difficulty" 太弱。修订——约束 1 改为正向断言（未沉淀 candidate 不出现在覆盖）+ 断言聚合不 FROM/JOIN memory_candidates。
  - P1-4：先失败测试依赖未落地的 plan-10。修订——12.4 / 15 节明确 Core 值类型测试可独立先行、Data 测试以 plan-10 合入为红绿前提。
  - P2-2：删除级联测试缺分支。修订——约束 5 / 15 节补「双空间软删其一仍含另一空间」；硬清理悬挂写入剩余风险。
  - P2-3：遗漏 spec/007 文档影响。修订——第 4/10/17 节补 spec/007 登记 compute-on-read 无持久化派生。
  - P2-1（读路径 upsert 账本破坏 CQS）：随 P1-2 去账本自动消解。
  - P3-1（模块归属待决处理得当）：保留为待用户确认（12.1）。
写回修改：以上各条已写回第 1、3、4、5、6、7、8、12、15、17、20 节并重拟标题。
用户确认结果（2026-06-15）：
  1. 【核心语义，P0-1】已确认：LM01 只做「事实性知识覆盖」（来自用户沉淀行为、不读 AI difficulty、不做盲点 / band），盲点与水平信号留 LM02。
  2. 【模块归属，P3-1】已定稿：采取长期最优、基础设施一步到位——新建独立 `LangoTraceLearnerModel` 包；schema 仍集中 Data、Data 暴露读 seam（见 12.1，相应更新第 4 / 8 / 15 / 16 / 17 节）。
仍需用户确认的问题：
  3. LM01 不含任何 UI（覆盖仅到 LearnerContextProvider 契约 + 测试），确认接受"本阶段无可视产出、靠测试验证"。
  4. 确认 plan-10 为硬前置（其 memory_items 落地后本方案才能进入实现）。
是否允许进入实现：暂不允许。语义与模块归属已确认；仍需用户就第 3/4 项确认 + plan-10 落地后，将状态推进到 User Approved。
```

## 14. 复查方法

- 代码：LearnerModel 包值类型测试、覆盖聚合测试全绿；`rg "memory_candidates" Packages/LangoTraceLearnerModel/Sources` 无命中（红线）；`git diff` 无新增 migration（约束 4）。
- 契约：`LearnerContextProvider.abilityCoverage(languageCode:)` 在测试 fixture 下符合预期分组 / 计数 / provenance；输出模型无 band / level 字段。
- 故障路径：源软删除后覆盖重算正确；同 language code 多空间合并为一份；空数据返回空覆盖而非崩溃；未沉淀 candidate 不进覆盖。

## 15. TDD / 测试落点

```text
测试落点（均在新包 LangoTraceLearnerModel 的测试 target）：
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/AbilityCoverageModelTests.swift（新增，值类型 / 分组语义，可独立先行）
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/GRDBLearnerContextProviderTests.swift（新增，含红线正向断言 / 按 language code JOIN 合并 / 软删失效 / 双空间合并；经注入内存 DatabaseReader 构造）
红绿前提：值类型测试可在 plan-10 之前独立红绿；覆盖聚合测试以 plan-10 的 memory_items migration 与 repository 已合入为前提（否则 fixture 无表可插、无法编译）。
先失败用例：
  （独立可先行）AbilityCoverageModelTests.entriesGroupByStructuralKind —— 预期失败原因：AbilityCoverage / AbilityCoverageEntry 尚不存在，编译失败。
  （依赖 plan-10）GRDBLearnerContextProviderTests.abilityCoverageAggregatesDepositedItemsByLanguageCode —— 预期失败原因：LearnerContextProvider / GRDBLearnerContextProvider 尚不存在，编译失败。
红线正向断言：GRDBLearnerContextProviderTests.unDepositedCandidateDoesNotAppearInCoverage —— 构造仅存在于 memory_candidates、未沉淀的项，断言不在覆盖结果中。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceLearnerModel
不新增单元测试的原因（如适用）：不适用，本任务全程 TDD。
```

## 16. 验证命令

```bash
# 工程生成（新增包后必跑）
xcodegen generate

# 聚焦 / 新包完整
swift test --package-path Packages/LangoTraceLearnerModel

# 受影响 package（Data 新增 reader seam）
swift test --package-path Packages/LangoTraceData

# 文档
scripts/check-docs.sh
```

本方案 v1 无 schema 变化，但**新增 Swift Package + project.yml + app target 依赖属包边界 / XcodeGen 变化**；收口前是否补跑 `scripts/verify.sh`（含三端构建，验证新包接线）按 CLAUDE.md 1.4 节第 7/8 条与用户确认，默认放 GitHub Actions（仓库临时设 public），记录为待 macOS / CI 环境收口项。

## 17. 文档影响检查

- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md)：实施后回写"LM01 已落地 Ability 知识覆盖 + LearnerContextProvider 边界（独立包 LangoTraceLearnerModel，compute-on-read，无账本）"。
- `docs/architecture/001-initial-module-boundaries.md`：登记新包 `LangoTraceLearnerModel` 的职责、依赖方向（→ Core + Data）与消费者（命中"包边界变化"审查触发）。
- `docs/architecture/002-system-map.md`：新增 Learner Model 子系统、入口点、数据流与依赖方向（命中"包边界 / 数据流变化"审查触发）。
- `project.yml`：新增 package 与 app target 依赖（命中"XcodeGen / 包边界变化"审查触发）。
- `docs/platform-page-inventory.md`：记录 LM01 无新增页面（数据层）。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：登记 Ability 覆盖为 compute-on-read 无持久化派生，不进导出 / 同步 / 备份（与 ADR-006 §8 一致）。
- review：本方案 v1 无 schema 变化，但新增子系统与数据流命中专项审查触发条件，实施后按 `docs/review/README.md` 创建 round 或在本方案记录跳过原因。
- 是否需要新 ADR：否，本方案是 ADR-006 的实施，沿用其全部决策。

## 18. 实施记录

（实施时按时间追加；deferred / aborted 项按模板记录决策日志。）

## 19. 完成标准

1. 第 3 节目标全部有代码、测试或文档证据。
2. 第 16 节聚焦与受影响 package 测试全绿。
3. ADR-006 实施回写、`docs/architecture/002-system-map.md`、`docs/platform-page-inventory.md`、`docs/spec/007` 已同步。
4. plan-vs-shipped 对账完成（Core 模型、Provider 契约、覆盖聚合 JOIN、provenance、软删失效、按 language code 合并、红线逐项核对），scope-down 与 deferred 项已记录。

## 20. 剩余风险

- **plan-10 前置**：本方案覆盖依赖 `memory_items`；plan-10 未落地前不能进入实现。已在用户确认记录与依赖契约写明。
- **v1 证据稀疏且仅覆盖、无盲点 / 水平**：仅 memory_items 作行为信号，覆盖内容有限且不含能力判决；这是有意的 v1 范围（idea-02 §14.2 盲点须用户产出），盲点 / band / 分技能 / 练习评分信号待 LM02 与练习评分接入（`LearnerSourceType` 已可扩展）。
- **账本推迟到 LM02**：v1 无账本，LM02 引入 band 重估 / 增量聚合时须按 ADR-006 §9 的 cursor 高水位形态一次建对；compute-on-read 在数据量增大后的性能需届时评估（v1 数据量小可接受）。
- **硬清理悬挂**：v1 覆盖只读 active 行，软删天然失效；未来若 plan-13/14 引入 memory_items 硬清理，provenance 引用的悬挂处理需独立评估（属未来能力，不在本轮）。
- **2026-05-25 语伴备忘录对齐**：其 per-space 记忆假设与 ADR-006 系统级 Memory 的对齐留到 LM03；本方案只做 Ability，不受影响，但记录该未决对齐。
- **跨域读 memory_items**：LearnerModel 包经读 seam 跨域读 Data 所有的 `memory_items` / `language_spaces`，是聚合型子系统的固有耦合；以原始 SQL 或 Data 公开记录类型实现，避免耦合 Data 内部布局；列名变更需回归测试覆盖。
- **LM02 写 seam**：本方案只暴露 `reader`；LM02 引入账本写入时需补写访问（Data 公开 writer 或 LearnerModel 专用写方法），属一次性小增量，已在 12.1 标注。
- 本环境（Linux）无法运行 Swift 工具链与模拟器，全部测试须在 macOS / GitHub Actions 验证；新增包接线尤其需 CI 三端构建确认。
