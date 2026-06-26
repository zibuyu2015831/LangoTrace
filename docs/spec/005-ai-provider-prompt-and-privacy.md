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
- 阅读选区解释只有在用户显式点击阅读页中的解释动作时才发送给 Provider；导入、打开、滚动、选中正文、删除 / 恢复资料或播放 TTS 都不得自动触发 AI。
- 照片写作 AI 看图辅助写作只有在用户显式点击「让 AI 看图帮我写」并经发送前确认时才发送照片给 Provider；选取照片、滚动、写正文、保存记录或进入详情都不得自动触发。发送的图片必须是经脱敏降采样（剥离 EXIF/GPS）的产物，不得发送原图或原始相册字节。`photoAttachments` 不再是全局 always-excluded：它**仅**对 `photoWritingAssist` 能力 included，对其余所有 AI 能力仍保持排除。
- AI 输出不能直接覆盖用户原文。
- AI 请求日志不能默认记录完整日记、完整照片识别文本、API Key 或密钥。
- 长期记忆上下文不能默认无限量发送给 Provider。
- 向量索引是可重建派生数据，默认不同步。
- Provider 请求必须能表达失败、取消、超时和配额限制，不允许只返回裸字符串。
- 多轮对话与文本流式请求必须经 Provider 流式 seam（`AIChatStreamingService` → `AsyncThrowingStream`），同样表达失败 / 取消 / 超时 / 配额，并在流式累积下保留响应体积上限拦截。多轮请求的投影元数据（preset / model / 体积分桶 / 消息条数）不得携带消息正文、system persona 或密钥；对话级日志的实际写入由调用方在请求终止后接线（沿用 §4.4 的 App-Shell recorder 依赖方向）。
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

阅读 selection explanation 允许记录 Prompt id / version、schema version、Provider / endpoint / model 非敏感元数据、selection 长度分桶、失败分类和耗时；不得记录完整 selection、完整句子、完整上下文、完整请求体或完整响应体。

默认不记录：

- API Key。
- 完整请求头。
- 完整日记原文。
- 完整 AI 请求体。
- 完整照片 OCR 结果。
- 对象存储密钥。

### 4.5 输出保存边界

AI 输出应保存为新对象或新版本，而不是覆盖用户输入。

阅读选区解释输出属于当前 selection 的派生学习结果。当前纵向切片将解释结果保留为短生命周期 UI 状态，并把请求状态写入 `reading_ai_explanation_operations` 非敏感 operation 摘要；后续若持久化解释正文，必须写入 reading AI result 表或等价派生对象，不能覆盖 `reading_documents.body`，也不能把解释结果混入用户原文。

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

真实文本 Entry 的一键学习材料生成已通过共享 `EntryDetailView` 接入 iPhone / iPad / macOS 记录详情：用户点击 `生成学习材料` 时，App Shell 通过 `LearningMaterialGenerationActions` / `LearningContentStore` 读取默认文本 endpoint、解析 Keychain secret、调用 `LearningMaterialGenerationService`，并将 LearningMaterial、analysis、candidate 和 operation 摘要写入 GRDB。该能力第一版只发送当前 Entry 文本或用户编辑后的当前 learning text，不发送照片、音频、OCR、附件摘要、历史记忆或多条 Entry 上下文；三端平台差异只体现在承载位置和布局，不分叉 AI 请求、Prompt、Keychain 或 Data 写入路径。后续实现必须遵守以下边界：

