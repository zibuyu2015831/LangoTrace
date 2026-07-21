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

#### 10.1 band 重估的实施契约（LM02-S4b 门控前置修订，2026-06-25）

本小节把 §10 的「评估 = 演进的内部值」具体化为 band 重估的实施契约，作为 **LM02-S4b（band 服务 + derive() 迟滞）进入实现的清线门控**（S4b 须在本修订 artifact 存在后方可动 `derive()`）。本修订**细化**而**不反转** §10 的三条红线（评估只演进内部值 / 永不覆盖用户标签 / 永不降级）。

1. **band = 演进的内部难度信号，建在独立行为信号上**：band 由 **S4a 捕获的查词信号 + S3 产出错误 + 练习行为** 派生（ADR-006 §4 闭环红线 = band 须建在**不被 level 污染**的独立信号上，idea-02 §13.1）；**绝不**吃 `memory_candidates.difficulty` / AI 判定（否则 level→生成→难度→band 闭环自证）。

2. **derive() 吃演进 band**：`ExplanationLanguageMode.derive()` 的 `proficiencyLevelCode` 来源从静态 onboarding level **改吃演进 band**——这是 band 的**唯一**消费点（v1 blast radius 限 `ReadingDocumentStore` 的 2 处 derive 调用）。

3. **迟滞契约（防体验在脚下漂移）**：band 接 derive() **必须经可测迟滞状态机**——band 小波动**不立即**改档；仅**持续越阈 + 足够停留**（停留单位 = **document-open 次数**，非 wall-clock dwell）才切档；切档**只作用于新内容**，不回改已渲染的解释。迟滞计数器 **per-language、local-only、重启清零属可接受退化**（非持久）。具体阈值 / 停留次数由 S4b 钉死为可测值。

4. **band 仅喂 derive()、不引入新增外发字段（诚实外发论证）**：band v1 **仅**驱动 derive() 的解释档位；`proficiencyLevelCode`（AI Provider 请求字段）/ 材料生成 / 照片写作 / 回译点评**仍读静态 `LanguageLevel`**，band 不流入。**诚实承认**：AI 解释请求同时携带 `explanationLanguageMode = derive() 输出`，故 band 经 derive() **确实影响发往 Provider 的解释档位**——但正确论证是 band **不引入新增外发字段**：`explanationLanguageMode` 早已随请求外发、隐私量级不变（仍是**三档枚举**，非 band 数值 / 置信度 / 趋势）。**不**宣称「band 零跨外发」（代码 `:96` 证伪）。

5. **永不覆盖用户可见 `LanguageLevel` 标签 / 永不降级**（重申 §10 红线）：band 是内部信号、只「建议 / 并存」，**绝不**静默改写用户可见标签；总览页只展示覆盖 / 已纠正 / 趋势 / 成长，**绝不**展示「你从 B1 降 A2」。

> 本修订仅为 S4b 清线门控的契约 artifact；band 服务、derive() 迟滞接线、总览呈现的实际实现见 [LM02-S4b 方案](../plans/done/2026-06-25-feature-lm02-s4b-band-service-and-derive-hysteresis.md)，实施后回写实施进展。AI 校准 band（外发增量）仍属 v2 opt-in、须过 §6 隐私闸，不在 S4b。

> **实施进展（2026-06-25，LM02 Slice 4b 落地，CI 绿）**：本系列最高风险末片（全系列唯一触碰 `derive()`）已实现并合入 `dev`，三门控（S4a merge + S3 信号回归 + 本 §10.1 artifact 存在）满足后进入实现。落地形态：① **`BandHysteresis` 迟滞状态机**（Core）= 连续 3 次 document-open 越阈方切档 + 切档后 ≥5 次停留方再切（防体验在脚下漂移）；计数器 per-language、in-memory、重启清零可接受。② **`GRDBLearnerBandProvider`**（LearnerModel）compute-on-read 吃**独立行为信号**（userAuthored 查词 + S3 错误），**红线 SQL 仅 `dictionary_lookup_events` + `language_spaces`**（排除 aiGenerated、绝不读 AI 难度 / learning_text，源 grep + 行为断言双守），保守 v1 强 struggling 信号下沉一档（更多支撑），confidence 恒 `.low`；**不写 `language_spaces.level`**。③ **derive() 迟滞接线**（`ReadingDocumentStore`，唯一碰 derive()）：解释档位来源从静态 seed 改吃 band（经迟滞、document-open 评估、仅新内容不回改已渲染解释）；`switchExplanationMode` 用户覆盖**始终优先**（per-document）。④ **band 仅喂 derive() 不增新外发字段**：`:95 proficiencyLevelCode` 仍静态、band 不流入材料生成 / 照片写作 / 回译点评；**诚实承认** `:96 explanationLanguageMode` 随 band 变化——外发的仍是**三档枚举**（早已外发、隐私量级不变），非 band 数值。⑤ **总览页 bandTrend / confidence 呈现，永不展示降级**：`levelDisplay` 恒为 onboarding level（即使内部 band 估计更低）。装配为 `readingBandLevelSource`（环境注入）+ snapshot builder `bandProvider`。详见 [LM02-S4b 方案](../plans/done/2026-06-25-feature-lm02-s4b-band-service-and-derive-hysteresis.md)。

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

