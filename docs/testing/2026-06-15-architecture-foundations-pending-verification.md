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

因此下方 Phase 1 / 2 / 3a–3c 各验证项均判定为 ✅（以该绿跑为准）。三项「转 Mac/CI 实施」（协议默认实现移除、RedactedSecret、Reading 范围整数偏移）已在 MacBook 环境完成，见下方 Phase 3-余 节。

## 验证矩阵

| 状态符号 | 含义 |
|---|---|
| ⬜ | 待验证（本机已写代码/测试，未在 Mac/CI 运行） |
| ✅ | Mac/CI 已通过 |
| ✅M | MacBook 本机六包测试已通过（CI 待验证） |
| ❌ | Mac/CI 失败（附处理） |

---

### Phase 1：AI text provider adapter 抽象

落点：`Packages/LangoTraceAI`。

- ✅ 聚焦测试：`swift test --package-path Packages/LangoTraceAI --filter AIProviderTextRequestAdapterTests`
- ✅ 全包回归：`swift test --package-path Packages/LangoTraceAI`（三个文本服务与 probe 现有 fixture 行为不变）
- ✅ 结构性检查（本机 rg 自查已执行）：三个文本服务源码内 `Bearer \(` 注入归零；Bearer 仅余 `AIProviderTextRequestAdapter.swift`（唯一新家）+ `TTSProviderAdapter.swift` / `EmbeddingConfigurationProbeService.swift`（按方案 §5 排除）。adapterKind 请求构造 switch 在三个服务中归零。

结果回填：CI run `27546863012` 全绿，HEAD `56ef9d4`。

---

### Phase 2：错误分类补全与错用修正

落点：`Packages/LangoTraceCore`、`Packages/LangoTraceAI`、`Packages/LangoTraceUI`。

- ✅ Core 聚焦测试：`swift test --package-path Packages/LangoTraceCore --filter LearningMaterialGenerationFailureCategoryTests`
- ✅ AI 聚焦测试：`swift test --package-path Packages/LangoTraceAI --filter LearningMaterialGenerationServiceTests`
- ✅ AI 聚焦测试：`swift test --package-path Packages/LangoTraceAI --filter ReadingSelectionExplanationServiceTests`
- ✅ AI 全包回归：`swift test --package-path Packages/LangoTraceAI`
- ✅ UI 全包回归：`swift test --package-path Packages/LangoTraceUI`
- ✅ 结构性检查（本机 rg 自查已执行）：`grep -rn "keychainWriteFailed" Packages/LangoTraceAI/Sources` 仅余真实 keychain 写入 / 保存路径。

结果回填：CI run `27546863012` 全绿，HEAD `56ef9d4`。

---

### Phase 3：Core 契约收紧（分批落地）

落点：`Packages/LangoTraceCore`、`Packages/LangoTraceData`、`Packages/LangoTraceUI`、`LangoTraceApp`。

**3a / 3b / 3c（CI 已验证）：**

- ✅ Core 全包回归：`swift test --package-path Packages/LangoTraceCore`
- ✅ Data 全包回归：`swift test --package-path Packages/LangoTraceData`
- ✅ UI 全包回归：`swift test --package-path Packages/LangoTraceUI`
- ✅ App 测试：`xcodebuild test ... -only-testing:LangoTraceAppTests`
- ✅ 结构性自查（本机）

结果回填：CI run `27546863012` 全绿，HEAD `56ef9d4`。

---

### Phase 3-余：协议默认实现移除 / RedactedSecret / Reading 范围整数偏移

落点：`Packages/LangoTraceCore`、`Packages/LangoTraceAI`、`Packages/LangoTraceSpeech`、`Packages/LangoTraceUI`、`LangoTraceApp`。

**MacBook 本机实施（2026-06-16），HEAD `f4e1cb7`：**

- ✅M 协议默认实现移除（commit `9820a60`）：移除 `AIProviderConfigurationRepository` 扩展中 `loadTTSSettings` / `loadTTSVoiceProfile` 的 nil 默认实现；两个 conformer 已全实现，无行为影响；转发便利方法保留。
- ✅M RedactedSecret 引入（commit `d75445f`）：新增 Core 公开 `RedactedSecret`（description/debugDescription/customMirror 固定掩码、常量时间相等、`unsafeUnwrappedValue`）；替换 `SentenceTTSGenerationRequest.plaintextSecret` / `AIProviderCredentialSecretSaveInput.plaintextSecret` / `PlayableTTSSecretResolving` 返回类型；连锁更新 Core/AI/UI/App 测试 mock。测试 11 条覆盖 description / debugDescription / Mirror / string interpolation / 常量时间比较 / 可选值描述。
- ✅M Reading 范围整数偏移（commit `efde82e`）：新增 Core 公开 `TextUnitRange`（UTF-16 code unit 偏移，含 NSRange / Range<String.Index> 互转）；替换 `ReadingTextChunk.range` / `ReadingMarkdownBlock.sourceRange` / `ReadingInlineRun.sourceRange`；修复 `segmentSentences` 单位混用（`.count` → `.utf16.count`）与 fallback 不一致（`text` → `trimmed`）；连锁更新 Data `GRDBReadingLibraryRepository`、UI `ReadingMarkdownBlockRenderer` / `ReadingDocumentStore+Selection`。测试 10 条覆盖 ASCII/emoji 转换、NSRange 互操作、边界条件。
- ✅M 本机六包测试：Core 177 / Data 138 / AI 145 / Speech 24 / UI 365 全绿。
- ✅ CI 验证：run `27595028506` 全绿（HEAD `2258e10`，含 SwiftFormat 修复）。

