# media-artifacts 实现地图

状态：Current Implementation Map

最后更新：2026-06-17

## 1. 对应规范

- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/plans/done/2026-05-25-feature-practice-shadowing-recording-completion.md`

## 2. 阶段零 API review 结论

2026-05-26 练习跟读录音任务实施前完成阶段零 review，结论如下：

- `media_artifacts` 是长期通用主表，不是 TTS 专属表。TTS、跟读录音、听写录音、OCR 中间文件、导出临时产物等都应共享 language space、owner、artifact type、derivation kind / key hash、相对路径、MIME、byte size、duration、content hash、file state、created / last accessed、invalidated / delete after、backup / sync / export policy 等通用字段。
- typed metadata 必须放在扩展表中。TTS 继续使用 `tts_audio_artifacts`；练习录音应新增 `practice_recording_artifacts` 或等价 typed extension metadata，不能写入 `tts_audio_artifacts`。
- 代码 public surface 当前仍偏 TTS：`MediaArtifactRepository`、`LocalMediaArtifactStoring` 和 `LocalMediaArtifactStore` 暴露 `ttsAudioArtifact` / `reserveTTSAudioArtifact` / `commitTTSAudioArtifact` 等方法。练习录音落地前应提升出通用 `MediaArtifactCommitInput`、`MediaArtifactCommitReservation`、`MediaArtifactLookupKey`、ready 标记、resolver 和 cleanup contract；TTS convenience wrapper 可以保留，但底层必须走通用 commit / lookup / resolver。
- 数据库 `derivation_kind` CHECK 必须允许 `ttsAudio` 和 `practiceRecording`。既有旧库可能仍停留在只允许 `ttsAudio` 的 schema，`v10_allow_practice_recording_media_derivation_kind` 负责重建 `media_artifacts` 表并保留既有 metadata。
- 通用 commit contract 的职责边界是：repository 只创建 / 查询 / 标记 metadata；file store 只管理 App 管理目录、staging、hash、原子 move 和删除；facade / service 负责编排验证、reservation、move、ready 标记、失败补偿和 cleanup。
- `file_state = pending` 的 metadata 不得被 lookup 当作 ready hit；文件 move 成功但 ready 标记失败时必须由 recovery / cleanup 处理，不得向 UI 暴露 ready 录音。
- completed practice recording 是用户练习证据，不是普通可重建缓存。被 `practice_sessions.completed_recording_id` 引用的 artifact 不得进入普通容量 LRU、TTS cache cleanup 或派生缓存清理候选。
- completed recording 文件缺失或 hash mismatch 时，不得把 completed session 改回未完成；repository / UI 应保留 completed session，并把 playback source 标为 unavailable / missing。
- practice recording 默认 local-only、excluded from system backup、excluded from default export。同步、默认导出或可恢复备份需要独立方案定义 manifest、加密、删除传播和恢复策略。

## 3. 当前实现

- Core 通用模型：`Packages/LangoTraceCore/Sources/LangoTraceCore/MediaArtifact.swift`
- Core TTS artifact key：`Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`
- Core practice recording artifact key：`Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeRecordingArtifact.swift`
- Core photo attachment model：`Packages/LangoTraceCore/Sources/LangoTraceCore/EntryPhotoAttachment.swift`
- Data metadata repository：`Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`
- Data file store：`Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactFileStore.swift`
- Data facade：`Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift`
- Data playback resolver：`Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactPlaybackSourceResolver.swift`
- Data photo attachment repository：`Packages/LangoTraceData/Sources/LangoTraceData/GRDBEntryPhotoAttachmentRepository.swift`
- Data photo import pipeline：`Packages/LangoTraceData/Sources/LangoTraceData/PhotoImportPipeline.swift`
- UI photo display actions environment key：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoDisplayActions.swift`
- DB schema：`Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- Test coverage：`Packages/LangoTraceData/Tests/LangoTraceDataTests/AppDatabaseTests.swift`、`MediaArtifactRepositoryTests.swift`、`LocalMediaArtifactStoreTests.swift`、`LocalMediaArtifactFileStoreTests.swift`、`MediaArtifactPlaybackSourceResolverTests.swift`、`MediaArtifactPhotoMigrationTests.swift`、`PhotoAttachmentRepositoryTests.swift`、`PhotoImportPipelineTests.swift`；UI 照片写作保存闭环：`Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/PhotoWritingSaveFlowTests.swift`

当前已经实现：

- `media_artifacts` / `tts_audio_artifacts` metadata。
- `practice_recording_artifacts` typed metadata，以及 `MediaArtifactDerivationKind.practiceRecording`。
- `v10_allow_practice_recording_media_derivation_kind` 旧库迁移，覆盖已有 v9 数据库中 `derivation_kind` CHECK 只允许 `ttsAudio` 时无法写入练习录音 artifact 的问题。
- `v17_add_photo_artifact_types` 迁移：扩展 `media_artifacts.artifact_type` CHECK 允许 `entryPhotoOriginal` / `entryPhotoThumbnail`；新建 `entry_photo_attachments` 表（`id`、`entry_id`、`language_space_id`、`original_artifact_id`、`thumbnail_artifact_id`、`status`、`width`、`height`、`exif_stripped`、`created_at`、`sort_order`）及对应索引。
- `v19_ensure_entry_photo_attachments` / `v20_backfill_entry_photo_attachments_from_media_artifacts` 旧库修复迁移：v19 修复已经记录旧 v17 但缺失 `entry_photo_attachments` 表的数据库；v20 对已有 ready `entryPhotoOriginal` media artifact metadata 但缺少 attachment row 的旧库状态生成 repair row。没有 `media_artifacts` metadata 的历史孤立文件不自动猜测绑定到 entry。
- pending / ready file state。
- TTS derivation key lookup、reservation、commit、ready 标记、precise invalidation、metadata deletion 和 cleanup selection。
- Practice recording derivation key lookup、reservation、commit、ready 标记和与 `practice_recordings` / `practice_sessions.completed_recording_id` 的 cleanup exclusion。
- 按 session id / recording id 解析 ready practice recording artifact metadata，用于用户录音回放前的 repository 级校验。
- App 管理的 `MediaArtifacts` 目录、staging 写入、相对路径校验、hash、move、删除和 staging cleanup。
- TTS 和 practice recording facade 编排文件验证、reservation、move、ready 标记和失败补偿。
- playback source resolver 校验 metadata 与文件 byte size / hash 一致后才返回本地 URL；单句练习页已接入录音回放入口，文件缺失或 hash mismatch 时保持 completed session 并向 UI 返回不可播放失败。
- `PhotoImportPipeline`：从用户选择的原始 `PHAsset` 出发，经过 EXIF GPS 元数据剥离、内容 hash 计算、缩略图生成、staging 写入、原子 move 和 `GRDBEntryPhotoAttachmentRepository` 元数据事务的完整写入流水线；metadata 事务失败时清理已经 move 到永久目录的 original / thumbnail 文件，避免产生无 metadata / attachment 的孤立照片文件；原始照片（`entryPhotoOriginal`）是用户主资产，`delete_after = NULL`，不进入 LRU 或派生缓存清理；缩略图（`entryPhotoThumbnail`）是可重建派生资产，可精确失效。照片字节不得发送给任何 AI Provider。
- `GRDBEntryPhotoAttachmentRepository.photoRelativePath(forEntryID:)`：通过 SQL JOIN `media_artifacts`，以 `COALESCE(thumbnail_artifact_id, original_artifact_id)` 为优先策略返回最佳可用照片的 `relative_file_path`，供 `PhotoDisplayActions` 加载显示用。
- `PhotoDisplayActions`：SwiftUI `@Environment` key（`\.photoDisplayActions`），封装 `loadPhotoData(entryID:) async -> Data?`；`AppEnvironment` 在启动时通过 `GRDBEntryPhotoAttachmentRepository` + `LocalMediaArtifactFileStore` 装配真实实现；App 根视图通过 `.environment(\.photoDisplayActions, ...)` 注入；UI 层不直接持有文件路径。
- 照片主资产和派生资产均默认 `local-only`、`excluded from system backup`、`excluded by default from export`，不进入普通 LRU 清理，不进入同步。

## 4. 已知偏差

- public facade 仍保留 TTS convenience wrapper，并新增 practice recording wrapper；底层 commit / lookup 已按通用 `MediaArtifactRepository` / `LocalMediaArtifactStoring` contract 扩展，但尚未抽出完全类型擦除的 generic public API。
- cleanup 已排除 completed practice recording，但仍缺少面向用户的存储管理 UI 和显式删除 recording / session 的完整文件删除补偿流程。
- pending recovery 目前只通过 cleanup / metadata delete 间接处理；练习录音需要区分可删除的 TTS cache pending 和被 session 引用的用户录音 pending / missing 状态。
- completed recording missing / unavailable 已在单句练习页通过回放失败状态暴露；仍需要后续存储管理 UI 定义用户主动删除、重新录制后是否清理旧录音、以及删除 session 时的文件补偿策略。

## 5. 复查方法

练习录音无法回放、staging 文件未晋升为 ready artifact、或旧库 schema 约束疑似漂移时，优先按 `docs/testing/practice-recording-troubleshooting.md` 排查。

照片不显示、图片数据返回 nil 或 `photoRelativePath` 返回 nil 时，检查 `entry_photo_attachments` 是否有对应行、`media_artifacts` 的 `file_state` 是否为 ready，以及 `LocalMediaArtifactFileStore` 是否能找到对应相对路径文件。若只有 `MediaArtifacts/entryPhotoOriginal` 文件、但没有 `media_artifacts` metadata，不能安全自动恢复到具体 entry；应显示缺失态并避免后续导入继续产生孤立文件。

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
rg "MediaArtifact|LocalMediaArtifactStore|ttsAudioArtifact|commitTTSAudioArtifact|derivation_kind|practiceRecording|entryPhotoOriginal|entryPhotoThumbnail|PhotoImportPipeline|PhotoDisplayActions|photoRelativePath" Packages/LangoTraceCore Packages/LangoTraceData Packages/LangoTraceUI docs/spec docs/plans
scripts/verify.sh
```
