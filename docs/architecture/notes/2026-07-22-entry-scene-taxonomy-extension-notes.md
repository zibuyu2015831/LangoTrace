# 开发备忘录：记录场景标签（scene）体系的后续演进

状态：开发备忘录（非正式方案 / 非事实源）
创建日期：2026-07-22
来源：`docs/plans/done/2026-07-22-feature-entry-scene-tags-and-timeline-filter.md`（v1 落地时登记的非目标）

> 本备忘录只登记尚未进入正式方案的跨任务提醒；创建相关任务方案前应检查本文件，但不得把内容直接当作已接受实现事实。

## 1. 当前事实（v1 边界）

- `entries.scene` 为单值 TEXT：预设 slug（`EntryScenePreset` 六值）、自由文本或空串（未标注）。
- **自由文本 scene 的生产入口是 E10 导入**：`GRDBLocalExportService.importPackage` 原样落 `PortableEntrySnapshot.scene`，因此展示与筛选层必须永远兼容非预设值（`displayScene` 三态、facet 附后排序）。
- 场景筛选为内存过滤（沿 store 全量加载惯例）；macOS 无任何时间线筛选 UI（状态 + 场景均无）。
- scene 不进入任何 AI 请求路径、请求预览类目。

## 2. 登记的后续切片

1. **场景编辑**：✅ 已于 2026-07-22 落地（`docs/plans/done/2026-07-22-feature-entry-scene-edit.md`）：`updateEntryScene` 窄方法 + 三端共享详情 `EntrySceneEditRow`。「合并为 `updateEntry(fields:)`」经该 plan 评估**暂不采纳**——仅两个更新维度且语义不同（body 关联材料 stale 判定、scene 是纯标签），窄方法与 `updateEntryBody` 对称更清晰；第三个可更新字段出现时再重估。
2. **Mac 时间线筛选整体切片**：状态筛选与场景筛选一起补（Mac 当前 entries 未过滤直传）。
3. **搜索联动**：SearchPalette 加场景维度；若时间线数据量增长，评估 SQL 级 `WHERE scene = ?` 与 repository 查询方法。
4. **自定义场景 / 多标签**：用户自造标签与一条记录多标签。多标签需 M:N 表 + migration + 标签管理 UX；届时重估「场景是标签」是否升级为一等 tag 体系（涉及 spec/007 与导出 schema，须走 active plan + 可能的 ADR）。产品主参考 §8.1 :185 的「社交媒体」等未纳入 v1 预设，可作自定义场景素材。
5. **场景进入 AI 上下文**：若未来把 scene 注入 Prompt（如按场景选 Preset），属外发类目变化，须过 spec/005 请求预览披露与 Prompt Registry 更新。

## 3. 约束提醒

- `EntryScenePreset` rawValue 是存储契约（Core 测试已钉死），改 slug 即孤儿化历史数据，只能加不减、不改。
- 场景 label 双通道纪律：预设 slug 走本地化、自由文本作为用户内容严禁进 String Catalog 查找（spec/006；`FilterPill` text 入口与 `SceneChipButton` 注释已声明）。
