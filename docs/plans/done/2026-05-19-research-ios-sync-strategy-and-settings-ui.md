# 任务方案：iOS 同步策略与同步设置 UI 设计

状态：Verified
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

- 2026-05-19：用户提出希望先优化 iOS 端“同步”设置界面，并讨论是否以 S3 配置作为多端同步方案。当前确认范围：先完成市场调研、产品/架构判断和真实级 UI 设计方案记录；暂不进入代码实现、CloudKit entitlement 配置、真实网络请求、Keychain 写入、同步引擎或对象存储接入。
- 2026-05-19：用户确认“创建一个方案文档，将讨论结果记录下来，内容需要详尽，包括但不限于决策依据、实施方案、参考来源等”。
- 2026-05-19：用户要求对方案中尚需确认的 UI 和产品取舍，由系统架构师视角基于项目定位、愿景和当前实现直接采纳最优推荐方案并更新文档。
- 2026-05-19：用户要求完整阅读本方案并开始实施，直到完整落地。执行范围按阶段 1 落地真实级 mock UI，不进入真实 CloudKit、S3、Keychain、数据库或网络副作用。

## 1. 需求描述

当前 iPhone 设置页中“同步”仍是能力边界说明页，状态表达为未启用，不提供真实级配置界面。用户希望开始优化 iOS 端同步设置体验，先完成 UI 设计并确认产品方案，再进入具体功能开发。初始设想是提供 S3 配置界面，让用户通过对象存储实现多端同步。

本方案需要回答三个问题：

1. 当前市场和主流 App 的多端同步方案大致有哪些？
2. 在语迹当前只面向 Apple 三端的阶段，默认同步方案应选择 iCloud / CloudKit、S3 兼容对象存储，还是其他方案？
3. iOS 端“同步”设置页应如何设计，既达到真实级 UI，又不误导用户认为真实同步能力已经接入？

## 2. 现状描述

### 2.1 产品和文档现状

