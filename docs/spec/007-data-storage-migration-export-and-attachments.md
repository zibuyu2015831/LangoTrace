# 007：数据存储、迁移、导出与附件规范

状态：Accepted

适用阶段：MVP 本地记录闭环、SQLite / GRDB 引入、附件存储、导入导出和长期记忆实现。

## 1. 适用范围

本文档规定语迹 LangoTrace 的本地主数据、派生数据、附件、迁移、导出、删除和恢复边界。它不要求当前阶段立即实现数据库，但后续任何会写入真实用户数据的任务都必须先读取本文档。

## 2. 当前结论

语迹是本地优先的个人语言记忆系统。真实记录、AI 生成材料、练习结果和记忆沉淀都必须先有清晰的本地数据边界，再接入 AI、Speech、OCR、同步或 StoreKit。

当前代码已有 SQLite / GRDB 语言空间基础设施，用于持久化 `language_spaces`、本地 `app_state.current_language_space_id`、启动恢复和语言空间管理。Entry、LearningMaterial、句子分析、修改说明、memory candidate、practice candidate 和 learning material operation 摘要已经通过 `GRDBLearningContentRepository` 进入真实本地持久化路径；`InMemoryLearningContentRepository` 只作为测试替身和开发期 seed preview，不再是 App Shell 的真实 learning content 主路径。后续附件、FTS、导出和同步仍应沿用 SQLite / GRDB 主存储路线；SwiftData 只能作为备选或局部原型方案。

## 3. 数据分层

- 主数据：Language Space、Entry、LearningMaterial / Rendering、PracticeSession、MemoryItem、PromptPreset、ProviderConfig、SyncConfig、PurchaseState。
- 附件数据：照片、音频、OCR 原始文件、手写图像、导入文件和导出包。
- 派生数据：FTS 索引、向量索引、缓存缩略图、AI 请求摘要、练习统计快照。
- 设备级偏好：界面语言偏好、窗口和面板状态、最近打开空间、调试开关。

主数据必须可迁移、可导出、可删除。附件必须有稳定归属和引用关系。派生数据必须可重建，默认不作为同步真源。

当前已落地的语言空间主数据采用：

- `language_spaces`：稳定 `id` 主键、母语、目标语言、水平、展示名、规范化展示名、创建/更新/最近打开/软删除时间。
- `app_state`：本设备当前空间状态，例如 `current_language_space_id`。该状态用于启动恢复和本机最近上下文，不等同于未来默认跨设备同步对象。
- 数据库位置：App 私有容器的 `Application Support/LangoTrace/LangoTrace.sqlite`。
- 删除语义：首版为 soft delete，active 查询、当前空间候选和同名提示排除 deleted 空间；真实 Entry、附件、导出和隐私删除仍需后续任务定义级联行为。
- 学习内容：`entries` 采用 soft delete；`learning_materials` 支持 current material 唯一约束、学习文本编辑后的 analysis stale 状态、重新分析替换 analysis 和候选内容；memory / practice candidates 的 active 查询必须受 Entry 与 current material 删除状态约束。
- Operation 摘要：`learning_material_operations` 采用单行 operation 摘要语义，同一 `operation_id` 只保留一行状态，记录 started / succeeded / failed / cancelled、Prompt id / version、Provider / model 非敏感元数据、长度分桶和失败分类，不记录原文、学习文本、Prompt 全文、请求体、响应体、API Key 或 Authorization header。

## 4. 强制规则

- 每条 Entry、Rendering、PracticeSession 和 MemoryItem 必须归属一个 Language Space。
- 缺少语言空间上下文时，任何真实写入路由都不得创建主数据。
- Language Space、Entry、Repository、迁移、导出、删除、恢复和启动恢复属于数据基础设施。一旦进入真实持久化实现，不得只实现单对象或单语言空间的临时版本作为可交付基础设施；可以在 UI 上暂时只开放创建第一个空间，但底层 schema、repository 协议、迁移测试和删除/导出边界必须按多语言空间、可扩展主数据模型建设。
- 早期开发阶段允许推翻临时代码，但不允许把临时 UserDefaults、内存列表或展示 ID 包装成长期数据基础设施。若为了验证交互临时使用轻量存储，必须在任务方案中标记为 prototype，并不得关闭对应真实基础设施任务。
- SQLite / GRDB schema 引入前，必须有任务方案说明表、主键、外键、迁移编号、回滚策略和测试方式。
- 迁移必须可重复验证；不得依赖用户手动清空容器作为正常升级路径。
- 附件不得散落在临时目录中成为事实主存储；必须通过附件 manifest 或数据库引用关联到主数据。
- 删除主数据时必须定义附件、派生索引、AI 请求元数据和同步 tombstone 的处理方式。
- 导出必须区分用户可读包和可恢复备份包；两者不能混为一个含义。
- API Key、对象存储密钥和外部 Provider token 不得进入普通数据库导出包。
- FTS 和向量索引是可重建派生数据，默认不同步，导出时默认不作为必需数据。
- 同步引擎不能把本地数据库文件整体当作唯一同步对象；后续应以对象、版本和冲突解决为边界。
- `current_language_space_id` 属于本地 app state。后续同步任务不得默认把它作为语言空间主数据同步；如需跨设备最近空间，应单独设计 device state 或用户偏好边界。