- API Key 输入只能作为当前页面的短生命周期明文草稿。保存成功后应清空本次新输入草稿；用户再次打开 Provider 配置页时，不得自动解析 Keychain 或回填明文。已有密钥时字段应以 placeholder 表达 `已保存到本机 Keychain`；只有用户点击字段右侧显示 / 隐藏按钮、触发配置测试或执行真实 AI 请求时，才允许通过服务边界解析 Keychain。用户显式查看成功后的明文只允许存在于当前 UI draft，不得写入 SQLite、诊断日志、同步目录、请求预览或测试输出。
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
- 当前阶段测试请求允许对文本模型 endpoint 发送固定合成检测内容，分为文本回复 probe、JSON 输出 probe、语言支持 probe 和可选图片理解 probe；JSON probe 只描述一个名为 `ok`、值为布尔 `true` 的字段结构，由模型生成严格 JSON object，验收仍只接受 exactly one field `ok: true`。语言支持 probe 只在调用方提供稳定目标语言 code 时运行，Prompt 中的目标语言英文名称、`NLLanguage` 映射和脚本规则必须由 AI 层 allowlist 派生；它要求模型返回包含 `sample` 字段的 JSON object，本机从常见 Markdown code fence 中提取 JSON，忽略 `sample` 之外的额外字段，并做非空、长度、离线语言识别和脚本规则校验。语言支持不得发送生活记录、用户照片、音频、OCR、历史记忆、目标语言正文、Prompt Preset 内容、用户自定义长文本或请求预览正文；失败只表示本次合成测试未能确认当前模型适合该语言空间，不是模型语言能力认证。图片理解 probe 只在当前 adapter 已支持图片请求体、endpoint purpose 为文本生成、能力策略允许或由模型决定、且用户显式启用图片输入后运行，并只发送项目内置白底蓝色正方形 PNG，用于验证图片输入链路、基础视觉属性识别和受控短标签输出；它不得发送用户照片、生活记录附件、OCR 文本、历史记忆、目标语言正文、Prompt Preset 内容、用户自定义长文本或请求预览正文，也不代表真实照片理解质量评分。向量化 probe 第一阶段只在用户显式启用且配置完整的 OpenAI、OpenRouter 或 Custom OpenAI-compatible 向量 endpoint 上运行，发送固定低敏文本 `LangoTrace embedding configuration test.` 到 `/embeddings`，只验证 `data[0].embedding` 是否为非空数字数组；不得发送用户内容，不得保存 vector、完整响应体、usage 细节或请求体。
- 一键学习材料生成不是 Provider 配置测试。它允许发送当前文本 Entry 或当前 learning text，前提是用户在记录详情主动点击 `生成学习材料` 或 `重新分析`。保存 Entry 的本机写入动作不得自动触发 AI 请求，也不得让用户误以为保存已经上传。
- 一键学习材料生成第一版采用非阻断确认：不弹出请求预览确认 sheet，但按钮附近、生成中状态和结果元数据必须明确表达当前文本会发送给已配置的 AI Provider，结果由 AI 生成，并展示非敏感 Prompt / Provider / model 元数据。照片、音频、OCR、历史记忆、多条 Entry 上下文或附件摘要不得复用该低摩擦边界。
- 学习材料 Prompt 必须由 `docs/prompts/learning-material/one-tap-learning-material.md` 和 `LearningMaterialPromptRegistry` 登记版本；修改 Prompt id、version、输入变量、schema version 或输出字段时，必须同步更新 Prompt Registry 文档、AI service 测试和 Data 映射测试。
- 学习材料响应必须是结构化 JSON object。Prompt 和 Provider 原生 JSON Schema 均必须要求纯 JSON；AI service 解析层可以为兼容 OpenAI-compatible Provider 的实际行为剥离包裹整个 JSON object 的常见 Markdown code fence，但剥离后仍必须执行同一 JSON schema / 字段级校验。自然语言前后缀、缺字段、非法枚举、额外不允许字段、数组超限或无法映射的结构必须拒绝，不得把半成品结果写入 Data 层。
- 学习材料请求和 operation 摘要只允许记录 operation id、Prompt id / version、Provider profile / endpoint / preset、model、长度分桶、input kind、失败分类、耗时和时间戳等非敏感元数据；不得记录用户原文、learning text、sentence / candidate 正文、完整 Prompt、请求体、响应体、API Key、Authorization header 或完整 Keychain account。
- 语音生成和向量化可以出现在结果面板的分能力状态中。语音生成在 `011-tts-provider-configuration-and-playback.md` 约束下允许使用固定低敏测试句进行真实 TTS probe；向量化第一阶段允许 OpenAI、OpenRouter 和 Custom OpenAI-compatible 使用固定低敏文本进行真实 embeddings probe。两者都必须保持 endpoint metadata、endpoint / voice validation 状态和文本模型 profile 全局验证摘要隔离。
- AI Provider 配置是系统级设置，不属于某一个语言空间；设置详情只保留导航标题，不在内容区重复显示 `AI Provider` 或当前语言空间方向 / 等级。iPhone、iPad 和 macOS Provider 设置页当前都通过共享 `SettingsCapabilityDetailView` 从当前语言空间传入目标语言 code，并在测试结果中展示 `语言支持` 分项；该 language context 只用于低敏合成 probe、voice profile 读取和适配性提示，不作为页面归属、Provider profile 静态事实或同步边界。平台差异只允许体现在承载宽度、导航位置和 presentation 行为；不得为 iPad 或 macOS 复制平台专属 Provider 表单，也不得让任一平台绕过共享 action seam。
- 未保存 draft 测试必须测试当前屏幕配置，且不得先写入 Keychain、SQLite 或 validation event；已保存且无修改的配置测试由服务层通过 Keychain 引用重新解析密钥。
- 已保存 profile 的 App 级合成测试可以记录 `synthetic_test` 类型的非敏感 validation event，并在同一 Data 事务内更新最近验证摘要；语言支持结果是语言空间上下文下的适配性提示，不得把 language support 失败写成 Provider profile 全局最近验证失败，也不得写入 Provider profile 静态能力事实。draft 测试只允许记录非敏感 diagnostic event，不得污染持久 profile 事实。取消的测试不得写失败 validation event。
- 本地配置验证可以记录 `credential_validation` 类型的非敏感 validation event；合成测试可以记录 `synthetic_test`。允许字段包括 provider、model、endpoint purpose、状态、错误分类、耗时、operation id 和 allowlisted target language code；不得记录请求体、响应体、语言支持 `sample` 原文、API Key、完整 Keychain account、完整请求头、Base URL query 中的敏感参数或用户内容。
- OpenAI Responses 和 OpenAI-compatible Chat 是第一阶段真实文本、内置图片合成测试和 OpenAI-like embeddings 配置测试范围；**Anthropic Messages 自 LM03-S4b（2026-06-27）起支持文本 + 尽力而为结构化 JSON 探针**（`x-api-key`+`anthropic-version` 鉴权、`content[].text` 解析），其图片 / TTS / embedding 探针与 Gemini 全部探针仍返回明确暂不支持测试，不得误映射为认证失败或网络失败。Provider preset 不能作为模型级图片输入能力或向量能力的最终事实源；OpenRouter 和 Custom OpenAI-compatible 等兼容层应表达为 model-dependent，允许用户显式开启并由真实 probe 验证。`supportsImageInput` 只作为 endpoint 运行期防线和保存快照，不表示模型已被验证支持图片理解；embedding 可用性也以 endpoint scoped probe result 为准。
- Provider preset 不能默认声明所有能力都可用。Chat、Embedding、TTS、图片理解、语音识别和自定义请求头需要分别表达支持状态。
- 聚合服务或兼容层的路由提示应只在用户选择该类 Provider 或进入高级信息时出现，避免把所有 Provider 的技术风险说明长期展示在普通设置主路径。

