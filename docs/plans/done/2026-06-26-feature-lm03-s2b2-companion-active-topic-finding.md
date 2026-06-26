# 任务方案：LM03-S2b-2 语伴方案B 主动找话题（一次性授权 + recency 智能最小发送）

状态：Done（六 Phase TDD + §17 文档收口 + 全量 CI 绿，已移 done/）

## 实施记录（2026-06-26）

六 Phase TDD 全落地，轻量本地单包测试全绿（Core 277 / LearnerModel 61 / AI 227 / Data 277 / UI 617），swiftformat 干净、swiftlint 0 serious：

- **Phase 1（Core）**：`CompanionTopicSourcingConsent` 三态 store；`CompanionInjectionGate.shouldSourceTopic`/`broughtInRecords` 纯函数 + 统一 toggle 不变量测试；`.broughtInRecords` descriptor；`CompanionTopicCandidate` 值类型。
- **Phase 2（LearnerModel）**：`CompanionTopicSelection`（recency top-1 纯函数）+ band 红线守卫（源 grep + 行为断言）。
- **Phase 3（AI）**：`CompanionPromptRegistry.systemPrompt(broughtInRecords:)` + `.topicGroundedInBroughtRecord`；`companionConversation(hasBroughtInRecords:)`；`CompanionConversationEngine` 加 `broughtInRecords` 参 + **修复 `seedEntryBody` scrub 遗漏**（方案A）+ scrub broughtInRecords（方案B）。
- **Phase 4（Data）**：`GRDBCompanionRepository.recentTopicCandidates`（recency、排软删、仅当前 space，纯 entries.body）。
- **Phase 5（UI）**：`.broughtInRecords` label（exhaustive switch）；store topic consent/`canSourceTopic`/`needsTopicSourcingPreview`/`topicPreviewModel`；View 一次性话题预览 sheet；本地化 key（含 toggle 语义统一为「使用我的内容」）；冷启动零外发回归（`loadNeverSendsEvenWhenTopicAuthorized`）。
- **Phase 6（App）**：`companionSend` send 回合内 topic grounding（无方案A种子 + shouldSourceTopic 门开 → recentTopicCandidates → select top-1 → broughtInRecords）+ `recordTopicPreviewProjection` 接线；持久存原文、仅 outbound 脱敏。

**全量 CI `Build & Test` 全绿（run 28217180799：iPhone/iPad/macOS 构建 + macOS app test + 全包测试 + lint，无新 migration）**。§17 文档回写完成。本片完成，移入 `done/`。
自审核状态：Reviewed
类型：feature
创建日期：2026-06-26（自 2026-06-25 原 S2b 拆分而来）
最后更新日期：2026-06-26

## 用户确认记录

- 2026-06-25：用户确认 S2 按风险拆 S2a/S2b。
- 2026-06-26：用户确认 **S2b 进一步拆 S2b-1 / S2b-2**；Memory 注入 + 两层隐私 + PII scrubbing = S2b-1（[`done/...s2b1`](2026-06-26-feature-lm03-s2b1-companion-memory-injection.md)，已落地 + CI 绿）。
- 2026-06-26（本片定调）：用户要 **减少授权与选择的交互、让语伴更有智能感** → v1 采**系统自动选条**（非手动逐条挑），授权收敛为**一次性全局授权**；过滤维度 v1 **仅 recency**（`entries` 无 tags 列、FTS 索引须显式 rebuild 易陈旧——见自审 P1-2，FTS 精排降后续）。
- **实现授权**：尚未授权。本方案已完成双轮隔离自审 → `Reviewed`，提交用户授权，授权前不写生产代码。

## 这份文档是什么

方案B = 语伴在「用户没有显式带入单条记录（方案 A）」时，**主动从用户已保存的记录里智能挑一个话题切入**。因属「系统自动把用户记录注入外发」（非用户逐条显式带入），与 S2b-1 同属**最高隐私门**（决策 #10 系统自动注入），复用 S2b-1 已验证的隐私闸 + PII scrubbing。权威边界以 ADR-008 §6 / ADR-006 §6 / 决策 #10 / spec/005 / spec/008 为准。