结构性检查（MacBook 本机 rg 自查）：
- `rg "plaintextSecret: String" Packages` → 0 命中
- `rg "Range<String.Index>" Packages/LangoTraceCore/Sources/LangoTraceCore/Reading` → 0 命中（`TextUnitRange` 已替换）
- `rg "loadTTSSettings|loadTTSVoiceProfile" Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift` → 仅保留转发便利方法（非默认实现）

---

### Phase 4：Data 层尾项

落点：`Packages/LangoTraceCore`、`Packages/LangoTraceData`、`docs/`。

**MacBook 本机实施（2026-06-16），HEAD `fb69eea`：**

- ✅M Bridge 读路径诊断事件（commit `1177594`）：三处 `try? ?? []` → `do/catch` + 诊断事件。新测试 5 条。
- ✅M 44 处枚举解码 decodeStored 替换（commit `fb69eea`）：新增 `StoredEnumDecoding.decode()` 辅助方法，8 个 GRDB 仓库逐一替换。所有仓库新增 `DiagnosticLogging`/`clock` 依赖。
- ✅M `LearningEntry.updatedAt`（commit `fb69eea`）：模型新增 `updatedAt: Date`（默认 `createdAt`），DB 列已存在，`entry(from:)` 读取该列。
- ✅M v16 迁移（commit `fb69eea`）：`reading_explanation_cache.space_id` 补 FK、`reading_import_operations.status` 补 CHECK、重建索引。
- ✅M `@MainActor` 决策（commit `fb69eea`）：改为文档注释标注 main-thread 使用意图，完整隔离推迟到 E0b。
- ✅M 软删除列决策（commit `fb69eea`）：upsert 已正确维护 `deleted_at`，非死列；软删除函数属于 E0b。
- ✅M Architecture note + spec 007 补充（commit `fb69eea`）。
- ✅M 本机六包测试：Core 177 / Data 143 / AI 145 / Speech 24 / UI 365 全绿。
- ✅ CI 验证：run `27595028506` 全绿（HEAD `2258e10`，含 SwiftFormat 修复）。

结构性检查（MacBook 本机 rg 自查）：
- `rg ') ?? \\.' Packages/LangoTraceData/Sources/ | grep rawValue` → 0 命中（44 处全部替换）
- `rg 'plaintextSecret: String' Packages` → 0 命中
- `rg 'try\\? .* ?? \\[\\]' Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift` → 0 命中

---

### Phase 5：AI/Speech 尾项

落点：`Packages/LangoTraceAI`、`Packages/LangoTraceSpeech`、`LangoTraceApp`、`docs/`。

**MacBook 本机实施（2026-06-16），HEAD `636422e`：**

- ✅M bytes(for:) 流式读取（commit `636422e`）：`URLSessionAIProviderHTTPClient.send` 改用 `bytes(for:)` + 逐字节累积，超限中断。
- ✅M AIBoundary/SpeechBoundary 统一处置（commit `636422e`）：两空标记协议 + Disabled 实现直接删除；AppEnvironment 移除对应属性。
- ✅M WAV RIFF chunk walker（commit `636422e`）：固定偏移 → 顺序 chunk 遍历，容忍扩展 fmt / LIST chunk。新 fixture + 测试。
- ✅M Keychain 伪测试替换（commit `636422e`）：3 个源码 grep 伪测试 → 行为测试 + 文档注释。
- ✅M macOS Keychain architecture note（commit `636422e`）：追加 Data Protection Keychain 迁移决策与触发条件。
- ✅M spec 012 prompt v4（commit `636422e`）：v3 → v4 更正。
- ✅M 本机六包测试：Core 177 / Data 143 / AI 143 / Speech 25 / UI 365 全绿。
- ✅ CI 验证：run `27595028506` 全绿（HEAD `2258e10`，含 SwiftFormat 修复）。

结构性检查（MacBook 本机 rg 自查）：
- `rg 'AIBoundary\|DisabledAIProvider\|SpeechBoundary\|DisabledSpeechService' Packages/` → 0 命中
- `rg 'session.data(for:' Packages/LangoTraceAI/Sources/` → 0 命中（已改为 `bytes(for:)`）
- `rg 'contentsOf: langoTraceAISourceFileURL' Packages/LangoTraceAI/Tests` → 0 命中

_（Phase 4 / 5 在实施时追加）_
