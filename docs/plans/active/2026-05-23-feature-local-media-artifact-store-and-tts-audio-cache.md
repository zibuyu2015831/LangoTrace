# 任务方案：本地媒体派生资产存储与 TTS 音频缓存基础设施

状态：Draft
类型：feature
创建日期：2026-05-23
最后更新日期：2026-05-23

审核状态：Ready for User Review

## 用户确认记录

- 2026-05-23：用户确认早期开发阶段发现错误或落后框架可以推倒重来，不需要为临时代码背历史包袱。
- 2026-05-23：用户确认基础设施首次实现时应采用最优完整方案，为后续开发留下足够扩展，避免后续返工。
- 2026-05-23：用户确认 docs 是 AI 辅助开发的工程控制面，规范文档可随更优设计演进，开发过程中需要持续沉淀规范。
- 2026-05-23：用户确认后续可扩展但暂不实现的能力，应按要求创建对应架构开发备忘录。
- 2026-05-23：逐句 TTS 播放方案已采纳“本地媒体派生资产基础设施”方向：TTS 逐句音频不是临时 UI 缓存，而是本地优先、隐私敏感、可重建的派生媒体资产。
- 2026-05-23：用户询问除 TTS Provider 语音模型测试方案外，其他前提条件是否需要创建方案文档。结论：需要创建本方案，作为逐句直接播放 TTS 音频前置方案之一。
- 2026-05-23：系统架构复查确认，本方案方向符合早期可重做、基础设施完整建设、规范文档演进和未来扩展进入备忘录的原则；复查补强 `LocalMediaArtifactStore` facade、staged file reference、UI 不接触文件路径、并发唯一索引兜底和后续 direct playback 依赖边界。
- 2026-05-23：基于当前代码再次严格复查后修订方案：`AppDatabase` 已存在 `v6_create_ai_provider_tts_configuration`，本方案迁移改为 `v7_create_media_artifact_infrastructure`；`LangoTraceSpeech` 已有 test target、bytes-based `TTSAudioValidationService`、preview store 和 preview playback service，本方案改为在现有 Speech 能力之上新增持久文件验证 seam；明确 Repository 只管 metadata，`LocalMediaArtifactStore` facade 统一编排 file store、repository 和 Core validator protocol；补强 voice profile 绑定、verification script 和三端共享基础设施边界。

## 1. 需求描述

`docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md` 要求用户在逐句分析中点击听一句时：

1. 已生成音频时直接播放本地音频。
2. 未生成音频时调用已测试通过的 TTS Provider 生成，成功后自动播放。
3. 重复播放同一句同配置音频时不得重复调用 Provider。
4. 句子、语言、Provider、模型、voice、format、style 或配置 fingerprint 变化后不得复用旧音频。

这些行为不能靠 `SentencePairView` 的私有 `@State`、临时目录文件或 ad hoc 文件名规则实现。当前项目处于早期阶段，应该先建设通用 `LocalMediaArtifactStore`，用统一 metadata、文件存储、失效、清理和 policy 机制承载 TTS 逐句音频，并为后续全文朗读、跟读录音、听写录音、导出临时产物和音频同步留下稳定扩展点。

本方案要定义并实施一个可独立验证的基础设施层：

- Core 中定义媒体派生资产领域类型、owner、artifact type、policy、artifact key 和错误类型。
- Data 中新增 GRDB metadata schema、repository、文件存储目录、`LocalMediaArtifactStore` facade 和清理能力。
- Speech 中提供音频文件验证 seam，确保 ready TTS artifact 不是不可解码文件。
- App / 后续 TTS 播放 coordinator 可以通过该基础设施完成 TTS audio artifact hit / miss / write / invalidated / cleanup。

## 2. 现状描述

当前代码事实：

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift` 当前 migration 到 `v6_create_ai_provider_tts_configuration`，已有 `language_spaces`、AI Provider 配置、diagnostic events、Entry / LearningMaterial / sentence / candidate / operation 表，以及 `ai_provider_tts_settings` / `ai_provider_tts_voice_profiles`。
- 当前没有 `media_artifacts`、`tts_audio_artifacts` 或等价 metadata 表。
- 当前 `GRDBLearningContentRepository` 已负责 Entry、LearningMaterial、句子分析和 operation 摘要，使用可注入 clock / id generator，Data package 已有 GRDB repository 测试模式可复用。
- 当前 `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/SpeechBoundary.swift` 仍只有空 `SpeechService` 和 `DisabledSpeechService`；但 `Packages/LangoTraceSpeech/Package.swift` 已有 `LangoTraceSpeechTests` test target，`Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioValidationService.swift` 已有面向 TTS Provider 配置测试的 bytes-based `DefaultTTSAudioValidationService`、内存 preview store 和 preview playback service。
- 当前 `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioValidation.swift` 已定义 `TTSAudioValidationService`、`TTSAudioMetadata`、`TTSAudioPreviewResource`、`TTSAudioPreviewStore` 和 `TTSAudioPreviewPlaybackService`。这些类型服务于设置页短生命周期 preview，不等同于持久 media artifact file validator。
- 当前 `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSProviderConfiguration.swift` 已定义 `TTSVoiceProfile`、`TTSProviderSettings`、`TTSAudioFormat`、`TTSProviderAdapterKind` 和 configuration fingerprint；本方案必须复用这些已落地类型和 fingerprint 语义，不再重新发明并行配置模型。
- 当前逐句播放 UI 只在 `SentencePairView` 内用 `isLocalPlaybackActive` 做原位视觉反馈，没有真实音频文件、播放服务或缓存命中能力。
- 当前 TTS Provider 配置测试方案已有独立文档：`docs/plans/active/2026-05-23-feature-tts-provider-configuration-test.md`。该方案负责配置、测试、voice profile 和 TTS 可用性，不负责真实逐句播放音频文件的本地存储基础设施。

当前文档事实：

- `docs/spec/007-data-storage-migration-export-and-attachments.md` 已把“媒体派生资产”纳入数据分层，要求通过 GRDB / SQLite metadata 或等价 repository 引用文件，并定义 owner、artifact type、derivation key、相对路径、byte size、duration、created / last accessed、失效、清理、backup policy、sync policy 和 export policy。
- `docs/spec/011-tts-provider-configuration-and-playback.md` 已要求逐句播放生成的 TTS 音频必须通过本地媒体派生资产基础设施管理，不得写入 SwiftUI 私有状态、临时目录、不可索引文件名或 UI 层 ad hoc 缓存。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md` 已记录全文朗读、跟读录音、听写录音、音频同步、导出和附件化的后续扩展边界。

