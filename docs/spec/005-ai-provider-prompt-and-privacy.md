# 005：AI Provider、Prompt 与隐私规范

状态：Accepted

适用阶段：Prompt 设计、AI Provider 抽象、MVP 早期开发。

## 1. 适用范围

本文档规定语迹 LangoTrace 中 AI Provider、Prompt Preset、请求预览、隐私边界、日志和长期记忆调用的开发规范。

## 2. 当前结论

AI 是语迹的重要能力，但不是产品的唯一中心。AI 应服务于“用生活记录学习语言”的闭环，而不是把 App 变成聊天工具。

所有 AI 能力都必须经过 Provider 抽象和 Prompt Preset 系统。敏感内容是否发送给外部服务必须可理解、可控制、可回溯。

## 3. 强制规则

- UI 不直接调用具体 AI 服务。
- 所有 AI 请求必须经过 Provider 层。
- Prompt Preset 是产品对象，不是散落在代码中的临时字符串。
- 内置 Prompt 和用户自定义 Prompt 必须区分来源。
- API Key 必须保存到 Keychain，不能保存到普通数据库、日志或同步目录。
- 照片、日记、音频、历史记忆和目标语言写作内容只有在用户明确触发相关能力时才发送给 Provider。
- AI 输出不能直接覆盖用户原文。
- AI 请求日志不能默认记录完整日记、完整照片识别文本、API Key 或密钥。
- 长期记忆上下文不能默认无限量发送给 Provider。
- 向量索引是可重建派生数据，默认不同步。
- Provider 请求必须能表达失败、取消、超时和配额限制，不允许只返回裸字符串。
- 结构化输出必须经过解析和校验，不能默认信任模型返回格式。
- 用户自定义 Prompt Preset 不能获得绕过隐私边界的特殊权限。

## 4. 默认推荐

### 4.1 Provider 类型

推荐保留以下抽象：

```text
TextGenerationProvider
EmbeddingProvider
TTSProvider
OCRProvider
ImageUnderstandingProvider
SpeechRecognitionProvider
```

第一阶段可以先实现协议、配置模型和 Mock Provider，不急于接入真实外部服务。

### 4.2 Prompt Preset

Prompt Preset 建议包含：

- ID。
- 名称。
- 描述。
- 任务类型。
- system prompt。
- 适用目标语言。
- 适用学习水平。
- 输出格式。
- 是否逐句对照。
- 是否提取词句。
- 是否允许使用长期记忆上下文。
- 版本号。
- 来源：内置或用户自定义。
- 是否需要请求预览。
- 是否允许附带附件摘要。
- 是否允许附带长期记忆片段。

任务类型建议至少区分：

- 母语记录转目标语言。
- 目标语言写作检查。
- 最小纠错。
- 自然润色。
- 词句提取。
- 错误模式提取。
- 照片写作引导。

### 4.3 请求预览

请求预览应让用户理解：

- 即将发送的内容类型。
- 是否包含照片、日记原文、目标语言文本或历史记忆。
- 使用哪个 Provider。
- 使用哪个模型或服务能力。
- 是否会保存请求元数据。

普通用户看到简洁说明，高级用户可以展开查看更细配置。

建议把请求分为三种同意级别：

- 低风险：只发送当前用户主动输入的短文本。
- 中风险：发送完整记录、目标语言写作或 OCR 识别文本。
- 高风险：发送照片内容、音频转写、长期记忆片段或多条历史记录。

中高风险请求应提供更明确的预览和确认。用户已经在当前动作中明确选择“用 AI 分析照片”“检查这篇文章”等场景时，可以使用简洁确认，但仍应保持可理解。

### 4.4 日志与元数据

可以记录：

- Provider 类型。
- 模型名。
- 请求时间。
- 耗时。
- 成功或失败状态。
- 错误码。
- Prompt Preset ID 和版本。

默认不记录：

- API Key。
- 完整请求头。
- 完整日记原文。
- 完整 AI 请求体。
- 完整照片 OCR 结果。
- 对象存储密钥。

