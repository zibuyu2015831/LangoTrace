# 002：CI 与分支协作 Runbook

状态：Accepted
创建日期：2026-06-13
最后审查日期：2026-06-13

本文档是 GitHub Actions CI 与分支协作的执行 runbook。它只规定操作顺序、触发策略和协作流程；验证体系的权威关系仍以 [009：测试与验证入口规范](../spec/009-testing-and-verification.md) 为准，本机工具链基线以 [开发环境记录](environment.md) 为准。两者冲突时以权威文档为准，并在任务方案中记录修正。

## 1. CI 是什么

- `.github/workflows/ci.yml` 是 `scripts/verify.sh` 的**远程镜像门禁**，在 GitHub 托管的 `macos-15` runner 上跑同一套验证：6 个 Swift Package 测试 → `xcodegen generate` → iPhone / iPad / macOS 三端构建 + macOS app 测试 → Python tooling 测试（有 secret 才跑）→ SwiftLint / SwiftFormat → `scripts/check-docs.sh` → `git diff --check`。
- 本地 `scripts/verify.sh` 仍是开发收尾的权威门禁；远程 CI 是合并前的二次确认，不替代本地验证。
- job 配了 `timeout-minutes: 40`，作为测试或构建挂起的硬兜底，避免 macOS runner 跑满默认 360 分钟浪费额度。若正常全流程（含三端构建）逼近该上限，应排查是否有挂起而非直接调大。
- runner 默认 Xcode 与本机（Xcode 26 / iOS 26.5）不一定同代。工程部署目标为 iOS 18.0 / macOS 15.0 / Swift 6.0，可在 Xcode 16.x runner 上编译；CI 的 iOS 模拟器目标以本地基线（iPhone 17 / iPad Pro 13-inch (M5)）为优先，runner 镜像缺失时自动回退到最新同类模拟器或 generic SDK 构建。调整本地基线设备时应同步检查 CI 解析逻辑。

### 1.1 测试场所与仓库可见性策略（重要）

本机开发设备是 **MacBook Air M4**（被动散热，长时间编译会发烫、可能超时），因此测试分工固定为：

- **重测试一律放 GitHub Actions**：全量验证（`scripts/verify.sh` 等价流程）、三端 `xcodebuild` 构建、跨多个 Swift Package 的测试、长时间运行的套件，都在 macOS runner 上跑，不在本机跑。
- **本机只做轻量动作**：单个改动包的 `swift test --package-path Packages/<X>`、`swiftformat .` / `swiftlint --no-cache` 自查、文档检查。不要在 MacBook Air 上跑全量 `verify.sh` 或三端构建。
- **仓库可见性与免费额度**：**public 仓库的 Actions 在标准 runner（含 macOS）上免费、分钟数无上限**；**private 仓库**免费额度 2000 分钟/月，且 **macOS 计费倍率 10×（约合 200 macOS 分钟/月）**。因此约定：仓库平时可保持 private，**需要跑 CI 前临时设为 public**，跑完可再设回 private。
  - 切换位置：`Settings → 页面底部 Danger Zone → Change repository visibility`。public→private、private→public 均可随时反复切换。
- **AI 协作约定**：当某次改动需要 CI 验证（重测试 / 三端构建 / 合并前）时，AI 在触发 CI 前应**主动提醒用户先把仓库临时设为 public**；验证通过后提示可设回 private。

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

### 3.1 合并到 `main` 的标准流程（强制走 PR，禁止本地直接合并）

> 项目里 `main` 即发布主干（用户口中的 master）。**原则上不允许直接 `git merge` 分支到 `main` 再 `git push origin main`**；`main` 的任何变更必须经 PR 且 `Build & Test` 跑绿后合并。

当你准备把 `dev`（或功能分支）合并到 `main` 时，按以下顺序：

1. 确认改动已 push 到 `dev`/功能分支，本地轻量验证已过。
2. **临时把仓库设为 public**：`Settings → 页面底部 Danger Zone → Change repository visibility → Make public`。理由：Free 私有仓库 ruleset 不生效（§4.1），且 public 时 macOS CI 免费。
3. 开 PR：`gh pr create --base main --head dev --title "…" --body "…"`（或网页）。PR 事件**总是触发 CI**。
4. **用 `gh` 跟踪 CI 状态直到 `Build & Test` 通过**，不要凭感觉合并：
   ```bash
   gh pr checks <PR号> --watch              # 跟踪该 PR 的检查
   gh run list --branch dev --limit 3       # 或查最近 run
   gh run watch <run-id> --exit-status
   ```
