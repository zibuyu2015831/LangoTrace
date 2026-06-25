# 007：数据存储、迁移、导出与附件规范

状态：Accepted

适用阶段：MVP 本地记录闭环、SQLite / GRDB 引入、附件存储、导入导出和长期记忆实现。

## 1. 适用范围

本文档规定语迹 LangoTrace 的本地主数据、派生数据、附件、迁移、导出、删除和恢复边界。它不要求当前阶段立即实现数据库，但后续任何会写入真实用户数据的任务都必须先读取本文档。

## 2. 当前结论

语迹是本地优先的个人语言记忆系统。真实记录、AI 生成材料、练习结果和记忆沉淀都必须先有清晰的本地数据边界，再接入 AI、Speech、OCR、同步或 StoreKit。

当前代码已有 SQLite / GRDB 语言空间基础设施，用于持久化 `language_spaces`、本地 `app_state.current_language_space_id`、启动恢复和语言空间管理。Entry、LearningMaterial、句子分析、修改说明、memory candidate、practice candidate 和 learning material operation 摘要已经通过 `GRDBLearningContentRepository` 进入真实本地持久化路径；`InMemoryLearningContentRepository` 只作为测试替身和开发期 seed preview，不再是 App Shell 的真实 learning content 主路径。Reading domain 已落地 `reading_documents`、collection / tag membership、search index、import batch / item、lifecycle event、position、source anchor 和 AI operation summary 扩展表，当前纵向切片通过 `GRDBReadingLibraryRepository` 支持当前语言空间资料列表、搜索、粘贴导入、`.txt` / `.md` 文件导入、collection / tag 赋值、打开、软删除 / 恢复和 reading AI explanation 非敏感 operation summary 写入。媒体派生资产基础设施已经落地 `media_artifacts` / `tts_audio_artifacts` / `practice_recording_artifacts` metadata、`GRDBMediaArtifactRepository`、`LocalMediaArtifactFileStore`、`LocalMediaArtifactStore` facade、Speech TTS 文件校验 seam 和练习录音本地保存 seam；当前实现地图见 `docs/spec/media-artifacts/impl.md`。后续附件、FTS、导出和同步仍应沿用 SQLite / GRDB 主存储路线；SwiftData 只能作为备选或局部原型方案。

## 3. 数据分层

- 主数据：Language Space、Entry、ReadingDocument、LearningMaterial / Rendering、PracticeSession、MemoryItem、PromptPreset、ProviderConfig、SyncConfig、PurchaseState。
- 附件数据：照片、音频、OCR 原始文件、手写图像、导入文件和导出包。
- 媒体派生资产：TTS 逐句音频、全文朗读音频、跟读录音、听写录音、OCR 中间文件和导出临时产物等由主数据、练习流程或 Provider 输出派生的本地媒体文件。
- 派生数据：FTS 索引、向量索引、缓存缩略图、AI 请求摘要、练习统计快照。
- 设备级偏好：界面语言偏好、窗口和面板状态、最近打开空间、调试开关。

主数据必须可迁移、可导出、可删除。附件必须有稳定归属和引用关系。派生数据必须可重建，默认不作为同步真源。

### 3.1 对象生命周期分层

后续设计、实现或评审任何“会被用户创建、导入、维护或依赖”的对象时，必须先判断该对象属于哪一类，再决定默认生命周期。禁止把所有对象粗暴套用同一 CRUD 模型，也禁止把用户主数据退化成只有创建或只读的半闭环。

#### 3.1.1 用户主数据

用户主数据是用户主动创建、导入、长期保留并期望继续维护的对象，例如 `LanguageSpace`、`Entry`、`ReadingDocument`、未来的 `MemoryItem`、附件主数据和用户自建词典条目。

默认要求：

- `Create`：必须定义创建或导入入口，以及失败 / 取消后的稳定状态。
- `Read`：必须定义列表、打开、查询、过滤、定位或恢复查看路径。
- `Update`：必须显式评估正文编辑、元数据编辑、状态更新或替代的受控修改路径；如果当前阶段暂不实现，任务方案必须记录原因和后续入口。
- `Delete`：必须定义删除语义，至少说明是软删除、硬删除还是受限删除，并定义恢复、确认、级联影响和导出 / 同步边界。

禁止事项：

- 不得把用户主数据只实现为“可创建但不可维护”的单向漏斗。
- 不得把临时导入缓存、视图状态或一次性 operation 伪装成用户主数据。

#### 3.1.2 派生数据

派生数据来自主数据、模型推理、索引或缓存重建，例如 `LearningMaterial` 分析结果、memory / practice candidate（学习材料候选 `memory_candidates` 与语伴聊天反哺候选 `companion_memory_candidates`，二者均为升级为记忆条目前的评审暂存）、FTS / 向量索引、TTS artifact 和各类可重建摘要。

默认生命周期不是通用 CRUD，而是：

- 生成 / 写入
- 查看 / 使用
- 失效 / 标记 stale
- 重建 / 重新生成
- 清理 / 淘汰

如果派生数据会被用户长期引用、人工修正或作为完成证据保留，任务方案必须进一步说明哪些字段接近主数据语义，哪些字段仍保持派生数据语义。

