# Workflow：新增 TTS Provider 或逐句播放能力

适用场景：新增 TTS Provider、语音生成 endpoint、voice profile、TTS probe、样例试听、逐句播放、本地 TTS 音频缓存或播放状态。

## 1. 必读文档

- `docs/README.md`
- `docs/plans/README.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/architecture/notes/README.md`
- `docs/architecture/notes/2026-05-23-tts-provider-extension-notes.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

## 2. 任务方案要求

实现前必须创建或更新 active plan，并明确：

- TTS endpoint 与 voice profile 是否按 `endpoint_id + language_code` 分离。
- 测试文本是否为固定低敏文本。
- 逐句播放是否只由用户点击触发。
- 生成音频是否进入本地媒体派生资产基础设施。
- 配置 fingerprint、cache invalidation、取消、重试和清理策略。
- 是否影响导出、备份、同步或附件化。

## 3. 关键落点

- AI / Provider 层：TTS adapter、probe、endpoint metadata、错误分类。
- Speech package：音频校验、preview playback、播放 coordinator、AudioSession 语义（TTS 播放会话须显式 `options: [.allowBluetoothA2DP]`，`setCategory` 失败须 OSLog warning soft-fail，不得 `try?` 静默吞掉；录音会话不得 `.allowBluetoothHFP`；详见 `spec/011 §13`）。
- Data package：voice profile、validation event、media artifact metadata。
- UI package：设置页 TTS 配置、结果面板、逐句播放按钮和状态。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：长期规则和当前实现边界。

## 4. 测试要求

至少覆盖：

- TTS 测试不发送用户 Entry、learning text、照片、音频、OCR 或历史记忆。
- Text endpoint 失败不默认覆盖 TTS endpoint 结果。
- Voice profile 使用当前语言空间 language code。
- 配置变化后旧音频 artifact 不被误认为当前配置命中。
- 取消播放或生成时状态可恢复。
- 音频文件写入 staging 后原子移动，路径安全且 metadata 可校验。

## 5. 故障与恢复路径

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| Voice 不支持当前语言 | 稳定错误分类，引导更换模型或 voice | adapter / service 测试 |
| 音频不可解码 | 拒绝写入 ready artifact | Speech 校验测试 |
| 生成中取消 | 停止 Provider 请求并保持取消状态 | store / coordinator 测试 |
| 配置 fingerprint 变化 | 旧 artifact 失效或重新生成 | Data / media artifact 测试 |

## 6. 完成前检查

运行相关 package 聚焦测试；涉及播放、缓存、Data migration 或三端共享 seam 时运行 `scripts/verify.sh`。文档-only 变更至少运行 `scripts/check-docs.sh`、占位符扫描、`git diff --check` 和 `git status --short`。

## 7. 反例

- 页面展示或进入详情时自动生成 TTS。
- 把 voice 作为 endpoint 全局字段，覆盖不同语言空间设置。
- 把 TTS 音频放在 UI 临时状态或不可追踪临时目录。
- 把测试文本、用户句子、audio bytes 或 API Key 写入日志。
