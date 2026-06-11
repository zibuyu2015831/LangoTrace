# 任务方案：同步引擎与 iCloud 首通道基础（Sync Engine + Adapter + CloudKit）（E11）

状态：Draft
自审核状态：Reviewed
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-11

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（[2026-06-11-chore-code-review-and-dev-plan-series.md](2026-06-11-chore-code-review-and-dev-plan-series.md)）。该授权仅覆盖"方案文档创建"；本方案进入实现前仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。本方案是系列中体量最大（XL）、风险最高的任务，按第 12 节切成三个可独立确认与收口的子切片；每个子切片进入实现前建议单独向用户复述范围。

## 1. 需求或 bug 描述

实现语迹的真实同步基础：

1. 同步元数据基础设施：独立 `sync_metadata` 表、变更跟踪（local revision）、tombstone 表与删除传播基础。
2. `Packages/LangoTraceSync` 中的 Sync Engine + Adapter 架构（核心决策 13），CloudKit 作为第一个 Adapter 通道。
3. 首版固定同步范围四类对象：语言空间、生活记录（entries）、学习材料（learning materials 及其句子 / 修改说明 / 候选）、记忆词句（memory items）；附件与练习录音排除在 v1 之外。
4. 冲突策略：保守的 keep-multiple-versions（不静默丢任一侧数据）。
5. `SyncSettingsView` 从 Local Mock 接到真实引擎状态。

## 2. 现状描述

以下事实已对照当前代码（2026-06-11 HEAD）核实：

- `Packages/LangoTraceSync` 是显式占位：`Sources/LangoTraceSync/SyncBoundary.swift` 只有空接口 `SyncService` 协议与 no-op `DisabledSyncService`；`Tests/LangoTraceSyncTests/SyncBoundaryTests.swift` 只验证 Disabled 边界。`AppEnvironment` 装配 `DisabledSyncService`。
- `SyncSettingsView`（`Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`）是外观接近真实的 Local Mock：`@State var draft = SyncSettingsDraft()` 本地草稿，含 `SyncMethodOption`（iCloud 推荐 / S3 高级）、`SyncScopeItem` / `SyncScopeKind`（included / offByDefault / localRebuild / localKeychainOnly 状态枚举）、`SyncStatusCard`、`ICloudSyncPreviewView`；没有任何持久化或引擎接线。
- 数据层没有 sync_metadata、tombstone、revision 或 device id；`language_spaces.deleted_at` 只是本地 soft delete（[2026-05-20-language-space-sync-extension-notes.md](../../architecture/notes/2026-05-20-language-space-sync-extension-notes.md) §3.3 明确它不等同 tombstone）。
- `app_state.current_language_space_id` 与主表分离（同备忘录 §2 预留点），按 §3.1 推荐不参与同步。
- entitlements 现状：macOS entitlements 无 iCloud / CloudKit 键；iOS 无 entitlements 文件（`project.yml` 仅 macOS target 配置 `CODE_SIGN_ENTITLEMENTS`）。CloudKit 通道需要双端 entitlement 与 container 配置。
- E10 的 12.1 节已决策"一套对象序列化（PortableSnapshot）、两种信封"；本方案同步信封必须复用该对象编码。
- 核心决策约束：决策 9（敏感凭证只入 Keychain、默认不同步）、决策 12（向量索引 / FTS 等派生数据默认不同步）、决策 13（Sync Engine + Adapter，不绑定 CloudKit-only）。

## 3. 目标

1. Slice A——元数据与变更跟踪基础：`sync_metadata`、`tombstones` 表落地（migration），四类对象的写路径产生 revision 递增与 tombstone；device id 设备级生成与保存；对用户行为零可见变化。
2. Slice B——引擎与 iCloud happy path：`SyncEngine`（变更收集、push / pull、应用远端变更）、`SyncAdapter` 协议、`CloudKitSyncAdapter` 首实现、entitlement / container 配置、手动触发同步即可在两台设备间复制四类对象。
3. Slice C——冲突与设置接线：keep-multiple-versions 冲突落地（冲突双方都保留，冲突项进入用户可见待处理状态）、tombstone 与编辑冲突的保守处理、`SyncSettingsView` 接真实引擎（启用 / 停用、上次同步时间、冲突计数、范围披露行反映真实 policy）。
4. 全程满足：Keychain 内容永不进入同步对象；FTS / 向量 / TTS 缓存 / 练习录音不同步；`current_language_space_id` 不同步；不把数据库文件整体当同步对象。
5. 实现过程中产出两份长期文档：新 ADR（同步引擎架构与 CloudKit 首通道，核心决策 13 的具体化演进）与新 `docs/spec/` 同步规范。

