# 任务方案：修复 TTS 播放音频会话路由冲突（allowBluetoothHFP 导致"语音交互"感）

状态：Confirmed
自审核状态：Reviewed
类型：bug
创建日期：2026-06-16
最后更新日期：2026-06-16

## 用户确认记录

- 确认日期：2026-06-16
- 确认方式：AI 辅助开发会话
- Step 2 方案选择：**方案 A**（还原 `.allowBluetooth`）
- 范围扩展确认：同步修复 TTS 播放侧 session 选项（显式加入 `.allowBluetoothA2DP`），在本次任务中完成完整的蓝牙音频路由修复，避免后续返工
- 原则确认：对于类似基础设施，要求一开始就采用最优方案

---

## 1. Bug 描述

用户在系统设置的 AI Provider 模块中测试 TTS 语音合成时，发现**语音播放的听感从"TTS 合成音"变成了"语音交互/通话"模式**：音质明显降低（窄带）、音频路由行为类似蓝牙通话（HFP 电话通道），而非扬声器高质量播放。

用户判断这是近期改动引入的 bug。经分析定位到 `LangoTraceApp/AppPracticeRecordingEngine.swift` 中一处未提交的本地改动：将音频会话选项从 `.allowBluetooth` 改为 `.allowBluetoothHFP`。

---

## 2. 现状描述

### 2.1 问题改动（未提交，工作区状态）

```swift
// AppPracticeRecordingEngine.swift:55 — 当前工作区（有 bug）
try session.setCategory(.playAndRecord, mode: .spokenAudio,
                        options: [.defaultToSpeaker, .allowBluetoothHFP])

// 原始代码（修复前）
try session.setCategory(.playAndRecord, mode: .spokenAudio,
                        options: [.defaultToSpeaker, .allowBluetooth])
```

`git diff` 已确认为 unstaged 本地变更，未进入任何 commit。

### 2.2 TTS 播放侧的音频会话管理（结构性问题）

```swift
// TTSAudioPlaybackService.swift:129-135
/// On iOS the default `.soloAmbient` session is muted by the silent switch...
private func activatePlaybackAudioSessionIfAvailable() {
    #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)   // silent fail
        try? session.setActive(true)                               // silent fail
    #endif
}
```

TTS 播放侧使用 `try?` 静默吞掉 session 激活失败，无法感知与录音会话的冲突。

### 2.3 会话生命周期全局单例风险

录音引擎和 TTS 播放服务共享 `AVAudioSession.sharedInstance()`，分别尝试激活不同 category（`.playAndRecord` vs `.playback`），两者无显式协调机制。

---

## 3. 目标

1. 还原 `AppPracticeRecordingEngine.swift` 中的录音会话选项为 `.allowBluetooth`，消除 `.allowBluetoothHFP` 引起的 HFP 双向通道干扰。
2. 同步修复 `TTSAudioPlaybackService.swift` 的播放会话选项：显式加入 `.allowBluetoothA2DP`，确保蓝牙耳机使用 A2DP 高质量通道，从根本上隔离录音 HFP 路由残留对 TTS 播放质量的影响。
3. 补充 TTS 播放侧会话激活失败的诊断日志，将 silent fail 改为带 OSLog warning 的 soft fail。
4. 新增单元测试覆盖录音会话选项配置意图，防止此类配置退化被静默引入。

---

## 4. 范围

- `LangoTraceApp/AppPracticeRecordingEngine.swift`：还原 `.allowBluetooth`（deprecation 迁移路径见 §20）
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift`：
  - session 选项显式加入 `.allowBluetoothA2DP`（强制 A2DP 高质量播放路由）
  - session 激活失败由 `try?` 改为带 OSLog warning 的 soft fail
- `LangoTraceApp/` 层和 `LangoTraceSpeech` 包（均限 iOS `#if os(iOS)` 分支内）的音频会话配置
- 新增单元测试：录音引擎音频会话配置测试

---

## 5. 不做什么

