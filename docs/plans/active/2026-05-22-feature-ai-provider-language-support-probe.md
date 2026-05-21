# AI Provider 语言支持合成测试方案

状态：User Approved
类型：feature
创建日期：2026-05-22
最后更新日期：2026-05-22

## 用户确认记录

- 2026-05-22：用户提出当前 AI Provider 配置测试只验证文本回复、JSON 输出和可选图片理解，无法确认用户设置的文本模型是否适合当前语言空间的目标学习语言。
- 2026-05-22：经讨论确认新增 `语言支持` 测试项，作为文本模型配置测试的一部分；它用于让模型生成目标语言样例，并由本机做离线语言识别与格式校验。
- 2026-05-22：用户确认采用软门槛方案：语言支持测试结果用于提示模型是否适合当前语言空间，不默认阻止语言空间创建；只有未来用户立即触发 AI 生成学习内容时，才可把对应语言支持结果作为前置可用性条件。
- 2026-05-22：用户确认 UI 名称采用 `语言支持`，不使用 `目标语言生成可用性检查` 等长名称。
- 2026-05-22：用户要求语言支持测试不要只让 AI 输出简短一句话，应输出 50 字左右的较长文本；原因是部分仅支持中文的模型可能也能输出简短英文，长文本更能暴露目标语言支持问题。
- 2026-05-22：系统架构复查后收紧边界：语言支持结果是语言空间上下文下的适配性提示，不得污染 Provider profile 的全局最近验证状态；本轮实施以 AI Provider 设置页的当前语言空间测试为主，onboarding / 新增语言空间软门槛只完成设计和文档落点，另开后续方案再实现交互；语言上下文必须以稳定 language code 为事实源，Prompt 名称、NaturalLanguage 映射和脚本规则由 AI 层 allowlist 派生。
- 2026-05-22：用户确认上述边界全部成立，并确认实施节奏采用平台分阶段方式：本轮代码先完成 iOS 端 AI Provider 设置页；用户人工审核确认无误后，再继续 iPad 和 macOS 端改动。

## 0. 实施者快速上下文

本任务是在现有 AI Provider 配置合成测试基础上新增一个 `语言支持` probe。它不是真实学习内容生成，不执行 Prompt Preset，不读取生活记录，不创建 Entry，也不评价语言教学质量。

当前已存在的测试能力：

- `文本回复`：最小连通性 probe。
- `JSON 输出`：结构化输出能力 probe。
- `图片理解`：用户显式启用后发送项目内置白底蓝色正方形 PNG 的图片输入 probe。
- `语音生成` 和 `向量化`：结果面板中显示未启用、未配置或暂不支持测试，不发真实网络请求。

本任务新增：

- `语言支持`：本轮使用当前语言空间的目标学习语言，要求文本模型生成约 50 字左右的目标语言样例；本机解析严格 JSON 后，用离线语言识别和脚本规则做 smoke test。后续若实现 onboarding 或新增语言空间软验证入口，再使用正在创建语言空间的 draft 目标语言。

硬边界：

- UI 名称使用 `语言支持`。
- Prompt id 使用 `ai-provider.configuration-probe.language-support.v1`。
- 代码能力枚举建议使用 `languageSupport` 或 `targetLanguageSupport`；若与现有 `AIProviderProbeCapability` 风格保持一致，推荐 `.languageSupport`。
- 不把语言支持测试写成“模型语言能力认证”。
- 不阻止本地语言空间创建；失败只提示当前模型可能不适合该语言空间。
- 不发送生活记录、照片、音频、OCR、历史记忆、目标语言正文、Prompt Preset 内容或用户自定义长文本。
- 不在诊断日志、validation event 或 UI 测试输出中保存完整响应文本。
- 已保存 profile 的文本回复、JSON 输出和可选图片理解等 App 级合成测试可以继续写入非敏感 `synthetic_test` validation outcome；语言支持结果只进入短生命周期 probe result 和非敏感 diagnostic event，不得写入 Provider profile 的 `last_validation_status` / `last_validated_at` 摘要，也不得作为 Provider profile 的静态能力事实。

推荐阅读顺序：

1. `docs/plans/done/2026-05-21-feature-ai-provider-text-model-test-request.md`
2. `docs/plans/done/2026-05-21-feature-ai-provider-image-understanding-probe.md`
3. `docs/plans/done/2026-05-21-refactor-ai-provider-model-capability-resolver.md`
4. `docs/spec/005-ai-provider-prompt-and-privacy.md` 第 4.7 节
5. `docs/spec/006-interface-localization-and-language-boundaries.md` 第 3.3、3.4 节
6. `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningLanguage.swift`
7. `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
8. `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
9. `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`

## 1. 需求描述

AI Provider 配置页当前能验证模型 endpoint 是否可连通、能否返回结构化 JSON，以及在用户启用图片输入后能否处理内置图片。但是，语言学习 App 的核心风险还包括：用户选择的文本模型可能不能稳定输出当前语言空间的目标学习语言。

例如用户创建日语、法语或韩语空间时，当前文本模型可能只支持中文或只适合英文；基础 `OK` probe 和 JSON probe 仍可能通过，却不能证明这个模型适合目标语言学习内容生成。