#### 3.1.3 配置对象

配置对象表达系统或空间级能力配置，例如 `AI Provider`、`TTS Provider`、同步配置、界面偏好和设备级设置。

默认生命周期是：

- 读取当前值
- 保存 / 创建配置
- 更新配置
- 删除、重置或停用配置
- 验证配置是否可用

配置对象不要求照搬内容型 CRUD 列表语义，但必须有清晰的保存、覆盖、清空和验证边界。

#### 3.1.4 运行期记录

运行期记录包括 operation summary、probe result、诊断日志、临时 preflight 失败记录和其他以审计或调试为主的对象。

默认生命周期是：

- 受控写入
- 脱敏保留
- 查询或摘要展示
- 清理、过期或轮转
- 导出排除或受控披露

运行期记录默认不是用户主数据，不应被设计成普通业务 CRUD 页面。

当前已落地的语言空间主数据采用：

- `language_spaces`：稳定 `id` 主键、母语、目标语言、水平、展示名、规范化展示名、创建/更新/最近打开/软删除时间。
- `app_state`：本设备当前空间状态，例如 `current_language_space_id`。该状态用于启动恢复和本机最近上下文，不等同于未来默认跨设备同步对象。
- 数据库位置：App 私有容器的 `Application Support/LangoTrace/LangoTrace.sqlite`。
- 删除语义：首版为 soft delete，active 查询、当前空间候选和同名提示排除 deleted 空间；真实 Entry、附件、导出和隐私删除仍需后续任务定义级联行为。
- 学习内容：`entries` 采用 soft delete，并允许在详情页更新 Entry body；该更新只修改 `entries.body` / `updated_at`，不得自动修改或删除派生 `learning_materials`。`learning_materials` 支持 current material 唯一约束、生成时的 `source_entry_body_hash`、学习文本编辑后的 analysis stale 状态、重新分析替换 analysis 和候选内容；memory / practice candidates 的 active 查询必须受 Entry 与 current material 删除状态约束。
- Operation 摘要：`learning_material_operations` 采用单行 operation 摘要语义，同一 `operation_id` 只保留一行状态，记录 started / succeeded / failed / cancelled、Prompt id / version、Provider / model 非敏感元数据、长度分桶和失败分类，不记录原文、学习文本、Prompt 全文、请求体、响应体、API Key 或 Authorization header。
- Reading 主数据：`reading_documents` 必须按 `space_id` 隔离，记录 stable id、title、source kind / format、adapter id/version、body storage kind、inline body 或未来 managed file artifact id、body hash、content revision、structure version、target language code、import status、library status、soft delete / restore 时间和 last opened 时间。`reading_document_search_index` 是可重建索引；collection / tag、import batch / item、lifecycle event、position、source anchor 和 AI explanation operation summary 必须继续保持 space scope，不保存外部绝对路径、完整 AI 请求体、完整响应体或 API Key。`reading_explanation_cache.result_json` 以明文 JSON 存储解析后的解释结果，属于本机可重建派生缓存：不进入导出、不同步、可随时从 AI Provider 重新生成而不丢失用户主数据；清理缓存不影响用户可见的学习状态。
- 本地 preflight 阻断也可以写入 failed operation 摘要，典型分类包括 `contentEmpty`、`contentTooLong` 和 `operationInProgress`；这些摘要不得暗示已经发送 Provider 请求。
- 媒体派生资产：`media_artifacts` 记录 language space、owner、artifact type、derivation kind / key hash、相对文件路径、MIME、byte size、duration、content hash、created / last accessed、invalidated / delete_after、`file_state` 和 backup / sync / export policy；`file_state = pending` 的 metadata 不得被 lookup 当作 ready cache hit，文件 move 与校验完成后才能转为 `ready`。`derivation_kind` CHECK 必须允许已落地的 `ttsAudio` 和 `practiceRecording`；旧库 schema 漂移不得要求用户清空容器，而应通过迁移修复。`tts_audio_artifacts` 记录 TTS 专属 sentence source、entry / learning material / temporary operation source、文本 hash、target language、provider profile、endpoint、voice profile、adapter、model、voice hash、format、speed / pitch / volume、instructions hash、provider parameters hash 和 configuration fingerprint。`practice_recording_artifacts` 记录练习录音 typed metadata，包括 session、recording、attempt、target text hash、target language、recording format、sample rate、channel count、duration 和 content hash。`GRDBMediaArtifactRepository` 只管 metadata；`LocalMediaArtifactFileStore` 只管 App 管理的 `MediaArtifacts` 文件目录、staging、原子 move、hash、删除和 staging 清理；`LocalMediaArtifactStore` facade 统一编排 metadata、文件和 Core 校验 / 录音提交 seam，metadata / 文件不一致时必须精确失效当前 artifact，不得按 owner 扩大失效同源其他缓存。

## 4. 强制规则

