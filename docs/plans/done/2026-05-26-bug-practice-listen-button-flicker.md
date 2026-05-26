# 任务方案：排查单句练习页首次点击听导致其他按钮闪动

状态：Verified
类型：bug
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户在 iPhone 17 模拟器截图中指出，单句练习详情页首次点击 `听` 按钮时，其他按钮会出现闪动，要求确认问题并深入排查原因。

## 2. Bug 描述

单句练习详情页点击 `听` 后，操作卡中的 `回放录音` 和主按钮会短暂切换 disabled / enabled 视觉状态。首次点击更明显，因为首次示范播放通常需要经过 TTS 配置检查、生成或缓存写入、播放源解析和播放器启动。

## 3. 复现方式

1. 进入 iPhone 练习 Tab。
2. 打开记录卡片，进入句子列表。
3. 进入单句练习详情页。
4. 在当前句首次点击 `听`。
5. 观察同一操作卡内 `回放录音` 和 `开始录音` 是否出现短暂变灰、恢复或视觉闪动。

## 4. 预期行为

- 点击 `听` 只应改变示范播放自身的状态。
- 其他按钮不应因为示范播放准备阶段出现无意义的短暂视觉闪动。
- 如果业务上需要禁止并发录音或回放，禁用状态应来自稳定、可解释的音频协调状态，而不是一次 async action 的临时生命周期。

## 5. 实际行为

截图和代码排查显示，点击 `听` 后其他按钮会短暂收到 disabled 状态：

- `PracticeSessionViewModel.playDemo()` 进入时把 `isPlayingDemo` 设置为 `true`。
- `PracticeControlBar` 使用 `isPlayingDemo` 禁用 `回放录音` 和主按钮。
- `playDemoAction` 返回后 `defer` 立即把 `isPlayingDemo` 设回 `false`。
- 首次点击需要 TTS 生成 / 播放准备，`true -> false` 的时间窗口足够被用户看见。

## 6. 根因分析

当前判断：直接根因是单句练习页把 `isPlayingDemo` 当作示范播放真实状态使用，但它实际表示 `handlePracticeDemoTap` 这次 async tap action 是否尚未返回。

证据：

- `PracticeSessionViewModel.playDemo()` 在调用 `playDemoAction()` 前设置 `isPlayingDemo = true`，并在 action 返回时通过 `defer` 设置为 `false`。
- `PracticeControlBar` 依据 `isPlayingDemo` 禁用 `回放录音` 和主按钮。
- `LearningContentStore.handlePracticeDemoTap()` 内部调用 `sentenceAudioPlaybackActions.handleTap(request)`，再启动对 `stateUpdates` 的观察。
- `SentenceAudioPlaybackCoordinator.handleTap()` 会执行 TTS 可用性检查、cache miss 时生成音频、提交 artifact、解析播放源并启动播放器；首次点击通常比缓存命中更慢。
- 播放开始后真实状态由 `SentenceAudioPlaybackCoordinator` 的 `SentenceAudioPresentationState` / `stateUpdates` 发布，但 `PracticeSessionViewModel` 没有订阅该状态，只用本地 `isPlayingDemo` 覆盖控制条禁用逻辑。

置信度：90%

置信度依据：代码路径能完整解释“首次点击更明显”和“其他按钮闪动”的表现；涉及的状态写入和 disabled 依赖关系均在当前实现中可直接定位。

备选原因：

- SwiftUI `.bordered` / `.borderedProminent` 在 disabled 变化时有系统默认视觉过渡，放大了闪动感。
- `LearningContentStore.sentenceAudioPlaybackStates` 更新触发上层 `ObservedObject` 重绘，导致整个 `PracticeSessionView` 重新计算 body；但它不是直接禁用其他按钮的根因。
- 按钮宽度或文字变化导致布局跳动；当前截图中的文字没有变化，代码也没有在 `PracticeControlBar` 内根据 demo state 改变标题，因此概率较低。