## 北极星 / 边界对照（实现前自检）

- **决策 #10 + ADR-008 §6**：方案B 采「一次性范围授权 + 本地预筛 + 最小发送」。v1 把「范围授权」收敛为**首次开启的一次性全局授权**（语义「允许语伴引用你保存的记录来开启话题」）。**这是 ADR-008 §6 的合规能力裁剪、非定位反转、不触发 ADR 修订**（自审 P1-4）：§6 核心约束是一次性授权 + 本地预筛 + 最小发送 top-1，三者全守；子范围（tags/时间窗）因 schema 限制留后续，登记 architecture note。
- **冷启动零外发不可破（自审 P0-1，最关键）**：S1 的冷启动 = 纯本地问候、零 outbound（`CompanionChatStore.load()` 从不调 `send`，红线测试 `box.sendCalled == false`）。**v1 绝不在进入会话 / load 阶段自动外发找话题**。找话题注入**只发生在用户已发起的 send 回合内**（与方案A `seedEntryBody` 同位）——用户发首条消息且无方案A种子且门开时，才 recency grounding。
- **系统自动注入分类**：v1 系统自动选条（非逐条手挑）→ 系统自动注入外发，**不可**降为用户主动发起类；必须挂 S2b-1 隐私闸（一次性授权 + per-conversation 开关 + 注入预览披露 + 发送前 PII scrubbing）。
- **最小发送**：v1 **仅 recency top-1**（最近 1 条记录正文）；绝不灌全库；预览如实披露「可能引用你保存的 1 条记录来找话题」。
- **band 红线（ADR-006）**：只读 `entries.body`（纯用户记录正文），**绝不**碰 band derive() / AI 难度 / learning_text；源级 grep + **数据源行为断言**双守（自审 P1-2/P2-1：注入正文一律走 `entryBody` 纯 `SELECT body FROM entries`，**绝不**用 FTS hit 的 snippet/body——后者折叠了 `learning_materials.learning_text` AI 生成物）。
- **AI-17 防注入**：记录正文是引用内容非指令，沿用方案A `<<<RECORD ... RECORD>>>` delimiter。
- **照片原图天然不外发**：方案B 只发记录文本正文；照片 / 音频附件保持 always-excluded。

## 范围（本片，待实现）

### 1. 一次性话题授权（第一层隐私，复用 S2b-1 consent 范式）

- 新增三态 `CompanionTopicSourcingConsent`（`notDecided / enabled / disabled`，`UserDefaults` key `LanguageCompanionTopicSourcing`，非敏感，mirror `CompanionMemoryConsentStore`）。
- `notDecided`：首次将触发找话题（用户发首条消息、门开、无方案A种子）前，呈现**一次性**预览（复用 `CompanionMemoryPreviewModel` 结构 + `.broughtInRecords` 标签，展示「将发送：为找话题引用你保存的 ≤1 条记录正文 + 母语/目标语画像；不发送：完整记录库 / 照片 / 音频 / 其他空间」）。选「使用」→ enabled，「不使用我的记录找话题」→ disabled。一次性、决策后不再弹。
- `notDecided` / `disabled`：不找话题（语伴照常本地冷启动问候，零外发）。

### 2. per-conversation 开关（第二层隐私，复用 v32 `uses_learner_profile`）

- v1 **复用** S2b-1 的 `companion_threads.uses_learner_profile`（v32），**语义自本片起统一为「本会话使用我的内容（学习画像 Memory + 记录话题）」**（自审 P2-1 审定：复用——少交互、免新 migration、最可落地；架构 P1-1 的「独立列」留后续若需分离）。
- **不变量（须测试）**：toggle=0 时 `CompanionInjectionGate.shouldInject==false` **且** `shouldSourceTopic==false`（关一处同时关画像与找话题）。
- 两个**全局** consent 仍物理隔离（`CompanionMemoryConsent` 管画像、`CompanionTopicSourcingConsent` 管找话题），仅 per-conversation 开关统一。