本任务新增 `语言支持` probe：要求模型按目标学习语言生成较长样例文本，再由本机做结构、长度、语言识别和脚本规则校验，尽可能在现有条件下发现明显的语言不匹配问题。

## 2. 现状描述

代码事实：

- `LearningLanguage` 已定义当前支持的目标学习语言：`en`、`ja`、`fr`、`de`、`es`、`ko`、`zh-Hans`。
- `LearningLanguage.promptLanguageName` 已提供英文语言名称，可用于 Prompt 构造。
- `AIProviderProbeCapability` 当前包含 `.textReply`、`.structuredJSON`、`.imageUnderstanding`、`.speechSynthesis` 和 `.embedding`。
- `AIProviderConfigurationProbeService` 当前顺序执行文本回复、JSON 输出和可选图片理解 probe。
- `AIProviderConfigurationProbeResult` 可以承载多个分能力结果，UI 结果面板按 `AIProviderProbeCapability.allCases` 展示。
- `AIProviderDraftConfiguration.makeConfigurationProbeDraftSnapshot(operationID:)` 当前只携带 endpoint、secret、requested capabilities 和 operation id，没有目标学习语言上下文。
- `AIProviderSettingsActions.testProviderConfiguration(...)` 是 UI 到 App / AI 服务层的 action seam。
- `AppSessionState.createLanguageSpace()` 当前同步创建语言空间，不包含 AI 测试或异步状态。

文档事实：

- `docs/spec/002-navigation-and-routing.md` 明确 AI Provider 不应成为首次启动门槛。
- `docs/spec/006-interface-localization-and-language-boundaries.md` 明确目标学习语言用于 AI 转换结果、TTS、跟读、听写、回译、词句记忆和练习内容；Provider / Prompt 输出语言必须由请求构建层显式传入，不能从 UI 文案反推。
- `docs/spec/005-ai-provider-prompt-and-privacy.md` 明确测试请求只允许发送固定合成检测内容，不得发送用户生活内容、照片、历史记忆、Prompt Preset 内容或用户正文。
- `docs/prompts/ai-provider/provider-configuration-probe.md` 当前登记文本回复、JSON 输出和图片理解三个固定 Prompt。

## 3. 目标

本任务完成后必须达到：

- AI Provider 配置测试结果面板新增 `语言支持` 分项。
- 本轮 `语言支持` probe 使用当前语言空间目标语言；语言空间创建 draft 目标语言只作为后续 onboarding / 新增语言空间软验证入口的设计边界。
- 当没有当前语言空间且测试入口不在创建流程中时，`语言支持` 显示未配置或需要选择测试语言，不阻断其他 probe。
- `语言支持` Prompt 要求模型返回严格 JSON object，且只包含一个字段 `sample`。
- `sample` 是目标语言的较长样例文本，不是简短一句话。
- 输出长度采用按语言族分层的“约 50 字左右”策略：
  - `zh-Hans`、`ja`、`ko`：目标为 45 到 80 个可见字符。
  - `en`、`fr`、`de`、`es`：目标为 40 到 70 个词。
- 本机校验至少包含 JSON 结构校验、非空校验、长度校验、离线语言识别和脚本规则。
- `语言支持` 失败不等于“模型不支持该语言”的绝对结论，只表示本次合成测试未能确认该模型适合当前目标语言。
- 已保存 profile 测试的 App 级 synthetic outcome 可以继续写入 validation event；语言支持分项失败不得把 Provider profile 最近验证摘要改为失败。diagnostic event 只记录非敏感枚举和值，不记录 `sample` 原文。
- 本轮代码实施范围只要求 AI Provider 设置页在已有当前语言空间时运行语言支持 probe；语言空间创建流程的软验证交互仅在本方案中明确设计和文档影响，不作为本轮代码完成标准。后续实现 onboarding / 新增语言空间测试入口时，默认仍不得阻止创建语言空间。
- 本轮平台实施顺序必须先收敛在 iOS 端：先完成 iPhone / iOS AI Provider 设置页的语言支持 probe、状态展示、测试和文档同步；iPad 与 macOS 的界面接入在用户完成 iOS 人工审核并确认无误后再进行。
- 后续真实 AI 学习内容请求可以把语言支持失败作为风险提示或前置检查，但必须另开真实请求预览和 Prompt Preset 执行方案。

## 4. 范围

本任务覆盖：

- Core 层新增语言支持 probe capability 和结果状态所需稳定类型。
- AI 层新增语言支持 Prompt、请求体构造、响应解析和本地语言校验。
- AI 层引入 Apple `NaturalLanguage` 或等价 Apple 平台本地语言识别能力。
- UI draft / action seam 支持传入目标学习语言上下文。
- AI Provider 设置页在有当前语言空间时运行语言支持 probe；本轮优先完成 iOS 端入口和展示。
- Onboarding / 语言空间创建路径的软验证设计：创建前或创建后可提示测试，不默认阻塞本地空间创建。
- Prompt Registry、AI Provider 隐私规范、语言边界规范和页面清单同步更新。
- 单元测试覆盖 Prompt、JSON 结构、语言识别、脚本规则、日志敏感字段、UI 结果面板和语言空间创建软门槛边界。