## 4. 范围

- `Packages/LangoTraceData`：sync metadata / tombstone migration、`SyncMetadataRepository`、写路径 revision 挂钩、变更读取查询。
- `Packages/LangoTraceSync`：`SyncEngine`、`SyncAdapter` 协议、`CloudKitSyncAdapter`、冲突模型、引擎状态（idle / syncing / failed / conflictsPending）。
- `Packages/LangoTraceCore`：revision / tombstone / 冲突值对象、device id 模型。
- `Packages/LangoTraceUI`：`SyncSettingsView` 接线、冲突待处理列表的最小呈现。
- `LangoTraceApp` / `project.yml` / entitlements：iCloud container、iOS entitlements 文件新增、装配。
- 文档：新 ADR、新同步 spec、spec 007 与 sync 备忘录采纳回写。

## 5. 不做什么

- 不同步附件、照片、练习录音、TTS 音频（v1 范围外；练习录音按 [2026-05-26 备忘录](../../architecture/notes/2026-05-26-practice-recording-sync-export-notes.md) 默认不同步）。
- 不同步 FTS / 向量索引等派生数据（核心决策 12）。
- 不同步 `current_language_space_id`、设备偏好与窗口状态（备忘录 §3.1）。
- 不做 WebDAV / S3 / R2 Adapter（协议为其预留，配置 UI 中 S3 保持"高级·后续"态）。
- 不做后台静默推送 / 订阅式实时同步；v1 为手动触发 + 前台时机触发。
- 不做冲突的字段级合并 UI；v1 只保证双版本保留与可见待处理状态，逐项解决界面后续方案。
- 不迁移 reading domain 与 AI Provider 配置进入同步范围（reading 文档同步在四类稳定后评估；Provider 非敏感配置同步需要独立隐私评估）。
- 不在本方案内实现端到端加密（CloudKit 私有库自带传输与静态加密；自管加密留给对象存储通道方案）。

## 6. 证据与决策依据

- 代码证据：见第 2 节逐条核实。
- 备忘录采纳说明（[2026-05-20-language-space-sync-extension-notes.md](../../architecture/notes/2026-05-20-language-space-sync-extension-notes.md)，按 §5 要求本任务启动前重读）：
  - §3.2：采纳独立 `sync_metadata` 表方案（不污染主表）；`remote_revision` 由 Adapter 抽象为不透明字符串（CloudKit 用 record change tag）；local revision 采用单调递增整数（单库内写序即定序，跨设备排序交给冲突模型而不是时钟）。
  - §3.3：采纳独立 `tombstones` 表（object_type / object_id / deleted_at / deleted_by_device_id / deletion_revision / last_synced_at / purge_after）；purge 策略 v1 固定为"已传播且超过 90 天"，参数进同步 spec。
  - §3.1：采纳 current space 不同步；不建 `device_state` 表（v1 无跨设备继续学习需求），记录为后续方向。
  - §3.4 / §3.5：采纳"删除与编辑冲突不静默丢数据、先保守保存两侧"；同名空间不算冲突。
  - §4 硬约束全部采纳。
- E10 对齐：同步信封复用 `PortableSnapshot` 对象编码（E10 §12.1"一套对象序列化、两种信封"）；若字段不足，按其 snapshotVersion 演进规则修订，不另起格式。
- workflow 引用：[add-storage-migration.md](../../workflows/add-storage-migration.md)（migration、tombstone、删除传播测试矩阵）。CloudKit 接入无现成 workflow，本方案第 12 节即执行顺序，实施后评估沉淀新 workflow。
- 核心决策 13 演进：本方案把"Sync Engine + Adapter 思路"具体化为可执行架构，属于决策细化而非反转；仍需新增 ADR 记录引擎边界、首通道选择与不选 CloudKit-only 的理由（第 17 节）。

