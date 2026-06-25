# 任务方案：Style 表层印记（本地启发式，零外发）（LM02 Slice 2）

状态：Draft
自审核状态：Reviewed（2026-06-25 隔离子代理双轮审查，一轮 2 P0/3 P1 + 二轮 1 P0/4 P1 已修订写回，见第 13 节）
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

> **用户范围决策（2026-06-25）**：自审主结论曾建议「消费者就绪前推迟 S2」，**用户拍板：现在就做 S2，采 seam-only（不展示）**，与本地优先第一批同期。据此 §12.0 范围分叉收口为「do-now / seam-only」；展示仍默认不启用。**实现授权尚未给出**（用户本轮选择「先只拆 plan、暂不授权任何实现」），状态保持 Draft，待批量实现门控时再走授权 + 实现。

## 用户确认记录

本方案是 [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 学习者模型系列 LM02 的第二份切片（S2），上接 LM01（Ability 覆盖，已落地）与 LM02-S1（Memory 层地基 + 学习画像总览页，Draft/Reviewed）。2026-06-25 会话中，用户拍板「继续把 LM02-S2（Style）拉成正式 active plan」。本方案据 [LM02 切片拆解文档](2026-06-25-docs-lm02-remaining-slices-decomposition.md) 的 S2 边界落地：**Style 层 v1 = 表面写作风格本地启发式**（句长节奏 / 词汇丰富度 / 正式度倾向），`NaturalLanguage` 本地分析，系统级跨空间，**compute-on-read、零外发、零迁移、不碰 derive()**。认知风格（观察角度 / 思维方式）= AI 校准 = v2 opt-in，不在本切片；Style → Ability 下投影到目标语改写的消费 = 语伴 / 改写切片，不在本切片。

状态仍为 `Draft`：进入生产代码实现前仍需 (1) 按 [plan-review-protocol](../plan-review-protocol.md) 完成严格自审核并推进到 `Reviewed`，(2) 用户实现授权，(3) 解决第 12 节的范围分叉确认点。

## 1. 需求或 bug 描述

ADR-006 §2 把 Learner Model 分 Ability / Memory / Style 三层。Style 层 v1 = **表面写作风格**（idea-01 §13.4：句长 / 词汇丰富度 / 正式度 → 本地启发式 / `NaturalLanguage`，「免费、进 v1」）。当前 Ability（LM01）已落地、Memory 随 S1 落地，**Style 层完全不存在**。

Style 的产品价值（idea-01 §13.4 / §13.5）：让 AI 输出（材料 / 改写 / 翻译）既像你**写**的、也像你**想**的，反「通用 AI 腔」，契合「用你的生活学语言」。但该价值的**合法消费者是输出塑造**（语伴 v2 / 目标语改写下投影，idea-01 §13.5），二者均排在本切片之后。

**自审核后的核心结论（见 §12.0）**：S2 在 v1 **无已就绪的消费者**——decomposition 文档与 idea-01 §13.4 的默认是「Style 隐式塑造输出、**不在画像页展示判决**」，故不展示；而输出塑造的消费者（语伴 v2 / 改写）尚不存在。因此本方案的首要待用户决策不是「怎么做 S2」，而是 **「现在是否应单独立 S2」**：纯地基（seam-only）无消费者构成投机性基础设施（idea-01 §12.2 / CLAUDE.md 1.1，LM01 刻意避开的陷阱）。本方案据此把默认收敛为 **seam-only**，并把「**建议推迟 S2 至语伴 v2 / 改写切片就绪时与消费者同期落地**」列为自审结论（§12.0）；总览页展示为需用户显式产品决策（收口展示默认——idea-01 §13.4 + decomposition §35③；如升正式待决须于 §13.9 新增该条，P1-C）后才启用的**可选增量**，非默认实现路径。

## 2. 现状描述

以下对照当前代码（2026-06-25 HEAD）逐条核实：

- **`LangoTraceLearnerModel` 包**只含 LM01 Ability：`LearnerContextProvider` 唯一方法 `abilityCoverage(languageCode:) throws`；`GRDBLearnerContextProvider` **compute-on-read**（读 `memory_items` JOIN `language_spaces.target_language_code`，`reader.read{}`，**无 writer、无 migration**，源删除经 `soft_deleted_at IS NULL` 天然级联，严守 §4 红线不读 `memory_candidates`）。**无 Memory / Style 任何代码**（Memory 随 S1）。
- **`entries` 表**（`AppDatabase.swift:383`）：`body TEXT NOT NULL`（用户写入正文）、`source TEXT CHECK (source IN ('typedText', 'photoWriting', 'targetLanguageWriting'))`、`deleted_at REAL`（**注意列名是 `deleted_at`，非 LM01 `memory_items` 的 `soft_deleted_at`**）。**P0-1 核实纠正**：`EntrySource`（`LearningMaterialGenerationModels.swift:4-7`）三值语义是**输入方式**（文本框 / 照片写作 / 目标语写作入口），**不是语言**。真实写入器**只产出** `.typedText`（`PhoneMainView:125` / `PadMainView:100` / `MacMainView:365`）与 `.photoWriting`（`SeedLearningContent` / `PhotoWritingSaveCoordinator`）；**全仓库无任何写入器产出 `.targetLanguageWriting`**（仅存在于 schema CHECK + 本地化串，是休眠 schema 值）。用户完全可在 `typedText` 文本框里**直接用目标语**写记录 → 落成 `source=typedText`。故 `source != 'targetLanguageWriting'` ≈「全部 entries」，**几乎不过滤任何东西，不是语言区分键**。
- **真正的「母语 / 目标语」字段 `LearningMaterialInputKind`（nativeRecord/targetWriting/mixed/uncertain）是 AI 生成 JSON 输出**（`LearningMaterialPromptRegistry:76` prompt 指令 + `LearningMaterialGenerationService:220` schema enum，落 `learning_materials.input_kind`）→ **被 ADR-006 §4 红线禁用**（AI 生成物不得作信号证据），S2 **不读**。
- **结论（信号取源唯一权威）**：Style 干净信号的语言判定**只能靠 `NLLanguageRecognizer` 对 `entries.body` 的本地检测**（检测=母语→高置信；=目标语→排除 / 低置信；不确定 / 短文本→低置信或跳过）。`entries.source` 至多作弱辅助，不作主键。
- **`language_spaces` 表**（`AppDatabase.swift:134`）含 `native_language_code` + `target_language_code`，**且每空间各自独立**（多空间可有不同母语）→ 跨空间聚合表面指标须**按母语分组**，不可跨语言算术平均（见 §12.1 / 约束 1，P1-3）。
- **`NaturalLanguage`** 框架在仓库**已可用**，当前**仅** `AIProviderLanguageSupportValidator`（`LangoTraceAI`）import。LearnerModel 引入它只是 import 系统框架，**不**依赖 `LangoTraceAI`（保持依赖方向 Core + Data + GRDB）。NL 识别 / 分词单位随语言变化（参 `AIProviderLanguageSupportValidator:123` 对 CJK vs Latin 分别处理），且对超短 / 非自然文本置信度低——须置信度阈值 + 最小长度门（§12.1）。
- **`ExplanationLanguageMode.derive(from:)`** 仅 `ReadingDocumentStore` 消费；本方案**不碰** derive() / band / LanguageLevel（属 S4，ADR-006 §10）。
- **`AppDatabase`** 当前只有 `public var reader: DatabaseReader`（`AppDatabase.swift:11`），**无 writer**（S1 才补 writer）。本方案 compute-on-read **只需 reader**，不依赖 S1 的 writer seam（见 §12.1）。
- **总览页**（`LearnerProfileView` / `LearnerProfilePresentation`）由 S1 新建；本方案若启用展示，扩展其 presentation 而非另起页面（S1 的 presentation model 已预留分区，见 S1 §20）。
- **provenance 粒度**：LM01 `LearnerEvidenceRef`（单 FK + 预留 `weight`）已为 Ability / Style 的「证据集 + 权重」留位（ADR-006 §9 / idea-01 §14.3：Style 证据是**一批分布**，非单 FK）。

## 3. 目标

1. **Style 域模型**（`LangoTraceLearnerModel` 包）：`StyleImprint`（表面写作印记，含句长节奏 / 词汇丰富度 / 正式度倾向等机械指标 + 每维度 `confidence` + provenance 证据集）、`StyleMetricKind`（surfaceMetrics v1；cognitive 维度预留枚举位、v1 不产出）、`StyleSignalConfidence`（源语言=高、目标语=低，编码 §13.4/§13.5 双向纪律）。
2. **`LearnerStyleProvider` 读 seam**（新协议）：`func styleImprint() throws -> StyleImprint`（系统级跨空间；纯本地读）。与 `LearnerContextProvider`（Ability/Memory）**并列分方法暴露**，不做「难度 ∪ 事实 ∪ 风格」union（沿用 idea-01 §12.2 纪律）。
3. **`GRDBLearnerStyleProvider`**（compute-on-read，镜像 LM01）：`reader.read{}` 读 `entries` JOIN `language_spaces`（`WHERE entries.deleted_at IS NULL AND ls.deleted_at IS NULL`），对 `entries.body` 用 `NLLanguageRecognizer` 检测语种、**按母语分组**（不跨语言算术聚合，P1-3），用 `NaturalLanguage` 算表面指标。**只读用户 `entries.body`，绝不读 `learning_materials` / `learning_text` / `input_kind` / `memory_candidates`（§4 红线）。无 writer、无 migration、无外发。**
4. **源语言信号纪律**：语言判定**以 `NLLanguageRecognizer` 对 body 的本地检测为唯一权威**（`entries.source` 不是语言键，P0-1）。检测=母语→高置信；检测=目标语→排除干净信号 / 打 `.low`（§13.4 坏来源 + §13.5 受限目标双向纪律）；不确定 / 短文本→低置信或跳过。
5. **总览页展示 = 可选增量，默认不启用（P0-2）**：decomposition §35③ / idea-01 §13.4 默认「不展示判决、仅内部供给」（§13.9 本身未含「是否展示」条，P1-C）。仅当用户显式把展示默认收口为「展示」后，才在 S1 `LearnerProfileView` 加**克制中性「表达快照」分区**（仅机械描述，呈现为「你自己母语写作的反映」，绝不作人格 / 思维 / 认知侧写判决、绝不下水平判决 / 降级）。**本方案默认路径不含此项**。
6. 全程**纯本地、零外发、零 AI 校准、零迁移、不碰 derive() / LanguageLevel、不做认知风格、不做 Style→Ability 下投影消费**（下投影消费者是语伴 / 改写切片）。

## 4. 范围

- **`Packages/LangoTraceLearnerModel`**：新增 `StyleImprint.swift`（域模型）、`LearnerStyleProvider.swift`（协议）、`GRDBLearnerStyleProvider.swift`（compute-on-read 实现 + NL 本地分析）；扩展 `LearnerSourceType`（加 `.entryBody` 源类型，供 Style provenance 标注源语言产出）。
- **`Packages/LangoTraceUI`**（**默认不含**；仅当用户显式收口「启用展示」才纳入）：扩展 S1 的 `LearnerProfilePresentation`（加表达快照 presentation 映射 + 不下判决逻辑）+ `LearnerProfileView`（表达快照分区）。**不**新建页面。
- **`LangoTraceApp/AppEnvironment.swift`**：装配 `GRDBLearnerStyleProvider(reader:)`（注入既有 reader；无 writer 依赖）。
- **`project.yml`**：无新增 package（沿用 LangoTraceLearnerModel）。
- 文档：ADR-006 实施回写（Style 层 v1 表层落地）、architecture/001（包获得 Style 层）、architecture/002-system-map（Style 子系统 compute-on-read 数据流）、platform-page-inventory（若启用展示，总览页新增表达快照分区）、spec/007（Style v1 持久化分层登记，P1-B）、idea-01 §13.9 待决点收口（命名 / 持久化）+ §13.4/decomposition §35③ 展示默认、决策拆解文档标注「→ 已拆 active plan」。

## 5. 不做什么

- **不做认知风格（观察角度 / 思维方式 / 思维习惯）**：需对内容做 AI 语义分析 = 外发，属 AI 校准 v2 opt-in（idea-01 §13.4 / 决策拆解「跨切 AI 校准」）；本方案零外发，**不新增 `AIRequestCapability` case**。
- **不做 Style → Ability 下投影到目标语改写 / 生成**：idea-01 §13.5 的下投影**消费者**是语伴 / 改写切片；S2 只产出源语言印记 + 读 seam，下投影留 LM03 / 改写切片。本方案**不**改写任何目标语输出。
- **不做持久化 Style 表 / migration**：v1 表面印记是**可重算真派生**（从 entries 机械重算，类比 Ability），故 compute-on-read、**无新表、无 v27+ migration、无 writer 依赖**（§13.7「Style 准原始」的 backup 分类针对 v2 自陈 / 认知风格，见 §12.4 reconcile）。
- **不碰 `ExplanationLanguageMode.derive()` / `LanguageLevel` / band 重估 / 分技能**（属 S4，ADR-006 §10 / idea-02 §14.2）。
- **默认不在画像页展示 Style 判决**（P0-2，对齐 decomposition 行 35③/36 + idea-01 §13.4「隐式用、不下侧写判决」默认）：展示是需用户显式收口展示默认（§13.4 / decomposition §35③）的可选增量；即便启用，也仅限机械描述统计、呈现为用户自己产出的反映，不贴标签、不下判决。
- **不做目标语产出作为干净 Style 信号**：目标语侧打低置信度 / 排除（§13.4 同型闭环纪律）。
- **不做自动后台外发 / 分析账本 / cursor**：零外发无需隐私闸（ADR-006 §6）、无聚合状态追踪需求（compute-on-read 每次重算）。
- **不依赖 S1 的 writer seam**：S2 compute-on-read 只用 reader；但 **S1 须先落地**（总览页是展示归宿、且 Style 与 Memory/Ability 同属一页治理，见 §7 约束 6）。

## 6. 证据与决策依据

- ADR 证据：[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) §2（Style 层：表面写作风格 = 本地 v1，认知风格 = AI 校准后置）、§3（Style 系统级跨空间、全局共享冷启动红利）、§4（证据红线：源语言干净信号、目标语打折，同型闭环纪律）、§5/§6（隐私重定义：本地分析非「收集」、零外发不触发决策 #10 可先行）、§8（可重建性梯度：Style 准原始——但见 §12.4 v1 表层 reconcile）、§9（provenance 一等公民：Ability/Style 证据是分布非单 FK）、§10（不展示降级、不打击信心）。
- idea 证据：`docs/idea/01-learner-model.md` §13.1（三层定义 + Style 系统级）、§13.4（Style 定义 / 两档推断 / 隐式用不下判决 / 源语言干净信号）、§13.5（Style↔Ability 下投影——**消费者**侧，S2 不做）、§13.7（可重建性梯度）、§13.9（待决点：命名 / 下投影档位映射；**不含「是否展示」**——见 decomposition §35③）、§14.3（provenance 粒度：Style 证据集 + 权重）；`docs/plans/active/2026-06-25-docs-lm02-remaining-slices-decomposition.md`（S2 边界 / 硬前置 / 待决 / 风险 / 排序）。
- 代码证据：见第 2 节逐条核实（entries.source 区分键、native/target language_code、NL 已可用、LM01 compute-on-read 镜像、reader-only）。
- workflow 引用：本方案**不命中** add-storage-migration（无新表 / 无 migration / 无 writer）、不命中 AI Provider / TTS / Prompt（零外发、无 prompt）；若启用展示，**轻度命中** [`add-platform-screen`](../../workflows/add-platform-screen.md)（扩展 S1 既有总览页一个分区，非新页面 / 新入口）。

```text
证据能证明什么：ADR-006 §2 把 Style 表面写作风格定为本地 v1；idea-01 §13.4 明列句长 / 词汇丰富度 / 正式度 → NaturalLanguage 本地启发式「免费、进 v1」；entries.source 现成区分源语言 vs 目标语产出；LM01 已证明 compute-on-read 读源表派生 Learner 信号的合规模式。故本方案技术路径合法。
证据不能证明什么：§13.4「隐式用、不下侧写判决」未明确「v1 是否在总览页展示表面指标」——decomposition §35③（引 §13.4）把「是否展示 Style」列为待决（idea-01 §13.9 本身未含此条，P1-C）；故 §12 范围分叉（展示 vs 仅 seam）是自审核 / 用户确认点，不可默认。ADR-006 §8 把 Style 列「准原始、纳入备份」，但那预期含自陈 / AI 认知风格；v1 纯机械可重算表层是否真需持久化 / 备份，须正面 reconcile（§12.4）。
迁移前提：无新表、无既有数据迁移；entries 读路径只读不改，Ability/Memory 读路径不受影响。
照搬风险：把「表面写作指标」当「认知 / 人格侧写」展示会越 §13.4 红线——已在 §5 / §7 约束 5 明确边界；把目标语产出当干净 Style 信号会触同型闭环——已在 §3 目标 4 / §7 约束 4 排除。
```

```text
是否需要 spike / probe / fixture / evidence：否——纯本地 NaturalLanguage + GRDB 只读聚合，无外发、无新并发原语、无流式、无新表。fixture 为合成 entries（母语 / 目标语各若干），无真实用户敏感内容。
需要时的落点：不适用。
是否包含真实用户敏感内容：否——测试用合成 entries 文本。
如何验证和清理：合成 fixture，无需清理。
```

## 7. 约束映射与验证路径

### 约束 1：Style 系统级跨空间、compute-on-read、零持久化（v1 表层）；按母语分组

- 来源：ADR-006 §3、idea-01 §13.1，LM01 compute-on-read 先例
- 适用范围：`GRDBLearnerStyleProvider` 读路径
- 严重度：blocker
- 执行或验证方式：单元测试 + 代码审查
- 验证提示：`styleImprint()` 跨**所有空间**聚合源语言产出（系统级，不按 space 分区）；`reader.read{}` 只读、写零行、无新表、`git diff` 无 migration；切换 / 删除空间不改变印记计算逻辑（从剩余 entries 重算，源删除经 `entries.deleted_at IS NULL` 天然级联，**注意列名 `deleted_at`**）。**P1-3 粒度**：表面指标语言相关（句长 / TTR / 正式度跨语言不可比），故须**按母语分组持有**（`StyleImprint` 是「各母语分组的集合」，非跨语言算术平均）；v1 可限「主母语」单组、其余低置信占位。

### 约束 2：零外发，不触发决策 #10

- 来源：ADR-006 §5/§6、核心决策 #10、ADR-005
- 适用范围：整个 Style 层 v1
- 严重度：blocker
- 执行或验证方式：依赖方向检查 + 代码审查
- 验证提示：`LangoTraceLearnerModel` 不 import 网络 / `LangoTraceAI`；`rg -i "urlsession|urlrequest|provider|http|LangoTraceAI" Packages/LangoTraceLearnerModel/Sources` 无网络 / AI 命中（NaturalLanguage 是本地系统框架，允许）；Style 仅由本地读 entries 计算，无任何外发路径。

### 约束 3：证据红线——源语言干净信号、目标语打折

- 来源：ADR-006 §4、idea-01 §13.4/§13.5
- 适用范围：信号取源与置信度
- 严重度：blocker
- 执行或验证方式：单元测试
- 验证提示：语言判定**以 `NLLanguageRecognizer` 对 `entries.body` 检测为唯一权威**（`entries.source` 不是语言键，P0-1）；检测=母语 → 高置信印记；检测=目标语 → 排除干净信号或标 `StyleSignalConfidence.low`；**绝不**读 `memory_candidates` / `learning_materials.learning_text` / `learning_materials.input_kind`（AI 生成物，§4 禁用）——只读用户 `entries.body`。红线 grep 须含 `learning_materials` / `input_kind` / `memory_candidates`。

### 约束 4：不下侧写判决（隐式用红线）

- 来源：idea-01 §13.4、ADR-006 §10、idea-02「不贴标签 / 不下判决」
- 适用范围：总览页表达快照展示（若启用）
- 严重度：blocker
- 执行或验证方式：presentation model 测试 + 人工审查
- 验证提示：表达快照仅呈现机械描述（句长 / 词汇范围 / 正式度倾向），文案框定为「你自己母语写作的反映」；**绝无**「你是 X 型思维 / 你的人格是 Y」式侧写、**绝无**水平判决 / 降级；presentation 测试断言无 personality/cognitive 文案键、无 level/downgrade 键。

### 约束 5：模块依赖方向清晰

- 来源：ADR-006 影响节、`docs/architecture/001-initial-module-boundaries.md`
- 适用范围：Style 层在包间位置
- 严重度：warn
- 执行或验证方式：编译依赖检查
- 验证提示：Style 域模型 / provider 在 `LangoTraceLearnerModel`（deps 仅 Core + Data + GRDB + 系统 NaturalLanguage）；Data / Core 不反向依赖本包；UI 经 provider 协议取用；不新增 schema（无需 Data `AppDatabase` 改动）。

### 约束 6：S1 先落地（展示归宿 + 同页治理）

- 来源：决策拆解文档「共同前置」、ADR-006 §1（统一治理入口）
- 适用范围：S2 排序前置
- 严重度：blocker（若启用展示）
- 执行或验证方式：排序门控
- 验证提示：S2 若启用总览页展示，须 S1 的 `LearnerProfileView` / `LearnerProfilePresentation` 已落地；S2 扩展其分区而非另起页面，保持 Learner Model 单一治理窗口（ADR-006 §1）。S2 的 provider seam 本身（不展示部分）不依赖 S1 代码，但产品上 Style 无独立入口。

### 约束 7：provenance 证据集而非单 FK

- 来源：ADR-006 §9、idea-01 §14.3
- 适用范围：StyleImprint 证据建模
- 严重度：warn
- 执行或验证方式：值类型测试
- 验证提示：StyleImprint 的证据是**一批 entries 的分布**（证据集 + 可选权重），复用 `LearnerEvidenceRef`（预留 `weight`）数组，**不**强制单 FK；与 Memory 单 FK 区分（§14.3 粒度警示）。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/StyleImprint.swift`（新增：`StyleImprint` / `StyleMetricKind` / `StyleSignalConfidence`）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/LearnerStyleProvider.swift`（新增：协议）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/GRDBLearnerStyleProvider.swift`（新增：compute-on-read + NL 本地分析）
- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/LearnerContextProvider.swift`（扩展 `LearnerSourceType` 加 `.entryBody`）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfilePresentation.swift`（仅启用展示：加表达快照映射 + 不下判决逻辑）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfileView.swift`（仅启用展示：表达快照分区）
- `LangoTraceApp/AppEnvironment.swift`（装配 `GRDBLearnerStyleProvider(reader:)`）
- 对应 `Tests` 目录新增测试（见第 15 节）

## 9. 参考的代码文件路径

- `Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/GRDBLearnerContextProvider.swift`（**compute-on-read 镜像模板**：reader-only、JOIN language_spaces、源删除天然级联、红线只读用户产出）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderLanguageSupportValidator.swift`（`NaturalLanguage` 语种检测用法参照）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（`entries` schema:383 / `language_spaces`:134，确认 source / native/target language 列）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearnerProfileView.swift` / `LearnerProfilePresentation.swift`（S1 总览页，启用展示时扩展）

## 10. 涉及的文档路径

- 本方案。
- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md)（实施后回写 Style 层 v1 表层已落地）。
- `docs/architecture/001-initial-module-boundaries.md`（LangoTraceLearnerModel 获得 Style 层）。
- `docs/architecture/002-system-map.md`（Style 子系统 compute-on-read 数据流）。
- `docs/platform-page-inventory.md`（若启用展示，总览页新增表达快照分区）。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（P1-B：登记 Style v1 表层 compute-on-read 不持久不备份 / 准原始适用 v2，与 S1 拟登记 Ability 条目并列）。
- `docs/idea/01-learner-model.md` §13.9（收口命名 / 持久化待决点）+ §13.4 / decomposition §35③（展示默认），作方案内决策回指。
- **新增 `docs/architecture/notes/`**（实施时建）：Style v1 表层 compute-on-read 不持久 + 准原始 / 备份仅 v2 的跨任务硬接缝（P1-2）。
- `docs/plans/active/2026-06-25-docs-lm02-remaining-slices-decomposition.md`（S2 标注「→ 已拆 active plan」）。
- `docs/plans/active/2026-06-11-00-docs-series-progress.md`（状态总表登记 S2）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

