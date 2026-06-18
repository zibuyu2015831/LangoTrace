# 任务方案：开发系列进度仪表盘（跨会话恢复指针）

状态：In Progress
自审核状态：N/A（导航/指针文档，不含生产代码变更）
类型：docs
创建日期：2026-06-15
最后更新日期：2026-06-18（E5 Slice 1 纯本地回译落地，方案因 Slice 2 deferred 保持 active；当前指针推进至 E6）

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

> **基线**：plan 01 全部 Phase 已 CI `Build & Test` 全绿（run `27595028506`，HEAD `2258e10`），已移入 `done/`。

## 当前指针

> **批量自主执行已编排**（2026-06-18）：E6…LM01 的全部剩余工作项方案，由仓库根目录编排手册 `BATCH-EXECUTION-PLAYBOOK.md` 统一驱动（用户已完全预授权，每方案独立分支 → 本地 merge dev → CI 绿 → 移 done/，不动 main，AI 自审后重排顺序）；`/goal` 指令见根目录 `BATCH-EXECUTION-GOAL.md`。本仪表盘仍为进度事实源，run 级游标见 Playbook §9。

> **当前指针**：E6 `docs/plans/active/2026-06-11-09-feature-ai-request-preview-and-log-foundation.md`。E5 **Slice 1（纯本地回译）已于 2026-06-18 落地并 CI 验证全绿**（run `27734245351`，含 iPhone/iPad/macOS App target 构建 + macOS app 回译注册编译验证）：App 现注册 `shadowing / dictation / backtranslation` 三段，回译题面→作答→对照参考三态闭环，参考经新增只读 seam `LearningContentRepository.sentenceAnalysis` 懒加载 + snapshot 兜底，attempt 复用 `practice_text_attempts`（diff 列由 `recordTextAttempt` repository 不变量恒 NULL）。**E5 Slice 2（可选 AI 点评）deferred**，双重门禁待 E6 落地 + 单独隐私授权，故 E5 方案保持 active；下一步推进 E6，E6 完成后再回到 E5 Slice 2。

## 状态总表

状态取值：`Draft`（草稿，需逐份自审核 + 用户确认）→ `User Approved` → `In Progress` → `Implemented` → 移入 `done/`。

