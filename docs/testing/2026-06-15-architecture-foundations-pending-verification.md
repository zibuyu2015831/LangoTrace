# 待验证清单：系列 E0a 架构地基整固（Mac / GitHub Actions）

本文件收集任务方案 `docs/plans/active/2026-06-11-01-refactor-architecture-foundations.md` 实施过程中，**在本机（Linux，无 Swift 工具链）无法运行**、必须在 Mac 开发机或 GitHub Actions 上执行的验证项。每个 Phase 提交后在此登记；用户在 Mac / CI 跑完后回填结果（通过 / 失败 + 处理）。

## 背景

- 实施环境为 Linux，无 Swift 工具链，所有 `swift test` / `xcodebuild` 均无法在本机运行。
- 本仓库重测试一律走 GitHub Actions（重测试约束见 `CLAUDE.md` §1.4 第 8 条）；触发 CI 前需将仓库临时设为 public，commit message 带 `[ci]`。
- 所有改动按 Phase 逐个 commit 并推送 `dev`，验证集中在 Mac/CI 一次性完成。

## 验证矩阵

| 状态符号 | 含义 |
|---|---|
| ⬜ | 待验证（本机已写代码/测试，未在 Mac/CI 运行） |
| ✅ | Mac/CI 已通过 |
| ❌ | Mac/CI 失败（附处理） |

---

### Phase 1：AI text provider adapter 抽象

落点：`Packages/LangoTraceAI`。

- ⬜ 聚焦测试：`swift test --package-path Packages/LangoTraceAI --filter AIProviderTextRequestAdapterTests`
- ⬜ 全包回归：`swift test --package-path Packages/LangoTraceAI`（三个文本服务与 probe 现有 fixture 行为不变）
- ✅ 结构性检查（本机 rg 自查已执行）：三个文本服务源码内 `Bearer \(` 注入归零；Bearer 仅余 `AIProviderTextRequestAdapter.swift`（唯一新家）+ `TTSProviderAdapter.swift` / `EmbeddingConfigurationProbeService.swift`（按方案 §5 排除）。adapterKind 请求构造 switch 在三个服务中归零。

预期：adapter 抽象不改变请求体与解析的可观察行为；现有 `LearningMaterialGenerationServiceTests` / `ReadingSelectionExplanationServiceTests` / `AIProviderConfigurationProbeServiceTests` 全绿。

结果回填：_（待 Mac/CI）_

---

_（后续 Phase 在实施时追加）_
