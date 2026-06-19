# Reading document save transaction failure bugfix

状态：Verified
自审核状态：Reviewed
类型：bug
创建日期：2026-06-03
最后更新日期：2026-06-03

## 用户确认记录

- 2026-06-03：用户在最新测试后反馈“还是无法保存，但这次底部会提示【保存失败，请重试】”，并要求“深入排查保存失败的原因并进行修复”。本方案将该授权收敛为一次阅读文档保存事务失败排查与修复，范围优先锁定真实保存链路，不扩展到无关 UI 重构。

## 1. 需求或 bug 描述

阅读文档编辑页现在已经能显示失败提示，但用户仍然无法保存。需要继续深入排查真正的失败原因，明确是 UI 输入、App 装配、repository 事务还是数据库状态导致保存失败，并完成修复。

## 2. 当前调查结论

- 最新日志确认保存动作已经发生，且失败已从底层冒泡到 UI；问题不再是“按钮没响应”。
- `ReadingLibraryView.saveEdits` / `ReadingDocumentDetailView.saveDetailEdits` 会把失败透传到 `ReadingDocumentStore.failSavingEdit(error)`，所以现在需要继续向下排查 `store.saveDocumentEdits` 和 `repository.updateDocument`。
- `ReadingLibraryActions` 在 `AppEnvironment` 中已经真实接到 `GRDBReadingLibraryRepository.updateDocument`，不是 disabled seam。
- 当前自动化测试主要覆盖 `markdown` 来源的 update happy path；用户真实文档来自 `pastedText`，现有 repository tests 尚未用真实 pasted 文本内容覆盖保存路径。
- 模拟器真实数据库已定位，存在 `pastedText` 阅读文档；离线检查确认真实持久库的 `reading_document_lifecycle_events` 表约束仍停留在旧版本，不允许 `event_type = 'updated'`。
- 这意味着问题不是 `rebuildStructure`、不是 UI 输入，也不是 disabled seam，而是旧持久数据库缺少针对阅读更新事件的迁移补丁；新建 in-memory 测试库之所以一直正常，是因为建表 SQL 已包含 `updated`。

## 3. 目标

1. 找到阅读保存失败的真实根因，而不是继续只修饰错误提示。
2. 用失败测试稳定复现该问题，优先覆盖真实 `pastedText` 文档更新场景。
3. 实施最小修复，让用户导入或粘贴得到的阅读文档都能正常保存编辑。
4. 视需要补充更具体的失败映射，避免后续同类事务失败继续被折叠成泛化“保存失败”。

## 4. 范围

- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingLibraryRepositoryTests.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingLibraryRepository.swift`
- 如根因在装配或 store 层，扩展到：
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryStore.swift`
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
  - `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/*`
- `docs/plans/active/2026-06-03-bug-reading-document-save-transaction-failure.md`

## 5. 不做什么

- 不扩大到阅读编辑器视觉改版。
- 不借机重构整个 Reading store 架构。
- 不处理与保存失败无关的数据库 WAL warning 或性能告警，除非它们被证明就是这次失败根因。

## 6. 根因与修复策略

根因：

- 真实持久库中的 `reading_document_lifecycle_events` 仍使用旧 CHECK 约束：
  `('imported', 'opened', 'softDeleted', 'restored', 'assignedCollection', 'removedCollection', 'tagged', 'untagged')`
- `GRDBReadingLibraryRepository.updateDocument(...)` 在事务末尾会写入 `ReadingDocumentLifecycleEventType.updated`。
- 因此编辑保存时事务会在 lifecycle event 插入阶段失败，并被上层 UI 映射成“保存失败，请重试”。

修复策略：

1. 新增一条数据库迁移，专门升级旧的 `reading_document_lifecycle_events` 表定义。
2. 迁移方式采用重建表并保留历史数据，而不是简单忽略旧约束。
3. 同时补一个真实 `pastedText` 更新用例，确保阅读材料来源不会影响保存路径。

