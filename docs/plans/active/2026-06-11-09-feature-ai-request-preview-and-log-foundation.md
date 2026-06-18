# 任务方案：AI 请求预览与请求日志基础（真实"将发送内容"投影 + ai_request_logs）

状态：User Approved
自审核状态：Reviewed（2026-06-18 第二轮隔离自审核，用当前代码核验漂移）
类型：feature
创建日期：2026-06-11
最后更新日期：2026-06-18（批量 run E6 实现前隔离自审核：修正 migration 版本漂移 v15→v24、依赖方向改 App-Shell recorder、失败 taxonomy 常驻映射、generate/analyze/explain 入口、行号漂移）

系列编号：E6（系列母方案：`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`，实施顺序位于 E5 之后启动，但必须先于 E5 Slice 2 完成）。规模：M-L。

前序依赖：

- E0a（`docs/plans/active/2026-06-11-01-refactor-architecture-foundations.md`）：其错误分类整备为本方案的 failure_category 分桶提供统一口径；当前 Core 中失败分类按域分散（`LearningMaterialGenerationFailureCategory`、`ReadingSelectionExplanationFailureCategory` 等，无统一 taxonomy）。E0a 未先行时本方案可按"各域分类 + 映射到日志分桶"落地，E0a 落地后只收敛映射，不阻塞。
- 下游：E5 Slice 2（回译 AI 点评）必须等本方案落地。

## 用户确认记录

本方案在 2026-06-11 系列母方案（`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`）的用户授权下创建。该授权仅覆盖"制定方案文档"本身；本方案进入生产代码实现前，仍需用户单独确认范围与实现授权，并将状态推进到 `User Approved`。

需要用户确认的关键点（见第 13 节）：E6-D2 iPhone 入口形态、E6-D3 取消请求是否记录日志、以及落地后是否恢复"基于预览的隐私状态摘要文案"（涉及今日刚修正的 PrivacyStatus 文案与其防回归测试）。

## 1. 需求或 bug 描述

当前 iPad 工作台与 macOS Inspector 中的 `RequestPreviewCard` 在真实生成路径下只有占位语义（mock 判定驱动），没有真实"将发送内容"投影；App 也没有任何 AI 请求日志。spec 005 §4.3 / §4.4 早已定义请求预览与日志的边界，但缺基础设施。本方案建立：

1. 真实"将发送内容"预览投影：由学习材料生成、阅读选区解释共享，并为未来回译 AI 点评（E5 Slice 2）预留同一投影契约。
2. `ai_request_logs` GRDB 表（migration）：只存非敏感属性（时间戳、能力、Provider preset、adapter kind、长度分桶、状态、失败分类等），绝不存内容、密钥。
3. 接线 iPad 学习面板与 macOS Inspector 的预览卡为真实投影；决定 iPhone 入口形态。
4. 记录一项文档影响：今日（2026-06-11，commit `274b7db`）PrivacyStatus 文案刚被修正为"不承诺请求预览"；本方案落地后，可能允许恢复基于预览的隐私摘要表达，需要显式决策。

## 2. 现状描述

以下事实已对照 2026-06-11 HEAD 核验：