### 3. 智能 recency 选条（最小发送 top-1，v1 仅 recency）

- 候选来源 v1 **仅 recency**：新 `GRDBCompanionRepository.recentTopicCandidates(spaceID:limit:)` —— `SELECT id, title, body FROM entries WHERE space_id=? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?`（吃现有 `idx_entries_space_created_at`；**仅当前 space** = 决策 #10「不发其他空间」的可测载体；排软删）。
- **FTS 精排降为后续（自审 P1-2）**：`GRDBLocalSearchRepository.search` 索引须显式 `rebuildSearchIndex` 否则陈旧（用户刚写就搜不到，核心用例沉默失效）；且其 body 折叠了 AI `learning_text`。v1 不用 FTS，纯 recency 兜底，最可落地、不触 AI 生成物。
- 选条纯函数 `CompanionTopicSelection.select(candidates:limit:1)`（LearnerModel/Core 纯函数，recency-primary top-1，可测，不碰 band；源码注释避英文 `difficulty`/`derive(`/`learning_text` 禁词以免 grep 守卫自伤，自审 P2-4）。
- **v1 不追踪「已用种子」（自审 P1-3）**：去 `excludingEntryIDs`（无持久载体；`companion_threads.source_entry_id` 只存方案A 单值）。v1 每个 send 回合 recency top-1，**同一会话可能重复引用最近一条** → 记入剩余风险；去重 / 已用追踪留后续。

### 4. 注入 + 诚实披露（含修复方案A 既有 scrub + 披露缺口）

- **注入正文**：选中记录正文经 `entryBody`（纯 entries 列）取回 → 经 `CompanionPromptRegistry.systemPrompt(broughtInRecords:)`（新参数，`<<<RECORD>>>` delimiter + 新 `.topicGroundedInBroughtRecord` directive）。
- **PII scrub 修复（自审 P0-2，关键）**：核验发现 S2b-1 的 `CompanionConversationEngine.assembleRequest` **遗漏 scrub `seedEntryBody`**（方案A 记录正文当前**未脱敏外发**——既有隐私漏洞）。本片把 `seedEntryBody`（方案A）与新 `broughtInRecords`（方案B）**都纳入 `.map(scrub)`/`scrub(...)`**；**存原文、仅 outbound 脱敏**不变量扩到记录正文。
- **诚实披露修复（自审 P0-2/P0-3）**：核验发现方案A 的 `seedEntryBody` 在**任何 preview 路径零披露**（`companionConversation` 投影无 record descriptor）。新 included descriptor `.broughtInRecords` 由 **A/B 共用**：只要 `seedEntryBody`/选中记录非空即在 preview 披露 `.broughtInRecords`，顺带修复方案A 披露缺口。`AIRequestProjections.companionConversation(..., hasBroughtInRecords:)` 加参；`memoryPreviewProjection` 接线同步。
- **注入门纯函数（自审 P1-4）**：`CompanionInjectionGate` 加 `shouldSourceTopic(consent:threadUsesProfile:)` + `broughtInRecords(rendered:consent:threadUsesProfile:)`（与 Memory 门并列，四态可单测、不依赖 App target）。
- **复用 `.companionConversation` capability**（不新增 capability）；`AIRequestLogListView:42` 是 capability switch、**不触**；不写 `makeLogEntry`（对话级日志沿用 S2b-1 defer）。

## 关键架构落点与触碰