### 4.5 输出保存边界

AI 输出应保存为新对象或新版本，而不是覆盖用户输入。

推荐关联：

- 母语转目标语言：保存为 Rendering。
- 逐句对照：保存为 SentencePair 或 Rendering 的结构化子对象。
- 写作检查：保存修改建议、修改后版本和错误解释。
- 词句提取：保存为候选 MemoryItem，用户确认后进入正式记忆。
- 错误模式提取：保存为可复习或可统计的派生学习记忆。

### 4.6 失败处理

Provider 调用失败时应区分：

- 未配置 Provider。
- API Key 无效。
- 网络不可用。
- 请求超时。
- 模型不支持当前能力。
- 内容过长。
- 返回格式无法解析。
- 用户取消。

UI 可用简洁文案展示，但服务层应保留可诊断错误类型。

### 4.7 Provider 配置页边界

Provider 配置页已经从真实级 mock 表单进入本地配置保存和配置合成测试阶段：非敏感 Provider profile、endpoint、credential metadata 和 validation event 进入 SQLite / GRDB，API Key 写入 Keychain；测试请求可以通过 Provider 层对文本 endpoint 发送固定文本、JSON、当前语言空间上下文下的语言支持和可选内置图片合成探测。

真实文本 Entry 的一键学习材料生成已在 iOS / iPhone 记录详情接入：用户点击 `生成学习材料` 时，App Shell 通过 `LearningMaterialGenerationActions` 读取默认文本 endpoint、解析 Keychain secret、调用 `LearningMaterialGenerationService`，并将 LearningMaterial、analysis、candidate 和 operation 摘要写入 GRDB。该能力第一版只发送当前 Entry 文本或用户编辑后的当前 learning text，不发送照片、音频、OCR、附件摘要、历史记忆或多条 Entry 上下文；iPad / macOS UI 入口待 iOS 人工测试通过后再接入。后续实现必须遵守以下边界：

