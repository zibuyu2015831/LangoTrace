# 项目级代码、文档与测试审查方案

状态：Done
类型：chore
创建日期：2026-05-24
最后更新日期：2026-05-24

## 1. 用户确认记录

- 2026-05-24：用户要求设定一次项目级审查计划，重点检查架构不合理或严重 bug、iOS / iPad / macOS 三端功能同步、规范文档与代码契合度、测试体系完整性，并要求考虑审查结果存放方式。
- 2026-05-24：用户要求完整阅读本方案，并根据方案规划对项目展开深入审核；本轮据此进入执行状态。
- 2026-05-24：项目级审查完成，审查 round 状态为 `Verified`，后续修复通过独立 active plan 承接。
- 当前状态：审查 round 已完成并标记为 `Verified`。

## 2. 任务描述

本任务为 LangoTrace 早期阶段的一次项目级深审准备方案。审查目标不是证明现状可接受，而是从长期付费 Apple 三端 App、文档驱动开发和基础设施长期可扩展的角度，主动找出当前代码、架构、三端实现、规范文档和测试体系中的结构性问题。

审查原则：

- 早期实现可以推倒重来；不为尚未发布的临时代码、mock 数据或未形成真实用户数据的结构背兼容包袱。
- 基础设施第一版必须为长期扩展留出正确边界；发现临时路径、局部 seam 或后续必然返工的实现，应记录为架构问题。
- `docs/` 是开发控制面；规范文档既要约束实现，也要随着更优设计持续演进。
- 暂不实现但影响后续数据、同步、AI、权限、附件、导出、StoreKit、三端架构或长期记忆的扩展提醒，应沉淀到 `docs/architecture/notes/`。

## 3. 现状描述

当前仓库已经有 SwiftUI Multiplatform App Shell、Core / Data / AI / Speech / Sync / UI package 边界、GRDB 本地存储、AI Provider 配置、TTS Provider 配置和学习材料相关实现。`docs/review/INDEX.md` 中已有多轮专项审查记录，最近一次完成审查为 `2026-05-23-one-tap-learning-material-flow`。

本方案创建时曾存在一组设置状态徽标相关并行改动；截至本方案更新时，这些并行改动已完成 commit。当前 `git status --short` 仅显示本计划文件未跟踪。

审查启动时必须重新运行 `git status --short`，并在审查 round `_meta.md` 中记录当时的工作区状态和 `git rev-parse HEAD`。

## 4. 目标

- 找出当前实现中 P0 / P1 级架构问题、严重 bug、数据安全风险、隐私边界风险和后续必然返工的基础设施问题。
- 建立 iOS、iPad、macOS 三端功能同步矩阵，明确每项能力在三端的状态：已完成、部分完成、mock、不可用、未接线、文档声明错误。
- 对照 `docs/README.md`、主参考文档、ADR、architecture、spec、testing 和 review 体系，检查文档是否准确、完整、可执行，并区分“代码应修正”和“规范应更新”。
- 对测试体系做项目级覆盖审查，明确自动化测试、手动验证、截图验证、权限验证、真实 Provider 验证和发布前验证的缺口。
- 将审查证据、问题清单、澄清问题、整改建议和后续任务拆分落盘，支持后续 AI 会话从磁盘恢复。

## 5. 范围

审查范围：

- 工程结构：`project.yml`、`scripts/verify.sh`、package 边界、App 启动结构、依赖方向、资源和本地化配置。
- Core / Data / AI / Speech / Sync / UI package 的公开模型、协议、repository、service、store、test target 和 mock / production seam。
- App 层：`LangoTraceApp`、环境注入、启动恢复、三端 scene / route / settings / commands。
- 三端 UI：iPhone、iPad、macOS 的主流程、设置入口、记录、学习材料、练习、记忆、AI Provider、TTS、同步、本地数据、隐私和导入导出状态。
- 文档：`docs/README.md`、`docs/product-main-reference.md`、`docs/technical-framework-roadmap.md`、`docs/platform-page-inventory.md`、`docs/architecture/`、`docs/architecture/notes/`、`docs/decisions/`、`docs/spec/`、`docs/testing/`、`docs/review/`、相关 active / done plan。
- 测试：Swift package tests、工具脚本 tests、`scripts/verify.sh`、手动验证清单、截图验证清单和未自动化风险记录。

