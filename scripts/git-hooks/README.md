# 仓库 Git 钩子

本目录存放**仓库内置、随仓库分发**的 Git 钩子，用于在本地强制项目协作纪律。

## 安装（每个克隆执行一次，仅影响本仓库）

```bash
# 在仓库根目录运行；写入本仓库 .git/config，不带 --global，不影响全局或其他仓库
git config core.hooksPath scripts/git-hooks
# 确保可执行
chmod +x scripts/git-hooks/*
```

验证：

```bash
git config --get core.hooksPath      # 应输出 scripts/git-hooks
```

卸载（恢复默认 .git/hooks）：

```bash
git config --unset core.hooksPath
```

## 当前钩子

- **`pre-commit`**：扫描暂存文件中的 API Key 模式，防止真实密钥意外提交（见 [spec-008 §3.1](../../docs/spec/008-permissions-local-privacy-and-diagnostics.md)）。
  - 检测 OpenRouter、Anthropic、OpenAI、MIMO、Google、Groq、xAI 等主流格式的真实密钥。
  - `.env.example` 等模板文件只应包含占位符（如 `sk-or-v1-...`），hook 会区分真实密钥与占位符。
  - 紧急绕过（仅在确认无密钥时）：`git commit --no-verify`。

- **`pre-push`**：拦截向 `main` 的直接推送。`main` 的变更必须经 PR + `Build & Test` 绿勾合并（见 [CI 与分支协作 Runbook §3.1](../../docs/development/002-ci-and-branch-workflow.md)）。
  - 即使仓库为 private（此时 GitHub ruleset 在 Free 计划下不生效）本钩子仍在本地拦截，是 AI 记忆无关的硬兜底。
  - 紧急绕过（不推荐）：`git push --no-verify`。

## 说明

- `core.hooksPath` 是 **repo 级**配置（写入本仓库 `.git/config`），仅对本仓库生效。
- 钩子脚本随仓库版本控制，因此团队/多设备克隆后只需跑一次上面的安装命令即可获得相同钩子。
- `.git/hooks/` 下的默认示例钩子不再生效（git 只读 `core.hooksPath` 指向的目录）；本仓库目前不依赖其他钩子。