> **实施进展（2026-06-25，LM02 Slice 1 落地，CI run `28158971678` 绿）**：本系列第二份（LM02-S1）已实现并合入 `dev`，落地 **Memory 层地基 + 三端学习画像总览页**。落地形态：① **Memory 层**（§2 显式记住先行）= `MemoryFact` / `MemoryFactKind`（lifeFact/preference/goal/relationship）/ `MemoryFactVisibility`（默认 `global`，§3 冷启动红利）域模型 + **系统级 GRDB 表 `learner_memory_facts`（v27，仓库首张横切表，无 space FK，§3）**，策略列按 §8「Memory 准原始」取 `localOnly`/`includedInSystemBackup`/`includedInRecoverableBackup`；`GRDBLearnerMemoryRepository` 系统级读写，单条删=软删可撤销、系统级重置=物理 DELETE（§7 全清名实相符 + 消除最浓缩 PII 软删残留）；v1 **无自动抽取无账本**（§9）。② `AppDatabase` 新增 `writer` seam；`LearnerContextProvider` 扩 `memoryFacts(visibility:)`（总览页 + 未来语伴两个真实消费者）；`LearnerProfileSnapshot` compute-on-read 聚合（Learner-owned 覆盖+事实 vs 借用展示的 per-space 复习统计）。③ **三端学习画像总览页**（独立设置导航项 / iPad·macOS 侧栏 peer，**非** SettingsCapability）：温和总体水平**不展示降级**（§10）、Ability 覆盖、复习统计、Memory 事实增删、系统级重置确认流、盲点占位（依赖产出信号未就绪，§10 行动闭环后置）。严守纯本地零外发（§5/§6）：`LangoTraceLearnerModel` 不依赖 AI/网络。**E10 可恢复备份必须纳入 `learner_memory_facts` 的硬接缝**由 `architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md` 托管；字段级加密 / SQLCipher（§5.2）仍为未决项。band 重估 / 盲点管线 / Style / 分技能 / 自动抽取 / 语伴 Memory 注入均为后续 LM02/LM03 切片。详见 [LM02-S1 方案](../plans/done/2026-06-25-feature-lm02-memory-layer-and-learner-profile-overview.md)。

> **实施进展（2026-06-25，LM02 Slice 3 落地，CI 绿）**：盲点（常犯错误清单）v1 已实现并合入 `dev`，填充 S1 总览页盲点分区。落地形态：**compute-on-read、零迁移、零 writer、零外发、零 AI 判定**——`BlindSpot` / `BlindSpotKind`（{missing,changed,extra} 一对一映射机械 `PracticeDictationDiff.SegmentKind`，不另造语言学分类以免趋近 AI 判定，§4）+ `LearnerBlindSpotProvider` 读 seam + `GRDBLearnerBlindSpotProvider`（镜像 LM01：`reader.read{}` 读 `practice_text_attempts` JOIN `language_spaces`，仅 dictation + diff 非空 + active，按 `target_language_code` 聚合；对每条重跑 `compare()` 取词文本做频次聚合，证据集分布用 `[LearnerEvidenceRef]` 表达，§9）。**红线（§4）严守**：SQL 仅 FROM/JOIN `practice_text_attempts` + `language_spaces`，绝不读 `memory_candidates` / `learning_text` / AI 判定（源级 grep + 行为断言 sentinel 双守）；规模上限 `ORDER BY created_at DESC LIMIT 200`（无状态、无缓存、可 TDD）。总览页盲点分区诚实标注「重复练习错误模式（来自听写练习）」、**不下水平判决 / 不降级**（§10），空态引导做听写练习。**有意 scope-down**：「盲点→加入记忆库」deposit（需独立 migration，`memory_items` 仅接 candidate 来源）、自由产出语种检测、AI 校准盲点均留后续子增量。详见 [LM02-S3 方案](../plans/done/2026-06-25-feature-lm02-s3-blind-spots.md)。