- `docs/product-main-reference.md` 已将用户自定义对象存储定义为语迹的重要高级卖点，但同时要求同步方案提前明确端到端加密、附件同步、AI 生成内容、向量索引、Prompt Preset、AI Provider 配置、API Key 永不同步和冲突处理等边界。
- `docs/technical-framework-roadmap.md` 已明确同步不绑定 CloudKit-only，而是采用自定义 Sync Engine，并把 CloudKit / iCloud Drive / WebDAV / S3 / R2 作为可选 Sync Adapter。
- `docs/platform-page-inventory.md` 记录当前 iPhone 设置列表包含同步入口，但同步详情还没有真实配置写入；iPad / macOS Sidebar 底部也有 Sync 状态入口。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PrivacyStatus.swift` 中 `SyncProviderStatus.off.summary` 已表达“数据仅保存在本机。你可以稍后配置 iCloud、WebDAV、S3 或 R2。”，说明现有代码已经把 iCloud 和对象存储都视为候选同步目标。

### 2.2 当前实现边界

- 当前没有真实数据库 schema、SQLite / GRDB Repository、附件存储、Sync Engine、CloudKit Adapter、S3 Adapter、WebDAV Adapter、冲突处理或同步 manifest。
- 当前没有 Keychain 同步凭证保存实现。同步设置 UI 即使做成真实级，也只能先表达设计态和 mock draft，不能真正保存访问密钥或发起网络请求。
- 当前没有语言空间真实持久化闭环完全落地；同步配置不应抢在核心本地记录闭环和数据层之前进入真实副作用实现。
- 当前 App 仍处于早期阶段，可以对 UI 和架构方案做较大调整，但若改变“Sync Engine + Adapter”或“本地优先”核心决策，需要新增或更新 ADR。本方案不改变核心决策。

## 3. 市场主流同步方案调研

### 3.1 平台原生同步

代表方案：

- Apple 生态：iCloud / CloudKit / Core Data with CloudKit / SwiftData iCloud sync。
- Google / Android 生态：Google 账号体系下的云端数据同步。

优势：

- 用户认知成本最低。Apple 用户通常理解“通过 iCloud 在 iPhone、iPad、Mac 同步”，不需要理解 bucket、endpoint、access key 或 region。
- 系统集成最好。Apple 官方 CloudKit 支持跨 iOS、iPadOS、macOS、watchOS、visionOS 和 Web 的数据同步能力。
- 登录和账号管理由系统处理。App 不必第一版自建账号体系。
- 对 Apple-only 首发产品，平台原生同步最符合用户预期。

限制：

- 锁定 Apple 生态，不适合未来非 Apple 客户端。
- CloudKit schema、Entitlements、生产环境迁移、后台 remote notification、冲突处理和调试都有复杂度。
- 如果使用 SwiftData/Core Data 自动 CloudKit 同步，模型设计会受 CloudKit schema 限制；例如 SwiftData 文档说明 CloudKit schema 不支持某些 unique constraint、非可选 relationship 和部分 delete rule 语义。
- 与语迹长期候选 SQLite / GRDB 主存储不是一键自动匹配。若坚持 SQLite / GRDB，需要自定义 CloudKit Adapter，而不是直接依赖 SwiftData 自动同步。

### 3.2 应用自建账号和自有云

代表方案：

- Notion、Todoist、Obsidian Sync、1Password 等产品常见的账号 + 官方同步服务。

优势：

- 用户体验最可控，可以跨 Apple / Android / Web / Windows。
- 便于做订阅、家庭共享、团队协作、Web 端和官方托管 AI / 同步增值服务。
- 服务端可以统一处理冲突、迁移、增量同步、附件分片和恢复。

限制：

- 需要账号系统、服务端、账单、运维、安全响应和隐私合规。
- 与语迹第一版“买断制、单人使用、本地优先、用户自带 Provider”的轻量路线冲突。
- 过早上官方云会把核心学习闭环的验证重心转移到基础设施。

### 3.3 BaaS / 托管实时数据库

代表方案：

- Firebase Firestore。
- Supabase 加第三方 sync layer。
- PowerSync、ElectricSQL 等围绕本地数据库和后端同步的方案。
- MongoDB Atlas Device Sync 曾是典型设备同步方案，但 MongoDB 文档和公告显示 Atlas App Services / Device Sync 已进入结束支持或被终止路线，不适合作为新产品长期依赖。

优势：

- 开发速度快，移动端 SDK 成熟。
- Firestore 官方文档说明 Apple 和 Android 平台默认支持离线持久化；设备离线时可以读写缓存，联网后同步本地变化。
- 适合需要跨端、实时协作和云端查询的产品。

限制：

- 产品会绑定到第三方后端、账号、安全规则、计费和数据模型。
- Firestore 的离线同步冲突默认为 last write wins，这和语迹“冲突优先保留多个版本，而不是自动覆盖”的原则不完全一致。
- 托管实时数据库通常不是“用户自带存储”。它更像官方云后端，会削弱语迹“用户掌控 AI 与同步”的定位。

### 3.4 用户自带存储

代表方案：

- S3。
- Cloudflare R2。
- MinIO。
- WebDAV。
- iCloud Drive 或本地文件夹。

优势：

- 数据主权强，适合高级用户、开发者、重视可迁移性的用户。
- 可以避免 App 运营方托管用户生活记录、照片、音频和学习记忆。
- S3 兼容生态广，R2 文档明确提供 S3-compatible API，应用可通过修改 endpoint 迁移到 R2。
- MinIO / S3 / R2 能统一到对象存储 Adapter 思路。

限制：

- 普通 iPhone 用户不熟悉 endpoint、bucket、region、access key、secret key、path-style access 等概念。
- 移动端直接持有对象存储访问密钥存在安全和权限粒度风险。即使密钥保存在 Keychain，也需要最小权限、路径前缀隔离和清晰删除/轮换策略。
- 对象存储只有对象读写语义，不自动提供业务层冲突处理、change log、manifest、迁移和事务一致性。
- 附件、数据库快照、增量日志和加密包格式需要 App 自己设计。

## 4. 决策结论

### 4.1 推荐产品策略

当前 Apple-only 阶段，默认推荐同步方式应为：

> iCloud 同步，技术上优先评估 CloudKit private database / CKSyncEngine Adapter，而不是 iCloud Drive 文件夹同步。

长期高级同步方式应保留为：

> S3 兼容对象存储，包括 AWS S3、Cloudflare R2、MinIO 和自定义 S3-compatible endpoint。

后续可扩展方式：

> WebDAV、本地文件夹、官方托管同步服务。

### 4.1.1 术语边界

本方案后续必须区分三件事：

- iCloud：用户感知层的 Apple 账号和云端存储能力，适合作为 UI 文案中的默认推荐名称。
- CloudKit：App 数据同步 API，适合作为语迹 Apple-only 默认 Adapter 的主要技术候选。
- iCloud Drive：面向文件和文档的同步能力，可作为未来“本地文件夹 / 文档包同步”候选，但不应在本方案中等同于 CloudKit。

因此，同步设置页面向用户可以写“iCloud 同步”，技术方案和实现任务必须写清楚是 CloudKit Adapter 还是 iCloud Drive 文件夹同步。第一阶段推荐评估 CloudKit Adapter；iCloud Drive 不作为默认实现路径。

### 4.2 为什么不是第一眼默认 S3

S3 方向本身正确，但不适合作为 iPhone 用户第一眼看到的默认同步方案。原因：

- iOS 用户对 iCloud 同步的认知成本显著低于 S3。
- S3 配置项过多，会把设置页变成云存储后台表单，削弱语迹的生活记录和语言学习主路径。
- 直接要求用户输入对象存储密钥，会提前引入安全责任、权限隔离、密钥轮换和错误恢复问题。
- 语迹当前还没有真实数据层和 Sync Engine，过早把 S3 做成主路径容易误导用户认为同步能力已经可用。

### 4.3 为什么不能 CloudKit-only

虽然 iCloud / CloudKit 应作为 Apple-only 阶段默认推荐，但不能把长期架构改成 CloudKit-only。原因：

- 产品定位要求用户掌控 AI 与同步，不应把同步主权交给单一 Apple 云服务。
- 语迹长期需要 SQLite / GRDB、导出、对象存储、自定义同步和可迁移数据包。
- CloudKit 适合 Apple 生态，但未来若支持非 Apple 客户端或高级用户自带存储，需要 Adapter 抽象。
- 现有核心决策已经明确“Sync Engine + Adapter”，本方案不反转该决策。

### 4.4 决策表

| 方案 | 推荐定位 | 适合用户 | 优点 | 风险 |
| --- | --- | --- | --- | --- |
| iCloud / CloudKit | Apple-only 阶段默认推荐 | 大多数 iPhone / iPad / Mac 用户 | 低配置、系统集成好、符合 Apple 用户预期 | Apple 生态绑定、CloudKit schema 和调试复杂 |
| S3 兼容对象存储 | 高级选项 | 开发者、高级用户、数据主权敏感用户 | 可迁移、兼容 R2 / MinIO、自带存储 | 配置复杂、密钥安全和冲突处理全部由 App 承担 |
| WebDAV | 后续高级选项 | NAS / 自建云用户 | 用户熟悉度较高、服务广泛 | 协议能力不一、性能和锁语义复杂 |
| 官方同步服务 | 未来增值选项 | 希望零配置跨端的用户 | 体验最好、跨平台能力强 | 需要账号、服务端、订阅和合规 |
| Firebase / Supabase 等 BaaS | 当前不推荐 | 快速验证云端产品 | 开发快、SDK 成熟 | 偏离本地优先和用户自带同步定位 |

## 5. 同步数据边界

### 5.1 默认可以同步

- 语言空间的稳定标识、母语、目标语言、水平和必要元数据。
- 用户创建的生活记录文本。
- 用户编辑后的学习材料。
- 练习记录和学习进度。
- 收藏词句、记忆卡片和用户手动整理内容。
- Prompt Preset 的非敏感配置。
- AI 生成内容，但 UI 必须让用户知道它属于可同步内容。

### 5.2 用户可选择同步

- 照片附件。
- 音频附件。
- OCR 中间结果。
- TTS 生成音频。
- 大体积导入资料。

这些内容可能包含更高隐私风险和更大存储占用。iOS 第一版 UI 应展示选项，但默认关闭或要求用户明确选择。

### 5.3 默认不跨设备同步

- 向量索引。
- FTS 临时索引。
- 本地缓存。
- UI 瞬时状态，例如当前 tab、sheet、popover、面板展开状态、滚动位置。

向量索引应在每台设备本地重建。Embedding Provider 配置和向量化处理配置需要通过 Provider / Repository 边界管理，但索引文件本身不应被当作普通无敏感缓存同步。

### 5.4 永不同步或需要独立高风险确认

- AI Provider API Key。
- S3 / R2 / WebDAV 访问密钥。
- 加密主密钥或恢复密钥。
- 对象存储 secret key。
- 诊断日志中的敏感片段。

当前默认结论：密钥只保存在本机 Keychain 或等价安全存储，不进入数据库、导出包、对象存储、CloudKit 普通记录、同步 manifest 或日志。

### 5.5 SyncConfig 分层

`docs/spec/007-data-storage-migration-export-and-attachments.md` 将 `SyncConfig` 列为主数据候选，但这里必须拆成两层：

- 非敏感配置：Adapter 类型、endpoint、bucket、region、path prefix、同步范围、最近同步状态、设备 ID、manifest 版本等，可以进入普通本地数据库；是否跨设备同步要按 Adapter 单独评估。
- 敏感配置：access key、secret key、WebDAV password、加密口令、恢复密钥、CloudKit 之外的 token 等，只能进入 Keychain 或等价安全存储，默认不进入任何同步内容。

即使非敏感配置可以同步，也不能自动让新设备获得可用同步能力；新设备仍必须通过 iCloud 账号、Keychain 中的本机密钥、用户手动输入恢复口令或重新配置对象存储凭证完成授权。

## 6. 加密、密钥和信任边界

### 6.1 不得混淆的三种保护

同步方案必须区分三种保护层级：

1. 平台传输和存储保护：例如 iCloud / CloudKit、S3、R2、WebDAV 服务自身的 TLS、服务端存储保护和账号访问控制。
2. App 自己的同步包加密：语迹在写入 CloudKit 或对象存储前，将业务 payload 加密成只有用户设备能解开的包。
3. 端到端加密承诺：App 运营方、对象存储服务商或 Apple 都无法读取明文内容。

本方案当前不承诺语迹已经具备第 2 或第 3 层。UI 和发布材料不得把“使用 iCloud / S3”表述成“已经端到端加密”。如果后续要提供端到端加密，必须单独设计密钥创建、跨设备恢复、丢失密钥后的数据恢复失败提示和用户教育。

### 6.2 跨设备密钥问题

如果同步 payload 做 App-level encryption，新设备必须能获得解密密钥。可选路径包括：

- 用户设置同步恢复口令或恢复短语，新设备首次拉取时手动输入。
- 使用平台 Keychain / iCloud Keychain 共享某类同步密钥，但这会改变“密钥默认不同步”的边界，必须单独确认。
- 只在第一阶段依赖 CloudKit private database 和 Apple 账号保护，不做 App-level E2E encryption；此时 UI 必须说明“使用 iCloud 存储和系统保护”，不能写“端到端加密同步”。

推荐阶段策略：

- UI mock 和第一轮设计：不展示“端到端加密已启用”，只展示“密钥不进入同步内容”和“同步范围由你选择”。
- CloudKit Adapter 第一版：优先明确是否采用 App-level encryption。如果不采用，必须把隐私文案限定在 Apple 账号、CloudKit private database 和 App 本地控制范围内。
- S3 Adapter 第一版：必须优先考虑 App-level encryption，因为对象存储由用户自带但服务商可见对象内容和元数据；若不做 App-level encryption，不应允许同步敏感生活记录正文。

### 6.3 元数据泄露边界

即使 payload 加密，对象名、大小、修改时间、设备数量、同步频率、bucket / zone 结构等元数据仍可能暴露使用模式。同步对象命名不应包含：

- 用户输入的标题、原始文件名、语言空间展示名。
- 日记日期加可读标题。
- Provider 名称或 Prompt 名称。
- 能推断内容类型的敏感标签。

对象名应使用稳定 ID、版本号和不可读前缀。可读 manifest 也必须避免泄露日记标题、全文摘要、原始附件文件名和用户真实路径。

## 7. iOS 同步设置 UI 设计方案

### 7.1 页面定位

“同步”设置详情页应是一个隐私敏感的数据控制台，而不是云服务后台表单。它要清楚表达：

- 当前同步状态。
- 推荐同步方式。
- 高级同步方式。
- 会同步哪些数据。
- 哪些内容不会同步。
- 当前阶段是否只是在配置草稿或 mock UI。

### 7.2 第一屏信息架构

iPhone 进入“设置 > 同步”后，建议结构如下：

1. 顶部上下文
   - 标题：同步
   - 当前语言空间：例如“英语 · B1”
   - 状态胶囊：未启用 / 已配置 / 同步中 / 已暂停 / 需要处理

2. 状态卡
   - 未启用时：数据仅保存在本机。
   - 已配置时：仅同步你选择的内容。
   - 同步中时：显示最近一次同步方向和进度。
   - 需要处理时：说明目标位置、权限、网络或冲突需要用户确认。

3. 推荐方式卡
   - iCloud 同步。
   - 文案：适合 iPhone、iPad 和 Mac；使用你的 Apple Account 和 iCloud 存储。
   - 操作：选择 iCloud。
   - 当前阶段如果没有真实 CloudKit 接入，按钮文案应为“查看设计”或“保存本地草稿”，不能写成“立即开启真实同步”。

4. 高级方式卡
   - S3 兼容对象存储。
   - 文案：适合 AWS S3、Cloudflare R2、MinIO 或自定义 S3 endpoint。
   - 操作：配置对象存储。

5. 同步范围卡
   - 生活记录：默认开启。
   - 学习材料和练习进度：默认开启。
   - Prompt Preset：默认开启。
   - AI 生成内容：默认开启或要求用户确认。
   - 照片附件：默认关闭，用户可开启。
   - 音频附件：默认关闭，用户可开启。
   - 向量索引：固定显示“不跨设备同步，本地重建”。
   - API Key 和访问密钥：固定显示“仅本机 Keychain”。

6. 操作卡
   - 预览配置。
   - 检查本机草稿。
   - 查看最近同步状态。
   - 未来真实接入后再加入：保存到 Keychain、测试连接、立即同步、暂停同步。

第一版 UI 设计阶段可以展示这些操作，但实现阶段必须按能力逐步解锁。未接入真实能力前，操作应明确为 mock / draft，不产生外部请求或持久化副作用。若 Keychain 未接入，按钮不应写“保存安全配置”，应写“保存本机草稿”或“预览配置”。

### 7.2.1 iOS 第一版 UI 定稿取舍

基于语迹当前产品定位、Apple-only 首发、真实数据库和同步引擎尚未接入的实现状态，iOS 同步设置第一版采用以下取舍：

1. 第一版只做真实级 mock UI，不保存真实同步配置。
   - 不写入 Keychain。
   - 不写入数据库。
   - 不发起 CloudKit、S3、R2、WebDAV 或 iCloud Drive 请求。
   - 按钮文案使用“预览配置”“检查本机草稿”或“查看同步范围”，不使用“立即启用”“安全保存”“开始同步”。

2. 同步首页只放两张主路径卡。
   - iCloud 同步：推荐，适合 iPhone、iPad 和 Mac。
   - S3 兼容对象存储：高级，适合 AWS S3、Cloudflare R2、MinIO 和自定义 endpoint。
   - WebDAV、本地文件夹和官方同步服务只作为“未来可扩展方式”出现在底部说明，不进入第一屏主操作。

3. 照片和音频附件在第一版 UI 中展示，但默认关闭。
   - 这两个选项能帮助用户理解同步范围和隐私边界。
   - 默认关闭可以避免用户误以为大体积、强隐私附件会自动上传。
   - UI 说明应包含“附件会占用更多云端存储空间，并可能包含更敏感的生活内容”。
   - 控件使用 iOS 原生开关样式，但当前只改变本地 UI 草稿状态，不写入数据库、Keychain 或云端。
   - 生活记录、学习材料、Prompt Preset 和 AI 生成内容不使用开关，作为核心同步范围说明展示。
   - 向量索引和密钥凭证不使用开关，固定展示“本地重建”和“仅本机”，避免误导用户以为可以同步密钥或跨设备搬运派生索引。

4. 第一版 UI 不展示“端到端加密”开关。
   - 当前没有 App-level encryption、跨设备密钥恢复、密钥轮换和遗失恢复策略。
   - 页面只展示“密钥不会进入同步内容”“向量索引本地重建”“同步范围由你选择”。
   - 若未来要展示加密能力，必须另开加密和密钥恢复方案。

5. S3 配置不内嵌在同步首页，而是进入二级页面。
   - iPhone 屏幕上 S3 字段过多，内嵌会压过 iCloud 推荐路径。
   - 同步首页只展示 S3 高级卡、状态摘要和“配置对象存储”入口。
   - 二级页面承载 endpoint、bucket、region、path prefix、access key、secret key、HTTPS、path-style access 和测试连接说明。

6. 第一版同步页不处理真实冲突。
   - 未接入 Sync Engine 前，不展示可点击的冲突处理列表。
   - 可以展示只读的“发生冲突时会保留多个版本”说明，作为后续能力边界。

这些取舍优先保证：普通 iOS 用户不被 S3 表单压垮；高级用户能看到对象存储路径存在；当前 mock UI 不制造真实同步、真实加密或真实保存能力已经完成的错觉。

### 7.3 同步方式选择

推荐使用单选列表或分组卡，而不是顶部 segmented control。原因是同步方式具有较多解释内容和风险边界，卡片能容纳说明、状态和适用人群。

排序建议：

1. iCloud，同步到你的 Apple 设备，推荐。
2. S3 兼容对象存储，高级。
3. WebDAV，稍后支持。
4. 本地文件夹，稍后支持。

“推荐”标签只给 iCloud。S3 不应写成“更安全”或“更高级保护”，而应写成“自带对象存储”和“高级配置”。

### 7.4 iCloud 配置区

第一版 iCloud UI 可包含：

- iCloud 状态：未检查 / 可用 / 未登录 Apple Account / 此 App 的 iCloud 功能不可用 / 权限或配额不足。
- 同步容器：语迹 iCloud 容器。
- 同步范围摘要。
- 说明：数据计入用户 iCloud 存储空间。
- 操作：测试 iCloud 状态、保存同步草稿。

真实实现前不能请求 CloudKit 写入，也不能展示“已同步”。

注意：CloudKit 不应被 UI 错误描述为“需要打开 iCloud Drive”。后续若实现的是 iCloud Drive 文件夹同步，才显示 iCloud Drive 状态和文件访问说明。

### 7.5 S3 兼容对象存储配置区

S3 高级配置页或展开区包含：

- Provider：AWS S3 / Cloudflare R2 / MinIO / 自定义。
- Endpoint。
- Region。
- Bucket。
- Path Prefix，例如 `langotrace/`。
- Access Key ID。
- Secret Access Key，使用 SecureField 和显示/隐藏按钮。
- HTTPS 开关，默认开启。
- Path-style access 开关，MinIO 常用。
- 自定义域名或兼容 endpoint，高级折叠。
- 测试连接。

字段设计要求：

- 访问密钥只存在页面草稿或 Keychain，不进入普通数据模型。
- 不使用真实密钥作为示例。
- R2 的 region 可按 Cloudflare 文档提示使用 `auto` 或兼容值。
- MinIO / 自定义 endpoint 必须提示用户自行保证服务端 HTTPS 和权限最小化。
- UI 应提示用户为语迹创建专用 bucket 或专用 prefix，并使用最小权限凭证。
- 不应建议用户使用主账号长期密钥。后续实现文档必须给出最小权限 policy 示例或检查清单。
- 测试连接只允许检查 bucket / prefix 读写能力，不上传真实生活记录。

### 7.6 备份、导出和同步的边界

设置页需要避免把“备份”“导出”和“同步”混成一个概念：

- 同步：多设备之间持续交换变更，必须处理冲突、删除 tombstone、设备状态和重试。
- 备份：某一时间点的可恢复包，强调恢复能力，不一定持续双向同步。
- 导出：用户可读或可迁移的数据包，强调可检查、可携带，不一定能完整恢复 App 状态。

同步设置页可以链接到“备份 / 导出”说明，但不能把对象存储同步宣传为完整备份替代品。后续真实实现必须同时设计恢复演练，否则不能承诺“可恢复”。

### 7.7 冲突处理 UI

同步冲突不应自动静默覆盖。第一版设计应预留：

- 冲突状态入口。
- 冲突数量。
- 最近冲突时间。
- 处理方式：保留两个版本、选择本机版本、选择远端版本、合并文本。

实现阶段可以先不做完整冲突处理界面，但同步设置页文案不能承诺“自动解决所有冲突”。

### 7.8 删除、撤销和 tombstone 边界

同步实现必须显式处理删除：

- 用户删除 Entry、Language Space、附件或 Prompt Preset 时，不能只删除本机对象；如果同步已启用，必须生成 tombstone 或等价删除记录。
- 删除 tombstone 必须有保留期，避免离线设备重新上线后把已删除内容复活。
- “删除本机数据”“从所有设备删除”“停止同步但保留远端数据”是不同动作，UI 不得合并。
- 在语言空间删除功能真实落地前，同步设置页不应提供会导致跨设备不可恢复删除的入口。

### 7.9 平台后台能力边界

iOS 后台同步能力受系统调度限制。设置页和文案不得承诺“实时同步”或“后台立即同步”。真实实现需要分别定义：

- 前台手动同步。
- App 激活时增量同步。
- 系统允许时的后台同步或 remote notification 拉起。
- 低电量、无网络、蜂窝数据、低数据模式、iCloud 不可用时的降级状态。

第一版 UI 可以显示“最近同步时间”和“下次打开 App 时继续同步”，比承诺实时更安全。

### 7.10 状态文案原则

推荐文案：

- “同步未启用时，数据只保存在这台设备。”
- “启用同步后，只会同步你选择的内容。”
- “密钥只保存在本机 Keychain，不会写入同步数据。”
- “向量索引不跨设备同步，每台设备会在本地重建。”
- “发生冲突时，语迹会优先保留多个版本，而不是自动覆盖。”
- “iCloud 同步使用你的 Apple Account；对象存储同步使用你配置的存储服务。”
- “当前为同步设置预览，不会连接云端或上传内容。”
- “照片和音频附件默认不同步，你可以在真实同步接入后单独开启。”

避免文案：

- “一键安全同步所有数据。”
- “S3 比 iCloud 更安全。”
- “已完成同步配置。”（真实实现前）
- “自动解决冲突。”
- “所有设备实时同步。”（没有真实后台同步和状态验证前）
- “已端到端加密。”（除非 App-level E2E encryption、跨设备密钥恢复和验证都已落地）
- “保存安全配置。”（Keychain 未接入前）
- “立即启用同步。”（CloudKit / Sync Engine 未接入前）

## 8. iOS 页面状态设计

### 8.1 状态 A：同步未启用

这是第一版进入同步详情页的默认状态。

页面结构：

1. 顶部上下文
   - 标题：同步
   - 副标题：当前语言空间，例如“英语 · B1”
   - 状态胶囊：未启用

2. 状态卡
   - 标题：数据只保存在这台设备
   - 正文：启用同步后，语迹只会同步你选择的内容。当前页面不会连接云端或上传内容。
   - 图标：`arrow.triangle.2.circlepath`

3. 推荐卡：iCloud 同步
   - 标签：推荐
   - 标题：同步到你的 Apple 设备
   - 正文：适合 iPhone、iPad 和 Mac。后续实现将优先评估 CloudKit private database。
   - 按钮：预览 iCloud 同步
   - 当前按钮行为：本地展开或进入只读说明，不触发 CloudKit。

4. 高级卡：S3 兼容对象存储
   - 标签：高级
   - 标题：使用自己的对象存储
   - 正文：适合 AWS S3、Cloudflare R2、MinIO 或自定义 endpoint。
   - 按钮：配置对象存储
   - 当前按钮行为：进入二级 mock 表单，不保存凭证。

5. 同步范围卡
   - 生活记录：固定纳入展示，不使用开关。
   - 学习材料和练习进度：固定纳入展示，不使用开关。
   - Prompt Preset：固定纳入展示，不使用开关。
   - AI 生成内容：固定纳入展示，不使用开关；后续真实同步接入时可在更细粒度隐私方案中复审。
   - 照片附件：使用开关，默认关闭；当前只切换本地 UI 草稿，不产生持久化或上传。
   - 音频附件：使用开关，默认关闭；当前只切换本地 UI 草稿，不产生持久化或上传。
   - 向量索引：固定为“本地重建”。
   - 密钥：固定为“仅本机保存，不进入同步”。

6. 底部说明
   - 同步不是导出，也不是一次性备份。
   - 冲突会优先保留多个版本。
   - 第一版预览不会请求网络、Keychain 或数据库写入。

### 8.2 状态 B：预览 iCloud 推荐路径

用户点击“预览 iCloud 同步”后展示 iCloud 推荐路径详情。

页面结构：

1. 顶部状态
   - 标题：iCloud 同步
   - 状态：推荐路径 / 未启用

2. 说明卡
   - 标题：适合 Apple 设备之间同步
   - 正文：iCloud 路径将使用你的 Apple Account。技术实现优先评估 CloudKit private database / CKSyncEngine Adapter。

3. 当前实现边界卡
   - 当前不会检查 iCloud 登录状态。
   - 当前不会创建 CloudKit container 或 record zone。
   - 当前不会写入云端。

4. 后续真实实现检查项
   - Apple Developer account。
   - iCloud capability。
   - CloudKit container。
   - Background Modes。
   - CloudKit schema / zone。
   - accountChanged、quota exceeded、network unavailable、partial failure。

5. 主按钮
   - 第一版：返回同步设置。
   - 真实实现后：检查 iCloud 状态。

禁止：

- 不显示“iCloud Drive 关闭”作为 CloudKit 阻断原因。
- 不显示“已启用 iCloud 同步”。
- 不显示“端到端加密已开启”。

### 8.3 状态 C：配置 S3 高级路径

S3 兼容对象存储使用二级页面，不内嵌在同步首页。

页面结构：

1. 顶部状态
   - 标题：对象存储
   - 状态：高级 / 本机草稿

2. Provider 选择
   - AWS S3。
   - Cloudflare R2。
   - MinIO。
   - 自定义 S3-compatible。

3. 连接字段
   - Endpoint。
   - Region。
   - Bucket。
   - Path Prefix。
   - Access Key ID。
   - Secret Access Key，默认遮蔽，带显示/隐藏按钮。
   - HTTPS 开关，默认开启。
   - Path-style access，默认按 Provider 决定。

4. 安全说明
   - 请为语迹创建专用 bucket 或专用 prefix。
   - 使用最小权限访问密钥。
   - 当前草稿不会保存到 Keychain。
   - 当前不会测试真实连接或上传内容。

5. 操作按钮
   - 第一版主按钮：检查草稿完整性。
   - 第一版次按钮：返回同步设置。
   - 真实实现后才允许出现：测试连接、保存到 Keychain。

字段校验：

- endpoint 不能为空。
- bucket 不能为空。
- path prefix 建议默认 `langotrace/`。
- access key 和 secret key 在 mock 阶段只校验是否为空，不记录真实值。

### 8.4 状态 D：同步异常 / 冲突待处理

第一版 UI 不进入真实异常处理，但需要为未来状态预留样式和文案。

状态类型：

- 未登录 Apple Account。
- iCloud 不可用。
- 对象存储凭证失效。
- 网络不可用。
- 云端空间不足。
- 远端 manifest 损坏。
- 发现冲突。
- 同步暂停。

第一版展示方式：

- 只在方案和模型中预留状态，不在 mock UI 中主动展示真实错误。
- 如果需要视觉样板，可使用静态预览数据，并明确标注“示例状态，不会访问云端”。

未来真实 UI 要求：

- 冲突必须进入用户可恢复路径。
- 错误文案必须说明影响范围和恢复动作。
- 不得把同步关闭、未配置或用户拒绝权限显示为危险错误。

## 9. 架构审查补充结论

### 9.1 审查结论摘要

本方案初稿方向正确，但从系统架构角度必须补强以下边界后才适合进入实施：

- iCloud、CloudKit 和 iCloud Drive 不能混用；默认推荐应落到 CloudKit Adapter 候选，而不是 iCloud Drive。
- “加密后的同步包”必须有密钥管理设计，否则跨设备无法解密；在密钥方案确认前，UI 不得承诺端到端加密。
- SyncConfig 必须拆分非敏感配置和敏感凭证，不能因为 `SyncConfig` 是主数据就把 secret 放入数据库或同步。
- S3 Adapter 必须有最小权限、专用 prefix、对象命名、checksum、重试和删除 tombstone 策略；不能只是上传数据库文件。
- 同步不是备份或导出，三者恢复语义不同；UI 和文档必须分开。
- 后台同步受 iOS 调度限制，不能承诺实时。

### 9.2 进入 UI mock 前的强制条件

进入阶段 1 真实级 mock UI 前，必须确认：

1. iOS 页面中“iCloud”是否明确标注为推荐方式，S3 是否明确标注为高级方式。
2. mock 按钮是否避免“已安全保存”“已同步”“已加密”等真实能力完成表述。
3. 同步范围是否展示“向量索引本地重建”和“密钥仅本机保存”。
4. S3 表单是否默认折叠在高级路径下，不压过 iCloud 推荐路径。
5. iCloud 状态文案是否避免误写为 iCloud Drive 状态。

### 9.3 进入真实 Sync Engine 前的强制条件

进入阶段 2 真实 Sync Engine 设计前，必须先完成：

1. SQLite / GRDB 主数据、附件 manifest、schema version 和迁移策略。
2. 每类主数据的 stable ID、版本号、updatedAt、deletedAt / tombstone、device ID、change author。
3. 同步范围和隐私级别字段，明确哪些对象可以进入哪些 Adapter。
4. 冲突检测规则：同一对象多设备并发修改如何判断、如何保留版本、如何展示给用户。
5. 恢复演练：从空设备拉取、从远端损坏 manifest 恢复、从本地损坏数据库恢复。
6. 密钥策略：是否做 App-level encryption，密钥如何创建、保存、轮换、恢复和遗失处理。

## 10. 实施方案

### 10.1 阶段 0：设计确认

目标：

- 确认本方案的产品策略：iCloud 作为默认推荐，S3 兼容对象存储作为高级选项。
- 确认 iOS 同步设置页的信息架构、文案边界和视觉层级。
- 已定稿：照片和音频附件在第一版 UI 中展示，但默认关闭。
- 已定稿：第一版 UI 不展示“端到端加密”开关，只展示密钥不进入同步内容、同步范围可控、向量索引本地重建。
- 已定稿：S3 配置进入二级页面，不内嵌在同步首页。
- 已定稿：第一版只做真实级 mock UI，不保存真实同步配置。

输出：

- 本方案由 Draft 进入实施，并在阶段 1 完成后更新为 Implemented / Verified。
- 如用户要求，可以再补一份同步设置页 UI 细化规格到 `docs/spec/ui-design/` 或继续在本方案中追加 UI 线框说明。

### 10.2 阶段 1：真实级 mock UI

目标：

- 将 iPhone 同步设置详情从静态说明页升级为真实级 mock 配置页。
- 页面展示 iCloud 推荐卡、S3 高级卡、同步范围、密钥永不同步边界和 mock 操作状态。
- 不接入真实 CloudKit、S3、Keychain、数据库或网络。
- 不展示端到端加密已启用，不展示实时同步已启用。
- S3 配置作为二级 mock 页面。
- 照片和音频附件默认关闭。

预计涉及文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`（新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsModels.swift`（新增）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/*`
- `docs/platform-page-inventory.md`