- API Key 输入只能作为当前页面的短生命周期明文草稿。保存成功后应清空本次新输入草稿；用户主动再次打开 Provider 配置页时，可以通过服务边界从 Keychain 解析已保存密钥并回填到输入框，默认仍以隐藏态展示。该回填只允许存在于当前 UI draft，不得写入 SQLite、诊断日志、同步目录、请求预览或测试输出。
- 非敏感配置和敏感凭证必须分层。Provider、Base URL、模型名属于普通表单配置；请求格式、认证方式和自定义请求头等技术信息应默认收起或进入高级配置，不应挤占首屏主路径。API Key、外部服务 token、自定义请求头中的密钥属于敏感凭证。
- 敏感凭证必须保存到本机 Keychain 或等价安全存储。SQLite 只能保存 credential metadata、Keychain service / account 引用、最近观测到的 secret presence 和非敏感验证事件；不得保存明文、可解密密文、hash、尾号或完整请求头值。
- 已保存配置的后续本地验证和未来真实 AI 请求必须由服务层通过 Keychain 引用解析密钥；不得要求用户每次请求前重新输入、暴露或预览密钥。
- Keychain item 默认不跨设备同步；数据库恢复到新设备但 Keychain 缺失时，应进入 `credential_missing` 或等价可恢复状态，引导用户重新输入密钥。
- Provider 配置页应按模型用途表达 endpoint：文本模型、语音生成模型、向量模型是不同能力边界，不使用“高级模型”统称。
- Provider 和 API Key 属于高频填写项。Provider 应使用一行设置项展示当前选择；API Key 输入必须有明确字段名，并提供显示/隐藏按钮，默认隐藏。面向普通中文用户的主路径文案应使用 `API Key`，避免使用“凭证”等偏工程术语。
- 模型 endpoint 与敏感凭证必须分离。多个 endpoint 可以引用同一份凭证，例如同一 Provider 的文本、语音和向量 endpoint 共用同一个 API Key，但它们的 Base URL、adapter、请求格式和模型名仍应独立配置。
- 当不同能力选择不同 Provider 时，默认使用独立凭证，避免跨 Provider 误用 API Key。只有用户明确选择共享凭证时，才允许 endpoint 引用文本模型凭证。
- 图片理解是文本模型 endpoint 的模型级输入能力开关。默认关闭，只有用户显式启用后，后续图片理解请求才可使用该能力。UI 可用性必须由 Provider preset、adapter 请求格式、endpoint purpose、模型能力策略和用户授权共同解析，不得只由 Provider preset 的静态布尔值决定。
- iPhone、iPad 和 macOS 的 Provider 设置页应共享同一字段语义和表单组件。平台差异只允许体现在承载宽度、导航位置、输入密度和窗口行为上；不得为 iPad 或 macOS 复制一套字段模型，避免重新出现旧术语、旧能力分组或未标注 API Key 输入。
- iPad / macOS 工作台中的 Provider 设置详情应使用合理最大内容宽度保持阅读栏；该宽度是视觉承载约束，不得写入 Provider 配置模型、Repository、同步协议或安全存储模型。
- macOS 原生 Settings scene 和工作台 Settings section 是两个入口层。当前原生 Settings scene 只展示能力状态列表，不承载 Provider 写入表单；后续若要在原生 Settings scene 支持 Provider 配置，必须复用同一配置模块并单独审查写入边界。
- “测试请求”按钮必须走明确状态机，并通过 `AIProviderSettingsActions` 进入 AI service / Provider 层；SwiftUI View 不得直接创建 `URLRequest`、拼接 Authorization header、读取 Keychain 或调用 Provider SDK。
- 当前阶段测试请求只允许对文本模型 endpoint 发送固定合成检测内容，分为文本回复 probe、JSON 输出 probe、语言支持 probe 和可选图片理解 probe；JSON probe 只描述一个名为 `ok`、值为布尔 `true` 的字段结构，由模型生成严格 JSON object，验收仍只接受 exactly one field `ok: true`。语言支持 probe 只在调用方提供稳定目标语言 code 时运行，Prompt 中的目标语言英文名称、`NLLanguage` 映射和脚本规则必须由 AI 层 allowlist 派生；它要求模型返回包含 `sample` 字段的 JSON object，本机从常见 Markdown code fence 中提取 JSON，忽略 `sample` 之外的额外字段，并做非空、长度、离线语言识别和脚本规则校验。语言支持不得发送生活记录、用户照片、音频、OCR、历史记忆、目标语言正文、Prompt Preset 内容、用户自定义长文本或请求预览正文；失败只表示本次合成测试未能确认当前模型适合该语言空间，不是模型语言能力认证。图片理解 probe 只在当前 adapter 已支持图片请求体、endpoint purpose 为文本生成、能力策略允许或由模型决定、且用户显式启用图片输入后运行，并只发送项目内置白底蓝色正方形 PNG，用于验证图片输入链路、基础视觉属性识别和受控短标签输出；它不得发送用户照片、生活记录附件、OCR 文本、历史记忆、目标语言正文、Prompt Preset 内容、用户自定义长文本或请求预览正文，也不代表真实照片理解质量评分。
- 一键学习材料生成不是 Provider 配置测试。它允许发送当前文本 Entry 或当前 learning text，前提是用户在记录详情主动点击 `生成学习材料` 或 `重新分析`。保存 Entry 的本机写入动作不得自动触发 AI 请求，也不得让用户误以为保存已经上传。
- 一键学习材料生成第一版采用非阻断确认：不弹出请求预览确认 sheet，但按钮附近、生成中状态和结果元数据必须明确表达当前文本会发送给已配置的 AI Provider，结果由 AI 生成，并展示非敏感 Prompt / Provider / model 元数据。照片、音频、OCR、历史记忆、多条 Entry 上下文或附件摘要不得复用该低摩擦边界。
- 学习材料 Prompt 必须由 `docs/prompts/learning-material/one-tap-learning-material.md` 和 `LearningMaterialPromptRegistry` 登记版本；修改 Prompt id、version、输入变量、schema version 或输出字段时，必须同步更新 Prompt Registry 文档、AI service 测试和 Data 映射测试。
- 学习材料响应必须是结构化 JSON object。AI service 必须拒绝 Markdown code fence、自然语言前后缀、缺字段、非法枚举、数组超限或无法映射的结构，不得把半成品结果写入 Data 层。
- 学习材料请求和 operation 摘要只允许记录 operation id、Prompt id / version、Provider profile / endpoint / preset、model、长度分桶、input kind、失败分类、耗时和时间戳等非敏感元数据；不得记录用户原文、learning text、sentence / candidate 正文、完整 Prompt、请求体、响应体、API Key、Authorization header 或完整 Keychain account。
- 语音生成和向量化可以出现在结果面板的分能力状态中，但当前阶段不得为这些能力发真实网络测试请求；应显示未启用、未配置或暂不支持测试。
- iPhone、iPad 和 macOS Provider 设置页当前都通过共享 `SettingsCapabilityDetailView` 从当前语言空间传入目标语言 code 并展示 `语言支持` 分项。平台差异只允许体现在承载宽度、导航位置和 presentation 行为；不得为 iPad 或 macOS 复制平台专属 Provider 表单，也不得让任一平台绕过共享 action seam。
- 未保存 draft 测试必须测试当前屏幕配置，且不得先写入 Keychain、SQLite 或 validation event；已保存且无修改的配置测试由服务层通过 Keychain 引用重新解析密钥。
- 已保存 profile 的 App 级合成测试可以记录 `synthetic_test` 类型的非敏感 validation event，并在同一 Data 事务内更新最近验证摘要；语言支持结果是语言空间上下文下的适配性提示，不得把 language support 失败写成 Provider profile 全局最近验证失败，也不得写入 Provider profile 静态能力事实。draft 测试只允许记录非敏感 diagnostic event，不得污染持久 profile 事实。取消的测试不得写失败 validation event。
- 本地配置验证可以记录 `credential_validation` 类型的非敏感 validation event；合成测试可以记录 `synthetic_test`。允许字段包括 provider、model、endpoint purpose、状态、错误分类、耗时、operation id 和 allowlisted target language code；不得记录请求体、响应体、语言支持 `sample` 原文、API Key、完整 Keychain account、完整请求头、Base URL query 中的敏感参数或用户内容。
- OpenAI Responses 和 OpenAI-compatible Chat 是第一阶段真实文本和内置图片合成测试范围；Anthropic / Gemini 第一阶段应返回明确暂不支持测试，不得误映射为认证失败或网络失败。Provider preset 不能作为模型级图片输入能力的最终事实源；OpenRouter 和 Custom OpenAI-compatible 等兼容层应表达为 model-dependent，允许用户显式开启并由真实 probe 验证。`supportsImageInput` 只作为 endpoint 运行期防线和保存快照，不表示模型已被验证支持图片理解；真实可用性以 probe result 为准。
- Provider preset 不能默认声明所有能力都可用。Chat、Embedding、TTS、图片理解、语音识别和自定义请求头需要分别表达支持状态。
- 聚合服务或兼容层的路由提示应只在用户选择该类 Provider 或进入高级信息时出现，避免把所有 Provider 的技术风险说明长期展示在普通设置主路径。

