# 学习材料历史与操作表增长边界备忘录

状态：Accepted
创建日期：2026-06-16
适用范围：learning_materials、learning_material_operations、learning_material_sentences、learning_revisions、learning_memory_candidates、learning_practice_candidates 表
目的：记录学习材料历史与操作表的增长边界，明确未来清理候选策略与触发条件

## 背景

当前 learning_materials 及其关联子表（sentences / revisions / memory_candidates / practice_candidates）和 learning_material_operations 表会随着用户每次生成 / 重新分析学习材料而持续增长。当前实现没有任何自动清理、归档或压缩机制。

## 已有设计留下的扩展点

1. **单 entry 多版本**：每次重新分析会替换 analysis 行但保留旧 revision；`learning_materials` 表本身只有一个当前版本（由 `source_entry_body_hash` 判断是否需要重新生成），但 `learning_material_operations` 表会记录每次操作的完整历史。
2. **操作日志膨胀**：`learning_material_operations` 按 entry 累积，无 TTL、无上限、无归档。长时间使用的用户可能积累大量操作记录。
3. **派生子表跟随**：`learning_material_sentences`、`learning_memory_candidates`、`learning_practice_candidates` 通过 material_id 级联删除，但只有当整个 material 行被删除时才触发。当前 replaceAnalysis 只标记旧 analysis 为 stale，不会删除旧行。

## 后续任务必须重新决策的问题

1. **保留策略**：是否需要保留全部操作历史？还是只保留最近 N 次操作？
2. **清理触发条件**：
   - 按时间（TTL：N 天前的操作记录自动归档 / 清理）
   - 按数量（每个 entry 最多保留 N 条操作记录）
   - 按空间（总库大小超阈值时触发清理）
   - 按状态（stale 的 analysis 及其子行何时清理）
3. **stale analysis 清理**：当前 `replaceAnalysis` 将旧 analysis 标记为 `.stale`，但 stale 行及其 sentences / candidates 不会被自动清理。需要决策 stale 行的保留时长。
4. **同步影响**：一旦引入同步引擎，操作历史和 stale 分析是否需要同步？如果不同步，清理策略可以更激进；如果需要同步，清理前必须确保同步已完成。
5. **导出影响**：导入导出功能（E10）是否需要包含操作历史？如果不需要，清理不影响导出。

## 不应在当前阶段提前实现的内容

- 真实的自动清理任务（需要同步引擎和导出功能先确定边界）
- 基于空间阈值的清理触发（需要存储配额产品决策）
- stale analysis 自动归档（需要 E5 阅读体验收口先确认 stale 的展示需求）

## 当前最小保障

- `media_artifacts` 和 `tts_audio_artifacts` 已有基于 `invalidated_at` / `delete_after` 的清理机制（`MediaArtifactCleanupPolicy`）
- `diagnostic_events` 已有基于数量和时间的剪枝策略（`DiagnosticRetentionPolicy`：最多 1000 条 / 7 天）
- 学习材料表本身暂不清理，但可以参照 diagnostic_events 的保留策略模式设计

## 关联

- `docs/spec/007-data-storage-migration-export-and-attachments.md`：数据保留与清理
- `docs/spec/learning-content/impl.md`：learning content 实现地图
- Plan E10（导入导出与可恢复备份）：清理策略需与导出范围对齐
- Plan E11（同步引擎）：清理策略需与同步范围对齐