Provider 配置保存链路必须记录可诊断但非敏感的阶段状态：

- UI 层记录保存点击、输入无效、服务调用开始、保存成功和保存失败。输入无效不得被归类为真实保存失败。
- AI service 层记录 Keychain 写入、数据库写入、补偿清理和整体保存结果。事件之间用 operation id 关联，不记录 API Key、请求头、完整 Keychain account、明文 base URL query、用户生活内容或 Prompt 内容。
- 保存失败应区分 `input_validation`、`keychain_write`、`database_write`、`credential_cleanup` 和 `unknown` 等阶段，并提供稳定错误分类给 UI 与诊断日志。
- SQLite 写入失败后必须尝试清理本次新建 Keychain item；清理也失败时，业务错误仍以原始数据库写入失败为主，清理失败只进入非敏感诊断。
- 诊断日志默认不开启产品期持久写入。开发期开启控制必须位于 App Shell 或等价装配层，Core、Data、AI 和 UI package 不直接读取环境变量。

### 4.8 照片写作 AI 看图辅助写作边界

照片写作页的「让 AI 看图帮我写」是当前实现中**第一个**把照片内容发送给 Provider 的能力，遵循以下边界：

- **显式触发**：仅在用户选好照片后点击该动作并经发送前确认时才发送（核心决策 #10）；选取、滚动、写正文、保存、进入详情都不触发。照片写作页不常驻隐私提示横幅，**发送前确认弹窗是披露发送范围（照片 + 备注，不发送其它内容）的唯一界面**，保证披露与实际发送动作原子绑定。
- **脱敏图片**：发送的图片经 `AIImageSanitizer` 降采样到受控边长（max edge 1024）+ 再次剥离 EXIF/GPS 后再 base64；不发原图、不复用 256px 列表缩略图、不发原始相册字节。脱敏是单一执行入口，UI 不得把原始 PhotosPicker 字节直接交给请求层。
- **能力专属投影**：新增 `AIRequestCapability.photoWritingAssist`，其请求预览投影是唯一在 `includedContent` 中含 `photoAttachments` 的能力。`photoAttachments` 不再是全局 always-excluded——对其余所有 AI 能力（学习材料生成 / 分析、阅读解释、回译点评）仍保持排除；该不变量由 Core 回归测试锁定。
- **适配范围**：仅 OpenAI 兼容 Chat / Responses，需用户已为该 endpoint 启用图片输入（`imageInputEnabled`）。门控顺序 `supportsImageInput → imageInputEnabled → adapter allowlist`，与配置图片 probe 共用同一 allowlist 防漂移。mimo / Anthropic / Gemini 返回明确 `unsupportedProvider`。
- **两种产出模式**：写作提示 / 母语草稿，单 Prompt + `mode` 切换，各对应一份严格 JSON schema（见 Prompt Registry）。产出非破坏性，显式「采用」才追加到写作框。
- **日志**：经 `ai_request_logs`（capability=`photoWritingAssist`）记非敏感字段；照片、备注、产出正文均不入日志、不持久化。专用 `photo_writing_assist_operations` 摘要表 v1 延后。

详见 [Photo Writing Assist Prompt](../prompts/photo-writing/photo-writing-assist.md) 与 `docs/plans/active/2026-06-24-feature-photo-writing-ai-assist.md`。

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
- 多轮对话与文本流式的传输能力已落地（见 §3、§8）。**语伴会话已接文本流式 UX**（LM03-S3a：`CompanionConversationEngine.reply(onPartial:)` 逐 delta 累积回调 → `CompanionChatActions.send` seam +`onPartial` 第三参 → store `AsyncStream` 单 MainActor 顺序消费 → in-flight 气泡；流式只改显示，外发请求体 / 内容类目 / 隐私闸与 S1/S2b 完全一致，无新 capability / 无新外发类目）。**语伴对话记忆 / 滚动摘要已落地**（LM03-S3b-1：超窗时把老化轮压缩为摘要注入、`.companionSummarization` capability preview-only 诚实披露、删/清空摘要同事务失效重建；只压缩本会话已外发内容、无新外发类目、无新 consent 门）。其余上层消费（Memory·Style 注入演进 / 对话小结 / 对话级日志写入接线）仍属可演进，按 LM03 各切片推进。
- **Anthropic Messages 多轮 + 流式适配已落地（LM03-S4b，2026-06-27）**：`AnthropicMessagesTextAdapter`（顶层 `system` / 必填 `max_tokens` / `content[].text` 解析 / `content_block_delta` 流式 / 无 `[DONE]` 由字节 EOF 终止）；鉴权升为可动态派发的协议要求 `providerRequestHeaders`（Anthropic `x-api-key`+`anthropic-version`、mimo `api-key`、OpenAI 默认 Bearer，连带修复 mimo 旧 override 潜伏鉴权 bug）。语伴 send 路径 kind-agnostic、零 App 改动即可跑 Anthropic。**无新外发类目、无新 `AIRequestCapability`**：Anthropic 只是又一个用户自配 Provider 端点，决策 #10 与语伴隐私闸不变；密钥走既有 Keychain，不入日志 / SQLite / 同步。Anthropic 上的严格 schema 结构化输出（`tool_use`）与图片理解仍后置。Gemini 多轮 + 流式适配仍为保留扩展点（当前 `unsupportedProvider`），后续走 `docs/workflows/add-ai-provider.md` 接入。

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