## 6. 不做什么

- 本轮不直接修代码、不直接重构、不直接补测试、不直接改核心规范。
- 本轮不删除历史 review、done plan、archive 或 reference 文档。
- 本轮不把未确认的新设计写成已接受事实。
- 本轮不把过程记录改写为当前事实源；历史偏差通过新审查记录、后续 active plan 或当前事实源修正承接。
- 本轮不做真实外部 AI / TTS / 同步 / StoreKit 付费操作；若需要外部验证，应拆到后续任务并写清敏感边界。

## 7. 审查结果存放

确认本方案后，创建复杂审查 round：

```text
docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/
  README.md
  _meta.md
  reports/
    01-architecture-and-serious-bugs.md
    02-platform-parity.md
    03-docs-code-conformance.md
    04-test-system-coverage.md
    05-infrastructure-readiness.md
  evidence/
    command-logs/
    screenshots/
    manual-checks/
  questions/
    _merged.questions.md
  clarifications/
  proposals/
    remediation-roadmap.md
    follow-up-task-splits.md
  consistency_check.md
```

`README.md` 保存本轮结论摘要、范围、代码快照、P0 / P1 问题索引、文档修改记录、验证命令、剩余风险和后续任务入口。

`_meta.md` 保存审查状态表、执行者、工作区状态、当前 `HEAD`、已读文档清单、已跑命令清单、异常区和副产物索引。

`reports/` 保存只读深审报告。每份报告必须包含证据路径、代码引用、文档引用、严重度、影响、建议处理方式和是否需要后续 active plan。

`evidence/` 保存可复查证据。`command-logs/` 放命令输出摘要或完整日志链接，`screenshots/` 放 iPhone / iPad / macOS 截图，`manual-checks/` 放手动验证记录。敏感信息、API Key、Authorization header、用户正文、照片、音频、转写全文和外部 Provider 响应体不得进入该目录。

`questions/` 保存需要用户澄清的问题。跨报告重复问题合并到 `_merged.questions.md`。

`clarifications/` 保存用户确认后的答复，不直接把聊天内容当作长期事实。

`proposals/` 保存整改路线和任务拆分。只有用户确认后，才能进入代码、spec、ADR 或核心事实源修改。

`consistency_check.md` 保存跨文档术语、路径、实现状态、验证命令和决策关系的一致性检查。

审查启动和完成时更新：

- `docs/review/INDEX.md`：新增或更新本轮索引。
- 本计划文档：记录执行进度、验证结果、后续任务拆分和完成状态。

复杂 round 状态机：

```text
Draft -> In Progress -> Waiting for Clarification -> Waiting for Approval -> Updating Docs -> Consistency Check -> Verified / Deferred
```

状态规则：

- `Draft`：目录骨架已创建，但审查尚未开始。
- `In Progress`：只读审查和命令验证正在执行。
- `Waiting for Clarification`：存在会影响结论的用户澄清问题，不能把猜测写成事实。
- `Waiting for Approval`：已有整改提案，但修改核心事实源、spec、ADR 或架构文档前需要用户确认。
- `Updating Docs`：用户已确认文档修正范围，正在更新当前事实源或长期规则。
- `Consistency Check`：所有报告和提案完成，正在做跨文档、命令和状态一致性复核。
- `Verified`：本轮审查完成，必要验证已运行，剩余风险已记录。
- `Deferred`：仍有未跑验证、未澄清问题或需后续任务承接的阻断项；读取时必须查看延后项。

## 8. 严重度与问题分流

严重度：

- P0：可能导致数据丢失、隐私泄漏、敏感内容误外发、密钥落盘、启动阻断、严重崩溃、核心 ADR / 产品决策被代码破坏。
- P1：架构边界明显错误、三端核心路径不一致、规范误导后续开发、基础设施第一版会造成明显返工、测试体系无法证明关键能力。
- P2：局部实现不完整、文档状态漂移、测试覆盖不足但有替代验证、平台体验不一致但不阻断核心路径。
- P3：命名、排版、局部文案、非误导性风格问题。

分流规则：

