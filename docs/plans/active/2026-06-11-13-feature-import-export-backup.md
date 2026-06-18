# 任务方案：导入导出与可恢复备份包（macOS 首发）（E10）

状态：User Approved（按切片实施：Slice 1 本轮落地，Slice 2 + 加密备份诚实 defer）
自审核状态：Reviewed（2026-06-18 批量 run 实现前隔离自审核，用当前代码核验漂移）
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-18（批量 run 实现前隔离自审核：表清单对账 v26、诚实 defer 加密备份、切片化、密钥相邻表排除）

## 批量 run 实现前隔离自审核（2026-06-18）

```text
审核方式：隔离子代理只读，用当前 HEAD（E8 已落地 dev）核验方案现状
核心决策/ADR 反转检查：无（落地 P0/P1 修订后）。导出排除密钥（决策 9）、排除可重建 FTS/向量（决策 12）、本地优先用户触发（ADR-005/决策 7）、不发可读 Markdown 导出充当备份（spec 007 §4）。
确认漂移与修订（实现时按此为准）：
  [P0] 表清单 stale：方案把 E2 照片 / E7 memory_items 当「未来」，且漏 E5 practice_text_attempts、E6 ai_request_logs、E9 search_index。按 v26 现状重写 per-table disposition：
    - 主数据（导出）：entries、learning_materials(+sentences/revision_notes)、memory_items、practice_sessions(+practice_recordings 元数据，文件 gated)、practice_text_attempts、reading 主表(documents/structure/sentences/collections/tags/positions/source_anchors/lifecycle)、entry_photo_attachments(元数据，文件 gated)、language_spaces(导出空间)。
    - 派生（排除，可重建）：memory_candidates、practice_candidates、search_index/search_index_meta、reading_document_search_index、reading_explanation_cache、tts_audio_artifacts(文件)。
    - 诊断/运行期（排除）：ai_request_logs、learning_material_operations、reading_ai_explanation_operations、reading_import_operations。
    - 设备本地（排除）：app_state（current_language_space_id 设备本地）。
  [P0] 诚实 defer 边界（写进 §3/§5/§20）：**现在落地**明文、开放格式、非敏感主数据导出包 + manifest + SHA-256 + import 预览/版本校验/同 id skip 合并——无需加密、无需新安全存储（因为 secrets 是排除而非加密）；**defer**加密/口令备份包（依赖不存在的 KDF/密钥管理），凭证永不导出（决策 9，Keychain）。defer 项写 architecture/notes 续传入口。
  [P1] 密钥相邻：把 AI provider config 表（含 keychain_service/account/secret_presence 列）、TTS settings 表、ai_request_logs 显式列入「禁止导出表清单」+ 排除测试断言导出 JSON 不含 keychain_*/secret_presence。
  [P1] 媒体：文件在 LocalMediaArtifactFileStore 根目录；导出 toggle 是对 media_artifacts 默认 excluded-from-export policy 的显式用户授权覆盖；缩略图 + TTS 文件不打包；附件文件打包 = Slice 2（macOS 文件面板 + entitlement）。
  [P1] seam：mac 接线点是 MacWorkspaceContentView.swift:101（.importExport case，非 MacMainView.swift）；iPad route 出范围。
  [P0] 切片（CI-greenable）：
    Slice 1（Linux swift test 绿，本轮）：Core/Data 纯 PortableSnapshot codable 家族（entry/material+children/memory_item/practice_session 元数据/practice_text_attempt/reading_document+structure，roundtrip + 未知字段容忍 + snapshotVersion）→ ExportPackageWriter 写入注入目录 URL（GRDB 一致性读快照，data/*.json + manifest + SHA-256，禁止表+白名单+密钥排除测试，无附件文件）→ ImportPackageReader+preview（manifest 解析、hash 校验、版本拒绝高 schema、计数/冲突预览、确认前零写）+ ImportMergeService 同 id skip 走既有 repository（临时 GRDB DB 测试）→ ImportExportActions UI 状态机 + 预览确认门 + 错误投影。
    Slice 2（macOS runner gated，defer）：entitlement files.user-selected.read-write + fileImporter/fileExporter 面板 + security-scoped URL + 附件文件打包。
    deferred（独立方案）：加密备份包、provider/TTS 配置导出、iPhone/iPad 入口。
  无新 migration（v26；manifest schema version 读 live 迁移标识 v26，不硬编码）。
是否允许进入实现：Slice 1 是（批量 run §1 预授权）；Slice 2 + 加密 defer 到 macOS 验证 / 独立方案，本轮 E10 为 Slice 1 落地 + 诚实 defer 记录。
```

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（[2026-06-11-chore-code-review-and-dev-plan-series.md](2026-06-11-chore-code-review-and-dev-plan-series.md)）。该授权仅覆盖"方案文档创建"；本方案进入实现前仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。本方案第 13 节列有一项必须由用户决断的默认值冲突（练习录音导出默认开关）。

