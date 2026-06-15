# 任务方案：Core / Data / AI / Speech 架构地基整固（系列 E0a）

状态：Draft
自审核状态：Reviewed
类型：refactor
创建日期：2026-06-11
最后更新日期：2026-06-15（隔离子代理实现前复核，基线漂移与三项事实校正写回，见 §13 第二条记录）

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）。该授权仅覆盖"系列方案文档的制定"，不覆盖本方案的实现。进入生产代码实现前，必须由用户单独确认本方案，并将状态推进为 `User Approved`。

- 2026-06-15：实现前隔离复核完成（见 §13 第二条记录），3 个 P1 已在方案内校正。用户**预先确认 3 项实现决策默认**：①软删除列＝保留列 + 修正写路径（非删列）；②RedactedSecret 公开 API 连锁破坏一次性完成；③StableHashing 采纳 Core 公开共享工具。这 3 项不再是待决项。
- 2026-06-15：用户选择**先自行复核本方案，暂未授权实现**。`状态` 保持 `Draft`；待用户复核后明确推进至 `User Approved` 方可进入生产代码实现。

## 1. 需求或 bug 描述

2026-06-11 全量代码审查（隔离子代理审查 + 主会话核验，修复 commit 71bfc01..274b7db）已修复 P0 / P1 发现，但留下一批被明确延后的 P2 架构债：AI 文本请求路径重复、错误分类不完整、数据层读取吞错、明文密钥裸露在普通 String 字段、Core 公开 API 不变量可破坏、Data 枚举解码静默回退、Speech WAV 解析过于僵硬等。这些问题分布在 Core / Data / AI / Speech 四层，都是后续功能方案（E1 时间线、E2 照片、E3+ 听写 / 回译 / 记忆）会直接踩到的接缝。

本方案把这些延后项收敛为一个有序重构，作为系列方案的第一个实施项（E0a），让后续功能在干净的契约上落地，而不是在每个功能方案里重复绕开同一批债。

## 2. 现状描述

以下现状原按 HEAD `274b7db` 核验。**2026-06-15 复核校正（基线漂移）**：当前 HEAD 已较 `274b7db` 前进 48 个 commit，其中 `83f4ef1`（swiftformat 全仓格式化）与 `483bfe9`（SwiftLint 体量重构）改动了本节点名的多个 AI 服务文件，导致 §2.1 / §2.2 的部分**行号已漂移**（例如 `LearningMaterialGenerationService` 的 Bearer 注入已从 `:154-208` 区间移到 `:176`）。因此：本节所有行号应作为**符号锚点**理解（按函数名 / 符号定位，而非绝对行号），实现开始前以当时 HEAD 重新取证；底层技术事实（重复、缺口、错用、裸 String 等）经复核**仍成立**。错用点 `AIProviderConfigurationProbeService.swift:567`、`AIProviderConfigurationService.swift:136,139` 经复核行号仍精确命中。

1. AI 文本请求路径：`LearningMaterialGenerationService`、`ReadingSelectionExplanationService`、`AIProviderConfigurationProbeService` 已共享今日抽取的 `AIProviderEndpointURLBuilder`、`AIProviderHTTPStatusErrorMapper`、`OpenAICompatibleResponseTextParser`，但 makeRequest 构造、`"Bearer \(secret)"` auth header 注入、chat / responses 的 provider kind dispatch switch 仍在三个服务里各写一遍（`LearningMaterialGenerationService.swift:154-208`、`ReadingSelectionExplanationService.swift:195-263`、`AIProviderConfigurationProbeService.swift:137-147, 460-511`）。`AIProviderAdapterKind` 已含 `anthropicMessages` / `geminiGenerateContent` case（Core `AIProviderConfiguration.swift:48-52`），但三处服务都各自 throw `unsupportedProvider`。
2. 错误分类：Core `LearningMaterialGenerationFailureCategory`（`LearningMaterialGenerationModels.swift:33-48`）缺 `rateLimited` / `authenticationFailed`；`ReadingSelectionExplanationFailureCategory`（`ReadingAIExplanation.swift:86-93`）只有 6 个 case，缺 timeout / 认证失败 / unsupportedModel；`AIProviderConfigurationError` 被错用：`AIProviderConfigurationProbeService.swift:567` 对 JSON 反序列化失败 throw `missingRequiredEndpointField`，`AIProviderConfigurationService.swift:136,139` 对 credentialStore 缺失 throw `keychainWriteFailed`、对 profile 缺失 throw `missingRequiredEndpointField`。
3. 数据层读取吞错：`GRDBLearningContentRepositoryBridge.swift:15,73,77` 用 `(try? ...) ?? []` 吞掉 entries / practiceItems / memoryItems 的 DB 读取错误，无诊断事件。
4. 明文密钥：`SentenceTTSGenerationRequest.plaintextSecret: String?`（`SentenceTTSGeneration.swift:7`）和 `AIProviderCredentialSecretSaveInput.plaintextSecret: String`（`AIProviderConfiguration.swift:440`）是普通 String，会进入默认 `description` / reflection / 调试输出；Core 中不存在任何 Redacted 包装类型。
5. Core 公开契约问题：
   - `CreateLanguageSpaceInput.normalized()` 声明 `throws` 但实际永不抛错，且经 `OnboardingDraft.normalized()`（`OnboardingDraft.swift:28-44`）把未知语言 code 静默重置为 zh-Hans → en（`LanguageSpace.swift:78-94`）。
   - `TTSVoiceProfile.configurationFingerprint` 是公开可变存储属性（`TTSProviderConfiguration.swift:150`），指纹不变量可被外部破坏；`AIProviderEndpointConfiguration.configurationFingerprint` 已是计算属性（安全）。
   - `ReadingTextChunk.range: Range<String.Index>`（`ReadingTextSegmentation.swift:9`）、`ReadingMarkdownBlock.sourceRange` / `ReadingInlineRun.sourceRange`（`ReadingMarkdown.swift:18,35`）把 `Range<String.Index>` 放进公开 Sendable 模型；同文件 `ReadingTextSegmentation.swift:247-260` 把 NSRange（UTF-16 单位）与 `String.count`（Character 单位）混合相加。
   - `PracticeSessionReducer.swift:99` 与 `SentenceAudioPlaybackCoordinator.swift:166,281,298` 直接调用 `Date()`，无可注入时钟。
   - sha256 hex 辅助函数当前至少 **8** 处重复实现（2026-06-15 复核：7→8，UI 包为 **2** 处）：Core `PracticeRecordingArtifact.swift`、`TTSAudioArtifact.swift`、`SentenceAudioPlaybackCoordinator.swift`、`ReadingTextSegmentation.swift`；Data `GRDBReadingLibraryRepository.swift`、`LocalMediaArtifactFileStore.swift`；UI `PracticeRouting.swift` **和 `ReadingDocumentStore+Selection.swift`（原方案漏列）**；FNV-1a 实现 1 处（`AIProviderConfiguration.swift`）。**因 UI 已有 2 个消费方，StableHashing 倾向 Core 公开（§12 Phase 3 step 6 / §13 P3 的「UI 仅 1 处可局部收敛」前提已失效）。**`AIProviderConfigurationRepository` 协议扩展提供返回 nil 的默认实现（`AIProviderConfiguration.swift:668-702`），会掩盖 conformance 漏实现。
   - 死代码与不变量杂项：`AIProviderCustomHeaderConfiguration` 无公开 init、不可在包外构造（`AIProviderConfiguration.swift:581-590`）；`LearningMaterialInputKind.kind(inferredFrom:)` 恒返回 nil（`LearningMaterialGenerationModels.swift:16-18`）；`InterfaceLanguagePreference.applying(to:)` 是恒等函数；`SentenceAudioPlayback.swift:212` 的 `.generationSucceeded` 转移从未被发出；`LanguageSpacePreview.swift:10-45` 两个 init 重复；`ReadingLibrarySearchQuery.normalized` 是公开可变 var（`ReadingSearch.swift`）；`ReadingDictionaryLookup` 的 `normalizedHeadword` 由调用方自报、不由 headword 计算（`ReadingDictionaryLookup.swift:5-14`）；`segmentSentences` 主路径用 trimmed 文本而 fallback 用原始 `text`（`ReadingTextSegmentation.swift:278-296`）；`PhoneRootTab` 未显式声明 `Sendable`（`PhoneRootTab.swift:1`）。
