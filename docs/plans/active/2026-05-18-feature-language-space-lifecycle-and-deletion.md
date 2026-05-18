# 任务方案：语言空间生命周期与删除边界

类型：feature

状态：Draft

创建日期：2026-05-18

最后更新日期：2026-05-18

## 1. 用户确认记录

2026-05-18：第一轮 UI 收敛方案要求将“添加学习语言 / 切换语言 / 删除语言空间”拆成独立 active plan，避免把删除能力混入 UI 修复。本方案仅记录后续实现边界；尚未获得用户确认进入实现。

## 2. 需求描述

语言空间是语迹的核心学习上下文。后续必须支持用户添加新的学习语言、在多个语言空间之间切换，并在有充分保护的前提下删除不再需要的语言空间。

删除语言空间会影响 Entry、Rendering、Practice、Memory、附件、向量索引、AI 请求日志和同步状态，因此不能作为简单 UI 按钮补丁实现。

## 3. 现状描述

- 当前 App 只有内存语言空间 preview。
- `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md` 只覆盖单个当前语言空间的持久化与启动恢复，明确不实现多个语言空间列表、切换、删除、重命名或排序。
- 第一轮 UI 收敛只把语言空间入口改为当前 Space summary 和 lifecycle placeholder，不创建、切换或删除真实空间。

## 4. 目标

- 定义语言空间列表、添加、切换、重命名和删除的产品与数据边界。
- 定义删除前导出、级联影响、撤销窗口、最后一个空间回退和同步 tombstone 策略。
- 为后续 SQLite / GRDB 主存储和 Sync Engine 保留可替换实现边界。
- 让 UI 能诚实表达当前空间 summary、后续 lifecycle 能力和删除风险。

## 5. 范围

本方案后续应覆盖：

- `LanguageSpaceRepository` 多空间协议形态。
- 当前空间选择与最近使用空间恢复。
- 添加学习语言和切换语言空间。
- 删除语言空间确认流。
- 最后一个语言空间删除后的 fallback：回到 onboarding、创建新空间或显示语言空间选择空态。
- 删除前导出或备份提示。
- Entry、Rendering、Practice、Memory、附件、向量索引、请求日志和诊断日志的级联策略。
- 可撤销删除或软删除窗口。
- 已同步或待同步空间的 tombstone / conflict 语义。

## 6. 不做什么

- 不在第一轮 UI 收敛中实现真实删除。
- 不绕过 `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md` 的单空间启动恢复计划。
- 不把语言空间当成 Project、团队、课程或工作区管理。
- 不在没有导出、撤销或同步 tombstone 策略前提供不可恢复删除。

## 7. 证据与决策依据

- `docs/README.md`：一个语言空间对应一门目标语言，工作、生活、旅行、会议和情绪不是空间。
- `docs/decisions/004-use-language-space-as-primary-model.md`：语言空间是核心信息模型。
- `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md`：单空间持久化计划明确排除多空间、切换和删除。
- `docs/plans/active/2026-05-18-feature-first-round-ui-convergence.md`：任务 11 要求独立记录 lifecycle 和删除方案。

## 8. 涉及代码文件路径

预计涉及：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/`
- `Packages/LangoTraceData/Sources/LangoTraceData/`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/`
- `LangoTraceApp/`

## 9. 参考代码文件路径

预计参考：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpace.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceRepository.swift`
- `LangoTraceApp/AppSessionState.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceFooter.swift`

## 10. 涉及文档路径

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/review/INDEX.md`
- `docs/testing/README.md`

## 11. 实施方案

后续恢复本方案时应先补充详细设计，再实现：

1. 设计多空间数据模型和 repository 协议。
2. 实现添加和切换，不先实现删除。
3. 实现当前空间恢复和最后空间 fallback。
4. 设计删除确认流，包含影响摘要、导出前置和撤销窗口。
5. 接入级联删除或软删除策略。
6. 接入同步 tombstone 和冲突处理语义。
7. 增加 Data、Core、UI 和 App 路由测试。
8. 更新导航、架构、数据存储、测试和审查文档。

## 12. 复查方法

- 确认删除不会绕过导出、确认和撤销策略。
- 确认最后一个语言空间被删除后不会创建隐式默认空间。
- 确认切换空间不会改变 App 界面语言。
- 确认向量索引作为可重建派生数据处理，但不把敏感内容误当普通缓存。
- 确认已同步空间删除会生成 tombstone，而不是静默丢失远端状态。

## 13. 验证命令

后续实现时至少运行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
git status --short
```

## 14. 文档影响检查

本方案后续实现会触发语言空间闭环、数据层、同步和文档审查机制。实现前必须确认是否需要新增专项审查 round。

## 15. 实施记录

尚未开始实现。2026-05-18 第一轮 UI 收敛仅创建本方案，并在 UI 中保留 lifecycle placeholder。

## 16. 完成标准

- 多空间添加、切换和删除具备可测试实现。
- 删除前置、撤销、最后空间 fallback、级联和 tombstone 语义明确。
- 相关 spec、testing 和 review 文档更新。
- `scripts/verify.sh` 通过，或失败项有明确环境原因和替代验证。

## 17. 剩余风险

在 SQLite / GRDB schema、附件存储和同步引擎落地前，删除策略只能先定义边界，不能最终确认所有级联实现细节。