```text
证据能证明什么：占位 package 与 mock 设置页证明同步没有任何已实现路径；备忘录给出了经过评审的 schema 候选与冲突清单。
证据不能证明什么：备忘录 schema 只是候选，字段最终形态以本方案 + 实施测试为准；SyncSettingsDraft 的 UI 结构不证明产品最终交互。
迁移前提：E2 / E4 / E7 schema 稳定（同步对象字段冻结）；E10 的 PortableSnapshot 已落地。
照搬风险：照搬 CloudKit + NSPersistentCloudKitContainer 式"全自动同步"会违反引擎 / Adapter 分层与不绑定 CloudKit-only 决策；照搬"最后写入胜出"会违反保守冲突原则。
```

## 7. 约束映射与验证路径

### 约束 1：敏感凭证永不进入同步对象

- 来源：`docs/README.md` 核心决策 9、`docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md` §4、`docs/decisions/005-local-first-and-user-owned-providers.md`
- 适用范围：变更收集、Adapter 上行 payload
- 严重度：blocker
- 执行或验证方式：单元测试（同步对象类型白名单；payload 全文不含凭证 fixture）
- 验证提示：变更收集只接受四类白名单 object_type；凭证表不在 sync_metadata 跟踪范围。

### 约束 2：派生数据不同步

- 来源：`docs/README.md` 核心决策 12、`docs/spec/007` §4
- 适用范围：同步范围定义
- 严重度：blocker
- 执行或验证方式：单元测试 + 同步 spec 范围表

### 约束 3：Engine / Adapter 分层，不绑定 CloudKit-only

- 来源：`docs/README.md` 核心决策 13
- 适用范围：LangoTraceSync 模块结构
- 严重度：blocker
- 执行或验证方式：人工架构审查 + 测试用 fake adapter 证明引擎不依赖 CloudKit 类型
- 验证提示：引擎测试全部以 `FakeSyncAdapter` 驱动；CloudKit 类型只出现在 adapter 文件。

### 约束 4：不整库同步、不同步 UI 状态

- 来源：`docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md` §4
- 适用范围：同步对象粒度
- 严重度：blocker
- 执行或验证方式：人工审查（同步单位为对象快照 + 变更，不存在数据库文件上传路径）

### 约束 5：冲突不静默丢数据

- 来源：同备忘录 §3.5
- 适用范围：冲突处理
- 严重度：blocker
- 执行或验证方式：单元测试（双设备同对象并发修改后两侧内容都可寻回）

### 约束 6：migration 可重复验证

- 来源：`docs/spec/007` §4、`docs/workflows/add-storage-migration.md`
- 适用范围：Slice A migration
- 严重度：blocker
- 执行或验证方式：migration 单元测试

### 约束 7：设置页渲染不读 Keychain、不发探测

- 来源：`docs/architecture/notes/2026-05-24-settings-status-projection-notes.md` §4
- 适用范围：Slice C 设置接线
- 严重度：warn
- 执行或验证方式：单元测试（状态投影只读引擎状态与本地配置表）