6. Data 层尾项：
   - 枚举解码静默回退 `Enum(rawValue:) ?? .default` 实际有约 44 处（多于审查记录的约 20 处），代表性位置 `GRDBDiagnosticEventRepository.swift:129-131`、`GRDBMediaArtifactRepository.swift:637-649`、`GRDBTTSProviderSettingsRepository.swift:66,210,214,224`、`GRDBReadingLibraryRepository.swift:150,162,167,504`。
   - `LearningEntry` 无 `updatedAt`（`LearningContentModels.swift:4-37`，仅 `createdAt`）。
   - AI provider 配置相关表带 `deleted_at` 软删除列（`AppDatabase.swift:146,173,205`），但写入路径为 replace-all，软删除列实际是死列。
   - `reading_explanation_cache.space_id` 无 FK（`AppDatabaseReadingMigration.swift:331`）；`reading_import_operations.status` 无 CHECK 约束（同文件 :309；其 `space_id` 已有 FK，与审查记录原文不同，已核正）。
   - learning material 历史 / operation 表无任何保留与清理策略，目前也没有 architecture note 承接该提醒。
   - `LearningContentRepository` 协议无并发标注（`LearningContent.swift:4`，`AnyObject` 而非 `@MainActor` / `Sendable` 边界）；Data `PracticeSessionState.swift:1-10` 的 `PracticeSessionStep` 仍是 mock 阶段命名残留。
   - spec 007 第 99 行只约束 operation 摘要不得记录原文 / 请求体 / 密钥，对 `reading_explanation_cache.result_json` 明文存储解释结果没有明确表述（核验未发现直接矛盾，属规范表述补全而非冲突修复）。
7. AI / Speech 尾项：
   - `AIProviderHTTPClient.swift:34-39` 先 `session.data(for:)` 读完整响应体再检查 `maximumResponseBytes`，超大响应仍会完整进内存。
   - `KeychainAIProviderCredentialStore.swift:146-167` 在 macOS 上通过 `dlopen` + `dlsym("SecAccessCreate")` 动态构造 ACL，未使用 `kSecUseDataProtectionKeychain`（背景与限制见 `docs/architecture/notes/2026-06-05-macos-ai-provider-credential-signing-notes.md`：无正式签名与 entitlements 时该常量会返回 -34018）。
   - `KeychainAIProviderCredentialStoreTests.swift:35-60` 存在读取源码文件断言子串的伪测试。
   - 空标记协议残留**两处同构**（2026-06-15 复核校正原「AIBoundary 不存在」结论）：AI 包 `AIBoundary.swift`（`public protocol AIProvider: Sendable {}` + `DisabledAIProvider`）与 Speech 包 `SpeechBoundary.swift`（`SpeechService` 空协议 + `DisabledSpeechService`）结构完全相同。Phase 5 step 4 须对两者用同一处置口径（以 `rg 'AIProvider\b' / 'SpeechService' -l` 的真实消费方核验为准；`DisabledAIProvider` 是否被 `AppEnvironment` 装配需现场核实，避免误删）。
   - `TTSAudioValidationService.swift:201-209` 按固定偏移（12=fmt、36=data）解析 WAV，扩展 fmt chunk / LIST chunk 的合法 WAV 会被拒绝。
   - `docs/spec/012-reading-learning-domain.md:79` 仍写 prompt v3，而代码已是 `builtin.reading.selection_explanation.v4`（`ReadingSelectionExplanationService.swift:13-15`，schema 仍为 v3）。

## 3. 目标