| 序 | 系列 | 方案 | 主题 | 状态 |
|---|---|---|---|---|
| 01 | E0a | `2026-06-11-01-refactor-architecture-foundations` | Core/Data/AI/Speech 架构地基整固 | ✅ **Verified**（CI run `27595028506` 全绿，已移入 done/） |
| 02 | E0b | `2026-06-11-02-refactor-ui-architecture-debt` | UI/App 层结构债清偿 | ✅ **Verified**（2026-06-17 本机 UI/Data/Core 三包测试全绿，已移入 done/） |
| 03 | E1 | `2026-06-11-03-feature-record-timeline-and-filters` | 记录生活时间线 + 三端筛选投影 | ✅ **Verified**（2026-06-17 全 5 Phase 实施完成 + post-E1 清理，已移入 done/） |
| 04 | E2 | `2026-06-11-04-feature-entry-photo-attachment-and-photo-writing` | 照片附件主数据 + 照片引导写作 | ✅ **Verified**（2026-06-17 全 5 Phase 实施完成 + 文档收口，已移入 done/） |
| 04-FU | E2 follow-up | `2026-06-17-bug-photo-writing-detail-image-missing` | 照片写作记录详情不展示图片 | ✅ **Verified**（2026-06-17 模拟器验证通过，含旧库修复；已移入 done/） |
| 04-FU-b | E2 infra | `2026-06-17-bug-photo-detail-card-layout` | 照片记录详情图片卡片布局修复 | ✅ **Verified**（2026-06-17 已实施 + 验证，已移入 done/） |
| 04-FU-c | E2 infra | `2026-06-17-bug-photo-writing-legacy-attachment-repair` | 照片写作旧数据附件修复与运行验证 | ✅ **Verified**（2026-06-17 模拟器验证通过，已移入 done/） |
| 05 | R1 | `2026-06-11-05-feature-reading-experience-completion` | 阅读体验收口 | ✅ **Implemented**（2026-06-17 全 4 Phase 实施完成，已移入 done/） |
| 06 | E3 | `2026-06-11-06-feature-practice-mode-routing-foundation` | 练习方式路由基础 | ✅ **Implemented**（2026-06-17 Core/Data/UI 轻量测试通过，已移入 done/） |
| 07 | E4 | `2026-06-11-07-feature-practice-dictation` | 听写练习 | ✅ **Implemented**（2026-06-18 Core/Data/UI 轻量测试通过，已移入 done/） |
| 08 | E5 | `2026-06-11-08-feature-practice-backtranslation` | 回译练习 | 🟡 **In Progress**（Slice 1 纯本地已落地，2026-06-18 CI run `27734245351` Build & Test 全绿；Slice 2 AI 点评 deferred 待 E6 + 单独隐私授权，方案保持 active） |
| 09 | E6 | `2026-06-11-09-feature-ai-request-preview-and-log-foundation` | AI 请求预览 + 请求日志基础 | ⚪ Draft |
| 10 | E7 | `2026-06-11-10-feature-memory-deposit-foundation` | 记忆沉淀基础 | ⚪ Draft |
| 11 | E8 | `2026-06-11-11-feature-memory-review-queue` | 记忆复习队列 | ⚪ Draft |
| 12 | E9 | `2026-06-11-12-feature-local-fts-search` | 本地 FTS 全文搜索 | ⚪ Draft |
| 13 | E10 | `2026-06-11-13-feature-import-export-backup` | 导入导出与可恢复备份包 | ⚪ Draft |
| 14 | E11 | `2026-06-11-14-feature-sync-engine-icloud-foundation` | 同步引擎 + iCloud 首通道 | ⚪ Draft |
| 15 | E12 | `2026-06-11-15-feature-settings-status-projection` | 设置真实状态投影 | ⚪ Draft |
| — | LM01 | `2026-06-15-01-feature-learner-model-boundary-and-ability-coverage` | 学习者模型边界 + Ability 覆盖 | ⚪ Draft |
| — | — | `2026-06-15-chore-prototype-large-screen-density-and-state-coverage` | 原型大屏密度 + 状态原型补全 | ✅ **Verified**（2026-06-16 截图验收通过，已移入 done/） |
| — | infra | `2026-06-17-bug-build-errors-xcodegen-import-exhaustive-switch` | XcodeGen 注册 + import + exhaustive switch 构建修复 | ✅ **Verified**（2026-06-17 已修复，已移入 done/） |
| — | infra | `2026-06-17-bug-generation-sqlite-unique-constraint` | 生成学习材料 SQLite 唯一约束冲突修复 | ✅ **Verified**（2026-06-17 已修复，已移入 done/） |

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
| 3-余 | 协议默认实现移除 / RedactedSecret / Reading 范围整数偏移 | ✅ 已实施 + CI 绿 |
| 4 | 数据层：迁移、44 处枚举解码 decodeStored、软删除列修正、FK/CHECK、@MainActor | ✅ 已实施 + CI 绿 |
| 5 | AI/Speech 尾项：bytes(for:) 流式、AIBoundary/SpeechBoundary 统一、WAV RIFF chunk walker、spec 012 prompt v4 等 | ✅ 已实施 + CI 绿 |

## plan 02（E0b）Phase 级子进度

权威范围见方案 `docs/plans/done/2026-06-11-02-refactor-ui-architecture-debt.md`；此处仅记完成度。

| Phase | 内容 | 状态 |
|---|---|---|
| 1 | iPhone 每个 Tab 独立 `NavigationStack`，消除共享路径 | ✅ 已实施 + 本机测试绿 |
| 2 | iPad / macOS 消除嵌套 `ScrollView` | ✅ 已实施 + 本机测试绿 |
| 3 | TTS 播放 sink 集中到 `LearningContentStore`；`ReadingTTSOutcome` 类型化枚举替代 `String` 信号 | ✅ 已实施 + 本机测试绿 |
| 4 | `EntryPracticeStatus` 结构化枚举替代 `practiceSummary: String`；中文 fallback 移出数据层 | ✅ 已实施 + 本机测试绿 |
| 5 | `LanguageOverrideBox`（`NSRecursiveLock`）替代 `nonisolated(unsafe) static var`；`saveRendering` 写入 `LearningContentRepository` 协议 | ✅ 已实施 + 本机测试绿 |
| 6 | 测试债清偿：源码断言测试替换为行为 seam 测试；spec 009 新增禁止「读取源码断言子串」规则；PhoneIOSConvergenceTests 等存量登记为迁移 backlog | ✅ 已实施 + 本机测试绿 |

