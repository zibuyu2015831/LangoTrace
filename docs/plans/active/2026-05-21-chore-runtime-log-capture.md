# 任务方案：运行时日志采集到本地 logs 目录

状态：In Progress
类型：chore
创建日期：2026-05-21
最后更新日期：2026-05-21

## 用户确认记录

- 2026-05-21：用户提出希望系统运行时日志记录到项目中，创建 `logs/` 目录并在 `.gitignore` 中排除，目的是便于 AI 辅助编程时读取日志排查问题。
- 2026-05-21：经系统架构师视角审查后确认：不让 App 直接写仓库目录；采用宿主机脚本采集模拟器 / macOS OSLog 到项目根目录 `logs/`，App 继续通过现有 `OSLog` / 诊断体系产生非敏感结构化日志。
- 2026-05-21：用户确认创建具体方案文档并立即实施。

## 需求描述

AI 辅助编程排查运行期问题时，需要能在仓库内快速读取最近一次 App 运行日志。当前可以临时运行 `xcrun simctl spawn ... log show`，但命令长、过滤条件容易不一致，输出不固定，AI 每次都需要重新定位日志。

本任务新增一个本地开发脚本，将模拟器或本机 OSLog 中的 LangoTrace 运行日志采集到项目根目录 `logs/`。`logs/` 已由 `.gitignore` 排除，日志可供本机 AI 读取但不会进入 Git。

## 现状描述

- `LangoTraceApp/AppEnvironment.swift` 已支持通过 `LANGOTRACE_DIAGNOSTICS=1` 开启 `ConsoleDiagnosticLogger`，输出到 `OSLog(subsystem: "com.zibuyu.LangoTrace")`。
- `scripts/verify.sh` 是当前唯一通用验证脚本，没有运行时日志采集脚本。
- `.gitignore` 已包含 `*.log`，本轮已新增 `/logs/` 忽略规则并创建本地 `logs/` 目录。
- iOS App 沙盒不能自然写宿主机仓库目录；让 App 直接写仓库路径会污染架构，也无法覆盖真机和发布环境。

## 目标

- 新增 `scripts/capture-runtime-log`，用于把 LangoTrace 运行日志采集到 `logs/`。
- 默认输出到 `logs/runtime-YYYYMMDD-HHMMSS.log`，并同步更新 `logs/latest.log`。
- 支持历史导出和实时流式采集。
- 默认过滤 LangoTrace App process 和 `com.zibuyu.LangoTrace` subsystem，降低系统噪音。
- 支持 AI Provider 场景的快捷过滤。
- 不改变 App 运行时架构，不让 SwiftUI / AI / Data 层知道仓库路径。
- 更新测试 / 入口文档，说明运行期问题排查时优先采集 `logs/latest.log`。

## 范围

本任务覆盖：

- `.gitignore` 根目录 `logs/` 忽略规则。
- `scripts/capture-runtime-log` 本地开发脚本。
- `Tests/README.md`、`docs/testing/README.md`、`docs/README.md` 的日志采集说明。
- 当前 AI Provider active 方案中的实施记录补充。

本任务不覆盖：

- App 内文件日志系统。
- 真机日志自动导出。
- 将日志上传或写入远端服务。
- 采集 API Key、Authorization header、请求体、响应体或用户内容。
- 诊断数据库导出包。

## 证据与决策依据

- iOS / iPadOS App 运行在沙盒中，直接写项目目录不可作为稳定架构。
- LangoTrace 已有 `OSLog` 诊断路径，适合作为开发期运行日志来源。
- `logs/` 被 `.gitignore` 排除后，AI 可以读取本地排查材料，Git 不会提交临时日志。
- 日志采集脚本比 App 直接写仓库路径更符合本地优先、隐私边界和发布架构隔离原则。

## 涉及的代码文件路径

- `.gitignore`
- `scripts/capture-runtime-log`

## 参考的代码文件路径