- **不实现 AVAudioSession 全局会话协调器**：通过录音侧 `.allowBluetooth` + TTS 侧 `.allowBluetoothA2DP` 的显式选项组合，已覆盖"录音结束 → TTS 播放"的顺序场景。全局协调器（session priority queue / coordinator 对象）适用于录音与 TTS 并发（如录音中实时 TTS 提示）场景，超出当前范围，已记录为架构备忘录。
- **不为 macOS 添加 AVAudioSession 处理**：macOS 不使用 `AVAudioSession`，相关代码在 `#if os(iOS)` 内，不受影响。
- **不更改 TTS probe 的播放行为**：TTS probe 当前只验证音频格式，不实际播放，此范围保持不变。
- **不修改 Embedding 或文本生成的配置路径**：与本 bug 无关。

---

## 6. 证据与决策依据

### 6.1 音频选项行为差异（Apple 文档）

| 选项 | 含义 | 在 `playAndRecord` 模式的效果 |
|------|------|-------------------------------|
| `.allowBluetooth` | 允许蓝牙 HFP 设备作为**输入路由**（麦克风） | iOS 17 已 deprecated；BT 设备可作为录音 mic，输出仍走 `.defaultToSpeaker`；iOS 17+ 行为等价于 `.allowBluetoothHFP` |
| `.allowBluetoothHFP` | 允许蓝牙 HFP 设备用于音频**输入 + 输出** | iOS 10+；当 BT HFP 耳机已连接时，同时接管输入和输出，进入"通话模式"（HFP = 8-16kHz 窄带）；`.allowBluetooth` 的后续非 deprecated 替代 |
| `.allowBluetoothA2DP` | 允许蓝牙 A2DP 设备用于**高质量输出路由** | iOS 10+；`.playback` 模式下默认可用；显式指定确保 HFP 会话退出后路由恢复为 A2DP 立体声；`playAndRecord` 不支持（蓝牙协议限制，全双工场景 A2DP 与麦克风互斥）|

当 `.allowBluetoothHFP` 生效时，BT 耳机切入 HFP 通话通道：
- 音质降至 8-16kHz（窄带 / CVoiceChat）
- 音频路由从扬声器切换到 BT 耳机
- 即使录音结束并调用 `setActive(false)`，BT 耳机可能短时间内仍处于 HFP 模式
- TTS 播放侧 `try? setCategory(.playback)` 若切换失败，音频继续走 HFP 通道

### 6.2 代码证据

- `AppPracticeRecordingEngine.swift:55`：本地未提交改动，`git diff` 确认
- `TTSAudioPlaybackService.swift:129-135`：`try?` 静默吞掉失败，已读源代码核验
- `AppPracticeRecordingEngine.swift:80,105`：录音结束时无条件调用 `setActive(false)`，无协调等待 TTS 播放

### 6.3 工作流参考

本任务属于 TTS Provider / 播放能力范畴，应参考 [新增 TTS Provider 或逐句播放能力](../../workflows/add-tts-provider.md) 中的"音频会话管理"检查清单。

```text
是否需要 spike / probe / fixture / evidence：否（本地可手动复现）
是否包含真实用户敏感内容：否
```

---

## 7. 约束映射与验证路径

### 约束 1：TTS 播放行为必须不依赖用户显式触发 AI Provider 配置

- 来源：`docs/CLAUDE.md §4.10`（"照片、日记、音频等敏感内容只有在用户明确触发对应 AI 能力时才发送给 Provider"）
- 适用范围：本任务的 fix 不改变 TTS 播放的触发条件
- 严重度：info
- 执行或验证方式：人工审查——确认修复代码只改音频会话选项，不影响 TTS 请求是否发送
- 说明：本任务修复的是音频路由，不涉及 AI Provider 请求触发条件

### 约束 2：本地媒体资产和录音默认不同步

- 来源：`docs/CLAUDE.md §2`（"练习录音默认本机保存，不自动发送 AI Provider、不默认导出、不同步"）
- 适用范围：`AppPracticeRecordingEngine.swift` 的修改不能改变录音的本地保存行为
- 严重度：blocker
- 执行或验证方式：人工审查——确认 fix 只改 AVAudioSession options，不改录音存储路径或导出策略
- 说明：audio session 选项变更不影响录音 artifact 的写入和同步边界

