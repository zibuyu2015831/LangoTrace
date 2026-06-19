# 01 架构与严重 Bug 深审

状态：Verified

## 1. 审查目标

找出代码层和工程层 P0 / P1 问题，包括架构边界错误、严重 bug、数据安全风险、隐私边界风险和后续必然返工的基础设施问题。

## 2. 已执行证据

- `git rev-parse HEAD`：`0c57e030dca477b1854df41e21d470176a020191`。
- `swift test --package-path Packages/LangoTraceCore`：通过，76 tests。
- `swift test --package-path Packages/LangoTraceData`：通过，77 tests。
- `swift test --package-path Packages/LangoTraceAI`：通过，74 tests。
- `swift test --package-path Packages/LangoTraceSpeech`：通过，13 tests。
- `swift test --package-path Packages/LangoTraceUI`：通过，216 tests。
- `xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests`：通过，2 tests。
- `Packages/LangoTraceSync/Package.swift:20-27` 只有 library target，没有 test target。
- `Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift:1-5` 只有 `SyncService` 协议和 `DisabledSyncService`。
- `scripts/verify.sh:8-16` 覆盖 Core / Data / AI / Speech / UI package tests 和 macOS AppTests，但没有 `swift test --package-path Packages/LangoTraceSync`。
- `swift test --package-path Packages/LangoTraceSync` 能编译 `LangoTraceSync`，但以 `error: no tests found; create a target in the 'Tests' directory` 退出。

## 3. 问题清单

### AUDIT-ARCH-004

