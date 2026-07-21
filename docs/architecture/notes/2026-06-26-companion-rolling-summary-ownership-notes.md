# 架构备忘录：语伴滚动摘要归属 —— companion-owned vs LearnerContextProvider

状态：Open（开发备忘录，非已接受实现事实）
创建日期：2026-06-26
关联：LM03-S3b-1（`docs/plans/done/2026-06-26-feature-lm03-s3b1-companion-rolling-summary.md`）、idea-03 §3.11、ADR-006

## 背景

idea-03 §3.11 把对话情景摘要（`CompanionMemorySummary`「记得你上次说的」）归 Learner Model 的 **Memory 层 per-space**，并要求语伴「通过 `LearnerContextProvider` 取用，而非语伴自建 store」。

LM03-S3b-1 实现时，把滚动摘要存为 `companion_threads` 上的派生 cache 列（v33），读写**封装在 `GRDBCompanionRepository.loadRollingSummary`/`updateRollingSummary`**，**companion-owned**，未经 `LearnerContextProvider`。

## 为什么 v1 选 companion-owned（自审采纳）

1. **per-space 对话情景 ≠ 系统级**：S2b-1 经 `LearnerContextProvider` 取用的是**系统级生活事实**（跨空间共享）；滚动摘要是**单会话上下文压缩**（per-thread/per-space、本会话内），把它路由进跨切面 learner-model provider 过度耦合。
2. **生命周期绑会话**：摘要随删该条及后续/清空**同事务失效重建**——这是会话写路径的强一致性约束，落在 companion repo 内最自然；provider 是只读取用接口，承载失效语义别扭。
3. **正确性优先**：v1 摘要是派生 cache，companion-owned 让失效一致性、水位模型、事务边界都在一个 repo 内闭环。

## 迁移点（v2 generalize 时检查）

- 读写已封装为 repo 方法（不裸露字段），**未来若需把对话情景摘要纳入 Memory 层统一治理**（跨空间聚合 / 与 Style·Memory 统一查看删除入口 / 经 `LearnerContextProvider` 返回），迁移点 = 这两个 repo 方法 + `CompanionRollingSummary` 类型；App `companionSend` 的摘要编排改为经 provider 取用。
- 届时需对齐 ADR-006 Memory 层契约 + idea-03 §3.11，并评估失效一致性在 provider 边界如何承载。

## 处理方式

- 本备忘录登记 v1 companion-owned 的取舍与 v2 迁移点；**不作为已接受的 generalize 实现要求**。
- 创建「Memory 层统一治理 / 对话情景纳入 provider」相关任务方案时，应检查本备忘录并说明采纳 / 暂不采纳 / 提升为正式 spec·ADR。
