# 语言空间同步扩展开发备忘录

状态：Draft
创建日期：2026-05-20
适用范围：后续 Sync Engine、Adapter、Entry、附件、导出恢复和语言空间删除策略设计。

## 1. 目的

本文记录 `docs/plans/active/2026-05-20-feature-language-space-data-infrastructure.md` 在语言空间本地持久化方案中为同步功能预留的边界，以及后续开发同步功能时必须重新决策的问题。

本文不是同步功能实施方案，不替代未来 `docs/plans/active/` 中的同步任务方案，也不改变现有 ADR。后续一旦正式设计同步，应以本文为输入，新增独立任务方案，并把被采纳的结论同步到 `docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/architecture/` 或 ADR。

## 2. 当前语言空间方案已经预留的扩展点

- `LanguageSpace.id` 是稳定唯一 ID，可作为 Entry、附件、AI 生成、练习记录和同步对象的归属键。
- `target_language_code` 和 `display_name` 不做唯一约束，后续多空间、同目标语言多空间、同名空间不会和同步对象身份冲突。
- `deleted_at` 保留软删除状态，可作为未来恢复窗口和同步 tombstone 的输入，但不能直接等同于完整同步 tombstone。
- `app_state.current_language_space_id` 独立于 `language_spaces`，说明“当前选择”不是语言空间主数据字段，后续可按设备偏好处理。
- Repository 隔离 SQLite / GRDB，后续 Sync Engine 不应直接被 SwiftUI 或 SQL 细节耦合。
- 主数据库位于 Application Support，符合 App 私有主数据存储边界；可重建索引、临时导出和缓存可继续与主数据库分离。

## 3. 后续同步设计必须重新决策的问题

### 3.1 是否同步当前语言空间选择

推荐默认不跨设备同步 `current_language_space_id`。

理由：

- 当前语言空间更像设备上的工作上下文或最近选择，不一定是用户希望在 iPhone、iPad、macOS 之间强制一致的主数据。
- iPhone 切换到“英语 - 通勤”不应意外改变 iPad 当前打开的“英语 - 工作”。
- 后续可以把每台设备的当前空间作为设备级偏好；如果产品需要“跨设备继续上次学习”，应单独设计最近活动入口，而不是同步覆盖 current。

需要决策：

- `app_state.current_language_space_id` 是否完全本地。
- 是否需要 `device_state` 表区分设备级状态。
- 是否需要“最近使用空间”同步为活动记录，而不是同步为当前选择。

### 3.2 语言空间对象的同步元数据

当前首版本地 schema 不应提前加入完整同步字段；同步任务启动时应评估新增独立 `sync_metadata` 表或 per-table sync columns。

推荐优先评估独立表：

```text
sync_metadata
  object_type TEXT NOT NULL
  object_id TEXT NOT NULL
  local_revision INTEGER NOT NULL
  remote_revision TEXT
  changed_at REAL NOT NULL
  changed_by_device_id TEXT
  last_synced_at REAL
  sync_state TEXT NOT NULL
  PRIMARY KEY(object_type, object_id)
```

理由：

- 不污染所有主数据表。
- 后续 Entry、Attachment、Rendering、PracticeSession、MemoryItem 可复用同一同步元数据模型。
- 不把同步适配器的 remote revision 设计写死到语言空间表。

需要决策：

- 使用独立 `sync_metadata` 还是每个主表增加 `sync_*` columns。
- `remote_revision` 是否由 Adapter 统一抽象，还是每个 Adapter 自行维护。
- 本地 revision 是整数递增、Lamport clock，还是 device-scoped change id。

### 3.3 tombstone 与软删除

`language_spaces.deleted_at` 只能表示本地 soft delete。后续同步需要更完整 tombstone。

推荐 tombstone 至少表达：

```text
tombstones
  object_type TEXT NOT NULL
  object_id TEXT NOT NULL
  deleted_at REAL NOT NULL
  deleted_by_device_id TEXT
  deletion_revision INTEGER NOT NULL
  last_synced_at REAL
  purge_after REAL
  PRIMARY KEY(object_type, object_id)
```

