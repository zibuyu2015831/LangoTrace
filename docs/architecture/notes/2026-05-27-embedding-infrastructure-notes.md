# Embedding Infrastructure Notes

状态：Accepted
创建日期：2026-05-27

## 适用范围

适用于后续 embedding job queue、向量索引、语义搜索、长期记忆检索、向量重建、向量删除、向量导出和向量同步相关方案。

## 背景

AI Provider 配置测试已经支持 OpenAI、OpenRouter 和 Custom OpenAI-compatible 的第一阶段向量化 probe。该 probe 只验证 endpoint、model、credential 和 OpenAI-like response shape，不创建向量索引。

本备忘录记录后续真正落地向量基础设施前必须处理的架构边界，避免把配置 probe 误当成长期记忆、语义搜索或本地索引已经完成。

## 目的

- 保留本轮配置 probe 对后续向量基础设施产生的架构提醒。
- 明确配置 probe 与真实内容 embedding 的隐私边界不同。
- 防止后续实现直接复用配置测试路径发送用户内容或保存 vector。

## 已有设计留下的扩展点

- `AIProviderEndpointConfiguration.configurationFingerprint` 可作为后续向量失效和重建的输入之一。
- `AIProviderEndpointProbeMetadata` 已能携带 endpoint purpose、provider preset、model 和 configuration fingerprint。
- Saved embedding probe 已使用 endpoint-scoped validation outcome，避免污染文本 profile 全局摘要。
- 向量 endpoint、文本 endpoint 和 TTS endpoint 已在配置模型中分离，可为后续独立 job queue 和索引策略提供边界。

## 后续任务必须重新决策的问题

- Embedding job queue：需要定义任务来源、批量大小、去重、取消、重试、退避、前台 / 后台执行和费用提示。
- 向量索引 schema：需要记录 object kind、object id、language space、source text hash、embedding model、dimension、configuration fingerprint、created at 和 invalidation reason。
- 维度与模型 fingerprint：不同 provider、model、base URL、adapter、credential reference、timeout 和 output-affecting capability flags 必须能触发重建或隔离，不能混写到同一索引。
- 删除与失效：Entry、LearningMaterial、SentencePair、Memory candidate 或语言空间删除时，派生向量必须可删除；配置 fingerprint 改变时旧向量必须标记 stale 或重建。
- 隐私提示：真实内容 embedding 会发送用户文本到外部 Provider，必须有独立请求边界或清晰披露；配置 probe 的固定低敏文本不能作为真实内容发送授权。
- 同步与导出：向量索引默认本地可重建、默认不同步；如未来允许同步或导出，需要单独审查体积、隐私、模型兼容和删除传播。
- 可观测性：可以记录任务状态、数量、耗时、失败分类和长度 bucket；不得记录完整用户文本、请求体、响应体、API Key、Authorization header 或 embedding vector。

## 当前任务不实现

- 不创建向量表或 ANN 索引。
- 不为任何用户内容生成 embedding。
- 不保存 vector、维度统计或 provider usage。
- 不实现语义搜索、长期记忆检索、相似记录召回或重建队列。
- 不改变“向量索引是本地可重建派生数据，默认不同步”的 ADR 边界。

## 进入正式方案前检查

创建后续向量索引、语义搜索、长期记忆或 embedding job queue 方案前，必须读取本备忘录，并在方案中说明哪些内容被采纳、延后或提升为正式 spec / architecture / ADR。