实际涉及文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/SyncSettingsTests.swift`
- `docs/platform-page-inventory.md`

测试重点：

- `.sync` 不再落入通用只读三段说明页。
- UI 中同时存在 iCloud 推荐和 S3 兼容对象存储高级选项。
- API Key、Secret Access Key、加密密钥等文案不会暗示进入同步。
- 当前 mock UI 不包含 `URLSession`、CloudKit 写入、S3 SDK 调用或 Keychain 写入。
- 当前 mock UI 不包含 `CKContainer`、`CKDatabase`、AWS SDK、S3 签名、WebDAV 请求或文件导出写入。

### 10.3 阶段 2：同步领域模型和 Sync Engine 方案

目标：

- 在不绑定具体 Adapter 的前提下，定义同步 manifest、change log、设备 ID、数据类型范围、附件引用、冲突记录和同步状态模型。
- 明确 SQLite / GRDB schema 与同步状态表的关系。
- 明确哪些字段可同步、哪些字段本地重建、哪些字段只存在 Keychain。
- 明确加密包格式、密钥策略、对象命名规则、删除 tombstone、远端 manifest 损坏恢复和离线设备重新上线流程。

预计涉及文档：

- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/architecture/` 下新增同步架构文档。
- 必要时新增 ADR，前提是改变现有核心决策；若只是细化 Adapter，不需要 ADR。

