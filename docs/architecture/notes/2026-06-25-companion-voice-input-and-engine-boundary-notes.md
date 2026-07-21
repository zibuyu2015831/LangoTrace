# 语伴语音输入与引擎边界开发备忘录

状态：Accepted

创建日期：2026-06-25

## 适用范围

LM03 语伴系列（[ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md) 定位、[LM03 拆解](../../plans/done/2026-06-25-docs-lm03-companion-decomposition.md)、[LM03-S1 active plan](../../plans/done/2026-06-25-feature-lm03-s1-companion-mvp.md)）。本备忘录服务于 LM03-S1（MVP 单线程文本对话引擎）之后的语音、隐私与包边界扩展，**不替代** ADR-008、LM03 各子片 active plan、spec 或 architecture 根文档。

## 目的

idea-03 §3.7 硬前置 6 明确要求：依据语伴构想拆 active plan 时，必须把「语伴语音输入 / 语音对话」作为跨任务扩展提醒写入架构备忘录，说明当前**文本优先**设计须为后续语音能力预留 message schema、输入栏交互与 Speech 权限边界，避免初版设计阻断远期语音。本备忘录在 LM03-S1 创建时一并落地该要求，并附带登记两条 S1 刻意不做、但后续片必须承接的跨片提醒（PII scrubbing / 独立包边界）。

## 1. 已有设计留下的扩展点（LM03-S1 已预留）

- **message schema 语音接缝**：S1 的 `companion_messages` 表（v30）预留两列——`input_modality`（默认 `text`）与 `audio_artifact_id`（nullable，v1 恒 null，ON DELETE SET NULL 弱链到媒体资产）。领域类型 `CompanionMessage` 同步带 `inputModality` / `audioArtifactID?`。故远期「用户语音输入 / 语伴语音消息」可在不改既有文本行语义、不做破坏性 migration 的前提下落地。
- **媒体资产基础设施已就绪**：练习录音 artifact（`practice_recording_artifacts`）+ App 管理的 `MediaArtifacts` 目录 + staging / 原子移动 / 失效 / 清理 / local-only / excluded-from-backup 策略已存在，语音消息音频可复用该 artifact 契约，`audio_artifact_id` 指向其 key，无须新建媒体存储路径。
- **逐句 TTS 朗读已复用**：S1 已接 `SentenceAudioPlaybackActions` / coordinator 朗读语伴回复（输出侧语音）。输入侧语音（Speech Recognition）是缺口。
- **引擎输入栏交互**：S1 聊天输入栏为纯文本；远期须在同一输入栏加录音触发 + 转写态 + 编辑确认，设计时输入栏组件应允许「输入来源 = 文本 / 语音转写」分支，不把文本输入硬编码为唯一来源。

## 2. 后续任务必须重新决策的问题

- **Speech Recognition 权限边界**：语音输入依赖 `Speech` / 麦克风权限。语伴录音权限与既有练习跟读录音（已配麦克风权限）的关系——复用同一权限说明还是区分用途文案？转写在本机（`SFSpeechRecognizer` on-device）还是允许云端转写（涉外发，须过决策 #10 + ADR-008 §6 外发边界）？默认应 on-device、本地优先。
- **语音消息的外发与隐私**：语音转写文本进入对话后，其外发等同文本消息（用户主动触发）；但若云端转写，则原始音频外发是新的敏感外发点，须独立 opt-in + 隐私预览。
- **语音 vs 文本的对话记忆一致性**：S3 滚动摘要 / 对话记忆落地时，语音转写消息须与文本消息同等参与摘要 + 删除该条及后续语义。
- **独立 `LangoTraceCompanion` 包边界（跨片提醒）**：S1 刻意不新建包（早期克制），引擎在 `LangoTraceAI`、领域类型在 `LangoTraceCore`、持久在 `LangoTraceData`、UI 在 `LangoTraceUI`。若 S2（找话题 + Memory 注入 + 反哺）/ S3（流式 + 对话记忆 + 摘要）/ S4（Style + Anthropic）使语伴编排显著膨胀、跨包耦合加重，应评估抽出独立 `LangoTraceCompanion` 包统一承载引擎 + 编排 + 领域类型。创建 S2 active plan 时须复核此提醒。
- **PII scrubbing + Memory 注入两层控制（S2 门控提醒）**：S1 **零系统自动注入**（不注入 Memory 生活事实、不读 FTS），故未实现 PII scrubbing。S2 引入 Memory 注入后，ADR-008 §6 / idea-03 §6.9 要求的「首次开启全局预览 + per-conversation toggle + 结构化 PII（手机号 / 身份证号）确定性 scrubbing」**必须在 S2 补齐**，不得随 Memory 注入一起遗漏。创建 S2 active plan 时此项为实现前必决项。

## 3. 不应在当前阶段提前实现的内容

- **不在 S1 实现语音输入 / 语音对话 / Speech Recognition 接入**：S1 文本优先，仅预留 schema / 输入栏 / 权限接缝。
- **不在 S1 实现云端转写或语音外发路径**。
- **不在 S1 预先抽出独立 `LangoTraceCompanion` 包**：膨胀信号出现前不过度工程化。
- **不在 S1 实现 PII scrubbing 基础设施**：绑定 S2 Memory 注入一起落地（S1 无系统自动注入，无该外发面）。

## 4. 读取要求

创建 LM03-S2 / S3 / S4 active plan 前，必须读取本备忘录，并在对应 plan 中说明：是否采纳语音 schema 接缝、是否到达独立包抽取阈值、PII scrubbing + Memory 两层控制如何在 S2 落地，以及哪些提醒需提升为正式 spec / architecture / ADR。
