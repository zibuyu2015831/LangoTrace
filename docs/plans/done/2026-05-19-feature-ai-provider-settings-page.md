# 任务方案：AI Provider 设置页真实级配置展示

状态：Verified
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

- 2026-05-19：用户回复“开始实施”，确认按本方案开始实现。确认范围：先完成 iOS 真实级 mock 配置页、测试按钮、主流 Provider preset、隐私边界和文档同步；不接入真实网络、真实 Keychain 或真实 AI 请求。

## 1. 需求或 bug 描述

iPhone 当前 AI Provider 设置详情仍是边界说明页，只展示“本地优先”“当前状态”“接下来”“隐私说明”等静态说明。用户希望把该页面改造成真实的 AI 请求信息填写页面，支持多种主流 AI Provider，填写 API Key、模型、base URL 等必要配置。当前阶段真实 AI 请求尚未接入，因此需要先使用模拟数据和真实级页面状态，用于确定 UI 设计和后续工程边界。

## 2. 现状描述

- `SettingsCapabilityDetailView` 对所有 `SettingsCapability.Kind` 复用同一说明模板；只有 `interfaceLanguage` 会显示真实控件。
- `SettingsCapability.Kind.aiProvider` 当前状态来自 `InMemoryLearningContentRepository.serviceSettingsCapabilities`，状态为 `.mockOnly`，没有配置表单、Provider 选择、API Key 输入、模型输入或连接测试。
- `LangoTraceAI` 目前只有 `AIProvider` 空协议和 `DisabledAIProvider`，没有真实 TextGenerationProvider、配置模型、Keychain repository 或网络请求实现。
- 现有长期规范已经要求 API Key 存入 Keychain，UI 不直接调用具体 AI 服务，AI 请求必须经过 Provider 层，并保留请求预览、日志元数据、错误处理和脱敏策略。

## 3. 目标

- 将 AI Provider 设置详情从静态说明页改为真实级配置页。
- iOS 首轮必须完成；共享组件应为 iPad 和 macOS 复用预留结构，但本任务以 iPhone 视觉验证为主。
- 支持主流 Provider preset 和自定义 OpenAI-compatible 配置。
- 页面可填写或展示：Provider、API Key、base URL、chat model、embedding model、TTS model 或 TTS 来源、请求格式、连接测试入口、隐私和本地保存说明。
- 页面必须提供一个明确的“测试连接 / 测试请求”按钮，供用户在填写 Provider、API Key、base URL 和模型后验证配置路径；本轮按钮使用模拟请求状态，后续真实接入时改为只发送合成测试内容的 Provider health check。
- 当前不发起真实网络请求，测试按钮、连接状态和保存结果使用模拟状态，避免误导为真实能力已接入。
- API Key 字段必须按敏感信息设计：输入遮蔽、只作为当前页面 transient draft、退出页面即丢弃；不得承诺已保存到 Keychain，后续 Keychain 接入边界必须明确。

## 4. 范围

- iPhone AI Provider 设置详情页 UI。
- Provider 配置展示模型和 mock 配置状态。
- 设置列表中 AI Provider 状态摘要的文案更新。
- 本地化字符串。
- 针对 UI 结构、敏感文案和未接入真实网络边界的单元测试。
- `docs/platform-page-inventory.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md` 或产品参考文档的必要同步。

## 5. 不做什么

- 不接入真实 OpenAI、Anthropic、Gemini、DeepSeek 或其他 Provider 网络请求。
- 不保存真实 API Key 到普通数据库、文件、日志或 mock repository。
- 不实现 Keychain repository。本任务只设计 UI 和 mock 状态；Keychain 可作为后续任务。
- 不实现 Prompt Preset 执行、请求预览真实 payload、请求日志、费用估算、模型列表在线拉取或健康检查真实调用。
- 不把用户输入的 API Key 传入 Data package、测试日志、预览 fixture、诊断日志或可截图的明文 UI。
- 不把 Provider 配置模型误建成普通学习内容模型；长期非敏感配置与敏感凭证必须分层。
- 不改变当前“本地优先、用户自带 Provider、敏感内容由用户明确触发后才发送”的核心决策。