## 3. 目标

本任务完成后，应达到以下目标：

1. 建立通用 `LocalMediaArtifactStore` 基础设施，首个落地对象是 TTS 逐句音频。
2. 新增可迁移、可测试的 GRDB metadata schema，记录通用 media artifact 与 TTS audio artifact 专属字段。
3. 音频文件写入 App 管理目录 `Application Support/LangoTrace/MediaArtifacts/` 或等价目录，默认排除系统备份。
4. 文件名和目录名不包含原文、Entry 标题、用户输入短语、Provider secret、完整 Keychain account 或可读敏感字段。
5. ready artifact 写入采用临时文件、音频验证、content hash 校验、原子移动和 metadata 提交边界。
6. artifact hit / miss / invalidated 判断可测试，不依赖 UI 状态。
7. 重复相同 artifact key 的写入或查询具备幂等和一致性边界。
8. Entry、LearningMaterial、语言空间、Provider profile、TTS endpoint、voice profile 或配置 fingerprint 变化时，相关 artifact 不再作为当前命中。
9. 支持按 artifact type、language space、owner、last accessed、capacity / LRU 清理。
10. 默认 policy 为 `syncPolicy = localOnly`、`backupPolicy = excludedFromSystemBackup`、`exportPolicy = excludedByDefault`。
11. Core / Data / Speech 包具备聚焦单元测试，后续 direct playback 方案可以依赖这些协议和 repository。

## 4. 范围

本任务范围：

- Core 媒体派生资产领域模型和协议。
- Data GRDB schema、repository、migration、文件存储和 `LocalMediaArtifactStore` facade。
- Speech 音频验证 seam，用于确保 TTS audio artifact 可解码。
- TTS 逐句音频 artifact key、metadata、hit / miss / invalidated / cleanup。
- 非敏感诊断字段和日志禁区的测试要求。
- 为逐句播放 coordinator 暴露可调用的查询、提交、失效、清理接口。

本任务支持 iPhone / iPad / macOS 三端共享基础设施；不做平台分叉。

## 5. 不做什么

本任务不实现以下内容：

- 不实现 TTS Provider 配置页、TTS probe、voice profile 测试或 Provider 错误映射；这些属于 `2026-05-23-feature-tts-provider-configuration-test.md`。
- 不实现 `SentencePairView` 真实播放 UI 接入；这属于 `2026-05-23-feature-direct-sentence-tts-playback.md`。
- 不实现真实 Provider 网络请求或请求体构造。
- 不实现后台播放、锁屏控制、远程控制中心或系统音频中断完整策略。
- 不实现批量预生成全文音频。
- 不实现跨设备音频同步、默认导出、可恢复备份或附件 manifest。
- 不实现用户跟读录音、听写录音、ASR 或跟读评分。
- 不做跨 Entry 全局文本音频去重；第一阶段 artifact key 纳入稳定句子来源。

## 6. 证据与决策依据

产品依据：

- LangoTrace 是本地优先的个人语言记忆系统，TTS 音频虽然可重建，但会泄露学习内容和生活语义，不能当作普通无管理缓存。
- 外部 TTS Provider 可能收费，同一句同配置重复播放应命中本地 artifact，避免重复扣费。
- 逐句播放是听说闭环高频动作，必须比临时文件或 UI 私有状态更稳定。

架构依据：

- `docs/spec/004-swiftui-architecture.md` 要求 AI、TTS、OCR、Speech、Sync 必须通过协议或服务层进入 UI，View 不直接访问 SQLite、Keychain、网络、对象存储或具体 Provider。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 已要求媒体派生资产通过 metadata / repository 管理，并定义 policy。
- `docs/spec/011-tts-provider-configuration-and-playback.md` 已要求逐句 TTS 音频通过本地媒体派生资产基础设施管理。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md` 已确认该基础设施需为后续音频能力复用。

数据一致性依据：

- `entryID + sentenceIndex` 不足以作为缓存 key。句子文本、目标语言、Provider、endpoint、adapter、model、voice、format、style、provider parameters 或 configuration fingerprint 变化都可能改变音频内容或合法性。
- metadata 存在但文件丢失、文件存在但 metadata 丢失、半成品文件、解码失败文件都必须有可测试恢复路径。

## 7. 涉及的代码文件路径

预计新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/MediaArtifact.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactFileStore.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioFileValidation.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioFileValidator.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/MediaArtifactTests.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/TTSAudioFileValidatorTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LocalMediaArtifactStoreTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LocalMediaArtifactFileStoreTests.swift`

预计修改：

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/AppDatabaseTests.swift`
- `Packages/LangoTraceSpeech/Package.swift`，仅当需要新增 fixture resources 或测试依赖；当前已有 `LangoTraceSpeechTests` test target，不需要为 test target 本身修改。
- `scripts/verify.sh`，新增 `swift test --package-path Packages/LangoTraceSpeech`，确保 Speech 基础设施进入完整验证。
- `LangoTraceApp/AppEnvironment.swift`，仅在后续 direct playback 或 service 装配任务中真正注入；本方案可先不接 UI。

可能修改：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticLogger.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBDiagnosticEventRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LanguageSpaceDatabaseLocation.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBDiagnosticEventRepository.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/AppDatabaseTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBLearningContentRepositoryTests.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/SpeechBoundary.swift`
- `Packages/LangoTraceSpeech/Package.swift`
- `LangoTraceApp/AppEnvironment.swift`