- 2026-05-23：补充 TTS 配置测试边界。原因：语音模型配置与测试方案进入 OpenAI + OpenRouter 第一阶段，需要把旧的“语音生成不得发真实网络测试请求”修订为受 `011` 约束的固定低敏 TTS probe，并明确结果面板、endpoint metadata 和 profile 全局验证摘要隔离。影响范围：AI Provider 设置、LangoTraceAI、LangoTraceData、LangoTraceSpeech、诊断日志和逐句播放前置状态。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-23：补充一键学习材料生成真实请求边界。原因：iOS / iPhone 记录详情已接入当前文本 Entry 的真实 Provider 请求、结构化 Prompt、GRDB 结果保存和非阻断 AI 披露，需要把“真实学习内容请求未接入”的旧边界更新为当前实现事实。影响范围：LangoTraceAI、LangoTraceData、LangoTraceUI、AppEnvironment、Prompt Registry 和页面清单。是否需要 ADR：否，沿用 ADR-005；照片、音频、历史记忆和多 Entry 上下文仍需单独方案。
- 2026-05-24：修正一键学习材料生成三端入口事实。原因：iPad / macOS 记录详情已通过共享 `EntryDetailView` 接入同一 `LearningMaterialGenerationActions` / `LearningContentStore` action seam，AI 请求、Keychain 解析和 GRDB 写入路径不再是 iPhone-only；隐私边界仍限制为当前 Entry 文本或当前 learning text。影响范围：AI Provider 请求边界、三端记录详情和页面清单。是否需要 ADR：否，沿用 ADR-005。
- 2026-06-24：新增 §4.8 照片写作 AI 看图辅助写作边界 + §3 强制规则照片显式触发条目。原因：照片写作新增显式触发的看图辅助写作，是当前实现中第一个把照片发送给 Provider 的能力，需把「照片永不发送」从无条件承诺收敛为「仅 `photoWritingAssist` 能力 included、其余能力仍 always-excluded」，并固化脱敏单一入口、图片适配 allowlist、两模式严格输出与日志边界。影响范围：spec/005、Prompt Registry、platform-page-inventory、architecture/002-system-map、LangoTraceCore/Data/AI/UI、App Shell。是否需要 ADR：否，符合核心决策 #10，沿用 ADR-005；详见 `docs/plans/active/2026-06-24-feature-photo-writing-ai-assist.md`。
- 2026-06-24：§4.8 显式触发条目明确发送前确认弹窗为唯一披露界面。原因：照片写作页移除底部常驻隐私提示横幅以保持页面简洁，隐私披露不降级——发送前确认弹窗仍完整披露发送范围且与发送动作原子绑定。主要事实：删除 `photoWriting.privacy.notice` 文案 key 与页内 banner 视图，本地化守卫从「常驻 banner 文案」迁移到「发送前确认弹窗披露发送范围」并新增断言 banner key 已删除。影响范围：spec/005 §4.8、platform-page-inventory、`PhotoWritingView`、`Localizable.xcstrings`、`PhotoWritingAssistLocalizationTests`。是否需要 ADR：否，隐私底线不变，沿用核心决策 #10 与 ADR-005。
- 2026-06-25：新增 §3 多轮对话 + 文本流式强制规则，并在 §5 登记其上层消费仍可演进。原因：落地独立基础设施 enabler——AI Provider 多轮 messages 请求形态 + 文本流式 `AsyncThrowingStream`（OpenAI 兼容族 chat/completions + responses；mimo 流式未验证暂 defer；Anthropic / Gemini 仍 `unsupportedProvider`），作为 LM03 语伴的传输前置。流式保留响应体积上限拦截，能表达失败 / 取消 / 超时 / 配额（复用既有错误分类）；多轮请求投影就绪（携带非敏感元数据，不含正文 / persona / 密钥），但对话级日志写入接线归 LM03（沿用 §4.4 App-Shell recorder 依赖方向）。影响范围：spec/005、LangoTraceCore（`ConversationMessage`）、LangoTraceAI（`ServerSentEventParser` / `AIChatStreamingService` / 流式 HTTP seam / adapter 流式 body）、architecture/002-system-map、architecture/notes、workflows/add-ai-provider、ADR-008。是否需要 ADR：否，属 ADR-005 Provider 抽象内的能力扩展，不改隐私 / 商业 / 默认数据边界（多轮 messages 属核心决策 #10 的用户主动发送）；详见 `docs/plans/done/2026-06-25-feature-ai-provider-multi-turn-and-streaming.md`。
- 2026-05-17：创建第一版 AI Provider、Prompt 与隐私规范。
- 2026-05-17：补充同意级别、结构化输出校验、输出保存边界和失败处理分类。原因：降低 AI 请求隐私、可靠性和数据覆盖风险。影响范围：AI Provider、Prompt、UI 请求预览、数据保存。是否需要 ADR：否。
- 2026-05-19：补充 Provider 配置页边界。原因：AI Provider 设置页开始从静态说明改为真实级 mock 配置页，需要把安全配置草稿、保存配置、测试请求、能力矩阵和聚合 provider 提示沉淀为长期约束。影响范围：AI Provider 设置、隐私文案、后续 Keychain 和真实请求测试。是否需要 ADR：否。
- 2026-05-19：补充 Provider 配置页信息降噪规则。原因：iOS 页面需要真实设置表单质感，Provider 风险说明、请求格式、认证方式和 mock 边界不应全部暴露在主路径。影响范围：AI Provider 设置 UI、后续高级配置入口。是否需要 ADR：否。
- 2026-05-19：补充多模型 endpoint 与凭证引用规则。原因：同一 Provider 可能共用 API Key 但使用不同 endpoint/model，三类能力也可能使用不同 Provider。影响范围：AI Provider 设置 UI、后续 Keychain item 引用、TTS 和向量化配置。是否需要 ADR：否。
- 2026-05-19：补充 Provider 和 API Key 表单可用性规则。原因：API Key 输入需要明确字段名和可见性控制，中文主路径应避免“凭证”等偏工程术语。影响范围：AI Provider 设置 UI、本地化文案、后续安全存储表单。是否需要 ADR：否。
- 2026-05-19：补充三端 Provider 设置页共享与大屏承载规则。原因：iPad / macOS 工作台详情需要保持与 iPhone 相同字段语义，同时避免把 iPhone 表单横向拉满大屏。影响范围：AI Provider 设置 UI、SettingsCapabilityDetailView、macOS Settings scene 边界。是否需要 ADR：否。
- 2026-05-20：更新 Provider 配置页从 mock 到本地配置保存阶段的事实边界。原因：AI Provider profile、endpoint、credential metadata、Keychain 保存和本地 credential validation 已落地，真实外部 Provider 合成探测仍未接入。影响范围：AI Provider 设置、Keychain、Data repository、validation event、后续真实 AI 请求。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-20：补充 Provider 配置保存诊断规则。原因：保存链路已经跨 UI、AI service、Keychain、SQLite 和补偿清理，需要稳定 operation id、阶段分类、非敏感日志字段和默认关闭边界。影响范围：AI Provider 设置、诊断日志、Data repository、Testing 和 App Shell 装配。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-27：调整已保存 API Key 查看边界。原因：macOS 登录钥匙串可能在设置页加载阶段弹出认证，且用户已确认保留当前 API Key 字段 UI；再次进入 Provider 配置页不得自动解析 Keychain，已有密钥以 `已保存到本机 Keychain` placeholder 表达，用户点击字段右侧小眼睛后才解析并回填到同一可编辑输入框。影响范围：AI Provider 设置 UI、Keychain resolver action、SwiftUI draft 状态和测试边界。是否需要 ADR：否，仍符合 ADR-005 的本地优先和用户自带 Provider 边界。
- 2026-05-20：调整已保存 API Key 回显边界。原因：用户完成配置后再次进入配置页，需要能查看和编辑当前本机保存的 API Key；回显仅允许通过服务边界解析 Keychain 并进入短生命周期 UI draft，默认隐藏，不进入数据库、日志、同步或请求预览。影响范围：AI Provider 设置 UI、Keychain resolver action、SwiftUI draft 状态。是否需要 ADR：否，仍符合 ADR-005 的本地优先和用户自带 Provider 边界；该边界已于 2026-05-27 收紧为用户点击显示按钮后才解析。
- 2026-05-21：更新 Provider 配置测试请求边界。原因：文本模型合成探测已接入 Provider 层，测试请求从本地 credential validation 扩展为固定合成网络 probe；需要沉淀 draft / saved profile 分流、`synthetic_test` validation event、分能力结果面板和非敏感诊断边界。影响范围：AI Provider 设置、LangoTraceAI、LangoTraceData、LangoTraceUI、诊断日志和后续真实学习请求。是否需要 ADR：否，沿用 ADR-005；真实学习内容请求仍需单独请求预览方案。
- 2026-05-21：补充图片理解合成 probe 边界。原因：Provider 配置测试请求从文本 / JSON 扩展为用户显式启用后的内置图片 probe，需要明确不发送用户照片、adapter 支持范围、Prompt Registry 登记和非敏感日志约束。影响范围：AI Provider 设置、LangoTraceAI、Prompt Registry、诊断日志和后续真实图片理解请求。是否需要 ADR：否，沿用 ADR-005；真实用户照片请求仍需单独请求预览方案。
- 2026-05-22：补充语言支持合成 probe 边界。原因：Provider 配置测试请求新增当前语言空间上下文下的 `语言支持` 分项，需要明确 target language code allowlist、Prompt Registry、离线校验、非认证性质、profile 全局验证摘要隔离和 `sample` 原文不落日志边界。影响范围：AI Provider 设置、LangoTraceAI、LangoTraceUI、Prompt Registry、诊断日志和后续真实学习请求。是否需要 ADR：否，沿用 ADR-005；真实学习内容请求仍需单独请求预览方案。
- 2026-05-22：补充 iPad / macOS 语言支持入口事实。原因：iOS 人工审核后，iPad / macOS 通过共享 `SettingsCapabilityDetailView` 接入同一 language context，不改变 Provider 保存、Keychain、网络、Prompt、日志或持久验证摘要边界。影响范围：AI Provider 设置 UI、SettingsCapabilityDetailView、页面清单。是否需要 ADR：否。
- 2026-05-24：补充 AI Provider 系统级设置归属边界。原因：Provider profile 和凭证是跨语言空间配置，设置详情不应把当前语言空间方向显示成页面归属；language context 只服务测试和 voice profile。影响范围：AI Provider 设置 UI、SettingsCapabilityDetailView、页面清单。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-27：补充向量化配置测试边界。原因：OpenAI、OpenRouter 和 Custom OpenAI-compatible 的向量 endpoint 已从占位状态推进到用户显式启用后的固定低敏 embeddings probe，需要明确不发送用户内容、不保存 vector、endpoint-scoped validation 和 profile 全局摘要隔离。影响范围：AI Provider 设置、LangoTraceAI、LangoTraceData、Prompt Registry、测试工具和后续向量基础设施。是否需要 ADR：否，沿用 ADR-005。
- 2026-06-01：补充阅读选区解释边界。原因：Reading vertical slice 已接入真实 `ReadingSelectionExplanationService` 和 Prompt Registry，阅读页点击 `解释` 后只发送 selection、sentence、limited context 和语言空间上下文，不发送全文。影响范围：LangoTraceAI、Reading UI、AppEnvironment、Prompt Registry、诊断日志和 Reading spec。是否需要 ADR：否，沿用 ADR-005。
- 2026-06-18：§4.3 请求预览与 §4.4 请求日志从规范推进到已落地基础设施（E6）。原因：建立真实「将发送内容」投影与本地 `ai_request_logs`。主要事实：(1) Core 新增 `AIRequestPreviewProjection`（capability、provider preset、model、prompt id/version、长度分桶、含/排除内容**类别**描述符——封闭枚举，绝不含 Prompt 正文或用户内容）与 `AIRequestLogEntry`（列级 allowlist，结构上无任何内容字段，仿 `DiagnosticAttribute`）；(2) 投影由学习材料生成 / 分析 / 阅读选区解释三条路径的 request struct 经纯函数 `previewProjection()` 同源构造，保证预览不与实际请求漂移；(3) 新增 `v24_create_ai_request_logs` migration + `GRDBAIRequestLogRepository`（append 同事务按 capability 修剪 200 行，本地诊断性数据，不同步不导出）；(4) 依赖方向遵循既有约定：AI service 保持纯执行器，日志由 **App-Shell `AIRequestLogRecorder`**（镜像 `ReadingExplanationOperationRecorder`）在 `AppEnvironment` 包裹真实 generate/analyze/explain 调用写入，成功 / 失败 / 取消三态，取消记 `cancelled` 无失败分类；(5) 各域 `FailureCategory` → 日志封闭分桶为常驻映射（E0a 仅丰富未统一 taxonomy）；(6) `RequestPreviewCard` 真实渲染投影（mock 保留本地草稿态，未配置 Provider 显式离线态），`AIRequestLogListView` 内容无正文、真实数据驱动、可达 iPad 面板 / macOS Inspector / 设置 AI Provider 详情。PrivacyStatus 文案本方案**不恢复**预览表达，维持 274b7db 收紧文案与防回归测试。影响范围：LangoTraceCore / Data / AI / UI、App Shell、本规范 §4.3 / §4.4 / §4.7。是否需要 ADR：否，沿用 ADR-005 本地优先与核心决策 9/10 边界。
- 2026-06-26：登记语伴聊天反哺提取 capability 与显式触发边界（LM03-S2a）。原因：语伴聊天反哺新增「提取词汇 / 表达」能力，把已存对话内容在用户显式点击时重发给所配置 Provider。主要事实：(1) 新增 `AIRequestCapability.companionExtraction` 闭集 case + `AIRequestContentDescriptor.companionConversation` 类目；请求预览投影 `includedContent = [companionConversation]`，**无新外发类目**（照片 / 长期记忆 / 历史记录 / 其他空间保持 always-excluded），预览须**显式披露**「将本段对话发送以提取词汇」（plan §D2 / P0-1）。(2) **分类：显式触发重发，非系统自动注入**——与「生成学习材料 / 重新分析」同构（已存用户内容、显式触发、仅受全局 Provider 配置 + 请求预览约束），**不进** Memory 注入的系统自动注入门（决策 #10）；系统自动注入（Memory 画像）= LM03-S2b，门控未开。(3) 固定提取 Prompt `CompanionExtractionPromptRegistry`（`builtin.companion.extraction.v1`，进 `docs/prompts/companion/extraction.md`，隐私边界 directive 禁臆造 / 禁画像，AI-17 加固，结构化 JSON 契约）；引擎 `CompanionExtractionEngine` 复用 S1 `CompanionReplyTransport`→`AIChatStreamingService`。(4) 静默每轮自动提取明确排除（会从显式触发漂移为后台自动外发）。影响范围：LangoTraceCore / Data / AI / UI、App Shell、Prompt Registry、本规范、architecture/002、page-inventory、spec/007、ADR-008。是否需要 ADR：否，受 ADR-008 约束、符合决策 #10、沿用 ADR-005；详见 `docs/plans/done/2026-06-25-feature-lm03-s2a-companion-reflux.md`。
- 2026-06-25：登记语伴会话 Prompt 与外发边界（LM03-S1）。原因：语伴落地固定 system Prompt（`CompanionPromptRegistry` `builtin.companion.system.v1`，进 `docs/prompts/companion/system.md`，人设三枚举→受控片段映射、无自由文本进指令位，AI-17 加固），请求经 Provider 抽象 `AIChatStreamingService` + E6 投影（`projectionMetadata`，非敏感元数据，不含 system 全文 / 消息正文 / 密钥）；S1 **零系统自动注入**（不注入 Memory / Style、不读 FTS），外发仅用户消息 + 显式带入单条 Entry（核心决策 #10 用户主动触发）；S1 缓冲 enabler 流式作非流式 UX。对话级 log 写入接线由 LM03 补（沿用 §4.4 App-Shell recorder）；Memory 注入 + PII scrubbing = LM03-S2。影响范围：LangoTraceAI（`CompanionPromptRegistry` / `CompanionConversationEngine`）、Prompt Registry、App Shell、本规范。是否需要 ADR：否，受 ADR-008 约束、沿用 ADR-005。
- 2026-06-26：登记语伴 Memory 注入 capability 与诚实披露契约（LM03-S2b-1）。原因：语伴落地系统级生活事实注入（决策 #10 首个系统自动注入外发）。主要事实：(1) 新增 `AIRequestCapability.companionConversation`（首个对话送 capability，**preview-only、不写 `ai_request_logs`**）+ 新 included descriptor `AIRequestContentDescriptor.curatedLearnerMemory`；`AIRequestProjections.companionConversation(hasMemoryInjection:)` 在注入时 includedContent 加 `.curatedLearnerMemory`，**`.longTermMemory` 始终 excluded**（原始全量长期记忆库永不外发，与 photo/audio/历史/其他空间 always-excluded 保证不破）。(2) 注入 Prompt = 复用 `builtin.companion.system.v1` 加性 `memoryContext` 受控片段（delimiter `<<<MEMORY>>>` 引用非指令 + `.memoryGroundedContext` directive，进 `docs/prompts/companion/system-injection.md`）；事实经 `CompanionMemorySelection`（时近性 + 种类配额 top-5、不读 salience、仅 `.global`）选择。(3) **PII scrubbing v1**（手机号 / 身份证）对**注入片段 + 历史回放 + 用户输入**统一 outbound 脱敏（`CompanionConversationEngine.scrub` seam，存原文发脱敏、不入日志 / DB）。(4) 授权 = 首次开启的一次性预览（`CompanionMemoryPreviewModel` 诚实展示发 curated / 不发全量，**不复用绑 entry 的 `RequestPreviewCardModel`**）+ 全局关 + per-conversation 开关；注入门 `CompanionInjectionGate` 纯函数四态可测，权威判定落 App send。(5) band 红线不碰（只读 `learner_memory_facts`）。影响范围：LangoTraceCore / LearnerModel / AI / Data / UI、App Shell、Prompt Registry、本规范、spec/007·008、ADR-006·008、architecture/002、page-inventory。是否需要 ADR：否，受 ADR-008 / 决策 #10 约束、沿用 ADR-005；详见 `docs/plans/done/2026-06-26-feature-lm03-s2b1-companion-memory-injection.md`。
- 2026-06-26：登记语伴方案B 主动找话题 capability 披露 + 修复方案A 披露缺口（LM03-S2b-2）。原因：语伴授权后自动带入一条用户记录开启话题。主要事实：(1) 新增 included descriptor `AIRequestContentDescriptor.broughtInRecords`（**A/B 共用**：方案A 用户显式带入 + 方案B 自动找）；`companionConversation(..., hasBroughtInRecords:)` 注入时 includedContent 加 `.broughtInRecords`、`.longTermMemory` 仍 excluded；**复用 `.companionConversation` capability，不新增 capability**、preview-only 不写 `ai_request_logs`。(2) **修复方案A 披露缺口**：方案A 的 `seedEntryBody` 此前外发记录正文但**任何 preview 路径零披露**，`.broughtInRecords` A/B 共用一并修复诚实披露。(3) 注入 Prompt = 复用 `builtin.companion.system.v1` 加性 `broughtInRecords` 受控片段（`<<<RECORD>>>` 引用非指令 + `.topicGroundedInBroughtRecord` directive，进 `docs/prompts/companion/system-injection.md`）；记录经 `CompanionTopicSelection`（recency top-1、纯 entries.body、不用 FTS）选择。(4) 一次性话题授权 UX（`CompanionMemoryPreviewModel` 复用展示发 1 条记录/不发全量）+ per-conversation 开关复用 + 注入门 `CompanionInjectionGate.shouldSourceTopic` 纯函数四态可测；仅 send 回合内、band 红线不碰。影响范围：LangoTraceCore / LearnerModel / AI / Data / UI、App Shell、Prompt Registry、本规范、spec/008、ADR-006·008、architecture/002 §4.14、page-inventory。是否需要 ADR：否，受 ADR-008 §6 / 决策 #10 约束、沿用 ADR-005；详见 `docs/plans/active/2026-06-26-feature-lm03-s2b2-companion-active-topic-finding.md`。
- 2026-06-26：登记语伴文本流式 UX + 温和复述 opt-in（LM03-S3a）。原因：语伴把 S1 缓冲整段的非流式 UX 升级为逐字流式显示，并暴露既有温和复述纠错档。主要事实：(1) **流式只改显示，不改外发边界**——`CompanionConversationEngine.reply(..., onPartial:)` 在既有 delta 循环内逐 token 回调**累积缓冲全文**；`CompanionChatActions.send` seam 新增 `onPartial` 第三参（传输契约变更）；store 用 `AsyncStream` + 单 MainActor consumer 顺序消费 `inFlightReply`（correct-by-construction，无 Task fan-out / 无单调守卫）；**无新 capability、无新外发类目、无新 migration**；请求体 / 内容类目 / 隐私闸 / PII scrub 与 S1·S2b 完全一致。(2) `inFlightReply` 纯 UI 派生态，**从不进持久路径**——仅成功 outcome 的完整缓冲文本持久；失败 / 取消任何路径清空 in-flight、保输入不伪装（ADR-008 §7）。(3) 温和复述 = 暴露既有 `CompanionCorrection.warmRecast` 闭集值（默认 `.ifNeeded` 关），directive + fragment 早已映射；persona 为 per-space（`conversation_companions`），toggle 经 App **read-modify-write**（loadPersona→仅改 correction→savePersona 全字段 upsert，保 tone/formality）。(4) band 红线不碰（纯对话 UX + persona）。影响范围：LangoTraceAI（`CompanionConversationEngine`）/ UI（`CompanionChatActions`·`CompanionChatStore`·`CompanionChatView`·`CompanionChatPresentation`）/ App Shell、本规范、architecture/002、page-inventory、prompts/companion/system.md。是否需要 ADR：否，受 ADR-008 约束、沿用 ADR-005，不改隐私 / 商业 / 默认数据边界；详见 `docs/plans/done/2026-06-26-feature-lm03-s3a-companion-streaming-and-recast.md`。
- 2026-06-26：登记语伴对话记忆 / 滚动摘要 capability + 失效重建一致性（LM03-S3b-1）。原因：会话超窗时把老化出窗的较早轮次压缩为滚动摘要注入 system prompt，长对话保持上下文。主要事实：(1) 新 `AIRequestCapability.companionSummarization`（**preview-only、不写 `ai_request_logs`**）+ `AIRequestProjections.companionSummarization` includedContent = `[.companionConversation]`、长期记忆/记录/照片/音频/历史/其他空间全 excluded。**隐私归类 = 语伴整体 opt-in 内、不新增 consent 门**：摘要系统自动触发，但被摘要内容 = provider 在本会话早轮已收到的对话（同会话同 provider、内容已见过、无外部数据），与 Memory 注入（注入外部系统级事实 = 最高门）严格不同类；capability 披露诚实说明此自动外发。(2) 摘要 Prompt `CompanionSummarizationPromptRegistry`（`builtin.companion.summary.v1`，进 `docs/prompts/companion/summary.md`，directive 禁臆造/禁画像/reference-only/仅本会话）；`CompanionConversationEngine.summarize` 非流式缓冲 + `shouldSummarize` 纯函数触发判定；被摘要轮 + 现有摘要经 `scrub`（PIIScrubber）outbound 脱敏；注入经 `systemPrompt(conversationMemory:)` `<<<CONVERSATION MEMORY>>>` 引用非指令 + `.conversationMemoryGrounded` directive。(3) **持久化 v33** `companion_threads` 加 `rolling_summary`/`summary_covers_through_sequence`/`summary_updated_at`（派生 cache 列、水位模型、无 fingerprint）、local-only 不同步；删该条及后续/清空 → 覆盖被删内容的摘要**同 write 事务失效重建**（idea-03 §3.2）；摘要失败 = honest failure 不更新不阻塞回复。(4) band 红线不碰（摘要只读 `companion_messages.content`）。影响范围：LangoTraceCore / AI / Data / App Shell、本规范、spec/007、ADR-006·008、architecture/002 §4.16、page-inventory、prompts/companion/summary.md。是否需要 ADR：否，受 ADR-008 / 决策 #10 约束、沿用 ADR-005；详见 `docs/plans/done/2026-06-26-feature-lm03-s3b1-companion-rolling-summary.md`。
