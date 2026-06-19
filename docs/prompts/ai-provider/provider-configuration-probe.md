# AI Provider Configuration Probe Prompts

状态：Accepted

适用阶段：AI Provider 配置页文本、JSON、语言支持、内置图片和向量化合成测试请求。

## 1. Prompt id

- `ai-provider.configuration-probe.text-reply.v1`
- `ai-provider.configuration-probe.structured-json.v1`
- `ai-provider.configuration-probe.language-support.v1`
- `ai-provider.configuration-probe.image-understanding.v1`
- `ai-provider.configuration-probe.embedding.v1`

## 2. 所属功能

AI Provider 配置页的“测试请求”能力，用于确认用户配置的文本模型 endpoint、model、credential 和 adapter 能完成最小合成请求。当前包含文本回复、JSON 输出、当前语言空间上下文下的语言支持 probe、用户显式启用后的内置图片理解 probe，以及用户显式启用并配置完整后的向量化 probe。图片理解 probe 是否可启用由 Provider preset、adapter 请求格式、文本 endpoint purpose 和模型能力策略共同决定；OpenRouter / Custom OpenAI-compatible 等兼容层属于模型相关能力，由真实 probe 验证。

向量化 probe 第一阶段只支持 OpenAI、OpenRouter 和 Custom OpenAI-compatible。它发送固定低敏文本并只验证返回 shape，不创建向量索引，不保存 vector，不评估语义质量。

语言支持 probe 只用于判断本次配置测试是否能确认当前模型适合当前语言空间的目标学习语言，不是模型语言能力认证。该 Prompt 只用于 Provider 配置探测，不属于真实学习内容生成、Prompt Preset、请求预览或长期记忆链路。

## 3. 调用模块

- Package：`Packages/LangoTraceAI`
- Service：`AIProviderConfigurationProbeService`
- 调用入口：
  - `probeDraftConfiguration(_:)`
  - `probeSavedConfiguration(_:)`
  - `EmbeddingConfigurationProbeService.probeDraftEmbeddingConfiguration(_:)`

## 4. 代码位置

