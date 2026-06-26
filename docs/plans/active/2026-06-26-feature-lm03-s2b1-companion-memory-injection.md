# 任务方案：LM03-S2b-1 语伴 Memory 注入 + 两层隐私控制 + PII scrubbing

状态：In Progress（六 Phase TDD 全落地 + 轻量单包测试全绿；待 §17 文档收口 + 全量 CI）

## 实施记录（2026-06-26）

六 Phase TDD 全部落地，轻量本地单包测试全绿（Core 270 / LearnerModel 55 / AI 223 / Data 274 / UI 612），swiftformat 干净、swiftlint 无新增 serious：

- **Phase 1（Core）**：`PIIScrubber`（手机号+身份证，outbound-only，中性占位）、`CompanionMemoryConsent`/`CompanionMemoryConsentStore`（三态 UserDefaults）、`CompanionInjectionGate`（纯函数四态门）、`CompanionThread.usesLearnerProfile`（Codable 向后兼容默认 true）、capability `.companionConversation` + descriptor `.curatedLearnerMemory`。
- **Phase 2（LearnerModel）**：`CompanionMemorySelection.select`（recency-DESC re-sort + 种类配额 top-5、不读 salience、仅 .global）+ band 红线守卫（源级 grep + 行为断言）。
- **Phase 3（AI）**：`CompanionPromptRegistry.systemPrompt(memoryContext:)` + `.memoryGroundedContext` directive（delimiter `<<<MEMORY>>>`）、`AIRequestProjections.companionConversation(hasMemoryInjection:)`（curated included / longTermMemory 始终 excluded）、`CompanionConversationEngine` 新增 `scrub` seam（历史回放 + 输入 + 注入片段统一脱敏，持久存原文）。
- **Phase 4（Data）**：v32 `companion_threads.uses_learner_profile`（DEFAULT 1）、repo 5 落点 + `setUsesLearnerProfile` writer + INSERT 一致性。
- **Phase 5（UI）**：两处 exhaustive switch、`CompanionMemoryPreviewModel`（included curated + excluded longTermMemory 披露）、`CompanionChatStore` consent/toggle 态 + `canInjectMemory`/`needsMemoryConsentPreview`、`CompanionChatView` 一次性预览 sheet + per-conversation 开关、本地化 key（en+zh-Hans）。
- **Phase 6（App）**：`AppEnvironment+Companion` 装配——`companionSend` 注入门权威判定（consent 最后一刻读 + 同 thread 行 toggle）→ select → 经 engine scrub 注入；`setUsesLearnerProfile` / `memoryPreviewProjection` 接线；持久存原文、仅 outbound 脱敏。

待办：§17 文档收口 + 全量 CI（v32 迁移 + 三端构建 + macOS app test）。
自审核状态：Reviewed（双轮隔离自审完成；4 P0 + 7 P1 + 关键 P2 已写回范围/架构/TDD 正文。Reviewed ≠ 用户已批准实现）
类型：feature
创建日期：2026-06-26
最后更新日期：2026-06-26

## 用户确认记录

- 2026-06-25：用户确认 LM03-S2 按风险拆 S2a/S2b。
- 2026-06-26：用户确认 **S2b 进一步拆 S2b-1 / S2b-2**（推荐）。本片 = **S2b-1**：语伴 Memory 注入（系统级生活事实）+ 两层隐私控制 + PII scrubbing。**方案B 主动找话题拆出为 S2b-2，独立后续门控**（边界登记见 [`2026-06-26-feature-lm03-s2b2-companion-active-topic-finding.md`](2026-06-26-feature-lm03-s2b2-companion-active-topic-finding.md)）。
- 2026-06-26：用户确认 **PII scrubbing v1 覆盖范围 = 手机号 + 身份证号**（确定性正则、低误杀；邮箱 / 地址留 v2）。
- 2026-06-25（沿用）：**Memory 注入 v1 排序 = 时近性 + 种类配额**（recency-primary；salience 列 v1 不参与，留 v2 FTS 相关性召回）。
- **实现授权**：**✅ 2026-06-26 用户授权实现**，并接受 3 项推荐默认：① 一次性预览在「首次进语伴会话（consent==notDecided）」触发；② 脱敏占位用母语中性短语；③ 接受 scrub 含历史回放（改 S1 原样外发行为，对齐「任何外发前」）。按方案 TDD 逐 Phase 实施，轻量本地单包测试 + 格式检查，重测试走 GitHub Actions CI。

## 这份文档是什么

S2b-1 的**完整实施方案**。承载语伴系列**最高隐私门**的核心半片：把用户保存的系统级生活事实（`learner_memory_facts`）经受控选择 + PII 脱敏后注入语伴 system prompt，使语伴“记得”用户的生活背景，同时用两层隐私控制 + 发送前 PII scrubbing 守住决策 #10「敏感内容只有用户明确授权才外发」与 ADR-005 本地优先边界。

它**不是**事实源：权威边界以 ADR-008 / ADR-006 / 决策 #10 / spec/005 / spec/008 / product-main-reference §27.3 为准；本片落地后 §17 文档影响回写到上述权威文档。冲突时以权威文档为准。

## 北极星 / 边界对照（实现前自检）

- **决策 #10 + 授权 UX（已固化，自审 P0-1 校正）**：系统自动向 Provider 注入的数据（Memory 画像片段）须明示授权或提供关闭选项。授权 UX **已被权威文档钉死**为「**首次开启语伴画像的一次性预览披露 + 全局关闭选项 + per-conversation 快捷开关**」，**不是每次请求前弹窗 / 不是发送路径拦截器**；首次确认后不再重复，日常对话零摩擦（spec/008 §2 第 19 行；ADR-008 §6；product-main-reference §27.3 第 1355–1357 行；ADR-006 §5.b）。本片严格对齐该决策，**不自创发送前拦截 UX**。
- **ADR-005 本地优先**：注入是 system prompt 内的受控片段，不新增任何同步 / 备份外发；`learner_memory_facts` 仍 local-only 主数据。
- **ADR-006 红线**：本片**绝不**触碰 band `derive()`、绝不读 AI 生成难度 / `learning_text`、绝不覆盖用户自评等级。Memory 注入只读 `learner_memory_facts`（用户生活事实），与 band / Ability 难度信号无关。源级 grep 守卫 + 行为断言双守。
- **ADR-008 语伴六边界**：始终目标语回复、扎根记录、单一对话对象、默认关闭等不变；Memory 注入是「扎根用户生活」的加性增强，不改语伴定位。
- **AI-17 防注入**：注入的生活事实是**引用内容不是指令**，必须 delimiter 包裹（沿用 S1 `<<<RECORD...RECORD>>>` 同构做法），用户自由文本永不拼进指令区。