- `RequestPreviewCard` 定义于 `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift:158-197`：文案由 `rendering?.isMock` 驱动，mock 时显示 `Local Mock` 语义（`.localMock(...)`），真实生成时显示 `.externalRequest(entryTitle:promptLabel:)`——内容只有 entry 标题与 prompt 标签，不是真实投影（不含 Provider / model / 长度 / 包含与排除清单）。
- 使用位置：`Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift:151`（iPad 学习面板）、`Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift:24`（macOS Inspector，entryDetail route 时）。
- iPhone：记录详情不默认显示持久 `RequestPreviewCard`（页面清单 §8 红线，已是既成约束）。
- 请求日志：全仓库 grep `ai_request_log` / `requestLog` / `AIRequestLog` 零命中——不存在任何请求日志表或基础设施。Data 最新 migration 为 `v15_reset_reading_explanation_cache_for_unix_epoch`。
- 请求体组装点：学习材料生成 `LearningMaterialGenerationService.makeRequest()`（`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift:162-208`，请求结构 `LearningMaterialServiceGenerationRequest` 含 endpoint、input、operationID、lengthBucket）；阅读解释 `ReadingSelectionExplanationService` + `ReadingSelectionExplanationPromptRegistry`（同目录）。两条路径都已有 operation 摘要落 GRDB 的非敏感 metadata 习惯（`reading_ai_explanation_operations`、learning material operation 摘要）。
- 非敏感属性 allowlist 先例：`DiagnosticAttribute`（`Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift:95-203`）为封闭枚举（operationID、providerPresetID、endpointPurpose、modelName、errorCategory、textLengthBucket、durationBucket、cacheResult 等约 20 个 case），以类型系统强制 allowlist——本方案复用该模式。
- PrivacyStatus：commit `274b7db`（2026-06-11）把 AI 摘要文案改为不承诺请求预览（"Content is sent only when you explicitly trigger an AI feature..."），并有防回归测试 `Packages/LangoTraceUI/Tests/LangoTraceUITests/PrivacyStatusLocalizationTests.swift:48-65` 断言全部语言的 AI 摘要不含 `请求预览` / `request preview` / `preview` 字样。
- 失败分类现状：按域分散（见前序依赖说明），无统一 taxonomy。

## 3. 目标

1. Core 定义 `AIRequestPreviewProjection` 共享契约：capability、Provider preset 标签、model 名、将发送内容描述（包含项清单，如 当前记录正文 / 选中片段及上下文窗口）、明确排除项清单（历史记录、照片、API Key 等）、长度分桶、Prompt id / version。投影与真实请求由同一输入构造（service / registry 暴露投影函数），保证预览不和实际请求漂移。
2. 学习材料生成与阅读选区解释两条真实路径产出投影；为 practice_backtranslation_review 预留 capability 枚举位。
3. `ai_request_logs` 表落地（一个 migration）：列级 allowlist 只含非敏感属性；写入与修剪策略明确（保留上限，超限按时间修剪）。
4. 学习材料生成与阅读解释完成 / 失败（/ 取消，见 E6-D3）时写日志行；取消不写失败分类。
5. iPad 学习面板与 macOS Inspector 的 `RequestPreviewCard` 改为真实投影渲染；日志列表视图（共享组件）在 iPad 面板 / mac Inspector / 设置入口可达。
6. iPhone 入口决策落地（E6-D2）：不引入持久卡片（红线），提供按需预览与日志入口。
7. 记录并提请决策：PrivacyStatus 是否恢复基于预览的隐私摘要（文档影响检查项，含防回归测试的有意调整）。

## 4. 范围

- Core package：`AIRequestPreviewProjection`、`AIRequestLogEntry`（非敏感字段模型 + 封闭属性枚举，仿 `DiagnosticAttribute` 模式）、capability 枚举。
- AI package：两个既有 service / registry 增加投影构造函数（纯函数，不发请求）；请求完成路径产出日志条目（经注入的 sink，AI 不直接依赖 Data concrete，沿用既有依赖方向）。
- Data package：migration `ai_request_logs`、`GRDBAIRequestLogRepository`（写入、按能力查询、修剪）、测试。
- UI package：`RequestPreviewCard` 真实化、日志列表共享组件、iPad / mac 接线、iPhone 按需入口、本地化 key。
- App Shell：装配投影与日志 sink。
- 文档：spec 005 实现状态、页面清单、PrivacyStatus 决策记录。

## 5. 不做什么

