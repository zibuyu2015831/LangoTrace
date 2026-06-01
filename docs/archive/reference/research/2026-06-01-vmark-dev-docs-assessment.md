# VMark dev-docs 文档体系评估

日期：2026-06-01
状态：Archived，已被后续 docs plan 承接并落地
参考项目：`docs/reference/projects/vmark/dev-docs`、`docs/reference/projects/vmark/zibuyu-analysis/`

本文记录对 VMark `dev-docs` 文档体系的再评估。它是已归档的参考研究记录，不是 LangoTrace 当前事实源、产品决策源或架构决策源。相关结论已由 `docs/plans/done/2026-06-01-docs-vmark-engineering-dev-docs.md` 承接并落地；后续若再次采纳其中建议，必须重新分流到 `docs/review/`、`docs/plans/`、`docs/spec/`、`docs/architecture/` 或 `docs/decisions/`。

## 1. 结论摘要

LangoTrace 已在 2026-05-25 的文档治理任务中吸收过 VMark 的核心文档机制：系统地图、spike / probe / fixture 证据链、周期性健康检查、health ledger 和每条发现必须有 verdict 的规则。因此，本次不建议新增 VMark 同名目录，也不建议把 `audit/`、`house-cleaning/` 或 `grills/` 直接复制进 LangoTrace。

本次新增可借鉴点主要来自 VMark 2026-05-31 终端审计和对应实施方案：

- 审计发现使用稳定 ID，例如 T1、C1、M1，并在后续计划中持续引用。
- 大型 remediation plan 把审计发现、ADR、Phase、Work Item、RED test、DoD 和延期 / 中止决策放在同一条证据链中。
- Phase 0 先做 spike 和 baseline，只有关键假设通过后才进入生产改动。
- 对每个阶段定义机器可检查 DoD，并用脚本验证计划执行状态。
- deferred / aborted 项明确写入状态摘要和决策日志，避免计划完成后留下隐性范围债。

这些机制适合补强 LangoTrace 的高风险任务方案和专项 review round，尤其是数据迁移、AI Provider、TTS / Speech、同步、StoreKit、权限和大型文档治理任务。

切换到 VMark `zibuyu` 分支后，`zibuyu-analysis/` 的项目考古评估报告进一步补充了更高层的结论：有效的 dev docs 不是“文档目录长得完整”，而是能把计划、ADR、审查、测试、脚本、CI、运行时事实和最终收口互相对账。该分支的 `reports/project-methods/dev-docs-system.md`、`reports/reusable/ai-assisted-programming-playbook.md`、`reports/author-thinking/development-philosophy.md` 和 `reports/author-thinking/growth-path.md` 都强调 evidence-backed claim、guardrail 生命周期、plan-vs-shipped 对账、cross-model audit 主线程复核和 release-tail closeout。

## 2. 已经吸收的内容

LangoTrace 已有对应落点：

| VMark 机制 | LangoTrace 当前落点 | 本次判断 |
| --- | --- | --- |
| 系统架构短路径入口 | `docs/architecture/002-system-map.md` | 已吸收，不需要新增平行入口。 |
| 周期性 house-cleaning | `docs/review/README.md`、`docs/review/health-ledger.md` | 已吸收轻量版本，不新增 `docs/house-cleaning/`。 |
| spike / probe / fixture / evidence | `docs/reference/research/spikes/README.md`、任务方案 evidence 字段 | 已吸收落点规则。 |
| 审计发现必须有 verdict | `docs/review/README.md`、`docs/review/health-ledger.md` | 已吸收为 review / ledger 规则。 |
| ADR 索引和状态 | `docs/decisions/` | LangoTrace 已有更强的核心决策边界。 |

## 3. 可继续吸收的内容

### 3.1 审计发现 ID 贯穿 plan

VMark 的终端文档把审计发现 ID 写入 plan source audit、phase 和 work item，例如 T1、T2、C1、M1。LangoTrace 后续专项审查也可以采用稳定 ID，并要求 active plan 在“证据与决策依据”中引用这些 ID。

推荐落点：

- `docs/review/README.md`：专项审查发现 ID 命名建议。
- `docs/plans/examples/task-plan-template.md`：增加“若来源于 review round，列出发现 ID -> work item 对照”的提示。

后续已由 `docs/plans/done/2026-06-01-docs-vmark-engineering-dev-docs.md` 承接，并落地到 `docs/review/README.md`、`docs/plans/README.md` 和 `docs/plans/examples/task-plan-template.md`。本节保留为研究来源说明，不再作为待办建议。

### 3.2 Phase 0 spike gate

VMark 在终端计划中把高风险假设放进 Phase 0，例如 binary channel、shell integration 和 orphan process 行为验证。LangoTrace 现有任务方案已有 TDD 和 evidence 要求，但还可以在高风险任务中更明确地区分：

- Phase 0：probe、fixture、baseline、失败条件。
- Phase 1+：生产实现。

适用范围：

- 数据迁移和导出恢复。
- AI Provider 请求预览、请求日志和 Prompt Registry 执行链路。
- Speech Recognition、OCR、Photos、Camera 权限。
- 同步冲突处理。
- StoreKit 购买和恢复购买。

### 3.3 机器可检查 DoD