## 1. 需求或 bug 描述

按 `prototypes/mac/import-export.html`（mac 专属页面），桌面端提供导入导出一级入口：

1. 导出备份包：把当前语言空间打包为可恢复备份文件；范围行包括 生活记录（始终包含）、学习材料（始终包含）、练习录音（开关）、照片附件（开关，默认关，"体积较大，按需勾选"）、目标位置选择。
2. 导入：选择语迹导出包，先显示内容预览，不直接覆盖现有数据。
3. 隐私边界常驻披露："导出包不包含 API Key、对象存储密钥或任何 Keychain 内容。"

本任务实现导出包格式、manifest 与哈希校验、范围选择、macOS 文件面板与沙盒权限、导入预览闭环。

## 2. 现状描述

以下事实已对照当前代码（2026-06-11 HEAD）核实：

- 仓库中没有任何导出包、manifest 或导入实现；设置中导入导出能力为说明型入口（`SettingsCapability.Kind.importExport`），mac 侧栏对应条目为 unavailable 占位。
- macOS entitlements（`LangoTraceApp/Supporting/LangoTrace-macOS.entitlements`）当前为：`com.apple.security.app-sandbox`、`com.apple.security.device.audio-input`、`com.apple.security.network.client`（network.client 为今日修复波次加入）。没有 `com.apple.security.files.user-selected.read-write`，沙盒下 NSOpenPanel / NSSavePanel 的用户选择文件读写需要补充该 entitlement（落点 `project.yml` 引用的同一文件）。
- 可导出主数据现状：`language_spaces`、`entries`、`learning_materials` + sentences + revision notes + candidates、`practice_sessions` / `practice_recordings` + artifacts、reading domain 表、媒体文件目录 `MediaArtifacts`。E2（照片附件）与 E7（`memory_items`）落地后各自纳入。
- 练习录音 policy 现状：`media_artifacts` 行携带 backup / sync / export policy 字段，practice recording 默认 local-only、excluded-from-export（[2026-05-26-practice-recording-sync-export-notes.md](../../architecture/notes/2026-05-26-practice-recording-sync-export-notes.md) §2 已落地边界）。
- 默认值冲突（必须显式决断，不得静默选择）：原型练习录音开关呈现为默认开（`aria-checked="true"`），而 2026-05-26 备忘录与已落地 policy 为默认排除。见第 13 节仍需用户确认问题 1。
- 数据库未使用 WAL 时也必须遵守 spec 007 / 同步备忘录约束：导出不得复制单个 `.sqlite` 文件，必须经一致性读快照序列化对象。

## 3. 目标

1. 导出包格式落地：目录式包（用户选定位置下创建 `<空间名>-<日期>.langotrace-export/`），内含 `manifest.json`（format version、app version、schema version、空间元数据、范围声明、对象计数、每文件相对路径 + 字节数 + SHA-256）、`data/` 下按对象类型分文件的 JSON payload、`attachments/` 下按开关纳入的媒体文件。
2. 范围控制：生活记录与学习材料始终包含；练习录音开关（默认值经用户决断后固定）；照片附件开关默认关；记忆数据（E7 后）随学习内容始终包含。
3. 导出全程使用 GRDB 一致性读快照，不复制数据库文件；写入先到包内临时名再原子完成，失败可清理。
4. 导入：选包 → manifest 解析与 format / schema 版本检查 → 内容预览（对象计数、空间信息、冲突概览）→ 用户确认后合并写入；不直接覆盖现有数据；同 id 已存在时按保守策略保留本地并在预览中列出跳过项。
5. 安全边界：导出包永不包含 Keychain 内容、API Key、完整请求 / 响应体、诊断敏感字段；导出器以"禁止表清单 + 序列化白名单"双保险实现并有测试。
6. macOS UI：工作台侧栏导入导出页（io-card 结构）、NSSavePanel / NSOpenPanel（SwiftUI `fileImporter` / `fileExporter` 或 AppKit 面板，经 security-scoped URL 访问）、entitlement 补充。
7. 导出 manifest 与未来同步 manifest 的格式方向收敛（决策见第 12.1 节），避免两套对象序列化格式。