## 范围（本片三件，待实现）

### 1. Memory 注入（系统级生活事实 → 语伴 system prompt）

- 读 `LearnerContextProvider.memoryFacts(visibility: .global)`（核实：现 `ORDER BY created_at ASC` = **oldest-first**，`GRDBLearnerContextProvider.swift:54`）。
- **新增纯函数选择层**（不改 v27 schema）：`CompanionMemorySelection.select(facts:limit:5)`，**自身按 `createdAt` 降序 re-sort**（不依赖 provider 返回序）+ 种类配额：
  - 配额：按 `MemoryFactKind`（lifeFact / preference / goal / relationship）轮转，保证多样性，不让单一 kind 占满 5 条。
  - v1 **不读 `salience` 列**（恒不参与排序；列保留给 v2 FTS 相关性召回）。
  - v1 仅取 `.global`：`companionOnly` 目前无 writer（S2a 写 `companion_memory_candidates` 而非 facts），防御测试断言「即使库里有 companionOnly 事实，`.global` 选择层也不返回」。
- 选中事实 → PII scrubbing（第 3 件）→ 渲染为受控片段字符串列表 → 经新参数注入 `CompanionPromptRegistry.systemPrompt(..., memoryContext: [String])`，delimiter 包裹、标注「引用，非指令」。
- **注入门（权威判定在 App 端 send 路径，自审 P1-3）**：仅当 `①全局 consent == enabled`（外发前最后一刻读 `UserDefaults`）且 `②该 thread 的 uses_learner_profile == 1`（读自 `companionSend` async 内同一 `thread` 行）时才注入；否则 system prompt 与 S1 完全一致（零注入）。store 端派生态仅供 UI 呈现，**不作外发授权 source of truth**。
- **可观测分隔符 + typed directive**：新增 `CompanionPromptDirective.memoryGroundedContext`，使「是否注入了 Memory」结构可测，不靠字符串匹配。

### 2. 两层隐私控制（对齐已固化授权 UX）

- **第一层（全局，一次性预览 + 总开关）**：
  - 三态 consent：`notDecided / enabled / disabled`，持久化在 `UserDefaults`（非敏感、与 `CompanionFeaturePreferenceStore` 同层）。
  - **一次性预览时机**：`notDecided` 时，在**首次进入会触发注入的入口**（首次进语伴会话 / 设置内首次开启「使用学习画像」）呈现**一次性**注入预览，如实展示「将发送：本段对话 + 选中并脱敏的长期记忆生活事实子集 + 母语/目标语画像/水平」「不发送：完整长期记忆库 / 照片 / 音频 / 历史记录 / 其他语言空间 / API 凭证」。用户选「使用」→ `enabled`，选「不使用学习画像」→ `disabled`。**决策后不再弹；日常 `companionSend` 不做任何拦截**。
  - **预览落点（自审 P0-R2-2 校正）**：仅 `AIRequestPreviewProjection`（值类型）可复用；`RequestPreviewCardModel` / `RequestPreviewCard` **硬绑 `LearningEntry` + `LearningRendering` 且只渲染 included 标签 + 静态 notSent footer、从不逐 descriptor 渲染 excluded**（`AIRequestPreviewPresentation.swift:42`、`LearningContentComponents.swift:165-219`），**不可直接复用**。本片**新建语伴专用一次性预览 presentation/view**，显式需求 = 同时渲染 included 的 `.curatedLearnerMemory` **与 excluded 的 `.longTermMemory` 标签**（兑现 P0-2 诚实披露契约）；为 `.longTermMemory` 补一个**非空 excluded 披露文案 key**（与 `label(for:)` 的 included 路径恒空互不冲突——included 路径 longTermMemory 仍空）。
  - `disabled` 后语伴照常工作，只是不注入任何画像；设置内可随时切回（再次走预览）。
  - **`notDecided` 期间默认不注入**（最高隐私门 + 决策 #10：未授权即不外发画像）。
- **第二层（per-conversation 开关）**：
  - 持久化在 `companion_threads` 新列 `uses_learner_profile`（v32 migration，`INTEGER NOT NULL DEFAULT 1`）；会话级粒度（用户决策：不改全局）。
  - thread 内可临时关闭本次会话的画像注入，不影响全局 consent。

### 3. PII scrubbing（外发前确定性脱敏，defense-in-depth）

- 新增 Core 纯函数 `PIIScrubber`：确定性正则脱敏，对齐 spec/008 §2「结构化 PII 在**任何外发前**做确定性 scrubbing」。
- **作用域 = 整个 outbound payload（自审 P0-R2-1 校正）**：核实 `CompanionConversationEngine.swift:71-79` 的 outbound assembly **同时**回放 `history.suffix(...).map(\.content)` **和** `append(userInput)`——即每轮把先前已持久化的用户消息一并重发。故 scrub 必须覆盖 **① 回放的历史消息 + ② 当前用户输入 + ③ 注入的 curated facts 片段** 三者，**仅 scrub 当前输入不够**（上一轮含手机号的消息会在本轮回放外发）。落点：scrub seam 下沉到 **engine outbound assembly（AI 包）**，或 App 端在传入 engine 前对 `history` 数组 + `userInput` + 注入片段统一 scrub。
- **outbound-only 不变量（自审 P2-R2-2）**：scrub 只作用于 outbound 投影，**不改写** `companion_messages` / `learner_memory_facts` 的持久原文（对话 / 事实是可恢复主数据，ADR-008 §4）——即「**存原文、发脱敏**」。
- v1 覆盖：**手机号（中国大陆 11 位 `1[3-9]\d{9}`）+ 身份证号（18 位，末位 X/数字）**。命中替换为**中性名词短语**占位（如 `[已隐去手机号]` / `[已隐去身份证号]`）——不可含可被弱模型解读为指令的动词（用户输入侧 scrub 后的占位走 `ConversationMessage(role:.user)` 消息体、**不在 system prompt delimiter 区内**，故占位文本须防注入，AI-17）。
- **对 S1 既有行为的有意修改（自审 P1-4）**：S1 `companionSend` 此前对用户输入 + 历史回放原样外发；本片起 outbound 前 scrub。须补 S1 send 路径回归测试；「误杀用户**故意**练习的数字串」入剩余风险（取向「宁少杀勿多杀」）。
- **不替代授权**：scrubbing 是纵深防御层；注入门 + 一次性预览仍是主闸。
- 纯函数、可穷举边界测试（见 TDD 1）。
- **绝不入日志**：scrubbing 前后内容都不写诊断日志 / DB；仅在内存中处理后送 Provider。