### 10.4 阶段 3：CloudKit Adapter

目标：

- 作为 Apple-only 阶段默认推荐路径，实现 iCloud / CloudKit Adapter。
- 只同步经过 Sync Engine 筛选和加密/序列化后的业务数据，不让 UI 直接访问 CloudKit。
- 处理 iCloud 账号状态、配额、网络、后台 remote notification、重试和错误恢复。
- 处理 CloudKit zone 初始化、server change token、accountChanged、partial failure、quota exceeded、network unavailable 和 schema promotion。

技术路径：

- 若长期主存储坚持 SQLite / GRDB，优先设计自定义 CloudKit Adapter，使用 CloudKit private database 保存同步包、manifest 或 record zone，而不是强行迁移到 SwiftData 自动同步。
- 如果后续重新评估 SwiftData / Core Data with CloudKit，必须单独做 ADR，因为这会影响主存储选择和数据模型约束。
- CloudKit Adapter 不能直接把本地 SQLite 数据库文件整体上传为唯一同步对象；必须以 Sync Engine 输出的对象级变更、同步包或 manifest 为边界。

### 10.5 阶段 4：S3 兼容对象存储 Adapter

目标：

- 支持 AWS S3、Cloudflare R2、MinIO 和自定义 S3-compatible endpoint。
- 使用最小权限访问密钥，路径前缀隔离语迹数据。
- 上传加密后的同步包、manifest、change log 和附件对象。

