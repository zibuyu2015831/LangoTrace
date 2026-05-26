# 任务方案：排查单句练习录音完成后回放按钮不刷新

状态：Verified
类型：bug
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户确认单句练习页句序移动到底部导航中间的问题已完成，但录音完成后 `回放录音` 仍未切换为可用，需要对这一块进行深入排查。
2026-05-26：用户确认回放录音问题已经修复，并要求更新或创建相关文档，便于后续类似问题参考。

## 2. Bug 描述

在单句练习详情页点击 `开始录音`，完成录音后，`回放录音` 按钮没有进入可用状态，用户无法回放刚录制的音频。

## 3. 复现方式

1. 进入 iPhone 单句练习详情页。
2. 点击 `开始录音`。
3. 结束录音。
4. 观察 `回放录音` 是否可用并能播放刚刚录制的音频。

## 4. 预期行为

停止录音成功后：

- 当前 session 读取到最新 ready recording。
- `回放录音` 按钮变为可用。
- 点击 `回放录音` 播放最近一次 ready recording。
- 如果停止录音、文件提交或 repository reload 失败，页面应暴露可理解的失败状态，而不是静默停留在不可回放。

## 5. 实际行为

用户在模拟器页面中观察到录音完成后 `回放录音` 仍不可用。

## 6. 根因分析

当前排查证据：

- `PracticeControlBar` 的 `回放录音` 可用性依赖 `session.latestReadyRecordingID != nil`。
- `PracticeSessionViewModel.stopRecording()` 依赖 App 注入的 `PracticeActions.stopRecording` 返回带 ready recording 的 session。
- `PracticeActionsAssembly.stopRecording` 顺序为 `recordingService.stop` -> `mediaStore.commitPracticeRecordingArtifact` -> `repository.session(id:)`。
- UI view-model 成功路径测试通过：停止录音返回带 ready recording 的 session 后，`latestReadyRecordingID` 会刷新，`回放录音` 可用。
- Data facade / repository 成功路径测试通过：`commitPracticeRecordingArtifact` 后，`GRDBPracticeRepository.session(id:)` 能读到最新 ready recording。
- App assembly 成功路径测试通过：fake recording engine 写入 staging 文件后，`PracticeActionsAssembly.stopRecording` 能提交 artifact 并返回带最新 ready recording 的 session。
- 发现危险路径：如果 stop、artifact commit 或 session reload 任一步失败，旧实现会把错误在 view-model 中统一映射成 `.missingReadyRecording`，而 `visibleFailure` 会隐藏该错误；同时 App assembly 旧实现对 `repository.session(id:) == nil` 使用 `?? session` 静默 fallback，可能把旧 session 返回给 UI，表现为 `回放录音` 继续不可用。
- 模拟器日志与容器文件确认：15:58 的 `.m4a` 已写入 `MediaArtifacts/staging/1DE4E5BD-396E-4A8E-92C9-9A0D062C3223.m4a`，大小 108723 bytes；麦克风权限为 Allowed，AudioQueue 也完成了录音启动和停止。
- 同一模拟器 SQLite 中 `practice_recordings`、`practice_recording_artifacts` 没有任何行，`media_artifacts` 只有 TTS 音频；因此失败点位于录音文件生成之后、练习录音 artifact 元数据落库之前。
- 进一步检查模拟器 SQLite schema 发现旧 `media_artifacts` 表仍带有 `CHECK (derivation_kind IN ('ttsAudio'))`，而练习录音提交写入的是 `practiceRecording`，导致 INSERT 触发 CHECK 失败、事务回滚，staging 文件无法晋升为 ready artifact。

当前判断：按钮不切状态的根因不是共享 UI 状态投影，也不是麦克风权限或录音文件完全没产生；直接根因是已有模拟器数据库的旧 `media_artifacts.derivation_kind` CHECK 约束未随代码事实放宽，阻止 `practiceRecording` 类型 media artifact 写入。失败路径之前又被静默隐藏，导致用户只看到 `回放录音` 一直不可用。

置信度：95%

置信度依据：日志证明录音 AudioQueue 正常启动/停止；文件系统证明录音 staging 文件已生成；数据库内容证明没有任何 practice recording 元数据；sqlite schema 直接显示旧 CHECK 仍拒绝 `practiceRecording`。

备选原因：

- `AVAudioRecorder` 在模拟器停止时未产出可读取文件或文件内容异常，导致 `recordingService.stop` 抛错；当前日志和 staging 文件证据不支持。
- `LocalMediaArtifactFileStore.moveStagedFile` 在 staging -> final 路径移动时失败，导致 commit 未完成；当前更早的 schema CHECK 失败已足以解释。
- `GRDBMediaArtifactRepository.commitPracticeRecordingArtifact` 未把对应 practice recording 标记为 ready；自动化成功路径不支持。
- SwiftUI view-model 发布成功但 `PracticeControlBar` 未收到新的 session 值；当前证据较弱。

## 7. 目标

- 找到实际断点：录音 stop、media artifact commit、repository reload、view-model 发布或 SwiftUI redraw。
- 不再把停止录音失败静默隐藏成不可回放状态。
- 用自动化测试覆盖可复现的失败模式和成功状态投影。
- 保留录音本地优先、不同步、不默认导出、不自动发送 AI Provider 的边界。

