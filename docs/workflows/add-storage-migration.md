# Workflow：新增数据存储或迁移

适用场景：新增 SQLite / GRDB table、migration、Repository、主数据、派生数据、附件 metadata、导出、备份、恢复、FTS、向量索引或清理策略。

## 1. 必读文档

- `docs/README.md`
- `docs/plans/README.md`
- `docs/technical-framework-roadmap.md` 第 2、5、6、9 节
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/architecture/notes/README.md`
- `docs/spec/learning-content/impl.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

## 2. 任务方案要求

实现前必须创建或更新 active plan，并明确：

- 新增内容是主数据、配置、敏感凭证 metadata、可重建派生数据，还是本地缓存。
- Migration id、事务边界、回滚或恢复策略。
- Repository contract、错误分类、并发写入和取消语义。
- 导出、备份、同步、删除传播和隐私影响。
- 是否需要补充 architecture note、spec、impl map 或 ADR。

## 3. 关键落点

- Data package：migration、record type、Repository、query、test fixture。
- Core package：跨模块模型、value object、错误类型和 contract。
- App assembly：数据库位置、依赖注入、启动恢复。
- `docs/spec/<module>/impl.md`：实现地图。
- `docs/review/rounds/`：数据库 schema、Repository 或 migration 变化命中专项审查时创建记录。

## 4. 测试要求

至少覆盖：

- 新库初始化后 schema 正确。
- 旧 schema 到新 schema 的 migration。
- Repository 读写、软删除、缺失值、重复键和事务失败。
- 敏感字段不进入普通表、日志、导出或同步候选。
- 派生数据可失效、可重建，并不被当作主数据。

## 5. 故障与恢复路径

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| Migration 失败 | 保持原数据不被半写入，返回可诊断错误 | migration 测试 |
| Repository 事务失败 | 回滚整组写入 | Data 测试 |
| 派生文件丢失 | metadata 标记失效或重新生成 | artifact 测试 |
| Keychain 缺失但 metadata 存在 | 进入 credential missing 状态 | service 测试 |

## 6. 完成前检查

运行对应 package 聚焦测试；数据库、Repository、migration、导出、备份或 App 启动结构变化时运行 `scripts/verify.sh`，并按 `docs/review/README.md` 判断专项审查。

## 7. 反例

- 为临时 UI 状态新增长期 schema。
- 不写 migration 测试就修改数据库结构。
- 把 API Key、对象存储密钥或加密密钥存入 SQLite。
- 把向量索引、FTS 或 TTS 音频当作同步主数据。