1. AI 文本请求路径收敛为统一的 text provider adapter 抽象：请求构造、认证头、dispatch、解析各只有一份实现，三个服务消费同一抽象；`anthropicMessages` / `geminiGenerateContent` 有明确的单点 unsupported 出口，为后续按 `docs/workflows/add-ai-provider.md` 接入 Anthropic（x-api-key）和 Gemini 预留位置。
2. 错误分类补全：生成与解释两个 failure category 覆盖 rateLimited / authenticationFailed / timeout / unsupportedModel；`AIProviderConfigurationError` 新增精确 case 并修正错用点；UI 错误映射同步更新。
3. 数据层读取失败不再静默：bridge 读路径上抛或经诊断事件上报，Core 定义对应诊断事件名。
4. Core 引入 `RedactedSecret` 包装类型（自定义 description / reflection 脱敏、常量时间相等比较），替换两处明文 String 字段。
5. Core 公开契约收紧：normalized 校验语义拆分、指纹属性改 `private(set)` / 工厂构造、Reading 范围模型改整数偏移并统一编码单位、Reducer / Coordinator 注入时钟、共享哈希工具、清除第 2 节列出的死代码与不变量杂项。
6. Data 尾项收口：枚举解码改 typed error 或显式 unknown、`LearningEntry` 增加 `updatedAt`、死软删除列处置决策落档、补 FK / CHECK、retention 提醒写入 architecture note、repository 协议并发标注、mock 残留清理、spec 007 表述补全。
7. AI / Speech 尾项收口：响应大小限制改为流式累计检查、macOS Keychain 演进方向写回 architecture note、伪测试替换为行为测试、WAV 解析改 RIFF chunk walker、spec 012 prompt 版本同步。

## 4. 范围

- `Packages/LangoTraceCore`、`Packages/LangoTraceData`、`Packages/LangoTraceAI`、`Packages/LangoTraceSpeech` 的源码与测试。
- `Packages/LangoTraceUI` 与 `LangoTraceApp` 中消费上述公开 API 的调用点（错误映射、类型重命名、签名变化的连锁修改）。
- `docs/spec/012-reading-learning-domain.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/learning-content/impl.md`、`docs/architecture/notes/`（新增 retention note、更新 macOS credential note）。

前序依赖：无（本方案是系列 E0a，系列首个实施项）。后续 E0b（UI / App 架构债）、E1（记录时间线）、E2（照片附件）均依赖本方案的错误分类与 adapter 接缝先落地。

## 5. 不做什么

- 不实际接入 Anthropic / Gemini provider（只做 adapter 抽象与扩展位，真实接入按 `docs/workflows/add-ai-provider.md` 另立方案）。
- 不改 `practiceSummary` 展示字符串为结构化状态：该项与 UI 渲染强耦合，整体划入 E0b（`2026-06-11-02-refactor-ui-architecture-debt.md`），避免两个方案改同一字段。
- 不在本方案直接切换 macOS Keychain 到 `kSecUseDataProtectionKeychain`（无正式签名与 entitlements 时会 -34018），只做代码注释与 architecture note 中的演进决策记录。
- 不新增数据库迁移把 44 处枚举解码点全部改成持久化 unknown 列；只改解码语义（typed error 或显式 unknown case），schema 不动。
- 不处理 UI / App 层结构债（PhoneMainView 导航、AppEnvironment 拆分等，归 E0b）。
- 不为 learning material 历史实现真实清理任务，只落 architecture note。
- 不重写 `GRDBLearningContentRepositoryBridge` 之外的 mock / seed 内容路径（E1 / E2 会按功能逐步替换）。
- 不收敛 TTS 与 Embedding 的请求路径：`TTSProviderAdapter.swift` 与 `EmbeddingConfigurationProbeService.swift`（2026-06-15 复核发现的第四个走 Bearer + makeRequest 的服务，原方案未提）也各自拼 Bearer，但**不在本方案 adapter 收敛范围**；adapter 收敛只针对三个文本服务。Phase 1 DoD 的 Bearer 计数须显式排除这两个文件，避免「三处重复」叙事被读成「全部文本路径」或诱导越界改 TTS / Embedding。

## 6. 证据与决策依据

- 代码证据：见第 2 节逐条文件路径与行号，全部于 2026-06-11 按 HEAD `274b7db` 重新核验。
- 文档证据：
  - `docs/workflows/add-ai-provider.md`：要求 Provider 协议 / adapter / probe / 结构化输出解析 / 错误分类在 AI 包分层实现；本方案的 adapter 抽象是其前置接缝。采纳该手册的分层要求；偏离点：本方案不做真实新 Provider 接入，因此不触发其 UI 设置页与 Keychain 全链路步骤。
  - `docs/architecture/notes/2026-06-05-macos-ai-provider-credential-signing-notes.md`：记录了 macOS ad-hoc 签名下 ACL 的脆弱性与 Data Protection Keychain 的 entitlements 前提，是 AI-12 只做"记录演进方向"而非"立即切换"的依据。
  - `docs/spec/004-swiftui-architecture.md` §3、§4.7：业务错误必须以可测试状态返回 UI，是错误分类补全后 UI 映射更新的依据。
  - CLAUDE.md §1.1 / §1.2：早期阶段允许直接收紧公开 API、不为未发布代码背兼容包袱。
- 审计发现与 work item 对照：

```text
来源：2026-06-11 全量代码审查（主方案 2026-06-11-chore-code-review-and-dev-plan-series.md 阶段 1 隔离审查，P2 延后项）
发现 ID 或 trigger ID：AI-09、AI-11、AI-12、AI-16、AI-21、AI-22、SPEECH-02、CORE-04、CORE-06、CORE-08、CORE-09、CORE-10、CORE-15、CORE-20、CORE-22、CORE-24、CORE-25、DATA-05、DATA-12、DATA-13、DATA-17、DATA-18、DATA-21、DATA-22、DATA-23
严重度：均为审查时的 P2（延后项）
对应 work item：见第 12 节 Phase 1-5 逐条映射
验证证据：本方案第 2 节的逐文件行号核验；其中 AI-22（AIBoundary）与 CORE-25 之一（PracticeAudioCoordinationState 平行状态机）经重核验为误记，已在第 13 节自审核记录中剔除或改写
```