## 5. 不做什么

本任务不实现：

- 不执行真实学习内容生成。
- 不执行 Prompt Preset。
- 不创建 Entry、Rendering、Practice、Memory 或学习内容保存对象。
- 不读取用户生活记录、照片、音频、OCR、历史记忆或附件。
- 不判断文本语法是否完全正确。
- 不判断文本是否自然、地道或适合用户 CEFR 水平。
- 不把测试结果命名为语言能力认证。
- 不默认阻止首次启动 onboarding 创建语言空间。
- 不把目标语言支持结果同步到云端。
- 不新增动态模型列表、Provider 能力在线查询或 OpenRouter models API。
- 不在本任务中接入 Anthropic / Gemini 文本 probe；它们仍沿用当前暂不支持测试边界，除非另开 Provider adapter 方案。
- 不在 iOS 人工审核前改动 iPad 和 macOS 的 AI Provider 设置页接入；共享 Core / AI / UI 状态模型可以先完成，但平台界面呈现先限制在 iOS。

## 6. 证据与决策依据

代码依据：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningLanguage.swift`：目标语言 code、native name、英文 Prompt 名称和支持语言集合。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`：当前固定合成 Prompt、请求体构造、响应解析和错误映射位置。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`：`AIProviderProbeCapability`、`AIProviderConfigurationProbeResult`、`AIProviderProbeCapabilityResult` 和 validation error category。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`：draft probe snapshot 构造和 requested capabilities。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`：结果面板按 capability all cases 展示。
- `LangoTraceApp/AppEnvironment.swift`：Provider 测试 action 的装配点，以及语言空间创建目前属于 `AppSessionState` 本地 lifecycle。

文档依据：

- `docs/spec/002-navigation-and-routing.md`：AI Provider 不应成为首次启动门槛。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：目标学习语言和 Provider / Prompt 输出语言是独立边界，输出语言必须由请求构建层显式传入。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：Provider 配置测试只能发送固定合成检测内容，不发送用户内容；测试请求必须走 Provider 层；SwiftUI 不直接触网或读 Keychain。
- `docs/prompts/README.md`：固定合成测试 Prompt 属于真实 Provider 请求内容，必须登记完整文案、输出契约和隐私边界。

关键决策：

| 决策 | 结论 | 理由 | 防误读 |
| --- | --- | --- | --- |
| UI 名称 | `语言支持` | 短、可与文本回复 / JSON 输出 / 图片理解并列 | 不是语言能力认证。 |
| 测试长度 | CJK/日/韩 45-80 可见字符；拉丁语系 40-70 词 | 长文本比一句短句更能暴露模型是否真正按目标语言输出 | 不要求精确 50 个字符或 50 个词。 |
| 校验方式 | JSON 结构 + 长度 + NaturalLanguage + 脚本规则 | 当前本机可做到的较强 smoke test | 不证明语法、自然度或教学质量。 |
| 语言空间创建 | 软门槛 | 语言空间是本地学习容器，AI Provider 是增强能力 | 失败不阻止创建，但应清楚提示风险。 |
| Provider 设置页测试语言 | 优先当前语言空间；无当前空间则显示未配置或引导选择 | Provider 配置本身是 App 级默认 profile，不绑定语言空间 | 不把测试语言写入 Provider profile。 |
| 日志与 validation | 只记录非敏感状态、语言 code、错误分类、耗时 | 防止样例文本进入诊断或持久日志 | `sample` 原文不得写入日志、validation event 或持久 profile；语言支持失败不得污染 Provider profile 全局验证摘要。 |

## 7. 语言支持 Prompt 契约

Prompt id：

- `ai-provider.configuration-probe.language-support.v1`

英文 Prompt 模板：

```text
Configuration test. Generate a natural sample in {target_language_name}.
Return exactly one JSON object with exactly one field named sample.
The sample must be written only in {target_language_name}.
For Chinese, Japanese, or Korean, write approximately 45 to 80 visible characters.
For English, French, German, or Spanish, write approximately 40 to 70 words.
The sample should describe a person recording an ordinary moment from daily life.
Do not include translation, language names, markdown, code fences, explanations, or any other text.
```

中文说明版本：

```text
配置测试。请使用 {目标语言名称} 生成一段自然样例。
只返回一个 JSON object，且只包含一个名为 sample 的字段。
sample 必须只使用 {目标语言名称}。
中文、日语或韩语请写约 45 到 80 个可见字符。
英语、法语、德语或西班牙语请写约 40 到 70 个词。
样例内容描述一个人记录日常生活中的普通片刻。
不要包含翻译、语言名称、Markdown、代码块、解释或任何其他文本。
```

响应示例结构：

```json
{"sample":"..."}
```

实现要求：

- Prompt 中可以包含目标语言英文名称，例如 `Japanese`、`French`、`Chinese`。
- Prompt 不提供目标语言示例答案，避免模型回显。
- 主题限定为“记录日常生活中的普通片刻”，与产品定位一致，但不包含用户真实生活内容。
- `sample` 原文只存在于短生命周期响应解析和本地校验内存中，不进入日志、validation event、diagnostic attributes、SQLite profile 或 UI 持久状态。

## 8. 本地语言校验方案

### 8.1 结构校验

必须先解析响应文本：

- 去除响应首尾空白。
- 拒绝 Markdown code fence。
- 使用 JSON parser 解析。
- 顶层必须是 object。
- object 必须 exactly one field。
- 字段名必须为 `sample`。
- `sample` 必须是非空字符串。

结构失败映射：

- capability：`languageSupport`
- status：`failed`
- errorCategory：`invalidResponse`

### 8.2 长度校验

长度规则按目标语言 code 分层：

| 目标语言 | 校验单位 | 合格范围 |
| --- | --- | --- |
| `zh-Hans` | 可见字符 | 45-80 |
| `ja` | 可见字符 | 45-80 |
| `ko` | 可见字符 | 45-80 |
| `en` | 词 | 40-70 |
| `fr` | 词 | 40-70 |
| `de` | 词 | 40-70 |
| `es` | 词 | 40-70 |

说明：

- 可见字符统计应去除空白和常见标点。
- 词数统计按 Unicode word boundary 或 `NLTokenizer(unit: .word)`，实现时优先使用 Apple NaturalLanguage 的 tokenizer。
- 长度不合格时返回 `invalidResponse`，因为 Provider 已响应但不符合测试契约。

### 8.3 离线语言识别

第一阶段使用 Apple `NaturalLanguage`：

- `NLLanguageRecognizer` 识别 `sample` 主语言。
- 目标语言 code 映射到 `NLLanguage`。
- 识别结果和目标语言一致时通过。
- 对拉丁语系可设置最低置信度阈值，例如 `0.45`；对 CJK / 日 / 韩可结合脚本规则降低误判。

建议映射：

| LearningLanguage code | NLLanguage |
| --- | --- |
| `en` | `.english` |
| `ja` | `.japanese` |
| `fr` | `.french` |
| `de` | `.german` |
| `es` | `.spanish` |
| `ko` | `.korean` |
| `zh-Hans` | `.simplifiedChinese`，必要时接受 `.traditionalChinese` 作为中文族兜底 |

### 8.4 脚本规则兜底

脚本规则用于防止语言识别在短文本、拉丁语系或混合文本下误判：

| 目标语言 | 必要规则 |
| --- | --- |
| `zh-Hans` | 至少包含一定比例 CJK Unified Ideographs；不应主要由拉丁字母组成。 |
| `ja` | 至少包含 Hiragana 或 Katakana；仅 CJK 汉字不足以通过日语。 |
| `ko` | 至少包含 Hangul syllables 或 jamo。 |
| `en` | 主要由拉丁字母组成；语言识别为 English；不应包含大量 CJK / Kana / Hangul。 |
| `fr` | 主要由拉丁字母组成；语言识别为 French；允许常见法语重音字符。 |
| `de` | 主要由拉丁字母组成；语言识别为 German；允许德语变音字符和 ß。 |
| `es` | 主要由拉丁字母组成；语言识别为 Spanish；允许 ñ 和西语重音字符。 |

脚本规则失败映射为 `invalidResponse`。如果未来需要更细的错误分类，可新增 `languageMismatch`，但第一阶段可以先复用 `invalidResponse`，避免扩大 Core 错误枚举。

### 8.5 不能承诺的能力

语言支持通过不能证明：

- 语法完全正确。
- 文本自然地道。
- 符合用户所选水平。
- 模型适合长期教学。
- 模型能处理真实用户生活内容。

UI 文案不得使用：

- `认证通过`
- `完全支持`
- `语言能力已验证`
- `适合所有{语言}学习任务`

推荐文案：

- 成功：`语言支持可用`
- 失败：`语言支持异常`
- 说明：`本次测试未能确认当前模型适合该语言空间。你仍可继续创建本地语言空间，并稍后调整 AI Provider。`

## 9. 交互设计

### 9.1 AI Provider 设置页

结果面板能力顺序调整为：

1. `文本回复`
2. `JSON 输出`
3. `语言支持`
4. `图片理解`
5. `语音生成`
6. `向量化`

测试语言来源：

- 如果存在当前语言空间，使用当前语言空间目标语言。
- 本轮如果没有当前语言空间，`语言支持` 显示 `notConfigured`，其他 probe 继续运行；后续若单独实现 onboarding / 新增语言空间软验证入口，才由调用方提供 draft 目标语言。

按钮与状态：

- 仍保留一个 `测试请求` 按钮，不为语言支持新增主按钮。
- 语言支持失败时，Core `overallStatus` 可以仍为 `failed`；UI 层根据其他 capability 成功状态显示部分可用或失败，不新增 `AIProviderValidationStatus.partial`。
- 如果文本回复失败，不运行 JSON 输出、语言支持和图片理解。
- 如果 JSON 输出失败，不运行语言支持，避免在结构化能力不可靠时继续依赖 JSON 契约；图片理解是否运行保持既有策略，除非另行修改 probe 组合规则并补充测试。
- 如果语言支持失败但文本回复和 JSON 输出成功，结果面板应显示部分可用，而不是把 Provider 连接性误判为完全不可用。
- 平台实施顺序为 iOS first：本轮先在 iPhone / iOS AI Provider 设置页展示和验证 `语言支持`；iPad / macOS 设置界面保持现状，待用户完成 iOS 人工审核并确认无误后再接入同一能力。

### 9.2 Onboarding 创建第一个语言空间

默认路径保持：

```text
选择母语 -> 选择目标语言 -> 选择水平 -> 创建语言空间 -> 进入主界面
```

不把 AI Provider 作为首次启动硬门槛。

本轮不实现 onboarding 测试入口，只保留后续交互设计和文档边界。后续若实现该入口，如果本机已有已保存 AI Provider profile：

- 创建按钮附近可以显示轻量提示：`可测试当前模型是否适合{目标语言}`。
- 用户可以选择先测试，也可以直接创建。
- 测试失败时显示风险提示，并提供：
  - `继续创建`
  - `调整 AI Provider`

如果本机没有 AI Provider profile：

- 不显示阻塞性错误。
- 可显示设置入口或后续提醒：`创建后可在设置中配置 AI Provider`。

### 9.3 后续新增语言空间

本轮不实现新增语言空间测试入口，只保留后续交互设计和文档边界。后续若在语言空间管理页和快速切换 sheet 中新增语言空间时接入测试：

- 如果已有 AI Provider profile，可以在保存前或保存后触发语言支持测试。
- 测试失败不删除草稿，不阻止保存。
- 用户选择继续创建时，语言空间正常写入本地数据库并可成为当前空间。
- 可在创建完成后的提示中说明：`当前 AI 模型的{目标语言}支持测试未通过，AI 学习内容可能不可用。`

## 10. 架构方案

### 10.1 数据流

Provider 设置页路径：

```text
Current LanguageSpacePreview?
  -> AIProviderSettingsView
  -> AIProviderDraftConfiguration.makeConfigurationProbeDraftSnapshot(...)
  -> AIProviderSettingsActions.testProviderConfiguration(...)
  -> AppEnvironment maps language context
  -> AIProviderConfigurationService
  -> AIProviderConfigurationProbeService
  -> language support Prompt
  -> HTTP response
  -> JSON parse
  -> local language validation
  -> AIProviderConfigurationProbeResult
  -> AIProviderProbeResultPanelContent