## 9. 涉及的文档路径

本方案创建：

- `docs/plans/active/2026-05-23-feature-local-media-artifact-store-and-tts-audio-cache.md`

本方案依赖：

- `docs/plans/active/2026-05-23-feature-tts-provider-configuration-test.md`
- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`

本任务实施完成后按影响更新：

- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/platform-page-inventory.md`，若设置页或学习页可见状态发生变化。
- `docs/testing/README.md`，若新增 media artifact 专项手动验证入口。
- `docs/review/INDEX.md` 或专项审查记录，若数据库 schema、包边界或隐私规则发生实际变更。

## 10. 设计方案

### 10.1 模块边界

推荐依赖方向：

```text
Core -> no concrete dependency
Data -> Core
Speech -> Core
App Shell -> Data / Speech / AI
UI -> Core through injected actions
```

本方案内：

```text
Core MediaArtifact models
Data GRDBMediaArtifactRepository
Data LocalMediaArtifactFileStore
Data LocalMediaArtifactStore
Speech TTSAudioFileValidator
Future SentenceAudioPlaybackCoordinator
  -> Data LocalMediaArtifactStore
  -> Core TTSAudioFileValidating protocol injected with Speech implementation / playback service
  -> AI TTS generation service
```

禁止：

- UI 直接拼文件路径或读写 `media_artifacts`。
- AI package 持有 AVFoundation 播放对象或本地文件生命周期。
- Speech package 读取 Provider secret、拼 TTS HTTP request、写 GRDB 或直接管理 media artifact metadata。
- Data package 发起 Provider 请求或持有 AVAudioPlayer 生命周期。
- UI、AI 或 Speech package 直接持有正式 media artifact 文件绝对路径。
- 文件名包含用户文本、Entry 标题、voice 明文、Provider secret、完整 Keychain account 或请求参数明文。

### 10.2 Core 领域模型

新增 Core 类型建议：

```swift
public struct MediaArtifact: Sendable, Equatable {
    public var id: String
    public var languageSpaceID: String
    public var owner: MediaArtifactOwner
    public var type: MediaArtifactType
    public var derivationKind: MediaArtifactDerivationKind
    public var derivationKeyHash: String
    public var relativeFilePath: String
    public var mimeType: String
    public var byteSize: Int64
    public var durationSeconds: Double?
    public var contentHash: String
    public var createdAt: Date
    public var lastAccessedAt: Date
    public var invalidatedAt: Date?
    public var deleteAfter: Date?
    public var backupPolicy: MediaArtifactBackupPolicy
    public var syncPolicy: MediaArtifactSyncPolicy
    public var exportPolicy: MediaArtifactExportPolicy
}
```

Owner 类型建议：

```swift
public enum MediaArtifactOwner: Sendable, Equatable {
    case entry(id: String)
    case learningMaterial(id: String)
    case learningMaterialSentence(materialID: String, sentenceIndex: Int)
    case practiceSession(id: String)
    case temporaryOperation(id: String)
}
```

Artifact type 第一阶段枚举建议：

```swift
public enum MediaArtifactType: String, Sendable, CaseIterable {
    case ttsSentenceAudio
    case ttsDocumentAudio
    case shadowingRecording
    case dictationRecording
    case ocrIntermediate
    case exportTemporary
}
```

第一阶段 repository 只需要支持 `ttsSentenceAudio` 的写入和查询；其他 enum 值用于 schema 和未来扩展边界，不在 UI 暴露。

TTS 专属 key 建议：

```swift
public struct TTSAudioArtifactKey: Sendable, Equatable {
    public var sentenceSource: TTSSentenceSource
    public var sentenceTextHash: String
    public var targetLanguageCode: String
    public var providerProfileID: String
    public var ttsEndpointID: String
    public var ttsVoiceProfileID: String
    public var adapterKind: String
    public var adapterVersion: String
    public var modelName: String
    public var voiceIDHash: String
    public var outputFormat: String
    public var sampleRate: Int?
    public var speed: Double?
    public var pitch: Double?
    public var volume: Double?
    public var instructionsHash: String?
    public var providerParametersHash: String?
    public var configurationFingerprint: String
}
```

Key hash 规则：

- 使用稳定字段顺序。
- 使用结构化 JSON 或等价 canonical string 后计算 SHA-256。
- 不把完整句子文本、voice 明文、instructions 明文、provider parameters 明文写入 key hash 输入之外的持久字段。
- key hash 可记录，原始敏感输入不进入日志或 diagnostic event。
- `ttsVoiceProfileID` 用于追踪当前 endpoint + language code 的 voice profile 生命周期；命中仍以 `configurationFingerprint` 和完整 key hash 为准，避免 voice profile 记录被同 id 更新后错误复用旧音频。

### 10.3 GRDB Schema

新增 migration：

```text
v7_create_media_artifact_infrastructure
```

通用表：

```sql
CREATE TABLE media_artifacts (
  id TEXT PRIMARY KEY,
  language_space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
  owner_type TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  owner_sub_id TEXT,
  artifact_type TEXT NOT NULL,
  derivation_kind TEXT NOT NULL,
  derivation_key_hash TEXT NOT NULL,
  relative_file_path TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL,
  duration_seconds REAL,
  content_hash TEXT NOT NULL,
  created_at REAL NOT NULL,
  last_accessed_at REAL NOT NULL,
  invalidated_at REAL,
  delete_after REAL,
  backup_policy TEXT NOT NULL,
  sync_policy TEXT NOT NULL,
  export_policy TEXT NOT NULL,
  CHECK (byte_size >= 0),
  CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  CHECK (artifact_type IN (
    'ttsSentenceAudio', 'ttsDocumentAudio', 'shadowingRecording',
    'dictationRecording', 'ocrIntermediate', 'exportTemporary'
  )),
  CHECK (backup_policy IN ('excludedFromSystemBackup', 'includedInSystemBackup')),
  CHECK (sync_policy IN ('localOnly', 'syncCandidate', 'syncManaged')),
  CHECK (export_policy IN ('excludedByDefault', 'includedInUserExport', 'includedInRecoverableBackup'))
)
```