- 不做阻断式确认弹窗：学习材料生成保持既有"非阻断确认"边界（spec 005 §4.7），预览是可查看的透明性能力，不是新增同意闸门；改变同意级别需独立方案。
- 不记录任何内容字段：不存用户原文、selection、Prompt 渲染结果、请求体、响应体、API Key、Authorization header、完整 Keychain account、Base URL query 敏感参数（spec 005 §4.4 默认不记录清单）。
- 不做日志同步、导出或跨设备聚合；`ai_request_logs` 是本地诊断性数据。
- 不做用量统计、费用估算或预算（`docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` 的成本预算属独立决策）。
- 不把 TTS probe / 配置合成测试纳入本日志：它们已有 validation event 体系（spec 005 §4.7），两套语义不混表；真实 TTS 生成请求是否入日志留给后续方案。
- 不重构 `diagnostic_events` 体系或与之合并：诊断事件面向开发期排障，请求日志面向用户透明性，受众与生命周期不同。
- 不在本方案直接改 PrivacyStatus 文案：只产出决策入口（第 17 节），文案恢复须用户确认后单独小方案或在本方案实施记录中经确认执行。
- 不实现 Anthropic / Gemini 请求路径（维持现有边界）。

## 6. 证据与决策依据

- spec：`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.3（预览应表达内容类型、是否含照片 / 原文 / 记忆、Provider、model、是否保存元数据；普通用户简洁、高级用户可展开）、§4.4（日志允许与禁止字段）、§4.6（失败分类）、§4.7（学习材料生成披露边界、operation 摘要先例）。
- workflow：`docs/workflows/add-ai-provider.md`（适用场景明确包含"请求预览、请求日志"；其测试要求与故障矩阵被采纳）、`docs/workflows/add-storage-migration.md`（migration 要求采纳）。
- 代码证据：第 2 节逐条（RequestPreviewCard 现状、零日志设施、makeRequest 组装点、DiagnosticAttribute 封闭枚举先例、PrivacyStatus 防回归测试）。
- 页面清单：`docs/platform-page-inventory.md` §8——iPhone 不得默认显示持久 RequestPreviewCard；设置页不得把未接入能力伪装成已接入（日志列表必须真实数据驱动）。
- 系列依赖：E5 Slice 2（`docs/plans/active/2026-06-11-08-feature-practice-backtranslation.md`）以本方案为前置。

```text
证据能证明什么：预览与日志的边界规则在 spec 005 早已定义且有 operation 摘要 / DiagnosticAttribute 的工程先例，本方案是按既定边界补基础设施。
证据不能证明什么：不能证明"预览投影 = 实际请求"在所有未来能力上自动成立；每个新能力接入时必须由同一输入构造投影（契约要求），并有渲染一致性测试。
迁移前提：投影函数与请求构造共享同一 input 结构。
照搬风险：把 validation event / diagnostic event 的字段直接照搬会混入开发期语义；本日志面向用户透明性，字段单独定义。
```

## 7. 约束映射与验证路径

### 约束 1：实现前 active plan + 用户确认 + 自审核

- 约束 ID：DOC-CONST-001 / DOC-CONST-002 / DOC-CONST-003
- 来源：`docs/README.md` §4.16、`docs/plans/plan-review-protocol.md` §2、`docs/plans/README.md` §4
- 适用范围：全局
- 严重度：blocker
- 执行或验证方式：人工审查状态字段
- 验证提示：`User Approved` 前不改生产代码
- 说明：无

### 约束 2：日志与元数据脱敏

- 约束 ID：DOC-CONST-011 / DOC-CONST-014
- 来源：`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.4、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- 适用范围：ai_request_logs 全部写入路径
- 严重度：blocker
- 执行或验证方式：单元测试（封闭枚举类型系统 + repository 写入断言）+ 人工审查
- 验证提示：日志行不可能携带自由文本内容字段——模型层就不存在该字段；测试断言序列化后的行不含用户输入样本
- 说明：复用 DiagnosticAttribute 封闭枚举模式从类型层防住

### 约束 3：数据迁移遵守存储 spec 与 workflow