> 单包为主（LearnerModel），可选 UI 扩展。分两 Phase + 一个范围分叉决策。

### 12.0 范围分叉（自审核首要确认点：是否现在做 S2 / 是否展示）

idea-01 §13.4 一方面把表面写作风格列为「本地 v1」，一方面说 Style「隐式用、不下侧写判决」；decomposition 文档 LM02-S2 条目**明确默认「不在画像页展示 Style 判决、仅内部供给」**（行 35③ / 36，引 §13.4），把「是否在总览页展示 Style」列为**待决**（idea-01 §13.9 本身未含此条，P1-C）。第一轮自审核（P0-2 / P1-1）核实出 S2 的根本张力：

- **展示路径越红线 / 与上游默认相反**：把「你的句子偏长 / 词汇偏丰富 / 偏正式」作为关于用户的画像呈现，即使措辞克制仍是对用户下「表达侧写」，正面冲撞 §13.4，且与 decomposition 默认「不展示」相反。与 S1 的类比**不成立**：S1 预留的是**盲点分区**（用户**自己的错误**，idea-02 §7.1 行动价值项），Style 表面统计无对应行动闭环，更接近侧写。故**不采纳「默认启用展示」**。
- **仅 seam 则无消费者 = 投机地基**：Style 合法消费者是输出塑造（语伴 v2 / 改写下投影），均排在 S2 之后；seam-only 是「建了没人读」，违反 idea-01 §12.2（LM01 刻意避开的 union 投机化）与 CLAUDE.md §9 克制。

