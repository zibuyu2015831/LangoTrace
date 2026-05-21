# AI Provider Configuration Probe Prompts

状态：Accepted

适用阶段：AI Provider 配置页文本、JSON 和内置图片合成测试请求。

## 1. Prompt id

- `ai-provider.configuration-probe.text-reply.v1`
- `ai-provider.configuration-probe.structured-json.v1`
- `ai-provider.configuration-probe.image-understanding.v1`

## 2. 所属功能

AI Provider 配置页的“测试请求”能力，用于确认用户配置的文本模型 endpoint、model、credential 和 adapter 能完成最小合成请求。当前包含文本回复、JSON 输出和用户显式启用后的内置图片理解 probe。

该 Prompt 只用于 Provider 配置探测，不属于真实学习内容生成、Prompt Preset、请求预览或长期记忆链路。

## 3. 调用模块

- Package：`Packages/LangoTraceAI`
- Service：`AIProviderConfigurationProbeService`
- 调用入口：
  - `probeDraftConfiguration(_:)`
  - `probeSavedConfiguration(_:)`

## 4. 代码位置

- Prompt 文案来源：`Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- 具体位置：`ProbeKind.prompt`
- 请求体生成位置：`body(_:endpoint:)`

## 5. 输入变量

无 Prompt 变量。

请求体包含非 Prompt 输入：

- `model`：用户配置的模型名。
- `input`：OpenAI Responses adapter 使用的固定 Prompt 文本或多模态 content 数组。
- `messages[0].content`：OpenAI-compatible Chat adapter 使用的固定 Prompt 文本或多模态 content 数组。
- `image_url`：图片理解 probe 使用的 `data:image/png;base64,...` 内置图片 data URL。

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

### Image Understanding Probe

模型必须读取内置图片，并返回恰好两个小写英文单词：颜色在前，形状在后。验收目标为：

```text
blue square
```

Prompt 不直接包含 `blue` 或 `square`。当前实现会对响应文本执行 trim 和 lowercase，只接受 exactly `blue square`。不接受 `a blue square`、`blue rectangle`、`square blue`、`blue square.` 或长句描述。

## 7. 是否包含用户原文

图片理解 probe 包含项目内置白底蓝色正方形 PNG。它不包含用户照片、相册图片、生活记录附件、OCR、音频、历史记忆或附件摘要。

## 8. 是否包含照片、音频、OCR、历史记忆或附件摘要

否。

## 9. 隐私等级

低敏合成测试 Prompt。

该请求会发送到用户配置的外部或本地 Provider，但不包含生活记录、学习内容、用户照片、音频、OCR、历史记忆、附件摘要、Prompt Preset 内容或用户自定义正文。图片理解 probe 使用的图片是项目内置合成素材，只用于配置连通性和基础图片输入链路验证。

## 10. 请求预览要求

当前阶段 AI Provider 配置探测尚未接入真实请求预览 UI。后续如果为该测试请求增加预览，应展示以下内容：

- Provider adapter 类型。
- endpoint purpose。
- model。
- 将发送的固定 Prompt 文案。
- 图片理解 probe 是否会发送内置合成图片。
- 是否使用已保存 Keychain credential 或当前 draft credential。

预览不得展示 API Key、Authorization header、完整 Keychain account、完整图片 base64、请求体中的敏感字段或 Base URL query 中的敏感参数。

## 11. 评测方式

- Core 测试确认 probe descriptor、capability status 和 diagnostic event 类型稳定。
- AI 测试确认 OpenAI Responses / OpenAI-compatible Chat 请求体包含固定 Prompt，图片理解 probe 使用内置 PNG data URL，并覆盖成功、认证失败、模型不可用、网络不可达、超时、取消、JSON 格式错误和图片响应无效。
- UI 测试确认测试状态、分能力状态和取消态文案存在。
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

### `ai-provider.configuration-probe.image-understanding.v1`

```text
Describe the image using exactly two lowercase English words: color then shape. Do not include punctuation or any other text.
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

### `ai-provider.configuration-probe.image-understanding.v1`

```text
使用恰好两个小写英文单词描述图片：先写颜色，再写形状。不要包含标点或任何其他文本。
```

## 14. 版本记录

- 2026-05-21：创建 Provider 配置合成测试 Prompt 文档。原因：代码已经通过 `AIProviderConfigurationProbeService` 向 Provider 发送固定合成 Prompt，按 Prompt Registry 规则需要记录完整 Prompt 文案、输出契约和隐私边界。影响范围：AI Provider 配置测试请求、后续请求预览和 Prompt 审查。是否需要 ADR：否，沿用 ADR-005 和 `spec/005` / `spec/008` 的隐私边界。
- 2026-05-21：更新 structured JSON probe Prompt。原因：系统架构复查认为直接在 Prompt 中给出完整 `{"ok":true}` 字面量更像回显测试，不足以证明模型能按结构说明生成 JSON；新版本只描述字段名、字段类型和无额外文本约束，验收仍严格要求 exactly one field `ok: true`。影响范围：AI Provider 配置测试请求、Prompt Registry 和相关单元测试。是否需要 ADR：否。
- 2026-05-21：新增 image understanding probe Prompt。原因：AI Provider 配置测试请求新增用户显式启用后的内置图片合成 probe，需要登记固定 Prompt、内置图片输入、输出契约和隐私边界。影响范围：AI Provider 配置测试请求、Prompt Registry、图片输入边界和相关单元测试。是否需要 ADR：否，沿用 ADR-005；真实用户照片请求仍需单独请求预览方案。