5. CI 绿后再合并 PR：`gh pr merge <PR号> --merge`（或网页 Merge）。保护生效时，检查未过无法合并。
6. （可选）合并完成后把仓库设回 private。

**本地硬兜底（pre-push 钩子）**：仓库内置 `scripts/git-hooks/pre-push`，拦截向 `main` 的直接推送（即使仓库 private、GitHub ruleset 不生效时也拦）。每个克隆安装一次（**repo 级，不影响全局或其他仓库**）：

```bash
git config core.hooksPath scripts/git-hooks   # 写入本仓库 .git/config，不带 --global
chmod +x scripts/git-hooks/*
```

详见 [scripts/git-hooks/README.md](../../scripts/git-hooks/README.md)。紧急绕过（不推荐）：`git push --no-verify`。

**AI 协作约定（必须遵守）**：当用户表达要把分支合并到 `main`，或出现"本地直接 merge / push `main`"的意图时，AI 应主动：① 提醒不要本地直接合并；② 提醒先把仓库临时设为 public；③ 用 `gh` 核对 `Build & Test` 已通过；④ 引导走 PR 合并。

## 4. main 分支保护配置（GitHub 网页端）

推荐用新版 **Rulesets**：`Settings → Rules → Rulesets → New branch ruleset`。

1. **Ruleset Name** 填 `main-protection`；**Enforcement status** 选 **Active**；**Bypass list 留空**（对仓库 admin / 本人也强制，避免自己绕过）。
2. **Target branches → Add target → Include by pattern**，填 `main`。
3. 勾选 **Require a pull request before merging**；单人开发把 **Required approvals 设为 0**（否则无人能批准你自己的 PR，会卡住无法合并）。
4. 勾选 **Require status checks to pass** → **Add checks** → 搜索并选中 **`Build & Test`**（即 workflow `jobs.verify.name`）。
   - 该 check 名只有在 CI **至少成功跑过一次**后才会出现在候选列表里；现已满足。
5. 建议一并勾 **Block force pushes**、**Restrict deletions**。
6. **Create**。

（旧版入口 `Settings → Branches → Add branch protection rule` 等价，搜索框选 `Build & Test` 即可。）

### 4.1 强制范围与「只能走 PR / 会不会被本地 merge 绕过」

- **「Require a pull request before merging」= 禁止直接 push 到 `main`**。规则强制时，本地 `git merge` 后 `git push origin main` 会被拒绝；必须开 PR、`Build & Test` 跑绿、（Bypass list 为空时）连本人也不能绕过，才能在网页合并。PR 事件**总是触发 CI**（不受 `[ci]` 门控），所以合并前一定跑过测试。
- **只保护了 `main`**：`dev` 不设保护，可自由 push / 合并（dev 是集成分支）；测试门禁落在 `dev → main` 的 PR 上。直接 push 到 `dev` 时仍按 §2 用 `[ci]` 决定是否跑远程验证。
- **Free 计划 + 私有仓库：ruleset 不强制**（新建 ruleset 页面顶部黄色横幅会提示，私有仓库需 GitHub Team 才强制）。即**仅当仓库为 public 时保护才真正生效**；私有期间规则休眠，此时**可以**直接 push `main`、绕过测试。
- **结论与约定**：本保护与「平时 private、跑 CI / 合并前才临时 public」（见 §1.1）契合——**只在 public 窗口期合并 `main`**，那时保护生效、本地 merge 无法绕过；私有期间不要直接推 `main`（靠纪律，或保持只在 public 时动 `main`）。若想私有期间也硬强制，需升级 GitHub Team（当前阶段不必）。

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
- 某步骤长时间无进展疑似挂起时，并行 `swift test` 的块缓冲会让日志难以定位卡点。临时把该步骤改为 `script -q /dev/null swift test … --no-parallel`（macOS 无 `stdbuf` / `timeout`，用 `script` 伪终端强制实时行输出 + 串行），重跑后日志最后一条 `started` 即挂起用例；定位修复后回滚该诊断改动。可配一个轮询脚本在预算内 `gh run cancel` 以省额度。

