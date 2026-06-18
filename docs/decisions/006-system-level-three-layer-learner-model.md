# ADR-006: 采用系统级三层学习者模型（Learner Model）

日期：2026-06-15

状态：Accepted

## 背景

语迹 LangoTrace 需要一个「App 对用户的、持续积累的理解」来支撑材料生成难度、解释语言模式、练习选材、复习排序、进步可见以及未来的「语伴」。当前这一理解只由一个静态值承担，且已经在驱动真实体验：

- `LanguageLevel` 是 CEFR 枚举（`A1…C2`，默认 `B1`），仅在首次启动 onboarding 设定一次，之后只能在语言空间编辑里手动改，不随使用更新。
- 这个静态自评已经在驱动体验：`ExplanationLanguageMode.derive(from:)`（`Packages/LangoTraceCore`）按 level 把阅读解释分成源语言 / 双语桥接 / 目标语沉浸三档，`ReadingDocumentStore` 已消费。体验依赖 level，而 level 只是一次主观猜测。
- 学习材料分析已产出 `memory_candidates`（带 `difficulty` / `kind`，已落 GRDB），是一条已存在但未被用来反推水平的证据流。

围绕「语伴」的探讨（`docs/idea/03-conversation-partner.md`）暴露出上游缺口：语伴的难度自适应依赖一个可信的水平信号，而水平信号若建立在陈旧的一次性自评上，等于把失败模式焊死在新功能里。三份构想文档（`docs/idea/01-learner-model.md`、`02-dynamic-proficiency-assessment.md`、`03-conversation-partner.md`）经多轮迭代收敛为同一个判断：把「关于用户的派生知识」抽象为一个统一的本地子系统。本 ADR 将该判断升格为正式决策。

本 ADR 是 `docs/idea/01-learner-model.md`（§13 / §14 定稿）与 `docs/idea/02-dynamic-proficiency-assessment.md`（§14 定稿）的权威化结果。**动态水平评估不单独出 ADR，作为本模型 Ability 层折叠进本文件**。「语伴」（idea 03）是本模型的消费者，依赖链最长，单独排在最后，本 ADR 不替其定边界。

## 决策

语迹采用一个**本地优先、持续演进、系统级（横切所有语言空间）**的子系统——学习者模型（Learner Model），统一承载 App 对用户的理解，分三层维护，并遵守以下决策。

### 1. Learner Model 是系统级、横切语言空间的子系统（补充决策 #4 / ADR-004）

- 语言空间仍是核心信息模型（ADR-004 不变），但 Learner Model **不归属任何单一语言空间，横切所有空间**。
- 这是对 ADR-004 的补充而非推翻：空间是用户可见的学习档案聚合边界，Learner Model 是 App 内部对用户本身的理解，二者正交。
- 治理上提供**统一的「查看 / 导出 / 删除 App 对我的了解」入口**，而非散在多处。

### 2. 三层模型：Ability / Memory / Style

| 层 | 是什么 | 分区键 | 主证据 | v1 落地 |
| --- | --- | --- | --- | --- |
| **Ability** | 语言 X 的水平 / 知识覆盖 / 常犯错误 | 按 language code（同语言多空间共享一份） | 用户行为 / 产出（AI 生成物禁用，见决策 4） | 纯本地启发式 |
| **Memory** | 生活事实 / 学习目标 + 对话情景 | 系统级（事实 / 目标）+ per-space（对话情景） | 记录 / 对话（显式记住优先，自动抽取 v2） | 显式记住先行 |
| **Style** | 表达 + 认知印记：写作风格 + 观察角度 / 思维方式 / 思维习惯 | 系统级跨空间 | 源语言产出为主（目标语打折，见决策 4） | 表面写作风格 = 本地；认知风格 = AI 校准、后置 opt-in |

- 区分口诀：**Style = 模式 / 倾向，Memory = 事实 / 事件，Ability = 能力 / 水平。**
- 三层是 Learner Model 的内部分解，与智能辅导系统（ITS）三元组（learner / domain / teaching）正交。
- 「学习目标」二分：生活动机（如移民）归 Memory；语言水平目标（如英语到 B2）归 Ability。

### 3. 分区键按层而定 + 全局共享

