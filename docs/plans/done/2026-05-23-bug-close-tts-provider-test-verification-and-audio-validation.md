# 任务方案：收口 TTS Provider 测试验证与音频解码验收

状态：Verified
类型：bug
创建日期：2026-05-23
最后更新：2026-05-23

## 1. 用户确认记录

- 2026-05-23：用户说明当前代码改动来自已完成的 `docs/plans/done/2026-05-23-feature-tts-provider-configuration-test.md`，要求检查该方案是否完整实施。
- 2026-05-23：复查发现主体链路已实施，但存在两个收口问题：`scripts/verify.sh` 未运行 `Packages/LangoTraceSpeech` 测试；Speech 层 MP3 校验只做 header sniffing，不能作为长期 TTS Provider 音频可播放验收。
- 2026-05-23：用户要求按早期开发、基础设施优先、docs 控制面和未来扩展备忘录原则评估，并确认“立即进行，创建对应的方案文档并立即执行”。

## 2. Bug 描述

`docs/plans/done/2026-05-23-feature-tts-provider-configuration-test.md` 已将 TTS Provider 配置测试推进到 Core / Data / AI / Speech / UI 多模块链路，但验证和音频验收仍有缺口：

1. `scripts/verify.sh` 作为 Swift 工程收尾门禁，没有运行 `Packages/LangoTraceSpeech` 的 package 测试。
2. `DefaultTTSAudioValidationService` 对 `.mp3` 只检查 `ID3` 或 `0xFF` 起始字节，无法证明 Provider 返回的 MP3 bytes 可被 Apple 平台音频栈解码或播放。

这会削弱 TTS Provider 测试的真实价值：用户点击“测试”后看到成功时，应代表当前 model / voice / language / format 组合返回了可播放音频，而不是只返回了看起来像音频的二进制。

## 3. 复现方式

1. 读取 `scripts/verify.sh`，确认只运行 Core、Data、AI、UI package 测试，未运行 Speech package 测试。
2. 读取 `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioValidationService.swift`，确认 `.mp3` 分支只检查 magic bytes。
3. 构造 `Data([0x49, 0x44, 0x33])` 作为声明为 MP3 的响应；当前实现会通过 MP3 分支并返回成功 metadata，尽管它不是完整可播放音频。

## 4. 预期行为

- `scripts/verify.sh` 必须运行 `swift test --package-path Packages/LangoTraceSpeech`。
- Speech package 必须成为 TTS 音频校验 / preview seam 的自动化验证入口。
- `DefaultTTSAudioValidationService` 必须通过 Core 协议边界接收 bytes，并在 Speech 模块内使用 AVFoundation 或等价 Apple 音频解码能力验证音频可解码。
- `.mp3` 不能仅凭 `ID3` 或 `0xFF` 起始字节通过；不可解码 bytes 必须返回 `.audioDecodeFailed`。
- AI package 仍不得直接依赖 `LangoTraceSpeech`；音频校验仍通过 `TTSAudioValidationService` 协议注入。

## 5. 实际行为

- `scripts/verify.sh` 第 8-11 行只运行 Core、Data、AI、UI 测试。
- `.mp3` 分支只做 header sniffing，并将 duration / sampleRate 留空。
- `docs/spec/009-testing-and-verification.md` 已经声明 TTS Provider 任务必须运行 Speech 测试，但统一脚本未同步。

## 6. 根因分析

置信度：95%

根因是 TTS Provider 配置测试实施时新增了 Speech package test target 和 Speech seam，但统一验证脚本仍停留在新增 Speech 前的模块列表；同时第一阶段音频校验为了快速闭环保留了过轻的 MP3 header 检查，没有把“Provider 测试成功必须意味着音频可解码”作为基础设施硬边界落入代码。

置信度依据：

- `docs/spec/009-testing-and-verification.md` 已明确 TTS Provider 配置任务必须运行 Speech package 测试。
- `scripts/verify.sh` 未包含 Speech package 测试。
- `.mp3` 当前实现没有调用 AVFoundation 解码 API。
- 现有 Speech 测试未覆盖“伪 MP3 header 不得通过”。

备选原因：

- 如果 AVFoundation 在 Swift package 单元测试中对部分格式支持不稳定，可能需要在 Speech 层引入可注入的解码器 seam，以单元测试证明策略与错误分类，并用 Apple 平台运行期验证真实解码能力。

## 7. 目标

- 补齐 TTS Provider 配置测试的统一验证闭环。
- 将 Speech 音频校验升级为长期可扩展的基础设施边界。
- 保持 AI / Speech 依赖方向正确：AI 只依赖 Core 协议，Speech 实现音频解码。
- 不引入持久音频缓存、逐句播放协调器或 `LocalMediaArtifactStore` 实现。

## 8. 不做什么

- 不实现直接逐句 TTS 播放。
- 不实现持久音频文件缓存。
- 不接入新的 TTS Provider。
- 不改变 OpenAI / OpenRouter TTS adapter 请求语义。
- 不重构 AI Provider 设置页布局。

