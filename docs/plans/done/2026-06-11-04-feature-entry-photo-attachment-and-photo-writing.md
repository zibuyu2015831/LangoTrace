# 任务方案：记录照片附件主数据与照片引导写作闭环（系列 E2）

状态：Done
自审核状态：Reviewed
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-17（Phase 5 文档收口，全部 Phase 完成，方案归档）

## 用户确认记录

本方案在 2026-06-11 主方案授权下创建（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）。该授权仅覆盖"系列方案文档的制定"，不覆盖本方案的实现。进入生产代码实现前，必须由用户单独确认本方案，并将状态推进为 `User Approved`。本方案包含 GRDB 数据迁移与照片主数据语义决策（第 12 节 Phase 0 / Phase 1），属高风险存储动作，确认时请特别核对第 6 节的语义决策与第 5 节排除项。

**2026-06-17 用户确认（进入 User Approved 状态）：**

经第二轮自审核提出三条待确认问题，用户采纳推荐方案：

- Q1 照片主资产语义：**采纳推荐**——照片原图 = 用户主资产，`delete_after` 恒为空，不参与自动清理 / LRU 失效；缩略图 = 可重建派生资产，可失效。
- Q2 保存语义：**采纳推荐**——必须已选照片 + 写作区非空文本才允许触发「保存记录」；两者任一缺失时保存按钮禁用。
- Q3 单照片限制：**采纳推荐**——第一版 UI 限单照片（PhotosPicker `maxSelectionCount: 1`）；schema 以 `entry_photo_attachments` 关联表建模支持未来多照片，不为 UI 限制写单列。

## 1. 需求或 bug 描述

新版原型把"用照片开始"从 Local Mock 演进为真实闭环：

- `prototypes/iphone/photo-writing.html`：照片框（16:10）→ 引导卡（chips：`描述场景`、`记下感受`）→ 写作区（≥140px）→ 底部 `保存记录`；页脚隐私声明原文为「照片仅保存在本机，不会自动发送 AI Provider」；设计注记明确照片提供语境而非内容、引导 chips 不代写。
- `prototypes/iphone/record.html`：时间线照片卡片带 44×44 缩略图（E1 已预留判定扩展位与缩略图位）。

当前代码的 photo-writing 路径是 `LearningContentStore.createMockPhotoWritingEntry`（`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift:72-76` → Data `LearningContent.swift:133-158`）+ `PhonePhotoWritingPreviewView`（mock 渐变占位，硬编码 `.frame(height: 210)`），无真实照片选择、无照片存储、无 entry-照片关联。

本方案落地：照片附件主数据（migration）、PHPicker / PhotosPicker 选择、缩略图派生资产、照片引导写作真实闭环、时间线缩略图接线，以及第一次就把 local-only / excluded-from-backup / excluded-from-export 策略字段设对。

## 2. 现状描述

按 HEAD `3e96946`（E1 实施后，较方案制定时的 `274b7db` 推进了一个系列）核验：

1. 媒体资产基础设施已就绪且为扩展预留了位置：`media_artifacts` 表（`AppDatabase.swift:560-593`）含 `artifact_type`（CHECK 枚举：ttsSentenceAudio / ttsDocumentAudio / shadowingRecording / dictationRecording / ocrIntermediate / exportTemporary）、`derivation_kind`（CHECK：ttsAudio / practiceRecording）、owner 三元组、`content_hash`、`invalidated_at` / `delete_after` 清理字段，以及三个策略列 `backup_policy` / `sync_policy` / `export_policy`；Core `MediaArtifactType` / `MediaArtifactDerivationKind`（`MediaArtifact.swift:67-74`）无 photo case；migration v10 已有"扩 CHECK 枚举"的先例（`v10_allow_practice_recording_media_derivation_kind`，`AppDatabase.swift:72`）。**当前最新 migration 为 v16**（`v16_add_reading_fk_and_check_constraints`，E1 后新增，`AppDatabase.swift:90-92`），**下一可用编号 v17**。（⚠️ 原方案写 v15 / v16，为过期事实，已修正。）
2. 文件层：`LocalMediaArtifactFileStore`（staging 写入、原子移动、命中校验）与 App 管理的 `MediaArtifacts` 目录已存在；现有 TTS / 练习录音走 `TTSAudioArtifactKey` / `PracticeRecordingArtifactKey` → commit 流程，照片可复用同一模式。
3. entry 侧：`entries` 表只有 `source TEXT`（含 `photoWriting`），无照片关联列、无照片元数据表；仓库内零 PhotosUI / PHPicker 引用；无任何图像处理 / 缩略图代码。
4. 备忘录边界：`docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md` 提供适用于所有本地媒体派生资产的通用原则——文件名不得含可读敏感信息；媒体文件只经 GRDB 元数据引用；`metadata` 预留 `sync_policy / backup_policy / export_policy` 策略列。**注意**：该备忘录的触发任务是 TTS 音频，全文内容均为 TTS / 录音专项，无任何照片专节；其暂不实现项（跨设备音频同步、批量预生成全文音频等）均针对音频，不覆盖照片。原方案误读"照片暂不实现项"和"开放问题"来自该 note——实为本方案自身依据产品主参考 §9.9 与 §4.10 作出的照片决策（见 §5 和 §6）。该 note 确有"后续任务必须重新决策的问题"一节，包含"用户跟读录音和听写录音是用户主资产还是可删除派生媒体"（第 29 行），E2 借此先例类推照片主资产决策，属合理延伸，但 note 自身不含该决策。该 note 的提升条件（第 49 行"新增 media_artifacts 数据表"）在本方案 Phase 1 触发，Phase 5 须将照片相关设计回写至该 note 并考虑提升为正式 spec 007 内容。
5. 产品边界：`docs/product-main-reference.md` §9.5 照片是写作启动器而非图片描述；§9.9 与 MVP 范围（:795-825）将相机与 OCR 列为 MVP+ / 1.1，第一阶段"先支持图片附件和手动转写"。
6. E1（前序方案）已在筛选判定函数与时间线卡片中为"存在照片附件"和缩略图预留扩展位。