- 明显代码 bug：新建 `docs/plans/active/YYYY-MM-DD-bug-<topic>.md`，不在审查中顺手修。
- 架构债或基础设施重做：新建 `refactor` 或 `chore` 方案；若改变核心决策，先新增或更新 ADR。
- 文档事实错误：在用户确认后修正当前事实源；历史记录保留。
- 规范过期：更新对应 `docs/spec/`，并在变更记录说明原因、影响范围和是否需要 ADR。
- 未来扩展提醒：写入 `docs/architecture/notes/YYYY-MM-DD-<topic>-notes.md`，状态为 `Draft` 或 `Accepted`。
- 测试缺口：更新 `docs/testing/` 或新建测试补充任务；不能用“后续补测”替代本轮风险记录。
- 需要用户判断的产品或架构取舍：写入 `questions/`，等待澄清，不凭空修改主参考或 ADR。

每条问题必须使用统一字段，避免报告之间口径漂移：

```text
问题 ID：
严重度：
标题：
问题现状：
证据：
影响范围：
涉及的代码文件路径：
涉及的文档路径：
复查方法：
优化方案：
影响：
所属维度：架构 / 三端同步 / 文档契合 / 测试覆盖 / 基础设施
四维切片：并发性能 / 异常边界 / 状态同步 / 数据一致性
建议处理：
后续落点：
是否阻塞继续开发：
需要用户确认：
```

字段要求：

- `问题现状`：必须描述当前代码、文档、测试或三端状态具体是什么，不能只写抽象判断。
- `影响范围`：必须说明影响的用户路径、平台、模块、数据 / 隐私 / AI / 同步 / 测试边界，以及是否影响后续基础设施扩展。
- `涉及的代码文件路径`：必须列出真实存在的文件路径；若问题只涉及文档或测试体系，应写 `无直接代码文件` 并说明原因。
- `涉及的文档路径`：必须列出需要对照或可能需要更新的文档；若无，应写 `无直接文档路径`。
- `复查方法`：必须给出可执行命令、代码搜索、手动验证步骤或截图验证方式。
- `优化方案`：必须说明推荐修复方向、替代设计或拆分任务；若需要用户确认，必须写清确认点。
- `建议处理` 和 `后续落点`：必须明确是直接更新 review 记录、创建 active plan、更新 spec / architecture / ADR / testing，还是写入 architecture note。

## 9. 阶段一：审查启动与基线固化

目标：固定审查快照和读写边界。

步骤：

1. 运行 `git status --short`，记录未提交改动和本轮不得覆盖的文件。
2. 运行 `git rev-parse HEAD`，写入 round `README.md` 和 `_meta.md`。
3. 读取 `docs/README.md`、`docs/plans/README.md`、`docs/review/README.md`、`docs/review/INDEX.md`、`docs/spec/README.md`、`docs/spec/009-testing-and-verification.md`、`docs/testing/README.md`。
4. 创建 round 目录和文件骨架。
5. 在 `_meta.md` 中建立报告状态表、文件写入权限表、命令执行表、疑问队列和异常区。
6. 更新 `docs/review/INDEX.md`，状态为 `In Progress`，可作为依据为 `No`。
7. 若使用子代理或多会话并行审查，先把每个执行者的写入范围限制到单个 `reports/*.md` 或 `evidence/*` 子目录；`README.md`、`_meta.md`、`docs/review/INDEX.md`、`proposals/` 和长期文档只允许主会话写。

阶段输出：

- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/README.md`
- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/_meta.md`
- 更新后的 `docs/review/INDEX.md`

## 10. 阶段二：架构与严重 bug 深审

目标：找出代码层和工程层 P0 / P1 问题。

检查点：

- package 依赖方向是否符合 `docs/architecture/001-initial-module-boundaries.md` 和 SwiftUI 架构规范。
- App 层是否把真实 data / AI / speech / media / diagnostics seam 注入到三端，而不是让 UI 直接持有临时 concrete repository。
- 数据库 migration、repository、Keychain、media artifact、diagnostics、TTS artifact 和 learning content 持久化是否存在事务、清理、失效、错误恢复或隐私边界漏洞。
- Provider 请求是否仍满足用户显式触发、合成 probe 不携带生活记录、敏感字段不进 SQLite / 日志 / 导出。
- UI 状态是否存在可点无反馈、并发状态错乱、取消后 stale result 覆盖、删除 fallback 错误、跨语言空间数据串线等严重 bug。
- `scripts/verify.sh`、XcodeGen、SwiftLint、SwiftFormat 和 package tests 是否真实覆盖当前工程，而不是过期命令。

