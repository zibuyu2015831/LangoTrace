# 开发文档

本目录用于记录阶段级开发 runbook、工程初始化步骤、跨任务工程路线、里程碑状态和新会话执行入口。

这里的文档偏执行，但只服务于阶段和工程路线，不替代产品主参考、架构决策记录或 `docs/plans/active/` 中的一项需求、一个 bug、一次重构的唯一实施方案。

如果本目录中的阶段路线沉淀出不可轻易反转的取舍，应把决策部分抽取到 `docs/decisions/` 的 ADR；本目录只保留执行顺序、验证矩阵、runbook 和跨任务上下文。不要在 `docs/decisions/` 下维护 implementation 文档来替代本目录。

适合放入本目录：

- 三端开发顺序、阶段完成度定义和平台验证矩阵。
- 工程初始化、生成、打开、构建和调试 runbook。
- 本机开发环境基线、工具链版本、模拟器状态和已知执行环境边界。
- 跨多个任务共享的环境、工具链或发布前工程流程。

当前文档：

- [开发环境记录](environment.md)
- [项目初始化规划](project-initialization.md)
- [三端开发顺序方案](001-platform-development-sequence.md)
- [CI 与分支协作 Runbook](002-ci-and-branch-workflow.md)
- [MVP 开发路线规划](mvp-development-roadmap.md)

不适合放入本目录：

- 单个功能的实施方案。
- 单个 bug 的根因分析和修复计划。
- 已完成任务的过程记录。

这些内容应写入 `docs/plans/active/`，验证完成后移入 `docs/plans/done/`。
