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
- 在 `async` 测试函数里直接查库断言时，`databaseQueue.read`/`write` 的**单表达式闭包必须显式标注返回类型**，例如 `try await database.databaseQueue.read { db -> Row? in try Row.fetchOne(...) }`。GRDB 的 `read`/`write` 同时有同步与 `async` 重载，闭包省略返回类型且结果随后用可选链（`row?["col"]`）消费时，类型推断会把闭包返回值误判为 `()`，引发「`()` 没有下标」「表达式是 async 但未标 await」等编译错误，且本地无 Swift 工具链时只能靠 macOS CI 才能发现。同步测试函数里的同步 `read` 不受影响，不要盲目补 `await`。
- 用 Swift Testing 的 `#require` / `#expect` 断言 **actor 隔离属性**时，不能写 `try await #require(actor.property)`：`await` 只作用在宏调用上，宏展开后对属性的访问仍落在非隔离上下文，报「actor-isolated property 不能从 nonisolated context 引用」并附「await 无 async 操作」警告。正确做法是**先 `await` 把属性读进局部变量，再传给宏**：`let value = await actor.property; let x = try #require(value)`。同样是本机无工具链、只能靠 macOS CI 发现的并发类错误。
- 测试里**构造 SwiftUI View 或调用其属性 / 静态方法**（这些类型默认 `@MainActor` 隔离）时，承载的 `@Suite` 或 `@Test` 必须标 `@MainActor`，否则报「main actor-isolated …不能从 nonisolated context 引用」。纯字符串断言（`#expect(source.contains("XxxView("))`）不构造类型，不受影响。
- 基于 `withCheckedContinuation` 的异步 store mock **必须竞态安全**：被测 store 常在后台 task 里调用注入的 action，而测试紧接着调用 `complete()`，可能**先于** action 注册 continuation 执行。若 `complete()` 用 `guard let cont = continuation else { return }` 直接丢弃，continuation 永不 resume，配合测试里的 `while store.state == .loading { await Task.yield() }` 忙等就会**永久挂起**，并在并行模式下拖垮整个测试进程。两种修法：mock 在 `complete()` 未注册时**缓存 pending result**、`register` 时若有缓存立即返回；或测试在 `complete()` 前先 `await mock.waitForRequestCount(n)` 等待注册。注意：依赖「丢弃 stale 回调」语义的测试只能用后者。此类挂起本机无工具链不可见，且并行日志会因块缓冲难以定位，必要时用 `script -q /dev/null swift test … --no-parallel` 串行+伪终端实时输出定位。
- SwiftLint / SwiftFormat 是 CI 的**硬门禁**（`swiftlint --no-cache` 出现 error 级违规即 exit 2 失败）。由于 `scripts/verify.sh` 负载高、平时很少本地全量跑，lint 违规容易累积到 CI 才暴露。**提交体量较大的代码后，应单独轻量跑 `swiftlint --no-cache`**（比全量 verify 快很多）自查，不要等 CI。常踩的 error 级默认阈值：文件 ≤1000 行（`file_length`）、类型体 ≤350 行（`type_body_length`）、函数体 ≤100 行（`function_body_length`，按排除注释/空白计）、单行 ≤200 字符（`line_length`）；超限优先用提取辅助方法、拆类型到 `extension`/新文件、折行解决，保持行为不变，不要随意调宽 `.swiftlint.yml` 阈值。
- SwiftFormat 同理：CI 跑 `swiftformat --lint`，任何格式偏差即失败；格式漂移会和 lint 一样**长期累积到 CI 才暴露**。修复用 `swiftformat .`（去掉 `--lint`）**一键自动改写**，参数与 `scripts/verify.sh` 一致（`--exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache ignore`），秒级完成、不编译、不改逻辑。提交较大改动后连同 `swiftlint --no-cache` 一起跑一次自查。注意 runner 用 brew 最新版、本机版本可能不同会产生格式差异；必要时在 `.github/workflows/ci.yml` 固定两者版本以保证本地与 CI 一致。
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
- 2026-06-13：补充 SwiftLint/SwiftFormat 为 CI 硬门禁、应单独轻量自查及常见 error 级体量阈值的规则。原因：CI 首次跑 swiftlint 一次暴露 6 个 error 级体量超限（file/type/function/line），因 `verify.sh` 负载高平时少跑而长期累积；已逐一以等价重构（抽辅助方法、拆 `extension`/新文件、折行）修复，并沉淀阈值与自查习惯避免复发。随后 `swiftformat --lint` 又暴露 57 处跨 15 文件的历史格式漂移（同样因 `verify.sh` 少跑而累积），用 `swiftformat .` 一键自动修复，并补充 SwiftFormat 自查与版本一致性约定。影响范围：所有 Swift 代码提交。是否需要 ADR：否。
- 2026-06-13：补充测试构造 SwiftUI View 须标 `@MainActor`、以及 `withCheckedContinuation` 异步 store mock 须竞态安全两条规则。原因：首次在 macOS CI 跑通 UI 测试编译后，`PracticeRouteSeed` / `LaunchRecovery` 因构造 `@MainActor` View 报隔离错误；`ReadingDocumentStore` 解释缓存测试因 `complete()` 先于 `explain` 注册 continuation 被丢弃，叠加忙等 `while ... == .loading` 永久挂起，并行下拖垮整个 UI 测试套件、耗时 25 分钟才被发现。这些 UI 测试此前从未真正执行，问题潜伏至今。影响范围：`Packages/LangoTraceUI/Tests` 及后续所有构造 View 或注入异步 action 的测试；并促成 `.github/workflows/ci.yml` 增加 `timeout-minutes` 兜底。是否需要 ADR：否。
- 2026-06-13：补充 GRDB `async` 测试中 `read`/`write` 闭包须显式标注返回类型，以及 `#require`/`#expect` 断言 actor 隔离属性须先 `await` 入局部变量两条规则。原因：MediaArtifact / AIProvider / Diagnostic 三个 Data 测试因 `read { db in fetchOne }` 闭包省略返回类型被推断成 `()`；AI / UI 测试因 `try await #require(actor.property)` 把 `await` 错加在宏上而非属性访问上，触发 actor 隔离错误。两类都因本机无 Swift 工具链只能靠 macOS CI 暴露，需沉淀为约定避免复发。影响范围：`Packages/*/Tests` 中所有直接查库断言或断言 actor 隔离值的测试。是否需要 ADR：否。
- 2026-06-13：登记 GitHub Actions CI 为 `scripts/verify.sh` 的远程镜像门禁。原因：`.github/workflows/ci.yml` 已进入仓库并在 push / PR 跑全套验证，但 spec 与 environment 文档此前未记录远程 CI，文档落后于工程事实；同时记录 CI 模拟器目标的自动回退策略，避免 runner 镜像设备轮换导致 destination 解析失败。影响范围：`.github/workflows/ci.yml`、`scripts/verify.sh`、`docs/development/environment.md`、合并前验证流程和后续模拟器基线调整。是否需要 ADR：否，沿用本规范的本地优先验证关系。