- 每条 Entry、Rendering、PracticeSession 和 MemoryItem 必须归属一个 Language Space。
- 缺少语言空间上下文时，任何真实写入路由都不得创建主数据。
- 新增主数据对象、导入入口、资料库页面或对象详情页时，任务方案必须显式判断该对象属于用户主数据、派生数据、配置对象还是运行期记录，并写明对应生命周期；若对象属于用户主数据，默认必须设计完整 CRUD，除非在方案中明确记录当前阶段暂缓的项、原因和后续入口。
- Language Space、Entry、Repository、迁移、导出、删除、恢复和启动恢复属于数据基础设施。一旦进入真实持久化实现，不得只实现单对象或单语言空间的临时版本作为可交付基础设施；可以在 UI 上暂时只开放创建第一个空间，但底层 schema、repository 协议、迁移测试和删除/导出边界必须按多语言空间、可扩展主数据模型建设。
- 早期开发阶段允许推翻临时代码，但不允许把临时 UserDefaults、内存列表或展示 ID 包装成长期数据基础设施。若为了验证交互临时使用轻量存储，必须在任务方案中标记为 prototype，并不得关闭对应真实基础设施任务。
- SQLite / GRDB schema 引入前，必须有任务方案说明表、主键、外键、迁移编号、回滚策略和测试方式。
- 迁移必须可重复验证；不得依赖用户手动清空容器作为正常升级路径。
- 附件不得散落在临时目录中成为事实主存储；必须通过附件 manifest 或数据库引用关联到主数据。
- 媒体派生资产不得散落在临时目录、SwiftUI 私有状态或不可索引文件名规则中成为事实主存储；必须通过 GRDB / SQLite metadata 或等价 repository 引用文件，并定义 owner、artifact type、derivation key、相对路径、byte size、duration、created / last accessed、失效、清理、backup policy、sync policy 和 export policy。
- 可重建但隐私敏感的媒体派生资产，例如 TTS 音频，默认不是用户主数据，也不是普通系统缓存；第一阶段应使用 App 管理目录，默认 local only、excluded from system backup、excluded by default from export，后续同步、备份或导出必须单独设计 manifest、加密、删除传播和恢复策略。
- 被练习完成态引用的用户录音不是可重建缓存，必须按练习证据处理。普通 LRU、TTS cache cleanup 或派生缓存清理不得静默删除 `practice_sessions.completed_recording_id` 引用的 recording artifact；文件缺失或 hash mismatch 时应保留 completed session，并把 playback source 标为 unavailable / missing。
- 媒体资产扩展必须采用通用主表加 typed metadata extension table 的形态。TTS typed metadata 属于 `tts_audio_artifacts`；练习录音不得复用 TTS key、TTS extension table 或 TTS 专属 commit method 承载用户录音。
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
- 媒体派生资产按语言空间、owner 和 artifact type 归属组织，文件名使用 artifact id、content hash 或 derivation key hash；文件名和目录名不得包含原文、Entry 标题、用户输入短语、Provider secret 或完整 Keychain account。
- 导出包优先使用开放、可检查格式，例如 JSON manifest 加附件目录；是否压缩和加密由导出类型决定。
- 导入恢复必须先做 schema 和版本检查，再进入用户确认，不直接覆盖当前数据库。
- 真实 AI 输出保存为新对象或新版本，不覆盖用户原始 Entry。
- 练习结果和记忆提取应保留来源引用，用户可以回到原始 Entry 和 Rendering。
- 学习材料生成成功时，LearningMaterial、analysis、candidate 和 succeeded operation 摘要必须在同一数据库写事务内落库；started、failed 和 cancelled operation 记录不得长时间持有写事务等待网络请求。
- 学习材料生成落库时必须基于同一事务中读取的 active Entry body 写入 `source_entry_body_hash`，用于后续判断 material 是否基于旧原文；该字段不得由 AI 响应提供。
- 用户编辑 Entry body 只更新原始 Entry，不自动发送 Provider 请求，不自动把 `analysis_status` 标为 stale。UI / Store 通过当前 Entry body hash 与 current material 的 `source_entry_body_hash` 比较展示“基于旧记录”，并由用户显式触发重新生成。
- 用户编辑 learning text 只能更新派生 LearningMaterial，不得修改原始 Entry 正文；重新分析只能替换当前 material 的 analysis 和候选内容，不得重新生成 learning text。
- 普通导出未来可以包含 Entry、LearningMaterial、句子分析、修改说明和候选项；可恢复备份可以包含稳定 ID、soft delete、current version 和非敏感 Prompt / Provider 元数据；两者都不得包含 API Key、完整请求头、完整请求体、完整响应体、完整 system / user prompt 或诊断日志中的敏感字段。

## 6. 验证要求

实现真实存储后至少覆盖：

