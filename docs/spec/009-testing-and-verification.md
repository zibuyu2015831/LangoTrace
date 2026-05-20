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
| 权限 / Speech / OCR / TTS | 权限状态和 unavailable / mock 流程测试 | 真机或模拟器权限手动验证 |
| 本地化 | Core 语言偏好测试、String Catalog 检查 | 多语言截图、Dynamic Type、长文本和发布材料检查 |
| 同步 | Adapter、冲突和失败恢复测试 | 多设备或多本地库演练 |
| StoreKit / 发布 | StoreKit 测试配置、恢复购买验证 | App Store 隐私标签、截图和 TestFlight 清单 |

## 4. 强制规则

- 任何完成声明前必须有本轮新运行的验证证据。
- 文档任务至少运行入口文档列出的四个文档检查命令。
- 涉及 Swift 工程状态的任务，收尾优先运行 `scripts/verify.sh`；无法运行时必须说明原因和剩余风险。
- `scripts/verify.sh` 是 Swift 工程收尾门禁，至少覆盖 XcodeGen、Xcode project list、Core/Data/AI/UI package 测试、iPhone build、iPad build、macOS build、SwiftLint、SwiftFormat 和文档占位扫描。
- 涉及 UI 的任务不能只靠编译通过；需要按 `docs/testing/README.md` 做三端页面、截图或手动验证。
- 涉及隐私、权限、AI 请求、日志、导出或同步的任务必须检查敏感数据不会出现在日志、导出包或未经确认的外部请求中。
- 涉及 AI Provider 保存、Keychain、诊断日志或请求边界的任务，必须至少运行 Core、Data、AI、UI 中受影响 package 的测试，并执行敏感字段扫描；收尾再运行 `scripts/verify.sh`。
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
