# 方案自审核协议本地化与任务类型口径修正

状态：Verified
自审核状态：Reviewed
类型：docs
创建日期：2026-06-01
最后更新日期：2026-06-05

## 用户确认记录

- 2026-06-01：用户指出 `docs/plan-review-protocol.md` 是从其他项目拷贝而来，要求评估并优化完善为本项目 active plan 创建后的方案审核协议；评估确认方向可纳入，但必须移除外部项目名、`dev_docs/` 路径、强制 commit 和 memo 落点冲突。
- 2026-06-01：用户明确要求立即进行该协议的优化和完善。本范围为“将外来方案自审核协议改造为 LangoTrace 的实现前 active plan 自审核协议，并接入现有 plans / review 权威关系”。
- 2026-06-05：在“检查 active plan、对照代码”任务中，本子范围从原 `docs/plans/active/2026-05-23-docs-doc-constraint-index.md` 拆分为独立、已完成的 docs 方案；约束路由索引子范围仍留在原 active plan，待用户确认后实施。

## 1. 需求描述

将根目录外来文档 `docs/plan-review-protocol.md`（含 `AnvilDeck`、`dev_docs/` 路径、强制 commit 与 memo 落点）改造为 LangoTrace 的 active plan 实现前严格方案自审核协议，并修正任务类型口径漂移（`docs/plans/README.md` 已允许 `docs` 类型，但 `docs/_meta/documentation-system.md` 任务类型清单缺少 `docs`）。

本子范围**不包含** `docs/_meta/documentation-constraints.md` 约束路由索引，以及与该索引耦合的 README / 模板“约束映射与验证路径”“TDD / 测试落点”必填字段（仍由原 active plan 跟踪，待用户确认）。

## 2. 现状（实施前）

- `docs/plan-review-protocol.md` 位于仓库根 docs 目录，含外部项目名与 `dev_docs/` 路径，与 LangoTrace 文档体系冲突。
- `docs/_meta/documentation-system.md` 任务类型清单缺少 `docs`，与 `docs/plans/README.md` 不一致。
- 任务方案模板与计划规范缺少“严格方案自审核记录”章节与 `自审核状态` 二态规范。

## 3. 目标

- 协议落点改为 `docs/plans/plan-review-protocol.md`，消除外来项目名与 `dev_docs/` 路径。
- 协议明确只管实现前 active plan 审核，不替代 ADR、spec、architecture、workflow、review、testing 文档。
- 保留双轮审核、P0-P3 分级、证据化发现写回 active plan，将强制 commit 改为条件性记录。
- `docs/_meta/documentation-system.md` 任务类型清单补充 `docs`，与 `docs/plans/README.md` 一致。
- 任务方案规范与模板新增 `自审核状态` 二态（`Not Reviewed` / `Reviewed`）与“严格方案自审核记录”章节，并在必要入口加入轻量引用。

## 4. 范围

- 协议改造与落点迁移。
- 任务类型口径修正。
- `自审核状态` 二态规范与模板章节。
- 目录职责登记与入口轻量引用。

## 5. 不做什么

- 不创建 `docs/_meta/documentation-constraints.md` 约束路由索引（留在原 active plan，待用户确认）。
- 不新增 README / 模板的“约束映射与验证路径”“TDD / 测试落点”必填字段（与索引耦合，一并延后）。
- 不修改 Swift 源码、工程配置、Package 或测试代码。
- 不恢复 `dev_docs/` 或外来目录。
- 不强制每次方案创建 / 修订单独 commit。

## 6. 涉及文档路径

- `docs/plans/plan-review-protocol.md`（新增 / 改造）
- `docs/plans/README.md`
- `docs/plans/examples/task-plan-template.md`
- `docs/_meta/documentation-system.md`
- `docs/_meta/directory-responsibilities.md`
- `docs/README.md`
- 删除：根目录 `docs/plan-review-protocol.md`

## 7. 实施记录

- 2026-06-01：删除外来根目录 `docs/plan-review-protocol.md`，新增 `docs/plans/plan-review-protocol.md`；改为 LangoTrace 路径、权威边界、双轮审核、P0-P3 发现写回、条件性 commit 记录与对 `docs/review/README.md` 的职责分离；同步更新 `docs/README.md`、`docs/plans/README.md`、`docs/plans/examples/task-plan-template.md`、`docs/_meta/documentation-system.md`、`docs/_meta/directory-responsibilities.md`。
- 2026-06-01：补充 `自审核状态` 二态规范（`Not Reviewed` / `Reviewed`），模板新增“严格方案自审核记录”章节，`docs/plans/README.md` 新增“状态说明”。
- 2026-06-05：本子范围从原约束索引 active plan 拆分为独立 Verified 方案。

## 8. 复查方法与验证

- `rg -n "AnvilDeck|dev_docs" docs/plans/plan-review-protocol.md`：无命中。
- `ls docs/plan-review-protocol.md`：不存在（旧根目录文件已删除）。
- `docs/_meta/documentation-system.md` 任务类型清单含 `docs`（第 167 行附近）。
- `docs/plans/README.md` 含 `自审核状态` 二态说明（“状态说明”章节）与协议引用。
- `docs/plans/examples/task-plan-template.md` 含 `自审核状态：Not Reviewed` 与“严格方案自审核记录”章节。
- `docs/_meta/directory-responsibilities.md` 已登记 `docs/plans/plan-review-protocol.md`。

## 9. 复查结论（2026-06-05，基于文档现状）

子代理对照磁盘文件复查，确认本子范围 7 项事实全部 ACCURATE：协议文件存在且无外来项目名 / 路径、旧根目录文件已删除、任务类型清单含 `docs`、二态规范与模板章节就位、目录职责已登记。本子范围满足其完成标准，标记为 Verified 并移入 `docs/plans/done/`。

## 10. 完成标准

- 协议已成为 LangoTrace active plan 实现前严格方案自审核协议，无外来项目名或 `dev_docs/` 路径。
- 任务类型口径在 README 与 `_meta` 一致。
- `自审核状态` 二态规范与模板章节就位。
- 已运行文档门禁并记录结果。

## 11. 剩余风险

- 约束路由索引及其配套必填字段仍未落地，由原 active plan 跟踪；本方案不覆盖该范围。

## 12. 关联方案

- 父方案（约束路由索引子范围，仍 active）：`docs/plans/active/2026-05-23-docs-doc-constraint-index.md`。