Provider 配置保存链路必须记录可诊断但非敏感的阶段状态：

- UI 层记录保存点击、输入无效、服务调用开始、保存成功和保存失败。输入无效不得被归类为真实保存失败。
- AI service 层记录 Keychain 写入、数据库写入、补偿清理和整体保存结果。事件之间用 operation id 关联，不记录 API Key、请求头、完整 Keychain account、明文 base URL query、用户生活内容或 Prompt 内容。
- 保存失败应区分 `input_validation`、`keychain_write`、`database_write`、`credential_cleanup` 和 `unknown` 等阶段，并提供稳定错误分类给 UI 与诊断日志。
- SQLite 写入失败后必须尝试清理本次新建 Keychain item；清理也失败时，业务错误仍以原始数据库写入失败为主，清理失败只进入非敏感诊断。
- 诊断日志默认不开启产品期持久写入。开发期开启控制必须位于 App Shell 或等价装配层，Core、Data、AI 和 UI package 不直接读取环境变量。

## 5. 可演进部分

- 是否提供官方托管 AI。
- 是否提供推荐 Provider 模板。
- 是否支持本地模型。
- 是否支持高级 Prompt 调试模式。
- 是否支持 Prompt Preset 导入导出。
- 是否允许跨设备同步用户自定义 Prompt Preset。
- 是否保存可重放的 AI 生成配置。
- 是否为不同任务定义严格 JSON Schema。
- 是否引入本地内容脱敏或敏感词提示。

