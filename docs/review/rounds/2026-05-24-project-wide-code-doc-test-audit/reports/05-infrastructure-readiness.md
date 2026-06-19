# 05 基础设施长期可扩展性审查

状态：Verified

## 1. 审查目标

从“第一版基础设施要长期正确”的角度，审查数据、AI Provider、TTS / Speech、本地媒体、诊断日志、UI / Navigation 和测试基础设施是否只是局部临时实现。

## 2. 已执行证据

- Data / Learning Content：`docs/spec/007-data-storage-migration-export-and-attachments.md:10-37` 与 Data tests 证明 Entry、LearningMaterial、operation 摘要、media artifact metadata 和 TTS audio artifact 已有长期边界。
- AI / TTS：`docs/spec/011-tts-provider-configuration-and-playback.md:2-39` 与 AI/Speech/Core/UI tests 证明 TTS provider 配置、低敏 probe、音频校验、preview playback 和逐句播放前置已落地。
- Sync：`Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift:1-5` 仍只有 disabled boundary；`docs/platform-page-inventory.md` 将同步设置页标为 Local Mock。

## 3. 问题清单

### AUDIT-INFRA-001

问题 ID：AUDIT-INFRA-001
严重度：P2
标题：Sync 仍只有 disabled boundary，但 UI 已有较完整同步设置 mock，后续真实同步前必须先冻结 Sync domain model
问题现状：三端已有 `SyncSettingsView`，展示 iCloud 推荐、S3-compatible 高级草稿、同步范围和密钥边界；但 `LangoTraceSync` package 只有空 `SyncService` 和 `DisabledSyncService`，没有 sync status、adapter input、manifest、tombstone、conflict model、credential boundary 或测试 target。
证据：`docs/platform-page-inventory.md:57`、`docs/platform-page-inventory.md:81`、`docs/platform-page-inventory.md:108` 将同步设置标为 Local Mock；`Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift:1-5` 只有 disabled boundary；`Packages/LangoTraceSync/Package.swift:20-27` 无 test target。
影响范围：同步、对象存储、导出、附件、向量索引、AI Key / 对象存储密钥隔离、跨设备冲突处理。当前 UI 文案已经暴露相当具体的未来同步范围，如果后续直接从 UI draft 推真实 Sync Adapter，容易让 UI shape 反向绑架 domain model。
涉及的代码文件路径：`Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift`、`Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`、`Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsModels.swift`
涉及的文档路径：`docs/platform-page-inventory.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md`
复查方法：读取 Sync package 与 SyncSettings UI；检查 `docs/architecture/notes/` 的同步相关备忘录是否被后续同步 active plan 引用和分流。
优化方案：真实同步前先创建 `refactor` 或 `feature` active plan，冻结最小 Sync domain model：sync object identity、manifest scope、local-only secret exclusion、tombstone、device state、conflict categories、adapter credential boundary 和 test target，再决定 CloudKit / S3 / WebDAV adapter UI 如何落地。
影响：避免 Local Mock UI 直接变成协议事实，降低未来同步和导出返工。
所属维度：基础设施 / 架构 / 三端同步
四维切片：状态同步 / 数据一致性 / 异常边界
建议处理：保留为后续 Sync Engine 前置任务；不在本轮审查中直接实现。
后续落点：同步 active plan、`docs/architecture/notes/` 采纳记录，必要时提升到 `docs/spec/` 或正式 architecture doc。
是否阻塞继续开发：不阻塞非同步功能；阻塞真实同步开发。
需要用户确认：后续进入真实同步设计时需要确认 adapter 路线和密钥恢复边界。

## 4. 修复后覆盖记录

- `AUDIT-INFRA-001`：本轮只完成测试基础边界修复，不把真实 Sync domain model 伪装成已完成。`Packages/LangoTraceSync` 已有 test target 和 disabled boundary test，`scripts/verify.sh` 已纳入 Sync package。
- 仍需后续真实同步前置方案冻结 sync object identity、manifest scope、local-only secret exclusion、tombstone、device state、conflict categories、adapter credential boundary 和三端设置页与 domain model 的映射关系。
- 验证：`swift test --package-path Packages/LangoTraceSync` 和 `scripts/verify.sh` 均通过。