| 层 | 落点 | 动作 |
|---|---|---|
| Core | `AIRequestPreviewProjection.swift` | 新增 included descriptor `case broughtInRecords`（A/B 共用：为找话题/带入带的记录正文类目）。**不新增 capability**。 |
| Core | `CompanionTopicSourcingConsentStore.swift`（新） | 三态 consent + `UserDefaults`（mirror `CompanionMemoryConsentStore`）。 |
| Core | `CompanionInjectionGate.swift` | 加 `shouldSourceTopic(consent:threadUsesProfile:)` + `broughtInRecords(...)` 纯函数（四态可测）。 |
| Core/LearnerModel | `CompanionTopicSelection.swift`（新） | 纯函数 recency top-1（注释避英文禁词）。 |
| AI | `CompanionPromptRegistry.swift` | `systemPrompt(..., broughtInRecords: [String] = [])` + `<<<RECORD>>>` + `.topicGroundedInBroughtRecord` directive。 |
| AI | `CompanionConversationEngine.swift` | `assembleRequest`/`reply` 加 `broughtInRecords: [String]`；**补 scrub `seedEntryBody`（修方案A 遗漏）+ scrub `broughtInRecords`**。 |
| AI | `AIRequestProjections.swift` | `companionConversation(..., hasBroughtInRecords:)`；注入时 includedContent 加 `.broughtInRecords`，`.longTermMemory` 仍 excluded。 |
| Data | `GRDBCompanionRepository.swift` | 新 `recentTopicCandidates(spaceID:limit:)`（recency、排软删、仅当前 space）；top-1 正文复用 `entryBody`。 |
| App | `AppEnvironment+Companion.swift` | `companionSend`（**send 回合内**，非 load）：无方案A种子 + `shouldSourceTopic` 门开（consent 最后一刻读 + 同 thread 行 toggle）时 → recentTopicCandidates → `CompanionTopicSelection` top-1 → scrub-注入；装配 `recordTopicPreviewProjection`。**无新 migration**（复用 v32）。 |
| UI | `AIRequestPreviewPresentation.swift` | `label(for: .broughtInRecords)` 真实 included 标签（唯一必更穷举 descriptor switch）。 |
| UI | `CompanionChatStore`/`View`/`Actions` | 一次性话题授权 state（mirror Memory）+ 复用 per-conversation 开关；预览复用 `CompanionMemoryPreviewModel` + `.broughtInRecords` 文案。 |
| UI | `Localizable.xcstrings` | 话题授权 / `.broughtInRecords` 披露文案（en + zh-Hans）。 |
| LearnerModel(Tests) | band 红线守卫 | 源级 grep（`CompanionTopicSelection.swift` 无禁词）+ **数据源行为断言**（含 learning_text 的 entry → 注入正文不含 learning_text 片段、band 输出不变）。 |

## 非目标（本片不做）

- **load/进入会话阶段自动外发**：绝不破坏冷启动零外发（自审 P0-1）；找话题仅 send 回合内。
- **FTS 精排找话题**：v1 仅 recency（FTS 须 rebuild 易陈旧 + body 含 AI 文本，自审 P1-2）。
- **tags / 时间窗 / scene 过滤、子范围授权**：`entries` 无 tags；留后续 + architecture note。
- **「已用种子」去重 / 持久追踪**：v1 不追踪（无持久载体），每回合 recency top-1。
- **多条带入（top-N>1）、salience / 向量召回 / memoryItem 索引、独立 `uses_record_topics` 列**：后续。
- **band / Ability / Style**：红线不碰；Style = S4。

## TDD 落点（先失败 → 最小实现 → 聚焦验证）