技术要求：

- 对象命名必须可迁移、可校验、可恢复。
- 必须有 checksum 或内容哈希。
- 必须处理断点、重试、远端对象缺失、版本冲突和本地删除 tombstone。
- Secret Access Key 只保存在 Keychain，不进入同步内容。
- 必须设计最小权限 policy、专用 bucket / prefix、远端锁或乐观并发控制、multipart 上传失败清理和 manifest 双写保护。

### 10.6 阶段 5：真实冲突处理和恢复

目标：

- 提供用户可理解的冲突处理入口。
- 支持至少文本记录的保留多个版本和手动合并。
- 支持同步暂停、恢复、重试、清除本机同步状态、重新从远端拉取索引。
- 支持离线设备重新上线、远端版本落后、本机版本落后、远端对象缺失、附件缺失和 manifest 损坏的恢复路径。

## 11. 不做什么

- 不在本任务中实现真实 CloudKit、S3、WebDAV 或 iCloud Drive 同步。
- 不在本任务中启用 CloudKit entitlement、iCloud container 或 Background Modes。
- 不保存真实对象存储密钥、iCloud token、加密密钥或同步配置到持久层。
- 不改变 SQLite / GRDB 作为长期主存储候选的当前决策。
- 不把同步设置做成 iPhone 底部一级 Tab。
- 不把界面语言偏好、UI 面板展开状态、滚动状态或其他 transient UI state 放入同步模型。
- 不承诺官方同步服务或订阅服务。
- 不承诺端到端加密同步，除非后续单独完成 App-level encryption 和跨设备密钥恢复设计。
- 不把“iCloud 同步”实现成用户可见的 iCloud Drive 文件夹写入，除非另开方案并确认文件访问、App Sandbox 和恢复语义。
- 不把本地 SQLite 数据库文件整体当作同步和备份的唯一真源。
- 不在第一版 UI 中把 WebDAV、本地文件夹或官方同步服务做成主操作。
- 不在第一版 UI 中展示可切换的端到端加密开关。