## 4. 范围

- `Packages/LangoTraceData`：`ExportPackageWriter`、`ImportPackageReader`、对象可移植快照编码（`PortableSnapshot` codable 类型族）、版本检查、合并写入、临时文件治理。
- `Packages/LangoTraceCore`：导出范围模型、manifest 模型、错误分类。
- `Packages/LangoTraceUI`：mac 导入导出页面、范围行与开关、进度 / 完成 / 失败状态、导入预览 sheet、`ImportExportActions` seam。
- `LangoTraceApp`：entitlement 补充（`LangoTrace-macOS.entitlements` 加 `com.apple.security.files.user-selected.read-write`）、装配。
- 文档：spec 007 导出事实更新、platform-page-inventory 更新。

## 5. 不做什么

- 不做 iPhone / iPad 导入导出入口（原型说明"通过设置内入口复用同一能力"，移动端入口在桌面闭环验证后另行立案）。
- 不做导出包加密与端到端加密备份（记入剩余风险与备忘录后续问题）。
- 不做"用户可读包"（如 Markdown / 纯文本阅读导出）；本任务只做可恢复备份包，两者按 spec 007 §4 不得混为一个含义。
- 不做自动定时备份、增量备份或版本链。
- 不做跨语言空间打包（一次导出一个空间；多空间循环导出后续考虑）。
- 不实现同步（E11），但 manifest 对象序列化层按 12.1 决策为同步预留复用。
- 不导出 FTS 索引、TTS 缓存等可重建派生数据。

## 6. 证据与决策依据

- 原型证据：`prototypes/mac/import-export.html`（范围行结构、默认值呈现、目标位置行、导入预览说明、Keychain 排除披露、设计说明指出"文件访问权限（security-scoped bookmark）与导出包格式需要独立任务方案定义"——本方案即该方案）。
- spec 证据：`docs/spec/007` §4（导出区分用户可读包与可恢复备份包；API Key 等不得进入导出包；FTS / 向量默认非必需；导入恢复先做 schema 和版本检查再用户确认）、§5（导出包优先开放可检查格式：JSON manifest + 附件目录；导入不直接覆盖）、§6（导出测试要求）。
- 备忘录采纳说明：
  - [2026-05-26-practice-recording-sync-export-notes.md](../../architecture/notes/2026-05-26-practice-recording-sync-export-notes.md)：采纳"导出包含原始音频 + metadata + hash + duration + session snapshot"的字段方向与"显式导出"原则；默认开关冲突上交用户决断（第 13 节）；可恢复备份加密按"暂不采纳、记录后续入口"处理。
  - [2026-06-11-prototype-target-design-extension-notes.md](../../architecture/notes/2026-06-11-prototype-target-design-extension-notes.md) §2.5：采纳"导出包格式、附件纳入策略遵守 spec 007"；"导出包与未来同步 manifest 的格式关系"由本方案 12.1 节决策；"导入冲突处理"按本方案第 3 节保守策略落地第一版。
  - [2026-05-20-language-space-sync-extension-notes.md](../../architecture/notes/2026-05-20-language-space-sync-extension-notes.md) §4：采纳"导出和备份必须使用一致性快照，不复制单个 .sqlite 文件"；tombstone 是否进入导出包：第一版导出 active 对象 + 软删除标记字段，完整 tombstone 留给 E11。
- workflow 引用：涉及导出 / 备份，属于 [add-storage-migration.md](../../workflows/add-storage-migration.md) 适用场景（导出、备份、恢复）；本任务不新增 migration（只读主数据 + 导入走既有 repository 写路径），与 workflow 测试矩阵中"敏感字段不进入导出"逐条对齐。无偏离。

```text
证据能证明什么：原型与 spec 007 共同固定了范围行、预览语义、开放格式与密钥排除边界。
证据不能证明什么：原型的练习录音默认开不能推翻已落地的 default-exclude policy 与备忘录结论——两者冲突必须由用户决断。
迁移前提：E2 / E7 schema 稳定后照片与记忆才能纳入；E10 在两者之后、按系列顺序在 E9 之后实施。
照搬风险：照搬"复制 sqlite 文件当备份"的常见做法被 spec 显式禁止；照搬原型默认值会静默改变隐私相关 policy。
```