### 约束 3：单元测试优先，先写失败用例

- 来源：`docs/CLAUDE.md §1.4`（"行为可自动化验证时，先写或更新单元测试，再改生产代码"）
- 适用范围：本任务所有行为变更
- 严重度：blocker
- 执行或验证方式：本方案 TDD 章节写明先失败测试
- 说明：AVAudioSession 的实际路由行为无法单测（需真实硬件），但音频会话**配置意图**可通过 protocol stub 验证

---

## 8. 涉及的代码文件路径

- `LangoTraceApp/AppPracticeRecordingEngine.swift` — 主修改文件（还原 `.allowBluetooth`）
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift` — 补充诊断 log

新增测试文件（TDD）：

- `LangoTraceApp/LangoTraceAppTests/PracticeRecordingConfigurationTests.swift`（若已存在则追加）

---

## 9. 参考的代码文件路径

- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/TTSAudioPlaybackServiceTests.swift`
- `LangoTraceApp/SentenceAudioPlaybackAssembly.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`（了解 TTS probe 播放路径）

---

## 10. 涉及的文档路径

- `docs/plans/active/2026-06-16-bug-tts-audio-session-hfp-routing.md`（本文件）
- `docs/architecture/notes/README.md`（音频会话生命周期协调为架构级备忘，需写入）

---

## 11. Bug 分析

```text
复现方式：
  前置条件：iOS 真机（模拟器不支持真实 BT 设备），配对蓝牙 HFP 耳机（如 AirPods）并连接。
  步骤：
    1. 打开语迹 App，进入练习 Tab。
    2. 选择任意句子，点击"开始跟读"（触发录音）。
    3. 停止或取消录音（录音引擎调用 stop() / cancel()）。
    4. 进入设置 → AI Provider 配置。
    5. 已配置 TTS provider（OpenAI / OpenRouter）的前提下，点击"测试配置"。
    6. Probe 成功后点击语音预览播放按钮（扬声器图标）。
  预期：音频通过 iPhone 扬声器以 TTS 合成音质（44.1kHz / mp3 等）播放。
  实际：音频通过蓝牙 HFP 通道播放，音质明显降低（窄带），听感类似电话通话。

预期行为：
  TTS 预览音频通过 .playback + .spokenAudio 会话播放，路由到扬声器。
  蓝牙耳机若已连接，使用 A2DP 通道（高质量）而非 HFP（通话质量）。

实际行为：
  录音引擎的 .playAndRecord + .allowBluetoothHFP 导致 BT 耳机进入 HFP 通话模式。
  录音停止后 setActive(false) 未能立即使 BT 耳机退出 HFP 模式。
  TTS 播放侧 try? setCategory(.playback) 切换失败（silent fail），
  回退到当前会话的 HFP 路由，音频走通话通道。

根因分析：
  主因：.allowBluetoothHFP 选项在 playAndRecord + spokenAudio 模式下，
        令已配对 BT 耳机同时接管音频输入和输出（双向 HFP 通道）。
        录音结束后 BT 耳机可能仍处于 HFP 模式，后续 TTS 播放受到影响。
  
  次因：TTSAudioPlaybackService.activatePlaybackAudioSessionIfAvailable()
        使用 try? 静默吞掉 setCategory 失败，无法感知冲突，也无法诊断原因。
  
  对比：旧选项 .allowBluetooth（deprecated iOS 17）只允许 BT 作为录音输入，
        输出仍走 .defaultToSpeaker，不触发 HFP 双向模式，TTS 播放不受影响。

置信度：75%

置信度依据：
  - 代码路径已通过源码阅读完整追踪（AppPracticeRecordingEngine → AVAudioSession →
    TTSAudioPlaybackService）
  - 本地 git diff 确认具体改动行
  - 选项语义分析基于 Apple 官方文档（allowBluetooth 为 input-focused，
    allowBluetoothHFP 为 input+output，iOS 17 起 allowBluetooth deprecated）
  - 未在真实设备 + BT 耳机场景复现验证（仅逻辑推断）；无 BT 耳机的纯扬声器场景
    可能不触发此 bug

备选原因：
  A. iOS 版本差异：iOS 17+ 中 .allowBluetooth 行为与 .allowBluetoothHFP 相同，
     两者本质相同，实际 bug 来自其他路径（例如 session 未在 TTS 播放前重新激活）。
     可能性：20%
  B. 操作系统 HFP 退出延迟：录音结束调用 setActive(false) 后，BT 耳机的 HFP
     通道并非立即退出（iOS 系统异步完成，无显式等待 API），导致后续 TTS 播放仍
     走 HFP 路由。注意：这是操作系统级延迟，不是 Swift actor 并发竞态；
     setActive(false) 本身在 actor 内串行执行，问题在于 HFP 退出的系统侧延迟。
     可能性：15%
  C. 用户误判：bug 实际是 TTS probe 本身的问题（如 API 返回格式错误），
     与音频路由无关。可能性：5%

回归测试方案：
  修复后在 iPhone 真机 + AirPods 场景验证：
  1. 练习录音 → 停止 → AI Provider TTS 预览 → 确认音质为扬声器 / A2DP
  2. 无 BT 设备时重复以上步骤，确认行为不变
  3. 快速连续多次触发录音 + 停止 + TTS 播放，验证无竞态
```