- 文本 / JSON / 语言 / 图片 Prompt 文案来源：`Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- 文本 / JSON / 语言 / 图片具体位置：`ProbeKind.prompt`
- 文本 / JSON / 语言 / 图片请求体生成位置：`body(_:endpoint:)`
- 向量化固定文本来源：`Packages/LangoTraceAI/Sources/LangoTraceAI/EmbeddingConfigurationProbeService.swift`
- 向量化请求体生成位置：`makeRequest(endpoint:secret:)`

## 5. 输入变量

Prompt 变量：

- `target_language_name`：由 AI 层根据稳定 `LearningLanguage.code` allowlist 派生的英文语言名称，例如 `English`、`Japanese`、`French`、`Chinese`。调用方不得传入任意展示名。

非 Prompt 语言上下文：

- `target_language_code`：来自当前语言空间的稳定目标语言 code，例如 `en`、`ja`、`fr`、`de`、`es`、`ko`、`zh-Hans`。该值不写入 Provider profile，也不作为静态模型能力事实。

请求体包含非 Prompt 输入：

- `model`：用户配置的模型名。
- `input`：OpenAI Responses adapter 使用的固定 Prompt 文本或多模态 content 数组。
- `messages[0].content`：OpenAI-compatible Chat adapter 使用的固定 Prompt 文本或多模态 content 数组。
- `image_url`：图片理解 probe 使用的 `data:image/png;base64,...` 内置图片 data URL。
- `input`：向量化 probe 使用的固定低敏文本 `LangoTrace embedding configuration test.`。
- `encoding_format`：向量化 probe 固定请求 `float`。

图片理解 probe 使用的非 Prompt 输入：

- 图片资源：`Packages/LangoTraceAI/Sources/LangoTraceAI/Resources/AIProviderProbe/blue-square.png`
- MIME type：`image/png`
- 图片内容：白底蓝色正方形，程序生成，无 EXIF，无用户内容。

## 6. 输出契约

### Text Reply Probe

模型应返回纯文本 `OK`。当前实现会把可解析的响应文本视为文本能力连通性证据，不要求逐字等于 `OK`。

### Structured JSON Probe

模型必须根据字段结构说明生成严格 JSON object。验收目标为：

```json
{"ok":true}
```

Prompt 不直接提供完整目标 JSON 字面量作为可复制答案，只说明字段名、字段类型和禁止额外文本的约束。模型不得返回 Markdown code fence、解释文本、额外字段或非 JSON 包裹内容。当前实现会解析响应文本，并要求顶层对象 exactly one field，且 `ok` 为 `true`。

### Language Support Probe

模型必须根据目标学习语言生成 JSON object，且包含一个字段 `sample`。验收结构为：

```json
{"sample":"..."}
```

`sample` 必须只使用 `target_language_name` 对应语言。Prompt 要求中文、日语或韩语约 50 个可见字符，英语、法语、德语或西班牙语约 50 个词；本机验收使用更宽容的范围，避免把轻微长度偏差误判为语言能力失败。内容主题固定为“一个人记录日常生活中的普通片刻”，不包含用户真实生活内容。

当前实现会从常见 Markdown code fence 中提取 JSON，忽略 `sample` 之外的额外字段，但会拒绝空字符串、明显短句、离线语言识别不匹配或脚本规则不匹配的响应。严格结构化输出能力由 `JSON 输出` probe 负责；语言支持失败只表示本次合成测试未能确认当前模型适合该目标语言，不证明模型绝对不支持该语言。

### Image Understanding Probe

模型必须读取内置图片，并返回恰好两个小写英文单词：颜色在前，形状在后。验收目标为：

```text
blue square
```

Prompt 不直接包含 `blue` 或 `square`。当前实现会对响应文本执行 trim 和 lowercase，只接受 exactly `blue square`。不接受 `a blue square`、`blue rectangle`、`square blue`、`blue square.` 或长句描述。

### Embedding Probe

Provider 必须返回 OpenAI-like embeddings JSON，验收结构为：

```json
{"data":[{"embedding":[0.1,0.2,0.3]}]}
```

当前实现只读取 `data[0].embedding`，并要求它是非空数字数组。不保存 vector 数组，不记录 vector 维度以外的响应内容，不比较相似度，不把该响应写入长期记忆或向量索引。

## 7. 是否包含用户原文

语言支持 probe 包含目标学习语言 code 派生出的语言英文名称，但不包含用户目标语言正文、用户生活记录、Prompt Preset 或用户自定义长文本。图片理解 probe 包含项目内置白底蓝色正方形 PNG。向量化 probe 只包含固定低敏文本 `LangoTrace embedding configuration test.`。它们不包含用户照片、相册图片、生活记录附件、OCR、音频、历史记忆或附件摘要。

## 8. 是否包含照片、音频、OCR、历史记忆或附件摘要

否。

## 9. 隐私等级

低敏合成测试 Prompt。

该请求会发送到用户配置的外部或本地 Provider，但不包含生活记录、学习内容、用户照片、音频、OCR、历史记忆、附件摘要、Prompt Preset 内容或用户自定义正文。语言支持 probe 的 `sample` 原文只存在于短生命周期响应解析和本地校验内存中，不进入日志、validation event、diagnostic attributes、SQLite profile 或 UI 持久状态。图片理解 probe 使用的图片是项目内置合成素材，只用于配置连通性和基础图片输入链路验证。向量化 probe 的返回 vector 只在内存中做 shape validation，不保存、不输出、不写日志、不进入 validation event。

## 10. 请求预览要求

当前阶段 AI Provider 配置探测尚未接入真实请求预览 UI。后续如果为该测试请求增加预览，应展示以下内容：

- Provider adapter 类型。
- endpoint purpose。
- model。
- 将发送的固定 Prompt 文案。
- 语言支持 probe 使用的目标语言 code 和由 allowlist 派生的英文语言名称。
- 图片理解 probe 是否会发送内置合成图片，以及该能力是官方支持、模型相关还是当前 adapter 暂不支持测试。
- 向量化 probe 是否会发送固定低敏文本，以及该 endpoint 是否属于 OpenAI、OpenRouter 或 Custom OpenAI-compatible 第一阶段范围。
- 是否使用已保存 Keychain credential 或当前 draft credential。

预览不得展示 API Key、Authorization header、完整 Keychain account、完整图片 base64、请求体中的敏感字段、Base URL query 中的敏感参数或 Provider 返回的 `sample` 原文。

## 11. 评测方式

- Core 测试确认 probe descriptor、capability status 和 diagnostic event 类型稳定。
- AI 测试确认 OpenAI Responses / OpenAI-compatible Chat 请求体包含固定 Prompt，语言支持 probe 只使用 allowlisted target language code 派生 Prompt 名称，图片理解 probe 使用内置 PNG data URL，向量化 probe 使用固定低敏文本和 OpenAI-like embeddings shape 校验，并覆盖成功、认证失败、模型不可用、网络不可达、超时、取消、JSON 格式错误、语言支持响应无效、图片响应无效和 embedding 响应无效。
- UI 测试确认 iPhone、iPad 和 macOS 的共享设置详情都能从当前语言空间传入 language context，测试状态、分能力状态和取消态文案存在；大屏平台不得复制独立 AI Provider 表单。
- `scripts/verify.sh` 作为统一回归入口。

## 12. 英文版本 Prompt

### `ai-provider.configuration-probe.text-reply.v1`

```text
Configuration test. Reply with OK only.
```

### `ai-provider.configuration-probe.structured-json.v1`

```text
Configuration test. Return a single JSON object with exactly one field named ok. The value must be the boolean true. Do not include markdown, code fences, or any other text.
```

### `ai-provider.configuration-probe.language-support.v1`

```text
Configuration test. Generate a natural sample in {target_language_name}.
Return exactly one JSON object with exactly one field named sample.
The sample must be written only in {target_language_name}.
For Chinese, Japanese, or Korean, write about 50 visible characters.
For English, French, German, or Spanish, write about 50 words.
The sample should describe a person recording an ordinary moment from daily life.
Do not include translation, language names, markdown, code fences, explanations, or any other text.
```

### `ai-provider.configuration-probe.image-understanding.v1`

```text
Describe the image using exactly two lowercase English words: color then shape. Do not include punctuation or any other text.
```

### `ai-provider.configuration-probe.embedding.v1`

```text
LangoTrace embedding configuration test.
```

## 13. 中文版本 Prompt

### `ai-provider.configuration-probe.text-reply.v1`

```text
配置测试。只回复 OK。
```

### `ai-provider.configuration-probe.structured-json.v1`

```text
配置测试。返回一个 JSON object，且只包含一个名为 ok 的字段。该字段的值必须是布尔值 true。不要包含 Markdown、代码块或任何其他文本。
```

### `ai-provider.configuration-probe.language-support.v1`

```text
配置测试。请使用 {目标语言名称} 生成一段自然样例。
只返回一个 JSON object，且只包含一个名为 sample 的字段。
sample 必须只使用 {目标语言名称}。
中文、日语或韩语请写约 50 个可见字符。
英语、法语、德语或西班牙语请写约 50 个词。
样例内容描述一个人记录日常生活中的普通片刻。
不要包含翻译、语言名称、Markdown、代码块、解释或任何其他文本。
```

### `ai-provider.configuration-probe.image-understanding.v1`

```text
使用恰好两个小写英文单词描述图片：先写颜色，再写形状。不要包含标点或任何其他文本。
```

### `ai-provider.configuration-probe.embedding.v1`

```text
LangoTrace embedding configuration test.
```

## 14. 版本记录

- 2026-05-21：创建 Provider 配置合成测试 Prompt 文档。原因：代码已经通过 `AIProviderConfigurationProbeService` 向 Provider 发送固定合成 Prompt，按 Prompt Registry 规则需要记录完整 Prompt 文案、输出契约和隐私边界。影响范围：AI Provider 配置测试请求、后续请求预览和 Prompt 审查。是否需要 ADR：否，沿用 ADR-005 和 `spec/005` / `spec/008` 的隐私边界。
- 2026-05-21：更新 structured JSON probe Prompt。原因：系统架构复查认为直接在 Prompt 中给出完整 `{"ok":true}` 字面量更像回显测试，不足以证明模型能按结构说明生成 JSON；新版本只描述字段名、字段类型和无额外文本约束，验收仍严格要求 exactly one field `ok: true`。影响范围：AI Provider 配置测试请求、Prompt Registry 和相关单元测试。是否需要 ADR：否。
- 2026-05-21：新增 image understanding probe Prompt。原因：AI Provider 配置测试请求新增用户显式启用后的内置图片合成 probe，需要登记固定 Prompt、内置图片输入、输出契约和隐私边界。影响范围：AI Provider 配置测试请求、Prompt Registry、图片输入边界和相关单元测试。是否需要 ADR：否，沿用 ADR-005；真实用户照片请求仍需单独请求预览方案。
- 2026-05-21：补充 model-dependent 图片理解适用范围。原因：OpenRouter / Custom OpenAI-compatible 的图片输入能力不能由 Provider preset 静态布尔值判断，应由能力解析器允许用户显式开启，再通过本 Prompt 的内置图片 probe 验证。影响范围：AI Provider 配置测试请求、请求预览说明和能力边界文案。是否需要 ADR：否。
- 2026-05-22：新增 language support probe Prompt。原因：AI Provider 配置测试需要在当前语言空间上下文下确认文本模型能否生成目标学习语言的较长样例，并由本机做 JSON、长度、NaturalLanguage 和脚本规则校验。影响范围：AI Provider 配置测试请求、语言边界、Prompt Registry、隐私日志边界和相关单元测试。是否需要 ADR：否，沿用 ADR-005；该结果不是模型语言能力认证，不写入 Provider profile 静态能力事实。
- 2026-05-27：新增 embedding probe 固定低敏文本和输出契约。原因：AI Provider 配置测试新增 OpenAI / OpenRouter / Custom OpenAI-compatible 向量 endpoint 真实 probe，需要登记固定输入、OpenAI-like embeddings shape 验收、不保存 vector 和 endpoint-scoped validation 边界。影响范围：AI Provider 配置测试请求、EmbeddingConfigurationProbeService、测试工具和后续向量基础设施。是否需要 ADR：否，沿用 ADR-005。
