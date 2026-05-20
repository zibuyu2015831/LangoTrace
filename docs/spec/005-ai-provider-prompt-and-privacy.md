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

Provider 配置页已经从真实级 mock 表单进入本地配置保存阶段：非敏感 Provider profile、endpoint、credential metadata 和 validation event 进入 SQLite / GRDB，API Key 写入 Keychain。真实外部 Provider 请求、Prompt Preset 执行、请求预览和请求日志仍未接入。后续实现必须遵守以下边界：

- API Key 输入只能作为当前页面的短生命周期明文草稿；保存成功后必须清空 SwiftUI 草稿，不得在加载已保存配置时解密或回填明文。
- 非敏感配置和敏感凭证必须分层。Provider、Base URL、模型名属于普通表单配置；请求格式、认证方式和自定义请求头等技术信息应默认收起或进入高级配置，不应挤占首屏主路径。API Key、外部服务 token、自定义请求头中的密钥属于敏感凭证。
- 敏感凭证必须保存到本机 Keychain 或等价安全存储。SQLite 只能保存 credential metadata、Keychain service / account 引用、最近观测到的 secret presence 和非敏感验证事件；不得保存明文、可解密密文、hash、尾号或完整请求头值。
- 已保存配置的后续本地验证和未来真实 AI 请求必须由服务层通过 Keychain 引用解析密钥；不得要求用户每次请求前重新输入、暴露或预览密钥。
- Keychain item 默认不跨设备同步；数据库恢复到新设备但 Keychain 缺失时，应进入 `credential_missing` 或等价可恢复状态，引导用户重新输入密钥。
- Provider 配置页应按模型用途表达 endpoint：文本模型、语音生成模型、向量模型是不同能力边界，不使用“高级模型”统称。
- Provider 和 API Key 属于高频填写项。Provider 应使用一行设置项展示当前选择；API Key 输入必须有明确字段名，并提供显示/隐藏按钮，默认隐藏。面向普通中文用户的主路径文案应使用 `API Key`，避免使用“凭证”等偏工程术语。
- 模型 endpoint 与敏感凭证必须分离。多个 endpoint 可以引用同一份凭证，例如同一 Provider 的文本、语音和向量 endpoint 共用同一个 API Key，但它们的 Base URL、adapter、请求格式和模型名仍应独立配置。
- 当不同能力选择不同 Provider 时，默认使用独立凭证，避免跨 Provider 误用 API Key。只有用户明确选择共享凭证时，才允许 endpoint 引用文本模型凭证。
- 图片理解是文本模型 endpoint 的能力开关。默认关闭，只有用户显式启用后，后续照片或图片理解请求才可使用该能力。
- iPhone、iPad 和 macOS 的 Provider 设置页应共享同一字段语义和表单组件。平台差异只允许体现在承载宽度、导航位置、输入密度和窗口行为上；不得为 iPad 或 macOS 复制一套字段模型，避免重新出现旧术语、旧能力分组或未标注 API Key 输入。
- iPad / macOS 工作台中的 Provider 设置详情应使用合理最大内容宽度保持阅读栏；该宽度是视觉承载约束，不得写入 Provider 配置模型、Repository、同步协议或安全存储模型。
- macOS 原生 Settings scene 和工作台 Settings section 是两个入口层。当前原生 Settings scene 只展示能力状态列表，不承载 Provider 写入表单；后续若要在原生 Settings scene 支持 Provider 配置，必须复用同一配置模块并单独审查写入边界。
- “测试请求”按钮必须走明确状态机。当前阶段只做本地配置完整性和 Keychain 可读性检查，不发起网络请求；真实阶段必须经过 Provider 层，不允许 SwiftUI View 直接创建具体服务请求。
- 真实测试请求只能发送合成检测内容，不得发送生活记录、照片、音频、历史记忆、目标语言正文或 Prompt Preset 内容。
- 本地配置验证可以记录 `credential_validation` 类型的非敏感 validation event，包括 provider、model、endpoint purpose、状态、错误分类和时间；不得记录请求体、响应体、API Key、完整 Keychain account、完整请求头或用户内容。
- Provider preset 不能默认声明所有能力都可用。Chat、Embedding、TTS、图片理解、语音识别和自定义请求头需要分别表达支持状态。
- 聚合服务或兼容层的路由提示应只在用户选择该类 Provider 或进入高级信息时出现，避免把所有 Provider 的技术风险说明长期展示在普通设置主路径。

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

- 2026-05-17：创建第一版 AI Provider、Prompt 与隐私规范。
- 2026-05-17：补充同意级别、结构化输出校验、输出保存边界和失败处理分类。原因：降低 AI 请求隐私、可靠性和数据覆盖风险。影响范围：AI Provider、Prompt、UI 请求预览、数据保存。是否需要 ADR：否。
- 2026-05-19：补充 Provider 配置页边界。原因：AI Provider 设置页开始从静态说明改为真实级 mock 配置页，需要把安全配置草稿、保存配置、测试请求、能力矩阵和聚合 provider 提示沉淀为长期约束。影响范围：AI Provider 设置、隐私文案、后续 Keychain 和真实请求测试。是否需要 ADR：否。
- 2026-05-19：补充 Provider 配置页信息降噪规则。原因：iOS 页面需要真实设置表单质感，Provider 风险说明、请求格式、认证方式和 mock 边界不应全部暴露在主路径。影响范围：AI Provider 设置 UI、后续高级配置入口。是否需要 ADR：否。
- 2026-05-19：补充多模型 endpoint 与凭证引用规则。原因：同一 Provider 可能共用 API Key 但使用不同 endpoint/model，三类能力也可能使用不同 Provider。影响范围：AI Provider 设置 UI、后续 Keychain item 引用、TTS 和向量化配置。是否需要 ADR：否。
- 2026-05-19：补充 Provider 和 API Key 表单可用性规则。原因：API Key 输入需要明确字段名和可见性控制，中文主路径应避免“凭证”等偏工程术语。影响范围：AI Provider 设置 UI、本地化文案、后续安全存储表单。是否需要 ADR：否。
- 2026-05-19：补充三端 Provider 设置页共享与大屏承载规则。原因：iPad / macOS 工作台详情需要保持与 iPhone 相同字段语义，同时避免把 iPhone 表单横向拉满大屏。影响范围：AI Provider 设置 UI、SettingsCapabilityDetailView、macOS Settings scene 边界。是否需要 ADR：否。
- 2026-05-20：更新 Provider 配置页从 mock 到本地配置保存阶段的事实边界。原因：AI Provider profile、endpoint、credential metadata、Keychain 保存和本地 credential validation 已落地，真实外部 Provider 合成探测仍未接入。影响范围：AI Provider 设置、Keychain、Data repository、validation event、后续真实 AI 请求。是否需要 ADR：否，沿用 ADR-005。
