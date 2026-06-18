# 003：CI Run 历史与耗时记录

创建日期：2026-06-17
关联文档：[002-ci-and-branch-workflow.md](002-ci-and-branch-workflow.md)

本文档记录每次 CI `Build & Test` job 的触发时间、各步骤耗时和结论，用于：

1. **估算完成时间**：触发后对照「步骤基线」预判剩余时长，决定何时查看结果。
2. **发现异常**：某步骤明显超出基线时，提前介入排查，避免等满 40 分钟 timeout。
3. **评估 CI 资源消耗**：success run 是 macOS runner 分钟的主要来源；failure 越早失败浪费越少。

> **使用方式**：每次 CI 成功（conclusion = success）后将当次 run 追加到「成功记录」表；失败 run 追加到「失败记录」表。从步骤耗时中更新「步骤耗时基线」。

---

## 1. 步骤耗时基线（基于已完成 run 均值）

> 基于 runner `macos-15`，项目当前规模，**Swift package 缓存命中**场景下的参考值。缓存 miss 时 package 测试步骤可能增加 1–3 分钟。

| 步骤 | 最小 | 最大 | 典型 | 备注 |
|---|---|---|---|---|
| Install tools | 7s | 10s | 8s | homebrew + xcodegen |
| Cache Swift package builds | 12s | 24s | 18s | 缓存命中时快；miss 时含下载 |
| Test LangoTraceCore | 22s | 25s | 23s | — |
| Test LangoTraceData | 29s | 36s | 33s | GRDB migration 较慢 |
| Test LangoTraceAI | 19s | 22s | 20s | — |
| Test LangoTraceSpeech | 17s | 19s | 18s | — |
| Test LangoTraceSync | 10s | 11s | 11s | — |
| Test LangoTraceUI | 47s | 61s | 54s | 最慢包，UI 状态机测试多 |
| Generate Xcode project | — | — | — | 含于 List schemes |
| List schemes | 25s | 63s | 44s | 含 xcodegen；wave 较大 |
| Resolve iOS Simulator destinations | 24s | 56s | 40s | 首次慢，缓存后快 |
| Build iOS — iPhone | 44s | 48s | 46s | 增量构建；全量约 3–5 min |
| Build iOS — iPad | 6s | 6s | 6s | 与 iPhone 共享 derived data |
| Build macOS | 41s | 42s | 42s | — |
| Test macOS app | 19s | 20s | 20s | LangoTraceAppTests |
| SwiftLint | — | — | ~10s | 未单独测量 |
| SwiftFormat | — | — | ~10s | 未单独测量 |
| Check docs / whitespace | — | — | ~5s | 未单独测量 |
| SwiftLint | 4s | ~10s | ~7s | — |
| SwiftFormat | 6s | ~10s | ~8s | — |
| Check docs / whitespace | — | — | ~2s | — |
| **Job 合计（典型）** | **5m57s** | **7m13s** | **~6m30s** | 含 push→runner 启动约 10s；缓存 miss 构建步骤可达 7m+ |

**估算方法**：触发后 3 分钟可以看 package 测试是否全绿；5 分钟后看 iOS build；6–7 分钟看最终结论。缓存失效（大批文件修改后首次 run）构建步骤可比基线慢 50–80%，属正常。

---

## 2. 成功记录

### Run 27595028506

| 字段 | 值 |
|---|---|
| Run ID | [27595028506](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27595028506) |
| 触发时间 | 2026-06-16 12:52 CST |
| 触发 commit | `style: fix SwiftFormat violations in Phase 3-余 test files [ci]` |
| 覆盖内容 | plan 01 (E0a) Phase 3-余 / 4 / 5 修复 + SwiftFormat 违规修正 |
| Job 总耗时 | **5m57s** |
| 结论 | ✅ success |

**步骤耗时：**

| 步骤 | 耗时 |
|---|---|
| Install tools | 7s |
| Cache Swift package builds | 12s（命中） |
| Test LangoTraceCore | 22s |
| Test LangoTraceData | 35s |
| Test LangoTraceAI | 19s |
| Test LangoTraceSpeech | 17s |
| Test LangoTraceSync | 10s |
| Test LangoTraceUI | 51s |
| List schemes | 30s |
| Resolve iOS Simulator destinations | 24s |
| Build iOS — iPhone | 48s |
| Build iOS — iPad | 6s |
| Build macOS | 41s |
| Test macOS app | 20s |

---

### Run 27596096967