## 12. 参考来源

### 12.1 Apple 官方资料

- Apple Developer：CloudKit 介绍页说明 CloudKit 可在 iOS、iPadOS、macOS 等 Apple 平台和 Web 上同步，并强调 private data 存储在用户 iCloud 账号中。  
  来源：https://developer.apple.com/icloud/cloudkit/
- Apple Developer：`CKDatabase` 文档说明每个用户可访问 public、private 和 shared database；private 和 shared database 需要 iCloud account。  
  来源：https://developer.apple.com/documentation/CloudKit/CKDatabase
- Apple Developer：`CKContainer.privateCloudDatabase` 文档说明 private database 只对当前用户可访问，数据计入用户 iCloud storage quota，且用户未登录 iCloud 时使用会报错。  
  来源：https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase
- Apple Developer：`CKSyncEngine` 文档提供 CloudKit 同步引擎 API，默认可通过系统调度进行发送和拉取操作。  
  来源：https://developer.apple.com/documentation/cloudkit/cksyncengine
- Apple Developer：SwiftData iCloud sync 文档说明 SwiftData 可使用 iCloud 自动同步模型数据，但需要 iCloud 和 Background Modes capability，并且模型 schema 需要符合 CloudKit 限制。  
  来源：https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
- Apple Support / Apple Platform Security：iCloud encryption 文档说明 iCloud 服务使用传输和存储保护，部分服务具备端到端加密或受 CloudKit service key 保护。  
  来源：https://support.apple.com/guide/security/icloud-encryption-sec3cac31735/web