- Style 与 Memory（生活事实 / 目标）**全局共享**；新建语言空间即复用——冷启动红利（「它本来就认识你」）。
- 对话情景记忆仍 **per-space**（属那条对话）。
- **Ability 按 language code keyed，不按空间 id**。依据：产品不鼓励同一学习语言建多个空间，但底层基础设施明确允许（`target_language_code` 无唯一约束，见 `spec/002-navigation-and-routing.md`）。同语言多空间若按空间 id 存会把同一门语言的水平 / 错误分裂成多份、证据稀薄且互不相通。故 Ability 按语言聚合一份：
  - 内部二分：水平 band / 分技能 / 常犯错误 / 语法盲点 = 按语言；词汇 / 知识「覆盖」= 按语言 + 标签 / 场景切片（工作 vs 旅行词汇是 domain 差异，domain 归标签 / 场景而非空间，呼应决策 #5）。
  - 不跨语言：英语 ≠ 日语，各一份；Ability 不像 Style / Memory 做语言无关。
- **不提供单空间「干净重来」opt-out**：共享是 App 级；若未来出现「敏感空间隔离」诉求再议（见复审条件）。

### 4. 证据红线：AI 生成物禁用于估水平

- 评估水平所用材料必须是**用户的输入 / 行为**，绝不能是 AI 生成的内容。AI 生成的学习文本、AI 赋予的 `difficulty` 标签、AI 选定的候选词，一律不得作为水平证据。
- 理由（闭环自证）：`memory_candidates.difficulty` 由 AI 在材料生成时赋值，而材料生成难度本身受 level 驱动，于是形成 `level → 生成难度 → 候选难度分布 → 反推 level` 的闭环，水平会被永久焊死、无法反映真实进步。
- 刺激 vs 响应：一条 AI 生成 item 可作**刺激**（如 SRS 卡片），但只有**用户对它的响应**（回忆对错、是否查词、转写是否正确）才是信号；AI 对它的**判断**（难度标签）永远不是。
- 同型纪律推广到 Style：目标语表达受能力限制，把「能力受限」误读成「风格选择」是同型闭环，故 Style 干净信号取源语言，目标语侧打低置信度。

### 5. 隐私重定义

- **隐私本体**：无第一方服务端、不收集不存储用户数据、用户自带 AI Provider 与存储、全本地运行。
- 据此，**在设备上、为用户、留在设备**地分析 Ability / Memory / Style **不构成「收集」意义的隐私问题，属产品必须**（修正前期把「本地分析」当「窥探」的措辞）。
- 但两条边界不随之消失：
  1. **外发边界**：出设备到 Provider（含用户自配的第三方 Provider）仍受核心决策 #10 + plan 09 请求预览 + 最小发送约束。本地算 Style 免费；把蒸馏后的风格 / 记忆送进 prompt 是外发，受管。外发分两类——a) 用户主动发起的 AI 交互（打字发消息、点击触发）本身即明示触发；b) 系统自动向 Provider 注入的数据（Memory / Style 摘要）必须明示授权或提供关闭选项，授权 UX 为「首次开启的一次性预览披露」而非每次弹窗（详见 `product-main-reference.md` §27.3、spec 008 §2）。
  2. **静态集中是「安全」而非「收集」问题**：系统级跨空间 = 最浓缩的全人 PII，设备失窃 / 备份泄露仍可一锅端 → 整库 `FileProtection` / 字段隔离决策保留，定位为「本地静态数据安全」。
- 统一「查看 / 删除 App 对我的了解」入口定位为**透明与掌控**特性，而非隐私违规补救。

### 6. 外发纪律与隐私前置闸门

- **纯本地启发式（零外发）不触发决策 #10，可先行**（= 动态评估 v1）。
- **自动（累计 / 定时）后台发分析请求是后台自动外发**，当前决策 #10 不允许 → 必须以本 ADR 的隐私重定义为权威依据，确立：自动画像分析 = 显式 opt-in、开启动作即决策 #10 的「显式触发」、其内最小发送 + plan 09 预览 + 默认关闭。
- 真正发请求时只发**增量 delta**（未分析的新内容），不重复灌全库；排除「私密」标签 / 照片原图；本地预筛优先。
- 排序：**① 隐私 / 定位修订（权威）→ ② 本 ADR（三层 + 分析账本 + provenance + 删除 / tombstone）→ ③ 拆 plan**。v1 本地账本 + 本地启发式不必等外发闸门；v2 opt-in AI 分析管线门控在隐私修订之后。