## 7. 约束映射与验证路径

### 约束 1：导出包不含 Keychain 内容与敏感字段

- 来源：`docs/spec/007` §4、§5、§6；`docs/README.md` 核心决策 9；`docs/decisions/005-local-first-and-user-owned-providers.md`
- 适用范围：导出器全部输出
- 严重度：blocker
- 执行或验证方式：单元测试（禁止表清单：凭证、custom headers、诊断事件等；序列化白名单逐字段声明）
- 验证提示：测试断言导出 JSON 全文不含已知密钥 fixture 字符串与禁止表对象。

### 约束 2：可恢复备份与用户可读包不得混用语义

- 来源：`docs/spec/007` §4
- 适用范围：UI 文案与格式定义
- 严重度：blocker
- 执行或验证方式：人工审查
- 验证提示：本任务只交付可恢复备份包，UI 文案不承诺"可读文档导出"。

### 约束 3：导入先版本检查与预览，不直接覆盖

- 来源：`docs/spec/007` §5
- 适用范围：导入链路
- 严重度：blocker
- 执行或验证方式：单元测试（版本不符拒绝、预览计数、确认前无写入）

### 约束 4：一致性快照导出

- 来源：`docs/architecture/notes/2026-05-20-language-space-sync-extension-notes.md` §4、`docs/spec/007` §4
- 适用范围：导出读路径
- 严重度：blocker
- 执行或验证方式：人工审查 + 并发写入下导出完整性测试

### 约束 5：练习录音按练习证据处理

- 来源：`docs/spec/007` §4（completed recording 非可重建缓存）
- 适用范围：录音纳入导出时的 hash 校验与缺文件处理
- 严重度：warn
- 执行或验证方式：单元测试（缺文件 / hash mismatch 录音在 manifest 中标记缺失而不是导出失败终止）

### 约束 6：macOS 沙盒文件访问