## 关键架构落点与触碰

| 层 | 落点 | 动作 |
|---|---|---|
| Core | `AIRequestPreviewProjection.swift` | ① 新增 capability `case companionConversation`（闭集，**S1 对话送 + S2b-1 注入共同的首个对话送 capability——S1 此前零预览投影**，自审 P1-1）；② 新增 included descriptor `case curatedLearnerMemory`（自审 P0-2：**不复用 `.longTermMemory`**）。**`companionConversation` 本片仅 preview 投影 + exhaustive switch，不写 `makeLogEntry`、不进 `ai_request_logs`**（对话级日志 defer，自审 P1-R2-1；`GRDBAIRequestLogRepository` 经核验以 rawString 存取 capability、无 exhaustive switch，不触）。 |
| Core | `PIIScrubber.swift`（新） | 纯函数结构化 PII 脱敏（手机号 / 身份证号），outbound-only。 |
| Core/AI | `CompanionInjectionGate`（新，纯函数 seam，自审 P2-R2-1） | `shouldInject(consent:threadUsesProfile:) -> Bool` + `memoryContext(facts:consent:threadUsesProfile:) -> [String]`——把「零注入」判定抽成**可单测纯函数**，App 只读 UserDefaults / thread 行再调它，使四态零注入可先失败。 |
| LearnerModel | `CompanionMemorySelection.swift`（新） | 纯函数 `select(facts:limit:) -> [MemoryFact]`，自身 recency-DESC re-sort + 种类配额 top-5；不读 `salience`。 |
| AI | `CompanionPromptRegistry.swift` | `systemPrompt(..., memoryContext: [String])` 新参数 + delimiter 注入 + `.memoryGroundedContext` directive（传 `[String]` 保持 AI 不依赖 LearnerModel）。 |
| AI | `CompanionConversationEngine.swift` | outbound assembly（行 71-79）接入 PII scrub seam：回放历史 + 当前输入 + 注入片段统一脱敏（自审 P0-R2-1；持久化仍存原文）。 |
| AI | `AIRequestProjections.swift` | 新增 `static func companionConversation(endpoint:lengthBucket:hasMemoryInjection:)` 工厂：`includedContent` 含 `.companionConversation` + `.nativeLanguageProfile` + `.targetLanguageProfile` + `.proficiencyLevel`，**`hasMemoryInjection` 时再含 `.curatedLearnerMemory`**；`excludedContent` 始终含 `.longTermMemory`（全局红线不破）+ 其余 alwaysExcluded。**不写 log-row builder**（P1-R2-1）。 |
| Data | `AppDatabaseCompanionMemoryToggleMigration.swift`（新）+ `AppDatabase.swift` | **v32**（核实 head=v31）`ALTER TABLE companion_threads ADD COLUMN uses_learner_profile INTEGER NOT NULL DEFAULT 1`。 |
| Core | `CompanionThread.swift` | 加字段 `usesLearnerProfile: Bool`（Codable 默认值处理，既有解码兼容，自审 P1-2）。 |
| Data | `GRDBCompanionRepository.swift` | 5 处落点（自审 P1-2 / P1-R2-2）：`thread(from:)` 解码 `row["uses_learner_profile"]`（行 332-339）+ `thread(id:)` SELECT 加列（行 99）+ `loadOrCreateThread` SELECT 加列（行 42）+ 新 writer `setUsesLearnerProfile(threadID:Bool)`。**INSERT 一致性义务**：`loadOrCreateThread` INSERT 若沿用 `DEFAULT 1` 不显式写列，**返回的内存 `CompanionThread` 必须同步设 `usesLearnerProfile = true`**，与 `thread(id:)` 读回一致（防 stale 断点）。行 254（`SELECT space_id`）/ 313（JOIN）不解码 thread，不受影响。 |
| Core | `CompanionMemoryConsentStore.swift`（新）+ `UserDefaults` 实现 | 三态 consent 持久化协议（与 `CompanionFeaturePreferenceStore` 同层、同风格）。 |
| UI | `AIRequestPreviewPresentation.swift` | `label(for: .curatedLearnerMemory)` 返回真实 included 标签；**`.longTermMemory` 的 included 路径保持恒空分支不动**（自审 P0-2）。**新增 excluded 披露文案 key**（供语伴预览渲染 excluded `.longTermMemory`，与 included 恒空互不冲突，P0-R2-2）。 |
| UI | `CompanionMemoryPreview*.swift`（新，P0-R2-2） | 语伴专用一次性预览 presentation + view：渲染 included `.curatedLearnerMemory` **与 excluded `.longTermMemory` 标签**（不复用绑 entry 的 `RequestPreviewCardModel`/`RequestPreviewCard`）。 |
| UI | `AIRequestLogListView.swift` | exhaustive capability switch（行 42）加 `case .companionConversation`。 |
| UI | `CompanionChatStore.swift` / `CompanionChatActions.swift` / `CompanionChatView.swift` | per-conversation 开关状态 + 一次性预览呈现 state machine（`notDecided` 触发一次性预览，非 per-send）+ toggle 入口。store `canInjectMemory` 仅 UI 呈现。 |
| UI | `Localizable.xcstrings` | 新增 consent / toggle / 注入披露（含 `curatedLearnerMemory` 标签）本地化 key（en + zh-Hans）。 |
| App | `AppEnvironment+Companion.swift` | `companionSend` 读 consent（最后一刻 UserDefaults）+ 同 thread 行 `usesLearnerProfile` → 调 `CompanionInjectionGate`（纯函数判定 + memoryContext）→ 取 facts → 选择 → scrub（历史回放 + 用户输入 + 注入片段）→ 渲染 → 注入；构建注入预览投影。**持久化存原文，仅 outbound 脱敏。** |
| LearnerModel(Tests) | band 红线守卫 | 源级 grep 目标文件清单（`CompanionMemorySelection.swift`：不含 `derive(`/`BandHysteresis`/`learning_text`/`difficulty`）+ 行为断言（构造含聊天+事实数据，band 输出不变，复用 S2a 模式）。 |