- Repository 单元测试：创建、读取、更新、删除和按语言空间查询。
- 迁移测试：从上一 schema 版本迁移到当前版本。
- 附件测试：写入、引用、删除和导出包含关系。
- 媒体派生资产测试：metadata / 文件原子提交、孤立文件清理、metadata 文件丢失恢复、失效规则、LRU 或容量清理、备份 / 同步 / 导出 policy 默认值、日志不含原文和密钥。
- 导出测试：确认导出包不含 API Key、完整请求头或未授权同步密钥。
- 启动恢复测试：冷启动后恢复最近语言空间和本地记录列表。
- 语言空间基础设施测试：同目标语言多空间、同名提示、missing/deleted current fallback、软删除、最近使用 fallback、Application Support 数据库位置、UTC epoch seconds 和可注入 clock。
- 学习内容基础设施测试：Entry 创建 / 查询、LearningMaterial 保存、学习文本编辑 stale、重新分析替换 analysis、current material 唯一约束、operation 单行摘要更新、删除 Entry 后 active 查询不再返回候选、v3 SQL helper 到当前 schema 迁移、空库迁移、重复 migrator、枚举 CHECK 和 foreign key enforcement。
- 统一收口：涉及数据库、附件或媒体派生资产写入的任务必须运行 `scripts/verify.sh`，除非环境缺少明确工具并记录剩余风险。

## 7. AI 开发提示

实现任何真实数据写入前先回答：

- 写入的是主数据、附件、媒体派生资产、派生数据还是设备级偏好？
- 所属 Language Space 如何确定？
- 数据是否需要迁移、导出、删除和同步？
- 是否包含照片、音频、日记、AI 输出、API Key 或外部服务凭据？
- 如果用户取消、失败或重复触发，数据是否会重复、丢失或悬挂？

## 8. 变更记录

- 2026-06-17：补充照片附件旧库修复和导入失败补偿事实。原因：运行态发现旧 v17 / v19 数据可能存在缺失 `entry_photo_attachments` 表或已有 `entryPhotoOriginal` media artifact metadata 但缺 attachment row 的漂移状态；新增 `v19_ensure_entry_photo_attachments` 和 `v20_backfill_entry_photo_attachments_from_media_artifacts` repair migration。`PhotoImportPipeline` 在 metadata 事务失败时必须清理已 move 到永久目录的 original / thumbnail 文件，避免继续产生无 metadata / attachment 的孤立照片文件；只有文件、没有 `media_artifacts` metadata 的历史孤立文件不得按文件名或时间猜测绑定回 entry。影响范围：AppDatabase migration、PhotoImportPipeline failure compensation、照片详情缺失态和后续故障排查。是否需要 ADR：否，属于既有 SQLite / GRDB、本地优先和照片主资产边界的实施修正。
- 2026-06-17：新增照片附件基础设施落地事实。原因：E2（feature-entry-photo-attachment-and-photo-writing）已完成 `entry_photo_attachments` 表（v17 migration）、`entryPhotoOriginal` / `entryPhotoThumbnail` artifact type 扩展、`GRDBEntryPhotoAttachmentRepository`、`PhotoImportPipeline`（EXIF GPS 剥离、缩略图、原子写入）和 `PhotoDisplayActions` 环境值。原始照片是用户主资产（`delete_after = NULL`，不进入 LRU），缩略图是可重建派生资产，两者均默认 local-only、excluded from backup、excluded from export；照片字节绝对不发送 AI Provider。实现地图已更新至 `docs/spec/media-artifacts/impl.md`。影响范围：media_artifacts schema、entry_photo_attachments schema、Data / Core / UI package、AppEnvironment 装配和后续删除 / 同步 / 导出边界。是否需要 ADR：否，沿用本地优先和用户自带 Provider；若未来引入照片同步或默认备份，再评估 ADR。
- 2026-06-03：新增对象生命周期分层规则。原因：阅读材料导入与三端阅读 UI 重构后，仓库需要明确”用户主数据默认必须具备完整生命周期”，同时避免把派生数据、配置对象和运行期记录粗暴套用同一 CRUD 模型。影响范围：ReadingDocument、后续 Memory / 附件 / PromptPreset / 设置对象设计、任务方案和 workflow 门禁。是否需要 ADR：否，属于数据和对象治理规范补强。
- 2026-05-26：新增 media-artifacts 实现地图并冻结练习录音前置 API review 结论。原因：跟读录音完成闭环需要把现有 TTS-oriented media artifact facade 提升为通用 commit / resolver / cleanup contract，并明确 completed practice recording retention。影响范围：Core、Data、Speech、Practice session schema、导出 / 备份 / 同步后续边界。是否需要 ADR：否，沿用本地优先和 SQLite / GRDB 主存储决策；若未来默认同步或备份用户录音，再评估 ADR。
- 2026-06-01：新增 Reading domain 存储事实。原因：阅读纵向切片新增 `v12_create_reading_domain_infrastructure` migration 和 `GRDBReadingLibraryRepository`，阅读资料成为按语言空间隔离的本地主数据。影响范围：ReadingDocument、资料库搜索、软删除 / 恢复、import batch、source anchor、AI operation summary、TTS source columns 和后续导出 / 同步边界。是否需要 ADR：否，沿用 SQLite / GRDB 和本地优先决策。
- 2026-05-26：同步练习录音回放故障修复后的 schema 边界。原因：旧库 `media_artifacts.derivation_kind` CHECK 只允许 `ttsAudio` 会阻止 `practiceRecording` artifact 落库，导致录音文件停留在 staging 且不可回放；数据规范需要明确旧库 schema 漂移必须通过迁移修复，不得要求用户清空容器。影响范围：AppDatabase migration、media artifact metadata、practice recording typed metadata、测试和故障排查 runbook。是否需要 ADR：否，属于既有 SQLite / GRDB 和本地优先决策的实施修正。
- 2026-05-23：更新 learning content GRDB 落地事实。原因：一键生成学习材料任务已将 Entry、LearningMaterial、analysis、candidate 和 operation 摘要接入真实 GRDB repository，并由 App Shell 装配为 iOS 主路径；数据规范需要从“纯内存 mock”更新为真实本地主数据边界。影响范围：LangoTraceData、LangoTraceAI、LangoTraceUI、AppEnvironment、导出/备份/删除/同步前置边界。是否需要 ADR：否，沿用 ADR-005 和 SQLite / GRDB 主存储决策。
- 2026-05-23：同步本地媒体派生资产基础设施落地事实。原因：`2026-05-23-feature-local-media-artifact-store-and-tts-audio-cache` 已实现 Core 契约、GRDB metadata、file store、facade、Speech 文件校验和聚焦测试，数据规范需要从“应建设”更新为“第一阶段已落地”。影响范围：Data、Speech、TTS direct playback 前置、导出 / 备份 / 同步后续边界和诊断日志。是否需要 ADR：否，沿用本地优先和用户自带 Provider；未来若默认同步或备份音频，再评估 ADR。
- 2026-05-23：补充媒体派生资产边界。原因：逐句 TTS 播放方案确认 TTS 音频不能按临时 UI 缓存落地，应作为本地优先、隐私敏感、可重建的媒体派生资产处理，并为后续全文朗读、跟读录音、听写录音、音频同步和导出预留一致基础设施。影响范围：Data、Speech、AI Provider、附件、导出、备份、同步前置设计和诊断日志。是否需要 ADR：否，沿用本地优先和用户自带 Provider；若未来引入官方托管音频或默认跨设备音频同步，再评估 ADR。
- 2026-05-20：补充基础设施完整建设原则。原因：语言空间持久化与启动恢复讨论确认，数据基础设施不能只实现单语言空间临时版本，否则会在多空间、删除、导出、同步和迁移阶段造成返工。影响范围：Language Space、Repository、SQLite / GRDB schema、启动恢复、导出、删除和测试。是否需要 ADR：否，属于既有本地优先与数据规范的实施约束。
- 2026-05-20：补充语言空间 SQLite / GRDB 已落地事实。原因：语言空间数据基础设施实现后，长期数据规范需要区分已完成的语言空间主数据与尚未持久化的 Entry / 附件 / 导出。影响范围：Language Space schema、Repository、Application Support 数据库位置、soft delete、current app state 和测试要求。是否需要 ADR：否，延续本地优先和语言空间 ADR。
- 2026-05-18：创建数据存储、迁移、导出与附件规范。原因：spec 深审确认正式数据层规范缺失，而当前内存 mock repository 不等于长期 SQLite / GRDB 边界。影响范围：Data package、Repository、附件、导入导出、同步前置设计和测试。是否需要 ADR：否，沿用本地优先和 SQLite / GRDB 候选决策。

