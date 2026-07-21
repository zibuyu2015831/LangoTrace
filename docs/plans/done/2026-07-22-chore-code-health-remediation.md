# 任务方案：代码健康度修复批（mockOnly 徽章漂移 / 空 catch / NSLog 泄漏 / capability 清单去重）

状态：Verified
自审核状态：Reviewed
类型：chore
创建日期：2026-07-22
最后更新日期：2026-07-22

## 用户确认记录

- 本任务在 `FABLE-MISSION.md` 授权的自主运行中执行（§2「优化已有实现」+ §4 active plan 自批授权）。不触碰核心决策、隐私边界、schema、外发类目；全部为行为修正与内部重构。

## 需求描述

独立代码健康度审查子代理（2026-07-22，全仓只读扫描）确认整体质量高（零 try!/as!/fatalError，Task 生命周期规范），但存在以下应修问题：

- **H1（用户可见误导）**：真实已落地的功能仍显示橙色 `.mockOnly` 徽章。
- **M1（可观测性缺口）**：`AppEnvironment.swift` 学习材料操作账本写入失败被 `} catch {}` 静默吞掉。
- **M2（日志隐私/一致性）**：`TTSConfigurationProbeService` 无门控 `NSLog` 打印 adapter/model/voice 与**完整 provider 错误响应体**，明文进入系统统一日志，绕过项目统一诊断通道。
- **M5（重复即漂移根因）**：`SettingsCapability` 清单在 bridge 与 InMemory mock 两处逐字重复，仅 status 有别——正是 H1 状态漂移的直接根因。
- **M4（脚本环境假设）**：`scripts/verify.sh` 写死模拟器名与 arch。
- **L3**：`SentenceAudioPlaybackAssembly.swift:112` 空 catch 属可接受（停止播放路径），缺一行说明注释。

## 现状描述（HEAD `c6b0b9e`，逐条经主会话亲自核验）

- `GRDBLearningContentRepositoryBridge.swift:225`：真实 GRDB 路径的 `interfaceLanguage` capability 标 `.mockOnly`；实际界面语言功能已完整实现并在 `LangoTraceApp.swift` 真实装配（`UserDefaultsInterfaceLanguageStore` + `InterfaceLanguageSettingsPageTests` / `InterfaceLanguageReactivityTests`）。
- `PadLearningPanelView.swift:157`：`pad.spaceSettings` 行标 `.mockOnly`，但 action 路由到真实 `settingsList`（语言空间管理已是真实 GRDB 闭环）。
- `LearningContentComponents.swift:96/103`：`MemoryLayerSummaryView` 内容/语言记忆两行在 memoryItems 非空时标 `.mockOnly`；memory deposit 闭环（E7/E8 + LM03-S3b-2 批量 deposit）已真实落地。
- `PhoneMainSupportingViews.swift:219`：`entry.rendering.localPreview` 行的 `.mockOnly` 语义正确（本地预览就是 mock 渲染，`PremiumUILayoutRules.swift:224` 也以 `rendering.isMock` 映射 `.mockOnly`），**保持不动**。
- `LearningContent.swift:216-287`（InMemory mock repo）与 bridge `:207-273` 两份清单逐字重复、仅 status 差异；`LearningContent.swift:403`（`UnavailableLearningContentRepository`）返回空数组，不参与重复。
- `AppEnvironment.swift`：`} catch {}` 共 **2 处**（`:962` recordBlockedOperation、`:981` cancelOperation；初稿写 3 处并虚构了 completeOperation，已由隔离审核证伪修正）；文件级 `generationLogger`（os.Logger，`category: "generation"`，`:12` private let）在闭包作用域可用，同文件 `:723/:741/:763/:925` 已有 `privacy: .public` 先例。cancelOperation 记录的是 `.cancelled` 操作而非失败，日志文案需区分语义。
- `TTSConfigurationProbeService.swift:123/139/165`：三处 `NSLog`，其中 `:165` 打印完整 provider 错误响应体——`spec/008` §113 明文禁止日志出现完整请求/响应体，删除属纠偏而非可选优化；`:164` 的 `let errorBody` 唯一使用点即 `:165`，删 NSLog 须连带删除该绑定，否则成死变量触发 lint。probe 结果已通过 `AIProviderProbeCapabilityResult.errorCategory` 结构化返回。Tests 对 NSLog / `LT-TTS-Probe` 零依赖。
- `scripts/verify.sh:69/72/75/78`：写死 `iPhone 17` / `iPad Pro 13-inch (M5)` / `arch=arm64`。
- 测试现状：`SettingsCapabilityTests.swift:12` 断言 **InMemory mock repo** 的 interfaceLanguage 为 `.mockOnly`（mock 语义）；**无任何测试覆盖 bridge（真实路径）的 capability status**——这是测试盲区。

## 目标、范围和不做什么