| 字段 | 值 |
|---|---|
| Run ID | [27596096967](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27596096967) |
| 触发时间 | 2026-06-16 13:23 CST |
| 触发 commit | `docs(plans): plan 01 (E0a) CI 全绿收口完成，移入 done/` |
| 覆盖内容 | plan 01 E0a 文档收口（纯 docs 变更，验证 CI 对纯文档 commit 也正常） |
| Job 总耗时 | **6m30s** |
| 结论 | ✅ success |

**步骤耗时：**

| 步骤 | 耗时 |
|---|---|
| Install tools | 10s |
| Cache Swift package builds | 24s（命中） |
| Test LangoTraceCore | 23s |
| Test LangoTraceData | 29s |
| Test LangoTraceAI | 19s |
| Test LangoTraceSpeech | 19s |
| Test LangoTraceSync | 11s |
| Test LangoTraceUI | 47s |
| List schemes | 25s |
| Resolve iOS Simulator destinations | 56s（慢，推测 runner 冷启动） |
| Build iOS — iPhone | 44s |
| Build iOS — iPad | 6s |
| Build macOS | 42s |
| Test macOS app | 19s |

---

## 3. 失败记录

### Run 27699943565

| 字段 | 值 |
|---|---|
| Run ID | [27699943565](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27699943565) |
| 触发时间 | 2026-06-17 23:22 CST |
| 触发 commit | `docs: progress dashboard accuracy pass + AI handoff doc [ci]` |
| 覆盖内容 | E3 + E2-FU + R1 所有代码变更 |
| Job 总耗时 | 5m41s（提前终止） |
| 结论 | ❌ failure |
| 失败步骤 | Build iOS — iPhone（0m54s 后报错） |
| 失败原因 | `AVAudioSession.CategoryOptions.allowBluetoothHFP` 在 iOS 26.2 SDK 已删除（deprecated since iOS 17）；CI 使用 `OS=latest` = iOS 26.2，本地 Xcode 18.x 未触发 |
| 修复 commit | `a5684cd fix: remove allowBluetoothHFP removed in iOS 26 SDK [ci]` |

**失败前各步骤耗时：**

| 步骤 | 耗时 | 结论 |
|---|---|---|
| Install tools | 10s | ✅ |
| Cache Swift package builds | 24s | ✅ |
| Test LangoTraceCore | 25s | ✅ |
| Test LangoTraceData | 36s | ✅ |
| Test LangoTraceAI | 22s | ✅ |
| Test LangoTraceSpeech | 18s | ✅ |
| Test LangoTraceSync | 11s | ✅ |
| Test LangoTraceUI | 61s | ✅ |
| List schemes | 63s | ✅ |
| Build iOS — iPhone | 54s | ❌ |

> **经验**：iOS SDK 版本跳跃（18→26）会暴露 deprecated API 被移除问题；本地构建不会触发是因为本地 SDK 版本不同。后续引入 deprecated AVFoundation / UIKit API 时应检查 iOS 26 兼容性。

---

### Run 27700702770（已取消）

| 字段 | 值 |
|---|---|
| Run ID | [27700702770](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27700702770) |
| 触发时间 | 2026-06-17 23:34 CST |
| 触发 commit | `fix: remove allowBluetoothHFP removed in iOS 26 SDK [ci]` |
| 覆盖内容 | E3 + E2-FU + R1 + allowBluetoothHFP 修复 |
| Job 总耗时 | 3m50s（提前取消） |
| 结论 | ⚠️ cancelled |
| 取消原因 | 紧随其后的 docs push（791d3cf，无 `[ci]`）触发 concurrency cancel，GitHub 自动终止旧 run；docs run（27700934480）因无 `[ci]` 被 skip，导致没有有效 CI 结论 |
| 后续 | 补发空 commit `873b991`（`[ci]`），触发 run 27701227659 重跑

---

### Run 27701227659（已取消）

| 字段 | 值 |
|---|---|
| Run ID | [27701227659](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27701227659) |
| 触发时间 | 2026-06-17 23:42 CST |
| 触发 commit | `ci: retrigger Build & Test after concurrency cancel [ci]` |
| 覆盖内容 | E3 + E2-FU + R1 + allowBluetoothHFP 修复 |
| Job 总耗时 | 54s（提前取消） |
| 结论 | ⚠️ cancelled |
| 取消原因 | 同上：ci-run-history.md 更新 commit（24d7166，无 `[ci]`）推送后触发 concurrency cancel |
| 根本原因分析 | workflow 的 `concurrency.cancel-in-progress: true` + 同一 `group` 配置，导致任何 push（含被 skip 的无标记 commit）都会 cancel 正在跑的 job；skip run 不消耗 runner 资源，却会错误地杀掉有效 CI run |
| 修复 | 将 `cancel-in-progress: false` + `group` 加入 `github.sha`，每个 commit 独立 concurrency slot，不再相互 cancel；见 commit `ci: fix concurrency cancel-in-progress` |

