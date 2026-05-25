# media-artifacts 实现地图

状态：Current Implementation Map

最后更新：2026-05-26

## 1. 对应规范

- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/plans/done/2026-05-25-feature-practice-shadowing-recording-completion.md`

## 2. 阶段零 API review 结论

2026-05-26 练习跟读录音任务实施前完成阶段零 review，结论如下：

- `media_artifacts` 是长期通用主表，不是 TTS 专属表。TTS、跟读录音、听写录音、OCR 中间文件、导出临时产物等都应共享 language space、owner、artifact type、derivation kind / key hash、相对路径、MIME、byte size、duration、content hash、file state、created / last accessed、invalidated / delete after、backup / sync / export policy 等通用字段。
- typed metadata 必须放在扩展表中。TTS 继续使用 `tts_audio_artifacts`；练习录音应新增 `practice_recording_artifacts` 或等价 typed extension metadata，不能写入 `tts_audio_artifacts`。
- 代码 public surface 当前仍偏 TTS：`MediaArtifactRepository`、`LocalMediaArtifactStoring` 和 `LocalMediaArtifactStore` 暴露 `ttsAudioArtifact` / `reserveTTSAudioArtifact` / `commitTTSAudioArtifact` 等方法。练习录音落地前应提升出通用 `MediaArtifactCommitInput`、`MediaArtifactCommitReservation`、`MediaArtifactLookupKey`、ready 标记、resolver 和 cleanup contract；TTS convenience wrapper 可以保留，但底层必须走通用 commit / lookup / resolver。
- 数据库当前 `derivation_kind` CHECK 只允许 `ttsAudio`。练习录音 migration 必须新增 `practiceRecording`，并同步更新 Core enum、mapper、fixture 和迁移测试。
- 通用 commit contract 的职责边界是：repository 只创建 / 查询 / 标记 metadata；file store 只管理 App 管理目录、staging、hash、原子 move 和删除；facade / service 负责编排验证、reservation、move、ready 标记、失败补偿和 cleanup。
- `file_state = pending` 的 metadata 不得被 lookup 当作 ready hit；文件 move 成功但 ready 标记失败时必须由 recovery / cleanup 处理，不得向 UI 暴露 ready 录音。
- completed practice recording 是用户练习证据，不是普通可重建缓存。被 `practice_sessions.completed_recording_id` 引用的 artifact 不得进入普通容量 LRU、TTS cache cleanup 或派生缓存清理候选。
- completed recording 文件缺失或 hash mismatch 时，不得把 completed session 改回未完成；repository / UI 应保留 completed session，并把 playback source 标为 unavailable / missing。
- practice recording 默认 local-only、excluded from system backup、excluded from default export。同步、默认导出或可恢复备份需要独立方案定义 manifest、加密、删除传播和恢复策略。

## 3. 当前实现

- Core 通用模型：`Packages/LangoTraceCore/Sources/LangoTraceCore/MediaArtifact.swift`
- Core TTS artifact key：`Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`
- Core practice recording artifact key：`Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeRecordingArtifact.swift`
- Data metadata repository：`Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`
- Data file store：`Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactFileStore.swift`
- Data facade：`Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift`
- Data playback resolver：`Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactPlaybackSourceResolver.swift`
- DB schema：`Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- Test coverage：`Packages/LangoTraceData/Tests/LangoTraceDataTests/AppDatabaseTests.swift`、`MediaArtifactRepositoryTests.swift`、`LocalMediaArtifactStoreTests.swift`、`LocalMediaArtifactFileStoreTests.swift`、`MediaArtifactPlaybackSourceResolverTests.swift`

当前已经实现：

- `media_artifacts` / `tts_audio_artifacts` metadata。
- `practice_recording_artifacts` typed metadata，以及 `MediaArtifactDerivationKind.practiceRecording`。
- pending / ready file state。
- TTS derivation key lookup、reservation、commit、ready 标记、precise invalidation、metadata deletion 和 cleanup selection。
- Practice recording derivation key lookup、reservation、commit、ready 标记和与 `practice_recordings` / `practice_sessions.completed_recording_id` 的 cleanup exclusion。
- App 管理的 `MediaArtifacts` 目录、staging 写入、相对路径校验、hash、move、删除和 staging cleanup。
- TTS 和 practice recording facade 编排文件验证、reservation、move、ready 标记和失败补偿。
- playback source resolver 校验 metadata 与文件 byte size / hash 一致后才返回本地 URL。

## 4. 已知偏差

- public facade 仍保留 TTS convenience wrapper，并新增 practice recording wrapper；底层 commit / lookup 已按通用 `MediaArtifactRepository` / `LocalMediaArtifactStoring` contract 扩展，但尚未抽出完全类型擦除的 generic public API。
- cleanup 已排除 completed practice recording，但仍缺少面向用户的存储管理 UI 和显式删除 recording / session 的完整文件删除补偿流程。
- pending recovery 目前只通过 cleanup / metadata delete 间接处理；练习录音需要区分可删除的 TTS cache pending 和被 session 引用的用户录音 pending / missing 状态。
- playback source resolver 当前仍主要服务 TTS 播放；completed recording missing / unavailable 的用户可见回放状态需要后续练习回放 UI 方案补强。

## 5. 复查方法

```bash
swift test --package-path Packages/LangoTraceData
rg "MediaArtifact|LocalMediaArtifactStore|ttsAudioArtifact|commitTTSAudioArtifact|derivation_kind|practiceRecording" Packages/LangoTraceCore Packages/LangoTraceData docs/spec docs/plans/active
scripts/verify.sh
```