- 约束 ID：DOC-CONST-012
- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/workflows/add-storage-migration.md`
- 适用范围：Data package
- 严重度：blocker
- 执行或验证方式：migration 测试（新库 + 升级）+ 修剪测试
- 验证提示：日志归类为本地诊断性数据（可清理，不同步不导出）；修剪策略有测试
- 说明：无

### 约束 4：预览不得改变触发边界

- 来源：`docs/spec/005-ai-provider-prompt-and-privacy.md` §4.3 / §4.7
- 适用范围：UI 接线
- 严重度：blocker
- 执行或验证方式：store 单元测试
- 验证提示：查看预览不发起请求；预览存在不把非阻断确认变成阻断流程；照片 / 历史记忆等高风险内容不得借预览复用低摩擦边界
- 说明：无

### 约束 5：iPhone 红线与三端共享 seam

- 来源：`docs/platform-page-inventory.md` §8、`docs/spec/004-swiftui-architecture.md`
- 适用范围：iPhone 入口、三端组件
- 严重度：blocker
- 执行或验证方式：人工审查 + 共享组件测试
- 验证提示：iPhone 无持久预览卡；投影构造三端唯一，平台只决定承载
- 说明：无

### 约束 6：PrivacyStatus 文案变化须显式决策

- 来源：`docs/spec/008-permissions-local-privacy-and-diagnostics.md`、`Packages/LangoTraceUI/Tests/LangoTraceUITests/PrivacyStatusLocalizationTests.swift` 防回归测试（工程事实）
- 适用范围：文档影响检查
- 严重度：warn
- 执行或验证方式：第 17 节决策项 + 用户确认
- 验证提示：恢复预览相关文案必须同步有意调整防回归测试，不得静默放宽
- 说明：今日修复刚把文案收紧，回摆必须留痕

## 8. 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIRequestPreviewProjection.swift`（新建）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIRequestLog.swift`（新建：entry 模型、capability 枚举、封闭属性集）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`（投影函数 + 日志条目产出）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`（同上）
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`（migration 注册）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIRequestLogRepository.swift`（新建）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`（RequestPreviewCard 真实化）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift`、`MacInspectorContent.swift`（接线）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIRequestLogListView.swift`（新建，共享日志列表）
- iPhone 入口承载文件（按 E6-D2 决策：`EntryDetailView` 相关 footnote 入口 + 设置 AI Provider 详情）
- `LangoTraceApp/`（装配 sink 与投影）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- 测试：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/AIRequestLogModelTests.swift`（新建）、`Packages/LangoTraceAI/Tests/LangoTraceAITests/AIRequestPreviewProjectionTests.swift`（新建）、`Packages/LangoTraceData/Tests/LangoTraceDataTests/AIRequestLogRepositoryTests.swift`（新建）、`Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/RequestPreviewCardTests.swift`（新建，落入既有 AIProvider 子目录）

## 9. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`（封闭枚举 allowlist 模式）
- `Packages/LangoTraceData/Sources/LangoTraceData/`（`reading_ai_explanation_operations` 与 learning material operation 摘要的非敏感 metadata 先例）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PrivacyStatusLocalizationTests.swift`（防回归测试现状）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PrivacyStatus.swift`

## 10. 涉及的文档路径