建议命令：

```bash
rg -n "fatalError|try!|as!|TO[D]O|TB[D]|Button \\{ \\}|InMemoryLearningContentRepository|apiKey|Authorization|requestBody|responseBody" LangoTraceApp Packages scripts docs --glob '!docs/plans/examples/*' --glob '!docs/spec/examples/*'
rg -n "import LangoTrace(Data|AI|Speech|Sync|UI)" Packages LangoTraceApp
find Packages -path '*/.build' -prune -o -type f -print | sort
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests
```

阶段输出：

- `reports/01-architecture-and-serious-bugs.md`
- 若发现未来扩展风险，提出对应 architecture note 草案清单。

## 11. 阶段三：iOS / iPad / macOS 三端同步审查

目标：建立三端功能矩阵，明确哪些能力已同步完成、哪些只是单端或 mock。

矩阵维度：

- Welcome / Onboarding / language space recovery。
- 语言空间新增、切换、重命名、删除。
- 记录创建、记录详情、学习材料生成、重新分析、取消、编辑 derived text。
- 练习入口、练习会话、听读 / TTS 入口。
- 记忆 / Memory 入口和状态展示。
- AI Provider 设置、保存、Keychain、文本 / JSON / 语言支持 / 图片 / TTS probe。
- 同步、本地数据、隐私、导入导出、外观、界面语言、诊断日志。
- 平台原生能力：iPhone navigation、iPad sidebar / inspector / Stage Manager、macOS Settings scene / commands / shortcuts / window behavior。

建议命令：

```bash
rg -n "Phone|Pad|Mac|Settings|AIProvider|LearningContent|Practice|Memory|LanguageSpace|TTS|Sync|Export|Import" Packages/LangoTraceUI/Sources LangoTraceApp
rg -n "keyboardShortcut|commands|Settings \\{|NavigationSplitView|sheet|popover|contextMenu|hoverEffect|accessibility" Packages/LangoTraceUI/Sources LangoTraceApp
```

手动或截图验证应按 `docs/testing/README.md` 的三端页面闭环验证清单执行。若环境或时间不足，本轮必须把未执行项写入剩余风险，不能写成已验证。

阶段输出：

- `reports/02-platform-parity.md`
- 三端能力矩阵，状态值只允许使用：`Implemented`、`Partially Implemented`、`Mock Only`、`Unavailable UI`、`Not Wired`、`Doc Drift`、`Unknown`。

## 12. 阶段四：规范文档与代码契合审查

目标：检查文档是否准确、完整、可执行，并明确是修代码还是修文档。

检查点：

- `docs/README.md` 的“已完成 / 尚未完成”是否与代码和测试匹配。
- `docs/platform-page-inventory.md` 是否准确描述三端页面、入口、代码路径和能力边界。
- `docs/architecture/` 是否准确描述 package 边界、AppEnvironment、repository、provider、diagnostics、media artifact、TTS 和 learning content。
- `docs/decisions/` 是否仍与实现保持一致；如代码偏离 ADR，不能直接改 ADR 迁就代码。
- `docs/spec/` 是否覆盖当前已落地行为，是否存在过期强制规则，是否缺少新的模块实现地图。
- `docs/testing/README.md` 与 `scripts/verify.sh` 是否一致，是否把真实可运行测试和未来计划混写。
- active / done plans 是否被误用为当前事实源，是否存在已完成能力仍停留在 active 或未完成能力写成 done。
- `docs/review/INDEX.md` 中旧 round 的 `可作为依据`、`当前事实源` 和 `后续覆盖记录` 是否仍能防止历史结论被误用。
- `docs/architecture/notes/` 是否有已被正式 spec / architecture / ADR / plan 接收但未标记 `Superseded` 的备忘录，或有应创建备忘录却缺失的未来扩展提醒。