**自审结论（默认取舍）**：

1. **默认收敛为 seam-only**（不展示），与 decomposition / §13.4 上游默认对齐。
2. **首要待用户决策 =「现在是否单独立 S2」**，先于命名 / 持久化。鉴于 seam-only 当前无消费者，**自审推荐：推迟 S2，至语伴 v2 或目标语改写切片就绪时与消费者同期落地**（届时接口有真实依据，避免投机地基）。
3. **总览页展示 = 可选增量**，仅当用户显式把展示默认（§13.4 / decomposition §35③）收口为「展示」后才纳入 §12.3（如升正式待决须于 idea-01 §13.9 新增该条，P1-C）；属产品决策，须回写 idea-01 / 视情况 ADR-006，不在 active plan 内默认掉。

**用户决策收口（2026-06-25，覆盖上述自审推荐 #2）**：用户拍板 **现在就做 S2、采 seam-only**，纳入本地优先第一批（与 S3 同期），**不采纳「推迟」推荐**。理由（用户侧）：Style provider seam 作为前置地基先行，语伴 v2 / 改写就绪即可直接消费，省去届时再起的接缝成本。据此本方案范围 = do-now / seam-only；展示仍默认不启用（如需展示须另行收口 §13.4 默认）。⚠️ 投机地基风险（自审 P1-1）已知并被用户接受：seam 在消费者就绪前无读者，须确保 `LearnerStyleProvider` 契约足够稳定、不因无消费者而过度泛化（沿用 idea-01 §12.2 纪律：分方法暴露、不做 union）。**实现仍待授权**（本轮仅拆 plan）。