## 变更记录补充：本地 FTS 全文搜索落地（E9，2026-06-18）

E9 落地本地 FTS5 全文搜索基础设施，作为**本地可重建派生数据**（沿用 §FTS/索引边界与核心决策 12）：

- migration `v25_create_local_search_index`：`search_index` 为 FTS5 `tokenize='trigram'` 虚表（`object_kind`/`object_id`/`space_id`/`reading_block_index` 为 UNINDEXED 元数据列，`title`/`body` 为索引列），trigram 对 CJK 与拉丁文本统一支持子串匹配；附 `search_index_meta` 单行版本表记录 `index_schema_version`。
- 维护策略（决策 12.1）：应用层集中写入 `SearchIndexWriter`（upsert/remove，同事务），v1 以 `GRDBLocalSearchRepository.rebuildSearchIndex(spaceID:)` 从主数据（entries + 当前 learning_text、reading_documents 当前结构版本的 blocks）全量重建为索引维护路径（搜索浮层打开时 rebuild，保证新鲜）；按写路径增量 upsert 列为后续优化。
- 查询：`GRDBLocalSearchRepository.search(query:spaceID:perGroupLimit:)` 分组（记录/阅读/记忆）、按 `space_id` 隔离、trigram MATCH（查询 ≥3 字符）/ `LIKE` 降级（<3 字符）、FTS rank 排序、每组截断；高亮区间用 Core `SearchHighlighting`（UTF-safe grapheme 偏移）。
- 边界：FTS 索引**不同步、导出非必需、可全量重建**；搜索全链路只依赖 GRDB，不接触任何 Provider/网络（约束 1/2）。记忆分组在 E7（`memory_items`）落地前以零态降级。
- tokenizer 可用性：部署目标 iOS 18 / macOS 15 的系统 SQLite 含 FTS5 + trigram；availability 已由 `LocalSearchTests` 在 CI macOS runner 上确认（创建 trigram 虚表 + MATCH 查询成功）。

## 变更记录补充：记忆沉淀主数据落地（E7，2026-06-18）