TTS 专属表：

```sql
CREATE TABLE tts_audio_artifacts (
  artifact_id TEXT PRIMARY KEY REFERENCES media_artifacts(id) ON DELETE CASCADE,
  sentence_source_type TEXT NOT NULL,
  entry_id TEXT REFERENCES entries(id) ON DELETE CASCADE,
  learning_material_id TEXT REFERENCES learning_materials(id) ON DELETE CASCADE,
  sentence_index INTEGER,
  sentence_text_hash TEXT NOT NULL,
  target_language_code TEXT NOT NULL,
  provider_profile_id TEXT NOT NULL REFERENCES ai_provider_profiles(id) ON DELETE CASCADE,
  tts_endpoint_id TEXT NOT NULL REFERENCES ai_provider_endpoints(id) ON DELETE CASCADE,
  tts_voice_profile_id TEXT NOT NULL REFERENCES ai_provider_tts_voice_profiles(id) ON DELETE CASCADE,
  adapter_kind TEXT NOT NULL,
  adapter_version TEXT NOT NULL,
  model_name TEXT NOT NULL,
  voice_id_hash TEXT NOT NULL,
  output_format TEXT NOT NULL,
  sample_rate INTEGER,
  speed REAL,
  pitch REAL,
  volume REAL,
  instructions_hash TEXT,
  provider_parameters_hash TEXT,
  configuration_fingerprint TEXT NOT NULL,
  CHECK (sentence_index IS NULL OR sentence_index >= 0)
)
```

索引建议：

```sql
CREATE UNIQUE INDEX idx_media_artifacts_active_derivation_key
ON media_artifacts(artifact_type, derivation_kind, derivation_key_hash)
WHERE invalidated_at IS NULL;

CREATE INDEX idx_media_artifacts_language_type_accessed
ON media_artifacts(language_space_id, artifact_type, invalidated_at, last_accessed_at);

CREATE INDEX idx_media_artifacts_owner
ON media_artifacts(owner_type, owner_id, owner_sub_id, invalidated_at);

CREATE INDEX idx_tts_audio_artifacts_entry_material_sentence
ON tts_audio_artifacts(entry_id, learning_material_id, sentence_index);

CREATE INDEX idx_tts_audio_artifacts_provider_config
ON tts_audio_artifacts(provider_profile_id, tts_endpoint_id, tts_voice_profile_id, configuration_fingerprint);
```

Schema 取舍：

- `owner_type + owner_id + owner_sub_id` 是通用 owner 索引，支持 Entry、material、sentence、practice session 和 temporary operation。
- TTS 专属表可以额外引用 `entries` / `learning_materials`，用于级联删除和查询。
- `artifact_type + derivation_kind + derivation_key_hash` 在 active artifact 上唯一，防止同一类型同一 derivation key 重复写 ready 记录，同时为未来不同 artifact type 复用同一 hash 算法保留空间。
- `tts_voice_profile_id` 记录当前 endpoint + language code 的 voice profile 生命周期；voice profile 被删除时相关 TTS artifact metadata 级联删除。voice profile 被同 id 更新时，`configuration_fingerprint` 和完整 key hash 负责让旧音频不再命中。
- `invalidated_at` 不删除历史 metadata 时也能避免旧记录命中；容量清理可以删除 invalidated metadata 和文件。

### 10.4 文件存储

推荐根目录：

```text
Application Support/LangoTrace/MediaArtifacts/
```

推荐相对路径：

```text
ttsSentenceAudio/<language_space_id>/<artifact_id>.<extension>
```

规则：

- 文件扩展名来自 allowlist：`mp3`、`m4a`、`wav`、`aac`、`opus`，第一阶段至少支持 `mp3`。
- 文件名使用 `artifact_id` 或 `content_hash`，不使用原文、标题、voice 明文或 model 明文。
- 写入时先写 `staging/<operation_id>.tmp`，验证成功后原子 move 到正式路径。
- `MediaArtifacts` 根目录设置 excluded from backup。
- iOS 上可沿用 App container 默认保护；如果设置 file protection，应与数据库文件保护策略一致或更严格。

### 10.5 Core 协议与验证边界

Core 协议建议：

```swift
public protocol MediaArtifactRepository: Sendable {
    func ttsAudioArtifactMetadata(for key: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult
    func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact
    func invalidateArtifacts(_ request: MediaArtifactInvalidationRequest) async throws
    func artifactsForCleanup(_ request: MediaArtifactCleanupRequest) async throws -> [MediaArtifact]
    func deleteArtifactMetadata(artifactIDs: [String]) async throws
    func markAccessed(artifactID: String, at date: Date) async throws
}
```

Facade 协议建议：

```swift
public protocol LocalMediaArtifactStoring: Sendable {
    func ttsAudioArtifact(for key: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult
    func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact
    func invalidateArtifacts(_ request: MediaArtifactInvalidationRequest) async throws
    func cleanupArtifacts(_ request: MediaArtifactCleanupRequest) async throws -> MediaArtifactCleanupResult
}
```

持久文件验证协议建议：

```swift
public protocol TTSAudioFileValidating: Sendable {
    func validateTTSAudioFile(_ input: TTSAudioFileValidationInput) async -> TTSAudioFileValidationResult
}

public struct TTSAudioFileValidationInput: Sendable, Equatable {
    public var stagedFile: MediaArtifactStagedFileReference
    public var declaredFormat: TTSAudioFormat
    public var mimeType: String
    public var byteSizeLimit: Int64
}

public struct TTSAudioFileValidationResult: Sendable, Equatable {
    public var status: TTSAudioValidationStatus
    public var metadata: TTSAudioMetadata?
}
```

边界规则：

