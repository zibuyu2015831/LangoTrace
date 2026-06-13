# 009：测试与验证入口规范

状态：Accepted

适用阶段：所有代码、文档、UI、数据、AI、权限、同步、StoreKit 和发布相关任务。

## 1. 适用范围

本文档定义 `docs/spec/` 与 `docs/testing/README.md` 的权威关系，并给后续 AI 会话一个选择验证方式的统一入口。具体测试步骤、截图矩阵和人工验证清单仍由 `docs/testing/README.md` 维护。

## 2. 当前结论

`docs/testing/README.md` 是测试流程和手动清单的主入口。各 spec 可以定义自身验收门槛，但不得复制出一套互相冲突的验证体系。若 spec 与 testing 文档冲突，先按更严格且更贴近当前任务风险的要求执行，并在任务方案中记录冲突，再修正文档。

## 3. 任务类型到验证入口

| 任务类型 | 最低验证 | 追加验证 |
| --- | --- | --- |
| 纯文档 | `find docs -maxdepth 3 -type f \| sort`、占位扫描、`git diff --check`、`git status --short` | 影响代码事实或核心决策时做语义审查 |
| Swift package 逻辑 | 对应 package 的 `swift test` | 收尾运行 `scripts/verify.sh` |
| SwiftUI 页面 / 路由 | `swift test --package-path Packages/LangoTraceUI` | iPhone / iPad / macOS 手动或截图验证 |
| 数据库 / 附件 / 导出 | Repository、迁移、附件和导出测试 | 启动恢复、隐私扫描、`scripts/verify.sh` |
| AI Provider / Prompt | Provider、Prompt、结构化输出和失败测试 | 请求预览、日志脱敏和外部请求边界验证 |
| 权限 / Speech / OCR / TTS / 练习录音 | 权限状态、Speech seam、TTS adapter / repository / UI 状态测试、练习录音 media artifact schema / metadata 测试 | 真机或模拟器权限、TTS 试听、录音 staging -> ready artifact、外部 Provider 失败路径手动验证 |
| 本地化 | Core 语言偏好测试、String Catalog 检查 | 多语言截图、Dynamic Type、长文本和发布材料检查 |
| 同步 | Adapter、冲突和失败恢复测试 | 多设备或多本地库演练 |
| StoreKit / 发布 | StoreKit 测试配置、恢复购买验证 | App Store 隐私标签、截图和 TestFlight 清单 |

## 4. 强制规则

- 任何完成声明前必须有本轮新运行的验证证据。
- 文档任务至少运行入口文档列出的四个文档检查命令。
- 涉及 Swift 工程状态的任务，收尾优先运行 `scripts/verify.sh`；无法运行时必须说明原因和剩余风险。
- `scripts/verify.sh` 是 Swift 工程收尾门禁，至少覆盖 XcodeGen、Xcode project list、Core/Data/AI/Speech/Sync/UI package 测试、Python tooling tests、iPhone build、iPad build、macOS build、SwiftLint、SwiftFormat 和文档占位扫描。
- `.github/workflows/ci.yml` 是 `scripts/verify.sh` 的远程镜像，跑同一套 package 测试、三端构建、lint 和 `scripts/check-docs.sh`。本地 `scripts/verify.sh` 仍是开发收尾的权威门禁，远程 CI 是合并前的二次确认，不替代本地验证。
- CI 触发策略采用「push 显式选择 + PR 强制」：直接 push 到 `main`、`dev` 仅当 commit message 含 `[ci]` 时运行（避免每次推送都占用 macOS runner）；PR 到 `main`、`dev` 以及手动 `workflow_dispatch` 总是运行，以便分支保护可以把 `Build & Test` 设为合并前必过检查。功能开发应走独立分支，通过 PR 合并到 `dev`、再合并到 `main`。
- CI 的 iOS 模拟器目标以本地基线（iPhone 17 / iPad Pro 13-inch (M5)）为优先，并在 runner 镜像缺失该设备时自动回退到最新同类模拟器或 generic SDK 构建；若调整本地基线设备，应同步检查 CI 解析逻辑。
- 涉及 UI 的任务不能只靠编译通过；需要按 `docs/testing/README.md` 做三端页面、截图或手动验证。
- 涉及隐私、权限、AI 请求、日志、导出或同步的任务必须检查敏感数据不会出现在日志、导出包或未经确认的外部请求中。
- 涉及 AI Provider 保存、Keychain、诊断日志或请求边界的任务，必须至少运行 Core、Data、AI、UI 中受影响 package 的测试，并执行敏感字段扫描；收尾再运行 `scripts/verify.sh`。
- 涉及 TTS Provider 配置、测试、试听或逐句播放前置的任务，必须同时运行 Core、Data、AI、Speech、UI 中受影响 package 的测试；Speech package 用于证明音频校验 / preview seam，不能用 AI package 的 HTTP 响应校验替代。
- 涉及练习录音、回放、media artifact schema 或 `MediaArtifacts` 文件晋升路径的任务，必须覆盖 UI 状态机、Data repository / migration、App assembly seam 和真实模拟器或真机的 staging -> ready artifact 验证；同类故障优先按 `docs/testing/practice-recording-troubleshooting.md` 排查。
- 涉及 iOS / iPadOS Keychain 的模拟器验证不得使用完全禁用 code signing 的构建产物。验证前应确认 iOS target 的 `CODE_SIGNING_ALLOWED` 不是 `NO`，并检查构建日志中有模拟器 entitlement 注入或本地签名步骤。
- 验证结果应写回任务方案、审查 round 或对应测试记录，不只留在聊天中。