**「推迟」情形的状态处置（P1-D，落地性）**：若用户采纳推迟，本 active plan 不应滞留 `active/`（decomposition §17 原则：不预先为未就绪能力留 active plan）。处置 = **移出 active/ 归档**（移入 `docs/plans/done/` 并在文件头标注「设计就绪 + 双轮自审通过，待消费者就绪拉起」），同时在 decomposition 文档 S2 条目标注「设计已就绪 + 双轮自审通过 → 暂缓，链接归档路径」作恢复入口，**保住已完成的双轮自审成果**、不丢失、不堆积 active/。若用户选「现在做 seam-only」，则保持 `active/` 走正常 Draft→实现→done。

用户可推翻本结论（如要求现在即落 seam 作前置地基、或要求启用展示）；当前以「seam-only + 建议推迟」记入 §13 / §20。

### 12.1 Phase 1：Style 域模型 + compute-on-read provider（镜像 LM01，reader-only，零迁移）

1. LearnerModel 域模型：`StyleImprint`（generatedAt + **按母语分组**的维度集合：每组含 `nativeLanguageCode` + `sentenceLengthProfile` / `vocabularyRange` / `formalityTendency` 等机械指标，每项带 `confidence` + 证据集 `[LearnerEvidenceRef]`，**证据集采样上限**：每维度保留 top-N 代表证据 + 总计数，避免值类型膨胀，idea-01 §14.3 只要求「证据集 + 权重」不强制全量）；`StyleMetricKind`（v1 仅 `.surface`；预留 `.cognitive` 枚举位但 v1 不产出，注释标明）；`StyleSignalConfidence`（`.high` 源语言 / `.low` 目标语，编码 §13.4/§13.5）；`LearnerSourceType` 加 `.entryBody`（与未来 S3 `.practiceTextAttempt` 协调命名）。先写值类型测试红绿。
2. `LearnerStyleProvider` 协议：`func styleImprint() throws -> StyleImprint`（系统级、无参；纯本地读）。**不**并入 `LearnerContextProvider`（保持分方法、不做 union，idea-01 §12.2）。
3. `GRDBLearnerStyleProvider(reader:detector:clock:)`（镜像 `GRDBLearnerContextProvider` 的注入式构造）：`reader.read{}` 读 `entries` JOIN `language_spaces`，`WHERE entries.deleted_at IS NULL AND ls.deleted_at IS NULL`（**entries 用 `deleted_at`，非 LM01 的 `soft_deleted_at`**；`source` **不**入过滤——非语言键 P0-1）。
   - **语言检测注入 seam（P0-A，落地性关键）**：定义 `LanguageDetector` 协议（`func detect(_ text: String) -> (language: String, confidence: Double)?`），默认实现包 `NLLanguageRecognizer`，**测试注入确定性 stub**。理由：`NLLanguageRecognizer` 对短 / 非自然文本判定不稳、且 NaturalLanguage 仅 Apple 平台——若不注入，§15 的「目标语排除 / 按母语分组」用例的「绿」不可控（flaky / Linux 编译失败）。类比 LM01 注入 `clock` 使 compute-on-read 可测。
   - 对 `entries.body` 经 `detector` 检测语种作为**唯一语言权威**：检测=该空间 `native_language_code` → 高置信纳入对应母语分组；=目标语 → 排除 / `.low`；不确定或 **body 短于最小长度门 / 置信度低于阈值** → 跳过或低置信（防短文本误判）。对纳入的 body 用 `NaturalLanguage`（`NLTokenizer` 分句 / 词，CJK vs Latin 分别处理参 `AIProviderLanguageSupportValidator:123`）算句长节奏 / 词汇丰富度（type-token ratio）/ 正式度启发式，**按母语分组聚合**。**只读用户 `entries.body`，绝不读 `learning_materials` / `learning_text` / `input_kind` / `memory_candidates`（§4 红线）。** 先失败测试 → 实现。

