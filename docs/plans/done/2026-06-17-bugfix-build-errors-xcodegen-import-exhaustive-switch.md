# Bug 修复：构建失败（文件未注册 + 缺少 import + 非穷举 switch + 废弃 API）

- **类型**：bugfix
- **日期**：2026-06-17
- **分支**：dev
- **commit**：49a9ade
- **状态**：已完成

---

## 背景

在 build 阶段出现四组报错，均集中在 `LangoTraceApp/` 的 App target 层。所有问题都属于工程基础设施漏洞（文件注册、import、穷举检查、废弃 API），不涉及业务逻辑变更。

---

## 发现的问题

### 问题 1：ReadingExplanationOperationRecorder 类型在 AppEnvironment 中找不到

**报错**：
```
AppEnvironment.swift:218:24 Cannot find 'ReadingExplanationOperationRecorder' in scope
```

**根本原因**：`LangoTraceApp/ReadingExplanationOperationRecorder.swift` 文件已添加到仓库，但 `LangoTrace.xcodeproj` 未重新生成，导致该文件未被注册进任何 target。

`project.yml` 使用目录级通配（`sources: path: LangoTraceApp`），所有新增文件都需要运行 `xcodegen generate` 才能进入 xcodeproj，不会自动同步。

**修复**：运行 `xcodegen generate`，将 `ReadingExplanationOperationRecorder.swift` 注册进 iOS 和 macOS 两个 target。

---

### 问题 2：ReadingExplanationOperationRecorder 中找不到 AIProviderConfigurationProfile / AIProviderEndpointInput

**报错**：
```
ReadingExplanationOperationRecorder.swift:39:26 Cannot find type 'AIProviderConfigurationProfile' in scope
ReadingExplanationOperationRecorder.swift:40:27 Cannot find type 'AIProviderEndpointInput' in scope
```

**根本原因**：`ReadingExplanationOperationRecorder.swift` 只 import 了 `LangoTraceAI` 和 `LangoTraceData`，但 `AIProviderConfigurationProfile` 和 `AIProviderEndpointInput` 定义在 `LangoTraceCore/AIProviderConfiguration.swift` 中，漏掉了 `import LangoTraceCore`。

**修复**：在文件顶部补加 `import LangoTraceCore`。

---

### 问题 3：makeReadingTTSAction 中对 SentenceAudioPlaybackState 的 switch 不穷举

**报错**：
```
AppEnvironment.swift:292:9 Switch must be exhaustive
```

**根本原因**：`SentenceAudioPlaybackState` 有六个 case：

```swift
case idle
case generating(SentenceAudioKey)
case playing(SentenceAudioKey)
case paused(SentenceAudioKey)
case requiresConfiguration(SentenceAudioConfigurationIssue)
case failed(SentenceAudioPlaybackFailure)
```

`makeReadingTTSAction` 中的 switch 只处理了 `.idle`、`.playing`、`.failed`、`.requiresConfiguration`，遗漏了 `.generating` 和 `.paused`。

**修复**：将 `.generating` 和 `.paused` 并入 `.idle, .playing` 分支，均返回 `.success`（tap 已被接受，音频正在生成或已暂停，均属于操作成功处理状态）。

```swift
// 修复前
case .idle, .playing:
    return .success

// 修复后
case .idle, .playing, .generating, .paused:
    return .success
```

---

### 问题 4：AVAudioSession 使用已废弃的 .allowBluetooth

**报错**：
```
AppPracticeRecordingEngine.swift:55:103 'allowBluetooth' was deprecated in iOS 8.0:
renamed to 'AVAudioSession.CategoryOptions.allowBluetoothHFP'
```

**根本原因**：`AppPracticeRecordingEngine` 的录音会话使用了 iOS 8.0 起被废弃的 `.allowBluetooth` 选项，该选项在 iOS 8 已更名为 `.allowBluetoothHFP`，两者功能等价。

**注意**：之前 (2026-06-16) 有一次专项修复（`2026-06-16-bug-tts-audio-session-hfp-routing.md`）将录音侧从 `.allowBluetoothHFP` 还原为 `.allowBluetooth`，但该修复的实际有效部分是在 TTS 播放侧添加 `.allowBluetoothA2DP`（`TTSAudioPlaybackService.swift:140`），而非录音侧的名称回退。由于 `.allowBluetooth` 和 `.allowBluetoothHFP` 是完全相同的值（仅名称被废弃），此次改回 `.allowBluetoothHFP` 不影响音频路由行为，TTS 侧 `.allowBluetoothA2DP` 保持不变。

**修复**：将 `.allowBluetooth` 替换为 `.allowBluetoothHFP`，消除废弃 API 警告。

---

## 关联文件

- `LangoTrace.xcodeproj/project.pbxproj` — xcodegen 重新生成，注册 ReadingExplanationOperationRecorder.swift
- `LangoTraceApp/ReadingExplanationOperationRecorder.swift` — 补 `import LangoTraceCore`
- `LangoTraceApp/AppEnvironment.swift` — 补 `.generating` 和 `.paused` case
- `LangoTraceApp/AppPracticeRecordingEngine.swift` — `.allowBluetooth` → `.allowBluetoothHFP`

---

## 验证

- build 通过（Xcode 报错全部消除）
- 无业务逻辑变更，无需新增单元测试
- 剩余风险：无

---

## 规范更新

本次 bug 触发了以下三条新规则，已写入 `docs/spec/004-swiftui-architecture.md`：

1. `LangoTraceApp/` 新增文件后必须运行 `xcodegen generate`，不自动同步 xcodeproj。
2. App target 文件使用跨 Package 类型时必须显式 import 每一个提供类型的 Package。
3. 公共 enum 新增 case 后，须 grep 现有 switch 语句确认穷举性。
