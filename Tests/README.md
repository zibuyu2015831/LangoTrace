# Tests

本目录是项目级测试索引。可执行单元测试默认放在所属 Swift Package 模块旁边的 `Packages/*/Tests`。

## 测试落点

单元测试使用 package 内部 test target：

- Core 领域测试：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/`
- Data / Repository 测试：`Packages/LangoTraceData/Tests/LangoTraceDataTests/`
- AI Provider / 请求边界测试：`Packages/LangoTraceAI/Tests/LangoTraceAITests/`
- SwiftUI 状态、presentation model 和源码边界测试：`Packages/LangoTraceUI/Tests/LangoTraceUITests/`
- 项目级开发脚本测试：`Tests/Tooling/`

当一个功能有多个测试文件，或预期会继续扩展时，应在对应 package test target 内创建功能子目录。当前示例：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/`

不要把 package 单元测试搬到根目录 `Tests/`，除非同时在 `project.yml` 中新增真实项目级 XCTest target。根目录测试目录保留给未来跨 package 集成测试、UI 自动化、共享 fixtures 或测试 runbook。

## TDD 规则

新功能、bug 修复、架构调整和行为变化，只要可以自动化验证，就应先创建或更新相关单元测试，再实施代码。

最低要求：

- 先新增一个能失败的测试，用来锁定目标行为或回归场景。
- 再实施能让测试通过的最小代码变更。
- 测试文件应靠近所属模块和功能目录。
- 先运行聚焦 package 测试，再运行更广的验证。
- Swift 代码或工程行为变化后，完成前必须运行 `scripts/verify.sh`。

Python 开发脚本的聚焦测试可以直接运行：

```bash
python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py
```

## 运行时日志

运行期问题、人工验证失败或模拟器复现失败时，优先使用仓库脚本采集本地日志：

```bash
scripts/capture-runtime-log --last 30m
```

脚本会把日志写入被 Git 忽略的 `logs/`，并更新 `logs/latest.log`，便于 AI 辅助排查。App 不应直接写仓库目录；日志采集由宿主机脚本完成。

## AI Provider 外部连通性诊断

iOS / iPadOS / macOS 内部 Provider 测试失败时，如果需要先排除 API Key、Base URL 或模型名本身不可用，可使用宿主机脚本发送固定合成请求：

```bash
OPENAI_API_KEY='...' scripts/probe_openai_compatible_api.py \
  --base-url 'https://api.example.com' \
  --model 'model-name' \
  --mode chat
```

脚本只用于开发期诊断，不属于 App 运行链路；不会打印 API Key、请求体或响应体。`--mode both` 会分别测试 OpenAI-compatible Chat Completions 和 Responses API。

如果不携带任何参数，脚本会进入交互模式，依次要求输入 Base URL、API Key 和 Model；API Key 在终端输入时可见，但脚本输出仍会脱敏。