- `TTSAudioValidationService` 继续服务设置页 Provider probe，输入是短生命周期 audio bytes，可返回 memory preview resource。
- `TTSAudioFileValidating` 服务持久 media artifact 提交，输入是受控 staging reference，不返回 preview resource，不暴露正式绝对路径。
- `TTSAudioFileValidating` 协议放在 Core；默认实现 `TTSAudioFileValidator` 放在 Speech；Data 的 `LocalMediaArtifactStore` 只依赖 Core 协议，不依赖 Speech package。
- 如果实现中需要用 AVFoundation 打开文件，真实文件 URL 只在 Speech validator 与 Data file store 的受控 adapter 内短生命周期使用，不进入 UI、AI、Core 业务模型、诊断日志或 metadata。

Lookup result：

```swift
public enum MediaArtifactLookupResult: Sendable, Equatable {
    case hit(MediaArtifact)
    case miss
    case invalidated(reason: MediaArtifactInvalidationReason)
}
```

Commit input 必须只接受已经通过基础校验的文件：

```swift
public struct MediaArtifactStagedFileReference: Sendable, Equatable {
    public var relativeStagingPath: String
    public var byteSize: Int64
    public var contentHash: String
}

public struct TTSAudioArtifactCommitInput: Sendable {
    public var key: TTSAudioArtifactKey
    public var languageSpaceID: String
    public var owner: MediaArtifactOwner
    public var stagedFile: MediaArtifactStagedFileReference
    public var mimeType: String
    public var durationSeconds: Double?
    public var createdAt: Date
}
```

`MediaArtifactRepository` 是 metadata 边界；真实路径解析只能发生在 Data package 的 `LocalMediaArtifactFileStore`。UI、AI、Speech 和 Core 业务层不得依赖正式文件绝对路径。`LocalMediaArtifactStore` facade 必须在本方案内实现，组合 repository、file store 和 Core validator protocol，并只对 coordinator 暴露 hit / stage / validate / commit / cleanup 语义。后续 direct playback coordinator 不得自己编排 DB 与文件系统。

协议职责：

- `MediaArtifactRepository` 只返回 metadata、写 metadata、标记失效、更新时间和选择待清理 metadata。
- `LocalMediaArtifactStoring` 是后续 coordinator 使用的真实基础设施入口，负责调用 repository、file store 和 validator，并返回包含文件删除数量与 reclaimed bytes 的 cleanup result。
- `MediaArtifactCleanupResult.deletedFileCount`、`reclaimedBytes` 和 `failedFileCount` 只能由 facade / file store 计算，不能由纯 metadata repository 猜测。

并发边界：

- Repository 必须基于 `derivation_key_hash` 做幂等检查。
- 如果同一 key 已有 active ready metadata 且文件存在，commit 应返回现有 artifact 或显式 `alreadyExists(existingArtifact)`，不得创建重复行。
- 同一 key 并发 commit 时，唯一索引必须兜底；业务层 coordinator 后续仍应复用 in-flight task，避免重复请求 Provider。
- 如果两个并发 commit 先后完成文件 move，但其中一个因唯一索引冲突失败，失败方必须删除自己移动出的正式文件，返回现有 artifact 或稳定冲突结果。
- 由于 Repository 不解析文件路径，“文件存在”与“删除自己移动出的正式文件”由 facade 通过 file store 判断和处理；Repository 只返回 metadata 冲突或现有 active metadata。

### 10.6 文件与 Metadata 提交顺序

推荐顺序：

1. 生成服务拿到 audio bytes 后写入 staging 文件。
2. Speech 验证 staging 文件可解码，并返回 duration / format metadata。
3. File store 计算 content hash 和 byte size。
4. Repository 在 DB 中检查 active derivation key 是否已存在。
5. File store 将 staging 文件原子 move 到正式相对路径。
6. Repository 写入 `media_artifacts` 和 `tts_audio_artifacts` metadata。
7. 若 metadata 写入失败，删除正式文件。
8. 若 move 失败，不写 metadata。

`LocalMediaArtifactStore` facade 负责上述顺序，repository 只负责 metadata transaction，file store 只负责路径与文件操作。这样可以让 direct playback coordinator 调用一个基础设施入口，而不是自己编排 DB 与文件系统。

实现时可根据 GRDB transaction 与文件系统事务不可合一的事实调整顺序，但必须在方案或代码注释中明确失败恢复：

- metadata 存在但文件丢失：删除 metadata 或标记 invalidated，并按 miss 处理。
- 文件存在但 metadata 丢失：删除孤立文件。
- staging 文件残留：启动或 cleanup 时删除。

### 10.7 Hit / Miss / Invalidated 规则

命中必须同时满足：

- active metadata 存在。
- `invalidated_at IS NULL`。
- 文件存在。
- 文件可读。
- byte size 与 metadata 匹配。
- content hash 与 metadata 匹配，或在性能考虑下使用 size + optional hash 校验策略并在方案中记录。
- TTS artifact key hash 与查询 key hash 一致。
- configuration fingerprint 与当前 voice profile 最近成功测试 fingerprint 一致。

以下情况返回 miss 或 invalidated：

- metadata 不存在。
- 文件丢失。
- 文件不可读。
- 文件损坏或不可解码。
- sentence text hash 变化。
- target language code 变化。
- provider profile / endpoint / model / voice / format / sample rate / speed / pitch / volume / instructions / provider parameters / adapter version / configuration fingerprint 变化。
- Entry、LearningMaterial、语言空间、Provider profile、TTS endpoint 或 voice profile 被删除。

### 10.8 清理策略

第一阶段必须支持：

- 按 language space 删除。
- 按 owner 删除。
- 按 artifact type 删除。
- 删除 invalidated artifacts。
- 删除 `delete_after` 已过期 artifacts。
- 基于 `last_accessed_at` 的 LRU 清理。
- 基于总 byte size 的容量清理。
- 清理 staging 文件。
- 清理孤立 metadata 和孤立文件。

清理结果必须返回：

