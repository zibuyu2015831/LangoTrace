# 任务方案文档

本目录用于记录语迹 LangoTrace 的功能开发、bug 修复、重构、调研、文档治理和工程杂项任务。后续一项需求、一个 bug 或一次文档治理只维护一份详细任务方案，不再同时维护 worklog 草案和独立 plan。

## 1. 目录结构

```text
docs/plans/
  README.md
  plan-review-protocol.md
  active/
  done/
  examples/
```

- `active/`：尚未完成的任务方案，状态可以是 `Draft`、`User Approved`、`In Progress`、`Implemented` 或 `Shelved`。
- `done/`：已完成验证并收口的任务方案，状态应为 `Verified` 或 `Done`。
- `examples/`：模板和示例，不作为真实任务状态来源。
- `plan-review-protocol.md`：active plan 进入实现前的严格方案自审核协议；它不替代实现后的文档影响检查和专项审查机制。

## 2. 命名规则

推荐路径：

```text
docs/plans/active/YYYY-MM-DD-<type>-<topic>.md
docs/plans/done/YYYY-MM-DD-<type>-<topic>.md
```

允许类型：

- `feature`
- `bug`
- `refactor`
- `research`
- `chore`
- `docs`

## 3. 必填内容

每份任务方案至少包含：

- 标题、状态、自审核状态、类型、创建日期、最后更新日期。
- 用户确认记录。
- 需求或 bug 描述。
- 现状描述。
- 目标、范围和不做什么。
- 证据与决策依据。
- 来源于 review round、health ledger 或运行期诊断时的 finding id / trigger id 与 work item 对照。
- 约束映射与验证路径。
- 涉及的代码文件路径。
- 参考的代码文件路径。
- 涉及的文档路径。
- 实施方案。
- 严格方案自审核记录。
- 复查方法。
- TDD / 测试落点。
- 验证命令。
- 文档影响检查。
- 实施记录。
- 完成标准。
- 剩余风险。

bug 方案还必须包含：

- 复现方式。
- 预期行为。
- 实际行为。
- 根因分析。
- 置信度。
- 置信度依据。
- 备选原因。
- 回归测试方案。

置信度必须使用百分比，例如 `置信度：85%`，不使用 `Low`、`Medium`、`High`。

## 4. 状态说明

任务方案使用两个状态字段：

- `状态`：表示任务生命周期。
- `自审核状态`：表示方案进入实现前的严格自审核门禁是否完成。

`状态` 取值：

- `Draft`：草案阶段，不能开始生产代码实现；可以继续完善方案、补证据、补自审核或等待用户确认。
- `User Approved`：用户已确认方案范围和实现授权，可以进入实现。
- `In Progress`：正在实施。
- `Implemented`：实现已完成但尚未完成最终验证、文档影响检查或归档收口。
- `Shelved`：任务暂缓或搁置，保留上下文但不继续推进。
- `Verified`：已完成验证并收口，通常用于 `docs/plans/done/`。
- `Done`：已完成收口但不需要或无法使用 `Verified` 表达完整验证时使用。

`自审核状态` 取值：

- `Not Reviewed`：尚未按 `docs/plans/plan-review-protocol.md` 完成严格方案自审核。
- `Reviewed`：已完成自审核；自审核发现的问题已修订并写回方案，剩余风险和仍需用户确认的问题已记录。

自审核状态不替代用户确认。`自审核状态：Reviewed` 的方案若仍为 `状态：Draft`，仍不能进入生产代码实现，除非用户明确确认并将状态推进到 `User Approved` 或在用户确认记录中写明授权范围。

## 5. 使用规则