- 本方案。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`（§4.3 / §4.4 从"规则"到"已落地基础设施"的实现状态变更记录）。
- `docs/platform-page-inventory.md`（iPad 面板 / mac Inspector / iPhone 入口 / 日志列表条目）。
- `docs/workflows/add-ai-provider.md`、`docs/workflows/add-prompt.md`（落地后检查"请求预览"步骤是否需要引用新契约；workflow 不是事实源，仅顺序手册更新）。
- PrivacyStatus 决策记录（第 17 节，结论按归属写回 spec 008 或本方案实施记录）。

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### 决策 E6-D1：投影与请求同源

每个 capability 的 service / registry 必须提供 `previewProjection(for input:) -> AIRequestPreviewProjection` 纯函数，与 `makeRequest` 消费同一 input 结构；投影描述"将发送什么类别的内容"（包含项 / 排除项 / 长度分桶 / Provider / model / Prompt 版本），不渲染真实 Prompt 正文（防止预览本身成为敏感内容泄漏面；spec 005 §4.7 明确显式查看密钥等不得进入请求预览）。一致性由测试保证：投影声明的包含项集合必须与该能力 Prompt 文档登记的输入变量一致。

### 决策 E6-D2：iPhone 入口（需用户确认）

iPhone 不引入持久预览卡（红线）。形态：记录详情"生成学习材料"按钮既有披露 footnote 旁提供"将发送内容"按需展开（sheet 或 expandable），点开即渲染真实投影；请求日志列表入口放在 设置 → AI Provider 详情（系统级设置归属，与 Provider 配置同域）。阅读 compact 面板的解释 footnote 同样提供按需展开。

### 决策 E6-D3：取消请求记录口径（需用户确认）

用户取消的请求写入日志，status = cancelled、无失败分类。理由：日志面向用户透明性（"何时差点发送 / 发送了什么类别"），取消本身是用户关心的事实；这与"取消不写失败 validation event"（spec 005 §4.7）不冲突——cancelled 不是失败。

### 步骤

1. Core（TDD）：`AIRequestCapability` 枚举（`learningMaterialGeneration`、`readingSelectionExplanation`，预留 `practiceBacktranslationReview`）；`AIRequestPreviewProjection`（包含项 / 排除项为受限描述符枚举，非自由字符串）；`AIRequestLogEntry`（id、operationID、capability、providerPresetID、endpointPurpose、adapterKind、modelName、promptID、promptVersion、inputLengthBucket、status：success / failed / cancelled、failureCategory（封闭分桶）、durationBucket、createdAt）。先写失败测试锁定"模型层不存在自由文本内容字段"。
2. Data：migration 建 `ai_request_logs`（列与 entry 字段一一对应；索引 `(capability, created_at)`）；repository：`append`（同事务内执行修剪：每 capability 保留最近 200 行，超出按时间删除）、`recent(capability:limit:)`、`recentAll(limit:)`；migration id 在实施时按当时最新注册顺序分配（当前最新 v15，需与 R1 / E4 协调先后）。
3. AI：两个 service 增加投影函数；请求完成路径（成功 / 失败 / 取消）构造 `AIRequestLogEntry` 交给注入的 `AIRequestLogSink`（Core protocol，Data 实现，App Shell 装配——保持 AI 不依赖 Data concrete 的既有方向）。失败分类映射：各域 FailureCategory → 日志封闭分桶（providerNotConfigured / credentialMissing / network / timeout / providerRejected / unsupported / invalidResponse / persistence / unknown）；E0a 收敛 taxonomy 后只改映射表。
4. UI：`RequestPreviewCard` 改为渲染真实投影（Provider / model / 包含项 / 排除项 / 长度 / Prompt 版本；mock rendering 时保留 Local Mock 语义）；新建 `AIRequestLogListView`（共享组件：时间、能力、Provider、状态、失败分类；无任何内容正文可显示）；接线 iPad 面板与 mac Inspector；按 E6-D2 落 iPhone 入口。
5. 装配与回归：App Shell 注入 sink；三端共享 seam 回归测试。
6. 文档收口：spec 005 实现状态变更记录、页面清单、PrivacyStatus 决策提交用户（第 17 节）；migration 命中专项审查判断。

### 故障与恢复路径

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| migration 失败 | 原库不半写入，可诊断错误 | migration 测试 |
| 日志写入失败 | 不影响 AI 请求主流程（sink 失败只进诊断，不向用户报错） | service / sink 测试 |
| 修剪与写入并发 | 同事务执行，无竞态 | repository 测试 |
| 投影构造失败（input 不完整） | 预览显示不可用态，不阻塞请求按钮既有行为 | UI 测试 |
| 旧库无日志表期间的查询 | repository 返回空列表而非崩溃（migration 后不存在该态，测试覆盖空表） | repository 测试 |

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：主会话自审核（双轮）
审核轮次：第一轮（架构）+ 第二轮（测试 / 安全 / 落地性）
未使用隔离审查的原因：本环境无并行隔离审查会话可用于方案文本审查；已按协议维度逐项自查，并以只读代码核验代理输出作为事实输入。
发现摘要：
  第一轮：
  - [P0] 初稿预览投影包含"渲染后的 Prompt 正文摘要"；与 spec 005 §4.7（预览不得成为敏感内容暴露面）冲突，且会使预览本身需要脱敏审查；改为受限描述符（包含项 / 排除项枚举），写入 E6-D1。
  - [P1] 初稿把日志条目直接写入 diagnostic_events；两者受众与生命周期不同（开发期排障 vs 用户透明性），混表会让诊断开关控制用户可见日志；改为独立表 + 独立 repository，并写入第 5 节"不做什么"。
  - [P1] AI 直接依赖 Data repository 会破坏依赖方向（2026-05-24 备忘录确立的边界）；改为 Core sink protocol + App Shell 装配。
  - [P2] 修剪策略初稿缺失（日志无限增长）；定为每 capability 保留 200 行、append 同事务修剪。
  第二轮：
  - [P1] "投影与实际请求不漂移"缺验证手段；加入"投影包含项与 Prompt 文档登记变量一致"的测试要求（第 15 节）。
  - [P1] PrivacyStatus 防回归测试会与未来文案恢复冲突；升级为约束 6 + 用户确认项，禁止静默放宽。
  - [P2] 取消是否记日志需要明确口径；新增 E6-D3 并与"取消不写失败 validation event"区分。
  - [P2] migration id 跨方案硬编码风险；统一为实施时分配。
  - [P3] 日志列表必须真实数据驱动，空态不得伪装（页面清单红线）；写入步骤 4。
写回修改：以上各项均已写回第 5、6、7、12、15 节。
仍需用户确认的问题：E6-D2 iPhone 入口形态；E6-D3 取消记录口径；落地后 PrivacyStatus 文案是否恢复预览表达；本方案整体范围与实现授权（推进到 User Approved）。
是否允许进入实现：待用户确认后允许。
```