---

## 12. 实施方案

### Step 0：TDD 前置微重构——在 `AppPracticeRecordingEngine.swift` 提取选项常量

`AVAudioSession` 是全局单例，运行时状态无法在 macOS 宿主单元测试中验证（`LangoTraceAppTests` 在 macOS 上跑，无法编译 `#if os(iOS)` 分支）。最小可测试方案是将音频会话选项**提取为源文件级常量**，让测试通过**读取源文件内容**断言选项字符串，与现有 `PracticeRecordingConfigurationTests.swift` 中"读 plist / entitlements → 断言"的风格一致。

不需要引入 mock AVAudioSession、不需要修改 `init` 签名、不修改 `PracticeRecordingEngine` 协议。

### Step 1：新增单元测试（先失败，再改代码，再通过）

在 `LangoTraceApp/LangoTraceAppTests/PracticeRecordingConfigurationTests.swift` 追加：

```swift
// 源文件内容扫描——与现有测试"读 .plist / project.yml → 断言"风格一致
// 当前工作区含 .allowBluetoothHFP → 此测试先失败 → Step 2 改代码 → 测试通过
@Test("AppPracticeRecordingEngine 不应使用 allowBluetoothHFP")
func recordingEngineDoesNotUseBluetoothHFP() throws {
    // 相对 #file 向上两级定位到 LangoTraceApp/ 目录下的源文件
    let sourceURL = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()           // LangoTraceAppTests/
        .deletingLastPathComponent()           // LangoTraceApp/
        .appendingPathComponent("AppPracticeRecordingEngine.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    #expect(
        !source.contains("allowBluetoothHFP"),
        "AppPracticeRecordingEngine.swift 不应包含 .allowBluetoothHFP，会激活 HFP 双向通道影响 TTS 播放"
    )
}
```

> **测试可信度说明**：这是文本扫描而非行为验证，无法断言运行时路由结果。局限已在注释中说明。若未来引入 AVAudioSession mock（需重构 `start()` 注入点），可替换为更强的行为测试。

### Step 2：修改 `AppPracticeRecordingEngine.swift`（确认方案 A）

```swift
// 还原为 .allowBluetooth（已获用户确认）
// iOS 17+ deprecated 但功能仍可用；后续 deprecation 迁移只需改录音侧，
// TTS 侧 .allowBluetoothA2DP 已在 Step 3 固定，无需返工。
// 运行 swiftlint 确认 deprecated warning 未被当作 error；若有需要追加
// // swiftlint:disable:next deployment_target
try session.setCategory(.playAndRecord, mode: .spokenAudio,
                        options: [.defaultToSpeaker, .allowBluetooth])
```

