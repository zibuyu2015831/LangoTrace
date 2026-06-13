# 002：CI 与分支协作 Runbook

状态：Accepted
创建日期：2026-06-13
最后审查日期：2026-06-13

本文档是 GitHub Actions CI 与分支协作的执行 runbook。它只规定操作顺序、触发策略和协作流程；验证体系的权威关系仍以 [009：测试与验证入口规范](../spec/009-testing-and-verification.md) 为准，本机工具链基线以 [开发环境记录](environment.md) 为准。两者冲突时以权威文档为准，并在任务方案中记录修正。

## 1. CI 是什么

- `.github/workflows/ci.yml` 是 `scripts/verify.sh` 的**远程镜像门禁**，在 GitHub 托管的 `macos-15` runner 上跑同一套验证：6 个 Swift Package 测试 → `xcodegen generate` → iPhone / iPad / macOS 三端构建 + macOS app 测试 → Python tooling 测试（有 secret 才跑）→ SwiftLint / SwiftFormat → `scripts/check-docs.sh` → `git diff --check`。
- 本地 `scripts/verify.sh` 仍是开发收尾的权威门禁；远程 CI 是合并前的二次确认，不替代本地验证。
- runner 默认 Xcode 与本机（Xcode 26 / iOS 26.5）不一定同代。工程部署目标为 iOS 18.0 / macOS 15.0 / Swift 6.0，可在 Xcode 16.x runner 上编译；CI 的 iOS 模拟器目标以本地基线（iPhone 17 / iPad Pro 13-inch (M5)）为优先，runner 镜像缺失时自动回退到最新同类模拟器或 generic SDK 构建。调整本地基线设备时应同步检查 CI 解析逻辑。

## 2. 触发策略

采用「push 显式选择 + PR 强制」：

| 事件 | 是否运行 | 说明 |
| --- | --- | --- |
| push 到 `main` / `dev` | 仅当 commit message 含 `[ci]` | 避免每次推送都占用 macOS runner；由开发者本次决定是否触发 |
| PR 到 `main` / `dev` | 总是运行 | 支撑分支保护，把 `Build & Test` 设为合并前必过检查 |
| 手动 `workflow_dispatch` | 总是运行 | Actions 页 *Run workflow*，或 `gh workflow run ci.yml --ref <branch>` |

实现要点（见 `.github/workflows/ci.yml`）：

```yaml
on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main, dev]
  workflow_dispatch:

jobs:
  verify:
    if: >-
      github.event_name != 'push' ||
      contains(github.event.head_commit.message, '[ci]')
```

触发示例：

```bash
git commit -m "fix: 修复某问题 [ci]"   # push 后触发 CI
git commit -m "wip: 阶段性提交"          # push 后不触发
gh workflow run ci.yml --ref dev         # 手动触发
```

> 注意：`contains(head_commit.message, '[ci]')` 匹配**整条 commit message，含正文**（与 GitHub 原生 `[skip ci]` 行为一致），不是只看标题。讨论 CI 机制、在正文里写下 `[ci]` 字样的提交会被**意外触发**。若提交确实需要在正文提及该标记又不想触发，改写为 `[ ci ]`、`ci 标记` 等不含连续 `[ci]` 的措辞。

## 3. 分支协作流程

功能性开发不直接 push 到 `dev`，而是走独立分支 + PR：

1. 从 `dev` 切出功能分支：`git switch -c feature/<topic>`（bug 用 `fix/<topic>`，重构用 `refactor/<topic>`）。
2. 在功能分支开发、按 [009 规范](../spec/009-testing-and-verification.md) 本地验证；过程提交无需带 `[ci]`。
3. 开 PR 合并到 `dev`：PR 事件**总是触发 CI**，绿勾后再合并。
4. 阶段稳定后开 PR 从 `dev` 合并到 `main`：同样总是触发 CI；`main` 配了分支保护时必须 CI 通过才能合并。
5. 直接 push 到 `dev`（如文档微调、紧急修复）时，按需在 commit message 加 `[ci]` 决定是否跑远程验证。

## 4. main 分支保护配置（GitHub 网页端）

`Settings → Branches → Add branch ruleset`（或旧版 Branch protection rule）：

1. 目标分支填 `main`。
2. 勾选 **Require a pull request before merging**。
3. 勾选 **Require status checks to pass before merging**，在搜索框选中 **`Build & Test`**（即 workflow `jobs.verify.name`）。
   - 该 check 名只有在 CI **至少成功跑过一次**后才会出现在候选列表里。先手动 *Run workflow* 触发一次，或先开一个 PR 让 `Build & Test` 跑通，再回来勾选。
4. 保存。

## 5. gh 作为开发要求

本项目把 GitHub CLI（`gh`）列为必备开发工具，用于自动获取 CI 失败日志、触发 workflow 和管理 PR。

- macOS 安装：`brew install gh`。
- Linux（Ubuntu）安装：使用 GitHub 官方 apt 源（`cli.github.com/packages`）。
- 认证（交互式，需本人凭证）：`gh auth login`，选 GitHub.com → HTTPS 或 SSH → 浏览器或 token 登录。
- 验证：`gh auth status` 显示已登录目标仓库。

## 6. 获取 CI 失败日志并修复

CI 变红时按以下顺序拿日志，定位后修代码、补测试、本地验证、再推送：

```bash
gh run list --limit 5                 # 列出最近运行，拿到 run id 和状态
gh run view <run-id> --log-failed     # 只看失败 step 的日志（最常用）
gh run view <run-id> --log            # 完整日志
gh run view <run-id> --web            # 在浏览器打开该 run
```

网页端备用入口：仓库 **Actions** → 点失败 run → 展开红叉 step → 右上角齿轮 *Download log archive*。

排查提示：

- Python tooling 步骤在未配置 `OPENAI_COMPATIBLE_API_KEY` secret 时**自动跳过**，不会导致 CI 失败；不要把 CI 失败误判为缺 secret。
- 模拟器 `destination` 解析失败时，优先检查 `Resolve iOS Simulator destinations` 步骤日志中的 `Resolved iPhone/iPad destination`。
- SwiftLint / SwiftFormat 在 runner 上用 `brew` 装最新版，可能比本地新而报新规则；必要时在本地对齐版本复现。

## 7. secret 配置（可选）

`Settings → Secrets and variables → Actions → New repository secret`：

- Name：`OPENAI_COMPATIBLE_API_KEY`，Value：对应 key。
- 不配置时 Python tooling 测试自动跳过，CI 仍可全绿。

## 8. 变更记录

- 2026-06-13：补充 `[ci]` 触发匹配整条 commit message（含正文）的注意事项。原因：一次没有在标题写 `[ci]`、但正文讨论了 CI 机制并写下 `[ci]` 字样的修复提交被意外触发了远程 CI。影响范围：§2 触发策略；提醒后续提交避免在正文出现非预期的 `[ci]`。是否需要 ADR：否。
- 2026-06-13：创建 CI 与分支协作 runbook。原因：`.github/workflows/ci.yml` 已进入仓库并调整为 `[ci]` 提交标记 + PR 强制触发，需要一份执行手册沉淀触发策略、分支协作流程、main 分支保护配置和基于 `gh` 的失败日志获取流程；同时把 `gh` 明确为开发要求。影响范围：`.github/workflows/ci.yml`、`docs/spec/009-testing-and-verification.md`、`docs/development/environment.md` 和后续合并前验证流程。是否需要 ADR：否，沿用 009 的本地优先验证关系。
