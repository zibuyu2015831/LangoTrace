# 逐句 TTS 播放完成状态不复位复发排查方案

状态：Verified

类型：bug

创建日期：2026-05-24

最后更新日期：2026-05-24

## 用户确认记录

- 2026-05-24：用户复测后反馈“记录详情”逐句播放完成后按钮仍未复位，要求复测、排查，必要时读取最新日志。
- 2026-05-24：用户再次测试确认问题已修复。

## Bug 描述

上一轮将详情页改为直接观察 `LearningContentStore` 后，用户在 iPhone 模拟器继续复现：逐句播放按钮进入播放态并播放音频，但音频自然结束后按钮仍未恢复为空闲态。

## 关联历史

- 上一轮方案：`docs/plans/done/2026-05-24-bug-sentence-tts-playback-state-reset.md`
- 上一轮判断 SwiftUI 详情观察边界是主要原因；本轮复测证明该判断不足以解释全部运行时路径。
- 临时排查上下文：`sentence-tts-playback-debug-context.md` 已将有价值内容归档到本文档，原文件删除。

## 最新日志证据

- 2026-05-24 11:37:49 采集 `scripts/capture-runtime-log --last 30m`
- 日志路径：`logs/runtime-20260524-113749.log`
- 进程：`LangoTrace[18999]`
- 可见音频事件：
  - 11:36:43 开始播放 MP3 AudioQueue。
  - 11:36:49 AudioQueue stop / delete。
  - 11:36:54 再次开始播放 MP3 AudioQueue。
  - 11:37:05 AudioQueue stop。
- 当前日志没有应用层 `SentenceAudio` / `LearningContentStore` 状态链日志，因此不能定位断点。
- 后续临时诊断日志确认：Store 订阅 `stateUpdates` 后 stream 立即结束，coordinator 没有 observer 注册；播放器 delegate、duration fallback 和 coordinator completion 路径可正常完成。

## 失败假设归档

本问题在修复前已经经历多次通过自动化验证但用户仍可复现的修复尝试，包括播放完成 fallback、
coordinator fallback、详情页显式传递播放状态，以及详情页直接观察 `LearningContentStore`。这些尝试分别证明了
coordinator、Store 和 SwiftUI source shape 的局部契约，但没有证明真实运行时链路中 App assembly
暴露给 Store 的 `SentenceAudioPlaybackActions` 是否完整。

因此本轮排查的关键经验是：当底层状态机测试和 UI 结构测试均通过但模拟器仍复现时，必须用运行期日志逐段确认
player completion、coordinator observer、Store subscription 和可见按钮状态，而不是继续基于局部测试补假设。

## 目标

- 用非敏感运行期日志打通以下边界：
  1. AVAudioPlayer 是否发出 completion 或 fallback completion。
  2. Coordinator 是否收到 completion 并 reduce 到 `.idle`。
  3. Coordinator 是否向 observer 发出 `.idle`。
  4. Store 是否收到 `.idle` 并更新 `sentenceAudioPlaybackStates`。
  5. 可见详情视图是否拿到 `.idle`。
- 在证据明确后修复真实断点，并补回归测试。

## 不做什么

- 不记录句子原文、API Key、完整文件路径或 Provider 密钥。
- 不继续基于猜测改状态链。
- 不改变 TTS Provider、缓存 schema、隐私边界。

## 根因分析

置信度：95%

真实断点不在播放器 completion，也不在 SwiftUI 可见详情观察边界。运行期诊断显示 `LearningContentStore`
调用 `stateUpdates(for:)` 后 observation stream 立即结束，没有进入 `SentenceAudioPlaybackCoordinator`
的 observer bucket；同时播放器 delegate 和 coordinator completion 都能正常完成。

根因是 `LangoTraceApp/SentenceAudioPlaybackAssembly.swift` 中的
`SentenceAudioPlaybackCoordinatorBox.actions()` 只转发了 `handleTap` 和
`presentationState`，遗漏了 `stateUpdates`。因此 App 运行时拿到的是
`SentenceAudioPlaybackActions` initializer 的默认空 stream，Store 订阅会立即结束，播放完成后的
`.idle` 永远不会回写到 UI Store。

## 备选原因

- 用户复测时运行的仍不是包含上一轮修复的构建。
- AVAudioPlayer delegate 不触发且 fallback 被取消。
- `stateUpdates(for:)` 的 summary 与 `handleTap` 写入的 summary 不一致。
- 可见句子的 `sentence.id` 与 Store 中写入的 key 不一致。
- 详情视图刷新了，但按钮视觉样式没有体现 `.idle`。

## 实施方案

1. 添加短期可保留的非敏感 `Logger` 诊断点，覆盖播放器、Coordinator、Store、详情容器和句子按钮。
2. 安装最新构建并在模拟器复现一次。
3. 用 `scripts/capture-runtime-log --last 10m` 收集日志，按事件链定位断点。
4. 只针对证据断点实施最小修复。
5. 增加或更新自动化测试。
6. 运行聚焦测试与 `scripts/verify.sh`。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceCore --filter SentenceAudioPlaybackCoordinatorTests
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
scripts/verify.sh
```

## 文档影响检查

本轮若仅修复播放状态链，不改变长期文档规则；若发现 SwiftUI 状态所有权规范缺失，再更新 `docs/spec/004-swiftui-architecture.md`。

## 实施记录

- 2026-05-24：用户复测失败后重新抓取最新模拟器日志，确认现有日志只有系统 AudioQueue 事件，缺少应用层状态链。
- 2026-05-24：增加短期非敏感诊断日志，复测确认 Store 的 `stateUpdates` stream 立即结束，而 coordinator 没有收到 observer 注册。
- 2026-05-24：定位到 App assembly 遗漏转发 `stateUpdates`，补充回归测试
  `SentenceAudioPlaybackAssemblyTests/testCoordinatorBoxActionsExposeStateUpdates`。
- 2026-05-24：修复 `SentenceAudioPlaybackCoordinatorBox.actions()`，把 `stateUpdates` 转发到同一个 coordinator，并在 coordinator 创建失败时返回 `.failed(.playbackFailed)` stream。
- 2026-05-24：新增 Store/coordinator 边界回归测试
  `LearningContentStoreSentenceAudioCoordinatorTests/storeKeepsCoordinatorStateSubscriptionAliveUntilPlaybackCompletion`，覆盖播放完成后 Store 回到 `.idle`。
- 2026-05-24：iPhone 17 模拟器人工复测通过：点击第一句播放按钮后进入暂停态，音频自然完成后按钮恢复为听音态。
- 2026-05-24：移除临时诊断日志；完整验证 `scripts/verify.sh` 通过。

## 完成标准

- 有日志证据说明断点。
- 修复后用户可见按钮在播放完成后恢复为空闲态。
- 相关自动化测试通过。
- 完整验证通过，或记录不能运行的原因。

## 剩余风险

- 该修复已覆盖 App assembly、Store/coordinator 边界和 iPhone 17 模拟器人工复测；剩余风险主要是未来新增 action assembly 时再次遗漏 stream 转发。
