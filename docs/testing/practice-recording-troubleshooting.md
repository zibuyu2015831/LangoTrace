# 练习录音回放故障排查 Runbook

状态：Current Runbook

最后更新：2026-05-26

## 1. 适用场景

当单句练习页出现以下现象时，按本文档排查：

- 点击 `开始录音` 后能停止，但 `回放录音` 没有变为可用。
- 页面提示录音不能保存为可回放音频。
- 完成态、回放态或最近一次录音状态与实际操作不一致。

本文档只覆盖本地练习录音、media artifact 和 GRDB metadata 链路。不覆盖发音评分、ASR、同步、导出或 AI Provider 上传。

## 2. 成功链路

停止录音后的成功链路应为：

1. `PracticeSessionViewModel.stopRecording()` 调用 `PracticeActions.stopRecording`。
2. `PracticeActionsAssembly.stopRecording` 依次执行 `recordingService.stop`、`mediaStore.commitPracticeRecordingArtifact`、`repository.session(id:)`。
3. `AppPracticeRecordingEngine.stop` 读取 staging `.m4a`，返回 `MediaArtifactStagedFileReference`。
4. `LocalMediaArtifactStore.commitPracticeRecordingArtifact` 将 staging 文件移动到 `shadowingRecording/<language>/<artifactID>.m4a`。
5. `GRDBMediaArtifactRepository` 写入并标记：
   - `media_artifacts.file_state = 'ready'`
   - `media_artifacts.derivation_kind = 'practiceRecording'`
   - `practice_recordings.status = 'ready'`
   - `practice_recording_artifacts` typed metadata
6. `GRDBPracticeRepository.session(id:)` 读回 `latestReadyRecordingID`。
7. `PracticeControlBar` 根据 `session.latestReadyRecordingID != nil` 启用 `回放录音`。

## 3. 快速定位顺序

先采集最新日志：

```bash
scripts/capture-runtime-log --last 30m
```

查找关键事件：

```bash
rg -n "practice_recording|recording_stop|artifact_commit|session_reload|AVAudio|AudioQueue|microphone|MediaArtifacts|LangoTrace" logs/latest.log
```

定位当前模拟器 App 容器：

```bash
xcrun simctl get_app_container booted com.zibuyu.LangoTrace data
```

如果日志中已有 `MediaArtifacts` 路径，也可以直接从日志复制容器路径。

## 4. 分层判断

### 4.1 权限层

日志中应能看到麦克风权限为 Allowed。若权限被拒绝，优先验证 Info.plist purpose string、模拟器隐私设置和 `PracticeRecordingServiceTests`。

### 4.2 音频文件层

检查 staging 和正式 artifact 文件：

```bash
APP_CONTAINER="$(xcrun simctl get_app_container booted com.zibuyu.LangoTrace data)"
find "$APP_CONTAINER/Library/Application Support/LangoTrace/MediaArtifacts" -maxdepth 6 -type f -ls | sort -k11 | tail -80
```

判断：

- 没有 staging 文件：重点查 `recordingService.stop`、`AppPracticeRecordingEngine.stop` 和系统音频日志。
- 只有 `staging/*.m4a`，没有 `shadowingRecording/.../*.m4a`：重点查 artifact commit、文件 move、数据库 INSERT / CHECK / FK。
- 有正式 `shadowingRecording` 文件但 UI 不可回放：重点查 `practice_recordings.status`、`media_artifacts.file_state`、session reload 和 playback resolver。

### 4.3 Metadata 层

查询数据库：

```bash
DB="$APP_CONTAINER/Library/Application Support/LangoTrace/LangoTrace.sqlite"

sqlite3 -header -column "$DB" "select id, status, media_artifact_id, duration_seconds, byte_size, content_hash, created_at, ready_at, invalidated_at from practice_recordings order by created_at desc limit 10;"

sqlite3 -header -column "$DB" "select id, artifact_type, derivation_kind, file_state, relative_file_path, mime_type, byte_size, duration_seconds, content_hash, created_at, invalidated_at from media_artifacts order by created_at desc limit 20;"

sqlite3 -header -column "$DB" "select artifact_id, session_id, recording_id, attempt_number, target_language_code, recording_format, duration_seconds, content_hash from practice_recording_artifacts order by artifact_id desc limit 10;"

sqlite3 -header -column "$DB" "select id, status, completed_recording_id, created_at, updated_at from practice_sessions order by updated_at desc limit 10;"
```

判断：

- `practice_recordings` 和 `practice_recording_artifacts` 为空，但 staging 文件存在：commit 前或 INSERT 阶段失败。
- `media_artifacts.file_state = 'pending'`：文件 move 或 ready 标记失败。
- `practice_recordings.status != 'ready'`：ready 标记失败。
- `latestReadyRecordingID` 未刷新但 metadata ready：查 `GRDBPracticeRepository.session(id:)` 查询条件和 App assembly postcondition。

### 4.4 Schema 层

检查迁移和建表约束：

```bash
sqlite3 -header -column "$DB" "select identifier from grdb_migrations order by identifier;"
sqlite3 -header -column "$DB" "select sql from sqlite_master where type='table' and name='media_artifacts';"
sqlite3 -header -column "$DB" "PRAGMA foreign_key_check;"
```

练习录音必须满足：

- `grdb_migrations` 包含 `v10_allow_practice_recording_media_derivation_kind`。
- `media_artifacts` 的 `derivation_kind` CHECK 包含 `('ttsAudio', 'practiceRecording')`。
- `PRAGMA foreign_key_check` 为空。

2026-05-26 的回放故障根因就是旧库仍停留在 `CHECK (derivation_kind IN ('ttsAudio'))`，导致 `practiceRecording` artifact INSERT 失败，事务回滚，录音文件只留在 staging。

## 5. 诊断事件

练习录音失败使用 allowlisted diagnostic event：

- event name：`practice_recording.failed`
- domain：`practice_recording`
- phase：`recording_stop`、`artifact_commit`、`session_reload`
- error category：稳定错误分类，不记录句子、音频内容、绝对路径或用户正文。

默认运行环境可能不会输出 diagnostic event。需要开发期 console 诊断时，给 App 启用：

```text
LANGOTRACE_DIAGNOSTICS=1
LANGOTRACE_LOG_LEVEL=debug
```

## 6. 回归测试落点

优先运行聚焦测试：

```bash
swift test --package-path Packages/LangoTraceUI --filter PracticeSessionViewModelTests
swift test --package-path Packages/LangoTraceData --filter AppDatabaseTests
swift test --package-path Packages/LangoTraceData --filter 'GRDBPracticeRepositoryTests|LocalMediaArtifactStoreTests|MediaArtifactRepositoryTests'
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests/AppEnvironmentPracticeBootstrapTests
```

涉及 schema、App assembly 或资源变更时继续运行：

```bash
git diff --check
scripts/verify.sh
```

## 7. 相关文档

- `docs/spec/media-artifacts/impl.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/testing/README.md`
- `docs/plans/done/2026-05-26-bug-practice-recording-playback-state-refresh.md`