## 8. 涉及的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（Slice A migration）
- `Packages/LangoTraceData/Sources/LangoTraceData/Sync/SyncMetadataRepository.swift`、`Sync/GRDBSyncMetadataRepository.swift`（新增）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`、`GRDBLanguageSpaceRepository.swift`、`GRDBMemoryItemRepository.swift`（写路径 revision / tombstone 挂钩）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SyncModels.swift`（新增）
- `Packages/LangoTraceSync/Sources/LangoTraceSync/SyncEngine.swift`、`SyncAdapter.swift`、`CloudKitSyncAdapter.swift`、`SyncConflict.swift`、`SyncBoundary.swift`（重写占位边界）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`（接线）、`SyncStatusProjection`（新增，供 E12 复用）
- `LangoTraceApp/AppEnvironment.swift`、`project.yml`、`LangoTraceApp/Supporting/LangoTrace-macOS.entitlements`、新增 iOS entitlements 文件

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/Export/PortableSnapshots.swift`（E10 产物，对象编码复用）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/KeychainAIProviderCredentialStore.swift`（敏感边界既有模式，仅参照不修改）
- `Packages/LangoTraceSync/Tests/LangoTraceSyncTests/SyncBoundaryTests.swift`（占位边界测试，将被替换）

## 10. 涉及的文档路径

- 本方案。
- 新增：`docs/decisions/006-sync-engine-adapter-and-cloudkit-first-channel.md`（编号以实施时为准）
- 新增：`docs/spec/`同步规范（范围表、revision / tombstone 语义、冲突策略、purge 参数）
- `docs/spec/007`（同步事实回写）、`docs/architecture/002-system-map.md`（数据流更新）
- `docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md`（采纳回写在本方案，备忘录保留）
- 前序依赖方案：[2026-06-11-13-feature-import-export-backup.md](2026-06-11-13-feature-import-export-backup.md)（E10，manifest 对齐）、[2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md](2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md)（E2）、[2026-06-11-07-feature-practice-dictation.md](2026-06-11-07-feature-practice-dictation.md)（E4）、[2026-06-11-10-feature-memory-deposit-foundation.md](2026-06-11-10-feature-memory-deposit-foundation.md)（E7）—— schema 稳定前置。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

三个子切片按序实施，各自有 DoD，可独立 commit 与收口；任一切片完成后可暂停而不留半残行为。

### Slice A：同步元数据、变更跟踪与 tombstone（用户零可见）

1. migration（编号实施时顺延）：`sync_metadata`（object_type / object_id / local_revision / remote_revision / changed_at / changed_by_device_id / last_synced_at / sync_state，PRIMARY KEY(object_type, object_id)）与 `tombstones`（备忘录 §3.3 字段集）。
2. `DeviceIdentity`：首启生成 UUID，存入本地配置表（非 Keychain——device id 非敏感凭证；不随导出包传播）。
3. 四类对象写路径在同一事务内 upsert sync_metadata（revision +1）；删除写 tombstone；`changed_at` 用注入 clock。
4. 变更读取查询：`pendingChanges(since:)`、`unsyncedTombstones()`。

Slice A DoD：

- migration 测试（空库 / 旧库 / 重复）绿；四类对象创建 / 更新 / 删除产生正确 metadata 与 tombstone 的测试绿。
- 凭证、派生、练习录音等表不产生 sync_metadata 的反向测试绿。
- 现有全部 Data 测试无回归；App 行为零变化。

### Slice B：Sync Engine + Adapter 协议 + CloudKit happy path

1. `SyncAdapter` 协议：`push(changes) -> [RemoteRevision]`、`pull(since cursor) -> RemoteChangeBatch`、能力声明与错误分类（网络、权限、配额、账号缺失）。payload 为 `PortableSnapshot` 编码。
2. `SyncEngine`：收集本地变更 → push → pull → 应用远端变更（经 repository 写路径，不直写 SQL）→ 更新 metadata / cursor。可取消、不可重入（同一时刻单飞行）、失败分类上抛。
3. `FakeSyncAdapter`（测试内）：内存远端，驱动引擎全部单元测试，包括双引擎（模拟两设备）roundtrip。
4. `CloudKitSyncAdapter`：私有库自定义 zone（每语言空间一个 zone）、record type 映射四类对象、change tag 作 remote_revision、CKFetchRecordZoneChanges 作 pull。entitlement：iOS 新增 entitlements 文件 + macOS entitlements 增加 iCloud container / CloudKit services，`project.yml` 同步。
5. 触发：设置页手动"立即同步" + App 进入前台节流触发；无后台推送。

Slice B DoD：

- 引擎单元测试（fake adapter）全绿：push / pull / 应用变更 / 取消 / 单飞行 / 错误分类 / 双引擎复制四类对象。
- 凭证与排除表永不进入 payload 的测试绿。
- macOS + iOS 构建通过；真机 / 双模拟器 CloudKit 人工验证记录在实施记录（CloudKit 集成无法纯单元测试，剩余风险记录）。

### Slice C：冲突 keep-multiple-versions + 设置接线

1. 冲突检测：push 遭遇 remote revision 不匹配 → 拉取远端版本 → 本地与远端都保留：远端版本应用为对象当前值之外的 `sync_conflict_versions` 附属记录（同 migration 于 Slice A 预建或 Slice C 增量 migration，二选一在实施时定夺并记录），对象进入 conflictsPending；删除 vs 编辑冲突按备忘录 §3.5：编辑侧保留为冲突版本，不静默服从 tombstone。
2. 冲突可见性：设置同步页显示冲突计数与最小列表（对象标题 + 两侧时间），逐项字段级解决 UI 不在本方案。
3. `SyncSettingsView` 接线：启用 iCloud（首次启用走 zone 初始化与全量上行）、停用（保留本地数据与 metadata）、上次同步时间、失败原因分类、范围披露行读真实 policy 表（`SyncScopeKind` 语义映射真实范围），并产出 `SyncStatusProjection` 供 E12 设置主列表复用。

Slice C DoD：

- 冲突测试绿：并发修改双保留、删除 vs 编辑保留编辑侧、冲突计数投影正确。
- 设置接线测试绿：渲染不读 Keychain、不触发网络；启用 / 停用状态机正确。
- 新 ADR 与同步 spec 草稿完成并经用户确认。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：同系列说明——方案撰写会话内无法对未落盘草稿做隔离审查，按协议第 3 节降级为主会话双轮自审核；鉴于本方案为 XL 高风险，建议实施前对本方案再做一次独立子代理审查（记录为仍需确认项 3）。
发现摘要：
  第一轮（架构）：
  - P0：初稿引擎应用远端变更时直写 SQL，绕过 repository 会破坏 candidate / current material 等不变量 → 改为经 repository 写路径应用（12 Slice B 第 2 步）。
  - P1：local revision 初稿用墙钟时间戳，设备时钟漂移会破坏定序 → 改为单调递增整数 + 冲突模型负责跨设备语义。
  - P1：冲突版本的存放初稿复用主表多行，会污染 active 查询 → 改为 sync_conflict_versions 附属记录。
  - P1：学习材料对象图（material + sentences + notes + candidates）若拆成独立同步对象会出现部分到达的不一致 → 决策：learning material 聚合为单一同步对象（PortableLearningMaterial 含子集合），revision 在聚合根上。
  - P2：每语言空间一个 CloudKit zone 的决策依据（空间删除 = zone 删除、变更游标按空间隔离）写入方案。
  第二轮（测试 / 安全 / 落地）：
  - P0：CloudKit 不可单元测试，若 DoD 依赖真机验证则 Linux / CI 环境无法收口 → 引擎全部测试改为 fake adapter 驱动，CloudKit 人工验证单列为实施记录项与剩余风险。
  - P1：payload 敏感泄漏只靠类型白名单不够（diagnostic 字段可能混入快照）→ 补充 payload 全文 fixture 扫描测试。
  - P1：停用同步后的 metadata 语义（保留还是清除）未定义 → 固定为保留（再次启用增量续传），写入 Slice C。
  - P2：前台触发的节流参数（如 15 分钟）进同步 spec 而非硬编码散落。
写回修改：以上均已写回第 6、7、12 节。
仍需用户确认的问题：
  1. CloudKit 作为首通道（而非 WebDAV / S3 先行）是否符合预期；S3 通道时间表不在本方案承诺。
  2. 每语言空间一个 CloudKit zone 的粒度决策。
  3. 实施前是否对本方案追加一次独立隔离审查（建议是）。
是否允许进入实现：待用户确认后允许；三个 Slice 建议逐一确认进入。
```

