# 任务方案文档

本目录用于记录语迹 LangoTrace 的功能开发、bug 修复、重构、调研、文档治理和工程杂项任务。后续一项需求、一个 bug 或一次文档治理只维护一份详细任务方案，不再同时维护 worklog 草案和独立 plan。

## 1. 目录结构

```text
docs/plans/
  README.md
  active/
  done/
  examples/
```

- `active/`：尚未完成的任务方案，状态可以是 `Draft`、`User Approved`、`In Progress`、`Implemented` 或 `Shelved`。
- `done/`：已完成验证并收口的任务方案，状态应为 `Verified` 或 `Done`。
- `examples/`：模板和示例，不作为真实任务状态来源。

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

- 标题、状态、类型、创建日期、最后更新日期。
- 用户确认记录。
- 需求或 bug 描述。
- 现状描述。
- 目标、范围和不做什么。
- 证据与决策依据。
- 涉及的代码文件路径。
- 参考的代码文件路径。
- 涉及的文档路径。
- 实施方案。
- 复查方法。
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

## 4. 使用规则

- 涉及新功能、bug 修复、架构调整、数据、AI、隐私、同步、权限、付费、发布或文档体系变化的任务，实现前必须先创建 `docs/plans/active/` 下的任务方案，并经用户确认。
- 低风险错别字、轻量文档修正或用户明确要求跳过方案的小任务，可以不创建任务方案，但最终答复应说明原因。
- 任务完成并通过验证后，将方案从 `active/` 移入 `done/`，并在实施记录中写明验证命令和结果。
- 如果任务改变了长期规则，应同步更新 `docs/spec/`、`docs/decisions/`、`docs/architecture/` 或其他相关文档。
- AI Provider、TTS Provider、数据迁移、平台页面或 Prompt 等高风险动作，应在任务方案的“证据与决策依据”或“实施方案”中引用对应 `docs/workflows/` 手册，并说明采纳或偏离原因。
- `docs/plans/done/` 是已完成任务的历史记录目录，不作为新任务入口；新任务必须先写入 `docs/plans/active/`。
- 模板缺陷、文档治理规则变化、历史资料清理、文档谬误修正、review 生命周期调整、当前事实源索引修正都属于 `docs` 类型任务。
- 文档治理任务创建前必须先搜索 `docs/plans/active/`、`docs/plans/done/` 和 `docs/review/INDEX.md`。若已有 active plan 处理同一问题，应追加到现有方案；若已完成任务的问题复发，应新建方案并引用旧任务，而不是重开或改写旧记录。
- 文档治理任务若涉及 ADR、产品主参考、核心 spec、文档权威关系或历史记录删除，必须在用户确认记录中写明确认范围。

## 5. 当前状态

状态：Accepted

适用阶段：文档体系重整后、MVP 早期开发及后续持续开发。
