# ADR-007: 同步引擎架构（Sync Engine + Adapter + 修订/冲突模型）

日期：2026-06-18

状态：Accepted

## 背景

ADR-005 与核心决策 13 确立「同步采用 Sync Engine + Adapter 思路，iCloud / WebDAV / S3 / R2 作为适配器，不绑定 CloudKit-only」。E11 把该原则具体化为可落地、可测试的引擎抽象，并明确首通道（iCloud/CloudKit）的诚实 defer 边界——因为 iCloud container 需要付费 Apple Developer capability、portal 注册、真实账号与多设备，CI 与当前环境均无法验证。

## 决策

同步采用一个**与具体后端无关的纯逻辑 Sync Engine** + 一个**可替换的 Adapter 协议**：

1. **`SyncRecord`（不透明、按修订戳）**：`(id, kind, revision, updatedAt, payload, isDeleted)`。引擎不解析 `payload`，因此与具体表、与 GRDB 解耦。payload 仅承载非敏感主数据（与 E10 导出同源的 snapshot）。
2. **`SyncAdapter` 协议**：`fetchChanges(since:)` / `push(_:)`。iCloud/CloudKit、WebDAV、S3 都只是该协议的实现；引擎不引用任何后端类型。
3. **`SyncEngine.synchronize(local:adapter:cursor:)`（纯逻辑）**：拉取远端变更 → 按 id 解决冲突 → 计算收敛集合 → 推送远端缺失或落后的记录。确定性，可用 fake adapter 完整单测，零网络。
4. **冲突策略（v1）= last-writer-wins**：先比 `revision`，相等再比 `updatedAt`，完全相等保留本地。删除 tombstone（更高 revision）压过编辑，反之亦然。可预测、可向用户解释。
5. **隐私边界（继承决策 9/12，不反转）**：secrets（Keychain）、provider/TTS 凭证、可重建派生数据（FTS/向量/缓存/TTS 音频）、设备本地状态（`app_state`/device id）**永不**进入 `SyncRecord`；该排除由「本地 store 提供什么」强制，不由引擎判断。
6. **首通道 iCloud/CloudKit 诚实 defer**：真实 `CloudKitSyncAdapter`、iOS/macOS iCloud entitlement、container 注册、CloudKit schema、双设备/双账号验证依赖当前不存在的基础设施，按 build-to-verifiable-boundary 原则延后；引擎/适配器协议/冲突逻辑先落地并单测。恢复入口见 `docs/architecture/notes/2026-06-18-sync-engine-deferred-channel.md`。
7. **变更跟踪 schema（sync_metadata + tombstones，v27+）与各 repository 写路径挂钩**随真实通道一并落地（deferred），届时提供 `SyncRecord` 的 GRDB 本地 store。

## 影响

- `LangoTraceSync` 从空 marker 协议升级为真实 `SyncService`（`isEnabled` + `synchronize()`）+ `SyncEngine`/`SyncAdapter`/`SyncConflictResolver`/`SyncRecord`。
- 不绑定任何后端；新增同步通道 = 新增一个 `SyncAdapter` 实现，引擎与冲突逻辑不变。
- 与 E10 导出的 Portable snapshot 同源（payload 复用同一非敏感主数据序列化），避免两套对象格式。

## 复审条件

- 接入真实 iCloud/CloudKit 通道时，复核冲突策略是否仍以 last-writer-wins 足够，或需 keep-multiple-versions（E11 方案 Slice C 已备纯逻辑）。
- 引入 WebDAV/S3/R2 适配器时，复核 `SyncAdapter` 协议是否需扩展（分页游标、大对象分块）。