目标：真实路径不再展示误导性 mock 徽章；操作账本写入失败可观测；probe 日志不再明文外漏错误体；capability 清单单一事实源化，消除未来漂移。

范围内（六个落点）：

1. **M5+H1（Data）**：抽出单一 capability 目录 `SettingsCapabilityCatalog`——**catalog 单一持有有序 kind 清单与全部元数据**（summary/detail/nextRequirement；isReadOnly 现两侧均走默认值，抽取后保持），调用方仅注入 `Kind -> CapabilityStatus` 映射；bridge 与 InMemory 均改为调用它（既有测试钉死 9 个 kind 的精确顺序，顺序必须由 catalog 保证）；bridge 的 `interfaceLanguage` 状态改 `.ready`；InMemory mock 保持现有 status 不变（mock 语义）。
2. **H1（UI）**：`PadLearningPanelView` spaceSettings 行 `.mockOnly` → `.ready`；`MemoryLayerSummaryView` 两行非空态 `.mockOnly` → `.ready`（生产装配只走 GRDB bridge，`memory_candidates` 为真实表，InMemory 不进生产装配点）。
3. **M1（App）**：2 处 `} catch {}` 改为 `generationLogger.error(...)`，沿用 `:925` 语法先例 `\(String(describing: error), privacy: .public)`；文案区分语义（`recordBlockedOperation persist failed` / `cancelOperation persist failed`），只记录错误描述，不含用户内容（GRDB DatabaseError.description 默认不含语句参数）。
4. **M2（AI）**：删除 `TTSConfigurationProbeService` 的 3 处 `NSLog`，**连带删除 `:164` 的 `errorBody` 绑定**（信息已由结构化 probe 结果承载；不再向系统日志明文输出错误体）。
5. **L3（App）**：`SentenceAudioPlaybackAssembly.swift:112` 空 catch 上加一行英文注释说明停止路径无需上报。
6. **M4（scripts）**：`verify.sh` 目的地改为环境变量参数化，默认值与现值完全一致（`LT_IOS_SIM`、`LT_IPAD_SIM`、`LT_MAC_ARCH`），行为零变化；CI 不调用 verify.sh（已核验 `ci.yml` 独立复刻步骤且用动态模拟器解析），对 CI 零影响。
7. **文档（确定交付，非条件句）**：更新 `docs/platform-page-inventory.md:90` iPad 记忆页行——状态列「Local Mock / Unavailable」与「memory items 来自本地 mock」描述已滞后于 GRDB `memory_candidates` 真实路径（E7/E8/LM02 落地后），随本批改为真实数据来源描述，并追加清单维护日志条目。

不做什么（登记去向）：

- **M3**（InMemory mock repo 位于生产 Sources）：迁移需新建 test-support target 并改动多包 imports，超出本批克制范围；写入 `docs/architecture/notes/` 备忘录承接。
- **L1**（`@preconcurrency import` 收敛）：属 Swift 6 迁移整体工作，备忘录同上承接。
- **L2**（三端主视图布局抽共享子视图）：UI 重构量大且有 `ThreePlatformPresentationCopyTests` 文案守护兜底，暂不动。
- **L4**（App 组装层测试盲区）：`AppEnvironment` 装配分支补测属独立测试基建任务，暂不动。
- 不改 `PhoneMainSupportingViews.swift:219`（语义正确）。
- 不新增 `DiagnosticEventName` case（避免封闭枚举跨包 exhaustive switch 破坏——S3b-1/S4b 已两次验证该风险；os.Logger 已满足可观测性需求）。

## 证据与决策依据

- 代码健康度审查子代理报告（2026-07-22）+ 主会话对每一处落点的亲自读码核验（见现状描述）。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：诊断日志走统一通道、不明文外漏内容——M2 的规范依据。
- `docs/spec/003-ui-design-system.md` / `CapabilityStatus` 语义：`.mockOnly` 应仅用于真正未接后端的能力。
- 早期重构原则（`docs/README.md` §1.1/§1.2）：重复清单是漂移根因，首次修正即抽单一事实源。

## 约束映射与验证路径

- 隐私边界（决策 9/10）：本批不新增任何外发路径；M2 反而收紧日志外漏。
- TDD（§1.4）：见下方测试落点。Linux 环境无 Swift 工具链（FABLE-MISSION §5），红绿以逻辑推演 + CI 实证：新增断言在旧代码下必然失败（断言 `.ready` 而旧值为 `.mockOnly`），与修复同批提交，CI 绿即完成红→绿链路的最终验证。

## 涉及的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapabilityCatalog.swift`（新建）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/SentenceAudioPlaybackAssembly.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/TTSConfigurationProbeService.swift`
- `scripts/verify.sh`

## 参考的代码文件路径

