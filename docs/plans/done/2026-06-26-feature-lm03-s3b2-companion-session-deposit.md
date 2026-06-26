# 任务方案：LM03-S3b-2 语伴对话小结 —— 候选批量 deposit 闭合「对话 → 记忆」

状态：Done（2026-06-26 实现完成，全量 CI 绿 run 28243788513，移 done/）
自审核状态：Reviewed
类型：feature
创建日期：2026-06-26
最后更新日期：2026-06-26

## 用户确认记录

- 2026-06-26：用户确认 **S3b-2 范围 = 复用 S2a 提取 + 批量 deposit，不新增摘要 AI**——小结的核心价值 = 把聊天候选词「闭合回记忆」（提取 → 复习），而非再造一段叙述摘要。
- 2026-06-26：用户确认 **deposit 粒度 = 批量「全部加入记忆库」+ 逐条「已加入」态**（对齐 idea-03 §3.8「复用现有管线、而非新造手动选词流程」）。
- **实现授权**：尚未授权。本方案完成双轮隔离自审 → `Reviewed` 后提交用户授权，授权前不写生产代码。

## 这份文档是什么

S3b-2 完整实施方案：落地 idea-03 §3.12「对话小结」的核心闭环——把语伴聊天反哺产出的候选词（LM03-S2a `companion_memory_candidates`，含词/短语/句型/语法点/**典型错误**五类）**批量 deposit 进真正的记忆复习系统**（E7/E8 `memory_items` + 复习队列），把对话闭合回「记录 → 对话 → 记忆」。

**调查结论（真增量）**：S2a 提取（含 errorPattern）、E7 deposit + 幂等、E8 复习队列**均已落地**；但 `companion_memory_candidates` 与 `memory_items` **当前完全孤立、无任何 deposit 连接**。本片唯一真增量 = **建立这条 deposit 连接 + 小结 deposit UI**。**无新 AI、无新外发类目、无新 migration**（deposit 是纯本地动作；提取复用既有 S2a；复习系统复用 E7/E8）。权威边界以 ADR-008 / spec/007 / idea-03 §3.8/§3.12 为准。

## 北极星 / 边界对照（实现前自检）

- **无新外发 / 无新 AI**：deposit 是**纯本地**写入（`companion_memory_candidates` → `memory_items`），不发任何 Provider；提取仍复用既有 S2a「提取词汇/表达」能力（既有外发类目 `.companionConversation`，非本片新增）；本片**不新增摘要 AI / capability / 外发类目**（用户已定）。决策 #10 不涉及（无新外发）。
- **复用 E7 幂等 deposit，不造手动选词流程**（idea-03 §3.8）：批量「全部加入」复用 `GRDBMemoryItemRepository.deposit(MemoryDepositInput)`（幂等键 `(space_id, source_candidate_id)`）；逐条「已加入」态由 `depositedCandidateIDs` 驱动；不新增逐词手动挑选流程。
- **候选 = 派生 staging，memory_item = 主数据**：deposit 把候选**快照**进 `memory_items`（E7 语义：snapshot 存 text/example，候选后续删除/重提取不影响已 deposit 项）；deposit 后候选仍在 `companion_memory_candidates`（展示「已加入」）。
- **无新 migration**：复用 `memory_items`（v26）+ `companion_memory_candidates`（v31）；`source_kind` 复用既有 `'candidate'`（CHECK 仅允许该值，companion 候选 deposit 也是 candidate 来源，id 为 UUID 不与分析候选冲突）；`entry_id` 列可空（对话来源候选无归属 entry → 写 NULL）。
- **band 红线**：deposit 只搬运候选文本（词/表达/句型/语法/错误模式），**不碰 band / AI 难度 / learning_text**；候选无 difficulty → deposit 默认 `.medium`（中性，不读任何难度信号）。

## 范围（本片，待实现）

### 1. Core：companion 候选 → deposit input 适配

- `MemoryDepositInput.entryID` 由 `String` 放宽为 `String?`（既有分析候选 init 传 String 自动兼容，非破坏；`memory_items.entry_id` 本可空，`DepositedMemoryItem.entryID` 已是可选）。
- 新增 `MemoryDepositInput.init(companionCandidate: CompanionMemoryCandidate, spaceID:)`：`entryID = nil`（对话来源无归属 entry）、`sourceCandidateID = candidate.id`、`kind = MemoryItemKind(candidate.kind)`（既有映射：word/phrase→wordPhrase，sentencePattern/grammarPoint/errorPattern→sentence）、`text/exampleTarget/exampleNative` 直传、`note = explanationNative`、`difficulty = .medium`（候选无难度，中性默认，不读 band）。

### 2. UI seam：CompanionChatActions 加 deposit 动作

- `depositAllCandidates: @Sendable (_ spaceID: String) async -> Int`——批量 deposit 该 space 全部 companion 候选，返回成功 deposit 数（幂等：已 deposit 的复算返回已有项、不重复）。
- `depositedCandidateIDs: @Sendable (_ spaceID: String) async -> Set<String>`——已 deposit 的候选 id 集（驱动逐条「已加入」态）。
- `.disabled` 与 init 默认值补齐（沿用既有 seam 风格）。

### 3. Store：CompanionChatStore deposit 态 + 动作

- `@Published private(set) var depositedCandidateIDs: Set<String>`（load + deposit 后刷新）。
- `func depositAllCandidates() async`：调 `actions.depositAllCandidates(spaceID)` → 刷新 `depositedCandidateIDs`；`@Published private(set) var isDepositing` 进行态防重入。
- `func isCandidateDeposited(_ id: String) -> Bool { depositedCandidateIDs.contains(id) }` 便捷查询。
- load 时 `depositedCandidateIDs = await actions.depositedCandidateIDs(spaceID)`。
- **自审订正（不改 `CompanionCandidatePresentation`）**：`isDeposited` **不加进 presentation struct**——它是随 deposit 动态变化的态（presentation 既有字段如 `isSourceMessageDeleted` 是静态的、且为 `let` 不可变，重投影别扭）。改由 store 的 `@Published depositedCandidateIDs` + 上述便捷查询承载，view 按候选 id 查询；deposit 后 `@Published` 变更自然驱动 view 重渲染。避免 presentation `let` 字段重投影 + 不破坏 presentation 既有构造点。

### 4. View：小结 deposit UI（复用既有提取结果面板）

- 既有提取结果区（`extractionResults`）在有候选时新增**「全部加入记忆库」批量按钮**（`canDeposit = 有候选 && !isDepositing`）；逐条候选行按 `store.isCandidateDeposited(candidate.id)` 展示「已加入」徽标。
- 对话小结 v1 = **可 deposit 的提取结果**（把对话闭合回记忆）；**不新增独立小结叙述视图 / 不触发新摘要**（用户已定）。可选低成本：展示既有 S3b-1 滚动摘要文本为「回顾」——**defer**（避免与 S3b-1 耦合，本片聚焦 deposit 闭环）。

### 5. App：装配 deposit 编排

- `CompanionChatActions.depositAllCandidates`：读 `repository.companionCandidates(spaceID)` → 逐条 `MemoryDepositInput(companionCandidate:spaceID:)` → `memoryItemRepository.deposit(input)`（幂等）→ 返回 deposit 数。**deposit 路径在 App 编排**（App 同时持有 companion repo + memory item repo），`GRDBMemoryItemRepository` **不依赖 companion 表**（保持边界）。
- `depositedCandidateIDs`：`memoryItemRepository.depositedCandidateIDs(spaceID)`（返回全 deposited source_candidate_id；store 与 companion 候选 id 取交集得「已加入」）。

## 关键架构落点与触碰

| 层 | 落点 | 动作 |
|---|---|---|
| Core | `MemoryDeposit.swift` | `MemoryDepositInput.entryID` → `String?`（**自审核验非破坏**：`memory_items.entry_id` 本为可空 FK `REFERENCES entries(id) ON DELETE SET NULL`；2 处 memberwise 调用点〔MemoryItemRepositoryTests / LocalExportServiceTests〕传 String→String? 隐式兼容；既有 `init(candidate:…,entryID:String)` 不改、body 仍传 String）；新 `init(companionCandidate:spaceID:)`（entryID nil / difficulty .medium / kind 映射 / note=explanationNative）。 |
| UI | `CompanionChatActions.swift` | `depositAllCandidates` + `depositedCandidateIDs` 两 seam **加在 init 末尾、带默认值**（**自审核验非破坏**：fixture 用标签参数 + 省略 optional，新 defaulted 参数不动 7 处闭包 fixture，区别 S3a `send` 既有闭包 arity 变更）；仅 `.disabled` 补 2 条默认。 |
| UI | `CompanionChatStore.swift` | `@Published depositedCandidateIDs` + `@Published isDepositing` + `depositAllCandidates()` + `isCandidateDeposited(_:)`；load 带出 deposited 集。**不改 `CompanionCandidatePresentation`**（见 §3 订正）。 |
| UI | `CompanionChatView.swift` | 提取结果区「全部加入记忆库」批量按钮 + 逐条按 `store.isCandidateDeposited(id)` 「已加入」徽标。 |
| UI | `CompanionChatPresentation.swift` | deposit 文案 key（en+zh-Hans：批量加入 / 已加入）。 |
| App | `AppEnvironment+Companion.swift` | `depositAllCandidates(spaceID)` = `repository.companionCandidates(spaceID)` 逐条 `MemoryDepositInput(companionCandidate:spaceID:)` → `memoryItemRepository.deposit(input)`（幂等，返回成功数；App 编排，`GRDBMemoryItemRepository` 不耦合 companion 表）；`depositedCandidateIDs(spaceID)` = `memoryItemRepository.depositedCandidateIDs(spaceID)` 透传。需在 `makeCompanionChatActions` 注入 `memoryItemRepository`（经 databaseFactory 构造 `GRDBMemoryItemRepository`）。 |
| 文档 | spec/005 或 007、architecture/002 §4.12（S2a 半环补 deposit 出站）、page-inventory、拆解 doc + 仪表盘、idea-03 §3.8/§3.12 收口 | §17 回写（无新外发 → 大概率不触发专项审查，但 deposit 连接跨 memory 主数据，architecture/002 + spec/007 须登记）。 |

## 非目标（本片不做）

- **新增摘要 AI / 独立小结叙述视图**（用户已定不做）；新外发类目 / capability / migration。
- **会话结束自动触发小结**：语伴是单一连续线程、无明确 session 边界 → defer（v1 手动批量加入）。
- **逐词手动挑选 deposit**（§3.8 反手动选词）；逐条「移除已加入」/ deposit 撤销（E7 有 softDelete，但本片只做加入侧，撤销走记忆库治理入口）。
- **companion 候选 → `learner_memory_facts`（系统级生活事实）**：候选是词汇/表达复习项（→ `memory_items`），非生活事实；生活事实 deposit 是学习画像页既有显式入口，不在本片。
- **S3b-1 滚动摘要作回顾展示**：defer（避免耦合）。
- **Ability 产出证据回流**（§3.8 第二半）：S2a `productionUtterances` 接缝已留，消费片后置。

## TDD 落点（先失败 → 最小实现 → 聚焦验证）

1. **Core `MemoryDepositTests`（扩，含既有回归核查）**：`MemoryDepositInput(companionCandidate:spaceID:)` —— word 候选 → kind `.wordPhrase`、errorPattern/sentencePattern/grammarPoint → `.sentence`；`entryID == nil`、`difficulty == .medium`、`sourceCandidateID == candidate.id`、`note == explanationNative`。**回归**：既有 `init(candidate:spaceID:entryID:)` 路径不变（entryID 仍 String 传入 → 非 nil）。
2. **Data `MemoryItemRepositoryTests`（扩）**：deposit 一条 companion 来源 input（entryID nil）→ `memory_items` 行 `entry_id` NULL、`source_kind 'candidate'`、kind 映射正确、review_state `new`；**幂等**：同 `sourceCandidateID` 再 deposit 返回同一项、不新增行；`depositedCandidateIDs` 含该 id。**回归**：既有 analysis 候选 deposit 测试（entryID 非空）仍绿。
3. **UI `CompanionDepositStoreTests`（新）**：经 stub `actions.depositAllCandidates`（返回数）+ `depositedCandidateIDs`（返回全候选 id）→ `depositAllCandidates()` 后 `store.depositedCandidateIDs` 含全部候选 id、`store.isCandidateDeposited(id) == true`；幂等（再调不报错、集合不变）；load 带出既有 deposited 集 → 对应候选预置「已加入」（`isCandidateDeposited` 真）、未 deposit 候选为假。
4. **UI 文案 key**：`CompanionChatPresentationTests` 锁 deposit 文案 key（批量加入 / 已加入）+ catalog 解析（en+zh-Hans）。
5. **App（经 CI macOS app test）**：批量 deposit 真实写 `memory_items` + 「已加入」态读回 + 幂等。

聚焦验证（本机轻量逐包，**含 UI package build——S3b-1 教训**）：`swift test --package-path Packages/{LangoTraceCore,LangoTraceData,LangoTraceUI}` + `swift build --package-path Packages/LangoTraceUI`（捕获 UI 包跨文件破坏）+ swiftformat/swiftlint。**App target 编译只能经 CI**（`LangoTraceApp` 是 xcodebuild target 非 SPM 包，本机不单独构建）。完整验证（三端构建 + macOS app test，**无新 migration**）走 GitHub Actions CI。

## 文档影响（§17，实现收口回写）

- **architecture/002 §4.12**：语伴聊天反哺半环补「候选批量 deposit 出站到 E7/E8 复习系统」（S2a 入站 + S3b-2 deposit 闭环）。
- **spec/007**：登记 companion 候选 deposit 进 `memory_items`（派生候选 → 主数据快照，复用 E7 幂等、`source_kind 'candidate'`、entry_id 可空）。
- **platform-page-inventory**：语伴行补「对话小结 = 候选批量加入记忆库 + 已加入态（LM03-S3b-2）」。
- **idea-03 §3.8/§3.12 收口**：对话闭合回记忆（候选 → 复习）落地；§3.8「真正存入记忆库/复习队列尚未实现」现状提示更新为已通。
- **拆解 doc + 仪表盘**：S3b-2 Done 登记（LM03 主体接近收口，仅余 S4 v2）。
- **专项审查触发判断**：无新外发 / 无新 migration / 无新 AI → **不触发隐私或 AI 专项审查**；但 deposit 连接跨 memory 主数据，architecture/002 + spec/007 须登记（数据流变化）。

## 剩余风险 / 待用户定（实现时 / 自审重点）

- **`source_kind 'candidate'` 复用 + 幂等键不含 source_kind（自审 P1）**：幂等 unique index = `(space_id, source_candidate_id)`（不含 source_kind），companion 与分析候选共用 `'candidate'`。两表 `source_candidate_id` 均为 UUID，跨表碰撞概率 ~2⁻¹²² 实际为零 → 幂等正确。**v1 接受**（两者都是候选来源、复习语义一致）；**注记**：若未来扩展 source_kind 来源种类，须把 source_kind 纳入幂等键（= migration），本片不做。
- **`entryID` 放宽为可选（自审 P0 → 核验为非破坏）**：`memory_items.entry_id` 本为可空 FK；2 处 memberwise 调用点（MemoryItemRepositoryTests / LocalExportServiceTests）传 String 隐式兼容 String?；既有 `init(candidate:…)` 签名不改。TDD 2 含既有 analysis deposit 回归断言。
- **批量 deposit 原子性**：v1 = 逐条幂等 deposit（非单事务全成全失）；因幂等，部分成功后重点「全部加入」可安全补齐 → 可接受，不引入批量事务。
- **「已加入」集合含分析候选 id**：`depositedCandidateIDs(spaceID)` 返回全来源 deposited id；store 与 companion 候选 id 取交集，不误标 → 正确。
- **difficulty 默认 `.medium`**：候选无难度信号、deposit 需值 → 中性默认（不读 band，红线安全）；复习初始难度中性可接受。

## 实施记录（2026-06-26，Done）

按 Reviewed 设计逐落点 TDD 落地，本机轻量逐包全绿 + 全量 CI 绿（run 28243788513）。

- **Core**：`MemoryDepositInput.entryID` String→String?（**核验非破坏**：2 处 memberwise 调用点传 String 隐式兼容、既有 `init(candidate:…)` 不改）；新 `init(companionCandidate:spaceID:)`（entryID nil / difficulty .medium / kind 五类映射 / note=explanationNative）。`MemoryDepositTests`（companion init + 映射 + analysis 回归）。
- **Data**：`deposit()` 无改动即支持 nil entryID（`DepositedMemoryItem.entryID` 本可选、`entry_id` 可空 FK）；`MemoryItemRepositoryTests` 扩 companion deposit（entry_id NULL / source_kind candidate / 幂等 / depositedCandidateIDs）+ 既有 analysis deposit 回归绿。
- **UI**：`CompanionChatActions` +`depositAllCandidates`/`depositedCandidateIDs`（init 末尾默认 + `.disabled`，**核验不破坏标签参数 fixture**）；store `@Published depositedCandidateIDs`/`isDepositing` + `depositAllCandidates()` + `isCandidateDeposited()` + load 带出 deposited 集（**不改 presentation**，避 `let` 重投影）；view 提取结果区「全部加入记忆库」批量按钮 + 逐条「已加入」徽标；本地化 key `companion.deposit.all`/`companion.deposit.added`（en+zh）。`CompanionDepositStoreTests`。
- **App**：`depositAllCandidates` = 读 `companionCandidates` 逐条 `MemoryDepositInput(companionCandidate:)`→`memoryItemRepository.deposit`（幂等、App 编排、memory repo 不耦合 companion 表）；`depositedCandidateIDs` 透传。
- **CI 教训复用（S3b-1）**：本机跑了 **UI 包全量测试** 捕获 `no-hardcoded-Han` 守卫——新增 UI 源注释含「已加入/对话小结」Han 字符被拦，已改英文（UI 源注释须英文）。本片**无跨包 exhaustive switch 破坏**（deposit 是新增 seam、非闭集 capability 消费点变更）。

**边界复核**：纯本地 deposit、无新 AI / 无新外发类目 / 无新 migration；复用 E7 幂等（`source_kind 'candidate'` + UUID `source_candidate_id`）；band 红线未碰（difficulty 默认 medium 不读难度信号）。

**轻量验证**：Core `MemoryDepositTests` + Data `MemoryItemRepositoryTests`(14，含 companion + analysis 回归) + UI(624) + swiftformat 0/453 + swiftlint（无 error）。**全量验证**：CI run 28243788513 `Build & Test` 绿（三端构建 + macOS app test + 全包测试 + lint）。

## 严格方案自审核记录

```
审核日期：2026-06-26
审核方式：隔离子代理 ×2（架构/数据一致性/边界/幂等 + 测试·落地/破坏面/可测性），并行 distinct-lens → 主会话核验汇总
审核轮次：第一轮（架构）+ 第二轮（测试·落地）
```

两轮各报 1 P0，**主会话核验后两 P0 均降级为非破坏（false alarm）**，其余 P1/P2 采纳写回：

- **架构轮 P0（`entryID` String→String? 级联破坏）→ 核验降级**：主会读码确认——`String→String?` 在实参位隐式兼容，既有 `init(candidate:…,entryID:String)` 签名**不必改**、body 传 String 到 String? 形参即可；memberwise 仅 2 处调用点（MemoryItemRepositoryTests / LocalExportServiceTests）传 String，隐式兼容；`memory_items.entry_id` 本为可空 FK（`REFERENCES entries(id) ON DELETE SET NULL`）。**非破坏**。采纳其诊断意图 = TDD 2 加既有 analysis deposit 回归断言。
- **测试轮 P0（两新 seam 破坏 7 处 fixture）→ 核验降级**：主会读 `CompanionExtractionStoreTests` 等确认——fixture 用**标签参数 + 省略 optional**（`loadThread:/send:/deleteFrom:/clear:/extract:`），新增**末尾 defaulted 参数不动任何 fixture**；区别 S3a 是改了 `send` **既有闭包的 arity**（非新增参数）。仅 `.disabled`（全量构造）补 2 条。**非破坏**。
- **P1（`isDeposited` presentation `let` 重投影别扭）已采纳〔设计调整〕**：弃「presentation 加 `isDeposited`」——它是 deposit 动态态、`let` 重投影别扭。改由 store `@Published depositedCandidateIDs` + `isCandidateDeposited(_:)` 承载、view 查询；deposit 后 `@Published` 自然驱动重渲染。不改 presentation struct。已写回 §3/§4 + 落点表 + TDD 3。
- **P1（`source_kind 'candidate'` 幂等键不含 source_kind，跨来源风险）已采纳为文档化残余**：幂等 index = `(space_id, source_candidate_id)`，两表 UUID 跨表碰撞实际为零 → 正确；注记未来扩展来源须纳 source_kind（= migration）。已写回 §剩余风险。
- **P1（既有 deposit 测试回归盘点）已采纳**：既有 deposit 测试 = `MemoryItemRepositoryTests` + `LocalExportServiceTests`；TDD 1/2 加回归断言，实施时先跑确认绿。
- **P1（验证须含 UI build；纠正 App 非 SPM）已采纳**：聚焦验证含 `swift build --package-path Packages/LangoTraceUI`（S3b-1 教训捕获 UI 包跨文件破坏）；**`LangoTraceApp` 是 xcodebuild target 非 SPM 包**，本机不单独构建、App 编译经 CI macOS app test。已写回验证段。
- **P2（App 编排不可单测）已采纳**：关键判定（Core input 构造 / Data 幂等 / store 投影）均下沉可单测层；App = 薄 glue（读候选→deposit 每条），经 CI macOS app test。落点表已写出 App 编排具体形态。
- **P2（`depositedCandidateIDs` 交集）已采纳为正确性说明**：返回全来源 deposited id，store 仅遍历 companion 候选取交集、分析候选 id 永不匹配 companion 候选 id（不同 UUID）→ 正确，无误标。
- **P2（`.disabled` + 参数顺序）已采纳**：两新 seam 加 init 末尾带默认（`{ _ in 0 }` / `{ _ in [] }`），`.disabled` 补齐。

**仍需用户确认的问题**：无新增范围性问题——范围（不新增摘要 AI）+ deposit 粒度（批量全加）已由用户 2026-06-26 决策；两 P0 经核验为非破坏，其余均实现细节，已收口。

**是否允许进入实现**：两轮 P0 经主会核验降级为非破坏（entryID 隐式兼容 / 新 seam 不破坏标签 fixture），全部 P1/P2 已写回正文（isDeposited 改 store 承载 / source_kind UUID 残余文档化 / 既有 deposit 回归盘点 / 验证含 UI build / App 编排具体化）。**自审门禁完成 → `Reviewed`**。待用户实现授权（`Reviewed` ≠ 已批准实现；本片无新 AI/外发/migration，风险中低，但触及 memory 主数据 deposit）。