## 14. 复查方法

- 代码：三个 Slice 的 DoD 命令全绿；CloudKit 类型只存在于 adapter 文件（`rg -l CloudKit Packages/LangoTraceSync/Sources` 仅 1 个文件命中）。
- 行为：双设备（或双模拟器双容器账号）创建 / 编辑 / 删除四类对象后手动同步双向收敛；并发修改产生冲突待处理而非数据丢失；停用再启用续传正确。
- 故障与恢复路径：无 iCloud 账号、网络中断、配额超限、push 中途取消、应用远端变更时本地校验失败（保留远端 payload 进重试队列）、tombstone purge 不影响未传播删除；同步日志不含对象正文与凭证（仅计数 / 分类 / 长度分桶）。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Sync/AppDatabaseSyncMigrationTests.swift（Slice A）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Sync/SyncMetadataRepositoryTests.swift（Slice A）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Sync/SyncScopeExclusionTests.swift（Slice A：排除表反向测试）
  Packages/LangoTraceSync/Tests/LangoTraceSyncTests/SyncEngineTests.swift（Slice B：fake adapter）
  Packages/LangoTraceSync/Tests/LangoTraceSyncTests/SyncPayloadPrivacyTests.swift（Slice B）
  Packages/LangoTraceSync/Tests/LangoTraceSyncTests/SyncConflictTests.swift（Slice C）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/Sync/SyncSettingsProjectionTests.swift（Slice C）