## 7. 目标

- 让 `听` 的准备 / 播放状态只影响必要的互斥行为，不造成其他按钮短暂闪动。
- 将控制条状态从一次 tap action 生命周期，收敛到真实音频 presentation state 或更明确的 busy 状态。
- 用 UI view-model 或 presentation 测试覆盖首次播放准备期间的控制条状态。

## 8. 范围

涉及代码路径：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeSessionViewModelTests.swift`

不做：

- 不改 TTS Provider、TTS 生成、media artifact 持久化或播放器底层。
- 不重做练习页整体视觉结构。
- 不改变录音、回放录音、完成态的持久化语义。

## 9. 拟实施方案

1. 先补失败测试：模拟 `playDemoAction` 持续挂起时，确认控制条 projection 不应让非相关按钮出现短暂无意义禁用，或至少把禁用态映射到稳定的 demo playback presentation。
2. 调整 `PracticeSessionViewModel`：区分 `isDemoTapInFlight` 和 `isDemoPlaybackActive`，避免用 tap action 生命周期直接驱动其他按钮 disabled。
3. 让 `PracticeSessionView` / `PracticeControlBar` 使用明确 projection 管理互斥：
   - 录音中仍禁止听示范和回放录音。
   - 回放录音中仍禁止听示范和录音。
   - 听示范准备中是否禁止录音，需要保持稳定并避免瞬时 enabled / disabled 抖动。
4. 如需接入真实 TTS presentation state，优先通过已有 `SentenceAudioPresentationState` seam，不在 View 内直接创建新的播放状态源。

## 10. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter PracticeSessionViewModelTests
```

收口验证：

```bash
git diff --check
swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|PracticeRouteSeedTests|ThreePlatformPresentationCopyTests|PhoneIOSConvergenceTests'
scripts/check-docs.sh
```

涉及 Swift 工程行为收口时继续运行：

```bash
scripts/verify.sh
```

## 11. 文档影响检查

当前阶段预计不需要更新长期 spec；若修复改变练习页音频互斥规则，应同步更新：

- `docs/spec/009-testing-and-verification.md`
- `docs/testing/README.md`

## 12. 完成标准

- 首次点击 `听` 时其他按钮不再出现无意义闪动。
- 录音、回放录音和示范播放互斥仍然成立。
- 自动化测试覆盖状态机或 presentation 规则。
- 聚焦验证通过。

## 13. 实施记录

- 2026-05-26：新增 `PracticeSessionViewModelTests.viewModelDoesNotMarkDemoPlaybackActiveWhileListenTapIsPreparing`，用挂起的 `playDemoAction` 复现首次点击 `听` 的准备阶段。修复前测试失败，显示 `isPlayingDemo == true`。
- 2026-05-26：将 `PracticeSessionViewModel.playDemo()` 的准备中防重入状态改为私有 `isDemoTapInFlight`，不再把一次 tap action 生命周期发布为 `isPlayingDemo`，避免 `PracticeControlBar` 因 `isPlayingDemo` 短暂禁用其他按钮。
- 2026-05-26：聚焦验证 `swift test --package-path Packages/LangoTraceUI --filter PracticeSessionViewModelTests` 通过，9 个 Swift Testing 用例通过。
- 2026-05-26：扩展 UI 回归验证 `swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|PracticeRouteSeedTests|ThreePlatformPresentationCopyTests|PhoneIOSConvergenceTests'` 通过，30 个 Swift Testing 用例通过。
- 2026-05-26：收口验证 `scripts/check-docs.sh`、占位词扫描、`git diff --check` 和 `scripts/verify.sh` 通过。`scripts/verify.sh` 中 SwiftLint 仍报告既有 warning，0 serious；SwiftFormat lint 显示 0 个文件需要格式化。

## 14. 剩余风险

真实视觉闪动受系统按钮样式和动画影响，自动化测试只能覆盖状态 projection；最终仍需要 iPhone 模拟器人工确认。
