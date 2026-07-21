# Language Companion System Prompt

状态：Active

## 1. 基本信息

- Prompt id：`builtin.companion.system.v1`
- Prompt version：`1`
- 所属功能：语伴（Language Companion）MVP 单线程文本对话引擎（LM03-S1）。
- 调用模块：`CompanionPromptRegistry`、`CompanionConversationEngine`。
- 代码位置：`Packages/LangoTraceAI/Sources/LangoTraceAI/CompanionPromptRegistry.swift`。
- 自动化测试：`Packages/LangoTraceAI/Tests/LangoTraceAITests/Companion/CompanionPromptRegistryTests.swift`、`CompanionConversationEngineTests.swift`。

## 2. 触发与隐私边界

仅在用户已在设置中手动开启语伴（默认关闭，ADR-008 §2.6）、并在语伴会话中**显式发送消息**时才发起请求；打开页面（通用入口）显示的首条问候是 App 内**本地模板**，零外发。记录详情「围绕这条记录对话」是用户**显式带入单条 Entry**（方案 A，决策 #10 明示触发）。

S1 **零系统自动注入**：请求 system 段只允许包含——

- 固定人设模板 + 三枚举（语气 / 正式度 / 纠错倾向）映射的受控片段（无用户自由文本）。
- 目标语言 code、母语 code、静态水平 `LanguageLevel`（来自 `LanguageSpace.level`）。
- 方案 A 时：用户显式带入的**单条** Entry 正文（以分隔符包裹为引用内容，非指令）。

请求**不得**包含：Memory 生活事实、Style 受控片段、完整记录库、FTS 检索结果、其他 Entry、照片、音频、OCR、API Key、Authorization header、本地路径。（Memory 注入 + PII scrubbing = LM03-S2，本片不做。）

日志 / operation metadata 只允许保存 Prompt id / version、Provider / endpoint / model 非敏感元数据、长度分桶、消息条数、状态、失败分类、耗时（经 `AIChatRequestProjectionMetadata`）；不得保存 system 全文、消息正文、完整请求 / 响应体。

## 3. 行为契约（typed directives）

`CompanionRenderedPrompt.directives` 以结构化集合声明（便于结构化验证，非脆弱字符串匹配）：

- `alwaysReplyTargetLanguage`（ADR-008 §2.1）：主回复**永远**用目标语，即使用户用母语发言。
- `ambiguityRealisticConfirm`（idea-03 §3.4）：输入过于模糊时，像真人一样确认 / 重述，不报错、不内联纠正。
- `difficultyResponsiveLayer`（idea-03 §3.9）：每轮读信号、自然调整难度，**不宣布**难度变化。
- `practicePartnerNotAssistant`（ADR-008 §2.5）：语言练习对象，不承接无关开放任务。
- `topicGroundedInRecord`（仅方案 A）：以带入记录为话题。
- `correctionPolicy(...)`：随人设纠错倾向枚举。**温和复述 opt-in（LM03-S3a）**：纠错档 = 既有 `CompanionCorrection` 闭集（`.ifNeeded` 默认 / `.warmRecast` 温和复述 / `.none`）；S3a 仅把 `.warmRecast` 暴露为用户 toggle（默认仍 `.ifNeeded` 关），其 directive `correctionPolicy(.warmRecast)` + 受控片段文本（"naturally restate the correct form …"）早已映射，开后自然生效——不引入任何自由文本，AI-17 边界不变。纠错档是 per-space persona（`conversation_companions`），toggle 经 App read-modify-write 仅改 correction、保 tone/formality。

## 4. 注入加固

用户**不可**编写 / 查看 system prompt；可调部分仅三枚举，经固定映射为受控片段（AI-17 加固）。方案 A 的 Entry 正文以 `<<<RECORD … RECORD>>>` 分隔包裹，声明为引用内容、非指令位。v1 不开放任何自由文本人设字段（含昵称）。