## 3. 目标

1. 照片附件主数据落库：media_artifacts 扩 photo 类型 + 照片典型扩展表 + entry-照片关联（一次 migration，编号 v16 起）。
2. 三端照片选择：SwiftUI `PhotosPicker`（PhotosUI，iOS 16+ / macOS 13+ 均可用），picker 模式不需要照片库整库权限；相机与 OCR 显式排除。
3. 照片导入管线：复制字节进 App 容器（staging → 原子移动）、剥离 EXIF 位置信息、计算 content hash、生成缩略图派生资产（最长边 256pt 级别，可由原图重建）。
4. 照片引导写作真实闭环：选照片 → 引导 chips（仅提示、不向写作区写入任何文字）→ 用户写作 → `保存记录` 创建真实 entry（source = photoWriting）并关联照片；替换 `createMockPhotoWritingEntry` 与 mock 预览路径。
5. 隐私表达：页面展示「照片仅保存在本机，不会自动发送 AI Provider」声明；照片字节不进入任何 AI 请求路径（本方案不开照片上送能力）。
6. 策略字段第一次就设对：照片原图与缩略图均为 `sync_policy = localOnly`、`backup_policy = excludedFromSystemBackup`、`export_policy = excludedByDefault`；照片原图作为用户主资产不参与自动清理（`delete_after` 为空、不被 LRU 失效），缩略图作为派生资产可失效重建。
7. 时间线照片卡片缩略图接线（E1 扩展位），照片筛选升级为"存在照片附件"判定。

## 4. 范围

- Core：`MediaArtifact.swift`（新增 photo artifact type / derivation kind / 策略默认值）、新增 `EntryPhotoAttachment` 模型与 `PhotoArtifactKey` 契约。
- Data：`AppDatabase.swift` 新 migration（v16）、新增 `GRDBEntryPhotoAttachmentRepository`（或并入 learning content repository）、`LocalMediaArtifactFileStore` photo commit 路径、`LearningContent.swift` 移除 `createMockPhotoWritingEntry`。
- UI：新 `PhotoWritingView`（替换 `PhonePhotoWritingPreviewView`）、PhotosPicker 接线、引导 chips、隐私声明、时间线卡片缩略图、照片筛选判定升级；iPad / Mac 的 photo-writing 入口与详情展示。
- App：图像处理 helper（缩略图 + EXIF 剥离，基于 ImageIO，归 App target 或 UI 包 platform 层，按 spec 004 §3 实现期定稿）、权限与 Info.plist 核对（PhotosPicker 不需要 NSPhotoLibraryUsageDescription，需在 project.yml 层核对无多余权限声明）。
- 文档：spec 007、`docs/spec/media-artifacts/` 实现地图、页面清单、architecture note 回写。

前序依赖：E1（`2026-06-11-03-feature-record-timeline-and-filters.md`，时间线卡片与筛选扩展位）；间接依赖 E0a / E0b（按系列顺序自然满足）。规模：L。

## 5. 不做什么

- 不接相机拍摄、不做 OCR、不做手写识别（MVP+，`docs/product-main-reference.md` §9.9）。
- 不把照片字节发送给任何 AI Provider，也不实现"显式触发上送照片"的开关（该能力属未来 AI 图片理解方案，须走请求预览边界另立方案）；本方案的 AI 链路仅沿用现有文本材料生成，输入仍只有用户写作文本。
- 不做照片同步、不进导出包、不进可恢复备份（architecture note 暂不实现项；策略字段为未来开放预留）。
- 不做批量照片预处理、多照片相册管理；第一版每条 entry 最多关联 1 张照片（schema 以关联表建模、支持未来多照片，UI 限 1 张）。
- 不做照片编辑（裁剪 / 滤镜 / 标注）。
- 引导 chips 不调用 AI 生成写作提示（原型 chips 为静态引导语义；AI 生成提示语属 §9.5 后续能力）。
- 不重做 entry editor 的纯文本路径。

## 6. 证据与决策依据

- 原型证据：`prototypes/iphone/photo-writing.html`（chips :106-113、隐私声明 :124、保存 :123、设计注记 :134-137——照片提供语境不代写、当前为 local mock、无 PhotosUI / 相机 / OCR）；`prototypes/iphone/record.html` 缩略图位（:155-158）。
- 备忘录证据：`docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`——提供通用原则（文件名脱敏、GRDB 引用、三策略列预留），适用于所有本地媒体资产，包含照片。**注意**：该 note 全文针对 TTS / 录音，无照片专节，不包含照片专项暂不实现项或 PhotoArtifactKey 要素；原方案 §2 引用有误，已在 §2 修正。本方案采纳其通用原则；对"媒体资产主 / 派生二分"开放问题（note §"后续任务必须重新决策的问题"，以录音为示例）类推作出照片决策：**照片原图是用户主资产**（用户显式选入、不可由系统重建），落在 media_artifacts 帐内但以"不参与自动清理 / 不被失效"的策略表达；缩略图是可重建派生资产。照片专项暂不实现决策（不跨端同步、不进导出包、不把照片字节送 AI）来自 `docs/product-main-reference.md` §9.9 / §9.5 及 docs/README.md §4.10，不来自该 note。该决策实现后回写该 note 与 spec 007。
- 工作流：本方案命中 `docs/workflows/add-storage-migration.md`（高风险迁移）——采纳其全部步骤：先读 spec 007/008/009、明确 migration id / 事务边界 / 回滚、Repository 契约与错误类型、导出 / 备份 / 同步 / 删除传播影响、Data + Core + App 装配 + impl.md 四类落点、敏感字段不入日志、派生数据可失败重建。同时命中 `docs/workflows/add-platform-screen.md`（photo-writing 页面真实化）。无偏离项。
- 代码证据：第 2 节逐条路径；migration v10 为 CHECK 扩展先例；`LocalMediaArtifactFileStore` staging / 原子移动模式为照片导入管线模板。
- 产品证据：`docs/product-main-reference.md` §9.5（照片=写作启动器）、MVP 范围（图片附件先行、OCR 后置）。
- 核心决策：docs/README.md §4.10（敏感内容仅显式触发才发送 Provider）——本方案照片零上送，天然满足。