### Step 3：修复 `TTSAudioPlaybackService.swift` 会话选项并补充诊断日志

在 `TTSAudioPlaybackService.swift`（`#if canImport(AVFoundation)` 块内）做两处修改：

**修改 1**：在 `DefaultTTSAudioPlaybackEngine` 内追加 logger 常量（文件顶部已有 `import AVFoundation`，补 `import OSLog`）：

```swift
// 在 #if canImport(AVFoundation) 块顶部追加
import OSLog

// actor DefaultTTSAudioPlaybackEngine 内追加：
private static let sessionLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.langotrace",
    category: "TTSPlayback"
)
```

**修改 2**：将 `activatePlaybackAudioSessionIfAvailable()` 从 `try?` 静默失败改为显式 A2DP 选项 + OSLog soft fail：

```swift
private func activatePlaybackAudioSessionIfAvailable() {
    #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // 显式指定 .allowBluetoothA2DP：确保录音会话（可能经历 HFP 模式）
            // 结束后，TTS 播放使用 A2DP 高质量立体声通道而非 HFP 通话通道。
            // .playback 模式下 A2DP 为默认路由，此处显式指定以明确意图并防止回退。
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            // Soft fail: player.play() will surface the error through the existing
            // engine error mapping. Log here so session conflicts with recording
            // sessions can be diagnosed in Console.app without persisting user data.
            Self.sessionLogger.warning(
                "TTS session activation failed: \(error.localizedDescription, privacy: .public) category=\(session.category.rawValue, privacy: .public)"
            )
        }
    #endif
}
```

> **路径 B（DiagnosticLogging 注入）不选用**：需向 `DefaultTTSAudioPlaybackEngine.init` 新增参数、在 `DiagnosticEventName` 新增 case、用 `Task { await ... }` fire-and-forget 包装 async 方法，改动跨模块接口。本任务诊断目标是开发者排查，OSLog 已足够。

### Step 4：追加架构备忘录

**追加到现有文件** `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` 的 §1「AudioSession 与后台播放」小节末尾（该小节已有 BT 耳机 options 交互的待决策清单），补充：

- 本次 bug 案例：`.allowBluetoothHFP` 激活 HFP 双向通道导致 TTS 播放走通话质量音频路由
- `.allowBluetooth` deprecation 迁移路径：iOS 17+ 需切换到 `.allowBluetoothHFP`，但必须同步修复 TTS 播放侧（先配置 `.allowBluetoothA2DP` 或在录音结束后等待 HFP 退出）
- 未来架构隔离方案候选：Session Coordinator / priority queue，在实现录音 + TTS 并发播放（如录音中实时 TTS 提示）时必须重新设计

---

## 13. 严格方案自审核记录

```text
审核日期：2026-06-16
审核方式：主会话并行双轮子代理
           第一轮：系统架构师视角（产品对齐、模块边界、实施链路、并发、异常边界）
           第二轮：测试/安全/落地性视角（TDD 红绿路径、隐私、验证命令、文档影响）
审核轮次：双轮（并行执行）
```

### 第一轮审核摘要（架构师视角）

**P0 问题（审核发现，已在本方案内修正）**

| # | 问题 | 修正位置 |
|---|------|---------|
| P0-1 | 聚焦验证命令使用 `LangoTrace-iOS` scheme，但 `LangoTraceAppTests` target 在 `project.yml` 中为 `platform: macOS`，iOS scheme 无 test targets，命令无法执行 | §15、§16 已改为 `-scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64'` |
| P0-2 | Step 3 伪代码调用 `diagnosticLogger?.logEvent()`，但该方法不存在（`DiagnosticLogging` 协议只有 `record(_ event: DiagnosticEvent) async`），且 `TTSAudioPlaybackService` 无 diagnosticLogger 注入点 | §12 Step 3 改为 `OSLog` 路径（路径 A） |

**P1 问题（已在本方案内修正或标注）**

