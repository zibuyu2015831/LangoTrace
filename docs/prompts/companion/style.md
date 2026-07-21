# Language Companion Style Injection — Surface Register + i+1 Down-Projection (LM03-S4a)

状态：Active

## 1. 基本信息

- 注入片段：`<<<STYLE … >>>` 受控块 + `.styleGroundedPersona` directive（无独立 Prompt id；并入 `builtin.companion.system.v1`）。
- 所属功能：语伴 Style 受控片段注入（LM03-S4a）——把 LM02-S2 的 surface Style 印记（学习者母语写作的句长 / 词汇丰富度 / 正式度）经 Ability band 的 **i+1 下投影**注入语伴 system prompt：镜像学习者**语域**（正式度），但**复杂度按 band 只读封顶**，不把母语复杂度强加给初学者。
- 调用模块：`CompanionStyleProjection.project(imprint:nativeLanguageCode:band:)`（LangoTraceLearnerModel，纯函数）→ `CompanionStyleDescriptor`（LangoTraceCore，值类型）→ `CompanionPromptRegistry.systemPrompt(styleDescriptor:)`（LangoTraceAI，渲染 `<<<STYLE>>>` 块）→ `CompanionConversationEngine.reply/assembleRequest(styleDescriptor:)` 透传。
- 数据来源：`LearnerStyleProvider.styleImprint()`（系统级 surface 印记，compute-on-read，无 migration）+ `LearnerBandProvider.band(...).estimatedLevel`（**只读** ceiling）。
- App 装配：`AppEnvironment+Companion.swift` send 回合内，gate 开时读 styleImprint + band → project → 传 styleDescriptor。
- 自动化测试：`CompanionStyleProjectionTests`（量化 / ceiling / nil 阈值 / 主子标签匹配）、`CompanionStyleProjectionBandGuardTests`（红线只读）、`CompanionPromptRegistryTests`（`<<<STYLE>>>` 渲染 + directive）、`CompanionConversationEngineTests`（styleDescriptor 透传）、`CompanionConversationProjectionTests`（`.curatedLearnerStyle` 披露）、`RequestPreviewCardTests`（included label）。

## 2. 触发与隐私边界（ADR-006 §6 Style 外发闸；复用 S2b-1 两层 consent，无新 consent 门）

Style 注入是**系统自动注入外发**（受 ADR-006 §6 + 决策 #10），但：

- **复用 S2b-1 两层 consent**：全局首次预览（`CompanionMemoryConsent`）+ per-conversation 开关（`companion_threads.uses_learner_profile`）；`uses_learner_profile` 语义澄清为「使用我的学习者画像（Memory + Style）」，**与 Memory 同一闸、不新增 consent 门**（用户 2026-06-27 决策）。
- **Style 块零原始用户内容**：注入的是**枚举派生的英文类别**（`formal`/`neutral`/`casual`、`concise`/`moderate`/`elaborate`、band CEFR 等级），**非母语原文、非原始指标数值** → PII 远低于 Memory 注入（注入真实生活事实）。**故 Style 块无需 PII scrub**（无可脱敏内容）；最小发送 = 仅语域类别 + ceiling。
- **诚实披露**：新 `AIRequestContentDescriptor.curatedLearnerStyle`（included 类，复用 `.companionConversation` capability，**无新 capability**）；一次性 learner-profile 预览披露 Memory + Style。
- **band 红线**：只读 `band(...)`（仅 SELECT `dictionary_lookup_events`），**绝不触 band 重估写路径 / 解释模式 derive 写路径**；`CompanionStyleProjectionBandGuardTests` 源级 grep + 行为守卫钉死。
- **无新 migration**（复用 `uses_learner_profile`）；surface Style 派生可复算、不持久。

## 3. 行为契约（typed directive + i+1 下投影）

- `CompanionPromptDirective.styleGroundedPersona`：styleDescriptor 非 nil 时插入，使「是否注入 Style」结构可测、非脆弱字符串匹配。
- 注入块以 `<<<STYLE … >>>`（实际渲染为带 `register` / `level` 措辞的引用句）分隔为**引用内容、非指令**（AI-17）；内容为固定枚举派生英文，无用户自由文本拼入 → 无 prompt 注入面。
- **i+1 下投影 v1 mapping**（idea-01 §13.5；§13.9 原 v2 待决，本片定义 v1）：
  - **正式度（formality）= 镜像**：`formalityTendency` double 量化为 casual/neutral/formal，指示语伴匹配该语域。
  - **复杂度（elaboration）= band 封顶**：句长 + 词汇丰富度量化为 concise/moderate/elaborate**倾向描述**，但指示语伴保持在 `complexityCeiling = band.estimatedLevel` 等级，**不超学习者当前目标语水平、不把母语丰富度强加初学者**。band 信号稀疏时其自身回退 seed=`space.level`。
- **evidence 阈值**：`minimumSampleCount`（默认 3）+ qualifying 母语组缺失 → `project` 返回 nil（不注入），避免微样本过拟合。
- 认知风格（cognitive Style）v2（AI 校准、opt-in）仍后置。

## 4. 输入变量与输出契约

- 输入：`CompanionStyleDescriptor { formality, nativeElaboration, complexityCeiling }`（均枚举 / CEFR）；`targetLanguageCode`。
- 输出契约：单段英文引用句注入 system prompt；无结构化返回；不影响 messages 数组。
- 隐私边界：见 §2——零原始内容、复用 consent 门、band 只读、无 scrub 需求、无新 capability / migration / 外发类目。
