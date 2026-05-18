# 文档审查轮次目录

本目录保存事件触发专项审查和里程碑轻量全审的单轮记录。

日常文档影响检查写在对应 `docs/plans/active/` 任务方案中，不在这里创建目录。

轮次目录命名：

```text
YYYY-MM-DD-<topic>/
```

普通轮次结构：

```text
YYYY-MM-DD-<topic>/
  README.md
```

复杂轮次结构：

```text
YYYY-MM-DD-<topic>/
  README.md
  _meta.md
  reports/
  questions/
  clarifications/
  proposals/
  consistency_check.md
```

每个轮次必须记录代码快照、审查范围、结论、验证结果和剩余风险。

## 生命周期和保留规则

review round 是审计记录，不是当前事实源。问题修复后通常不删除、不重写正文；应在 `docs/review/INDEX.md` 或新的收口记录中标注当前事实源、后续覆盖记录和可作为依据状态。

支持的长期状态：

- `Verified`：该轮在当时快照下已完成并验证；保留为历史审计记录。
- `Deferred`：该轮仍有延后项；必须说明延后原因和重新触发条件。
- `Superseded`：该轮发现的问题或建议已被后续 plan、review、commit 或长期文档覆盖；仍可作为历史证据。
- `Invalidated`：该轮结论基于错误前提或已被后续确认推翻；仅作为历史过程记录，不再作为依据。

索引字段：

```text
当前事实源：<path or none>
后续覆盖记录：<plan/review/commit or none>
可作为依据：Yes / Historical Only / No
```

保留优先级：

1. 当前事实修正优先于历史记录重写。
2. 索引降权和当前事实源标注优先于移动或删除。
3. 归档优先于删除。
4. 删除只适用于误生成、重复、临时、无引用且无审计价值的文件，并且需要用户确认。

禁止事项：

- 不因问题已修复而删除历史 review。
- 不把旧 review 正文反复改写成当前事实源。
- 不用单一 `Superseded` 覆盖“问题已修复”和“结论被推翻”两类不同语义。
- 不让自动化工具直接删除或改写长期文档；工具只能先报告候选问题。