VMark 的 `scripts/check-terminal-phase.sh <N>` 让 plan phase 状态可用脚本校验。LangoTrace 不应为每个小任务都写脚本，但大型多阶段任务可以采用同类机制。

推荐标准：

- 只有超过 3 个阶段、跨多个 package 或涉及数据 / AI / 权限 / 同步 / StoreKit 的任务才考虑阶段检查脚本。
- 脚本只检查结构性事实，例如文件存在、测试命令存在、migration id 存在、review round 状态存在。
- 脚本不得替代语义审查，也不得自动改写文档。

### 3.4 deferred / aborted 决策日志

VMark 的终端计划在状态摘要中明确列出 deferred 和 aborted 项。LangoTrace 当前 plan 有“剩余风险”和“延后项”，但大型任务可以更明确要求：

- 延后项：为什么延后、何时复审、是否影响完成标准。
- 中止项：为什么中止、依据是什么、是否需要 ADR / spec 修订。
- 不再读取旧计划时，后续事实源在哪里。

这与 LangoTrace 的保守文档自进化原则兼容，可以降低 done plan 被误读为全部范围已实现的风险。

### 3.5 Evidence-backed claim 层

VMark 考古报告本身展示了一种更成熟的研究和治理写法：最终报告不能直接引用单个 commit 或单次 AI 输出，而要经过 episode、ledger、evidence index 和 claim admission。LangoTrace 不需要复制完整考古系统，但可以吸收两个轻量规则：

- 重大文档治理结论应区分“证据能证明什么 / 证据不能证明什么 / 迁移前提 / 照搬风险”。
- 参考项目结论被采纳前，应先进入 `docs/reference/research/` 或 active plan 的证据章节，再提升到 `docs/spec/`、`docs/architecture/`、`docs/decisions/` 或 `docs/review/`。

适用范围：

- 参考项目研究。
- 文档体系治理。
- AI 辅助开发方法沉淀。
- 大型 review round 的结论摘要。

### 3.6 Guardrail 生命周期

VMark 的负样本显示，强门禁和高阈值并非天然正确；真正可迁移的是记录 guardrail 的生命周期：introduced、strengthened、weakened、manualized、removed、replacement。LangoTrace 后续新增脚本、CI、TDD、coverage、AI audit 或文档检查规则时，应同步记录：

- 强度：advisory / manual / script / CI / hook-blocking / release-blocking。
- 引入原因。
- 失败或误报时的回调路径。
- 替代机制。

这可以避免把一次治理实验永久包装成不可质疑规则。

### 3.7 Plan-vs-shipped 对账

考古报告反复提醒：plan status、commit message、ADR proposal 和 AI 叙事都不能直接当作完成证据。LangoTrace 的高风险 done plan 收口可以补充一个轻量对账要求：

- 计划中承诺的 work item 是否都有实际文档、代码、测试、脚本或 review evidence。
- 延后 / 中止项是否从完成叙事中剥离。
- 如果实施结果缩小范围，应写明 scope-down，而不是让原计划继续暗示已完成。

### 3.8 Release-tail closeout

VMark 后期形成的 `land -> audit -> focused tests -> CI repair -> stale-test alignment` 思路，对 LangoTrace 可转化为“阶段性功能落地后的收口检查”。它不应套到每个小任务，但适合：

- 数据层、AI 层、同步层、StoreKit、权限层阶段完成。
- 跨 package 大功能完成。
- 准备 TestFlight 或公开发布前。

推荐落点仍是 `docs/review/` 和 active plan 的“文档影响检查 / 完成标准 / 剩余风险”，不新增独立 release-tail 目录。

## 4. 不建议吸收的内容

- 不新增 `docs/audit/`、`docs/house-cleaning/`、`docs/grills/`，避免和现有 `review/`、`plans/`、`reference/research/` 分裂。
- 不复制 VMark 面向 Tauri / React / Rust / MCP / Markdown editor 的技术栈规则。
- 不把 VMark 的 CLI AI routing、Markdown source of truth、MCP sidecar 或 terminal architecture 当作 LangoTrace 架构事实。
- 不为小型任务引入阶段脚本，否则流程成本会超过收益。
- 不复制 VMark 的完整考古目录、episode ledger、claim ledger 或 evidence admission pipeline；LangoTrace 只吸收轻量证据边界和结论写法。
- 不把 cross-model audit 当作自动真理；第二模型或工具审查必须由主线程复核，并写回 plan、测试、代码或 review 记录。

## 5. 后续使用建议

本轮机制已由 `docs/plans/done/2026-06-01-docs-vmark-engineering-dev-docs.md` 吸收为长期文档规则。后续建议在命中以下条件的任务中重点使用，而不是把这些机制扩张到所有小任务：

- 来源于专项 review round，且有 5 个以上发现需要 remediation。
- 任务超过 3 个阶段。
- 任务涉及数据迁移、AI Provider、权限、同步、StoreKit 或跨 package 状态同步。
- 任务需要先验证技术假设，否则直接实现风险较高。

这些机制的当前权威落点是 `docs/review/README.md`、`docs/plans/README.md`、`docs/plans/examples/task-plan-template.md`、`docs/reference/research/spikes/README.md`、`docs/review/health-ledger.md` 和 `scripts/check-docs.sh`；本文只作为参考研究证据。
