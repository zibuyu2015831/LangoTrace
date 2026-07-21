# 已归档任务方案

本目录保存按用户决定整体归档的历史任务方案，仅作为历史证据保留，不作为新任务入口，也不代表其中结论仍然适用。

2026-06-11：根据用户决定，`docs/plans/active/` 下 4 份旧方案整体归档。原因：三端原型已按新版设计重做，后续开发以 `docs/plans/active/` 中 2026-06-11 系列方案为准；旧方案中仍然适用的问题（如阅读 UI 交互缺陷、解释语言模式、AI Provider 待人工验证项）已被新系列方案与 `docs/testing/2026-06-11-mac-verification-checklist.md` 吸收或登记。

- 2026-05-26-bug-ai-provider-language-support-diagnostics.md（归档时状态：Implemented - Pending Manual Verification；剩余人工验证项已登记到 Mac 验证清单）
- 2026-05-26-bug-mac-ai-provider-key-retention.md（归档时状态：代码完成、待本机验证；剩余验证项已登记到 Mac 验证清单）
- 2026-06-06-bug-reading-ui-selection-and-display-issues.md（归档时状态：Draft；其中仍有效的问题并入新系列阅读方案）
- 2026-06-06-feature-explanation-language-mode-by-level.md（归档时状态：实施中；后续是否继续由新系列方案重新评估）

2026-06-25：根据用户决定，将 E10/E11 两份长期 defer 的基础设施方案整体归档。原因：`active/` 收敛为学习者模型系列（LM02/LM03，三份 idea 的具体拆分）；E10/E11 的引擎切片已落地并 CI 绿，剩余能力依赖当前不存在的基础设施（E10 加密 KDF/安全存储；E11 iCloud container/付费 capability/真实账号/多设备）而诚实 defer，不在当前实施重点内。**红线移交**：E10 的可恢复备份必须纳入 LM02-S1 的 `learner_memory_facts`（否则删库=永久失忆），该约束的事实源是架构备忘录 `docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`（仍生效，不随本归档失效）；恢复 E10/E11 实施时以该备忘录与各方案自审核记录为准。

- 2026-06-11-13-feature-import-export-backup.md（E10；归档时状态：In Progress——Slice 1 引擎已落地并 CI 绿，加密备份 + 其余主数据表诚实 defer）
- 2026-06-11-14-feature-sync-engine-icloud-foundation.md（E11；归档时状态：In Progress——引擎切片已落地并 CI 绿 + ADR-007，CloudKit 真实通道/entitlement/双设备验证诚实 defer）