## 7. secret 配置（可选）

`Settings → Secrets and variables → Actions → New repository secret`：

- Name：`OPENAI_COMPATIBLE_API_KEY`，Value：对应 key。
- 不配置时 Python tooling 测试自动跳过，CI 仍可全绿。

## 8. 变更记录

- 2026-06-13：新增仓库内置 `scripts/git-hooks/pre-push` 钩子（repo 级 `core.hooksPath` 安装，仅本仓库），在本地拦截向 `main` 的直接推送，作为 Free 私有仓库 ruleset 失效期的硬兜底；并把"main 只走 PR"提升进 `docs/README.md` §4 第 18 条核心决策。原因：用户要求让该纪律不只靠 AI 记忆、必要时能被强制发现。影响范围：`scripts/git-hooks/`、§3.1、`docs/README.md` §4。是否需要 ADR：否。
- 2026-06-13：新增 §3.1 合并到 `main` 的标准流程（禁止本地直接合并、临时 public、`gh` 核对 `Build & Test`、走 PR），并写入 AI 协作约定。原因：用户要求规范"不允许直接 merge 到 main、合并时提醒切 public 并用 gh 检查状态、经 PR 合并"。影响范围：§3.1、`docs/README.md` §1.4 第 9 条。是否需要 ADR：否。
- 2026-06-13：扩写 §4，改用 Rulesets 步骤，并新增 §4.1 强制范围说明：「Require PR」禁止直接 push `main`、PR 总跑 CI；Free 私有仓库 ruleset 不强制、仅 public 时生效；约定只在 public 窗口期合并 `main`。原因：用户询问能否只走 PR、本地 merge 是否会绕过测试。影响范围：§4、§4.1。是否需要 ADR：否。
- 2026-06-13：新增 §1.1 测试场所与仓库可见性策略。原因：本机为 MacBook Air（被动散热），明确重测试放 CI、本机只做轻量动作；并固定「仓库平时 private、跑 CI 前临时设 public（免费 macOS）、AI 触发前提醒切 public」的协作约定。影响范围：§1.1、`docs/spec/009`、`docs/development/environment.md`、`docs/README.md` §1.4。是否需要 ADR：否。
- 2026-06-13：`actions/checkout` 升到 v5，并在 workflow 顶层加 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"`。原因：GitHub 将于 2026-06-16 强制 JS action 切到 Node 24，`checkout@v4` / `cache@v4` 在 Node 20 上持续告警；提前 opt-in 消除告警并在 Node 24 上预先验证。影响范围：`.github/workflows/ci.yml`。是否需要 ADR：否。
- 2026-06-13：补充 job `timeout-minutes: 40` 兜底，以及挂起步骤用 `script` 伪终端 + `--no-parallel` 串行定位的排查技巧。原因：首次跑通 UI 测试编译后，一个 continuation 竞态在并行模式下挂起 25 分钟才被人工取消，暴露出缺少超时兜底与卡点定位手段。影响范围：`.github/workflows/ci.yml`、§1、§6 排查提示。是否需要 ADR：否。
- 2026-06-13：补充 `[ci]` 触发匹配整条 commit message（含正文）的注意事项。原因：一次没有在标题写 `[ci]`、但正文讨论了 CI 机制并写下 `[ci]` 字样的修复提交被意外触发了远程 CI。影响范围：§2 触发策略；提醒后续提交避免在正文出现非预期的 `[ci]`。是否需要 ADR：否。
- 2026-06-13：创建 CI 与分支协作 runbook。原因：`.github/workflows/ci.yml` 已进入仓库并调整为 `[ci]` 提交标记 + PR 强制触发，需要一份执行手册沉淀触发策略、分支协作流程、main 分支保护配置和基于 `gh` 的失败日志获取流程；同时把 `gh` 明确为开发要求。影响范围：`.github/workflows/ci.yml`、`docs/spec/009-testing-and-verification.md`、`docs/development/environment.md` 和后续合并前验证流程。是否需要 ADR：否，沿用 009 的本地优先验证关系。