证据边界声明：

```text
证据能证明什么：上述文件与行号在当前 HEAD（274b7db）的代码中确实存在所述结构。
证据不能证明什么：不能证明这些结构在真实运行期已造成用户可见缺陷；它们是契约与可维护性债，不是已复现 bug。
迁移前提：无外部参考迁移；全部为仓库内重构。
照搬风险：不适用。
```

```text
是否需要 spike / probe / fixture / evidence：AI-11 流式大小限制需要 macOS 上的 URLSession bytes(for:) 行为验证（Linux 环境无法运行 swift test）。
需要时的落点：Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderHTTPClientTests.swift 内新增用例，配合 mock URLProtocol fixture；不需要真实网络。
是否包含真实用户敏感内容：否。
如何验证和清理：fixture 为合成数据，随测试代码长期保留，无清理需求。
```

## 7. 约束映射与验证路径

### 约束 1：实现前必须创建 active plan 并获用户确认

- 约束 ID：DOC-CONST-001 / DOC-CONST-003
- 来源：docs/README.md §4.16、docs/plans/README.md §4
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查本方案状态字段
- 验证提示：实现开始前确认状态为 `User Approved`
- 说明：本方案当前为 Draft，仅授权方案制定。

### 约束 2：行为可自动化验证时先写单元测试

- 约束 ID：DOC-CONST-005
- 来源：docs/README.md §1.4、docs/spec/009-testing-and-verification.md
- 适用范围：本方案全部行为变化
- 严重度：blocker
- 执行或验证方式：单元测试 + `swift test --package-path Packages/<target>`
- 验证提示：每个 Phase 的 TDD 落点见第 15 节；伪测试替换项（AI-21）本身即测试改造。
- 说明：无。

### 约束 3：敏感凭证边界

- 约束 ID：DOC-CONST-011
- 来源：docs/README.md §4.9、docs/spec/005-ai-provider-prompt-and-privacy.md
- 适用范围：RedactedSecret 引入、Keychain 相关改动
- 严重度：blocker
- 执行或验证方式：单元测试断言 description / dump 输出不含明文；人工审查日志路径
- 验证提示：`RedactedSecret` 测试必须覆盖 `String(describing:)`、`String(reflecting:)`、`Mirror` 三条泄漏路径。
- 说明：CORE-06 与 AI-12 直接命中该约束。

### 约束 4：业务错误必须以可测试状态返回 UI

- 来源：docs/spec/004-swiftui-architecture.md §3、§4.7
- 适用范围：错误分类补全与 UI 映射
- 严重度：blocker
- 执行或验证方式：单元测试覆盖新 case 的 UI 展示映射
- 验证提示：新增 failure case 必须在 UI presentation 映射测试中有对应断言，避免 fallthrough 到 unknown。
- 说明：无。

### 约束 5：数据 / 存储任务回到存储 spec 检查

- 约束 ID：DOC-CONST-012
- 来源：docs/README.md §4.11、docs/spec/007-data-storage-migration-export-and-attachments.md
- 适用范围：FK / CHECK 补全、软删除列处置
- 严重度：warn
- 执行或验证方式：migration 测试 + 文档影响检查
- 验证提示：FK / CHECK 属于 schema 变化，需要新 migration（v16 起的下一个可用编号）并遵循 `docs/workflows/add-storage-migration.md`。
- 说明：本方案唯一的 schema 改动点。

## 8. 涉及的代码文件路径

- AI：`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`、`ReadingSelectionExplanationService.swift`、`AIProviderConfigurationProbeService.swift`、`AIProviderConfigurationService.swift`、`AIProviderHTTPClient.swift`、`KeychainAIProviderCredentialStore.swift`、新增 `AIProviderTextRequestAdapter.swift`（命名可在实现期微调）。
- Core：`AIProviderConfiguration.swift`、`LearningMaterialGenerationModels.swift`、`ReadingAIExplanation.swift`、`SentenceTTSGeneration.swift`、`LanguageSpace.swift`、`OnboardingDraft.swift`、`TTSProviderConfiguration.swift`、`ReadingTextSegmentation.swift`、`ReadingMarkdown.swift`、`PracticeSessionReducer.swift`、`SentenceAudioPlaybackCoordinator.swift`、`SentenceAudioPlayback.swift`、`LanguageSpacePreview.swift`、`InterfaceLanguagePreference.swift`、`ReadingSearch.swift`、`ReadingDictionaryLookup.swift`、`PhoneRootTab.swift`、新增 `RedactedSecret.swift`、新增 `StableHashing.swift`（共享 sha256Hex / fnv1a）。
- Data：`GRDBLearningContentRepositoryBridge.swift`、`LearningContentModels.swift`、`LearningContent.swift`、`PracticeSessionState.swift`、`AppDatabase.swift`（新 migration）、`AppDatabaseReadingMigration.swift`（仅参考，新约束放新 migration）、各 GRDB repository 的枚举解码点（44 处，见第 2 节代表性列表）。
- Speech：`TTSAudioValidationService.swift`、`SpeechBoundary.swift`。
- 连锁调用点：`Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift`（共享哈希迁移）、UI 错误展示映射文件、`LangoTraceApp/AppEnvironment.swift`（签名连锁）。
- 测试：上述各包 `Tests` 目录对应测试文件（详见第 15 节）。