### 7. 删除语义三件套

1. **删语言空间** → 删该空间 per-space 对话情景；保留系统级 Style / Memory。Ability 不随空间级联删：Ability 按语言聚合，删一个英语空间则该语言 Ability 从剩余英语空间证据重算；删掉该语言最后一个空间则证据归零、该语言 Ability 按 provenance 整体撤回。全程走统一 provenance 重算，不为 Ability 单写 per-space 级联。
2. **系统级「重置 App 对我的了解」** → 唯一的系统级全清入口。
3. **源删除级联失效 + tombstone**：删源记录 / 对话 → 撤回其派生事实与行为信号；「忘掉这条」写抑制表，防下轮重抽。

### 8. 可重建性三级梯度与按层持久化

- **Ability 真派生**（行为日志廉价重算）→ **Memory 准原始**（AI 抽取、源可删）→ **Style 准原始 / 自陈**。
- 备份 / 导出 / 同步按层分叉：Ability **local-only、不备份、可丢弃重算**（对齐核心决策 #12）；Memory / Style 纳入导出 + 可恢复备份（删库 = 永久失忆，且是最痛 PII），删除即永久 + tombstone。
- 三层共享**敏感度与治理入口**，但**不共享持久化等级**。

### 9. 实现形态：分析账本 + provenance 一等公民

- 状态追踪落在 Learner Model 名下一张**分析账本（intake ledger）**，键 `(source_type, source_id, analyzer, analyzer_version)`，记 `status / pass_count / last_analyzed_at / last_version`，**以 (类型, id) 引用源行，不在源表（Entry / 查词 / 练习 / 对话消息）加列**。理由：三层 × 多分析器，单布尔表达不了；源表不该知道 Learner Model 处理状态；Ability 是真派生，污染源表会破坏可重建性；升版重跑需 `analyzer_version`。
- 分析粒度按层不同：Memory 走行级账本（per-item 抽取 + 版本）；Ability / Style 走**高水位游标（cursor）增量重算**（窗口聚合，非 per-item 旗标）。两形态可在同一账本并存。
- **provenance 一等公民**：派生事实 / 信号带 `source_refs`，支撑可解释、删除级联、tombstone。粒度警示：Memory 事实证据是单条 FK；Ability / Style 证据是一批分布（证据集 + 权重）——schema 不得强制所有派生结果都挂单 FK。

### 10. 细化核心决策 #6（自评与评估的关系）

- **自评 = 种子**：onboarding 自评仍保留，措辞建议轻量阶段化（初学 / 能日常交流 / 较流利）+ 内部映射 CEFR + 「仅起点，会自动校准」。
- **评估 = 演进的内部值**：评估覆盖「内部难度信号」，**永不覆盖「用户可见标签」**；用户标签保留可手动编辑，评估只「建议 / 并存」、绝不静默改写。
- **永不展示「降级」**：只展示覆盖 / 已纠正错误 / 趋势 / 成长（不打击信心红线）。

## 备选方案

### 方案 A：不抽模块，两子域各自为政

水平评估与关系记忆各自重造「读取用户数据 → 派生 → 存储 → 隐私边界 → 展示 → 删除」。

优点：

- 每个功能独立推进，短期耦合小。

缺点：

- 消费者要分别接多个 store，隐私边界可能不一致。
- 没有统一的「我们了解你什么、存在哪、怎么删」入口，对隐私即北极星的产品是结构性缺陷。
- 当派生知识 ≥ 2 种且治理姿态相同时，重复成本高于抽模块成本。

### 方案 B：按语言空间维护学习者模型（早期设想）

把能力画像 + 关系记忆按空间外键、随空间级联删除。

优点：

- 与 ADR-004 的空间聚合边界直觉一致，1:1 场景下简单。

缺点：

- 底层允许同语言多空间，按空间存会把同一门语言的水平 / 错误 / 风格 / 生活事实分裂成多份、互不相通。
- 生活事实、表达风格本质是跨空间的「全人」属性，绑空间产生割裂与重复授权。

### 方案 C：系统级三层 Learner Model（采纳）

Ability / Memory / Style 三层，分区键按层而定，全局共享，统一治理入口，分析账本 + provenance。

优点：

- 冷启动红利、单一治理入口、证据可解释、删除可级联。
- 隐私边界集中、可审计，契合本地优先与隐私北极星。
- 先立边界、增量填充：v1 可只填本地启发式，v2 接 opt-in AI 分析管线，不重写。