## 14. 复查方法

1. 预览：iPad 记录详情触发生成前查看面板预览卡——显示真实 Provider preset、model、包含项（当前记录正文）、排除项（历史记录 / 照片 / API Key）、长度分桶、Prompt 版本；mac Inspector 同步；查看预览不发请求（测试断言）。
2. 日志：执行一次生成与一次解释（成功 / 失败 / 取消各一），日志列表出现对应行；逐行检查无内容正文；数据库行字段与 allowlist 一致。
3. 修剪：写入超过上限后旧行被修剪（repository 测试）。
4. iPhone：记录详情无持久卡；按需展开可见投影；设置 AI Provider 详情可达日志列表。
5. 故障矩阵逐项触发验证（第 12 节表格），重点：日志写失败不影响生成主流程。
6. 一致性：投影包含项集合与 `docs/prompts/` 对应 Prompt 文档输入变量一致（测试 + 人工抽查）。

## 15. TDD / 测试落点

```text
测试落点：
  1. Packages/LangoTraceCore/Tests/LangoTraceCoreTests/AIRequestLogModelTests.swift（新建：entry 字段封闭性、分桶映射、capability 枚举契约）
  2. Packages/LangoTraceAI/Tests/LangoTraceAITests/AIRequestPreviewProjectionTests.swift（新建：两能力投影构造、包含项与 Prompt 变量一致、投影纯函数不触发网络、成功 / 失败 / 取消产出正确日志条目）
  3. Packages/LangoTraceData/Tests/LangoTraceDataTests/AIRequestLogRepositoryTests.swift（新建：migration schema、append + 修剪、按能力查询、空表查询、事务失败回滚）
  4. Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/RequestPreviewCardTests.swift（新建：真实投影渲染、Local Mock 保留、查看不触发请求、iPhone 无持久卡断言）
先失败用例：
  testLearningMaterialPreviewProjectionDescribesProviderModelAndContentKinds
  —— 用与 makeRequest 相同的 LearningMaterialServiceGenerationRequest 输入调用 previewProjection，断言投影含 provider preset / model / 包含项 = 当前记录正文 / 排除项含 API Key；投影函数尚不存在，按 stub-first 建空投影使断言失败成红。
聚焦验证命令：
  swift test --package-path Packages/LangoTraceAI --filter AIRequestPreviewProjectionTests
不新增单元测试的原因（如适用）：三端面板视觉承载与 sheet 交互属人工模拟器验证；投影内容、日志字段与触发边界均已由单元测试覆盖。
```