## 6. 证据与决策依据

### 6.1 项目内证据

- `docs/spec/005-ai-provider-prompt-and-privacy.md`：API Key 必须保存到 Keychain；UI 不直接调用具体 AI 服务；所有 AI 请求经过 Provider 层；请求预览要说明 Provider、模型、发送内容类型和元数据保存边界。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：API Key 和外部服务 token 必须存入 Keychain，默认不进入数据库、日志、导出包或同步目录。
- `docs/technical-framework-roadmap.md` 第 7 节：Provider 应支持 OpenAI-compatible endpoint、自定义 base URL、自定义 API Key、自定义请求头、自定义模型名、Prompt Preset、请求前隐私预览和请求日志元数据。
- `docs/product-main-reference.md` 第 23 节：AI 配置应设计成 provider 体系，不是单一 API Key 输入框；普通用户看到最少配置，高级用户可以配置 provider、模型、preset 和请求格式。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`：当前 AI Provider 走通用只读说明模板，没有表单。
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`：当前 `SettingsCapability` 只表达能力状态，不表达 provider 配置。
- `LangoTraceApp/AppEnvironment.swift` 和 `Packages/LangoTraceAI/Sources/LangoTraceAI/AIBoundary.swift`：当前环境注入的是 `DisabledAIProvider`，AI 模块还没有真实 provider 实现。

### 6.2 Provider 官方文档核对

本轮页面字段按“能支持真实 provider 差异，但不把所有高级参数暴露给普通用户”的原则设计：

