# 待验证清单：系列 E0a 架构地基整固（Mac / GitHub Actions）

本文件收集任务方案 `docs/plans/active/2026-06-11-01-refactor-architecture-foundations.md` 实施过程中，**在本机（Linux，无 Swift 工具链）无法运行**、必须在 Mac 开发机或 GitHub Actions 上执行的验证项。每个 Phase 提交后在此登记；用户在 Mac / CI 跑完后回填结果（通过 / 失败 + 处理）。

## 背景

- 实施环境为 Linux，无 Swift 工具链，所有 `swift test` / `xcodebuild` 均无法在本机运行。
- 本仓库重测试一律走 GitHub Actions（重测试约束见 `CLAUDE.md` §1.4 第 8 条）；触发 CI 前需将仓库临时设为 public，commit message 带 `[ci]`。
- 所有改动按 Phase 逐个 commit 并推送 `dev`，验证集中在 Mac/CI 一次性完成。

## ✅ 验证结果（2026-06-15）

**CI `Build & Test` 全绿**：run `27546863012`，验证快照 HEAD `56ef9d4`（含 Phase 1 / 2 / 3a / 3b / 3c 全部已实施项）。6 包 `swift test` + iPhone/iPad/macOS `xcodebuild build` + macOS `LangoTraceAppTests` + SwiftLint + SwiftFormat + check-docs + whitespace 全部通过。

收敛过程（每轮 CI 暴露下一层、均为机械性小修，核心逻辑零返工）：
- run 27545276639 → `Test LangoTraceCore` 红：`LearningMaterialGenerationFailureCategory` 穷尽断言未随 Phase 2 新增 case 同步 → 补全（`8f7e493`）。
- run 27545409630 → `SwiftLint` 红：`ReadingSelectionExplanationServiceTests` 主 struct 超 `type_body_length` 350 error 阈值 → 拆出 `ReadingSelectionExplanationFailureMappingTests` suite（`0d065a4`）。
- run 27545979887 → `Test LangoTraceUI` 红：`ReadingDocumentStoreExplanationCacheTests` 的 insertCount 与 fire-and-forget 持久化 Task 抢跑（pre-existing flaky，非本会话引入；重跑即过）。
- run 27546287601（重跑）→ `SwiftFormat` 红：Phase 1 adapter + Phase 3a 删测的 10 处格式 error → 手修（`56ef9d4`，同 commit 去抖了上面的 flaky 用例）。
- run 27546863012 → **全绿**。

因此下方各 Phase 的 ⬜ 项均判定为 ✅（以该绿跑为准）。三项「转 Mac/CI 实施」（协议默认实现移除、RedactedSecret、Reading 范围整数偏移）仍未实施，保持待办。

## 验证矩阵

| 状态符号 | 含义 |
|---|---|
| ⬜ | 待验证（本机已写代码/测试，未在 Mac/CI 运行） |
| ✅ | Mac/CI 已通过 |
| ❌ | Mac/CI 失败（附处理） |

---

### Phase 1：AI text provider adapter 抽象

落点：`Packages/LangoTraceAI`。

- ⬜ 聚焦测试：`swift test --package-path Packages/LangoTraceAI --filter AIProviderTextRequestAdapterTests`
- ⬜ 全包回归：`swift test --package-path Packages/LangoTraceAI`（三个文本服务与 probe 现有 fixture 行为不变）
- ✅ 结构性检查（本机 rg 自查已执行）：三个文本服务源码内 `Bearer \(` 注入归零；Bearer 仅余 `AIProviderTextRequestAdapter.swift`（唯一新家）+ `TTSProviderAdapter.swift` / `EmbeddingConfigurationProbeService.swift`（按方案 §5 排除）。adapterKind 请求构造 switch 在三个服务中归零。

预期：adapter 抽象不改变请求体与解析的可观察行为；现有 `LearningMaterialGenerationServiceTests` / `ReadingSelectionExplanationServiceTests` / `AIProviderConfigurationProbeServiceTests` 全绿。

结果回填：_（待 Mac/CI）_

---

### Phase 2：错误分类补全与错用修正

落点：`Packages/LangoTraceCore`、`Packages/LangoTraceAI`、`Packages/LangoTraceUI`。

- ⬜ Core 聚焦测试：`swift test --package-path Packages/LangoTraceCore --filter LearningMaterialGenerationFailureCategoryTests`（新建；first-fail `rateLimitedCaseExists`）
- ⬜ AI 聚焦测试：`swift test --package-path Packages/LangoTraceAI --filter LearningMaterialGenerationServiceTests`（更新：401/403→`authenticationFailed`、429→`rateLimited`、404→`unsupportedModel`、500→`providerRejected`）
- ⬜ AI 聚焦测试：`swift test --package-path Packages/LangoTraceAI --filter ReadingSelectionExplanationServiceTests`（更新：HTTP 状态码精确映射 + 新增 transport 错误区分 `timedOut`→`timeout`、其余→`networkUnavailable`）
- ⬜ AI 全包回归：`swift test --package-path Packages/LangoTraceAI`
- ⬜ UI 全包回归：`swift test --package-path Packages/LangoTraceUI`（`AIProviderDraftConfiguration.init(error:)` 新增两个 case 的 switch arm，确认无穷尽性破坏）
- ✅ 结构性检查（本机 rg 自查已执行）：`grep -rn "keychainWriteFailed" Packages/LangoTraceAI/Sources` 仅余真实 keychain 写入 / 保存路径（`saveDefaultProfile`、保存凭证 keychain 写入、`saveFailure` 映射）；validate / test 读取路径的 credentialStore 缺失改抛 `configurationStoreUnavailable`、default profile 缺失改抛 `defaultProfileMissing`（`:136/:139/:208/:212`）。