## 9. 参考的代码文件路径

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderEndpointURLBuilder.swift`、`AIProviderHTTPStatusErrorMapper.swift`、`OpenAICompatibleResponseTextParser.swift`（已抽取的共享 helper，是 adapter 的内层）。
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift` v10 migration（CHECK 约束演进的既有先例）。
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/WAVTestFixtures.swift`（WAV fixture 扩展基础）。

## 10. 涉及的文档路径

- `docs/spec/012-reading-learning-domain.md`（prompt v3 → v4 + schema v3 的准确表述）。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`（reading explanation cache 明文存储表述补全）。
- `docs/spec/learning-content/impl.md`（LearningEntry.updatedAt、bridge 错误上报后的实现地图更新）。
- `docs/architecture/notes/`：新增 `2026-06-11-learning-material-history-retention-notes.md`；更新 `2026-06-05-macos-ai-provider-credential-signing-notes.md`（Data Protection Keychain 演进决策与触发条件）。
- `docs/prompts/`：无 Prompt 内容变化，但若 adapter 抽象改变请求体构造位置，需核对 registry 中输入变量描述仍准确。
- 本方案。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

按 5 个 Phase 顺序实施，每个 Phase 独立可验证、独立 commit。Core 公开 API 变化会连锁到 Data / AI / UI / App，因此每个涉及 Core 签名变化的 Phase 都以"全包测试通过"为 DoD，最终在 macOS 上做一次跨包全测扫尾。

### Phase 1：AI text provider adapter 抽象（AI-09）

1. 在 LangoTraceAI 新增 `AIProviderTextRequestAdapter`（协议 + `OpenAICompatibleChatAdapter` / `OpenAIResponsesAdapter` 两个实现）：输入 endpoint 配置、model、消息 / 指令、结构化输出要求与凭证引用，输出 `URLRequest`；解析侧复用 `OpenAICompatibleResponseTextParser`。
2. 新增单一 dispatch 入口（按 `AIProviderAdapterKind` 返回 adapter；`anthropicMessages` / `geminiGenerateContent` 返回带明确分类的 unsupported 错误），删除三个服务内各自的 switch。
3. 三个服务改为消费 adapter；auth header（Bearer）由 adapter 统一注入，为 Anthropic `x-api-key` 预留 header 策略点。
4. DoD：三个服务源码中不再出现重复的 makeRequest / Bearer 拼接 / kind switch；`swift test --package-path Packages/LangoTraceAI` 全绿；现有 fixture 行为不变。

### Phase 2：错误分类补全与错用修正（AI-16）

1. Core：`LearningMaterialGenerationFailureCategory` 增加 `rateLimited`、`authenticationFailed`；`ReadingSelectionExplanationFailureCategory` 增加 `timeout`、`authenticationFailed`、`unsupportedModel`、`rateLimited`。
2. AI：`AIProviderHTTPStatusErrorMapper` 的 401/403/429 映射接到新 case；`AIProviderConfigurationError` 新增 `invalidResponseBody`、`configurationStoreUnavailable`、`defaultProfileMissing` 等精确 case，修正第 2 节列出的三处错用点。
3. UI / App：错误展示映射补齐新 case（String Catalog key 同步新增），不允许新 case 落入 unknown fallback。
4. DoD：新 case 的映射测试全绿；`rg "keychainWriteFailed" Packages/LangoTraceAI` 只剩真实 Keychain 写入路径。

### Phase 3：Core 契约收紧（CORE-04/06/08/09/10/15/20/22/24/25）

1. 新增 `RedactedSecret`：存储 String，自定义 `description` / `debugDescription` / `customMirror` 输出固定掩码，实现常量时间相等比较；替换 `SentenceTTSGenerationRequest` 与 `AIProviderCredentialSecretSaveInput` 字段，连锁更新 AI / Speech / UI / App 调用点。
2. 拆分 `CreateLanguageSpaceInput.normalized()`：UI 草稿归一化（不抛错、允许回退默认值，供 onboarding 草稿预览）与持久化校验（未知语言 code 抛 typed error）分成两个明确入口，移除"声明 throws 永不抛"状态。
3. `TTSVoiceProfile.configurationFingerprint` 改 `private(set)` + 工厂 / 重算入口；`ReadingLibrarySearchQuery.normalized` 改 `let` 或 `private(set)`；`ReadingDictionaryLookup.normalizedHeadword` 改由 init 内从 headword 计算。
4. Reading 范围模型：`ReadingTextChunk` / `ReadingMarkdownBlock` / `ReadingInlineRun` 的范围改为整数偏移类型（统一 UTF-16 code unit 偏移，新增轻量 `TextUnitRange` 值类型并文档化单位），同步修复 `ReadingTextSegmentation.swift:247-260` 的单位混用与 `segmentSentences` fallback 不一致（fallback 与主路径同用 trimmed 语义）。
5. `PracticeSessionReducer` 与 `SentenceAudioPlaybackCoordinator` 注入 `now: () -> Date`（或 Clock），相关测试移除真实等待。
6. 新增 `StableHashing`（internal-per-package 或 Core 公开工具，倾向 Core 公开 + 各包复用），收敛 7 处 sha256Hex 与 1 处 FNV-1a；移除 `AIProviderConfigurationRepository` 协议扩展的 nil 默认实现（让漏实现编译期暴露）。
7. 死代码清理：为 `AIProviderCustomHeaderConfiguration` 补公开 init（自定义 header 是 Anthropic / 自建网关的真实需求，保留并修复）；删除 `kind(inferredFrom:)`、`applying(to:)` 恒等函数、`.generationSucceeded` 未用转移、重复 `LanguageSpacePreview` init；`PhoneRootTab` 显式声明 `Sendable`。
8. DoD：Core / Data / AI / Speech / UI 全部 `swift test` 通过；`rg "plaintextSecret: String" Packages` 无裸 String 命中。

### Phase 4：Data 层尾项（DATA-05/12/13/17/18/21/22/23）

