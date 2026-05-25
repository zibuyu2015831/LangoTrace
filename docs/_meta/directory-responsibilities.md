# 文档目录职责与写入规则

状态：Accepted
创建日期：2026-05-18
最后审查日期：2026-05-18

本文档记录 LangoTrace `docs/` 目录的职责、权威类型、写入规则和禁止事项。后续如果要改变目录职责、恢复已退出目录或新增受保护规则层，必须显式更新本文档。

## 1. 当前目录职责

| 目录 | 职责 | 权威类型 | 写入规则 | 禁止事项 |
| --- | --- | --- | --- | --- |
| `docs/README.md` | 总入口和任务路由 | 入口权威 | 文档结构、阅读路径、项目状态变化时更新 | 不存放详细实施过程 |
| `docs/_meta/` | 文档体系自身规则 | 受保护规则 | 目录职责、文档体系规范、迁移规则、文档治理规则变化时更新 | 不记录普通功能方案 |
| `docs/architecture/` | 系统架构、模块边界、系统地图、数据流、故障恢复索引 | 架构说明 | 架构边界、模块关系、关键入口、异常路径或当前系统地图变化时更新 | 不记录逐步实施计划；不替代 ADR 或 spec |
| `docs/architecture/notes/` | 架构级开发备忘录 | 设计输入和检查清单 | 当前任务为未来架构能力留下跨任务提醒、风险清单或候选模型时更新 | 不作为最终事实源；不替代 plan、spec、正式 architecture 或 ADR |
| `docs/decisions/` | ADR 和不可轻易反转的取舍 | 决策权威 | 核心产品、架构、隐私、同步、付费等决策变化时新增或更新 | 不记录临时想法、implementation 文档或阶段执行细节 |
| `docs/development/` | 阶段级开发 runbook、初始化记录、开发环境记录、跨任务工程路线 | 开发参考 | 工程流程、阶段路线、开发环境或跨任务执行入口变化时更新 | 不替代单项需求、bug 或重构任务方案 |
| `docs/plans/active/` | 进行中任务方案 | 执行中任务记录 | 新功能、bug、重构、文档治理等任务实现前创建 | 不存放已完成任务 |
| `docs/plans/done/` | 已完成任务方案 | 历史任务记录 | 验证完成后从 active 移入 | 不作为当前实现事实直接引用 |
| `docs/plans/examples/` | 任务方案模板 | 模板 | 任务方案字段规则变化时更新 | 不存放真实任务 |
| `docs/workflows/` | 高频高风险开发动作手册 | 执行手册 | 新增或调整 Provider、TTS、数据迁移、平台页面、Prompt 等动作流程时更新 | 不作为产品决策源、架构事实源或实现事实源 |
| `docs/prompts/` | Prompt Registry | Prompt 规则和索引 | 代码中出现真实 Prompt 或 Prompt Preset 时补文档 | 不只写摘要，不省略中英版本 |
| `docs/reference/` | 外部参考入口、本地源码软链接、功能参考映射、许可证边界和研究资料 | 外部参考资料 | 新增外部参考项目、研究入口、许可证快照或功能参考映射时更新 | 不作为产品决策源、架构事实源或实现事实源 |
| `docs/reference/projects/` | 本地参考项目源码软链接 | 阅读入口 | 只登记已进入 `docs/reference/README.md` 的参考项目软链接 | 不放入 LangoTrace 源码或未登记项目 |
| `docs/reference/research/` | 参考项目研究、竞品分析、许可证审查、spike / probe 研究和未定结论 | 非决策资料 | 研究外部项目、竞品、许可证、短期 spike 或可保留 probe 上下文时更新 | 不替代主参考、spec、architecture、ADR 或测试 |
| `docs/reference/research/spikes/` | spike / probe / fixture / evidence 的研究落点规则和可保留研究上下文 | 过程证据和研究入口 | 高风险任务需要保留可行性验证上下文、外部格式样本规则或 probe 清理规则时更新 | 不作为当前实现事实源；不保存真实用户敏感内容 |
| `docs/spec/` | 开发规范、模块规范、实现地图 | 规范权威和实现描述 | 规范变化、模块稳定、实现地图需要更新时修改 | 不承载 ADR 级决策 |
| `docs/review/` | 文档一致性审查机制、审查记录和轻量健康趋势记录 | 审查记录 | 专项审查、里程碑审查、审查规则或健康趋势记录变化时更新 | 不顺手修代码；health ledger 不替代 review round 或 task plan |
| `docs/testing/` | 测试策略、手动验证、回归流程 | 验证规则 | 验证流程或测试要求变化时更新 | 不记录未验证结论 |
| `docs/release/` | StoreKit、TestFlight、App Store、隐私标签 | 发布规则 | 发布、付费、隐私标签变化时更新 | 不记录普通开发任务 |
| `docs/archive/` | 历史参考和已退出目录内容 | 历史归档 | 迁移后仍有追溯价值但不应作为当前事实的内容放入 | 不作为新任务入口 |