缺点：

- 系统级集中带来更浓缩的 PII，对静态安全（FileProtection / 字段隔离）要求更高。
- 跨空间删除语义比「随空间级联」复杂，需要 provenance 重算机制。

## 影响

> **实施进展（2026-06-18，LM01 落地，CI run `27749945215` 绿）**：本 ADR 系列第一份（LM01）已实现并合入 `dev`。落地形态：新建独立 Swift Package **`LangoTraceLearnerModel`**（deps Core + Data + GRDB，对应 §1「系统级横切子系统」物理边界），承载 `AbilityCoverage` / `AbilityCoverageEntry` / `AbilityCoverageKind`（v1 仅 `wordPhrase`/`sentence`）/ `LearnerEvidenceRef` / `LearnerSourceType` 域模型 + `LearnerContextProvider` 唯一 seam；`GRDBLearnerContextProvider` 以 **compute-on-read** 从 active 沉淀 `memory_items`（JOIN `language_spaces.target_language_code`）聚合 Ability 知识覆盖，按 §8「Ability 真派生不持久化」**不新增表/无 migration**，删除经 active-only 读天然级联（§7）。严守 §4 红线：**不读 `memory_candidates`、无 band/level/difficulty**。§9 的分析账本/cursor 形态按方案推迟到 LM02 引入 band 重估时一次建对（v1 compute-on-read 下账本即「建了不读」）。盲点 / 水平 band / 分技能 / Memory / Style / 总览页 UI 均为 LM02/LM03，未在 LM01 实现。详见 [LM01 方案](../plans/done/2026-06-15-01-feature-learner-model-boundary-and-ability-coverage.md)。

- **工程**：新增 Learner Model 模块边界（独立包 `LangoTraceLearnerModel`：域模型 + GRDB 实现 + `LearnerContextProvider` 供给 seam；LM01 已落地）；消费者（材料生成、解释模式、练习、复习、语伴）经统一 Provider 取用户上下文，不自建 store。
- **数据模型**：新增分析账本表与三层派生存储；按层分叉持久化（Ability local-only 不备份，Memory / Style 进导出 + 备份）；provenance `source_refs` 作为派生结果一等字段。
- **隐私 / 定位文档**：本 ADR 的隐私重定义需与 `product-main-reference.md`（§11 / §27）、`spec/008`、ADR-005 保持一致（已联动修订）；核心决策 #4 补充「Learner Model 横切空间」、#6 细化「自评 = 种子、评估 = 演进内部值」、#10 明确两类外发与一次性授权 UX。
- **计划系列**：在现有 01–15 系列后追加（不重编）——① Learner Model 边界 + Ability 覆盖视图（接 plan 10）→ ② 学习画像总览页 + 水平信号演进 + 分技能占位（接 plan 11）→ ③ 语伴（最后）。硬门控：先关闭 2026-06-11 Mac 验证门再实现。
- **既有备忘录对齐**：`architecture/notes/2026-05-25-language-companion-extension-notes.md` 的 per-space 记忆假设需对齐——生活事实升系统级 Memory、对话情景留 per-space。

## 风险

- 系统级集中 PII 一旦设备失窃 / 备份泄露可一锅端 → 依赖整库 `FileProtection` 与字段隔离落实。
- 评估效度：若证据红线执行不严，闭环自证会让水平焊死、无法反映进步。
- 母语记录占多数时目标语产出信号天然稀疏，早期产出维度测不准 → v1 只做理解 + 覆盖，产出维度标低置信度占位。
- 三层持久化等级不同，导出 / 备份 / 同步实现复杂度上升，需要清晰的按层策略与测试。
- 自动后台外发若在隐私闸门升格前就实现，会违反决策 #10。

## 复审条件

以下情况需要复审本决策：

- 出现「敏感语言空间隔离」的高频刚需，全局共享无 opt-out 不再可接受。
- 评估效度在真实数据上无法达到「比静态自评更准」，自适应承诺不可兑现。
- 同语言多空间在真实使用中极其罕见，按 language code keyed 的复杂度收益不成立。
- 静态安全方案（FileProtection / 字段隔离）无法满足系统级集中 PII 的安全要求。
- 产品商业模式或多用户 / 教学方向变化，使「单人、系统级、本地」前提不再成立。
