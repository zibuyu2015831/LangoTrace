---
title: 同步引擎 deferred 通道与恢复入口（E11）
summary: E11 落地纯逻辑 Sync Engine + Adapter 协议 + 冲突逻辑 + ADR-007；真实 iCloud/CloudKit 通道、entitlement、变更跟踪 schema 写路径、双设备验证诚实 defer，本备忘录记录恢复入口。
keywords: sync | iCloud | CloudKit | adapter | E11 | deferred
related_files: docs/plans/active/2026-06-11-14-feature-sync-engine-icloud-foundation.md | docs/decisions/007-sync-engine-architecture.md
verified_at: 2026-06-18
---

# 同步引擎 deferred 通道（E11，2026-06-18）

**已实现并 CI 绿**：`LangoTraceSync` 的 `SyncRecord` / `SyncAdapter` 协议 / `SyncConflictResolver`（last-writer-wins）/ `SyncEngine.synchronize`（纯逻辑、fake adapter 单测、双引擎收敛、tombstone 传播）；`SyncService` 升级为真实协议（`isEnabled` + `synchronize()`）；ADR-007 记录架构。

以下 **deferred**（依赖当前不存在的基础设施 / 需真实设备账号验证），恢复入口：

1. **真实 `CloudKitSyncAdapter`**：实现 `SyncAdapter`（fetchChanges/push）对接 CloudKit。`#if canImport(CloudKit)` 包裹，不进引擎单测路径。
2. **iCloud entitlement + container**：iOS 新增 entitlements 文件 + macOS entitlements 加 iCloud 键 + `project.yml` container id；需付费 Apple Developer iCloud capability + portal 注册。**注意**：带 iCloud entitlement 的 build 在无 provisioning 的 CI 可能签名失败——接入时需验证 simulator build（CODE_SIGNING_ALLOWED=NO）不触发校验，否则隔离到 macOS 签名 runner。
3. **变更跟踪 schema（v27+）+ 各 repository 写路径挂钩**：`sync_metadata`（object_kind/object_id/revision/updated_at）+ `tombstones` + 在创建/更新/软删时写 revision/tombstone；GRDB `SyncLocalStore` 把行 ↔ `SyncRecord`（payload 复用 E10 Portable snapshot）。device id 存 `app_state`（设备本地、不同步）。
4. **同步对象范围**：v1 复用已有 `PortableEntrySnapshot`/`PortableMemorySnapshot` + 新建 language space 编码；learning material / reading / practice 同步随其 Portable snapshot（E10 deferred）落地。
5. **冲突 keep-multiple-versions**（E11 方案 Slice C 纯逻辑）+ `SyncSettingsView`：真实通道接入后补。
6. **双设备/双账号人工验证**：四类对象跨设备复制、冲突、删除传播。

**理由**：iCloud container/付费 capability/真实账号/多设备在 CI macOS runner 与当前环境均不存在，无法验证；按 build-to-verifiable-boundary，引擎/适配器协议/冲突逻辑落地并单测，真实通道明确延后，不伪造完成。**永不同步**（非 deferred，是边界）：Keychain/凭证、FTS/向量/缓存/TTS 音频派生、app_state 设备本地。