## 2. 已退出目录

| 原目录 | 当前处理 | 迁移完成日期 | 后续规则 |
| --- | --- | --- | --- |
| `docs/guidelines/` | 重命名为 `docs/spec/` | 2026-05-18 | 不再恢复；新规范写入 `docs/spec/` |
| `docs/superpowers/specs/` | 长期规格迁入 `docs/spec/`，目录说明归档到 `docs/archive/superpowers/specs/` | 2026-05-18 | 不再作为规格入口 |
| `docs/superpowers/plans/` | 旧实施计划归档到 `docs/archive/superpowers/plans/` | 2026-05-18 | 不再作为任务方案入口 |
| `docs/worklogs/` | 历史任务迁入 `docs/plans/active/`、`docs/plans/done/` 或 `docs/archive/worklogs/` | 2026-05-18 | 不再作为新任务入口 |
| 原一级 `research/` 目录 | 迁入 `docs/reference/research/`，开源参考入口升级为 `docs/reference/README.md` | 2026-05-18 | 不再恢复一级目录；外部参考和研究资料统一进入 `docs/reference/` |

`docs/superpowers/` 和 `docs/worklogs/` 的空目录已由用户手动删除。后续不再恢复这些目录；若发现旧内容仍有当前价值，必须迁入当前目录并更新入口。

## 3. 写入门禁

- 新功能、bug 修复、架构调整、数据、AI、隐私、同步、权限、付费、发布或文档体系变化，先写 `docs/plans/active/` 任务方案。
- AI Provider、TTS Provider、数据迁移、平台页面或 Prompt 等高风险动作，应先读取 `docs/workflows/` 中对应手册；手册只能作为执行顺序，不替代任务方案确认。
- 改变核心产品模型、技术路线、隐私边界、同步策略或付费策略，必须新增或更新 `docs/decisions/`。
- 改变开发一致性规则，更新 `docs/spec/`，并检查是否需要 ADR。
- 代码中新增真实 Prompt 时，同步更新 `docs/prompts/`，并保存英文版本和中文版本。
- 当前任务不实现但会影响未来数据、同步、AI、权限、附件、导出、StoreKit、三端架构或长期记忆边界的提醒，写入对应领域备忘录；架构级提醒写入 `docs/architecture/notes/`。
- 创建相关任务方案前，应检查 `docs/architecture/notes/` 是否有可用设计输入，并在任务方案中记录采纳、暂不采纳或提升为正式文档的处理。
- 不能把历史 `docs/archive/` 内容当作当前事实；如果历史内容重新生效，必须迁回当前目录并更新入口。
- 系统地图是当前工程结构入口，不替代 ADR、spec、review round 或任务方案。
- spike、probe、fixture 和 evidence 是证据材料；被采纳后必须提升到对应权威文档，不能自动成为产品决策或当前实现事实。
- 故障恢复矩阵是异常路径索引和测试覆盖视图，不替代 spec、bug plan 或 review round。
- `docs/review/health-ledger.md` 只记录趋势、指标和 verdict；语义问题仍应进入 active plan 或 review round。

## 4. 验证要求

文档体系变更完成前至少运行：

```bash
find docs -maxdepth 4 -type f | sort
scripts/check-docs.sh
test ! -d docs/guidelines
test ! -d docs/superpowers
test ! -d docs/worklogs
test ! -d research
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

文本中允许出现历史归档、迁移清单和“已退出目录”说明中的旧路径；验证重点是这些目录不能作为当前目录重新出现。