### 12.2 命名收口（自审核 #2 确认点：Style / Voice / 表达印记）

idea-01 §13.9 列「Style 命名」待决（「Style」略低估认知半边）。**本方案取舍**：内部类型名用中性 `StyleImprint`（表达印记），面向用户文案（若展示）用「表达快照 / 你的写作」，**不**用「Style / 风格人格」字样以免暗示侧写。认知半边（v2）落地时再议是否升「表达与认知印记」总称。用户可推翻。

### 12.3 Phase 2（**默认不执行**；仅当用户显式收口「启用展示」）：总览页表达快照分区

1. 扩展 S1 `LearnerProfilePresentation`：加 `StyleSnapshotPresentation`（机械指标 → 中性文案映射；**不下判决**逻辑：无 personality/cognitive/level/downgrade 文案键）。
2. 扩展 S1 `LearnerProfileView`：在画像页加「表达快照」分区（句长节奏 / 词汇范围 / 正式度倾向，配「这是你自己母语写作的反映，仅供参考」说明）；空态（产出不足时「继续记录以解锁表达快照」）。
3. App 装配 `GRDBLearnerStyleProvider(reader:)`；presentation 测试 + 三端状态覆盖。

### 12.4 持久化分类 reconcile（自审核 #3 确认点：§13.7「Style 准原始」张力）

ADR-006 §8 / idea-01 §13.7 把 **整个 Style 层**列「准原始 → 纳入导出 + 可恢复备份、删除即永久 + tombstone」，**未区分 v1 表层 vs v2 认知**。**本方案 reconcile（P1-2）**：v1 表面写作印记是纯机械、可从 `entries` 完全重算的真派生量（与 Ability 同类），故 v1 **compute-on-read、不持久、不进备份**（entries 本身已纳入主数据备份，重算即得）。§13.7「准原始 / 纳入备份」的字面对整层成立，但**实质应分层细化**：仅 v2 自陈 / AI 认知风格（不可从行为廉价重算）才是「准原始 → 持久 + 备份」；v1 表层是真派生。