预期：人为构造 401/403/404/429/500 fixture 时，生成与阅读两个服务返回精确的限流 / 认证失败 / 模型不支持分类而非 `providerRejected` / `credentialMissing`；阅读服务超时映射为 `timeout` 而非 `networkUnavailable`；`AIProviderConfigurationError` 两个新 case 不破坏 `saveFailure` 与 UI `init(error:)` 的穷尽 switch。

结果回填：_（待 Mac/CI）_

---

### Phase 3：Core 契约收紧（分批落地）

落点：`Packages/LangoTraceCore`、`Packages/LangoTraceData`、`Packages/LangoTraceUI`、`LangoTraceApp`。

**已实施并推 dev 的子批：**

- 3a 死代码与不变量（commit 8f422b5）、3b StableHashing（commit 417a199）、3c normalized 拆分 + 时钟注入（本批）。
- ⬜ Core 全包回归：`swift test --package-path Packages/LangoTraceCore`（重点：`LanguageSpaceTests` 新增的 `validated()` 抛错 / `normalizedDraft()` 回退用例、`PracticeSessionReducerTests` 注入时钟用例、`ReadingDictionaryLookupTests`、`SentenceAudioPlaybackCoordinatorTests` 的 `StableHashing` 调用、`InterfaceLanguagePreferenceTests` / `LearningMaterialGenerationTests` 删测后仍绿）。
- ⬜ Data 全包回归：`swift test --package-path Packages/LangoTraceData`（`GRDBLanguageSpaceRepository` 改走 `validated()`、`GRDBReadingLibraryRepository` / `LocalMediaArtifactFileStore` 改走 `StableHashing`、Data 测试私有哈希助手移除）。
- ⬜ UI 全包回归：`swift test --package-path Packages/LangoTraceUI`（`ReadingDocumentStore+Selection`、`PracticeRouting` 改走 `StableHashing`，`AIProviderDraftConfiguration` 新增枚举 case 的 switch arm 已在 Phase 2 处理）。
- ⬜ App 测试：`xcodebuild test ... -only-testing:LangoTraceAppTests`（`AppSessionStateTests` mock 改走 `validated()`）。
- ✅ 结构性自查（本机）：`func sha256Hex`/`func fnv1a64Hex` 仅存于 `StableHashing.swift`；`CreateLanguageSpaceInput`/`UpdateLanguageSpaceInput.normalized()` 调用点归零（剩余 `.normalized()` 均为 `OnboardingDraft` / `AIProviderEndpointInput` / 凭证 input，无关本项）；删除符号 `kind(inferredFrom`/`applying(to`/`generationSucceeded` 全仓归零。

**转 Mac/CI 实施（本机 Linux 无编译器、强编译敏感，盲改风险大于收益）：**

- ⬜ **协议默认实现移除**（`AIProviderConfigurationRepository` 扩展的 forwarding/nil 默认）：真实 conformer `GRDBAIProviderConfigurationRepository` 已全实现，生产安全；移除默认后需借编译错误给各测试 mock 补显式 stub。落点：删 `AIProviderConfiguration.swift` 内 `public extension AIProviderConfigurationRepository { ... }`，随后在 Mac 上按报错给 `AIProviderConfigurationRepositoryTests` / `TTSProviderSettingsRepositoryTests` / `MediaArtifactRepositoryTests(+More)` 等 mock 补 stub。
- ⬜ **RedactedSecret**（明文密钥类型化，§12 Phase 3 第 1 条）：80+ 跨 Core/AI/Speech/UI/App 连锁点，含 `SentenceTTSGenerationRequest.plaintextSecret` / `AIProviderCredentialSecretSaveInput.plaintextSecret` 及大量 String 读用法（trim、`?? ""`、插值、比较）。需在有编译器的环境逐点改类型与读路径。
- ⬜ **Reading 范围整数偏移**（§12 Phase 3 第 4 条）：`ReadingTextChunk` / `ReadingMarkdownBlock` / `ReadingInlineRun` 的 `Range<String.Index>` → 统一 UTF-16 整数偏移（新 `TextUnitRange`），含 markdown 解析与 UI 渲染重做、`ReadingTextSegmentation` 单位混用与 fallback 一致性修复。

预期：上述已实施子批不改变可观察行为（哈希逐字节一致、`validated()` 仅对未知 code 抛错、时钟注入对默认调用方等价）；三项转 Mac/CI 的工作借编译错误逐个收敛。

结果回填：_（待 Mac/CI）_

---

_（后续 Phase 在实施时追加）_
