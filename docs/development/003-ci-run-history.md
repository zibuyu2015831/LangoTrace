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
| **Job 合计（典型）** | **5m57s** | **6m34s** | **~6m15s** | 含 push→runner 启动约 10s |

**估算方法**：触发后 3 分钟可以看 package 测试是否全绿；5 分钟后看 iOS build；6–7 分钟看最终结论。

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

### Run 27700702770（进行中）

| 字段 | 值 |
|---|---|
| Run ID | [27700702770](https://github.com/zibuyu2015831/LangoTrace/actions/runs/27700702770) |
| 触发时间 | 2026-06-17 23:34 CST |
| 触发 commit | `fix: remove allowBluetoothHFP removed in iOS 26 SDK [ci]` |
| 覆盖内容 | E3 + E2-FU + R1 + allowBluetoothHFP 修复 |
| 结论 | ⏳ in_progress |

*耗时待更新。*

---

## 4. 维护约定

- 每次 CI `success` 后，将 run 数据追加到「成功记录」，并用新数据更新「步骤耗时基线」均值。
- 每次 CI `failure` 后，将 run 数据追加到「失败记录」，记录失败步骤、原因和修复 commit。
- 当前 run 正在进行时，在「失败记录」中以「进行中」占位，结论确定后补全。
- 本文档由 AI 在完成 CI 监控后自动追加；用户无需手动维护。