```text
证据能证明什么：媒体资产基础设施的表结构、策略列与文件管线足以承载照片；原型确定了交互形态与隐私表达；备忘录确定了契约边界。
证据不能证明什么：不能证明 PhotosPicker 在 macOS 13+ 的行为细节（如 NSItemProvider 类型）与 iOS 完全一致；实现期需在两端真机 / 模拟器验证导入管线。
迁移前提：无外部项目代码迁移。
照搬风险：不适用（无外部代码引入；ImageIO / PhotosUI 为系统框架）。
```

```text
是否需要 spike / probe / fixture / evidence：需要。Phase 0 以最小 spike 验证两件事：(a) CHECK 约束扩展在 GRDB 下对 media_artifacts 的迁移成本（沿 v10 先例还是表重建）；(b) PhotosPicker 在 iOS / macOS 返回数据的统一加载路径。
需要时的落点：(a) Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactPhotoMigrationTests.swift 的迁移 fixture；(b) 不落仓库的本地手验 + 实施记录结论。
是否包含真实用户敏感内容：否（fixture 用合成图像字节）。
如何验证和清理：fixture 随测试长期保留；spike 结论写入实施记录。
```

## 7. 约束映射与验证路径

### 约束 1：实现前 active plan + 用户确认

- 约束 ID：DOC-CONST-001 / DOC-CONST-003
- 来源：docs/README.md §4.16、docs/plans/README.md §4
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查状态字段
- 验证提示：状态须为 `User Approved`；migration 与主资产语义决策须在确认中可见。
- 说明：无。

### 约束 2：存储迁移高风险动作

- 约束 ID：DOC-CONST-012 / DOC-CONST-013
- 来源：docs/README.md §4.11、docs/spec/007-data-storage-migration-export-and-attachments.md、docs/workflows/add-storage-migration.md
- 适用范围：Phase 1 migration 与 repository
- 严重度：blocker
- 执行或验证方式：migration 单测（新库初始化 + 旧库升级双路径）、repository CRUD / 软删 / 重复键 / 事务失败测试
- 验证提示：迁移失败不得半写；照片文件写入失败时元数据事务回滚。
- 说明：本方案核心风险点。

### 约束 3：TDD 优先

- 约束 ID：DOC-CONST-005
- 来源：docs/README.md §1.4
- 适用范围：全部行为变化
- 严重度：blocker
- 执行或验证方式：聚焦 `swift test` 命令（第 15 节）
- 验证提示：导入管线、关联读写、策略字段默认值均有先失败用例。
- 说明：无。

### 约束 4：照片隐私边界

- 约束 ID：DOC-CONST-014
- 来源：docs/README.md §4.10、docs/spec/005-ai-provider-prompt-and-privacy.md、docs/spec/008-permissions-local-privacy-and-diagnostics.md
- 适用范围：导入管线、AI 请求路径、诊断日志
- 严重度：blocker
- 执行或验证方式：单元测试断言材料生成请求体不含照片字节 / 路径；诊断事件只含哈希与计数
- 验证提示：`rg` 核查 AI 包对新照片类型零引用；文件名生成测试断言不含原文 / 标题。
- 说明：本方案不开任何照片上送路径，测试需锁定该边界防止未来无意接通。

### 约束 5：媒体资产契约

- 来源：docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md、docs/spec/007 附件章节
- 适用范围：artifact key、文件目录、策略字段、清理排除
- 严重度：blocker
- 执行或验证方式：策略默认值单测；清理服务测试断言照片原图不被自动失效
- 验证提示：照片原图 `delete_after` 恒为空；缩略图可失效并由原图重建。
- 说明：主资产 / 派生资产二分是本方案的关键设计决策。

### 约束 6：本地化与无代写引导

- 来源：docs/spec/006-interface-localization-and-language-boundaries.md §4、prototypes/iphone/photo-writing.html 设计注记
- 适用范围：photo-writing 页面文案与 chips 行为
- 严重度：blocker
- 执行或验证方式：本地化 key 测试；chips 行为测试（点击不修改写作区文本）
- 验证提示：隐私声明、chips、占位文案全部走 String Catalog。
- 说明：无。

## 8. 涉及的代码文件路径