建议命令：

```bash
find docs -maxdepth 3 -type f | sort
rg -n "已完成|尚未完成|Mock|mock|不可用|disabled|TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
rg -n "LangoTrace(Core|Data|AI|Speech|Sync|UI)|AppEnvironment|scripts/verify.sh|swift test|xcodebuild|xcodegen" docs
```

阶段输出：

- `reports/03-docs-code-conformance.md`
- `consistency_check.md`
- 需要用户确认的核心文档改动写入 `questions/`。

## 13. 阶段五：测试体系完整性审查

目标：判断测试体系是否覆盖项目当前所有已实现功能点，并识别关键缺口。

检查点：

- 每个 package 是否有对应 test target；test target 是否被 `scripts/verify.sh` 覆盖。
- App target 是否有独立测试；`LangoTraceAppTests` 是否覆盖 App 装配、scene、provider wiring、playback assembly 或其他 package tests 不能覆盖的集成边界。
- 已实现模型、repository、service、store、presentation model、route helper、diagnostics、provider probe、TTS audio validator、media artifact store 是否有自动化测试。
- 三端 UI 的状态 helper、source boundary、本地化 key、platform-specific behavior 是否有可自动化测试。
- 哪些路径只能手动验证：权限弹窗、真实 Keychain 模拟器签名、真实 Provider、截图、VoiceOver、Dynamic Type、Stage Manager、macOS menu。
- 是否存在“文档要求测试，但代码没有测试”或“代码已有测试，但文档未记录入口”的双向漂移。
- 覆盖结论必须按功能点写，不以 package 测试通过替代功能覆盖。

建议命令：

```bash
find Packages LangoTraceAppTests Tests -path '*/.build' -prune -o -path '*Tests*' -type f -print | sort
rg -n "func test|@Test|XCTest|Testing" Packages LangoTraceAppTests Tests
rg -n "swift test|xcodebuild|swiftlint|swiftformat|capture-runtime-log|screencapture" scripts docs/testing docs/spec docs/plans
scripts/verify.sh
```

若 `scripts/verify.sh` 因模拟器、工具链或已有未提交改动无法运行，必须记录：

- 具体失败命令。
- 失败日志摘要。
- 是否属于环境问题、代码问题或测试体系问题。
- 剩余风险。
- 后续重跑条件。

阶段输出：

- `reports/04-test-system-coverage.md`
- 测试覆盖矩阵。
- 测试补充任务拆分建议。

## 14. 阶段六：基础设施长期可扩展性审查

目标：从“第一版基础设施要长期正确”的角度，审查已落地基础设施是否只是局部临时实现。

检查点：

- 数据层：schema、migration、repository、transaction、soft delete、current state、export / backup / cleanup、future sync tombstone。
- AI Provider：配置模型、Keychain、provider abstraction、probe、request preview、request log、prompt registry、structured output、capability flags。
- TTS / Speech：endpoint settings、voice profile、fingerprint、audio validator、preview playback seam、artifact key、future sentence playback coordinator。
- 本地媒体：file store、staging、atomic move、backup exclusion、export exclusion、metadata repository、invalidation、cleanup。
- 诊断日志：默认关闭、非敏感、ring buffer、export boundary、runtime OSLog capture。
- UI / Navigation：platform-specific composition、shared state store、routing model、settings scene、keyboard / pointer / accessibility。
- 测试基础设施：package ownership、project-level tooling tests、screenshot/manual evidence location、future integration tests。

阶段输出：

- `reports/05-infrastructure-readiness.md`
- 需要提升为 spec / architecture / ADR 的候选清单。
- 需要新增或更新 `docs/architecture/notes/` 的候选清单。

## 15. 阶段七：复核、分流与收口

目标：把审查发现变成可执行后续工作，而不是停留在报告。

步骤：

