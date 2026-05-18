# 文档目录职责与写入规则

状态：Accepted
创建日期：2026-05-18
最后审查日期：2026-05-18

本文档记录 LangoTrace `docs/` 目录的职责、权威类型、写入规则和禁止事项。后续如果要改变目录职责、恢复已退出目录或新增受保护规则层，必须显式更新本文档。

## 1. 当前目录职责

| 目录 | 职责 | 权威类型 | 写入规则 | 禁止事项 |
| --- | --- | --- | --- | --- |
| `docs/README.md` | 总入口和任务路由 | 入口权威 | 文档结构、阅读路径、项目状态变化时更新 | 不存放详细实施过程 |
| `docs/_meta/` | 文档体系自身规则 | 受保护规则 | 目录职责、迁移规则、文档治理规则变化时更新 | 不记录普通功能方案 |
| `docs/architecture/` | 系统架构、模块边界、数据流 | 架构说明 | 架构边界或模块关系变化时更新 | 不记录逐步实施计划 |
| `docs/decisions/` | ADR 和不可轻易反转的取舍 | 决策权威 | 核心产品、架构、隐私、同步、付费等决策变化时新增或更新 | 不记录临时想法 |
| `docs/development/` | 阶段开发 runbook、初始化记录、工程路线 | 开发参考 | 工程流程或阶段路线变化时更新 | 不替代任务方案 |
| `docs/plans/active/` | 进行中任务方案 | 执行中任务记录 | 新功能、bug、重构、文档治理等任务实现前创建 | 不存放已完成任务 |
| `docs/plans/done/` | 已完成任务方案 | 历史任务记录 | 验证完成后从 active 移入 | 不作为当前实现事实直接引用 |
| `docs/plans/examples/` | 任务方案模板 | 模板 | 任务方案字段规则变化时更新 | 不存放真实任务 |
| `docs/prompts/` | Prompt Registry | Prompt 规则和索引 | 代码中出现真实 Prompt 或 Prompt Preset 时补文档 | 不只写摘要，不省略中英版本 |
| `docs/spec/` | 开发规范、模块规范、实现地图 | 规范权威和实现描述 | 规范变化、模块稳定、实现地图需要更新时修改 | 不承载 ADR 级决策 |
| `docs/review/` | 文档一致性审查机制和审查记录 | 审查记录 | 专项审查、里程碑审查或审查规则变化时更新 | 不顺手修代码 |
| `docs/testing/` | 测试策略、手动验证、回归流程 | 验证规则 | 验证流程或测试要求变化时更新 | 不记录未验证结论 |
| `docs/release/` | StoreKit、TestFlight、App Store、隐私标签 | 发布规则 | 发布、付费、隐私标签变化时更新 | 不记录普通开发任务 |
| `docs/research/` | 调研材料和未定结论 | 非决策资料 | 竞品、开源项目、技术调研时更新 | 不作为最终产品决策 |
| `docs/archive/` | 历史参考和已退出目录内容 | 历史归档 | 迁移后仍有追溯价值但不应作为当前事实的内容放入 | 不作为新任务入口 |

## 2. 已退出目录

| 原目录 | 当前处理 | 迁移完成日期 | 后续规则 |
| --- | --- | --- | --- |
| `docs/guidelines/` | 重命名为 `docs/spec/` | 2026-05-18 | 不再恢复；新规范写入 `docs/spec/` |
| `docs/superpowers/specs/` | 长期规格迁入 `docs/spec/`，目录说明归档到 `docs/archive/superpowers/specs/` | 2026-05-18 | 不再作为规格入口 |
| `docs/superpowers/plans/` | 旧实施计划归档到 `docs/archive/superpowers/plans/` | 2026-05-18 | 不再作为任务方案入口 |
| `docs/worklogs/` | 历史任务迁入 `docs/plans/active/`、`docs/plans/done/` 或 `docs/archive/worklogs/` | 2026-05-18 | 不再作为新任务入口 |

`docs/superpowers/` 和 `docs/worklogs/` 的空目录由用户手动删除。AI 不主动删除这些空目录。

## 3. 写入门禁

- 新功能、bug 修复、架构调整、数据、AI、隐私、同步、权限、付费、发布或文档体系变化，先写 `docs/plans/active/` 任务方案。
- 改变核心产品模型、技术路线、隐私边界、同步策略或付费策略，必须新增或更新 `docs/decisions/`。
- 改变开发一致性规则，更新 `docs/spec/`，并检查是否需要 ADR。
- 代码中新增真实 Prompt 时，同步更新 `docs/prompts/`，并保存英文版本和中文版本。
- 不能把历史 `docs/archive/` 内容当作当前事实；如果历史内容重新生效，必须迁回当前目录并更新入口。

## 4. 验证要求

文档体系变更完成前至少运行：

```bash
find docs -maxdepth 4 -type f | sort
rg "docs/guidelines|guidelines/" docs
rg "docs/superpowers|superpowers/" docs
rg "docs/worklogs|worklogs/" docs
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如果仅历史归档或迁移清单中出现旧路径，需要确认它不会作为新任务入口。