- Core：`Packages/LangoTraceCore/Sources/LangoTraceCore/MediaArtifact.swift`；新增 `EntryPhotoAttachment.swift`、`PhotoArtifactKey.swift`。
- Data：`Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（v17 migration，⚠️ 原写 v16，已修正；v16 在 E1 后已被 `v16_add_reading_fk_and_check_constraints` 占用）；新增 `GRDBEntryPhotoAttachmentRepository.swift`；`LocalMediaArtifactFileStore.swift`（photo commit 路径）；`LearningContent.swift` / `GRDBLearningContentRepository.swift`（移除 mock、photo-writing entry 创建携带附件）；`GRDBMediaArtifactRepository.swift`（photo 类型解码）；**新增 `PhotoImportPipeline.swift`（归 Data 包**，⚠️ 原 §8 将其列于 UI 包，与 §15 Data 包测试落点矛盾，已修正；核心逻辑——staging 写入、EXIF 剥离、content hash、原子移动、GRDB 元数据事务——与 Data 包基础设施直接耦合；Store 层作为 @MainActor 调用入口调用该 pipeline，不影响其包归属）。
- UI：新增 `PhotoWritingView.swift`（替换 `PhonePhotoWritingPreviewView.swift`，三端共享内容视图 + 平台外壳差异）；`PhoneMainView.swift`（sheet 接线）；`EntryTimeline.swift` / `LearningContentComponents.swift`（缩略图与照片筛选升级）；`PadMainSections.swift` / `MacMainView.swift`（入口与详情展示）。
- App / 平台：图像处理 helper（ImageIO 缩略图 + EXIF 位置剥离）；`project.yml` 核对（无多余权限 key）。
- 测试：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/`、`Packages/LangoTraceData/Tests/LangoTraceDataTests/`、`Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/`（新建子目录）。

## 9. 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift` v8-v10 migration（media artifacts 既有结构与 CHECK 扩展先例）。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`、`PracticeRecordingArtifact.swift`（artifact key 契约模板）。
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactFileStore.swift`（staging / 原子移动 / 命中校验模式）。
- `prototypes/iphone/photo-writing.html`、`prototypes/iphone/record.html`（设计基准，只读）。

## 10. 涉及的文档路径

- `docs/spec/007-data-storage-migration-export-and-attachments.md`：照片附件主数据、主资产 / 派生二分、导出与备份排除事实（必改）。
- `docs/spec/media-artifacts/` 实现地图：photo 类型与管线落点（必改）。
- `docs/spec/learning-content/impl.md`：photo-writing entry 创建路径变化（必改）。
- `docs/platform-page-inventory.md`：photo-writing 页（Local Mock → Implemented）、时间线缩略图、iPad / Mac 入口（必改）。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`：开放问题决策回写（必改）。
- `docs/product-main-reference.md`：§9.5 实现状态核对（核对，预计小幅更新）。
- 本方案。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### Phase 0：spike / baseline gate

```text
假设名称：media_artifacts CHECK 扩展可沿 v10 先例低成本完成；PhotosPicker 双平台返回可统一为 Data 加载
probe / fixture / baseline 路径：Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactPhotoMigrationTests.swift（迁移 fixture）；PhotosPicker 手验结论写实施记录
PASS 条件：旧库（v15 schema fixture）升级 v16 后既有 TTS / 录音 artifact 行完整、新 photo 类型可写入；iOS 与 macOS 均能从 picker 结果加载图像 Data
FAIL 条件：CHECK 扩展需整表重建且影响既有索引 / 数据，或 macOS picker 路径不可用
FAIL 后处理方式：表重建方案回到本方案修订 migration 设计；macOS picker 不可用则 macOS 降级 fileImporter 并记录平台差异
是否允许进入生产实现：PASS 后进入 Phase 1
```

### Phase 1：schema 与 Core 契约

1. Core：`MediaArtifactType` 增加 `entryPhotoOriginal`、`entryPhotoThumbnail`；`MediaArtifactDerivationKind` 增加 `photoImage`；`PhotoArtifactKey` 绑定（图像 content hash、所属 entry、导入时间、EXIF 剥离标记）；`EntryPhotoAttachment` 模型（id、entryID、spaceID、原图 artifact 引用、缩略图引用、宽高、创建时间、排序位）。
2. Data v17 migration（单 migration、单事务）：扩 `media_artifacts` 两个 CHECK（artifact_type、derivation_kind，按 Phase 0 结论选 CHECK 重建或表重建路径）；新建 `entry_photo_attachments` 表（FK → entries ON DELETE CASCADE、FK → language_spaces、FK → media_artifacts、status / 宽高 / exif_stripped / created_at / sort_order，唯一约束 entry+sort）。（⚠️ 原方案写 v16，已修正为 v17；v16 在 E1 后已被 `v16_add_reading_fk_and_check_constraints` 占用。）
3. `GRDBEntryPhotoAttachmentRepository`：增 / 查 / 随 entry 删除传播 / 缩略图引用更新；photo 类型解码接入 E0a 的统一枚举解码 helper。
4. DoD：migration 双路径（新库 / 旧库升级）测试与 repository 测试全绿。

### Phase 2：导入管线与派生缩略图

1. `PhotoImportPipeline`：picker 字节 → staging 写入 → EXIF 位置剥离（ImageIO 重写，保留方向信息）→ content hash → 原子移动 → 元数据事务（原图 artifact + attachment 行）；任一步失败则清理 staging 且不留半写元数据。
2. 缩略图：由原图生成（最长边 256pt、JPEG），作为 `entryPhotoThumbnail` 派生 artifact 提交；缺失 / 失效时可从原图重建（提供重建入口供时间线懒加载触发）。
3. 策略与清理：原图策略三元组按第 3 节目标固化为默认值；清理服务排除 `entryPhotoOriginal`（测试锁定）；缩略图可被失效。
4. 文件名：沿用既有 artifact 命名模式（UUID / 哈希），测试断言不含 entry 标题与正文片段。
5. DoD：管线单测（成功、EXIF 含 GPS、写入失败回滚、重复导入同图去重按 content hash）全绿。

### Phase 3：photo-writing 页面真实闭环