### 12.2 第三方和对象存储资料

- Firebase 官方文档：Cloud Firestore 支持离线数据持久化；Apple 和 Android 平台默认启用，联网后会同步本地变化；同一文档多次变更时使用 last write wins。  
  来源：https://firebase.google.com/docs/firestore/manage-data/enable-offline
- Cloudflare R2 官方文档：R2 提供 S3-compatible API，可通过修改 endpoint 迁移 S3 客户端；R2 endpoint 形如 `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`，region 兼容值包括 `auto`。  
  来源：https://developers.cloudflare.com/r2/api/s3/api/
- Cloudflare R2 官方入门文档：R2 支持 S3-compatible API，可使用 S3 SDK、library 或 tool 操作 bucket。  
  来源：https://developers.cloudflare.com/r2/get-started/s3/
- MongoDB 官方文档：Atlas App Services / Device Sync 已进入结束支持或停止支持路径，不适合作为新项目长期同步基础。  
  来源：https://www.mongodb.com/docs/atlas/app-services/sync/configure/pause-or-terminate-sync/

### 12.3 项目内资料

- `docs/product-main-reference.md` 第 24 节：同步、加密与冲突处理原则。
- `docs/technical-framework-roadmap.md` 第 2.5 节：为什么同步不绑定 CloudKit。
- `docs/spec/002-navigation-and-routing.md`：设置入口、同步状态和配置 route 边界。
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`：同步未启用是正常状态，不使用错误视觉。
- `docs/platform-page-inventory.md`：当前 iPhone / iPad / macOS 设置和同步入口事实源。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PrivacyStatus.swift`：`SyncProviderStatus` 当前状态模型和文案。

## 13. 复查方法

设计复查：

- 确认 iCloud 是默认推荐路径，S3 兼容对象存储是高级路径。
- 确认方案没有把 CloudKit-only 写成长期架构。
- 确认方案没有把 S3 写成普通用户默认路径。
- 确认密钥、API Key、访问 token 和加密密钥均不进入同步内容。
- 确认向量索引默认本地重建，不跨设备同步。
- 确认同步冲突原则是保留多个版本，而不是自动覆盖。
- 确认 CloudKit 和 iCloud Drive 没有混用。
- 确认加密文案没有越过当前实现能力。
- 确认 SyncConfig 敏感和非敏感配置分层明确。
- 确认同步、备份和导出没有被混为一个能力。
- 确认第一版 UI 只包含 iCloud 推荐和 S3 高级两张主路径卡。
- 确认 S3 字段只出现在二级页面。
- 确认照片和音频附件默认关闭。
- 确认第一版 UI 没有端到端加密开关。

文档复查：

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs/plans/active/2026-05-19-research-ios-sync-strategy-and-settings-ui.md
git diff --check
git status --short
```

实现阶段源码文案复查：

```bash
rg "一键安全同步所有数据|S3 比 iCloud 更安全|自动解决冲突|所有设备实时同步|已端到端加密|iCloud Drive 关闭" Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift' --glob '*.xcstrings'
```

实现前复查：

- 重新读取 Apple CloudKit、CKSyncEngine、SwiftData iCloud sync、Cloudflare R2 S3 compatibility、AWS S3 和 WebDAV 相关官方文档，因为平台能力和限制可能变化。
- 若进入真实 CloudKit 实现，必须检查 Apple Developer account、iCloud capability、CloudKit container、Background Modes、production schema promotion 和真机测试要求。
- 若进入真实 S3 / R2 实现，必须检查目标 SDK、签名算法、最小权限策略、路径前缀隔离、checksum、重试和对象命名规则。
- 若进入 App-level encryption 实现，必须先完成密钥创建、跨设备恢复、遗失密钥、密钥轮换和诊断日志脱敏方案。

## 14. 验证命令

本任务为方案文档，不运行 Swift 工程验证。当前文档验证命令：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

若后续进入 UI mock 实现，至少运行：

```bash
swift test --package-path Packages/LangoTraceUI
swift test --package-path Packages/LangoTraceCore
swiftlint --no-cache
swiftformat --lint . --cache ignore
scripts/verify.sh
```

实际验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter SyncSettingsTests
swift test --package-path Packages/LangoTraceUI
swift test --package-path Packages/LangoTraceCore
rg "一键安全同步所有数据|S3 比 iCloud 更安全|自动解决冲突|所有设备实时同步|已端到端加密|iCloud Drive 关闭" Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift' --glob '*.xcstrings'
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
scripts/verify.sh
```