**这是对一条 Accepted ADR 明文分类的实质性细化，不能仅在 plan 内自决**：须 (1) 回写 ADR-006 §8 / 实施进展（「Style v1 表层 = 真派生不持久；准原始 / 备份适用 v2 自陈 + 认知」）；(2) 新增一条 architecture note 防后续会话误把 v1 表层当准原始去建表 / 建备份（与 S1 已建 persistence note 同型）；(3) 在 §13 标为需用户确认的 ADR 细化点。compute-on-read 取向本身不阻塞，但文档分流必须补。用户可推翻（要求 v1 即持久化 → 改建表 + writer 路径）。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-25
审核方式：隔离审查（general-purpose 子代理第一轮架构审查 + 主会话用当前 HEAD 代码逐条核验写回）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地）
未使用隔离审查的原因：不适用，已使用隔离子代理。
发现摘要（子代理原始分级，主会话已用代码逐条核验）：
  P0 阻塞（2 项，均核验成立）：
  - [P0-1] 「源语言干净信号」区分键不成立：方案把 source != 'targetLanguageWriting' 当母语 / 目标语区分键。核实 EntrySource（LearningMaterialGenerationModels.swift:4-7）三值是输入方式非语言；真实写入器只产 .typedText（PhoneMainView:125/PadMainView:100/MacMainView:365）+ .photoWriting，.targetLanguageWriting 无任何写入器（休眠 schema 值）；用户可在 typedText 框直接用目标语写 → source 几乎不过滤。真正的 native/target 字段 LearningMaterialInputKind 是 AI 生成 JSON 输出（PromptRegistry:76 / GenerationService:220）→ §4 红线禁用。修订——§2/§3 目标3-4/§7 约束3/§12.1/§15 改：语言判定以 NLLanguageRecognizer 对 body 检测为唯一权威、source 非语言键、红线 grep 加 input_kind/learning_materials、目标语排除测试改 NL fixture。
  - [P0-2] 默认「启用展示」越 §13.4 红线且与上游默认相反：decomposition 行 35③/36 明定 S2 默认「不展示判决、仅内部供给」；与 S1 类比错位（S1 预留盲点分区=用户自己的错误行动项，Style 表面统计无行动闭环、更近侧写）。修订——§12.0 默认翻转为 seam-only；§3 目标5/§5/§12.3 降展示为可选增量、需用户收口展示默认（§13.4 / decomposition §35③）。
  P1（核验成立）：
  - [P1-1] 剥离展示后 seam-only 无消费者 = 投机地基（idea-01 §12.2 / CLAUDE.md 1.1，LM01 刻意避开）：合法消费者（语伴 v2 / 改写下投影）均排在 S2 后。修订——§12.0 提升「建议推迟 S2 至消费者就绪」为自审主结论；首要确认点 =「是否现在做 S2」。
  - [P1-2] §12.4 持久化 reconcile 不能仅 plan 内自决：ADR-006 §8 / idea-01 §13.7 字面把整个 Style 层列「准原始 + 备份」，未分 v1/v2。compute-on-read 取向工程上成立，但须回写 ADR + architecture note 防文档实现脱节。修订——§12.4/§17/§20 增 ADR 分层细化回写 + 新 architecture note。
  - [P1-3] 系统级跨母语聚合表面指标语义不成立：language_spaces.native_language_code 每空间独立（:144），句长 / TTR / 正式度语言相关、跨语言算术平均无意义。修订——§3 目标3/约束1/§12.1 改「按母语分组、不跨语言算术聚合」；§20 列可比性风险。
  P2/P3：
  - [P2-1] entries 用 deleted_at 非 LM01 的 soft_deleted_at——§2/§12.1 已澄清列名，防照抄 LM01 SQL。
  - [P2-2] NL 对短 / 非自然 / 非白名单语言不可靠——§12.1 增最小长度门 + 置信阈值；§15 加 neverCrashesOnShortOrNonNaturalText。
  - [P2-4] provenance 证据集系统级可成百上千——§12.1 增 top-N 采样上限。
  - [P3-1] 命名（§12.2）—— seam-only 路径下用户面文案不产生，注明仅展示时才需定。
  - [P3-2] LearnerSourceType.entryBody 与未来 S3 .practiceTextAttempt 协调命名——§12.1 已注。
  第二轮（测试 / 安全 / 落地，基于一轮修订后）发现（均核验成立）：
  - [P0-A 阻塞] NL 不可注入致 TDD 红绿不可控：provider 直接 new NLLanguageRecognizer 无 seam，NL 对短文本判定不稳 + 仅 Apple 平台 → 目标语排除 / 分组用例 flaky/Linux 编译失败；仓库无「喂 fixture 断言 NL」先例（AIProviderLanguageSupportValidator 的 NL 路径本身零测试覆盖）。修订——§12.1 引入 LanguageDetector 注入 seam（类比 LM01 注入 clock）；§15 核心用例改注入 stub 断言、真实 NL 仅冒烟（macOS）；§20 列风险。
  - [P1-A] neverReadsAIGeneratedText 应行为断言非 SQL 字符串断言：LM01 undepositedCandidateExcluded(:150-190) 已有行为断言先例。修订——§15 改 seed AI-only token + 断言不进 StyleImprint。
  - [P1-B] §17 漏 spec/007：S1 已登记 spec/007，S2 同类持久化分层却漏。修订——§10/§17 增 spec/007 登记。
  - [P1-C] §13.9 引用错误：「是否展示」实在 decomposition §35③（引 §13.4），idea-01 §13.9 待决项无此条（仅命名 / 认知校准 / 下投影 / 文案 / opt-out）。修订——全文 §13.9 展示引用更正为 §13.4 / decomposition §35③；如升正式待决于 §13.9 新增。
  - [P1-D] 「推迟 S2」状态处置盲点：decomposition §17 禁未就绪能力滞留 active/。修订——§12.0/§20 增推迟即移出 active/ 归档 done/ + decomposition 标注恢复入口。
  - [P2-A] §14 红线 grep 缺 input_kind/learning_text + 缺 import 依赖断言。修订——§14 补全。
  - [P2-B] §15 fixture 构造未点名 LM01 路径（DatabaseQueue+AppDatabase+raw SQL，模板 :157）。修订——§15 点名。
  - [P3-A] NL 仅 Apple 平台 CI 表述——§15/§16 注明真实 NL 用例只能 macOS runner。
  - [P3-B 通过] LearnerSourceType 加 .entryBody 无破坏——核验通过无需改。
  第二轮已核验通过无需改：compute-on-read 无 writer/migration/新表 → 无新安全面；entries.deleted_at 列名正确；source 非语言键成立；S1 persistence note 模板可用。
写回修改：P0-1→§2/§3/§7/§12.1/§14/§15；P0-2→§1/§3/§5/§12.0/§12.3；P1-1→§1/§12.0/§20；P1-2→§12.4/§17/§20；P1-3→§3/§7 约束1/§12.1/§20；P2-1→§2/§12.1；P2-2→§12.1/§15；P2-4→§12.1；P3-1→§12.2；P3-2→§12.1；P0-A→§12.1/§15/§20；P1-A→§14/§15；P1-B→§10/§17；P1-C→§1/§3/§5/§6/§10/§12.0/§12.3/§17/§20；P1-D→§12.0/§20；P2-A→§14；P2-B→§15；P3-A→§15/§16。
新增 architecture note（待实施时建）：Style v1 表层 compute-on-read 不持久 + 准原始仅 v2（§17）。
仍需用户确认的问题（按优先级）：
  1. 【首要】是否现在单独立 S2 实现，还是采纳自审推荐「推迟至语伴 v2 / 改写切片就绪时与消费者同期落地」。
  2. 若现在做：seam-only（默认，推荐）还是要求启用总览页展示（需先收口展示默认——§13.4 / decomposition §35③，越红线风险见 P0-2）。
  3. §12.4 ADR-006 §8 持久化分层细化（v1 真派生不持久）是否认可，或要求 v1 即持久化 / 备份。
  4. 实现授权（Reviewed ≠ 批准实现；状态保持 Draft）。