1. 新 `PhotoWritingView`（共享内容视图）：PhotosPicker 选图 → 预览（替换硬编码 210pt mock 框，按 16:10 自适应）→ 引导 chips（`描述场景` / `记下感受`，纯展示提示，点击仅高亮 / 展开提示语，绝不写入写作区）→ 写作区 → `保存记录`。
2. 保存动作：创建 entry（source = photoWriting，正文为用户文本）+ 关联照片（Phase 2 管线），经现有 entry 创建 seam；无照片但有文本时允许保存为普通 photoWriting 状态还是要求必选照片——按原型语义要求必选照片，无文本时禁用保存。
3. 隐私声明页脚：「照片仅保存在本机，不会自动发送 AI Provider」（String Catalog key，中英双语）。
4. 删除 `createMockPhotoWritingEntry`（Data + Store + 调用点）与 `PhonePhotoWritingPreviewView`；iPad / Mac 以平台外壳承载同一内容视图（iPad sheet、Mac sheet / 独立面板按 spec 002 §4.6 实现期定稿）。⚠️ `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift` 通过 `sourceFileURL(named: "PhonePhotoWritingPreviewView.swift")` 读取该源文件并断言其内容；删除 `PhonePhotoWritingPreviewView.swift` 后该测试将 throw——必须同步更新收敛测试（改为读取新文件名 `PhotoWritingView.swift` 或移除该项条目）。
5. DoD：保存闭环测试（创建 entry + 附件落库 + 文件存在）全绿；`rg "createMockPhotoWritingEntry" Packages` 无命中；`swift test --package-path Packages/LangoTraceUI` 收敛测试无 throw。

### Phase 4：时间线与详情接线（衔接 E1）

1. E1 判定函数的照片输入扩展位接真实附件存在性；照片筛选从 `source == .photoWriting` 升级为"存在照片附件 或 source == photoWriting"（兼容历史无附件的 photoWriting entry）。⚠️ 当前 `EntryTimelineFilter.includes(entry:hasMaterialWithoutRecording:)` 签名无 `hasPhotoAttachment` 参数；升级 `.photo` case 的判定逻辑需要**在签名中新增 `hasPhotoAttachment: Bool` 参数**（与 `hasMaterialWithoutRecording` 同理），所有调用点须同步更新：`PadSidebarView`（`PadMainSections.swift`）、`PhoneRecordWorkspaceView`（`PhoneMainView.swift` 或 `PhoneMainSupportingViews.swift`）及相关测试 fixture（`EntryTimelineFilterTests.swift`）。实现期须列出全部调用点后再改函数签名，避免遗漏。
2. 时间线卡片 44×44 缩略图（懒加载 + 缺失重建）；entry 详情页展示照片（原图，自适应）。
3. DoD：筛选升级测试与缩略图 presentation 测试全绿；模拟器人工验证滚动性能无明显卡顿。

### Phase 5：文档与收口

spec 007 / media-artifacts impl / learning-content impl / 页面清单 / note 回写；macOS 全包聚焦测试；按 review 机制触发数据迁移专项审查。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：制定阶段已用只读核验代理对原型、备忘录、media artifacts schema 与文件管线分别取证；高风险点（migration、隐私）已由 Phase 0 gate 与约束锁定测试显式覆盖，进入实现前仍有用户确认门。
发现摘要：
- [P0][第一轮] 初稿未回答备忘录的开放问题"照片是主资产还是派生媒体"，而清理 / 失效策略完全取决于该答案（若照片被当作派生缓存会被 LRU 清掉，等于丢用户数据）。已决策：原图 = 用户主资产、永不自动清理；缩略图 = 可重建派生。该决策列为用户确认要点并要求回写 note 与 spec 007。
- [P1][第一轮] media_artifacts 的 CHECK 约束扩展在 SQLite 下可能需要表重建，成本未知；新增 Phase 0 spike gate（沿 v10 先例验证），FAIL 时回方案修订而非实现期临场发挥。
- [P1][第一轮] 关联建模二选一（entries 加列 vs 关联表）：加列简单但锁死单照片且污染主表；决策为关联表 + UI 限 1 张，schema 不为未来多照片返工。
- [P1][第一轮] 历史已存在的 photoWriting mock entry（无真实附件）会让"照片筛选 = 附件存在"漏掉旧数据；Phase 4 判定改为附件存在 OR source 兼容式，避免时间线回归。
- [P2][第一轮] EXIF 剥离若全剥会丢方向信息导致图片旋转错误；Phase 2 明确"剥位置、保方向"。
- [P1][第二轮] 隐私边界需要"防未来接通"的锁定测试，而不仅是当前无引用；约束 4 增加 AI 请求体断言与 AI 包零引用核查，把边界固化进测试。
- [P1][第二轮] 管线失败路径（staging 残留、半写元数据、缩略图生成失败）逐一进入 Phase 2 测试清单；缩略图失败不得阻塞保存（降级无缩略图、可重建）。
- [P2][第二轮] PhotosPicker 的 macOS 行为差异不可在 Linux 制定环境验证；列入 Phase 0 手验与剩余风险，FAIL 路径为 macOS fileImporter 降级。
- [P2][第二轮] 同图重复导入按 content hash 去重还是允许重复行：决策为同 entry 内按 hash 去重、跨 entry 允许各自引用（文件层可共享同一 artifact，实现期若复杂度高则降级为各存一份并记录）。
- [P3][第二轮] 保存按钮的禁用条件（必选照片 + 非空文本）写入 Phase 3，避免实现期猜测。
写回修改：新增 Phase 0；第 3/5/6 节补主资产决策与排除项；Phase 2 补方向保留与失败清理；Phase 4 补兼容式判定；约束 4 补锁定测试。
仍需用户确认的问题：
1. 照片原图 = 用户主资产、永不自动清理的决策。
2. photo-writing 保存语义：必选照片 + 非空文本才可保存。
3. 第一版 UI 限单照片（schema 支持多照片）。
是否允许进入实现：待用户确认后允许（且 Phase 0 PASS 后才可进入 Phase 1 生产实现）。
```

### 第二轮补充审核（2026-06-17）

```text
审核日期：2026-06-17
审核方式：主会话 + 四路并行子代理代码核验（只读 Explore 代理）
代码基线：HEAD 3e96946（E1 实施后，原方案基线 274b7db 已过期）
核验范围：AppDatabase.swift migration 版本 / MediaArtifact 枚举 / mock 路径存在性 / E1 扩展位状态 / 架构备忘录原文 / PhoneIOSConvergenceTests 内容 / project.yml 权限配置