### `.curatedLearnerMemory` 披露设计（最高隐私门核心决策，自审 P0-2 改定）

**问题**：`.longTermMemory` 当前在 `alwaysExcludedContent`（`AIRequestProjections.swift:19-26`），`label(for:)` 与 photo/audio/apiCredential **共用恒空分支**（`AIRequestPreviewPresentation.swift:83-88`）——这个分支正是「长期记忆从不外发」**全局红线的物理载体**。

**决定（自审第一轮 P0-2 采纳）**：**新增专用 included descriptor `.curatedLearnerMemory`**，`.longTermMemory` 在所有 capability **保持 always-excluded 恒真**。
- `.curatedLearnerMemory` 仅出现在 `companionConversation(hasMemoryInjection: true)` 的 includedContent；label 真实文案（如「经你授权、选中并脱敏的长期记忆生活事实子集」）。
- 预览**同时**展示 included 的 `.curatedLearnerMemory` 与 excluded 的 `.longTermMemory`——诚实表达「注入的是经选择 + 脱敏的 curated 子集，原始全量长期记忆库不外发」。
- 语义更准：注入对象是 top-5 选择 + PII scrub 后的**派生片段**，与 raw 长期记忆库不是同一对象；`.longTermMemory` 全局红线不被削弱，新 capability 误标风险面不增。

## 非目标（本片不做）

- **方案B 主动找话题 / FTS 预筛 / 范围授权**：拆出 S2b-2（强依赖本片隐私闸）。
- **salience 评分 / FTS 相关性召回**：v2，本片注入排序只用时近性 + 种类配额。
- **`companionOnly` 可见性事实的写入 / 注入**：v1 仅注入 `.global`；无 companionOnly writer。
- **band / Ability / Style 注入**：band 红线不碰；Style 注入是 S4（v2）。
- **邮箱 / 地址 / 姓名 PII**：v1 仅手机号 + 身份证号。
- **对话级注入日志写库**：本片只做一次性预览披露，不强制写 `ai_request_logs`（S1 对话级 log 本就 defer；如未来需审计「何时注入画像」再加，记入后续方向，自审 P3-2）。

## TDD 落点（先失败 → 最小实现 → 聚焦验证）

1. **Core `PIIScrubberTests`**（swift-testing）：**精确边界**——`13800138000`（手机命中）/ `1234567890`（10 位不命中）/ `12000000000`（`1[0-2]` 不命中）/ 超长串定义命中规则；身份证 `11010519491231002X`（命中）/ 17 位 / 末位非 X 非数字（不命中）；纯价格/年份/短数字不误杀；空串/无 PII 原样返回；占位为中性名词短语（不含指令动词）。
2. **LearnerModel `CompanionMemorySelectionTests`**：7 条混 kind + createdAt → `select(limit:5)` 返回 5、recency-DESC、kind 配额不被单一 kind 占满、空→空、<5→全返回；**provider 返回 oldest-first 时选择层仍输出 recency-DESC**（防依赖 provider 序）；**库含 companionOnly 时 `.global` 选择层不返回**；**`salience` 独立守卫**——两 fact 仅 salience 不同、createdAt 相同时结果与 salience 无关（自审 P2-R2-3）。
3. **AI `CompanionPromptRegistryMemoryInjectionTests`**：`memoryContext: ["..."]` → 文本含 delimiter 包裹事实 + directives 含 `.memoryGroundedContext`；`memoryContext: []` → 文本与 S1 一致、不含该 directive。
4. **AI `CompanionConversationProjectionTests`**：`companionConversation(hasMemoryInjection: true)` 的 `includedContent` 含 `.curatedLearnerMemory` 且 `excludedContent` **仍含 `.longTermMemory`** + photo/audio/historicalEntries/otherLanguageSpaces/apiCredential；`hasMemoryInjection: false` → 不含 `.curatedLearnerMemory`、`.longTermMemory` 仍 excluded。
5. **Data `CompanionMemoryToggleMigrationTests`**：v32 后列存在且既有行默认 1；`setUsesLearnerProfile(threadID:false)` 写入读回；**`loadOrCreateThread` 新建 thread 后 `usesLearnerProfile == true` 且经 `thread(id:)` 读回一致**（P1-2 链路断点防御）。
6. **Core/AI `CompanionInjectionGateTests`**（自审 P2-R2-1，四态零注入可先失败）：`notDecided→[]`、`disabled→[]`、`enabled && toggle=1→非空`、`enabled && toggle=0→[]`——结构化断言注入门，不依赖 App target。
7. **UI `CompanionMemoryConsentStoreTests` + `CompanionChatStore` 注入态测试**：consent 三态持久化；`notDecided` 时 store 暴露「需一次性预览」态（非 per-send）；store `canInjectMemory` 派生（仅 UI）；per-conversation toggle 改派生态。
8. **UI presentation / 本地化 key 测试**：`label(for: .curatedLearnerMemory)` 非空、`label(for: .longTermMemory)` included 路径仍空、**excluded 披露文案 key 非空**；语伴预览 model included 含 `.curatedLearnerMemory` 且 excluded 披露含 `.longTermMemory` 标签；consent/toggle key 存在；exhaustive capability switch 覆盖 `.companionConversation`。
9. **LearnerModel `CompanionMemoryInjectionBandGuardTests`**（红线）：源级 grep（`CompanionMemorySelection.swift` 不含 `derive(`/`BandHysteresis`/`learning_text`/`difficulty`，沿用 S2a `#filePath` 定位法）+ 行为断言（含聊天+事实数据时 `GRDBLearnerBandProvider.band()` 输出不变）。
10. **AI/App outbound scrub 回归**（P0-R2-1 / P1-4）：构造**历史轮含手机号 + 本轮输入含身份证号**，断言 outbound assembly 后**两者均脱敏**、且持久 `companion_messages` 仍存原文；不破坏既有 send 成功路径。

