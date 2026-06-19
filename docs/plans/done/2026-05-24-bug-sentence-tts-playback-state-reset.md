# 逐句 TTS 播放完成后按钮状态不复位修复方案

状态：Verified

类型：bug

创建日期：2026-05-24

最后更新日期：2026-05-24

## 用户确认记录

- 2026-05-24：用户提供 iPhone 17 模拟器截图并要求深入排查“记录详情”页面中点击逐句播放按钮后，音频播放完成但按钮不切回原状态的问题，要求修复和测试。

## Bug 描述

在 iPhone “记录详情”页面的逐句练习卡片中，点击播放按钮后按钮进入播放态，且对应 TTS 音频能够播放；音频播放完成后，按钮没有恢复为听音/空闲态。

## 复现方式

1. 启动 iPhone 模拟器中的 LangoTrace。
2. 进入“记录详情”页面。
3. 点击任一句子的播放按钮。
4. 等待对应音频自然播放完成。

## 预期行为

音频播放完成后，当前句子的播放按钮应恢复为空闲态图标；切换到另一句播放时，旧句子的按钮也应恢复为空闲态。

## 实际行为

音频播放完成后，按钮仍停留在播放/暂停态；用户侧还可观察到切换句子后存在多个句子按钮显示为活动态的情况。

## 现状描述

- `SentenceAudioPlaybackCoordinator` 已有播放完成和 duration fallback 测试。
- `LearningContentStore` 已有 action stream 将 `.idle` 写回 `sentenceAudioPlaybackStates` 的测试。
- `EntryDetailView` 当前接收普通字典值 `sentenceAudioPlaybackStates`，父视图在导航 destination 中拼装详情页。
- SwiftUI 导航 destination 可能缓存已入栈详情视图；仅依赖父视图传入普通值，不能保证详情页在 Store 发布播放状态变化时被重新计算。

## 目标

- 找到并修复播放完成状态没有反映到可见按钮的真实边界问题。
- 让详情页自身直接观察 `LearningContentStore`，从 Store 派生播放状态、生成状态和内容读模型。
- 保持 iPhone / iPad / macOS 三端入口一致。
- 增加回归测试，避免未来退回到普通字典快照传值。

## 不做什么

- 不重写 TTS Provider、音频文件缓存或数据库 schema。
- 不改变 AI/TTS 隐私边界。
- 不引入正式逐句播放 coordinator 的新产品能力。
- 不提交未跟踪的临时排查上下文文件。

## 根因分析

置信度：90%

根因判断：底层播放完成事件链已有 coordinator 和 store 单元测试覆盖；当前更可能卡在 SwiftUI 导航 destination 的观察边界。详情页接收 `sentenceAudioPlaybackStates` 普通值，若导航 destination 已缓存，Store 的后续 `@Published` 字典变更不会稳定驱动可见 `EntryDetailView` 重算，导致按钮停留在旧状态。

## 置信度依据

- 既有 `SentenceAudioPlaybackCoordinatorTests` 覆盖播放完成和 duration fallback 后恢复 `.idle`。
- 既有 `LearningContentStoreTests` 覆盖 action stream 推送 `.idle` 后 store 字典恢复。
- 用户反馈发生在真实可见详情页按钮，符合 SwiftUI 视图观察边界失效，而不是底层状态机完全未复位。
- 已有排查上下文指出前几次修复均通过自动化验证但仍未解决运行时症状，应避免继续只补 coordinator/store 层。

## 备选原因

- AVAudioPlayer delegate 或 fallback 在真实文件上未触发。
- 运行的模拟器 App 不是最新构建。
- sentence id / request summary 在生成和显示之间不稳定。
- Store observation task 生命周期提前结束。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackCoordinatorTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`

## 涉及的文档路径

- `docs/README.md`
- `docs/plans/README.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/009-testing-and-verification.md`

## 实施方案

1. 新增或更新 UI 回归测试，要求详情路由使用直接观察 `LearningContentStore` 的容器视图，并禁止平台入口继续直接把 `contentStore.sentenceAudioPlaybackStates` 作为普通字典快照传给 `EntryDetailView`。
2. 增加共享 `EntryDetailStoreView` 容器，由该容器持有 `@ObservedObject var contentStore: LearningContentStore`，内部重新读取 entry、rendering、practice、generation、stale 和 sentence playback state。
3. 将 iPhone navigation destination、iPad/macOS detail 入口切换为该容器。
4. 保留 `EntryDetailView` 为纯展示视图，降低变更面。
5. 运行聚焦 UI 测试、Core/Store 相关测试和可行的完整验证。

## 回归测试方案

- `swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests/sentenceAudioPlaybackStateIsSwiftUIObservedDetailInput`
- `swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests`
- `swift test --package-path Packages/LangoTraceCore --filter SentenceAudioPlaybackCoordinatorTests`

## 复查方法

- 检查三端入口不再直接向 `EntryDetailView` 传入 `sentenceAudioPlaybackStates: contentStore.sentenceAudioPlaybackStates`。
- 检查详情容器自身声明 `@ObservedObject var contentStore: LearningContentStore`。
- 检查播放按钮状态仍从 `EntryDetailView` 的 `sentenceAudioPlaybackStates[sentence.id]` 派生。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests/sentenceAudioPlaybackStateIsSwiftUIObservedDetailInput
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests
swift test --package-path Packages/LangoTraceCore --filter SentenceAudioPlaybackCoordinatorTests
scripts/verify.sh
```

## 文档影响检查

本修复不改变长期产品、隐私、数据、AI Provider、同步或发布规则；属于 SwiftUI 观察边界 bug 修复。完成后如发现规范缺口，再补充 `docs/spec/004-swiftui-architecture.md`。

## 实施记录

- 2026-05-24：创建任务方案，开始以详情页 Store 观察边界为主要假设进行 TDD 修复。
- 2026-05-24：新增失败测试 `PhoneIOSConvergenceTests/sentenceAudioPlaybackStateIsSwiftUIObservedDetailInput`，确认旧实现仍直接通过平台入口传递 `sentenceAudioPlaybackStates` 普通字典快照。
- 2026-05-24：新增 `EntryDetailStoreView`，由可见详情路由直接 `@ObservedObject` 观察 `LearningContentStore`，并将 iPhone / iPad / macOS 详情入口切换到该容器。
- 2026-05-24：更新既有源码结构测试，使生成、编辑、重分析和播放状态观察契约落到共享详情容器。
- 2026-05-24：验证通过：
  - `swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests/sentenceAudioPlaybackStateIsSwiftUIObservedDetailInput`
  - `swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests`
  - `swift test --package-path Packages/LangoTraceCore --filter SentenceAudioPlaybackCoordinatorTests`
  - `swift test --package-path Packages/LangoTraceUI`
  - `scripts/verify.sh`

## 完成标准

- 回归测试先失败后通过。
- 详情页可见播放按钮由观察 Store 的容器驱动更新。
- 聚焦 Core/UI 测试通过。
- 若完整验证无法完成，记录原因和剩余风险。

## 剩余风险

- 已验证自动化状态链和三端构建；尚未在用户当前模拟器上做一次人工播放完成复测。如果真实运行时仍不复位，需要继续用运行期日志确认 AVAudioPlayer delegate、coordinator completion task、store observer 和 visible view 四段事件链。