1. bridge 读路径：`GRDBLearningContentRepositoryBridge` 三处 `try? ?? []` 改为捕获后写诊断事件（Core 新增事件名，如 `learning_content.repository_read_failed`，复用现有 DiagnosticEvent 通道）并返回空集合，行为对 UI 仍是降级而非崩溃。
2. 枚举解码：引入统一解码 helper（`decodeStored(_:fallback:)`），失败时写诊断事件再回退显式 `unknown` / 文档化 fallback，逐处替换 44 个 `rawValue ?? default` 点（允许分两批 commit）。
3. `LearningEntry` 增加 `updatedAt`（新 migration 增列，回填 `created_at` 值；`updateEntryBody` 写入新值）。
4. 软删除死列：决策为"保留列、修正写路径"——AI provider 配置写入从 replace-all 改为 soft-delete 旧行 + 插入新行，使 `deleted_at` 语义成立；若实现中发现成本过高，回退决策为删除列并在本方案实施记录中说明（两种处置都需写回 `docs/spec/007`）。
5. 新 migration：为 `reading_explanation_cache.space_id` 补 FK（SQLite 需重建表，参照 v10 先例）、为 `reading_import_operations.status` 补 CHECK。
6. `LearningContentRepository` 协议标注 `@MainActor`（与当前唯一消费方 `LearningContentStore` 的主线程语义一致）；重命名 / 清理 Data `PracticeSessionStep` mock 残留命名。
7. 新增 `docs/architecture/notes/2026-06-11-learning-material-history-retention-notes.md`：记录 material 历史与 operation 表的增长边界、未来清理候选策略与触发条件。
8. spec 007 补一句明确表述：`reading_explanation_cache.result_json` 以明文存储解析后的解释结果、属于本机可重建派生缓存、不进入导出与同步。
9. DoD：`swift test --package-path Packages/LangoTraceData` 全绿，migration 测试覆盖旧库升级路径。

### Phase 5：AI / Speech 尾项（AI-11/12/21/22、SPEECH-02、spec 012 同步）

1. `AIProviderHTTPClient` 改用 `bytes(for:)` 流式累计读取，超过 `maximumResponseBytes` 即中断抛 `responseTooLarge`；保留旧行为测试 + 新增超限中断测试（标注需 macOS 验证 URLSession 实现差异）。
2. macOS Keychain：在 `2026-06-05-macos-ai-provider-credential-signing-notes.md` 中追加决策记录——保留 dlopen / SecAccessCreate 现状，明确触发条件（获得稳定开发者签名 + keychain-access-groups entitlement）满足后迁移 `kSecUseDataProtectionKeychain`，并在代码处加指向该 note 的注释。
3. 替换 `KeychainAIProviderCredentialStoreTests` 的源码 grep 伪测试：以可注入 query executor seam 断言"查询字典包含 `kSecUseAuthenticationUIFail`、不触发交互"等行为；无法注入的平台分支以编译期断言或文档化豁免说明。
4. 两个同构空标记协议文件统一处置（2026-06-15 复核：AI 包 `AIBoundary.swift` 与 Speech 包 `SpeechBoundary.swift`）：各自以 `rg "AIProvider\b" -l` / `rg "SpeechService" -l` 的真实消费方核验——无任何消费方则删（含对应 `DisabledAIProvider` / `DisabledSpeechService`），有装配消费（如 `AppEnvironment` 注入 disabled 实现）则改为有契约的最小协议。两文件采用同一判定口径，不留不对称残留。
5. WAV 解析改 RIFF chunk walker：顺序遍历 chunk（fmt 长度可变、容忍 LIST / fact），新增扩展 fmt 与 LIST chunk 的合成 fixture。
6. `docs/spec/012-reading-learning-domain.md:79` 更新为 prompt v4 + schema `reading_selection_explanation.v3` 的准确组合表述。
7. DoD：AI / Speech 包测试全绿；`rg "contentsOf: langoTraceAISourceFileURL" Packages/LangoTraceAI/Tests` 无命中。

### 收口

