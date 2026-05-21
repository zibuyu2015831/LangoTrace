# AI Provider Configuration Probe Prompts

状态：Accepted

适用阶段：AI Provider 配置页文本模型合成测试请求。

## 1. Prompt id

- `ai-provider.configuration-probe.text-reply.v1`
- `ai-provider.configuration-probe.structured-json.v1`

## 2. 所属功能

AI Provider 配置页的“测试请求”能力，用于确认用户配置的文本模型 endpoint、model、credential 和 adapter 能完成最小合成请求。

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
- `input`：OpenAI Responses adapter 使用的固定 Prompt 文本。
- `messages[0].content`：OpenAI-compatible Chat adapter 使用的固定 Prompt 文本。

## 6. 输出契约

### Text Reply Probe

模型应返回纯文本 `OK`。当前实现会把可解析的响应文本视为文本能力连通性证据，不要求逐字等于 `OK`。

### Structured JSON Probe

模型必须返回严格 JSON：

```json
{"ok":true}
```

不得返回 Markdown code fence、解释文本、额外字段或非 JSON 包裹内容。当前实现会解析响应文本，并要求顶层对象中的 `ok` 为 `true`。

## 7. 是否包含用户原文

否。

## 8. 是否包含照片、音频、OCR、历史记忆或附件摘要

否。

## 9. 隐私等级

低敏合成测试 Prompt。

该请求会发送到用户配置的外部或本地 Provider，但不包含生活记录、学习内容、照片、音频、OCR、历史记忆、附件摘要、Prompt Preset 内容或用户自定义正文。

## 10. 请求预览要求

当前阶段 AI Provider 配置探测尚未接入真实请求预览 UI。后续如果为该测试请求增加预览，应展示以下内容：

- Provider adapter 类型。
- endpoint purpose。
- model。
- 将发送的固定 Prompt 文案。
- 是否使用已保存 Keychain credential 或当前 draft credential。

预览不得展示 API Key、Authorization header、完整 Keychain account、请求体中的敏感字段或 Base URL query 中的敏感参数。

## 11. 评测方式

- Core 测试确认 probe descriptor、capability status 和 diagnostic event 类型稳定。
- AI 测试确认 OpenAI Responses / OpenAI-compatible Chat 请求体包含固定 Prompt，并覆盖成功、认证失败、模型不可用、网络不可达、超时、取消和 JSON 格式错误。
- UI 测试确认测试状态、分能力状态和取消态文案存在。
- `scripts/verify.sh` 作为统一回归入口。

## 12. 英文版本 Prompt

### `ai-provider.configuration-probe.text-reply.v1`

```text
Configuration test. Reply with OK only.
```

### `ai-provider.configuration-probe.structured-json.v1`

```text
Configuration test. Reply only with {"ok":true}.
```

## 13. 中文版本 Prompt

### `ai-provider.configuration-probe.text-reply.v1`

```text
配置测试。只回复 OK。
```

### `ai-provider.configuration-probe.structured-json.v1`

```text
配置测试。只回复 {"ok":true}。
```

## 14. 版本记录

- 2026-05-21：创建 Provider 配置合成测试 Prompt 文档。原因：代码已经通过 `AIProviderConfigurationProbeService` 向 Provider 发送固定合成 Prompt，按 Prompt Registry 规则需要记录完整 Prompt 文案、输出契约和隐私边界。影响范围：AI Provider 配置测试请求、后续请求预览和 Prompt 审查。是否需要 ADR：否，沿用 ADR-005 和 `spec/005` / `spec/008` 的隐私边界。