1. **Core `CompanionTopicSourcingConsentStoreTests`**：三态持久化 + reset → notDecided。
2. **Core `CompanionInjectionGateTopicTests`**（四态可单测、不依赖 App）：`shouldSourceTopic` notDecided→false / disabled→false / enabled&&toggle=1→true / enabled&&toggle=0→false；`broughtInRecords(...)` 门关→[]、门开→透传；**统一 toggle 不变量**：toggle=0 时 `shouldInject` 与 `shouldSourceTopic` 同为 false。
3. **LearnerModel `CompanionTopicSelectionTests`**：recency-DESC、top-1、空→空、与 salience 无关。
4. **AI `CompanionPromptRegistryTopicTests`**：`broughtInRecords:["..."]` → 含 `<<<RECORD>>>` + `.topicGroundedInBroughtRecord`；`[]` → 与无注入一致。
5. **AI `CompanionConversationProjectionTests`（扩）**：`hasBroughtInRecords:true` → includedContent 含 `.broughtInRecords`、`.longTermMemory` 仍 excluded；false → 不含。
6. **Data `CompanionTopicCandidateRepositoryTests`**：`recentTopicCandidates` created_at DESC、排软删、**仅当前 space**（跨空间隔离守卫）、limit 生效、空库→空。
7. **AI outbound scrub 回归（修方案A + 覆盖方案B）**：`seedEntryBody` 含手机号 + `broughtInRecords` 含身份证 → outbound system prompt 两者均脱敏、持久 `entries` 仍原文。
8. **UI `CompanionTopicSourcingUITests`**：notDecided→needsTopicPreview、enabled&&toggle→canSourceTopic、一次性（决策后不再弹）；`label(for: .broughtInRecords)` 非空 + exhaustive switch 覆盖。
9. **UI 冷启动零外发回归**：沿用 `box.sendCalled==false` 不变量——授权后 `load()` 仍**不**触发任何 outbound（找话题只在 send）。
10. **LearnerModel `CompanionTopicSelectionBandGuardTests`**：源级 grep + 数据源行为断言（含 learning_text 的 entry → 注入正文纯 entries.body、band 不变）。

聚焦验证（本机轻量逐包）：`swift test --package-path Packages/{LangoTraceCore,LangoTraceLearnerModel,LangoTraceAI,LangoTraceData,LangoTraceUI}` + swiftformat/swiftlint。完整验证（三端构建 + macOS app test，**无新 migration**）走 GitHub Actions CI。

## 文档影响（§17，实现收口回写）

- ADR-008 §6（方案B v1 落地 = 一次性全局授权 + recency 最小发送；声明合规裁剪非反转）。
- ADR-006 §6 隐私闸 / band 红线（找话题只读 entries.body，不触 learning_text/FTS-折叠 AI 文本）。
- 决策 #10 收口：spec/008 §2 第二个系统自动注入实例。
- **spec/008（含既有漏洞修正记录）**：话题授权 + **修复 S2b-1/方案A 的 `seedEntryBody` scrub 遗漏**（对已落地行为的隐私修正，changelog 显式记）+ 复用 PII scrubbing。
- spec/005（`.broughtInRecords` descriptor + 投影披露 + 修复方案A 披露缺口 + changelog）。
- architecture/002 §4.14（找话题数据流，send 回合内、recency top-1）。
- platform-page-inventory（语伴页找话题 + 一次性授权；写明「找话题为 send 回合内注入、非进入会话自动外发」对齐 spec/008 §3）。
- idea-03 §3.6/§3.11 收口；prompts/companion（找话题注入条目）；拆解 + 仪表盘。
- architecture note：子范围授权（tags/时间窗）+ 独立 `uses_record_topics` 列 + 「已用种子」去重 + FTS 精排，四项后续提升登记。
- **专项审查触发判断**（AI Provider 新 descriptor + 隐私最高门 + App 注入接线 + 修既有 scrub 漏洞）+ release/testing 影响判断收口时显式记录。

## 剩余风险 / 待用户定（实现时）

- **单条记录 PII 集中度（自审 P1-3）**：方案B 带入**单条完整记录正文**，PII 集中度高于 S2b-1 的蒸馏片段；`PIIScrubber` 仅手机号/身份证，记录中地址/人名/事件不脱敏。缓解 = top-1 最小化 + 一次性预览前置披露 + per-conversation 开关 + 全局可关。**按用户「少交互智能感」诉求，v1 采一次性预览闸、不加每话题确认**；若后续需更强透明可加「外发前会话内可撤销提示」（登记 architecture note）。
- **同会话重复引用最近记录**：v1 不追踪已用种子，同会话多回合可能重复 recency top-1；可接受降级，去重留后续。
- **recency ≠ 相关**：v1 纯 recency 可能选到与对话不相关的记录；FTS 相关性精排留后续。
- **consent/toggle stale read**：沿用 S2b-1 纪律——`CompanionTopicSourcingConsent` 在 `companionSend` 最后一刻读、`uses_learner_profile` 读自同 thread 行；store 侧 `canSourceTopic` 仅 UI。