```

Onboarding / 新增语言空间后续设计路径，本轮不实现：

```text
OnboardingDraft or CreateLanguageSpaceInput
  -> target LearningLanguage
  -> optional AI Provider language support probe
  -> warning or success presentation
  -> user confirms create / adjust provider
  -> LanguageSpaceRepository.createLanguageSpace(...)
```

### 10.2 Core 类型调整

建议修改：

- `AIProviderProbeCapability`
  - 新增 `.languageSupport = "language_support"`。
  - 插入在 `.structuredJSON` 和 `.imageUnderstanding` 之间。

建议新增：

```swift
public struct AIProviderProbeLanguageContext: Equatable, Sendable {
    public var languageCode: String

    public init(languageCode: String) {
        self.languageCode = languageCode
    }
}
```

用途：

- Core 只承载非敏感稳定语言 code。
- 不把 UI 展示名或调用方传入的任意 Prompt 名称塞入 AI package。
- 不把界面语言、用户母语或本地化展示名误用为 Provider 输出语言。
- AI 层必须通过 allowlist 从 language code 派生 Prompt 英文名称、`NLLanguage` 映射和脚本规则；code 不在当前 `LearningLanguage.supportedTargetLanguages` 范围内时，不发语言支持网络请求，返回 `.notConfigured` 或输入校验失败。

### 10.3 AI 层调整

建议新增：

- `AIProviderLanguageSupportValidator`
  - 负责 JSON sample 校验后的语言识别和脚本规则。
  - 依赖 Apple `NaturalLanguage`。
  - 不触网。
  - 不记录 sample 原文。

建议修改：

- `AIProviderConfigurationProbeDraftInput`
  - 新增 `languageContext: AIProviderProbeLanguageContext?`。
- `AIProviderConfigurationProbeSavedInput`
  - 新增 `languageContext: AIProviderProbeLanguageContext?`。
- `AIProviderConfigurationProbeService`
  - 新增 `ProbeKind.languageSupport(context:)` 或等价输入。
  - 在 `textReply` 和 `structuredJSON` 成功后运行语言支持。
  - 如果没有 language context，结果为 `.notConfigured`。
  - 如果 `structuredJSON` 失败，不运行语言支持；图片理解是否运行保持既有策略，除非另行修改 probe 组合规则并补充测试。
  - 语言支持失败时，Core `AIProviderConfigurationProbeResult.overallStatus` 可以仍为 `.failed`；UI 通过部分 capability 成功派生 `partial` 展示，不新增 `AIProviderValidationStatus.partial`。

### 10.4 UI / App 装配调整

建议修改：

- `AIProviderSettingsView`
  - 接收可选 `languageSpace: LanguageSpacePreview?` 或更小的 `languageContext`。
  - 保持 SwiftUI View 不直接触网、不读 Keychain、不构造 HTTP。
- `AIProviderDraftConfiguration`
  - `configurationProbeRequestedCapabilities` 在有语言上下文时包含 `.languageSupport`。
  - snapshot 携带非敏感语言上下文。
- `AIProviderSettingsActions`
  - action seam 扩展语言上下文参数，或继续由 snapshot 携带。
- `LangoTraceApp.swift`
  - 向 Settings detail / AI Provider 设置页传入当前语言空间。
- `AppEnvironment`
  - 将 snapshot language context 映射到 AI service input。

### 10.5 Data / validation 边界

不新增 AI Provider 表字段。

原因：

- Provider profile 是 App 级默认配置，不绑定某个语言空间。
- 语言支持测试是当前语言空间上下文下的合成测试结果，不应写成 Provider profile 的静态能力。
- 已保存 profile 的 App 级 synthetic outcome 可以继续通过现有 `recordValidationOutcome(_:)` 更新最近验证摘要，但该持久摘要必须排除语言支持分项：文本回复、JSON 输出、图片理解、语音生成占位和向量化占位仍按既有规则判断 Provider profile 最近验证状态；语言支持分项只影响当前 probe result 和 UI 部分可用提示。
- 如果实现层复用 `AIProviderConfigurationProbeResult.overallStatus`，必须新增一个明确的 persistence summary 计算逻辑，避免 `languageSupport` 失败把 `last_validation_status` 写成 `failed`。也可以在本轮对 language support 结果只记录 diagnostic event，不写 validation event。
- 具体语言 code 只进入非敏感 diagnostic attributes，如 `target_language_code`。若 Core diagnostic attributes 当前没有该字段，应新增 allowlisted attribute。

未来如果需要按语言空间长期保存模型适配性结果，应另开方案，明确是否写入语言空间本地状态、是否随同步、如何失效，以及模型名 / Provider 变更后如何清理。

## 11. 涉及的代码文件路径

预计修改：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
  - 新增 `.languageSupport` capability。
  - 新增非敏感语言上下文类型。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
  - 如需记录目标语言 code，新增 allowlisted diagnostic attribute。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
  - 新增语言支持 Prompt、请求体构造、执行顺序和结果映射。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderLanguageSupportValidator.swift`
  - 新增本地语言校验器。