| # | 问题 | 修正位置 |
|---|------|---------|
| P1-1 | TDD 测试实现机制（mock AVAudioSession）需要重构 `AppPracticeRecordingEngine.start()` 引入注入点，超出本 bug 修复范围 | §12 Step 1 改为源文件内容扫描方案，与现有测试风格一致 |
| P1-2 | 备选原因 A（iOS 17+ `.allowBluetooth` 行为与 `.allowBluetoothHFP` 等价）若成立，仅还原选项不能根治，方案未说明 fallback 路径 | §20 补充了此分支的处置说明 |

**P2 / P3 问题（已修正或确认无需处理）**

- **P2-1**：备选原因 B 的 HFP 退出延迟是操作系统异步行为，不是 Swift actor 层面竞态——§11 表述已修正
- **P2-2**：`cancel()` 文件删除顺序（在 `activeURL = nil` 之前删除）已确认安全，无需改动
- **P2-3**：`.allowBluetooth` 已 deprecated，SwiftLint 可能报 warning——Step 2 补充了检查说明
- **P3-1**：约束 1 与修复直接关联弱，保留但标注为 `info`（已有）
- **P3-2**：Step 4 备忘录文件名及追加目标——Step 4 已改为追加到现有文件
- **P3-3**：`swiftlint --path` 选项合法性——§16 保持与 `verify.sh` 一致用法

---

### 第二轮审核摘要（测试/安全/落地性视角）

**P0 问题（与第一轮交叉，已修正）**

| # | 问题 | 修正位置 |
|---|------|---------|
| P0-1 | 同第一轮 P0-1：验证命令 scheme 错误 | 同上 |
| P0-2 | 当前 `AppPracticeRecordingEngine` 无会话选项注入点，TDD 红绿路径无法写出可编译测试 | §12 Step 1 改为静态常量 + 文件内容扫描方案 |

**P1 问题（已修正）**

| # | 问题 | 修正位置 |
|---|------|---------|
| P1-1 | Step 3 `diagnosticLogger?.logEvent()` API 不存在（同 Round 1 P0-2）| §12 Step 3 已修正 |
| P1-2 | `LangoTraceAppTests` 在 macOS 宿主运行，无法编译 `#if os(iOS)` 分支代码，mock session 方案在此 target 下编译失败 | §12 Step 1 改为平台无关的文件内容扫描，绕过此边界 |

**P2 / P3 问题（已修正）**

- **P2-1**：`session.category.rawValue` 是固定系统枚举字符串，无 PII 风险；OSLog 不持久化到数据库，隐私上更安全
- **P2-2**：`error.localizedDescription` 在 OSLog 路径下标记 `.public`，不持久化，可接受
- **P2-3**：Step 4 建议追加到现有 `2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`——已更新
- **P2-4**：Speech package 的 `#if os(iOS)` session 激活分支在 macOS 测试中不可见——§16 补充了说明
- **P3-2**：§11 复现步骤中"模拟器"不支持真实 BT 硬件——已修正为仅真机
- **P3-3**：§7 约束 3 表述与新 TDD 步骤对齐——已更新

---

```text
仍需用户确认的问题：
  1. Step 2 方案选择：
     - 方案 A（还原 .allowBluetooth）：保留 BT 耳机麦克风能力，有 iOS 17 deprecated 警告
     - 方案 B（仅 .defaultToSpeaker）：无 deprecated 警告，但有 BT 耳机的用户无法使用耳机麦克风录音
  2. Step 3 已明确选路径 A（OSLog），无需额外确认
  3. Step 4 已明确改为追加到现有备忘录，无需额外确认

是否允许进入实现：
  P0 问题已在方案内部修正；用户确认 Step 2 方案选择后可进入 Step 0 + Step 1（TDD）实现
```

---

## 14. 复查方法