## 7. TDD 落点

实际红绿路径：

1. 新增 `AppDatabaseReadingMigrationTests`：
   `reopening a persisted database upgrades reading lifecycle events to accept updated actions`
   先红测，稳定复现“旧持久库保存失败”的真实根因。
2. 新增 `GRDBReadingLibraryRepositoryTests`：
   `pasted text document with markdown-like content can be updated`
   确认 `pastedText` 来源本身不是失败根因。
3. 补 `v13_upgrade_reading_lifecycle_events_for_document_updates` 迁移和表重建 helper，回到绿测。

## 8. 验证命令

```bash
swift test --package-path Packages/LangoTraceData --filter GRDBReadingLibraryRepositoryTests
swift test --package-path Packages/LangoTraceUI --filter ReadingLibraryStoreTests
scripts/check-docs.sh
git diff --check
```

根因修复后追加：

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

## 9. 严格方案自审核记录

```text
审核日期：2026-06-03
审核方式：主会话自审核
审核轮次：单轮
发现摘要：
1. 原 UI bugfix 只修复了错误提示，没有触及真实数据库迁移差异，因此对旧持久库无效。
2. 新建 in-memory 数据库和用户真实持久库行为不一致，必须补持久库迁移红测，不能继续只靠 repository happy path。
3. 这次修复的正确落点是数据迁移层，而不是继续加 UI 特判或 store 重试。
写回修订：
1. 将优先排查方向收敛为 schema drift / migration drift。
2. 将首个红测调整为 persisted database migration test。
3. 将修复范围前移到 `AppDatabase` 与 `AppDatabaseReadingMigration`。
仍需用户确认的问题：无。用户已明确授权立即修复。
是否允许进入实现：允许
```

## 10. 完成标准

- 能明确说明保存失败发生在保存链路的哪一层。
- 有新增或更新的自动化测试先失败后通过。
- 用户真实阅读文档可以保存成功。
- 文档和验证结果同步收口。

## 11. 实施记录

- 2026-06-03：采集最新 `logs/latest.log`，确认保存动作已触发且失败已冒泡到 UI。
- 2026-06-03：核对 `ReadingViews -> ReadingLibraryStore -> ReadingLibraryActions -> GRDBReadingLibraryRepository` 链路，排除 disabled seam。
- 2026-06-03：离线检查模拟器真实 SQLite，发现 `reading_document_lifecycle_events` 仍使用旧 CHECK 约束，不接受 `updated`。
- 2026-06-03：通过 `sqlite3` 直接插入 `event_type='updated'` 复现约束失败，确认真实根因。
- 2026-06-03：先补 `AppDatabaseReadingMigrationTests` 红测，稳定复现旧持久库重开后仍无法接受 `updated` 事件。
- 2026-06-03：新增 `v13_upgrade_reading_lifecycle_events_for_document_updates` 迁移；在 `AppDatabaseReadingMigration.swift` 中增加表定义升级 helper，并保留旧事件数据。
- 2026-06-03：补充 `GRDBReadingLibraryRepositoryTests` 的 `pastedText` 更新用例，确认 `pastedText` 不是失败来源。
- 2026-06-03：验证通过：
  - `swift test --package-path Packages/LangoTraceData --filter AppDatabaseReadingMigrationTests`
  - `swift test --package-path Packages/LangoTraceData --filter GRDBReadingLibraryRepositoryTests`
  - `swift test --package-path Packages/LangoTraceData`
  - `scripts/check-docs.sh`
  - `git diff --check`
  - `scripts/verify.sh`

## 12. 剩余风险

- 这次修复依赖应用重新打开后执行数据库迁移；如果用户不重启当前进程，旧连接不会自动升级。
- 当前 UI 仍把多数 repository 失败折叠为通用“保存失败，请重试”；这不影响本次根因修复，但后续若还有其他保存失败来源，仍建议继续细化错误分类。