## 严格方案自审核记录

```
审核日期：2026-06-26
审核方式：隔离子代理 ×2（架构 / 测试·安全·落地），并行 distinct-lens 后主会话核验汇总
审核轮次：第一轮（架构）+ 第二轮（测试·安全·落地）
并行说明：两轮以独立 lens 并行执行后由主会话核验、去重、写回（非严格串行；高隐私门已交叉核验关键冲突）
```

两轮独立核验，**高度收敛**（两轮各自独立命中相同 2 个 P0），合计 4 P0 + 6 P1 + 多 P2，全部确认并写回正文：

- **P0-1（冷启动零外发被破）已采纳**：两轮独立命中——`CompanionChatStore.load()` 从不 send、`box.sendCalled==false` 是钉死不变量。**已校正**：找话题仅 send 回合内，绝不在 load 自动外发；TDD 9 守此不变量。
- **P0-2（`seedEntryBody` 既有 scrub 遗漏 + 方案A 零披露）已采纳**：两轮独立命中——`assembleRequest` 仅 scrub memoryContext/history/input，**漏 seedEntryBody**；`companionConversation` 投影无 record descriptor，方案A 记录正文外发但从不披露。**已校正**：本片补 scrub seedEntryBody（修方案A）+ broughtInRecords；`.broughtInRecords` A/B 共用修披露缺口；§17 spec/008 记既有漏洞修正。
- **P1-1 vs P2-1（per-conversation 列复用 vs 独立）分歧已裁定**：架构轮主张独立 v33 列（语义纠缠/误关），测试轮主张复用（少交互/免迁移/可落地）。**裁定 = v1 复用 `uses_learner_profile`**（对齐用户「少交互」），但把「语义统一为『使用我的内容（画像+记录）』」定为不变量 + 测试 toggle=0 同关两门；独立列留后续。
- **P1-2（FTS 不可靠：须 rebuild 易陈旧 + body 含 AI learning_text）已采纳**：v1 **仅 recency**，FTS 精排降后续；band 守卫补数据源行为断言（注入正文走 entryBody 纯列、不取 FTS snippet）。
- **P1-3（单条记录 PII 集中、是否加每话题确认）已处置**：按用户「少交互智能感」采一次性预览闸、不加每话题确认；残余风险显式记录 + 后续可加会话内可撤销提示（note）。
- **P1-4（一次性全局授权 vs ADR-008 §6「范围授权」）已采纳**：声明为合规能力裁剪、非反转、不触发 ADR 修订；§17 回写 ADR-008 §6 + note 登记子范围后续。
- **P1（excludingEntryIDs 悬空契约）已采纳**：v1 去除，不追踪已用种子，残余风险记录。
- **P1（注入门纯函数 / exhaustive switch 精确化）已采纳**：`shouldSourceTopic` 落 `CompanionInjectionGate` 纯函数四态可测；`.broughtInRecords` 仅触 `AIRequestPreviewPresentation.label(for:)` 一处，capability 复用不触 log switch。
- **P2（跨空间隔离测试 / 注释避禁词 / stale read 纪律 / 无新 migration 确认）已采纳**：TDD 6 加「仅当前 space」断言；选条源注释避英文禁词；门读纪律沿用 S2b-1；复用 v32 无新 migration。

**仍需用户确认的问题**：① 单条记录 PII 集中——是否接受 v1「一次性预览闸、不加每话题确认」（自审按你的少交互诉求默认接受）；② `.broughtInRecords` 顺带修复方案A 披露缺口（属隐私改善，默认接受）。

**是否允许进入实现**：两轮 4 P0 + 6 P1 已全部写回正文（触发模型绑 send / seedEntryBody+broughtInRecords scrub 修复 / .broughtInRecords A-B 共用披露 / 复用 toggle 统一语义 / v1 recency-only / 注入门纯函数 / 去 excludingEntryIDs）。**自审门禁完成 → `Reviewed`**。仍待用户对上述 2 项确认 + **实现授权**（`Reviewed` ≠ 已批准实现）。