## plan 03（E1）Phase 级子进度

权威范围见方案 `docs/plans/done/2026-06-11-03-feature-record-timeline-and-filters.md`；此处仅记完成度。

| Phase | 内容 | 状态 |
|---|---|---|
| 1 | 共享筛选与投影类型（`EntryTimelineFilter`、`groupEntriesByDay`、`EntryMaterialStatusPill` 等 UI 纯函数层） | ✅ 已实施 + 本机测试绿 |
| 2 | Data 只读投影查询（`learningPracticeReadiness` 协议 + GRDB SQL EXISTS 实现） | ✅ 已实施 + 本机测试绿 |
| 3 | iPhone 时间线（筛选 chips、日期分组、空态两态、EntryCard pill 替换） | ✅ 已实施 + 本机测试绿 |
| 4 | iPad 与 Mac 接线（删除 PadFilter、EntryTimelineRow pill、Mac sidebar 计数驱动） | ✅ 已实施 + 本机测试绿 |
| 5 | 文档收口 + post-E1 清理（platform inventory、impl map、architecture note、String Catalog orphan 清理） | ✅ 已实施 + 本机测试绿 |

## plan 04（E2）Phase 级子进度

权威范围见方案 `docs/plans/done/2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md`；此处仅记完成度。

| Phase | 内容 | 状态 |
|---|---|---|
| 0 | Spike gate：v17 `media_artifacts` CHECK 扩展 + TDD 红绿验证 | ✅ 已实施 + 本机测试绿 |
| 1 | Core photo model（`EntryPhotoAttachment`、`PhotoArtifactKey`）+ v17 migration `entry_photo_attachments` + `GRDBEntryPhotoAttachmentRepository` | ✅ 已实施 + 本机测试绿 |
| 2 | `PhotoImportPipeline`（EXIF GPS strip → hash → 缩略图 → staging → 原子 move → 元数据事务）| ✅ 已实施 + 本机测试绿 |
| 3 | `PhotoWritingView` 替换 mock `PhonePhotoWritingPreviewView`；`PhotoDisplayActions` 环境值；`AppEnvironment` 装配 | ✅ 已实施 + 本机测试绿 |
| 4 | `EntryTimelineFilter.photo` 升级含 `hasPhotoAttachment`；`EntryCard` 缩略图；`EntryDetailView` 全宽照片 | ✅ 已实施 + 本机测试绿 |
| 5 | 文档收口（impl map、platform inventory、spec 007、architecture note、方案移入 done/）| ✅ 已完成（commit c10c412）|

## plan 05（R1）Phase 级子进度

权威范围见方案 `docs/plans/done/2026-06-11-05-feature-reading-experience-completion.md`；此处仅记完成度。

| Phase | 内容 | 状态 |
|---|---|---|
| 1 | DATA-08 结构构建统一（`rebuildStructure` 真实分句 + `importInlineDocument` 同事务构建 + v21 `content_revision` 列） | ✅ 已实施 + 本机测试绿 |
| 2 | 阅读进度与收藏（v22 migration + `GRDBReadingLibraryRepository` + `ReadingWordCounter` + UI 三段元信息 + 收藏 + 筛选 chips） | ✅ 已实施 + 本机测试绿 |
| 3 | iPad inspector 折叠降级（`canFoldInspector` + 折叠按钮 + 底部 compact 面板 safeAreaInset） | ✅ 已实施 + 本机测试绿 |
| 4 | 解释语言模式面板控件（`switchExplanationMode` + `ExplanationLanguageModePicker` + 三端接线） | ✅ 已实施 + 本机测试绿 |
| 5 | 文档收口（spec 012 变更记录 + platform inventory + 架构备忘录 §5 + migration 审查说明 + 移入 done/） | ✅ 已完成 |

## 维护约定

- 每完成一个 Phase / 一份方案状态推进时，同步更新本表（与对应方案的 `状态：` 字段保持一致）。
- 本文件随系列收尾一并移入 `done/`；它存在的意义就是系列全程的「中断后从哪继续」。
- 详细决策、验证结果、TDD 落点不写在这里，写回各权威文档并在此留指针。