## 5. 默认推荐

- 主键使用稳定 ID，不使用展示名、语言名或文件名作为业务主键。
- 数据库 schema 与 Swift model 之间保留 repository 层，不让 SwiftUI View 直接访问数据库。
- 附件按空间和对象归属组织，文件名使用稳定 ID 加扩展名，原始用户文件名作为元数据保存。
- 导出包优先使用开放、可检查格式，例如 JSON manifest 加附件目录；是否压缩和加密由导出类型决定。
- 导入恢复必须先做 schema 和版本检查，再进入用户确认，不直接覆盖当前数据库。
- 真实 AI 输出保存为新对象或新版本，不覆盖用户原始 Entry。
- 练习结果和记忆提取应保留来源引用，用户可以回到原始 Entry 和 Rendering。
- 学习材料生成成功时，LearningMaterial、analysis、candidate 和 succeeded operation 摘要必须在同一数据库写事务内落库；started、failed 和 cancelled operation 记录不得长时间持有写事务等待网络请求。
- 用户编辑 learning text 只能更新派生 LearningMaterial，不得修改原始 Entry 正文；重新分析只能替换当前 material 的 analysis 和候选内容，不得重新生成 learning text。
- 普通导出未来可以包含 Entry、LearningMaterial、句子分析、修改说明和候选项；可恢复备份可以包含稳定 ID、soft delete、current version 和非敏感 Prompt / Provider 元数据；两者都不得包含 API Key、完整请求头、完整请求体、完整响应体、完整 system / user prompt 或诊断日志中的敏感字段。

## 6. 验证要求

实现真实存储后至少覆盖：

- Repository 单元测试：创建、读取、更新、删除和按语言空间查询。
- 迁移测试：从上一 schema 版本迁移到当前版本。
- 附件测试：写入、引用、删除和导出包含关系。
- 导出测试：确认导出包不含 API Key、完整请求头或未授权同步密钥。
- 启动恢复测试：冷启动后恢复最近语言空间和本地记录列表。
- 语言空间基础设施测试：同目标语言多空间、同名提示、missing/deleted current fallback、软删除、最近使用 fallback、Application Support 数据库位置、UTC epoch seconds 和可注入 clock。
- 学习内容基础设施测试：Entry 创建 / 查询、LearningMaterial 保存、学习文本编辑 stale、重新分析替换 analysis、current material 唯一约束、operation 单行摘要更新、删除 Entry 后 active 查询不再返回候选、v3 SQL helper 到当前 schema 迁移、空库迁移、重复 migrator、枚举 CHECK 和 foreign key enforcement。
- 统一收口：涉及数据库或附件写入的任务必须运行 `scripts/verify.sh`，除非环境缺少明确工具并记录剩余风险。

## 7. AI 开发提示

实现任何真实数据写入前先回答：

- 写入的是主数据、附件、派生数据还是设备级偏好？
- 所属 Language Space 如何确定？
- 数据是否需要迁移、导出、删除和同步？
- 是否包含照片、音频、日记、AI 输出、API Key 或外部服务凭据？
- 如果用户取消、失败或重复触发，数据是否会重复、丢失或悬挂？

## 8. 变更记录

- 2026-05-23：更新 learning content GRDB 落地事实。原因：一键生成学习材料任务已将 Entry、LearningMaterial、analysis、candidate 和 operation 摘要接入真实 GRDB repository，并由 App Shell 装配为 iOS 主路径；数据规范需要从“纯内存 mock”更新为真实本地主数据边界。影响范围：LangoTraceData、LangoTraceAI、LangoTraceUI、AppEnvironment、导出/备份/删除/同步前置边界。是否需要 ADR：否，沿用 ADR-005 和 SQLite / GRDB 主存储决策。
- 2026-05-20：补充基础设施完整建设原则。原因：语言空间持久化与启动恢复讨论确认，数据基础设施不能只实现单语言空间临时版本，否则会在多空间、删除、导出、同步和迁移阶段造成返工。影响范围：Language Space、Repository、SQLite / GRDB schema、启动恢复、导出、删除和测试。是否需要 ADR：否，属于既有本地优先与数据规范的实施约束。
- 2026-05-20：补充语言空间 SQLite / GRDB 已落地事实。原因：语言空间数据基础设施实现后，长期数据规范需要区分已完成的语言空间主数据与尚未持久化的 Entry / 附件 / 导出。影响范围：Language Space schema、Repository、Application Support 数据库位置、soft delete、current app state 和测试要求。是否需要 ADR：否，延续本地优先和语言空间 ADR。
- 2026-05-18：创建数据存储、迁移、导出与附件规范。原因：spec 深审确认正式数据层规范缺失，而当前内存 mock repository 不等于长期 SQLite / GRDB 边界。影响范围：Data package、Repository、附件、导入导出、同步前置设计和测试。是否需要 ADR：否，沿用本地优先和 SQLite / GRDB 候选决策。
