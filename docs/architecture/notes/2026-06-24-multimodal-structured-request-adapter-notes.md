# Multimodal Structured Request Adapter Notes

状态：Draft
创建日期：2026-06-24

## 适用范围

适用于后续任何「图片输入 + 结构化输出」的 AI 能力方案：照片写作 AI 辅助、未来 OCR、图片问答、图文混合的学习材料生成，以及其它需要在同一请求中携带图片与 JSON schema 的能力。

## 背景

截至 HEAD = a484b64，`Packages/LangoTraceAI/.../AIProviderTextRequestAdapter.swift` 把两类请求体分开实现且互不相交：

- `imagePromptBody`（Chat `image_url` data URL；Responses `input_image` / `detail:"low"`）：**纯文本 prompt，无 `response_format` / `json_schema`，`max_tokens` 写死为调用方传入的极小值**（图片 probe 传 8）。唯一调用方是配置探测的图片 probe。
- `structuredCompletionBody`（`strict: true` 的 json_schema）：**纯文本输入，无图片**。三个调用方（learning material、reading、backtranslation）均无图片。

也就是说，当前代码中**不存在「图片 + 结构化 JSON schema」的请求体**。`MimoCompatibleChatTextAdapter` 实现了 `imagePromptBody`，但 `AIProviderConfigurationProbeService.supportsImageProbe` 的 allowlist 只放行 `openAIResponses` / `openAICompatibleChat`；Anthropic / Gemini adapter 抛 `unsupportedProvider`。

`docs/plans/active/2026-06-24-feature-photo-writing-ai-assist.md` 是第一个需要「看图 + 结构化产出」的能力，因此第一个撞上这个缺口。本备忘录记录该 adapter 契约扩展应作为跨能力基础设施一次性想清楚，而不是每个能力各拼一份 body。

## 目的

- 防止后续每个多模态能力各自硬拼一份「图片 + schema」请求体，造成 adapter 实现发散。
- 记录第一阶段必须用合成图（非真实用户照片）验证的 Provider 兼容性待验证项。
- 明确该扩展不在某单一能力任务内被悄悄当作「复用现有方法」处理。

## 已有设计留下的扩展点

- `AIProviderTextRequestAdapter` 已分别具备图片消息体与结构化输出体两种能力，二者形态已知，合并是增量而非新协议。
- `AIProviderAdapterKind` 已区分 openAICompatibleChat / openAIResponses / mimoCompatibleChat / anthropicMessages / geminiGenerateContent，可作为多模态支持矩阵的 allowlist 维度。
- `supportsImageProbe` 已确立「能力由 adapter allowlist 解析」的范式，可被结构化图片能力复用，避免 probe 与真实请求两套放行集合漂移。
- 项目内置合成图 `Packages/LangoTraceAI/.../Resources/AIProviderProbe/blue-square.png` 可用于结构化图片请求的兼容性 gate，无需真实照片。

## 后续任务必须重新决策的问题

- 统一的多模态结构化请求体形态：是为 `imagePromptBody` 增加可选 `schema` / token 上限参数，还是新增独立 `structuredImagePromptBody`？跨能力是否收敛为单一入口。
- Provider 兼容性（必须以合成图验证，FAIL 则记录并退回方案）：
  - OpenAI Responses 的 `input_image` 与 `text.format = json_schema` 能否共存。
  - OpenAI-compatible Chat 的 `image_url` 与 `response_format` 能否共存；各聚合层（OpenRouter / Custom）行为差异。
- strict json_schema 与「按 mode 互斥可选字段」的张力：strict 模式要求固定 `required` 且禁 additionalProperties，互斥可选字段难表达，是否按 mode 选用多份 strict schema。
- 多模态能力的 token 上限策略：probe 的极小 `max_tokens` 不适用于真实产出，需按能力配置合理上限并防滥用。
- 图片支持矩阵随 adapter 演进的维护点：mimo 当前不在图片 allowlist，未来纳入需同步 probe 与真实请求两条链路。

## 不应在当前阶段提前实现的内容

- 不为 Anthropic / Gemini 提前实现图片或多模态请求体（adapter 现状不支持，且无能力需求驱动）。
- 不把多模态请求体设计成通用「任意附件」通道；当前只服务受控的图片 + 结构化输出，附件/音频等另行决策。
- 不在本备忘录阶段定稿统一 API；待 photo-writing-assist 方案进入实现并跑通兼容性 gate 后，再决定是否把本备忘录提升为正式 architecture 文档或 spec 条款。
