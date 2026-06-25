# Style Surface Imprint Recompute Notes

状态：Accepted
创建日期：2026-06-25

## 适用范围

适用于后续任何触及 Learner Model Style 层持久化 / 备份 / 导出的方案，以及 v2 认知风格 / 自陈 Style 的落地。

## 背景

LM02-S2（`docs/plans/done/2026-06-25-feature-lm02-s2-style-surface-imprint.md`）落地 Style 层 v1 **表面写作印记**：`GRDBLearnerStyleProvider` compute-on-read 从 `entries` 机械重算（`NaturalLanguage` 检测语种 + 机械分词指标），**无新表 / 无 writer / 无 migration**，与 LM01 Ability 同型。

ADR-006 §8「可重建性梯度」把**整个 Style 层**列「准原始 → 纳入导出 + 可恢复备份、删除即永久 + tombstone」，**未区分 v1 表层 vs v2 认知**。这与 v1 的 compute-on-read 实现存在字面张力。

## 目的

- 防止后续会话误把 **v1 表面印记当「准原始」去建表 / 建备份**（它是可从 `entries` 完全重算的真派生量，建表是冗余且违 §8 真派生不持久原则）。
- 固化 §8「准原始 / 备份」的**实质适用边界 = v2 自陈 + AI 认知风格**（不可从行为廉价重算者），与 LM02-S2 在 ADR-006 实施进展中的分层细化一致。

## 已有设计留下的扩展点

- `StyleImprint` 已分 `StyleMetricKind.surface`（v1，真派生）vs `.cognitive`（保留位，v2）；持久化边界天然沿此切：surface 不持久、cognitive（v2）才进「准原始 / 备份」。
- `LearnerStyleProvider` 读 seam 已系统级、与 Ability/Memory/盲点并列分方法暴露，v2 认知风格可加新方法 / 新源而不改 v1 重算路径。
- LM01 Ability「compute-on-read 真派生不持久」+ S1 Memory「准原始 → `includedInRecoverableBackup`」两条先例已划清「真派生 vs 准原始」的持久化分叉，Style 沿用同一判据（能否从已备份的源数据廉价重算）。

## 后续任务必须重新决策的问题

- **v2 认知风格 / 自陈 Style 落地时**：这部分是「准原始 → 持久 + 备份」（不可从行为重算），须建表 + 纳入 `learner_memory_facts` 同型的可恢复备份硬接缝（参 `2026-06-25-learner-memory-persistence-and-security-notes.md`），并在 ADR-006 §8 实施进展再细化。
- **若产品决定展示 Style**（当前 seam-only 不展示）：须先收口 idea-01 §13.4 / decomposition §35③ 展示默认，表达快照须严守机械描述、不越人格 / 认知侧写。

## 不应在当前阶段提前实现的内容

- 不为 v1 表面印记建表 / 建 writer / 建备份（它是真派生，compute-on-read 即可）。
- 不做认知风格 / AI 校准（外发，v2 opt-in，须过隐私闸）。
- 不做 Style → Ability 下投影到目标语改写（消费者是语伴 v2 / 改写切片）。