## 16. 验证命令

```bash
# 聚焦（红绿循环）
swift test --package-path Packages/LangoTraceAI --filter AIRequestPreviewProjectionTests
swift test --package-path Packages/LangoTraceData --filter AIRequestLogRepositoryTests
swift test --package-path Packages/LangoTraceUI --filter RequestPreviewCardTests

# 受影响 package 轻量验证
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
git diff --check
git status --short
```

按 CLAUDE.md §1.4 约束 7，不主动运行 `scripts/verify.sh`。

## 17. 文档影响检查

- `docs/spec/005-ai-provider-prompt-and-privacy.md`：§4.3 / §4.4 实现状态与允许字段落地记录——是。
- `docs/platform-page-inventory.md`：iPad 面板预览卡真实化、mac Inspector、iPhone 按需入口、日志列表条目——是。
- **PrivacyStatus 文案决策项**：今日 commit `274b7db` 刚把隐私状态摘要修正为不承诺请求预览（含 `PrivacyStatusLocalizationTests` 防回归断言）。本方案落地后预览成为真实能力，可以考虑恢复基于预览的隐私摘要表达；该恢复必须：用户显式确认 → 有意调整防回归测试（保留对未实现能力的禁止语义）→ 文案变更记录写回 spec 008 或独立小方案。本方案只登记决策入口，不静默恢复——是。
- `docs/workflows/add-ai-provider.md` / `add-prompt.md`：落地后检查是否需要把"投影函数 + 日志接入"补入手册步骤——是（workflow 为顺序手册，不改变权威关系）。
- ADR：无核心决策变化（透明性能力沿用 ADR-005 本地优先边界）。
- `docs/review/`：数据库 schema 变化 + 请求日志属 AI Provider 域，命中专项审查触发条件，实现完成后创建 review round 或在本方案实施记录中说明。

## 13bis. 第二轮隔离自审核记录（2026-06-18，批量 run 实现前）