macOS 环境跨包全测扫尾（六个包 `swift test` + `xcodebuild test -only-testing:LangoTraceAppTests`），文档影响检查（第 17 节），实施记录回填后移入 done。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：本方案本身基于 2026-06-11 主方案的五路隔离子代理审查输出制定，且制定过程中已用三个只读核验代理对每条代码事实重新取证；再起隔离会话边际收益低。
发现摘要：
- [P1][第一轮] 原始审查记录中 "PracticeAudioCoordinationState 平行状态机"（CORE-25 子项）经重核验不成立：PracticeAudioCoordination.swift 以单一 activeResource 为事实源。已从范围中剔除。
- [P1][第一轮] 原始记录 "AIBoundary 空协议残留"（AI-22）在 LangoTraceAI 包不存在；实际残留为 Speech 包 SpeechBoundary.swift。已改写 Phase 5 第 4 步并以消费方核验为前置。
- [P1][第一轮] sha256Hex 重复数量为至少 7 处（非 4 处）、FNV-1a 为 1 处（非 2 处）；reading_import_operations.space_id 实际已有 FK（仅 status 缺 CHECK）。第 2 节与 Phase 4 已按实数核正。
- [P1][第一轮] practiceSummary 结构化替换与 E0b 的 UI 渲染项重叠，若两方案分改同一字段会产生跨方案冲突。已整体划归 E0b，本方案"不做什么"显式排除。
- [P2][第一轮] AIProviderCustomHeaderConfiguration 直接删除会损失 Anthropic / 自建网关的真实扩展需求；修订为"补公开 init 修复不可构造"而非删除。
- [P2][第一轮] DATA-23 经核验不构成 spec 冲突，降级为 spec 007 表述补全项，避免把"代码偏差"包装为"规范修复"。
- [P1][第二轮] 本环境（Linux）无 swift 工具链，所有 swift test 验证命令无法在制定环境运行。已在第 16 节与第 20 节记录：实现必须在 macOS 开发机执行验证，AI-11 的 URLSession 流式行为属于必须上 macOS 验证的项。
- [P2][第二轮] Phase 3 的 Range<String.Index> → 整数偏移会连锁 Reading UI（UITextView per-block 渲染按 UTF-16 计），第 9 节补充参考 docs/architecture/notes/2026-06-06-reading-uitextview-per-block-patterns.md 的单位约定；统一选用 UTF-16 code unit 并在新类型文档注释中固定。
- [P2][第二轮] 枚举解码 44 处逐点替换体量大，允许分两批 commit 并在 DoD 中以 rg 扫描收敛进度，避免单 commit 过大不可审。
- [P3][第二轮] StableHashing 放 Core 公开还是各包 internal 留有两案；方案倾向 Core 公开，实现期若发现 UI 包仅 1 处消费可降级为局部收敛，须在实施记录说明。
写回修改：第 2 节按重核验实数改写；第 5 节新增 practiceSummary、Keychain 切换、清理任务三项排除；第 12 节 Phase 4 软删除列改为双处置决策、Phase 5 第 4 步改为消费方核验前置；第 16 节、第 20 节补 macOS 验证约束。
仍需用户确认的问题：
1. 软删除死列的默认处置（保留列 + 修正写路径）是否符合预期，或直接删列。
2. RedactedSecret 引入造成的公开 API 破坏范围（Core/AI/Speech/UI/App 连锁）是否接受一次性完成。
是否允许进入实现：待用户确认后允许。
```

---

```text
审核日期：2026-06-15（第二条记录：实现前隔离子代理复核）
审核方式：隔离审查（只读 Plan 子代理）+ 主会话对 3 个 P1 逐条核验（git / 真实文件）
审核轮次：实现前再复核（Mac 验证门关闭、基线前进 48 commit 后）
触发原因：本方案制定 + 自审核均在 2026-06-11；其后 Mac 验证门关闭引入 5 类修复，需对照当前代码核验现状是否仍成立。
发现摘要（均经主会话核验属实）：
- [P1-1] 资料基线 `274b7db` 已落后当前 HEAD 48 个 commit；`83f4ef1`(swiftformat) / `483bfe9`(SwiftLint 重构) 改动了 §8 点名的 AI 服务文件，§2.1/§2.2 行号系统性漂移（Bearer 154→176 等）。→ 已在 §2 开头加基线漂移说明，行号降级为符号锚点。是否阻塞：是（已处置）。
- [P1-2] sha256Hex 重复 7→8，UI 包从 1 增至 2（漏列 `ReadingDocumentStore+Selection.swift`）。→ §2.5 已更新计数并改 StableHashing 倾向 Core 公开。是否阻塞：是（已处置）。
- [P1-3] 原「AIBoundary 不存在/误记」结论不成立：`AIBoundary.swift`(`AIProvider`/`DisabledAIProvider`) 客观存在且与 `SpeechBoundary.swift` 同构。→ §2.7 改写、Phase 5 step 4 统一两文件处置口径。是否阻塞：否（已处置）。
- [P2-1] §2.6 schema 行号错位（`:309` 实为 lifecycle_events，import_operations 表在 ~267、status 在 ~272；cache 表在 ~327）。底层 FK/CHECK 缺口成立。建议实现时按表名而非行号定位。
- [P2-3] Phase 1 DoD「Bearer 只剩 adapter 一处」不可达：AI 包共 6 处 Bearer，TTS/Embedding 不在范围。→ §5 增列排除、§16 DoD 限定到三个文本服务、计数目标改 0。
- [P2 新] 发现第四个走 Bearer+makeRequest 的服务 `EmbeddingConfigurationProbeService`，原方案未提。→ §5 显式排除。
- [P2-2] Reading 解释缓存 async 测试历史有 continuation 竞态（commit 9d81330/8bb89cc/62fcc78）；Phase 3 时钟注入触及该区域。→ 写入 §20 剩余风险。
- [P3] §15 首失败用例对 enum 新增 case 的「编译失败即红」机制应注明；§5 应排除 Embedding（已处置）。
写回修改：§2 基线漂移说明 + 行号符号锚点化；§2.5 sha256 计数 7→8 + StableHashing 倾向；§2.7 + Phase 5 step 4 双 boundary 统一口径；§5 排除 TTS/Embedding；§16 Bearer DoD 限定范围与目标；§20 增 async coordinator 风险。
仍需用户确认的问题：3 项实现决策已于 2026-06-15 由用户预先确认（软删除列＝保留列+修正写路径、RedactedSecret 一次性完成、StableHashing＝Core 公开），见「用户确认记录」。剩余唯一门：用户对方案整体的复核与实现授权。
裁决：3 个 P1 已在本方案内完成事实校正（不涉及新建 plan / architecture note，均为 §2/§5/§12/§16/§20 的源头订正）；3 项设计决策已锁定；校正后方案 implementation-ready，仍为 `状态:Draft`，待用户复核后推进至 `User Approved` 方可实现。
```

## 14. 复查方法

- adapter：检查三个服务源码无重复请求构造；故障路径核查——构造 URL 失败、401/403/429、超时、取消、结构化输出非法、不支持的 adapter kind 各有 typed 出口且有测试。
- 错误分类：人为构造 429 / 401 fixture，确认 UI 展示为限流 / 认证失败而非 unknown。
- RedactedSecret：`print` / `dump` / 字符串插值手动验证输出为掩码；Keychain 保存与 TTS 请求功能不回归。
- 数据层：删除底层表后调用 bridge 读路径，确认产生诊断事件且 UI 降级为空态不崩溃；migration 用旧 schema fixture 库验证升级。
- WAV：用扩展 fmt chunk 的真实 WAV 样本（合成 fixture）验证通过校验、44 字节标准 WAV 不回归。
- 全局：macOS 上六包 `swift test` + App 测试全绿。

## 15. TDD / 测试落点

```text
测试落点（Phase 1）：Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderTextRequestAdapterTests.swift（新建），类型 AIProviderTextRequestAdapterTests
先失败用例：chatAdapterBuildsBearerAuthorizedRequest —— 失败原因：AIProviderTextRequestAdapter 类型尚不存在（编译失败即红）
聚焦验证命令：swift test --package-path Packages/LangoTraceAI --filter AIProviderTextRequestAdapterTests