E7 落地 `memory_items` 作为用户主数据（§3.1.1），归属语言空间（ADR-004），从分析候选显式沉淀：

- migration `v26_create_memory_item_infrastructure`：`memory_items`（space_id NOT NULL、entry_id ON DELETE SET NULL 使沉淀项在来源记录删除后仍存活、source_kind='candidate'、kind CHECK('wordPhrase','sentence')、difficulty、created_at、soft_deleted_at）+ E8 复习生命周期列（review_state CHECK('new','scheduled','mastered')、review_rung、review_due_at、last_reviewed_at、review_count、mastered_at），候选去重 partial unique index `(space_id, source_candidate_id)`。
- 主数据 vs 派生：沉淀项是**快照**（text/note/example 从候选拷贝），与 `memory_candidates`（派生、reanalysis 时 CASCADE 删除）解耦——候选重生成不影响已沉淀记忆。候选 5 kind→沉淀 2 kind 映射：word/phrase→wordPhrase、sentencePattern/grammarPoint/errorPattern→sentence。
- `MemoryItemRepository`（Core 协议）+ `GRDBMemoryItemRepository`：幂等 `depositCandidate`（同候选二次沉淀返回既有项）、`listMemoryItems`、`depositedCandidateIDs`/`depositedEntryIDs`、`softDelete`。
- UI：iPhone/iPad/macOS 记忆面展示只读沉淀列表；iPhone 候选行提供显式「加入记忆/已加入」动作；`EntryTimelineFilter.settled` 由 `depositedEntryIDs` 真实判定（Phone/Pad 时间线与侧栏计数已接线）。
- 同步/导出：沉淀记忆是主数据，同步（E11）/导出（E10）留对应方案；本切片不含同步/导出。E8 复习队列复用本表 review 列、不新增 migration。E9 记忆搜索组待消费本表（当前仍零态，按写路径接入索引为后续）。

## 变更记录补充：记忆复习队列落地（E8，2026-06-18）

E8 在 E7 `memory_items`（v26）的 review 列上落地本地固定间隔复习，**不新增 migration**：

- Core 纯 `MemoryReviewScheduler`（注入 clock，间隔阶梯 [1,3,7,14,30] 天，状态机 `new→scheduled→(阶梯顶端)mastered`，`还要再看` 重置首鬰、`markMastered`/`resumeReview`）+ `MemoryReviewOutcome`（记得/还要再看）+ `MemoryStatistics`。
- `MemoryItemRepository` 扩展：`dueItems`（state IN new/scheduled 且 due<=now，new 视为立即可复习）、`recordReviewOutcome`（单事务读→scheduler→写回并自增 review_count）、`markMastered`/`resumeReview`、`memoryStatistics`（本周沉淀按 `created_at` 落在本地周一起始当周，在 Swift 用 Calendar 派生而非 SQL；待复习；已掌握）。
- UI：三端记忆面顶部统计条（本周沉淀/待复习/已掌握）+「开始复习」入口；共享 `MemoryReviewSessionView` 小批量（默认 10）复习会话：目标文本先行→看释义→记得/还要再看→标记已掌握，中途退出安全（已提交反馈已落库，未复习项留队列）。
- 边界：全程本地、不发外部请求、不建向量/检索（守核心决策 12 + embedding 红线），低压力文案不暴露算法概念。复习数据是主数据；同步/导出留 E10/E11。

## 变更记录补充：非敏感导出/导入引擎落地（E10 Slice 1，2026-06-18）

E10 Slice 1 落地本地非敏感导出/导入引擎（无新 migration，导出只读、导入走 INSERT OR IGNORE 同 id skip）：

- Core `ImportExport`：`PortableEntrySnapshot`/`PortableMemorySnapshot`/`ExportManifest`/`PortableExportPackage` + 确定性 SHA-256 payload checksum（按 id 排序，与行序无关）+ `formatVersion` 兼容门。
- Data `GRDBLocalExportService`：`exportPackage(spaceID:)`/`exportPackageData` 导出 entries + deposited memory_items（用户主数据）；`preview`/`importPackage` verify-before-write（先校验 formatVersion ≤ 当前 + checksum，再同 id skip 合并）。明文开放格式，**无加密**——secrets 是排除而非保护（核心决策 9）；manifest schemaVersion 记 `v26`（informational）。
- 排除保证（有测试断言导出 JSON 不含 keychain/secret/api_key）：凭证/Keychain 列、provider/TTS 配置、ai_request_logs 与 operation 摘要、search_index/向量/cache/tts artifacts 派生、app_state 设备本地。
- **deferred**（见 `docs/architecture/notes/2026-06-18-export-backup-deferred-slices.md`）：Slice 2（macOS `fileExporter`/`fileImporter` + entitlement + 附件文件打包，需 macOS runner 验证）、加密/口令备份包（依赖不存在的 KDF/安全存储）、其余主数据表（learning materials/reading/practice）导出。引擎格式已证明，扩展为机械工作。

## 变更记录补充：学习者模型 Memory 层落地（LM02 Slice 1，2026-06-25）

LM02 Slice 1 落地 Learner Model 的 **Memory 层**——用户**显式记住**的生活事实 / 目标，系统级横切语言空间（ADR-006 §3）：

