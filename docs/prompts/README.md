# Prompt Registry

本目录用于记录 LangoTrace 后续 AI / Prompt 功能中实际使用或计划使用的 Prompt。代码中出现真实发送给 Provider 的 Prompt 后，必须在本目录登记完整文案、输出契约和隐私边界。

## 1. 使用原则

- 代码中实际使用的内置 Prompt 以英文版本为准，便于获得更稳定的模型效果和跨模型兼容性。
- 文档中必须同时保存英文版本和中文版本。
- 中文版本用于客户阅读、业务校对、隐私审查和产品讨论。
- 英文版本和中文版本语义必须一致；如果为了模型效果存在非逐字翻译，应说明差异原因。
- Prompt 文档不得只写摘要。关键 Prompt 文案应保存完整文本，或明确说明文案从哪个代码位置生成。

## 2. 目录建议

具体 Prompt 落地后，按功能或模块建文档：

```text
docs/prompts/
  README.md
  <feature-or-module>/<prompt-id>.md
```

只有当代码中出现真实 Prompt、Prompt Preset、模板渲染或请求预览需求时，才新增对应文档。固定合成测试 Prompt 也属于真实 Provider 请求内容，必须登记。

## 3. 单个 Prompt 文档必填字段

每个具体 Prompt 文档至少包含：

- Prompt id。
- 所属功能。
- 调用模块。
- 代码位置。
- 输入变量。
- 输出契约。
- 是否包含用户原文。
- 是否包含照片、音频、OCR、历史记忆或附件摘要。
- 隐私等级。
- 请求预览要求。
- 评测方式。
- 版本记录。
- 英文版本 Prompt。
- 中文版本 Prompt。

## 4. 模板渲染规则

如果代码中的 Prompt 由模板拼接生成，文档必须记录：

- 模板源文件路径。
- 变量列表和变量含义。
- 完整渲染后的英文样例。
- 对应中文版本。
- 哪些变量可能包含敏感内容。
- 请求预览中必须展示或脱敏的字段。

## 5. 隐私规则

Prompt 文档必须明确该 Prompt 是否会包含：

- 用户原始生活记录。
- 目标学习语言内容。
- 母语解释。
- 图片或 OCR 文本。
- 音频转写。
- 历史记忆摘要。
- 附件摘要。

如果包含敏感内容，必须说明用户触发条件、请求预览要求和日志记录边界。

## 6. 当前状态

状态：Accepted

适用阶段：Prompt Preset、AI Provider、请求预览和真实 AI 功能接入前。

当前已登记：

- [AI Provider Configuration Probe Prompts](ai-provider/provider-configuration-probe.md)：AI Provider 配置页文本、JSON 和内置图片合成测试请求。

## 7. 版本记录

- 2026-05-21：更新目录当前事实。原因：AI Provider 配置测试请求已经接入固定合成 Prompt，Prompt Registry 不再是空目录；后续真实 Provider 请求内容必须在本目录登记。影响范围：AI Provider 配置测试请求、Prompt 审查、请求预览和隐私复查。是否需要 ADR：否。
- 2026-05-21：补充图片理解合成测试 Prompt 当前事实。原因：AI Provider 配置测试请求新增可选内置图片 probe，仍属于真实发送给 Provider 的固定 Prompt，需要纳入 Prompt Registry。影响范围：AI Provider 配置测试请求、图片输入边界和隐私复查。是否需要 ADR：否。