| Provider | 官方配置事实 | 页面字段影响 |
| --- | --- | --- |
| OpenAI | API 使用 Bearer API Key；模型通过 model ID 指定；模型列表接口为 `https://api.openai.com/v1/models`；当前模型文档列出 GPT-5.2、GPT-5 mini、GPT-5 nano、embedding、TTS、transcribe 等模型族。来源：https://platform.openai.com/docs/api-reference/introduction/tokenization ，https://platform.openai.com/docs/models | Preset 默认 base URL `https://api.openai.com/v1`；chat model、embedding model、TTS model 分开填写或选择。 |
| Anthropic | Messages API 为 `https://api.anthropic.com/v1/messages`；认证头使用 `x-api-key`，并要求 `anthropic-version`；请求体使用 `model`。来源：https://docs.anthropic.com/fr/api/messages | 不能只按 OpenAI-compatible 渲染；需要 `adapterKind = anthropicMessages` 和版本头字段。首轮可展示 preset，但真实请求留后续 adapter。 |
| Google Gemini | REST 内容生成端点形如 `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`；认证使用 `x-goog-api-key`；模型名如 `gemini-2.5-flash`。来源：https://ai.google.dev/api ，https://ai.google.dev/gemini-api/docs/api-key | 需要 `adapterKind = geminiGenerateContent`；base URL 与模型路径拼接方式不同，不能强塞到 OpenAI-compatible。 |
| DeepSeek | 官方说明兼容 OpenAI/Anthropic；OpenAI base URL 为 `https://api.deepseek.com`，Anthropic base URL 为 `https://api.deepseek.com/anthropic`；当前模型包含 `deepseek-v4-flash`、`deepseek-v4-pro`，`deepseek-chat` 和 `deepseek-reasoner` 将在 2026-07-24 弃用。来源：https://api-docs.deepseek.com/ | OpenAI-compatible preset；模型提示不应默认旧 alias。 |
| Mistral | Chat completions 端点为 `https://api.mistral.ai/v1/chat/completions`；API Key 使用 Bearer；请求体需要 `model`，文档示例包含 `mistral-small-latest`、`mistral-large-latest`。来源：https://docs.mistral.ai/api ，https://docs.mistral.ai/admin/security-access/api-keys | 可作为 OpenAI-like chat preset，但参数支持和安全参数不同，首轮只暴露基础字段。 |
| Groq | OpenAI-compatible base URL 为 `https://api.groq.com/openai/v1`；模型列表端点为 `/models`；请求使用 Bearer `GROQ_API_KEY`；示例模型包含 `openai/gpt-oss-20b`、`llama-3.3-70b-versatile` 等。来源：https://console.groq.com/docs ，https://console.groq.com/docs/models | OpenAI-compatible preset；适合低延迟文本模型，但模型可用性需以后在线校验。 |
| xAI | OpenAI SDK 示例 base URL 为 `https://api.x.ai/v1`；认证使用 Bearer `XAI_API_KEY`；Responses API 示例模型为 `grok-4.3`，Chat Completions 示例模型为 `grok-4.20-reasoning`。来源：https://docs.x.ai/developers/quickstart ，https://docs.x.ai/docs/guides/chat-completions | OpenAI-compatible preset，但推荐接口偏 Responses；首轮 UI 记录请求格式。 |
| Moonshot / Kimi | OpenAI SDK 示例 base URL 为 `https://api.moonshot.ai/v1`；API Key 使用 `MOONSHOT_API_KEY`；示例模型包含 `kimi-k2.5`、`kimi-k2-turbo-preview`。来源：https://platform.moonshot.ai/docs/guide/kimi-k2-5-quickstart ，https://platform.moonshot.ai/docs/guide/agent-support.en-US | OpenAI-compatible preset；适合作为中文用户常见 provider。 |
| OpenRouter | API schema 类似 OpenAI Chat API；模型列表为 `https://openrouter.ai/api/v1/models`；API Key 使用 Bearer；模型 ID 形如 `openai/gpt-4` 或其他 provider/model。来源：https://openrouter.ai/docs/api-reference/overview ，https://openrouter.ai/docs/guides/overview/models | 作为聚合 provider preset；需要明确第三方路由和隐私边界，不默认推荐给所有用户。 |
| Qwen / DashScope | 阿里云百炼 DashScope 提供兼容 OpenAI 的调用方式，常见 base URL 为 `https://dashscope.aliyuncs.com/compatible-mode/v1`，模型 ID 使用 Qwen 系列。来源：https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope | 中文用户常见 provider；作为 OpenAI-compatible preset，但地域、账号和模型可用性需以后在线校验。 |
| Zhipu GLM | 智谱开放平台提供 GLM 系列模型和 OpenAI 风格接口；配置涉及 API Key、模型 ID 和平台 endpoint。来源：https://docs.bigmodel.cn/cn/guide/start/introduction | 中文用户常见 provider；纳入 preset 候选，实施前再次核对当前官方 base URL 和模型名。 |
| SiliconFlow | SiliconFlow 提供 Chat Completions API，官方示例端点为 `https://api.siliconflow.com/v1/chat/completions`；中文账号或区域可能使用 `.cn` 域名，实施前必须按官方控制台和文档复核。来源：https://docs.siliconflow.com/en/api-reference/chat-completions/chat-completions_copy | 聚合和国产模型常用入口；需要提示第三方路由与模型提供方差异。 |
| Ollama / local OpenAI-compatible | Ollama 官方原生 API 默认 base URL 为 `http://localhost:11434/api`；OpenAI-compatible 客户端通常使用 `/v1` 兼容入口，实施前必须核对当前 Ollama 官方 OpenAI compatibility 文档。来源：https://docs.ollama.com/api ，https://github.com/ollama/ollama/blob/main/docs/openai.md | 适合作为未来本地模型入口；iPhone 真机访问本机 localhost 边界复杂，首轮可作为 Custom / local preset 说明，不默认启用。 |

### 6.3 系统架构复查结论