1. 合并各报告 P0 / P1 / P2 / P3 问题，去重并统一严重度。
2. 为每个 P0 / P1 问题指定处理方式：`bug plan`、`refactor plan`、`docs plan`、`spec update`、`ADR review`、`architecture note`、`user clarification`。
3. 写入 `proposals/follow-up-task-splits.md`，每项任务给出推荐顺序和阻塞关系。
4. 写入 `proposals/remediation-roadmap.md`，区分“必须先修再继续功能开发”和“可排入后续里程碑”的问题。
5. 更新 `README.md` 结论摘要。
6. 更新 `docs/review/INDEX.md` 状态。若审查完整完成且验证通过，状态为 `Verified`；若仍有用户澄清或未跑验证，状态为 `Deferred`。
7. 更新本计划的实施记录、验证命令、剩余风险和完成标准。

阶段输出：

- `proposals/remediation-roadmap.md`
- `proposals/follow-up-task-splits.md`
- 完成后的 round `README.md`
- 更新后的 `docs/review/INDEX.md`
- 更新后的本计划文档

## 16. 涉及的代码文件路径

审查可能读取但本计划不直接修改：

- `project.yml`
- `scripts/verify.sh`
- `scripts/capture-runtime-log`
- `LangoTraceApp/`
- `LangoTraceAppTests/`
- `Packages/LangoTraceCore/`
- `Packages/LangoTraceData/`
- `Packages/LangoTraceAI/`
- `Packages/LangoTraceSpeech/`
- `Packages/LangoTraceSync/`
- `Packages/LangoTraceUI/`
- `Tests/`

## 16.1 参考的代码文件路径

审查执行时必须优先抽样读取这些实现表面，避免只按文件名或文档猜测：

- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/LangoTraceApp.swift`
- `LangoTraceApp/SentenceAudioPlaybackAssembly.swift`
- `LangoTraceAppTests/SentenceAudioPlaybackAssemblyTests.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LaunchRoute.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageSpace.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/SentenceTTSGenerationService.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioFileValidator.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift`
- `Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`

## 17. 涉及的文档路径

本计划创建：

- `docs/plans/active/2026-05-24-chore-project-wide-code-doc-test-audit.md`

审查执行时创建或修改：

- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/`
- `docs/review/INDEX.md`
- 本计划文档的实施记录和状态

审查执行时读取：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/platform-page-inventory.md`
- `docs/_meta/documentation-system.md`
- `docs/architecture/`
- `docs/architecture/notes/`
- `docs/decisions/`
- `docs/spec/`
- `docs/testing/`
- `docs/release/`
- `docs/review/`
- `docs/plans/active/`
- `docs/plans/done/`

## 18. 验证命令

本计划创建后的文档级验证：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

审查执行阶段按各阶段命令追加验证。若审查产生代码或规范修复任务，修复任务必须另建 active plan，并按对应 package 运行聚焦测试和 `scripts/verify.sh`。

审查命令失败时的归因规则：

- Swift 编译、测试断言、lint、format 或占位扫描失败：优先记录为代码 / 文档 / 测试体系问题。
- 模拟器不可用、DerivedData / SwiftPM cache 权限、Xcode toolchain 缺失或网络依赖不可达：记录为环境问题，并写明重跑条件。
- 命令本身引用了不存在的 scheme、target、simulator 或路径：记录为验证脚本或测试文档问题。
- 因并行未提交改动导致结果不可解释：停止结论升级，记录 dirty worktree，等待用户确认是否先收口并行改动。

本轮审查不要求所有手动验证都在同一会话完成，但每个跳过项必须写入 `README.md` 的延后项和 `reports/04-test-system-coverage.md` 的覆盖矩阵。

## 19. 文档影响检查

本计划本身改变的是任务方案层，不改变当前事实源、ADR、spec 或 review 机制。

确认并执行审查后，必然影响：

- `docs/review/INDEX.md`：新增项目级审查轮次。
- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/`：新增复杂审查记录。

可能影响：

- `docs/README.md`、`docs/platform-page-inventory.md`、`docs/spec/`、`docs/testing/README.md`、`docs/architecture/`、`docs/decisions/`。

这些长期文档只有在审查发现明确问题并经用户确认后才修改。审查发现代码问题时，默认新建后续 `bug` / `refactor` / `chore` 方案，不在审查过程中顺手修。

## 19.1 复查方法

本方案确认前复查：