```swift
public struct MediaArtifactCleanupResult: Sendable, Equatable {
    public var deletedArtifactCount: Int
    public var deletedFileCount: Int
    public var reclaimedBytes: Int64
    public var failedFileCount: Int
}
```

### 10.9 诊断与隐私

允许记录：

- operation id。
- artifact type。
- provider preset id。
- endpoint purpose。
- model name。
- output format。
- cache hit / miss / invalidated。
- byte size bucket。
- duration bucket。
- error category。
- cleanup reclaimed byte bucket。

不得记录：

- 用户句子文本。
- 测试文本。
- complete request body。
- complete response body。
- audio bytes。
- API Key。
- Authorization header。
- 完整 Keychain account。
- voice 明文，除非后续 Provider 风险评估允许。
- instructions 明文。
- provider parameters 明文。
- 文件绝对路径。

### 10.10 AppEnvironment 与后续接入

本方案可以先不把真实 store 注入 UI，但应为后续装配预留：

```text
AppEnvironment
  mediaArtifactRepository
  mediaArtifactFileStore
  ttsAudioFileValidator
```

如果本阶段实际修改 `AppEnvironment`，必须提供 Disabled / InMemory / Noop 实现供 preview 和测试使用。若不修改 AppEnvironment，本方案完成标准中必须说明后续 direct playback 方案负责装配。

## 11. 实施方案

### 11.1 实施前检查

实施前运行：

```bash
rg -n "media_artifact|MediaArtifact|LocalMediaArtifact|tts_audio|TTSAudioArtifact|音频缓存|媒体派生资产" docs Packages LangoTraceApp
git status --short
```

人工确认：

- `docs/spec/007-data-storage-migration-export-and-attachments.md` 中媒体派生资产边界仍为当前规范。
- `docs/spec/011-tts-provider-configuration-and-playback.md` 中逐句 TTS 音频前置要求仍为当前规范。
- 本方案仍不实现真实 Provider 请求、逐句 UI 播放和跨设备同步。

### 11.2 测试先行：Core Key 与 Policy

新增 `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/MediaArtifactTests.swift` 或放入现有 Core test target，覆盖：

- `TTSAudioArtifactKey` 对同字段生成稳定 hash。
- 字段顺序变化不影响 canonical hash。
- 句子文本 hash、target language、voice profile id、voice hash、model、format、adapter version、configuration fingerprint 任一变化都会生成不同 key hash。
- 默认 policy 为 local only、excluded from backup、excluded by default from export。
- `TTSAudioFileValidating` 输入和结果不携带正式绝对路径，也不携带 preview resource。