是否允许进入实现：方案门禁已过（一轮 2 P0 + 3 P1、二轮 1 P0(P0-A) + 4 P1 均已修订写回、确认点已列、自审核状态 Reviewed）；但状态仍为 Draft，且自审主结论是「在消费者就绪前不建议进入实现」——须待用户就上述 #1 决策后方可推进。
```

## 14. 复查方法

- 代码：LearnerModel 值类型 / provider 测试全绿；红线 grep `rg "memory_candidates|learning_materials|learning_text|input_kind|urlsession|urlrequest|LangoTraceAI" Packages/LangoTraceLearnerModel/Sources` 无命中（§4 红线 + 零外发）；依赖断言 `LangoTraceLearnerModel` 不 import `LangoTraceAI` / 网络模块（约束 2）；`git diff` 无 migration、无新表。
- 数据：Style 系统级（跨空间聚合）；源语言高置信 / 目标语低置信或排除；源删除经 active 过滤天然级联；空 entries 返回空印记不崩溃。
- 展示（若启用）：表达快照仅机械描述、无侧写 / 无降级；空态引导；三端可达。
- 故障路径：NL 对超短 / 非自然语言文本不崩溃（降级为低置信 / 跳过）；并发只读安全。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/Style/StyleImprintModelTests.swift（值类型 / confidence / 证据集采样上限 / 按母语分组）
  Packages/LangoTraceLearnerModel/Tests/LangoTraceLearnerModelTests/Style/GRDBLearnerStyleProviderTests.swift（compute-on-read / 跨空间系统级按母语分组 / NL 检测母语高置信 / NL 检测目标语排除或低置信 / 只读用户 body 不读 AI 生成 / 源删除天然级联 / 空 entries 空印记 / 短文本不崩溃）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/LearnerProfile/StyleSnapshotPresentationTests.swift（**默认不含**；仅启用展示：机械描述、无侧写判决键、无降级键、空态）
fixture 构造（复用 LM01 路径，P2-B）：`DatabaseQueue()` → `AppDatabase(databaseQueue:)`（应用全 migration）→ `database.reader`；raw SQL seed `entries` / `language_spaces`，entries INSERT 模板见 `GRDBLearnerContextProviderTests.swift:157`。语言检测用注入 stub（P0-A），不依赖真实 NL。
先失败用例（红绿次序：LearnerModel 值类型 → provider → （若展示）UI）：
  StyleImprintModelTests.surfaceMetricKindIsV1Only —— 预期失败：类型尚不存在，编译失败。
  GRDBLearnerStyleProviderTests.aggregatesByNativeLanguageSystemLevel —— 注入 stub 把不同 body 判为不同母语，断言**按母语分组**（确定性，不靠真实 NL）；预期失败：provider 尚不存在。
  GRDBLearnerStyleProviderTests.targetLanguageBodyExcludedViaInjectedDetector —— 注入 stub 把某 body 判为目标语，断言其被排除 / 标 `.low`（脱离真实 NL 不确定性，P0-A）；预期失败：§13.4 源取信纪律未实现。
  GRDBLearnerStyleProviderTests.neverReadsAIGeneratedText —— **行为断言**（镜像 LM01 `undepositedCandidateExcluded`，P1-A）：同时 seed 一条母语 `entries.body` 与一条 `learning_materials.learning_text` / `memory_candidates.text` 含唯一 AI-only token，断言该 token 的语言学特征**不**进入 StyleImprint；预期失败：provider 尚不存在。
  GRDBLearnerStyleProviderTests.neverCrashesOnShortOrNonNaturalText —— 预期失败：最小长度门 / 低置信降级未实现（P2-2）。
  GRDBLearnerStyleProviderTests.realDetectorSmoke —— 少量**真实 NL 冒烟**（强信号长 fixture），覆盖默认 `NLLanguageRecognizer` 实现；仅 macOS runner（NaturalLanguage 仅 Apple 平台，P0-A/P3-A）。
  （仅启用展示）StyleSnapshotPresentationTests.neverShowsCognitiveOrLevelVerdict —— 预期失败：presentation 尚不存在（约束 4）。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceLearnerModel   # 含真实 NL 冒烟用例时只能 macOS runner，Linux 本机编译失败
  swift test --package-path Packages/LangoTraceUI   # 仅启用展示时
不新增单元测试的原因（如适用）：不适用，全程 TDD。
```

## 16. 验证命令

```bash
# 聚焦（本机 / CI 轻量单包）
swift test --package-path Packages/LangoTraceLearnerModel
swift test --package-path Packages/LangoTraceUI   # 仅启用展示

# 文档
scripts/check-docs.sh
```

本方案**无 migration**；若启用展示含三端 UI，收口前三端构建 / 全量验证按 CLAUDE.md 1.4 放 GitHub Actions（仓库临时 public），不在本机跑 `scripts/verify.sh`。若仅 seam（无 UI），单包测试即可覆盖。

## 17. 文档影响检查

- [ADR-006](../../decisions/006-system-level-three-layer-learner-model.md)：回写「LM02 Style 层 v1 表面写作印记已落地（compute-on-read、零外发；认知风格 / 下投影留 v2 / 后续切片）」+ **§8 持久化分类分层细化（P1-2）**：v1 表层可重算真派生、不持久；「准原始 → 纳入备份」适用 v2 自陈 / 认知风格——此为对 ADR §8 明文的实质性细化，须正式回写实施进展（实施后）。
- **新增 architecture note**（P1-2，与 S1 persistence note 同型）：记「Style v1 表层 = compute-on-read 真派生、不建表 / 不进备份；准原始 / 备份纳入仅 v2 自陈 + 认知风格」的跨任务硬接缝，防后续会话误判建表。
- `docs/architecture/001-initial-module-boundaries.md`：LangoTraceLearnerModel 获得 Style 层（命中包边界变化审查触发）。
- `docs/architecture/002-system-map.md`：Style 子系统 compute-on-read 数据流（读 entries → NL 本地检测语种按母语分组 → StyleImprint）。
- `docs/platform-page-inventory.md`：**仅当**启用展示，总览页新增表达快照分区（命中平台页面变化触发）；默认 seam-only 不触发。
- `docs/idea/01-learner-model.md`：§13.9 待决点收口回指——命名 = StyleImprint/表达快照、持久化 = v1 compute-on-read（§8 分层细化）；展示默认（§13.4 / decomposition §35③）= **默认不展示（待用户产品决策）**。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（P1-B）：登记「Style v1 表层 compute-on-read 不持久不备份；准原始 / 备份适用 v2 自陈 + 认知风格」，与 S1 拟登记的 Ability compute-on-read 条目并列（spec/007 当前零 learner-model 条目）。
- review：新子系统 + （若展示）页面分区命中专项审查触发，实施后按 `docs/review/README.md` 创建 round 或记录跳过原因。
- 是否需要新 ADR：否——本方案是 ADR-006 Style 层的实施，沿用其全部决策；§12.0 展示（idea 层默认见 §13.4 / decomposition §35③）/ §12.2 命名（§13.9）未定，作方案内决策 + 用户最终确认；§12.4 §8 持久化分层细化须回写 ADR-006 实施进展但不反转决策，不构成 ADR 级反转。