- 对照 `docs/plans/README.md` 检查必填章节是否齐全。
- 对照 `docs/review/README.md` 检查复杂 round 目录、状态机、写入权限和验收方式是否一致。
- 对照 `scripts/verify.sh` 检查审查命令是否覆盖当前真实验证入口。
- 对照当前代码树检查计划中的路径是否存在，且没有把 `.build`、DerivedData 或历史归档误当成审查对象。

审查执行完成前复查：

- 随机抽取一个 P0 / P1 发现，从 evidence 到 report、proposal、follow-up plan 或 question 做闭环追踪。
- 随机抽取一个三端能力，从代码入口、三端 UI 状态、文档事实和测试覆盖矩阵做闭环追踪。
- 随机抽取一个长期规范，确认它没有与当前代码、ADR 或产品主参考冲突。
- 随机抽取一个测试命令，确认命令在 `scripts/verify.sh`、`docs/testing/README.md`、审查报告和本计划中的口径一致。

## 19.2 证据与决策依据

本方案依据：

- `docs/README.md`：项目入口、核心决策和完成前检查。
- `docs/plans/README.md`：active plan 必填字段、生命周期和使用规则。
- `docs/review/README.md`：复杂审查 round 结构、状态机、写入权限、问题分流和验收方式。
- `docs/review/INDEX.md`：既有审查轮次、当前事实源和历史依据状态。
- `docs/spec/009-testing-and-verification.md`：任务类型到验证入口、统一门禁和验证结果写回规则。
- `docs/testing/README.md`：自动化测试组织、运行时日志、截图验证和三端页面闭环验证清单。
- `scripts/verify.sh`：当前 Swift 工程收尾门禁，包含 Swift package tests、iOS / iPad / macOS build、macOS App target tests、lint、format、占位扫描和 git 状态检查。
- 当前代码树：`LangoTraceApp/`、`LangoTraceAppTests/`、`Packages/*/Sources`、`Packages/*/Tests` 和 `Tests/Tooling/`。

## 20. 实施记录

- 2026-05-24：创建项目级审查方案草案。
- 2026-05-24：启动审查，记录基线 `HEAD` 为 `0c57e030dca477b1854df41e21d470176a020191`，启动时 `git status --short` 仅显示本计划文件未跟踪；创建 `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/` 复杂 round 骨架，并更新 `docs/review/INDEX.md` 为 `In Progress`。
- 2026-05-24：完成项目级深审并将 round 标记为 `Verified`。本轮未发现 P0；记录 P1 / P2 问题 9 项，创建两个 P1 bug active plan：`2026-05-24-bug-learning-content-store-language-space-switch.md` 和 `2026-05-24-bug-learning-material-cancel-provider-request.md`。验证结果：Core / Data / AI / Speech / UI package tests、macOS AppTests、Python tooling tests 和 `scripts/verify.sh` 已运行；Sync package 直接测试暴露 `no tests found`。

## 21. 完成标准

本计划完成需满足：

- 用户确认审查方案。
- 审查 round 目录创建完成，审查范围、快照和状态记录完整。
- 五份核心报告完成：架构与严重 bug、三端同步、文档代码契合、测试覆盖、基础设施可扩展性。
- 所有问题均按统一字段记录问题现状、影响范围、涉及的代码文件路径、涉及的文档路径、复查方法、优化方案、建议处理方式和后续落点；P0 / P1 问题不得缺字段。
- 需要用户澄清的问题已归并到 `questions/`，且不被伪装成长期事实。
- 后续整改任务拆分完成，并明确哪些需要 active plan、architecture note、spec、ADR 或 testing 文档。
- 文档级检查通过，或失败项被写入剩余风险。
- `docs/review/INDEX.md` 和本计划文档更新到最终状态。

## 22. 剩余风险

- 项目级审查范围大，单次会话可能无法完成全部手动验证；未执行的截图、真机、VoiceOver、Dynamic Type、Stage Manager、真实 Provider 或 StoreKit 验证必须明确写入剩余风险。
- 本方案创建期间曾有并行任务改动，现已提交；审查启动前仍必须重新确认 `git status --short`，避免后续新改动被误判为本轮审查结果。
- 自动化测试通过不等于功能覆盖完整；本轮必须按功能矩阵判断测试缺口。
- 若审查发现核心 ADR 冲突，不能直接按代码现状修文档，需要进入用户确认和 ADR 复审流程。