- 配置页面应分为三层：UI transient draft、非敏感 Provider 配置、敏感凭证。UI 可以承载 `SecureField` 的临时输入，但不能把真实 API Key 写入普通模型、日志、截图可见文本或 mock repository。
- 当前阶段的 `AIProviderSettingsModels.swift` 只能是 UI 展示模型或 draft；长期可执行配置模型应下沉到 `LangoTraceAI` 或专门的 Provider 配置模块，避免 `LangoTraceData` 学习内容 repository 直接拥有 Provider 密钥语义。
- “测试连接 / 测试请求”必须作为页面一等按钮存在，但本轮实现为模拟状态机；真实接入时必须走 Provider 层，不允许 View 直接构造 URLSession 请求。
- 真实测试请求只能发送合成测试内容，例如“Return OK for LangoTrace provider configuration test.”，不得发送生活记录、照片、音频、历史记忆、目标语言正文或 Prompt Preset 内容。
- 测试按钮应区分 `idle`、`missingRequiredFields`、`mockTesting`、`mockSucceeded`、`mockFailed`、`realTestingUnavailable`、未来 `realSucceeded`、`realFailed`、`cancelled`、`timeout`、`quotaLimited`、`invalidCredentials` 和 `unsupportedModel` 等状态，避免后续真实 Provider 错误被压成一个字符串。
- Provider preset 不能默认假定都支持 chat、embedding、TTS 和 image understanding。模型区应按 capability 展示：chat 必填，embedding / TTS / image understanding 只有 provider 声称可用或用户展开高级配置时显示。
- 聚合 provider（OpenRouter、SiliconFlow）和国内兼容层（DashScope、GLM 等）需要在 UI 中提示“请求会经过该服务商或其路由模型”，不能只显示最终模型名。

## 7. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`（预计新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`（预计新增，若模型更适合 Data package 则调整）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`（预计新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/*`
- 可能涉及 `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ContentUtilityComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIBoundary.swift`

## 9. 涉及的文档路径

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/platform-page-inventory.md`
- `docs/plans/active/2026-05-19-feature-ai-provider-settings-page.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

1. 建立 UI mock 数据模型
   - 定义 `AIProviderPreset`：`openAI`、`anthropic`、`gemini`、`deepSeek`、`mistral`、`groq`、`xAI`、`moonshotKimi`、`openRouter`、`dashScopeQwen`、`zhipuGLM`、`siliconFlow`、`ollamaLocal`、`customOpenAICompatible`。
   - 定义 `AIProviderAdapterKind`：`openAICompatibleChat`、`openAIResponses`、`anthropicMessages`、`geminiGenerateContent`。
   - 定义 `AIProviderCapabilitySet`：chat、embedding、tts、imageUnderstanding、speechRecognition、openAICompatible、customHeaders。
   - 定义 `AIProviderDraftConfiguration`：provider、display name、base URL、auth header kind、API key transient state、chat model、embedding model、tts mode、request format、custom headers allowed、capability set、last test state。
   - 定义 `AIProviderTestState`：`idle`、`missingRequiredFields`、`mockTesting`、`mockSucceeded`、`mockFailed`、`realTestingUnavailable`；预留真实错误枚举映射。
   - 首轮数据只存在 View 内或 UI mock factory，不进入持久层；测试 fixture 不包含真实 API Key 示例。

2. 替换 AI Provider 设置详情内容
   - 在 `SettingsCapabilityDetailView` 中对 `.aiProvider` 分支渲染专用 `AIProviderSettingsView`。
   - 保留平台统一页面 chrome、返回按钮、背景和文字密度。
   - 顶部状态从“未配置 / 本地优先”升级为“本地草稿 / 未保存密钥 / 未发起请求”。