测试落点（Phase 2）：Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LearningMaterialGenerationFailureCategoryTests.swift（新建）
先失败用例：rateLimitedCaseExists —— 失败原因：case 尚未定义（编译失败即红）
聚焦验证命令：swift test --package-path Packages/LangoTraceCore --filter LearningMaterialGenerationFailureCategoryTests

测试落点（Phase 3）：Packages/LangoTraceCore/Tests/LangoTraceCoreTests/RedactedSecretTests.swift（新建）
先失败用例：descriptionDoesNotContainPlaintext —— 失败原因：RedactedSecret 尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceCore --filter RedactedSecretTests

测试落点（Phase 4）：Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBLearningContentRepositoryBridgeDiagnosticsTests.swift（新建）
先失败用例：entriesReadFailureEmitsDiagnosticEvent —— 失败原因：bridge 当前吞错且不发事件
聚焦验证命令：swift test --package-path Packages/LangoTraceData --filter GRDBLearningContentRepositoryBridgeDiagnosticsTests

测试落点（Phase 5）：Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/TTSAudioValidationTests.swift（扩展）
先失败用例：acceptsWAVWithExtendedFmtChunk —— 失败原因：现有固定偏移解析拒绝扩展 fmt chunk fixture
聚焦验证命令：swift test --package-path Packages/LangoTraceSpeech --filter TTSAudioValidationTests

不新增单元测试的原因（如适用）：spec 012 / 007、architecture notes 更新为文档变更，依赖第 16 节文档命令；macOS Keychain 注释属非行为变更。
```

## 16. 验证命令

```bash
# 聚焦（按 Phase，见第 15 节 --filter 命令）

# Phase DoD（结构性检查）
# Phase 1 DoD：三个文本服务源码内 Bearer 注入归零（统一移入 text adapter）。
# 注意：TTSProviderAdapter.swift / EmbeddingConfigurationProbeService.swift 的 Bearer 不在本方案范围，须排除（见 §5）。
rg "Bearer \\\\(" Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift --count-matches   # Phase 1 后应为 0
rg "plaintextSecret: String" Packages                              # Phase 3 后无命中
rg "\(try\? .*\) \?\? \[\]" Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift  # Phase 4 后无命中
rg "contentsOf: langoTraceAISourceFileURL" Packages/LangoTraceAI/Tests  # Phase 5 后无命中

# 完整（必须在 macOS 开发机运行；当前制定环境为 Linux，无 swift 工具链）
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests

# 文档
scripts/check-docs.sh
git diff --check
```

按 CLAUDE.md §1.4 第 7 条，不主动运行 `scripts/verify.sh`；本方案为跨模块重构，收口前的跨包全测以上述逐包命令表达，仅在用户要求或合并前考虑全量脚本。

## 17. 文档影响检查

- `docs/spec/012-reading-learning-domain.md`：prompt 版本事实更新（必改）。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：explanation cache 明文表述、软删除列处置结论（必改）。
- `docs/spec/learning-content/impl.md`：`updatedAt`、诊断事件、repository 注解后的实现地图（必改）。
- `docs/architecture/notes/`：新增 retention note；更新 macOS credential signing note（必改）。
- `docs/prompts/README.md` 及 registry：核对请求构造位置变化后输入变量描述仍准确（核对，预计不改内容）。
- `docs/platform-page-inventory.md`：无页面增删；若错误展示文案 key 变化导致页面能力描述变化则同步（预计不改）。
- ADR：不推翻任何核心决策，无新增 ADR。
- 实现完成后按 `docs/review/README.md` 做文档影响检查（涉及数据 migration 与包边界，命中专项审查触发条件）。

## 18. 实施记录

2026-06-11：方案创建并完成双轮自审核（见第 13 节）。尚未进入实现。

## 19. 完成标准

1. 第 12 节 5 个 Phase 全部实施，DoD 结构性检查全部通过。
2. macOS 上六包 `swift test` 与 LangoTraceAppTests 全绿。
3. 第 17 节必改文档全部更新，`scripts/check-docs.sh` 通过。
4. plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：逐 Phase 核对第 12 节 DoD
scope-down 是否已记录：若软删除列处置回退为删列、StableHashing 降级局部收敛，须在实施记录写明
deferred / aborted 项是否已从完成叙事中剥离：Anthropic / Gemini 真实接入、Keychain 切换、material 清理任务均为显式排除项，不计入完成叙事
后续事实源或复审入口：docs/spec/learning-content/impl.md、docs/architecture/notes/ 两份 note
```

## 20. 剩余风险

- Core 公开 API 变化（RedactedSecret、整数偏移、normalized 拆分）连锁 Data / AI / UI / App，存在编译连锁面大、单次 commit 过大的风险；以 Phase 切分与逐包测试缓解。
- 制定环境无 swift 工具链，方案中的红绿路径未在本机演练；首个失败测试的"预期失败原因"在 macOS 上可能表现为编译错误而非断言失败，属可接受的 TDD 红态。
- `bytes(for:)` 流式行为在不同 OS 版本的 URLSession 实现差异未验证，Phase 5 必须在 macOS 真实运行测试。
- 44 处枚举解码点逐一替换可能遗漏个别点；以 rg 扫描作为 DoD 兜底，但 rg 模式可能漏掉变体写法，最终以人工抽查补充。
- 软删除列改写路径若触及 AI provider 配置保存链路的既有测试预期，改动量可能超出预估；已预留回退处置（删列）决策口。
- （2026-06-15 复核增列）Phase 3 给 `SentenceAudioPlaybackCoordinator` / `PracticeSessionReducer` 注入时钟、Phase 3 改 Reading 范围模型，触及 Mac 验证门期间暴露过 continuation 竞态的 async/coordinator 区域（commit `9d81330` / `8bb89cc` / `62fcc78`）。改动须遵守 `docs/spec/009` 沉淀的约定（`#require` 先 await、GRDB read 闭包显式返回类型、continuation 单次 resume），否则 CI（macOS）UI / playback 异步测试可能挂起，而本机 Linux 无法复现。
