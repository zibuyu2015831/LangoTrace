---
title: Learner Memory 层持久化与静态安全跨任务提醒（LM02）
summary: LM02 落地系统级 learner_memory_facts（Memory 准原始）后，为 E10 可恢复备份与系统级 PII 静态加密留两条跨任务硬接缝，避免后续会话遗漏。
keywords: learner model | memory | export | recoverable backup | E10 | FileProtection | SQLCipher | field encryption | PII
related_files: docs/decisions/006-system-level-three-layer-learner-model.md | docs/plans/active/2026-06-25-feature-lm02-memory-layer-and-learner-profile-overview.md | docs/idea/01-learner-model.md | docs/spec/007-data-storage-migration-export-and-attachments.md
verified_at: 2026-06-25
---

# Learner Memory 层持久化与静态安全跨任务提醒（LM02）

状态：Accepted（作为设计输入与检查清单，非实现要求）
创建日期：2026-06-25
来源：LM02 Slice 1 方案自审核（`docs/plans/active/2026-06-25-feature-lm02-memory-layer-and-learner-profile-overview.md` 第 13 节 P2-3 / P1-5）

## 适用范围

后续 E10（导入导出与可恢复备份）切片、以及任何触及系统级 PII 静态安全的任务，开工前必须重新检查本备忘录。本备忘录是设计输入，不替代 ADR-006、LM02 方案、spec/007 或 E10 方案；被采纳后须写回对应权威文档。

## 背景

LM02 Slice 1 落地仓库**首张系统级（横切语言空间）业务表** `learner_memory_facts`（Memory 层「生活事实 / 目标」，用户显式记住）。按 ADR-006 §8，Memory 是**准原始数据**——不像 Ability（compute-on-read 真派生、可丢弃重算），Memory **删库 = 永久失忆**，是最痛的 PII 丢失。LM02 v1 只**登记**该表的持久化策略列（`sync_policy=localOnly` / `backup_policy=includedInSystemBackup` / `export_policy=includedInRecoverableBackup`），不实现实际导出 / 备份打包。

## 两条跨任务硬接缝

### 1. E10 可恢复备份必须纳入 `learner_memory_facts`

- E10 当前仅落地 Slice 1（非敏感主数据明文导出 / 导入引擎，见 `2026-06-18-export-backup-deferred-slices.md`），可恢复备份 / 加密备份 deferred。
- E10 后续实现**可恢复备份**时，**必须**把 `learner_memory_facts` 纳入备份范围（其 `export_policy=includedInRecoverableBackup` 已声明此意图）。遗漏将导致用户备份恢复后「App 对我的了解」永久丢失，违反 ADR-006 §8。
- 同时须确认：Ability 覆盖是 compute-on-read 派生（**不**进备份，会从 memory_items 重算）；Memory / 未来 Style 进备份——**按层分叉**，不可一刀切。

### 2. 系统级 PII 字段级加密 / SQLCipher 仍为未决项

- ADR-006 §5.2 指出系统级集中 = 最浓缩全人 PII，设备失窃 / 备份泄露可一锅端，保留「整库 FileProtection / 字段隔离」决策；idea-01 §12.2 把「派生但高浓缩事实是否需超出默认 SQLite 的静态加密（SQLCipher / 字段级）」列为**升 ADR 时须正面回答**的未决项。
- LM02 v1 现状：复用既有整库 `FileProtection.completeUntilFirstUserAuthentication`（`AppDatabase.swift`，iOS），**未**引入字段级加密 / SQLCipher。LM02 v1 用「系统级重置 = 物理硬删」降低软删明文残留风险，但未解决整库静态加密强度问题。
- 后续若 Memory / Style 体量增长、或引入更敏感的认知风格画像，须重新评估字段级加密 / SQLCipher，并在需要时升 ADR（密钥管理 / 后台访问复杂度是主要权衡，见 idea-01 §12.7 倾向 FileProtection 优先、不引 SQLCipher）。

### 3. 查词行为事件 FileProtection 接缝（LM02-S4a，2026-06-25）

- LM02-S4a 落地 `dictionary_lookup_events`（v28）：高频查词 / 索取解释行为信号，是「用户读什么 / 哪些词难」的浓缩行为 PII。v1 复用整库 `FileProtection.completeUntilFirstUserAuthentication`，**显式声明 local-only / 排除备份 / 排除导出**（设备迁移后不可恢复——S4b band 须能从剩余信号优雅降级）。
- 后续若查词事件体量增长、或与 Memory / Style 合并形成更完整行为画像，须连同上节字段级加密评估一并重估。

## 后续检查触发点

- 启动任何 E10 备份 / 恢复切片方案前。
- 引入 Style 层或 Memory 自动抽取（v2）导致 PII 体量 / 敏感度上升时。
- 出现「敏感语言空间隔离」或「设备失窃静态安全」相关需求时（呼应 ADR-006 复审条件）。
- 查词行为事件（S4a）与其它行为信号合并、或引入 S4b band 外发档位时。