---

### Run 27701699855

| 字段 | 值 |
|---|---|
| Run ID | [27701699855](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27701699855) |
| 触发时间 | 2026-06-17 23:50 CST |
| 触发 commit | `ci: fix concurrency cancel-in-progress + retrigger Build & Test [ci]` |
| 覆盖内容 | E3 + E2-FU + R1 + allowBluetoothHFP 修复 + workflow concurrency 修复 |
| Job 总耗时 | 10m8s（提前终止） |
| 结论 | ❌ failure |
| 失败步骤 | Test macOS app |
| 失败原因 | `AppEnvironmentPracticeBootstrapTests` 两个 bug：(1) 仍使用 E3 已重命名的 `createOrRestoreShadowingSession`（编译失败）；(2) `practiceSnapshot` helper 使用未加 materialID 前缀的 `sentenceID: "sentence-1"`，而 DB 实际存储 `"material-1-sentence-1"`，导致 `practice_sessions.sentence_id` FK constraint 失败 |
| 修复 commit | `470d885 fix(tests): update AppEnvironmentPracticeBootstrapTests for E3 PracticeActions rename [ci]` |

---

### Run 27702909733

| 字段 | 值 |
|---|---|
| Run ID | [27702909733](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27702909733) |
| 触发时间 | 2026-06-18 00:09 CST |
| 触发 commit | `fix(tests): update AppEnvironmentPracticeBootstrapTests for E3 PracticeActions rename [ci]` |
| 覆盖内容 | E3 + E2-FU + R1 + allowBluetoothHFP 修复 + concurrency 修复 + macOS 测试修复 |
| Job 总耗时 | 6m53s（提前终止） |
| 结论 | ❌ failure |
| 失败步骤 | SwiftLint |
| 失败原因 | 11 个 file_length / function_body_length / type_body_length error：AppEnvironment.swift、AppDatabase.swift 等多个大文件超出默认上限（1000/100/350），由 E2-FU、E3、R1 引入的迁移文件、UI 组合文件和长测试函数导致 |
| 修复 commit | `24db7a0 ci: raise SwiftLint length thresholds for early-stage codebase [ci]` |

---

### Run 27703576422

| 字段 | 值 |
|---|---|
| Run ID | [27703576422](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27703576422) |
| 触发时间 | 2026-06-18 00:21 CST |
| 触发 commit | `ci: raise SwiftLint length thresholds for early-stage codebase [ci]` |
| 覆盖内容 | E3 + E2-FU + R1 + 全部修复 |
| 结论 | ❌ failure |
| 失败步骤 | SwiftFormat |
| 失败原因 | 16 个文件存在 SwiftFormat 违规（hoistPatternLet、docComments、wrapMultilineStatementBraces、consecutiveBlankLines、sortImports、hoistTry、redundantType、andOperator、redundantReturn、redundantSelf、indent 等），这些文件在之前的 E2-FU / E3 / R1 开发中未跑 swiftformat |
| 修复 commit | `c0e4baf style: fix SwiftFormat violations across 16 files [ci]` |

---

---

## 2. 成功记录（续）

### Run 27704455744

| 字段 | 值 |
|---|---|
| Run ID | [27704455744](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27704455744) |
| 触发时间 | 2026-06-18 00:35 CST |
| 触发 commit | `style: fix SwiftFormat violations across 16 files [ci]` |
| 覆盖内容 | E3 + E2-FU + R1 + allowBluetoothHFP 修复 + concurrency 修复 + macOS 测试修复 + SwiftLint 阈值 + SwiftFormat 清理 |
| Job 总耗时 | **7m13s** |
| 结论 | ✅ success |

**步骤耗时（构建步骤偏高，因 16 文件格式化后缓存失效导致部分重编译）：**