- `Packages/LangoTraceAI/Package.swift`
  - 确认 `NaturalLanguage` 可用于目标平台和 test target。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
  - snapshot 和 requested capabilities 支持语言上下文。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift`
  - action seam 支持语言上下文。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
  - 接收当前语言空间或语言上下文。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
  - 结果面板展示 `语言支持`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
  - 新增 `语言支持`、成功、失败、未配置和说明文案。
- `LangoTraceApp/LangoTraceApp.swift`
  - 传递当前语言空间到设置详情。
- `LangoTraceApp/AppEnvironment.swift`
  - 映射语言上下文到 AI service。

可能修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
  - 如果本轮同步落地 onboarding 软验证入口，新增非阻塞测试提示和结果状态。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
  - 如果本轮同步落地新增语言空间软验证入口，新增测试提示或创建后警告。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceEditorView.swift`
  - 如果新增语言空间表单承载测试操作，则补充 UI 状态。

预计不修改：

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`
  - 不新增表字段。
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift`
  - 不改变语言空间 schema。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpace.swift`
  - 不把 AI 测试结果写入语言空间主模型。

## 12. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningLanguage.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/LangoTraceApp.swift`

## 13. 涉及的文档路径

本方案创建：

- `docs/plans/active/2026-05-22-feature-ai-provider-language-support-probe.md`