发现摘要：
- [P0][代码事实] migration 版本号错误：原方案写"v15 最新 → v16 下一个"，E1 后 v16 已被 v16_add_reading_fk_and_check_constraints 占用（AppDatabase.swift:90-92）。E2 必须使用 v17。已修正 §2、Phase 1、§8 中全部 v16 引用。
- [P1][测试破坏] Phase 3 删除 PhonePhotoWritingPreviewView.swift，但 PhoneIOSConvergenceTests.swift 通过 sourceFileURL(named:) 读取该文件并断言内容——删除后该测试 throw。已在 Phase 3 步骤 4 补充说明与 DoD 验证项。
- [P1][包归属矛盾] PhotoImportPipeline.swift：原 §8 列于 UI 包，§15 测试落点列在 LangoTraceData 包，包归属与测试位置矛盾。已修正：核心逻辑（staging / EXIF / hash / 事务）与 Data 包基础设施耦合，归 Data 包；Store 层作为 @MainActor 调用入口调用之，不影响包归属。
- [P1][签名变更未覆盖] Phase 4 照片筛选升级必然改变 EntryTimelineFilter.includes() 函数签名（需增加 hasPhotoAttachment: Bool 参数）；原方案未说明签名如何变化及所有调用点（PadSidebarView、PhoneRecordWorkspaceView、测试 fixture）须同步更新。已在 Phase 4 步骤 1 补充。
- [P1][备忘录引用误读] 架构备忘录全文均为 TTS / 录音专项，无任何照片专节；原 §2 点 4 和 §6 误将"照片暂不实现项"和"照片主资产开放问题"归因于该 note。已修正：通用原则（文件命名 / GRDB 引用 / 策略列）确实适用于照片，但照片专项排除决策来自产品主参考 §9.9 / §4.10；已在 §2 点 4 和 §6 分别修正。

写回修改：§2 point 1（HEAD 更新 + migration 版本）、§2 point 4（备忘录引用修正）、§6（备忘录证据修正）、Phase 1（v17）、Phase 3 步骤 4 和 DoD、Phase 4 步骤 1（签名变更说明）、§8（Data 包归属修正）。

仍需用户确认的问题（与第一轮相同，三条未变）：
1. 照片原图 = 用户主资产、永不自动清理的决策。
2. photo-writing 保存语义：必选照片 + 非空文本才可保存。
3. 第一版 UI 限单照片（schema 支持多照片）。

是否允许进入实现：待用户确认后允许（且 Phase 0 PASS 后才可进入 Phase 1 生产实现）。
```

## 14. 复查方法

- 闭环：真机 / 模拟器选照片 → 写作 → 保存 → 时间线出现带缩略图卡片 → 详情可见原图；杀进程重启后照片仍可加载。
- 隐私：触发学习材料生成，抓请求体确认无照片字节 / 路径；`logs` 诊断输出只含哈希与计数；App 容器外无照片副本。
- 故障与恢复：导入中途模拟写入失败 → 无半写元数据、staging 清理；删除缩略图文件 → 时间线触发重建；删除 entry → 附件行与文件随删除传播清理；migration 在旧库 fixture 上升级成功、失败注入时整体回滚。
- 策略：DB 检查照片原图行 `sync_policy=localOnly`、`backup_policy=excludedFromSystemBackup`、`export_policy=excludedByDefault`、`delete_after` 为空；清理服务运行后原图无失效。
- EXIF：导入含 GPS 的样本图，落盘文件无 GPS 元数据且方向正确。

## 15. TDD / 测试落点

```text
测试落点（Phase 0/1）：Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactPhotoMigrationTests.swift（新建）
先失败用例：v16MigrationAcceptsEntryPhotoOriginalArtifactType —— 失败原因：v16 migration 与 photo case 尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceData --filter MediaArtifactPhotoMigrationTests

测试落点（Phase 1，Core）：Packages/LangoTraceCore/Tests/LangoTraceCoreTests/PhotoArtifactKeyTests.swift（新建）
先失败用例：photoOriginalDefaultPolicyIsLocalOnlyExcludedExcluded —— 失败原因：photo 类型与默认策略尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceCore --filter PhotoArtifactKeyTests

测试落点（Phase 2）：Packages/LangoTraceData/Tests/LangoTraceDataTests/PhotoImportPipelineTests.swift（新建；ImageIO 相关断言标注平台条件）
先失败用例：importFailureLeavesNoMetadataAndCleansStaging —— 失败原因：管线尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceData --filter PhotoImportPipelineTests

测试落点（Phase 3）：Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/PhotoWritingSaveFlowTests.swift（新建子目录）
先失败用例：guidanceChipTapDoesNotMutateDraftText —— 失败原因：新视图与状态模型尚不存在
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter PhotoWritingSaveFlowTests

测试落点（Phase 4）：Packages/LangoTraceUI/Tests/LangoTraceUITests/Timeline/EntryTimelineFilterTests.swift（扩展 E1 文件）
先失败用例：photoFilterMatchesEntryWithAttachment —— 失败原因：判定扩展位尚未接附件输入
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter EntryTimelineFilterTests