聚焦命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter MediaArtifactTests
```

### 11.3 实现 Core 模型

新增 Core 文件：

- `MediaArtifact.swift`
- `TTSAudioArtifact.swift`
- `TTSAudioFileValidation.swift`

要求：

- 所有 public 模型 `Sendable`。
- enum raw value 与 DB CHECK 值一致。
- hash 计算只依赖 canonical representation。
- 不在模型中保存完整句子文本、instructions 明文或 provider parameters 明文。
- `TTSAudioFileValidating` 协议定义在 Core，Data 和 Speech 都依赖该协议而不是彼此依赖。

### 11.4 测试先行：GRDB Migration

新增或更新 `AppDatabaseTests`，覆盖：

- in-memory database 创建 `media_artifacts` 和 `tts_audio_artifacts`。
- `media_artifacts.derivation_key_hash` active 唯一索引存在并生效。
- `tts_audio_artifacts.artifact_id` 级联删除。
- `language_space_id` 外键生效。
- policy CHECK 约束拒绝非法值。
- artifact type CHECK 约束拒绝非法值。

聚焦命令：

```bash
swift test --package-path Packages/LangoTraceData --filter AppDatabaseTests
```

### 11.5 实现 Migration

修改 `AppDatabase.swift`：

- 注册 `v7_create_media_artifact_infrastructure`。
- 新增 `createMediaArtifactInfrastructure(_:)`。
- 创建通用 metadata 表、TTS 专属表和索引。
- 维持 `PRAGMA foreign_keys = ON`。

注意：

- 不依赖用户清空容器。
- 不改变既有 `v1` 到 `v6` migration 名称。
- 不在 migration 中创建真实媒体目录；目录属于 file store 初始化。

### 11.6 测试先行：File Store

新增 `LocalMediaArtifactFileStoreTests`，覆盖：

- 初始化时创建 `MediaArtifacts` 根目录。
- 根目录设置 excluded from backup。
- staging 写入后可以原子 move 到正式相对路径。
- 正式相对路径不包含原文或 voice 明文。
- 删除 artifact 文件返回 reclaimed bytes。
- 清理 staging 残留文件。
- 路径 traversal 输入被拒绝，例如 `../secret.mp3`。

聚焦命令：

```bash
swift test --package-path Packages/LangoTraceData --filter LocalMediaArtifactFileStoreTests
```

### 11.7 实现 File Store

新增 `LocalMediaArtifactFileStore.swift`：

- 管理 `MediaArtifacts` 根目录。
- 提供 staging 写入、atomic move、delete、exists、readable、content hash、byte size。
- 对所有 relative path 做规范化校验，禁止绝对路径和 `..`。
- 设置 root directory excluded from backup。
- 不知道 Provider、sentence text 或 TTS 配置。

### 11.8 测试先行：LocalMediaArtifactStore Facade

新增 `LocalMediaArtifactStoreTests` 或并入 `MediaArtifactRepositoryTests`，覆盖：

- facade 调用 file store 写 staging、调用 validator、调用 repository commit，成功后返回 ready artifact。
- validator 失败时删除 staging，不写 metadata。
- repository commit 因唯一索引冲突返回现有 artifact 时，facade 删除本次 staging 或已移动文件。
- file store move 成功但 metadata 写入失败时，facade 清理正式文件。
- lookup hit 时 facade 校验文件存在、byte size、content hash，并更新 `last_accessed_at`。
- lookup 发现 metadata / 文件不一致时，facade 调用 invalidation 或 cleanup，并返回 miss / invalidated。

聚焦命令：

```bash
swift test --package-path Packages/LangoTraceData --filter LocalMediaArtifactStoreTests
```

### 11.9 实现 LocalMediaArtifactStore Facade

新增 `LocalMediaArtifactStore.swift`：

- 组合 `GRDBMediaArtifactRepository`、`LocalMediaArtifactFileStore` 和可注入的 audio validator 协议。
- 实现 Core `LocalMediaArtifactStoring` facade 协议。
- 对 direct playback coordinator 暴露单一 hit / stage / validate / commit / cleanup 入口。
- 不发起 Provider 请求。
- 不播放音频。
- 不记录敏感文本。
- 把 DB / 文件系统不可合一事务的失败恢复收口在一个地方，避免后续 UI 或 coordinator 自己处理半成品文件。

### 11.10 测试先行：Repository Hit / Commit / Invalidated

新增 `MediaArtifactRepositoryTests`，覆盖：

- commit TTS audio artifact 后可按同 key hit。
- hit 更新 `last_accessed_at`。
- 同 key 二次 commit 不创建重复 active artifact。
- key 任一关键字段变化返回 miss。
- repository 层不读取文件系统；文件丢失和 content hash 不匹配由 `LocalMediaArtifactStoreTests` 覆盖。
- `invalidateArtifacts` 可按 owner、language space、artifact type、provider profile、endpoint 和 configuration fingerprint 标记失效。
- 删除 Entry 或 LearningMaterial 后相关 TTS metadata 不再 active hit。
- cleanup invalidated artifacts 删除 metadata；文件删除由 facade/file store cleanup 覆盖。
- cleanup by capacity 选择 LRU 顺序返回待删 artifact 或通过 facade 删除最久未访问 artifact；不得在 repository 内直接拼文件路径。

聚焦命令：

```bash
swift test --package-path Packages/LangoTraceData --filter MediaArtifactRepositoryTests
```

### 11.11 实现 Repository

新增 `GRDBMediaArtifactRepository.swift`：

- 实现 Core `MediaArtifactRepository`。
- 使用 `DatabaseQueue.read` / `write`。
- 使用可注入 clock 和 id generator。
- 只管理 metadata 查询、写入、失效、访问时间和 cleanup selection；不得直接访问文件系统或解析绝对路径。
- commit 时处理唯一索引冲突并返回现有 active artifact。
- cleanup selection 返回待删除 metadata；真实 `MediaArtifactCleanupResult` 由 facade 汇总 file store 删除结果后返回。
- 诊断输出只使用非敏感分类；如果接入 DiagnosticLogger，必须 best-effort、non-throwing。

### 11.12 测试先行：Speech 音频验证 Seam

`Packages/LangoTraceSpeech/Package.swift` 当前已有 `LangoTraceSpeechTests` test target；仅当新增 fixture resources 或测试依赖时修改 Package.swift。新增 `TTSAudioFileValidatorTests`，覆盖：

- 空文件返回 `audioDecodeFailed` 或等价稳定错误。
- 非音频 bytes 返回 `audioDecodeFailed`。
- 超过 size limit 的文件返回 `audioTooLarge` 或等价稳定错误。
- 支持的最小 fixture 音频返回 duration / format metadata。

如果当前测试环境难以稳定生成音频 fixture，可第一阶段测试 validator 的前置检查和错误映射，并在方案实施记录中说明真实 AVFoundation 解码需在后续 playback service 中补充模拟器 / 真机验证。

聚焦命令：

```bash
swift test --package-path Packages/LangoTraceSpeech
```

### 11.13 实现 Speech 验证

新增 `TTSAudioFileValidator.swift`：

- 使用 AVFoundation 或平台可用 API 验证音频文件可打开、duration 合法、格式可识别。
- 不播放音频。
- 不读取 Provider secret。
- 不写数据库。
- 不记录完整文件路径到诊断。

### 11.14 集成边界测试

新增 Data / Speech 可组合测试或在 Data tests 中用 fake validator 覆盖：

- fake TTS bytes 先写 staging，再经 fake validator 返回 metadata，再 commit 成 ready artifact。
- validator 失败时不写 ready metadata，staging 被清理。
- commit 后 lookup hit，cleanup 后 lookup miss。

命令：

```bash
swift test --package-path Packages/LangoTraceData --filter MediaArtifact
swift test --package-path Packages/LangoTraceSpeech
```

### 11.15 文档与装配收口

实施完成后：

- 更新 `docs/spec/007-data-storage-migration-export-and-attachments.md` 的“当前代码已有”事实，说明 media artifact schema 已落地。
- 更新 `docs/spec/011-tts-provider-configuration-and-playback.md` 的播放前置状态，说明本地媒体派生资产基础设施已具备。
- 更新 `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md`，把本方案从前置待建改为前置已完成或引用本方案实施结果。
- 如 AppEnvironment 装配了真实服务，更新 `docs/spec/004-swiftui-architecture.md` 或相关架构说明。
- 如未装配 UI，明确后续 direct playback 方案负责装配。
- 更新 `scripts/verify.sh`，将 `swift test --package-path Packages/LangoTraceSpeech` 纳入完整验证。若暂时不修改脚本，必须在实施记录中写明原因和剩余风险；默认推荐修改。

## 12. 复查方法

代码复查重点：

- `media_artifacts` 和 `tts_audio_artifacts` schema 是否有外键、CHECK、索引和唯一 active derivation key。
- Repository 是否不保存完整句子文本、instructions 明文、provider parameters 明文、audio bytes 或 secret。
- File store 是否禁止路径 traversal 和绝对路径。
- File store 是否设置 excluded from backup。
- commit 是否有半成品清理和 metadata / file 不一致恢复。
- cleanup 是否不会删除 MediaArtifacts 根目录外的文件。
- Data package 是否没有 Provider request 或 AVAudioPlayer 生命周期。
- Speech package 是否没有 Provider secret 或 GRDB 依赖。
- UI 是否没有直接访问文件路径或 media artifact table。

文档复查重点：

- `007`、`011`、direct playback plan 和 local media artifact architecture note 是否描述一致。
- 本方案是否仍然只做基础设施，不越界实现 Provider 请求、逐句 UI 播放、同步或导出。
- 未来能力是否继续留在 architecture note 或后续 active plan，而不是伪装成已实现。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter MediaArtifactTests
swift test --package-path Packages/LangoTraceData --filter AppDatabaseTests
swift test --package-path Packages/LangoTraceData --filter LocalMediaArtifactFileStoreTests
swift test --package-path Packages/LangoTraceData --filter LocalMediaArtifactStoreTests
swift test --package-path Packages/LangoTraceData --filter MediaArtifactRepositoryTests
swift test --package-path Packages/LangoTraceSpeech
```