- `scripts/verify.sh`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticLogger.swift`

## 涉及的文档路径

- `docs/README.md`
- `docs/testing/README.md`
- `Tests/README.md`
- `docs/plans/active/2026-05-21-feature-ai-provider-text-model-test-request.md`

## 实施方案

1. 保留 `logs/` 为本地忽略目录。
2. 新增 `scripts/capture-runtime-log`：
   - `--last <duration>`：导出最近一段历史日志，默认 `30m`。
   - `--stream`：实时流式采集，直到用户中断。
   - `--device <uuid|booted>`：指定模拟器，默认 `booted`。
   - `--macos`：采集宿主机 macOS unified log，而不是 simulator log。
   - `--category ai-provider`：追加 AI Provider 相关关键词过滤。
   - `--output <path>`：指定输出文件，默认生成 timestamp 文件。
   - `--no-latest`：不更新 `logs/latest.log`。
   - `--help`：输出中文帮助。
3. 脚本只负责采集 OSLog / unified log，不启动 App、不写 App 数据库、不读取 Keychain。
4. 文档补充：运行期问题排查时先运行脚本生成 `logs/latest.log`，再交给 AI 读取分析。

## 复查方法

- 检查脚本是否包含中文 help、严格参数校验、默认安全过滤。
- 检查 `.gitignore` 是否忽略 `/logs/`。
- 检查文档是否明确 App 不直接写仓库目录。
- 检查脚本不会输出到 Git 跟踪路径。

## 验证命令

```bash
scripts/capture-runtime-log --help
git check-ignore -v logs logs/latest.log
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs Tests --glob '!docs/plans/examples/*' --glob '!docs/spec/examples/*'
scripts/verify.sh
```

如果需要验证真实采集，可在模拟器启动后运行：

```bash
scripts/capture-runtime-log --last 5m
```

## 文档影响检查

- 需要更新 `docs/README.md`：入口文件说明运行期排查优先采集 `logs/latest.log`。
- 需要更新 `docs/testing/README.md`：新增运行时日志采集说明。
- 需要更新 `Tests/README.md`：说明测试失败或人工验证失败时可附带 `logs/latest.log`。
- 不需要更新 ADR；本任务不改变 App 运行时架构，只新增本地开发工具。

## 实施记录

- 2026-05-21：创建方案文档。
- 2026-05-21：新增 `scripts/capture-runtime-log` 并设为可执行；脚本支持 `--help`、`--last`、`--stream`、`--device`、`--macos`、`--category ai-provider`、`--output` 和 `--no-latest`。`.gitignore` 已忽略 `/logs/`，`Tests/README.md`、`docs/testing/README.md`、`docs/README.md` 已补充运行时日志采集和 App 不直接写仓库目录的边界。
- 2026-05-21：验证 `scripts/capture-runtime-log --help` 通过；`git check-ignore -v logs logs/latest.log` 确认日志目录被忽略。普通沙盒下访问 CoreSimulatorService 失败，错误包含 `Operation not permitted` / `Connection refused`；按工具权限升级后 `scripts/capture-runtime-log --last 5m --category ai-provider --output logs/runtime-ai-provider-smoke-filtered.log` 成功生成日志并更新 `logs/latest.log`。首次 `ai-provider` 过滤包含通用 `Provider`，误采集系统 `LocationProvider` 噪音；已收紧为 `AIProvider` / `aiProvider` / `configurationProbe`，复测 `logs/latest.log` 不再包含 `LocationProvider`。

## 完成标准

- `scripts/capture-runtime-log --help` 可用。
- `logs/` 和 `logs/latest.log` 被 Git 忽略。
- 脚本能在默认参数下把模拟器 LangoTrace 日志写入 `logs/`。
- 文档说明清楚 App 不直接写仓库目录，日志采集由宿主机脚本完成。
- 验证命令通过；如真实采集因当前没有 booted simulator 或无日志而无法验证，需说明剩余风险。

## 剩余风险

- OSLog 由系统统一日志管理，历史日志可能受系统保留策略影响，不保证任意时间都可回溯。
- `--stream` 会持续运行，用户需要手动中断。
- 若 App 未开启 `LANGOTRACE_DIAGNOSTICS=1`，只能采集系统层面日志和已有 `OSLog` 输出，诊断事件粒度可能不足。
- 日志采集仍必须遵守隐私边界，不应把 API Key、请求体、响应体或用户内容写入 OSLog。