> **实施进展（2026-06-25，LM02 Slice 2 落地，CI 绿）**：Style 层 v1 **表面写作印记** 已实现并合入 `dev`，**seam-only（不展示，用户 2026-06-25 定）**。落地形态：**compute-on-read、零迁移、零 writer、零外发、零 AI**——`StyleImprint`（`StyleMetricKind.surface` v1；`.cognitive` 保留位不产出，认知风格属 v2 AI 校准 opt-in）+ `StyleSignalConfidence`（high 源语言 / low 目标语，编码 §4 双向纪律）+ **按母语分组**（表面指标语言相关，不跨语言算术平均，§3）+ 证据集分布（§9）+ `LearnerStyleProvider` 读 seam + `GRDBLearnerStyleProvider`（镜像 LM01：`reader.read{}` 读 `entries` JOIN `language_spaces`，`deleted_at` 过滤天然级联；`LanguageDetector` 注入 seam 判语种=母语→高置信纳入、=目标语→排除、短文本/低置信→跳过）。**红线（§4）严守**：SQL 仅 FROM/JOIN `entries` + `language_spaces`，绝不读 `learning_materials`/`input_kind`/`memory_candidates`（AI 生成物）；语言判定靠 `NLLanguageRecognizer`，`entries.source` 非语言键。**装配为 seam-only 前置地基**（`AppEnvironment.learnerStyleProvider`，无消费者读，语伴 v2 / 改写下投影届时消费）。**§8 持久化分类分层细化（实质细化，非反转）**：§8 把整个 Style 层列「准原始 → 纳入备份」**未分 v1/v2**；本切片 reconcile——**v1 表面写作印记是纯机械、可从 `entries` 完全重算的真派生量，故 compute-on-read、不持久、不进备份**（`entries` 已纳主数据备份，重算即得）；§8「准原始 → 持久 + 备份」实质仅适用 **v2 自陈 / AI 认知风格**（不可从行为廉价重算）。事实源 architecture note `2026-06-25-style-surface-imprint-recompute-notes.md`。详见 [LM02-S2 方案](../plans/done/2026-06-25-feature-lm02-s2-style-surface-imprint.md)。

> **实施进展（2026-06-25，LM02 Slice 4a 落地，CI 绿）**：S4b band 重估的**信号捕获 + 分析账本地基**已实现并合入 `dev`，纯本地零外发零 AI 判定。落地形态：① **查词 / 索取解释行为事件捕获**（v28 `dictionary_lookup_events`）——阅读视图 AI 解释 seam（用户选中文本→索取解释）落库为**用户行为信号**（记「何时对哪段文本索取解释」，非 AI 返回内容，§4 合规）；**显式持久化策略 = local-only / 排除备份 / 排除导出**（不可重算用户行为新类别，非伪先例）；`source_content_origin` 列为**前向 schema 接缝**（v1 阅读文档恒用户导入 → 恒 `userAuthored`；`aiGenerated` 分支待未来「学习材料可作阅读源」基础设施，二阶闭环过滤届时由 S4b 启用）。② **§9 分析账本 + 高水位 cursor 首次建对**（v29 `analysis_ledger`）——键 `(source_type, source_id, analyzer, analyzer_version)` + cursor **增量窗口聚合**（非 per-item 旗标）；升 `analyzer_version` 触发全量重跑；cursor 单调推进、重入不双进。③ repository（`GRDBDictionaryLookupEventRepository` / `GRDBAnalysisLedgerRepository`）建在 S1 v27 `writer: DatabaseWriter` seam 之上。**有意 scope-out**：`derive()` / band 产出 / 总览呈现 / 信号加权 / aiGenerated 过滤均属 S4b。查词事件 FileProtection 接缝登记进 `2026-06-25-learner-memory-persistence-and-security-notes.md`。详见 [LM02-S4a 方案](../plans/done/2026-06-25-feature-lm02-s4a-lookup-capture-and-ledger.md)。

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