## 18. 实施记录

2026-06-25 落地（dev 分支，seam-only / Phase 1 only，Phase 2 展示按用户决策不执行）：

- **域模型**：`StyleImprint` / `StyleMetricKind`（surface v1；cognitive 保留位不产出）/ `StyleSignalConfidence`（high/low）/ `StyleSurfaceMetrics`（句长/TTR/正式度）/ `StyleNativeLanguageImprint`（按母语分组 + 证据集采样上限 evidenceSampleLimit=20）；`LearnerSourceType.entryBody`。
- **注入 seam（P0-A）**：`LanguageDetector` 协议 + 默认 `NaturalLanguageDetector`（包 `NLLanguageRecognizer`）；测试注入确定性 `StubDetector`，核心分组/排除用例脱离真实 NL。
- **provider**：`LearnerStyleProvider` 协议 + `GRDBLearnerStyleProvider`（镜像 LM01 reader-only，读 `entries` JOIN `language_spaces`，`deleted_at` 过滤天然级联；最小长度门 + 置信阈值；机械分词算指标确定性；CJK glyph/Latin word 分别计 token）。红线：SQL 仅 FROM/JOIN `entries` + `language_spaces`，源级 grep + 行为断言 `neverReadsAIGeneratedText`（sentinel 不入印记）。
- **装配**：`AppEnvironment.learnerStyleProvider` 字段（seam-only 暴露，无消费者，镜像 LM01 `learnerContextProvider`）；抽出 `makeMemoryReviewActions` 控 file_length（AppEnvironment 1292 行 < 1300）。
- **TDD**：StyleImprintModelTests(3) + GRDBLearnerStyleProviderTests(6，含红线/目标语排除/级联/短文本/真实 NL macOS 冒烟) 先失败后实现。
- **验证**：轻量本机 LearnerModel 41 全绿，format/lint 0 error；含 AppEnvironment 改动的全量 Build & Test 经 GitHub Actions CI 绿。
- **scope-down 全兑现**：无认知风格/AI 校准、无 Style→Ability 下投影消费、无持久化表/migration、无展示（seam-only）、不碰 derive()/LanguageLevel。
- **§12.4 §8 持久化分层细化**已落 ADR-006 实施进展 + 新 architecture note（v1 表层真派生不持久；准原始/备份仅 v2）。
- **§17 文档影响已回写**：ADR-006 影响节（S2 进展 + §8 reconcile）、新增 architecture note `2026-06-25-style-surface-imprint-recompute-notes.md`、architecture/001 §2.8、architecture/002-system-map §4.10、spec/007（Style v1 真派生不持久登记）、idea-01 §13.9（命名/持久化/展示默认收口）。

## 19. 完成标准

1. 第 3 节目标 1–6 均有代码 / 测试 / 文档证据（目标 5 视 §12.0 分叉决策）。
2. LearnerModel（+ 若展示 UI）聚焦测试全绿；无 migration、`git diff` 无新表；零外发 grep 无命中。
3. ADR-006 实施回写（含 §8 reconcile）、architecture/001 + 002、spec/007、（若展示）platform-page-inventory、idea-01 §13.9（命名 / 持久化）+ §13.4 展示默认收口已同步。
4. plan-vs-shipped 对账：StyleImprint 模型、LearnerStyleProvider seam、compute-on-read provider、源语言取信 / 目标语打折、（若展示）表达快照不下判决——逐项核对；认知风格 / 下投影消费 / 持久化 / band 作为有意 scope-down 记录。

## 20. 剩余风险

- **S2 立项已定（§12.0，P1-1）**：用户拍板 do-now / seam-only，**已采纳、不推迟**；投机地基风险（消费者未就绪前 seam 无读者）已知并被接受，缓解 = provider 契约保持克制稳定、不过度泛化（idea-01 §12.2）。剩余动作 = 待实现授权后纳入本地优先第一批。
- **NL 不可注入致测试不可控（P0-A，落地性）**：§12.1 已引入 `LanguageDetector` 注入 seam（默认包 `NLLanguageRecognizer`，测试注入 stub），核心分组 / 排除用例改注入断言、真实 NL 仅冒烟。若实现时省去 seam，红绿路径将 flaky / Linux 编译失败——实现必须落 seam。
- **展示越红线风险（§12.0，P0-2）**：默认已收敛为不展示；若用户要求启用展示，表达快照须严守机械描述、不越人格 / 认知侧写（presentation 测试断言无侧写 / 降级键 + 人工审查），且须先收口展示默认（§13.4 / decomposition §35③）。误展示判决是本切片最大产品风险。
- **信号取源依赖 NL 检测（P0-1）**：`entries.source` 非语言键，语言判定全靠 `NLLanguageRecognizer`；母语产出量少 / 短文本 / 混合语言时误检 → 目标语误入干净信号风险，须置信阈值 + 最小长度门 + 排除策略，空态优雅降级。
- **跨母语可比性（P1-3）**：表面指标语言相关，须按母语分组、不跨语言算术平均；多母语用户 v1 可限主母语单组、其余低置信占位。
- **持久化分层细化（§12.4，P1-2）**：v1 表层判可重算真派生（不持久），但这是对 ADR-006 §8 明文的实质细化，须回写 ADR + 新 architecture note；若用户认为 Style 应一开始即持久 / 备份，改建表 + writer，返工中等。
- **Style 命名（§12.2）**：内部 StyleImprint、用户面「表达快照」（仅展示时需定）；v2 认知半边落地时再议总称。
- **与语伴 / 改写下投影的接缝**：S2 只产出源语言印记 + seam；§13.5 下投影到目标语改写（按 Ability i+1）留语伴 / 改写切片消费，本方案 provider 返回完整印记 + 置信度，为下投影留接口，不预实现。
- **本环境（若 Linux）**无 Swift 工具链；NaturalLanguage 是 Apple 框架，测试须 macOS / GitHub Actions。
```