聚焦验证（本机轻量，逐包）：
```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceLearnerModel
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache ignore
swiftlint --no-cache
```
完整验证（含 v32 迁移 + 三端构建 + macOS app test，走 GitHub Actions CI，跑前仓库临时 public、commit 带 `[ci]`、跑完转回 private）：`scripts/verify.sh` 等价序列。

## 文档影响（§17，实现收口时回写）

- **ADR-008 §6**：补 Memory 注入 = 受控 opt-in 系统注入、一次性预览授权 UX、两层控制、PII scrubbing；与 S1/S2a 外发分类区分。
- **ADR-006 §6 隐私闸 / §7.1**：记录 Memory（生活事实）注入路径与 band 红线隔离；注入只读 `learner_memory_facts`。
- **决策 #10 收口**：spec/008 §2 记录「系统自动注入」首个落地实例及其一次性预览闸。
- **spec/005**：companionConversation capability + 注入预览披露 + `.curatedLearnerMemory` 新 descriptor（含 changelog）。
- **spec/008**：PII scrubbing v1 边界（手机号/身份证）+ scrubbing 不入日志 + 用户输入侧 scrub 行为变更。
- **spec/007**：v32 `uses_learner_profile` 列（companion_threads）。
- **architecture/002**：§4.x 新增「语伴 Memory 注入与两层隐私」数据流条目。
- **platform-page-inventory**：语伴页新增 per-conversation 画像开关 + 一次性预览入口（三端）。
- **idea-03 §3.11 / §6.9**：收口 Memory 注入隐私模型（方案B 部分留 S2b-2）。
- **prompts/companion/**：新增 `system-injection.md` 记录注入片段渲染、delimiter、引用非指令边界。
- **架构备忘录**：记录 v2 salience/FTS 召回、companionOnly 事实注入、方案B（S2b-2）依赖本片隐私闸。
- **拆解文档 + 仪表盘**：登记 S2b-1 状态推进。
- **专项审查触发判断（自审 P3-R2-2）**：本片同时命中 migration（v32）+ AI Provider（新 capability）+ 隐私（最高门）+ App 启动结构（注入门接线），按 `docs/review/README.md` 收口时**须显式声明触发专项审查或说明跳过原因**。
- **release / testing 影响判断**：一次性预览披露文案 + PII 脱敏属隐私可见行为，收口时判断是否影响 release 隐私材料 / testing 手动验证清单（即便结论「暂不」也显式记录）。

## 剩余风险 / 待用户定（实现时）

- **PII 假阴性**：v1 覆盖中国大陆手机号 / 身份证号；国际号码 / 护照 / 银行卡 / 邮箱 / 地址不覆盖——剩余风险记录，主闸仍是注入门 + 一次性预览。
- **误杀练习数字**：对用户输入 scrub 可能误杀其故意练习的数字串（如练目标语数字）——取向「宁少杀勿多杀」，记入剩余风险。
- **占位文案语言**：脱敏占位倾向**母语**（避免污染目标语练习语境），实现时定。
- **一次性预览触发入口**：在「首次进语伴会话（consent==notDecided）」还是「设置内首次开启使用学习画像」呈现，二者皆为一次性、非 per-send；实现时择一或两者皆作为首次触发点（首次命中即决策、之后不再弹）。**已对齐权威授权 UX（自审 P0-1），不做发送前拦截。**
- **consent 与 per-conversation 默认**：全局默认 `notDecided`（未授权不注入）；per-conversation 默认 `1`（跟随全局）。已在范围内定。

## 严格方案自审核记录

```
审核日期：2026-06-26
审核方式：隔离子代理（第一轮架构已执行）+ 主会话核验（第二轮测试·安全·落地）
审核轮次：第一轮（架构，隔离子代理）/ 第二轮（测试·安全·落地）
未使用隔离审查的原因：第一轮已用隔离子代理；第二轮见下方记录。
```

### 第一轮（架构，隔离子代理）发现与处置

隔离子代理用真实代码核验，输出 2 P0 + 4 P1 + 4 P2 + 3 P3。全部确认并写回：

- **P0-1（授权 UX 冲突）已采纳**：原 §倾向「首次将要注入的发送前拦截」与 spec/008 §2 / ADR-008 §6 / product-main-reference §27.3 / ADR-006 §5.b 已固化的「**首次开启的一次性预览披露 + 全局关 + per-conversation，非每次弹窗**」直接冲突。**已校正**：consent 一次性预览、日常 send 零拦截。已核验三权威文档原文（spec/008:19、ADR-008:60、product-main-reference:1355-1356）。**非 ADR 变更**（是把方案对齐既有决策）。
- **P0-2（`.longTermMemory` 复用削弱全局红线）已采纳**：改采**新增 `.curatedLearnerMemory` included 专用 descriptor**，`.longTermMemory` 保持全局 always-excluded 恒真；预览同时展示 curated-included 与 longTermMemory-excluded，更诚实且不增回归面。已重写「披露设计」节、范围表、TDD 4/7。
- **P1-1（companionConversation 是全新 capability，S1 send 此前零预览）已采纳**：纠正「在既有投影上加分支」措辞；范围表列全 新 capability + 投影工厂 + `companionSend` 预览接线 + 三处闭集 switch。
- **P1-2（v32 列读投影链路不完整）已采纳**：列全 5 落点（Core 模型 Codable 默认 + `thread(from:)` + `thread(id:)` SELECT + `loadOrCreateThread` + 新 writer），TDD 5 补 `loadOrCreateThread` 读回一致断言。
- **P1-3（注入门 source-of-truth / stale read）已采纳**：注入门权威判定落 App 端 `companionSend` async（consent 最后一刻读 UserDefaults、`usesLearnerProfile` 读自同一 thread 行）；store `canInjectMemory` 仅 UI。
- **P1-4（PII scrub 作用域 + S1 行为变更）已采纳**：v1 scrub **注入片段 + 用户输入**（对齐 spec/008「任何外发前」）；显式声明对 S1 用户输入原样外发的有意修改 + 补回归测试（TDD 9）+ 误杀风险入剩余风险。
- **P2-1/2-2/2-3/2-4 已采纳/确认**：选择层显式 recency re-sort（不依赖 provider 序）；分层无环（选择层 LearnerModel / scrubber Core / 渲染 AI 传 String / 装配 App）；band grep 守卫钉死目标文件清单；companionOnly 防御测试。
- **P3-1/3-2/3-3**：占位母语（剩余风险）；对话级注入日志列后续方向不入本片；v2/方案B 未误塞本片。
- **子代理确认无需重复加固**：migration head=v31→v32 正确；memoryFacts oldest-first 事实准确；salience v1 不参与正确；AI-17 delimiter 沿用 S1 正确；descriptor `companionConversation` 已存在（本片新建的是 capability）。

### 第二轮（测试·安全·落地）

```
审核日期：2026-06-26
审核方式：主会话自审核（第一轮已用隔离子代理；第二轮主会话用真实代码核验，按 §4.2）
审核轮次：第二轮（测试·安全·落地）
基线：第一轮修订后方案（不重复第一轮已收口的 2 P0 + 4 P1）
```

第二轮用真实代码核验全部关键路径（`AIRequestPreviewProjection.swift`、`AIRequestProjections.swift`、`AIRequestPreviewPresentation.swift:71-89`、`AIRequestLogListView.swift:42-47`、`GRDBCompanionRepository.swift`、`AppDatabaseCompanionMigration.swift`、`CompanionThread.swift`、`CompanionPromptRegistry.swift`、`CompanionConversationEngine.swift:55-105`、`AppEnvironment+Companion.swift`、`GRDBLearnerContextProvider.swift:42-58`、`MemoryFact.swift`、`CompanionRefluxBandGuardTests.swift`）。报 **2 P0 + 3 P1 + 3 P2 + 2 P3**。第一轮已收口项确认正确写回（见末节）。

#### P0（阻塞实现）

- **P0-R2-1（scrub 作用域漏掉 history 回放 → 历史 PII 仍逐轮外发）**：第一轮 P1-4 把 scrub 定为「注入片段 + 用户输入」，但代码核验显示**外发不止当前输入**。`CompanionConversationEngine.swift:71-79`：outbound assembly 同时 `history.suffix(...).map { $0.content }` **和** `append(userInput)`——即**每一轮都把先前已持久化（原样存储）的用户消息一起重发**给 Provider。仅 scrub 当前 `userInput`（TDD 9 的范围）无法阻止**上一轮含手机号的消息在本轮被回放外发**。证据：`AppEnvironment+Companion.swift` `companionSend` 把原样 `userInput` 持久化（`appendMessage(content: userInput)`），下一轮经 `repository.messages()` 读回进 `history`，再经 engine 行 72-76 outbound。
  - **影响**：spec/008 §2「任何外发前确定性 scrubbing」与 ADR-008 §6 被绕过一条路径；最高隐私门出现漏洞。
  - **建议修改**：把 scrub seam 下沉到 **engine outbound assembly**（AI 包，对行 73-76 的 `message.content` 和行 79 的 `userInput` 统一 scrub），或在 App 端把传入 engine 的 `history` 数组与 `userInput` 一并 scrub（注入片段同理）。**持久化仍存原文**（对话是可恢复主数据，ADR-008 §4；scrub 只作用于 outbound，不污染本地存储）——即「存原文、发脱敏」。TDD 9 须扩为：构造**历史轮**含手机号 + 本轮新输入含身份证号，断言**两者**在 outbound assembly 后均被脱敏。
  - **是否阻塞**：是。这是本片隐私主张的核心，作用域定义错误会让「PII 绝不外发」名不副实。

- **P0-R2-2（一次性预览复用 `RequestPreviewCardModel` / `RequestPreviewCard` 不可落地，被高估）**：范围表第 77 行与 §48 写「复用 `AIRequestPreviewProjection` / `RequestPreviewCardModel`」呈现一次性预览。代码核验：`RequestPreviewCardModel.init(projection:entry:rendering:)`（`AIRequestPreviewPresentation.swift:42`）与 `RequestPreviewCard`（`LearningContentComponents.swift:165-167`）**硬绑 `LearningEntry` + `LearningRendering`**——语伴预览**没有 entry / rendering**，无法直接复用该 card model / view。更关键：当前 card **只渲染 `includedLabels` + 静态 `requestPreview.notSent` 文案**（`LearningContentComponents.swift:208-219`），**从不逐 descriptor 渲染 `excludedContent`**。而 P0-2 披露设计要求「**同时**展示 included 的 `.curatedLearnerMemory` 与 excluded 的 `.longTermMemory`」——现有 surface 无此能力。
  - **影响**：可复用的只是 `AIRequestPreviewProjection`（值类型）；card model / view 不可复用。若不澄清，实现期会撞墙或临时拼出与 P0-2 披露契约不符的 UI。
  - **建议修改**：范围表与 §48 改为：复用 `AIRequestPreviewProjection` 投影 + **新建语伴专用一次性预览 presentation/view**（或把 `RequestPreviewCardModel` 重构出一条「无 entry、projection-only、且渲染 excluded descriptor 标签」的构造路径）。把「渲染 `excludedContent` 的 `.longTermMemory` 标签」列为该 view 的显式需求；为 `.longTermMemory` 补一个**非空** excluded 标签 key（注意：现 `label(for:)` 对 `.longTermMemory` 恒空——P0-2 要求它在 included 路径保持恒空，但 excluded 披露路径需要单独的 excluded 文案，二者不冲突但**plan 未拆开**）。新增 TDD：语伴预览 model 的 included 含 `.curatedLearnerMemory`、excluded 披露含 `.longTermMemory` 标签非空。
  - **是否阻塞**：是。披露 UX 是最高隐私门的用户可见面，落点错误 = 无法兑现 P0-2 契约。

#### P1（高风险缺口）

- **P1-R2-1（exhaustive switch 落点漏列 `AIRequestLog.swift` 一族，但本片可不触）**：plan §68/78 列了 `AIRequestPreviewPresentation.swift` 与 `AIRequestLogListView.swift:42` 两处 capability/descriptor switch。核验：`AIRequestLogListView.swift:42` 的 `switch capability` 确需加 `.companionConversation`；`AIRequestPreviewPresentation.swift:71` 的 `switch descriptor` 确需加 `.curatedLearnerMemory`（含 `.longTermMemory` excluded 文案见 P0-R2-2）。**但**：新增 `case companionConversation` capability 后，若本片**不**为其写 `makeLogEntry` / 不进 `ai_request_logs`（§100 明确 defer 对话级日志），则 `AIRequestProjections.swift` 只需加 `companionConversation(...)` 投影工厂、**无需** log-row builder——这点 plan 范围表表述含糊（§72 写「工厂」未明确不含 log builder）。`GRDBAIRequestLogRepository.swift` 经核验**无 capability exhaustive switch**（capability 以 rawString 存取），故不触。
  - **影响**：若实现者误以为要补 log builder 会引入死代码；若漏 `AIRequestLogListView.swift:42` 则编译失败（exhaustive）。
  - **建议修改**：范围表显式写明「`companionConversation` capability **本片仅** preview 投影 + 三处 exhaustive switch（`AIRequestPreviewPresentation` descriptor switch、`AIRequestLogListView:42` capability switch、`RequestPreviewCardModel.label(for:)` descriptor switch），**不**写 `makeLogEntry`、不进 `ai_request_logs`（对话级日志 defer，§100）」。确认 `GRDBAIRequestLogRepository` 不在落点（已核验）。
  - **是否阻塞**：是（落点清单不全 = 编译失败或死代码）。

- **P1-R2-2（v32 INSERT 一致性与「5 处落点」语义校正）**：plan §75 列「5 处读投影落点」。代码核验 `companion_threads` 相关点：① `loadOrCreateThread` SELECT（`GRDBCompanionRepository.swift:42`）需加 `uses_learner_profile` 列；② `loadOrCreateThread` INSERT（行 55-59）——若沿用 `DEFAULT 1` 不写该列，则**返回的内存 `CompanionThread` 必须独立构造为 `usesLearnerProfile: true`** 才能与 `thread(id:)` 读回一致；③ `thread(id:)` SELECT（行 99）需加列；④ `thread(from:)` 解码器（行 332-339）需加 `usesLearnerProfile: row["uses_learner_profile"]`；⑤ 新 writer `setUsesLearnerProfile`。注意行 254（`SELECT space_id`）与行 313（JOIN）**不解码 thread，不受影响**。
  - **影响**：plan「5 处」数目对，但未点明 INSERT 走 DEFAULT 时**内存对象与 DB 默认值的一致性义务**——这正是 stale 读 / 显示与持久不符的经典断点。
  - **建议修改**：§75 补一句「INSERT 沿用 `DEFAULT 1` 不显式写列时，`loadOrCreateThread` 返回的 `CompanionThread` 须同步设 `usesLearnerProfile = true`」。TDD 5 已含 `loadOrCreateThread` 读回一致断言——确认覆盖此点（已覆盖，good），但 plan 正文须显式声明义务，避免实现者只改 SELECT 忘改内存构造。
  - **是否阻塞**：是（一致性义务未写明 = 易留 stale 断点；TDD 已设防但正文需声明）。

- **P1-R2-3（PII 误杀与目标语练习冲突的可验证边界 + 占位文案当指令风险）**：plan TDD 1 列「纯价格/年份/短数字不误杀」，但**身份证 18 位正则**与**手机号 `1[3-9]\d{9}`** 的边界与**目标语练习内容**的冲突缺结构化断言。具体风险：① 用户练日语/英语时输入连续数字串（电话练习、报数）会被误杀——plan 已记入剩余风险（取向「宁少杀勿多杀」），但**无测试锁定「11 位且 `1[3-9]` 开头才命中、10 位或 `1[0-2]` 开头不命中」的精确边界**；② 占位文案（如 `[已隐去手机号]`）注入 prompt 后，若落在指令区或未 delimiter 包裹，可能被弱模型当**指令**读（AI-17）——plan §29 要求注入片段 delimiter 包裹，但**用户输入侧 scrub 后的占位**是否也在 delimiter 区内未明确（用户输入走 `ConversationMessage(role:.user, content:)`，**不在** system prompt delimiter 区）。
  - **影响**：误杀边界不可回归 → 后续改正则易回归；占位当指令 → 防注入漏洞。
  - **建议修改**：TDD 1 补**精确边界用例**：`13800138000`（命中）/ `1234567890`（10 位不命中）/ `12000000000`（`1[0-2]` 不命中）/ `1380013800012`（超长不命中或仅命中内部 11 位——须定义）；身份证 `11010519491231002X`（命中）/ 17 位 / 末位非 X 非数字（不命中）。占位文案选**中性名词短语**（非祈使句），并在剩余风险记录「占位走用户消息体、非 delimiter 区，故须确保占位文本不含可被解读为指令的动词」。
  - **是否阻塞**：是（最高隐私门的脱敏器，边界必须可回归 + 占位防注入须声明）。

#### P2（重要改进）

- **P2-R2-1（注入门「零注入」结构化断言落点不在 App target，难先失败）**：决策 #10 最高隐私门要求 `consent==notDecided`/`disabled` 或 `toggle=0` 时**零注入**。但权威判定落在 `AppEnvironment+Companion.swift` 的 `companionSend`（App target），App 集成测试难写、难先红。建议：把「给定 consent + threadUsesProfile → 是否注入 + memoryContext 内容」抽为一个**可单测的纯决策函数**（如 Core/AI 的 `CompanionInjectionGate.shouldInject(consent:threadUsesProfile:) -> Bool` 与 `memoryContext(facts:consent:threadUsesProfile:) -> [String]`），App 只做 UserDefaults / thread 行读取再调它。这样 TDD 6 能对 `notDecided→[]`、`disabled→[]`、`enabled&&toggle=1→非空`、`enabled&&toggle=0→[]` 四态结构化先失败，不依赖 App target。建议写回 TDD 6 + 范围表（注入门纯函数 seam）。非阻塞但强烈建议（否则最高隐私门只有代码路径、无可先失败断言）。

- **P2-R2-2（持久化原文 vs 外发脱敏的边界未在 plan 显式声明）**：P0-R2-1 的修复隐含一条重要不变量——**scrub 只作用于 outbound，本地持久化存原文**（对话/事实是可恢复主数据）。plan §62 只说「scrubbing 前后内容都不写诊断日志/DB」，但**未明确「已存的对话原文不被 scrub 改写」**。建议 §3 补一句「scrub 是 outbound-only 投影，不改写 `companion_messages` / `learner_memory_facts` 持久原文（主数据完整性）」，避免实现者误把 scrub 写回库。非阻塞，但澄清边界。

- **P2-R2-3（`salience` 恒不参与的回归守卫缺失）**：plan §38 承诺 v1「不读 `salience` 列」。`MemoryFact.salience: Int` 存在（`MemoryFact.swift:38`）。建议 `CompanionMemorySelectionTests` 加一条：构造两 fact 仅 `salience` 不同、`createdAt` 相同，断言选择/排序结果与 salience 无关（锁死 v1 不依赖 salience，防 v2 提前泄漏）。非阻塞，低成本强守卫。

#### P3（非阻塞）

- **P3-R2-1（band 红线 grep 守卫目标文件名校正）**：plan TDD 8 守 `CompanionMemorySelection.swift` 不含 `derive(`/`BandHysteresis`/`learning_text`/`difficulty`。已 Done 的 `CompanionRefluxBandGuardTests.swift` 用 `#expect(!text.lowercased().contains("companion"))` 守 band provider 源——本片守的是**反向**（选择层不含 band 词）。写法可行（仿 S2a 的 `#filePath` + 路径上溯 + `String(contentsOf:)`）。建议直接沿用 S2a 的 `#filePath` 定位法（plan 已说「复用 S2a 模式」，确认无误）。仅表达确认，无需改。

- **P3-R2-2（磁盘可恢复性整体良好，两处补强即可）**：plan 自洽、引用行号精确、类型名经核验全部存在（`MemoryFactKind` 四态、`MemoryFactVisibility.global/.companionOnly`、`CompanionPromptDirective`、`<<<RECORD...RECORD>>>` delimiter、head=v31）。后续会话可仅凭 plan 从磁盘恢复。唯二需补：① P0-R2-1 的 scrub 作用域（history+输入）；② P0-R2-2 的预览落点（不可复用 card model）。补齐后磁盘可恢复性完整。

#### 文档影响完整性（§17 复核）

§17 覆盖 ADR-006/008、决策 #10、spec/005/007/008、architecture/002、page-inventory、idea-03、prompts、备忘录、拆解/仪表盘——经核验目标文件均存在（`docs/architecture/notes/`、`docs/prompts/companion/{system,extraction}.md`、ADR-006/008、S2b-2 boundary file）。**补两点**：① **触发专项审查判断**未显式写——本片同时命中 migration（v32）+ AI Provider（新 capability）+ 隐私（最高门）+ App 启动结构（注入门接线），按 `docs/review/README.md` 应在 §17 显式声明「触发专项审查 or 在收口说明跳过原因」（现仅列回写落点，未列审查触发判断）。② **release / testing** 影响未判断——一次性预览披露文案 + PII 脱敏属隐私可见行为，收口时应判断是否影响 release 隐私材料 / testing 手动验证清单（即便结论是「暂不」，也应显式记录）。建议 §17 补「专项审查触发 + release/testing 影响判断」两行。

**第二轮发现摘要**：2 P0（scrub 漏 history 回放 / 预览 card 不可复用）+ 3 P1（switch 落点清单精确化 / v32 INSERT 一致性义务 / PII 边界+占位防注入可验证）+ 3 P2（注入门纯函数 seam / 持久原文 vs 外发脱敏边界 / salience 守卫）+ 2 P3（grep 守卫确认 / 文档审查触发与 release-testing 判断）。

**写回要求（实现授权前须落实到正文）**：P0-R2-1 改 scrub 作用域为「engine outbound assembly（history + 输入 + 注入片段）」并扩 TDD 9 含历史轮；P0-R2-2 改预览落点为「投影复用 + 新建语伴专用预览 view（渲染 excluded `.longTermMemory` 标签）」并补 excluded 文案 key；P1 三项补范围表/§75/TDD 1 的精确化；P2-R2-1 抽注入门纯函数 seam 进 TDD 6。

**仍需用户确认的问题**（沿第一轮，未新增范围性问题）：① 一次性预览触发入口（首次进会话 vs 设置开启）；② 占位文案语言（倾向母语）；③ 对用户输入 + **历史回放** scrub 改变 S1 行为是否接受（第二轮把作用域从「仅当前输入」扩到「含历史回放」，建议接受，对齐「任何外发前」）。

**是否允许进入实现**：第二轮 2 P0 + 3 P1 + 3 P2 **已于 2026-06-26 全部写回正文**——scrub 作用域扩至「engine outbound assembly（历史回放 + 输入 + 注入片段）+ 存原文发脱敏」（§3 / App 行 / TDD 10）；预览落点改「投影复用 + 新建语伴专用 view 渲染 excluded `.longTermMemory`」（§2 / UI 行 / TDD 8）；switch 清单精确化 + capability preview-only 不写 log（架构表 / P1-R2-1）；PII 精确边界 + 占位防注入（TDD 1 / §3）；注入门抽 `CompanionInjectionGate` 纯函数 seam（架构表 / TDD 6）；INSERT 一致性义务（Data 行）；salience 守卫（TDD 2）；§17 补专项审查触发 + release/testing 判断。**自审门禁完成 → `Reviewed`**。仍待：用户对下方 3 项确认 + **用户实现授权**（`Reviewed` ≠ 已批准实现）。