先失败用例：SyncMetadataRepositoryTests.entryWriteBumpsLocalRevision —— 预期失败原因：sync_metadata 表与 repository 尚不存在，编译失败。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceData --filter Sync
  swift test --package-path Packages/LangoTraceSync
  swift test --package-path Packages/LangoTraceUI --filter Sync
不新增单元测试的原因（如适用）：CloudKitSyncAdapter 对真实 CloudKit 的集成行为无法单元测试，以 adapter 协议契约测试 + 双端人工验证覆盖，剩余风险见第 20 节。
```

## 16. 验证命令

```bash
# Slice A DoD
swift test --package-path Packages/LangoTraceData --filter Sync
swift test --package-path Packages/LangoTraceData

# Slice B DoD
swift test --package-path Packages/LangoTraceSync
xcodegen generate
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build

# Slice C DoD
swift test --package-path Packages/LangoTraceSync --filter SyncConflictTests
swift test --package-path Packages/LangoTraceUI --filter Sync

# 文档
scripts/check-docs.sh
```

同步属于最高风险基础设施，全部 Slice 收口前与用户确认补跑 `scripts/verify.sh`。

## 17. 文档影响检查

- 新增 ADR（必做）：同步引擎架构、CloudKit 首通道、冲突 keep-multiple-versions、每空间 zone 粒度；这是核心决策 13 的演进，按 CLAUDE.md 第 4 节规则必须 ADR 化。
- 新增同步 spec（必做）：范围表、revision / tombstone / purge 语义、节流参数、错误分类。
- `docs/spec/007`：同步事实回写（tombstone、metadata 与导出边界关系）。
- `docs/architecture/002-system-map.md`：Sync 数据流与模块依赖更新。
- `docs/platform-page-inventory.md`：同步设置页状态更新。
- release：iCloud capability 影响发布配置与隐私标签，实施后在 release 文档登记。
- review：同步引擎属于专项审查触发条件，每个 Slice 完成后按 `docs/review/README.md` 判断。

## 18. 实施记录

（实施时按 Slice 追加；CloudKit 人工验证证据必须留痕。）

## 19. 完成标准

1. 三个 Slice 的 DoD 全部达成且各自有 commit。
2. 新 ADR 与同步 spec 已创建并经用户确认。
3. 约束 1–7 全部有测试或审查证据。
4. plan-vs-shipped 对账完成；S3 通道、字段级冲突解决、附件同步等 deferred 项有后续入口记录。

## 20. 剩余风险

- CloudKit 真实环境行为（配额、限流、账号切换、zone 删除传播）无法自动化验证，依赖双端人工验证；首个公开版本前需要 TestFlight 阶段实测。
- 聚合根同步（learning material 含子集合）使大材料的单对象 payload 偏大；CloudKit 单 record 1MB 限制下超长材料需要拆分策略，实施中若命中先按失败分类上报并记录，不静默截断。
- keep-multiple-versions 缺少解决 UI 时冲突可能累积；Slice C 提供计数与列表保底，解决界面为后续方案。
- 四类对象之外（reading、AI 配置）暂不同步造成跨设备体验不完整；范围扩展按同步 spec 演进。
- schema 在 E2 / E4 / E7 后仍变化会触发同步对象版本演进；依赖 PortableSnapshot 的 snapshotVersion 规则兜底。