## 8. 范围

涉及代码路径：

- `LangoTraceApp/PracticeActionsAssembly.swift`
- `LangoTraceApp/AppPracticeRecordingEngine.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/PracticeRecordingService.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- 相关 Core / Data / Speech / UI / App tests

不做：

- 不做发音评分、ASR、上传或同步。
- 不重做练习页视觉布局。
- 不把录音文件加入默认导出或同步。

## 9. 排查方案

1. 增加 view-model 级失败可见性测试：停止录音 action 抛错时不能静默隐藏为 `.missingReadyRecording`。
2. 增加 App/Data seam 级测试或 probe，验证真实 commit 后 repository session 读取到 ready recording。
3. 增加 App assembly postcondition：stop / commit 后 reload 出的 session 必须包含本次 recordingID，否则按 `.recordingUnavailable` 失败处理，不返回旧 session。
4. 增加 allowlisted typed diagnostic event，记录 `recording_stop`、`artifact_commit`、`session_reload` 三个失败阶段及错误分类，不记录句子、音频内容或绝对路径。
5. 用 `scripts/capture-runtime-log --last 30m` 捕获真实模拟器链路，确认实际运行期断点。
6. 新增数据库迁移，修复旧库 `media_artifacts.derivation_kind` CHECK 只允许 `ttsAudio` 的 schema 漂移。
7. 新增旧 v9 schema 升级回归测试，确保升级后可插入 `practiceRecording` media artifact。

## 10. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter PracticeSessionViewModelTests
swift test --package-path Packages/LangoTraceData --filter AppDatabaseTests
swift test --package-path Packages/LangoTraceData --filter 'GRDBPracticeRepositoryTests|LocalMediaArtifactStoreTests|MediaArtifactRepositoryTests'
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests/AppEnvironmentPracticeBootstrapTests
```

收口验证：

```bash
git diff --check
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
scripts/verify.sh
```

## 11. 文档影响检查

本轮修复发现 media artifact schema 迁移漂移，已新增数据库迁移；需要在完成前确认是否同步更新 media artifact 实现地图或测试文档。

已同步更新：

- `docs/spec/media-artifacts/impl.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/testing/README.md`
- `docs/testing/practice-recording-troubleshooting.md`

## 12. 实施记录

- 2026-05-26：创建 active bug plan，开始按运行期链路排查。
- 2026-05-26：补充 UI view-model 失败可见性测试。`stopRecording` 失败时不再静默隐藏成 `.missingReadyRecording`，而是暴露 `.recordingUnavailable`。
- 2026-05-26：补充 Data facade 测试，确认 practice recording artifact commit 后 repository session 能读取最新 ready recording。
- 2026-05-26：补充 App assembly 成功路径测试，确认 fake recording engine -> staging -> commit -> session reload 会返回本次 `latestReadyRecordingID`。
- 2026-05-26：补充 App assembly 失败诊断测试，确认 stop 失败会记录 `practice_recording.failed`，包含 `failure_phase=recording_stop` 和 `error_category=stop_failed`，且不包含句子、音频内容或绝对路径。
- 2026-05-26：收紧 App assembly postcondition。`repository.session(id:)` 为空或没有本次 ready recording 时，不再 fallback 到旧 session，而是记录 `session_reload` 失败并抛出 `.recordingUnavailable`。
- 2026-05-26：读取 `logs/latest.log` 和模拟器容器，确认 15:58 录音 staging 文件存在但 practice recording 元数据完全未落库；定位到旧 SQLite schema 的 `CHECK (derivation_kind IN ('ttsAudio'))` 阻止 `practiceRecording` artifact 写入。
- 2026-05-26：新增 `v10_allow_practice_recording_media_derivation_kind` 数据库迁移，重建 `media_artifacts` 表并保留既有 TTS artifact 元数据，同时允许 `practiceRecording` derivation kind。
- 2026-05-26：补充旧 v9 限制性 schema 升级测试，验证迁移后可以插入 `shadowingRecording` / `practiceRecording` media artifact。
- 2026-05-26：用户确认问题已修复后，新增 `docs/testing/practice-recording-troubleshooting.md`，沉淀录音回放问题的日志、staging 文件、GRDB metadata 和 schema 分层排查步骤。
- 2026-05-26：完成文档影响检查，补充数据存储规范、测试验证入口规范、media artifact 实现地图、测试 README 和练习录音故障排查 runbook。
- 2026-05-26：完成收口验证。`scripts/verify.sh` 通过，SwiftLint 仍有 warning 但 0 serious；`scripts/check-docs.sh`、占位词扫描和 `git diff --check` 通过。

## 13. 完成标准

- 根因有代码级证据。
- 停止录音失败不再静默表现为不可回放。
- 成功停止录音后 `回放录音` 可用的链路有自动化覆盖。
- 聚焦验证通过。

## 14. 剩余风险

真实麦克风、模拟器音频设备和系统权限弹窗仍需要人工验证；自动化测试只能覆盖服务 seam、状态机和持久化链路。