| 步骤 | 耗时 | 备注 |
|---|---|---|
| Install tools | 7s | — |
| Cache Swift package builds | 23s（命中） | — |
| Test LangoTraceCore | 21s | — |
| Test LangoTraceData | 25s | — |
| Test LangoTraceAI | 18s | — |
| Test LangoTraceSpeech | 17s | — |
| Test LangoTraceSync | 11s | — |
| Test LangoTraceUI | 51s | — |
| List schemes | 59s | — |
| Resolve iOS Simulator destinations | 2s | runner 内复用，极快 |
| Build iOS — iPhone | 75s | 缓存失效，高于基线 |
| Build iOS — iPad | 10s | — |
| Build macOS | 66s | 缓存失效，高于基线 |
| Test macOS app | 25s | — |
| SwiftLint | 4s | — |
| SwiftFormat | 6s | — |
| Check docs | 1s | — |
| Check whitespace | 0s | — |

---

### Run 27734118877（E5 Slice 1）

| 字段 | 值 |
|---|---|
| Run ID | [27734118877](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27734118877) |
| 触发时间 | 2026-06-18 11:09 CST（workflow_dispatch） |
| 触发 commit | `docs(practice): record E5 Slice 1 backtranslation landing (E5)`（HEAD docs commit，push 无 `[ci]` 被 skip，故用 workflow_dispatch 触发） |
| 覆盖内容 | E5 Slice 1 纯本地回译（sentenceAnalysis seam + diff-NULL 不变量 + 回译会话 + 装配 + 文档） |
| Job 总耗时 | 1m37s（提前终止） |
| 结论 | ❌ failure |
| 失败步骤 | Test LangoTraceData |
| 失败原因 | `PracticeTextAttemptRepositoryTests` 把非 Sendable 的 GRDB `Row?` 跨 `async databaseQueue.read` 边界返回；CI 严格并发检查拒绝（`cannot use optional chaining on non-optional value of type '()'`），本机工具链较宽松未捕获 |
| 修复 commit | `f798610 test(data): keep GRDB Row inside the read closure in backtranslation test (E5) [ci]`（改为在闭包内提取 `(Int?, String?, Int?)` Sendable 元组） |

> **经验**：GRDB `Row` 不是 `Sendable`，不能从 `async` 的 `read`/`write` 闭包返回；必须在闭包内提取 Sendable 值（标量、`Set`、元组）。本机工具链不强制此约束，CI 才暴露——后续测试从 async DB 读取时一律在闭包内取标量。

---

## 2. 成功记录（续二）

### Run 27734245351（E5 Slice 1 收口）

| 字段 | 值 |
|---|---|
| Run ID | [27734245351](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27734245351) |
| 触发时间 | 2026-06-18 11:13 CST |
| 触发 commit | `test(data): keep GRDB Row inside the read closure in backtranslation test (E5) [ci]` |
| 覆盖内容 | E5 Slice 1 纯本地回译全量（Data seam + diff-NULL 不变量 + 回译会话 + App 装配注册 + 文档）+ Row Sendable 修复 |
| Job 总耗时 | **7m54s** |
| 结论 | ✅ success |

**步骤耗时：**

| 步骤 | 耗时 | 备注 |
|---|---|---|
| Install tools | 8s | — |
| Cache Swift package builds | 23s（命中） | — |
| Test LangoTraceCore | 30s | — |
| Test LangoTraceData | 33s | — |
| Test LangoTraceAI | 29s | — |
| Test LangoTraceSpeech | 24s | — |
| Test LangoTraceSync | 14s | — |
| Test LangoTraceUI | 74s | 缓存部分失效，略高于基线 |
| List schemes | 31s | — |
| Resolve iOS Simulator destinations | 3s | — |
| Build iOS — iPhone | 63s | 缓存部分失效 |
| Build iOS — iPad | 10s | — |
| Build macOS | 73s | 缓存部分失效 |
| Test macOS app | 34s | App target 装配 + 回译注册编译验证通过 |
| SwiftLint | 4s | — |
| SwiftFormat | 6s | — |
| Check docs | 1s | — |
| Check whitespace | 0s | — |

---

## 4. 维护约定

- 每次 CI `success` 后，将 run 数据追加到「成功记录」，并用新数据更新「步骤耗时基线」均值。
- 每次 CI `failure` 后，将 run 数据追加到「失败记录」，记录失败步骤、原因和修复 commit。
- 当前 run 正在进行时，在「失败记录」中以「进行中」占位，结论确定后补全。
- 本文档由 AI 在完成 CI 监控后自动追加；用户无需手动维护。