问题 ID：AUDIT-ARCH-004
严重度：P1
标题：学习材料生成 / 分析的“取消”没有取消实际 Provider 请求，可能继续发送敏感内容并消耗额度
问题现状：`LearningContentStore` 在 `generateLearningMaterial` 和 `analyzeCurrentLearningText` 中直接 `await generationActions.generateMaterial` / `analyzeCurrentText`，只保存 operation metadata，没有保存可取消的 `Task` handle。`cancelLearningMaterialGeneration` 只清空 `runningOperationsByEntryID`、把 UI 状态改为 cancelled，并调用 `generationActions.cancelOperation` 记录取消；它不会取消已经启动的 async provider request。现有测试也明确只验证“late result discarded”，没有验证 HTTP 请求被取消。
证据：`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift:167-186` 创建 operation 并 await generation action；`LearningContentStore.swift:251-266` 对 analysis 同样 await action；`LearningContentStore.swift:288-302` cancel path 只更新状态和记录 operation；`Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift:178-206` 测试名为“discards late result”，测试实现通过 gate 释放晚到结果，断言结果被丢弃和 cancelOperation 被调用，但没有断言实际任务取消；`LangoTraceApp/AppEnvironment.swift:196-215`、`317-336` 真实 action 会 resolve secret 并调用 `LearningMaterialGenerationService.generate/analyze` 发送 provider 请求。
影响范围：真实 AI Provider 接入后的文本学习材料生成、当前学习文本分析、诊断 operation 语义、用户隐私预期和 Provider 额度。用户在请求预览后点击取消，UI 会显示取消，但原始生活记录或学习文本可能仍继续在网络请求中处理，且 Provider 可能扣费；如果请求成功，结果会被 UI 丢弃，但外部副作用已经发生。
涉及的代码文件路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`、`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`、`LangoTraceApp/AppEnvironment.swift`、`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`
涉及的文档路径：`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`、`docs/spec/009-testing-and-verification.md`
复查方法：新增失败测试，使用可挂起 generation action 或 fake HTTP client，点击 cancel 后证明底层 task 被取消且不会继续执行 provider send / persistence；再补真实 service cancellation 映射测试，确保 `Task` cancellation 进入 `.cancelled` 而不是 `.unknown` / `.networkUnavailable`。
优化方案：新建 P1 bug active plan。修复方向应让 UI 层或 action 层持有 per-entry operation task，cancel 时真正 `Task.cancel()`，并让 action / service 在取消路径记录 `.cancelled` operation；同时确认取消时不再 resolve secret、发送 HTTP、保存 material 或覆写 generation state。
影响：修复后，“用户明确触发 AI 能力”和“用户取消请求”的隐私语义才闭合；否则真实 Provider 生成链路不能宣称支持可靠取消。
所属维度：架构 / AI 隐私 / 并发取消 / 异常边界
四维切片：并发性能 / 异常边界 / 状态同步
建议处理：新建 `bug` active plan，不在本轮审查中顺手修代码。
后续落点：`docs/plans/active/YYYY-MM-DD-bug-learning-material-cancel-provider-request.md`
是否阻塞继续开发：阻塞真实 AI Provider 学习材料生成 / 分析链路的完成声明；不阻塞本地 mock UI。
需要用户确认：否，属于代码事实和 AI 隐私边界 bug；执行修复前仍按项目规则创建 active plan。

### AUDIT-ARCH-003

问题 ID：AUDIT-ARCH-003
严重度：P1
标题：语言空间切换后 `LearningContentStore` 可能保持旧 `spaceID`，造成三端内容串线和错误 AI/TTS 上下文
问题现状：`PlatformMainView` 用 `@StateObject private var contentStore` 持有 `LearningContentStore`，并在 init 时用当前 `languageSpace.id` 创建 store。`LearningContentStore.spaceID` 是私有常量。`LangoTraceRootView` 传入新的 `languageSpace` 时，`PlatformMainView` 处于同一结构位置，代码没有 `.id(languageSpace.id)`、`onChange` 重建 store、或 store 内部切换空间的方法。基于 SwiftUI `StateObject` 生命周期推断，切换语言空间后 content store 可能继续读写旧空间 entries，而页面 header 和 AI/TTS 上下文已经显示新空间。
证据：`Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift:146-159` 定义 `PlatformMainView` 和 `@StateObject contentStore`；`LangoTraceRootView.swift:188-195` 只在 init 中创建 `LearningContentStore(spaceID: languageSpace.id)`；`LangoTraceRootView.swift:201-233` 把同一个 `contentStore` 传给 iPad / iPhone / macOS 平台视图；`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift:8-10` 把 `spaceID` 存为私有常量；`LearningContentStore.swift:42-53`、`56+` 后续 select/create/generate 均使用这个固定 `spaceID`；当前 UI 测试搜索未发现覆盖 root 层语言空间切换时 content store 重建或换绑。
影响范围：iPhone、iPad、macOS 的记录列表、记录创建、记录详情、学习材料生成、逐句 TTS 和练习 / 记忆展示。用户切换到日语空间后可能仍看到英语空间记录；更严重的是共享 `EntryDetailView` 若拿旧 entry 配新 `LanguageSpacePreview`，生成学习材料可能把旧空间 entry 文本按新空间目标语言上下文发送给 Provider，并把结果写入旧 entry 或造成 UI 状态错配。
涉及的代码文件路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`、`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`、`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`、`Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`、`Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
涉及的文档路径：`docs/spec/004-swiftui-architecture.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/platform-page-inventory.md`
复查方法：增加 UI package 单元测试或 root-level source-boundary test，证明 `PlatformMainView` 在 `languageSpace.id` 变化时重建 `LearningContentStore`，或将 `LearningContentStore` 改为支持显式 `switchSpace` 并清空 entries、selectedEntry、memoryItems、generationStates、running operations、sentence audio playback states。手动验证：创建两个语言空间，在 A 空间创建记录，切到 B 空间后记录列表不显示 A 空间记录，新建记录写入 B 空间。
优化方案：推荐优先创建 bug active plan。低风险修复路径是给 `PlatformMainView` 或其调用处加 `.id(languageSpace.id)`，让 `@StateObject` 随空间身份重建；更长期方案是让 store 提供显式空间切换 API，并在切换时取消运行中的 generation / playback observation、清空派生 UI 状态、重新加载目标空间。修复必须先写失败测试。
影响：修复后，语言空间作为核心信息模型的隔离边界才可信；否则三端“多语言空间管理已完成”的声明需要降级。
所属维度：架构 / 三端同步 / 数据一致性 / 基础设施
四维切片：状态同步 / 数据一致性 / 并发性能 / 异常边界
建议处理：新建 `bug` active plan，不在本轮审查中顺手修代码。
后续落点：`docs/plans/active/YYYY-MM-DD-bug-learning-content-store-language-space-switch.md`
是否阻塞继续开发：阻塞任何依赖多语言空间隔离的真实学习内容、AI 请求、TTS 播放和同步开发完成声明。
需要用户确认：否，属于代码事实和核心模型隔离 bug；执行修复前仍按项目规则创建 active plan。

### AUDIT-ARCH-001

问题 ID：AUDIT-ARCH-001
严重度：P1
标题：Sync package 已进入 App 装配和长期边界，但没有测试 target，也不在统一验证脚本中运行
问题现状：`LangoTraceSync` 已作为 App target 和 `LangoTraceAppTests` 的依赖进入工程图，但 package 自身只有 source target 和 disabled service，没有 SwiftPM test target；`scripts/verify.sh` 没有运行 Sync package 测试。
证据：`project.yml:13-24` 注册 `LangoTraceSync` package，`project.yml:65-66`、`project.yml:97-98` 和 `project.yml:122-123` 将它接入 iOS、macOS 和 AppTests；`Packages/LangoTraceSync/Package.swift:20-27` 只有 `.target`；`Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift:1-5` 只有边界占位；`scripts/verify.sh:8-16` 未包含 `swift test --package-path Packages/LangoTraceSync`；本轮直接运行 `swift test --package-path Packages/LangoTraceSync`，源码编译完成后以 `error: no tests found; create a target in the 'Tests' directory` 退出。
影响范围：同步模块、未来 Sync Engine / Adapter / 冲突模型、统一验证门禁和文档中“Core / Data / AI / Speech / Sync / UI package 边界”的可信度。当前还没有真实同步实现，所以不是 P0；但一旦开始同步任务，缺测试 target 会让协议、状态枚举和 disabled boundary 演进没有最小回归落点。
涉及的代码文件路径：`Packages/LangoTraceSync/Package.swift`、`Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift`、`scripts/verify.sh`、`project.yml`
涉及的文档路径：`docs/README.md`、`docs/architecture/001-initial-module-boundaries.md`、`docs/spec/009-testing-and-verification.md`、`docs/testing/README.md`
复查方法：运行 `swift test --package-path Packages/LangoTraceSync`；检查 `Packages/LangoTraceSync/Package.swift` 是否存在 `.testTarget`；检查 `scripts/verify.sh` 是否包含 Sync package 测试。
优化方案：新建后续 `chore` 或 `refactor` active plan，为 Sync package 增加最小 `LangoTraceSyncTests` target，先覆盖 `DisabledSyncService`、未来同步状态枚举和 adapter 协议的 stable contract，再把 `swift test --package-path Packages/LangoTraceSync` 加入 `scripts/verify.sh` 和测试文档。
影响：补齐后，后续同步基础设施可以在 package 内 TDD 起步，而不是等真实 Sync Engine 出现后才建立测试边界。
所属维度：架构 / 测试覆盖 / 基础设施
四维切片：状态同步 / 数据一致性
建议处理：创建 `chore` active plan；不在本轮审查中直接改代码。
后续落点：`docs/plans/active/YYYY-MM-DD-chore-sync-package-test-boundary.md`
是否阻塞继续开发：不阻塞非同步功能；阻塞真实 Sync Engine / Adapter 开发前的基础设施完备性。
需要用户确认：否，属于测试基础设施补齐；执行前仍需按项目规则创建 active plan。

## 4. 修复后覆盖记录

- `AUDIT-ARCH-004`：已由 `docs/plans/done/2026-05-24-bug-learning-material-cancel-provider-request.md` 修复。`LearningContentStore` 现在持有运行中生成 / 分析 task，取消时调用 `Task.cancel()`；新增生成和分析取消传播测试，并让 GRDB operation summary 中 `cancelled` 保持终态。验证：`swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreCancellationTests`、`swift test --package-path Packages/LangoTraceData --filter operationSummariesKeepCancelledAsTerminalStatus`、`scripts/verify.sh` 均通过。
- `AUDIT-ARCH-003`：已由 `docs/plans/done/2026-05-24-bug-learning-content-store-language-space-switch.md` 修复。Root 层 `PlatformMainView` 调用显式绑定 `.id(languageSpace.id)`，让 `@StateObject` content store 随语言空间 identity 重建；新增源码约束测试。验证：`swift test --package-path Packages/LangoTraceUI --filter LanguageSpaceContentStoreBindingTests`、`scripts/verify.sh` 均通过。
- `AUDIT-ARCH-001`：已由 `docs/plans/done/2026-05-24-chore-project-wide-audit-remediation.md` 完成基础整改。Sync package 新增 `LangoTraceSyncTests` test target 和 disabled boundary test，`scripts/verify.sh` 已纳入 `swift test --package-path Packages/LangoTraceSync`。真实 Sync domain model 仍由 `AUDIT-INFRA-001` 保留为同步前置风险。
- `AUDIT-ARCH-002`：已由 `docs/plans/done/2026-05-24-chore-project-wide-audit-remediation.md` 补最小 AppEnvironment bootstrap tests，覆盖生产 learning content repository boundary 与 AI / Speech / Sync disabled service boundary。验证：`xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests` 通过，4 tests。

### AUDIT-ARCH-002

问题 ID：AUDIT-ARCH-002
严重度：P1
标题：App 层集成测试覆盖面过窄，无法证明当前 AppEnvironment 装配图
问题现状：`LangoTraceAppTests` 当前只有 `SentenceAudioPlaybackAssemblyTests` 两个测试，证明 TTS playback coordinator assembly 和 action stream 初始状态，但没有覆盖 `AppEnvironment.bootstrap()` 的核心装配：语言空间 repository、learning content repository、AI Provider settings actions、diagnostic logger、disabled Sync / Speech service、Settings scene 与 root 注入一致性。
证据：`LangoTraceAppTests/SentenceAudioPlaybackAssemblyTests.swift:8-42` 只有两个测试；本轮 `xcodebuild test -scheme LangoTrace-macOS ... -only-testing:LangoTraceAppTests` 输出 2 tests passed；`LangoTraceApp/AppEnvironment.swift:23-147` 组装了 database factory、Keychain store、diagnostic logger、learning content repository、AI Provider settings actions、learning material generation actions、sentence audio playback actions、disabled AI / Speech / Sync service。
影响范围：App Shell、依赖注入、三端 scene、AI / Data / Speech / Sync 装配、未来真实 Provider / Sync / StoreKit 接入。Package tests 已经很强，但它们不能证明 App 层把真实实现、disabled implementation 和 UI action seam 正确接在一起。
涉及的代码文件路径：`LangoTraceApp/AppEnvironment.swift`、`LangoTraceApp/LangoTraceApp.swift`、`LangoTraceAppTests/SentenceAudioPlaybackAssemblyTests.swift`、`project.yml`
涉及的文档路径：`docs/spec/004-swiftui-architecture.md`、`docs/spec/009-testing-and-verification.md`、`docs/testing/README.md`
复查方法：统计 `LangoTraceAppTests` 测试文件；运行 `xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests`；对照 `AppEnvironment.bootstrap()` 的字段逐项查看是否有测试。
优化方案：新建后续 `chore` active plan，补 App target integration tests：验证 bootstrap 不回退到 `InMemoryLearningContentRepository`、learning repository unavailable 时 UI 能得到明确 unavailable boundary、AI Provider actions 使用同一 service factory、Settings scene 与 root 注入同一 action seam、disabled Sync / Speech 不产生副作用。
影响：降低后续跨 package 装配漂移风险，尤其是真实 Sync、导出、StoreKit 和权限能力进入 App 层时。
所属维度：架构 / 测试覆盖 / 基础设施
四维切片：异常边界 / 状态同步
建议处理：创建 `chore` active plan；不在本轮审查中直接改代码。
后续落点：`docs/plans/active/YYYY-MM-DD-chore-app-environment-integration-tests.md`
是否阻塞继续开发：不阻塞当前 UI / package 内功能；阻塞高风险 App Shell 装配变化的完成声明。
需要用户确认：否，属于测试基础设施补齐；执行前仍需按项目规则创建 active plan。