3. iPhone 首轮页面结构
   - 顶部摘要：当前语言空间、AI Provider 配置状态、隐私边界。
   - Provider 选择：使用 segmented 或 picker，常用 preset 优先；自定义放在末尾。
   - 连接信息：base URL、请求格式、auth header 类型，只读默认值加“自定义”入口。
   - 凭证：SecureField 风格 API Key 输入；显示“当前只保存在页面草稿，离开页面即丢弃；真实保存将在 Keychain 接入后启用”。
   - 模型：chat model 必填；embedding、TTS 和图片理解按 provider capability 显示为可选折叠区。
   - 测试：提供主按钮 `测试请求`。必填项缺失时按钮进入 disabled 或 `missingRequiredFields` 状态；字段齐全后进入模拟测试流程，展示 `mockTesting` 到 `mockSucceeded` / `mockFailed`，并明确“本次没有发起网络请求”。后续真实接入时，该按钮改为经过 Provider 层发送合成测试 prompt，不发送任何生活记录。
   - 隐私：精简说明“保存配置不会发送生活记录；只有你触发 AI 生成并确认请求时才会发送选中内容”。
   - Provider 风险说明：对 OpenRouter、SiliconFlow、DashScope、GLM 等聚合或兼容服务显示“请求由该服务商处理，模型可用性和费用以服务商为准”。

4. 文案和本地化
   - 中文界面优先去掉工程化标记，例如“规划中”“待配置”“当前页面只展示入口边界”。
   - 对未真实接入的能力使用产品化 mock 文案，例如“本地草稿”“模拟检测”“尚未保存到钥匙串”。
   - 英文字符串同步补齐。

5. 测试
   - 增加测试确保 `.aiProvider` 不再落入通用只读三段说明页。
   - 增加测试确保 API Key 文案不承诺已经保存到 Keychain，且不包含真实密钥示例。
   - 增加测试确保 provider preset 包含 OpenAI、Anthropic、Gemini、DeepSeek、Mistral、Groq、xAI、Kimi、OpenRouter、DashScope/Qwen、Zhipu GLM、SiliconFlow、Ollama/local 和 Custom。
   - 增加测试确保 DeepSeek 默认模型不使用将于 2026-07-24 弃用的 `deepseek-chat` / `deepseek-reasoner`。
   - 增加测试确保 `测试请求` 按钮存在，且当前实现不包含 `URLSession`、真实 endpoint 调用或生活记录 payload。
   - 增加测试确保 provider capability 不把所有 provider 都标记为支持 chat、embedding、TTS 和 image understanding。

6. 文档同步
   - 更新 `docs/platform-page-inventory.md` 中 AI Provider 设置页状态，从只读边界说明改为真实级 mock 配置页。
   - 如实现引入新的长期规则，补充 `docs/spec/005-ai-provider-prompt-and-privacy.md` 的“Provider 配置 UI”章节。

## 12. 复查方法

- 代码复查：确认 `.aiProvider` 有专用页面分支，不再只渲染 `LocalizedTextPanel` 三段说明。
- UI 复查：在 iPhone simulator 打开设置 > AI Provider，检查页面是否为可填写配置页，且没有开发标记文案。
- 隐私复查：搜索 API Key、Keychain、请求预览相关文案，确认没有暗示真实保存或真实发送已经完成。
- 测试按钮复查：确认页面有 `测试请求` 按钮，字段缺失、模拟测试中、模拟成功和模拟失败状态可见；确认当前按钮不会发起 `URLSession` 或真实 Provider 调用。
- Provider 复查：将 preset 默认 base URL 和请求格式与官方文档逐项比对。
- 三端影响复查：确认 iPad/macOS 仍能打开 AI Provider 设置详情，不因 iPhone 页面改造导致空白或布局崩溃。