实施完成后预计更新：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
  - 补充 `语言支持` probe 边界、Prompt、日志和不阻塞语言空间创建原则。
- `docs/spec/006-interface-localization-and-language-boundaries.md`
  - 补充目标学习语言作为 Provider 配置合成测试上下文的规则。
- `docs/platform-page-inventory.md`
  - 更新 AI Provider 设置页当前事实和语言空间创建软验证事实。
- `docs/prompts/ai-provider/provider-configuration-probe.md`
  - 登记 `ai-provider.configuration-probe.language-support.v1` 完整 Prompt、输出契约和隐私边界。
- `docs/prompts/README.md`
  - 更新 Prompt Registry 当前事实。

预计不更新：

- `docs/decisions/005-local-first-and-user-owned-providers.md`
  - 本任务沿用本地优先、用户自带 Provider 和 Keychain 边界，不改变 ADR。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
  - 不新增数据库 schema 或导出对象。

## 14. 实施方案

### 阶段 1：Core 能力与 AI 校验器

1. 在 `AIProviderProbeCapability` 中新增 `.languageSupport`。
2. 新增 `AIProviderProbeLanguageContext`。
3. 在 `AIProviderConfigurationProbeTests` 中更新 capability all cases 顺序。
4. 新增 `AIProviderLanguageSupportValidator`。
5. 用 TDD 覆盖：
   - 英语 40-70 词通过。
   - 英语短句失败。
   - 日语无假名失败。
   - 韩语无 Hangul 失败。
   - 中文纯英文失败。
   - 法语 / 德语 / 西语使用 NaturalLanguage 识别和拉丁脚本规则。