- 涉及新功能、bug 修复、架构调整、数据、AI、隐私、同步、权限、付费、发布或文档体系变化的任务，实现前必须先创建 `docs/plans/active/` 下的任务方案，并经用户确认。
- 上述任务在进入实现前，必须按 `docs/plans/plan-review-protocol.md` 完成严格方案自审核，并将确认的问题、修订、TDD 落点、验证命令和剩余风险写回 active plan。
- 低风险错别字、轻量文档修正或用户明确要求跳过方案的小任务，可以不创建任务方案，但最终答复应说明原因。
- 任务完成并通过验证后，将方案从 `active/` 移入 `done/`，并在实施记录中写明验证命令和结果。
- 如果任务改变了长期规则，应同步更新 `docs/spec/`、`docs/decisions/`、`docs/architecture/` 或其他相关文档。
- AI Provider、TTS Provider、数据迁移、平台页面或 Prompt 等高风险动作，应在任务方案的“证据与决策依据”或“实施方案”中引用对应 `docs/workflows/` 手册，并说明采纳或偏离原因。
- 高风险任务应在方案中说明是否需要 spike / probe / fixture / evidence；需要时写清落点、是否包含真实用户敏感内容、验证方式、保留期限和清理条件。
- 来源于 review round 的 remediation plan，应写明 `round id -> finding id -> work item`；来源于 health ledger 或运行期诊断时，应写明 trigger id -> work item。
- 高风险、多阶段、跨 package 或超过 3 个阶段的任务，应考虑增加 Phase 0 spike / baseline gate。Phase 0 至少写明假设名称、probe / fixture / baseline 路径、PASS / FAIL 条件、FAIL 后处理方式，以及是否允许进入生产实现。
- 大型多阶段任务可以定义机器可检查 DoD；DoD 只检查文件、章节、命令、测试、migration、review round 状态等结构性事实，不替代语义审查或人工判断。
- 任务中出现 deferred 或 aborted 项时，必须记录项目、决策类型、原因、影响、后续事实源或复审入口；不得在完成叙事中把 deferred / aborted 项包装成已完成。
- 高风险任务完成并移入 `done/` 前，应做 plan-vs-shipped 对账：检查 work item 是否有实际文档、代码、测试、脚本或 review evidence；scope-down 是否写明；deferred / aborted 项是否有后续入口。
- 新增或强化脚本、CI、TDD、coverage、AI audit、文档检查或 release gate 时，应记录 guardrail 的 enforcement level、引入原因和未来回调路径；弱化、手动化、移除或替换时，应说明原因和替代机制。
- `docs/plans/done/` 是已完成任务的历史记录目录，不作为新任务入口；新任务必须先写入 `docs/plans/active/`。
- 模板缺陷、文档治理规则变化、历史资料清理、文档谬误修正、review 生命周期调整、当前事实源索引修正都属于 `docs` 类型任务。
- 文档治理任务创建前必须先搜索 `docs/plans/active/`、`docs/plans/done/` 和 `docs/review/INDEX.md`。若已有 active plan 处理同一问题，应追加到现有方案；若已完成任务的问题复发，应新建方案并引用旧任务，而不是重开或改写旧记录。
- 文档治理任务若涉及 ADR、产品主参考、核心 spec、文档权威关系或历史记录删除，必须在用户确认记录中写明确认范围。
- `docs/plans/plan-review-protocol.md` 只管理实现前方案审核；代码或文档变更完成后的日常文档影响检查、事件触发专项审查和里程碑轻量全审仍以 `docs/review/README.md` 为准。
- 如果任务涉及新功能、bug 修复、架构调整或行为变化，方案必须在"TDD / 测试落点"章节写明测试落点（Package、文件、测试函数名）、先失败用例和聚焦验证命令；如果不新增单元测试，必须说明原因与剩余风险。
- "约束映射与验证路径"章节只记录已有 LangoTrace 权威文档来源的规则；不允许把外部参考项目、done plan 历史方案或 AI 推断直接升级为 blocker；可参考 `docs/_meta/documentation-constraints.md` 快速定位相关约束来源。

## 6. 当前状态

状态：Accepted

适用阶段：文档体系重整后、MVP 早期开发及后续持续开发。
