# 任务方案：补齐单句练习页听示范与录音回放闭环

状态：Done
类型：bug
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 问题描述

`2026-05-25-feature-practice-shadowing-recording-completion` 已落地单句 practice session、麦克风录音、GRDB recording metadata 和完成态保存，但 post-implementation 复审发现单句练习页的用户体验链路仍缺两段关键能力：

1. 单句 `PracticeSessionView` 内没有听示范入口。用户可以在句子列表页点击 `听`，但进入单句跟读页后只能开始录音，无法在同一练习上下文中再次听目标句示范。
2. 完成步骤没有用户录音回放入口。`PracticeControlBar` 只支持开始录音、停止录音和完成；`PracticeActions` / `PracticeSessionViewModel` 没有 play recording action，也没有从 `practice_recordings` 解析 playback source 的用户可见状态。

这与 done plan 中“跟读：用户听目标语言示范”“录音结果可回放作为自我对比”“完成步骤显示回放”的完成标准不一致。当前实现可以保存录音和完成态，但还不能声称完整实现“跟读录音完成闭环”。

## 2. 代码证据

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`：主操作只在 `startRecording` / `stopRecording` / `complete` 之间切换，没有示范播放或录音回放按钮。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`：只暴露 `load()`、`startRecording()`、`stopRecording()`、`completeLatestRecording()`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeActions.swift`：action seam 只包含 create/restore、start recording、stop recording、complete。
- `LangoTraceApp/PracticeActionsAssembly.swift`：只装配 `PracticeRecordingService` 和 `LocalMediaArtifactStore.commitPracticeRecordingArtifact`，没有 playback source resolver / player，也没有示范 TTS action wrapper。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSessionReducer.swift` 已有 `demoPlaybackStarted` 和 `recordingPlaybackStarted` reducer 事件，说明领域状态预留了这两段能力，但 UI/App seam 尚未接入。
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactPlaybackSourceResolver.swift` 可校验并返回 artifact playback source，但当前没有按 `practice_recordings.id` 解析 completed / latest ready recording source 的 repository API。

## 3. 目标

- 单句练习页在 shadowing 阶段可直接触发已有逐句 TTS 播放能力听示范。
- 单句练习页在已有 ready recording 后可回放用户录音，用于自我对比。
- 录音中禁止示范播放和录音回放；播放中开始录音必须稳定停止、拒绝或转移状态。
- 完成态引用的录音若文件缺失或 hash mismatch，session 仍保持 completed，UI 显示录音不可播放而不是抹掉完成态。
- iPhone、iPad、macOS 继续共享同一 `PracticeSessionRouteSeed`、ViewModel 和 action seam，不为某个平台复制业务逻辑。

## 4. 不做什么

- 不做发音评分。
- 不做 ASR / Speech Recognition。
- 不做后台播放或锁屏控制。
- 不做录音上传、同步、默认导出或可恢复备份。
- 不改变当前 practice session schema 的第一阶段 exercise type。

## 5. 推荐修复方案

1. UI / Store：
   - 给 `LearningContentStore` 增加基于 `PracticeSessionRouteSeed` 构造 `SentenceAudioRequest` 的 helper，复用现有 `SentenceAudioPlaybackActions` 和 `SentenceAudioPlaybackCoordinator`，不复制 TTS 请求路径。
   - `PracticeSessionView` 增加 `onPlayDemo` closure，三端 route 传入同一 helper。
   - `PracticeControlBar` 或单句页局部 controls 增加“听示范”和“回放录音”按钮，保持 44pt 触控目标和本地化文案。
2. Data：
   - 在 `PracticeRepository` 或媒体 artifact repository 中新增按 recording id 读取 ready practice recording artifact metadata 的方法，必须校验 recording 属于 session、状态 ready、media artifact ready 且未 invalidated。
   - 使用 `LocalMediaArtifactPlaybackSourceResolver` 做文件存在和 hash 校验；失败时返回稳定 unavailable / playback failure，不改变 completed session。
3. Speech / App：
   - 复用 `TTSAudioPlaybackService` 或抽出命名更通用的 foreground audio playback service，播放 resolver 返回的 practice recording source。
   - `PracticeActions` 增加 `playDemo` 或由 UI closure 接入现有 sentence audio action；增加 `playRecording` / `stopPlayback` 或最小 `playLatestReadyRecording`。
   - 把 `PracticeAudioCoordinationState` 从纯 Core reducer 测试提升到 App/UI 实际 action seam，覆盖示范 TTS、录音、录音回放互斥。
4. 测试：
   - UI：ViewModel 覆盖听示范 action、录音回放 action、录音中禁用播放、missing playback source 的用户可见失败状态。
   - Data：按 recording id 解析 playback source；completed recording 文件缺失时 session 保持 completed。
   - App：assembly 装配 playback resolver/player，不回退 disabled seam。
   - Core：补足 demo / recording playback 与 recording 互斥的 reducer / coordination 用例。

## 6. 文档影响

- 更新 `docs/plans/done/2026-05-25-feature-practice-shadowing-recording-completion.md` 的实施记录，标明本次复审发现缺口，避免后续误读为已完整实现回放闭环。
- 修复完成后更新 `docs/platform-page-inventory.md`、`docs/architecture/002-system-map.md`、`docs/spec/media-artifacts/impl.md` 和 `docs/testing/README.md` 中关于 practice playback source / UI 可见回放状态的描述。

## 7. 验证命令

```bash
swift test --package-path Packages/LangoTraceCore --filter 'PracticeSessionReducerTests|PracticeAudioCoordinationTests'
swift test --package-path Packages/LangoTraceData --filter 'GRDBPracticeRepositoryTests|MediaArtifactPlaybackSourceResolverTests|MediaArtifactRepositoryTests'
swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|PracticeRouteSeedTests|LearningContentStoreSentenceAudioCoordinatorTests'
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests
scripts/verify.sh
```

## 8. 实施条件

2026-05-26：用户确认方案通过，立即实施。

## 9. 实施记录

2026-05-26：按 TDD 补齐缺口。先新增 Core / Data / UI / App 聚焦测试，验证单句页听示范、ready recording artifact 解析、录音中禁止播放、开始录音前停止示范播放、production assembly 不回退 disabled playback seam，以及 `SentenceAudioPlaybackCoordinator.stopActivePlayback()`。

2026-05-26：实现层面复用现有逐句 TTS 播放链路，`LearningContentStore.handlePracticeDemoTap` 由 `PracticeSessionRouteSeed` 构造 `SentenceAudioRequest`，三端 `PracticeSessionView` 注入同一 `onPlayDemo` / `onStopDemo` closure；没有新增第二套 TTS generation 或 cache 路径。

2026-05-26：实现用户录音回放链路。`PracticeRepository.readyRecordingArtifact(sessionID:recordingID:)` 校验 recording 属于当前 session、recording ready 且 artifact ready / 未 invalidated；`PracticeActions.playRecording` 经 `LocalMediaArtifactPlaybackSourceResolver` 校验文件和 hash 后使用前台 playback service 播放，缺失或失败映射为稳定 `playbackUnavailable`，不改变 completed session。

2026-05-26：更新 UI 控制和互斥。`PracticeControlBar` 增加听示范与回放录音按钮；`PracticeSessionViewModel` 维护示范播放 / 录音回放本地 busy 状态，录音中禁止播放，播放中禁止开始录音，开始录音前调用 `stopDemoAction` 停止当前示范播放。

2026-05-26：同步文档事实源。更新 `docs/platform-page-inventory.md`、`docs/architecture/002-system-map.md`、`docs/spec/media-artifacts/impl.md`、`docs/testing/README.md`，并回写原 done plan，避免后续误读为仍存在 active 缺口。

## 10. 验证记录

聚焦验证已通过：

```bash
swift test --package-path Packages/LangoTraceCore --filter 'SentenceAudioPlaybackCoordinatorTests|PracticeSessionReducerTests|PracticeAudioCoordinationTests'
swift test --package-path Packages/LangoTraceData --filter 'GRDBPracticeRepositoryTests|MediaArtifactPlaybackSourceResolverTests|MediaArtifactRepositoryTests'
swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|PracticeRouteSeedTests|LearningContentStoreSentenceAudioCoordinatorTests'
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests/AppEnvironmentPracticeBootstrapTests -only-testing:LangoTraceAppTests/SentenceAudioPlaybackAssemblyTests
```

完整验证已通过：

```bash
scripts/verify.sh
```

结果：XcodeGen、所有 package tests、工具测试、iPhone / iPad / macOS build、macOS App tests、SwiftLint、SwiftFormat 和文档 placeholder 扫描均完成；SwiftLint 仍只报告既有 warning，无 serious violation。

## 11. 剩余风险

- 真实 iPhone / macOS 设备上的麦克风授权、录音回放音频路由、系统中断和前后台切换仍需人工验收；自动化测试使用 fake service 和 simulator / macOS build，不替代真机音频验收。
- 存储管理 UI、用户显式删除 recording / session 后的文件补偿、录音同步 / 默认导出 / 可恢复备份仍不在本任务范围内。
- `TTSAudioPlaybackService` 目前作为前台本地音频播放服务被复用于录音回放；后续若引入更复杂的系统音频策略，可再按架构方案重命名或抽出更通用的 playback service。