完整验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceSpeech
scripts/verify.sh
```

文档验证：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 14. 文档影响检查

本任务涉及数据库 schema、媒体文件存储、TTS、Speech、隐私、诊断、导出、备份和同步前置边界，属于必须做文档影响检查的任务。

实施完成后至少检查：

- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md`
- `docs/review/INDEX.md`

若后续决定把 TTS 音频纳入同步、导出、备份、官方服务或用户可见资产管理，必须新增或更新对应 ADR / spec / architecture 文档。

## 15. 实施记录

- 2026-05-23：创建方案。当前仅定义本地媒体派生资产存储与 TTS audio artifact 基础设施，不实施代码。该方案是逐句直接播放 TTS 音频的前置方案之一，与 TTS Provider 配置测试方案并列依赖。

## 16. 完成标准

本任务完成时必须同时满足：

- Core 已定义媒体派生资产、TTS audio artifact key、policy、lookup result、commit input、cleanup result 和错误类型。
- Data 已新增 `media_artifacts` 和 `tts_audio_artifacts` migration、repository、file store、`LocalMediaArtifactStore` facade 和清理能力。
- Speech 已在现有 `LangoTraceSpeechTests` test target 下提供 TTS 音频文件验证 seam，并有明确的可自动化测试覆盖。
- TTS audio artifact 可以按 key hit / miss / invalidated。
- 同 key 重复 commit 不创建重复 active artifact。
- metadata 与文件不一致时有可测试恢复路径。
- 文件写入使用 staging 和原子移动，失败时不留下 ready metadata。
- MediaArtifacts 根目录默认 excluded from backup。
- policy 默认值为 local only、excluded from system backup、excluded by default from export。
- TTS metadata 保存 `tts_voice_profile_id`，并以完整 derivation key hash 与 `configuration_fingerprint` 保证 voice profile 更新后旧音频不再命中。
- `GRDBMediaArtifactRepository` 不访问文件系统；文件验证、路径解析、孤立文件清理和 cleanup result 汇总全部由 `LocalMediaArtifactStore` facade / `LocalMediaArtifactFileStore` 负责。
- 日志和诊断不包含句子原文、请求体、响应体、audio bytes、API Key、Authorization header、完整 Keychain account、instructions 明文、provider parameters 明文或文件绝对路径。
- cleanup 支持 invalidated、owner、language space、artifact type、capacity / LRU 和 staging 残留。
- direct playback coordinator 后续只需要调用 `LocalMediaArtifactStore`，不需要自己拼文件路径、写 metadata 或处理半成品文件。
- `scripts/verify.sh` 默认纳入 `swift test --package-path Packages/LangoTraceSpeech`，除非实施记录明确说明暂缓原因和剩余风险。
- 聚焦测试和完整验证通过，或记录无法运行的具体原因和剩余风险。
- 文档影响检查完成，相关事实源不再把 TTS 音频描述为临时 UI 缓存。

## 17. 剩余风险

- AVFoundation 在 macOS / iOS 模拟器上的解码行为可能存在平台差异，Speech validator 需要尽量使用稳定 fixture，并保留真机 / 模拟器手动验证入口。
- 文件系统和 SQLite 事务无法形成单一原子事务，必须通过失败恢复和清理任务降低不一致风险。
- 如果后续 Provider 返回流式音频，本方案的“完整文件验证后提交”模型需要扩展 streaming artifact 状态；当前不提前实现。
- 如果未来把 TTS 音频纳入同步或导出，当前 local only policy 需要通过单独方案升级，不得直接复用本地文件路径作为同步对象。
- 如果后续做跨 Entry 全局去重，必须重新评估隐私、删除传播和用户预期；当前稳定来源纳入 key 是更安全的第一阶段设计。

## 18. 开发原则符合性自查

早期可推倒重来：

- 本方案不迁就当前 `SentencePairView` 的临时 `@State` 播放反馈，也不把临时 UI 行为包装成长期架构。
- 本方案要求新增真实 media artifact 基础设施，而不是在现有空 `SpeechService` 或 UI 组件里堆临时文件逻辑。

基础设施一次搭完整：

- 本方案不只为逐句 TTS 建单点缓存，而是定义通用 media artifact schema、repository、file store、facade、policy、清理、失效、测试和诊断边界。
- 第一阶段只开放 `ttsSentenceAudio` 写入和查询，但 schema 和 enum 明确预留全文朗读、跟读录音、听写录音、OCR 中间文件和导出临时产物。
- 本方案将 metadata repository 与文件系统 facade 拆开，避免一开始把数据库、文件路径、音频验证和清理策略混成难以扩展的单体对象。

规范文档可演进：

- 本方案依赖并延续 `007` 和 `011` 的最新 media artifact 规范。
- 实施完成后必须回写 `007`、`011`、direct playback plan，以及必要时的 `004` 和 review 记录，确保 docs 继续作为 AI 辅助开发的全局事实源。

未来扩展进入备忘录：

- 跨设备音频同步、批量预生成、全文朗读、跟读录音、听写录音、后台播放、导出和附件化不在当前阶段提前实现。
- 这些扩展已进入 `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`，后续采纳时必须提升为 active plan、正式 spec、architecture 文档或 ADR。
