# 逐句 TTS 播放基础设施扩展备忘录

状态：Accepted
创建日期：2026-05-24

## 适用范围

本备忘录适用于逐句 TTS generation、持久音频 playback、跨句 playback coordinator、AudioSession、后台播放、流式 TTS、批量预生成、TTS artifact 同步导出和成本预算相关后续设计。

当前触发任务是 `docs/plans/done/2026-05-24-feature-sentence-tts-generation-playback-coordinator.md` 的严格架构复查。本备忘录不是该任务的实施记录，也不替代 `docs/spec/011-tts-provider-configuration-and-playback.md`、正式架构文档或 ADR。后续任务采纳其中任一提醒时，必须写回对应 active plan、spec、architecture 或 ADR。

## 目的

逐句 TTS 播放会把 AI Provider、Keychain、HTTP client、Data media artifact、Speech playback、SwiftUI action contract 和诊断日志串成一条真实用户路径。该路径一旦以临时方式落地，后续后台播放、流式 TTS、同步导出、批量预生成和成本预算会被迫返工。

因此，第一版基础设施即使不实现这些未来能力，也必须保留清晰扩展点：

- 生产 TTS 请求不能绑定到 probe-only HTTP client。
- AI generation 不能直接依赖 Data package concrete staging store。
- Speech playback 不能接受任意 UI 传入 URL。
- Coordinator 核心状态机不能只存在于没有稳定单元测试 target 的 App Shell。
- 诊断必须提前采用 typed event 和 allowlisted attributes，避免未来补日志时泄露用户句子或 secret。

## 已有设计留下的扩展点

### 1. HTTP client

设置页 probe 已有 `AIProviderProbeHTTPClient`，但逐句 TTS 是生产请求、可能产生费用，并且需要更严格的取消、超时、response body size 和错误分类。

后续应把可复用网络能力提升为 `AIProviderHTTPClient` 或等价通用 contract，让 probe、学习材料生成和 TTS generation 共享 production-safe 基础设施。probe 可以继续使用更小 body limit 和 probe-specific result mapping，但不应让生产功能依赖 probe-only 命名和语义。

### 2. Staging writer

`LocalMediaArtifactFileStore` 位于 Data package，负责 App 管理目录、staging、相对路径安全和文件移动。AI package 负责 Provider request 和 response validation，不应直接 import Data concrete。

后续应通过 Core protocol 表达 staging writer，例如 `TTSAudioStagingWriting`。Data package 实现该协议，App Shell 注入给 AI generation service 或 coordinator。这样后续替换文件目录、加密 staging、对象存储 staging 或测试 fake staging 时，不需要改变 AI package 依赖方向。

### 3. Playback source resolver

Speech package 可以使用 AVFoundation 或等价音频引擎播放文件，但不能接受 UI、AI 或任意调用方传入的绝对路径。播放源必须来自 Data package 对 ready `MediaArtifact` 的解析。

后续应通过 Core protocol 表达 ready playback source resolver，例如 `MediaArtifactPlaybackSourceResolving`。Resolver 负责验证 artifact 未 invalidated、type 正确、relative path 安全、文件存在、byte size 和 content hash 匹配。Speech playback service 只接收 resolver 产出的受限 source。

### 4. Coordinator 测试落点

跨句互斥、重复点击、取消、active key recheck、cache hit / miss、commit failure 和 playback failure 都是核心业务状态机，不应只放在 App target 中靠构建验证覆盖。

后续应优先把 transition reducer / coordinator core 放入 Core package；如果需要 `@MainActor ObservableObject` presentation model，可放入 UI package，但底层状态转换仍应保持纯 Swift 可测试。App Shell 只做 production assembly。

App Shell 的 production assembly 也不能长期只靠 build 间接覆盖。逐句 TTS generation / playback / coordinator 基础设施首次落地时，应同步建立轻量 App test target，用于验证 `AppEnvironment` / assembly 能构造真实依赖图、不会回退到 disabled service、且 direct playback UI 尚未越界接入底层 concrete。该 App test target 不承载核心状态机测试；核心状态机仍属于 package-level tests。

### 5. Typed diagnostics

逐句 TTS 诊断需要覆盖 generation 和 playback lifecycle，但不得记录用户句子、完整请求体、完整响应体、audio bytes、API Key、Authorization header、完整 Keychain account、完整文件路径或完整 voice id。

后续应新增 typed diagnostic event name 和 allowlisted attributes。允许记录 operation id、provider preset id、endpoint purpose、model name、adapter kind、output format、text length bucket、byte size bucket、duration bucket、cache result、failure category 和 elapsed milliseconds。

## 后续任务必须重新决策的问题

### 1. AudioSession 与后台播放

第一版逐句播放只承诺前台播放。进入后台播放、锁屏控制、远程控制中心或系统音频中断恢复前，必须重新决策：

- AudioSession category / mode / options。
- 与系统静音开关、其他音频 App 和蓝牙耳机的交互。
- App 进入后台时是停止、暂停还是继续播放。
- 电话、Siri、耳机拔出、系统中断后的恢复策略。
- iOS、iPadOS、macOS 是否采用同一语义。
- 这些能力是否改变 App Store 隐私说明或后台模式声明。

