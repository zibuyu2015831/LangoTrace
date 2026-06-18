# `/goal` 指令：批量自主完成 active/ 剩余系列

> 本文件存放在**仓库根目录**，是一份 **run 控制器**，不是 `docs/plans/` 下的代码实施方案、不是工作项、不是事实源。它只承载一条供复制到 Claude Code `/goal` 命令的指令。
> 配套编排手册：根目录 `BATCH-EXECUTION-PLAYBOOK.md`（下称 Playbook）。

## 使用方法

1. 确认仓库当前为 **public**（CI 免费、`[ci]` 触发可用）。
2. 在 Claude Code 中输入 `/goal`，把下面**代码块内的全部内容**粘贴进去。
3. 让它自主跑；中断后用 `/goal resume` 续传——停止条件已写成可判定的**状态**（见末段），不会因「resume」反复触发 stop hook。

## 指令正文（复制以下代码块）

```
按仓库根目录 BATCH-EXECUTION-PLAYBOOK.md（批量执行 Playbook）自主完成 docs/plans/active/ 下剩余的全部工作项方案。

先读取：根 CLAUDE.md / docs/README.md → 根 BATCH-EXECUTION-PLAYBOOK.md → 仪表盘 docs/plans/active/2026-06-11-00-docs-series-progress.md → docs/plans/plan-review-protocol.md → docs/development/002-ci-and-branch-workflow.md。

授权与纪律（用户已于 2026-06-18 确认，记录在 Playbook §1）：
- 完全预授权、全程不逐份停。任何疑问站在系统架构师角度，基于产品北极星与本地优先边界，直接采取最优推荐方案并在对应方案记录理由。唯一暂停例外：某方案实现会反转核心决策或某条 ADR 时，跳过它、记录冲突、转下一份，最后汇总待我裁决。
- 运行期隐私边界不被预授权覆盖：涉及向 Provider 外发敏感内容的能力，实现中必须保留运行期显式用户触发（核心决策 10）。
- 每份方案独立 feature 分支开发；本机只做轻量单包测试 + swiftformat/swiftlint 自查；重测试走 GitHub Actions。完成后本地 merge 进 dev（不开 PR），push dev 时 commit message 带 [ci] 触发远程 CI，用 gh 跟踪 Build & Test 跑绿。全程不动 main。
- 顺序：首轮自审核后基于真实依赖重排（起点见 Playbook §7），把定稿顺序写进 Playbook §9。

每份方案的循环（Playbook §4）：① 用子代理做实现前隔离自审核（plan-review-protocol §9），用当前代码核验已漂移的方案假设，把发现/修订/TDD 落点/验证命令写回该方案、状态推进到 User Approved + Reviewed；② 按 Phase 小步 TDD，先写失败测试再改代码，每个 Phase 本机轻量验证 + commit（过程提交不带 [ci]）；③ 全部 Phase 完成后本地 merge 进 dev、push 带 [ci]、gh 跟踪 CI 绿；④ 绿后写实施记录、方案移入 docs/plans/done/、同步仪表盘 00 与 Playbook §9。

进度事实源是仪表盘 00 + Playbook §9，每次推进同步更新，断点续传只读磁盘不靠聊天记忆。必要时主动 compact 上下文、派子代理。诚实 defer：依赖当前不存在的能力（真实凭证安全存储、StoreKit 等）时，实现到可验证边界、把剩余标 deferred 并写清后续入口，不把 deferred 包装成完成，然后继续下一份。

完成状态（stop 条件，与 Playbook §8 一致）：Playbook §2 的 9 份工作项方案中，每一份「可在本 run 内完成」的方案都满足「CI 在 dev 跑绿 + 状态 Implemented/Verified + 实施记录含 commit 和 CI run id + 文件已移入 docs/plans/done/」，且仪表盘 00 状态总表对应行标绿；docs/plans/active/ 中不再存在「可完成却未完成」的工作项方案——剩下的至多是仪表盘 00（随后移入 done/），以及因核心决策冲突或诚实 defer 而合法留存的方案（状态 In Progress、已落地部分已合并 dev 并 CI 绿、deferred/冲突段落齐全，不算全绿但在仪表盘 00 与该方案有明确记录和后续入口）。达到该状态即完成，并向我汇总所有 deferred / 待裁决项。
```

## 停止条件是「状态」不是「动作」

`/goal` 的停止条件已表述为可布尔判定的**终止状态**（active/ 是否还有工作项方案、9 行是否全绿、done/ 是否就位、deferred 是否有据可查），而非「resume / 继续干」这类动作，避免 stop hook 因无法判定而反复触发。续传时直接 `/goal resume`，AI 会从仪表盘 00 + Playbook §9 的磁盘游标恢复。