## 9. 涉及的代码文件路径

- `scripts/verify.sh`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioValidationService.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/TTSAudioValidationTests.swift`

## 10. 涉及的文档路径

- `docs/plans/active/2026-05-23-bug-close-tts-provider-test-verification-and-audio-validation.md`
- `docs/plans/done/2026-05-23-feature-tts-provider-configuration-test.md`
- `docs/spec/009-testing-and-verification.md`

## 11. 实施方案

1. 在 Speech 测试中先新增失败用例：伪 MP3 header bytes 不得通过校验，应返回 `.audioDecodeFailed`。
2. 在 Speech 层引入内部解码边界，用 AVFoundation 对音频 bytes 进行可解码验证，并读取可得 duration。
3. 保留 WAV parser 的确定性 metadata 能力，但让 MP3 成功路径依赖真实解码结果，不再只依赖 magic bytes。
4. 将 `scripts/verify.sh` 增加 `swift test --package-path Packages/LangoTraceSpeech`。
5. 轻量修订 done 方案，将旧代码现状标注为“实施前快照”，避免后续 AI 会话误读为当前事实。
6. 运行 Speech 聚焦测试、受影响 AI 测试和完整 `scripts/verify.sh`。

## 12. 回归测试方案

- RED：新增 `Validator rejects MP3 header bytes that are not decodable audio`，在当前代码下应失败，因为伪 MP3 会被接受。
- GREEN：实现真实解码边界后，该测试应通过。
- 聚焦测试：`swift test --package-path Packages/LangoTraceSpeech`
- AI 边界测试：`swift test --package-path Packages/LangoTraceAI`
- 完整验证：`scripts/verify.sh`

## 13. 文档影响检查

- `docs/spec/009-testing-and-verification.md` 已包含 Speech 测试门禁；本任务只需通过脚本同步落实，不需要新增规范。
- done 方案是历史记录，不应重写实施过程；只允许做防误读标注。
- 本任务不创建未来开发备忘录，因为问题属于当前 TTS Provider 测试基础设施闭环缺陷，不是未来扩展能力。

## 14. 完成标准

- Speech package 有回归测试证明伪 MP3 header 不会被当作成功音频。
- Speech 实现不再以 MP3 magic bytes 作为成功条件。
- `scripts/verify.sh` 覆盖 Speech package 测试。
- done 方案中的实施前代码现状不会被误读为当前事实。
- 聚焦测试和完整验证通过；如果完整验证失败，必须记录失败原因和剩余风险。

## 15. 剩余风险

- AVFoundation 对不同音频格式的 metadata 可得性可能不一致；第一阶段只要求可解码与 byte count，duration / sampleRate 按平台能力尽力返回。
- 真实 Provider 可能返回 content-type 不规范但可播放的音频；本任务不放宽现有 content-type 边界，后续如遇实际 Provider 兼容性问题再按 evidence 调整。

## 16. 实施记录

- 2026-05-23：新增 Speech 回归测试 `validatorRejectsMP3HeaderBytesThatAreNotDecodableAudio`。RED 验证命令 `swift test --package-path Packages/LangoTraceSpeech --filter TTSAudioValidationTests/validatorRejectsMP3HeaderBytesThatAreNotDecodableAudio` 已确认失败，失败原因为伪 MP3 header bytes 被旧实现误判为 `.succeeded`。
- 2026-05-23：将 `.mp3` 音频验收改为调用 Speech 模块内 AVFoundation 解码边界，解码失败返回 `.audioDecodeFailed`，不再仅凭 magic bytes 判定成功。
- 2026-05-23：将 `scripts/verify.sh` 增加 `swift test --package-path Packages/LangoTraceSpeech`，使统一验证脚本符合 `docs/spec/009-testing-and-verification.md` 的 TTS 门禁。
- 2026-05-23：轻量修订已完成 TTS Provider 配置测试方案，将原“当前代码现状”标注为“实施前代码现状快照”，避免后续 AI 会话误读历史事实。
- 2026-05-23：GREEN 验证命令 `swift test --package-path Packages/LangoTraceSpeech --filter TTSAudioValidationTests/validatorRejectsMP3HeaderBytesThatAreNotDecodableAudio` 通过；`swift test --package-path Packages/LangoTraceSpeech` 通过，5 个测试通过；`swift test --package-path Packages/LangoTraceAI` 通过，69 个测试通过。
- 2026-05-23：完整验证命令 `scripts/verify.sh` 通过。该脚本本轮已覆盖 `swift test --package-path Packages/LangoTraceSpeech`、iPhone build、iPad build、macOS build、SwiftLint、SwiftFormat 和文档占位扫描；SwiftLint 仍有既有 warning，但 0 serious，脚本退出码为 0。
- 2026-05-23：文档任务检查已完成：`find docs -maxdepth 3 -type f | sort` 通过；占位扫描无命中；`git diff --check` 通过；`git status --short` 仅显示本任务相关改动。