后续单独实现该 UI 时的验证命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationProbeTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderLanguageSupportValidatorTests
```

### 阶段 2：AI Provider probe 执行链路

1. 扩展 draft / saved probe input，携带可选 language context。
2. 在 `AIProviderConfigurationProbeService` 中新增 `ProbeKind.languageSupport`。
3. 在 text reply 和 structured JSON 成功后运行 language support。
4. 没有 language context 时返回 `notConfigured`。
5. language code 不在当前支持目标语言 allowlist 时返回 `notConfigured` 或输入校验失败，不发语言支持网络请求。
6. 结构失败、长度失败、语言识别失败和脚本规则失败均映射为 `invalidResponse`。
7. 确认 diagnostics 不包含 `sample` 原文。
8. 已保存 profile 路径新增测试：语言支持失败但文本回复和 JSON 输出成功时，UI / probe result 可以显示部分可用，但 Provider profile 的持久最近验证摘要不得因语言支持失败被写成全局失败。

验证命令：

```bash
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationProbeServiceTests
```

### 阶段 3：UI 结果面板和 Provider 设置页上下文

1. 共享 UI presentation model 和结果面板能力顺序可以先完成，但本轮平台入口只接入 iOS。
2. iPhone / iOS AI Provider 设置页增加 `语言支持` 行，顺序位于 `JSON 输出` 和 `图片理解` 之间。
3. iOS 路径下的 `AIProviderSettingsView` 接收当前语言空间或语言上下文。
4. `AIProviderDraftConfiguration` 在有语言上下文时把 `.languageSupport` 加入 requested capabilities。
5. `AIProviderSettingsActions` 和 `AppEnvironment` 转发 language context。
6. 补充本地化 key。
7. 用 source-boundary 测试确认 UI 不出现 `NaturalLanguage`、`NLLanguageRecognizer`、`URLSession`、`Authorization` 或 `Bearer `。
8. iPad / macOS 的设置界面接入暂不实施；用户完成 iOS 人工审核并确认无误后，再继续三端扩展或另开后续执行轮次。

验证命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
```

iOS 人工审核节点：

- 代码完成并通过聚焦测试与完整验证后，先提交给用户进行 iOS 人工审核。
- 人工审核通过前，不继续改动 iPad / macOS 平台设置页接入。
- 人工审核关注：当前语言空间是否正确传入、结果面板顺序和文案是否清楚、语言支持失败是否显示为风险提示而非硬阻断、Provider profile 全局验证摘要是否未被污染。

### 阶段 4：语言空间创建软门槛设计记录

本轮只完成设计明确和长期文档落点，不实现 onboarding 或新增语言空间测试入口，也不把创建流程改成硬阻塞：

1. 在本方案和相关 spec 中记录：Onboarding 创建语言空间仍可直接创建。
2. 在本方案和相关 spec 中记录：后续如果有已保存 Provider profile，可以提供非阻塞提示或入口：`测试当前模型的语言支持`。
3. 在本方案和相关 spec 中记录：后续测试失败时提供 `继续创建` 和 `调整 AI Provider`。
4. 在本方案和相关 spec 中记录：新增语言空间管理入口沿用同一软门槛原则。
5. 不修改 `LanguageSpace` schema。

后续若要真正实现 onboarding / 新增语言空间测试入口，必须新建或延续 active plan，补充异步状态、取消、失败恢复、当前 draft 与保存动作的竞态，以及三端 presentation 边界。

验证命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter Onboarding
swift test --package-path Packages/LangoTraceUI --filter LanguageSpace
```

### 阶段 5：文档同步与完整验证

1. 更新 Prompt Registry。
2. 更新 `spec/005` 和 `spec/006`。
3. 更新 `platform-page-inventory.md`。
4. 运行聚焦测试。
5. 运行完整验证。

验证命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationProbeTests
swift test --package-path Packages/LangoTraceAI --filter LangoTraceAITests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
scripts/verify.sh
```

## 15. 复查方法

代码复查：

- 搜索 `languageSupport`，确认 Core、AI、UI 和测试覆盖一致。
- 搜索 iPad / macOS 设置页装配路径，确认 iOS 人工审核前没有把 `语言支持` 平台入口扩散到 iPad / macOS；共享 Core / AI / UI presentation model 变更除外。
- 搜索 `sample`，确认它只在 Prompt、短生命周期解析、测试 fixture 和 validator 测试中出现，不进入 diagnostic attributes、SQLite repository、validation event 或 UI 持久状态。
- 搜索 `NLLanguageRecognizer`，确认只出现在 AI package 的本地 validator 和相关测试中，不进入 SwiftUI View。
- 搜索 `URLSession`、`Authorization`、`Bearer `，确认仍只在 AI package 网络层，Provider 设置 UI 不拼接请求。
- 检查 `AIProviderProbeCapability.allCases` 顺序，确认结果面板顺序为文本回复、JSON 输出、语言支持、图片理解、语音生成、向量化。
- 检查本方案、`spec/005`、`spec/006` 和页面清单中的 onboarding / 语言空间管理边界，确认语言支持失败不被写成阻止本地空间创建的条件。

