# Language Companion System Prompt — Memory Injection (LM03-S2b-1)

状态：Active

## 1. 基本信息

- 复用 Prompt id：`builtin.companion.system.v1`（version `1`）——Memory 注入是同一 system prompt 的**加性受控片段**，不另起 Prompt。
- 所属功能：语伴 Memory 注入（系统级生活事实）+ 两层隐私控制 + PII scrubbing（LM03-S2b-1）。
- 调用模块：`CompanionPromptRegistry.systemPrompt(memoryContext:)`、`CompanionConversationEngine`（`scrub` seam）、`CompanionInjectionGate`、`CompanionMemorySelection`、`PIIScrubber`。
- 代码位置：`Packages/LangoTraceAI/Sources/LangoTraceAI/CompanionPromptRegistry.swift`、`CompanionConversationEngine.swift`；`Packages/LangoTraceCore/.../PIIScrubber.swift`、`CompanionInjectionGate.swift`；`Packages/LangoTraceLearnerModel/.../CompanionMemorySelection.swift`。
- 自动化测试：`CompanionPromptRegistryTests`（memory injection）、`CompanionConversationEngineTests`（outbound scrub）、`CompanionMemorySelectionTests`、`PIIScrubberTests`、`CompanionInjectionGateTests`、`CompanionConversationProjectionTests`。

## 2. 触发与隐私边界（最高隐私门，决策 #10）

Memory 注入是**系统自动注入外发**（与用户显式发送/重发严格不同类），受三道控制：

1. **全局一次性预览 + consent**（`CompanionMemoryConsent`，`UserDefaults`）：授权 UX = 首次开启语伴画像的**一次性预览披露**（如实展示发/不发类目）+ 全局「不使用学习画像」关闭项；**非每次弹窗、非发送前拦截**，决策后日常零摩擦。`notDecided` 期间**不注入**。
2. **per-conversation 开关**（`companion_threads.uses_learner_profile`，v32 DEFAULT 1）：该会话可单独关闭。
3. **PII scrubbing**：注入前对**注入片段 + 历史回放 + 用户输入**统一确定性脱敏。

注入门权威判定在 App `companionSend`：`CompanionInjectionGate.shouldInject(consent:threadUsesProfile:)`（纯函数），consent 最后一刻读、toggle 读自同一 thread 行。门关时 system prompt 与 S1 完全一致（零注入）。

## 3. 注入内容契约

- 来源：`GRDBLearnerContextProvider.memoryFacts(visibility: .global)` → `CompanionMemorySelection.select`（时近性 DESC + 种类配额 top-5，**不读 salience**，仅 `.global`）。
- 渲染：选中事实文本经 PII scrub 后，以 delimiter `<<<MEMORY ... MEMORY>>>` 包裹为**引用内容、非指令**（AI-17 防注入，与方案 A 的 `<<<RECORD>>>` 同构）；声明 `.memoryGroundedContext` directive（结构可测）。
- **不得**包含：原始全量长期记忆库、band / AI 难度 / `learning_text`、Style 片段、FTS 结果、其他 Entry、照片、音频、API Key。

## 4. PII scrubbing（v1）

- 覆盖：手机号（`(?<![0-9])1[3-9][0-9]{9}(?![0-9])`）+ 身份证号（`(?<![0-9Xx])[0-9]{17}[0-9Xx](?![0-9Xx])`）。
- 占位：中性母语名词短语（`[已隐去手机号]` / `[已隐去身份证号]`，无指令动词）。
- **outbound-only**：仅作用于发送投影，**不改写**持久 `companion_messages` / `learner_memory_facts`（存原文、发脱敏）；不入日志 / DB。
- 剩余风险：国际号 / 护照 / 银行卡 / 邮箱 / 地址不覆盖；可能误杀用户故意练习的数字串（取向「宁少杀勿多杀」）。

## 5. 请求预览披露契约

- capability `.companionConversation`（首个对话送 capability，preview-only、不写 `ai_request_logs`）。
- 注入时 includedContent 含 `.curatedLearnerMemory`；`.longTermMemory` **始终 excluded**（原始全量不外发）。
- 一次性预览 `CompanionMemoryPreviewModel` 同时展示 included（curated 子集）与 excluded（完整记忆库 / 照片 / 录音），诚实区分「发 curated / 不发全量」。

## 6. 方案B 记录找话题注入（LM03-S2b-2）

- 同一 `builtin.companion.system.v1` 的加性 `broughtInRecords: [String]` 受控片段：授权（`CompanionTopicSourcingConsent` 一次性）后，**仅 send 回合内**（无方案A 种子 + `CompanionInjectionGate.shouldSourceTopic` 门开）自动带入 `CompanionTopicSelection` 选出的 recency top-1 记录正文（纯 `entries.body`、仅当前 space、不用 FTS）。
- 渲染：`<<<RECORD ... RECORD>>>` delimiter（引用非指令，AI-17）+ `.topicGroundedInBroughtRecord` directive（区别方案A 的 `.topicGroundedInRecord`，结构可测）。
- **PII scrubbing**：`broughtInRecords`（方案B）与 `seedEntryBody`（方案A）均经 `CompanionConversationEngine.scrub` outbound 脱敏——**本片修复 S2b-1 遗漏的 `seedEntryBody` 脱敏**；存原文发脱敏、不入日志/DB。
- 披露：included descriptor `.broughtInRecords`（A/B 共用）；`companionConversation(..., hasBroughtInRecords:)`。