#### 1.1 蓝牙 HFP / A2DP 路由冲突案例（2026-06-16 修复）

已发生的 bug（见 `docs/plans/done/2026-06-16-bug-tts-audio-session-hfp-routing.md`）：

- **根因**：`AppPracticeRecordingEngine` 录音会话使用 `.allowBluetoothHFP`，令已连接的 BT 耳机进入 HFP 双向通道（8–16kHz 通话模式）。录音停止 `setActive(false)` 后，BT 耳机在 OS 层异步退出 HFP，TTS 播放侧原 `try? setCategory(.playback, mode: .spokenAudio)` 切换失败（silent fail），音频继续走 HFP 路由，TTS 听感变为通话质量。
- **已修复**：
  - 录音侧恢复 `.allowBluetooth`（input-focused，不触发双向 HFP）。
  - TTS 播放侧显式加入 `.allowBluetoothA2DP`，强制 A2DP 高质量立体声路由；`try?` 改为带 OSLog warning 的 soft fail。
- **`.allowBluetooth` deprecation 迁移路径**（iOS 17 已 deprecated）：
  - 待 `.allowBluetooth` 被移除时，录音侧迁移到 `.allowBluetoothHFP`（iOS 17+ 的推荐替代，两者行为等价）。
  - 迁移时必须同步确认 TTS 播放侧已显式 `.allowBluetoothA2DP`（本次修复已固定），避免 HFP 通话通道残留影响 TTS 音质。
  - TTS 侧无需额外返工：`.allowBluetoothA2DP` 在 `.playback` 模式下始终强制走 A2DP，对录音侧使用何种 BT 选项不敏感。
- **未来并发场景**（录音中同时 TTS 提示）：`.playAndRecord` 模式下蓝牙协议限制 A2DP 与麦克风互斥，全双工场景必须重新设计 Session Coordinator / priority queue，作为独立架构任务，不复用当前顺序场景的修复方案。

### 2. Streaming TTS

第一版逐句播放使用 non-streamed request。后续若接入 streaming TTS、WebSocket 或 provider-specific partial audio，需要重新设计：

- partial audio 是否可以边生成边播放。
- 取消时已收到 partial audio 是否保存、删除或标记失败。
- partial artifact metadata、staging 文件和 ready commit 的一致性。
- 播放开始延迟、buffer underrun 和 retry 策略。
- streaming request 是否仍适用单句点击低摩擦隐私边界。

### 3. 批量预生成与成本预算

第一版只在用户显式点击单句时请求 TTS，并依赖本地 artifact 避免重复扣费。后续若支持全文朗读、批量预生成或离线包，需要重新决策：

- 是否展示费用提醒、字符数估算或 Provider 计费提示。
- 是否需要本地每日预算、队列、暂停、取消和失败恢复。
- Provider rate limit / quota error 如何进入 UI。
- 批量任务是否允许后台继续。
- 预生成是否复用单句 artifact key，还是生成 document-level artifact。

批量预生成不得复用“单句点击播放”的低摩擦边界。

### 4. TTS artifact 同步、导出与备份

当前 TTS audio artifact 默认 local-only、excluded from system backup、excluded by default from export。后续若同步、导出或可恢复备份音频，需要重新决策：

- 音频是用户数据、派生数据、可重建缓存还是混合类型。
- 多设备是同步 audio bytes、同步 metadata 后按需重生成，还是完全不复用。
- manifest 是否需要记录 provider、model、voice、format、hash、license 和 deletion state。
- 是否需要加密、删除传播、冲突处理和恢复校验。
- Provider / voice 条款是否限制导出或跨设备分发。

在正式方案前，逐句 TTS audio bytes 不进入同步目录、默认导出或可恢复备份。

### 5. 本地 TTS Provider 与 Apple system voice

后续若引入 Apple `AVSpeechSynthesizer` 或第三方本地 TTS 引擎，需要重新决策：

- 本地 Provider 是否仍使用 `.tts` endpoint 和 voice profile。
- 本地 voice 可用性是否需要 probe。
- 本地生成是否写入同一 `LocalMediaArtifactStore`。
- 本地 voice 的平台差异如何影响 cache key。
- 本地 TTS 是否作为无外部请求的隐私优先兜底。

本地 TTS 不应伪装成 OpenAI-compatible adapter。

## 不应在当前阶段提前实现的内容

当前逐句 TTS generation / playback / coordinator 基础设施任务不实现：

- 后台播放、锁屏控制、远程控制中心。
- 完整 AudioSession 中断恢复策略。
- Streaming TTS、WebSocket TTS 或 partial audio artifact。
- 批量预生成、全文朗读队列、离线包。
- TTS 成本预算 UI、额度阈值、Provider 用量统计。
- TTS audio bytes 同步、默认导出、可恢复备份或附件 manifest。
- Apple system voice / 本地 TTS Provider。

这些能力进入实现前，必须创建或更新对应 active plan，并检查本备忘录是否需要提升为正式 spec、architecture 文档或 ADR。

## 关联文档

- `docs/plans/done/2026-05-24-feature-sentence-tts-generation-playback-coordinator.md`
- `docs/plans/done/2026-05-23-feature-direct-sentence-tts-playback.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md`