- 来源：`docs/spec/008-permissions-local-privacy-and-diagnostics.md`、`docs/decisions/003-use-xcodegen-for-project-generation.md`（entitlements 经 project.yml 管理）
- 适用范围：entitlement 与文件面板
- 严重度：blocker
- 执行或验证方式：entitlements 文件 diff + macOS 人工验证面板读写
- 验证提示：仅新增 user-selected read-write，不引入更宽的文件权限。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ExportModels.swift`（新增：manifest、范围、错误模型）
- `Packages/LangoTraceData/Sources/LangoTraceData/Export/ExportPackageWriter.swift`、`Export/PortableSnapshots.swift`、`Export/ImportPackageReader.swift`、`Export/ImportMergeService.swift`（新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ImportExport/MacImportExportView.swift`、`ImportExport/ImportPreviewSheet.swift`、`ImportExport/ImportExportActions.swift`（新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`（侧栏入口接线）
- `LangoTraceApp/Supporting/LangoTrace-macOS.entitlements`（新增 user-selected read-write）
- `LangoTraceApp/AppEnvironment.swift`（装配）

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`、`GRDBMediaArtifactRepository.swift`、`GRDBReadingLibraryRepository.swift`（对象读取与媒体 policy 字段）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（schema version 来源）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryStore.swift`（文件导入 preflight 与 security-scoped 资源访问既有模式）

## 10. 涉及的文档路径

- 本方案。
- `docs/spec/007`（实施后补充导出包格式、manifest 与导入合并事实）
- `docs/platform-page-inventory.md`（mac 导入导出页面状态更新）
- `docs/architecture/notes/2026-05-26-practice-recording-sync-export-notes.md`（只读；默认值决断结果实施后回写采纳说明）
- 前序依赖方案：[2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md](2026-06-11-04-feature-entry-photo-attachment-and-photo-writing.md)（E2，照片 policy 字段）、[2026-06-11-10-feature-memory-deposit-foundation.md](2026-06-11-10-feature-memory-deposit-foundation.md)（E7，记忆数据完整性）；推荐在 [2026-06-11-12-feature-local-fts-search.md](2026-06-11-12-feature-local-fts-search.md)（E9）之后实施（导出明确排除 FTS 派生表后边界更清晰）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### 12.1 架构决策：导出 manifest 与未来同步 manifest 收敛为"一套对象序列化、两种信封"

为避免出现两套对象格式（扩展备忘录 §2.5 提醒），决策如下：

- 定义按对象类型的可移植快照编码 `PortableSnapshot`（如 `PortableEntry`、`PortableLearningMaterial`、`PortableMemoryItem`、`PortablePracticeSession`），含稳定 id、space id、全部主数据字段、软删除标记、schema-independent 字段命名与显式 `snapshotVersion`。这是唯一的对象级序列化格式。
- 导出信封：`manifest.json` + `data/*.json`（数组形式的快照集合）+ `attachments/`。
- 未来同步信封（E11）：变更集（change set）+ 修订信息 + tombstone，复用同一 `PortableSnapshot` 编码承载对象内容。
- E11 方案必须引用本节并对齐；若 E11 实施中需要调整快照字段，先回写本格式的 `snapshotVersion` 演进规则，不允许另起对象格式。

### 12.2 实施步骤

1. Core 模型与 Data 序列化（先失败测试）：`PortableSnapshot` 类型族 + 编解码测试（roundtrip、未知字段容忍、版本字段）。
2. 导出器：一致性读快照内逐表读取 → 序列化 `data/*.json` → 按范围开关复制附件文件（经 `MediaArtifactRepository` 解析路径，逐文件 SHA-256，与 metadata content hash 比对，mismatch 标记缺失项）→ 写 `manifest.json` → 包内临时名原子收尾。禁止表清单测试（凭证、custom headers、validation events、diagnostic events、FTS、TTS artifacts 默认排除）。
3. 导入器：security-scoped URL 读取 → manifest 解析 + format / schema 版本检查（高于当前版本拒绝并给出升级提示）→ 哈希校验 → 预览模型（计数、空间信息、id 冲突列表）→ 用户确认后在事务批次内经既有 repository 写路径合并（同 id 跳过保留本地；附件复制回 `MediaArtifacts` 并重建 metadata）。确认前零写入。
4. UI：mac 导入导出页（范围行、目标位置、导出进度与完成态、失败错误分类展示）、导入预览 sheet、`ImportExportActions` seam；面板使用 SwiftUI `fileImporter` / `fileExporter`（满足需求则不直接用 AppKit 面板），目标位置默认 `~/Documents`下用户选择目录。
5. entitlement：`LangoTrace-macOS.entitlements` 增加 `com.apple.security.files.user-selected.read-write`；`xcodegen generate` 后验证。
6. 文档同步与验证收口；导出 / 导入在 macOS 人工走查（大包、断电中断模拟＝中途 kill、重复导入幂等）。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：同系列说明——方案撰写会话内无法对未落盘草稿做隔离审查，按协议第 3 节降级为主会话双轮自审核。
发现摘要：
  第一轮（架构）：
  - P0：原型练习录音默认开 与 2026-05-26 备忘录 / 已落地 export policy 默认排除直接冲突 → 按"不得静默选择"原则上交用户决断（下方问题 1），方案两路皆可实现（开关本身必做，仅默认值不同）。
  - P1：初稿未决策导出 manifest 与同步 manifest 关系 → 新增 12.1 节"一套对象序列化、两种信封"。
  - P1：导入合并的 id 冲突策略缺失 → 固定第一版保守策略：跳过保留本地并在预览列出。
  - P2：导出中途失败的半成品包治理 → 临时名 + 原子收尾 + 失败清理。
  第二轮（测试 / 安全 / 落地）：
  - P0：entitlements 核实确认缺少 user-selected read-write，沙盒下导出落盘会失败 → 列入第 12.2 第 5 步与约束 6。
  - P1：敏感内容排除若只靠"忘了写进去"不可验证 → 改为禁止表清单 + 白名单双保险并写测试。
  - P1：录音缺文件 / hash mismatch 时导出整体失败会让用户无法备份 → 改为标记缺失项继续导出（约束 5）。
  - P2：导入包来自更新 schema 版本的兼容策略 → 高版本拒绝 + 提示，写入测试。
写回修改：以上均已写回第 3、6、7、12 节。
仍需用户确认的问题：
  1.（必须决断）练习录音导出开关的默认值：A=默认关（与 2026-05-26 备忘录、已落地 local-only policy 一致，推荐项需用户确认）；B=默认开（与原型呈现一致，需同步修订备忘录采纳记录与 media artifact export policy 语义说明）。本方案不预设结论。
  2. 导出包形态采用目录式包（`.langotrace-export/` 目录）还是单文件 zip；方案按目录式撰写（可检查、可逐文件校验），如用户偏好单文件再调整。
是否允许进入实现：待用户确认后允许（问题 1 未决断前不得实现练习录音范围行的默认值）。
```

## 14. 复查方法

- 代码：序列化 roundtrip、禁止表清单、导入版本检查、合并幂等测试全绿。
- 行为：macOS 导出一个含记录 / 材料 / 记忆 / 录音 / 照片的空间，包内 manifest 哈希逐项可校验；删除本地数据后导入该包恢复内容；重复导入不产生重复对象；预览数字与实际写入一致。
- 故障与恢复路径：导出中途终止不留半成品污染目标目录；导入损坏包（哈希不符 / manifest 缺失）被拒绝且零写入；磁盘空间不足有用户可见错误；security-scoped 访问失效（书签过期）给出重选路径提示；导出包中检索不到任何密钥串。

## 15. TDD / 测试落点

```text
测试落点：
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Export/PortableSnapshotCodingTests.swift（新增）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Export/ExportPackageWriterTests.swift（新增）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Export/ExportSensitiveExclusionTests.swift（新增）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Export/ImportPackageReaderTests.swift（新增）
  Packages/LangoTraceData/Tests/LangoTraceDataTests/Export/ImportMergeServiceTests.swift（新增）
  Packages/LangoTraceUI/Tests/LangoTraceUITests/ImportExport/ImportExportActionsTests.swift（新增：范围状态、预览确认门、错误分类投影）
先失败用例：ExportPackageWriterTests.manifestListsAllIncludedFilesWithHashes —— 预期失败原因：ExportPackageWriter 尚不存在，编译失败。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceData --filter Export
  swift test --package-path Packages/LangoTraceUI --filter ImportExport
不新增单元测试的原因（如适用）：NSSavePanel / fileExporter 的真实面板交互无法单元测试，降级为 macOS 人工走查（第 14 节），其余全程 TDD。
```

## 16. 验证命令

```bash
# 聚焦
swift test --package-path Packages/LangoTraceData --filter Export
swift test --package-path Packages/LangoTraceUI --filter ImportExport

# 受影响 package 完整
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 工程（entitlements 变化，macOS 环境）
xcodegen generate
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build

# 文档
scripts/check-docs.sh
```

涉及导出 / 备份基础设施，收口前按 spec 007 §6 与用户确认是否补跑 `scripts/verify.sh`（默认不主动运行）。

## 17. 文档影响检查

- `docs/spec/007`：补充导出包格式、manifest、范围 policy、导入合并策略落地事实；练习录音默认值决断结果回写。
- `docs/platform-page-inventory.md`：mac 导入导出页面更新。
- `docs/architecture/notes/2026-05-26-practice-recording-sync-export-notes.md` 与 `2026-06-11-prototype-target-design-extension-notes.md`：采纳处理在本方案记录，备忘录保留原文。
- ADR：不需要新增（沿用本地优先与数据规范）；若用户决断练习录音默认开且涉及隐私边界叙事变化，实施前重新评估是否需要 spec 008 同步。
- release：导出能力进入发布版本前，隐私标签与说明文案需在 release 文档评估（不属于本任务）。
- review：导出 / 备份属于专项审查触发条件，实施后按 `docs/review/README.md` 处理。

## 18. 实施记录

（实施时按时间追加。）

## 19. 完成标准

1. 第 3 节目标全部有代码、测试或人工走查证据；默认值决断已写回方案与文档。
2. 聚焦与受影响 package 测试全绿；macOS 构建通过；导出→清空→导入恢复闭环人工验证通过。
3. spec 007 与页面清单同步完成。
4. plan-vs-shipped 对账完成；加密备份等 deferred 项有后续入口记录。

## 20. 剩余风险

- 导出包未加密：含用户生活记录的明文备份离开 App 容器后由用户自行保管；加密备份为后续独立方案（2026-05-26 备忘录后续问题）。
- 导入合并第一版"同 id 跳过"不处理字段级合并，跨设备各自演进的同 id 对象差异会被忽略，由 E11 冲突模型最终解决。
- 大体积附件导出的进度与取消体验只做基础版（可取消 + 已写入清理），未做断点续传。
- snapshotVersion 演进规则在 E11 对齐前只有导出一个消费方，规则的充分性要在 E11 自审核中复核。
- Linux 环境无法验证面板、entitlement 与真实文件系统行为，必须 macOS 补验。
