# 任务方案：开发系列进度仪表盘（跨会话恢复指针）

状态：In Progress
自审核状态：N/A（导航/指针文档，不含生产代码变更）
类型：docs
创建日期：2026-06-15
最后更新日期：2026-06-16（Phase 4 在 MacBook 环境实施并本机六包测试全绿；CI 待验证）

## 这份文档是什么

本文件是 `docs/plans/active/` 的**活的进度仪表盘与跨会话恢复指针**，只做导航：

- 一行状态登记 active/ 全部方案；
- 标出推荐实施顺序与「下一步从这里继续」的当前指针；
- 承载单份方案的状态字段看不出的 **Phase 级子进度**（当前主要是 plan 01）。

它**不是**事实源，不替代任何权威文档：

- 历史决策与 ~110 条审查发现处置全表 → 主控文档（已 Done）`docs/plans/done/2026-06-11-chore-code-review-and-dev-plan-series.md` 附录 A。
- 验证真相（Mac/CI 跑没跑、绿没绿）→ `docs/testing/2026-06-15-architecture-foundations-pending-verification.md` 及后续各 Phase 待验证清单。
- 每份方案的权威范围、TDD 落点、自审核 → 各方案文件本身。

冲突时以上述权威文档为准；本仪表盘只反映「推进到哪了」。

## 实施环境约束

读取本仪表盘时，须先检测开发设备环境，按以下分支约束实施方式：

- **Linux 环境**：无 Swift 工具链，所有 `swift test` / `xcodebuild` / `swiftformat` / `swiftlint` 走 GitHub Actions；触发 CI 前需将仓库临时设为 public、commit message 带 `[ci]`，跑完可设回 private。
- **MacBook 环境**：本机可执行轻量单包测试（`swift test --package-path Packages/<target>`）和格式检查（`swiftformat --lint` / `swiftlint`）；重测试（全量验证 `scripts/verify.sh`、三端构建、跨多包测试）一律放 GitHub Actions，避免被动散热设备过热降频。

> **基线**：plan 01 Phase 1–3c 已 CI `Build & Test` 全绿（run `27546863012`，HEAD `56ef9d4`）；Phase 3 余项（协议默认实现移除 / RedactedSecret / TextUnitRange）已在 MacBook 本机六包测试全绿（HEAD `f4e1cb7`），CI 验证待推送后触发。

## 当前指针

> **下一步候选**：plan 01 的 Phase 5（AI/Speech 尾项：bytes(for:) 流式 / AIBoundary/SpeechBoundary 统一 / WAV RIFF chunk walker / spec 012 prompt v4）。

## 状态总表

状态取值：`Draft`（草稿，需逐份自审核 + 用户确认）→ `User Approved` → `In Progress` → `Implemented` → 移入 `done/`。

| 序 | 系列 | 方案 | 主题 | 状态 |
|---|---|---|---|---|
| 01 | E0a | `2026-06-11-01-refactor-architecture-foundations` | Core/Data/AI/Speech 架构地基整固 | 🟡 **In Progress**（见下方 Phase 子进度） |
| 02 | E0b | `2026-06-11-02-refactor-ui-architecture-debt` | UI/App 层结构债清偿 | ⚪ Draft |
| 03 | E1 | `2026-06-11-03-feature-record-timeline-and-filters` | 记录生活时间线 + 三端筛选投影 | ⚪ Draft |
| 04 | E2 | `2026-06-11-04-feature-entry-photo-attachment-and-photo-writing` | 照片附件主数据 + 照片引导写作 | ⚪ Draft |
| 05 | R1 | `2026-06-11-05-feature-reading-experience-completion` | 阅读体验收口 | ⚪ Draft |
| 06 | E3 | `2026-06-11-06-feature-practice-mode-routing-foundation` | 练习方式路由基础 | ⚪ Draft |
| 07 | E4 | `2026-06-11-07-feature-practice-dictation` | 听写练习 | ⚪ Draft |
| 08 | E5 | `2026-06-11-08-feature-practice-backtranslation` | 回译练习 | ⚪ Draft |
| 09 | E6 | `2026-06-11-09-feature-ai-request-preview-and-log-foundation` | AI 请求预览 + 请求日志基础 | ⚪ Draft |
| 10 | E7 | `2026-06-11-10-feature-memory-deposit-foundation` | 记忆沉淀基础 | ⚪ Draft |
| 11 | E8 | `2026-06-11-11-feature-memory-review-queue` | 记忆复习队列 | ⚪ Draft |
| 12 | E9 | `2026-06-11-12-feature-local-fts-search` | 本地 FTS 全文搜索 | ⚪ Draft |
| 13 | E10 | `2026-06-11-13-feature-import-export-backup` | 导入导出与可恢复备份包 | ⚪ Draft |
| 14 | E11 | `2026-06-11-14-feature-sync-engine-icloud-foundation` | 同步引擎 + iCloud 首通道 | ⚪ Draft |
| 15 | E12 | `2026-06-11-15-feature-settings-status-projection` | 设置真实状态投影 | ⚪ Draft |
| — | LM01 | `2026-06-15-01-feature-learner-model-boundary-and-ability-coverage` | 学习者模型边界 + Ability 覆盖 | ⚪ Draft |
| — | — | `2026-06-15-02-chore-prototype-large-screen-density-and-state-coverage` | 原型大屏密度 + 状态原型补全 | 🟢 **Implemented**（待用户对截图最终判断后移入 done/） |

说明：

- 01–15 是 2026-06-11 全量代码审查派生的连号实施系列；E 编码与处置见主控文档附录 A。
- 后两份为 2026-06-15 新增：LM01 仍 Draft；原型收尾已实现并自审核 Reviewed，仅差归档。

## plan 01（E0a）Phase 级子进度

权威范围见方案 §12；验证收敛见待验证清单。此处仅记完成度。

| Phase | 内容 | 状态 |
|---|---|---|
| 1 | AI text provider adapter 抽象 | ✅ 已实施 + CI 绿 |
| 2 | 错误分类补全与错用修正 | ✅ 已实施 + CI 绿 |
| 3a | 死代码清理 + 不变量收紧 | ✅ 已实施 + CI 绿 |
| 3b | StableHashing 收敛（8 处散落哈希 → Core 共享工具） | ✅ 已实施 + CI 绿 |
| 3c | normalized() 拆分（normalizedDraft/validated）+ 时钟注入 | ✅ 已实施 + CI 绿 |
| 3-余 | 协议默认实现移除 / RedactedSecret / Reading 范围整数偏移 | ✅ 已实施 + 本机六包测试全绿（CI 待验证） |
| 4 | 数据层：迁移、44 处枚举解码 decodeStored、软删除列修正、FK/CHECK、@MainActor | ✅ 已实施 + 本机六包测试全绿（CI 待验证） |
| 5 | AI/Speech 尾项：bytes(for:) 流式、AIBoundary/SpeechBoundary 统一、WAV RIFF chunk walker、spec 012 prompt v4 等 | ⬜ 未启动 |

## 维护约定

- 每完成一个 Phase / 一份方案状态推进时，同步更新本表（与对应方案的 `状态：` 字段保持一致）。
- 本文件随系列收尾一并移入 `done/`；它存在的意义就是系列全程的「中断后从哪继续」。
- 详细决策、验证结果、TDD 落点不写在这里，写回各权威文档并在此留指针。