- `Packages/LangoTraceData/Tests/LangoTraceDataTests/SettingsCapabilityTests.swift`（既有断言风格）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`（source-boundary 断言先例）
- `LangoTraceApp/AppEnvironment.swift` `emitReadFailed` / `generationLogger` 习惯

## 涉及的文档路径

- `docs/architecture/notes/2026-07-22-test-support-target-and-concurrency-cleanup-notes.md`（新建，承接 M3/L1/L4 defer）
- `docs/platform-page-inventory.md`（确定交付：`:90` iPad 记忆页行状态与数据来源描述更新 + 维护日志条目）
- `FABLE-WORKLOG.md`

## 实施方案

1. Data：新建 `SettingsCapabilityCatalog`（元数据唯一化 + status 注入），bridge / InMemory 改调用；bridge interfaceLanguage → `.ready`。
2. UI：两个视图的三处状态改 `.ready`。
3. App：三处空 catch 改 `generationLogger.error`；播放 assembly 补注释。
4. AI：删三处 `NSLog`。
5. scripts：verify.sh 目的地环境变量化（默认值不变）。
6. 新建 defer 承接备忘录；核对页面清单措辞。
7. 提交（分逻辑小步），HEAD 带 `[ci]` 推送，观察 CI。

## TDD / 测试落点

- **Data**（新文件 `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBBridgeSettingsCapabilityTests.swift`）：
  - **红测试** `bridgeReportsInterfaceLanguageAsReady`：断言 bridge 静态清单 interfaceLanguage == `.ready`（旧值 `.mockOnly`，旧代码下必红）。
  - **守护测试** `bridgeAndMockCatalogShareMetadata`：断言 bridge 与 InMemory 清单的 **kind 顺序**与 summary/detail/nextRequirement 逐项一致、**排除 status 字段**（4 个 kind 的 status 本就合理不同）。该测试在旧代码下即绿——目的是钉死单一事实源防再漂移，不是红绿测试，如实标注。
  - 既有 `SettingsCapabilityTests` / `InMemoryLearningContentRepositoryTests`（精确 kind 顺序、aiProvider `.mockOnly`、isReadOnly 全 true、count == allCases）对 mock 的断言保持不变且必须保持绿。
- **UI**（**挂进既有 `PhoneIOSConvergenceTests` 或复用其 `sourceFileURL` helper**，不再造第 26 份复制）：source-boundary 断言 `PadLearningPanelView.swift` 与 `LearningContentComponents.swift` 源码不再含 `.mockOnly` 用法（两文件中 `.mockOnly` 仅存在于待改行，无误伤；旧代码下必红）。
- **M1/M2/L3/M4 不新增单元测试**：os.Logger 输出与 NSLog 删除无公开可断言 seam，脚本默认行为零变化；剩余风险 = 回归靠 CI 全量编译 + 既有测试套（含 `TTSConfigurationProbeServiceTests` 直接测被改文件）；风险低（纯删日志 / 加日志 / 注释 / 参数化默认值）。
- 红绿说明：本环境无 Swift 工具链，红相位以「新断言在旧值下必然失败」逻辑成立（上方已逐条区分红测试与守护测试），绿相位由 CI `Build & Test` 实证。

## 验证命令

聚焦（CI 内等价步骤）：`swift test --package-path Packages/LangoTraceData`、`swift test --package-path Packages/LangoTraceUI`、`swift test --package-path Packages/LangoTraceAI`（M2 改动 AI 包，`TTSConfigurationProbeServiceTests` 直接覆盖）。
App 层改动（AppEnvironment / SentenceAudioPlaybackAssembly）无独立聚焦命令，由 CI 的三端构建 + `LangoTraceAppTests`（macOS test step）覆盖。
完整：GitHub Actions `Build & Test`（HEAD 提交带 `[ci]`），以 run conclusion=success 为准。

## 文档影响检查

- 无 schema / AI 请求路径 / 权限 / 隐私边界变化 → 不触发专项审查。
- capability 状态语义与页面事实 → 核对 `docs/platform-page-inventory.md` 相关行是否描述过 mockOnly 状态，如有随实更新。
- defer 项（M3/L1/L4）→ 新建架构备忘录承接，避免静默丢失。

## 严格方案自审核记录

```text
审核日期：2026-07-22
审核方式：隔离审查（独立 general-purpose 子代理，新上下文、只读，HEAD c6b0b9e 核验）
审核轮次：双轮合并
未使用隔离审查的原因：不适用（已使用）
发现摘要：P0=0；P1=2（① 现状描述虚构 completeOperation 闭包、空 catch 实为 2 处非 3 处；② 聚焦验证遗漏 LangoTraceAI 包）；P2=3（errorBody 死变量须连带删除、platform-page-inventory:90 记忆页行更新应为确定交付、红绿映射需区分红测试与守护测试且守护测试须排除 status 字段）；P3=5（M1 文案沿用 :925 先例并区分 blocked/cancelled、catalog 须单一持有 kind 顺序、MemoryLayerSummaryView 非空即 ready 属长期状态投影权衡、source-boundary helper 复用既有 suite、入口文档 verify.sh 描述默认值未变可不动）。
关键核验：两清单元数据逐字一致仅 4 处 status 差异且 isReadOnly 均走默认值；界面语言真实装配 + 三组测试存在；memory items 生产路径为 GRDB memory_candidates 真实表、InMemory 不进生产装配；ci.yml 不调用 verify.sh；Tests 对 NSLog 零依赖；spec/008 §113 明文禁止日志含完整响应体（M2 属纠偏）；FABLE-MISSION §4 自批授权链成立。
写回修改：现状描述改 2 处空 catch + cancel 语义、M2 补 errorBody 连带删除与 spec/008 依据；实施方案第 1 条补 catalog 持有顺序、第 3 条补文案先例、第 4 条补死变量、新增第 7 条页面清单确定交付；TDD 落点区分红测试/守护测试 + UI 断言挂进既有 suite；验证命令补 AI 包与 App 层覆盖说明；剩余风险补 MemoryLayerSummaryView 权衡。
仍需用户确认的问题：无（自批授权范围内；无核心决策 / 隐私 / schema / 外发变化）。
是否允许进入实现：是（P1 修订已全部写回本方案）。
```

## 实施记录

2026-07-22 实施完成（自主运行，FABLE-MISSION 授权）：

- 提交序列：`40643c8`（主批：catalog 抽取 + 三处 `.ready` + 空 catch 日志 + NSLog 删除 + verify.sh 参数化 + 测试 + 页面清单 + defer 备忘录）→ `4070f6f`（fix：静态清单改名 `realPathSettingsCapabilities`）→ `8cdaf6e`（fix：静态清单移出 private extension——**首轮「同名歧义」报错实为可见性问题伪装**，private extension 成员 fileprivate 对测试不可见）→ `e9c2e06`（style：声明前注释改 doc comments 过 SwiftFormat `docComments` 规则）。
- CI 证据：run 29856344239 红（测试文件编译错）→ run 29856938870 红（fileprivate 不可访问）→ run 29857721868 红（**全部测试已绿**，仅 SwiftFormat 拦截）→ **run 29858671734 `Build & Test` conclusion=success（完整绿：v33 迁移 + 三端构建 + macOS AppTests + 全包测试 + SwiftLint + SwiftFormat + check-docs）**。
- 红→绿链路：`bridgeReportsInterfaceLanguageAsReady` / `bridgeExposesNoMockOnlyCapability` / UI source-boundary 断言在旧代码逻辑红、与修复同批入库、run 29858671734 实证绿；守护测试 `bridgeAndMockCatalogShareMetadata`（顺序 + 元数据一致、排除 status）过。
- 实施期教训（写回 worklog）：① 本机无 Swift 工具链，编译期错误只能靠 CI 首轮捕获，新成员命名避开既有方法裸名；② 访问级错误可能伪装成重载歧义——测试可见性问题优先怀疑声明所在 extension 的访问级；③ 声明前注释一律 doc comments（SwiftFormat 0.62.1 `docComments` 规则）。

## 复查方法

后续会话核对：`git show e9c2e06` 前后四提交 + CI run 29858671734 结论；`GRDBBridgeSettingsCapabilityTests` 三断言与 `SettingsCapabilityCatalog` 单一事实源结构；`docs/platform-page-inventory.md` 2026-07-22 变更记录条目。

## 完成标准

- 三处用户可见 `.mockOnly` 误导消除；capability 元数据与 kind 顺序单一事实源。
- `docs/platform-page-inventory.md` 记忆页行与代码一致。
- 操作账本写入失败有日志；TTS probe 不再 NSLog 明文错误体。
- 新增测试随修复入库；CI `Build & Test` success。
- defer 项备忘录落地；plan 移入 `done/`。

## 剩余风险

- `SettingsCapabilityCatalog` 抽取若遗漏某字段差异（如 `isReadOnly`），可能改变现有 UI 行为；缓解：metadata 一致性测试 + CI 全量 UI 测试。
- 删除 NSLog 后若未来需要现场排查 TTS probe，需依赖结构化 probe 结果与诊断事件；缓解：probe 结果已含 errorCategory 与 statusCode。
- verify.sh 无法在本环境执行验证；缓解：默认值与现值逐字符一致，仅包一层变量；CI 不依赖该脚本。
- `MemoryLayerSummaryView` 非空即 `.ready` 为视图硬编码，不感知数据来源；当前生产装配只走 GRDB 故语义正确，若未来向该共享组件注入 mock 数据会误显 ready——属与 E12 SettingsStatusProjection 同类的长期状态投影问题，本批不扩大范围，记录在案。