- migration `v27_create_learner_memory_facts`：**仓库首张系统级表**，刻意**无 `space_id`/无 space FK**（事实全局共享，切换空间可见、删空间不级联删，ADR-006 §7.1）；`source_entry_id TEXT REFERENCES entries(id) ON DELETE SET NULL`（弱引用，事实比来源记录长寿，沿用 `memory_items.entry_id` 先例）；`kind`/`visibility`/`source`/三策略列均带 CHECK 约束；`soft_deleted_at REAL`。索引 `idx_learner_memory_facts_active_created(soft_deleted_at, created_at)`。
- **准原始持久化策略（ADR-006 §8，与 TTS 派生资产相反）**：策略列复用 Core `MediaArtifact*Policy` 词汇但取 `sync_policy=localOnly` / `backup_policy=includedInSystemBackup` / `export_policy=includedInRecoverableBackup`（**真实枚举字面值**，不存在 `included`）。
- **删除语义（二段式）**：单条删 = `soft_deleted_at` 置位（可查看已删除 / 撤销）；系统级「重置 App 对我的了解」= `resetAll()` **物理 DELETE**（使「重置」名实相符，并消除最浓缩 PII 软删明文残留）。v2 自动抽取的 tombstone 暂不建（v1 无抽取）。
- **写 seam**：`AppDatabase` 新增 `public var writer: DatabaseWriter`（LM01 §20 预告），`GRDBLearnerMemoryRepository` 经此拥有系统级读写。Ability 覆盖仍 compute-on-read 不持久（E7/LM01 不受影响）。
- **静态安全**：v1 复用整库 `FileProtection.completeUntilFirstUserAuthentication`（iOS）；**字段级加密 / SQLCipher 未决**（ADR-006 §5.2），记入 `docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`。
- **E10 硬接缝**：可恢复备份**必须**纳入 `learner_memory_facts`（`export_policy=includedInRecoverableBackup`），否则删库 = 永久失忆；实际打包随 E10 后续切片（当前 Slice 2 deferred），接缝由上述 architecture note 托管。

## 变更记录补充：学习者模型 Style 表面印记（LM02 Slice 2，2026-06-25）

LM02 Slice 2 落地 Learner Model 的 **Style 层 v1 表面写作印记**（seam-only，不展示）：

- **compute-on-read 真派生、不持久、不进备份**：`GRDBLearnerStyleProvider` 从 `entries.body` 机械重算（`NaturalLanguage` 检测语种 + 机械分词指标 + 按母语分组），**无新表 / 无 writer / 无 migration**，与 LM01 Ability 同型；`entries` 本身已纳主数据备份，重算即得。
- **ADR-006 §8 持久化分类分层细化**：§8 把整个 Style 层列「准原始 → 纳入备份」**未分 v1/v2**；本切片 reconcile——**v1 表面印记 = 真派生不持久**；§8「准原始 → 持久 + 备份」实质仅适用 **v2 自陈 / AI 认知风格**（不可从行为廉价重算）。事实源 `docs/architecture/notes/2026-06-25-style-surface-imprint-recompute-notes.md`。
- **红线（ADR-006 §4）**：只读 `entries.body`，绝不读 `learning_materials` / `learning_text` / `input_kind` / `memory_candidates`（AI 生成物）。语言判定靠 `NLLanguageRecognizer`，`entries.source` 非语言键。
- 与 LM01 Ability（compute-on-read 不持久）、S1 Memory（准原始 → `includedInRecoverableBackup`）、S3 盲点（compute-on-read 不持久）并列，构成 Learner Model 三层持久化分叉的完整图景：**能从已备份源数据廉价重算者不持久；不可廉价重算者（Memory 显式记住 / v2 认知风格）才准原始 + 备份**。

## 变更记录补充：查词行为捕获 + 分析账本（LM02 Slice 4a，2026-06-25）

LM02 Slice 4a 落地 S4b band 重估的**信号 + 增量重算地基**（硬前置 S1 v27 + writer seam）：

- migration `v28_create_dictionary_lookup_events`：查词 / 索取解释**行为事件**（`language_space_id` FK ON DELETE CASCADE、`looked_up_term`、`source_content_id`、`source_content_origin TEXT CHECK('userAuthored','aiGenerated') DEFAULT 'userAuthored'`、`occurred_at`、`soft_deleted_at`）。**显式持久化策略列**：`sync_policy=localOnly` / `backup_policy=excludedFromSystemBackup` / `export_policy=excludedByDefault`——**「不可重算用户行为信号」新类别**（非照搬 practice_text_attempts 伪先例：后者无策略列、归档导出方案列其为主数据；spec §112 的 local-only 讲的是 TTS / 媒体派生资产）。索引 `(language_space_id, soft_deleted_at, occurred_at)` 支撑窗口查询。
- migration `v29_create_analysis_ledger`：ADR-006 §9 分析账本 + 高水位 cursor 首次建对——键 `UNIQUE(source_type, source_id, analyzer, analyzer_version)` + `cursor_position`（增量窗口聚合、非 per-item 旗标）；升 `analyzer_version` = 新行 cursor 0 = 全量重跑；cursor 单调推进（stale advance 忽略）。账本以 `(source_type, source_id)` 引用源，不在源表加列（查词事件 `source_type='dictionaryLookup'`）。
- **持久化分层**：查词事件 = 不可重算用户行为信号（local-only 不备份不导出，设备迁移后丢失——S4b band 须能从剩余信号优雅降级重估）；账本 / cursor = 派生状态（可从事件重算）。**开放产品问题**：查词事件是否应像 practice 主数据可导出，v1 默认否。
- **红线（ADR-006 §4）**：repository / 埋点写入字段仅用户行为（term + 时间 + 内容引用），绝不记 AI 判定难度 / AI 点评内容。FileProtection 接缝登记进 `docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`。
- **source_content_origin 前向接缝**：v1 阅读文档恒用户导入（`reading_documents.source_kind` 仅 pastedText/fileImport），故 v1 恒 `userAuthored`；`aiGenerated` 分支待未来「学习材料可作阅读源」基础设施落地再填 + S4b 启用二阶闭环过滤。