这些变化如果影响隐私、商业模式或默认数据边界，应更新 ADR。

## 6. 反例

不应这样做：

- 在某个页面中直接写死 OpenAI 请求。
- 把 system prompt 写在按钮 action 里。
- 默认把用户所有历史记录塞进 AI 上下文。
- 用户只是打开照片详情时就自动上传照片分析。
- 把 API Key 存进普通配置文件或对象存储同步目录。
- 为了调试方便，把完整 AI 请求体写进日志。

## 7. AI 开发提示

AI 在实现任何 AI 能力前应先确认：

- 这是哪种任务类型？
- 使用哪个 Prompt Preset？
- 是否需要请求预览？
- 是否会发送用户日记、照片、音频、历史记忆或目标语言写作？
- 是否需要记录请求元数据？
- 是否需要把结果关联到 Entry、Rendering、SentencePair、MemoryItem 或 PracticeSession？
- 输出是否需要结构化解析和校验？
- 失败、取消、超时和返回格式错误如何处理？

如果答案不明确，应先补设计文档或规范，不应直接实现请求。

## 8. 变更记录

- 2026-05-23：补充一键学习材料生成真实请求边界。原因：iOS / iPhone 记录详情已接入当前文本 Entry 的真实 Provider 请求、结构化 Prompt、GRDB 结果保存和非阻断 AI 披露，需要把“真实学习内容请求未接入”的旧边界更新为当前实现事实。影响范围：LangoTraceAI、LangoTraceData、LangoTraceUI、AppEnvironment、Prompt Registry 和页面清单。是否需要 ADR：否，沿用 ADR-005；照片、音频、历史记忆和多 Entry 上下文仍需单独方案。
- 2026-05-17：创建第一版 AI Provider、Prompt 与隐私规范。
- 2026-05-17：补充同意级别、结构化输出校验、输出保存边界和失败处理分类。原因：降低 AI 请求隐私、可靠性和数据覆盖风险。影响范围：AI Provider、Prompt、UI 请求预览、数据保存。是否需要 ADR：否。
- 2026-05-19：补充 Provider 配置页边界。原因：AI Provider 设置页开始从静态说明改为真实级 mock 配置页，需要把安全配置草稿、保存配置、测试请求、能力矩阵和聚合 provider 提示沉淀为长期约束。影响范围：AI Provider 设置、隐私文案、后续 Keychain 和真实请求测试。是否需要 ADR：否。
- 2026-05-19：补充 Provider 配置页信息降噪规则。原因：iOS 页面需要真实设置表单质感，Provider 风险说明、请求格式、认证方式和 mock 边界不应全部暴露在主路径。影响范围：AI Provider 设置 UI、后续高级配置入口。是否需要 ADR：否。
- 2026-05-19：补充多模型 endpoint 与凭证引用规则。原因：同一 Provider 可能共用 API Key 但使用不同 endpoint/model，三类能力也可能使用不同 Provider。影响范围：AI Provider 设置 UI、后续 Keychain item 引用、TTS 和向量化配置。是否需要 ADR：否。
- 2026-05-19：补充 Provider 和 API Key 表单可用性规则。原因：API Key 输入需要明确字段名和可见性控制，中文主路径应避免“凭证”等偏工程术语。影响范围：AI Provider 设置 UI、本地化文案、后续安全存储表单。是否需要 ADR：否。
- 2026-05-19：补充三端 Provider 设置页共享与大屏承载规则。原因：iPad / macOS 工作台详情需要保持与 iPhone 相同字段语义，同时避免把 iPhone 表单横向拉满大屏。影响范围：AI Provider 设置 UI、SettingsCapabilityDetailView、macOS Settings scene 边界。是否需要 ADR：否。
- 2026-05-20：更新 Provider 配置页从 mock 到本地配置保存阶段的事实边界。原因：AI Provider profile、endpoint、credential metadata、Keychain 保存和本地 credential validation 已落地，真实外部 Provider 合成探测仍未接入。影响范围：AI Provider 设置、Keychain、Data repository、validation event、后续真实 AI 请求。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-20：补充 Provider 配置保存诊断规则。原因：保存链路已经跨 UI、AI service、Keychain、SQLite 和补偿清理，需要稳定 operation id、阶段分类、非敏感日志字段和默认关闭边界。影响范围：AI Provider 设置、诊断日志、Data repository、Testing 和 App Shell 装配。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-20：调整已保存 API Key 回显边界。原因：用户完成配置后再次进入配置页，需要能查看和编辑当前本机保存的 API Key；回显仅允许通过服务边界解析 Keychain 并进入短生命周期 UI draft，默认隐藏，不进入数据库、日志、同步或请求预览。影响范围：AI Provider 设置 UI、Keychain resolver action、SwiftUI draft 状态。是否需要 ADR：否，仍符合 ADR-005 的本地优先和用户自带 Provider 边界。
- 2026-05-21：更新 Provider 配置测试请求边界。原因：文本模型合成探测已接入 Provider 层，测试请求从本地 credential validation 扩展为固定合成网络 probe；需要沉淀 draft / saved profile 分流、`synthetic_test` validation event、分能力结果面板和非敏感诊断边界。影响范围：AI Provider 设置、LangoTraceAI、LangoTraceData、LangoTraceUI、诊断日志和后续真实学习请求。是否需要 ADR：否，沿用 ADR-005；真实学习内容请求仍需单独请求预览方案。
- 2026-05-21：补充图片理解合成 probe 边界。原因：Provider 配置测试请求从文本 / JSON 扩展为用户显式启用后的内置图片 probe，需要明确不发送用户照片、adapter 支持范围、Prompt Registry 登记和非敏感日志约束。影响范围：AI Provider 设置、LangoTraceAI、Prompt Registry、诊断日志和后续真实图片理解请求。是否需要 ADR：否，沿用 ADR-005；真实用户照片请求仍需单独请求预览方案。
- 2026-05-22：补充语言支持合成 probe 边界。原因：Provider 配置测试请求新增当前语言空间上下文下的 `语言支持` 分项，需要明确 target language code allowlist、Prompt Registry、离线校验、非认证性质、profile 全局验证摘要隔离和 `sample` 原文不落日志边界。影响范围：AI Provider 设置、LangoTraceAI、LangoTraceUI、Prompt Registry、诊断日志和后续真实学习请求。是否需要 ADR：否，沿用 ADR-005；真实学习内容请求仍需单独请求预览方案。
- 2026-05-22：补充 iPad / macOS 语言支持入口事实。原因：iOS 人工审核后，iPad / macOS 通过共享 `SettingsCapabilityDetailView` 接入同一 language context，不改变 Provider 保存、Keychain、网络、Prompt、日志或持久验证摘要边界。影响范围：AI Provider 设置 UI、SettingsCapabilityDetailView、页面清单。是否需要 ADR：否。