## 5. AI 开发提示

开始实现前先决定：

- 当前任务属于哪一类验证入口？
- 哪些检查可以用自动化证明，哪些必须手动验证？
- 是否影响文档事实、核心决策或发布承诺？
- 如果无法运行统一脚本，剩余风险是什么，是否需要用户确认？

## 6. 变更记录

- 2026-05-18：创建测试与验证入口规范。原因：spec 深审确认测试文档已经存在，但 `docs/spec/` 缺少统一入口和对 `docs/testing/README.md` 的明确委托关系。影响范围：所有任务方案、审查 round、验证记录和完成门禁。是否需要 ADR：否。
- 2026-05-20：补充 AI package 与诊断隐私验证门禁。原因：AI Provider 配置保存链路已经跨 Core/Data/AI/UI，统一验证脚本必须覆盖 `Packages/LangoTraceAI`，隐私敏感任务也需要敏感字段扫描。影响范围：`scripts/verify.sh`、任务方案验证记录、AI Provider、诊断日志和后续权限 / 请求任务。是否需要 ADR：否。
- 2026-05-20：补充 iOS / iPadOS Keychain 模拟器签名验证规则。原因：AI Provider 保存失败排查确认完全禁用 code signing 的模拟器产物无法可靠验证 Keychain 写入。影响范围：`project.yml`、XcodeGen、AI Provider 保存验证和后续权限 / Keychain 任务。是否需要 ADR：否。
- 2026-05-23：补充 TTS Provider 配置测试验证门禁。原因：TTS 配置测试跨 Core 配置模型、Data voice profile、AI Provider 请求、Speech 音频校验和 UI 结果面板，不能只用 AI HTTP 响应测试代表音频可用性。影响范围：TTS Provider 配置、Speech package test target、逐句播放前置和后续媒体资产基础设施任务。是否需要 ADR：否，沿用 011 规范。
- 2026-05-24：补充 Sync package 和 Python tooling 进入统一验证门禁。原因：项目级审查确认 Sync package 已进入工程依赖图但缺 test target，Python tooling tests 也未进入 `scripts/verify.sh`。影响范围：`scripts/verify.sh`、Sync package、工具脚本测试和后续同步开发。是否需要 ADR：否。
- 2026-05-26：补充练习录音 media artifact 验证门禁。原因：单句练习录音回放故障确认，真实录音文件可能已经进入 staging，但旧库 schema、artifact commit 或 session reload 任一层失败都会让 `回放录音` 不可用；验证入口需要明确 schema / metadata / 文件晋升 / UI 状态同时覆盖。影响范围：Data migration、Speech recording seam、UI practice state、App assembly 和故障排查 runbook。是否需要 ADR：否。
- 2026-06-13：登记 GitHub Actions CI 为 `scripts/verify.sh` 的远程镜像门禁。原因：`.github/workflows/ci.yml` 已进入仓库并在 push / PR 跑全套验证，但 spec 与 environment 文档此前未记录远程 CI，文档落后于工程事实；同时记录 CI 模拟器目标的自动回退策略，避免 runner 镜像设备轮换导致 destination 解析失败。影响范围：`.github/workflows/ci.yml`、`scripts/verify.sh`、`docs/development/environment.md`、合并前验证流程和后续模拟器基线调整。是否需要 ADR：否，沿用本规范的本地优先验证关系。