## 变更记录补充：语伴会话存储（LM03 Slice 1，2026-06-25）

LM03-S1 落地语伴单线程文本对话的 GRDB 存储（硬前置 S1 writer seam）：

- migration `v30_create_companion_infrastructure`，三表均 per-space、显式策略列：
  - `conversation_companions`（`space_id` PK/FK ON DELETE CASCADE、人设三枚举 `tone`/`formality`/`correction` 带 CHECK）。
  - `companion_threads`（`space_id` FK CASCADE、`source_entry_id` FK **ON DELETE SET NULL**=方案 A 弱链、`created_at`）。
  - `companion_messages`（`thread_id` FK CASCADE、`UNIQUE(thread_id, sequence)` 线性序、`role` CHECK('user','assistant')、`content`、`detected_language`、`target_language_code`、**语音前向接缝** `input_modality` CHECK('text','voice') DEFAULT 'text' + `audio_artifact_id`（v1 恒 null，FK 待语音切片））。
- **持久化策略第三类（区别于 S4a 行为信号）**：companion 三表 = **可恢复用户主数据**，显式 `sync_policy=localOnly` / `backup_policy=includedInSystemBackup` / `export_policy=includedByDefault`——与 entries / learning content 同备份+导出口径，仅不同步（对话历史的价值在跨会话持续存在；ADR-008 §4「可导出」）。这是 spec 三分法的明确补充：① 可重建派生（向量索引，不备份不导出）；② 不可重算行为信号（`dictionary_lookup_events`，excluded）；③ **可恢复用户主数据（companion，included）**。
- **隐私边界**：S1 零系统自动注入（不读 Memory facts / 不 FTS）；外发仅用户消息 + 显式带入单条 Entry，经 Provider 抽象 + E6 投影。Memory 注入 + PII scrubbing = LM03-S2b。
- 语音接缝事实源：`docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md`。

## 变更记录补充：语伴聊天反哺候选（LM03 Slice 2a，2026-06-26）

LM03-S2a 落地语伴聊天反哺的派生候选存储与产出证据前向接缝：

- migration `v31_create_companion_reflux_infrastructure`，新表 `companion_memory_candidates`（**独立表，不改 `memory_candidates`**——后者 `entry_id`/`material_id` NOT NULL FK 物理排斥聊天来源行；改可空需 12 步整表重建，触碰学习内容主路径，故隔离，plan §D1）：
  - 列 `id` PK、`space_id` FK CASCADE、`thread_id` FK `companion_threads` CASCADE、`message_id` FK `companion_messages` **ON DELETE SET NULL**（弱链：删来源消息→候选存活、`message_id` 置 NULL）、`kind`（复用学习材料候选 5 值 CHECK）、`text`、`explanation_native`、`example_target`、`example_native`、`status`（CHECK 'candidate'）、`created_at`/`updated_at`。
  - **派生数据分类（plan §D4）**：与 `memory_candidates` 一致，**无 sync/backup/export 策略列**——评审暂存、可复算（删 thread CASCADE / 重算 = 显式重新提取），local-only。主数据边界在「升级为记忆条目」（`learner_memory_facts`，已进可恢复备份）。备份恢复一致性：恢复后 `companion_messages`（主数据）在、`companion_memory_candidates`（派生）不在，用户可对保留对话重新显式提取——与 `memory_candidates` 删材料后需重新分析一致，属可接受降级。
- **产出证据前向读接缝（交付物 B）**：`GRDBCompanionRepository.productionUtterances(spaceID:after:)` 只读既有 v30 列（`role='user'` 且行内 `detected_language == target_language_code`），**无新表、无迁移、无 ledger 常量、不改 band**；band 消费 = 后续演进片（备忘录 `docs/architecture/notes/2026-06-26-companion-reflux-production-signal-and-candidate-unification-notes.md`）。
- **隐私边界**：提取 = 用户显式触发重发已存对话（同「重新分析」），非系统自动注入；capability `companionExtraction` 仅含 `companionConversation` 类目，无新外发类目，请求预览显式披露。Memory 注入 = LM03-S2b。