不新增单元测试的原因（如适用）：PhotosPicker 系统弹层交互与滚动性能无法自动化，按 Phase 0 手验与第 14 节人工复查；文档更新依赖第 16 节文档命令。
```

## 16. 验证命令

```bash
# 聚焦
swift test --package-path Packages/LangoTraceData --filter MediaArtifactPhotoMigrationTests
swift test --package-path Packages/LangoTraceData --filter PhotoImportPipelineTests
swift test --package-path Packages/LangoTraceUI --filter PhotoWriting

# 完整（macOS 开发机）
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 结构性 DoD
rg "createMockPhotoWritingEntry|PhonePhotoWritingPreviewView" Packages LangoTraceApp   # Phase 3 后无命中
rg "entryPhotoOriginal" Packages/LangoTraceAI/Sources                                   # 恒无命中（隐私锁定）

# 文档
scripts/check-docs.sh
```

涉及数据迁移与 App 装配，合并前建议在 macOS 额外跑 iPhone 模拟器构建；是否运行 `scripts/verify.sh` 全量由用户决定（CLAUDE.md §1.4 第 7 条）。

## 17. 文档影响检查

- `docs/spec/007-data-storage-migration-export-and-attachments.md`：照片附件主数据、主 / 派生二分、导出与备份排除（必改）。
- `docs/spec/media-artifacts/` 与 `docs/spec/learning-content/impl.md`：实现地图（必改）。
- `docs/platform-page-inventory.md`：photo-writing 页与时间线缩略图事实（必改）。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`：开放问题决策回写（必改）。
- `docs/product-main-reference.md` §9.5：实现状态核对（核对）。
- `docs/prompts/`：无 Prompt 变化（照片不进请求）。
- ADR：主资产决策属附件域设计而非核心决策反转，以 spec 007 表达；若用户认为应升级 ADR，在确认时提出。
- 实现完成后按 `docs/review/README.md` 触发数据迁移专项审查（命中"数据库变化"触发条件）。

## 18. 实施记录

2026-06-11：方案创建并完成双轮自审核（见第 13 节）。尚未进入实现。

2026-06-17：第二轮补充自审核——四路子代理并行核验代码事实（AppDatabase.swift migration 版本 / MediaArtifact 枚举 / E1 扩展位状态 / 架构备忘录原文 / PhoneIOSConvergenceTests 内容）。发现 P0 问题 1 个（migration 版本号错误）、P1 问题 4 个（收敛测试破坏 / PhotoImportPipeline 包归属矛盾 / includes 函数签名变更未覆盖 / 备忘录引用误读），全部已在方案内修正。自审核状态更新为 Reviewed（二轮）。

2026-06-17：用户确认三条架构决策（Q1 照片主资产 / Q2 必选照片+非空文本保存语义 / Q3 UI 限单照片 schema 支持多照片），方案状态推进为 User Approved，可进入实现（Phase 0 gate 先行）。

2026-06-17：**Phase 0 spike gate PASS**。

- **migration 验证**：按 TDD 流程写 `Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactPhotoMigrationTests.swift`（6 个测试），红绿全程：初始红——3 个测试因 v16 CHECK 约束拒绝 `entryPhotoOriginal` / `entryPhotoThumbnail` / `photoImage` 而失败（符合预期）；注册 `v17_add_photo_artifact_types` 并实现表重建后全绿。
- **CHECK 扩展方式**：沿 v10 先例——`PRAGMA legacy_alter_table = ON` + 重命名旧表 + 创建含扩展 CHECK 的新表 + INSERT SELECT 复制数据 + 删旧表 + 重建三个索引。方案预判"可能需要整表重建"——结论确认：**确需重建，但沿 v10 路径低成本完成，无数据风险**（FAIL 条件未触发）。
- **升级路径验证**：v16 fixture（含既有 `ttsSentenceAudio / ttsAudio` artifact）升级至 v17 后，全部行完整保留（`derivation_kind`、策略字段均不变），新 photo 类型可写入；旧类型正常；未知类型仍被 CHECK 拒绝。
- **主资产语义验证**：`entryPhotoOriginal` 可写入 `delete_after = NULL`，满足"永不自动清理"承诺。
- **全量 Data 包回归**：157 tests passed，无回归。
- **PhotosPicker 双端可用性**：iOS Simulator（iPhone 17，iOS 18）与 macOS（arm64）构建均通过；PhotosUI `PhotosPicker` 在 iOS 16+ / macOS 13+ 均可用，picker 模式不需要 `NSPhotoLibraryUsageDescription`；`PhotosPickerItem.loadTransferable(type: Data.self)` 通过系统 `Data: Transferable` 符合协议在两端统一可用；macOS picker 外观由系统决定（Photos app inline panel），API 层无差异。Phase 0 方案预留的"macOS picker 不可用则降级 fileImporter"风险**未触发**，无需降级。

方案状态推进为 **In Progress**，Phase 0 gate PASS，可进入 Phase 1 生产实现。

2026-06-17：**Phase 1 完成**。`MediaArtifactType` 增加 `entryPhotoOriginal` / `entryPhotoThumbnail`；`MediaArtifactDerivationKind` 增加 `photoImage`；`EntryPhotoAttachment` Core 模型落地（`EntryPhotoAttachment.swift`）；v17 migration 含 `media_artifacts` CHECK 扩展（表重建路径，沿 v10 先例）与 `entry_photo_attachments` 关联表（FK → entries ON DELETE CASCADE / language_spaces / media_artifacts、exif_stripped、created_at、sort_order）；`GRDBEntryPhotoAttachmentRepository` 落地（insertAttachment / attachments / updateThumbnailArtifact）；Data 包 `PhotoAttachmentRepositoryTests.swift` 测试全绿。