需要决策：

- deleted 语言空间保留多久。
- tombstone 是否进入导出备份。
- 已传播 tombstone 何时可以 purge。
- 用户可见删除与隐私彻底删除是否拆成两个动作。

### 3.4 删除空间与子对象的关系

当前语言空间方案只实现语言空间 soft delete，尚未有 Entry、附件、AI 输出和练习记录表。同步功能或 Entry 持久化功能启动前必须定义空间删除的子对象策略。

推荐方向：

- 删除语言空间时，普通 active 查询排除该空间及其子对象。
- Entry、Rendering、PracticeSession、MemoryItem 和附件 metadata 后续应通过 `space_id` 归属语言空间。
- 首版有真实 Entry 后，删除空间应优先采用“空间级 soft delete + 子对象默认隐藏”的模型，而不是立即硬删除子对象。
- 附件文件清理、导出恢复和隐私彻底删除单独设计，不由语言空间管理页隐式执行不可逆硬删除。

需要决策：

- 删除空间时是否级联写入子对象 `deleted_at`。
- 恢复空间时是否恢复子对象可见性。
- 同步冲突中“设备 A 删除空间，设备 B 编辑空间内 Entry”如何处理。

### 3.5 冲突解决

同步任务必须处理至少以下冲突：

- 两台设备同时重命名同一语言空间。
- 一台设备删除空间，另一台设备修改空间属性。
- 两台设备创建同名空间。
- 一台设备切换 current，另一台设备仍在旧空间编辑 Entry。
- 空间删除 tombstone 与未同步 Entry 创建同时出现。

推荐原则：

- 同名空间允许存在，不把同名当冲突。
- current 选择若作为设备偏好，不参与主数据冲突。
- 删除与编辑冲突不能静默丢数据；首版可把被删除空间内的新变更保留为隐藏或冲突待处理状态。
- 空间级冲突解决策略应先保守保存两侧信息，再设计用户可见解决入口。

## 4. 同步实现时的硬约束

- 不把 SQLite 数据库文件整体当作唯一同步对象。
- 不通过 iCloud Drive、WebDAV、S3 或 R2 直接覆盖整个主数据库作为常规同步方式。
- Sync Engine 应同步对象、版本、变更和 tombstone，而不是同步 UI 状态。
- Provider API Key、对象存储密钥、同步 token 和加密密钥不得进入普通数据库同步对象。
- FTS、向量索引、缩略图和其他可重建派生数据默认不同步。
- 如果后续使用 `DatabasePool` / WAL，导出和备份必须使用一致性快照，不复制单个 `.sqlite` 文件。

## 5. 后续任务建议

建议在以下任务启动前重新读取本文：

- Entry / Attachment SQLite schema。
- 语言空间删除与恢复窗口。
- 导出备份和导入恢复。
- Sync Engine 主模型。
- CloudKit / WebDAV / S3 / R2 Adapter。
- 多设备最近活动和继续学习体验。

后续同步任务方案至少应包含：

- 对象 ID 与本地 revision 策略。
- 设备 ID 和 device state 设计。
- `current_language_space_id` 是否本地化。
- tombstone 表或 sync metadata 表。
- 空间删除对子对象和附件的影响。
- 冲突解决策略和用户可见状态。
- 导出、备份、隐私删除和同步之间的边界。

## 6. 当前实施阶段结论

当前语言空间本地持久化任务可以不提前实现完整同步字段，但必须保持以下约束：

- 保持稳定 `LanguageSpace.id`。
- 保持 `deleted_at` 软删除。
- 保持 `app_state.current_language_space_id` 与主表分离。
- 不把 SQLite 文件复制描述为同步或可恢复备份。
- 不让 SwiftUI 直接依赖 GRDB 或 SQL。
- 为后续 Entry、附件和同步表保留 `space_id` 外键边界。
