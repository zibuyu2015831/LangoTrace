---
title: 导出/备份 deferred 切片与恢复入口（E10）
summary: E10 仅落地 Slice 1（非敏感主数据导出/导入引擎）；macOS 文件面板、附件打包、加密备份、其余主数据表 deferred，本备忘录记录恢复入口。
keywords: export | import | backup | encryption | E10 | deferred
related_files: docs/plans/active/2026-06-11-13-feature-import-export-backup.md | docs/spec/007-data-storage-migration-export-and-attachments.md
verified_at: 2026-06-18
---

# 导出/备份 deferred 切片（E10，2026-06-18）

E10 在批量 run 中按切片落地。**Slice 1 已实现并 CI 绿**：Core `ImportExport`（PortableEntry/Memory snapshot、ExportManifest、SHA-256 payload checksum、format-version 门）+ Data `GRDBLocalExportService`（导出 entries + deposited memory 为明文 JSON 包、preview、verify-before-write 同 id skip 合并）。无新 migration；无加密（secrets 是**排除**而非保护，核心决策 9）。

以下 **deferred**，各有明确恢复入口：

1. **macOS 文件面板 UI（Slice 2，需 macOS runner 验证）**：`fileExporter`/`fileImporter`、`com.apple.security.files.user-selected.read-write` entitlement、security-scoped URL、目录包写盘。接线点 `MacWorkspaceContentView.swift` 的 `.importExport` case（当前仍 unavailable 占位）。引擎 `GRDBLocalExportService.exportPackageData`/`importPackage(packageData:)` 已就绪，Slice 2 只需把 Data 接到文件面板。
2. **附件文件打包（Slice 2）**：照片原图 / 练习录音的 `attachments/` 打包是对 `media_artifacts` 默认 excluded-from-export policy 的显式用户授权覆盖；缩略图 + TTS 文件不打包（可重建）。需 macOS 文件 IO + 逐文件 SHA-256。
3. **加密 / 口令备份包（独立方案）**：依赖当前**不存在**的 KDF / 密钥管理 / 加密-at-rest 安全存储（现仅有 Keychain 存 AI key 引用）。在该基础设施落地前不实现；凭证永不进导出包（决策 9）。
4. **其余主数据表导出**：learning_materials(+sentences/revision_notes)、reading 域主表、practice_sessions/practice_text_attempts、entry_photo_attachments 元数据。Slice 1 引擎格式（manifest + snapshot 家族 + checksum + 同 id skip）已证明，扩展为机械添加 snapshot 类型 + 读/写 SQL。

**永久排除**（非 deferred）：keychain 列 / secret_presence / provider+TTS 配置、ai_request_logs 与各 operation 摘要（诊断/运行期）、memory_candidates/practice_candidates/search_index/reading_document_search_index/reading_explanation_cache/tts_audio_artifacts（可重建派生，决策 12）、app_state（设备本地）。