结果：

- `SyncSettingsTests`：6 个测试通过。
- `Packages/LangoTraceUI`：94 个测试通过。
- `Packages/LangoTraceCore`：26 个测试通过。
- 禁用同步文案扫描：无命中。
- `swiftlint --no-cache`：0 violations。
- `swiftformat --lint . --cache ignore`：0 files require formatting。
- `git diff --check`：通过。
- 文档占位扫描：无命中。
- `scripts/verify.sh`：通过；包含 XcodeGen、Core / Data / UI 测试、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat 和文档占位扫描。

## 15. 文档影响检查

本方案是同步策略和 UI 设计前置方案，暂不改变长期事实源，因此当前不直接修改 `docs/product-main-reference.md`、`docs/technical-framework-roadmap.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md` 或 ADR。

如果用户确认本方案为产品决策，后续应同步更新：

- `docs/product-main-reference.md`：明确 Apple-only 阶段 iCloud 为推荐默认同步路径，S3 兼容对象存储为高级自带存储路径。
- `docs/technical-framework-roadmap.md`：补充 CloudKit Adapter 与 S3 Adapter 的阶段顺序。
- `docs/platform-page-inventory.md`：在 UI mock 实现后更新同步设置页事实源。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：进入真实数据层和 Sync Engine 设计时补充 manifest、change log、附件和冲突处理规则。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：如果引入 App-level encryption、同步密钥恢复、iCloud Keychain 或对象存储凭证保存，需要补充密钥和诊断日志边界。
- `docs/review/INDEX.md`：若后续落地真实 Sync Engine、CloudKit Adapter、S3 Adapter 或同步数据模型，需要按文档审查机制触发专项审查。

## 16. 实施记录

- 2026-05-19：完成 AGENTS.md 背景阅读。
- 2026-05-19：围绕 iOS 同步设置界面展开头脑风暴，初步判断 S3 兼容对象存储适合作为高级路径，但不适合作为 Apple-only 阶段默认路径。
- 2026-05-19：检索项目文档和当前代码，确认既有决策为 Sync Engine + Adapter，不绑定 CloudKit-only；当前同步未实现真实副作用。
- 2026-05-19：调研 Apple CloudKit / CKSyncEngine / SwiftData iCloud sync、Firebase Firestore offline persistence、Cloudflare R2 S3 compatibility、MongoDB Atlas Device Sync 支持状态等资料。
- 2026-05-19：创建本 Draft 方案，等待用户审阅。
- 2026-05-19：按系统架构师视角完成深度审查，补充 iCloud / CloudKit / iCloud Drive 术语边界、App-level encryption 与跨设备密钥恢复、SyncConfig 分层、S3 最小权限、备份/导出/同步区分、删除 tombstone、后台同步限制和实施前强制条件。
- 2026-05-19：按用户要求由系统架构师视角定稿 UI 取舍：第一版只做真实级 mock UI；同步首页只放 iCloud 推荐和 S3 高级两张主路径卡；照片和音频附件展示但默认关闭；不展示端到端加密开关；S3 配置进入二级页面；异常和冲突只做未来状态预留。
- 2026-05-19：按最新实施指令进入阶段 1。先新增 `SyncSettingsTests` 并确认测试因缺少同步草稿模型和专用 UI 失败，再补 `SyncSettingsModels.swift`、`SyncSettingsView.swift` 和 `SettingsCapabilityDetailView.swift` 路由。
- 2026-05-19：完成真实级 mock UI：同步状态卡、iCloud 推荐卡、S3 兼容对象存储高级卡、同步范围卡、当前无云端副作用边界、iCloud 预览 sheet、S3 二级草稿表单和 Secret Access Key 显示/隐藏控件。
- 2026-05-19：补充 `Localizable.xcstrings` 中同步设置页英文和简体中文文案，避免 UI 渲染本地化 key。
- 2026-05-19：更新 `docs/platform-page-inventory.md`，记录同步设置页已从通用说明升级为 Local Mock，并保留无 Keychain、无数据库、无网络和无上传副作用边界。
- 2026-05-20：运行阶段 1 收口验证，`scripts/verify.sh` 通过；方案状态更新为 `Verified` 并准备移入 `docs/plans/done/`。

## 17. 完成标准

- 文档清楚记录市场主流多端同步方案。
- 文档清楚给出 Apple-only 阶段推荐 iCloud / CloudKit 作为默认同步方式的依据。
- 文档清楚保留 S3 兼容对象存储作为高级同步选项，并说明 AWS S3、Cloudflare R2、MinIO 和自定义 endpoint 的 UI 边界。
- 文档没有反转 Sync Engine + Adapter 的长期架构。
- 文档包含 iOS 同步设置页真实级 UI 结构和文案边界。
- 文档清楚区分 iCloud、CloudKit 和 iCloud Drive。
- 文档清楚说明加密能力、密钥恢复和端到端加密承诺的边界。
- 文档清楚拆分非敏感 SyncConfig 与敏感凭证。
- 文档清楚区分同步、备份和导出。
- 文档定稿 iOS 第一版同步设置 UI 取舍和四类页面状态。
- 文档包含实施阶段、复查方法、验证命令、文档影响检查和参考来源。
- 用户审阅后，将状态更新为 User Approved 或按反馈修订。

## 18. 剩余风险

- Apple、Cloudflare、Firebase、MongoDB 等平台文档和能力会持续变化；进入真实实现前必须再次核对官方文档。
- CloudKit private database、iCloud Drive、SwiftData 自动同步和自定义 CKSyncEngine Adapter 是不同技术路径，不能在实现时混为一谈。
- 如果未来坚持 SQLite / GRDB 作为主存储，CloudKit 只能作为 Adapter 或同步传输层，不能直接套用 SwiftData 自动同步方案。
- S3 兼容对象存储的安全性很大程度依赖用户配置、服务端权限和 App 加密包格式；UI 不能暗示“配置 S3 就天然端到端安全”。
- 真正的多端同步需要数据模型、变更日志、冲突处理、附件策略、加密密钥管理和恢复流程共同落地，不能只靠设置页完成。
- 如果选择 App-level encryption，最大产品风险是用户丢失恢复口令后无法在新设备恢复数据；这需要明确的 UX 和支持策略。
- 如果第一版 CloudKit Adapter 不做 App-level encryption，最大信任风险是隐私文案必须非常克制，不能把 Apple 平台保护包装成语迹自有端到端加密。