文档复查：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 不应把语言支持写成真实学习内容请求。
- `docs/spec/006-interface-localization-and-language-boundaries.md` 应明确 Provider 输出语言来自目标学习语言上下文，不来自界面语言。
- `docs/prompts/ai-provider/provider-configuration-probe.md` 必须记录完整 Prompt 文案、输出契约、输入变量和隐私边界。
- `docs/platform-page-inventory.md` 不应把语音生成、向量化或真实 Prompt Preset 执行写成已完成。

## 16. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationProbeTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationProbeServiceTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
```

如后续单独实施 onboarding / 语言空间软门槛 UI：

```bash
swift test --package-path Packages/LangoTraceUI --filter Onboarding
swift test --package-path Packages/LangoTraceUI --filter LanguageSpace
```

完整验证：

```bash
scripts/verify.sh
```

真实 Provider 人工验证建议：

- OpenAI Responses：英文、日语、法语至少各测一次。
- OpenAI-compatible Chat：OpenRouter 或 Custom endpoint 选择一个多语言模型，至少测英语和日语。
- 选择一个明显不适合目标语言的模型或故意要求中文模型输出西语，确认语言支持显示异常。
- 网络断开、API Key 错误、模型名错误仍应优先显示连接、认证或模型错误，而不是误报语言支持异常。
- 已保存 profile 路径下，选择一个语言支持失败但文本回复和 JSON 输出成功的场景，确认结果面板显示部分可用，同时 Provider profile 的全局最近验证摘要不被语言支持失败污染。

人工验证不得在日志、截图说明或文档中记录 API Key、完整请求头或完整 Provider 响应体。

## 17. 文档影响检查

本任务涉及 AI Provider、Prompt、目标学习语言、语言空间创建体验、隐私和诊断边界，实施完成后必须做文档影响检查。

必须更新：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/prompts/ai-provider/provider-configuration-probe.md`
- `docs/prompts/README.md`
- `docs/platform-page-inventory.md`

不需要更新 ADR，除非实施中改变以下任一决策：

- 把 AI Provider 配置绑定到语言空间。
- 把 AI Provider 变成首次启动硬门槛。
- 把语言支持测试结果持久写入语言空间主模型。
- 引入官方托管 AI 或默认外部 Provider。

## 18. 实施记录

- 2026-05-22：创建方案文档。当前仅完成设计和实施路径记录，尚未修改生产代码。

## 19. 完成标准

满足以下条件才可将本方案移入 `docs/plans/done/`：

- iOS 端 AI Provider 测试结果面板出现 `语言支持` 分项，顺序正确。
- 语言支持 Prompt 已登记到 Prompt Registry，包含英文版本、中文说明、输入变量、输出契约和隐私边界。
- 语言支持 probe 能使用当前语言空间的目标学习语言；onboarding draft / 新增语言空间测试入口只完成后续设计记录，不作为本轮代码完成标准。
- 输出约 50 字左右的较长目标语言样例，而不是短句。
- 本地校验覆盖 JSON 结构、长度、NaturalLanguage 识别和脚本规则。
- 失败文案不把结果说成模型绝对不支持该语言。
- 语言空间创建不被语言支持失败默认阻止。
- 语言支持失败不污染 Provider profile 的全局 `last_validation_status` / `last_validated_at` 摘要。
- SwiftUI View 不直接调用网络、Keychain、NaturalLanguage 或 Provider SDK。
- 诊断日志和 validation event 不包含 `sample` 原文、API Key、请求头、请求体或响应体。
- 聚焦测试和 `scripts/verify.sh` 通过。
- 用户完成人工审核前，iPad 和 macOS 设置页入口保持未接入；审核通过后再继续对应平台改动。

## 20. 剩余风险

- Apple `NLLanguageRecognizer` 对拉丁语系短文本仍可能误判；本方案通过 40-70 词样例和脚本规则降低风险，但不能完全消除。
- 部分模型可能输出混合语言文本，语言识别结果接近目标语言但内容质量不佳；本任务不评价教学质量。
- `zh-Hans` 与 `zh-Hant` 可能在语言识别中互相接近；第一阶段可按中文族处理，但 UI 文案仍应说明测试目标是中文输出，不是简繁转换质量。
- 某些 Provider 会自动翻译、审查或改写 Prompt；语言支持失败应被视为风险提示，不应删除或阻止本地语言空间。
- 约 50 字左右的长文本会比 `OK` 和 JSON probe 消耗更多 token；它仍是用户主动触发的配置测试，不应在后台自动频繁运行。
- 如果未来支持更多目标语言，需要为每种语言补充 `LearningLanguage` 到 `NLLanguage` 的映射、脚本规则和测试 fixture。