1. **代码层（录音侧）**：`grep -n "allowBluetooth" LangoTraceApp/AppPracticeRecordingEngine.swift` 确认选项为 `.allowBluetooth`，不含 `HFP`。
2. **代码层（TTS 侧）**：`grep -n "allowBluetoothA2DP" Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift` 确认 TTS session 已显式指定 `.allowBluetoothA2DP`。
3. **日志层**：运行 App，触发录音 → TTS 播放，通过 Console.app 检索 category `TTSPlayback` 的 warning 日志，确认正常路径下无 session 激活失败日志。
4. **行为层**：在 iPhone 真机 + AirPods 场景，完整走录音 → 停止 → TTS 预览路径，确认 TTS 音频走 AirPods A2DP 高质量通道，不走 HFP 通话通道。
5. **单元测试**：`xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests/PracticeRecordingConfigurationTests` 通过（见第 16 节）。

---

## 15. TDD / 测试落点

```text
测试落点：
  - LangoTraceApp/LangoTraceAppTests/PracticeRecordingConfigurationTests.swift（已存在）
  - 测试类：PracticeRecordingConfigurationTests
  - 新增测试：recordingEngineDoesNotUseBluetoothHFP()

先失败用例：
  - 函数名：recordingEngineDoesNotUseBluetoothHFP
  - 预期失败原因：当前工作区的 AppPracticeRecordingEngine.swift 包含 "allowBluetoothHFP"
    字符串，文件内容扫描断言应失败
  - 实现方式：读取 AppPracticeRecordingEngine.swift 源文件内容并断言不含
    "allowBluetoothHFP"，与现有测试的"读 plist / entitlements → 断言"风格一致
  - 无需 mock AVAudioSession，无需重构 start()，在 macOS 宿主可编译并正确
    报告失败 / 通过
  - 步骤顺序：先写测试并确认失败 → Step 2 改生产代码 → 确认测试通过

聚焦验证命令（LangoTraceAppTests 在 macOS 宿主，使用 macOS scheme）：
  xcodebuild test -scheme LangoTrace-macOS \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:LangoTraceAppTests/PracticeRecordingConfigurationTests

不新增单元测试的原因（如适用）：
  不适用——本次必须新增。源文件扫描是可实现的最小 TDD 路径；
  运行时路由验证需要真实 BT 硬件，由人工验证补充（§11 回归测试方案）。
```

---

## 16. 验证命令

```bash
# 聚焦验证：录音配置测试
# 注意：LangoTraceAppTests 在 macOS 宿主（project.yml platform: macOS），
#       必须用 LangoTrace-macOS scheme + macOS destination
xcodebuild test -scheme LangoTrace-macOS \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:LangoTraceAppTests/PracticeRecordingConfigurationTests

# Speech package 测试（确认 TTSAudioPlaybackService 改动无退化）
# 注意：#if os(iOS) 的 session 激活分支在 macOS 测试环境不可见；
#       该分支的最终覆盖依赖 CI iOS 构建
swift test --package-path Packages/LangoTraceSpeech

# SwiftFormat / SwiftLint 快查（包含 deprecated warning 检查）
swiftformat --lint LangoTraceApp/AppPracticeRecordingEngine.swift \
  Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift \
  --exclude .build,build,DerivedData --cache ignore
swiftlint --no-cache
```

---

## 17. 文档影响检查

| 文档 | 是否受影响 | 说明 |
|------|-----------|------|
| `docs/plans/active/`（本文件） | ✅ 创建 | 本 Bug 修复方案 |
| `docs/architecture/notes/README.md` | ✅ 新增备忘录 | 音频会话生命周期隔离问题 |
| `docs/spec/` | 否 | 无 spec 涉及具体音频会话选项 |
| `docs/decisions/` | 否 | 不涉及 ADR 级变更 |
| `docs/workflows/add-tts-provider.md` | P3 可选 | 可在 checklist 中补充"录音 session 与 TTS 会话冲突检查"条目 |
| `docs/review/` | 否 | 不触发专项审查门槛（非 DB / AI Provider / StoreKit 变更） |

---

## 18. 实施记录

实施日期：2026-06-16
实施方式：AI 辅助开发会话

**Step 1（TDD）**：在 `LangoTraceAppTests/PracticeRecordingConfigurationTests.swift` 追加 `testRecordingEngineDoesNotUseBluetoothHFP()`，采用源文件内容扫描方案（与现有测试 `repositoryRoot()` 风格一致）。先确认测试失败（当前代码含 `allowBluetoothHFP`）。