## 13. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
swift test --package-path Packages/LangoTraceData
swiftlint --no-cache
swiftformat --lint . --cache ignore
rg "规划中|待配置|当前页面只展示入口边界|不会发送内容或改变已保存数据" Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'
rg "URLSession|dataTask|uploadTask|downloadTask|apiKey.*print|Authorization.*Bearer" Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'
git diff --check
scripts/verify.sh
```

若只完成方案文档，不运行 Swift 验证；实现阶段必须运行上述 Swift/UI 验证。

## 14. 文档影响检查

本任务影响 AI Provider、隐私边界、设置页页面清单和 UI mock 事实源。实现后至少需要更新 `docs/platform-page-inventory.md`；如果新增 provider 配置模型成为长期约束，需要同步 `docs/spec/005-ai-provider-prompt-and-privacy.md`。不需要新增 ADR，因为仍沿用“本地优先、用户自带 Provider、Provider 抽象、Keychain 保存密钥”的既有核心决策。

## 15. 实施记录

- 2026-05-19：创建 Draft 方案；完成项目内规范、当前代码和主流 provider 官方文档核对；等待用户确认后实施。
- 2026-05-19：按 TDD 先新增 `PremiumUIBehaviorTests`，验证缺少 `AIProviderPreset` / `AIProviderDraftConfiguration` 时失败。
- 2026-05-19：新增 `AIProviderSettingsModels.swift`、`AIProviderDraftConfiguration.swift` 和 `AIProviderSettingsView.swift`；`SettingsCapabilityDetailView` 对 `.aiProvider` 渲染专用配置页；新增本地化字符串。
- 2026-05-19：完成 `swift test --package-path Packages/LangoTraceUI`，结果 76 tests passed。
- 2026-05-19：拆分 `AIProviderSettingsTests.swift` 和 `AIProviderDraftConfiguration.swift`，修复 SwiftFormat / SwiftLint 反馈。
- 2026-05-19：完成 `swift test --package-path Packages/LangoTraceUI`，结果 77 tests passed；完成 `swift test --package-path Packages/LangoTraceData`，结果 11 tests passed。
- 2026-05-19：完成 `swiftlint --no-cache`，结果 0 violations；完成 `swiftformat --lint . --cache ignore`，结果 0 files require formatting。
- 2026-05-19：完成 `scripts/verify.sh`，结果通过；脚本覆盖 XcodeGen、Core/Data/UI tests、iPhone/iPad/macOS builds、SwiftLint、SwiftFormat 和 docs placeholder scan。
- 2026-05-19：完成 simulator 安装和启动：`xcrun simctl install booted .../Debug-iphonesimulator/LangoTrace.app` 成功，`xcrun simctl launch booted com.zibuyu.LangoTrace` 返回进程 `93072`。

## 16. 完成标准

- iPhone AI Provider 设置详情为真实级配置页面，而不是静态说明页。
- 页面支持主流 provider preset 和自定义 OpenAI-compatible 配置。
- 页面包含 API Key、base URL、chat model 等关键字段，并明确当前为 transient mock 草稿，不承诺已保存到 Keychain。
- 页面包含 `测试请求` 按钮，当前为模拟测试状态；字段缺失、测试中、成功、失败和未发起真实网络请求的边界清楚。
- 没有真实网络请求、真实密钥持久化或误导性能力承诺。
- 测试覆盖 provider preset、隐私文案和 `.aiProvider` 专用页面分支。
- 必要文档已同步，验证命令通过。

## 17. 剩余风险

- Provider 官方模型名和推荐默认模型变化较快，实现时需要再次核对官方文档。
- Anthropic 和 Gemini 不是纯 OpenAI-compatible；首轮 UI 可以统一展示，但真实请求 adapter 必须分开实现。
- API Key 在移动端用户自带 provider 的安全和产品责任需要后续在 Keychain、日志、导出和发布隐私材料中继续收口。
- 连接测试若后续做真实网络请求，需要单独设计超时、取消、错误分类、请求日志和不发送生活内容的测试请求 payload。
- iPhone 真机无法直接访问用户 Mac 上的 `localhost`；Ollama/local preset 后续需要说明局域网地址、Mac helper 或同设备运行边界。
- 国内 provider 的官方文档 URL、模型名、地域和账号体系变化较快，实施前需要再次核对官方文档并避免把临时模型名写死为长期默认。