```text
审核日期：2026-06-18
审核方式：隔离审查（子代理只读，用当前 HEAD 代码逐条核验方案 §2 现状断言）
审核轮次：实现前漂移复核（第二轮）
核心决策 / ADR 反转检查：无。ai_request_logs 为本地诊断性数据（不同步/不导出/无内容字段），透明性能力沿用 ADR-005 本地优先边界与核心决策 9/10；不构成暂停条件，准予进入实现。
确认的漂移与修订（已写回对应章节）：
  [P0-1] E0a 并未统一失败 taxonomy（仅在各域枚举补 case）。各域 FailureCategory→日志封闭分桶的映射是【常驻设计】，不是过渡映射。证据：LearningMaterialGenerationFailureCategory（Core/LearningMaterialGenerationModels.swift:29，16 case）、ReadingSelectionExplanationFailureCategory（Core/ReadingAIExplanation.swift:86，10 case）仍按域分散；无统一 FailureCategory 类型。→ 步骤 3 与 §20 风险 2 改为常驻映射表。
  [P0-2] 依赖方向：现有非敏感 operation 摘要不是由 AI service 写入，而是【App Shell recorder】写入。证据：LangoTraceApp/ReadingExplanationOperationRecorder.swift + AppEnvironment.swift:265-316 在 explain 调用前后 record(.pending/.succeeded/.cancelled/.failed)；AI service 是纯执行器，不 import Data、不持 sink。→ E6-D1/步骤 3 改为新增 App-Shell `AIRequestLogRecorder`（镜像 ReadingExplanationOperationRecorder）在 AppEnvironment 包裹 generate/analyze/explain，不向 LangoTraceAI 注入 sink。Core 仍持非敏感模型 + 封闭枚举（仿 DiagnosticAttribute，DiagnosticEvent.swift:97），Data 持 repository。
  [P1-1] migration 漂移：最新已是 v23_create_practice_text_attempts（AppDatabase.swift:111），新表为 **v24_create_ai_request_logs**，沿用 db.create(table:) inline 模式（无 Migrations/ 目录、无独立 SQL 文件）。
  [P1-2] 投影挂在公共入口 generate(_:)（:68）/ analyze(_:)（:89）/ explain(_:)（:152）消费的 request 结构上，非私有 makeRequest（:173）。请求结构 LearningMaterialServiceGenerationRequest 在 :4。
  [P2-1] RequestPreviewCard 现位于 LearningContentComponents.swift:165-204（cases/use-site 行为不变；PadLearningPanelView.swift:151、MacInspectorContent.swift:24 验证准确）。
  [P2-3] 预留 capability practiceBacktranslationReview 接入的是 E5 Slice1 既有 seam（PracticeMode.backtranslation 小写、submitBacktranslationAttempt）；注意学习材料 kind 用 backTranslation（驼峰），两拼写并存，capability 采用 practiceBacktranslationReview。
写回修改：§2 现状、§8 路径、§12 步骤 1-3 与 E6-D1、§15 TDD seed、§20 风险均已同步。
仍需用户确认的问题（不阻塞，批量 run 预授权下按推荐方案直接采纳并留痕）：
  - E6-D2 iPhone 入口：采纳「记录详情按需展开 + 设置 AI Provider 详情挂日志列表」。
  - E6-D3 取消记日志：采纳 status=cancelled、无失败分类。
  - PrivacyStatus 文案恢复：本方案【不恢复】，维持 274b7db 收紧文案与防回归测试，只登记决策入口（§17）。理由：恢复属独立隐私文案变更，应单独留痕，不在基础设施方案里夹带。
是否允许进入实现：是（批量 run §1 预授权 + 本轮漂移已修订写回）。
```

## 18. 实施记录

2026-06-11：方案创建并完成两轮自审核（见第 13 节）。尚未进入实现。

2026-06-18：批量 run 实现前隔离自审核完成（见 §13bis），状态推进 User Approved，开 feature/e6-ai-request-preview-log 分支进入 TDD 实现。

## 19. 完成标准

1. 第 15 节测试全部存在且通过；首个失败用例转绿。
2. 两条真实路径（生成 / 解释）的预览与日志可用；E5 Slice 2 可仅通过新增 capability + 投影函数接入（以测试中注册预留 capability 验证扩展性）。
3. iPad / mac / iPhone 入口符合各自红线；日志列表真实数据驱动。
4. PrivacyStatus 决策项已提交用户并有结论记录（恢复 / 暂不恢复均可，必须留痕）。
5. 文档影响检查各项完成；专项审查判断有记录。
6. plan-vs-shipped 对账：

```text
work item 是否都有文档 / 代码 / 测试 / 脚本 / review evidence：收口时逐项核对第 12 节步骤 1–6。
scope-down 是否已记录：若 iPhone 入口或日志列表缩水，记录决策日志。
deferred / aborted 项是否已从完成叙事中剥离：是。
后续事实源或复审入口：spec 005、platform-page-inventory、本方案实施记录中的 PrivacyStatus 决策。
```

## 20. 剩余风险

1. 投影描述符粒度是人工维护的契约：新能力若忘记登记包含项，预览会缺项而非错项；以"投影与 Prompt 文档变量一致"测试缓解，但 Prompt 文档本身偏差仍需人工审查兜底。
2. failure_category 分桶在 E0a 收敛前是映射表方案，存在双重维护面；E0a 落地后收敛，期间映射表变更需同步测试。
3. 日志保留上限（200 / capability）是经验值，重度用户可能希望更长历史；本地数据可日后放宽，无迁移成本。
4. 取消记录（E6-D3）若用户认为"取消也留痕"过于敏感，可改为不记录——属一行开关级调整，已列为用户确认项。