**Step 2**：将 `AppPracticeRecordingEngine.swift:55` 的 `.allowBluetoothHFP` 还原为 `.allowBluetooth`，确认测试通过。

**Step 3**：修改 `TTSAudioPlaybackService.swift`：
- 在 `#if canImport(AVFoundation)` 块追加 `import OSLog`
- `DefaultTTSAudioPlaybackEngine` 中追加 `private static let sessionLogger`
- `activatePlaybackAudioSessionIfAvailable()` 改为显式 `.allowBluetoothA2DP` 选项 + `do-catch` + OSLog warning

**Step 4**：在 `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` §1 末追加 §1.1 蓝牙路由冲突案例、deprecation 迁移路径和未来并发场景说明。

**验证结果**：
- TDD 红绿：先失败，修复后通过 ✅
- `PracticeRecordingConfigurationTests`（4 项）全绿 ✅
- `LangoTraceSpeech` package 测试（25 项）全绿 ✅
- SwiftFormat lint 0 文件需要格式化 ✅
- SwiftLint 0 serious violations ✅（295 pre-existing warnings 无新增）

---

## 19. 完成标准

1. `AppPracticeRecordingEngine.swift` 中音频会话选项还原为 `.allowBluetooth`（方案 A，已确认）。
2. `TTSAudioPlaybackService.swift` 的 `activatePlaybackAudioSessionIfAvailable()` 已显式加入 `.allowBluetoothA2DP` 选项，且 session 激活失败改为带 OSLog warning 的 soft fail。
3. 新单元测试 `recordingEngineDoesNotUseBluetoothHFP` 通过：`xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests/PracticeRecordingConfigurationTests`。
4. `Packages/LangoTraceSpeech` 全量测试通过：`swift test --package-path Packages/LangoTraceSpeech`。
5. 架构备忘录已追加到 `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`。
6. SwiftFormat / SwiftLint 无新增违规（`swiftlint --no-cache` 通过，包含 deprecated warning 检查）。

---

## 20. 剩余风险

1. **`.allowBluetooth` iOS 17 deprecation**：`.allowBluetooth` 已 deprecated，未来 iOS 版本可能移除。TTS 播放侧已在本次任务中固定为 `.allowBluetoothA2DP`，后续 deprecation 迁移**只需**将录音侧 `.allowBluetooth` 改为 `.allowBluetoothHFP`（两者在 iOS 17+ 行为等价，`.allowBluetoothHFP` 为当前推荐），无需 TTS 侧返工。届时新建独立任务方案。

2. **备选原因 A 成立时的影响已大幅缩小**（可能性 20%）：即使 iOS 17/18 中 `.allowBluetooth` 运行时行为与 `.allowBluetoothHFP` 等价（录音激活 HFP），本次修复的 TTS 侧 `.allowBluetoothA2DP` 会显式请求 A2DP 路由，大幅降低 HFP 路由残留的影响。
   - 验证方法：修复后必须在 iPhone 真机 + iOS 17/18 + AirPods 场景人工验证（CI 模拟器无 BT 硬件）。
   - 若真机验证后 TTS 仍偶发走 HFP 路由：参见风险 3（HFP 退出延迟），需引入 `routeChangeNotification` 监听。

3. **HFP 退出延迟（备选原因 B，15%）**：系统异步完成 BT HFP → A2DP 切换，与 Swift actor 并发无关。TTS 侧已显式指定 `.allowBluetoothA2DP`，可缩短路由恢复时间，但无法完全消除操作系统侧的过渡延迟。若修复后偶发 TTS 仍在极短时间内走 HFP 路由，需引入 `AVAudioSession.routeChangeNotification` 等待退出信号（架构级任务，超出本次范围，已记录为架构备忘录候选）。

4. **Speech package iOS session 激活分支无 CI 单测覆盖**：`#if os(iOS)` 分支在 macOS test target 不可见；`.allowBluetoothA2DP` 和 OSLog 改动的正确性依赖 iOS CI 构建验证和人工 Console.app 检查，无自动化断言。