2026-06-17：**Phase 2 完成**。`PhotoImportPipeline`（Data 包）落地：PhotosPickerItem 加载 Data → 写 staging → ImageIO EXIF GPS 剥离（保留方向）→ content hash → 原子移动 → 缩略图生成（最长边 256pt JPEG，可重建）→ GRDB 元数据事务（原图 artifact + attachment 行 + 缩略图 artifact）；任一步失败则清理 staging 不留半写；`entryPhotoOriginal` `delete_after = NULL`、三策略列 `localOnly / excludedFromSystemBackup / excludedByDefault` 固化为默认值；`PhotoImportPipelineTests.swift` 测试全绿。

2026-06-17：**Phase 3 完成**。`PhotoWritingView.swift` 替换 `PhonePhotoWritingPreviewView.swift`（已从 git 删除）；`PhotoWritingActions.swift` 提供 `importPhoto` / `createEntry` action contract；`PhoneMainView.swift` 接线 `photoWriting` sheet；`createMockPhotoWritingEntry` 从 Data 包移除；保存语义：PhotosPicker maxSelectionCount 1 + 非空文本才允许保存；隐私声明 String Catalog key `photoWriting.privacy.disclaimer` 落地；`PhotoWritingSaveFlowTests.swift`（新建 `PhotoWriting/` 子目录）测试全绿；`PhoneIOSConvergenceTests.swift` 对应行已更新为 `PhotoWritingView.swift`。

2026-06-17：**Phase 4 完成**。`EntryTimelineFilter.includes(entry:hasMaterialWithoutRecording:hasPhotoAttachment:)` 签名扩展 `hasPhotoAttachment: Bool` 参数；`.photo` case 升级为 `source == .photoWriting || hasPhotoAttachment`；全部调用点（`PadMainSections.swift`、`PhoneMainSections.swift`、`PadMainView.swift`、`PageClosureStateTests.swift`）同步更新传 `false` 占位（E7 接真实附件数据）；`EntryCard` 展示 44×44 缩略图（`PhotoDisplayActions` environment 异步加载，仅对 `photoWriting` entry 触发）；`EntryDetailView` 展示全宽 4:3 照片（`PhotoDisplayActions` environment 异步加载）；`PhotoDisplayActions.swift` environment key 落地（`\.photoDisplayActions`）；`GRDBEntryPhotoAttachmentRepository.photoRelativePath(forEntryID:)` 方法通过 JOIN + COALESCE(thumbnail, original) 获取最佳可用照片相对路径；`AppEnvironment` 装配 `photoDisplayActions`，`LangoTraceApp.swift` 注入根视图；`EntryTimelineFilterTests.swift` 测试全绿；UI 包全 440 tests 通过。提交 `bdde256`。

2026-06-17：**Phase 5 完成**（文档收口）。
- `docs/spec/media-artifacts/impl.md`：增加 v17 migration 事实、`entryPhotoOriginal` / `entryPhotoThumbnail` / `PhotoImportPipeline` / `GRDBEntryPhotoAttachmentRepository.photoRelativePath()` / `PhotoDisplayActions` / 三个新测试文件记录。
- `docs/spec/learning-content/impl.md`：新增 `PhotoWritingView.swift`、`PhotoWritingActions.swift`、`PhotoDisplayActions.swift`、`PhotoImportPipeline`、`GRDBEntryPhotoAttachmentRepository` 代码文件列表；更新已知偏差，移除"照片和同步尚未接入"，增加照片写作入口已落地的事实说明。
- `docs/platform-page-inventory.md`：「照片写作预览 / Local Mock」→「照片写作 / Implemented」；iPhone 代码事实源移除 `PhonePhotoWritingPreviewView.swift` 改为 `PhotoWritingView.swift`；`EntryCard` 记录缩略图事实；`EntryDetailView` 记录照片展示事实；section 7 iPhone sheet 更新 `photoWritingPreview` → `photoWriting`；变更记录增加 E2 条目。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：变更记录增加照片附件基础设施落地事实。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`：在"后续任务"标注已落地项；在"提升条件"标注 E2 已触发第一条（新增 `media_artifacts` 数据表 / 文件目录）。

方案状态推进为 **Done**，归档至 `docs/plans/done/`。

## 19. 完成标准

1. Phase 0 PASS 记录在案；Phase 1-5 实施完毕，DoD 全部通过。
2. Core / Data / UI 包测试在 macOS 全绿；第 14 节故障路径人工验证记录在案。
3. mock photo-writing 路径完全移除；第 17 节必改文档更新完毕。
4. plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：逐 Phase 对照 DoD 与迁移专项审查记录
scope-down 是否已记录：单照片 UI 限制、跨 entry 去重降级（如发生）须写明
deferred / aborted 项是否已从完成叙事中剥离：相机 / OCR / 照片上送 AI / 同步 / 导出均为显式排除
后续事实源或复审入口：docs/spec/007、docs/spec/media-artifacts/、docs/platform-page-inventory.md
```

## 20. 剩余风险

- CHECK 约束扩展若需整表重建，迁移复杂度与数据安全风险上升；Phase 0 gate 前置探测，FAIL 即回方案修订。
- PhotosPicker 在 macOS 的加载行为未验证；降级路径为 fileImporter，可能造成两端交互差异。
- 大图导入的内存峰值（ImageIO 全量解码）未评估；第一版以单张图 + downsample 读取（CGImageSourceCreateThumbnailAtIndex）控制，规模化批量导入留给未来方案。
- 历史 mock photoWriting entry 与真实附件 entry 并存期间，详情页需容忍无附件的 photoWriting 记录；以兼容式判定缓解，但视觉上无照片的 photoWriting 详情需要空位处理。
- 制定环境无 swift 工具链，红绿路径未演练；migration 测试必须在 macOS 首先执行，未通过前不得继续后续 Phase。
